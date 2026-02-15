"""Skill learning system - saves and reuses successful action sequences."""

import json
import re
from pathlib import Path

from .config import SKILLS_DIR, SKILL_AUTO_EXECUTE_THRESHOLD


def _skills_file(name: str) -> Path:
    return SKILLS_DIR / f"{name}.json"


def _normalize_name(text: str) -> str:
    """Convert natural language to a skill filename."""
    text = text.lower().strip()
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", "_", text)
    return text[:60]


def save_skill(command: str, steps: list[dict], app: str = "") -> str:
    """Save a successful action sequence as a skill."""
    SKILLS_DIR.mkdir(parents=True, exist_ok=True)
    name = _normalize_name(command)
    path = _skills_file(name)

    if path.exists():
        skill = json.loads(path.read_text())
        skill["success_count"] += 1
        skill["steps"] = steps  # Update with latest successful steps
    else:
        skill = {
            "name": name,
            "command": command,
            "trigger_patterns": [command.lower()],
            "steps": steps,
            "app": app,
            "success_count": 1,
        }

    path.write_text(json.dumps(skill, indent=2, ensure_ascii=False))
    return name


def find_skill(command: str) -> dict | None:
    """Find a matching skill for the given command."""
    command_lower = command.lower().strip()

    best_match = None
    best_score = 0

    for path in SKILLS_DIR.glob("*.json"):
        try:
            skill = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            continue

        for pattern in skill.get("trigger_patterns", []):
            # Simple word overlap scoring
            pattern_words = set(pattern.split())
            command_words = set(command_lower.split())
            overlap = len(pattern_words & command_words)
            score = overlap / max(len(pattern_words | command_words), 1)

            if score > best_score and score > 0.6:
                best_score = score
                best_match = skill

    return best_match


def should_auto_execute(skill: dict) -> bool:
    """Check if a skill has enough successes to run without AI."""
    return skill.get("success_count", 0) >= SKILL_AUTO_EXECUTE_THRESHOLD


def demote_skill(name: str) -> None:
    """Reduce skill success count on failure."""
    path = _skills_file(name)
    if not path.exists():
        return
    try:
        skill = json.loads(path.read_text())
        skill["success_count"] = max(0, skill.get("success_count", 0) - 1)
        if skill["success_count"] <= 0:
            path.unlink()
        else:
            path.write_text(json.dumps(skill, indent=2, ensure_ascii=False))
    except (json.JSONDecodeError, OSError):
        pass


def list_skills() -> list[dict]:
    """List all saved skills."""
    skills = []
    for path in sorted(SKILLS_DIR.glob("*.json")):
        try:
            skills.append(json.loads(path.read_text()))
        except (json.JSONDecodeError, OSError):
            continue
    return skills

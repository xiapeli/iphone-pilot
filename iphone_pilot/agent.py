"""Agent - executes action steps on the iPhone.

This module provides the execution layer. The "brain" is Claude Code itself,
which analyzes screenshots using its native vision and decides the actions.
"""

import time

from . import actions, screen, skills


def execute_step(step: dict) -> bool:
    """Execute a single action step.

    Step format: {"action": "tap", "x": 163, "y": 340}

    Supported actions:
        tap(x, y)           - Tap at coordinates
        swipe(x1,y1,x2,y2) - Swipe between points
        type(text)          - Type text
        press_key(key)      - Press special key (return, delete, etc.)
        home()              - Go to home screen
        back()              - Go back (Escape)
        scroll_down()       - Scroll down
        scroll_up()         - Scroll up
        open_app(name)      - Open app by name via Spotlight
        app_switcher()      - Open app switcher
        spotlight()         - Open Spotlight search
        wait(seconds)       - Wait
    """
    action = step.get("action")

    if action == "tap":
        return actions.tap(step["x"], step["y"])
    elif action == "swipe":
        return actions.swipe(step["x1"], step["y1"], step["x2"], step["y2"])
    elif action == "type":
        return actions.type_text(step["text"])
    elif action == "press_key":
        return actions.press_key(step["key"])
    elif action == "home":
        return actions.home()
    elif action == "back":
        return actions.back()
    elif action == "scroll_down":
        return actions.scroll_down()
    elif action == "scroll_up":
        return actions.scroll_up()
    elif action == "paste":
        return actions.paste_text(step["text"])
    elif action == "open_app":
        return actions.open_app(step["name"])
    elif action == "app_switcher":
        return actions.app_switcher()
    elif action == "spotlight":
        return actions.spotlight()
    elif action == "wait":
        time.sleep(step.get("seconds", 1))
        return True
    return False


def execute_steps(steps: list[dict]) -> list[dict]:
    """Execute a list of action steps.

    Returns list of results: [{"step": ..., "success": bool}]
    """
    results = []
    for step in steps:
        success = execute_step(step)
        results.append({"step": step, "success": success})
        if not success:
            break
    return results


def screenshot(path: str | None = None) -> str | None:
    """Capture current iPhone screen. Returns path to saved PNG."""
    return screen.capture_screenshot(path)


def status() -> dict:
    """Check iPhone Mirroring status."""
    running = screen.is_iphone_mirroring_running()
    bounds = screen.get_window_bounds() if running else None
    return {
        "running": running,
        "bounds": bounds,
        "width": bounds[2] if bounds else None,
        "height": bounds[3] if bounds else None,
    }


def save_skill(command: str, steps: list[dict], app: str = "") -> str:
    """Save a successful sequence as a reusable skill."""
    return skills.save_skill(command, steps, app)


def find_skill(command: str) -> dict | None:
    """Find a cached skill matching the command."""
    return skills.find_skill(command)


def run_skill(command: str) -> list[dict] | None:
    """Find and execute a cached skill. Returns results or None if no skill found."""
    skill = skills.find_skill(command)
    if not skill or not skills.should_auto_execute(skill):
        return None
    results = execute_steps(skill["steps"])
    all_ok = all(r["success"] for r in results)
    if all_ok:
        skills.save_skill(command, skill["steps"], skill.get("app", ""))
    else:
        skills.demote_skill(skill["name"])
    return results

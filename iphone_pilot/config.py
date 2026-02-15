"""Configuration and constants for iPhone Pilot."""

from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SKILLS_DIR = PROJECT_ROOT / "skills"
SCREENSHOT_PATH = PROJECT_ROOT / "screenshot.png"

# iPhone Mirroring window
IPHONE_MIRRORING_PROCESS = "iPhone Mirroring"

# Timing
ACTION_DELAY = 0.8  # seconds to wait after each action
SCREENSHOT_DELAY = 0.3  # seconds to wait before screenshot

# Skills
SKILL_AUTO_EXECUTE_THRESHOLD = 3  # success_count needed to auto-execute

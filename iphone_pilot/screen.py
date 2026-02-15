"""Screen capture for iPhone Mirroring window."""

import subprocess
import time
from pathlib import Path

from .config import IPHONE_MIRRORING_PROCESS, SCREENSHOT_DELAY, SCREENSHOT_PATH


def get_window_bounds() -> tuple[int, int, int, int] | None:
    """Get iPhone Mirroring window position and size via AppleScript.

    Returns (x, y, width, height) or None if window not found.
    """
    script = f'''
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            set winPos to position of window 1
            set winSize to size of window 1
            return (item 1 of winPos) & "," & (item 2 of winPos) & "," & (item 1 of winSize) & "," & (item 2 of winSize)
        end tell
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        parts = result.stdout.strip().split(", ")
        if len(parts) != 4:
            return None
        return tuple(int(p) for p in parts)
    except (subprocess.TimeoutExpired, ValueError):
        return None


def capture_screenshot(path: str | Path | None = None) -> str | None:
    """Capture iPhone Mirroring window to a PNG file.

    Args:
        path: Where to save. Defaults to SCREENSHOT_PATH.

    Returns the absolute path to the saved screenshot, or None on failure.
    """
    time.sleep(SCREENSHOT_DELAY)
    bounds = get_window_bounds()
    if not bounds:
        return None

    x, y, w, h = bounds
    save_path = Path(path) if path else SCREENSHOT_PATH

    try:
        result = subprocess.run(
            ["screencapture", "-R", f"{x},{y},{w},{h}", "-x", str(save_path)],
            capture_output=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        return str(save_path.resolve())
    except subprocess.TimeoutExpired:
        return None


def is_iphone_mirroring_running() -> bool:
    """Check if iPhone Mirroring app is running."""
    script = f'''
    tell application "System Events"
        return exists process "{IPHONE_MIRRORING_PROCESS}"
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() == "true"
    except subprocess.TimeoutExpired:
        return False


def bring_to_front() -> None:
    """Bring iPhone Mirroring window to front."""
    script = f'''
    tell application "{IPHONE_MIRRORING_PROCESS}"
        activate
    end tell
    '''
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=5)

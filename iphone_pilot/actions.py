"""Actions on iPhone via iPhone Mirroring (tap, swipe, type, home)."""

import subprocess
import time

from .config import ACTION_DELAY, IPHONE_MIRRORING_PROCESS
from .screen import get_window_bounds


def _run_applescript(script: str) -> bool:
    """Run an AppleScript and return success status."""
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        return False


def _to_absolute(rel_x: int, rel_y: int) -> tuple[int, int] | None:
    """Convert coordinates relative to iPhone window to absolute screen coords."""
    bounds = get_window_bounds()
    if not bounds:
        return None
    win_x, win_y, _, _ = bounds
    return (win_x + rel_x, win_y + rel_y)


def tap(x: int, y: int) -> bool:
    """Tap at coordinates relative to iPhone Mirroring window."""
    abs_coords = _to_absolute(x, y)
    if not abs_coords:
        return False
    ax, ay = abs_coords
    script = f'''
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            set frontmost to true
        end tell
    end tell
    delay 0.2
    do shell script "cliclick c:{ax},{ay}"
    '''
    result = _run_applescript(script)
    time.sleep(ACTION_DELAY)
    return result


def swipe(x1: int, y1: int, x2: int, y2: int, duration: float = 0.3) -> bool:
    """Swipe from (x1,y1) to (x2,y2), coordinates relative to iPhone window."""
    start = _to_absolute(x1, y1)
    end = _to_absolute(x2, y2)
    if not start or not end:
        return False
    sx, sy = start
    ex, ey = end
    # cliclick drag: dd = drag down (mousedown, move, mouseup)
    script = f'''
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            set frontmost to true
        end tell
    end tell
    delay 0.2
    do shell script "cliclick dd:{sx},{sy} du:{ex},{ey}"
    '''
    result = _run_applescript(script)
    time.sleep(ACTION_DELAY)
    return result


def type_text(text: str) -> bool:
    """Type text into the currently focused field."""
    # Escape special characters for AppleScript
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    script = f'''
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            set frontmost to true
        end tell
    end tell
    delay 0.2
    tell application "System Events"
        keystroke "{escaped}"
    end tell
    '''
    result = _run_applescript(script)
    time.sleep(ACTION_DELAY)
    return result


def press_key(key: str) -> bool:
    """Press a special key (return, escape, delete, tab)."""
    key_codes = {
        "return": 36, "escape": 53, "delete": 51,
        "tab": 48, "space": 49, "up": 126,
        "down": 125, "left": 123, "right": 124,
    }
    code = key_codes.get(key.lower())
    if code is None:
        return False
    script = f'''
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            set frontmost to true
        end tell
    end tell
    delay 0.2
    tell application "System Events"
        key code {code}
    end tell
    '''
    result = _run_applescript(script)
    time.sleep(ACTION_DELAY)
    return result


def home() -> bool:
    """Go to home screen (swipe up from bottom)."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    # Swipe up from bottom center
    return swipe(w // 2, h - 20, w // 2, h // 3)


def back() -> bool:
    """Go back (swipe from left edge to right)."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    # Swipe from left edge to center
    return swipe(10, h // 2, w // 2, h // 2)


def scroll_down() -> bool:
    """Scroll down on the current screen."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    return swipe(w // 2, h * 2 // 3, w // 2, h // 3)


def scroll_up() -> bool:
    """Scroll up on the current screen."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    return swipe(w // 2, h // 3, w // 2, h * 2 // 3)

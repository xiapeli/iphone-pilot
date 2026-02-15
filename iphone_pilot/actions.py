"""Actions on iPhone via iPhone Mirroring (tap, swipe, type, home).

All actions activate iPhone Mirroring first, get bounds, compute
absolute coordinates, then execute via cliclick in a single flow.
"""

import subprocess
import time

from .config import ACTION_DELAY, IPHONE_MIRRORING_PROCESS
from .screen import get_window_bounds


def _run_cliclick(*args: str) -> bool:
    """Run cliclick with given arguments."""
    try:
        result = subprocess.run(
            ["cliclick", *args],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def _activate_and_run(*cliclick_args: str) -> bool:
    """Activate iPhone Mirroring, then immediately run cliclick."""
    # Activate in AppleScript
    script = f'''
    tell application "{IPHONE_MIRRORING_PROCESS}" to activate
    delay 0.5
    '''
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=5)
    return _run_cliclick(*cliclick_args)


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
    result = _activate_and_run(f"c:{ax},{ay}")
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
    result = _activate_and_run(f"dd:{sx},{sy}", f"du:{ex},{ey}")
    time.sleep(ACTION_DELAY)
    return result


def type_text(text: str) -> bool:
    """Type text into the currently focused field."""
    # Activate iPhone Mirroring first
    script = f'''
    tell application "{IPHONE_MIRRORING_PROCESS}" to activate
    delay 0.5
    '''
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=5)

    # Use cliclick for typing (handles special chars better)
    result = _run_cliclick(f"t:{text}")
    time.sleep(ACTION_DELAY)
    return result


def press_key(key: str) -> bool:
    """Press a special key (return, escape, delete, tab)."""
    # Map friendly names to cliclick key codes
    key_map = {
        "return": "return", "escape": "escape", "delete": "delete",
        "tab": "tab", "space": "space", "up": "arrow-up",
        "down": "arrow-down", "left": "arrow-left", "right": "arrow-right",
    }
    ck_key = key_map.get(key.lower())
    if ck_key is None:
        return False

    script = f'''
    tell application "{IPHONE_MIRRORING_PROCESS}" to activate
    delay 0.5
    '''
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=5)

    result = _run_cliclick(f"kp:{ck_key}")
    time.sleep(ACTION_DELAY)
    return result


def home() -> bool:
    """Go to home screen (swipe up from bottom)."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    return swipe(w // 2, h - 20, w // 2, h // 3)


def back() -> bool:
    """Go back (swipe from left edge to right)."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
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

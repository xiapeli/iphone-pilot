"""Actions on iPhone via iPhone Mirroring (tap, swipe, type, home).

Uses the Swift helper (iphone_event) which sends CGEvents directly to the
iPhone Mirroring process via CGEventPostToPid. The physical mouse cursor
does NOT move — you can keep using your Mac normally.
"""

import subprocess
import time
from pathlib import Path

from .config import ACTION_DELAY
from .screen import get_window_bounds

HELPER = str(Path(__file__).parent.parent / "helper" / "iphone_event")


def _run_helper(*args: str) -> bool:
    """Run the Swift event helper."""
    try:
        result = subprocess.run(
            [HELPER, *args],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def tap(x: int, y: int) -> bool:
    """Tap at coordinates relative to iPhone Mirroring window.
    Does NOT move the physical mouse cursor.
    """
    result = _run_helper("tap", str(x), str(y))
    time.sleep(ACTION_DELAY)
    return result


def swipe(x1: int, y1: int, x2: int, y2: int, steps: int = 20) -> bool:
    """Swipe from (x1,y1) to (x2,y2), coordinates relative to iPhone window.
    Does NOT move the physical mouse cursor.
    """
    result = _run_helper("swipe", str(x1), str(y1), str(x2), str(y2), str(steps))
    time.sleep(ACTION_DELAY)
    return result


def type_text(text: str) -> bool:
    """Type text into the currently focused field.
    Does NOT steal focus from your current app.
    """
    result = _run_helper("type", text)
    time.sleep(ACTION_DELAY)
    return result


def press_key(key: str) -> bool:
    """Press a special key (return, escape, delete, tab, space, arrows)."""
    result = _run_helper("key", key)
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

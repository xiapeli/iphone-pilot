"""Actions on iPhone via iPhone Mirroring (tap, swipe, type, home).

Uses the Swift helper (iphone_event) which sends events via:
- CGEvent with private source for taps (zero cursor movement)
- Scroll wheel events for scrolling (zero cursor movement)
- AppleScript System Events for keyboard sequences (most reliable)
- Cmd+1/2/3 shortcuts for Home/App Switcher/Spotlight

Focus is automatically saved/restored after each action.
"""

import subprocess
import time
from pathlib import Path

from .config import ACTION_DELAY
from .screen import get_window_bounds

HELPER = str(Path(__file__).parent.parent / "helper" / "iphone_event")


def _run_helper(*args: str, timeout: int = 15) -> bool:
    """Run the Swift event helper."""
    try:
        result = subprocess.run(
            [HELPER, *args],
            capture_output=True, text=True, timeout=timeout,
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


def swipe(x1: int, y1: int, x2: int, y2: int) -> bool:
    """Swipe from (x1,y1) to (x2,y2) using scroll wheel events.
    Does NOT move the physical mouse cursor.
    """
    result = _run_helper("swipe", str(x1), str(y1), str(x2), str(y2))
    time.sleep(ACTION_DELAY)
    return result


def type_text(text: str) -> bool:
    """Type text into the currently focused field."""
    result = _run_helper("type", text)
    time.sleep(ACTION_DELAY)
    return result


def press_key(key: str) -> bool:
    """Press a special key (return, escape, delete, tab, space, arrows)."""
    result = _run_helper("key", key)
    time.sleep(ACTION_DELAY)
    return result


def open_app(name: str) -> bool:
    """Open an app by name using Spotlight search.
    Uses AppleScript: Home → Spotlight → type name → Return.
    """
    result = _run_helper("openapp", name, timeout=15)
    time.sleep(ACTION_DELAY)
    return result


def home() -> bool:
    """Go to home screen (Cmd+1)."""
    result = _run_helper("home")
    time.sleep(ACTION_DELAY)
    return result


def app_switcher() -> bool:
    """Open app switcher (Cmd+2)."""
    result = _run_helper("appswitcher")
    time.sleep(ACTION_DELAY)
    return result


def spotlight() -> bool:
    """Open Spotlight search (Cmd+3)."""
    result = _run_helper("spotlight")
    time.sleep(ACTION_DELAY)
    return result


def back() -> bool:
    """Go back (press Escape key)."""
    return press_key("escape")


def scroll_down() -> bool:
    """Scroll down on the current screen using scroll wheel events."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    result = _run_helper("scroll", str(w // 2), str(h // 2), "-300")
    time.sleep(ACTION_DELAY)
    return result


def scroll_up() -> bool:
    """Scroll up on the current screen using scroll wheel events."""
    bounds = get_window_bounds()
    if not bounds:
        return False
    _, _, w, h = bounds
    result = _run_helper("scroll", str(w // 2), str(h // 2), "300")
    time.sleep(ACTION_DELAY)
    return result

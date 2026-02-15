"""Screen capture for iPhone Mirroring window."""

import subprocess
import time
from pathlib import Path

from .config import IPHONE_MIRRORING_PROCESS, SCREENSHOT_DELAY, SCREENSHOT_PATH

# Cache bounds to avoid repeated activate calls within a session
_cached_bounds: tuple[int, int, int, int] | None = None


def _activate_and_get_bounds() -> tuple[int, int, int, int] | None:
    """Activate iPhone Mirroring and get window bounds in a single AppleScript.

    iPhone Mirroring's window only exists when the app is frontmost.
    We must activate it and get bounds in the same script to avoid
    the window disappearing when another app takes focus.
    """
    script = f'''
    tell application "{IPHONE_MIRRORING_PROCESS}" to activate
    delay 1.5
    tell application "System Events"
        tell process "{IPHONE_MIRRORING_PROCESS}"
            if (count of windows) is 0 then
                delay 1.5
            end if
            if (count of windows) is 0 then
                return "NOWINDOW"
            end if
            set winPos to position of window 1
            set winSize to size of window 1
            set x to item 1 of winPos
            set y to item 2 of winPos
            set w to item 1 of winSize
            set h to item 2 of winSize
            return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
        end tell
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return None
        output = result.stdout.strip()
        if output == "NOWINDOW" or not output:
            return None
        parts = output.split(",")
        if len(parts) != 4:
            return None
        return tuple(int(p) for p in parts)
    except (subprocess.TimeoutExpired, ValueError):
        return None


def get_window_bounds(use_cache: bool = True) -> tuple[int, int, int, int] | None:
    """Get iPhone Mirroring window position and size.

    Activates the app first (required — window only exists when frontmost).
    Caches the result for subsequent calls within the same CLI invocation.

    Returns (x, y, width, height) or None if window not found.
    """
    global _cached_bounds
    if use_cache and _cached_bounds is not None:
        return _cached_bounds

    bounds = _activate_and_get_bounds()
    if bounds:
        _cached_bounds = bounds
    return bounds


def capture_screenshot(path: str | Path | None = None) -> str | None:
    """Capture iPhone Mirroring window to a PNG file.

    Activates iPhone Mirroring, captures the screen region, then returns
    the absolute path to the saved screenshot.
    """
    bounds = get_window_bounds(use_cache=False)
    if not bounds:
        return None

    x, y, w, h = bounds
    save_path = Path(path) if path else SCREENSHOT_PATH
    time.sleep(SCREENSHOT_DELAY)

    try:
        result = subprocess.run(
            ["screencapture", f"-R{x},{y},{w},{h}", "-x", str(save_path)],
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
    time.sleep(1)

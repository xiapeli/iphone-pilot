"""Screen capture for iPhone Mirroring window.

Uses screencapture -l<windowID> to capture the window regardless of z-order.
The window does NOT need to be frontmost — works even behind other windows.
"""

import subprocess
import time
from pathlib import Path

from .config import SCREENSHOT_DELAY, SCREENSHOT_PATH

HELPER = str(Path(__file__).parent.parent / "helper" / "iphone_event")


def get_window_bounds() -> tuple[int, int, int, int] | None:
    """Get iPhone Mirroring window position and size via Swift helper.

    Uses CGWindowListCopyWindowInfo — works even when app is in background.
    Returns (x, y, width, height) or None if window not found.
    """
    try:
        result = subprocess.run(
            [HELPER, "bounds"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        parts = result.stdout.strip().split(",")
        if len(parts) != 4:
            return None
        return tuple(int(p) for p in parts)
    except (subprocess.TimeoutExpired, ValueError, FileNotFoundError):
        return None


def get_window_id() -> int | None:
    """Get the CGWindowID for iPhone Mirroring window.

    Used for screencapture -l<windowID> which captures the window
    regardless of z-order (even behind other windows).
    """
    try:
        result = subprocess.run(
            [HELPER, "windowid"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        return int(result.stdout.strip())
    except (subprocess.TimeoutExpired, ValueError, FileNotFoundError):
        return None


def capture_screenshot(path: str | Path | None = None) -> str | None:
    """Capture iPhone Mirroring window to a PNG file.

    Uses screencapture -l<windowID> to capture the specific window,
    even if it's behind other windows. Does NOT activate or move focus.
    Returns the absolute path to the saved screenshot, or None on failure.
    """
    window_id = get_window_id()
    if not window_id:
        return None

    save_path = Path(path) if path else SCREENSHOT_PATH
    time.sleep(SCREENSHOT_DELAY)

    try:
        result = subprocess.run(
            ["screencapture", f"-l{window_id}", "-o", "-x", str(save_path)],
            capture_output=True, timeout=5,
        )
        if result.returncode != 0:
            return None
        return str(save_path.resolve())
    except subprocess.TimeoutExpired:
        return None


def is_iphone_mirroring_running() -> bool:
    """Check if iPhone Mirroring app is running."""
    try:
        result = subprocess.run(
            [HELPER, "pid"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0 and result.stdout.strip().isdigit()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

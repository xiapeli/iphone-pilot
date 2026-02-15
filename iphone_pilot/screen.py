"""Screen capture for iPhone Mirroring window."""

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


def capture_screenshot(path: str | Path | None = None) -> str | None:
    """Capture iPhone Mirroring window to a PNG file.

    Does NOT activate or move focus — captures from wherever the window is.
    Returns the absolute path to the saved screenshot, or None on failure.
    """
    bounds = get_window_bounds()
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
    try:
        result = subprocess.run(
            [HELPER, "pid"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0 and result.stdout.strip().isdigit()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

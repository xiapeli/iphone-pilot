# iPhone Pilot - Project Guide

## What is this?

A toolkit that lets Claude Code control an iPhone via macOS iPhone Mirroring. No API keys needed — Claude Code's native vision is the brain.

## Quick Start

```bash
source .venv/bin/activate
iphone-pilot status         # Check connection
iphone-pilot screenshot     # Capture screen
iphone-pilot tap 163 340    # Tap at coordinates
iphone-pilot type "hello"   # Type text
iphone-pilot home            # Go to home screen
```

## Using the /iphone command

Type `/iphone Open Settings and go to Wi-Fi` to control the iPhone via natural language.

## Architecture

```
helper/
└── iphone_event.swift     → Swift: CGEvent injection (zero cursor movement for taps)
iphone_pilot/
├── config.py               → Constants and paths
├── screen.py               → Screenshot via screencapture -l<windowID> (works in background)
├── actions.py              → Tap, swipe, type, scroll via Swift helper
├── agent.py                → Execution layer (step runner, status, skills)
├── skills.py               → Skill learning system (JSON persistence)
└── main.py                 → CLI entry point
.claude/skills/iphone/      → Claude Code /iphone skill
skills/                     → Learned skills (JSON files)
```

## How events work

- **Tap**: CGEvent with private source posted at target coordinates. No cursor movement.
- **Swipe**: Cursor briefly warped during drag (physical mouse disconnected). Restored after.
- **Scroll**: Scroll wheel events posted at target coordinates. No cursor movement.
- **Type/Key**: Keyboard events posted via private source.
- **Focus**: iPhone Mirroring is briefly activated (~300ms), then previous app restored.
- **Screenshot**: `screencapture -l<windowID>` captures window even behind other windows.

## Coordinate System

- Origin (0, 0) = top-left of the iPhone Mirroring window
- Typical window size: ~326x720 pixels
- All tap/swipe coordinates are relative to this window

## Development

```bash
# Compile Swift helper
swiftc -O -o helper/iphone_event helper/iphone_event.swift -framework Cocoa

# Setup Python
python3 -m venv .venv && source .venv/bin/activate && pip install -e .

# Test
iphone-pilot status
iphone-pilot screenshot
helper/iphone_event tap 163 340
helper/iphone_event scroll 163 400 -300
```

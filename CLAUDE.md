# iPhone Pilot - Project Guide

## What is this?

A toolkit that lets Claude Code control an iPhone via macOS iPhone Mirroring. No API keys needed — Claude Code's native vision is the brain.

## Quick Start

```bash
# Activate the virtual environment
source .venv/bin/activate

# Check if iPhone Mirroring is connected
iphone-pilot status

# Capture a screenshot (saves to screenshot.png)
iphone-pilot screenshot

# Execute actions
iphone-pilot tap 163 340
iphone-pilot type "hello"
iphone-pilot home
```

## Using the /iphone command

Type `/iphone Open Settings and go to Wi-Fi` to start controlling the iPhone. The skill will handle the capture → analyze → act → verify loop automatically.

## Architecture

```
.claude/skills/iphone/   → Claude Code skill (the brain)
iphone_pilot/
├── config.py             → Constants and paths
├── screen.py             → Screenshot capture via screencapture + AppleScript
├── actions.py            → Tap, swipe, type via cliclick + AppleScript
├── agent.py              → Execution layer (step runner, status, skills)
├── skills.py             → Skill learning system (JSON persistence)
└── main.py               → CLI entry point
skills/                   → Learned skills (JSON files)
```

## Development

```bash
# Setup
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e .

# Test
iphone-pilot status
iphone-pilot screenshot
```

## Coordinate System

- Origin (0, 0) = top-left of the iPhone Mirroring window
- Typical window size: ~326x720 pixels
- All tap/swipe coordinates are relative to this window

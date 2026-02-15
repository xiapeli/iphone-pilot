---
name: iphone
description: Control iPhone via iPhone Mirroring. Use when the user wants to interact with their iPhone - tap, swipe, type, open apps, navigate, or perform any action on the iPhone screen.
argument-hint: "[what to do on the iPhone]"
allowed-tools: Bash(*), Read, Glob, Grep
---

# iPhone Pilot - Control iPhone via iPhone Mirroring

You are controlling an iPhone through macOS iPhone Mirroring. You have access to the `iphone-pilot` CLI toolkit to capture screenshots and execute actions.

## Available Commands

```bash
iphone-pilot status                          # Check connection
iphone-pilot screenshot [path]               # Capture screen → returns file path
iphone-pilot tap <x> <y>                     # Tap at coordinates
iphone-pilot swipe <x1> <y1> <x2> <y2>      # Swipe between points
iphone-pilot type <text>                     # Type text
iphone-pilot key <return|delete|escape|tab>  # Press special key
iphone-pilot home                            # Go to home screen
iphone-pilot back                            # Swipe back
iphone-pilot scroll-down                     # Scroll down
iphone-pilot scroll-up                       # Scroll up
iphone-pilot skills                          # List learned skills
```

## Workflow

Follow this loop for every user request:

### 1. Check connection
```bash
iphone-pilot status
```
If not connected, tell the user to open iPhone Mirroring.

### 2. Capture screenshot
```bash
iphone-pilot screenshot
```
This saves a PNG file. Read it with the Read tool to see the iPhone screen.

### 3. Analyze the screen
After reading the screenshot image, identify:
- What app/screen is currently showing
- All visible UI elements (buttons, text, icons, fields)
- Their approximate coordinates (top-left of iPhone screen is 0,0)
- The iPhone screen is typically ~326x720 pixels

### 4. Execute actions
Based on what you see, execute the appropriate commands:
```bash
iphone-pilot tap 163 340        # Tap on an element
iphone-pilot type "hello"       # Type into a focused field
iphone-pilot scroll-down        # Scroll to find more content
```

### 5. Verify result
After each action, capture a new screenshot and read it to confirm the action worked:
```bash
iphone-pilot screenshot
```
Then read the screenshot to verify.

### 6. Repeat
Continue the capture → analyze → act → verify loop until the task is complete.

## User Request

$ARGUMENTS

## Important Rules

- ALWAYS capture and READ a screenshot before deciding what to tap
- Coordinates are relative to the iPhone Mirroring window (0,0 = top-left of iPhone screen)
- After tapping, WAIT briefly then screenshot again to see the result
- If something doesn't work, try alternative approaches (scroll to find element, go home and try again)
- Be precise with coordinates - aim for the CENTER of the target element
- Tell the user what you see and what you're doing at each step
- If you can't find an element, scroll down/up to look for it
- The iPhone screen is small (~326x720), so elements are compact

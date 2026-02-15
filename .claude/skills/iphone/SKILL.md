---
name: iphone
description: Control iPhone via iPhone Mirroring. Use when the user wants to interact with their iPhone - tap, swipe, type, open apps, navigate, or perform any action on the iPhone screen.
argument-hint: "[what to do on the iPhone]"
allowed-tools: Bash(*), Read, Glob, Grep
---

# iPhone Pilot - Control iPhone via iPhone Mirroring

You control an iPhone through macOS iPhone Mirroring using the `iphone-pilot` CLI.

**CLI path:** `/Users/phelipexavier/iphone-pilot/.venv/bin/iphone-pilot`

Alias for this document: `ip` = `/Users/phelipexavier/iphone-pilot/.venv/bin/iphone-pilot`

## Commands

| Command | What it does |
|---------|-------------|
| `ip screenshot` | Captures iPhone screen → prints PNG path. Read the file to see it. |
| `ip tap <x> <y>` | Tap at coordinates (relative to iPhone screen, 0,0 = top-left) |
| `ip swipe <x1> <y1> <x2> <y2>` | Swipe between two points |
| `ip type "<text>"` | Type text into focused field |
| `ip key <return\|delete\|escape\|tab\|space>` | Press a special key |
| `ip home` | Swipe up to go to home screen |
| `ip back` | Swipe right to go back |
| `ip scroll-down` | Scroll the current view down |
| `ip scroll-up` | Scroll the current view up |
| `ip status` | Check if iPhone Mirroring is connected |

## How to execute a task

Follow this loop strictly:

### Step 1: Screenshot and analyze

```bash
/Users/phelipexavier/iphone-pilot/.venv/bin/iphone-pilot screenshot
```

Then **Read** the PNG file it prints. Look at the image and identify:
- Current app and screen state
- All visible buttons, text, icons, and fields
- Approximate (x, y) coordinates for each element
- Screen size is ~326 wide x 720 tall

### Step 2: Act

Run ONE action at a time:

```bash
/Users/phelipexavier/iphone-pilot/.venv/bin/iphone-pilot tap 163 340
```

### Step 3: Screenshot again to verify

```bash
/Users/phelipexavier/iphone-pilot/.venv/bin/iphone-pilot screenshot
```

Read the new screenshot to confirm the action had the expected effect.

### Step 4: Repeat until done

Continue the **screenshot → analyze → act → verify** loop until the task is complete.

## User Request

$ARGUMENTS

## Critical Rules

1. **ALWAYS screenshot first.** Never guess coordinates — look at the screen.
2. **One action at a time.** Tap, then screenshot, then decide next action.
3. **Coordinates are relative to the iPhone screen.** Top-left corner is (0, 0). Bottom is ~720. Right edge is ~326.
4. **Aim for the CENTER** of buttons/icons, not edges.
5. **If "iPhone in Use" appears** — tell the user to lock their iPhone so mirroring reconnects, then tap the "Connect" button (~230, 730).
6. **If an element isn't visible** — scroll down/up to find it before giving up.
7. **If a tap doesn't work** — the coordinates might be off. Screenshot again, recalculate, and retry.
8. **Tell the user what you see** at each step — describe the screen briefly.
9. **Don't loop more than 15 actions** without confirming progress with the user.
10. **The screenshot command handles activation** — it automatically brings iPhone Mirroring to the foreground. No need to activate it manually.

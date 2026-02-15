# iPhone Pilot

Control your iPhone via macOS iPhone Mirroring using natural language — powered by Claude Code's native vision.

No API keys. No external AI calls. Claude Code **is** the brain — it sees the screen, decides what to do, and uses this toolkit to execute.

## Demo

```
You: /iphone Open Settings and go to Wi-Fi

Claude Code: Capturing screenshot...
             I can see the home screen with app icons.
             Tapping on "Settings" at (163, 340)...

             Capturing screenshot...
             Settings is open. I can see the menu items.
             Tapping on "Wi-Fi" at (163, 180)...

             Done! Wi-Fi settings are now open.
```

## Requirements

- macOS 15+ (Sequoia) with [iPhone Mirroring](https://support.apple.com/en-us/105097)
- Python 3.11+
- [cliclick](https://github.com/BlueM/cliclick) (`brew install cliclick`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## Setup

```bash
# 1. Install cliclick (mouse automation tool)
brew install cliclick

# 2. Clone and install
git clone https://github.com/xiapeli/iphone-pilot.git
cd iphone-pilot
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e .

# 3. Verify
iphone-pilot status
```

## Usage

### With Claude Code (recommended)

1. Open **iPhone Mirroring** on your Mac
2. Open Claude Code inside the `iphone-pilot` project directory
3. Use the `/iphone` command:

```
/iphone Open the Instagram app
/iphone Send "hello" on WhatsApp to the first chat
/iphone Take a screenshot
/iphone Go to Settings > Wi-Fi
```

The `/iphone` skill handles the full loop: capture screen → analyze with vision → execute action → verify → repeat.

### CLI (manual / scripting)

```bash
iphone-pilot status                          # Check connection
iphone-pilot screenshot [path]               # Capture screen
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

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Claude Code (the brain)                        │
│  - Sees screenshots via native vision           │
│  - Decides what actions to take                 │
│  - Orchestrates the full workflow               │
└──────────────┬──────────────────────────────────┘
               │ calls via Bash
┌──────────────▼──────────────────────────────────┐
│  iphone-pilot CLI (the hands)                   │
│  - Captures screenshots (screencapture)         │
│  - Detects window position (AppleScript)        │
│  - Executes taps/swipes/typing (cliclick)       │
│  - Manages learned skills (JSON)                │
└──────────────┬──────────────────────────────────┘
               │ controls
┌──────────────▼──────────────────────────────────┐
│  iPhone Mirroring (macOS 15+)                   │
│  - Mirrors iPhone screen on Mac                 │
│  - Receives click/keyboard events               │
└─────────────────────────────────────────────────┘
```

## Skills System

iPhone Pilot learns from successful interactions. Completed action sequences are saved as JSON files in `skills/`. After enough successful runs, skills are replayed directly without needing AI analysis.

```bash
iphone-pilot skills    # List all learned skills
ls skills/             # See raw JSON files
```

## Project Structure

```
iphone-pilot/
├── .claude/
│   └── skills/iphone/SKILL.md   # Claude Code /iphone command
├── iphone_pilot/
│   ├── config.py                 # Constants and paths
│   ├── screen.py                 # Screenshot capture
│   ├── actions.py                # Tap, swipe, type, home, back
│   ├── agent.py                  # Execution layer
│   ├── skills.py                 # Skill learning system
│   └── main.py                   # CLI entry point
├── skills/                       # Learned skills (JSON)
├── CLAUDE.md                     # Claude Code project guide
├── CONTRIBUTING.md               # Contribution guidelines
└── pyproject.toml                # Package config (zero dependencies)
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Areas where help is needed

- **Multi-display support** — better window detection on multi-monitor setups
- **Gesture accuracy** — improving tap/swipe precision
- **New gestures** — long press, pinch, rotate
- **Skill matching** — better fuzzy matching for cached skills
- **Testing** — automated tests with mock screenshots
- **Documentation** — usage examples and video tutorials

## License

MIT

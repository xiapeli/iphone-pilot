# Contributing to iPhone Pilot

Thanks for your interest! iPhone Pilot is an open-source project and contributions are welcome.

## How to Contribute

### Reporting Bugs

Open an issue with:
- What you expected to happen
- What actually happened
- Your macOS version and iPhone model
- Screenshot of the error (if applicable)

### Suggesting Features

Open an issue with the `enhancement` label describing:
- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes
4. Test manually with iPhone Mirroring
5. Commit with a clear message
6. Push and open a Pull Request

## Development Setup

```bash
# Prerequisites
brew install cliclick
# Python 3.11+ required

# Clone and setup
git clone https://github.com/<your-fork>/iphone-pilot.git
cd iphone-pilot
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e .

# Verify
iphone-pilot status
```

## Project Structure

| Module | Purpose |
|--------|---------|
| `screen.py` | Screen capture via `screencapture` + AppleScript window detection |
| `actions.py` | iPhone interactions via `cliclick` + AppleScript |
| `agent.py` | Execution layer — runs action steps, manages status |
| `skills.py` | Skill persistence — save/load/match learned action sequences |
| `config.py` | Constants and paths |
| `main.py` | CLI entry point |

## Areas Where Help is Needed

- **Multi-display support**: Better window detection on multi-monitor setups
- **Action reliability**: Improving tap/swipe accuracy
- **Skill matching**: Better NLP for matching commands to cached skills
- **New actions**: Long press, pinch, rotate gestures
- **Testing**: Automated tests with mock screenshots
- **Documentation**: Usage examples and tutorials

## Guidelines

- Keep it simple — minimal dependencies, no heavy frameworks
- All interactions go through AppleScript + `cliclick` (no pyobjc/pyautogui)
- The "brain" is Claude Code, not this project — keep AI logic out of the Python code
- Skills are JSON files in `skills/` — keep them human-readable

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

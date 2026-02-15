"""CLI entry point for iPhone Pilot.

Provides a simple CLI for direct use, but the primary usage is via Claude Code
which uses this package as a toolkit (screenshot, tap, swipe, type).
"""

import json
import sys

from . import __version__, agent, screen, skills as skills_mod


def main():
    """Simple CLI for manual use and diagnostics."""
    if len(sys.argv) < 2:
        print(f"iPhone Pilot v{__version__}")
        print(f"Usage: iphone-pilot <command> [args]")
        print()
        print("Commands:")
        print("  status              Check iPhone Mirroring connection")
        print("  screenshot [path]   Capture screen to file")
        print("  tap <x> <y>        Tap at coordinates")
        print("  swipe <x1> <y1> <x2> <y2>  Swipe between points")
        print("  type <text>         Type text")
        print("  key <key>           Press key (return, delete, etc.)")
        print("  home                Go to home screen")
        print("  back                Go back")
        print("  scroll-down         Scroll down")
        print("  scroll-up           Scroll up")
        print("  run <json-steps>    Execute action steps from JSON")
        print("  skills              List learned skills")
        return

    cmd = sys.argv[1]

    if cmd == "status":
        info = agent.status()
        if info["running"] and info["bounds"]:
            print(f"OK - iPhone Mirroring ({info['width']}x{info['height']})")
        elif info["running"]:
            print("RUNNING - but window not accessible (bring it to foreground)")
        else:
            print("NOT CONNECTED - Open iPhone Mirroring first")
            sys.exit(1)

    elif cmd == "screenshot":
        path = sys.argv[2] if len(sys.argv) > 2 else None
        result = agent.screenshot(path)
        if result:
            print(result)
        else:
            print("ERROR: Failed to capture", file=sys.stderr)
            sys.exit(1)

    elif cmd == "tap" and len(sys.argv) >= 4:
        ok = agent.execute_step({"action": "tap", "x": int(sys.argv[2]), "y": int(sys.argv[3])})
        print("OK" if ok else "FAIL")

    elif cmd == "swipe" and len(sys.argv) >= 6:
        ok = agent.execute_step({
            "action": "swipe",
            "x1": int(sys.argv[2]), "y1": int(sys.argv[3]),
            "x2": int(sys.argv[4]), "y2": int(sys.argv[5]),
        })
        print("OK" if ok else "FAIL")

    elif cmd == "type" and len(sys.argv) >= 3:
        ok = agent.execute_step({"action": "type", "text": " ".join(sys.argv[2:])})
        print("OK" if ok else "FAIL")

    elif cmd == "key" and len(sys.argv) >= 3:
        ok = agent.execute_step({"action": "press_key", "key": sys.argv[2]})
        print("OK" if ok else "FAIL")

    elif cmd == "home":
        ok = agent.execute_step({"action": "home"})
        print("OK" if ok else "FAIL")

    elif cmd == "back":
        ok = agent.execute_step({"action": "back"})
        print("OK" if ok else "FAIL")

    elif cmd == "scroll-down":
        ok = agent.execute_step({"action": "scroll_down"})
        print("OK" if ok else "FAIL")

    elif cmd == "scroll-up":
        ok = agent.execute_step({"action": "scroll_up"})
        print("OK" if ok else "FAIL")

    elif cmd == "run" and len(sys.argv) >= 3:
        steps = json.loads(sys.argv[2])
        results = agent.execute_steps(steps)
        print(json.dumps(results, indent=2))

    elif cmd == "skills":
        for s in skills_mod.list_skills():
            print(f"  {s['name']} ({s.get('success_count', 0)} uses)")

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


def cli():
    main()


if __name__ == "__main__":
    cli()

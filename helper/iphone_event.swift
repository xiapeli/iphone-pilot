#!/usr/bin/env swift
// iphone_event.swift — Send mouse/keyboard events to iPhone Mirroring
// without moving the physical cursor.
//
// Uses CGEventPostToPid (private CoreGraphics API) to post events
// directly to the iPhone Mirroring process.
//
// Usage:
//   iphone_event tap <x> <y>
//   iphone_event swipe <x1> <y1> <x2> <y2> [steps]
//   iphone_event type <text>
//   iphone_event key <keycode>

import Cocoa

// Private API: post CGEvent to a specific process (no cursor movement)
@_silgen_name("CGEventPostToPid")
func CGEventPostToPid(_ pid: pid_t, _ event: CGEvent?) -> Void

// MARK: - Find iPhone Mirroring

func findIPhoneMirroringPID() -> pid_t? {
    // Try known bundle IDs
    let bundleIDs = [
        "com.apple.ScreenContinuity",
        "com.apple.iPhoneMirroring",
    ]
    for bid in bundleIDs {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        if let app = apps.first {
            return app.processIdentifier
        }
    }
    // Fallback: search by name
    let workspace = NSWorkspace.shared
    for app in workspace.runningApplications {
        if app.localizedName == "iPhone Mirroring" {
            return app.processIdentifier
        }
    }
    return nil
}

func getWindowBounds(pid: pid_t) -> CGRect? {
    // Use CGWindowListCopyWindowInfo to find the window bounds
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for window in windowList {
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID == pid,
              let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let w = boundsDict["Width"] as? CGFloat,
              let h = boundsDict["Height"] as? CGFloat else {
            continue
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
    return nil
}

// MARK: - Events

func postMouseEvent(pid: pid_t, type: CGEventType, point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
        return
    }
    CGEventPostToPid(pid, event)
}

func tap(pid: pid_t, windowOrigin: CGPoint, x: Double, y: Double) {
    // Convert relative coords to absolute screen coords
    let absPoint = CGPoint(x: windowOrigin.x + x, y: windowOrigin.y + y)

    postMouseEvent(pid: pid, type: .leftMouseDown, point: absPoint)
    usleep(50_000) // 50ms
    postMouseEvent(pid: pid, type: .leftMouseUp, point: absPoint)
    print("OK")
}

func swipe(pid: pid_t, windowOrigin: CGPoint, x1: Double, y1: Double, x2: Double, y2: Double, steps: Int = 20) {
    let startPoint = CGPoint(x: windowOrigin.x + x1, y: windowOrigin.y + y1)
    let endPoint = CGPoint(x: windowOrigin.x + x2, y: windowOrigin.y + y2)

    // Mouse down at start
    postMouseEvent(pid: pid, type: .leftMouseDown, point: startPoint)
    usleep(50_000)

    // Interpolate movement
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        let cx = startPoint.x + CGFloat(t) * (endPoint.x - startPoint.x)
        let cy = startPoint.y + CGFloat(t) * (endPoint.y - startPoint.y)
        let movePoint = CGPoint(x: cx, y: cy)

        if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: movePoint, mouseButton: .left) {
            CGEventPostToPid(pid, event)
        }
        usleep(15_000) // 15ms between steps
    }

    // Mouse up at end
    postMouseEvent(pid: pid, type: .leftMouseUp, point: endPoint)
    print("OK")
}

func typeText(pid: pid_t, text: String) {
    for char in text {
        let str = String(char)
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
        let chars = Array(str.utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        CGEventPostToPid(pid, event)

        guard let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
        eventUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        CGEventPostToPid(pid, eventUp)
        usleep(30_000) // 30ms between keystrokes
    }
    print("OK")
}

func pressKey(pid: pid_t, keyCode: CGKeyCode) {
    if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
        CGEventPostToPid(pid, down)
    }
    usleep(50_000)
    if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
        CGEventPostToPid(pid, up)
    }
    print("OK")
}

// MARK: - Main

let args = CommandLine.arguments

guard args.count >= 2 else {
    fputs("""
    Usage:
      iphone_event tap <x> <y>
      iphone_event swipe <x1> <y1> <x2> <y2> [steps]
      iphone_event type <text>
      iphone_event key <return|delete|escape|tab|space>
      iphone_event bounds
      iphone_event pid
    """, stderr)
    exit(1)
}

guard let pid = findIPhoneMirroringPID() else {
    fputs("ERROR: iPhone Mirroring not running\n", stderr)
    exit(1)
}

let command = args[1]

if command == "pid" {
    print(pid)
    exit(0)
}

if command == "bounds" {
    guard let bounds = getWindowBounds(pid: pid) else {
        fputs("ERROR: Window not found\n", stderr)
        exit(1)
    }
    print("\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))")
    exit(0)
}

// For actions that need window bounds
guard let bounds = getWindowBounds(pid: pid) else {
    // Try to activate the app and retry
    NSRunningApplication(processIdentifier: pid)?.activate()
    usleep(1_500_000) // 1.5s
    guard let bounds2 = getWindowBounds(pid: pid) else {
        fputs("ERROR: Cannot find iPhone Mirroring window. Is it visible?\n", stderr)
        exit(1)
    }
    // Use bounds2 below (Swift scoping won't let us reassign, so duplicate the switch)
    let origin = bounds2.origin
    switch command {
    case "tap":
        guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
            fputs("Usage: iphone_event tap <x> <y>\n", stderr); exit(1)
        }
        tap(pid: pid, windowOrigin: origin, x: x, y: y)
    default:
        fputs("ERROR: Unknown command after retry: \(command)\n", stderr); exit(1)
    }
    exit(0)
}

let origin = bounds.origin

switch command {
case "tap":
    guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
        fputs("Usage: iphone_event tap <x> <y>\n", stderr); exit(1)
    }
    tap(pid: pid, windowOrigin: origin, x: x, y: y)

case "swipe":
    guard args.count >= 6,
          let x1 = Double(args[2]), let y1 = Double(args[3]),
          let x2 = Double(args[4]), let y2 = Double(args[5]) else {
        fputs("Usage: iphone_event swipe <x1> <y1> <x2> <y2> [steps]\n", stderr); exit(1)
    }
    let steps = args.count >= 7 ? Int(args[6]) ?? 20 : 20
    swipe(pid: pid, windowOrigin: origin, x1: x1, y1: y1, x2: x2, y2: y2, steps: steps)

case "type":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event type <text>\n", stderr); exit(1)
    }
    let text = args[2...].joined(separator: " ")
    typeText(pid: pid, text: text)

case "key":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event key <keyname>\n", stderr); exit(1)
    }
    let keyMap: [String: CGKeyCode] = [
        "return": 36, "escape": 53, "delete": 51,
        "tab": 48, "space": 49, "up": 126,
        "down": 125, "left": 123, "right": 124,
    ]
    guard let code = keyMap[args[2].lowercased()] else {
        fputs("Unknown key: \(args[2]). Valid: \(keyMap.keys.sorted().joined(separator: ", "))\n", stderr); exit(1)
    }
    pressKey(pid: pid, keyCode: code)

default:
    fputs("Unknown command: \(command)\n", stderr)
    exit(1)
}

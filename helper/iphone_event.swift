#!/usr/bin/env swift
// iphone_event.swift — Send mouse/keyboard events to iPhone Mirroring
//
// Zero cursor movement. Events are posted via CGEvent with private source
// at the correct absolute coordinates. iPhone Mirroring is briefly activated
// to receive events (~300ms), then the previous app is restored.
// The physical mouse cursor NEVER moves.
//
// Usage:
//   iphone_event tap <x> <y>
//   iphone_event swipe <x1> <y1> <x2> <y2> [steps]
//   iphone_event type <text>
//   iphone_event key <keycode>
//   iphone_event bounds
//   iphone_event windowid
//   iphone_event pid

import Cocoa

// MARK: - Logging

func log(_ msg: String) {
    fputs("[iphone_event] \(msg)\n", stderr)
}

// MARK: - Find iPhone Mirroring

func findIPhoneMirroringApp() -> NSRunningApplication? {
    let bundleIDs = [
        "com.apple.ScreenContinuity",
        "com.apple.iPhoneMirroring",
    ]
    for bid in bundleIDs {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        if let app = apps.first {
            return app
        }
    }
    for app in NSWorkspace.shared.runningApplications {
        if app.localizedName == "iPhone Mirroring" {
            return app
        }
    }
    return nil
}

struct WindowInfo {
    let id: CGWindowID
    let bounds: CGRect
}

func getWindowInfo(pid: pid_t) -> WindowInfo? {
    let windowList = CGWindowListCopyWindowInfo(
        [.optionAll, .excludeDesktopElements], kCGNullWindowID
    ) as? [[String: Any]] ?? []

    // Collect all windows for this PID that look like phone screens
    var candidates: [(WindowInfo, CGFloat)] = []
    for window in windowList {
        guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
              ownerPID == pid,
              let windowID = window[kCGWindowNumber as String] as? CGWindowID,
              let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let w = boundsDict["Width"] as? CGFloat,
              let h = boundsDict["Height"] as? CGFloat,
              w > 100 && h > 100 else {
            continue
        }
        let info = WindowInfo(
            id: windowID,
            bounds: CGRect(x: x, y: y, width: w, height: h)
        )
        let aspectRatio = h / w
        candidates.append((info, aspectRatio))
        log("window candidate: id=\(windowID) bounds=(\(Int(x)),\(Int(y)),\(Int(w)),\(Int(h))) aspect=\(String(format: "%.2f", aspectRatio))")
    }

    // Prefer portrait windows (iPhone aspect ratio ~2.0+)
    // Sort by aspect ratio descending — tallest/narrowest first
    candidates.sort { $0.1 > $1.1 }
    if let best = candidates.first, best.1 > 1.3 {
        log("selected window: id=\(best.0.id) aspect=\(String(format: "%.2f", best.1))")
        return best.0
    }
    // Fallback: return any window
    return candidates.first?.0
}

// MARK: - Focus management

/// Save the currently focused app, activate iPhone Mirroring, return the saved app
func activateIPhoneMirroring(_ app: NSRunningApplication) -> NSRunningApplication? {
    let previousApp = NSWorkspace.shared.frontmostApplication
    app.activate()
    // Wait for it to become frontmost
    for _ in 0..<30 { // up to 300ms
        usleep(10_000)
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            break
        }
    }
    usleep(50_000) // extra settle time
    return previousApp
}

/// Restore the previously focused app
func restorePreviousApp(_ app: NSRunningApplication?) {
    guard let app = app else { return }
    usleep(50_000)
    app.activate()
}

// MARK: - Event source & posting

/// Private event source — doesn't affect physical mouse/keyboard state
let eventSource: CGEventSource? = CGEventSource(stateID: .privateState)

func postMouse(type: CGEventType, at point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type,
                              mouseCursorPosition: point, mouseButton: .left) else {
        log("WARN: Failed to create mouse event \(type) at \(point)")
        return
    }
    event.post(tap: .cghidEventTap)
}

func postDrag(to point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDragged,
                              mouseCursorPosition: point, mouseButton: .left) else { return }
    event.post(tap: .cghidEventTap)
}

func postMouseMove(to point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved,
                              mouseCursorPosition: point, mouseButton: .left) else { return }
    event.post(tap: .cghidEventTap)
}

// MARK: - Actions (zero cursor movement)

func tap(at absPoint: CGPoint, app: NSRunningApplication) {
    log("tap: target=\(absPoint)")

    let previousApp = activateIPhoneMirroring(app)

    // Post mouseMoved so window server routes to correct window
    postMouseMove(to: absPoint)
    usleep(30_000)

    postMouse(type: .leftMouseDown, at: absPoint)
    usleep(80_000) // hold
    postMouse(type: .leftMouseUp, at: absPoint)
    usleep(50_000)

    restorePreviousApp(previousApp)
    log("tap: done, focus restored")
    print("OK")
}

/// Swipe using scroll wheel events (both horizontal and vertical).
/// iPhone Mirroring maps scroll wheel → touch swipe on iPhone.
/// Shift+scroll = horizontal scroll.
func swipe(at point: CGPoint, deltaX: Int32, deltaY: Int32, app: NSRunningApplication) {
    log("swipe: at=\(point), deltaX=\(deltaX), deltaY=\(deltaY)")

    let previousApp = activateIPhoneMirroring(app)

    postMouseMove(to: point)
    usleep(50_000)

    // Post scroll events in small increments for smooth scrolling
    let scrollSteps: Int32 = 8
    let perStepX = deltaX / scrollSteps
    let perStepY = deltaY / scrollSteps

    for _ in 0..<scrollSteps {
        if let event = CGEvent(scrollWheelEvent2Source: eventSource,
                                units: .pixel,
                                wheelCount: 2,
                                wheel1: perStepY, wheel2: perStepX, wheel3: 0) {
            event.location = point
            event.post(tap: .cghidEventTap)
        }
        usleep(20_000)
    }
    usleep(100_000)

    restorePreviousApp(previousApp)
    log("swipe: done, focus restored")
    print("OK")
}

/// Scroll using scroll wheel events (alternative to drag-based swipe)
func scroll(at point: CGPoint, deltaY: Int32, app: NSRunningApplication) {
    log("scroll: at=\(point), deltaY=\(deltaY)")

    let previousApp = activateIPhoneMirroring(app)

    // Post a mouseMoved to position the "virtual cursor" over the window
    postMouseMove(to: point)
    usleep(50_000)

    // Post scroll wheel events
    let scrollSteps: Int32 = 5
    let perStep = deltaY / scrollSteps
    for _ in 0..<scrollSteps {
        if let event = CGEvent(scrollWheelEvent2Source: eventSource,
                                units: .pixel,
                                wheelCount: 1,
                                wheel1: perStep, wheel2: 0, wheel3: 0) {
            event.location = point
            event.post(tap: .cghidEventTap)
        }
        usleep(30_000)
    }
    usleep(100_000)

    restorePreviousApp(previousApp)
    log("scroll: done, focus restored")
    print("OK")
}

// MARK: - Character to keycode mapping

let charToKeyCode: [Character: (CGKeyCode, Bool)] = [
    // (keycode, needsShift)
    "a": (0, false), "s": (1, false), "d": (2, false), "f": (3, false),
    "h": (4, false), "g": (5, false), "z": (6, false), "x": (7, false),
    "c": (8, false), "v": (9, false), "b": (11, false), "q": (12, false),
    "w": (13, false), "e": (14, false), "r": (15, false), "y": (16, false),
    "t": (17, false), "1": (18, false), "2": (19, false), "3": (20, false),
    "4": (21, false), "6": (22, false), "5": (23, false), "=": (24, false),
    "9": (25, false), "7": (26, false), "-": (27, false), "8": (28, false),
    "0": (29, false), "]": (30, false), "o": (31, false), "u": (32, false),
    "[": (33, false), "i": (34, false), "p": (35, false), "l": (37, false),
    "j": (38, false), "'": (39, false), "k": (40, false), ";": (41, false),
    "\\": (42, false), ",": (43, false), "/": (44, false), "n": (45, false),
    "m": (46, false), ".": (47, false), "`": (50, false), " ": (49, false),
    // Uppercase
    "A": (0, true), "S": (1, true), "D": (2, true), "F": (3, true),
    "H": (4, true), "G": (5, true), "Z": (6, true), "X": (7, true),
    "C": (8, true), "V": (9, true), "B": (11, true), "Q": (12, true),
    "W": (13, true), "E": (14, true), "R": (15, true), "Y": (16, true),
    "T": (17, true), "O": (31, true), "U": (32, true), "I": (34, true),
    "P": (35, true), "L": (37, true), "J": (38, true), "K": (40, true),
    "N": (45, true), "M": (46, true),
    // Shift symbols
    "!": (18, true), "@": (19, true), "#": (20, true), "$": (21, true),
    "^": (22, true), "%": (23, true), "+": (24, true), "(": (25, true),
    "&": (26, true), "_": (27, true), "*": (28, true), ")": (29, true),
    "}": (30, true), "{": (33, true), "\"": (39, true), ":": (41, true),
    "|": (42, true), "<": (43, true), "?": (44, true), ">": (47, true),
    "~": (50, true),
]

func typeChar(_ char: Character) {
    if let (keyCode, needsShift) = charToKeyCode[char] {
        let flags: CGEventFlags = needsShift ? .maskShift : []
        if let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        usleep(30_000)
        if let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
        usleep(50_000)
    } else {
        // Fallback for non-ASCII: use unicode string approach
        let str = String(char)
        let chars = Array(str.utf16)
        if let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            down.post(tap: .cghidEventTap)
        }
        usleep(30_000)
        if let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) {
            up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            up.post(tap: .cghidEventTap)
        }
        usleep(50_000)
    }
}

func typeText(_ text: String, app: NSRunningApplication, restoreFocus: Bool = true) {
    let previousApp = activateIPhoneMirroring(app)

    for char in text {
        typeChar(char)
    }

    if restoreFocus {
        restorePreviousApp(previousApp)
    }
    print("OK")
}

/// Helper to post a keyboard shortcut
func postKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags = []) {
    if let d = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) {
        d.flags = flags; d.post(tap: .cghidEventTap)
    }
    usleep(30_000)
    if let u = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) {
        u.flags = flags; u.post(tap: .cghidEventTap)
    }
    usleep(50_000)
}

/// Open an app by name using Spotlight via AppleScript (most reliable for keyboard sequences).
/// Flow: activate → Home → Spotlight → type name → Return → restore focus.
func openApp(_ name: String) {
    log("openapp: opening '\(name)' via AppleScript")

    // Escape special chars for AppleScript string
    let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
                      .replacingOccurrences(of: "\"", with: "\\\"")

    let script = """
    tell application "iPhone Mirroring" to activate
    delay 0.3
    tell application "System Events"
        keystroke "1" using command down
        delay 0.8
        keystroke "3" using command down
        delay 1.2
        keystroke "\(escaped)"
        delay 0.8
        key code 36
    end tell
    delay 0.8
    """

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    try? proc.run()
    proc.waitUntilExit()

    // Restore previous app
    // (AppleScript leaves iPhone Mirroring in front; we restore from here)
    if let prev = NSWorkspace.shared.runningApplications.first(where: {
        $0.processIdentifier != findIPhoneMirroringApp()?.processIdentifier &&
        $0.activationPolicy == .regular &&
        $0.isActive == false &&
        $0.localizedName != "Finder"
    }) {
        prev.activate()
    }

    log("openapp: done")
    print("OK")
}

/// Type text via AppleScript System Events (more reliable than CGEvent for iPhone Mirroring)
func typeTextViaAppleScript(_ text: String, app: NSRunningApplication) {
    let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                      .replacingOccurrences(of: "\"", with: "\\\"")

    let script = """
    tell application "iPhone Mirroring" to activate
    delay 0.3
    tell application "System Events"
        keystroke "\(escaped)"
    end tell
    """

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    try? proc.run()
    proc.waitUntilExit()
    usleep(200_000)

    restorePreviousApp(NSWorkspace.shared.frontmostApplication)
    print("OK")
}

func pressKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], app: NSRunningApplication) {
    let previousApp = activateIPhoneMirroring(app)

    if let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) {
        down.flags = flags
        down.post(tap: .cghidEventTap)
    }
    usleep(50_000)
    if let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) {
        up.flags = flags
        up.post(tap: .cghidEventTap)
    }

    restorePreviousApp(previousApp)
    print("OK")
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: iphone_event <tap|swipe|type|key|bounds|windowid|pid> [args]\n", stderr)
    exit(1)
}

guard let mirroringApp = findIPhoneMirroringApp() else {
    fputs("ERROR: iPhone Mirroring not running\n", stderr)
    exit(1)
}

let pid = mirroringApp.processIdentifier
let cmd = args[1]

switch cmd {
case "pid":
    print(pid)

case "windowid":
    guard let info = getWindowInfo(pid: pid) else {
        fputs("ERROR: Window not found\n", stderr); exit(1)
    }
    print(info.id)

case "bounds":
    guard let info = getWindowInfo(pid: pid) else {
        fputs("ERROR: Window not found\n", stderr); exit(1)
    }
    let b = info.bounds
    print("\(Int(b.origin.x)),\(Int(b.origin.y)),\(Int(b.width)),\(Int(b.height))")

case "tap":
    guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]),
          let info = getWindowInfo(pid: pid) else {
        fputs("Usage: iphone_event tap <x> <y>\n", stderr); exit(1)
    }
    let b = info.bounds
    let absPoint = CGPoint(x: b.origin.x + x, y: b.origin.y + y)
    log("tap cmd: relative=(\(x),\(y)) bounds=\(b) absolute=\(absPoint)")
    tap(at: absPoint, app: mirroringApp)

case "swipe":
    guard args.count >= 6,
          let x1 = Double(args[2]), let y1 = Double(args[3]),
          let x2 = Double(args[4]), let y2 = Double(args[5]),
          let info = getWindowInfo(pid: pid) else {
        fputs("Usage: iphone_event swipe <x1> <y1> <x2> <y2>\n", stderr); exit(1)
    }
    let b = info.bounds
    // Calculate delta from start to end and use scroll wheel
    let midX = (x1 + x2) / 2.0
    let midY = (y1 + y2) / 2.0
    let deltaX = Int32(x2 - x1) * 3 // amplify for better gesture recognition
    let deltaY = Int32(y2 - y1) * 3
    log("swipe cmd: from=(\(x1),\(y1)) to=(\(x2),\(y2)) deltaX=\(deltaX) deltaY=\(deltaY)")
    swipe(
        at: CGPoint(x: b.origin.x + midX, y: b.origin.y + midY),
        deltaX: deltaX, deltaY: deltaY,
        app: mirroringApp
    )

case "home":
    // Cmd+1 = Home screen in iPhone Mirroring
    log("home: sending Cmd+1")
    pressKey(18, flags: .maskCommand, app: mirroringApp) // keycode 18 = "1"

case "appswitcher":
    // Cmd+2 = App Switcher in iPhone Mirroring
    log("appswitcher: sending Cmd+2")
    pressKey(19, flags: .maskCommand, app: mirroringApp) // keycode 19 = "2"

case "spotlight":
    // Cmd+3 = Spotlight in iPhone Mirroring
    log("spotlight: sending Cmd+3")
    pressKey(20, flags: .maskCommand, app: mirroringApp) // keycode 20 = "3"

case "openapp":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event openapp <name>\n", stderr); exit(1)
    }
    openApp(args[2...].joined(separator: " "))

case "scroll":
    guard args.count >= 4,
          let x = Double(args[2]), let y = Double(args[3]),
          let info = getWindowInfo(pid: pid) else {
        fputs("Usage: iphone_event scroll <x> <y> [deltaY]\n", stderr); exit(1)
    }
    let b = info.bounds
    let deltaY: Int32 = args.count >= 5 ? Int32(args[4]) ?? -200 : -200
    log("scroll cmd: at=(\(x),\(y)) deltaY=\(deltaY)")
    scroll(
        at: CGPoint(x: b.origin.x + x, y: b.origin.y + y),
        deltaY: deltaY,
        app: mirroringApp
    )

case "type":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event type <text>\n", stderr); exit(1)
    }
    typeText(args[2...].joined(separator: " "), app: mirroringApp)

case "key":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event key <name>\n", stderr); exit(1)
    }
    let keyMap: [String: (CGKeyCode, CGEventFlags)] = [
        "return": (36, []), "escape": (53, []), "delete": (51, []),
        "tab": (48, []), "space": (49, []), "up": (126, []),
        "down": (125, []), "left": (123, []), "right": (124, []),
    ]
    guard let (code, flags) = keyMap[args[2].lowercased()] else {
        fputs("Unknown key. Valid: \(keyMap.keys.sorted().joined(separator: ", "))\n", stderr); exit(1)
    }
    pressKey(code, flags: flags, app: mirroringApp)

default:
    fputs("Unknown: \(cmd)\n", stderr); exit(1)
}

#!/usr/bin/env swift
// iphone_event.swift — Send mouse/keyboard events to iPhone Mirroring
//
// ZERO visible cursor movement. For mouse events (tap, scroll, swipe):
//   1. Hide the cursor (CGDisplayHideCursor)
//   2. Save current cursor position
//   3. Warp to target coordinates
//   4. Post click/scroll via .cghidEventTap (required by iPhone Mirroring)
//   5. Warp cursor back to saved position
//   6. Show cursor again
// The user sees NO cursor movement — it's hidden during the entire operation.
//
// For keyboard events: posted directly, no cursor involvement.
// iPhone Mirroring is briefly activated to receive events, then restored.
//
// Usage:
//   iphone_event tap <x> <y>
//   iphone_event swipe <x1> <y1> <x2> <y2>
//   iphone_event scroll <x> <y> [deltaY]
//   iphone_event type <text>
//   iphone_event key <keycode>
//   iphone_event home | appswitcher | spotlight
//   iphone_event openapp <name>
//   iphone_event bounds | windowid | pid

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
    candidates.sort { $0.1 > $1.1 }
    if let best = candidates.first, best.1 > 1.3 {
        log("selected window: id=\(best.0.id) aspect=\(String(format: "%.2f", best.1))")
        return best.0
    }
    return candidates.first?.0
}

// MARK: - Focus management

func activateIPhoneMirroring(_ app: NSRunningApplication) -> NSRunningApplication? {
    let previousApp = NSWorkspace.shared.frontmostApplication
    app.activate()
    for _ in 0..<30 {
        usleep(10_000)
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            break
        }
    }
    usleep(50_000)
    return previousApp
}

func restorePreviousApp(_ app: NSRunningApplication?) {
    guard let app = app else { return }
    usleep(50_000)
    app.activate()
}

// MARK: - Stealth cursor: hide → warp → act → warp back → show

/// Get current cursor position (screen coordinates, origin top-left)
func getCursorPosition() -> CGPoint {
    return CGEvent(source: nil)?.location ?? .zero
}

/// Hide cursor, warp to target position. Returns saved cursor position.
func stealthWarpTo(_ target: CGPoint) -> CGPoint {
    let saved = getCursorPosition()
    CGDisplayHideCursor(CGMainDisplayID())
    CGWarpMouseCursorPosition(target)
    // After warp, re-associate so next mouse move doesn't jump
    CGAssociateMouseAndMouseCursorPosition(1)
    usleep(10_000) // tiny settle
    return saved
}

/// Warp cursor back to saved position and show it again.
func stealthRestore(_ saved: CGPoint) {
    CGWarpMouseCursorPosition(saved)
    CGAssociateMouseAndMouseCursorPosition(1)
    CGDisplayShowCursor(CGMainDisplayID())
}

// MARK: - Event source & posting

let eventSource: CGEventSource? = CGEventSource(stateID: .privateState)

func postMouse(type: CGEventType, at point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type,
                              mouseCursorPosition: point, mouseButton: .left) else {
        log("WARN: Failed to create mouse event \(type) at \(point)")
        return
    }
    event.post(tap: .cghidEventTap)
}

func postMouseMove(to point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved,
                              mouseCursorPosition: point, mouseButton: .left) else { return }
    event.post(tap: .cghidEventTap)
}

// MARK: - Actions (stealth cursor — user sees NO movement)

func tap(at absPoint: CGPoint, app: NSRunningApplication) {
    log("tap: target=\(absPoint)")

    // 1. Hide cursor and warp to target
    let saved = stealthWarpTo(absPoint)

    // 2. Activate iPhone Mirroring
    let previousApp = activateIPhoneMirroring(app)

    // 3. Post mouse move + click (cursor is hidden, user sees nothing)
    postMouseMove(to: absPoint)
    usleep(30_000)
    postMouse(type: .leftMouseDown, at: absPoint)
    usleep(80_000)
    postMouse(type: .leftMouseUp, at: absPoint)
    usleep(50_000)

    // 4. Restore cursor to original position (still hidden)
    stealthRestore(saved)

    // 5. Restore previous app
    restorePreviousApp(previousApp)
    log("tap: done")
    print("OK")
}

func swipe(at point: CGPoint, deltaX: Int32, deltaY: Int32, app: NSRunningApplication) {
    log("swipe: at=\(point), deltaX=\(deltaX), deltaY=\(deltaY)")

    let saved = stealthWarpTo(point)
    let previousApp = activateIPhoneMirroring(app)

    postMouseMove(to: point)
    usleep(50_000)

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

    stealthRestore(saved)
    restorePreviousApp(previousApp)
    log("swipe: done")
    print("OK")
}

func scroll(at point: CGPoint, deltaY: Int32, app: NSRunningApplication) {
    log("scroll: at=\(point), deltaY=\(deltaY)")

    let saved = stealthWarpTo(point)
    let previousApp = activateIPhoneMirroring(app)

    postMouseMove(to: point)
    usleep(50_000)

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

    stealthRestore(saved)
    restorePreviousApp(previousApp)
    log("scroll: done")
    print("OK")
}

// MARK: - Keyboard (no cursor involvement at all)

let charToKeyCode: [Character: (CGKeyCode, Bool)] = [
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
    "A": (0, true), "S": (1, true), "D": (2, true), "F": (3, true),
    "H": (4, true), "G": (5, true), "Z": (6, true), "X": (7, true),
    "C": (8, true), "V": (9, true), "B": (11, true), "Q": (12, true),
    "W": (13, true), "E": (14, true), "R": (15, true), "Y": (16, true),
    "T": (17, true), "O": (31, true), "U": (32, true), "I": (34, true),
    "P": (35, true), "L": (37, true), "J": (38, true), "K": (40, true),
    "N": (45, true), "M": (46, true),
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

/// Check if text contains non-ASCII characters (Chinese, emoji, etc.)
func hasNonASCII(_ text: String) -> Bool {
    return text.unicodeScalars.contains { $0.value > 127 }
}

/// Paste text via clipboard + Cmd+V (works for ANY language including Chinese)
func pasteText(_ text: String, app: NSRunningApplication) {
    log("paste: setting clipboard and pasting")

    // Set macOS clipboard
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    let previousApp = activateIPhoneMirroring(app)
    usleep(100_000)

    // Cmd+V to paste
    if let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 9, keyDown: true) {
        down.flags = .maskCommand
        down.post(tap: .cghidEventTap)
    }
    usleep(50_000)
    if let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 9, keyDown: false) {
        up.flags = .maskCommand
        up.post(tap: .cghidEventTap)
    }
    usleep(200_000)

    restorePreviousApp(previousApp)
    print("OK")
}

func typeText(_ text: String, app: NSRunningApplication, restoreFocus: Bool = true) {
    // Auto-detect: use paste for non-ASCII text (Chinese, emoji, etc.)
    if hasNonASCII(text) {
        pasteText(text, app: app)
        return
    }

    let previousApp = activateIPhoneMirroring(app)
    for char in text {
        typeChar(char)
    }
    if restoreFocus {
        restorePreviousApp(previousApp)
    }
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

/// Open app via AppleScript (most reliable for multi-step keyboard sequences)
/// For non-ASCII names (Chinese, etc.), uses clipboard paste instead of keystroke
func openApp(_ name: String) {
    log("openapp: opening '\(name)' via AppleScript")

    let previousApp = NSWorkspace.shared.frontmostApplication

    var typeMethod: String
    if hasNonASCII(name) {
        // Set clipboard first, then paste with Cmd+V
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(name, forType: .string)
        typeMethod = "keystroke \"v\" using command down"
    } else {
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        typeMethod = "keystroke \"\(escaped)\""
    }

    let script = """
    tell application "iPhone Mirroring" to activate
    delay 0.3
    tell application "System Events"
        keystroke "1" using command down
        delay 0.8
        keystroke "3" using command down
        delay 1.2
        \(typeMethod)
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

    restorePreviousApp(previousApp)
    log("openapp: done")
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
    let midX = (x1 + x2) / 2.0
    let midY = (y1 + y2) / 2.0
    let deltaX = Int32(x2 - x1) * 3
    let deltaY = Int32(y2 - y1) * 3
    log("swipe cmd: from=(\(x1),\(y1)) to=(\(x2),\(y2)) deltaX=\(deltaX) deltaY=\(deltaY)")
    swipe(
        at: CGPoint(x: b.origin.x + midX, y: b.origin.y + midY),
        deltaX: deltaX, deltaY: deltaY,
        app: mirroringApp
    )

case "home":
    log("home: sending Cmd+1")
    pressKey(18, flags: .maskCommand, app: mirroringApp)

case "appswitcher":
    log("appswitcher: sending Cmd+2")
    pressKey(19, flags: .maskCommand, app: mirroringApp)

case "spotlight":
    log("spotlight: sending Cmd+3")
    pressKey(20, flags: .maskCommand, app: mirroringApp)

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

case "paste":
    guard args.count >= 3 else {
        fputs("Usage: iphone_event paste <text>\n", stderr); exit(1)
    }
    pasteText(args[2...].joined(separator: " "), app: mirroringApp)

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

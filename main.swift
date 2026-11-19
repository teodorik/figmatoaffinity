import AppKit
@preconcurrency import ApplicationServices

private let figmaBundleID = "com.figma.Desktop"
private let affinityBundleIDs: Set = ["com.canva.affinity", "com.seriflabs.affinitydesigner2",
                                      "com.seriflabs.affinitydesigner"]
private let chromiumSource = NSPasteboard.PasteboardType("org.chromium.source-url")

private extension AXUIElement {
    func elements(_ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success
        else { return [] }
        return value as? [AXUIElement] ?? []
    }

    var title: String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    func menuItem(titled name: String, depth: Int) -> AXUIElement? {
        if title?.localizedCaseInsensitiveCompare(name) == .orderedSame { return self }
        guard depth > 0 else { return nil }
        for child in elements(kAXChildrenAttribute) {
            if let match = child.menuItem(titled: name, depth: depth - 1) {
                return match
            }
        }
        return nil
    }
}

private func copyAsSVG(in figma: NSRunningApplication) -> Bool {
    let app = AXUIElementCreateApplication(figma.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 0.25)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &value) == .success,
          let value,
          CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return false }

    let menuBar = value as! AXUIElement
    guard let edit = menuBar.elements(kAXChildrenAttribute).first(where: { $0.title == "Edit" }),
          let command = edit.menuItem(titled: "Copy as SVG", depth: 4),
          figma.isActive
    else { return false }

    var enabled: CFTypeRef?
    if AXUIElementCopyAttributeValue(command, kAXEnabledAttribute as CFString, &enabled) == .success,
       (enabled as? Bool) == false { return false }

    return AXUIElementPerformAction(command, kAXPressAction as CFString) == .success
}

private final class FtoA: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private struct Request {
        let original: ClipboardSnapshot
        let change: Int
        let source: Data?
        let deadline: TimeInterval
    }

    private let board = NSPasteboard.general
    private var observedChange = NSPasteboard.general.changeCount
    private var request: Request?
    private var transfer: Transfer?
    private var statusItem: NSStatusItem?
    private let status = NSMenuItem(title: "Waiting for Figma Copy", action: nil, keyEquivalent: "")
    private let enable = NSMenuItem(
        title: "Enable Automatic Copy…", action: #selector(enableAutomaticCopy), keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "FtoA")
        item.button?.toolTip = "FtoA"
        statusItem = item

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(enable)
        enable.target = self
        menu.addItem(withTitle: "Quit FtoA", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        menuWillOpen(menu)

        let timer = Timer(
            timeInterval: 0.05, target: self, selector: #selector(checkClipboard(_:)),
            userInfo: nil, repeats: true
        )
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(checkClipboard(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
    }

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        enable.isHidden = trusted
        if !trusted {
            status.title = "Automatic Copy Needs Accessibility"
        } else if status.title == "Automatic Copy Needs Accessibility" {
            status.title = "Waiting for Figma Copy"
        }
    }

    @objc private func enableAutomaticCopy() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if var transfer {
            _ = transfer.displaySVG(false, on: board)
        }
    }

    @objc private func checkClipboard(_ sender: Any) {
        let change = board.changeCount
        guard change != observedChange || request != nil || transfer != nil else { return }

        let front = NSWorkspace.shared.frontmostApplication
        let bundle = front?.bundleIdentifier ?? ""
        let inAffinity = affinityBundleIDs.contains(bundle)

        if var ready = transfer {
            if ready.displaySVG(inAffinity, on: board) {
                transfer = ready
                observedChange = ready.change
                return
            }
            transfer = nil
            status.title = "Waiting for Figma Copy"
        }

        if let pending = request {
            if change == pending.change {
                if ProcessInfo.processInfo.systemUptime >= pending.deadline {
                    request = nil
                    status.title = "Figma Did Not Return SVG"
                }
                return
            }

            request = nil
            if let item = board.pasteboardItems?.first,
               pending.source == nil || item.data(forType: chromiumSource) == pending.source,
               let svg = svgText(from: item) {
                var ready = Transfer(original: pending.original, svg: svg, change: change, showingSVG: true)
                if ready.displaySVG(inAffinity, on: board) {
                    transfer = ready
                    observedChange = ready.change
                    status.title = "Vector Ready for Affinity"
                    return
                }
            }
            status.title = "Waiting for Figma Copy"
        }

        guard change != observedChange else { return }
        observedChange = change
        guard bundle == figmaBundleID, let figma = front, AXIsProcessTrusted(),
              let items = board.pasteboardItems, let first = items.first, isFigmaLayerCopy(first),
              let original = ClipboardSnapshot(items)
        else { return }
        let source = first.data(forType: chromiumSource)
        guard board.changeCount == change, copyAsSVG(in: figma) else {
            status.title = "Copy As SVG Is Unavailable"
            return
        }
        request = Request(
            original: original, change: change, source: source,
            deadline: ProcessInfo.processInfo.systemUptime + 3
        )
        status.title = "Getting SVG from Figma…"
    }
}

let application = NSApplication.shared
private let bridge = FtoA()
application.delegate = bridge
application.setActivationPolicy(.accessory)
application.run()

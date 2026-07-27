import AppKit
import ApplicationServices
import ServiceManagement

private let appName = "Window Memory"
private let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(appName)
private let profilesURL = supportDirectory.appendingPathComponent("profiles.json")

struct WindowSnapshot: Codable {
    let bundleIdentifier: String
    let applicationName: String
    let title: String
    let windowNumber: Int?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct LayoutProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    let displaySignature: String
    let savedAt: Date
    var windows: [WindowSnapshot]
}

struct ProfileStore: Codable {
    var profiles: [LayoutProfile] = []
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var store = ProfileStore()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        loadStore()
        setupStatusItem()
        refreshMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: appName)
            button.toolTip = appName
        }
        menu = NSMenu()
        statusItem.menu = menu
    }

    private func refreshMenu() {
        menu.removeAllItems()
        let trusted = AXIsProcessTrusted()
        let access = NSMenuItem(title: trusted ? "Accessibility Access Granted" : "Grant Accessibility Access…", action: trusted ? nil : #selector(openAccessibilitySettings), keyEquivalent: "")
        access.target = self
        menu.addItem(access)
        menu.addItem(.separator())

        let save = NSMenuItem(title: "Save Current Layout…", action: #selector(saveCurrentLayout), keyEquivalent: "s")
        save.keyEquivalentModifierMask = [.command, .option]
        save.target = self
        menu.addItem(save)

        let restoreMenu = NSMenu(title: "Restore Layout")
        let restore = NSMenuItem(title: "Restore Layout", action: nil, keyEquivalent: "")
        restore.submenu = restoreMenu
        menu.addItem(restore)
        let current = currentProfiles
        if current.isEmpty {
            let empty = NSMenuItem(title: "No layouts for this display setup", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            restoreMenu.addItem(empty)
        } else {
            for (index, profile) in current.enumerated() {
                let item = NSMenuItem(title: profile.name, action: #selector(restoreProfile(_:)), keyEquivalent: index < 9 ? String(index + 1) : "")
                item.target = self
                item.representedObject = profile.id
                item.toolTip = "Saved \(profile.windows.count) windows"
                if index < 9 { item.keyEquivalentModifierMask = [.command] }
                restoreMenu.addItem(item)
            }
        }

        let manageMenu = NSMenu(title: "Manage Layouts")
        let manage = NSMenuItem(title: "Manage Layouts", action: nil, keyEquivalent: "")
        manage.submenu = manageMenu
        menu.addItem(manage)
        if store.profiles.isEmpty {
            let empty = NSMenuItem(title: "No saved layouts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            manageMenu.addItem(empty)
        } else {
            for profile in store.profiles.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                let item = NSMenuItem(title: "Delete \(profile.name)", action: #selector(deleteProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = profile.id
                manageMenu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let launchTitle = "Launch at Login" + (launchAtLoginEnabled ? " ✓" : "")
        let launch = NSMenuItem(title: launchTitle, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        let quit = NSMenuItem(title: "Quit Window Memory", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private var currentProfiles: [LayoutProfile] {
        store.profiles.filter { $0.displaySignature == displaySignature() }.sorted { $0.savedAt > $1.savedAt }
    }

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    @objc private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        refreshMenu()
    }

    @objc private func saveCurrentLayout() {
        guard AXIsProcessTrusted() else { openAccessibilitySettings(); return }
        let alert = NSAlert()
        alert.messageText = "Save Current Layout"
        alert.informativeText = "Give this window arrangement a name."
        let field = NSTextField(string: "Layout \(store.profiles.count + 1)")
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let windows = readWindows()
        guard !windows.isEmpty else {
            showNotice("No windows found", "Make sure the apps you want to save are running and Window Memory has Accessibility access.")
            return
        }
        store.profiles.append(LayoutProfile(id: UUID(), name: name, displaySignature: displaySignature(), savedAt: Date(), windows: windows))
        persistStore()
        refreshMenu()
    }

    @objc private func restoreProfile(_ sender: NSMenuItem) {
        guard AXIsProcessTrusted(), let id = sender.representedObject as? UUID, let profile = store.profiles.first(where: { $0.id == id }) else { openAccessibilitySettings(); return }
        let result = restore(profile)
        if result.failed > 0 { showNotice("Layout restored with warnings", "Restored \(result.restored) window(s). \(result.failed) could not be matched.") }
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        guard let profile = store.profiles.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(profile.name)?"
        alert.informativeText = "This only removes the saved layout. Open windows are not changed."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.profiles.removeAll { $0.id == id }
            persistStore()
            refreshMenu()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                if launchAtLoginEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            } else { UserDefaults.standard.set(!launchAtLoginEnabled, forKey: "launchAtLogin") }
            refreshMenu()
        } catch { showNotice("Launch at Login unavailable", error.localizedDescription) }
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private func readWindows() -> [WindowSnapshot] {
        var result: [WindowSnapshot] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { continue }
            for window in windows {
                guard let frame = windowFrame(window), frame.width > 1, frame.height > 1 else { continue }
                let title = attribute(window, kAXTitleAttribute) as? String ?? ""
                let number = (attribute(window, "AXWindowNumber") as? NSNumber)?.intValue
                result.append(WindowSnapshot(bundleIdentifier: app.bundleIdentifier ?? "", applicationName: app.localizedName ?? "Application", title: title, windowNumber: number, x: frame.minX, y: frame.minY, width: frame.width, height: frame.height))
            }
        }
        return result
    }

    private func restore(_ profile: LayoutProfile) -> (restored: Int, failed: Int) {
        var restored = 0
        var failed = 0
        for snapshot in profile.windows {
            let candidates = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == snapshot.bundleIdentifier }
            var matched = false
            for app in candidates {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                var value: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success, let windows = value as? [AXUIElement] else { continue }
                let matching = windows.first { window in
                    let title = attribute(window, kAXTitleAttribute) as? String ?? ""
                    let number = (attribute(window, "AXWindowNumber") as? NSNumber)?.intValue
                    if let savedNumber = snapshot.windowNumber, let number { return savedNumber == number }
                    return title == snapshot.title
                }
                if let window = matching {
                    setWindowFrame(window, CGRect(x: snapshot.x, y: snapshot.y, width: snapshot.width, height: snapshot.height))
                    restored += 1; matched = true; break
                }
            }
            if !matched { failed += 1 }
        }
        return (restored, failed)
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, kAXPositionAttribute), let size = attribute(window, kAXSizeAttribute) else { return nil }
        guard CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let positionValue = position as! AXValue
        let sizeValue = size as! AXValue
        var point = CGPoint.zero; var dimension = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &dimension) else { return nil }
        return CGRect(origin: point, size: dimension)
    }

    private func setWindowFrame(_ window: AXUIElement, _ frame: CGRect) {
        var point = frame.origin; var size = frame.size
        if let p = AXValueCreate(.cgPoint, &point) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p) }
        if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func displaySignature() -> String {
        NSScreen.screens.map { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            let frame = screen.frame
            return "\(id):\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
        }.sorted().joined(separator: "|")
    }

    private func loadStore() {
        do { store = try decoder.decode(ProfileStore.self, from: Data(contentsOf: profilesURL)) } catch { store = ProfileStore() }
    }

    private func persistStore() {
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(store)
            let temporary = profilesURL.appendingPathExtension("tmp")
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: profilesURL.path) { try FileManager.default.removeItem(at: profilesURL) }
            try FileManager.default.moveItem(at: temporary, to: profilesURL)
        } catch { showNotice("Could not save layouts", error.localizedDescription) }
    }

    private func showNotice(_ title: String, _ message: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.addButton(withTitle: "OK"); alert.runModal()
    }
}

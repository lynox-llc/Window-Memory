import AppKit
import ApplicationServices
import ServiceManagement

private let appName = "Window Memory"
private let releasesAPI = "https://api.github.com/repos/lynox-llc/Window-Memory/releases/latest"
private let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(appName)
private let profilesURL = supportDirectory.appendingPathComponent("profiles.json")

/// Minimal localisation: Japanese when the first preferred language is Japanese, English otherwise.
private func L(_ en: String, _ ja: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("ja") == true ? ja : en
}

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
    private var pendingAutoRestore: DispatchWorkItem?
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
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

    // MARK: - Menu

    private func refreshMenu() {
        menu.removeAllItems()
        let trusted = AXIsProcessTrusted()
        let access = NSMenuItem(
            title: trusted ? L("Accessibility Access Granted", "アクセシビリティ許可済み") : L("Grant Accessibility Access…", "アクセシビリティを許可…"),
            action: trusted ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        access.target = self
        menu.addItem(access)
        menu.addItem(.separator())

        let save = NSMenuItem(title: L("Save Current Layout…", "現在の配置を保存…"), action: #selector(saveCurrentLayout), keyEquivalent: "s")
        save.keyEquivalentModifierMask = [.command, .option]
        save.target = self
        menu.addItem(save)

        let restoreMenu = NSMenu(title: L("Restore Layout", "配置を復元"))
        let restore = NSMenuItem(title: L("Restore Layout", "配置を復元"), action: nil, keyEquivalent: "")
        restore.submenu = restoreMenu
        menu.addItem(restore)
        let current = currentProfiles
        if current.isEmpty {
            let empty = NSMenuItem(title: L("No layouts for this display setup", "このディスプレイ構成の配置はありません"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            restoreMenu.addItem(empty)
        } else {
            for (index, profile) in current.enumerated() {
                let item = NSMenuItem(title: profile.name, action: #selector(restoreProfile(_:)), keyEquivalent: index < 9 ? String(index + 1) : "")
                item.target = self
                item.representedObject = profile.id
                item.toolTip = L("Saved \(profile.windows.count) windows", "\(profile.windows.count)個のウィンドウを保存")
                if index < 9 { item.keyEquivalentModifierMask = [.command] }
                restoreMenu.addItem(item)
            }
        }

        let manageMenu = NSMenu(title: L("Manage Layouts", "配置の管理"))
        let manage = NSMenuItem(title: L("Manage Layouts", "配置の管理"), action: nil, keyEquivalent: "")
        manage.submenu = manageMenu
        menu.addItem(manage)
        if store.profiles.isEmpty {
            let empty = NSMenuItem(title: L("No saved layouts", "保存された配置はありません"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            manageMenu.addItem(empty)
        } else {
            for profile in store.profiles.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                let item = NSMenuItem(title: L("Delete \(profile.name)", "\(profile.name) を削除"), action: #selector(deleteProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = profile.id
                manageMenu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let auto = NSMenuItem(
            title: L("Auto-Restore When Displays Change", "ディスプレイ変更時に自動復元"),
            action: #selector(toggleAutoRestore),
            keyEquivalent: ""
        )
        auto.target = self
        auto.state = autoRestoreEnabled ? .on : .off
        menu.addItem(auto)

        let launch = NSMenuItem(title: L("Launch at Login", "ログイン時に起動"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launch)

        let update = NSMenuItem(title: L("Check for Updates…", "アップデートを確認…"), action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit Window Memory", "Window Memory を終了"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - State

    private var currentProfiles: [LayoutProfile] {
        let signature = displaySignature()
        return store.profiles
            .filter { normalizedSignature($0.displaySignature) == signature }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    private var autoRestoreEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoRestore") }
        set { UserDefaults.standard.set(newValue, forKey: "autoRestore") }
    }

    // MARK: - Actions

    @objc private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        refreshMenu()
    }

    @objc private func saveCurrentLayout() {
        guard AXIsProcessTrusted() else { openAccessibilitySettings(); return }
        bringToFront()
        let alert = NSAlert()
        alert.messageText = L("Save Current Layout", "現在の配置を保存")
        alert.informativeText = L("Give this window arrangement a name.", "この配置に名前を付けてください。")
        let field = NSTextField(string: L("Layout \(store.profiles.count + 1)", "配置 \(store.profiles.count + 1)"))
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: L("Save", "保存"))
        alert.addButton(withTitle: L("Cancel", "キャンセル"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let windows = readWindows()
        guard !windows.isEmpty else {
            showNotice(
                L("No windows found", "ウィンドウが見つかりません"),
                L("Make sure the apps you want to save are running and Window Memory has Accessibility access.",
                  "保存したいアプリが起動していることと、Window Memory にアクセシビリティが許可されていることを確認してください。")
            )
            return
        }
        store.profiles.append(LayoutProfile(id: UUID(), name: name, displaySignature: displaySignature(), savedAt: Date(), windows: windows))
        persistStore()
        refreshMenu()
    }

    @objc private func restoreProfile(_ sender: NSMenuItem) {
        guard AXIsProcessTrusted(), let id = sender.representedObject as? UUID, let profile = store.profiles.first(where: { $0.id == id }) else { openAccessibilitySettings(); return }
        let result = restore(profile)
        if result.failed > 0 {
            showNotice(
                L("Layout restored with warnings", "配置を復元しました(一部未復元)"),
                L("Restored \(result.restored) window(s). \(result.failed) could not be matched.",
                  "\(result.restored)個のウィンドウを復元しました。\(result.failed)個は一致するウィンドウが見つかりませんでした。")
            )
        }
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        guard let profile = store.profiles.first(where: { $0.id == id }) else { return }
        bringToFront()
        let alert = NSAlert()
        alert.messageText = L("Delete \(profile.name)?", "\(profile.name) を削除しますか?")
        alert.informativeText = L("This only removes the saved layout. Open windows are not changed.", "保存された配置のみ削除されます。開いているウィンドウは変更されません。")
        alert.addButton(withTitle: L("Delete", "削除"))
        alert.addButton(withTitle: L("Cancel", "キャンセル"))
        if alert.runModal() == .alertFirstButtonReturn {
            store.profiles.removeAll { $0.id == id }
            persistStore()
            refreshMenu()
        }
    }

    @objc private func toggleAutoRestore() {
        autoRestoreEnabled.toggle()
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                if launchAtLoginEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            } else { UserDefaults.standard.set(!launchAtLoginEnabled, forKey: "launchAtLogin") }
            refreshMenu()
        } catch { showNotice(L("Launch at Login unavailable", "ログイン時の起動を変更できません"), error.localizedDescription) }
    }

    /// Manual check only: the app makes no network request unless the user asks for it.
    @objc private func checkForUpdates() {
        guard let url = URL(string: releasesAPI) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard error == nil, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    self.showNotice(L("Could not check for updates", "アップデートを確認できませんでした"),
                                    L("Please check your internet connection and try again.", "ネットワーク接続を確認して、もう一度お試しください。"))
                    return
                }
                let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    self.bringToFront()
                    let alert = NSAlert()
                    alert.messageText = L("Version \(latest) is available", "バージョン \(latest) が利用可能です")
                    alert.informativeText = L("You are using version \(current).", "現在のバージョンは \(current) です。")
                    alert.addButton(withTitle: L("Open Releases", "リリースページを開く"))
                    alert.addButton(withTitle: L("Later", "あとで"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        let page = (json["html_url"] as? String).flatMap(URL.init(string:))
                            ?? URL(string: "https://github.com/lynox-llc/Window-Memory/releases")!
                        NSWorkspace.shared.open(page)
                    }
                } else {
                    self.showNotice(L("You're up to date", "最新バージョンです"), L("Version \(current)", "バージョン \(current)"))
                }
            }
        }.resume()
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - Display changes

    @objc private func screensChanged() {
        refreshMenu()
        pendingAutoRestore?.cancel()
        guard autoRestoreEnabled, AXIsProcessTrusted() else { return }
        // Wait for macOS to finish re-arranging windows after the display change.
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let profile = self.currentProfiles.first else { return }
            _ = self.restore(profile)
        }
        pendingAutoRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    // MARK: - Windows

    private func readWindows() -> [WindowSnapshot] {
        var result: [WindowSnapshot] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            for window in axWindows(of: app) {
                guard let frame = windowFrame(window), frame.width > 1, frame.height > 1 else { continue }
                result.append(WindowSnapshot(
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    applicationName: app.localizedName ?? "Application",
                    title: windowTitle(window),
                    windowNumber: windowNumber(window),
                    x: frame.minX, y: frame.minY, width: frame.width, height: frame.height
                ))
            }
        }
        return result
    }

    /// Matches each saved window to a live window and moves it.
    /// Order of preference: same title, same window number, then (only if the app
    /// has a single saved window) any unused window of that app. A window is used at most once.
    private func restore(_ profile: LayoutProfile) -> (restored: Int, failed: Int) {
        var restored = 0
        var failed = 0
        var used: [AXUIElement] = []
        for snapshot in profile.windows {
            let savedCountForApp = profile.windows.filter { $0.bundleIdentifier == snapshot.bundleIdentifier }.count
            var target: AXUIElement?
            for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == snapshot.bundleIdentifier {
                let free = axWindows(of: app).filter { window in !used.contains { CFEqual($0, window) } }
                target = free.first { !snapshot.title.isEmpty && windowTitle($0) == snapshot.title }
                    ?? free.first { snapshot.windowNumber != nil && windowNumber($0) == snapshot.windowNumber }
                    ?? (savedCountForApp == 1 ? free.first : nil)
                if target != nil { break }
            }
            if let window = target {
                setWindowFrame(window, CGRect(x: snapshot.x, y: snapshot.y, width: snapshot.width, height: snapshot.height))
                used.append(window)
                restored += 1
            } else {
                failed += 1
            }
        }
        return (restored, failed)
    }

    private func axWindows(of app: NSRunningApplication) -> [AXUIElement] {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    private func windowTitle(_ window: AXUIElement) -> String {
        attribute(window, kAXTitleAttribute) as? String ?? ""
    }

    private func windowNumber(_ window: AXUIElement) -> Int? {
        (attribute(window, "AXWindowNumber") as? NSNumber)?.intValue
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
        // Size first, position second, size again: moving to another display can clamp the size.
        if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }
        if let p = AXValueCreate(.cgPoint, &point) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p) }
        if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    // MARK: - Display signature

    /// Frames only, so the signature stays the same when macOS reassigns display IDs on reconnect.
    private func displaySignature() -> String {
        NSScreen.screens.map { screen in
            let frame = screen.frame
            return "\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
        }.sorted().joined(separator: "|")
    }

    /// Converts signatures saved by v1.1.x ("<displayID>:x,y,w,h|…") to the current format.
    private func normalizedSignature(_ signature: String) -> String {
        signature.split(separator: "|").map { part -> String in
            if let colon = part.firstIndex(of: ":") { return String(part[part.index(after: colon)...]) }
            return String(part)
        }.sorted().joined(separator: "|")
    }

    // MARK: - Persistence

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
        } catch { showNotice(L("Could not save layouts", "配置を保存できませんでした"), error.localizedDescription) }
    }

    // MARK: - UI helpers

    private func bringToFront() {
        if #available(macOS 14.0, *) { NSApplication.shared.activate() } else { NSApplication.shared.activate(ignoringOtherApps: true) }
    }

    private func showNotice(_ title: String, _ message: String) {
        bringToFront()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

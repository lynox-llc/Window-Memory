import Cocoa
import ApplicationServices
import ServiceManagement
import CoreGraphics

// MARK: - Models

/// One captured window's placement.
struct WindowSnapshot: Codable {
    var bundleId: String
    var appName: String
    var windowIndex: Int
    var title: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

/// A named layout profile bound to the display arrangement it was captured under.
struct Profile: Codable {
    var id: String
    var name: String
    var displaySignature: String
    var displayDescription: String
    var windows: [WindowSnapshot]
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - Display configuration

enum Displays {
    /// A stable signature for the current monitor arrangement, so a layout saved
    /// on one setup is only auto-suggested when that same setup returns.
    static func signature() -> String {
        let parts = NSScreen.screens.map { screen -> String in
            let f = screen.frame
            return "\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.width)),\(Int(f.height))"
        }.sorted()
        return parts.joined(separator: "|")
    }

    static func description() -> String {
        let n = NSScreen.screens.count
        let sizes = NSScreen.screens.map { "\(Int($0.frame.width))×\(Int($0.frame.height))" }.joined(separator: " + ")
        return "ディスプレイ\(n)台（\(sizes)）"
    }
}

// MARK: - Accessibility / window engine

enum WindowEngine {

    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Counts real on-screen windows system-wide via CGWindowList — this needs no
    /// special permission, unlike AXUIElement. Used to tell "there's genuinely
    /// nothing to capture" apart from "accessibility is broken and returning
    /// nothing despite windows being open" — the two look identical from
    /// `capture().count == 0` alone.
    static func systemWindowCountHint() -> Int {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return 0 }
        let myPID = ProcessInfo.processInfo.processIdentifier
        return list.filter { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return false }
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != myPID else { return false }
            return true
        }.count
    }

    /// Read an attribute off an AX element.
    private static func copyAttr(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &ref)
        return err == .success ? ref : nil
    }

    static func capture() -> [WindowSnapshot] {
        var snapshots: [WindowSnapshot] = []
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            guard let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier else { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windowsRef = copyAttr(axApp, kAXWindowsAttribute as String),
                  let windows = windowsRef as? [AXUIElement] else { continue }

            for (index, window) in windows.enumerated() {
                guard let (pos, size) = frame(of: window) else { continue }
                // Skip minimized or zero-size windows.
                if size.width < 1 || size.height < 1 { continue }
                let title = copyAttr(window, kAXTitleAttribute as String) as? String ?? ""
                snapshots.append(WindowSnapshot(
                    bundleId: bundleId,
                    appName: app.localizedName ?? bundleId,
                    windowIndex: index,
                    title: title,
                    x: Double(pos.x), y: Double(pos.y),
                    w: Double(size.width), h: Double(size.height)
                ))
            }
        }
        return snapshots
    }

    private static func frame(of window: AXUIElement) -> (CGPoint, CGSize)? {
        guard let posRef = copyAttr(window, kAXPositionAttribute as String),
              let sizeRef = copyAttr(window, kAXSizeAttribute as String) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return (position, size)
    }

    private static func setFrame(of window: AXUIElement, position: CGPoint, size: CGSize) {
        var pos = position
        var sz = size
        // Set size first, then position, then size again — some apps clamp
        // position against the old size, so a second pass lands it correctly.
        if let szVal = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, szVal)
        }
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let szVal2 = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, szVal2)
        }
    }

    /// Restore a saved layout. Returns (restored, total).
    @discardableResult
    static func restore(_ snapshots: [WindowSnapshot]) -> (Int, Int) {
        var restored = 0
        // Group snapshots by app for efficient lookup.
        let byBundle = Dictionary(grouping: snapshots, by: { $0.bundleId })

        for (bundleId, wanted) in byBundle {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleId && $0.activationPolicy == .regular
            }) else { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windowsRef = copyAttr(axApp, kAXWindowsAttribute as String),
                  let windows = windowsRef as? [AXUIElement] else { continue }

            // Live windows with their titles, for matching.
            var live: [(el: AXUIElement, title: String, index: Int)] = []
            for (i, w) in windows.enumerated() {
                let title = copyAttr(w, kAXTitleAttribute as String) as? String ?? ""
                live.append((w, title, i))
            }
            var used = Set<Int>()

            for snap in wanted {
                // Prefer an exact title match, then fall back to window index.
                var pick: Int? = live.first(where: {
                    !used.contains($0.index) && !snap.title.isEmpty && $0.title == snap.title
                })?.index
                if pick == nil {
                    pick = live.first(where: {
                        !used.contains($0.index) && $0.index == snap.windowIndex
                    })?.index
                }
                if pick == nil {
                    pick = live.first(where: { !used.contains($0.index) })?.index
                }
                guard let idx = pick, let target = live.first(where: { $0.index == idx }) else { continue }
                used.insert(idx)
                setFrame(of: target.el,
                         position: CGPoint(x: snap.x, y: snap.y),
                         size: CGSize(width: snap.w, height: snap.h))
                restored += 1
            }
        }
        return (restored, snapshots.count)
    }
}

// MARK: - Persistence

final class Store {
    static let shared = Store()
    private(set) var profiles: [Profile] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WindowMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("profiles.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        profiles = (try? JSONDecoder.iso.decode([Profile].self, from: data)) ?? []
    }

    func save() {
        guard let data = try? JSONEncoder.iso.encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ profile: Profile) {
        if let i = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[i] = profile
        } else {
            profiles.append(profile)
        }
        save()
    }

    func delete(id: String) {
        profiles.removeAll { $0.id == id }
        save()
    }

    /// Profiles captured under the current display arrangement, newest first.
    func profilesForCurrentDisplays() -> [Profile] {
        let sig = Displays.signature()
        return profiles.filter { $0.displaySignature == sig }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted]; return e
    }
}
extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    // MARK: Auto-restore on display change (v1.2)

    /// Pending restore scheduled after a display change. Cancelled and rescheduled
    /// on every change so a burst of notifications (plugging in a dock fires
    /// several) results in a single restore once things settle.
    private var pendingAutoRestore: DispatchWorkItem?
    private static let autoRestoreKey = "autoRestoreOnDisplayChange"
    private var autoRestoreEnabled: Bool { UserDefaults.standard.bool(forKey: Self.autoRestoreKey) }

    @objc private func screensChanged() {
        rebuildMenu()
        pendingAutoRestore?.cancel()
        guard autoRestoreEnabled, WindowEngine.isTrusted(prompt: false) else { return }
        let work = DispatchWorkItem {
            guard let profile = Store.shared.profilesForCurrentDisplays().first else { return }
            WindowEngine.restore(profile.windows)
        }
        pendingAutoRestore = work
        // Wait for macOS to finish its own window shuffling after the change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    @objc private func toggleAutoRestore() {
        UserDefaults.standard.set(!autoRestoreEnabled, forKey: Self.autoRestoreKey)
        rebuildMenu()
    }

    @objc private func checkForUpdatesManually() {
        checkForUpdates(userInitiated: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle",
                                   accessibilityDescription: "ウィンドウメモリ")
        }
        rebuildMenu()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // First launch: explain setup once, then ask the system for access.
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            showWelcome()
        }

        // Prompt for accessibility access on first launch if needed.
        if !WindowEngine.isTrusted(prompt: false) {
            _ = WindowEngine.isTrusted(prompt: true)
        }

        checkForUpdates()
    }

    /// Lightweight, non-blocking check against GitHub Releases. Distribution is a
    /// manual DMG download with no auto-update mechanism, so without this, users
    /// on an old build (some of which had real bugs) have no way to learn a fix
    /// exists. The launch-time check is silent on any network failure; a check
    /// started from the menu (`userInitiated`) always reports its result.
    private func checkForUpdates(userInitiated: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/lynox-llc/Window-Memory/releases") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard let data,
                  let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = releases.first,
                  let tag = latest["tag_name"] as? String,
                  let htmlURLString = latest["html_url"] as? String else {
                // Background check stays silent; a check the user asked for must answer.
                if userInitiated {
                    DispatchQueue.main.async {
                        self?.notify("アップデートを確認できませんでした",
                                     "ネットワーク接続を確認して、もう一度お試しください。")
                    }
                }
                return
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if Self.isNewerVersion(tag, than: current) {
                    self.showUpdateAvailable(tag: tag, urlString: htmlURLString, force: userInitiated)
                } else if userInitiated {
                    self.notify("最新バージョンです", "Window Memory \(current) は最新です。")
                }
            }
        }.resume()
    }

    /// Compares dotted version numbers component-by-component (e.g. "v1.2.0" vs
    /// "1.1.1"), ignoring a leading "v" and any non-numeric suffix.
    private static func isNewerVersion(_ remoteTag: String, than currentVersion: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .map { Int($0.filter(\.isNumber)) ?? 0 }
        }
        let remote = parts(remoteTag), current = parts(currentVersion)
        for i in 0..<max(remote.count, current.count) {
            let r = i < remote.count ? remote[i] : 0
            let c = i < current.count ? current[i] : 0
            if r != c { return r > c }
        }
        return false
    }

    /// Shown at most once per version — a dismissal is remembered so the app
    /// doesn't nag on every subsequent launch.
    private func showUpdateAvailable(tag: String, urlString: String, force: Bool = false) {
        let dismissKey = "dismissedUpdate_\(tag)"
        // A manual check always shows the result, even for a previously dismissed version.
        guard force || !UserDefaults.standard.bool(forKey: dismissKey) else { return }
        let alert = NSAlert()
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) { alert.icon = icon }
        alert.messageText = "新しいバージョンがあります"
        alert.informativeText = "Window Memory \(tag) が公開されています。ダウンロードページを開きますか？"
        alert.addButton(withTitle: "開く")
        alert.addButton(withTitle: "後で")
        if presentFrontmost(alert) == .alertFirstButtonReturn {
            if let u = URL(string: urlString) { NSWorkspace.shared.open(u) }
        } else {
            UserDefaults.standard.set(true, forKey: dismissKey)
        }
    }

    /// Shown once on first launch — covers the two things that block new users:
    /// the Gatekeeper warning (unsigned app) and accessibility access.
    private func showWelcome() {
        let alert = NSAlert()
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) { alert.icon = icon }
        alert.messageText = "Window Memory へようこそ"
        alert.informativeText = """
        セットアップはあと1ステップだけです。

        【ウィンドウ操作の許可】
        システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」
        で Window Memory を【オン】にしてください。
        このあと表示される確認ダイアログからも開けます。

        許可が終わったら、メニューバーの ⊞ アイコンから
        「現在の配置を保存…」で配置を記録できます。

        ※ うまく動かないときは、メニューの
        「アクセシビリティを診断…」で状態を確認できます。
        """
        alert.addButton(withTitle: "はじめる")
        alert.addButton(withTitle: "システム設定を開く")
        if presentFrontmost(alert) == .alertSecondButtonReturn { openAccessibilitySettings() }
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Window Memory — ウィンドウメモリ", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let trusted = WindowEngine.isTrusted(prompt: false)

        if !trusted {
            let warn = NSMenuItem(title: "⚠︎ アクセシビリティ権限が必要です", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let grant = NSMenuItem(title: "システム設定で許可する…",
                                   action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
            menu.addItem(.separator())
        }

        let save = NSMenuItem(title: "現在の配置を保存…", action: #selector(saveLayout), keyEquivalent: "s")
        save.target = self
        save.isEnabled = trusted
        menu.addItem(save)

        // Restore submenu / current-display profiles.
        let current = Store.shared.profilesForCurrentDisplays()
        let restoreItem = NSMenuItem(title: "配置を復元", action: nil, keyEquivalent: "")
        let restoreMenu = NSMenu()
        if current.isEmpty {
            let none = NSMenuItem(title: "このディスプレイ構成の配置はありません", action: nil, keyEquivalent: "")
            none.isEnabled = false
            restoreMenu.addItem(none)
        } else {
            for (i, p) in current.enumerated() {
                let item = NSMenuItem(title: p.name, action: #selector(restoreProfile(_:)),
                                      keyEquivalent: i < 9 ? "\(i + 1)" : "")
                item.target = self
                item.representedObject = p.id
                item.isEnabled = trusted
                restoreMenu.addItem(item)
            }
        }
        restoreItem.submenu = restoreMenu
        restoreItem.isEnabled = trusted && !current.isEmpty
        menu.addItem(restoreItem)

        // Manage submenu — lists every profile grouped by display setup.
        menu.addItem(.separator())
        let manageItem = NSMenuItem(title: "配置を管理", action: nil, keyEquivalent: "")
        let manageMenu = NSMenu()
        if Store.shared.profiles.isEmpty {
            let none = NSMenuItem(title: "保存された配置はありません", action: nil, keyEquivalent: "")
            none.isEnabled = false
            manageMenu.addItem(none)
        } else {
            let grouped = Dictionary(grouping: Store.shared.profiles, by: { $0.displayDescription })
            for (desc, profs) in grouped.sorted(by: { $0.key < $1.key }) {
                let head = NSMenuItem(title: desc, action: nil, keyEquivalent: "")
                head.isEnabled = false
                manageMenu.addItem(head)
                for p in profs.sorted(by: { $0.updatedAt > $1.updatedAt }) {
                    let sub = NSMenuItem(title: "   \(p.name)（\(p.windows.count)ウィンドウ）",
                                         action: nil, keyEquivalent: "")
                    let subMenu = NSMenu()
                    let rename = NSMenuItem(title: "名前を変更…", action: #selector(renameProfile(_:)), keyEquivalent: "")
                    rename.target = self; rename.representedObject = p.id
                    subMenu.addItem(rename)
                    let over = NSMenuItem(title: "現在のウィンドウで上書き", action: #selector(overwriteProfile(_:)), keyEquivalent: "")
                    over.target = self; over.representedObject = p.id; over.isEnabled = trusted
                    subMenu.addItem(over)
                    let del = NSMenuItem(title: "「\(p.name)」を削除", action: #selector(deleteProfile(_:)), keyEquivalent: "")
                    del.target = self; del.representedObject = p.id
                    subMenu.addItem(del)
                    sub.submenu = subMenu
                    manageMenu.addItem(sub)
                }
                manageMenu.addItem(.separator())
            }
        }
        manageItem.submenu = manageMenu
        menu.addItem(manageItem)

        menu.addItem(.separator())

        // Auto-restore toggle (v1.2).
        let autoRestore = NSMenuItem(title: "ディスプレイ変更時に自動復元",
                                     action: #selector(toggleAutoRestore), keyEquivalent: "")
        autoRestore.target = self
        autoRestore.state = autoRestoreEnabled ? .on : .off
        menu.addItem(autoRestore)

        // Launch at login toggle.
        let login = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)

        let diag = NSMenuItem(title: "アクセシビリティを診断…", action: #selector(runDiagnostics), keyEquivalent: "")
        diag.target = self
        menu.addItem(diag)

        let update = NSMenuItem(title: "アップデートを確認…", action: #selector(checkForUpdatesManually), keyEquivalent: "")
        update.target = self
        menu.addItem(update)

        let about = NSMenuItem(title: "Window Memory について", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func openAccessibilitySettings() {
        _ = WindowEngine.isTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Verify accessibility access before any window operation.
    /// Never fails silently — guides the user when access is missing or stale.
    @discardableResult
    private func ensureTrusted() -> Bool {
        if WindowEngine.isTrusted(prompt: false) { return true }
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
        ウィンドウを操作するには許可が必要です。

        システム設定 →「プライバシーとセキュリティ」→「アクセシビリティ」で
        Window Memory をオンにしてください。

        ● すでにオンなのに動作しない場合
        リストで Window Memory を選んで「−」で削除し、「＋」から
        /Applications/Window Memory.app をもう一度追加してオンにしてください。
        （アプリを更新すると、以前の許可が無効になることがあります）
        """
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "キャンセル")
        if presentFrontmost(alert) == .alertFirstButtonReturn { openAccessibilitySettings() }
        return false
    }

    @objc private func runDiagnostics() {
        // Report the API's answer and a real capture separately: the permission can
        // read as granted while every AX call still fails (stale grant after update).
        // A capture count of 0 is ambiguous by itself — it also happens when the
        // user legitimately has no other windows open — so cross-check against a
        // system-wide window count that needs no accessibility permission at all.
        let trusted = WindowEngine.isTrusted(prompt: false)
        let count = WindowEngine.capture().count
        let systemHint = WindowEngine.systemWindowCountHint()
        let nothingToCapture = systemHint == 0
        let working = count > 0 || nothingToCapture

        let verdict: String
        if count > 0 {
            verdict = "✅ 正常に動作します。\n「現在の配置を保存…」で配置を保存できます。"
        } else if nothingToCapture {
            verdict = "ℹ️ 現在、他のアプリのウィンドウが開かれていません。\nウィンドウを開いてから保存をお試しください（許可自体は正常です）。"
        } else if trusted {
            verdict = """
            ⚠️ 許可は「オン」ですが、実際にはウィンドウを取得できていません。
            アプリを更新・再インストールしたため、以前の許可が
            無効になった状態です。

            解決手順：
            1. システム設定 →「プライバシーとセキュリティ」
               →「アクセシビリティ」
            2. 「Window Memory」を「−」で削除
            3. 「＋」で /Applications/Window Memory.app を追加
            4. 【オン】にしてから、このアプリを再起動
            """
        } else {
            verdict = """
            ❌ 許可が有効になっていません。
            システム設定 →「プライバシーとセキュリティ」
            →「アクセシビリティ」で Window Memory をオンにしてください。
            """
        }

        let alert = NSAlert()
        alert.alertStyle = working ? .informational : .warning
        alert.messageText = "アクセシビリティ診断"
        alert.informativeText = """
        許可の状態（API）： \(trusted ? "有効" : "無効")
        実際のウィンドウ取得： \(count) 個（画面上の他アプリのウィンドウ： \(systemHint) 個）
        バージョン： \(appVersion)
        アプリの場所： \(Bundle.main.bundlePath)

        \(verdict)
        """
        alert.addButton(withTitle: "OK")
        if !working { alert.addButton(withTitle: "システム設定を開く") }
        if presentFrontmost(alert) == .alertSecondButtonReturn { openAccessibilitySettings() }
    }

    @objc private func saveLayout() {
        guard ensureTrusted() else { return }
        let windows = WindowEngine.capture()
        if windows.isEmpty {
            // A capture count of 0 is ambiguous: it also happens when the user
            // simply has no other windows open right now. Cross-check against a
            // system-wide window count that needs no accessibility permission,
            // so a legitimately empty desktop isn't reported as a broken grant.
            if WindowEngine.systemWindowCountHint() == 0 {
                notify("保存できるものがありません", "他のアプリのウィンドウが開かれていません。ウィンドウを開いてからお試しください。")
                return
            }
            // Windows do exist on screen but AX couldn't read them — this is the
            // classic stale-permission state after the app is updated or replaced.
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "ウィンドウを取得できませんでした"
            alert.informativeText = """
            アクセシビリティの許可が有効になっていない可能性があります。
            設定上は「オン」でも、アプリを更新・再インストールすると
            以前の許可が無効になることがあります。

            次の手順で解決できます：

            1. システム設定 →「プライバシーとセキュリティ」
               →「アクセシビリティ」を開く
            2. リストの「Window Memory」を選び、「−」ボタンで削除
            3. 「＋」ボタンを押し、
               /Applications/Window Memory.app を追加
            4. 追加された「Window Memory」を【オン】にする
            5. このアプリを終了して、もう一度起動する

            ※ 上記でも解決しない場合は、ターミナルで次を実行してください：
              tccutil reset Accessibility \(Bundle.main.bundleIdentifier ?? "com.lynox.WindowMemory")
            """
            alert.addButton(withTitle: "システム設定を開く")
            alert.addButton(withTitle: "閉じる")
            if presentFrontmost(alert) == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = "配置を保存"
        alert.informativeText = "\(Displays.description()) で \(windows.count) 個のウィンドウを取得しました。\nこの配置に名前を付けてください:"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = defaultProfileName()
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? defaultProfileName() : name
        let now = Date()

        // A same-named profile used to silently create a second, confusingly
        // duplicate entry. Ask before overwriting instead.
        if let existing = Store.shared.profiles.first(where: { $0.name == finalName }) {
            let overwrite = NSAlert()
            overwrite.alertStyle = .warning
            overwrite.messageText = "「\(finalName)」は既に存在します"
            overwrite.informativeText = "上書きしますか？別名で保存したい場合はキャンセルして、もう一度名前を入力してください。"
            overwrite.addButton(withTitle: "上書き")
            overwrite.addButton(withTitle: "キャンセル")
            guard presentFrontmost(overwrite) == .alertFirstButtonReturn else { return }
            var profile = existing
            profile.windows = windows
            profile.displaySignature = Displays.signature()
            profile.displayDescription = Displays.description()
            profile.updatedAt = now
            Store.shared.upsert(profile)
            rebuildMenu()
            notify("配置を上書きしました", "「\(profile.name)」— \(windows.count) 個のウィンドウ")
            return
        }

        let profile = Profile(
            id: UUID().uuidString,
            name: finalName,
            displaySignature: Displays.signature(),
            displayDescription: Displays.description(),
            windows: windows,
            createdAt: now, updatedAt: now
        )
        Store.shared.upsert(profile)
        rebuildMenu()
        notify("配置を保存しました", "「\(profile.name)」— \(windows.count) 個のウィンドウ")
    }

    @objc private func restoreProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let profile = Store.shared.profiles.first(where: { $0.id == id }) else { return }
        guard ensureTrusted() else { return }
        let (done, total) = WindowEngine.restore(profile.windows)
        if done == 0 {
            notify("復元できませんでした", """
            保存時のアプリが起動していないか、アクセシビリティの許可が
            無効になっている可能性があります。

            メニューの「アクセシビリティを診断…」で状態を確認できます。
            """)
        } else {
            notify("「\(profile.name)」を復元しました",
                   "\(done)/\(total) 個のウィンドウを配置しました。"
                   + (done < total ? "\n\n配置されなかったウィンドウは、保存時のアプリが起動していない可能性があります。" : ""))
        }
    }

    @objc private func renameProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              var profile = Store.shared.profiles.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "名前を変更"
        alert.informativeText = "「\(profile.name)」の新しい名前を入力してください:"
        alert.addButton(withTitle: "変更")
        alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = profile.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != profile.name else { return }
        if Store.shared.profiles.contains(where: { $0.name == newName && $0.id != profile.id }) {
            notify("名前を変更できませんでした", "「\(newName)」は既に使われています。別の名前を指定してください。")
            return
        }
        profile.name = newName
        profile.updatedAt = Date()
        Store.shared.upsert(profile)
        rebuildMenu()
    }

    @objc private func overwriteProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              var profile = Store.shared.profiles.first(where: { $0.id == id }) else { return }
        guard ensureTrusted() else { return }
        profile.windows = WindowEngine.capture()
        profile.displaySignature = Displays.signature()
        profile.displayDescription = Displays.description()
        profile.updatedAt = Date()
        Store.shared.upsert(profile)
        rebuildMenu()
        notify("配置を更新しました", "「\(profile.name)」は \(profile.windows.count) 個のウィンドウになりました。")
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let profile = Store.shared.profiles.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "「\(profile.name)」を削除しますか？"
        alert.informativeText = "この配置は完全に削除されます。"
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        guard presentFrontmost(alert) == .alertFirstButtonReturn else { return }
        Store.shared.delete(id: id)
        rebuildMenu()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            notify("自動起動の設定エラー", error.localizedDescription)
        }
        rebuildMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        if let icon = NSImage(contentsOfFile:
            Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? "") {
            alert.icon = icon
        }
        alert.messageText = "Window Memory（ウィンドウメモリ）  バージョン \(appVersion)"
        alert.informativeText = """
        外部モニターの抜き差しで崩れたウィンドウ配置を、\
        1クリックで元通りに復元するメニューバー常駐アプリです。

        ■ 主な機能
        ・アプリ配置保存 … 起動中の全アプリのウィンドウ位置・サイズを記録
        ・1クリック復元 … メニューから選ぶだけで一括復元（⌘1〜⌘9）
        ・ディスプレイごとのプロファイル … モニター構成ごとに配置を自動グループ化。\
        同じ構成に戻ったときだけ、その配置を「配置を復元」に表示
        ・ディスプレイ変更時の自動復元（任意） … モニターの抜き差しを検知し、\
        その構成で最後に保存した配置を自動で復元
        ・ログイン時に自動起動

        ■ しくみ
        macOS のアクセシビリティ API を用いて、各アプリのウィンドウ位置・サイズを\
        読み書きします。配置データはお使いの Mac 内にのみ保存され、外部には送信しません。
        （ウィンドウの移動にはアクセシビリティ権限の許可が必要です）

        ────────────────────────
        開発： LYNOX LLC
        © 2026 LYNOX LLC. All rights reserved.
        """
        alert.addButton(withTitle: "OK")
        presentFrontmost(alert)
    }

    /// Single source of truth for the displayed version — read from the bundle
    /// instead of a literal, so the About/diagnostics text can't drift out of
    /// sync with Info.plist on a version bump.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func defaultProfileName() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "M月d日 HH:mm"
        return "配置 \(df.string(from: Date()))"
    }

    /// Show feedback the user is guaranteed to see.
    ///
    /// Notification Center is unreliable for an unsigned, LSUIElement app — messages
    /// were being dropped silently, so failures looked like "nothing happened".
    /// A modal alert always appears, so every outcome is now reported.
    private func notify(_ title: String, _ body: String) {
        let alert = NSAlert()
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) { alert.icon = icon }
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        presentFrontmost(alert)
    }

    /// Bring a modal alert reliably to the front.
    ///
    /// An `.accessory` app does not own the active app slot, so alerts could open
    /// behind other windows and appear to never show. Switching to `.regular` for
    /// the duration of the modal guarantees it is visible and focused.
    @discardableResult
    private func presentFrontmost(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let previous = NSApp.activationPolicy()
        if previous != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .modalPanel
        alert.window.makeKeyAndOrderFront(nil)
        let response = alert.runModal()
        if previous != .regular { NSApp.setActivationPolicy(previous) }
        return response
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()

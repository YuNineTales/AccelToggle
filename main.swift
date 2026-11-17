// AccelToggle — 메뉴 막대에서 브라우저 하드웨어 가속을 켜고 끄는 앱
// 왼쪽 클릭: 선택한 브라우저 가속 토글 / 오른쪽 클릭: 메뉴
// 동작: 브라우저 정상 종료 → "Local State"의 hardware_acceleration_mode.enabled 변경 → 재실행
// 크로미움 계열 브라우저(Chrome, Edge, Brave, Vivaldi 등)는 같은 설정 키를 사용하므로 공통으로 동작합니다

import AppKit
import ServiceManagement

// MARK: - 지원 브라우저 목록 (여기에 추가하면 메뉴에 표시됩니다)

struct Browser {
    let name: String
    let bundleID: String
    /// ~/Library/Application Support/ 아래 사용자 데이터 폴더
    let dataDir: String

    var localStateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(dataDir)
            .appendingPathComponent("Local State")
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}

let allBrowsers: [Browser] = [
    Browser(name: "Google Chrome",      bundleID: "com.google.Chrome",        dataDir: "Google/Chrome"),
    Browser(name: "Google Chrome Beta", bundleID: "com.google.Chrome.beta",   dataDir: "Google/Chrome Beta"),
    Browser(name: "Microsoft Edge",     bundleID: "com.microsoft.edgemac",    dataDir: "Microsoft Edge"),
    Browser(name: "Brave",              bundleID: "com.brave.Browser",        dataDir: "BraveSoftware/Brave-Browser"),
    Browser(name: "Vivaldi",            bundleID: "com.vivaldi.Vivaldi",      dataDir: "Vivaldi"),
]

// MARK: - 앱

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var busy = false
    private var lastSidecar = false
    private var screenWorkItem: DispatchWorkItem?

    private var installedBrowsers: [Browser] { allBrowsers.filter { $0.isInstalled } }

    /// 현재 대상 브라우저 (메뉴에서 선택하며, 선택값은 저장됩니다)
    private var target: Browser? {
        let saved = UserDefaults.standard.string(forKey: "targetBundleID")
        let installed = installedBrowsers
        return installed.first { $0.bundleID == saved } ?? installed.first
    }

    private var autoSidecar: Bool {
        get { UserDefaults.standard.bool(forKey: "autoSidecar") }
        set { UserDefaults.standard.set(newValue, forKey: "autoSidecar") }
    }

    // MARK: 시작

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        lastSidecar = sidecarConnected()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appChanged(_:)),
                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(appChanged(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        refreshIcon()
    }

    // MARK: 설정 파일 읽기/쓰기

    private func readAcceleration(_ b: Browser) -> Bool {
        guard let data = try? Data(contentsOf: b.localStateURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mode = root["hardware_acceleration_mode"] as? [String: Any],
              let enabled = mode["enabled"] as? Bool
        else { return true } // 값이 없으면 기본값(켜짐)으로 간주합니다
        return enabled
    }

    private func writeAcceleration(_ b: Browser, _ enabled: Bool) -> Bool {
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: b.localStateURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            showAlert("\(b.name) 설정 파일(Local State)을 읽을 수 없습니다.\n전체 디스크 접근 권한을 확인하거나, 브라우저를 한 번 실행했다가 종료한 뒤 다시 시도하십시오.")
            return false
        }

        // 처음 한 번만 원본을 백업합니다
        let backup = b.localStateURL.deletingLastPathComponent()
            .appendingPathComponent("Local State.acceltoggle-backup")
        if !fm.fileExists(atPath: backup.path) {
            try? fm.copyItem(at: b.localStateURL, to: backup)
        }

        var mode = root["hardware_acceleration_mode"] as? [String: Any] ?? [:]
        mode["enabled"] = enabled
        root["hardware_acceleration_mode"] = mode

        do {
            let out = try JSONSerialization.data(withJSONObject: root)
            try out.write(to: b.localStateURL, options: .atomic)
            return true
        } catch {
            showAlert("설정 파일을 저장하지 못했습니다: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: 브라우저 제어

    private func running(_ b: Browser) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: b.bundleID)
    }

    private func setAcceleration(_ b: Browser, _ enabled: Bool) {
        guard !busy else { return }
        let apps = running(b)

        // 브라우저가 꺼져 있으면 파일만 변경합니다 (다음 실행부터 적용)
        if apps.isEmpty {
            _ = writeAcceleration(b, enabled)
            refreshIcon()
            return
        }

        busy = true
        refreshIcon()
        apps.forEach { $0.terminate() } // Cmd+Q와 같은 정상 종료입니다

        waitForExit(b, deadline: Date().addingTimeInterval(15)) { [weak self] exited in
            guard let self = self else { return }
            guard exited else {
                self.busy = false
                self.refreshIcon()
                self.showAlert("\(b.name)이(가) 종료되지 않았습니다. 종료 확인 창이 표시되어 있는지 확인하십시오.")
                return
            }
            // 브라우저가 종료하면서 Local State를 기록하므로, 완전히 종료된 뒤 잠시 기다렸다가 수정합니다
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if self.writeAcceleration(b, enabled) {
                    self.launch(b)
                }
                self.busy = false
                self.refreshIcon()
            }
        }
    }

    private func waitForExit(_ b: Browser, deadline: Date, completion: @escaping (Bool) -> Void) {
        if running(b).isEmpty { completion(true); return }
        if Date() > deadline { completion(false); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.waitForExit(b, deadline: deadline, completion: completion)
        }
    }

    private func launch(_ b: Browser) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b.bundleID) else {
            showAlert("\(b.name)을(를) 찾을 수 없습니다.")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        // 종료 직전에 열려 있던 탭과 창을 복원합니다 (크롬의 "시작 시" 설정과 관계없이 적용됩니다)
        config.arguments = ["--restore-last-session"]
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    // MARK: Sidecar 감지

    private func sidecarConnected() -> Bool {
        NSScreen.screens.contains { screen in
            let name = screen.localizedName.lowercased()
            return name.contains("sidecar") || name.contains("ipad")
        }
    }

    @objc private func screensChanged() {
        // 화면 변경 이벤트가 여러 번 발생하므로 1.5초 동안 모아서 한 번에 처리합니다
        screenWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let now = self.sidecarConnected()
            guard now != self.lastSidecar else { return }
            self.lastSidecar = now
            if self.autoSidecar, let b = self.target {
                self.setAcceleration(b, !now) // Sidecar가 연결되면 가속을 끕니다
            }
        }
        screenWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    @objc private func appChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        if app?.bundleIdentifier == target?.bundleID { refreshIcon() }
    }

    // MARK: 메뉴 막대 UI

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let symbol: String
        let tip: String
        if let b = target {
            if busy {
                symbol = "arrow.triangle.2.circlepath"; tip = "\(b.name) 재시작 중…"
            } else if readAcceleration(b) {
                symbol = "bolt.fill"; tip = "\(b.name) 하드웨어 가속 켜짐 (클릭하면 끕니다)"
            } else {
                symbol = "film"; tip = "\(b.name) 하드웨어 가속 꺼짐 / DRM 시청 모드 (클릭하면 켭니다)"
            }
        } else {
            symbol = "questionmark.circle"; tip = "지원하는 브라우저가 설치되어 있지 않습니다"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if let b = target {
            setAcceleration(b, !readAcceleration(b))
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        if let b = target {
            let enabled = readAcceleration(b)
            let on = !running(b).isEmpty
            let header = NSMenuItem(
                title: "\(b.name) · 가속 \(enabled ? "켜짐" : "꺼짐") · \(on ? "실행 중" : "꺼짐")",
                action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())

            let toggle = NSMenuItem(
                title: enabled ? "가속 끄기 (DRM 시청 모드)" : "가속 켜기 (일반 모드)",
                action: #selector(toggleFromMenu), keyEquivalent: "")
            toggle.target = self
            menu.addItem(toggle)
            menu.addItem(.separator())
        }

        // 대상 브라우저 선택
        let browserMenu = NSMenu()
        for b in installedBrowsers {
            let item = NSMenuItem(title: b.name, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = b.bundleID
            item.state = (b.bundleID == target?.bundleID) ? .on : .off
            browserMenu.addItem(item)
        }
        if installedBrowsers.isEmpty {
            let none = NSMenuItem(title: "설치된 크로미움 브라우저 없음", action: nil, keyEquivalent: "")
            none.isEnabled = false
            browserMenu.addItem(none)
        }
        let browserItem = NSMenuItem(title: "대상 브라우저", action: nil, keyEquivalent: "")
        browserItem.submenu = browserMenu
        menu.addItem(browserItem)
        menu.addItem(.separator())

        let auto = NSMenuItem(title: "Sidecar 연결 시 자동 전환",
                              action: #selector(toggleAutoSidecar), keyEquivalent: "")
        auto.target = self
        auto.state = autoSidecar ? .on : .off
        menu.addItem(auto)

        let login = NSMenuItem(title: "로그인 시 자동 실행",
                               action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // 왼쪽 클릭이 다시 토글로 동작하도록 메뉴를 해제합니다
    }

    @objc private func toggleFromMenu() {
        guard let b = target else { return }
        setAcceleration(b, !readAcceleration(b))
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        UserDefaults.standard.set(id, forKey: "targetBundleID")
        refreshIcon()
    }

    @objc private func toggleAutoSidecar() { autoSidecar.toggle() }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert("로그인 항목을 설정하지 못했습니다: \(error.localizedDescription)\n앱을 '응용 프로그램' 폴더로 옮긴 뒤 다시 시도하십시오.")
        }
    }

    private func showAlert(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "AccelToggle"
        alert.informativeText = message
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Dock 아이콘 없이 메뉴 막대에만 표시합니다
app.run()

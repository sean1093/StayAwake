import AppKit
import ServiceManagement
import StayAwakeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let idleThresholdKey = "idleThreshold"
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    private let strings = Strings.current
    private let keepAwake: KeepAwake
    private var statusItem: NSStatusItem?

    override init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.idleThresholdKey: IdleThreshold.defaultValue])
        let stored = defaults.double(forKey: Self.idleThresholdKey)
        let idleThreshold = IdleThreshold.sanitized(stored)
        if idleThreshold != stored {
            defaults.set(idleThreshold, forKey: Self.idleThresholdKey)
        }
        keepAwake = KeepAwake(idleThreshold: idleThreshold)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.menu = menu
        self.statusItem = statusItem

        keepAwake.onStateChange = { [weak self] in self?.updateIcon() }
        start()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        keepAwake.refreshPermission()
        menu.removeAllItems()

        // action 為 nil 的項目會自動變成灰色，當作狀態文字。
        menu.addItem(withTitle: keepAwake.isRunning ? strings.statusRunning : strings.statusPaused, action: nil, keyEquivalent: "")
        if keepAwake.isRunning, let lastJiggle = keepAwake.lastJiggle {
            let time = lastJiggle.formatted(date: .omitted, time: .standard)
            menu.addItem(withTitle: strings.lastNudge(time), action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())

        let toggle = menu.addItem(withTitle: strings.keepAwake, action: #selector(toggleRunning), keyEquivalent: "")
        toggle.target = self
        toggle.state = keepAwake.isRunning ? .on : .off

        let thresholdMenu = NSMenu()
        for seconds in IdleThreshold.choices {
            let item = thresholdMenu.addItem(
                withTitle: strings.idleThresholdTitle(seconds: seconds),
                action: #selector(selectIdleThreshold(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(seconds)
            item.state = keepAwake.idleThreshold == seconds ? .on : .off
        }
        menu.addItem(withTitle: strings.idleThresholdMenu, action: nil, keyEquivalent: "").submenu = thresholdMenu

        // 每次打開選單都重新讀取：使用者也可能在系統設定裡改。
        let loginItem = menu.addItem(withTitle: strings.openAtLogin, action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }

        if !keepAwake.canPostEvents {
            menu.addItem(.separator())
            menu.addItem(withTitle: strings.permissionMissing, action: nil, keyEquivalent: "")
            menu.addItem(withTitle: strings.openAccessibilitySettings, action: #selector(openAccessibilitySettings), keyEquivalent: "")
                .target = self
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: strings.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func start() {
        keepAwake.start()
        if !keepAwake.canPostEvents {
            // 跳出系統授權視窗，並把 App 加進「輔助使用」清單。
            // 鍵值即 kAXTrustedCheckOptionPrompt；Swift 6 不允許直接讀這個可變的 C 全域變數。
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    private func updateIcon() {
        let (symbol, description) = if !keepAwake.isRunning {
            ("cup.and.saucer", strings.statusPaused)
        } else if keepAwake.canPostEvents {
            ("cup.and.saucer.fill", strings.statusRunning)
        } else {
            ("exclamationmark.triangle", strings.needsPermission)
        }
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        statusItem?.button?.toolTip = description
    }

    @objc private func toggleRunning() {
        if keepAwake.isRunning {
            keepAwake.stop()
        } else {
            start()
        }
    }

    @objc private func selectIdleThreshold(_ sender: NSMenuItem) {
        keepAwake.idleThreshold = TimeInterval(sender.tag)
        UserDefaults.standard.set(keepAwake.idleThreshold, forKey: Self.idleThresholdKey)
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                // 已登記但被使用者在系統設定關掉，只能請使用者自己打開。
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                // 使用者曾在系統設定關掉、或受管理的 Mac 要求核准時，登記成功後仍需手動打開。
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = strings.openAtLoginFailed
            alert.informativeText = error.localizedDescription
            // 沒有 Dock 圖示的 App 要先啟用，對話框才會出現在最前面。
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
    }
}

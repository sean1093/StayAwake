import AppKit
import StayAwakeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let idleThresholdKey = "idleThreshold"
    private static let idleThresholdChoices: [TimeInterval] = [30, 60, 120, 240]
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    private let strings = Strings.current
    private let keepAwake: KeepAwake
    private var statusItem: NSStatusItem?

    override init() {
        UserDefaults.standard.register(defaults: [Self.idleThresholdKey: 60.0])
        keepAwake = KeepAwake(idleThreshold: UserDefaults.standard.double(forKey: Self.idleThresholdKey))
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
        for seconds in Self.idleThresholdChoices {
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

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
    }
}

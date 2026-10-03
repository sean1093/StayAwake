import AppKit
import ApplicationServices

/// 讓 Mac 維持「有人在用」的狀態：
/// - 執行期間持有 display-sleep assertion，螢幕與系統都不會因閒置而休眠。
/// - 使用者閒置超過 `idleThreshold` 時送出滑鼠移動事件，把系統閒置計時器歸零；
///   Teams 判斷「離開」、螢幕保護程式啟動都是看這個計時器。
@MainActor
public final class KeepAwake: NSObject {
    /// 與系統互動的部分；測試時換成假的實作。
    public struct Environment {
        /// 距離上次鍵盤或滑鼠輸入的秒數。
        public var idleSeconds: @MainActor () -> TimeInterval
        /// 是否已取得「輔助使用」權限。
        public var isTrusted: @MainActor () -> Bool
        /// 移動滑鼠，讓系統閒置計時器歸零。
        public var nudge: @MainActor () -> Void

        public init(
            idleSeconds: @escaping @MainActor () -> TimeInterval,
            isTrusted: @escaping @MainActor () -> Bool,
            nudge: @escaping @MainActor () -> Void
        ) {
            self.idleSeconds = idleSeconds
            self.isTrusted = isTrusted
            self.nudge = nudge
        }

        public static var system: Environment {
            Environment(
                idleSeconds: { KeepAwake.systemIdleSeconds() },
                // 用 AXIsProcessTrusted 而非 CGPreflightPostEventAccess：後者結果會被快取，
                // 使用者在系統設定打開開關後，不重開 App 就不會更新。
                isTrusted: { AXIsProcessTrusted() },
                nudge: { KeepAwake.jiggle() }
            )
        }
    }

    private static let pollInterval: TimeInterval = 5
    private static let anyInputEvent = CGEventType(rawValue: ~0)!

    /// 使用者閒置超過幾秒就移動滑鼠；要小於 Teams 判定「離開」的 5 分鐘。
    public var idleThreshold: TimeInterval
    /// `isRunning` 或 `canPostEvents` 改變時呼叫。
    public var onStateChange: (@MainActor () -> Void)?

    public private(set) var lastJiggle: Date?
    /// 送出滑鼠事件需要「輔助使用」權限；沒有權限時系統會默默丟掉事件。
    public private(set) var canPostEvents: Bool

    private let environment: Environment
    private var activity: NSObjectProtocol?
    private var timer: Timer?

    public var isRunning: Bool { activity != nil }

    public init(idleThreshold: TimeInterval, environment: Environment = .system) {
        self.idleThreshold = idleThreshold
        self.environment = environment
        canPostEvents = environment.isTrusted()
        super.init()
    }

    public func start() {
        guard activity == nil else { return }
        // .idleDisplaySleepDisabled 建立 PreventUserIdleDisplaySleep assertion；
        // .userInitiated 擋住系統閒置休眠，也避免 App Nap 延遲下面的計時器。
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleDisplaySleepDisabled],
            reason: "StayAwake: keep display awake" // 顯示在 `pmset -g assertions`
        )
        let timer = Timer(
            timeInterval: Self.pollInterval, target: self, selector: #selector(tick), userInfo: nil, repeats: true
        )
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        onStateChange?()
    }

    public func stop() {
        guard let activity else { return }
        timer?.invalidate()
        timer = nil
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
        onStateChange?()
    }

    public func refreshPermission() {
        let granted = environment.isTrusted()
        guard granted != canPostEvents else { return }
        canPostEvents = granted
        onStateChange?()
    }

    @objc func tick() {
        refreshPermission()
        guard isRunning, canPostEvents, environment.idleSeconds() >= idleThreshold else { return }
        environment.nudge()
        lastJiggle = Date()
    }

    private static func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEvent)
    }

    /// 在 HID 層送出「右移 1 像素、再移回原位」兩個事件：
    /// 系統閒置計時器歸零，游標停回原處，不干擾畫面。
    private static func jiggle() {
        guard let origin = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for point in [CGPoint(x: origin.x + 1, y: origin.y), origin] {
            CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }
}

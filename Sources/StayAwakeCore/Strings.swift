import Foundation

/// App 支援的介面語言。
public enum Language: Sendable, Equatable {
    case english
    case traditionalChinese

    /// 依使用者在系統設定的語言偏好順序，挑第一個支援的語言；都不支援就用英文。
    /// 所有中文（含簡體）都用繁體中文，對中文使用者來說比英文好讀。
    public static func preferred(from languages: [String] = Locale.preferredLanguages) -> Language {
        for language in languages.map({ $0.lowercased() }) {
            if language == "zh" || language.hasPrefix("zh-") || language.hasPrefix("zh_") {
                return .traditionalChinese
            }
            if language == "en" || language.hasPrefix("en-") || language.hasPrefix("en_") {
                return .english
            }
        }
        return .english
    }
}

/// 所有顯示給使用者的文字。
/// 寫在程式裡而不用 .lproj：build.sh 手動組 .app，SwiftPM 的資源 bundle 放在 App 根目錄會破壞簽章。
public struct Strings: Sendable, Equatable {
    public let statusRunning: String
    public let statusPaused: String
    /// `%@` 換成時間。
    public let lastNudgeFormat: String
    public let keepAwake: String
    public let keepAwakeFor: String
    /// `%@` 換成結束時間。
    public let activeUntilFormat: String
    public let idleThresholdMenu: String
    public let permissionMissing: String
    public let openAccessibilitySettings: String
    public let openAtLogin: String
    public let openAtLoginFailed: String
    public let quit: String
    public let needsPermission: String
    let secondsFormat: String
    let oneMinute: String
    let minutesFormat: String
    let oneHour: String
    let hoursFormat: String

    public static let english = Strings(
        statusRunning: "StayAwake is running",
        statusPaused: "StayAwake is paused",
        lastNudgeFormat: "Last mouse nudge: %@",
        keepAwake: "Keep Awake",
        keepAwakeFor: "Keep Awake For",
        activeUntilFormat: "Until %@",
        idleThresholdMenu: "Nudge Mouse After Idle For",
        permissionMissing: "⚠️ Accessibility not granted, the mouse won't move",
        openAccessibilitySettings: "Open Accessibility Settings…",
        openAtLogin: "Open at Login",
        openAtLoginFailed: "Couldn't change Open at Login",
        quit: "Quit StayAwake",
        needsPermission: "StayAwake needs Accessibility permission",
        secondsFormat: "%ld seconds",
        oneMinute: "1 minute",
        minutesFormat: "%ld minutes",
        oneHour: "1 hour",
        hoursFormat: "%ld hours"
    )

    public static let traditionalChinese = Strings(
        statusRunning: "StayAwake 運作中",
        statusPaused: "StayAwake 已暫停",
        lastNudgeFormat: "上次移動滑鼠：%@",
        keepAwake: "保持清醒",
        keepAwakeFor: "保持清醒一段時間",
        activeUntilFormat: "持續到 %@",
        idleThresholdMenu: "閒置多久後移動滑鼠",
        permissionMissing: "⚠️ 尚未授權「輔助使用」，滑鼠不會移動",
        openAccessibilitySettings: "開啟「輔助使用」設定…",
        openAtLogin: "登入時自動開啟",
        openAtLoginFailed: "無法變更「登入時自動開啟」",
        quit: "結束 StayAwake",
        needsPermission: "StayAwake 需要「輔助使用」權限",
        secondsFormat: "%ld 秒",
        oneMinute: "1 分鐘",
        minutesFormat: "%ld 分鐘",
        oneHour: "1 小時",
        hoursFormat: "%ld 小時"
    )

    public static func `for`(_ language: Language) -> Strings {
        switch language {
        case .english: english
        case .traditionalChinese: traditionalChinese
        }
    }

    /// 依系統語言偏好選擇的文字。
    public static var current: Strings { .for(.preferred()) }

    public func lastNudge(_ time: String) -> String {
        String(format: lastNudgeFormat, time)
    }

    public func activeUntil(_ time: String) -> String {
        String(format: activeUntilFormat, time)
    }

    /// 限時選項的標題，例如「1 hour」、「4 小時」。
    public func durationTitle(seconds: TimeInterval) -> String {
        let seconds = Int(seconds)
        guard seconds >= 3600, seconds % 3600 == 0 else { return idleThresholdTitle(seconds: TimeInterval(seconds)) }
        let hours = seconds / 3600
        return hours == 1 ? oneHour : String(format: hoursFormat, hours)
    }

    /// 閒置時間選項的標題，例如「30 seconds」、「2 分鐘」。
    public func idleThresholdTitle(seconds: TimeInterval) -> String {
        let seconds = Int(seconds)
        if seconds < 60 || seconds % 60 != 0 {
            return String(format: secondsFormat, seconds)
        }
        let minutes = seconds / 60
        return minutes == 1 ? oneMinute : String(format: minutesFormat, minutes)
    }
}

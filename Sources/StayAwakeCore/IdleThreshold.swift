import Foundation

/// 「閒置多久後移動滑鼠」的可選值。
public enum IdleThreshold {
    /// 都小於 Teams 與螢幕保護程式常見的 5 分鐘閒置判定。
    public static let choices: [TimeInterval] = [30, 60, 120, 240]
    public static let defaultValue: TimeInterval = 60

    /// 把任意值（例如使用者用 `defaults write` 寫入的）換成最接近的可選值；
    /// 不是正數（含 `UserDefaults` 讀不到數字時回傳的 0）就用預設值。
    public static func sanitized(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite, value > 0 else { return defaultValue }
        return choices.min { abs($0 - value) < abs($1 - value) }!
    }
}

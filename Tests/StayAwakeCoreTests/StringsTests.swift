import XCTest
@testable import StayAwakeCore

final class StringsTests: XCTestCase {
    func testChinesePreferencesPickTraditionalChinese() {
        for preference in ["zh-Hant-TW", "zh-TW", "zh-Hant", "zh-HK", "zh-Hans-CN", "zh", "ZH-TW", "zh_TW"] {
            XCTAssertEqual(Language.preferred(from: [preference]), .traditionalChinese, preference)
        }
    }

    func testEnglishAndUnsupportedPreferencesPickEnglish() {
        for preference in ["en-US", "en", "en-GB", "ja-JP", "de-DE", "fr"] {
            XCTAssertEqual(Language.preferred(from: [preference]), .english, preference)
        }
        XCTAssertEqual(Language.preferred(from: []), .english)
    }

    func testFirstSupportedPreferenceWins() {
        XCTAssertEqual(Language.preferred(from: ["ja-JP", "zh-Hant-TW", "en-US"]), .traditionalChinese)
        XCTAssertEqual(Language.preferred(from: ["ja-JP", "en-US", "zh-Hant-TW"]), .english)
        XCTAssertEqual(Language.preferred(from: ["en-US", "zh-Hant-TW"]), .english)
    }

    func testLanguagesWithZhOrEnPrefixAreNotMisdetected() {
        // "zu"（祖魯語）、"enm" 不是中文或英文。
        XCTAssertEqual(Language.preferred(from: ["zu-ZA", "zh-TW"]), .traditionalChinese)
        XCTAssertEqual(Language.preferred(from: ["enm", "zh-TW"]), .traditionalChinese)
    }

    func testStringsForLanguage() {
        XCTAssertEqual(Strings.for(.english), .english)
        XCTAssertEqual(Strings.for(.traditionalChinese), .traditionalChinese)
    }

    func testEveryStringIsTranslated() {
        for strings in [Strings.english, Strings.traditionalChinese] {
            for child in Mirror(reflecting: strings).children {
                let value = child.value as? String
                XCTAssertFalse(value?.isEmpty ?? true, "\(child.label ?? "?") is empty")
            }
        }
        let english = Mirror(reflecting: Strings.english).children.map { $0.value as? String }
        let chinese = Mirror(reflecting: Strings.traditionalChinese).children.map { $0.value as? String }
        for (label, pair) in zip(Mirror(reflecting: Strings.english).children.map(\.label), zip(english, chinese)) {
            XCTAssertNotEqual(pair.0, pair.1, "\(label ?? "?") is not translated")
        }
    }

    func testLastNudge() {
        XCTAssertEqual(Strings.english.lastNudge("10:00:00"), "Last mouse nudge: 10:00:00")
        XCTAssertEqual(Strings.traditionalChinese.lastNudge("10:00:00"), "上次移動滑鼠：10:00:00")
    }

    func testIdleThresholdTitles() {
        XCTAssertEqual(Strings.english.idleThresholdTitle(seconds: 30), "30 seconds")
        XCTAssertEqual(Strings.english.idleThresholdTitle(seconds: 60), "1 minute")
        XCTAssertEqual(Strings.english.idleThresholdTitle(seconds: 120), "2 minutes")
        XCTAssertEqual(Strings.english.idleThresholdTitle(seconds: 240), "4 minutes")
        XCTAssertEqual(Strings.english.idleThresholdTitle(seconds: 90), "90 seconds")
        XCTAssertEqual(Strings.traditionalChinese.idleThresholdTitle(seconds: 30), "30 秒")
        XCTAssertEqual(Strings.traditionalChinese.idleThresholdTitle(seconds: 60), "1 分鐘")
        XCTAssertEqual(Strings.traditionalChinese.idleThresholdTitle(seconds: 240), "4 分鐘")
    }

    func testDurationTitles() {
        XCTAssertEqual(Strings.english.durationTitle(seconds: 3600), "1 hour")
        XCTAssertEqual(Strings.english.durationTitle(seconds: 7200), "2 hours")
        XCTAssertEqual(Strings.english.durationTitle(seconds: 28800), "8 hours")
        XCTAssertEqual(Strings.english.durationTitle(seconds: 1800), "30 minutes")
        XCTAssertEqual(Strings.traditionalChinese.durationTitle(seconds: 3600), "1 小時")
        XCTAssertEqual(Strings.traditionalChinese.durationTitle(seconds: 14400), "4 小時")
    }

    func testActiveUntil() {
        XCTAssertEqual(Strings.english.activeUntil("17:30"), "Until 17:30")
        XCTAssertEqual(Strings.traditionalChinese.activeUntil("17:30"), "持續到 17:30")
    }
}

import XCTest
@testable import StayAwakeCore

final class IdleThresholdTests: XCTestCase {
    func testChoicesAreKeptAsIs() {
        for choice in IdleThreshold.choices {
            XCTAssertEqual(IdleThreshold.sanitized(choice), choice)
        }
    }

    func testDefaultIsAChoice() {
        XCTAssertTrue(IdleThreshold.choices.contains(IdleThreshold.defaultValue))
    }

    func testAllChoicesAreUnderFiveMinutes() {
        XCTAssertTrue(IdleThreshold.choices.allSatisfy { $0 > 0 && $0 < 300 })
    }

    func testOtherValuesSnapToNearestChoice() {
        XCTAssertEqual(IdleThreshold.sanitized(1), 30)
        XCTAssertEqual(IdleThreshold.sanitized(50), 60)
        XCTAssertEqual(IdleThreshold.sanitized(100), 120)
        XCTAssertEqual(IdleThreshold.sanitized(200), 240)
        XCTAssertEqual(IdleThreshold.sanitized(600), 240)
    }

    func testInvalidValuesUseDefault() {
        for value in [0, -30, .nan, .infinity, -.infinity] as [TimeInterval] {
            XCTAssertEqual(IdleThreshold.sanitized(value), IdleThreshold.defaultValue, "\(value)")
        }
    }
}

import XCTest
@testable import StayAwakeCore

@MainActor
final class KeepAwakeTests: XCTestCase {
    /// 假的系統環境：測試直接設定閒置秒數與權限，並記錄滑鼠被移動幾次。
    @MainActor
    private final class FakeSystem {
        var idleSeconds: TimeInterval = 0
        var isTrusted = true
        var nudges = 0
        var now = Date(timeIntervalSinceReferenceDate: 0)

        var environment: KeepAwake.Environment {
            KeepAwake.Environment(
                idleSeconds: { self.idleSeconds },
                isTrusted: { self.isTrusted },
                nudge: { self.nudges += 1 },
                now: { self.now }
            )
        }
    }

    /// 計算 `onStateChange` 被呼叫幾次。
    @MainActor
    private final class Counter {
        var count = 0
    }

    private func makeKeepAwake(_ system: FakeSystem, idleThreshold: TimeInterval = 60) -> KeepAwake {
        KeepAwake(idleThreshold: idleThreshold, environment: system.environment)
    }

    func testStartAndStopToggleRunningAndNotify() {
        let keepAwake = makeKeepAwake(FakeSystem())
        let changes = Counter()
        keepAwake.onStateChange = { changes.count += 1 }

        XCTAssertFalse(keepAwake.isRunning)
        keepAwake.start()
        XCTAssertTrue(keepAwake.isRunning)
        XCTAssertEqual(changes.count, 1)

        keepAwake.start() // 重複呼叫不應再通知
        XCTAssertEqual(changes.count, 1)

        keepAwake.stop()
        XCTAssertFalse(keepAwake.isRunning)
        XCTAssertEqual(changes.count, 2)

        keepAwake.stop()
        XCTAssertEqual(changes.count, 2)
    }

    func testNudgesWhenIdleAtOrPastThreshold() {
        let system = FakeSystem()
        let keepAwake = makeKeepAwake(system, idleThreshold: 60)
        keepAwake.start()
        defer { keepAwake.stop() }

        system.idleSeconds = 59
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 0)
        XCTAssertNil(keepAwake.lastJiggle)

        system.idleSeconds = 60
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 1)
        XCTAssertNotNil(keepAwake.lastJiggle)

        system.idleSeconds = 600
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 2)
    }

    func testDoesNotNudgeWithoutPermission() {
        let system = FakeSystem()
        system.isTrusted = false
        system.idleSeconds = 600
        let keepAwake = makeKeepAwake(system)
        keepAwake.start()
        defer { keepAwake.stop() }

        XCTAssertFalse(keepAwake.canPostEvents)
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 0)
    }

    func testDoesNotNudgeWhenStopped() {
        let system = FakeSystem()
        system.idleSeconds = 600
        let keepAwake = makeKeepAwake(system)

        keepAwake.tick()
        XCTAssertEqual(system.nudges, 0)
    }

    func testIdleThresholdChangeTakesEffectImmediately() {
        let system = FakeSystem()
        system.idleSeconds = 45
        let keepAwake = makeKeepAwake(system, idleThreshold: 60)
        keepAwake.start()
        defer { keepAwake.stop() }

        keepAwake.tick()
        XCTAssertEqual(system.nudges, 0)

        keepAwake.idleThreshold = 30
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 1)
    }

    func testPermissionGrantedLaterIsPickedUpOnTick() {
        let system = FakeSystem()
        system.isTrusted = false
        system.idleSeconds = 600
        let keepAwake = makeKeepAwake(system)
        let changes = Counter()
        keepAwake.start()
        defer { keepAwake.stop() }
        keepAwake.onStateChange = { changes.count += 1 }

        system.isTrusted = true
        keepAwake.tick()
        XCTAssertTrue(keepAwake.canPostEvents)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(system.nudges, 1)
    }

    func testRefreshPermissionOnlyNotifiesOnChange() {
        let system = FakeSystem()
        let keepAwake = makeKeepAwake(system)
        let changes = Counter()
        keepAwake.onStateChange = { changes.count += 1 }

        keepAwake.refreshPermission()
        XCTAssertEqual(changes.count, 0)

        system.isTrusted = false
        keepAwake.refreshPermission()
        XCTAssertFalse(keepAwake.canPostEvents)
        XCTAssertEqual(changes.count, 1)

        keepAwake.refreshPermission()
        XCTAssertEqual(changes.count, 1)
    }

    func testStartWithoutDurationHasNoEndDate() {
        let keepAwake = makeKeepAwake(FakeSystem())
        keepAwake.start()
        defer { keepAwake.stop() }

        XCTAssertNil(keepAwake.endDate)
    }

    func testTimedStartStopsAtEndDate() {
        let system = FakeSystem()
        let keepAwake = makeKeepAwake(system)
        let changes = Counter()
        keepAwake.onStateChange = { changes.count += 1 }
        keepAwake.start(for: 3600)
        defer { keepAwake.stop() }

        XCTAssertEqual(keepAwake.endDate, system.now.addingTimeInterval(3600))
        XCTAssertEqual(changes.count, 1)

        system.now = system.now.addingTimeInterval(3599)
        keepAwake.tick()
        XCTAssertTrue(keepAwake.isRunning)

        system.now = system.now.addingTimeInterval(1)
        keepAwake.tick()
        XCTAssertFalse(keepAwake.isRunning)
        XCTAssertNil(keepAwake.endDate)
        XCTAssertEqual(changes.count, 2)
    }

    func testDoesNotNudgeOnceTimeIsUp() {
        let system = FakeSystem()
        system.idleSeconds = 600
        let keepAwake = makeKeepAwake(system)
        keepAwake.start(for: 60)
        defer { keepAwake.stop() }

        system.now = system.now.addingTimeInterval(120) // 例如闔上螢幕休眠後醒來
        keepAwake.tick()
        XCTAssertEqual(system.nudges, 0)
        XCTAssertFalse(keepAwake.isRunning)
    }

    func testStartWhileRunningReplacesEndDate() {
        let system = FakeSystem()
        let keepAwake = makeKeepAwake(system)
        let changes = Counter()
        keepAwake.onStateChange = { changes.count += 1 }
        keepAwake.start(for: 3600)
        defer { keepAwake.stop() }

        system.now = system.now.addingTimeInterval(600)
        keepAwake.start(for: 7200)
        XCTAssertEqual(keepAwake.endDate, system.now.addingTimeInterval(7200))
        XCTAssertEqual(changes.count, 2)

        keepAwake.start() // 改成不限時
        XCTAssertNil(keepAwake.endDate)
        XCTAssertEqual(changes.count, 3)

        keepAwake.start() // 沒有變化就不通知
        XCTAssertEqual(changes.count, 3)
    }

    func testStopClearsEndDate() {
        let keepAwake = makeKeepAwake(FakeSystem())
        keepAwake.start(for: 3600)
        keepAwake.stop()

        XCTAssertNil(keepAwake.endDate)
    }

    func testLastJiggleUsesEnvironmentClock() {
        let system = FakeSystem()
        system.idleSeconds = 600
        let keepAwake = makeKeepAwake(system)
        keepAwake.start()
        defer { keepAwake.stop() }

        keepAwake.tick()
        XCTAssertEqual(keepAwake.lastJiggle, system.now)
    }

    func testTimedDurationsAreWholeHours() {
        XCTAssertFalse(KeepAwake.timedDurations.isEmpty)
        XCTAssertTrue(KeepAwake.timedDurations.allSatisfy { $0 > 0 && $0.truncatingRemainder(dividingBy: 3600) == 0 })
    }
}

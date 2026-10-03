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

        var environment: KeepAwake.Environment {
            KeepAwake.Environment(
                idleSeconds: { self.idleSeconds },
                isTrusted: { self.isTrusted },
                nudge: { self.nudges += 1 }
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
}

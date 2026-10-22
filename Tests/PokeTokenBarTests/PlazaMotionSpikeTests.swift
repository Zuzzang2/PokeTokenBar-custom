import XCTest
@testable import PokeTokenBar

// SPIKE: plaza motion — constant-speed walking, interpolated remotes, trailing follower.
final class PlazaMotionSpikeTests: XCTestCase {
    private func player(x: Double = 100, y: Double = 200) -> PlazaPlayer {
        PlazaPlayer(profile: PlazaProfile(id: "p", trainer: "t", speciesID: 1, shiny: false, leadName: "x"), x: x, y: y)
    }

    private func walk(_ p: PlazaPlayer, held: Set<PlazaFacing>, seconds: Double, fps: Double) -> PlazaPlayer {
        var p = p
        for _ in 0..<Int(seconds * fps) { p = PlazaMotion.walk(p, held: held, dt: 1 / fps) }
        return p
    }

    /// Distance depends on time held, not on how often keys repeat or ticks arrive.
    func testWalkSpeedIsIndependentOfTickRate() {
        let fast = walk(player(), held: [.right], seconds: 0.5, fps: 120)
        let slow = walk(player(), held: [.right], seconds: 0.5, fps: 30)
        XCTAssertEqual(fast.x - 100, PlazaMotion.walkSpeed * 0.5, accuracy: 0.5)
        XCTAssertEqual(fast.x, slow.x, accuracy: 0.5)
        XCTAssertEqual(fast.facing, .right)
    }

    func testDiagonalIsNotFaster() {
        let p = walk(player(), held: [.right, .up], seconds: 0.2, fps: 60)
        let moved = hypot(p.x - 100, p.y - 200)
        XCTAssertEqual(moved, PlazaMotion.walkSpeed * 0.2, accuracy: 0.5)
    }

    /// A remote update moves the target; the drawn position eases toward it instead of jumping.
    func testRemoteInterpolatesTowardTarget() {
        var p = player()
        p.x = 140                                        // network says: now at 140
        p = PlazaMotion.follow(p, dt: 1 / 60)
        XCTAssertGreaterThan(p.shownX, 100)
        XCTAssertLessThan(p.shownX, 140, "must not teleport on the first frame")
        for _ in 0..<30 { p = PlazaMotion.follow(p, dt: 1 / 60) }
        XCTAssertEqual(p.shownX, 140, accuracy: 1)
        XCTAssertEqual(p.facing, .right)
    }

    func testFarJumpSnaps() {
        var p = player()
        p.x = 380
        p = PlazaMotion.follow(p, dt: 1 / 60)
        XCTAssertEqual(p.shownX, 380)
    }

    func testFollowerTrailsBehind() {
        let p = walk(player(), held: [.right], seconds: 0.3, fps: 60)
        XCTAssertLessThan(p.followerX, p.shownX - 10, "follower stays behind a right-walking trainer")
        let settled = (0..<120).reduce(p) { q, _ in PlazaMotion.follow(q, dt: 1 / 60) }
        XCTAssertEqual(settled.followerX, settled.shownX - 28, accuracy: 1)
    }

    func testWalkingFramesAdvanceWithDistanceOnly() {
        let moving = walk(player(), held: [.right], seconds: 0.5, fps: 60)
        XCTAssertTrue(moving.moving)
        XCTAssertGreaterThan(moving.walked, 30)
        let stopped = PlazaMotion.walk(moving, held: [], dt: 1 / 60)
        XCTAssertFalse(stopped.moving)
        XCTAssertEqual(stopped.walked, moving.walked)
    }

    /// Walking into the fountain slides along it instead of sticking.
    func testBlockedAxisStillSlidesOnTheOther() {
        let size = PlazaSession.size
        // Left of the fountain, holding right + down: x is blocked, y keeps going.
        let start = player(x: size.width * 0.5 - size.width * 0.13 - 2, y: size.height * 0.54)
        let p = walk(start, held: [.right, .down], seconds: 0.2, fps: 60)
        XCTAssertGreaterThan(p.y, start.y + 5)
        XCTAssertTrue(PlazaSession.isWalkable(x: p.x, y: p.y))
    }
}

// SPIKE: plaza zoom to the window size.
final class PlazaLayoutSpikeTests: XCTestCase {
    func testWideWindowScalesPlazaUpByWidth() {
        let k = PlazaLayout.scale(available: CGSize(width: 800, height: 2000), reservedHeight: 200)
        XCTAssertEqual(k, 2, accuracy: 0.001)
    }

    func testShortWindowIsLimitedByHeight() {
        let k = PlazaLayout.scale(available: CGSize(width: 2000, height: 734), reservedHeight: 200)
        XCTAssertEqual(k, 2, accuracy: 0.01)          // (734 - 200) / 267
    }

    func testNeverShrinksBelowNativeSize() {
        XCTAssertEqual(PlazaLayout.scale(available: CGSize(width: 300, height: 300), reservedHeight: 200), 1)
    }
}

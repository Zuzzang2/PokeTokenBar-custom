import XCTest
@testable import PokeTokenBar

// SPIKE: plaza motion — constant-speed walking, interpolated remotes, trailing follower.
final class PlazaMotionSpikeTests: XCTestCase {
    private func player(x: Double = PlazaMap.spawnCenter.x, y: Double = PlazaMap.spawnCenter.y) -> PlazaPlayer {
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
        XCTAssertEqual(fast.x - PlazaMap.spawnCenter.x, PlazaMotion.walkSpeed * 0.5, accuracy: 0.5)
        XCTAssertEqual(fast.x, slow.x, accuracy: 0.5)
        XCTAssertEqual(fast.facing, .right)
    }

    /// Right-click walking covers ground at walk speed and lands exactly on the target.
    func testWalkTowardTargetStopsExactlyOnIt() {
        let start = PlazaMap.spawnCenter
        let target = CGPoint(x: start.x + 20, y: start.y)
        var p = player()
        for _ in 0..<60 { p = PlazaMotion.walk(p, held: [], dt: 1 / 60, toward: target) }
        XCTAssertEqual(p.x, target.x, accuracy: 0.001)
        XCTAssertEqual(p.y, target.y, accuracy: 0.001)
        XCTAssertEqual(p.facing, .right)
    }

    func testHeldKeyOverridesTarget() {
        let start = PlazaMap.spawnCenter
        let p = PlazaMotion.walk(player(), held: [.left], dt: 0.1, toward: CGPoint(x: start.x + 50, y: start.y))
        XCTAssertLessThan(p.x, start.x)
    }

    func testDiagonalIsNotFaster() {
        let p = walk(player(), held: [.right, .up], seconds: 0.2, fps: 60)
        let moved = hypot(p.x - PlazaMap.spawnCenter.x, p.y - PlazaMap.spawnCenter.y)
        XCTAssertEqual(moved, PlazaMotion.walkSpeed * 0.2, accuracy: 0.5)
    }

    /// A remote update moves the target; the drawn position eases toward it instead of jumping.
    func testRemoteInterpolatesTowardTarget() {
        var p = player(x: 100, y: 200)
        p.x = 140                                        // network says: now at 140
        p = PlazaMotion.follow(p, dt: 1 / 60)
        XCTAssertGreaterThan(p.shownX, 100)
        XCTAssertLessThan(p.shownX, 140, "must not teleport on the first frame")
        for _ in 0..<30 { p = PlazaMotion.follow(p, dt: 1 / 60) }
        XCTAssertEqual(p.shownX, 140, accuracy: 1)
        XCTAssertEqual(p.facing, .right)
    }

    func testFarJumpSnaps() {
        var p = player(x: 100, y: 200)
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
        let f = PlazaMap.fountain
        // Just left of the fountain, holding right + down: x is blocked, y keeps going.
        let start = player(x: f.center.x - f.radius.width - 2, y: f.center.y)
        XCTAssertTrue(PlazaMap.isWalkable(x: start.x, y: start.y))
        let p = walk(start, held: [.right, .down], seconds: 0.2, fps: 60)
        XCTAssertGreaterThan(p.y, start.y + 5)
        XCTAssertTrue(PlazaMap.isWalkable(x: p.x, y: p.y))
    }
}

// SPIKE: town map collisions and the follow camera.
final class PlazaMapSpikeTests: XCTestCase {
    func testSpawnAndPlazaRingAreWalkable() {
        XCTAssertTrue(PlazaMap.isWalkable(x: PlazaMap.spawnCenter.x, y: PlazaMap.spawnCenter.y))
        for _ in 0..<50 {
            let p = PlazaMap.randomSpawn()
            XCTAssertTrue(PlazaMap.isWalkable(x: p.x, y: p.y))
        }
    }

    func testFountainHousesAndPondBlock() {
        let f = PlazaMap.fountain
        XCTAssertFalse(PlazaMap.isWalkable(x: f.center.x, y: f.center.y))
        for house in PlazaMap.houses {
            XCTAssertFalse(PlazaMap.isWalkable(x: house.midX, y: house.midY))
        }
        XCTAssertFalse(PlazaMap.isWalkable(x: PlazaMap.pond.midX, y: PlazaMap.pond.midY))
    }

    func testBridgeCrossesThePond() {
        XCTAssertTrue(PlazaMap.isWalkable(x: PlazaMap.bridge.midX, y: PlazaMap.bridge.midY))
    }

    func testOutsideTheTreeLineBlocks() {
        XCTAssertFalse(PlazaMap.isWalkable(x: 5, y: 5))
        XCTAssertFalse(PlazaMap.isWalkable(x: PlazaMap.size.width - 5, y: PlazaMap.size.height - 5))
    }

    /// The camera centers on the player but never shows past the map edge.
    func testCameraFollowsAndClampsToTheMap() {
        let view = CGSize(width: 400, height: 300)
        let mid = PlazaLayout.camera(center: CGPoint(x: 512, y: 340), viewport: view)
        XCTAssertEqual(mid.x, 312, accuracy: 0.01)
        XCTAssertEqual(mid.y, 190, accuracy: 0.01)
        let corner = PlazaLayout.camera(center: CGPoint(x: 0, y: 0), viewport: view)
        XCTAssertEqual(corner, .zero)
        let far = PlazaLayout.camera(center: CGPoint(x: 5000, y: 5000), viewport: view)
        XCTAssertEqual(far.x, PlazaMap.size.width - 400, accuracy: 0.01)
        XCTAssertEqual(far.y, PlazaMap.size.height - 300, accuracy: 0.01)
    }

    func testViewportLargerThanMapShowsWholeMap() {
        let p = PlazaLayout.camera(center: CGPoint(x: 900, y: 600), viewport: CGSize(width: 5000, height: 5000))
        XCTAssertEqual(p, .zero)
    }
}

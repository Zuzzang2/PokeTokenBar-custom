import XCTest
@testable import PokeTokenBar

// SPIKE: replays a scripted solution for every 메아리 level, plus the mechanics the puzzles rely on.
final class EchoCoreTests: XCTestCase {
    private typealias Segments = [(Int, String)]

    private func script(_ segments: Segments) -> (Int) -> EchoInput {
        let timeline = segments.flatMap { n, keys in
            Array(repeating: EchoInput(left: keys.contains("l"), right: keys.contains("r"), jump: keys.contains("j")), count: n)
        }
        return { f in f < timeline.count ? timeline[f] : .none }
    }

    /// Plays every loop in order; each finished loop becomes an echo for the next.
    private func play(_ level: EchoLevel, _ loops: [Segments]) -> (echoes: [EchoRecording], last: EchoWorld?) {
        loops.reduce(into: (echoes: [EchoRecording](), last: EchoWorld?.none)) { acc, segs in
            let r = EchoCore.simulate(level, echoes: acc.echoes, input: script(segs))
            acc.echoes.append(r.rec)
            acc.last = r.world
        }
    }

    private func level(_ name: String) -> EchoLevel { EchoLevels.all.first { $0.name == name }! }

    private let solutions: [String: [Segments]] = [
        "wake": [[(45, "r"), (15, "rj"), (55, "r"), (15, "rj"), (46, "r"), (15, "rj"), (100, "r")]],
        "echo": [[(34, "r")], [(300, "r")]],
        "stair": [[(200, "r")], [(100, "r"), (15, "rj"), (10, "r"), (20, "rj"), (200, "r")]],
        "relay": [[(18, "r")], [(130, "r")], [(400, "r")]],
        "tower": [
            [(200, "r")],
            [(100, "r"), (15, "rj"), (200, "r")],
            [(100, "r"), (20, "rj"), (25, "r"), (20, "rj"), (25, "r"), (20, "rj"), (200, "r")],
        ],
        "sacrifice": [
            [(300, "r")],
            [(30, "r"), (15, "rj"), (300, "r")],
            [(30, "r"), (15, "rj"), (120, "r"), (15, "rj"), (10, "r"), (20, "rj"), (200, "r")],
        ],
        "chorus": [
            [(28, "r")],
            [(30, "r"), (15, "rj"), (200, "r")],
            [(30, "r"), (15, "rj"), (30, "r"), (15, "rj"), (10, "r"), (20, "rj"), (13, "r")],
            [(30, "r"), (15, "rj"), (30, "r"), (15, "rj"), (10, "r"), (20, "rj"), (300, "r")],
        ],
    ]

    func testEveryLevelParses() throws {
        for def in EchoLevels.defs + [EchoLevels.title] {
            let lvl = try EchoCore.parse(def)
            XCTAssertEqual(lvl.cells.count, EchoCore.rows, def.name)
        }
    }

    func testParseRejectsMalformedRow() {
        let bad = EchoCore.LevelDef(name: "bad", title: "", hint: "", seconds: 1, echoes: 0,
                                    map: Array(EchoLevels.title.map.prefix(17)) + ["###"])
        XCTAssertThrowsError(try EchoCore.parse(bad)) { error in
            XCTAssertEqual(error as? EchoCore.ParseError, .cols("bad", row: 17, count: 3))
        }
    }

    func testEveryLevelHasASolutionWithinItsEchoBudget() {
        for lvl in EchoLevels.all {
            guard let loops = solutions[lvl.name] else { return XCTFail("missing solution for \(lvl.name)") }
            XCTAssertLessThanOrEqual(loops.count - 1, lvl.maxEchoes, lvl.name)
            XCTAssertEqual(play(lvl, loops).last?.status, .won, lvl.name)
        }
    }

    func testALoneJumpCannotClearTheStairWall() {
        XCTAssertEqual(play(level("stair"), [solutions["stair"]![1]]).last?.status, .timeout)
    }

    func testOneEchoIsNotEnoughForTheTower() {
        let t = solutions["tower"]!
        XCTAssertEqual(play(level("tower"), [t[0], t[2]]).last?.status, .timeout)
    }

    func testDoorStaysShutOnceThePlateIsReleased() {
        let last = play(level("echo"), [solutions["echo"]![1]]).last
        XCTAssertEqual(last?.status, .timeout)
        XCTAssertEqual(last?.open["a"], false)
    }

    func testChorusDoorNeedsEveryPlateHeldAtOnce() {
        let c = solutions["chorus"]!
        XCTAssertNotEqual(play(level("chorus"), [c[0], c[1], c[3]]).last?.status, .won)
    }

    // Regression (web prototype): a parked echo walled off the corridor for a player who waited at spawn.
    func testPlayerWhoWaitsWalksThroughAParkedEcho() {
        let lvl = level("echo")
        let first = EchoCore.simulate(lvl, echoes: [], input: script([(34, "r")])).rec
        let r = EchoCore.simulate(lvl, echoes: [first], input: script([(90, ""), (300, "r")]))
        XCTAssertEqual(r.world.status, .won)
    }

    func testJumpingUpThroughAnEchoLandsOnItsHead() {
        let lvl = EchoLevels.titleRoom
        let head = EchoFrame(x: lvl.spawn.x, y: lvl.spawn.y - 40, facing: 1)
        let frames = (0..<300).map { $0 < 5 ? EchoFrame(x: 400, y: lvl.spawn.y, facing: 1) : head }
        let r = EchoCore.simulate(lvl, echoes: [EchoRecording(frames: frames, end: .timeout)], input: script([(10, ""), (20, "j")]))
        XCTAssertEqual(r.rec.frames[100].y, head.y - EchoCore.P.h)
    }

    func testStandingOnAMovingEchoCarriesThePlayer() {
        let lvl = EchoLevels.titleRoom
        let gx = lvl.spawn.x + 40
        let frames = (0..<400).map { EchoFrame(x: $0 < 120 ? gx : gx + 2 * Double($0 - 120), y: lvl.spawn.y, facing: 1) }
        let r = EchoCore.simulate(lvl, echoes: [EchoRecording(frames: frames, end: .timeout)],
                                  input: script([(5, "r"), (10, "rj"), (8, "j")]))
        XCTAssertEqual(r.rec.frames[119].y, lvl.spawn.y - EchoCore.P.h)
        XCTAssertEqual(r.rec.frames[200].x - r.rec.frames[119].x, frames[200].x - frames[119].x, accuracy: 0.001)
    }

    func testRewoundEchoHoldsItsSpotAndDeadEchoVanishes() {
        let held = EchoRecording(frames: [EchoFrame(x: 1, y: 2, facing: 1), EchoFrame(x: 3, y: 4, facing: 1)], end: .rewind)
        let dead = EchoRecording(frames: [EchoFrame(x: 1, y: 2, facing: 1)], end: .dead)
        let g = EchoCore.ghosts([held, dead], at: 50)
        XCTAssertEqual(g[0], held.frames[1])
        XCTAssertNil(g[1])
    }

    func testFallingIntoSpikesKills() {
        let last = play(level("wake"), [[(50, "r"), (20, "rj"), (60, "r"), (20, "rj"), (100, "r")]]).last
        XCTAssertEqual(last?.status, .dead)
        XCTAssertEqual(last?.cause, .spike)
    }

    // Review finding (web prototype): a full echo budget silently dropped the oldest echo on the next death.
    func testFullBudgetKeepsEveryEchoAndReportsNotAdded() {
        let a = EchoRecording(frames: [EchoFrame(x: 0, y: 0, facing: 1)], end: .rewind)
        let b = EchoRecording(frames: [EchoFrame(x: 9, y: 9, facing: 1)], end: .dead)
        let full = EchoCore.commit(b, to: [a], max: 1)
        XCTAssertEqual(full.echoes, [a])
        XCTAssertFalse(full.added)
        let room = EchoCore.commit(b, to: [a], max: 2)
        XCTAssertEqual(room.echoes, [a, b])
        XCTAssertTrue(room.added)
        XCTAssertFalse(EchoCore.commit(b, to: [], max: 0).added)
    }

    // Co-op: a live teammate standing on the plate holds the door for me, with no echoes at all.
    func testLiveTeammateOnThePlateOpensTheDoor() {
        let lvl = level("echo")
        let mate = EchoFrame(x: 186, y: lvl.spawn.y, facing: 1)
        var w = EchoCore.makeWorld(lvl, echoes: [])
        while w.status == .play { w = EchoCore.step(w, EchoInput(right: true), peers: [mate]) }
        XCTAssertEqual(w.status, .won)
    }

    func testPlayerCanStandOnALiveTeammatesHead() {
        let lvl = level("stair")
        let mate = EchoFrame(x: 462, y: lvl.spawn.y, facing: 1)
        let solo = EchoCore.simulate(lvl, echoes: [], input: script([(100, "r"), (15, "rj"), (10, "r"), (20, "rj"), (200, "r")]))
        XCTAssertEqual(solo.world.status, .timeout)
        var w = EchoCore.makeWorld(lvl, echoes: [])
        let input = script([(100, "r"), (15, "rj"), (10, "r"), (20, "rj"), (200, "r")])
        while w.status == .play { w = EchoCore.step(w, input(w.frame), peers: [mate]) }
        XCTAssertEqual(w.status, .won)
    }
}

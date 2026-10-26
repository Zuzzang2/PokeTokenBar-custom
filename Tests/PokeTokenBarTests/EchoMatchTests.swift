import XCTest
@testable import PokeTokenBar

// SPIKE: host rules for co-op 메아리 loops.
final class EchoMatchTests: XCTestCase {
    private func run(_ owner: String, _ end: EchoEnd = .rewind) -> EchoOwned {
        EchoOwned(owner: owner, speciesID: 25, isShiny: false,
                  rec: EchoRecording(frames: [EchoFrame(x: 0, y: 0, facing: 1)], end: end))
    }

    func testLevelClearsOnlyWhenEveryPlayerReachesTheExit() {
        var m = EchoMatch(players: ["a", "b"], level: 0)
        m.playerExited("a")
        XCTAssertFalse(m.isCleared)
        m.playerExited("b")
        XCTAssertTrue(m.isCleared)
    }

    func testLoopIsOverWhenEveryoneIsDoneWithoutAClear() {
        var m = EchoMatch(players: ["a", "b"], level: 0)
        m.playerExited("a")
        XCTAssertFalse(m.allDone)
        m.playerDied("b")
        XCTAssertTrue(m.allDone)
        XCTAssertFalse(m.isCleared)
    }

    func testEachPlayerHasTheirOwnEchoBudget() {
        var m = EchoMatch(players: ["a", "b"], level: 0)
        m.beginCollecting()
        m.receive(run("a"))
        XCTAssertFalse(m.hasEveryRecording)
        m.receive(run("b"))
        XCTAssertTrue(m.hasEveryRecording)
        XCTAssertEqual(m.startNextLoop(maxPerPlayer: 1), [])
        XCTAssertEqual(m.echoCount(of: "a"), 1)
        XCTAssertEqual(m.echoCount(of: "b"), 1)

        // Both budgets are full: the next runs are reported, and the existing echoes stay.
        m.beginCollecting()
        m.receive(run("a", .dead))
        m.receive(run("b", .dead))
        XCTAssertEqual(m.startNextLoop(maxPerPlayer: 1), ["a", "b"])
        XCTAssertEqual(m.echoes.map(\.rec.end), [.rewind, .rewind])
    }

    func testNoEchoesAreKeptOnALevelWithoutABudget() {
        var m = EchoMatch(players: ["a"], level: 0)
        m.beginCollecting()
        m.receive(run("a"))
        XCTAssertEqual(m.startNextLoop(maxPerPlayer: 0), [])
        XCTAssertTrue(m.echoes.isEmpty)
    }

    func testALeavingPlayerNoLongerBlocksTheClearOrTheCollection() {
        var m = EchoMatch(players: ["a", "b"], level: 0)
        m.playerExited("a")
        m.playerLeft("b")
        XCTAssertTrue(m.isCleared)

        var n = EchoMatch(players: ["a", "b"], level: 0)
        n.beginCollecting()
        n.receive(run("a"))
        n.playerLeft("b")
        XCTAssertTrue(n.hasEveryRecording)
    }

    func testEraseDropsOnlyThatPlayersLatestEcho() {
        var m = EchoMatch(players: ["a", "b"], level: 0)
        for _ in 0..<2 {
            m.beginCollecting()
            m.receive(run("a"))
            m.receive(run("b"))
            m.startNextLoop(maxPerPlayer: 2)
        }
        m.erase(lastOf: "a")
        XCTAssertEqual(m.echoCount(of: "a"), 1)
        XCTAssertEqual(m.echoCount(of: "b"), 2)
    }

    func testEventsDuringCollectionAreIgnoredAndLevelsResetEchoes() {
        var m = EchoMatch(players: ["a"], level: 0)
        m.beginCollecting()
        m.playerExited("a")
        XCTAssertFalse(m.isCleared)
        m.receive(run("a"))
        m.startNextLoop(maxPerPlayer: 1)
        XCTAssertEqual(m.loop, 1)
        m.advanceLevel()
        XCTAssertEqual(m.level, 1)
        XCTAssertTrue(m.echoes.isEmpty)
        XCTAssertEqual(m.totalLoops, 2)
    }

    // Review finding: finishing the last level pinned solo progress at the last level forever.
    func testProgressAfterTheLastLevelStartsOver() {
        XCTAssertEqual(EchoMatch.nextStart(afterClearing: 2, levelCount: 7), 3)
        XCTAssertEqual(EchoMatch.nextStart(afterClearing: 6, levelCount: 7), 0)
    }

    // Review finding: a run finished across several sessions showed only the last session's loops.
    func testLoopsCarryOverFromEarlierSessions() {
        var m = EchoMatch(players: ["a"], level: 3, priorLoops: 20)
        m.beginCollecting()
        m.startNextLoop(maxPerPlayer: 1)
        XCTAssertEqual(m.totalLoops, 21)
    }
}


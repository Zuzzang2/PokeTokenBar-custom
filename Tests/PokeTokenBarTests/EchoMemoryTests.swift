import AppKit
import XCTest
@testable import PokeTokenBar

// SPIKE: the "지난번의 나" ghost — the run that last cleared a level plays alongside the next attempt.
@MainActor
final class EchoMemoryTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "EchoMemoryTests-\(UUID().uuidString)")!

    private func soloView(level: Int, memory: EchoMemory) -> EchoGameView {
        let me = EchoRosterEntry(id: "me", trainer: "잭", pokemonName: "뮤", speciesID: 151, isShiny: false)
        var v: EchoGameView?
        let view = EchoGameView(frame: NSRect(x: 0, y: 0, width: 960, height: 540), roster: [me], meID: "me",
                                hostID: "me", gameID: UUID().uuidString, startLevel: level, memory: memory,
                                send: { v?.handle($0) }, sendState: { _ in })
        v = view
        return view
    }

    private func key(_ v: EchoGameView, _ code: UInt16, down: Bool) {
        let e = NSEvent.keyEvent(with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                                 windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                                 isARepeat: false, keyCode: code)!
        down ? v.keyDown(with: e) : v.keyUp(with: e)
    }

    /// Plays "2. 메아리": park an echo on the plate, then walk out.
    private func clearEchoLevel(_ v: EchoGameView) {
        v.begin()
        key(v, 124, down: true); v.advance(frames: 34); key(v, 124, down: false)
        key(v, 15, down: true); v.advance(frames: 80)
        key(v, 124, down: true); v.advance(frames: 260); key(v, 124, down: false)
    }

    func testAClearedRunReturnsAsLastTimesGhost() {
        let memory = EchoMemory(defaults: defaults)
        let first = soloView(level: 1, memory: memory)
        first.begin()
        XCTAssertNil(first.pastRun, "nothing to remember on a first visit")
        clearEchoLevel(first)
        XCTAssertEqual(first.mode, .clear)

        let second = soloView(level: 1, memory: memory)
        second.begin()
        XCTAssertNotNil(second.pastRun)
        XCTAssertEqual(second.pastRun?.last?.x ?? 0, first.frames.last?.x ?? -1, accuracy: 1, "the winning walk, not a failed one")
    }

    func testFailedRunsAreNotRemembered() {
        let memory = EchoMemory(defaults: defaults)
        let v = soloView(level: 1, memory: memory)
        v.begin()
        key(v, 124, down: true); v.advance(frames: 60)
        key(v, 15, down: true); v.advance(frames: 80)
        XCTAssertNil(memory.lastWin(level: "echo"))
    }

    func testMemoryRoundTripsThroughDefaults() {
        let frames = [EchoFrame(x: 66.4, y: 454, facing: 1), EchoFrame(x: 70.9, y: 450.2, facing: -1)]
        EchoMemory(defaults: defaults).remember(level: "echo", frames: frames)
        let back = EchoMemory(defaults: defaults).lastWin(level: "echo")
        XCTAssertEqual(back?.count, 2)
        XCTAssertEqual(back?[1].facing, -1)
        XCTAssertEqual(back?[1].x ?? 0, 70.9, accuracy: 0.5)
    }

    // Review finding: in co-op, reaching the shrine alone is not a clear and must not be remembered.
    func testCoopArrivalWithoutAClearIsNotRemembered() {
        let memory = EchoMemory(defaults: defaults)
        let me = EchoRosterEntry(id: "me", trainer: "잭", pokemonName: "뮤", speciesID: 151, isShiny: false)
        let mate = EchoRosterEntry(id: "zz", trainer: "에디", pokemonName: "피카츄", speciesID: 25, isShiny: false)
        var v: EchoGameView?
        let view = EchoGameView(frame: NSRect(x: 0, y: 0, width: 960, height: 540), roster: [me, mate], meID: "me",
                                hostID: "me", gameID: "g", startLevel: 0, memory: memory,
                                send: { v?.handle($0) }, sendState: { _ in })
        v = view
        view.begin()
        // "1. 깨어남": jump the blocks and the spikes into the shrine; the teammate never arrives.
        for (n, keys) in [(45, "r"), (15, "rj"), (55, "r"), (15, "rj"), (46, "r"), (15, "rj"), (100, "r")] {
            key(view, 124, down: true)
            if keys.contains("j") { key(view, 49, down: true) }
            view.advance(frames: n)
            key(view, 49, down: false)
        }
        XCTAssertTrue(view.exitedIDs.contains("me"))
        XCTAssertNotEqual(view.mode, .clear)
        XCTAssertNil(memory.lastWin(level: "wake"))
    }
}


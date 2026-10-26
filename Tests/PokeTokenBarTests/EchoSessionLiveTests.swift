import XCTest
@testable import PokeTokenBar

// SPIKE: two EchoSessions in one process over real MultipeerConnectivity (local Bonjour), opt-in because it
// needs local-network access: PTB_LIVE_MC=1 swift test --filter EchoSessionLiveTests
@MainActor
final class EchoSessionLiveTests: XCTestCase {
    func testTwoSessionsFindEachOtherStartAGameAndExchangeLoopMessages() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PTB_LIVE_MC"] == "1", "live MultipeerConnectivity test")
        let a = EchoSession(me: EchoPlayerInfo(id: "a-\(UUID().uuidString)", trainer: "잭", speciesID: 151,
                                               isShiny: false, pokemonName: "뮤", inGame: false))
        let b = EchoSession(me: EchoPlayerInfo(id: "b-\(UUID().uuidString)", trainer: "에디", speciesID: 25,
                                               isShiny: false, pokemonName: "피카츄", inGame: false))
        defer { a.stop(); b.stop() }
        var gotByB: [EchoMessage] = []
        b.onMessage = { gotByB.append($0) }

        try await waitUntil(30) { a.players.count == 1 && b.players.count == 1 }
        XCTAssertEqual(a.hostID, b.hostID, "both sides agree on the host")
        let host = a.isHost ? a : b
        let guestGot: () -> [EchoMessage] = { a.isHost ? gotByB : [] }
        XCTAssertTrue(a.isHost, "smaller ID hosts")

        host.startGame()
        try await waitUntil(10) { guestGot().contains { if case .start = $0 { return true }; return false } }

        let run = EchoOwned(owner: "x", speciesID: 25, isShiny: false,
                            rec: EchoRecording(frames: [EchoFrame(x: 1, y: 2, facing: 1)], end: .rewind))
        host.send(.loop(EchoLoopStart(gameID: "g", level: 1, loop: 3, echoes: [run], full: [])))
        try await waitUntil(10) {
            guestGot().contains { if case .loop(let l) = $0 { return l.loop == 3 && l.echoes == [run] }; return false }
        }
    }

    /// The co-op flow from EchoCoopFlowTests, but every message crosses a real MCSession.
    func testTwoTrainersClearALevelOverTheRealTransport() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PTB_LIVE_MC"] == "1", "live MultipeerConnectivity test")
        let a = EchoSession(me: EchoPlayerInfo(id: "a-\(UUID().uuidString)", trainer: "잭", speciesID: 151,
                                               isShiny: false, pokemonName: "뮤", inGame: false))
        let b = EchoSession(me: EchoPlayerInfo(id: "b-\(UUID().uuidString)", trainer: "에디", speciesID: 25,
                                               isShiny: false, pokemonName: "피카츄", inGame: false))
        defer { a.stop(); b.stop() }
        try await waitUntil(30) { a.players.count == 1 && b.players.count == 1 }

        var views: [String: EchoGameView] = [:]
        for s in [a, b] {
            s.onMessage = { [weak s] m in
                guard let s else { return }
                if case .start(let st) = m {
                    let v = EchoGameView(frame: NSRect(x: 0, y: 0, width: 960, height: 540), roster: st.roster,
                                         meID: s.me.id, hostID: st.hostID, gameID: st.gameID, startLevel: 1,
                                         send: { [weak s] in s?.send($0) }, sendState: { [weak s] in s?.sendState($0) })
                    views[s.me.id] = v
                    v.begin()
                } else {
                    views[s.me.id]?.handle(m)
                }
            }
        }
        a.startGame()
        try await waitUntil(10) { views.count == 2 && views.values.allSatisfy { $0.mode == .play } }
        let host = views[a.me.id]!, guest = views[b.me.id]!

        func key(_ v: EchoGameView, _ code: UInt16, _ down: Bool) {
            let e = NSEvent.keyEvent(with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: code)!
            down ? v.keyDown(with: e) : v.keyUp(with: e)
        }
        func run(_ frames: Int, until done: () -> Bool = { false }) async throws {
            for _ in 0..<frames where !done() {
                host.advance(frames: 1)
                guest.advance(frames: 1)
                try await Task.sleep(for: .milliseconds(4))
            }
        }

        key(guest, 124, true); key(host, 124, true)
        try await run(34)
        key(guest, 124, false)
        try await run(240)
        XCTAssertTrue(host.exitedIDs.contains(a.me.id), "host walked through while the guest held the plate")
        key(host, 124, false)
        key(guest, 15, true)
        try await run(600) { host.loop == 1 && guest.loop == 1 }
        XCTAssertEqual(guest.loop, 1, "the guest's rewind reached the host and the next loop came back")
        XCTAssertEqual(guest.echoes, host.echoes)
        XCTAssertEqual(host.echoes.count, 2)

        key(host, 124, true); key(guest, 124, true)
        try await run(300)
        XCTAssertEqual(host.mode, .clear)
        XCTAssertEqual(guest.mode, .clear)
        try await run(240)
        XCTAssertEqual(guest.levelIndex, 2, "the host moved everyone on")
    }

    private func waitUntil(_ seconds: Double, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            guard Date() < deadline else { return XCTFail("timed out after \(seconds)s") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}

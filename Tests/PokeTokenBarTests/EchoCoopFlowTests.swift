import AppKit
import XCTest
@testable import PokeTokenBar

// SPIKE: two 메아리 game views wired through an in-memory bus instead of MultipeerConnectivity. Messages to
// yourself arrive at once (as EchoSession.send does); messages to the other machine arrive one step later.
@MainActor
final class EchoCoopFlowTests: XCTestCase {
    @MainActor private final class Bus {
        var views: [String: EchoGameView] = [:]
        var queue: [(to: String, message: EchoMessage)] = []
        var log: [String] = []

        func send(from id: String, _ m: EchoMessage, reliable: Bool = true) {
            if reliable { views[id]?.handle(m) }
            for other in views.keys where other != id { queue.append((other, m)) }
        }

        func flush() {
            while !queue.isEmpty {
                let batch = queue
                queue = []
                for (to, m) in batch { views[to]?.handle(m) }
            }
        }
    }

    private let host = EchoRosterEntry(id: "a", trainer: "잭", pokemonName: "뮤", speciesID: 151, isShiny: false)
    private let guest = EchoRosterEntry(id: "b", trainer: "에디", pokemonName: "피카츄", speciesID: 25, isShiny: false)

    private func makePair(level: Int) -> (Bus, EchoGameView, EchoGameView) {
        let bus = Bus()
        func view(_ me: EchoRosterEntry) -> EchoGameView {
            EchoGameView(frame: NSRect(x: 0, y: 0, width: 960, height: 540), roster: [host, guest], meID: me.id,
                         hostID: host.id, gameID: "g", startLevel: level,
                         send: { [weak bus] in bus?.send(from: me.id, $0) },
                         sendState: { [weak bus] in bus?.send(from: me.id, $0, reliable: false) })
        }
        let a = view(host), b = view(guest)
        bus.views = ["a": a, "b": b]
        return (bus, a, b)
    }

    private func key(_ v: EchoGameView, _ code: UInt16, down: Bool) {
        let e = NSEvent.keyEvent(with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                                 windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                                 isARepeat: false, keyCode: code)!
        down ? v.keyDown(with: e) : v.keyUp(with: e)
    }

    /// Steps both machines together, delivering network traffic after every frame.
    private func run(_ bus: Bus, _ frames: Int) {
        for _ in 0..<frames {
            for v in bus.views.values { v.advance(frames: 1) }
            bus.flush()
        }
    }

    func testTwoTrainersClearALevelTogetherAndMoveOn() {
        let (bus, a, b) = makePair(level: 1)  // "2. 메아리": one plate, one door
        a.begin()
        bus.flush()
        XCTAssertEqual(a.mode, .play)
        XCTAssertEqual(b.mode, .play)

        // Loop 1: the guest parks on the plate; the host walks through the open door into the shrine.
        key(b, 124, down: true)
        key(a, 124, down: true)
        run(bus, 34)
        key(b, 124, down: false)
        run(bus, 240)
        XCTAssertTrue(a.exitedIDs.contains("a"), "host reached the shrine while the guest held the door")
        XCTAssertEqual(b.exitedIDs, ["a"], "the guest saw the host arrive")
        XCTAssertNotEqual(a.mode, .clear, "one trainer arriving is not a clear")

        // The guest rewinds for everyone: both runs come back as echoes.
        key(a, 124, down: false)
        key(b, 15, down: true)
        run(bus, 90)
        XCTAssertEqual(a.loop, 1)
        XCTAssertEqual(b.loop, 1)
        XCTAssertEqual(a.echoes.map(\.owner).sorted(), ["a", "b"])
        XCTAssertEqual(b.echoes, a.echoes, "both machines replay the same echoes")

        // Loop 2: the guest's echo holds the plate, so both walk out.
        key(a, 124, down: true)
        key(b, 124, down: true)
        run(bus, 300)
        XCTAssertEqual(a.mode, .clear)
        XCTAssertEqual(b.mode, .clear)

        run(bus, 220)
        XCTAssertEqual(a.levelIndex, 2, "host moved everyone to the next level")
        XCTAssertEqual(b.levelIndex, 2)
        XCTAssertTrue(b.echoes.isEmpty)
    }

    func testFullEchoBudgetIsReportedInsteadOfDroppingAnEcho() {
        let (bus, a, b) = makePair(level: 1)  // budget: one echo each
        a.begin()
        bus.flush()
        key(a, 15, down: true)
        run(bus, 90)
        let first = a.echoes
        key(a, 124, down: true)
        run(bus, 20)
        key(a, 15, down: true)
        run(bus, 90)
        XCTAssertEqual(a.echoes, first, "the first echoes stay; the new runs are not swapped in")
        XCTAssertEqual(a.echoCount(of: "a"), 1)
        XCTAssertEqual(a.echoCount(of: "b"), 1)
        XCTAssertEqual(b.echoes, a.echoes)
        XCTAssertNotNil(b.banner, "the full budget is announced")
    }

    func testGuestLeavingDoesNotStallTheHost() {
        let (bus, a, _) = makePair(level: 1)
        a.begin()
        bus.flush()
        bus.views["b"] = nil
        a.markLeft("b")
        key(a, 15, down: true)
        run(bus, 90)
        XCTAssertEqual(a.loop, 1, "the host's loop moved on without the guest's recording")
    }

    // Review finding: while spectating, plates and doors froze in the last state this machine simulated.
    func testSpectatorSeesThePlateReleaseWhenTheTeammateLeavesIt() {
        let (bus, a, b) = makePair(level: 1)
        a.begin()
        bus.flush()
        key(b, 124, down: true)
        key(a, 124, down: true)
        run(bus, 34)
        key(b, 124, down: false)
        run(bus, 240)
        XCTAssertEqual(a.mode, .spectate, "host is in the shrine, watching")
        XCTAssertFalse(a.displayedPressed.isEmpty, "guest still on the plate")
        key(b, 123, down: true)
        run(bus, 40)
        XCTAssertTrue(a.displayedPressed.isEmpty, "the spectator sees the plate come up")
    }
}


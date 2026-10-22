import XCTest
@testable import PokeTokenBar

// SPIKE: minimal checks for the throwaway battle engine.
final class BattleEngineSpikeTests: XCTestCase {
    private func mon(_ name: String, types: [String], hp: Int, speed: Int, move: BattleMove) -> BattleMon {
        BattleMon(trainer: name, name: name, speciesID: 1, isShiny: false, types: types,
                  stats: ["hp": hp, "attack": 100, "defense": 100, "special-attack": 100,
                          "special-defense": 100, "speed": speed],
                  moves: [move])
    }
    private let tackle = BattleMove(name: "tackle", type: "normal", power: 40, accuracy: nil, isPhysical: true, priority: 0)
    private let nuke = BattleMove(name: "nuke", type: "fire", power: 250, accuracy: nil, isPhysical: false, priority: 0)

    func testSameSeedSameResult() {
        let teams = [[mon("a", types: ["fire"], hp: 150, speed: 90, move: nuke)],
                     [mon("b", types: ["grass"], hp: 150, speed: 80, move: tackle)]]
        let s = BattleEngine.initialState(teams)
        let r1 = BattleEngine.resolve(s, teams: teams, actions: [.move(0), .move(0)], seed: 42)
        let r2 = BattleEngine.resolve(s, teams: teams, actions: [.move(0), .move(0)], seed: 42)
        XCTAssertEqual(r1, r2)
    }

    func testFaintWithBenchRequiresReplacementThenSwitchGoesFirst() {
        let a = mon("a", types: ["fire"], hp: 150, speed: 90, move: nuke)
        let b1 = mon("b1", types: ["grass"], hp: 50, speed: 10, move: tackle)
        let b2 = mon("b2", types: ["water"], hp: 500, speed: 10, move: tackle)
        let teams = [[a], [b1, b2]]
        var s = BattleEngine.resolve(BattleEngine.initialState(teams), teams: teams, actions: [.move(0), .move(0)], seed: 1)
        XCTAssertNil(s.winner)
        XCTAssertEqual(s.needsReplacement, [false, true])
        XCTAssertEqual(s.hp[0][0], 150, "fainted defender must not attack back")
        s = BattleEngine.replace(s, teams: teams, choices: [nil, 1])
        XCTAssertEqual(s.active, [0, 1])
        XCTAssertFalse(s.awaitingReplacement)
    }

    func testVoluntarySwitchHappensBeforeMoveAndTakesTheHit() {
        let a = mon("a", types: ["normal"], hp: 300, speed: 200, move: tackle)
        let b1 = mon("b1", types: ["grass"], hp: 300, speed: 10, move: tackle)
        let b2 = mon("b2", types: ["ghost"], hp: 300, speed: 10, move: tackle)
        let teams = [[a], [b1, b2]]
        let s = BattleEngine.resolve(BattleEngine.initialState(teams), teams: teams, actions: [.move(0), .switchTo(1)], seed: 7)
        XCTAssertEqual(s.active[1], 1)
        XCTAssertEqual(s.hp[1], [300, 300], "normal move into ghost does nothing")
    }

    func testLastFaintEndsBattle() {
        let teams = [[mon("a", types: ["fire"], hp: 150, speed: 90, move: nuke)],
                     [mon("b", types: ["grass"], hp: 10, speed: 10, move: tackle)]]
        let s = BattleEngine.resolve(BattleEngine.initialState(teams), teams: teams, actions: [.move(0), .move(0)], seed: 3)
        XCTAssertEqual(s.winner, 0)
    }

    func testEventsReplayAttackDamageFaintInOrder() {
        let teams = [[mon("a", types: ["fire"], hp: 150, speed: 90, move: nuke)],
                     [mon("b", types: ["grass"], hp: 10, speed: 10, move: tackle)]]
        let s = BattleEngine.resolve(BattleEngine.initialState(teams), teams: teams, actions: [.move(0), .move(0)], seed: 3)
        let kinds = s.events.compactMap { e -> String? in
            switch e {
            case .attack: return "attack"
            case .damage(let side, let hp, _, _): return "damage\(side)=\(hp)"
            case .faint(let side): return "faint\(side)"
            default: return nil
            }
        }
        XCTAssertEqual(kinds, ["attack", "damage1=0", "faint1"])
        XCTAssertEqual(s.step, 1)
    }
}

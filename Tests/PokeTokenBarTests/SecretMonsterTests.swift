import XCTest
@testable import PokeTokenBar

/// 무쇠깨비: a local-only, unlock-gated battle monster with every battle stat at 999.
final class SecretMonsterTests: XCTestCase {
    private let pikachu = BattleCandidate(id: "dex-1", speciesID: 25, name: "피카츄", isShiny: false,
                                          profile: nil, nature: nil, isRaising: false)

    func testOnlyOfferedWhenUnlocked() {
        XCTAssertEqual(SecretMonster.withSecret([pikachu], unlocked: false).map(\.id), ["dex-1"])
        let unlocked = SecretMonster.withSecret([pikachu], unlocked: true)
        XCTAssertEqual(unlocked.first?.speciesID, SecretMonster.id, "listed first so it is easy to pick")
        XCTAssertEqual(unlocked.count, 2)
    }

    func testUnlockReadsTheLocalSetting() {
        let defaults = UserDefaults(suiteName: "SecretMonsterTests-\(UUID().uuidString)")!
        XCTAssertFalse(SecretMonster.isUnlocked(defaults))
        defaults.set(true, forKey: SecretMonster.unlockKey)
        XCTAssertTrue(SecretMonster.isUnlocked(defaults))
    }

    func testNeverHatches() {
        XCTAssertFalse(DigimonCatalog.baseIDs.contains(SecretMonster.id))
        XCTAssertNil(DigimonCatalog.line(baseSpeciesID: SecretMonster.id))
    }

    func testBattleStatsAreAll999() async throws {
        let mon = try await BattleMonBuilder.build(SecretMonster.candidate, trainer: "jack")
        XCTAssertEqual(mon.name, "무쇠깨비")
        XCTAssertEqual(mon.maxHP, 999)
        XCTAssertEqual(Set(PokemonStatCalculator.order.map { mon.stats[$0] }), [999])
        XCTAssertEqual(mon.moves.count, 4)
        XCTAssertEqual(Set(mon.moves.map(\.type)).count, 4, "four different types for coverage")
    }

    func testOneShotsATypicalLevel50Mon() async throws {
        let musoe = try await BattleMonBuilder.build(SecretMonster.candidate, trainer: "jack")
        let foe = BattleMon(trainer: "x", name: "foe", speciesID: 1, isShiny: false, types: ["normal"],
                            stats: ["hp": 200, "attack": 150, "defense": 150, "special-attack": 150,
                                    "special-defense": 150, "speed": 150],
                            moves: [BattleMove(name: "t", type: "normal", power: 40, accuracy: nil, isPhysical: true, priority: 0)])
        let state = BattleEngine.resolve(BattleEngine.initialState([[musoe], [foe]]), teams: [[musoe], [foe]],
                                         actions: [.move(0), .move(0)], seed: 1)
        XCTAssertEqual(state.winner, 0)
    }
}

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
        XCTAssertEqual(unlocked.count, 2 + 649, "plus every Gen 1–5 species for free pick")
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

/// Free pick: with the unlock, every Gen 1–5 species can join the party; never shared as owned.
final class FreePickRosterTests: XCTestCase {
    private let mew = BattleCandidate(id: "dex-151", speciesID: 151, name: "뮤", isShiny: false,
                                      profile: nil, nature: nil, isRaising: false)

    func testNameTableCoversGen1To5() {
        let names = SpeciesRoster.names
        XCTAssertEqual(names.count, 649)
        XCTAssertEqual(names.first { $0.id == 25 }?.ko, "피카츄")
        XCTAssertEqual(names.first { $0.id == 649 }?.en, "Genesect")
    }

    func testUnlockAddsEverySpeciesAfterOwnedOnes() {
        let list = SecretMonster.withSecret([mew], unlocked: true)
        XCTAssertEqual(list.prefix(2).map(\.id), [SecretMonster.candidate.id, "dex-151"])
        XCTAssertEqual(list.filter(SecretMonster.isGranted).count, 1 + 649)
        XCTAssertTrue(list.contains { $0.speciesID == 25 && $0.name == "피카츄" })
        XCTAssertEqual(SecretMonster.withSecret([mew], unlocked: false).count, 1)
    }

    func testSearchMatchesKoreanEnglishAndNumber() {
        let list = SecretMonster.withSecret([mew], unlocked: true)
        XCTAssertTrue(SpeciesRoster.filter(list, query: "피카").contains { $0.speciesID == 25 })
        XCTAssertTrue(SpeciesRoster.filter(list, query: "pika").contains { $0.speciesID == 25 })
        XCTAssertTrue(SpeciesRoster.filter(list, query: "25").contains { $0.speciesID == 25 })
        XCTAssertEqual(SpeciesRoster.filter(list, query: "  ").count, list.count)
    }

    /// Plaza peers can browse a trainer's collection; unlock-only picks must not show up as owned.
    func testSharedCollectionHasOnlyOwnedMonsters() {
        let list = SecretMonster.withSecret([mew], unlocked: true)
        XCTAssertEqual(SecretMonster.ownedOnly(list).map(\.id), ["dex-151"])
    }
}

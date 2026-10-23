import XCTest
@testable import PokeTokenBar

final class DigimonTests: XCTestCase {
    private let pokemon = EvoLine(baseID: 1, tree: EvoNode(speciesID: 1, children: []), rarity: .common, names: [1: ["en": "P1"]])
    private var provider: DigimonAwareProvider { DigimonAwareProvider(inner: StubProvider(value: pokemon)) }

    func testBothLinesHaveFiveUntrimmedForms() async throws {
        for base in DigimonCatalog.baseIDs {
            let line = try await provider.line(baseSpeciesID: base)
            XCTAssertEqual(line.totalForms, 5)
            XCTAssertEqual(line.rarity, .rare)
            // Agumon also carries the shiny-only Black line, ending at SkullGreymon.
            XCTAssertEqual(line.tree.finalIDs, base == 9001 ? [9005, 9008] : [base + 4])
            XCTAssertNotEqual(line.localizedName(base, .en), "#\(base)")
        }
    }

    func testShinyTakesBlackBranchAndNormalNeverDoes() async throws {
        let tree = try await provider.line(baseSpeciesID: 9001).tree
        XCTAssertEqual(DigimonCatalog.eligibleChildren(tree.children, shiny: true).map(\.speciesID), [9006])
        XCTAssertEqual(DigimonCatalog.eligibleChildren(tree.children, shiny: false).map(\.speciesID), [9002])
        let pokemonKids = pokemon.tree.children
        XCTAssertEqual(DigimonCatalog.eligibleChildren(pokemonKids, shiny: true).count, pokemonKids.count)
    }

    func testOmegamonIsGrantedNotHatched() async throws {
        XCTAssertFalse(DigimonCatalog.baseIDs.contains(DigimonCatalog.omegamonID))
        XCTAssertEqual(DigimonCatalog.line(baseSpeciesID: DigimonCatalog.omegamonID)?.rarity, .legendary)
        XCTAssertNotNil(DigimonCatalog.details(speciesID: DigimonCatalog.omegamonID))
    }

    func testIndexAddsDigimonBasesAndDelegatesPokemon() async throws {
        let ids = try await provider.baseSpeciesIndex().map(\.id)
        XCTAssertEqual(Set(ids), [1, 9001, 9011, 9031, 9041, 9051, 9061, 9071, 9081])
        let digimon = try await provider.baseSpecies(id: 9001)
        XCTAssertEqual(digimon?.captureRate, DigimonCatalog.captureRate)
        let poke = try await provider.baseSpecies(id: 1)
        XCTAssertEqual(poke?.id, 1)
    }

    func testDetailsCoverEveryStageWithAllSixStats() throws {
        for id in DigimonCatalog.agumonLine + DigimonCatalog.blackAgumonLine + DigimonCatalog.gabumonLine + DigimonCatalog.extraLines.flatMap { $0 } + [DigimonCatalog.omegamonID] {
            let d = try XCTUnwrap(DigimonCatalog.details(speciesID: id))
            XCTAssertEqual(Set(d.baseStats.keys), Set(PokemonStatCalculator.order))
            XCTAssertFalse(d.moves.isEmpty)
        }
        XCTAssertNil(DigimonCatalog.details(speciesID: 25))
    }
}

final class DigimonSkillTests: XCTestCase {
    private var allIDs: [Int] {
        DigimonCatalog.agumonLine + DigimonCatalog.blackAgumonLine + DigimonCatalog.gabumonLine
            + DigimonCatalog.extraLines.flatMap { $0 } + [DigimonCatalog.omegamonID]
    }

    func testEveryDigimonHasFourOwnSkillsWithRisingPower() throws {
        for id in allIDs {
            let moves = try XCTUnwrap(DigimonCatalog.battleMoves(speciesID: id), "\(id)")
            XCTAssertEqual(moves.count, 4, "\(id)")
            XCTAssertEqual(Set(moves.map(\.name)).count, 4, "\(id) skill names are distinct")
            XCTAssertEqual(moves.map(\.power), moves.map(\.power).sorted(), "\(id) power rises with the slot")
            XCTAssertTrue(moves.allSatisfy { $0.power > 0 && ($0.accuracy ?? 100) >= 90 })
        }
    }

    func testPowerGrowsWithEvolutionStage() throws {
        for line in [DigimonCatalog.agumonLine, DigimonCatalog.gabumonLine] + DigimonCatalog.extraLines {
            let tops = try line.map { try XCTUnwrap(DigimonCatalog.battleMoves(speciesID: $0)).last!.power }
            XCTAssertEqual(tops, tops.sorted())
            XCTAssertLessThan(tops.first!, tops.last!)
        }
        let omega = try XCTUnwrap(DigimonCatalog.battleMoves(speciesID: DigimonCatalog.omegamonID)).last!.power
        let war = try XCTUnwrap(DigimonCatalog.battleMoves(speciesID: 9005)).last!.power
        XCTAssertGreaterThan(omega, war)
    }

    func testPokemonKeepTheirPokeAPIMoves() {
        XCTAssertNil(DigimonCatalog.battleMoves(speciesID: 25))
    }
}

final class SavedPartyTests: XCTestCase {
    private func candidate(_ id: String, _ species: Int, shiny: Bool = false) -> BattleCandidate {
        BattleCandidate(id: id, speciesID: species, name: "#\(species)", isShiny: shiny, profile: nil, nature: nil,
                        isRaising: false)
    }

    private func party(_ name: String, _ ids: [(String, Int)]) -> SavedParty {
        SavedParty(name: name, members: ids.map { .init(id: $0.0, speciesID: $0.1, name: "#\($0.1)", shiny: false) })
    }

    func testSavingUnderTheSameNameReplacesAndCapsTheList() {
        var list: [SavedParty] = []
        for i in 0..<10 { list = SavedPartyStore.adding(party("조합 \(i)", [("a", 1)]), to: list) }
        XCTAssertEqual(list.count, SavedPartyStore.maxSaved)
        XCTAssertEqual(list.first?.name, "조합 9")
        list = SavedPartyStore.adding(party("조합 5", [("b", 2)]), to: list)
        XCTAssertEqual(list.filter { $0.name == "조합 5" }.count, 1)
        XCTAssertEqual(list.first?.members.first?.id, "b")
    }

    func testResolveKeepsOrderAndFallsBackToTheSameSpecies() {
        let owned = [candidate("x", 25), candidate("y", 6), candidate("z", 9001)]
        let result = SavedPartyStore.resolve(party("p", [("y", 6), ("gone", 25), ("nope", 150)]), candidates: owned, limit: 6)
        XCTAssertEqual(result.ids, ["y", "x"])   // "gone" falls back to the other Pikachu; Mewtwo is missing
        XCTAssertEqual(result.missing, 1)
    }

    func testDefaultNameSkipsTakenNumbers() {
        XCTAssertEqual(SavedPartyStore.defaultName(in: [party("조합 1", [("a", 1)])]), "조합 2")
    }

    func testRoundTripThroughDefaults() {
        let defaults = UserDefaults(suiteName: "SavedPartyTests-\(UUID().uuidString)")!
        let list = [party("조합 1", [("a", 1), ("b", 2)])]
        SavedPartyStore.save(list, to: defaults)
        XCTAssertEqual(SavedPartyStore.load(defaults), list)
    }
}

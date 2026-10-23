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

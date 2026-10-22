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
            XCTAssertEqual(line.tree.finalIDs, [base + 4])
            XCTAssertNotEqual(line.localizedName(base, .en), "#\(base)")
        }
    }

    func testIndexAddsDigimonBasesAndDelegatesPokemon() async throws {
        let ids = try await provider.baseSpeciesIndex().map(\.id)
        XCTAssertEqual(Set(ids), [1, 9001, 9011])
        let digimon = try await provider.baseSpecies(id: 9001)
        XCTAssertEqual(digimon?.captureRate, DigimonCatalog.captureRate)
        let poke = try await provider.baseSpecies(id: 1)
        XCTAssertEqual(poke?.id, 1)
    }

    func testDetailsCoverEveryStageWithAllSixStats() throws {
        for id in DigimonCatalog.agumonLine + DigimonCatalog.gabumonLine {
            let d = try XCTUnwrap(DigimonCatalog.details(speciesID: id))
            XCTAssertEqual(Set(d.baseStats.keys), Set(PokemonStatCalculator.order))
            XCTAssertFalse(d.moves.isEmpty)
        }
        XCTAssertNil(DigimonCatalog.details(speciesID: 25))
    }
}

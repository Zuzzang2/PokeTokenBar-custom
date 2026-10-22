import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

private let storedRenderNames: [Int: [String: String]] = [
    1: ["ko": "이상해씨", "en": "Bulbasaur"], 2: ["ko": "이상해풀", "en": "Ivysaur"],
    3: ["ko": "이상해꽃", "en": "Venusaur"], 25: ["ko": "피카츄", "en": "Pikachu"],
    133: ["ko": "이브이", "en": "Eevee"], 172: ["ko": "피츄", "en": "Pichu"],
    399: ["ko": "비버니", "en": "Bidoof"], 400: ["ko": "비버통", "en": "Bibarel"],
]

private struct StoredRenderProvider: PokeProviding, PokemonDetailProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        EvoLine(baseID: baseSpeciesID, tree: EvoNode(speciesID: baseSpeciesID, children: []),
                rarity: .common, names: storedRenderNames)
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    func pokemonDetails(speciesID: Int) async throws -> PokemonDetails {
        PokemonDetails(speciesID: speciesID, name: "fixture", height: 5, weight: 200,
                       baseExperience: 50, genderRate: 4, types: ["normal"],
                       baseStats: ["hp": 59, "attack": 45, "defense": 40,
                                   "special-attack": 35, "special-defense": 40, "speed": 31],
                       abilities: [PokemonAbilityOption(name: "simple", slot: 1, isHidden: false)],
                       moves: [PokemonMoveOption(name: "tackle", learnMethods: [
                           PokemonMoveLearnMethod(method: "level-up", level: 1)])])
    }
}

/// Opt-in native captures of the storage UI on temporary saves — never the user's collection.
@MainActor
final class StoredCompanionRenderingTests: XCTestCase {
    func testGenerateStoredCompanionEvidence() async throws {
        guard let output = ProcessInfo.processInfo.environment["PTB_STORED_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set PTB_STORED_SCREENSHOT_DIR for native storage UI evidence")
        }
        let directory = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for language in [AppLanguage.ko, .en] {
            for incubating in [false, true] {
                let store = try makeStore(language: language, incubating: incubating)
                let prefix = "\(language.rawValue)\(incubating ? "-egg" : "")"
                let navigation = PopoverNavigation()
                navigation.showingCollectionLog = true
                try await capture(CollectionView(store: store, navigation: navigation),
                                  to: directory.appendingPathComponent("\(prefix)-log.png"))
                let bidoof = try XCTUnwrap(store.dexSpecies.first { $0.id == 399 })
                await store.loadPokemonDetails(speciesID: 399)
                try await capture(PokemonDetailView(store: store, species: bidoof, onBack: {}),
                                  to: directory.appendingPathComponent("\(prefix)-detail.png"))
                if !incubating {
                    try await capture(ShopView(store: store, nav: PopoverNavigation()),
                                      to: directory.appendingPathComponent("\(prefix)-shop.png"))
                }
            }
        }
    }

    private func makeStore(language: AppLanguage, incubating: Bool) throws -> CompanionStore {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("stored-render-\(UUID()).json")
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        let caught = Date().addingTimeInterval(-3 * 3600)
        var state = CompanionState()
        state.language = language
        state.installBaselineSet = true
        state.usedSinceInstall = 5_000_000_000
        if !incubating {
            state.active = MonState(baseID: 133, pathIDs: [133], stageIndex: 0, usedAtStage: 40_000_000,
                                    rarity: .uncommon, totalForms: 2, nature: .jolly)
        }
        let bidoof = MonState(baseID: 399, pathIDs: [399], plannedPathIDs: [399, 400], stageIndex: 0,
                              usedAtStage: 24_280_057, rarity: .common, totalForms: 2, nature: .quirky)
        state.dex = [
            DexEntry(id: "grad", baseID: 1, finalID: 3, chainOrder: [1, 2, 3], rarity: .common,
                     caughtAt: caught.addingTimeInterval(-86_400), nature: .modest, names: storedRenderNames),
            DexEntry(id: "legacy", baseID: 172, finalID: 25, chainOrder: [172, 25], rarity: .common,
                     caughtAt: caught.addingTimeInterval(-3600), nature: .timid, names: storedRenderNames,
                     releasedAt: caught.addingTimeInterval(-3600)),
            DexEntry(id: "bidoof", baseID: 399, finalID: 399, chainOrder: [399], rarity: .common,
                     caughtAt: caught, nature: .quirky, names: storedRenderNames, releasedAt: caught,
                     storedMon: bidoof),
        ]
        try JSONEncoder().encode(state).write(to: file)
        return CompanionStore(provider: StoredRenderProvider(), fileURL: file,
                              defaults: UserDefaults(suiteName: "stored-render-\(UUID().uuidString)")!)
    }

    private func capture<V: View>(_ view: V, to file: URL) async throws {
        let size = NSSize(width: PopoverMetrics.contentWidth, height: 520)
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color.white)
            .environment(\.colorScheme, .light))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: size.width, height: size.height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        // Sprites and the detail fixture arrive asynchronously; spin the run loop so SwiftUI applies them.
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: file)
    }
}

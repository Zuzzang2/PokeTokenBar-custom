import Foundation

/// Digimon lines bundled with the app. PokéAPI has no Digimon, so ids live in a reserved 9000s band
/// (Pokémon use 1...649, forms use 10000+) and data/sprites come from this file and the app bundle.
enum DigimonCatalog {
    struct Entry {
        let id: Int
        let names: [String: String]     // PokéAPI-style language code → name
        let types: [String]
        let stats: [Int]                // hp, atk, def, spa, spd, spe
        let ability: String
        let moves: [(name: String, level: Int)]
    }

    static let agumonLine: [Int] = [9001, 9002, 9003, 9004, 9005]
    static let gabumonLine: [Int] = [9011, 9012, 9013, 9014, 9015]
    static let baseIDs: [Int] = [agumonLine[0], gabumonLine[0]]
    /// Same as `PokeAPIClient`'s capture-rate threshold for `.rare`.
    static let captureRate = 45

    private static let entries: [Int: Entry] = Dictionary(uniqueKeysWithValues: [
        Entry(id: 9001, names: ["ko": "코로몬", "en": "Koromon", "ja": "コロモン"], types: ["normal"],
              stats: [50, 40, 35, 40, 35, 45], ability: "run-away",
              moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
        Entry(id: 9002, names: ["ko": "아구몬", "en": "Agumon", "ja": "アグモン"], types: ["fire"],
              stats: [65, 70, 55, 60, 50, 70], ability: "blaze",
              moves: [("scratch", 1), ("ember", 1), ("fire-fang", 14), ("flame-burst", 22)]),
        Entry(id: 9003, names: ["ko": "그레이몬", "en": "Greymon", "ja": "グレイモン"], types: ["fire", "dragon"],
              stats: [90, 100, 85, 85, 70, 70], ability: "blaze",
              moves: [("ember", 1), ("headbutt", 1), ("flamethrower", 24), ("dragon-claw", 32)]),
        Entry(id: 9004, names: ["ko": "메탈그레이몬", "en": "MetalGreymon", "ja": "メタルグレイモン"], types: ["fire", "steel"],
              stats: [95, 120, 105, 95, 80, 75], ability: "blaze",
              moves: [("flamethrower", 1), ("metal-claw", 1), ("flash-cannon", 30), ("fire-blast", 40)]),
        Entry(id: 9005, names: ["ko": "워그레이몬", "en": "WarGreymon", "ja": "ウォーグレイモン"], types: ["fire", "dragon"],
              stats: [100, 135, 115, 90, 90, 90], ability: "blaze",
              moves: [("dragon-claw", 1), ("flare-blitz", 1), ("dragon-dance", 34), ("outrage", 46)]),

        Entry(id: 9011, names: ["ko": "뿔몬", "en": "Tsunomon", "ja": "ツノモン"], types: ["normal"],
              stats: [50, 38, 40, 38, 38, 42], ability: "run-away",
              moves: [("tackle", 1), ("leer", 5), ("powder-snow", 10)]),
        Entry(id: 9012, names: ["ko": "파피몬", "en": "Gabumon", "ja": "ガブモン"], types: ["ice"],
              stats: [65, 62, 58, 58, 55, 65], ability: "snow-cloak",
              moves: [("bite", 1), ("powder-snow", 1), ("ice-fang", 14), ("ice-shard", 22)]),
        Entry(id: 9013, names: ["ko": "가루몬", "en": "Garurumon", "ja": "ガルルモン"], types: ["ice"],
              stats: [90, 95, 80, 80, 80, 100], ability: "snow-cloak",
              moves: [("ice-fang", 1), ("bite", 1), ("ice-beam", 24), ("crunch", 32)]),
        Entry(id: 9014, names: ["ko": "워가루몬", "en": "WereGarurumon", "ja": "ワーガルルモン"], types: ["ice", "fighting"],
              stats: [95, 115, 90, 90, 90, 100], ability: "snow-cloak",
              moves: [("ice-punch", 1), ("close-combat", 1), ("avalanche", 30), ("blizzard", 40)]),
        Entry(id: 9015, names: ["ko": "메탈가루몬", "en": "MetalGarurumon", "ja": "メタルガルルモン"], types: ["ice", "steel"],
              stats: [100, 120, 110, 105, 95, 105], ability: "snow-cloak",
              moves: [("ice-beam", 1), ("metal-claw", 1), ("flash-cannon", 34), ("blizzard", 46)]),
    ].map { ($0.id, $0) })

    static func contains(_ id: Int) -> Bool { entries[id] != nil }

    private static func chain(_ ids: [Int]) -> EvoNode {
        let tail = ids.dropFirst()
        return EvoNode(speciesID: ids[0], children: tail.isEmpty ? [] : [chain(Array(tail))])
    }

    static func line(baseSpeciesID: Int) -> EvoLine? {
        guard let ids = [agumonLine, gabumonLine].first(where: { $0.first == baseSpeciesID }) else { return nil }
        return EvoLine(baseID: baseSpeciesID, tree: chain(ids), rarity: .rare,
                       names: Dictionary(uniqueKeysWithValues: ids.map { ($0, entries[$0]!.names) }))
    }

    static func details(speciesID: Int) -> PokemonDetails? {
        guard let e = entries[speciesID] else { return nil }
        let keys = PokemonStatCalculator.order
        return PokemonDetails(
            speciesID: e.id, name: e.names["en"] ?? "", height: 10, weight: 300,
            baseExperience: 100, genderRate: -1, types: e.types,
            baseStats: Dictionary(uniqueKeysWithValues: zip(keys, e.stats).map { ($0, $1) }),
            abilities: [PokemonAbilityOption(name: e.ability, slot: 1, isHidden: false)],
            moves: e.moves.map {
                PokemonMoveOption(name: $0.name, learnMethods: [PokemonMoveLearnMethod(method: "level-up", level: $0.level)])
            })
    }
}

/// Serves Digimon from `DigimonCatalog` and delegates everything else (Pokémon) to PokéAPI.
struct DigimonAwareProvider: PokeProviding, PokemonDetailProviding {
    let inner: any PokeProviding

    func line(baseSpeciesID: Int) async throws -> EvoLine {
        if let local = DigimonCatalog.line(baseSpeciesID: baseSpeciesID) { return local }
        return try await inner.line(baseSpeciesID: baseSpeciesID)
    }

    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        try await inner.baseSpeciesIndex() + DigimonCatalog.baseIDs.map {
            BaseSpecies(id: $0, captureRate: DigimonCatalog.captureRate)
        }
    }

    func baseSpecies(id: Int) async throws -> BaseSpecies? {
        if DigimonCatalog.baseIDs.contains(id) { return BaseSpecies(id: id, captureRate: DigimonCatalog.captureRate) }
        return try await inner.baseSpecies(id: id)
    }

    func pokemonDetails(speciesID: Int) async throws -> PokemonDetails {
        if let local = DigimonCatalog.details(speciesID: speciesID) { return local }
        guard let detail = inner as? any PokemonDetailProviding else { throw URLError(.unsupportedURL) }
        return try await detail.pokemonDetails(speciesID: speciesID)
    }
}

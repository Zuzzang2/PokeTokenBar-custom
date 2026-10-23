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
    /// Shiny Koromon branches off to this line instead of Agumon's; normal ones never take it.
    static let blackAgumonLine: [Int] = [9006, 9007, 9008]
    static let shinyOnlyIDs: Set<Int> = Set(blackAgumonLine)
    /// Granted on the graduation that completes both of these finals. Not in `baseIDs`, so never hatched.
    static let omegamonID = 9021
    static let omegamonRequirements: Set<String> = ["9001:9005", "9011:9015"]
    static let gabumonLine: [Int] = [9011, 9012, 9013, 9014, 9015]
    /// Five-stage lines generated from `lineSpecs`: Guilmon 9031, Veemon 9041, Piyomon 9051,
    /// Patamon 9061, Tentomon 9071, Gomamon 9081.
    static let extraLines: [[Int]] = lineSpecs.map { spec in (0..<5).map { spec.base + $0 } }
    static let baseIDs: [Int] = [agumonLine[0], gabumonLine[0]] + extraLines.map { $0[0] }
    /// Same as `PokeAPIClient`'s capture-rate threshold for `.rare`.
    static let captureRate = 45

    private static let handWritten: [Entry] = [
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

        Entry(id: 9006, names: ["ko": "블랙아구몬", "en": "BlackAgumon", "ja": "ブラックアグモン"], types: ["dark"],
              stats: [65, 72, 55, 60, 50, 70], ability: "blaze",
              moves: [("scratch", 1), ("ember", 1), ("bite", 14), ("shadow-claw", 22)]),
        Entry(id: 9007, names: ["ko": "블랙그레이몬", "en": "BlackGreymon", "ja": "ブラックグレイモン"], types: ["dark", "dragon"],
              stats: [90, 105, 85, 85, 70, 70], ability: "blaze",
              moves: [("ember", 1), ("headbutt", 1), ("dark-pulse", 24), ("dragon-claw", 32)]),
        Entry(id: 9008, names: ["ko": "스컬그레이몬", "en": "SkullGreymon", "ja": "スカルグレイモン"], types: ["dark", "ghost"],
              stats: [100, 130, 70, 100, 60, 80], ability: "blaze",
              moves: [("shadow-claw", 1), ("crunch", 1), ("hex", 30), ("hyper-beam", 42)]),
        Entry(id: 9021, names: ["ko": "오메가몬", "en": "Omegamon", "ja": "オメガモン"], types: ["dragon", "steel"],
              stats: [110, 140, 120, 110, 100, 100], ability: "blaze",
              moves: [("flash-cannon", 1), ("dragon-claw", 1), ("sacred-sword", 40), ("fire-blast", 55)]),

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
    ]

    private static let entries: [Int: Entry] = Dictionary(
        uniqueKeysWithValues: (handWritten + lineSpecs.flatMap(lineEntries)).map { ($0.id, $0) })

    static func contains(_ id: Int) -> Bool { entries[id] != nil }

    private struct Stage {
        let ko: String, en: String, ja: String
        let types: [String]
        let moves: [(name: String, level: Int)]
    }
    private struct LineSpec {
        let base: Int
        let ability: String
        let stages: [Stage]
    }
    /// Shared stage curve: baby, child, adult, perfect, ultimate (hp, atk, def, spa, spd, spe).
    private static let stageStats: [[Int]] = [
        [50, 38, 38, 38, 38, 42], [65, 65, 55, 60, 52, 66], [90, 95, 82, 82, 72, 80],
        [95, 115, 95, 92, 85, 88], [100, 130, 110, 100, 92, 95]]

    private static func lineEntries(_ spec: LineSpec) -> [Entry] {
        spec.stages.enumerated().map { i, st in
            Entry(id: spec.base + i, names: ["ko": st.ko, "en": st.en, "ja": st.ja], types: st.types,
                  stats: stageStats[i], ability: i == 0 ? "run-away" : spec.ability, moves: st.moves)
        }
    }

    private static let lineSpecs: [LineSpec] = [
        LineSpec(base: 9031, ability: "blaze", stages: [
            Stage(ko: "지기몬", en: "Gigimon", ja: "ジジモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
            Stage(ko: "길몬", en: "Guilmon", ja: "ギルモン", types: ["fire"], moves: [("scratch", 1), ("ember", 1), ("fire-fang", 14), ("flame-burst", 22)]),
            Stage(ko: "그라우몬", en: "Growlmon", ja: "グラウモン", types: ["fire"], moves: [("ember", 1), ("headbutt", 1), ("flamethrower", 24), ("dragon-claw", 32)]),
            Stage(ko: "워그라우몬", en: "WarGrowlmon", ja: "メガログラウモン", types: ["fire", "dragon"], moves: [("flamethrower", 1), ("dragon-claw", 1), ("flash-cannon", 30), ("fire-blast", 40)]),
            Stage(ko: "듀크몬", en: "Gallantmon", ja: "デュークモン", types: ["fire", "steel"], moves: [("flare-blitz", 1), ("dragon-claw", 1), ("flash-cannon", 34), ("fire-blast", 46)])]),
        LineSpec(base: 9041, ability: "justified", stages: [
            Stage(ko: "치보몬", en: "Chibomon", ja: "チビモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("headbutt", 10)]),
            Stage(ko: "브이몬", en: "Veemon", ja: "ブイモン", types: ["dragon"], moves: [("tackle", 1), ("headbutt", 1), ("dragon-breath", 14), ("brick-break", 22)]),
            Stage(ko: "엑스브이몬", en: "ExVeemon", ja: "エクスブイモン", types: ["dragon", "fighting"], moves: [("headbutt", 1), ("dragon-claw", 1), ("brick-break", 24), ("dragon-pulse", 32)]),
            Stage(ko: "패일드라몬", en: "Paildramon", ja: "パイルドラモン", types: ["dragon", "steel"], moves: [("dragon-claw", 1), ("flash-cannon", 1), ("hyper-beam", 30), ("dragon-pulse", 40)]),
            Stage(ko: "임페리얼드라몬", en: "Imperialdramon", ja: "インペリアルドラモン", types: ["dragon", "steel"], moves: [("dragon-pulse", 1), ("flash-cannon", 1), ("hyper-beam", 34), ("outrage", 46)])]),
        LineSpec(base: 9051, ability: "keen-eye", stages: [
            Stage(ko: "요코몬", en: "Yokomon", ja: "ピョコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("peck", 10)]),
            Stage(ko: "피요몬", en: "Biyomon", ja: "ピヨモン", types: ["flying"], moves: [("peck", 1), ("gust", 1), ("wing-attack", 14), ("air-slash", 22)]),
            Stage(ko: "버드라몬", en: "Birdramon", ja: "バードラモン", types: ["fire", "flying"], moves: [("ember", 1), ("wing-attack", 1), ("flamethrower", 24), ("aerial-ace", 32)]),
            Stage(ko: "가루다몬", en: "Garudamon", ja: "ガルダモン", types: ["fire", "flying"], moves: [("flamethrower", 1), ("air-slash", 1), ("fire-blast", 30), ("hurricane", 40)]),
            Stage(ko: "피닉스몬", en: "Phoenixmon", ja: "ホウオウモン", types: ["fire", "flying"], moves: [("fire-blast", 1), ("brave-bird", 1), ("hurricane", 34), ("sky-attack", 46)])]),
        LineSpec(base: 9061, ability: "serene-grace", stages: [
            Stage(ko: "토코몬", en: "Tokomon", ja: "トコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("gust", 10)]),
            Stage(ko: "파닥몬", en: "Patamon", ja: "パタモン", types: ["normal", "flying"], moves: [("tackle", 1), ("gust", 1), ("headbutt", 14), ("air-slash", 22)]),
            Stage(ko: "엔젤몬", en: "Angemon", ja: "エンジェモン", types: ["flying", "psychic"], moves: [("confusion", 1), ("wing-attack", 1), ("psychic", 24), ("aerial-ace", 32)]),
            Stage(ko: "매그나엔젤몬", en: "MagnaAngemon", ja: "ホーリーエンジェモン", types: ["flying", "psychic"], moves: [("psychic", 1), ("sacred-sword", 1), ("air-slash", 30), ("hyper-beam", 40)]),
            Stage(ko: "세라피몬", en: "Seraphimon", ja: "セラフィモン", types: ["flying", "psychic"], moves: [("psychic", 1), ("hyper-beam", 1), ("air-slash", 34), ("sacred-sword", 46)])]),
        LineSpec(base: 9071, ability: "static", stages: [
            Stage(ko: "모티몬", en: "Motimon", ja: "モチモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("bug-bite", 10)]),
            Stage(ko: "텐타몬", en: "Tentomon", ja: "テントモン", types: ["bug", "electric"], moves: [("thunder-shock", 1), ("bug-bite", 1), ("spark", 14), ("bug-buzz", 22)]),
            Stage(ko: "카부테리몬", en: "Kabuterimon", ja: "カブテリモン", types: ["bug", "electric"], moves: [("thunder-shock", 1), ("bug-bite", 1), ("thunderbolt", 24), ("x-scissor", 32)]),
            Stage(ko: "메가카부테리몬", en: "MegaKabuterimon", ja: "アトラーカブテリモン", types: ["bug", "electric"], moves: [("thunderbolt", 1), ("x-scissor", 1), ("megahorn", 30), ("thunder", 40)]),
            Stage(ko: "헤라클카부테리몬", en: "HerculesKabuterimon", ja: "ヘラクルカブテリモン", types: ["bug", "electric"], moves: [("thunder", 1), ("megahorn", 1), ("bug-buzz", 34), ("hyper-beam", 46)])]),
        LineSpec(base: 9081, ability: "torrent", stages: [
            Stage(ko: "푸카몬", en: "Pukamon", ja: "プカモン", types: ["water"], moves: [("tackle", 1), ("growl", 5), ("water-gun", 10)]),
            Stage(ko: "고마몬", en: "Gomamon", ja: "ゴマモン", types: ["water"], moves: [("tackle", 1), ("water-gun", 1), ("aqua-jet", 14), ("bubble-beam", 22)]),
            Stage(ko: "이가몬", en: "Ikkakumon", ja: "イッカクモン", types: ["water", "ice"], moves: [("water-gun", 1), ("horn-attack", 1), ("ice-beam", 24), ("horn-drill", 32)]),
            Stage(ko: "주드몬", en: "Zudomon", ja: "ズドモン", types: ["water", "fighting"], moves: [("hammer-arm", 1), ("waterfall", 1), ("surf", 30), ("close-combat", 40)]),
            Stage(ko: "플레시오몬", en: "Plesiomon", ja: "プレシオモン", types: ["water", "dragon"], moves: [("hydro-pump", 1), ("dragon-pulse", 1), ("surf", 34), ("hyper-beam", 46)])]),
    ]

    private static func chain(_ ids: [Int]) -> EvoNode {
        let tail = ids.dropFirst()
        return EvoNode(speciesID: ids[0], children: tail.isEmpty ? [] : [chain(Array(tail))])
    }

    private static func names(_ ids: [Int]) -> [Int: [String: String]] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, entries[$0]!.names) })
    }

    static func line(baseSpeciesID: Int) -> EvoLine? {
        if baseSpeciesID == omegamonID {
            return EvoLine(baseID: omegamonID, tree: EvoNode(speciesID: omegamonID, children: []),
                           rarity: .legendary, names: names([omegamonID]))
        }
        if baseSpeciesID == agumonLine[0] {
            let tree = EvoNode(speciesID: baseSpeciesID,
                               children: [chain(agumonLine).children[0], chain(blackAgumonLine)])
            return EvoLine(baseID: baseSpeciesID, tree: tree, rarity: .rare,
                           names: names(agumonLine + blackAgumonLine))
        }
        guard let ids = ([gabumonLine] + extraLines).first(where: { $0.first == baseSpeciesID }) else { return nil }
        return EvoLine(baseID: baseSpeciesID, tree: chain(ids), rarity: .rare, names: names(ids))
    }

    /// Of `children`, the ones this individual may evolve into: shiny takes the shiny-only branch,
    /// normal never does. Nodes without a shiny-only child (every Pokémon) keep all children.
    static func eligibleChildren(_ children: [EvoNode], shiny: Bool) -> [EvoNode] {
        let eligible = children.filter { shinyOnlyIDs.contains($0.speciesID) == shiny }
        return eligible.isEmpty ? children : eligible
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

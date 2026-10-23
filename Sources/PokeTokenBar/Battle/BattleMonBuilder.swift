import Foundation

// SPIKE: turns owned Pokémon (raising companion + Pokédex graduates) into level-50 BattleMons.

/// One owned Pokémon the player can put in the party.
struct BattleCandidate: Identifiable, Sendable {
    let id: String
    let speciesID: Int
    let name: String
    let isShiny: Bool
    let profile: PokemonProfile?
    let nature: PokemonNature?
    let isRaising: Bool
}

enum BattleMonBuilder {
    static let maxParty = 6
    static let maxNicknameLength = 12

    /// Display name in the plaza and battles. It is also the MCPeerID display name, which traps
    /// above 63 UTF-8 bytes, so it is capped at 12 characters (36 bytes even for Korean).
    static func trainerName(nickname: String, fallback: String) -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? fallback.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
        return base.isEmpty ? "트레이너" : String(base.prefix(maxNicknameLength))
    }

    @MainActor
    static func candidates(companion: CompanionStore) -> [BattleCandidate] {
        let lang = companion.language
        var out: [BattleCandidate] = []
        if let a = companion.state.active {
            // `displayName` reads "Token Egg" until the evolution line loads after launch; the dex
            // record of the raising line already carries localized names.
            let recorded = companion.dexEntries.lazy.compactMap { $0.names?[a.currentID] }.first
            let name = companion.currentLine != nil ? companion.displayName
                : recorded.flatMap { lang.resolveName($0) } ?? "#\(a.currentID)"
            out.append(BattleCandidate(id: "active", speciesID: a.currentID, name: name,
                                       isShiny: a.displaysShiny, profile: a.profile, nature: a.nature, isRaising: true))
        }
        for entry in companion.dexEntriesSorted where !companion.isActiveDexEntry(entry) {
            let name = lang.resolveName(entry.names?[entry.finalID] ?? [:]) ?? "#\(entry.finalID)"
            out.append(BattleCandidate(id: entry.id, speciesID: entry.finalID, name: name,
                                       isShiny: entry.isShiny, profile: entry.profile, nature: entry.nature, isRaising: false))
        }
        return out
    }

    /// Dev fallback (raw `swift run` has no save): three random Pokémon so two local instances can battle.
    static func randomCandidates(count: Int = 3) -> [BattleCandidate] {
        (0..<count).map { i in
            let id = Int.random(in: 1...649)
            return BattleCandidate(id: "random-\(i)", speciesID: id, name: "#\(id)", isShiny: false,
                                   profile: nil, nature: nil, isRaising: false)
        }
    }

    static func build(_ candidate: BattleCandidate, trainer: String) async throws -> BattleMon {
        // Digimon are not in PokéAPI; their stats and moves live in the bundled catalog.
        let digimon = DigimonCatalog.details(speciesID: candidate.speciesID)
        let details: PokemonDetails
        if let digimon { details = digimon } else {
            details = try await PokeAPIClient.shared.pokemonDetails(speciesID: candidate.speciesID)
        }
        var profile = candidate.profile ?? PokemonProfile.generate(seed: UInt64.random(in: 1...UInt64.max))
        profile.enrich(with: details)
        profile.level = 50
        let nature = candidate.nature ?? PokemonNature.allCases.randomElement()
        let stats = PokemonStatCalculator.stats(details: details, profile: profile, nature: nature)
        var name = candidate.name
        if name.hasPrefix("#"), digimon == nil { name = await MoveDataClient.shared.speciesName(candidate.speciesID) ?? details.name }
        return BattleMon(
            trainer: trainer,
            name: name,
            speciesID: candidate.speciesID,
            isShiny: candidate.isShiny,
            types: details.types,
            stats: Dictionary(uniqueKeysWithValues: stats.map { ($0.name, $0.value) }),
            moves: await pickMoves(details: details))
    }

    /// Last four damaging level-up moves learnable by 50. Falls back to Tackle.
    static func pickMoves(details: PokemonDetails) async -> [BattleMove] {
        let candidates = details.levelUpMoves(through: 50).map(\.name).reversed()
        var picked: [BattleMove] = []
        for name in candidates where picked.count < 4 {
            if let move = await MoveDataClient.shared.move(name), move.power > 0 { picked.append(move) }
        }
        if picked.isEmpty {
            picked = [BattleMove(name: "몸통박치기", type: "normal", power: 40, accuracy: 100, isPhysical: true, priority: 0)]
        }
        return picked.reversed()
    }
}

actor MoveDataClient {
    static let shared = MoveDataClient()
    private var cache: [String: BattleMove?] = [:]

    private struct NamedRef: Decodable { let name: String }
    private struct LocalName: Decodable { let name: String; let language: NamedRef }
    private struct MoveDTO: Decodable {
        let name: String
        let power: Int?
        let accuracy: Int?
        let priority: Int
        let type: NamedRef
        let damage_class: NamedRef
        let names: [LocalName]
    }
    private struct SpeciesNameDTO: Decodable { let names: [LocalName] }

    func move(_ name: String) async -> BattleMove? {
        if let hit = cache[name] { return hit }
        guard let url = URL(string: "https://pokeapi.co/api/v2/move/\(name)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let dto = try? JSONDecoder().decode(MoveDTO.self, from: data) else { return nil }
        let display = dto.names.first { $0.language.name == "ko" }?.name ?? dto.name
        let move = dto.damage_class.name == "status" ? nil : BattleMove(
            name: display, type: dto.type.name, power: dto.power ?? 0, accuracy: dto.accuracy,
            isPhysical: dto.damage_class.name == "physical", priority: dto.priority)
        cache[name] = move
        return move
    }

    func speciesName(_ id: Int) async -> String? {
        guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon-species/\(id)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let dto = try? JSONDecoder().decode(SpeciesNameDTO.self, from: data) else { return nil }
        return dto.names.first { $0.language.name == "ko" }?.name
    }
}

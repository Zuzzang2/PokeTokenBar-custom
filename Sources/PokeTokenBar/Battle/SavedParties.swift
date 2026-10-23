import Foundation

// SPIKE: favourite party combinations, saved on this Mac before entering the plaza.

struct SavedParty: Codable, Equatable, Identifiable {
    struct Member: Codable, Equatable {
        let id: String          // BattleCandidate.id at save time
        let speciesID: Int
        let name: String
        let shiny: Bool
    }

    var id = UUID().uuidString
    var name: String
    var members: [Member]       // party order: first = lead
}

enum SavedPartyStore {
    static let key = "battleSavedParties"
    static let maxSaved = 8
    static let maxNameLength = 12

    static func load(_ defaults: UserDefaults = .standard) -> [SavedParty] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([SavedParty].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [SavedParty], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: key) }
    }

    /// Newest first. Saving under an existing name replaces it; the list never exceeds `maxSaved`.
    static func adding(_ party: SavedParty, to list: [SavedParty]) -> [SavedParty] {
        Array(([party] + list.filter { $0.name != party.name }).prefix(maxSaved))
    }

    /// "조합 3" style default: the first number not used by an existing name.
    static func defaultName(in list: [SavedParty]) -> String {
        let taken = Set(list.map(\.name))
        return (1...(maxSaved + 1)).map { "조합 \($0)" }.first { !taken.contains($0) } ?? "조합"
    }

    /// Candidate ids to select for `party`, in party order. A member that is gone (released, or the
    /// raising Pokémon evolved) is matched by species and shininess instead; anything still missing is dropped.
    static func resolve(_ party: SavedParty, candidates: [BattleCandidate], limit: Int) -> (ids: [String], missing: Int) {
        var ids: [String] = []
        for member in party.members {
            let exact = candidates.first { $0.id == member.id && !ids.contains($0.id) }
            let similar = candidates.first {
                $0.speciesID == member.speciesID && $0.isShiny == member.shiny && !ids.contains($0.id)
            }
            if let hit = exact ?? similar { ids.append(hit.id) }
        }
        let capped = Array(ids.prefix(limit))
        return (capped, party.members.count - capped.count)
    }
}

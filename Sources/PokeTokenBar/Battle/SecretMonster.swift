import Foundation

/// 무쇠깨비 — a one-off battle monster for a single trainer, plus free pick of every Gen 1–5 species.
/// Both are offered in the party picker only on a Mac where the `battleSecretMonster` default is set,
/// and every 무쇠깨비 battle stat is pinned to `battleStat`. Data and sprites live with the bundled
/// species in `DigimonCatalog` (id 9101, never hatched).
enum SecretMonster {
    static let id = 9101
    static let unlockKey = "battleSecretMonster"
    static let battleStat = 999

    static func isUnlocked(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: unlockKey)
    }

    static let candidate = BattleCandidate(id: "secret-\(id)", speciesID: id, name: "무쇠깨비", isShiny: false,
                                           profile: nil, nature: nil, isRaising: false)

    /// The party candidates with 무쇠깨비 first and every species after the owned ones when unlocked.
    static func withSecret(_ list: [BattleCandidate], unlocked: Bool) -> [BattleCandidate] {
        unlocked ? [candidate] + list + SpeciesRoster.candidates : list
    }
}

extension SecretMonster {
    /// Candidates that come from the unlock rather than the player's own collection.
    static func isGranted(_ c: BattleCandidate) -> Bool { c.id.hasPrefix("secret-") || c.id.hasPrefix("free-") }

    /// What plaza peers may browse as this trainer's collection.
    static func ownedOnly(_ list: [BattleCandidate]) -> [BattleCandidate] { list.filter { !isGranted($0) } }
}

/// Every Gen 1–5 species (PokéAPI ids 1…649) with Korean and English names, from the bundled
/// assets/battle/species_names.json, so the free-pick list needs no network.
enum SpeciesRoster {
    struct Name: Decodable, Sendable {
        let id: Int
        let ko: String
        let en: String
    }

    static let names: [Name] = {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("battle")) }
        dirs.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../assets/battle").standardized)   // dev / swift test
        for dir in dirs {
            if let data = try? Data(contentsOf: dir.appendingPathComponent("species_names.json")),
               let decoded = try? JSONDecoder().decode([Name].self, from: data) { return decoded }
        }
        return []
    }()

    static var candidates: [BattleCandidate] {
        names.map { n in
            BattleCandidate(id: "free-\(n.id)", speciesID: n.id, name: n.ko.isEmpty ? n.en : n.ko, isShiny: false,
                            profile: PokemonProfile.generate(seed: UInt64(n.id)),   // same IVs every time
                            nature: nil, isRaising: false)
        }
    }

    /// Case-insensitive match on the Korean/English name or the dex number.
    static func filter(_ list: [BattleCandidate], query: String) -> [BattleCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return list }
        let english = Dictionary(uniqueKeysWithValues: names.map { ($0.id, $0.en.lowercased()) })
        return list.filter { c in
            c.name.lowercased().contains(q) || (english[c.speciesID]?.contains(q) ?? false) || String(c.speciesID) == q
        }
    }
}

import Foundation

/// 무쇠깨비 — a one-off battle monster for a single trainer. It is offered in the party picker only
/// on a Mac where `defaults write io.github.chattymin.poketokenbar battleSecretMonster -bool YES`
/// was run, and every battle stat is pinned to `battleStat`. Data and sprites live with the bundled
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

    /// The party candidates with 무쇠깨비 first when unlocked.
    static func withSecret(_ list: [BattleCandidate], unlocked: Bool) -> [BattleCandidate] {
        unlocked ? [candidate] + list : list
    }
}

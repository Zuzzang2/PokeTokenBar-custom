import CoreGraphics
import Foundation

// SPIKE: the raised Pokémon / Digimon follows the player through 픽셀 모험 as a pet, fights next to them and
// fetches dropped items. The pet is not saved: it is read from the companion on every launch.

struct RpgPetInfo: Codable, Sendable, Equatable {
    var speciesID: Int
    var shiny: Bool
    var name: String
    /// The companion's attack stat on the battle scale (level-50 stats, roughly 60...200).
    var power: Int
    var element: RpgElement

    /// Remote players send this over the wire; keep it inside sane bounds.
    var sanitized: RpgPetInfo {
        RpgPetInfo(speciesID: min(max(speciesID, 1), 99_999), shiny: shiny, name: String(name.prefix(12)),
                   power: min(max(power, 1), 400), element: element)
    }
}

/// The pet in the world; `info` is what its owner sent, the rest is simulated by the host.
struct RpgPetState {
    let owner: Int
    var map: RpgMapID
    var pos: CGPoint
    var facingRight = true
    var moving = false
    var attackAt = 0.0
    var info: RpgPetInfo
}

struct RpgPetPub: Codable, Sendable {
    let owner: Int
    let map: RpgMapID
    let x: Double, y: Double
    let facingRight: Bool
    let moving: Bool
    let speciesID: Int
    let shiny: Bool
    let name: String
}

enum RpgPetFactory {
    /// The raised companion as a pet, or nil while it is still an egg.
    @MainActor
    static func make(companion: CompanionStore) async -> RpgPetInfo? {
        guard let pick = BattleMonBuilder.candidates(companion: companion).first(where: \.isRaising),
              let mon = try? await BattleMonBuilder.build(pick, trainer: "") else { return nil }
        return RpgPetInfo(speciesID: pick.speciesID, shiny: pick.isShiny, name: pick.name,
                          power: mon.stats["attack"] ?? 80, element: element(for: mon.types)).sanitized
    }

    /// The pet attacks with the element of its first type.
    static func element(for types: [String]) -> RpgElement {
        switch types.first {
        case "fire": return .fire
        case "water", "ice": return .ice
        case "electric": return .thunder
        case "poison": return .poison
        case "flying": return .wind
        case "psychic", "ghost", "fairy": return .holy
        case "dark", "dragon": return .cosmic
        default: return .base
        }
    }
}

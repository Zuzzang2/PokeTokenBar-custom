import Foundation

// SPIKE: the damage rules in one place, as pure functions, so the game, the stat window and the tests agree.
//
//   player hit   = attack × skill power × spread(0.9…1.1) × mitigation(attack, monster defense) × element × crit
//   monster hit  = monster attack × spread × mitigation(attack, player defense) × buffs
//   mitigation   = a / (a + 0.6 × defense)      share of the hit that gets through; never 0, never above 1
//
// Unlike a flat subtraction, mitigation never collapses to "1 damage" when defense grows past attack: it only shrinks the hit.

enum RpgCombat {
    static let spread = 0.1
    static let critMultiplier = 1.7
    static let ambushMultiplier = 2.1
    static let defenseWeight = 0.6
    /// Extra / reduced damage against a monster of an element it is weak to / resists.
    static let weakBonus = 0.3
    static let resistPenalty = 0.3

    static func mitigation(_ attack: Double, defense: Double) -> Double {
        guard attack > 0 else { return 0 }
        return attack / (attack + defenseWeight * max(0, defense))
    }

    /// Elements a target takes extra damage from. Base-element targets have no weakness.
    static func weakTo(_ target: RpgElement) -> Set<RpgElement> {
        switch target {
        case .fire: return [.ice]
        case .ice: return [.fire]
        case .wind: return [.thunder]
        case .thunder: return [.wind]
        case .holy: return [.cosmic]
        case .cosmic: return [.holy]
        case .poison: return [.holy]
        case .base: return []
        }
    }

    /// 1.3 against a weakness, 0.7 against the target's own element, otherwise 1.
    static func affinity(attacker: RpgElement, target: RpgElement) -> Double {
        if weakTo(target).contains(attacker) { return 1 + weakBonus }
        if attacker == target, target != .base { return 1 - resistPenalty }
        return 1
    }

    /// Damage of one player hit. `roll` is the 0…1 position inside the ±10% spread (0.5 = the middle).
    static func playerHit(base: Double, monsterDefense: Double, element: RpgElement, monsterElement: RpgElement,
                          crit: Bool, ambush: Bool = false, roll: Double = 0.5) -> Double {
        let spreadFactor = 1 - spread + 2 * spread * roll
        var dmg = base * mitigation(base, defense: monsterDefense) * spreadFactor * affinity(attacker: element, target: monsterElement)
        if crit { dmg *= ambush ? ambushMultiplier : critMultiplier }
        return max(1, dmg)
    }

    /// Damage a player takes from a monster hit of `raw` attack, before shields and buffs.
    static func monsterHit(raw: Double, playerDefense: Double, roll: Double = 0.5) -> Double {
        max(1, raw * mitigation(raw, defense: playerDefense) * (1 - spread + 2 * spread * roll))
    }

    /// The window's damage readout: weakest and strongest non-crit hit of an attack of `base` on a defense-0 target, and the crit top.
    static func readout(attack: Double) -> (min: Double, max: Double, crit: Double) {
        (attack * (1 - spread), attack * (1 + spread), attack * (1 + spread) * critMultiplier)
    }
}

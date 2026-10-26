import Foundation
@testable import PokeTokenBar

/// The damage rules (`RpgCombat`) and that the world actually uses them.
func combatChecks() {
    check(abs(RpgCombat.mitigation(100, defense: 0) - 1) < 1e-9, "no defense lets everything through")
    check(RpgCombat.mitigation(100, defense: 1_000_000) > 0, "mitigation never reaches 0")
    check(RpgCombat.mitigation(500, defense: 100) > RpgCombat.mitigation(500, defense: 300), "more defense lets less through")
    let low = RpgCombat.playerHit(base: 10, monsterDefense: 500, element: .base, monsterElement: .base, crit: false)
    check(low >= 1 && low < 10, "a weak hit on a tough monster still does something (\(low))")
    let mid = RpgCombat.playerHit(base: 200, monsterDefense: 50, element: .base, monsterElement: .base, crit: false, roll: 0.5)
    let lo = RpgCombat.playerHit(base: 200, monsterDefense: 50, element: .base, monsterElement: .base, crit: false, roll: 0)
    let hi = RpgCombat.playerHit(base: 200, monsterDefense: 50, element: .base, monsterElement: .base, crit: false, roll: 1)
    check(abs(lo / mid - 0.9) < 1e-9 && abs(hi / mid - 1.1) < 1e-9, "the spread is ±10% around the middle")
    let crit = RpgCombat.playerHit(base: 200, monsterDefense: 50, element: .base, monsterElement: .base, crit: true, roll: 0.5)
    let ambush = RpgCombat.playerHit(base: 200, monsterDefense: 50, element: .base, monsterElement: .base, crit: true, ambush: true, roll: 0.5)
    check(abs(crit / mid - 1.7) < 1e-9 && abs(ambush / mid - 2.1) < 1e-9, "crit ×1.7, ambush crit ×2.1")
    check(RpgCombat.affinity(attacker: .fire, target: .ice) == 1.3 && RpgCombat.affinity(attacker: .ice, target: .ice) == 0.7
          && RpgCombat.affinity(attacker: .fire, target: .base) == 1, "weakness +30%, own element -30%, base targets neutral")
    check(RpgCombat.monsterHit(raw: 100, playerDefense: 0) == 100 && RpgCombat.monsterHit(raw: 100, playerDefense: 200) < 100, "player defense cuts monster hits")

    let r = RpgCombat.readout(attack: 1000)
    check(r.min == 900 && r.max == 1100 && abs(r.crit - 1870) < 1e-6, "the readout matches the spread and crit rules")
}

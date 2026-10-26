import Foundation
@testable import PokeTokenBar

/// Rogue-specific behaviour: real stealth, ambush crit, and the class's skills as a set.
func rogueChecks() {
    // 은신: monsters that were chasing lose the player, and attacking breaks it.
    var ok = false, brokeOnAttack = false, ambush = false, hiddenFromPack = false
    for _ in 0..<6 where !ok {
        guard let (w, a) = skillBench(.rogue, job: 0, skill: "r_vanish") else { continue }
        let me = w.player(2)!
        let dx = a.pos.x - me.pos.x, dy = a.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
        var input = RpgInput()
        input.pos = me.pos
        input.facing = CGVector(dx: dx / d, dy: dy / d)
        for _ in 0..<20 { w.step(1.0 / 30, inputs: [2: input]) }
        let chasing = (w.mobs[.desert] ?? []).filter { !$0.dead && $0.targetID == 2 }.count
        guard chasing > 0 else { continue }
        w.perform(.cast(0), for: 2)
        let stealthOn = w.player(2)!.stealthUntil > w.time
        for _ in 0..<10 { w.step(1.0 / 30, inputs: [2: input]) }
        let stillChasing = (w.mobs[.desert] ?? []).filter { !$0.dead && $0.targetID == 2 && $0.def.behavior != .boss }.count
        hiddenFromPack = stealthOn && stillChasing == 0
        var attack = input
        attack.attack = true
        w.step(1.0 / 30, inputs: [2: attack])
        let after = w.player(2)!
        brokeOnAttack = after.stealthUntil == 0
        ambush = after.ambushUntil > w.time
        ok = hiddenFromPack && brokeOnAttack && ambush
    }
    check(hiddenFromPack, "stealth makes chasing monsters lose the rogue")
    check(brokeOnAttack && ambush, "attacking breaks stealth and starts the ambush window")
}

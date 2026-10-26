import Foundation
@testable import PokeTokenBar

/// 3차·4차 전직: gating by level and gold, skills learned, stronger multipliers, template skills present for every branch.
func tierChecks() {
    check(RpgTiers.skills.count == 64 && RpgTiers.skills.allSatisfy { $0.fx != nil }, "64 template skills for the 3차·4차 jobs")
    for cls in RpgClass.allCases {
        for job in 1...2 {
            let t1 = RpgJobs.def(cls, job)!, t2 = RpgJobs.def(cls, job, tier: 2)!, t3 = RpgJobs.def(cls, job, tier: 3)!
            check(t2.attack >= t1.attack && t3.attack >= t2.attack && t3.hp >= t1.hp, "\(t1.name) → \(t2.name) → \(t3.name) only get stronger")
        }
    }
    var p = RpgSaveStore.newPlayer(name: "t", cls: .mage, id: 1)
    p.level = 50
    p.gold = 1_000_000
    let w = RpgWorld(player: p)
    w.perform(.promote, for: 1)
    check(w.player(1)!.tier == 0, "no promotion without a 2차 job")
    w.perform(.advance(1), for: 1)
    let goldBefore = w.player(1)!.gold
    w.perform(.promote, for: 1)
    let third = w.player(1)!
    check(third.tier == 2 && third.title == "불꽃 대마도사" && goldBefore - third.gold >= 25_000, "Lv50 mage promotes to 3차 for gold: \(third.title)")
    check(third.skills[RpgTiers.skillIDs(.mage, 1, tier: 2)[0]] != nil && third.skills[RpgTiers.skillIDs(.mage, 1, tier: 2)[1]] == nil, "3차 teaches its first skill at Lv45 and the second at Lv55")
    w.perform(.promote, for: 1)
    check(w.player(1)!.tier == 2, "4차 needs Lv70")
    check(third.skillList.count == 8 + 4, "skill window lists class, 2차 and 3차 skills: \(third.skillList.count)")
    var q = RpgSaveStore.newPlayer(name: "poor", cls: .rogue, id: 1)
    q.level = 45
    q.gold = 100
    let w2 = RpgWorld(player: q)
    w2.perform(.advance(2), for: 1)
    w2.perform(.promote, for: 1)
    check(w2.player(1)!.tier == 1, "promotion needs the gold")
    let saved = RpgSaveStore.snapshot(third)
    let back = RpgSaveStore.player(from: saved, id: 1)
    check(back.tier == 2 && back.job == 1, "tier survives a save")
    var old = saved
    old.tier = nil
    check(RpgSaveStore.player(from: old, id: 1).tier == 1, "a save from before tiers counts as 2차")
}

import Foundation
@testable import PokeTokenBar

/// 능력치 포인트: earned per level, spent through actions, effects on the derived stats, untrusted saves cleaned.
func statChecks() {
    var p = RpgSaveStore.newPlayer(name: "t", cls: .warrior, id: 1)
    p.level = 10
    p.ap = 10
    p.gold = 100_000
    let w = RpgWorld(player: p)
    let before = (p.attack(at: 0), p.maxHP, p.maxMP)
    w.perform(.addStat(0), for: 1)
    w.perform(.addStat(2), for: 1)
    w.perform(.addStat(3), for: 1)
    let after = w.player(1)!
    check(after.ap == 7 && after.stats == [1, 0, 1, 1], "addStat spends one point each: \(after.ap) \(after.stats)")
    check(after.attack(at: 0) > before.0 && after.maxHP > before.1 && after.maxMP > before.2, "stats raise attack, HP and MP")
    w.perform(.addStat(9), for: 1)
    check(w.player(1)!.ap == 7, "bad stat index spends nothing")
    w.perform(.resetStats, for: 1)
    let reset = w.player(1)!
    check(reset.stats == [0, 0, 0, 0] && reset.ap == 10 && reset.gold < 100_000, "reset refunds all points for gold")
    check(RpgStats.clean(ap: nil, stats: nil, level: 5) == (20, [0, 0, 0, 0]), "old save earns every point")
    check(RpgStats.clean(ap: 5000, stats: [9999, 0, 0, 0], level: 5) == (20, [0, 0, 0, 0]), "forged stats are reset")
    check(RpgStats.clean(ap: 2, stats: [3, 5, 0, 10], level: 5).1 == [3, 5, 0, 10], "honest split is kept")
}

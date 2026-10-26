import Foundation
@testable import PokeTokenBar

/// 해저 신전 · 유령 마을 · 지하 마계: spawn tables fit their maps, region materials go round, signature gear keeps to its tier budget.
func underseaHauntedUnderworldChecks() {
    let regions = RpgRegions.all.filter { ["undersea", "haunted", "underworld"].contains($0.id) }
    check(regions.count == 3, "undersea, haunted and underworld are listed")
    let vanilla = RpgItems.all.filter { !$0.id.contains("_") }
    /// The stats a slot actually applies (see RpgPlayer.maxHP / attack / defense / critChance / speed).
    func stats(_ i: RpgItem) -> [Double] {
        switch i.kind {
        case .ring: return [Double(i.bonusHP), Double(i.bonusMP), i.bonusCrit, i.bonusAttack]
        case .amulet: return [Double(i.bonusHP), Double(i.bonusMP), Double(i.defense)]
        case .helmet: return [Double(i.bonusHP), Double(i.defense)]
        case .boots: return [i.bonusSpeed, Double(i.defense)]
        default: return [Double(i.attack), Double(i.defense)]
        }
    }
    // Normal monsters sit on the existing curve: between the nearest vanilla monsters of the same behaviour (±25%).
    let regionMonsters = Set(RpgRegions.all.flatMap(\.monsters).map(\.id))
    let base = RpgMonsters.all.filter { !regionMonsters.contains($0.id) && $0.behavior != .boss }
    for m in regions.flatMap(\.monsters) where m.behavior != .boss && m.behavior != .coward {
        let same = base.filter { $0.behavior == m.behavior }
        let near = [same.filter { $0.level <= m.level }.max { $0.level < $1.level }, same.filter { $0.level >= m.level }.min { $0.level < $1.level }].compactMap { $0 }
        let fits = [\RpgMonsterDef.hp, \.attack, \.xp].allSatisfy { k in
            let vals = near.map { Double($0[keyPath: k]) }
            return !vals.isEmpty && (vals.min()! * 0.8...vals.max()! * 1.25).contains(Double(m[keyPath: k]))
        }
        if !fits { check(false, "\(m.name) Lv\(m.level) sits between \(near.map { "\($0.name) Lv\($0.level)" })") }
    }
    for r in regions {
        for def in r.maps where def.kind != .boss {
            let nums = def.levelText.split { !$0.isNumber }.compactMap { Int($0) }
            let kinds = def.monsters.map { RpgMonsters.def($0.monster) }
            check((3...4).contains(kinds.count) && Set(kinds.map { "\($0.behavior)" }).count >= 3
                  && kinds.allSatisfy { ((nums[0] - 1)...(nums[1] + 1)).contains($0.level) },
                  "\(def.name): 3-4 kinds in 3+ behaviours, all inside \(def.levelText)")
        }
        for def in r.maps where def.kind == .boss {
            let boss = RpgMonsters.def(def.monsters[0].monster)
            check(def.monsters.count == 1 && boss.behavior == .boss && def.levelText == "보스 Lv\(boss.level)"
                  && def.portals.count == 1 && boss.minion.hasPrefix(r.id), "\(def.name): one \(boss.name), its own minion, label matches")
        }
        let drops = Set(r.monsters.flatMap { $0.drops.map(\.item) })
        let used = Set(r.recipes.flatMap { $0.materials.keys })
        check(r.items.allSatisfy { drops.contains($0.id) }, "\(r.id): every region item drops from a region monster")
        check(r.items.filter { $0.kind == .material }.allSatisfy { used.contains($0.id) }, "\(r.id): every region material is used at the smith")
        check(r.items.filter(\.isEquipment).allSatisfy { i in r.recipes.contains { $0.output == i.id } }, "\(r.id): every piece of gear can be crafted")
        for item in r.items where item.isEquipment {
            let peers = vanilla.filter { $0.kind == item.kind }.sorted { $0.price < $1.price }
            guard let same = peers.first(where: { $0.price == item.price }), let next = peers.first(where: { $0.price > item.price }) else {
                check(false, "\(item.name): priced like a real tier with a tier above it"); continue
            }
            let mine = stats(item), budget = stats(same), above = stats(next)
            let spent = zip(mine, budget).filter { $0.1 > 0 }.reduce(0.0) { $0 + $1.0 / $1.1 }
            let room = Double(budget.filter { $0 > 0 }.count)
            let dominates = zip(mine, above).allSatisfy { $0 >= $1 } && zip(mine, above).contains { $0 > $1 }
            check(spent <= room * 1.01 && spent >= room * 0.9 && !dominates,
                  "\(item.name): \(String(format: "%.2f", spent))/\(Int(room)) of the \(same.name) budget, not better than \(next.name)")
        }
    }
}

import Foundation
@testable import PokeTokenBar

/// The four endgame regions (frost, celestial, rift, chaos): layout and seeds, spawns inside each map's band, normal monsters
/// on the built-in late-game curves, bosses on the built-in boss curve with the Emperor of Chaos on top, gear that only uses
/// stats its slot applies and never beats the top real tier, recipes for all of it, and looks no other monster shares.
func endgameChecks() {
    let regionIDs = Set(RpgRegions.all.flatMap(\.monsters).map(\.id))
    let lateBuiltIn = RpgMonsters.all.filter { !regionIDs.contains($0.id) && $0.level >= 58 && $0.id != "demonking" }
    /// Log-linear interpolation (extrapolation past the ends) of `f` over the built-in late monsters of `behavior`.
    func curve(_ behavior: RpgBehavior, _ level: Int, _ f: (RpgMonsterDef) -> Int) -> Double {
        let pts = lateBuiltIn.filter { $0.behavior == behavior }.map { (Double($0.level), log(Double(f($0)))) }.sorted { $0.0 < $1.0 }
        let hi = min(max(pts.firstIndex { $0.0 > Double(level) } ?? pts.count, 1), pts.count - 1)
        let (a, b) = (pts[hi - 1], pts[hi])
        return exp(a.1 + (b.1 - a.1) * (Double(level) - a.0) / max(1, b.0 - a.0))
    }
    /// Passive and coward monsters ride the aggressive curve and are meant to be softer; cowards never attack.
    func onCurve(_ m: RpgMonsterDef) -> Bool {
        let base: RpgBehavior = [.passive, .coward].contains(m.behavior) ? .aggressive : m.behavior
        let keys: [KeyPath<RpgMonsterDef, Int>] = m.behavior == .coward ? [\.hp, \.defense, \.xp] : [\.hp, \.attack, \.defense, \.xp]
        return m.sprite == m.id && keys.allSatisfy { key in
            let r = Double(m[keyPath: key]) / curve(base, m.level) { $0[keyPath: key] }
            return r >= (base == m.behavior ? 0.6 : 0.45) && r <= (m.behavior == .coward ? 1.8 : 1.6)
        }
    }
    let bosses = lateBuiltIn.filter { $0.behavior == .boss }.sorted { $0.level < $1.level }
    func onBossCurve(_ m: RpgMonsterDef) -> Bool {
        let lo = bosses.last { $0.level <= m.level } ?? bosses[0], hi = bosses.first { $0.level >= m.level } ?? bosses[bosses.count - 1]
        let t = hi.level == lo.level ? 0 : Double(m.level - lo.level) / Double(hi.level - lo.level)
        let keys: [KeyPath<RpgMonsterDef, Int>] = [\.hp, \.attack, \.xp]
        return keys.allSatisfy { key in
            abs(Double(m[keyPath: key]) / (Double(lo[keyPath: key]) + Double(hi[keyPath: key] - lo[keyPath: key]) * t) - 1) < 0.05
        }
    }
    /// attack, defense, HP, MP, crit, attack %, speed — and which of them each slot really applies (see `RpgPlayer`).
    func stats(_ i: RpgItem) -> [Double] { [Double(i.attack), Double(i.defense), Double(i.bonusHP), Double(i.bonusMP), i.bonusCrit, i.bonusAttack, i.bonusSpeed] }
    func slot(_ kind: RpgItemKind) -> (applies: [Bool], top: RpgItem?) {
        switch kind {
        case .weapon(let cls): ([true, false, false, false, false, false, false], RpgItems.item("\(cls.weaponPrefix)12"))
        case .armor: ([false, true, false, false, false, false, false], RpgItems.item("armor11"))
        case .ring: ([false, false, true, true, true, true, false], RpgItems.item("ring11"))
        case .amulet: ([false, true, true, true, false, false, false], RpgItems.item("amulet11"))
        case .helmet: ([false, true, true, false, false, false, false], RpgItems.item("helmet11"))
        case .boots: ([false, true, false, false, false, false, true], RpgItems.item("boots11"))
        default: ([], nil)
        }
    }
    let dropped = Set(RpgMonsters.all.flatMap { $0.drops.map(\.item) } + RpgMaterials.bands.map(\.item) + ["stone"])
    let looks = MainActor.assumeIsolated { RpgMonsters.all.map { RpgArt.sprite($0.sprite)?.dataProvider?.data as Data? } }
    func list(_ ids: [String]) -> String { ids.isEmpty ? "" : " — off: \(ids)" }

    for (index, id) in [(11, "frost"), (12, "celestial"), (13, "rift"), (14, "chaos")] {
        guard let region = RpgRegions.all.first(where: { $0.id == id }) else { check(false, "\(id): region is listed"); continue }
        let hunting = (1...7).map { RpgMaps.def(RpgMapID("\(id)_\($0)")) }, bossRooms = region.maps.filter { $0.kind == .boss }
        check(region.maps.count == 7 + bossRooms.count && (1...2).contains(bossRooms.count)
              && region.maps.map(\.seed).sorted() == (1...region.maps.count).map { UInt64(1000 * index + $0) }
              && hunting.allSatisfy { (46...50).contains($0.width) && (28...32).contains($0.height) }
              && bossRooms.allSatisfy { $0.width == 28 && $0.height == 22 && $0.zone != nil && !$0.waypoint }
              && hunting.enumerated().allSatisfy { $1.waypoint == ($0 % 2 == 0) },
              "\(id): 7 hunting grounds + \(bossRooms.count) boss rooms, seeds from \(1000 * index + 1), sizes and waypoints")
        let gates = hunting.dropLast().map { def in def.portals.first { $0.at.x > 40 }?.minLevel ?? 0 }
        check(zip(gates, gates.dropFirst()).allSatisfy { $0 < $1 } && region.minLevel < gates[0], "\(id): gates rise along the chain \(gates)")
        let crowded = hunting.filter { def in
            let band = def.levelText.split { !$0.isNumber }.compactMap { Int($0) }, kinds = def.monsters.map { RpgMonsters.def($0.monster) }
            return !(kinds.allSatisfy { ((band[0] - 1)...(band[1] + 1)).contains($0.level) } && (3...4).contains(kinds.count)
                     && Set(kinds.map { "\($0.behavior)" }).count >= 3)
        }.map(\.id.rawValue)
        check(crowded.isEmpty, "\(id): every hunting ground spawns 3-4 kinds in 3+ behaviours inside its level band" + list(crowded))
        let normals = region.monsters.filter { $0.behavior != .boss }
        check(normals.allSatisfy(onCurve), "\(id): \(normals.count) normal monsters sit on the built-in late curves" + list(normals.filter { !onCurve($0) }.map(\.id)))
        let regular = region.monsters.filter { $0.behavior == .boss && $0.id != "chaos_emperor" }
        check(regular.allSatisfy(onBossCurve), "\(id): bosses follow the built-in boss curve" + list(regular.filter { !onBossCurve($0) }.map(\.id)))
        let badGear = region.items.filter(\.isEquipment).filter { item in
            let (applies, top) = slot(item.kind)
            guard let top else { return true }
            let s = stats(item), used = zip(applies, zip(s, stats(top))).filter(\.0).map(\.1)
            let beatsTop = used.allSatisfy { $0 >= $1 } && used.contains { $0 > $1 }
            return beatsTop || zip(applies, s).contains { !$0 && $1 != 0 } || !region.recipes.contains { $0.output == item.id }
        }.map(\.id)
        check(badGear.isEmpty, "\(id): gear uses only its slot's stats, never beats the top tier and is crafted at the smith" + list(badGear))
        check(region.recipes.allSatisfy { $0.materials.keys.allSatisfy(dropped.contains) }, "\(id): every recipe material drops somewhere")
        let mine = zip(RpgMonsters.all, looks).filter { $0.0.id.hasPrefix("\(id)_") }.map(\.1)
        check(mine.allSatisfy { look in look != nil && looks.filter { $0 == look }.count == 1 }, "\(id): no other monster looks like one of its \(mine.count)")
        // Smoke: a Lv100 warrior stands in each boss room while the boss cycles its moves (summons included), and hunts the last map.
        let ordinary = Set(RpgMonsters.all.filter { $0.behavior != .boss }.map(\.id))
        for room in bossRooms {
            let boss = RpgMonsters.def(room.monsters[0].monster)
            var p = RpgSaveStore.newPlayer(name: "raid", cls: .warrior, id: 2)
            p.level = 100
            p.map = room.id
            p.pos = RpgMap.center(RpgTile(x: 14, y: 17))   // where the north door of the hunting ground lets you in
            (p.armor, p.ring, p.amulet, p.helmet, p.boots) = ("armor11", "ring11", "amulet11", "helmet11", "boots11")
            p.plus["armor11"] = 15
            p.hp = p.maxHP
            let w = world(level: 100)
            w.addPlayer(p)
            for _ in 0..<600 { w.step(1.0 / 30, inputs: [:]) }
            let room = w.mobs[room.id] ?? []
            check(ordinary.contains(boss.minion) && room.contains { $0.def.id == boss.id } && room.contains { $0.summoned && $0.def.id == boss.minion },
                  "\(boss.name): fights 20 s and summons its \(boss.minion)")
        }
        var p = RpgSaveStore.newPlayer(name: "hunter", cls: .warrior, id: 2)
        p.level = 100
        p.map = hunting[6].id
        p.pos = RpgMap.center(RpgTile(x: 4, y: hunting[6].height / 2))
        let w = world(level: 100)
        w.addPlayer(p)
        hunt(w, id: 2, seconds: 10)
        check((w.mobs[hunting[6].id] ?? []).count > 10, "\(hunting[6].name): a Lv100 warrior hunts there for 10 s")
    }
    if let emperor = RpgMonsters.all.first(where: { $0.id == "chaos_emperor" }) {
        let others = RpgMonsters.all.filter { $0.id != emperor.id && $0.behavior == .boss }
        check(emperor.level == 100 && others.allSatisfy { $0.hp < emperor.hp && $0.attack < emperor.attack && $0.defense <= emperor.defense && $0.xp < emperor.xp },
              "\(emperor.name) is the strongest regular boss (\(emperor.hp) HP, \(emperor.attack) ATK)")
    }
}

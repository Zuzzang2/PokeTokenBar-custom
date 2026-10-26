import Foundation
@testable import PokeTokenBar

/// 수정 광산 · 기계 공장 · 하늘 섬: chain layout and gates, spawn tables, the stat curve the regions are balanced on, boss scale,
/// signature gear against the real tiers, distinct sprites, and a 차원문 trip into each region.
func crystalFactorySkyisleChecks() {
    // The curve fitted to the main-line Lv22-58 monsters (see the table at the top of RpgCrystalRegion.swift).
    func base(_ l: Int) -> (hp: Double, atk: Double, def: Double, xp: Double) {
        let L = Double(l)
        return (0.9 * pow(L, 2.3), 115 * pow(L / 28, 1.6), 0.03 * L * L + 0.5 * L, 0.213 * pow(L, 2.4))
    }
    func band(_ text: String) -> ClosedRange<Int> {
        let nums = text.split { !$0.isNumber }.compactMap { Int($0) }
        return nums[0]...(nums.last ?? nums[0])
    }
    let otherMonsters = RpgMonsters.all.filter { m in !["crystal_", "factory_", "skyisle_"].contains { m.id.hasPrefix($0) } }
    for (index, id) in [(5, "crystal"), (6, "factory"), (7, "skyisle")] {
        guard let region = RpgRegions.all.first(where: { $0.id == id }) else { check(false, "\(id): region is listed"); continue }
        let hunting = (1...7).map { RpgMaps.def(RpgMapID("\(id)_\($0)")) }
        let bossRooms = [1, 2].map { RpgMaps.def(RpgMapID("\(id)_b\($0)")) }
        check(region.maps.count == 9 && Set(region.maps.map(\.id)) == Set((hunting + bossRooms).map(\.id)), "\(id): seven hunting grounds and two boss rooms")
        check(region.maps.map(\.seed).sorted() == (1...9).map { UInt64(1000 * index + $0) }, "\(id): seeds \(1000 * index + 1)...\(1000 * index + 9)")
        check(hunting.allSatisfy { (46...50).contains($0.width) && (28...32).contains($0.height) } && bossRooms.allSatisfy { $0.width == 28 && $0.height == 22 && $0.zone != nil },
              "\(id): map sizes")
        check(hunting.enumerated().allSatisfy { $0.element.waypoint == ($0.offset % 2 == 0) } && bossRooms.allSatisfy { !$0.waypoint },
              "\(id): the 차원문 lists the entry and every second hunting ground")
        check(region.minLevel >= band(hunting[0].levelText).lowerBound - 3 && region.minLevel < band(hunting[0].levelText).lowerBound, "\(id): minLevel just below the first map")

        // Gates: forward doors open at the next map's first level, every door into a map carries that map's gate.
        var gate: [RpgMapID: Int] = [hunting[0].id: region.minLevel]
        for def in hunting.dropFirst() { gate[def.id] = band(def.levelText).lowerBound }
        for room in bossRooms {
            let door = hunting.flatMap(\.portals).first { $0.to == room.id }
            gate[room.id] = door?.minLevel
            check(door != nil && door!.at.y == 1 && door!.minLevel < band(room.levelText).lowerBound, "\(id): \(room.name) has a north door below the boss level")
        }
        var gatesOK = true
        for def in region.maps {
            for p in def.portals where p.to != .town && p.minLevel != gate[p.to] { gatesOK = false; print("  gate \(def.id.rawValue) -> \(p.to.rawValue) is \(p.minLevel)") }
        }
        check(gatesOK, "\(id): every door carries the gate of the map it leads to")
        let gates = hunting.compactMap { gate[$0.id] }
        check(zip(gates, gates.dropFirst()).allSatisfy { $0 < $1 }, "\(id): gates rise along the chain \(gates)")
        check(zip(hunting, hunting.dropFirst()).allSatisfy { a, b in a.portals.contains { $0.to == b.id } && b.portals.contains { $0.to == a.id } },
              "\(id): hunting grounds are linked both ways")

        // Spawns: 3-4 kinds in 3+ behaviours, levels inside the band, one boss per room at the band's top.
        var spawnsOK = true
        for def in hunting {
            let b = band(def.levelText)
            let kinds = def.monsters.map { RpgMonsters.def($0.monster) }
            if !(3...4).contains(kinds.count) || Set(kinds.map { "\($0.behavior)" }).count < 3 || !def.monsters.allSatisfy({ (2...10).contains($0.count) }) { spawnsOK = false }
            for m in kinds where !((b.lowerBound - 1)...(b.upperBound + 1)).contains(m.level) || !m.id.hasPrefix(id + "_") { spawnsOK = false; print("  \(m.id) on \(def.id.rawValue)") }
        }
        check(spawnsOK, "\(id): each hunting ground spawns 3-4 kinds of its own monsters inside its level band")
        for room in bossRooms {
            let boss = room.monsters.count == 1 ? RpgMonsters.def(room.monsters[0].monster) : nil
            check(boss?.behavior == .boss && boss?.level == band(room.levelText).lowerBound && region.monsters.contains { $0.id == boss?.minion && $0.behavior != .boss },
                  "\(id): \(room.name) holds one boss of its level with a minion from the region")
        }

        // Monsters: own ids and sprites, Korean names not used elsewhere, every behaviour, stats on the curve.
        let normals = region.monsters.filter { $0.behavior != .boss && $0.behavior != .coward }
        check(region.monsters.allSatisfy { $0.id.hasPrefix(id + "_") && $0.sprite == $0.id && $0.level < 58 }, "\(id): monster ids, sprites and levels (< 58, the late game starts there)")
        check(Set(region.monsters.map(\.name)).isDisjoint(with: otherMonsters.map(\.name)), "\(id): monster names are new")
        let behaviours = Set(region.monsters.map { "\($0.behavior)" })
        check(["passive", "aggressive", "ranged", "flyer", "swarm", "charger", "exploder", "coward", "boss"].allSatisfy(behaviours.contains), "\(id): every behaviour appears")
        let mult: [String: (Double, Double, Double, Double)] = [   // hp, atk, def, xp vs the base curve
            "passive": (0.88, 0.95, 1, 1), "flyer": (0.7, 1, 0.82, 0.93), "ranged": (0.8, 1.03, 0.8, 1),
            "charger": (1.18, 1.06, 0.97, 1.27), "swarm": (0.31, 0.71, 0.49, 0.49), "exploder": (0.55, 1.29, 0.52, 1.1)]
        var curveOK = true
        for m in normals {
            let b = base(m.level)
            // Aggressive monsters are either plain (.92 hp) or golem-like tanks (1.1 hp, 1.05 def).
            let k = mult["\(m.behavior)"] ?? (Double(m.hp) / b.hp > 1 ? (1.1, 1, 1.05, 1.02) : (0.92, 1, 1, 1))
            let ratios = [Double(m.hp) / (b.hp * k.0), Double(m.attack) / (b.atk * k.1), Double(m.defense) / (b.def * k.2), Double(m.xp) / (b.xp * k.3)]
            if !ratios.allSatisfy({ (0.93...1.07).contains($0) }) { curveOK = false; print("  \(m.id) off the curve \(ratios.map { String(format: "%.2f", $0) })") }
        }
        check(curveOK, "\(id): normal monsters sit on the fitted curve (within 7%)")
        // Flyers pay ~7% less than walkers of their level (as in the main line), so compare monsters two or more levels apart.
        let walkers = normals.filter { $0.behavior != .swarm && $0.behavior != .charger && $0.behavior != .exploder }
        check(walkers.allSatisfy { a in walkers.allSatisfy { b in b.level < a.level + 2 || a.xp < b.xp } }, "\(id): XP per kill rises with level")
        let bosses = region.monsters.filter { $0.behavior == .boss }.sorted { $0.level < $1.level }
        check(bosses.count == 2 && bosses.allSatisfy { b in
            let hp = Double(b.hp) / base(b.level).hp, atk = Double(b.attack) / base(b.level).atk
            return (25...40).contains(hp) && (1.4...1.55).contains(atk) && b.drops.filter { $0.item == "stone" && $0.chance == 1 }.count >= 3
        }, "\(id): bosses have 25-40x the HP and ~1.5x the attack of a same-level monster, plus a stone bundle")

        // Items: tier-safe ids, every one obtainable, gear never strictly better than the next real tier.
        let dropped = Set(region.monsters.flatMap { $0.drops.map(\.item) })
        check(region.items.count >= 8 && region.items.allSatisfy { $0.id.hasPrefix(id + "_") && $0.tier == 0 && dropped.contains($0.id) },
              "\(id): \(region.items.count) items, all dropped by the region's monsters")
        check(region.recipes.allSatisfy { r in region.items.contains { $0.id == r.output } && r.gold > 0 }, "\(id): recipes make the region's own items")
        var tiersOK = true
        for item in region.items where item.isEquipment {
            let prefix: String, stats: (RpgItem) -> [Double]
            switch item.kind {
            case .ring: prefix = "ring"; stats = { [Double($0.bonusHP), $0.bonusCrit, $0.bonusAttack] }
            case .amulet: prefix = "amulet"; stats = { [Double($0.bonusHP), Double($0.bonusMP), Double($0.defense)] }
            case .helmet: prefix = "helmet"; stats = { [Double($0.bonusHP), Double($0.defense)] }
            case .boots: prefix = "boots"; stats = { [$0.bonusSpeed, Double($0.defense)] }
            case .armor: prefix = "armor"; stats = { [Double($0.defense)] }
            case .weapon(let cls): prefix = cls.weaponPrefix; stats = { [Double($0.attack)] }
            default: continue
            }
            guard let next = (0...12).compactMap({ RpgItems.item("\(prefix)\($0)") }).first(where: { $0.price > item.price }) else { tiersOK = false; continue }
            let mine = stats(item), theirs = stats(next)
            if zip(mine, theirs).allSatisfy({ $0 >= $1 }) { tiersOK = false; print("  \(item.id) beats \(next.id)") }
        }
        check(tiersOK, "\(id): signature gear is never strictly better than the next real tier")

        // A 차원문 trip: the region opens at its level and drops the traveller on its entry tile, among monsters.
        var p = RpgSaveStore.newPlayer(name: "traveller", cls: .warrior, id: 1)
        p.level = region.minLevel - 1
        let w = RpgWorld(player: p)
        w.perform(.warp(region.entry), for: 1)
        check(w.player(1)?.map == .town, "\(id): the 차원문 refuses Lv\(region.minLevel - 1)")
        var q = RpgSaveStore.newPlayer(name: "traveller", cls: .warrior, id: 1)
        q.level = band(hunting[0].levelText).upperBound
        q.weapon = "sword6"
        q.armor = "armor5"
        q.hp = q.maxHP
        let w2 = RpgWorld(player: q)
        w2.perform(.warp(region.entry), for: 1)
        let want = hunting[0].monsters.reduce(0) { $0 + Int((Double($1.count) * RpgWorld.monsterDensity).rounded(.up)) }
        check(w2.player(1)?.map == region.entry && w2.player(1)?.pos == RpgMap.center(region.entryTile) && w2.mobs[region.entry]?.count == want,
              "\(id): the 차원문 takes a Lv\(q.level) player to \(hunting[0].name) with \(want) monsters")
        hunt(w2, id: 1, seconds: 15)
        check(w2.player(1)?.kills.keys.contains { $0.hasPrefix(id + "_") } == true, "\(id): a Lv\(q.level) warrior in shop gear hunts there")
    }

    // Sprites: no two of the new monsters look alike, and none looks like an older one.
    let mine = RpgMonsters.all.filter { m in ["crystal_", "factory_", "skyisle_"].contains { m.id.hasPrefix($0) } }
    let looks = MainActor.assumeIsolated { () -> (mine: [Data], others: Set<Data>) in
        (mine.compactMap { RpgArt.sprite($0.sprite)?.dataProvider?.data as Data? },
         Set(otherMonsters.compactMap { RpgArt.sprite($0.sprite)?.dataProvider?.data as Data? }))
    }
    check(looks.mine.count == mine.count && Set(looks.mine).count == mine.count && Set(looks.mine).isDisjoint(with: looks.others),
          "\(mine.count) new monster sprites, all distinct")
}

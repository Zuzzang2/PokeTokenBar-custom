import Foundation
@testable import PokeTokenBar

/// The four early regions (해안 5-22, 정글 10-30, 버섯 15-36, 고대 20-42) on top of `regionChecks()`: doors joined on every map,
/// gates along the chain, monster levels inside their map's band, the spawn mix, boss scale and stats next to the shipped monsters of
/// nearby levels, signature gear below the next shipped item of its kind, and sprites that are 16x16 and unlike every other monster.
func earlyRegionChecks() {
    let order = ["coast", "jungle", "mushroom", "ancient"]
    let regions = order.compactMap { id in RpgRegions.all.first { $0.id == id } }
    check(regions.count == 4 && zip(regions, regions.dropFirst()).allSatisfy { $0.minLevel < $1.minLevel }, "early regions open in order (\(regions.map(\.minLevel)))")
    func band(_ text: String) -> ClosedRange<Int> {
        let n = text.split { !$0.isNumber }.compactMap { Int($0) }
        return n[0]...(n.last ?? n[0])
    }
    let regionMonsters = Set(RpgRegions.all.flatMap(\.monsters).map(\.id)), regionItems = Set(RpgRegions.all.flatMap(\.items).map(\.id))
    let shipped = RpgMonsters.all.filter { !regionMonsters.contains($0.id) && $0.behavior != .boss && $0.behavior != .coward }
    let ownSpecs = MainActor.assumeIsolated { [RpgArt.specsCoast, RpgArt.specsJungle, RpgArt.specsMushroom, RpgArt.specsAncient] }

    for (r, specs) in zip(regions, ownSpecs) {
        let hunting = r.maps.filter { $0.kind != .boss }, rooms = r.maps.filter { $0.kind == .boss }
        var bad: [String] = []
        // Every door (and the 차원문 arrival tile on the entry) can be walked to from the first door.
        for def in r.maps {
            let map = RpgMap(def)
            var seen: Set<RpgTile> = [def.portals[0].at], queue = [def.portals[0].at]
            while let t = queue.popLast() {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let n = RpgTile(x: t.x + dx, y: t.y + dy)
                    if n.x >= 0, n.y >= 0, n.x < def.width, n.y < def.height, !map.at(n.x, n.y).blocks, seen.insert(n).inserted { queue.append(n) }
                }
            }
            if !def.portals.allSatisfy({ seen.contains($0.at) }) || (def.id == r.entry && !seen.contains(r.entryTile)) { bad.append(def.id.rawValue) }
        }
        check(bad.isEmpty, "\(r.id): every door of every map can be walked to \(bad)")
        // The chain: forward doors open at the next map's first level, doors back carry the gate of the map they lead to.
        let gatesOK = zip(hunting.indices, hunting.indices.dropFirst()).allSatisfy { i, j in
            let fwd = hunting[i].portals.first { $0.to == hunting[j].id }, back = hunting[j].portals.first { $0.to == hunting[i].id }
            return fwd?.minLevel == band(hunting[j].levelText).lowerBound && back?.minLevel == (i == 0 ? r.minLevel : band(hunting[i].levelText).lowerBound)
        }
        check(hunting.count == 7 && gatesOK, "\(r.id): 7 hunting grounds linked both ways, gates rising (\(hunting.map(\.levelText)))")
        check(hunting.enumerated().allSatisfy { $1.waypoint == ($0 % 2 == 0) } && rooms.allSatisfy { !$0.waypoint }, "\(r.id): the entry and every 2nd map are 차원문 waypoints")
        // Spawns: 3-4 kinds in 3+ behaviours, every monster inside the map's band (±1).
        bad = hunting.filter { def in
            let b = band(def.levelText), defs = def.monsters.map { RpgMonsters.def($0.monster) }
            return !(3...4).contains(defs.count) || Set(defs.map { "\($0.behavior)" }).count < 3 || !defs.allSatisfy { (b.lowerBound - 1...b.upperBound + 1).contains($0.level) }
        }.map(\.name)
        check(bad.isEmpty, "\(r.id): hunting grounds hold 3-4 kinds in 3+ behaviours inside their level band \(bad)")
        // Boss rooms: one boss at the room's level behind a lower gate, 20-50x the HP and 1.2-1.8x the attack of shipped melee monsters ±3 levels.
        for room in rooms {
            let boss = RpgMonsters.def(room.monsters[0].monster), gate = r.maps.flatMap(\.portals).first { $0.to == room.id }?.minLevel ?? 99
            let melee = shipped.filter { $0.behavior == .aggressive && abs($0.level - boss.level) <= 3 }
            let hp = Double(boss.hp) / (Double(melee.map(\.hp).reduce(0, +)) / Double(max(1, melee.count)))
            let atk = Double(boss.attack) / (Double(melee.map(\.attack).reduce(0, +)) / Double(max(1, melee.count)))
            check(room.monsters.count == 1 && boss.behavior == .boss && band(room.levelText).lowerBound == boss.level && gate < boss.level && !melee.isEmpty
                  && (20...50).contains(hp) && (1.2...1.8).contains(atk) && RpgMonsters.def(boss.minion).behavior != .boss,
                  "\(r.id): \(boss.name) Lv\(boss.level) has \(Int(hp))x HP and \(String(format: "%.2f", atk))x attack of shipped melee monsters near its level")
        }
        // Normal monsters stay between half the weakest and 1.5x the strongest shipped monster within 4 levels, and pay 12-45 kills a level
        // (swarms 20-90, they come in packs and pay half).
        bad = r.monsters.filter { $0.behavior != .boss && $0.behavior != .coward }.compactMap { m in
            let near = shipped.filter { abs($0.level - m.level) <= 4 }
            func inside(_ f: (RpgMonsterDef) -> Int) -> Bool { Double(f(m)) >= 0.5 * Double(near.map(f).min() ?? 0) && Double(f(m)) <= 1.5 * Double(near.map(f).max() ?? 0) }
            let kills = Double(RpgMaps.xpNeeded(m.level)) / Double(m.xp)
            return !near.isEmpty && inside(\.hp) && inside(\.attack) && inside(\.xp) && (m.behavior == .swarm ? 20...90 : 12...45).contains(kills) ? nil : m.name
        }
        check(bad.isEmpty, "\(r.id): normal monsters sit on the shipped stat curve and pay sane XP \(bad)")
        // Items: no trailing digits (the gear tier parser), and no signature gear beats the next shipped item of its kind on every stat.
        check(r.items.allSatisfy { $0.tier == 0 }, "\(r.id): item ids carry no tier digits")
        bad = r.items.filter(\.isEquipment).compactMap { item in
            func stats(_ i: RpgItem) -> [Double] { [Double(i.attack), Double(i.defense), Double(i.bonusHP), Double(i.bonusMP), i.bonusCrit, i.bonusAttack, i.bonusSpeed] }
            guard let next = RpgItems.all.filter({ $0.kind == item.kind && !regionItems.contains($0.id) && $0.price > item.price }).min(by: { $0.price < $1.price })
            else { return item.name }
            let pairs = zip(stats(item), stats(next))
            return pairs.allSatisfy { $0 >= $1 } && pairs.contains { $0 > $1 } ? "\(item.name) > \(next.name)" : nil
        }
        check(bad.isEmpty, "\(r.id): signature gear is never better on every stat than the next shipped item \(bad)")
        check(specs.count == r.monsters.count && specs.values.allSatisfy { $0.grid.count == 16 && $0.grid.allSatisfy { $0.count == 16 } }, "\(r.id): one 16x16 sprite per monster")
    }
    // No two monsters in the game look the same, and the early regions' item icons all differ.
    let mine = Set(regions.flatMap(\.monsters).map(\.id))
    let looks = MainActor.assumeIsolated { RpgMonsters.all.map { RpgArt.sprite($0.sprite)?.dataProvider?.data as Data? } }
    check(RpgMonsters.all.indices.filter { mine.contains(RpgMonsters.all[$0].id) }.allSatisfy { i in looks[i] != nil && looks.indices.allSatisfy { $0 == i || looks[$0] != looks[i] } },
          "early-region monsters (\(mine.count)) each have a look of their own")
    let icons = MainActor.assumeIsolated { regions.flatMap(\.items).compactMap { RpgArt.icon($0)?.dataProvider?.data as Data? } }
    check(icons.count == regions.flatMap(\.items).count && Set(icons).count == icons.count, "early-region item icons (\(icons.count)) are all different")
    // Smoke: a player of the boss's level stands in each boss room with its boss for a few seconds.
    for room in regions.flatMap(\.maps) where room.kind == .boss {
        let boss = RpgMonsters.def(room.monsters[0].monster)
        var p = RpgSaveStore.newPlayer(name: "raid", cls: .cleric, id: 2)
        p.level = boss.level
        p.map = room.id
        p.pos = RpgMap.center(RpgTile(x: 14, y: 17))
        let w = world(level: boss.level)
        w.addPlayer(p)
        for _ in 0..<120 { w.step(1.0 / 30, inputs: [:]) }
        check(w.mobs[room.id]?.filter { $0.def.behavior == .boss }.count == 1 && w.player(2) != nil, "\(room.name): \(boss.name) holds its room")
    }
}

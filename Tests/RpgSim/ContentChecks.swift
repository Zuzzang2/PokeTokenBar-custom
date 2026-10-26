import Foundation
@testable import PokeTokenBar

/// Checks for the Lv60-100 content: level cap and XP curve, gear tiers, materials and recipes, the twelve late-game maps
/// (reachability, gates, spawn tables), their monsters and bosses, and a smoke test of a Lv90 player on one of them.
func contentChecks() {
    let lateMaps: [RpgMapID] = [.sky, .abyss, .temple, .demongate, .dragon, .icepalace, .firetemple, .canyon, .darkforest, .library, .stargarden, .dimension]
    let lateBossRooms: [RpgMapID] = [.abyssBoss, .dragonBoss, .icepalaceBoss, .canyonBoss, .libraryBoss, .dimensionBoss]

    // MARK: level cap and XP curve
    check(RpgMaps.maxLevel == 100, "max level is \(RpgMaps.maxLevel)")
    /// The curve as it was before the Lv100 work.
    func oldXP(_ l: Int) -> Int {
        (15 * l + 5 * l * l) * 5 / 2 + (l > 15 ? 22 * (l - 15) * (l - 15) : 0) + (l > 35 ? 40 * (l - 35) * (l - 35) * (l - 35) / 10 : 0)
    }
    check((1...60).allSatisfy { RpgMaps.xpNeeded($0) == oldXP($0) }, "levels 1-60 keep the original XP curve")
    check(RpgMaps.xpNeeded(1) == 50 && RpgMaps.xpNeeded(15) == 3375 && abs(RpgMaps.xpNeeded(30) - 17_325) < 50, "early XP values are unchanged (50 / 3375 / ~17.3k)")
    check((1..<100).allSatisfy { RpgMaps.xpNeeded($0 + 1) > RpgMaps.xpNeeded($0) }, "the XP curve is strictly increasing up to Lv100")
    check((36..<100).allSatisfy { Double(RpgMaps.xpNeeded($0 + 1)) / Double(RpgMaps.xpNeeded($0)) < 1.2 }, "the XP curve grows smoothly (no jumps over 20%)")
    let top = RpgMaps.xpNeeded(99)
    check(top > 1_500_000 && top < 3_000_000, "Lv99 -> 100 needs \(top) XP (1.5M-3M)")

    // MARK: gear tiers
    check(RpgItems.item("sword10")?.tier == 10 && RpgItems.item("armor11")?.tier == 11 && RpgItems.item("sword9")?.tier == 9 && RpgItems.item("hp5")?.tier == 5,
          "two-digit gear tiers parse from the id")
    check(RpgItems.item("mat_sky")?.tier == 0 && RpgItems.item("scroll_protect")?.tier == 0, "ids without trailing digits are tier 0")
    for cls in RpgClass.allCases {
        let ws = (0...12).map { RpgItems.item("\(cls.weaponPrefix)\($0)") }
        check(ws.allSatisfy { $0?.kind == .weapon(cls) }, "\(cls.name): weapons tier 0-12 exist")
        let atk = ws.compactMap { $0?.attack }
        check(atk.count == 13 && zip(atk[8...], atk[9...]).allSatisfy { $0 < $1 } && atk[9] >= 170 && atk[12] >= 380,
              "\(cls.name): top weapon tiers climb (\(atk.suffix(5).map(String.init).joined(separator: ", ")))")
        check(ws.compactMap { $0 }.suffix(3).allSatisfy { $0.rarity == 4 && !$0.inShop }, "\(cls.name): tiers 10-12 are mythic drops")
    }
    check((0...11).allSatisfy { RpgItems.item("armor\($0)")?.kind == .armor }, "armor tiers 0-11 exist")
    let armorDef = (7...11).compactMap { RpgItems.item("armor\($0)")?.defense }
    check(armorDef.count == 5 && zip(armorDef, armorDef.dropFirst()).allSatisfy { $0 < $1 }, "armor defense climbs through tier 11 (\(armorDef))")
    for (prefix, kind) in [("ring", RpgItemKind.ring), ("amulet", .amulet), ("helmet", .helmet), ("boots", .boots)] {
        let items = (0...11).compactMap { RpgItems.item("\(prefix)\($0)") }
        check(items.count == 12 && items.allSatisfy { $0.kind == kind }, "\(prefix) tiers 0-11 exist")
        check(zip(items, items.dropFirst()).allSatisfy { $0.price < $1.price }, "\(prefix) prices climb with the tier")
    }
    let rings = (6...11).compactMap { RpgItems.item("ring\($0)") }
    check(rings.count == 6 && zip(rings, rings.dropFirst()).allSatisfy { $0.bonusHP < $1.bonusHP && $0.bonusAttack < $1.bonusAttack && $0.bonusCrit < $1.bonusCrit },
          "ring bonuses climb through tier 11")
    check(RpgItems.item("hp5")?.inShop == true && RpgItems.item("mp3")?.inShop == true
          && (RpgItems.item("hp5")?.heal ?? 0) > (RpgItems.item("hp4")?.heal ?? 0) && (RpgItems.item("mp3")?.heal ?? 0) > (RpgItems.item("mp2")?.heal ?? 0),
          "bigger potions hp5 / mp3 are sold")
    check(RpgShop.potion.stock.contains { $0.id == "hp5" } && !RpgShop.weapon.stock.contains { $0.tier >= 9 }, "shop stock: new potions yes, late-game weapons no")
    let iconsOK = MainActor.assumeIsolated { RpgItems.all.allSatisfy { RpgArt.icon($0) != nil } }
    check(iconsOK, "every item has an icon")
    let distinctIcons = MainActor.assumeIsolated { () -> Bool in
        let tiers = (8...12).compactMap { RpgArt.icon(RpgItems.item("sword\($0)")!)?.dataProvider?.data as Data? }
        return Set(tiers).count == 5
    }
    check(distinctIcons, "sword tiers 8-12 have distinct icons")

    // MARK: materials and recipes
    check((1...100).allSatisfy { RpgMaterials.pick(level: $0, roll: 0) != nil }, "material bands cover levels 1-100")
    check(RpgMaterials.bands.allSatisfy { RpgItems.item($0.item)?.kind == .material }, "every banded material is an item")
    let recipeIDs = Set(RpgRecipes.all.map(\.id))
    check(recipeIDs.count == RpgRecipes.all.count, "recipe ids are unique")
    for prefix in ["ring", "amulet", "helmet", "boots"] {
        check((0...11).allSatisfy { recipeIDs.contains("\(prefix)\($0)") }, "recipes exist for \(prefix) tiers 0-11")
    }
    check(RpgRecipes.all.allSatisfy { r in RpgItems.item(r.output) != nil && r.materials.keys.allSatisfy { RpgItems.item($0) != nil } && r.gold > 0 },
          "every recipe output and ingredient is a real item")
    let banded = Set(RpgMaterials.bands.map(\.item))
    let droppedAnywhere = Set(RpgMonsters.all.flatMap { $0.drops.map(\.item) })
    check(RpgRecipes.all.allSatisfy { r in r.materials.keys.allSatisfy { $0 == "stone" || banded.contains($0) || droppedAnywhere.contains($0) } }, "every recipe material drops somewhere")
    let ring11 = RpgRecipes.def("ring11")
    check(ring11?.materials["mat_void"] != nil && (ring11?.materials["stone"] ?? 0) > 0, "the top ring needs the newest material and stones")

    // MARK: maps: graph, gates, tiles
    func band(_ text: String) -> ClosedRange<Int>? {
        let nums = text.split { !$0.isNumber }.compactMap { Int($0) }
        guard text.contains("Lv"), let lo = nums.first else { return nil }
        return lo...(nums.last ?? lo)
    }
    check(lateMaps.allSatisfy { RpgMapID.allCases.contains($0) } && RpgMapID.allCases.count >= 19 + 18, "the 12 hunting maps and 6 boss rooms exist (\(RpgMapID.allCases.count) maps)")
    var dests: [RpgMapID: [RpgPortal]] = [:]
    for def in RpgMaps.all { dests[def.id] = def.portals.filter { !$0.waypoint } }
    check(Set(RpgMaps.all.map(\.id)) == Set(RpgMapID.allCases) && RpgMaps.all.count == RpgMapID.allCases.count, "every map id has exactly one definition")
    let seeds = RpgMaps.all.map(\.seed)
    check(Set(seeds).count == seeds.count, "map seeds are unique")
    // Lowest level at which each map can be entered from the town (best path, gates taken as the max along it).
    var entry: [RpgMapID: Int] = [.town: 1]
    for region in RpgRegions.all { entry[region.entry] = region.minLevel }   // the 차원문 opens each region at its level
    var changed = true
    while changed {
        changed = false
        for def in RpgMaps.all {
            guard let here = entry[def.id] else { continue }
            for p in dests[def.id] ?? [] {
                let need = max(here, p.minLevel)
                if need < (entry[p.to] ?? Int.max) { entry[p.to] = need; changed = true }
            }
        }
    }
    check(RpgMapID.allCases.allSatisfy { entry[$0] != nil }, "every map is reachable from the town through portals")
    check(entry.values.max() ?? 999 <= 100, "the deepest gate is Lv\(entry.values.max() ?? 0), passable by a level-100 player")
    check(lateMaps.allSatisfy { entry[$0] != nil && entry[$0]! <= band(RpgMaps.def($0).levelText)!.lowerBound }, "late hunting grounds open no later than their first level")
    let lateEntry = lateMaps.compactMap { entry[$0] }
    check(lateEntry.count == 12 && zip(lateEntry, lateEntry.dropFirst()).allSatisfy { $0 <= $1 }, "late gates rise along the chain (\(lateEntry))")
    // No dead ends: from every map a way leads back to the town, and each map has an exit its entry level can use.
    var home: Set<RpgMapID> = [.town]
    changed = true
    while changed {
        changed = false
        for def in RpgMaps.all where !home.contains(def.id) && (dests[def.id] ?? []).contains(where: { home.contains($0.to) }) { home.insert(def.id); changed = true }
    }
    check(home.count == RpgMapID.allCases.count, "no dead ends: every map leads back to the town")
    check(RpgMaps.all.filter { $0.id != .town }.allSatisfy { def in
        (dests[def.id] ?? []).contains { $0.minLevel <= (entry[def.id] ?? 1) && $0.to != def.id }
    }, "every map has an exit its entry level can use")
    check(RpgMaps.def(.crypt).portals.contains { $0.to == .sky && $0.minLevel == 58 }, "the crypt's east door leads to the sky island (Lv58)")
    check(zip(lateMaps, lateMaps.dropFirst()).allSatisfy { a, b in
        dests[a]!.contains { $0.to == b } && dests[b]!.contains { $0.to == a }
    }, "late hunting grounds are linked both ways in a chain")
    check(lateBossRooms.allSatisfy { room in
        let from = RpgMaps.all.filter { $0.portals.contains { $0.to == room } }
        return from.count == 1 && lateMaps.contains(from[0].id) && dests[room]!.count == 1 && dests[room]![0].to == from[0].id
    }, "each boss room has one door in and the same door back out")
    check(Set(RpgMaps.waypoints).isSuperset(of: lateMaps) && Set(RpgMaps.waypoints).isDisjoint(with: lateBossRooms), "the 차원문 lists the 12 late hunting grounds, not the boss rooms")
    // Tiles: doors inside the map, arrival points standable, and one connected walkable area joins all doors of each new map.
    var tilesOK = true, connected = true, spawnsOK = true
    for id in lateMaps + lateBossRooms {
        let def = RpgMaps.def(id)
        let map = RpgMap(def)
        for p in def.portals where p.at.x < 0 || p.at.y < 0 || p.at.x >= def.width || p.at.y >= def.height { tilesOK = false }
        for other in RpgMaps.all { for p in other.portals where p.to == id && !p.waypoint && !map.canStand(RpgMap.center(p.arrive)) { tilesOK = false; print("  blocked arrival in \(id.rawValue)") } }
        var seen: Set<RpgTile> = [def.portals[0].at], queue = [def.portals[0].at]
        while let t = queue.popLast() {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let n = RpgTile(x: t.x + dx, y: t.y + dy)
                if !seen.contains(n), n.x >= 0, n.y >= 0, n.x < def.width, n.y < def.height, !map.at(n.x, n.y).blocks { seen.insert(n); queue.append(n) }
            }
        }
        if !def.portals.allSatisfy({ seen.contains($0.at) }) { connected = false; print("  disconnected doors in \(id.rawValue)") }
        if !def.monsters.isEmpty, map.spawnTiles.count < 60 { spawnsOK = false; print("  few spawn tiles in \(id.rawValue)") }
    }
    check(tilesOK, "new maps: doors inside the map and arrival spots are walkable")
    check(connected, "new maps: every door can be reached from every other door")
    check(spawnsOK, "new hunting grounds have room for their monsters")

    // MARK: level bands
    let bands = RpgMaps.all.compactMap { band($0.levelText) }
    check((60...100).allSatisfy { lv in bands.contains { $0.contains(lv) } }, "map level bands cover every level from 60 to 100")
    let sorted = bands.sorted { $0.lowerBound < $1.lowerBound }
    var reach = sorted[0].upperBound, worstGap = 0
    for b in sorted { worstGap = max(worstGap, b.lowerBound - reach - 1); reach = max(reach, b.upperBound) }
    check(worstGap <= 6 && reach >= 100, "no gap between map bands over 6 levels (worst \(worstGap)), top band reaches Lv\(reach)")
    check(lateMaps.allSatisfy { band(RpgMaps.def($0).levelText) != nil } && band(RpgMaps.def(.sky).levelText)!.lowerBound <= 60 && band(RpgMaps.def(.dimension).levelText)!.upperBound == 100,
          "late maps run from Lv58 to Lv100")

    // MARK: monsters
    let late = RpgMonsters.all.filter { $0.level >= 58 && $0.id != "demonking" }
    let lateNormal = late.filter { $0.behavior != .boss }
    let regionMonsterIDs = Set(RpgRegions.all.flatMap(\.monsters).map(\.id))
    let lateBosses = late.filter { $0.behavior == .boss && !regionMonsterIDs.contains($0.id) }
    check(lateNormal.count >= 45, "at least 45 new normal monsters (\(lateNormal.count))")
    check(lateBosses.count == 6 && lateBosses.allSatisfy { (60...100).contains($0.level) }, "6 new bosses at Lv60-100 (\(lateBosses.map { "\($0.name) Lv\($0.level)" }))")
    let ids = RpgMonsters.all.map(\.id)
    check(Set(ids).count == ids.count, "monster ids stay unique (\(ids.count))")
    let spritesOK = MainActor.assumeIsolated { RpgMonsters.all.allSatisfy { RpgArt.sprite($0.sprite) != nil } }
    check(spritesOK && late.allSatisfy { $0.sprite == $0.id }, "every new monster has its own sprite")
    let uniqueLooks = MainActor.assumeIsolated { () -> Bool in
        let datas = late.compactMap { RpgArt.sprite($0.sprite)?.dataProvider?.data as Data? }
        return datas.count == late.count && Set(datas).count == late.count
    }
    check(uniqueLooks, "no two new monsters look the same")
    let known = Set(ids)
    var refsOK = true
    for def in RpgMaps.all { for s in def.monsters where !known.contains(s.monster) || s.count < 1 { refsOK = false; print("  unknown monster \(s.monster) in \(def.id.rawValue)") } }
    check(refsOK, "every monster a map spawns exists")
    check(lateMaps.allSatisfy { id in
        let def = RpgMaps.def(id)
        return (3...4).contains(def.monsters.count) && Set(def.monsters.map { RpgMonsters.def($0.monster).behavior }).count >= 3
    }, "each late hunting ground has 3-4 monster kinds in 3+ behaviours")
    let behaviours = Set(lateNormal.map(\.behavior))
    check([RpgBehavior.swarm, .charger, .exploder, .ranged, .flyer, .aggressive].allSatisfy { behaviours.contains($0) }, "late monsters use swarm, charger, exploder, ranged, flyer and melee behaviours")
    var levelsFit = true
    for id in lateMaps {
        let b = band(RpgMaps.def(id).levelText)!
        for s in RpgMaps.def(id).monsters where !((b.lowerBound - 1)...(b.upperBound + 1)).contains(RpgMonsters.def(s.monster).level) { levelsFit = false; print("  \(s.monster) outside \(id.rawValue)") }
    }
    check(levelsFit, "monster levels sit inside their map's level band")
    for id in lateBossRooms {
        let spawns = RpgMaps.def(id).monsters
        check(spawns.count == 1 && spawns[0].count == 1 && RpgMonsters.def(spawns[0].monster).behavior == .boss, "\(id.rawValue) holds exactly one boss")
    }
    check(lateBosses.allSatisfy { known.contains($0.minion) && RpgMonsters.def($0.minion).behavior != .boss }, "boss minions are ordinary monsters")
    let bossOrder = lateBosses.sorted { $0.level < $1.level }
    check(zip(bossOrder, bossOrder.dropFirst()).allSatisfy { $0.hp < $1.hp && $0.attack < $1.attack && $0.xp < $1.xp }, "boss HP, attack and XP climb with level")
    let demonking = RpgMonsters.def("demonking")
    check(bossOrder[0].hp > demonking.hp && bossOrder[0].hp < demonking.hp * 2 && bossOrder[0].attack > demonking.attack, "the first new boss continues from the Lv58 마왕")
    check(Set(lateBosses.map { "\($0.bossStyle)" }).count >= 4 && Set(lateBosses.map { "\($0.element)" }).count >= 3, "late bosses vary in style and element")
    // Scaling: stats and rewards of normal monsters rise from band to band; ~100 kills per level at Lv95.
    func avg(_ lo: Int, _ hi: Int, _ f: (RpgMonsterDef) -> Int) -> Double {
        let xs = lateNormal.filter { (lo...hi).contains($0.level) }.map(f)
        return xs.isEmpty ? 0 : Double(xs.reduce(0, +)) / Double(xs.count)
    }
    let steps = [(58, 67), (68, 77), (78, 87), (88, 100)]
    let stats: [(RpgMonsterDef) -> Int] = [\.hp, \.attack, \.defense, \.xp, { $0.gold.upperBound }]
    check(zip(steps, steps.dropFirst()).allSatisfy { a, b in stats.allSatisfy { avg(a.0, a.1, $0) < avg(b.0, b.1, $0) } }, "normal monster stats and rewards grow with level")
    let lv95 = lateNormal.filter { (93...97).contains($0.level) && $0.behavior != .swarm }
    check(!lv95.isEmpty && lv95.allSatisfy { (15_000...30_000).contains($0.xp) }, "Lv93-97 monsters pay 15k-30k XP (\(lv95.map(\.xp)))")
    let kills = Double(RpgMaps.xpNeeded(95)) / (Double(lv95.map(\.xp).reduce(0, +)) / Double(max(1, lv95.count)))
    check(kills > 70 && kills < 140, "about 100 kills per level at Lv95 (\(Int(kills)))")
    let kills60 = Double(RpgMaps.xpNeeded(60)) / Double(RpgMonsters.def("skyhawk").xp)
    check(kills60 > 20 && kills60 < 60, "about \(Int(kills60)) kills per level at Lv60")
    var dropsOK = true
    for def in RpgMonsters.all { for d in def.drops where RpgItems.item(d.item) == nil || d.chance <= 0 || d.chance > 1 { dropsOK = false; print("  bad drop \(d.item) on \(def.id)") } }
    check(dropsOK, "every drop is a real item with a sane chance")
    let dropped = Set(lateNormal.flatMap { $0.drops.map(\.item) } + lateBosses.flatMap { $0.drops.map(\.item) })
    check(RpgClass.allCases.allSatisfy { cls in (9...12).allSatisfy { dropped.contains("\(cls.weaponPrefix)\($0)") } }, "every class's tier 9-12 weapon drops from some late monster")
    check((8...11).allSatisfy { t in ["armor", "ring", "amulet", "helmet", "boots"].allSatisfy { dropped.contains("\($0)\(t)") } }, "armor and accessories of tiers 8-11 drop from late monsters")

    // MARK: smoke: players on the new maps
    func spawnIn(_ map: RpgMapID, level: Int, cls: RpgClass = .warrior) -> RpgWorld {
        let w = world(level: level, cls: cls)
        var p = RpgSaveStore.newPlayer(name: "late", cls: cls, id: 2)
        p.level = level
        p.map = map
        p.pos = RpgMap.center(RpgMaps.all.lazy.flatMap(\.portals).first { $0.to == map && !$0.waypoint }!.arrive)
        w.addPlayer(p)
        return w
    }
    for id in lateMaps {
        let def = RpgMaps.def(id)
        let want = def.monsters.reduce(0) { $0 + Int((Double($1.count) * RpgWorld.monsterDensity).rounded(.up)) }
        let w = spawnIn(id, level: 90)
        check(w.mobs[id]?.count == want && want > 10, "\(def.name): \(want) monsters spawn")
    }
    do {
        let w = spawnIn(.library, level: 90)
        for _ in 0..<400 { w.step(1.0 / 30, inputs: [:]) }
        check(w.player(2) != nil && (w.mobs[.library] ?? []).count > 10, "a Lv90 warrior idles 400 frames in the library without trouble")
        hunt(w, id: 2, seconds: 20)
        check(w.player(2) != nil, "a Lv90 warrior can hunt in the library (and survive the sim loop)")
    }
    do {
        var p = RpgSaveStore.newPlayer(name: "gear", cls: .archer, id: 3)
        p.level = 100
        p.weapon = "bow8"
        let before = p.attack(at: 0)
        p.weapon = "bow12"
        check(p.attack(at: 0) > before * 1.3, "a tier-12 bow beats the tier-8 bow by more than 30%")
        p.ring = "ring11"; p.amulet = "amulet11"; p.helmet = "helmet11"; p.boots = "boots11"
        check(p.maxHP > 4000 && p.defense > 300, "tier-11 accessories add up (HP \(Int(p.maxHP)), defense \(Int(p.defense)))")
    }
    do {
        let w = spawnIn(.dimensionBoss, level: 100)
        for _ in 0..<300 { w.step(1.0 / 30, inputs: [:]) }
        check(w.mobs[.dimensionBoss]?.count == 1 && w.player(2) != nil, "the final boss room holds its boss while a Lv100 player stands there")
    }
}

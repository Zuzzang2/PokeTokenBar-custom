import Foundation
@testable import PokeTokenBar

// Saves go to a throw-away folder, never to the real app state.
let simStateDir = NSTemporaryDirectory() + "rpgsim-\(UUID().uuidString)"
setenv("PTB_STATE_DIR", simStateDir, 1)

// Plain assertions: any failure prints and exits non-zero.
var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   " : "FAIL ", what)
    if !ok { failures += 1 }
}

func world(level: Int = 1, cls: RpgClass = .warrior) -> RpgWorld {
    var p = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
    p.level = level
    return RpgWorld(player: p)
}


// MARK: hunting helpers
/// A world with the player standing at the field's entrance (player 2 joins so the field's monsters spawn).
func fieldWorld(level: Int, cls: RpgClass = .warrior) -> (RpgWorld, Int) {
    let w = world(level: level, cls: cls)
    var p = RpgSaveStore.newPlayer(name: "hunter", cls: cls, id: 2)
    p.level = level
    p.map = .field
    p.pos = RpgMap.center(RpgMaps.def(.field).portals.first!.arrive)
    w.addPlayer(p)
    return (w, 2)
}

/// Walks toward the nearest living monster and attacks for `seconds` (hopping sideways when scenery blocks the way);
/// returns the highest combo seen.
@discardableResult
func hunt(_ w: RpgWorld, id: Int, seconds: Double) -> Int {
    var t = 0.0, best = 0, lastPos = CGPoint.zero, stuck = 0
    while t < seconds {
        guard let me = w.player(id) else { break }
        let target = (w.mobs[me.map] ?? []).filter { !$0.dead }
            .min { hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < hypot($1.pos.x - me.pos.x, $1.pos.y - me.pos.y) }
        var input = RpgInput()
        stuck = hypot(me.pos.x - lastPos.x, me.pos.y - lastPos.y) < 0.5 ? stuck + 1 : 0
        lastPos = me.pos
        if let target {
            let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
            // Report positions like a remote player so the walk cannot snag on scenery: hop up to 80px per step.
            var ux = dx / d, uy = dy / d
            var go: CGFloat = d > 80 ? 80 : max(0, d - 10)
            if stuck >= 3 {
                let a = Double.random(in: 0..<(2 * .pi))
                ux = CGFloat(cos(a)); uy = CGFloat(sin(a)); go = 40
            }
            input.pos = CGPoint(x: me.pos.x + ux * go, y: me.pos.y + uy * go)
            input.facing = CGVector(dx: dx / d, dy: dy / d)
            input.attack = true
        }
        w.step(1.0 / 30, inputs: [id: input])
        best = max(best, w.player(id)?.combo ?? 0)
        t += 1.0 / 30
    }
    return best
}

/// Attacks one specific monster until it dies (or `seconds` pass). When the walk is blocked by scenery it hops sideways.
func kill(_ w: RpgWorld, id: Int, mob mobID: Int, seconds: Double = 25) {
    var t = 0.0, lastPos = CGPoint.zero, stuck = 0
    while t < seconds {
        guard let me = w.player(id), let target = (w.mobs[me.map] ?? []).first(where: { $0.id == mobID }), !target.dead else { return }
        stuck = hypot(me.pos.x - lastPos.x, me.pos.y - lastPos.y) < 0.5 ? stuck + 1 : 0
        lastPos = me.pos
        let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
        var input = RpgInput()
        var go = d > 80 ? min(d, 80) : max(0, d - 10)
        var ux = dx / d, uy = dy / d
        if stuck >= 3 {
            // Blocked: try a random direction for a few steps.
            let a = Double.random(in: 0..<(2 * .pi))
            ux = CGFloat(cos(a)); uy = CGFloat(sin(a)); go = 40
        }
        input.pos = CGPoint(x: me.pos.x + ux * go, y: me.pos.y + uy * go)
        input.facing = CGVector(dx: dx / d, dy: dy / d)
        input.attack = true
        w.step(1.0 / 30, inputs: [id: input])
        t += 1.0 / 30
    }
}

func idle(_ w: RpgWorld, seconds: Double) {
    var t = 0.0
    while t < seconds { w.step(1.0 / 30, inputs: [:]); t += 1.0 / 30 }
}

// MARK: basics
let basic = world()
basic.step(0.05, inputs: [:])
check(basic.player(1)?.level == 1, "world steps")

let advanced = world(level: 20)
advanced.perform(.advance(1), for: 1)
check(advanced.player(1)?.job == 1 && advanced.player(1)?.skills["j_bash"] != nil, "advance at Lv20 teaches the first job skill")
advanced.perform(.advance(2), for: 1)
check(advanced.player(1)?.job == 1, "a job cannot be changed")
let early = world(level: 19)
early.perform(.advance(1), for: 1)
check(early.player(1)?.job == 0, "no advancement below Lv20")


// MARK: combo
do {
    let (w, id) = fieldWorld(level: 30)
    let best = hunt(w, id: id, seconds: 40)
    check(best >= 3, "combo builds while killing (best \(best))")
    idle(w, seconds: RpgWorld.comboWindow + 1)
    check(w.player(id)?.combo == 0, "combo resets after the window")
    check(RpgWorld.comboBonus(9) == 0 && RpgWorld.comboBonus(10) == 0.05 && RpgWorld.comboBonus(500) == 0.5, "combo bonus steps by 5% per 10 and caps at 50%")
}

// MARK: elite
do {
    // 3% per monster: build fields until one has a golden elite.
    var found: (RpgWorld, Int, RpgMob)?
    for _ in 0..<60 {
        let (w, id) = fieldWorld(level: 40)
        // Bombs may blow themselves up before they can be killed for XP, so test an ordinary elite.
        if let e = (w.mobs[.field] ?? []).first(where: { $0.elite && $0.def.behavior != .exploder }) { found = (w, id, e); break }
    }
    check(found != nil, "elite monsters spawn")
    if let (w, id, e) = found {
        check(e.hp == Double(e.def.hp) * RpgWorld.eliteHP && e.hpScale == RpgWorld.eliteHP, "elite has 3x HP")
        let before = w.player(id)!.xp
        kill(w, id: id, mob: e.id)
        let after = w.player(id)!
        let dead = w.mobs[.field]?.first { $0.id == e.id }?.dead ?? false
        check(dead, "elite can be killed")
        // Level 40 vs a Lv1-3 monster: the over-level penalty divides XP by 5; elite pays 4x.
        check(after.xp - before >= max(1, e.def.xp * 4 / 5) || after.level > 40, "elite pays 4x XP (\(after.xp - before) vs \(e.def.xp * 4 / 5))")
        check(w.drops.contains { $0.item == "stone" }, "elite drops a guaranteed enhancement stone")
    }
}

// MARK: pet special attack
do {
    let (w, id) = fieldWorld(level: 30)
    let info = RpgPetInfo(speciesID: 25, shiny: false, name: "피카", power: 120, element: .thunder,
                          moveName: "Test Move", moveType: "electric", movePower: 90)
    w.perform(.pet(info), for: id)
    check(w.player(id)?.petInfo?.moveName == "Test Move", "pet info arrives with its move")
    var sawMove = false
    for _ in 0..<300 {
        hunt(w, id: id, seconds: 0.2)
        if w.floaters.contains(where: { $0.text == "Test Move" }) { sawMove = true; break }
    }
    check(sawMove, "pet uses its special move (name floats up)")
    check(w.pets[id] != nil, "pet exists in the world")
    // Keep hunting: kills drop gold and the bag fills up (the pet fetches drops too).
    hunt(w, id: id, seconds: 25)
    check((w.player(id)?.gold ?? 0) > 150, "gold collected while hunting with a pet")
}

// MARK: achievements and codex
do {
    let w = world(level: 20)
    let goldBefore = w.player(1)!.gold, stonesBefore = w.player(1)!.inventory["stone"] ?? 0
    w.perform(.advance(1), for: 1)
    let p = w.player(1)!
    check(p.achievements.contains("job") && p.achievements.contains("lv20"), "advancing unlocks the job and Lv20 achievements")
    check(p.gold == goldBefore + 1500 && (p.inventory["stone"] ?? 0) == stonesBefore + 8, "achievement rewards are paid once")

    var hunter = RpgSaveStore.newPlayer(name: "t", cls: .archer, id: 1)
    hunter.kills = ["slime": 42]
    hunter.eliteKills = 3
    hunter.bestCombo = 31
    hunter.achievements = ["kill100"]
    let back = RpgSaveStore.player(from: RpgSaveStore.snapshot(hunter), id: 1)
    check(back.kills["slime"] == 42 && back.eliteKills == 3 && back.bestCombo == 31 && back.achievements == ["kill100"], "counters and achievements survive a save round trip")

    let cleaned = RpgAchievements.cleanKills(["slime": 99_999_999_999, "not-a-monster": 5, "bat": -4])
    check(cleaned["slime"] == 10_000_000 && cleaned["not-a-monster"] == nil && cleaned["bat"] == 0, "save counters are clamped and unknown monsters dropped")

    let (fw, fid) = fieldWorld(level: 30)
    hunt(fw, id: fid, seconds: 20)
    let after = fw.player(fid)!
    check(after.kills.values.reduce(0, +) > 0 && after.bestCombo > 0, "hunting records kills and best combo (\(after.kills.values.reduce(0, +)) kills)")
}

// MARK: tower
do {
    let w10 = RpgWorld.towerWave(floor: 10), w5 = RpgWorld.towerWave(floor: 5), w1 = RpgWorld.towerWave(floor: 1)
    check(w10.boss && w10.defs.first?.behavior == .boss, "floor 10 is a boss floor")
    check(w5.elite && !w5.boss, "floor 5 is an elite wave")
    check(!w1.elite && !w1.boss && w1.defs.count >= 5 && w1.defs.allSatisfy { $0.behavior != .boss }, "floor 1 is a plain wave")
    check((1...80).allSatisfy { !RpgWorld.towerWave(floor: $0).defs.isEmpty }, "every floor up to 80 has monsters")

    var p = RpgSaveStore.newPlayer(name: "climber", cls: .warrior, id: 1)
    p.level = 60
    p.visited.insert(.tower)
    let w = RpgWorld(player: p)
    w.perform(.warp(.tower), for: 1)
    w.step(1.0 / 30, inputs: [:])
    check(w.player(1)?.map == .tower && w.towerFloor == 1, "entering the tower starts floor 1")
    check((w.mobs[.tower] ?? []).count == w1.defs.count, "floor 1 spawned its wave (\(w.mobs[.tower]?.count ?? 0) monsters)")
    hunt(w, id: 1, seconds: 25)
    check(w.towerFloor >= 2, "clearing a floor opens the next (now floor \(w.towerFloor))")
    check((w.player(1)?.bestFloor ?? 0) >= 1, "best floor is recorded")
    let back = RpgSaveStore.player(from: RpgSaveStore.snapshot(w.player(1)!), id: 1)
    check(back.bestFloor == w.player(1)?.bestFloor && back.map == .town, "best floor saves and a tower save resumes in town")

    // Leaving the tower resets it.
    w.perform(.interact, for: 1)
    w.perform(.warp(.town), for: 1)
    w.step(1.0 / 30, inputs: [:])
    check(w.player(1)?.map == .town && w.towerFloor == 0, "leaving empties the tower")
}

// MARK: trade
func tradeWorld() -> RpgWorld {
    let w = world(level: 10)
    var p2 = RpgSaveStore.newPlayer(name: "friend", cls: .mage, id: 2)
    p2.level = 10
    w.addPlayer(p2)
    return w
}
do {
    let w = tradeWorld()
    w.perform(.tradeRequest(2), for: 1)
    check(w.tradeView(for: 1) == nil, "a request alone does not start a trade")
    w.perform(.tradeAccept, for: 2)
    check(w.tradeView(for: 1)?.partnerID == 2 && w.tradeView(for: 2)?.partnerID == 1, "accepting starts the trade for both")

    w.perform(.tradeOffer(item: "hp0", count: 3), for: 1)
    w.perform(.tradeGold(100), for: 1)
    w.perform(.tradeOffer(item: "mp0", count: 2), for: 2)
    check(w.tradeView(for: 2)?.theirs.items["hp0"] == 3 && w.tradeView(for: 2)?.theirs.gold == 100, "each side sees the other's offer")
    w.perform(.tradeConfirm(true), for: 1)
    check(w.player(1)?.inventory["hp0"] == 6, "one confirmation does not swap")
    w.perform(.tradeOffer(item: "mp0", count: 1), for: 2)
    check(w.tradeView(for: 1)?.mine.ok == false, "changing an offer clears confirmations")
    w.perform(.tradeConfirm(true), for: 1)
    w.perform(.tradeConfirm(true), for: 2)
    let a = w.player(1)!, b = w.player(2)!
    check(a.inventory["hp0"] == 3 && b.inventory["hp0"] == 9 && a.inventory["mp0"] == 5 && b.inventory["mp0"] == 3, "both confirmed: items swap")
    check(a.gold == 50 && b.gold == 250, "gold swaps")
    check(w.tradeView(for: 1) == nil && w.tradeView(for: 2) == nil, "the trade closes after the swap")
}
do {
    // Enhanced items cannot be offered.
    var p1 = RpgSaveStore.newPlayer(name: "smith", cls: .warrior, id: 1)
    p1.level = 10
    p1.inventory["sword1"] = 2
    p1.plus["sword1"] = 3
    let w = RpgWorld(player: p1)
    var p2 = RpgSaveStore.newPlayer(name: "friend", cls: .mage, id: 2)
    p2.level = 10
    w.addPlayer(p2)
    w.perform(.tradeRequest(2), for: 1)
    w.perform(.tradeAccept, for: 2)
    w.perform(.tradeOffer(item: "sword1", count: 1), for: 1)
    check(w.tradeView(for: 1)?.mine.items.isEmpty == true, "an enhanced item id cannot be offered")
    w.perform(.tradeOffer(item: "hp0", count: 99), for: 1)
    check(w.tradeView(for: 1)?.mine.items["hp0"] == 6, "an offer is capped at what you own")
}
do {
    // Stock that disappears after offering cancels the trade without moving anything.
    let w = tradeWorld()
    w.perform(.tradeRequest(2), for: 1)
    w.perform(.tradeAccept, for: 2)
    w.perform(.tradeOffer(item: "hp0", count: 5), for: 1)
    for _ in 0..<4 { w.perform(.sell("hp0"), for: 1) }
    w.perform(.tradeConfirm(true), for: 1)
    w.perform(.tradeConfirm(true), for: 2)
    check(w.tradeView(for: 1) == nil && w.player(2)?.inventory["hp0"] == 6, "stale offer cancels the trade and moves nothing")
}
do {
    // Walking away cancels.
    let w = tradeWorld()
    w.perform(.tradeRequest(2), for: 1)
    w.perform(.tradeAccept, for: 2)
    var far = RpgSaveStore.newPlayer(name: "friend", cls: .mage, id: 2)
    far.level = 10
    far.pos = CGPoint(x: far.pos.x + 400, y: far.pos.y)
    w.addPlayer(far)
    w.step(1.0 / 30, inputs: [:])
    check(w.tradeView(for: 1) == nil, "traders who move apart lose the trade")
}

// MARK: party fixes
do {
    let w = tradeWorld()
    var p3 = RpgSaveStore.newPlayer(name: "third", cls: .archer, id: 3)
    p3.level = 10
    w.addPlayer(p3)
    w.perform(.invite(2), for: 1)
    w.perform(.acceptInvite, for: 2)
    let oldParty = w.player(2)?.partyID
    w.perform(.leaveParty, for: 1)
    w.perform(.invite(3), for: 1)
    w.perform(.acceptInvite, for: 3)
    check(w.player(1)?.partyID != oldParty || oldParty == nil, "a founder who left forms a new party instead of rejoining the old one")

    var p4 = RpgSaveStore.newPlayer(name: "deep", cls: .warrior, id: 4)
    p4.level = 60
    p4.map = .crypt
    p4.pos = RpgMap.center(RpgMaps.def(.crypt).portals.first!.arrive)
    p4.visited.insert(.crypt)
    w.addPlayer(p4)
    w.perform(.invite(1), for: 4)
    w.perform(.acceptInvite, for: 1)
    w.perform(.warpToMember(4), for: 1)
    check(w.player(1)?.map == .town, "warping to a party member checks the level a portal there would need")
}

// MARK: monsters: density and new behaviours
/// A world with a strong player parked next to `mob` on `map` (tries a few offsets until the spot is walkable).
func parkedWorld(on map: RpgMapID, level: Int = 60, near target: (RpgWorld) -> RpgMob?) -> (RpgWorld, RpgMob)? {
    var seed = RpgSaveStore.newPlayer(name: "bait", cls: .warrior, id: 2)
    seed.level = level
    seed.map = map
    seed.pos = RpgMap.center(RpgMaps.def(map).portals.first!.arrive)
    let w = world(level: level)
    w.addPlayer(seed)
    guard let mob = target(w) else { return nil }
    for off in [CGPoint(x: -50, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 0, y: -50), CGPoint(x: 0, y: 50), CGPoint(x: -30, y: 30)] {
        var p = seed
        p.pos = CGPoint(x: mob.pos.x + off.x, y: mob.pos.y + off.y)
        if RpgMap(RpgMaps.def(map)).canStand(p.pos) { w.addPlayer(p); return (w, mob) }
    }
    return nil
}

do {
    for map in RpgMapID.allCases where map != .tower && RpgMaps.def(map).kind != .boss {
        let def = RpgMaps.def(map)
        guard !def.monsters.isEmpty else { continue }
        let want = def.monsters.reduce(0) { $0 + Int((Double($1.count) * RpgWorld.monsterDensity).rounded(.up)) }
        let w = world(level: 1)
        var p = RpgSaveStore.newPlayer(name: "scout", cls: .warrior, id: 2)
        p.map = map
        p.pos = RpgMap.center(def.portals.first!.arrive)
        w.addPlayer(p)
        check(w.mobs[map]?.count == want, "\(map.rawValue) spawns \(want) monsters (density x\(RpgWorld.monsterDensity))")
    }
    let ids = RpgMonsters.all.map(\.id)
    check(Set(ids).count == ids.count, "monster ids are unique (\(ids.count) monsters)")
    let allSprites = MainActor.assumeIsolated { RpgMonsters.all.allSatisfy { RpgArt.sprite($0.sprite) != nil } }
    check(allSprites, "every monster has a sprite")
    check(RpgMonsters.all.filter { [.swarm, .charger, .exploder].contains($0.behavior) }.count >= 33, "at least 33 pack / charger / bomb monsters exist")
}

do {
    // Swarm: waking one wakes the pack around it.
    if let (w, a) = parkedWorld(on: .desert, near: { $0.mobs[.desert]?.first { $0.def.id == "desertswarm" } }) {
        // The pack is whoever stands within 90 px of the first monster at the start (they wander afterwards).
        let packIDs = Set((w.mobs[.desert] ?? []).filter { $0.def.id == "desertswarm" && hypot($0.pos.x - a.pos.x, $0.pos.y - a.pos.y) < 90 }.map(\.id))
        for _ in 0..<12 { w.step(1.0 / 30, inputs: [:]) }
        let pack = (w.mobs[.desert] ?? []).filter { packIDs.contains($0.id) }
        check(pack.count >= 1 && pack.allSatisfy { $0.targetID != nil }, "a swarm pack (\(pack.count) near) all turn on the player together")
    } else { check(false, "found a spot next to a swarm monster") }
}
do {
    // Charger: telegraphs, then dashes.
    if let (w, a) = parkedWorld(on: .snow, near: { $0.mobs[.snow]?.first { $0.def.id == "snowcharger" } }) {
        var telegraphed = false, dashed = false
        for _ in 0..<240 {
            w.step(1.0 / 30, inputs: [:])
            if let m = w.mobs[.snow]?.first(where: { $0.id == a.id }) {
                if m.windup != nil { telegraphed = true }
                if m.chargeDir != nil { dashed = true }
            }
        }
        check(telegraphed && dashed, "a charger winds up and then dashes")
    } else { check(false, "found a spot next to a charger") }
}
do {
    // Exploder: runs in, detonates, hurts, and pays no XP. A bomb stuck behind scenery does not count against it:
    // try a few worlds, each parked next to a different bomb.
    var blew = false, hurt = false, noXP = false
    for _ in 0..<8 where !blew {
        guard let (w, a) = parkedWorld(on: .volcano, level: 40, near: { world in world.mobs[.volcano]?.filter { $0.def.id == "volcanoexploder" }.randomElement() }) else { continue }
        let hpBefore = w.player(2)!.hp, xpBefore = w.player(2)!.xp
        for _ in 0..<240 {
            w.step(1.0 / 30, inputs: [:])
            if w.mobs[.volcano]?.first(where: { $0.id == a.id })?.dead == true { blew = true; break }
        }
        if blew { hurt = w.player(2)!.hp < hpBefore; noXP = w.player(2)!.xp == xpBefore }
    }
    check(blew, "an exploder detonates next to the player")
    check(hurt && noXP, "the blast hurts and gives no XP")
}
do {
    // The densest map still steps quickly.
    var seed = RpgSaveStore.newPlayer(name: "lag", cls: .warrior, id: 2)
    seed.level = 60
    seed.map = .desert
    seed.pos = RpgMap.center(RpgMaps.def(.desert).portals.first!.arrive)
    let w = world(level: 60)
    w.addPlayer(seed)
    let count = w.mobs[.desert]?.count ?? 0
    let start = Date()
    for _ in 0..<600 { w.step(1.0 / 30, inputs: [:]) }
    let perStep = Date().timeIntervalSince(start) / 600 * 1000
    check(perStep < 4, "desert with \(count) monsters steps in \(String(format: "%.2f", perStep)) ms (budget 4 ms)")
}

// MARK: items: accessories, crafting, buffs, materials
do {
    check(RpgItems.all.count >= 105, "the item table has \(RpgItems.all.count) items")
    check((0..<8).allSatisfy { RpgItems.item("ring\($0)")?.kind == .ring && RpgItems.item("amulet\($0)")?.kind == .amulet && RpgItems.item("helmet\($0)")?.kind == .helmet && RpgItems.item("boots\($0)")?.kind == .boots }, "8 tiers each of rings, amulets, helmets and boots exist")
    check(RpgMaterials.bands.allSatisfy { RpgItems.item($0.item)?.kind == .material }, "every material band points at a material")
    check(RpgRecipes.all.allSatisfy { r in RpgItems.item(r.output) != nil && r.materials.keys.allSatisfy { RpgItems.item($0) != nil } }, "every recipe uses real items (\(RpgRecipes.all.count) recipes)")

    var p = RpgSaveStore.newPlayer(name: "jeweller", cls: .warrior, id: 1)
    p.level = 20
    p.inventory["ring2"] = 1
    p.inventory["ring1"] = 1
    p.inventory["amulet3"] = 1
    let w = RpgWorld(player: p)
    let before = w.player(1)!
    w.perform(.equip("ring2"), for: 1)
    w.perform(.equip("amulet3"), for: 1)
    let after = w.player(1)!
    check(after.maxHP == before.maxHP + 110 + 380 && after.maxMP == before.maxMP + 80, "ring and amulet add HP and MP (\(Int(before.maxHP)) -> \(Int(after.maxHP)))")
    check(after.attack(at: 0) > before.attack(at: 0) && after.critChance(at: 0) > before.critChance(at: 0), "a ring raises attack and crit")
    check(after.defense == before.defense + 12, "an amulet adds defense")
    check(after.inventory["ring2"] == nil && after.ring == "ring2", "the equipped ring leaves the bag")
    w.perform(.equip("ring1"), for: 1)
    check(w.player(1)?.ring == "ring1" && w.player(1)?.inventory["ring2"] == 1, "swapping rings returns the old one to the bag")

    var bad = RpgSaveStore.snapshot(w.player(1)!)
    check(RpgSaveStore.player(from: bad, id: 1).ring == "ring1" && RpgSaveStore.player(from: bad, id: 1).amulet == "amulet3", "equipped accessories survive a save round trip")
    bad.ring = "sword1"
    bad.amulet = "nonsense"
    check(RpgSaveStore.player(from: bad, id: 1).ring == nil && RpgSaveStore.player(from: bad, id: 1).amulet == nil, "a save cannot put the wrong item in an accessory slot")
}
do {
    // Crafting at the smith.
    let smithDoor = RpgWorld.townSpawn
    _ = smithDoor
    var p = RpgSaveStore.newPlayer(name: "crafter", cls: .mage, id: 1)
    p.level = 20
    p.gold = 5000
    p.inventory["mat_jelly"] = 5
    p.inventory["mat_hide"] = 3
    let town = RpgMap(RpgMaps.def(.town))
    let door = town.buildings.first { $0.place == .smith }!.door
    p.pos = door
    let w = RpgWorld(player: p)
    w.perform(.craft("ring0"), for: 1)
    let r = w.player(1)!
    check(r.inventory["ring0"] == 1 && r.inventory["mat_jelly"] == nil && r.inventory["mat_hide"] == nil && r.gold == 4800, "crafting a ring spends the materials and gold")
    w.perform(.craft("ring0"), for: 1)
    check(w.player(1)?.inventory["ring0"] == 1, "crafting without materials does nothing")

    var far = RpgSaveStore.newPlayer(name: "away", cls: .mage, id: 1)
    far.gold = 5000
    far.inventory["mat_jelly"] = 5
    far.inventory["mat_hide"] = 3
    let w2 = RpgWorld(player: far)
    w2.perform(.craft("ring0"), for: 1)
    check(w2.player(1)?.inventory["ring0"] == nil, "crafting only works at the smith")
}
do {
    // Buff items.
    var p = RpgSaveStore.newPlayer(name: "buffed", cls: .archer, id: 1)
    p.inventory["buff_atk"] = 1
    p.inventory["buff_speed"] = 1
    p.inventory["buff_xp"] = 1
    p.inventory["buff_luck"] = 1
    let w = RpgWorld(player: p)
    let t0 = w.time
    let atk0 = w.player(1)!.attack(at: t0), spd0 = w.player(1)!.speed(at: t0)
    for id in ["buff_atk", "buff_speed", "buff_xp", "buff_luck"] { w.perform(.equip(id), for: 1) }
    let q = w.player(1)!
    check(abs(q.attack(at: w.time) / atk0 - 1.3) < 0.001, "attack elixir gives +30% attack")
    check(abs(q.speed(at: w.time) / spd0 - 1.25) < 0.001, "speed elixir gives +25% speed")
    check(q.buffActive("xp", w.time) && q.buffActive("luck", w.time) && q.inventory["buff_atk"] == nil, "buffs start and the item is consumed")
    var t = 0.0
    while t < 61 { w.step(1.0 / 30, inputs: [:]); t += 1.0 / 30 }
    check(!w.player(1)!.buffActive("atk", w.time) && w.player(1)!.buffActive("xp", w.time), "the 60 s buffs end, the 10 min ones last")
}
do {
    // Monsters drop crafting materials as you hunt.
    let (w, id) = fieldWorld(level: 30)
    hunt(w, id: id, seconds: 60)
    let bag = w.player(id)!.inventory
    check((bag["mat_jelly"] ?? 0) + (bag["mat_hide"] ?? 0) > 0, "hunting in the field yields crafting materials (jelly \(bag["mat_jelly"] ?? 0), hide \(bag["mat_hide"] ?? 0))")
}

do {
    // Helmet and boots.
    var p = RpgSaveStore.newPlayer(name: "knight", cls: .warrior, id: 1)
    p.inventory["helmet3"] = 1
    p.inventory["boots3"] = 1
    let w = RpgWorld(player: p)
    let before = w.player(1)!
    w.perform(.equip("helmet3"), for: 1)
    w.perform(.equip("boots3"), for: 1)
    let after = w.player(1)!
    check(after.maxHP == before.maxHP + 280 && after.defense == before.defense + 9 + 7, "helmet and boots add HP and defense")
    check(abs(after.speed(at: 0) / before.speed(at: 0) - 1.05) < 0.001, "boots add walking speed")
    check(RpgSaveStore.player(from: RpgSaveStore.snapshot(after), id: 1).helmet == "helmet3" && RpgSaveStore.player(from: RpgSaveStore.snapshot(after), id: 1).boots == "boots3", "helmet and boots save")
}
do {
    // A protection scroll keeps the enhancement level when a +7 or higher upgrade fails.
    var p = RpgSaveStore.newPlayer(name: "smith", cls: .warrior, id: 1)
    p.level = 30
    p.gold = 100_000_000
    p.inventory["stone"] = 500
    p.inventory["scroll_protect"] = 30
    p.plus[p.weapon] = 8
    let w = RpgWorld(player: p)
    var lowest = 99, spent = 0
    for _ in 0..<40 {
        w.perform(.enhance(weapon: true), for: 1)
        lowest = min(lowest, w.player(1)!.plus[w.player(1)!.weapon] ?? 0)
    }
    spent = 30 - (w.player(1)!.inventory["scroll_protect"] ?? 0)
    check(lowest >= 8 && spent > 0, "protection scrolls stop +8 gear from dropping (used \(spent))")
}

// MARK: seven classes
do {
    check(RpgClass.allCases.count == 8, "there are 8 classes")
    for cls in RpgClass.allCases {
        let weapons = (0..<9).allSatisfy { RpgItems.item("\(cls.weaponPrefix)\($0)")?.kind == .weapon(cls) }
        check(weapons && RpgItems.item(cls.starterWeapon) != nil, "\(cls.name) has nine weapon tiers")
        check(cls.skills.count == 8 && cls.skills.filter(\.starter).count == 2, "\(cls.name) has 8 skills, 2 of them starters")
        let sprite = MainActor.assumeIsolated { RpgArt.sprite(cls.rawValue) != nil }
        check(sprite, "\(cls.name) has a sprite")
        let p = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
        check(p.skills.count == 2 && p.slots.compactMap { $0 }.count == 2, "\(cls.name) starts with its two starter skills on the hotbar")
        var hi = p
        hi.level = 30
        check(hi.maxHP > p.maxHP && hi.attack(at: 0) > p.attack(at: 0), "\(cls.name) grows with level")
        // 2차 전직: both branches work at Lv20 and teach the first skill.
        for job in 1...2 {
            var q = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
            q.level = 20
            let w = RpgWorld(player: q)
            w.perform(.advance(job), for: 1)
            let got = w.player(1)!
            let first = RpgJobs.def(cls, job)!.skills[0]
            check(got.job == job && got.skills[first] != nil, "\(cls.name) job \(job) (\(RpgJobs.def(cls, job)!.name)) advances and learns \(first)")
        }
    }
    check(RpgJobs.all.count == 16 && RpgJobs.skills.count == 32, "16 advanced jobs with 32 job skills")
}

/// A level-60 player of `cls` standing in the thickest cluster of desert monsters, hurt, with `skill` on slot 0.
func skillBench(_ cls: RpgClass, job: Int, skill: String) -> (RpgWorld, RpgMob)? {
    let w = world(level: 1)
    var seed = RpgSaveStore.newPlayer(name: "caster", cls: cls, id: 2)
    seed.level = 60
    seed.map = .desert
    seed.pos = RpgMap.center(RpgMaps.def(.desert).portals.first!.arrive)
    w.addPlayer(seed)
    let all = (w.mobs[.desert] ?? []).filter { !$0.dead }
    guard let center = all.max(by: { a, b in
        all.filter { hypot($0.pos.x - a.pos.x, $0.pos.y - a.pos.y) < 50 }.count < all.filter { hypot($0.pos.x - b.pos.x, $0.pos.y - b.pos.y) < 50 }.count
    }) else { return nil }
    let map = RpgMap(RpgMaps.def(.desert))
    for off in [CGPoint(x: -40, y: 0), CGPoint(x: 40, y: 0), CGPoint(x: 0, y: -40), CGPoint(x: 0, y: 40), CGPoint(x: -25, y: 25)] {
        var p = seed
        p.pos = CGPoint(x: center.pos.x + off.x, y: center.pos.y + off.y)
        guard map.canStand(p.pos) else { continue }
        p.job = job
        p.skills[skill] = 1
        p.slots[0] = skill
        p.hp = p.maxHP * 0.3
        p.mp = p.maxMP
        w.addPlayer(p)
        return (w, center)
    }
    return nil
}

do {
    var failed: [String] = []
    var tried = 0
    var defs: [(RpgClass, Int, RpgSkillDef)] = []
    for cls in RpgClass.allCases {
        for sk in cls.skills { defs.append((cls, 0, sk)) }
        for job in 1...2 { for tier in 1...RpgTiers.maxTier { for id in RpgJobs.def(cls, job, tier: tier)!.skills { defs.append((cls, job, RpgSkills.def(id)!)) } } }
    }
    for (cls, job, sk) in defs {
        var ok = false
        for _ in 0..<8 where !ok {   // a cluster behind scenery, or a shot that flies past, deserves another world
            guard let (w, center) = skillBench(cls, job: job, skill: sk.id) else { continue }
            let me = w.player(2)!
            let near = { (w: RpgWorld) in (w.mobs[.desert] ?? []).filter { !$0.dead && hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < 130 }.reduce(0.0) { $0 + $1.hp } }
            let hpBefore = near(w), mobsBefore = (w.mobs[.desert] ?? []).filter { !$0.dead && hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < 130 }.count
            // Face the cluster (a remote-style report), then cast.
            let dx = center.pos.x - me.pos.x, dy = center.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
            var input = RpgInput()
            input.pos = me.pos
            input.facing = CGVector(dx: dx / d, dy: dy / d)
            w.step(1.0 / 30, inputs: [2: input])
            let before = w.player(2)!
            w.perform(.cast(0), for: 2)
            let cast = w.player(2)!
            let spent = (cast.cooldowns[sk.id] ?? 0) > 0 && cast.mp < before.mp
            for _ in 0..<75 { w.step(1.0 / 30, inputs: [2: input]) }
            let after = w.player(2)!
            let hpAfter = near(w)
            let aliveAfter = (w.mobs[.desert] ?? []).filter { !$0.dead && hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < 130 }.count
            let damaged = hpAfter < hpBefore - 1 || aliveAfter < mobsBefore
            let healed = after.hp > before.hp
            let buffed = after.rageUntil > before.rageUntil || after.ironUntil > before.ironUntil || after.focusUntil > before.focusUntil
                || after.shieldUntil > before.shieldUntil || after.frenzyUntil > before.frenzyUntil || after.cycloneUntil > before.cycloneUntil || after.invulnerable > before.invulnerable || after.buffUntil["speed"] != nil || after.dash != nil
            ok = spent && (sk.power > 0 ? damaged : (healed || buffed))
            tried += 1
        }
        if !ok { failed.append("\(cls.name)/\(sk.name)") }
    }
    check(failed.isEmpty, "all \(defs.count) skills work when cast (\(failed.isEmpty ? "ok" : "failing: " + failed.joined(separator: ", ")))")
}
do {
    // The four new classes can actually fight with their basic attack.
    for cls in [RpgClass.rogue, .cleric, .monk, .summoner] {
        let (w, id) = fieldWorld(level: 20, cls: cls)
        hunt(w, id: id, seconds: 30)
        let kills = w.player(id)!.kills.values.reduce(0, +)
        check(kills > 0, "\(cls.name) kills monsters with basic attacks (\(kills) in 30 s)")
    }
}

// MARK: character slots
do {
    for slot in 1...3 { RpgSaveStore.delete(slot: slot) }
    let classes: [RpgClass] = [.warrior, .monk, .summoner]
    for (k, cls) in classes.enumerated() {
        var p = RpgSaveStore.newPlayer(name: "slot\(k + 1)", cls: cls, id: 1)
        p.level = 10 * (k + 1)
        RpgSaveStore.save(RpgSaveStore.snapshot(p), slot: k + 1)
    }
    var allOK = true
    for (k, cls) in classes.enumerated() {
        if case .ok(let d) = RpgSaveStore.load(slot: k + 1) { allOK = allOK && d.cls == cls && d.name == "slot\(k + 1)" && d.level == 10 * (k + 1) } else { allOK = false }
    }
    check(allOK, "three slots hold three different characters")
    check(FileManager.default.fileExists(atPath: simStateDir + "/rpg-save.json") && FileManager.default.fileExists(atPath: simStateDir + "/rpg-save-3.json"), "slot 1 keeps the original file name, the others get their own")

    RpgSaveStore.delete(slot: 2)
    var left = 0
    if case .none = RpgSaveStore.load(slot: 2) { left += 1 }
    if case .ok = RpgSaveStore.load(slot: 1) { left += 1 }
    if case .ok = RpgSaveStore.load(slot: 3) { left += 1 }
    check(left == 3, "deleting one slot leaves the others alone")

    try? "not a save".write(toFile: simStateDir + "/rpg-save-3.json", atomically: true, encoding: .utf8)
    var tamperedOnly = false
    if case .tampered = RpgSaveStore.load(slot: 3), case .ok = RpgSaveStore.load(slot: 1) { tamperedOnly = true }
    check(tamperedOnly, "a damaged slot file is flagged without touching the other slots")
    RpgSaveStore.quarantine(slot: 3)
    var gone = false
    if case .none = RpgSaveStore.load(slot: 3) { gone = true }
    check(gone, "a damaged slot is moved aside")

    var p = RpgSaveStore.newPlayer(name: "extra", cls: .rogue, id: 1)
    RpgSaveStore.save(RpgSaveStore.snapshot(p), slot: 4)
    var outside = false
    if case .none = RpgSaveStore.load(slot: 4) { outside = !FileManager.default.fileExists(atPath: simStateDir + "/rpg-save-4.json") }
    check(outside, "slot numbers beyond the limit are rejected")

    RpgSaveStore.slot = 2
    p.name = "current"
    RpgSaveStore.save(RpgSaveStore.snapshot(p))
    var viaDefault = false
    if case .ok(let d) = RpgSaveStore.load(slot: 2) { viaDefault = d.name == "current" }
    check(viaDefault, "saving without a slot goes to the slot picked on the title screen")
    RpgSaveStore.slot = 1
}

// Check groups that live in their own files (Tests/RpgSim/*Checks.swift).
contentChecks()
rogueChecks()
statChecks()
tierChecks()
regionChecks()
combatChecks()
designChecks()

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")

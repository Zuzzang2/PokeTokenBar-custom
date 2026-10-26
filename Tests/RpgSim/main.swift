import Foundation
@testable import PokeTokenBar

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

/// Walks toward the nearest living monster and attacks for `seconds`; returns the highest combo seen.
@discardableResult
func hunt(_ w: RpgWorld, id: Int, seconds: Double) -> Int {
    var t = 0.0, best = 0
    while t < seconds {
        guard let me = w.player(id) else { break }
        let target = (w.mobs[me.map] ?? []).filter { !$0.dead }
            .min { hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < hypot($1.pos.x - me.pos.x, $1.pos.y - me.pos.y) }
        var input = RpgInput()
        if let target {
            let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
            // Report positions like a remote player so the walk cannot snag on scenery: hop up to 80px per step.
            let hop = min(d, 80)
            input.pos = CGPoint(x: me.pos.x + dx / d * (d > 80 ? hop : max(0, d - 10)), y: me.pos.y + dy / d * (d > 80 ? hop : max(0, d - 10)))
            input.facing = CGVector(dx: dx / d, dy: dy / d)
            input.attack = true
        }
        w.step(1.0 / 30, inputs: [id: input])
        best = max(best, w.player(id)?.combo ?? 0)
        t += 1.0 / 30
    }
    return best
}

/// Attacks one specific monster until it dies (or `seconds` pass).
func kill(_ w: RpgWorld, id: Int, mob mobID: Int, seconds: Double = 20) {
    var t = 0.0
    while t < seconds {
        guard let me = w.player(id), let target = (w.mobs[me.map] ?? []).first(where: { $0.id == mobID }), !target.dead else { return }
        let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
        var input = RpgInput()
        let go = d > 80 ? min(d, 80) : max(0, d - 10)
        input.pos = CGPoint(x: me.pos.x + dx / d * go, y: me.pos.y + dy / d * go)
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
        if let e = (w.mobs[.field] ?? []).first(where: { $0.elite }) { found = (w, id, e); break }
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

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")

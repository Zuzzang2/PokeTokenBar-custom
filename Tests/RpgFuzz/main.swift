import Foundation
@testable import PokeTokenBar

// Fuzz probe: three players in one world fire random actions and inputs for a long time; after every step the world's invariants are
// checked (finite positions and HP, no negative gold or counts, sane levels). A crash (runtime trap) or a violation prints the seed.
// Usage: scripts/rpg-fuzz.sh [seeds] [steps]

struct Rng {
    var s: UInt64
    mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
    mutating func pick<T>(_ a: [T]) -> T { a[int(a.count)] }
    mutating func double(_ lo: Double, _ hi: Double) -> Double { lo + Double(next() % 1_000_000) / 1_000_000 * (hi - lo) }
}

let seeds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 20 : 20
let steps = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 6000 : 6000
let itemIDs = RpgItems.all.map(\.id)
let skillIDs = RpgSkills.all.map(\.id) + RpgJobs.skills.map(\.id) + RpgTiers.skills.map(\.id)
let recipeIDs = RpgRecipes.all.map(\.id)
let mapIDs = RpgMapID.allCases
let cosmeticIDs = RpgCosmetics.all.map(\.id)
let junk = ["", "  ", "a", "<>&", "새이름", String(repeating: "가", count: 40), "dave\u{0}", "💥", "taken", "p2", "p3"]

func randomAction(_ r: inout Rng, others: [Int]) -> RpgAction {
    switch r.int(48) {
    case 0: return .interact
    case 1: return .hpPotion
    case 2: return .mpPotion
    case 3: return .scroll
    case 4, 5: return .equip(r.int(10) == 0 ? "nope" : r.pick(itemIDs))
    case 6: return .buy(r.int(10) == 0 ? "nope" : r.pick(itemIDs))
    case 7: return .sell(r.pick(itemIDs))
    case 8: return .levelSkill(r.pick(skillIDs))
    case 9: return .assign(slot: r.int(12) - 2, skill: r.int(4) == 0 ? nil : r.pick(skillIDs))
    case 10: return .enhance(weapon: r.int(2) == 0)
    case 11: return .acceptQuest(UUID().uuidString)
    case 12: return .claimQuest(UUID().uuidString)
    case 13: return .abandonQuest(UUID().uuidString)
    case 14: return .warp(r.int(8) == 0 ? RpgMapID("missing") : r.pick(mapIDs))
    case 15, 16, 17, 18: return .cast(r.int(10) - 1)
    case 19: return .invite(r.pick(others + [99]))
    case 20: return .acceptInvite
    case 21: return .declineInvite
    case 22: return .leaveParty
    case 23: return .warpToMember(r.pick(others + [99]))
    case 24: return .advance(r.int(4))
    case 25: return .promote
    case 26: return .tradeRequest(r.pick(others + [99]))
    case 27: return .tradeAccept
    case 28: return .tradeDecline
    case 29: return .tradeCancel
    case 30: return .tradeOffer(item: r.pick(itemIDs), count: r.int(8) - 2)
    case 31: return .tradeGold(r.int(5000) - 500)
    case 32: return .tradeConfirm(r.int(2) == 0)
    case 33: return .craft(r.int(10) == 0 ? "nope" : r.pick(recipeIDs))
    case 34: return .addStat(r.int(7) - 1)
    case 35: return .resetStats
    case 36: return .unequip(r.int(9) - 1)
    case 37: return .claimStory
    case 38: return .wear(r.int(8) == 0 ? "nope" : r.pick(cosmeticIDs))
    case 39: return .unwear(r.pick(RpgCosmeticSlot.allCases.map(\.rawValue) + ["x"]))
    case 40: return .buyCosmetic(r.pick(cosmeticIDs))
    case 41: return .gacha(r.int(14) - 2)
    case 42: return .rename(r.pick(junk))
    case 43: return .pet(nil)
    default: return .cast(r.int(8))
    }
}

func check(_ w: RpgWorld, _ ids: [Int], seed: Int, step: Int) -> String? {
    for id in ids {
        guard let p = w.player(id) else { return "player \(id) vanished" }
        if !p.pos.x.isFinite || !p.pos.y.isFinite { return "p\(id) pos not finite \(p.pos)" }
        if !p.hp.isFinite || !p.mp.isFinite { return "p\(id) hp/mp not finite \(p.hp) \(p.mp)" }
        if p.gold < 0 { return "p\(id) negative gold \(p.gold)" }
        if p.hp > p.maxHP + 1 || p.mp > p.maxMP + 1 { return "p\(id) hp/mp above max \(p.hp)/\(p.maxHP) \(p.mp)/\(p.maxMP)" }
        if let bad = p.inventory.first(where: { $0.value <= 0 }) { return "p\(id) inventory \(bad.key)=\(bad.value)" }
        if let bad = p.inventory.first(where: { RpgItems.item($0.key) == nil }) { return "p\(id) unknown item \(bad.key)" }
        if !(1...RpgMaps.maxLevel).contains(p.level) { return "p\(id) level \(p.level)" }
        if p.sp < 0 || p.ap < 0 || p.stats.contains(where: { $0 < 0 || $0 > RpgStats.cap }) { return "p\(id) sp/ap/stats \(p.sp) \(p.ap) \(p.stats)" }
        if p.name.isEmpty || p.name.count > 24 { return "p\(id) name '\(p.name)'" }
        if p.wardrobe.contains(where: { RpgCosmetics.def($0) == nil }) { return "p\(id) unknown cosmetic" }
        if p.worn.contains(where: { !p.wardrobe.contains($0.value) }) { return "p\(id) wears an unowned cosmetic" }
        if p.plus.contains(where: { $0.value < 0 }) { return "p\(id) negative plus" }
    }
    for (_, list) in w.mobs { for m in list where !m.pos.x.isFinite || !m.pos.y.isFinite || !m.hp.isFinite { return "mob \(m.def.id) bad state \(m.pos) \(m.hp)" } }
    if w.shots.count > 5000 || w.fx.count > 5000 || w.drops.count > 5000 { return "unbounded growth: shots \(w.shots.count) fx \(w.fx.count) drops \(w.drops.count)" }
    return nil
}

var bad = 0
let start = Date()
for seed in 1...seeds {
    var r = Rng(s: UInt64(seed) &* 7919)
    let classes = RpgClass.allCases
    var players: [RpgPlayer] = []
    for k in 0..<3 {
        var p = RpgSaveStore.newPlayer(name: "p\(k + 1)", cls: classes[(seed + k) % classes.count], id: k + 1)
        p.level = [1, 12, 30, 45, 60, 80, 100][r.int(7)]
        p.gold = r.int(3) == 0 ? 50_000_000 : r.int(5000)
        p.sp = r.int(40); p.ap = r.int(200)
        for _ in 0..<r.int(12) { p.inventory[r.pick(itemIDs), default: 0] += 1 + r.int(5) }
        for s in p.cls.skills where s.minLevel <= p.level && r.int(2) == 0 { p.skills[s.id] = 1 + r.int(6) }
        p.hp = p.maxHP; p.mp = p.maxMP
        players.append(p)
    }
    let w = RpgWorld(player: players[0])
    for p in players.dropFirst() { w.addPlayer(p) }
    let ids = players.map(\.id)
    var failure: String?
    var lastAction = ""
    for step in 0..<steps {
        var inputs: [Int: RpgInput] = [:]
        for id in ids {
            guard let me = w.player(id) else { continue }
            var input = RpgInput()
            if r.int(4) != 0 {
                let ang = r.double(0, .pi * 2), d = r.double(0, 6)
                input.pos = CGPoint(x: me.pos.x + CGFloat(cos(ang) * d), y: me.pos.y + CGFloat(sin(ang) * d))
                input.facing = CGVector(dx: cos(ang), dy: sin(ang))
            }
            input.attack = r.int(3) == 0
            if r.int(6) == 0 { input.slots.insert(r.int(8)) }
            inputs[id] = input
            if r.int(10) == 0 {
                let a = randomAction(&r, others: ids.filter { $0 != id })
                lastAction = "p\(id) \(a)"
                w.perform(a, for: id)
            }
        }
        w.step(1.0 / 30, inputs: inputs)
        if let f = check(w, ids, seed: seed, step: step) { failure = "step \(step): \(f) (last action \(lastAction))"; break }
        // Players warp around a lot: keep a few in dangerous places so monsters actually fight.
    }
    if let failure { bad += 1; print("FAIL seed \(seed): \(failure)") }
}
print("fuzz: \(seeds) seeds × \(steps) steps in \(Int(Date().timeIntervalSince(start))) s — \(bad == 0 ? "no violations" : "\(bad) failing seeds")")
exit(bad == 0 ? 0 : 1)

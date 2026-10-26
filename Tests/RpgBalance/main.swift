import Foundation
@testable import PokeTokenBar

// Balance probe: a bot plays every class at several levels with level-appropriate gear, jobs, skills and stat points,
// and prints kills per minute, deaths and damage taken. Compare columns to see which class is out of line.
// Usage: scripts/rpg-balance.sh [seconds] [level,level,...]

let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 60 : 60
let levels = CommandLine.arguments.count > 2 ? CommandLine.arguments[2].split(separator: ",").compactMap { Int($0) } : [10, 20, 30, 45, 60, 80, 100]

func pick(_ table: [(Int, Int)], _ level: Int) -> Int { table.last { level >= $0.0 }?.1 ?? table[0].1 }
let weaponTier: [(Int, Int)] = [(1, 0), (8, 1), (14, 2), (22, 5), (35, 6), (45, 7), (55, 8), (65, 9), (75, 10), (88, 11), (97, 12)]
let armorTier: [(Int, Int)] = [(1, 0), (6, 1), (12, 2), (20, 3), (30, 4), (40, 5), (50, 6), (58, 7), (68, 8), (78, 9), (88, 10), (97, 11)]

let ranged: Set<RpgClass> = [.archer, .mage, .cleric, .summoner, .mechanic]

func mapFor(level: Int) -> RpgMapDef {
    func band(_ t: String) -> ClosedRange<Int>? {
        let nums = t.split { !$0.isNumber }.compactMap { Int($0) }
        guard t.contains("Lv"), !t.contains("보스"), let lo = nums.first else { return nil }
        return lo...(nums.last ?? lo)
    }
    let fits = RpgMaps.all.filter { $0.id != .tower && band($0.levelText)?.contains(level) == true }
    return fits.max { band($0.levelText)!.lowerBound < band($1.levelText)!.lowerBound } ?? RpgMaps.def(.field)
}

func build(_ cls: RpgClass, level: Int, mapID: RpgMapID, id: Int) -> RpgPlayer {
    var p = RpgSaveStore.newPlayer(name: "bot", cls: cls, id: id)
    p.level = level
    p.gold = 10_000_000
    let wt = pick(weaponTier, level), at = pick(armorTier, level)
    p.weapon = "\(cls.weaponPrefix)\(wt)"
    p.armor = "armor\(at)"
    p.ring = "ring\(max(0, at - 1))"; p.amulet = "amulet\(max(0, at - 1))"; p.helmet = "helmet\(max(0, at - 1))"; p.boots = "boots\(max(0, at - 1))"
    p.inventory = ["hp3": 200, "hp5": 200, "mp1": 200, "mp3": 200, "hp0": 200, "mp0": 200]
    // Skill points: everything learnable up to the level, spread evenly (what a sensible player does).
    let usable = cls.skills.filter { $0.minLevel <= level }
    for s in usable { p.skills[s.id] = 1 }
    var sp = (1..<max(1, level)).reduce(0) { $0 + (($1 + 1) % 10 == 0 ? 2 : 1) }
    var round = 0
    while sp > 0, !usable.isEmpty, round < 200 {
        let s = usable[round % usable.count]
        if (p.skills[s.id] ?? 1) < s.maxLevel { p.skills[s.id] = (p.skills[s.id] ?? 1) + 1; sp -= 1 }
        round += 1
        if usable.allSatisfy({ (p.skills[$0.id] ?? 1) >= $0.maxLevel }) { break }
    }
    p.sp = 0
    // Stat points: the class's main stat plus vitality.
    let ap = max(0, level - 1) * RpgStats.perLevel
    let main = cls == .mage || cls == .summoner || cls == .cleric ? 3 : (cls == .archer || cls == .rogue || cls == .mechanic ? 1 : 0)
    var stats = [0, 0, 0, 0]
    stats[main] = min(RpgStats.cap, Int(Double(ap) * 0.6)); stats[2] = min(RpgStats.cap, Int(Double(ap) * 0.4))
    p.stats = stats; p.ap = 0
    p.map = mapID
    p.pos = RpgMap.center(RpgMaps.def(mapID).portals.first { !$0.waypoint }?.at ?? RpgTile(x: 6, y: 6))
    return p
}

struct Result { var kills = 0, deaths = 0, taken = 0.0, xp = 0, gold = 0 }

func run(_ cls: RpgClass, level: Int) -> Result {
    let def = mapFor(level: level)
    let host = RpgWorld(player: RpgSaveStore.newPlayer(name: "host", cls: .warrior, id: 1))
    var p = build(cls, level: level, mapID: def.id, id: 2)
    // Promote through the tiers by the same level gates a player meets.
    host.addPlayer(p)
    if level >= RpgJobs.advanceLevel { host.perform(.advance(1), for: 2) }
    for _ in 0..<2 { host.perform(.promote, for: 2) }
    p = host.player(2)!
    let startXP = p.xp, startGold = p.gold, startLevel = p.level
    _ = startLevel
    // Fill the hotbar with the job's damaging skills first.
    var res = Result()
    var t = 0.0, lastPos = CGPoint.zero, stuck = 0, lastHP = p.maxHP, deadBefore = false
    while t < seconds {
        guard let me = host.player(2) else { break }
        if me.dead { if !deadBefore { res.deaths += 1 }; deadBefore = true } else { deadBefore = false }
        res.taken += max(0, lastHP - me.hp)
        lastHP = me.hp
        let mobs = (host.mobs[me.map] ?? []).filter { !$0.dead && $0.def.behavior != .boss }
        let target = mobs.min { hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < hypot($1.pos.x - me.pos.x, $1.pos.y - me.pos.y) }
        var input = RpgInput()
        stuck = hypot(me.pos.x - lastPos.x, me.pos.y - lastPos.y) < 0.5 ? stuck + 1 : 0
        lastPos = me.pos
        if let target, !me.dead {
            let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
            let want: CGFloat = ranged.contains(cls) ? 70 : 12
            var ux = dx / d, uy = dy / d
            var go: CGFloat = d > 80 ? 80 : max(0, d - want)
            if stuck >= 3 { let a = Double.random(in: 0..<(2 * .pi)); ux = CGFloat(cos(a)); uy = CGFloat(sin(a)); go = 40 }
            input.pos = CGPoint(x: me.pos.x + ux * go, y: me.pos.y + uy * go)
            input.facing = CGVector(dx: dx / d, dy: dy / d)
            input.attack = true
            if d < 160 { for (slot, sk) in me.slots.enumerated() where sk != nil { input.slots.insert(slot) } }
        }
        if me.hp < me.maxHP * 0.45 { host.perform(.hpPotion, for: 2) }
        if me.mp < me.maxMP * 0.25 { host.perform(.mpPotion, for: 2) }
        host.step(1.0 / 30, inputs: [2: input])
        t += 1.0 / 30
    }
    let end = host.player(2)!
    res.kills = end.kills.values.reduce(0, +)
    res.xp = end.xp - startXP
    res.gold = end.gold - startGold
    return res
}

func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
var table: [RpgClass: [Int: Result]] = [:]
let trials = Int(ProcessInfo.processInfo.environment["TRIALS"] ?? "") ?? 3
for cls in RpgClass.allCases {
    for l in levels {
        var sum = Result()
        for _ in 0..<trials { let r = run(cls, level: l); sum.kills += r.kills; sum.deaths += r.deaths; sum.taken += r.taken; sum.xp += r.xp; sum.gold += r.gold }
        table[cls, default: [:]][l] = Result(kills: sum.kills / trials, deaths: sum.deaths / trials, taken: sum.taken / Double(trials), xp: sum.xp / trials, gold: sum.gold / trials)
    }
}

print("kills / deaths / damage taken per \(Int(seconds))s")
print(pad("class", 10) + levels.map { pad("Lv\($0)", 16) }.joined())
for cls in RpgClass.allCases {
    var row = pad(cls.name, 10)
    for l in levels { let r = table[cls]![l]!; row += pad("\(r.kills)/\(r.deaths)/\(Int(r.taken))", 16) }
    print(row)
}
print("\nkills vs the median class at that level (1.00 = typical)")
print(pad("class", 10) + levels.map { pad("Lv\($0)", 8) }.joined())
for cls in RpgClass.allCases {
    var row = pad(cls.name, 10)
    for l in levels {
        let all = RpgClass.allCases.map { table[$0]![l]!.kills }.sorted()
        let median = max(1, Double(all[all.count / 2]))
        row += pad(String(format: "%.2f", Double(table[cls]![l]!.kills) / median), 8)
    }
    print(row)
}

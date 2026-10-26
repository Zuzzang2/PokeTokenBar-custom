import CoreGraphics
import Foundation

// SPIKE: "포켓몬 아레나" — a one-lane MOBA. Two teams of Pokémon champions push a lane with minion waves,
// two towers and a core each; destroy the enemy core to win. Pure simulation in low-res pixels (y down):
// the view feeds it `ArenaCommand`s for the player's champion and steps it every frame, CPU champions
// think inside. Everything here is plain state + rules so a host can later run it for a lobby and send
// snapshots, with players' commands coming in over the network.
//
// Champions come from `BattleMon`s: stats shape HP/attack/range/speed, the four moves become
// Q (skill shot), W (delayed blast), E (dash strike) and R (burst + shield, from level 3).
// Skill damage uses the move's power and the type chart against the target.

enum ArenaTeam: Int, Sendable {
    case blue = 0, red = 1
    var other: ArenaTeam { self == .blue ? .red : .blue }
    /// Direction of the enemy base along x.
    var forward: CGFloat { self == .blue ? 1 : -1 }
}

enum ArenaKind: Sendable { case champion, minion, rangedMinion, tower, core }
enum ArenaShape: Sendable { case shot, blast, dash, burst }

enum ArenaCommand: Sendable {
    case move(CGPoint)
    case attack(Int)
    case cast(slot: Int, aim: CGPoint)
    case stop
    case recall
}

struct ArenaSkill {
    let move: BattleMove
    let shape: ArenaShape
    let cooldown: TimeInterval
    var remaining: TimeInterval = 0
}

struct ArenaDash {
    var to: CGPoint
    var damage: CGFloat
    var moveType: String
    var hit: Set<Int>
}

struct ArenaUnit {
    let id: Int
    let kind: ArenaKind
    let team: ArenaTeam
    var pos: CGPoint
    var hp: CGFloat
    var maxHP: CGFloat
    let radius: CGFloat
    var speed: CGFloat
    var range: CGFloat
    var attackDamage: CGFloat
    var attackInterval: TimeInterval
    var attackTimer: TimeInterval = 0
    var targetID: Int?
    var moveTarget: CGPoint?
    var dead = false
    var diedAt: TimeInterval = 0
    var hitFlash: TimeInterval = 0
    var attackFlash: TimeInterval = 0
    var facingRight = false
    var moving = false
    var laneOffset: CGFloat = 0
    /// Towers: tier 0 is the outer tower; the inner one is shielded until it falls.
    var tier = 0
    /// Towers: an enemy champion that just hit an allied champion in range gets shot first.
    var aggroID: Int?
    var aggroUntil: TimeInterval = 0

    // Champions only.
    var name = ""
    var trainer = ""
    var speciesID: Int?
    var isShiny = false
    var types: [String] = []
    var physicalStat: CGFloat = 1
    var specialStat: CGFloat = 1
    var guardFactor: CGFloat = 1
    var baseHP: CGFloat = 0
    var baseAttack: CGFloat = 0
    var level = 1
    var xp: CGFloat = 0
    var skills: [ArenaSkill] = []
    var respawnAt: TimeInterval = 0
    var isPlayer = false
    var isCPU = false
    var shield: CGFloat = 0
    var shieldUntil: TimeInterval = 0
    var dash: ArenaDash?
    var recallAt: TimeInterval?
    var kills = 0
    var deaths = 0
    var retreating = false
    var nextThink: TimeInterval = 0

    var hpRatio: CGFloat { maxHP > 0 ? hp / maxHP : 0 }
    var isStructure: Bool { kind == .tower || kind == .core }
    var isMinion: Bool { kind == .minion || kind == .rangedMinion }
}

struct ArenaProjectile {
    var pos: CGPoint
    var vel: CGPoint
    let team: ArenaTeam
    let ownerID: Int
    let damage: CGFloat
    let moveType: String?
    let radius: CGFloat
    var life: TimeInterval
    /// Basic attacks and tower shots home in on one unit; skill shots fly straight and hit the first enemy.
    let homingID: Int?
    let size: CGFloat
}

struct ArenaBlast {
    let pos: CGPoint
    let radius: CGFloat
    let detonateAt: TimeInterval
    let team: ArenaTeam
    let ownerID: Int
    let damage: CGFloat
    let moveType: String
}

struct ArenaRing {
    let pos: CGPoint
    let radius: CGFloat
    var life: TimeInterval
    let maxLife: TimeInterval
    let moveType: String?
}

struct ArenaFloater {
    enum Style { case normal, strong, weak, hurt, gold }
    let text: String
    var pos: CGPoint
    var life: TimeInterval
    let style: Style
}

struct ArenaFeed {
    let text: String
    let at: TimeInterval
    let team: ArenaTeam?
}

struct ArenaEntry {
    let mon: BattleMon
    let trainer: String
    let isPlayer: Bool
}

final class ArenaSim {
    static let size = CGSize(width: 1000, height: 300)
    static let laneY: CGFloat = 150
    static let maxLevel = 12
    static let towerRange: CGFloat = 74
    static let waveInterval: TimeInterval = 25

    private(set) var units: [ArenaUnit] = []
    private(set) var projectiles: [ArenaProjectile] = []
    private(set) var blasts: [ArenaBlast] = []
    private(set) var rings: [ArenaRing] = []
    private(set) var floaters: [ArenaFloater] = []
    private(set) var feed: [ArenaFeed] = []
    private(set) var time: TimeInterval = 0
    private(set) var winner: ArenaTeam?
    private(set) var score = [0, 0]
    private(set) var nextWave: TimeInterval = 5
    private(set) var playerID = 0
    private var nextID = 1
    private var rng = KartRNG(seed: UInt64.random(in: 1...UInt64.max))

    init(blue: [ArenaEntry], red: [ArenaEntry]) {
        for (team, roster) in [(ArenaTeam.blue, blue), (ArenaTeam.red, red)] {
            for (n, entry) in roster.enumerated() {
                var u = Self.champion(entry.mon, id: nextID, team: team)
                u.trainer = entry.trainer
                u.isPlayer = entry.isPlayer
                u.isCPU = !entry.isPlayer
                u.laneOffset = CGFloat(n) * 14 - CGFloat(roster.count - 1) * 7
                u.pos.y += u.laneOffset
                if entry.isPlayer { playerID = nextID }
                nextID += 1
                units.append(u)
            }
            let f = team.forward
            let coreX: CGFloat = team == .blue ? 100 : 900
            for (tier, x) in [(0, coreX + f * 270), (1, coreX + f * 115)] {
                var t = ArenaUnit(id: nextID, kind: .tower, team: team, pos: CGPoint(x: x, y: Self.laneY), hp: 1700,
                                  maxHP: 1700, radius: 10, speed: 0, range: Self.towerRange, attackDamage: 0, attackInterval: 1)
                t.tier = tier
                nextID += 1
                units.append(t)
            }
            units.append(ArenaUnit(id: nextID, kind: .core, team: team, pos: CGPoint(x: coreX, y: Self.laneY), hp: 2200,
                                   maxHP: 2200, radius: 14, speed: 0, range: 0, attackDamage: 0, attackInterval: 1))
            nextID += 1
        }
    }

    static func fountain(_ team: ArenaTeam) -> CGPoint { CGPoint(x: team == .blue ? 44 : 956, y: laneY) }

    static func clampWalkable(_ p: CGPoint) -> CGPoint {
        let x = min(max(p.x, 20), 980)
        let inBase = x < 130 || x > 870
        let minY: CGFloat = inBase ? 74 : 94, maxY: CGFloat = inBase ? 226 : 206
        return CGPoint(x: x, y: min(max(p.y, minY), maxY))
    }

    static func xpNeeded(_ level: Int) -> CGFloat { CGFloat(90 + 45 * level) }

    private static func champion(_ mon: BattleMon, id: Int, team: ArenaTeam) -> ArenaUnit {
        // Clamped so a 999-stat secret monster or a tiny baby still plays inside the same band.
        func stat(_ key: String) -> CGFloat { min(max(CGFloat(mon.stats[key] ?? 80), 30), 230) }
        let hp = stat("hp"), atk = stat("attack"), def = stat("defense")
        let spa = stat("special-attack"), spd = stat("special-defense"), spe = stat("speed")
        let physical = atk >= spa
        let maxHP = 460 + hp * 3
        var u = ArenaUnit(id: id, kind: .champion, team: team, pos: fountain(team), hp: maxHP, maxHP: maxHP, radius: 6,
                          speed: 52 + spe * 0.09, range: physical ? 18 : 62, attackDamage: 22 + max(atk, spa) * 0.16,
                          attackInterval: max(0.75, 1.15 - Double(spe) / 900))
        u.name = mon.name
        u.speciesID = mon.speciesID
        u.isShiny = mon.isShiny
        u.types = mon.types
        u.physicalStat = min(max(atk / 100, 0.6), 1.9)
        u.specialStat = min(max(spa / 100, 0.6), 1.9)
        u.guardFactor = min(max(0.8 + (def + spd) / 200 * 0.35, 0.85), 1.5)
        u.baseHP = maxHP
        u.baseAttack = u.attackDamage
        u.facingRight = team == .blue
        let moves = mon.moves.isEmpty
            ? [BattleMove(name: "몸통박치기", type: "normal", power: 40, accuracy: 100, isPhysical: true, priority: 0)]
            : mon.moves
        let shapes: [ArenaShape] = [.shot, .blast, .dash, .burst]
        let cooldowns: [TimeInterval] = [4.5, 7, 9, 30]
        u.skills = (0..<4).map { ArenaSkill(move: moves[min($0, moves.count - 1)], shape: shapes[$0], cooldown: cooldowns[$0]) }
        return u
    }

    // MARK: lookup

    func index(of id: Int) -> Int? { units.firstIndex { $0.id == id } }
    func unit(_ id: Int) -> ArenaUnit? { index(of: id).map { units[$0] } }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    /// Inner towers wait for the outer one; a core waits for both towers.
    func isTargetable(_ u: ArenaUnit) -> Bool {
        switch u.kind {
        case .tower where u.tier == 1:
            return !units.contains { $0.kind == .tower && $0.team == u.team && $0.tier == 0 && !$0.dead }
        case .core:
            return !units.contains { $0.kind == .tower && $0.team == u.team && !$0.dead }
        default:
            return true
        }
    }

    func isValidTarget(_ t: ArenaUnit, for team: ArenaTeam) -> Bool {
        !t.dead && t.team != team && isTargetable(t)
    }

    // MARK: commands

    func apply(_ command: ArenaCommand, for id: Int) {
        guard winner == nil, let i = index(of: id), units[i].kind == .champion, !units[i].dead else { return }
        switch command {
        case .move(let p):
            units[i].moveTarget = Self.clampWalkable(p)
            units[i].targetID = nil
            units[i].recallAt = nil
        case .attack(let t):
            units[i].targetID = t
            units[i].moveTarget = nil
            units[i].recallAt = nil
        case .stop:
            units[i].moveTarget = nil
            units[i].targetID = nil
        case .recall:
            guard units[i].recallAt == nil, units[i].dash == nil else { return }
            units[i].recallAt = time + 3
            units[i].moveTarget = nil
            units[i].targetID = nil
        case .cast(let slot, let aim):
            cast(i, slot: slot, aim: aim)
        }
    }

    private func skillDamage(_ u: ArenaUnit, _ s: ArenaSkill) -> CGFloat {
        let stat = s.move.isPhysical ? u.physicalStat : u.specialStat
        return (55 + CGFloat(s.move.power) * 1.25) * stat * (1 + 0.07 * CGFloat(u.level - 1))
    }

    private func cast(_ i: Int, slot: Int, aim: CGPoint) {
        var u = units[i]
        guard u.skills.indices.contains(slot), u.skills[slot].remaining <= 0, u.dash == nil else { return }
        if slot == 3, u.level < 3 { return }
        let s = u.skills[slot]
        let dx = aim.x - u.pos.x, dy = aim.y - u.pos.y
        let d = max(0.001, hypot(dx, dy))
        let dir = CGPoint(x: dx / d, y: dy / d)
        if abs(dir.x) > 0.1 { u.facingRight = dir.x > 0 }
        u.recallAt = nil
        u.attackFlash = 0.2
        u.skills[slot].remaining = s.cooldown
        let damage = skillDamage(u, s)
        switch s.shape {
        case .shot:
            projectiles.append(ArenaProjectile(pos: CGPoint(x: u.pos.x + dir.x * 8, y: u.pos.y - 6 + dir.y * 8),
                                               vel: CGPoint(x: dir.x * 240, y: dir.y * 240), team: u.team, ownerID: u.id,
                                               damage: damage, moveType: s.move.type, radius: 5, life: 150.0 / 240,
                                               homingID: nil, size: 3))
        case .blast:
            let r = min(d, 115)
            let center = Self.clampWalkable(CGPoint(x: u.pos.x + dir.x * r, y: u.pos.y + dir.y * r))
            blasts.append(ArenaBlast(pos: center, radius: 26, detonateAt: time + 0.45, team: u.team, ownerID: u.id,
                                     damage: damage * 1.15, moveType: s.move.type))
        case .dash:
            let r = min(d, 85)
            u.dash = ArenaDash(to: Self.clampWalkable(CGPoint(x: u.pos.x + dir.x * r, y: u.pos.y + dir.y * r)),
                               damage: damage * 0.85, moveType: s.move.type, hit: [])
            u.moveTarget = nil
        case .burst:
            units[i] = u
            rings.append(ArenaRing(pos: u.pos, radius: 50, life: 0.5, maxLife: 0.5, moveType: s.move.type))
            let victims = units.filter {
                !$0.isStructure && isValidTarget($0, for: u.team) && dist($0.pos, u.pos) < 50 + $0.radius
            }.map(\.id)
            for v in victims { if let vi = index(of: v) { applyDamage(to: vi, damage * 1.9, from: u.id, moveType: s.move.type) } }
            if let me = index(of: u.id) {
                units[me].shield = units[me].maxHP * 0.25
                units[me].shieldUntil = time + 3
            }
            return
        }
        units[i] = u
    }

    // MARK: step

    func step(_ dt: TimeInterval) {
        time += dt
        for k in floaters.indices {
            floaters[k].life -= dt
            floaters[k].pos.y -= CGFloat(dt) * 16
        }
        floaters.removeAll { $0.life <= 0 }
        for k in rings.indices { rings[k].life -= dt }
        rings.removeAll { $0.life <= 0 }
        feed.removeAll { time - $0.at > 6 }
        guard winner == nil else { return }

        if time >= nextWave {
            spawnWave()
            nextWave += Self.waveInterval
        }
        respawnChampions()
        for id in units.filter({ $0.isCPU && !$0.dead && time >= $0.nextThink }).map(\.id) {
            guard let i = index(of: id) else { continue }
            units[i].nextThink = time + 0.2
            think(id)
        }
        for id in units.map(\.id) {
            if let i = index(of: id) { updateUnit(i, dt: dt) }
        }
        updateProjectiles(dt)
        updateBlasts()
        fountains(dt)
        separate()
        units.removeAll { $0.isMinion && $0.dead && time - $0.diedAt > 0.5 }
    }

    private func spawnWave() {
        let scale = 1 + CGFloat(time / 60) * 0.12
        for team in [ArenaTeam.blue, .red] {
            let f = team.forward
            let startX: CGFloat = team == .blue ? 140 : 860
            let offsets: [CGFloat] = [-9, 9, 0, 0]
            for k in 0..<4 {
                let ranged = k == 3
                var m = ArenaUnit(id: nextID, kind: ranged ? .rangedMinion : .minion, team: team,
                                  pos: CGPoint(x: startX - f * CGFloat(k) * 12, y: Self.laneY + offsets[k]),
                                  hp: (ranged ? 170 : 260) * scale, maxHP: (ranged ? 170 : 260) * scale, radius: 5,
                                  speed: 38, range: ranged ? 52 : 12, attackDamage: (ranged ? 22 : 16) * scale,
                                  attackInterval: ranged ? 1.25 : 1.0)
                m.laneOffset = offsets[k]
                m.facingRight = team == .blue
                nextID += 1
                units.append(m)
            }
        }
    }

    private func respawnChampions() {
        for i in units.indices where units[i].kind == .champion && units[i].dead && time >= units[i].respawnAt {
            units[i].dead = false
            units[i].hp = units[i].maxHP
            units[i].pos = Self.fountain(units[i].team)
            units[i].targetID = nil
            units[i].moveTarget = nil
            units[i].retreating = false
            rings.append(ArenaRing(pos: units[i].pos, radius: 18, life: 0.5, maxLife: 0.5, moveType: nil))
        }
    }

    private func stepToward(_ u: inout ArenaUnit, _ p: CGPoint, dt: TimeInterval) -> Bool {
        let dx = p.x - u.pos.x, dy = p.y - u.pos.y
        let d = hypot(dx, dy)
        let step = u.speed * CGFloat(dt)
        u.moving = true
        if abs(dx) > 0.5 { u.facingRight = dx > 0 }
        if d <= step {
            u.pos = Self.clampWalkable(p)
            return true
        }
        u.pos = Self.clampWalkable(CGPoint(x: u.pos.x + dx / d * step, y: u.pos.y + dy / d * step))
        return false
    }

    private func updateUnit(_ i: Int, dt: TimeInterval) {
        var u = units[i]
        guard !u.dead else { return }
        u.attackTimer = max(0, u.attackTimer - dt)
        u.hitFlash = max(0, u.hitFlash - dt)
        u.attackFlash = max(0, u.attackFlash - dt)
        u.moving = false

        if u.kind == .champion {
            for s in u.skills.indices { u.skills[s].remaining = max(0, u.skills[s].remaining - dt) }
            if u.shieldUntil < time { u.shield = 0 }
            if var dash = u.dash {
                let arrived = stepToward(&u, dash.to, dt: dt * 6)   // a dash covers ground ~6× walking speed
                let hits = units.filter {
                    !$0.isStructure && isValidTarget($0, for: u.team) && !dash.hit.contains($0.id) && dist($0.pos, u.pos) < 12 + $0.radius
                }.map(\.id)
                dash.hit.formUnion(hits)
                u.dash = arrived ? nil : dash
                units[i] = u
                for h in hits { if let hi = index(of: h) { applyDamage(to: hi, dash.damage, from: u.id, moveType: dash.moveType) } }
                if arrived { rings.append(ArenaRing(pos: u.pos, radius: 16, life: 0.3, maxLife: 0.3, moveType: dash.moveType)) }
                return
            }
            if let at = u.recallAt {
                if time >= at {
                    u.pos = Self.fountain(u.team)
                    u.recallAt = nil
                    rings.append(ArenaRing(pos: u.pos, radius: 18, life: 0.5, maxLife: 0.5, moveType: nil))
                }
                units[i] = u
                return
            }
        }
        if u.isStructure {
            units[i] = u
            if u.kind == .tower { towerAttack(i) }
            return
        }

        if u.isMinion {
            u.targetID = minionTarget(u)
        } else if u.targetID == nil, u.moveTarget == nil {
            u.targetID = nearestEnemy(to: u.pos, team: u.team, within: u.range + 8)
        }
        if let t = u.targetID, let ti = index(of: t), isValidTarget(units[ti], for: u.team) {
            let target = units[ti]
            let gap = dist(u.pos, target.pos) - target.radius
            if gap <= u.range {
                if abs(target.pos.x - u.pos.x) > 0.5 { u.facingRight = target.pos.x > u.pos.x }
                if u.attackTimer <= 0 {
                    u.attackTimer = u.attackInterval
                    u.attackFlash = 0.15
                    units[i] = u
                    basicAttack(from: i, at: ti)
                    return
                }
            } else {
                _ = stepToward(&u, target.pos, dt: dt)
            }
        } else {
            if u.kind == .champion { u.targetID = nil }
            if let m = u.moveTarget {
                if stepToward(&u, m, dt: dt) { u.moveTarget = nil }
            } else if u.isMinion {
                let goal = CGPoint(x: u.team == .blue ? 900 : 100, y: Self.laneY + u.laneOffset)
                _ = stepToward(&u, goal, dt: dt)
            }
        }
        units[i] = u
    }

    private func nearestEnemy(to p: CGPoint, team: ArenaTeam, within r: CGFloat, includeStructures: Bool = true) -> Int? {
        var best: (id: Int, gap: CGFloat)?
        for t in units where isValidTarget(t, for: team) && (includeStructures || !t.isStructure) {
            let gap = dist(t.pos, p) - t.radius
            if gap <= r, gap < (best?.gap ?? .greatestFiniteMagnitude) { best = (t.id, gap) }
        }
        return best?.id
    }

    private func minionTarget(_ u: ArenaUnit) -> Int? {
        if let t = u.targetID, let tu = unit(t), isValidTarget(tu, for: u.team), dist(tu.pos, u.pos) - tu.radius < 90 { return t }
        // Minions fight minions first; champions and structures when nothing else is near.
        if let m = nearestEnemy(to: u.pos, team: u.team, within: 60, includeStructures: false),
           let mu = unit(m), mu.isMinion { return m }
        return nearestEnemy(to: u.pos, team: u.team, within: 60)
    }

    private func basicAttack(from i: Int, at ti: Int) {
        let a = units[i]
        if a.range > 30 {
            let t = units[ti]
            let dx = t.pos.x - a.pos.x, dy = t.pos.y - a.pos.y, d = max(0.001, hypot(dx, dy))
            projectiles.append(ArenaProjectile(pos: CGPoint(x: a.pos.x, y: a.pos.y - 6), vel: CGPoint(x: dx / d * 200, y: dy / d * 200),
                                               team: a.team, ownerID: a.id, damage: a.attackDamage, moveType: nil, radius: 3,
                                               life: 2, homingID: t.id, size: 2))
        } else {
            applyDamage(to: ti, a.attackDamage, from: a.id, moveType: nil)
        }
    }

    private func towerAttack(_ i: Int) {
        let tower = units[i]
        guard tower.attackTimer <= 0 else { return }
        func inRange(_ id: Int?) -> ArenaUnit? {
            guard let id, let t = unit(id), isValidTarget(t, for: tower.team), dist(t.pos, tower.pos) - t.radius <= tower.range
            else { return nil }
            return t
        }
        var target = tower.aggroUntil > time ? inRange(tower.aggroID) : nil
        if target == nil { target = inRange(tower.targetID) }
        if target == nil {
            let near = units.filter { isValidTarget($0, for: tower.team) && !$0.isStructure && dist($0.pos, tower.pos) - $0.radius <= tower.range }
            target = near.filter(\.isMinion).min { dist($0.pos, tower.pos) < dist($1.pos, tower.pos) }
                ?? near.min { dist($0.pos, tower.pos) < dist($1.pos, tower.pos) }
        }
        guard let t = target else { units[i].targetID = nil; return }
        units[i].targetID = t.id
        units[i].attackTimer = tower.attackInterval
        units[i].attackFlash = 0.2
        let damage: CGFloat = t.kind == .champion ? 150 + CGFloat(time / 60) * 12 : 95
        let dx = t.pos.x - tower.pos.x, dy = t.pos.y - tower.pos.y, d = max(0.001, hypot(dx, dy))
        projectiles.append(ArenaProjectile(pos: CGPoint(x: tower.pos.x, y: tower.pos.y - 26), vel: CGPoint(x: dx / d * 230, y: dy / d * 230),
                                           team: tower.team, ownerID: tower.id, damage: damage, moveType: nil, radius: 4,
                                           life: 2, homingID: t.id, size: 3))
    }

    private func updateProjectiles(_ dt: TimeInterval) {
        var keep: [ArenaProjectile] = []
        let current = projectiles
        projectiles = []
        for var p in current {
            p.life -= dt
            if let h = p.homingID {
                guard let ti = index(of: h), !units[ti].dead else { continue }
                let t = units[ti]
                let dx = t.pos.x - p.pos.x, dy = t.pos.y - 4 - p.pos.y, d = hypot(dx, dy)
                let speed = hypot(p.vel.x, p.vel.y)
                if d <= speed * CGFloat(dt) + t.radius {
                    applyDamage(to: ti, p.damage, from: p.ownerID, moveType: p.moveType)
                    continue
                }
                p.vel = CGPoint(x: dx / d * speed, y: dy / d * speed)
                p.pos.x += p.vel.x * CGFloat(dt)
                p.pos.y += p.vel.y * CGFloat(dt)
            } else {
                p.pos.x += p.vel.x * CGFloat(dt)
                p.pos.y += p.vel.y * CGFloat(dt)
                let foot = CGPoint(x: p.pos.x, y: p.pos.y + 6)
                if let victim = units.firstIndex(where: {
                    !$0.isStructure && isValidTarget($0, for: p.team) && dist($0.pos, foot) < p.radius + $0.radius + 2
                }) {
                    rings.append(ArenaRing(pos: units[victim].pos, radius: 12, life: 0.3, maxLife: 0.3, moveType: p.moveType))
                    applyDamage(to: victim, p.damage, from: p.ownerID, moveType: p.moveType)
                    continue
                }
            }
            if p.life > 0 { keep.append(p) }
        }
        projectiles += keep
    }

    private func updateBlasts() {
        let due = blasts.filter { time >= $0.detonateAt }
        blasts.removeAll { time >= $0.detonateAt }
        for b in due {
            rings.append(ArenaRing(pos: b.pos, radius: b.radius, life: 0.4, maxLife: 0.4, moveType: b.moveType))
            let victims = units.filter {
                !$0.isStructure && isValidTarget($0, for: b.team) && dist($0.pos, b.pos) < b.radius + $0.radius
            }.map(\.id)
            for v in victims { if let vi = index(of: v) { applyDamage(to: vi, b.damage, from: b.ownerID, moveType: b.moveType) } }
        }
    }

    private func fountains(_ dt: TimeInterval) {
        for i in units.indices where units[i].kind == .champion && !units[i].dead {
            let own = Self.fountain(units[i].team), enemy = Self.fountain(units[i].team.other)
            if dist(units[i].pos, own) < 40 {
                units[i].hp = min(units[i].maxHP, units[i].hp + units[i].maxHP * 0.2 * CGFloat(dt))
            }
            if dist(units[i].pos, enemy) < 44 {
                units[i].hp -= 500 * CGFloat(dt)
                if units[i].hp <= 0 { units[i].hp = 0; kill(i, by: -1) }
            }
        }
    }

    /// Soft bodies: mobile units push each other apart; structures push mobile units out.
    private func separate() {
        for a in units.indices where !units[a].dead {
            for b in units.indices where b > a && !units[b].dead {
                let sa = units[a].isStructure, sb = units[b].isStructure
                guard !(sa && sb) else { continue }
                let dx = units[b].pos.x - units[a].pos.x, dy = units[b].pos.y - units[a].pos.y
                let d = hypot(dx, dy), minD = units[a].radius + units[b].radius
                guard d < minD, d > 0.01 else { continue }
                let push = minD - d, nx = dx / d, ny = dy / d
                let shareA: CGFloat = sa ? 0 : (sb ? 1 : 0.5), shareB: CGFloat = sb ? 0 : (sa ? 1 : 0.5)
                units[a].pos = Self.clampWalkable(CGPoint(x: units[a].pos.x - nx * push * shareA, y: units[a].pos.y - ny * push * shareA))
                units[b].pos = Self.clampWalkable(CGPoint(x: units[b].pos.x + nx * push * shareB, y: units[b].pos.y + ny * push * shareB))
            }
        }
    }

    // MARK: damage

    private func applyDamage(to ti: Int, _ amount: CGFloat, from ownerID: Int, moveType: String?) {
        var t = units[ti]
        guard !t.dead else { return }
        var d = amount
        var style = ArenaFloater.Style.normal
        if t.kind == .champion {
            if let mt = moveType {
                let m = TypeChart.multiplier(mt, against: t.types)
                // Immunities still sting a little so no matchup is hopeless.
                let clamped = m == 0 ? 0.35 : min(max(m, 0.5), 2)
                d *= CGFloat(clamped)
                if clamped > 1.01 { style = .strong } else if clamped < 0.99 { style = .weak }
            }
            d /= t.guardFactor
        } else if t.isStructure {
            d *= 0.9
        }
        if t.shield > 0 {
            let absorbed = min(t.shield, d)
            t.shield -= absorbed
            d -= absorbed
        }
        t.hp -= d
        t.hitFlash = 0.12
        if t.isPlayer { style = .hurt }
        let attacker = unit(ownerID)
        if t.kind == .champion || attacker?.isPlayer == true || t.isPlayer {
            floaters.append(ArenaFloater(text: "\(Int(d.rounded()))", pos: CGPoint(x: t.pos.x, y: t.pos.y - 22), life: 0.8, style: style))
        }
        // Hitting a champion under its tower draws the tower's fire.
        if t.kind == .champion, let a = attacker, a.kind == .champion {
            for k in units.indices where units[k].kind == .tower && units[k].team == t.team && !units[k].dead
                && dist(units[k].pos, a.pos) < Self.towerRange + 8 {
                units[k].aggroID = a.id
                units[k].aggroUntil = time + 2.5
            }
        }
        units[ti] = t
        if t.hp <= 0 {
            units[ti].hp = 0
            kill(ti, by: ownerID)
        }
    }

    private func kill(_ ti: Int, by killerID: Int) {
        var t = units[ti]
        t.dead = true
        t.diedAt = time
        let killer = index(of: killerID)
        switch t.kind {
        case .champion:
            t.deaths += 1
            t.respawnAt = time + 6 + Double(t.level) * 2
            t.dash = nil
            t.recallAt = nil
            t.targetID = nil
            t.moveTarget = nil
            t.shield = 0
            units[ti] = t
            score[t.team.other.rawValue] += 1
            if let k = killer, units[k].kind == .champion {
                units[k].kills += 1
                feed.append(ArenaFeed(text: "\(units[k].name) → \(t.name) 처치!", at: time, team: units[k].team))
                grantXP(k, 140 + 20 * CGFloat(t.level))
            } else {
                feed.append(ArenaFeed(text: "\(t.name) 쓰러짐", at: time, team: t.team.other))
            }
        case .minion, .rangedMinion:
            units[ti] = t
            for k in units.indices where units[k].kind == .champion && !units[k].dead && units[k].team != t.team
                && dist(units[k].pos, t.pos) < 160 {
                grantXP(k, 30)
            }
        case .tower:
            units[ti] = t
            feed.append(ArenaFeed(text: "\(t.team == .blue ? "블루" : "레드") 포탑 파괴!", at: time, team: t.team.other))
            for k in units.indices where units[k].kind == .champion && !units[k].dead && units[k].team != t.team
                && dist(units[k].pos, t.pos) < 220 {
                grantXP(k, 100)
            }
        case .core:
            units[ti] = t
            winner = t.team.other
            feed.append(ArenaFeed(text: "\(t.team == .blue ? "레드" : "블루") 팀 승리!", at: time, team: t.team.other))
        }
    }

    private func grantXP(_ k: Int, _ amount: CGFloat) {
        guard units[k].level < Self.maxLevel else { return }
        units[k].xp += amount
        while units[k].level < Self.maxLevel, units[k].xp >= Self.xpNeeded(units[k].level) {
            units[k].xp -= Self.xpNeeded(units[k].level)
            units[k].level += 1
            let lv = CGFloat(units[k].level - 1)
            let oldMax = units[k].maxHP
            units[k].maxHP = units[k].baseHP * (1 + 0.09 * lv)
            units[k].hp += units[k].maxHP - oldMax
            units[k].attackDamage = units[k].baseAttack * (1 + 0.07 * lv)
            floaters.append(ArenaFloater(text: "LEVEL UP", pos: CGPoint(x: units[k].pos.x, y: units[k].pos.y - 30), life: 1.2, style: .gold))
            if units[k].isPlayer, units[k].level == 3 {
                feed.append(ArenaFeed(text: "궁극기(R) 해금!", at: time, team: nil))
            }
        }
    }

    // MARK: CPU champions

    private func enemyTower(covering p: CGPoint, team: ArenaTeam) -> ArenaUnit? {
        units.first { $0.kind == .tower && $0.team != team && !$0.dead && dist($0.pos, p) < Self.towerRange + 6 }
    }

    /// Diving a tower is only fine with allied minions soaking its shots.
    private func isSafe(_ p: CGPoint, team: ArenaTeam) -> Bool {
        guard let tower = enemyTower(covering: p, team: team) else { return true }
        return units.filter { $0.isMinion && !$0.dead && $0.team == team && dist($0.pos, tower.pos) < Self.towerRange }.count >= 2
    }

    private func laneFront(_ team: ArenaTeam, offset: CGFloat) -> CGPoint {
        let f = team.forward
        let minions = units.filter { $0.isMinion && !$0.dead && $0.team == team }
        let x: CGFloat
        if let front = minions.max(by: { $0.pos.x * f < $1.pos.x * f }) {
            x = front.pos.x - f * 18
        } else if let tower = units.filter({ $0.kind == .tower && $0.team == team && !$0.dead }).max(by: { $0.pos.x * f < $1.pos.x * f }) {
            x = tower.pos.x - f * 16
        } else {
            x = (team == .blue ? 100 : 900) + f * 30
        }
        return CGPoint(x: x, y: Self.laneY + offset)
    }

    private func think(_ id: Int) {
        guard let i = index(of: id) else { return }
        let u = units[i]
        guard u.dash == nil, u.recallAt == nil else { return }
        let home = Self.fountain(u.team)

        if u.hpRatio < 0.28 { units[i].retreating = true }
        if units[i].retreating {
            if u.hpRatio > 0.92 {
                units[i].retreating = false
            } else {
                let threatened = units.contains { $0.kind == .champion && isValidTarget($0, for: u.team) && dist($0.pos, u.pos) < 110 }
                if dist(u.pos, home) > 260, !threatened {
                    apply(.recall, for: id)
                } else if dist(u.pos, home) > 20 {
                    apply(.move(home), for: id)
                }
                return
            }
        }

        let champs = units.filter { $0.kind == .champion && isValidTarget($0, for: u.team) && dist($0.pos, u.pos) < 160 }
        if let c = champs.min(by: { $0.hpRatio < $1.hpRatio }) {
            let d = dist(c.pos, u.pos)
            // Lead the shot a little toward where the target is walking.
            let lead = c.moveTarget.map { mt -> CGPoint in
                let dx = mt.x - c.pos.x, dy = mt.y - c.pos.y, l = max(0.001, hypot(dx, dy))
                let ahead = min(l, c.speed * 0.4)
                return CGPoint(x: c.pos.x + dx / l * ahead, y: c.pos.y + dy / l * ahead)
            } ?? c.pos
            if u.skills[0].remaining <= 0, d < 145 {
                apply(.cast(slot: 0, aim: lead), for: id)
            } else if u.skills[1].remaining <= 0, d < 112 {
                apply(.cast(slot: 1, aim: lead), for: id)
            } else if u.level >= 3, u.skills[3].remaining <= 0, d < 48, u.hpRatio < 0.6 || c.hpRatio < 0.5 {
                apply(.cast(slot: 3, aim: c.pos), for: id)
            } else if u.skills[2].remaining <= 0, c.hpRatio < 0.35, d < 85, isSafe(c.pos, team: u.team) {
                apply(.cast(slot: 2, aim: c.pos), for: id)
            }
            if c.hpRatio < u.hpRatio + 0.1, d < 100, isSafe(c.pos, team: u.team) {
                apply(.attack(c.id), for: id)
                return
            }
        }
        // Farm minions near the front, poking a cluster with Q now and then.
        let minions = units.filter { $0.isMinion && isValidTarget($0, for: u.team) && dist($0.pos, u.pos) < 130 && isSafe($0.pos, team: u.team) }
        if let m = minions.min(by: { $0.hp < $1.hp }) {
            if u.skills[0].remaining <= 0, minions.count >= 3, rng.int(4) == 0 { apply(.cast(slot: 0, aim: m.pos), for: id) }
            if units[i].targetID != m.id { apply(.attack(m.id), for: id) }
            return
        }
        let structure = units.first { s in
            s.isStructure && isValidTarget(s, for: u.team) && dist(s.pos, u.pos) < 120
                && units.contains { $0.isMinion && !$0.dead && $0.team == u.team && dist($0.pos, s.pos) < Self.towerRange }
        }
        if let s = structure {
            if units[i].targetID != s.id { apply(.attack(s.id), for: id) }
            return
        }
        let front = laneFront(u.team, offset: u.laneOffset)
        if dist(front, u.pos) > 10 { apply(.move(front), for: id) }
    }
}

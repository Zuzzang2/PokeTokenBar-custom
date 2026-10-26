import CoreGraphics
import Foundation

// SPIKE: the 픽셀 모험 simulation. Players act through `RpgInput` (held movement, attack and skill
// presses, one-shot actions) so a lobby host can later feed remote players' inputs in the same way.
// Monsters of a map only live while someone is on it. Pixel coordinates, y down, positions are feet.

struct RpgInput {
    var move = CGVector.zero
    var attack = false
    var skill1 = false
    var skill2 = false
}

enum RpgAction {
    case interact, hpPotion, mpPotion, scroll
    case equip(String)
    case use(String)
    case buy(String)
    case sell(String)
}

struct RpgPlayer {
    let id: Int
    var name: String
    var cls: RpgClass
    var level = 1
    var xp = 0
    var gold = 0
    var hp: Double = 1
    var mp: Double = 1
    var inventory: [String: Int] = [:]
    var weapon: String
    var armor: String?
    var map: RpgMapID = .town
    var pos: CGPoint
    var facing = CGVector(dx: 0, dy: 1)
    var facingRight = true
    var moving = false
    var attackTimer = 0.0
    var skillTimers = [0.0, 0.0]
    var invulnerable = 0.0
    var hurtFlash = 0.0
    var dash: (to: CGPoint, hit: Set<Int>, damage: Double)?
    var dead = false
    var respawnAt = 0.0
    var lastHurt = -10.0
    var potionTimer = 0.0
    var playTime = 0.0

    var weaponItem: RpgItem? { RpgItems.item(weapon) }
    var armorItem: RpgItem? { armor.flatMap(RpgItems.item) }
    var element: RpgElement { weaponItem?.element ?? .base }
    var maxHP: Double { Double(cls.baseHP + cls.hpPerLevel * (level - 1)) }
    var maxMP: Double { Double(cls.baseMP + cls.mpPerLevel * (level - 1)) }
    var attack: Double { Double(cls.baseAttack) + cls.attackPerLevel * Double(level - 1) + Double(weaponItem?.attack ?? 0) }
    var defense: Double { Double(cls.baseDefense) + cls.defensePerLevel * Double(level - 1) + Double(armorItem?.defense ?? 0) }
    var attackInterval: Double { cls.attackInterval * (element == .wind ? 0.7 : 1) }
}

struct RpgMob {
    let id: Int
    let def: RpgMonsterDef
    var pos: CGPoint
    var home: CGPoint
    var hp: Double
    var targetID: Int?
    var aggroUntil = 0.0
    var attackTimer = 0.0
    var windup: Double?
    var hurtFlash = 0.0
    var knock = CGVector.zero
    var dead = false
    var diedAt = 0.0
    var respawnAt = 0.0
    var wanderTo: CGPoint?
    var nextWander = 0.0
    var facingRight = false
    var burnTicks = 0
    var burnDamage = 0.0
    var nextBurn = 0.0
    var slowUntil = 0.0
    var stunUntil = 0.0
    var phase = 0
    var phaseUntil = 0.0
    var jumpTarget: CGPoint?
    var airborne = false
    var lastHitBy: Int?

    var radius: CGFloat { def.behavior == .boss ? 14 : 6 }
    var flies: Bool { def.behavior == .flyer }
}

struct RpgShot {
    enum Kind { case arrow, orb, bigArrow, mobArrow, slimeBall }
    var pos: CGPoint
    var vel: CGVector
    let map: RpgMapID
    let fromPlayer: Bool
    let ownerID: Int
    let damage: Double
    let element: RpgElement
    let kind: Kind
    var life: Double
    var hit: Set<Int> = []
    var pierce: Bool { kind == .bigArrow }
}

struct RpgFX {
    enum Kind {
        case slash(angle: Double, radius: Double)
        case burst(radius: Double)
        case ice(radius: Double)
        case meteor(radius: Double)
        case chain([CGPoint])
        case spark(crit: Bool)
        case levelUp
        case telegraph(radius: Double, until: Double)
    }
    let kind: Kind
    let map: RpgMapID
    let pos: CGPoint
    let element: RpgElement
    let start: Double
    let duration: Double
}

struct RpgFloater {
    enum Style { case damage, crit, hurt, heal, gold, xp, info }
    let text: String
    let map: RpgMapID
    var pos: CGPoint
    var life: Double
    let style: Style
}

struct RpgDropped {
    let id: Int
    let map: RpgMapID
    let pos: CGPoint
    let gold: Int
    let item: String?
    let at: Double
}

final class RpgWorld {
    static let townSpawn = RpgTile(x: 15, y: 16)

    private(set) var maps: [RpgMapID: RpgMap] = [:]
    private(set) var players: [RpgPlayer] = []
    private(set) var mobs: [RpgMapID: [RpgMob]] = [:]
    private(set) var shots: [RpgShot] = []
    private(set) var fx: [RpgFX] = []
    private(set) var floaters: [RpgFloater] = []
    private(set) var drops: [RpgDropped] = []
    private(set) var toasts: [(text: String, at: Double)] = []
    private(set) var time = 0.0
    private(set) var shake = 0.0
    private var nextID = 1
    private var rng = KartRNG(seed: UInt64.random(in: 1...UInt64.max))

    init(player: RpgPlayer) {
        players = [player]
        _ = map(player.map)
        spawnMobsIfNeeded(player.map)
    }

    func map(_ id: RpgMapID) -> RpgMap {
        if let m = maps[id] { return m }
        let m = RpgMap(RpgMaps.def(id))
        maps[id] = m
        return m
    }

    func player(_ id: Int) -> RpgPlayer? { players.first { $0.id == id } }
    private func pIndex(_ id: Int) -> Int? { players.firstIndex { $0.id == id } }

    private func newID() -> Int { nextID += 1; return nextID }
    private func rand(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * Double(rng.int(10_000)) / 10_000 }
    private func dist(_ a: CGPoint, _ b: CGPoint) -> Double { Double(hypot(a.x - b.x, a.y - b.y)) }

    func toast(_ text: String) {
        toasts.append((text, time))
        if toasts.count > 4 { toasts.removeFirst() }
    }

    private func float(_ text: String, _ map: RpgMapID, _ p: CGPoint, _ style: RpgFloater.Style) {
        floaters.append(RpgFloater(text: text, map: map, pos: CGPoint(x: p.x, y: p.y - 18), life: style == .info ? 1.4 : 0.9, style: style))
    }

    private func effect(_ kind: RpgFX.Kind, _ map: RpgMapID, _ p: CGPoint, _ e: RpgElement, duration: Double = 0.3) {
        fx.append(RpgFX(kind: kind, map: map, pos: p, element: e, start: time, duration: duration))
    }

    // MARK: monsters

    private func spawnMobsIfNeeded(_ id: RpgMapID) {
        guard mobs[id] == nil else { return }
        let m = map(id)
        var list: [RpgMob] = []
        for spawn in m.def.monsters {
            for _ in 0..<spawn.count {
                let def = RpgMonsters.def(spawn.monster)
                let p = def.behavior == .boss ? CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2 - 24) : randomSpawn(m)
                list.append(RpgMob(id: newID(), def: def, pos: p, home: p, hp: Double(def.hp)))
            }
        }
        mobs[id] = list
    }

    private func randomSpawn(_ m: RpgMap) -> CGPoint {
        guard !m.spawnTiles.isEmpty else { return CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2) }
        return RpgMap.center(m.spawnTiles[rng.int(m.spawnTiles.count)])
    }

    // MARK: actions

    func perform(_ action: RpgAction, for id: Int) {
        guard let i = pIndex(id), !players[i].dead else { return }
        switch action {
        case .interact:
            if let portal = nearbyPortal(for: id) { travel(i, through: portal) }
        case .hpPotion:
            let pick = ["hp1", "hp0"].first { (players[i].inventory[$0] ?? 0) > 0 && (($0 == "hp1" && players[i].maxHP - players[i].hp > 90) || $0 == "hp0") }
                ?? ["hp0", "hp1"].first { (players[i].inventory[$0] ?? 0) > 0 }
            if let pick { use(pick, i) } else { toast("빨간 물약이 없어요") }
        case .mpPotion:
            if (players[i].inventory["mp0"] ?? 0) > 0 { use("mp0", i) } else { toast("파란 물약이 없어요") }
        case .scroll:
            if (players[i].inventory["scroll"] ?? 0) > 0 { use("scroll", i) } else { toast("귀환 주문서가 없어요") }
        case .use(let item):
            use(item, i)
        case .equip(let item):
            equip(item, i)
        case .buy(let item):
            guard let it = RpgItems.item(item), it.inShop else { return }
            guard players[i].gold >= it.price else { toast("골드가 부족해요"); return }
            players[i].gold -= it.price
            players[i].inventory[item, default: 0] += 1
            toast("\(it.name) 구매 (-\(it.price)G)")
        case .sell(let item):
            guard let it = RpgItems.item(item), let have = players[i].inventory[item], have > 0 else { return }
            players[i].inventory[item] = have - 1 == 0 ? nil : have - 1
            players[i].gold += it.sellPrice
            toast("\(it.name) 판매 (+\(it.sellPrice)G)")
        }
    }

    private func use(_ item: String, _ i: Int) {
        guard let it = RpgItems.item(item), (players[i].inventory[item] ?? 0) > 0 else { return }
        switch it.kind {
        case .potionHP, .potionMP:
            guard players[i].potionTimer <= 0 else { return }
            players[i].potionTimer = 0.6
            if it.kind == .potionHP {
                players[i].hp = min(players[i].maxHP, players[i].hp + Double(it.heal))
                float("+\(it.heal)", players[i].map, players[i].pos, .heal)
            } else {
                players[i].mp = min(players[i].maxMP, players[i].mp + Double(it.heal))
                float("+\(it.heal) MP", players[i].map, players[i].pos, .heal)
            }
        case .scroll:
            moveToTown(i)
            toast("마을로 귀환했어요")
        case .weapon, .armor:
            equip(item, i)
            return
        }
        consume(item, i)
    }

    private func consume(_ item: String, _ i: Int) {
        let left = (players[i].inventory[item] ?? 0) - 1
        players[i].inventory[item] = left > 0 ? left : nil
    }

    private func equip(_ item: String, _ i: Int) {
        guard let it = RpgItems.item(item), (players[i].inventory[item] ?? 0) > 0 else { return }
        switch it.kind {
        case .weapon(let cls):
            guard cls == players[i].cls else { toast("\(cls.name) 전용 무기예요"); return }
            let old = players[i].weapon
            consume(item, i)
            players[i].inventory[old, default: 0] += 1
            players[i].weapon = item
            toast("\(it.name) 장착!")
        case .armor:
            if let old = players[i].armor { players[i].inventory[old, default: 0] += 1 }
            consume(item, i)
            players[i].armor = item
            toast("\(it.name) 장착!")
        default:
            use(item, i)
        }
    }

    func nearbyPortal(for id: Int) -> RpgPortal? {
        guard let p = player(id) else { return nil }
        return map(p.map).def.portals.first { dist(RpgMap.center($0.at), p.pos) < 16 }
    }

    func nearbyShop(for id: Int) -> RpgShop? {
        guard let p = player(id), p.map == .town else { return nil }
        return map(.town).buildings.first { dist($0.door, p.pos) < 22 }?.shop
    }

    private func travel(_ i: Int, through portal: RpgPortal) {
        guard players[i].level >= portal.minLevel else {
            toast("강한 기운이 느껴진다… (Lv\(portal.minLevel) 이상)")
            return
        }
        let from = players[i].map
        players[i].map = portal.to
        players[i].pos = RpgMap.center(portal.arrive)
        players[i].dash = nil
        spawnMobsIfNeeded(portal.to)
        leaveMapIfEmpty(from)
        let def = RpgMaps.def(portal.to)
        toast("\(def.name) — \(def.levelText)")
    }

    private func moveToTown(_ i: Int) {
        let from = players[i].map
        players[i].map = .town
        players[i].pos = RpgMap.center(Self.townSpawn)
        players[i].dash = nil
        leaveMapIfEmpty(from)
    }

    /// Nobody left on a map: the boss heals, monsters forget their targets.
    private func leaveMapIfEmpty(_ id: RpgMapID) {
        guard !players.contains(where: { $0.map == id }), var list = mobs[id] else { return }
        for k in list.indices {
            list[k].targetID = nil
            if !list[k].dead { list[k].hp = Double(list[k].def.hp); list[k].pos = list[k].home; list[k].phase = 0; list[k].airborne = false }
        }
        mobs[id] = list
    }

    // MARK: step

    func step(_ dt: Double, inputs: [Int: RpgInput]) {
        time += dt
        shake = max(0, shake - dt * 8)
        for i in players.indices { stepPlayer(i, dt, inputs[players[i].id] ?? RpgInput()) }
        for mapID in Set(players.map(\.map)) { stepMobs(mapID, dt) }
        stepShots(dt)
        pickups()
        for k in floaters.indices { floaters[k].life -= dt; floaters[k].pos.y -= CGFloat(dt * 18) }
        floaters.removeAll { $0.life <= 0 }
        fx.removeAll { time - $0.start > $0.duration }
        toasts.removeAll { time - $0.at > 3.5 }
        drops.removeAll { time - $0.at > 90 }
    }

    private func stepPlayer(_ i: Int, _ dt: Double, _ input: RpgInput) {
        var p = players[i]
        p.playTime += dt
        p.attackTimer = max(0, p.attackTimer - dt)
        p.skillTimers = p.skillTimers.map { max(0, $0 - dt) }
        p.invulnerable = max(0, p.invulnerable - dt)
        p.hurtFlash = max(0, p.hurtFlash - dt)
        p.potionTimer = max(0, p.potionTimer - dt)
        if p.dead {
            if time >= p.respawnAt {
                p.dead = false
                p.hp = p.maxHP
                p.mp = p.maxMP
                players[i] = p
                moveToTown(i)
                toast("마을에서 부활했어요")
            } else {
                players[i] = p
            }
            return
        }
        // Regeneration when out of combat, much faster in town.
        if time - p.lastHurt > 5 {
            let k = p.map == .town ? 0.12 : 0.015
            p.hp = min(p.maxHP, p.hp + p.maxHP * k * dt)
            p.mp = min(p.maxMP, p.mp + p.maxMP * k * 1.4 * dt)
        }
        let m = map(p.map)
        if let dash = p.dash {
            let dx = Double(dash.to.x - p.pos.x), dy = Double(dash.to.y - p.pos.y), d = hypot(dx, dy)
            let step = 420 * dt
            let next = d <= step ? dash.to : CGPoint(x: p.pos.x + CGFloat(dx / d * step), y: p.pos.y + CGFloat(dy / d * step))
            let blocked = !m.canStand(next)
            if !blocked { p.pos = next }
            players[i] = p
            var hit = dash.hit
            for v in mobIDs(near: p.pos, radius: 16, map: p.map) where !hit.contains(v) {
                hit.insert(v)
                damageMob(v, map: p.map, base: dash.damage, by: p.id, element: p.element, skill: true)
            }
            players[i].dash = (d <= step || blocked) ? nil : (dash.to, hit, dash.damage)
            return
        }
        let mv = input.move
        let len = hypot(mv.dx, mv.dy)
        p.moving = len > 0.01
        if p.moving {
            let dir = CGVector(dx: mv.dx / len, dy: mv.dy / len)
            p.facing = dir
            if abs(dir.dx) > 0.2 { p.facingRight = dir.dx > 0 }
            let step = CGFloat(p.cls.speed * dt)
            let nx = CGPoint(x: p.pos.x + dir.dx * step, y: p.pos.y)
            if m.canStand(nx) { p.pos = nx }
            let ny = CGPoint(x: p.pos.x, y: p.pos.y + dir.dy * step)
            if m.canStand(ny) { p.pos = ny }
        }
        players[i] = p
        if input.attack, players[i].attackTimer <= 0 { basicAttack(i) }
        if input.skill1 { castSkill(i, 0) }
        if input.skill2 { castSkill(i, 1) }
    }

    private func facingAngle(_ p: RpgPlayer) -> Double { Double(atan2(p.facing.dy, p.facing.dx)) }

    private func basicAttack(_ i: Int) {
        let p = players[i]
        players[i].attackTimer = p.attackInterval
        let angle = facingAngle(p)
        switch p.cls {
        case .warrior:
            let center = CGPoint(x: p.pos.x, y: p.pos.y - 6)
            effect(.slash(angle: angle, radius: 11), p.map, center, p.element, duration: 0.3)
            for v in mobIDs(inArcOf: p, range: 26, cosLimit: 0.2) {
                damageMob(v, map: p.map, base: p.attack, by: p.id, element: p.element, skill: false)
            }
        case .archer:
            fire(from: p, angle: angle, kind: .arrow, damage: p.attack, speed: 230, range: 170)
        case .mage:
            fire(from: p, angle: angle, kind: .orb, damage: p.attack * 1.15, speed: 170, range: 140)
        }
    }

    private func fire(from p: RpgPlayer, angle: Double, kind: RpgShot.Kind, damage: Double, speed: Double, range: Double) {
        let v = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        shots.append(RpgShot(pos: CGPoint(x: p.pos.x + CGFloat(cos(angle) * 6), y: p.pos.y - 7 + CGFloat(sin(angle) * 6)), vel: v, map: p.map,
                             fromPlayer: true, ownerID: p.id, damage: damage, element: p.element, kind: kind, life: range / speed))
    }

    private func castSkill(_ i: Int, _ slot: Int) {
        let p = players[i]
        guard p.skillTimers[slot] <= 0 else { return }
        let cost = Double(p.cls.skillCost[slot])
        guard p.mp >= cost else { toast("MP가 부족해요"); return }
        players[i].mp -= cost
        players[i].skillTimers[slot] = p.cls.skillCooldown[slot]
        let angle = facingAngle(p)
        let e = p.element
        switch (p.cls, slot) {
        case (.warrior, 0):
            let c = CGPoint(x: p.pos.x, y: p.pos.y - 4)
            effect(.burst(radius: 30), p.map, c, e, duration: 0.3)
            effect(.slash(angle: angle, radius: 16), p.map, c, e)
            effect(.slash(angle: angle + .pi, radius: 16), p.map, c, e)
            for v in mobIDs(near: p.pos, radius: 32, map: p.map) { damageMob(v, map: p.map, base: p.attack * 1.8, by: p.id, element: e, skill: true) }
        case (.warrior, 1):
            var to = p.pos
            for s in stride(from: 6.0, through: 76, by: 6) {
                let c = CGPoint(x: p.pos.x + CGFloat(cos(angle) * s), y: p.pos.y + CGFloat(sin(angle) * s))
                if map(p.map).canStand(c) { to = c } else { break }
            }
            players[i].dash = (to, [], p.attack * 2.0)
            players[i].invulnerable = 0.3
            effect(.slash(angle: angle, radius: 13), p.map, CGPoint(x: to.x, y: to.y - 6), e)
        case (.archer, 0):
            for d in [-0.26, 0.0, 0.26] { fire(from: p, angle: angle + d, kind: .arrow, damage: p.attack * 0.95, speed: 240, range: 170) }
        case (.archer, 1):
            fire(from: p, angle: angle, kind: .bigArrow, damage: p.attack * 2.6, speed: 320, range: 230)
        case (.mage, 0):
            let target = CGPoint(x: p.pos.x + CGFloat(cos(angle) * 56), y: p.pos.y + CGFloat(sin(angle) * 56))
            mageBlast(at: target, p)
        case (.mage, 1):
            var points = [CGPoint(x: p.pos.x, y: p.pos.y - 8)]
            var used: Set<Int> = []
            var from = p.pos
            for _ in 0..<4 {
                guard let next = (mobs[p.map] ?? []).filter({ !$0.dead && !$0.airborne && !used.contains($0.id) && dist($0.pos, from) < 95 })
                        .min(by: { dist($0.pos, from) < dist($1.pos, from) }) else { break }
                used.insert(next.id)
                points.append(CGPoint(x: next.pos.x, y: next.pos.y - 6))
                from = next.pos
                damageMob(next.id, map: p.map, base: p.attack * 1.7, by: p.id, element: e == .base ? .thunder : e, skill: true)
            }
            if points.count > 1 { effect(.chain(points), p.map, p.pos, e == .base ? .thunder : e, duration: 0.35) }
            else { toast("주변에 적이 없어요"); players[i].mp += cost; players[i].skillTimers[slot] = 0 }
        default: break
        }
    }

    private func mageBlast(at target: CGPoint, _ p: RpgPlayer) {
        let e = p.element
        switch e {
        case .fire:
            effect(.burst(radius: 30), p.map, target, .fire, duration: 0.35)
            hitArea(target, 32, p, p.attack * 2.4, .fire)
        case .ice:
            effect(.ice(radius: 30), p.map, target, .ice, duration: 0.4)
            hitArea(target, 32, p, p.attack * 2.0, .ice)
        case .thunder:
            effect(.burst(radius: 28), p.map, target, .thunder, duration: 0.3)
            effect(.chain([CGPoint(x: target.x + 6, y: target.y - 60), target]), p.map, target, .thunder, duration: 0.25)
            hitArea(target, 30, p, p.attack * 2.2, .thunder)
        case .cosmic:
            effect(.meteor(radius: 38), p.map, target, .cosmic, duration: 0.45)
            hitArea(target, 40, p, p.attack * 3.0, .cosmic)
            shake = max(shake, 1.2)
        default:
            effect(.burst(radius: 28), p.map, target, e, duration: 0.3)
            hitArea(target, 30, p, p.attack * 2.2, e)
        }
    }

    private func hitArea(_ c: CGPoint, _ r: Double, _ p: RpgPlayer, _ dmg: Double, _ e: RpgElement) {
        for v in mobIDs(near: c, radius: r, map: p.map) { damageMob(v, map: p.map, base: dmg, by: p.id, element: e, skill: true) }
    }

    private func mobIDs(near c: CGPoint, radius: Double, map: RpgMapID) -> [Int] {
        (mobs[map] ?? []).filter { !$0.dead && !$0.airborne && dist($0.pos, c) < radius + Double($0.radius) }.map(\.id)
    }

    private func mobIDs(inArcOf p: RpgPlayer, range: Double, cosLimit: Double) -> [Int] {
        (mobs[p.map] ?? []).filter { m in
            guard !m.dead, !m.airborne else { return false }
            let dx = Double(m.pos.x - p.pos.x), dy = Double(m.pos.y - p.pos.y), d = hypot(dx, dy)
            guard d < range + Double(m.radius) else { return false }
            if d < 6 { return true }
            return (dx * Double(p.facing.dx) + dy * Double(p.facing.dy)) / d > cosLimit
        }.map(\.id)
    }

    // MARK: damage

    private func damageMob(_ id: Int, map: RpgMapID, base: Double, by playerID: Int, element: RpgElement, skill: Bool, splash: Bool = false) {
        guard var list = mobs[map], let k = list.firstIndex(where: { $0.id == id }), !list[k].dead, !list[k].airborne,
              let pi = pIndex(playerID) else { return }
        let p = players[pi]
        var m = list[k]
        let crit = !splash && Double(rng.int(1000)) / 1000 < p.cls.critChance
        var dmg = max(1, base - Double(m.def.defense) * 0.6) * rand(0.9, 1.1)
        if crit { dmg *= 1.7 }
        m.hp -= dmg
        m.hurtFlash = 0.12
        m.lastHitBy = playerID
        if m.def.behavior != .boss {
            let dx = Double(m.pos.x - p.pos.x), dy = Double(m.pos.y - p.pos.y), d = max(1, hypot(dx, dy))
            m.knock = CGVector(dx: dx / d * (skill ? 140 : 90), dy: dy / d * (skill ? 140 : 90))
        }
        m.targetID = playerID
        m.aggroUntil = time + 8
        // Weapon element riders.
        switch element {
        case .fire: m.burnTicks = 3; m.burnDamage = dmg * 0.15; m.nextBurn = time + 0.6
        case .ice: m.slowUntil = time + 1.8
        case .thunder where rng.int(100) < 18: m.stunUntil = time + 0.7
        default: break
        }
        list[k] = m
        mobs[map] = list
        float(crit ? "\(Int(dmg))!" : "\(Int(dmg))", map, m.pos, crit ? .crit : .damage)
        effect(.spark(crit: crit), map, CGPoint(x: m.pos.x, y: m.pos.y - 6), element, duration: 0.2)
        if crit { shake = max(shake, 0.5) }
        if element == .holy, !splash {
            for v in mobIDs(near: m.pos, radius: 20, map: map) where v != id {
                damageMob(v, map: map, base: base * 0.4, by: playerID, element: .base, skill: skill, splash: true)
            }
        }
        if element == .cosmic, !splash, !skill, rng.int(100) < 10 {
            effect(.meteor(radius: 20), map, m.pos, .cosmic, duration: 0.45)
            for v in mobIDs(near: m.pos, radius: 22, map: map) { damageMob(v, map: map, base: base * 0.8, by: playerID, element: .base, skill: true, splash: true) }
        }
        if let idx = mobs[map]?.firstIndex(where: { $0.id == id }), let mm = mobs[map]?[idx], mm.hp <= 0, !mm.dead { killMob(id, map: map, by: playerID) }
    }

    private func killMob(_ id: Int, map: RpgMapID, by playerID: Int) {
        guard var list = mobs[map], let k = list.firstIndex(where: { $0.id == id }) else { return }
        var m = list[k]
        m.dead = true
        m.diedAt = time
        m.burnTicks = 0
        if !m.respawnAt.isInfinite { m.respawnAt = time + (m.def.behavior == .boss ? 60 : (m.def.behavior == .coward ? 30 : 10)) }
        list[k] = m
        mobs[map] = list
        if m.def.behavior == .boss {
            effect(.burst(radius: 50), map, m.pos, .holy, duration: 0.6)
            shake = 2
            toast("슬라임 킹을 쓰러뜨렸다!")
        }
        let gold = Int.random(in: m.def.gold)
        drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(9) - 4), y: m.pos.y + CGFloat(rng.int(5) - 2)), gold: gold, item: nil, at: time))
        for d in m.def.drops where Double(rng.int(10_000)) / 10_000 < d.chance {
            drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(21) - 10), y: m.pos.y + CGFloat(rng.int(11) - 5)),
                                    gold: 0, item: d.item, at: time))
        }
        grantXP(playerID, m.def.xp)
    }

    private func grantXP(_ playerID: Int, _ amount: Int) {
        guard let i = pIndex(playerID) else { return }
        float("+\(amount) XP", players[i].map, CGPoint(x: players[i].pos.x, y: players[i].pos.y - 10), .xp)
        guard players[i].level < RpgMaps.maxLevel else { return }
        players[i].xp += amount
        while players[i].level < RpgMaps.maxLevel, players[i].xp >= RpgMaps.xpNeeded(players[i].level) {
            players[i].xp -= RpgMaps.xpNeeded(players[i].level)
            players[i].level += 1
            players[i].hp = players[i].maxHP
            players[i].mp = players[i].maxMP
            effect(.levelUp, players[i].map, players[i].pos, .holy, duration: 1.0)
            toast("레벨 업! Lv\(players[i].level)")
            if players[i].level == 12 { toast("보스방이 열렸어요 (동굴 2층 북쪽)") }
        }
    }

    private func hurtPlayer(_ i: Int, _ raw: Double, from p: CGPoint) {
        guard !players[i].dead, players[i].invulnerable <= 0, players[i].dash == nil else { return }
        let dmg = max(1, raw - players[i].defense * 0.5) * rand(0.9, 1.1)
        players[i].hp -= dmg
        players[i].invulnerable = 0.55
        players[i].hurtFlash = 0.2
        players[i].lastHurt = time
        float("-\(Int(dmg))", players[i].map, players[i].pos, .hurt)
        shake = max(shake, 0.6)
        // A small shove away from the hit.
        let dx = Double(players[i].pos.x - p.x), dy = Double(players[i].pos.y - p.y), d = max(1, hypot(dx, dy))
        let shove = CGPoint(x: players[i].pos.x + CGFloat(dx / d * 6), y: players[i].pos.y + CGFloat(dy / d * 6))
        if map(players[i].map).canStand(shove) { players[i].pos = shove }
        if players[i].hp <= 0 {
            players[i].hp = 0
            players[i].dead = true
            players[i].respawnAt = time + 3
            let lost = players[i].gold / 10
            players[i].gold -= lost
            toast(lost > 0 ? "쓰러졌다… 골드 \(lost)G를 잃었어요" : "쓰러졌다…")
        }
    }

    // MARK: monster AI

    private func stepMobs(_ mapID: RpgMapID, _ dt: Double) {
        guard var list = mobs[mapID] else { return }
        let m = map(mapID)
        let here = players.indices.filter { players[$0].map == mapID && !players[$0].dead }
        var spawned: [RpgMob] = []
        for k in list.indices {
            var mob = list[k]
            if mob.dead {
                if time >= mob.respawnAt {
                    mob = RpgMob(id: mob.id, def: mob.def, pos: mob.def.behavior == .boss ? mob.home : randomSpawn(m), home: mob.home, hp: Double(mob.def.hp))
                    if mob.def.behavior != .boss { mob.home = mob.pos }
                }
                list[k] = mob
                continue
            }
            mob.hurtFlash = max(0, mob.hurtFlash - dt)
            mob.attackTimer = max(0, mob.attackTimer - dt)
            if mob.burnTicks > 0, time >= mob.nextBurn {
                mob.burnTicks -= 1
                mob.nextBurn = time + 0.6
                mob.hp -= mob.burnDamage
                floaters.append(RpgFloater(text: "\(Int(mob.burnDamage))", map: mapID, pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 16), life: 0.6, style: .crit))
                if mob.hp <= 0 {
                    list[k] = mob
                    mobs[mapID] = list
                    killMob(mob.id, map: mapID, by: mob.lastHitBy ?? players.first?.id ?? 0)
                    list = mobs[mapID] ?? list
                    continue
                }
            }
            // Knockback slides first.
            if hypot(mob.knock.dx, mob.knock.dy) > 1 {
                let np = CGPoint(x: mob.pos.x + mob.knock.dx * CGFloat(dt), y: mob.pos.y + mob.knock.dy * CGFloat(dt))
                if mob.flies || m.canStand(np) { mob.pos = np }
                mob.knock = CGVector(dx: mob.knock.dx * CGFloat(max(0, 1 - dt * 10)), dy: mob.knock.dy * CGFloat(max(0, 1 - dt * 10)))
            }
            if time < mob.stunUntil { list[k] = mob; continue }
            let speedK = time < mob.slowUntil ? 0.5 : 1.0
            // Nearest player in reach.
            let nearest = here.min { dist(players[$0].pos, mob.pos) < dist(players[$1].pos, mob.pos) }
            if let t = mob.targetID, !here.contains(where: { players[$0].id == t }) { mob.targetID = nil }
            if mob.targetID == nil, let n = nearest {
                let d = dist(players[n].pos, mob.pos)
                let aggro: Double = switch mob.def.behavior {
                case .aggressive: 80
                case .flyer: 90
                case .ranged: 120
                case .boss: 200
                default: 0
                }
                if d < aggro { mob.targetID = players[n].id; mob.aggroUntil = time + 8 }
            }
            if mob.targetID != nil, time > mob.aggroUntil, mob.def.behavior == .passive { mob.targetID = nil }
            if dist(mob.pos, mob.home) > 260, mob.def.behavior != .boss { mob.targetID = nil; mob.wanderTo = mob.home }

            let target = mob.targetID.flatMap { id in here.first { players[$0].id == id } }
            func walk(to goal: CGPoint, _ speed: Double) {
                let dx = Double(goal.x - mob.pos.x), dy = Double(goal.y - mob.pos.y), d = hypot(dx, dy)
                guard d > 1 else { return }
                let s = min(d, speed * speedK * dt)
                if abs(dx) > 0.5 { mob.facingRight = dx > 0 }
                let nx = CGPoint(x: mob.pos.x + CGFloat(dx / d * s), y: mob.pos.y)
                if mob.flies || m.canStand(nx) { mob.pos.x = nx.x }
                let ny = CGPoint(x: mob.pos.x, y: mob.pos.y + CGFloat(dy / d * s))
                if mob.flies || m.canStand(ny) { mob.pos.y = ny.y }
                mob.pos.x = min(max(mob.pos.x, 8), m.pixelSize.width - 8)
                mob.pos.y = min(max(mob.pos.y, 8), m.pixelSize.height - 8)
            }

            switch mob.def.behavior {
            case .boss:
                if let t = target ?? nearest { bossThink(&mob, players[t], dt, mapID, &spawned) }
            case .coward:
                if let n = nearest, dist(players[n].pos, mob.pos) < 90 {
                    let away = CGPoint(x: mob.pos.x * 2 - players[n].pos.x, y: mob.pos.y * 2 - players[n].pos.y)
                    walk(to: away, mob.def.speed)
                } else if let w = wanderGoal(&mob) { walk(to: w, mob.def.speed * 0.45) }
            case .ranged:
                if let t = target {
                    let d = dist(players[t].pos, mob.pos)
                    if d < 60 { walk(to: CGPoint(x: mob.pos.x * 2 - players[t].pos.x, y: mob.pos.y * 2 - players[t].pos.y), mob.def.speed) }
                    else if d > 120 { walk(to: players[t].pos, mob.def.speed) }
                    mob.facingRight = players[t].pos.x > mob.pos.x
                    if mob.attackTimer <= 0, d < 150 {
                        mob.attackTimer = 1.8
                        let dx = Double(players[t].pos.x - mob.pos.x), dy = Double(players[t].pos.y - mob.pos.y), l = max(1, hypot(dx, dy))
                        shots.append(RpgShot(pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 6), vel: CGVector(dx: dx / l * 150, dy: dy / l * 150), map: mapID,
                                             fromPlayer: false, ownerID: mob.id, damage: Double(mob.def.attack), element: .base, kind: .mobArrow, life: 1.4))
                    }
                } else if let w = wanderGoal(&mob) { walk(to: w, mob.def.speed * 0.45) }
            default:
                if let t = target {
                    let tp = players[t].pos
                    let d = dist(tp, mob.pos)
                    if let w = mob.windup {
                        mob.windup = w - dt
                        if w - dt <= 0 {
                            mob.windup = nil
                            mob.attackTimer = 1.1
                            if dist(players[t].pos, mob.pos) < 20 { hurtPlayer(t, Double(mob.def.attack), from: mob.pos) }
                        }
                    } else if d < 15, mob.attackTimer <= 0 {
                        mob.windup = 0.35
                    } else if d >= 12 {
                        var goal = tp
                        if mob.flies { goal.y += CGFloat(sin(time * 6 + Double(mob.id)) * 8) }
                        walk(to: goal, mob.def.speed)
                    }
                } else if let w = wanderGoal(&mob) { walk(to: w, mob.def.speed * 0.45) }
            }
            list[k] = mob
        }
        // Mobs push each other apart a little so packs do not stack into one sprite.
        for a in list.indices where !list[a].dead {
            for b in list.indices where b > a && !list[b].dead {
                let dx = list[b].pos.x - list[a].pos.x, dy = list[b].pos.y - list[a].pos.y, d = hypot(dx, dy)
                let minD = list[a].radius + list[b].radius
                guard d < minD, d > 0.01 else { continue }
                let push = (minD - d) / 2
                let pa = CGPoint(x: list[a].pos.x - dx / d * push, y: list[a].pos.y - dy / d * push)
                let pb = CGPoint(x: list[b].pos.x + dx / d * push, y: list[b].pos.y + dy / d * push)
                if list[a].flies || m.canStand(pa) { list[a].pos = pa }
                if list[b].flies || m.canStand(pb) { list[b].pos = pb }
            }
        }
        list.removeAll { $0.dead && $0.respawnAt.isInfinite && time - $0.diedAt > 1 }
        list += spawned
        mobs[mapID] = list
    }

    /// Where an idle monster ambles next (nil while it rests).
    private func wanderGoal(_ mob: inout RpgMob) -> CGPoint? {
        if time >= mob.nextWander {
            mob.nextWander = time + rand(2, 5)
            let a = rand(0, .pi * 2), r = rand(10, 50)
            mob.wanderTo = CGPoint(x: mob.home.x + CGFloat(cos(a) * r), y: mob.home.y + CGFloat(sin(a) * r))
        }
        if let w = mob.wanderTo, dist(w, mob.pos) < 3 { mob.wanderTo = nil }
        return mob.wanderTo
    }

    /// Slime King: chase and body-slam, then a jump onto the target, a ring of slime balls or a summon.
    private func bossThink(_ mob: inout RpgMob, _ target: RpgPlayer, _ dt: Double, _ mapID: RpgMapID, _ spawned: inout [RpgMob]) {
        let enraged = mob.hp < Double(mob.def.hp) * 0.4
        let pace = enraged ? 0.7 : 1.0
        if time >= mob.phaseUntil {
            mob.phase = (mob.phase + 1) % 4
            switch mob.phase {
            case 0:
                mob.phaseUntil = time + 2.6 * pace
            case 1:
                mob.jumpTarget = target.pos
                mob.airborne = true
                mob.phaseUntil = time + 1.0 * pace
                effect(.telegraph(radius: 32, until: time + 1.0 * pace), mapID, target.pos, .base, duration: 1.0 * pace)
            case 2:
                mob.phaseUntil = time + 1.6 * pace
                for burst in 0..<(enraged ? 3 : 2) {
                    for k in 0..<10 {
                        let a = Double(k) / 10 * .pi * 2 + Double(burst) * 0.3
                        shots.append(RpgShot(pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 10), vel: CGVector(dx: cos(a) * (100 + Double(burst) * 30), dy: sin(a) * (100 + Double(burst) * 30)),
                                             map: mapID, fromPlayer: false, ownerID: mob.id, damage: Double(mob.def.attack) * 0.7, element: .base, kind: .slimeBall, life: 2.2))
                    }
                }
            default:
                mob.phaseUntil = time + 1.2 * pace
                let alive = (mobs[mapID] ?? []).filter { !$0.dead && $0.def.behavior != .boss }.count + spawned.count
                if alive < 8 {
                    for k in 0..<3 {
                        let a = Double(k) / 3 * .pi * 2
                        let p = CGPoint(x: mob.pos.x + CGFloat(cos(a) * 30), y: mob.pos.y + CGFloat(sin(a) * 20))
                        let def = RpgMonsters.def(enraged ? "blueslime" : "slime")
                        var s = RpgMob(id: newID(), def: def, pos: p, home: p, hp: Double(def.hp) * 2)
                        s.targetID = target.id
                        s.aggroUntil = time + 20
                        s.respawnAt = .infinity
                        spawned.append(s)
                    }
                    effect(.burst(radius: 34), mapID, mob.pos, .wind, duration: 0.4)
                }
            }
        }
        switch mob.phase {
        case 0:
            let dx = Double(target.pos.x - mob.pos.x), dy = Double(target.pos.y - mob.pos.y), d = hypot(dx, dy)
            if d > 4 {
                let s = min(d, mob.def.speed * (enraged ? 1.4 : 1) * dt)
                mob.pos = CGPoint(x: mob.pos.x + CGFloat(dx / d * s), y: mob.pos.y + CGFloat(dy / d * s))
                mob.facingRight = dx > 0
            }
            if d < 22, mob.attackTimer <= 0, let ti = pIndex(target.id) {
                mob.attackTimer = 1
                hurtPlayer(ti, Double(mob.def.attack), from: mob.pos)
            }
        case 1:
            if let jt = mob.jumpTarget, time >= mob.phaseUntil - 0.05 {
                mob.pos = jt
                mob.airborne = false
                mob.jumpTarget = nil
                effect(.burst(radius: 34), mapID, jt, .base, duration: 0.4)
                shake = max(shake, 2)
                for i in players.indices where players[i].map == mapID && dist(players[i].pos, jt) < 34 {
                    hurtPlayer(i, Double(mob.def.attack) * 1.5, from: jt)
                }
                mob.phaseUntil = time + 0.5
                mob.phase = 1
            }
        default: break
        }
    }

    // MARK: projectiles & pickups

    private func stepShots(_ dt: Double) {
        var keep: [RpgShot] = []
        for var s in shots {
            s.life -= dt
            s.pos.x += s.vel.dx * CGFloat(dt)
            s.pos.y += s.vel.dy * CGFloat(dt)
            let m = map(s.map)
            let foot = CGPoint(x: s.pos.x, y: s.pos.y + 6)
            if m.isBlocked(foot), m.at(Int(foot.x / 16), Int(foot.y / 16)) != .water {
                if s.fromPlayer, s.element == .fire, s.kind == .orb { explode(s) }
                continue
            }
            if s.fromPlayer {
                var done = false
                for v in mobIDs(near: foot, radius: s.kind == .bigArrow ? 8 : 5, map: s.map) where !s.hit.contains(v) {
                    s.hit.insert(v)
                    if s.kind == .orb, s.element == .fire {
                        explode(s)
                    } else {
                        damageMob(v, map: s.map, base: s.damage, by: s.ownerID, element: s.element, skill: s.kind == .bigArrow)
                    }
                    if !s.pierce { done = true; break }
                }
                if done { continue }
            } else {
                if let i = players.indices.first(where: { players[$0].map == s.map && !players[$0].dead && dist(players[$0].pos, foot) < 8 }) {
                    hurtPlayer(i, s.damage, from: s.pos)
                    continue
                }
            }
            if s.life > 0 { keep.append(s) } else if s.fromPlayer, s.kind == .orb, s.element == .fire { explode(s) }
        }
        shots = keep
    }

    private func explode(_ s: RpgShot) {
        let c = CGPoint(x: s.pos.x, y: s.pos.y + 6)
        effect(.burst(radius: 16), s.map, c, .fire, duration: 0.3)
        for v in mobIDs(near: c, radius: 16, map: s.map) { damageMob(v, map: s.map, base: s.damage, by: s.ownerID, element: .fire, skill: false) }
    }

    private func pickups() {
        guard !drops.isEmpty else { return }
        var keep: [RpgDropped] = []
        for d in drops {
            guard time - d.at > 0.35,
                  let i = players.indices.first(where: { players[$0].map == d.map && !players[$0].dead && dist(players[$0].pos, d.pos) < 26 })
            else { keep.append(d); continue }
            if d.gold > 0 {
                players[i].gold += d.gold
                float("+\(d.gold)G", d.map, d.pos, .gold)
            }
            if let item = d.item, let it = RpgItems.item(item) {
                players[i].inventory[item, default: 0] += 1
                toast("\(RpgItems.rarityName[it.rarity]) \(it.name) 획득!")
                if it.rarity >= 2 { effect(.levelUp, d.map, players[i].pos, .holy, duration: 0.8) }
            }
        }
        drops = keep
    }
}

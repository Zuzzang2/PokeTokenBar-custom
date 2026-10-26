import CoreGraphics
import Foundation

// SPIKE: the 픽셀 모험 simulation. Players act through `RpgInput` (held movement and attack, pressed
// skill slots) and `RpgAction`s (shops, quests, enhancement, travel) so a lobby host can later feed
// remote players the same way. Monsters of a map only live while someone is on it. Pixel coordinates,
// y down; unit positions are their feet.

struct RpgInput: Codable, Sendable {
    var move = CGVector.zero
    var attack = false
    /// Skill slots pressed this frame (8 slots).
    var slots: Set<Int> = []
    /// Set by remote players: where they stand and face on their own screen.
    var pos: CGPoint?
    var facing: CGVector?
}

struct RpgToast: Codable, Sendable {
    let text: String
    let at: Double
    /// Player the toast is for; nil shows it to everyone.
    let to: Int?
}

struct RpgChat: Codable, Sendable {
    let name: String
    let text: String
    let at: Double
    /// Party chat (/p …) is shown only to that party.
    var party: Int? = nil
}

enum RpgAction: Codable, Sendable {
    case interact, hpPotion, mpPotion, scroll
    case equip(String)
    case buy(String)
    case sell(String)
    case levelSkill(String)
    case assign(slot: Int, skill: String?)
    case enhance(weapon: Bool)
    case acceptQuest(String)
    case claimQuest(String)
    case abandonQuest(String)
    case warp(RpgMapID)
    /// A remote player fires skill slot n (sent reliably so a press is never lost).
    case cast(Int)
    case invite(Int)
    case acceptInvite
    case declineInvite
    case leaveParty
    /// 차원문: go stand next to a party member wherever they are.
    case warpToMember(Int)
    /// 2차 전직 at the 전직관: pick advanced job 1 or 2.
    case advance(Int)
    /// The player's raised companion, sent by its owner so the host can run it as their pet.
    case pet(RpgPetInfo?)
    // 거래 (see RpgTrade.swift)
    case tradeRequest(Int)
    case tradeAccept
    case tradeDecline
    case tradeCancel
    case tradeOffer(item: String, count: Int)
    case tradeGold(Int)
    case tradeConfirm(Bool)
}

struct RpgQuest: Codable, Sendable, Equatable {
    var id = UUID().uuidString
    let monster: String
    let count: Int
    var progress = 0
    let gold: Int
    let xp: Int
    let stones: Int
    let book: String?

    var done: Bool { progress >= count }
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
    var plus: [String: Int] = [:]
    var skills: [String: Int] = [:]
    var sp = 0
    var slots: [String?] = Array(repeating: nil, count: 8)
    var quests: [RpgQuest] = []
    var visited: Set<RpgMapID> = [.town]
    var map: RpgMapID = .town
    var pos: CGPoint
    var facing = CGVector(dx: 0, dy: 1)
    var facingRight = true
    var moving = false
    var attackTimer = 0.0
    var cooldowns: [String: Double] = [:]
    var invulnerable = 0.0
    var hurtFlash = 0.0
    var dash: (to: CGPoint, hit: Set<Int>, damage: Double)?
    var dead = false
    var respawnAt = 0.0
    var lastHurt = -10.0
    var potionTimer = 0.0
    var playTime = 0.0
    var rageUntil = 0.0
    var ironUntil = 0.0
    var focusUntil = 0.0
    var shieldUntil = 0.0
    var cycloneUntil = 0.0
    var nextCyclone = 0.0
    /// Host ignores client-reported positions until then (dashes, blinks, travel move the player on the host).
    var posLockUntil = 0.0
    var bubble: String?
    var bubbleUntil = 0.0
    /// Party = the founder's player id; nil when solo.
    var partyID: Int?
    var inviteFrom: Int?
    /// Pending trade request from this player id.
    var tradeFrom: Int?
    /// Boss id → when this player last received its personal loot (seconds since 1970, survives restarts).
    var bossLoot: [String: Double] = [:]
    /// Hardcore: one life. `fallen` once that life is spent.
    var hardcore = false
    var fallen = false
    /// 0 before the 2차 전직, then 1 or 2 (see `RpgJobs`).
    var job = 0
    /// The raised companion that follows this player; not saved.
    var petInfo: RpgPetInfo?
    var frenzyUntil = 0.0
    /// Kills in a row; resets when `comboUntil` passes. Not saved.
    var combo = 0
    var comboUntil = 0.0
    /// Lifetime counters (saved): kills per monster id, golden elites, best combo, unlocked achievements.
    var kills: [String: Int] = [:]
    var eliteKills = 0
    var bestCombo = 0
    var bestFloor = 0
    var achievements: Set<String> = []

    var weaponItem: RpgItem? { RpgItems.item(weapon) }
    var armorItem: RpgItem? { armor.flatMap(RpgItems.item) }
    var element: RpgElement { weaponItem?.element ?? .base }
    var jobDef: RpgJobDef? { RpgJobs.def(cls, job) }
    /// Class name, or the advanced job's name once advanced.
    var title: String { jobDef?.name ?? cls.name }
    /// The skills shown in the skills window: the class's 8 plus the advanced job's 2.
    var skillList: [RpgSkillDef] { cls.skills + (jobDef?.skills.compactMap(RpgSkills.def) ?? []) }
    var maxHP: Double { Double(cls.baseHP + cls.hpPerLevel * (level - 1)) * (jobDef?.hp ?? 1) }
    var maxMP: Double { Double(cls.baseMP + cls.mpPerLevel * (level - 1)) * (jobDef?.mp ?? 1) }
    func weaponAttack() -> Double { weaponItem.map { RpgItems.boosted($0.attack, plus: plus[$0.id] ?? 0) } ?? 0 }
    func armorDefense() -> Double { armorItem.map { RpgItems.boosted($0.defense, plus: plus[$0.id] ?? 0) } ?? 0 }
    func attack(at time: Double) -> Double {
        let base = (Double(cls.baseAttack) + cls.attackPerLevel * Double(level - 1) + weaponAttack()) * (jobDef?.attack ?? 1)
        var buff = time < rageUntil ? 1.3 + 0.03 * Double((skills["w_rage"] ?? 1) - 1) : 1
        if time < frenzyUntil { buff = max(buff, 1.4) }
        return base * buff
    }
    var defense: Double { (Double(cls.baseDefense) + cls.defensePerLevel * Double(level - 1) + armorDefense()) * (jobDef?.defense ?? 1) }
    func attackInterval(at time: Double) -> Double {
        cls.attackInterval * (jobDef?.interval ?? 1) * (element == .wind ? 0.7 : 1) * (time < focusUntil ? 0.77 : 1)
    }
    func critChance(at time: Double) -> Double { cls.critChance + (jobDef?.crit ?? 0) + (time < focusUntil ? 0.4 : 0) }
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
    var dotTicks = 0
    var dotDamage = 0.0
    var dotElement = RpgElement.fire
    var nextDot = 0.0
    var slowUntil = 0.0
    var stunUntil = 0.0
    var phase = 0
    var phaseUntil = 0.0
    var jumpTarget: CGPoint?
    var airborne = false
    var chargeDir: CGVector?
    var lastHitBy: Int?
    var summoned = false
    /// Bosses grow with the raid: HP x(1 + 0.75 per extra player in the room).
    var hpScale = 1.0
    /// A rare golden variant: 3× HP, 1.5× attack, 4× XP and gold, better drops (see `RpgWorld.eliteChance`).
    var elite = false
    /// Bosses: everyone who landed a hit gets credit and loot, even if they fell before the end.
    var contributors: Set<Int> = []
    /// When the first hit landed (0 = not engaged); drives the berserk timer.
    var engagedAt = 0.0

    var radius: CGFloat { def.behavior == .boss ? 14 : 6 }
    var flies: Bool { def.behavior == .flyer }
}

struct RpgShot: Codable, Sendable {
    enum Kind: Codable, Sendable { case arrow, orb, bigArrow, mobArrow, slimeBall, bossOrb, poisonArrow }
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

struct RpgFX: Codable, Sendable {
    enum Kind: Codable, Sendable {
        case slash(angle: Double, radius: Double)
        case burst(radius: Double)
        case ice(radius: Double)
        case meteor(radius: Double)
        case chain([CGPoint])
        case spark(crit: Bool)
        case levelUp
        case telegraph(radius: Double)
        case rain(radius: Double)
        case strike
    }
    let kind: Kind
    let map: RpgMapID
    let pos: CGPoint
    let element: RpgElement
    let start: Double
    let duration: Double
}

/// A hit that lands later: skill waves, meteor marks, boss telegraphs.
struct RpgPending {
    let at: Double
    let map: RpgMapID
    let pos: CGPoint
    let radius: Double
    let damage: Double
    let ownerID: Int
    let fromPlayer: Bool
    let element: RpgElement
    let stun: Double
    let fx: RpgFX.Kind?
}

struct RpgTrap: Codable, Sendable {
    let map: RpgMapID
    let pos: CGPoint
    let ownerID: Int
    let damage: Double
    let expires: Double
    let armedAt: Double
}

struct RpgFloater: Codable, Sendable {
    enum Style: Codable, Sendable { case damage, crit, hurt, heal, gold, xp, info, poison }
    let text: String
    let map: RpgMapID
    var pos: CGPoint
    var life: Double
    let style: Style
}

struct RpgDropped: Codable, Sendable {
    let id: Int
    let map: RpgMapID
    let pos: CGPoint
    let gold: Int
    let item: String?
    let at: Double
    /// Party loot: only this player can pick it up for the first 30 seconds.
    var owner: Int? = nil
}

final class RpgWorld {
    static let townSpawn = RpgTile(x: 15, y: 10)
    static let slotCount = 8
    static let berserkAfter = 480.0
    /// Seconds between kills that keep a combo alive, and the XP / gold bonus it earns (+5% per 10 kills, max +50%).
    static let comboWindow = 4.0
    /// Chance (percent) that a normal monster spawns as a golden elite, and what it is worth.
    static let eliteChance = 3
    /// How many times the per-map monster counts in `RpgMaps` are multiplied (bosses excluded), and how fast they come back.
    static let monsterDensity = 1.5
    static let respawnDelay = 6.0
    static let eliteHP = 3.0
    static let eliteAttack = 1.5
    static func comboBonus(_ combo: Int) -> Double { min(0.5, Double(combo / 10) * 0.05) }
    static let bossLootLockout = 1800.0
    static let hardcoreDamage = 1.5
    static let hardcoreReward = 1.3
    static let gravesPerMap = 50

    private(set) var maps: [RpgMapID: RpgMap] = [:]
    private(set) var players: [RpgPlayer] = []
    private(set) var mobs: [RpgMapID: [RpgMob]] = [:]
    private(set) var shots: [RpgShot] = []
    private(set) var fx: [RpgFX] = []
    private(set) var pending: [RpgPending] = []
    private(set) var traps: [RpgTrap] = []
    private(set) var floaters: [RpgFloater] = []
    private(set) var drops: [RpgDropped] = []
    /// Raised companions following their owners (host simulates; a client mirrors the host's).
    private(set) var pets: [Int: RpgPetState] = [:]
    /// Active trades (host only) and, on a client, the view of its own trade from the last private state.
    private var trades: [RpgTrade] = []
    var mirrorTrade: RpgTradeView?
    private var nextPartyID = 10_000
    private(set) var toasts: [RpgToast] = []
    private(set) var chatLog: [RpgChat] = []
    private(set) var graves: [RpgGrave] = []
    /// Called whenever a new tombstone appears, so it can be written to disk.
    var onGraves: (() -> Void)?
    /// Who an action is being resolved for, so toasts reach only that player in a shared world.
    private var actor: Int?
    /// A client mirrors the host: no simulation, snapshots fill it in.
    var isMirror = false
    /// Client side: where the host last put each remote player (p<id>) and monster (m<id>); drawn positions ease toward them.
    var netTargets: [String: CGPoint] = [:]
    private var lootTurn = 0
    private(set) var offers: [RpgQuest] = []
    private(set) var time = 0.0
    private(set) var shake = 0.0
    /// 무한의 탑: the floor everyone inside is on (0 when nobody is), and when it was cleared.
    private(set) var towerFloor = 0
    private var towerClearedAt: Double?
    private var offersAt = -1000.0
    private var nextID = 1
    private var rng = KartRNG(seed: UInt64.random(in: 1...UInt64.max))

    init(player: RpgPlayer) {
        var p = player
        p.visited.insert(p.map)
        players = [p]
        _ = map(p.map)
        spawnMobsIfNeeded(p.map)
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

    func toast(_ text: String, to target: Int? = -1) {
        toasts.append(RpgToast(text: text, at: time, to: target == -1 ? actor : target))
        if toasts.count > 12 { toasts.removeFirst() }
    }

    private func float(_ text: String, _ map: RpgMapID, _ p: CGPoint, _ style: RpgFloater.Style) {
        floaters.append(RpgFloater(text: text, map: map, pos: CGPoint(x: p.x, y: p.y - 18), life: style == .info ? 1.4 : 0.9, style: style))
    }

    private func effect(_ kind: RpgFX.Kind, _ map: RpgMapID, _ p: CGPoint, _ e: RpgElement, duration: Double = 0.3, delay: Double = 0) {
        fx.append(RpgFX(kind: kind, map: map, pos: p, element: e, start: time + delay, duration: duration))
    }

    // MARK: monsters

    private func spawnMobsIfNeeded(_ id: RpgMapID) {
        guard mobs[id] == nil else { return }
        let m = map(id)
        var list: [RpgMob] = []
        for spawn in m.def.monsters {
            let count = RpgMonsters.def(spawn.monster).behavior == .boss ? spawn.count : Int((Double(spawn.count) * Self.monsterDensity).rounded(.up))
            for _ in 0..<count {
                let def = RpgMonsters.def(spawn.monster)
                let p = def.behavior == .boss ? CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2 - 24) : randomSpawn(m)
                list.append(newMob(id: newID(), def: def, at: p))
            }
        }
        mobs[id] = list
    }

    /// A fresh monster; ordinary ones have a small chance to be a golden elite.
    private func newMob(id: Int, def: RpgMonsterDef, at p: CGPoint, canBeElite: Bool = true) -> RpgMob {
        let elite = canBeElite && def.behavior != .boss && rng.int(100) < Self.eliteChance
        var mob = RpgMob(id: id, def: def, pos: p, home: p, hp: Double(def.hp) * (elite ? Self.eliteHP : 1))
        if elite { mob.elite = true; mob.hpScale = Self.eliteHP }
        return mob
    }

    private func randomSpawn(_ m: RpgMap) -> CGPoint {
        guard !m.spawnTiles.isEmpty else { return CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2) }
        return RpgMap.center(m.spawnTiles[rng.int(m.spawnTiles.count)])
    }

    // MARK: actions

    func perform(_ action: RpgAction, for id: Int) {
        guard let i = pIndex(id) else { return }
        actor = id
        defer { actor = nil }
        if players[i].dead { return }
        switch action {
        case .interact:
            if let portal = nearbyPortal(for: id), !portal.waypoint { travel(i, to: portal.to, at: portal.arrive, minLevel: portal.minLevel) }
        case .hpPotion:
            let missing = players[i].maxHP - players[i].hp
            let order = ["hp0", "hp1", "hp2", "hp3"].filter { (players[i].inventory[$0] ?? 0) > 0 }
            // The smallest potion that covers what is missing, else the biggest one carried.
            let pick = order.first { Double(RpgItems.item($0)?.heal ?? 0) >= missing } ?? order.last
            if let pick { use(pick, i) } else { toast("HP 물약이 없어요") }
        case .mpPotion:
            let order = ["mp0", "mp1"].filter { (players[i].inventory[$0] ?? 0) > 0 }
            let missing = players[i].maxMP - players[i].mp
            if let pick = order.first(where: { Double(RpgItems.item($0)?.heal ?? 0) >= missing }) ?? order.last { use(pick, i) } else { toast("MP 물약이 없어요") }
        case .scroll:
            if (players[i].inventory["scroll"] ?? 0) > 0 { use("scroll", i) } else { toast("귀환 주문서가 없어요") }
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
        case .levelSkill(let skill):
            guard let def = RpgSkills.def(skill), let lv = players[i].skills[skill] else { return }
            guard players[i].sp > 0 else { toast("스킬 포인트가 없어요 (레벨업마다 1)"); return }
            guard lv < def.maxLevel else { toast("이미 최대 레벨이에요"); return }
            players[i].sp -= 1
            players[i].skills[skill] = lv + 1
            toast("\(def.name) Lv\(lv + 1)")
        case .assign(let slot, let skill):
            guard slot >= 0, slot < Self.slotCount else { return }
            if let skill { for k in players[i].slots.indices where players[i].slots[k] == skill { players[i].slots[k] = nil } }
            players[i].slots[slot] = skill
        case .enhance(let weapon):
            enhance(i, weapon: weapon)
        case .acceptQuest(let qid):
            guard let k = offers.firstIndex(where: { $0.id == qid }) else { return }
            guard players[i].quests.count < 3 else { toast("의뢰는 3개까지 받을 수 있어요"); return }
            players[i].quests.append(offers.remove(at: k))
            toast("의뢰 수락!")
        case .claimQuest(let qid):
            guard let k = players[i].quests.firstIndex(where: { $0.id == qid }), players[i].quests[k].done else { return }
            let q = players[i].quests.remove(at: k)
            players[i].gold += q.gold
            players[i].inventory["stone", default: 0] += q.stones
            if let b = q.book { players[i].inventory[b, default: 0] += 1 }
            toast("의뢰 완료! +\(q.gold)G, 강화석 \(q.stones)개" + (q.book.flatMap(RpgItems.item).map { ", \($0.name)" } ?? ""))
            grantXP(players[i].id, q.xp)
        case .abandonQuest(let qid):
            players[i].quests.removeAll { $0.id == qid }
        case .cast(let slot):
            if players[i].slots.indices.contains(slot), let s = players[i].slots[slot] { castSkill(i, s) }
        case .invite(let target):
            guard target != id, let t = pIndex(target) else { return }
            if players[i].partyID == nil { nextPartyID += 1; players[i].partyID = nextPartyID }
            guard partyMembers(of: id).count < 8 else { toast("파티는 8명까지예요"); return }
            guard players[t].partyID == nil || players[t].partyID != players[i].partyID else { toast("이미 같은 파티예요"); return }
            players[t].inviteFrom = id
            toast("\(players[t].name) 님에게 파티 초대를 보냈어요")
            toast("\(players[i].name) 님의 파티 초대! 파티창(P)에서 수락하세요", to: target)
        case .acceptInvite:
            guard let from = players[i].inviteFrom, let f = pIndex(from), let party = players[f].partyID else {
                players[i].inviteFrom = nil
                toast("초대가 사라졌어요")
                return
            }
            guard partyMembers(of: from).count < 8 else { toast("파티가 가득 찼어요"); return }
            leaveParty(i)
            players[i].partyID = party
            players[i].inviteFrom = nil
            for m in partyMembers(of: from) { toast("\(players[i].name) 님이 파티에 들어왔어요 (\(partyMembers(of: from).count)/8)", to: m) }
        case .declineInvite:
            players[i].inviteFrom = nil
        case .leaveParty:
            leaveParty(i)
            toast("파티를 나왔어요")
        case .warpToMember(let member):
            guard let m = player(member), m.partyID != nil, m.partyID == players[i].partyID, !m.dead else { return }
            // The UI only offers this in town; the host enforces it, and the level a portal into that map would need.
            guard players[i].map == .town else { toast("파티원 곁으로는 마을에서 이동할 수 있어요"); return }
            let needed = RpgMaps.all.flatMap(\.portals).filter { $0.to == m.map }.map(\.minLevel).min() ?? 1
            guard players[i].level >= needed else { toast("Lv\(needed) 이상만 갈 수 있는 곳이에요"); return }
            let from = players[i].map
            players[i].map = m.map
            players[i].pos = m.pos
            players[i].dash = nil
            players[i].posLockUntil = time + 0.6
            players[i].visited.insert(m.map)
            spawnMobsIfNeeded(m.map)
            leaveMapIfEmpty(from)
            toast("\(m.name) 님 곁으로 이동했어요")
        case .warp(let target):
            guard players[i].visited.contains(target), let arrive = arrival(for: target) else { return }
            travel(i, to: target, at: arrive, minLevel: 1)
        case .advance(let choice):
            advance(i, choice)
        case .pet(let info):
            let clean = info?.sanitized
            if let clean, clean.speciesID != players[i].petInfo?.speciesID { toast("\(clean.name)이(가) 함께 모험해요!") }
            players[i].petInfo = clean
        case .tradeRequest, .tradeAccept, .tradeDecline, .tradeCancel, .tradeOffer, .tradeGold, .tradeConfirm:
            handleTrade(action, i)
        }
    }

    // MARK: 2차 전직

    private func advance(_ i: Int, _ choice: Int) {
        guard players[i].job == 0 else { toast("이미 전직했어요"); return }
        guard players[i].level >= RpgJobs.advanceLevel else { toast("Lv\(RpgJobs.advanceLevel) 이상이어야 전직할 수 있어요"); return }
        guard let def = RpgJobs.def(players[i].cls, choice) else { return }
        players[i].job = choice
        learnJobSkills(i)
        players[i].hp = players[i].maxHP
        players[i].mp = players[i].maxMP
        effect(.levelUp, players[i].map, players[i].pos, .holy, duration: 1.4)
        shake = max(shake, 1)
        toast("2차 전직! \(def.name)이(가) 되었어요", to: nil)
        checkAchievements(i)
    }

    /// Pays out every achievement whose goal has just been reached (once each).
    private func checkAchievements(_ i: Int) {
        for a in RpgAchievements.all where !players[i].achievements.contains(a.id) && RpgAchievements.value(a.metric, players[i]) >= a.goal {
            players[i].achievements.insert(a.id)
            players[i].gold += a.gold
            if a.stones > 0 { players[i].inventory["stone", default: 0] += a.stones }
            toast("업적 달성: \(a.name)  (+\(a.gold)G, 강화석 \(a.stones)개)", to: players[i].id)
            effect(.levelUp, players[i].map, players[i].pos, .holy, duration: 1.2)
        }
    }

    /// Teaches the job skills the character's level allows (the second at Lv30) and puts new ones on a free slot.
    private func learnJobSkills(_ i: Int) {
        guard let def = players[i].jobDef else { return }
        for (k, id) in def.skills.enumerated() where players[i].skills[id] == nil {
            guard players[i].level >= (k == 0 ? RpgJobs.advanceLevel : RpgJobs.secondSkillLevel) else { continue }
            players[i].skills[id] = 1
            if let slot = players[i].slots.firstIndex(where: { $0 == nil }) { players[i].slots[slot] = id }
            if let s = RpgSkills.def(id) { toast("\(s.name) 스킬을 배웠어요 (스킬창에서 슬롯을 바꿀 수 있어요)") }
        }
    }

    private func arrival(for map: RpgMapID) -> RpgTile? {
        RpgMaps.all.lazy.flatMap(\.portals).first { $0.to == map && !$0.waypoint }?.arrive
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
        case .book(let skill):
            guard let def = RpgSkills.def(skill) else { return }
            guard def.cls == players[i].cls else { toast("\(def.cls.name) 스킬북이에요 (상점에 팔 수 있어요)"); return }
            guard players[i].skills[skill] == nil else { toast("이미 배운 스킬이에요"); return }
            guard players[i].level >= def.minLevel else { toast("Lv\(def.minLevel)부터 배울 수 있어요"); return }
            players[i].skills[skill] = 1
            if let free = players[i].slots.firstIndex(where: { $0 == nil }) { players[i].slots[free] = skill }
            effect(.levelUp, players[i].map, players[i].pos, .cosmic, duration: 1.0)
            toast("새 스킬 습득: \(def.name)!")
        case .weapon, .armor, .stone:
            equip(item, i)
            return
        }
        consume(item, i)
    }

    private func consume(_ item: String, _ i: Int, _ n: Int = 1) {
        let left = (players[i].inventory[item] ?? 0) - n
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
        case .stone:
            toast("강화석은 대장간에서 써요")
        default:
            use(item, i)
        }
    }

    private func enhance(_ i: Int, weapon: Bool) {
        guard let id = weapon ? players[i].weapon : players[i].armor, let item = RpgItems.item(id) else { toast("장착한 장비가 없어요"); return }
        let plus = players[i].plus[id] ?? 0
        guard plus < RpgItems.maxPlus else { toast("최대 강화 단계예요"); return }
        let cost = RpgItems.enhanceCost(item, plus: plus)
        guard players[i].gold >= cost.gold else { toast("골드가 부족해요 (\(cost.gold)G)"); return }
        guard (players[i].inventory["stone"] ?? 0) >= cost.stones else { toast("강화석이 부족해요 (\(cost.stones)개)"); return }
        players[i].gold -= cost.gold
        consume("stone", i, cost.stones)
        if Double(rng.int(10_000)) / 10_000 < RpgItems.enhanceChance(plus) {
            players[i].plus[id] = plus + 1
            toast("강화 성공! \(item.name) +\(plus + 1)")
            effect(.levelUp, players[i].map, players[i].pos, .holy, duration: 1)
        } else if plus >= 7 {
            players[i].plus[id] = plus - 1
            toast("강화 실패… +\(plus - 1)로 떨어졌어요")
        } else {
            toast("강화 실패… (단계 유지)")
        }
    }

    func nearbyPortal(for id: Int) -> RpgPortal? {
        guard let p = player(id) else { return nil }
        return map(p.map).def.portals.first { dist(RpgMap.center($0.at), p.pos) < 16 }
    }

    func nearbyPlace(for id: Int) -> RpgPlace? {
        guard let p = player(id), p.map == .town else { return nil }
        return map(.town).buildings.first { dist($0.door, p.pos) < 22 }?.place
    }

    private func travel(_ i: Int, to target: RpgMapID, at arrive: RpgTile, minLevel: Int) {
        guard players[i].level >= minLevel else {
            toast("강한 기운이 느껴진다… (Lv\(minLevel) 이상)")
            return
        }
        let from = players[i].map
        players[i].map = target
        players[i].pos = RpgMap.center(arrive)
        players[i].dash = nil
        players[i].posLockUntil = time + 0.6
        let first = players[i].visited.insert(target).inserted
        if first { checkAchievements(i) }
        spawnMobsIfNeeded(target)
        leaveMapIfEmpty(from)
        let def = RpgMaps.def(target)
        toast("\(def.name) — \(def.levelText)")
        if first, RpgMaps.waypoints.contains(target) { toast("차원문에 \(def.name)이(가) 등록됐어요") }
    }

    private func moveToTown(_ i: Int) {
        let from = players[i].map
        players[i].map = .town
        players[i].pos = RpgMap.center(Self.townSpawn)
        players[i].dash = nil
        players[i].posLockUntil = time + 0.6
        leaveMapIfEmpty(from)
    }

    /// Nobody left on a map: bosses heal, monsters forget their targets.
    private func leaveMapIfEmpty(_ id: RpgMapID) {
        if id == .tower, !players.contains(where: { $0.map == id }) { mobs[id] = nil; towerFloor = 0; towerClearedAt = nil }
        guard !players.contains(where: { $0.map == id }), var list = mobs[id] else { return }
        list.removeAll { $0.summoned }
        for k in list.indices {
            list[k].targetID = nil
            if !list[k].dead { list[k].hp = Double(list[k].def.hp); list[k].hpScale = 1; list[k].contributors = []; list[k].engagedAt = 0; list[k].pos = list[k].home; list[k].phase = 0; list[k].airborne = false; list[k].chargeDir = nil }
            if list[k].elite, !list[k].dead { list[k].hpScale = Self.eliteHP; list[k].hp = Double(list[k].def.hp) * Self.eliteHP }
        }
        mobs[id] = list
        pending.removeAll { $0.map == id }
        traps.removeAll { $0.map == id }
    }

    // MARK: quests

    /// Offers on the board, refreshed every five minutes or when taken.
    func boardOffers(for id: Int) -> [RpgQuest] {
        if isMirror { return offers }
        guard let p = player(id) else { return [] }
        if offers.count < 3 || time - offersAt > 300 {
            offersAt = time
            offers = (0..<3).compactMap { _ in makeQuest(level: p.level, cls: p.cls) }
        }
        return offers
    }

    private func makeQuest(level: Int, cls: RpgClass) -> RpgQuest? {
        let normal = RpgMonsters.all.filter { $0.behavior != .boss && $0.behavior != .coward && $0.behavior != .exploder && $0.level >= level - 5 && $0.level <= level + 3 }
        let bosses = RpgMonsters.all.filter { $0.behavior == .boss && $0.level >= level - 4 && $0.level <= level + 6 }
        let bossTurn = !bosses.isEmpty && rng.int(4) == 0
        guard let m = bossTurn ? bosses[rng.int(bosses.count)] : (normal.isEmpty ? nil : normal[rng.int(normal.count)]) else { return nil }
        let count = bossTurn ? 1 : 12 + rng.int(4) * 6
        let avgGold = (m.gold.lowerBound + m.gold.upperBound) / 2
        let books = RpgSkills.all.filter { !$0.starter && $0.cls == cls && $0.minLevel <= level + 6 }
        let book = !books.isEmpty && rng.int(100) < (bossTurn ? 50 : 12) ? "book_\(books[rng.int(books.count)].id)" : nil
        return RpgQuest(monster: m.id, count: count, gold: count * avgGold * (bossTurn ? 1 : 2), xp: count * m.xp * (bossTurn ? 1 : 1) / 2,
                        stones: (bossTurn ? 4 : 1) + level / 12, book: book)
    }

    // MARK: step

    func step(_ dt: Double, inputs: [Int: RpgInput]) {
        time += dt
        shake = max(0, shake - dt * 8)
        for i in players.indices { stepPlayer(i, dt, inputs[players[i].id] ?? RpgInput()) }
        for mapID in Set(players.map(\.map)) { stepMobs(mapID, dt) }
        stepPets(dt)
        stepTower()
        stepTrades()
        stepShots(dt)
        stepPending()
        stepTraps()
        pickups()
        for k in floaters.indices { floaters[k].life -= dt; floaters[k].pos.y -= CGFloat(dt * 18) }
        floaters.removeAll { $0.life <= 0 }
        fx.removeAll { time - $0.start > $0.duration }
        toasts.removeAll { time - $0.at > 3.5 }
        chatLog.removeAll { time - $0.at > 30 }
        drops.removeAll { time - $0.at > 120 }
    }

    private func stepPlayer(_ i: Int, _ dt: Double, _ input: RpgInput) {
        actor = players[i].id
        defer { actor = nil }
        var p = players[i]
        p.playTime += dt
        p.attackTimer = max(0, p.attackTimer - dt)
        for (k, v) in p.cooldowns where v > 0 { p.cooldowns[k] = max(0, v - dt) }
        p.invulnerable = max(0, p.invulnerable - dt)
        p.hurtFlash = max(0, p.hurtFlash - dt)
        p.potionTimer = max(0, p.potionTimer - dt)
        if p.combo > 0, time > p.comboUntil { p.combo = 0 }
        if p.dead {
            players[i] = p
            if time >= p.respawnAt {
                players[i].dead = false
                players[i].hp = players[i].maxHP
                players[i].mp = players[i].maxMP
                moveToTown(i)
                toast("마을에서 부활했어요")
            }
            return
        }
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
            if dash.damage > 0 {
                for v in mobIDs(near: p.pos, radius: 16, map: p.map) where !hit.contains(v) {
                    hit.insert(v)
                    damageMob(v, map: p.map, base: dash.damage, by: p.id, element: p.element, skill: true)
                }
            }
            players[i].dash = (d <= step || blocked) ? nil : (dash.to, hit, dash.damage)
            return
        }
        let mv = input.move
        let len = hypot(mv.dx, mv.dy)
        p.moving = len > 0.01
        if let reported = input.pos {
            // A remote player moves on their own machine; take their position when it is believable.
            if time >= p.posLockUntil, m.canStand(reported), dist(reported, p.pos) < 90 { p.pos = reported }
            if let f = input.facing, hypot(f.dx, f.dy) > 0.1 {
                p.facing = f
                if abs(f.dx) > 0.2 { p.facingRight = f.dx > 0 }
            }
        } else if p.moving {
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
        // 회오리검 ticks while it lasts.
        if time < p.cycloneUntil, time >= p.nextCyclone {
            players[i].nextCyclone = time + 0.25
            let lv = p.skills["w_cyclone"] ?? 1
            let def = RpgSkills.def("w_cyclone")!
            effect(.slash(angle: time * 9, radius: 18), p.map, CGPoint(x: p.pos.x, y: p.pos.y - 5), p.element, duration: 0.25)
            for v in mobIDs(near: p.pos, radius: 30, map: p.map) {
                damageMob(v, map: p.map, base: p.attack(at: time) * RpgSkills.damage(def, level: lv), by: p.id, element: p.element, skill: true)
            }
        }
        if input.attack, players[i].attackTimer <= 0 { basicAttack(i) }
        for slot in input.slots.sorted() {
            if let skill = players[i].slots[slot] { castSkill(i, skill) }
        }
    }

    private func facingAngle(_ p: RpgPlayer) -> Double { Double(atan2(p.facing.dy, p.facing.dx)) }
    private func ahead(_ p: RpgPlayer, _ d: Double) -> CGPoint {
        let a = facingAngle(p)
        return CGPoint(x: p.pos.x + CGFloat(cos(a) * d), y: p.pos.y + CGFloat(sin(a) * d))
    }

    private func basicAttack(_ i: Int) {
        let p = players[i]
        players[i].attackTimer = p.attackInterval(at: time)
        let angle = facingAngle(p)
        let atk = p.attack(at: time)
        switch p.cls {
        case .warrior:
            effect(.slash(angle: angle, radius: 11), p.map, CGPoint(x: p.pos.x, y: p.pos.y - 6), p.element, duration: 0.3)
            for v in mobIDs(inArcOf: p, range: 26, cosLimit: 0.2) { damageMob(v, map: p.map, base: atk, by: p.id, element: p.element, skill: false) }
        case .archer:
            fire(from: p, angle: angle, kind: .arrow, damage: atk, speed: 230, range: 170)
        case .mage:
            fire(from: p, angle: angle, kind: .orb, damage: atk * 1.15, speed: 170, range: 140)
        }
    }

    private func fire(from p: RpgPlayer, angle: Double, kind: RpgShot.Kind, damage: Double, speed: Double, range: Double, element: RpgElement? = nil) {
        let v = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        shots.append(RpgShot(pos: CGPoint(x: p.pos.x + CGFloat(cos(angle) * 6), y: p.pos.y - 7 + CGFloat(sin(angle) * 6)), vel: v, map: p.map,
                             fromPlayer: true, ownerID: p.id, damage: damage, element: element ?? p.element, kind: kind, life: range / speed))
    }

    private func schedule(_ delay: Double, _ map: RpgMapID, _ pos: CGPoint, radius: Double, damage: Double, owner: Int, fromPlayer: Bool = true,
                          element: RpgElement, stun: Double = 0, fx: RpgFX.Kind?) {
        pending.append(RpgPending(at: time + delay, map: map, pos: pos, radius: radius, damage: damage, ownerID: owner, fromPlayer: fromPlayer,
                                  element: element, stun: stun, fx: fx))
    }

    private func castSkill(_ i: Int, _ skill: String) {
        let p = players[i]
        guard let def = RpgSkills.def(skill), let lv = p.skills[skill] else { return }
        guard (p.cooldowns[skill] ?? 0) <= 0 else { return }
        guard p.mp >= Double(def.mp) else { toast("MP가 부족해요"); return }
        let angle = facingAngle(p)
        let e = p.element
        let atk = p.attack(at: time)
        let power = atk * RpgSkills.damage(def, level: lv)
        var refund = false
        switch skill {
        case "w_whirl":
            let c = CGPoint(x: p.pos.x, y: p.pos.y - 4)
            effect(.burst(radius: 30), p.map, c, e)
            effect(.slash(angle: angle, radius: 16), p.map, c, e)
            effect(.slash(angle: angle + .pi, radius: 16), p.map, c, e)
            hitArea(p.pos, 32, p, power, e)
        case "w_dash":
            var to = p.pos
            for s in stride(from: 6.0, through: 76, by: 6) {
                let c = CGPoint(x: p.pos.x + CGFloat(cos(angle) * s), y: p.pos.y + CGFloat(sin(angle) * s))
                if map(p.map).canStand(c) { to = c } else { break }
            }
            players[i].dash = (to, [], power)
            players[i].posLockUntil = time + 0.5
            players[i].invulnerable = 0.3
            effect(.slash(angle: angle, radius: 13), p.map, CGPoint(x: to.x, y: to.y - 6), e)
        case "w_quake":
            for k in 1...7 {
                let c = ahead(p, Double(k) * 16)
                schedule(Double(k) * 0.045, p.map, c, radius: 14, damage: power, owner: p.id, element: e, fx: .burst(radius: 12))
            }
            shake = max(shake, 0.8)
        case "w_rage":
            players[i].rageUntil = time + 12
            effect(.levelUp, p.map, p.pos, .fire, duration: 1)
            toast("분노! 공격력 상승")
        case "w_iron":
            players[i].ironUntil = time + 10
            effect(.levelUp, p.map, p.pos, .base, duration: 1)
            toast("철벽! 받는 피해 감소")
        case "w_cyclone":
            players[i].cycloneUntil = time + 3.5
            players[i].nextCyclone = time
        case "w_slam":
            effect(.burst(radius: 44), p.map, ahead(p, 14), e, duration: 0.4)
            shake = max(shake, 1.5)
            for v in mobIDs(near: ahead(p, 14), radius: 44, map: p.map) { damageMob(v, map: p.map, base: power, by: p.id, element: e, skill: true, stun: 1.2) }
        case "w_ult":
            let targets = (mobs[p.map] ?? []).filter { !$0.dead && !$0.airborne && dist($0.pos, p.pos) < 170 }.sorted { dist($0.pos, p.pos) < dist($1.pos, p.pos) }
            for k in 0..<6 {
                let c = targets.isEmpty ? ahead(p, 30 + Double(k) * 14) : targets[k % targets.count].pos
                schedule(Double(k) * 0.12, p.map, c, radius: 26, damage: power, owner: p.id, element: .thunder, stun: 1, fx: .strike)
            }
            shake = max(shake, 2)
        case "a_triple":
            for d in [-0.26, 0.0, 0.26] { fire(from: p, angle: angle + d, kind: .arrow, damage: power, speed: 240, range: 170) }
        case "a_pierce":
            fire(from: p, angle: angle, kind: .bigArrow, damage: power, speed: 320, range: 230)
        case "a_rain":
            let c = ahead(p, 70)
            for k in 0..<6 { schedule(Double(k) * 0.2, p.map, c, radius: 30, damage: power, owner: p.id, element: e, fx: k == 0 ? .rain(radius: 30) : nil) }
            effect(.rain(radius: 30), p.map, c, e, duration: 1.2)
        case "a_poison":
            fire(from: p, angle: angle, kind: .poisonArrow, damage: power, speed: 240, range: 180, element: .poison)
        case "a_back":
            var to = p.pos
            for s in stride(from: 6.0, through: 54, by: 6) {
                let c = CGPoint(x: p.pos.x - CGFloat(cos(angle) * s), y: p.pos.y - CGFloat(sin(angle) * s))
                if map(p.map).canStand(c) { to = c } else { break }
            }
            players[i].dash = (to, [], 0)
            players[i].posLockUntil = time + 0.5
            players[i].invulnerable = 0.35
            for d in [-0.4, -0.2, 0.0, 0.2, 0.4] { fire(from: p, angle: angle + d, kind: .arrow, damage: power, speed: 250, range: 180) }
        case "a_trap":
            traps.append(RpgTrap(map: p.map, pos: p.pos, ownerID: p.id, damage: power, expires: time + 20, armedAt: time + 0.5))
            toast("덫 설치!")
        case "a_focus":
            players[i].focusUntil = time + 12
            effect(.levelUp, p.map, p.pos, .wind, duration: 1)
            toast("집중! 치명타·공격속도 상승")
        case "a_ult":
            for d in [-0.2, -0.1, 0.0, 0.1, 0.2] { fire(from: p, angle: angle + d, kind: .bigArrow, damage: power, speed: 340, range: 260) }
            shake = max(shake, 1.2)
        case "m_blast":
            mageBlast(at: ahead(p, 56), p, power)
        case "m_chain":
            var points = [CGPoint(x: p.pos.x, y: p.pos.y - 8)]
            var used: Set<Int> = []
            var from = p.pos
            let el: RpgElement = e == .base ? .thunder : e
            for _ in 0..<4 {
                guard let next = (mobs[p.map] ?? []).filter({ !$0.dead && !$0.airborne && !used.contains($0.id) && dist($0.pos, from) < 95 })
                        .min(by: { dist($0.pos, from) < dist($1.pos, from) }) else { break }
                used.insert(next.id)
                points.append(CGPoint(x: next.pos.x, y: next.pos.y - 6))
                from = next.pos
                damageMob(next.id, map: p.map, base: power, by: p.id, element: el, skill: true)
            }
            if points.count > 1 { effect(.chain(points), p.map, p.pos, el, duration: 0.35) } else { toast("주변에 적이 없어요"); refund = true }
        case "m_blink":
            var to = p.pos
            for s in stride(from: 6.0, through: 84, by: 6) {
                let c = CGPoint(x: p.pos.x + CGFloat(cos(angle) * s), y: p.pos.y + CGFloat(sin(angle) * s))
                if map(p.map).canStand(c) { to = c }
            }
            effect(.burst(radius: 24), p.map, p.pos, e == .base ? .cosmic : e)
            hitArea(p.pos, 24, p, power, e)
            players[i].pos = to
            players[i].posLockUntil = time + 0.5
            players[i].invulnerable = 0.3
            effect(.levelUp, p.map, to, .cosmic, duration: 0.4)
        case "m_shield":
            players[i].shieldUntil = time + 15
            toast("마나 실드!")
        case "m_blizzard":
            let c = ahead(p, 60)
            for k in 0..<10 { schedule(Double(k) * 0.4, p.map, c, radius: 40, damage: power, owner: p.id, element: .ice, fx: .ice(radius: 34)) }
        case "m_pillar":
            for k in 1...7 {
                schedule(Double(k) * 0.07, p.map, ahead(p, Double(k) * 17), radius: 18, damage: power, owner: p.id, element: .fire, fx: .burst(radius: 16))
            }
        case "m_heal":
            let amount = p.maxHP * (0.3 + 0.03 * Double(lv - 1))
            for k in players.indices where players[k].map == p.map && !players[k].dead && dist(players[k].pos, p.pos) < 70 {
                players[k].hp = min(players[k].maxHP, players[k].hp + amount)
                float("+\(Int(amount))", p.map, players[k].pos, .heal)
                effect(.levelUp, p.map, players[k].pos, .wind, duration: 1)
            }
        case "m_ult":
            for k in 0..<8 {
                let a = rand(0, .pi * 2), d = rand(20, 110)
                let c = CGPoint(x: p.pos.x + CGFloat(cos(a) * d), y: p.pos.y + CGFloat(sin(a) * d * 0.7))
                effect(.telegraph(radius: 30), p.map, c, .cosmic, duration: 0.25 + Double(k) * 0.18)
                schedule(0.25 + Double(k) * 0.18, p.map, c, radius: 32, damage: power, owner: p.id, element: .cosmic, fx: .meteor(radius: 32))
            }
        // 2차 전직 skills (RpgJobs)
        case "j_bash":
            let c = ahead(p, 18)
            effect(.burst(radius: 24), p.map, c, e)
            effect(.slash(angle: angle, radius: 14), p.map, c, e)
            for v in mobIDs(near: c, radius: 26, map: p.map) { damageMob(v, map: p.map, base: power, by: p.id, element: e, skill: true, stun: 1.5) }
            players[i].invulnerable = max(players[i].invulnerable, 0.3)
            shake = max(shake, 0.6)
        case "j_aegis":
            let heal = p.maxHP * 0.25
            players[i].hp = min(p.maxHP, p.hp + heal)
            players[i].ironUntil = time + 8
            float("+\(Int(heal))", p.map, p.pos, .heal)
            effect(.levelUp, p.map, p.pos, .holy, duration: 1.2)
            toast("수호의 성역! 받는 피해 감소")
        case "j_bloodslash":
            let c = ahead(p, 16)
            for a in [-0.5, 0.0, 0.5] { effect(.slash(angle: angle + a, radius: 17), p.map, c, .fire, duration: 0.3) }
            hitArea(c, 40, p, power, e)
            shake = max(shake, 0.8)
        case "j_frenzy":
            players[i].frenzyUntil = time + 10
            players[i].cycloneUntil = time + 3
            players[i].nextCyclone = time
            effect(.levelUp, p.map, p.pos, .fire, duration: 1)
            toast("광기! 공격력 상승")
        case "j_snipe":
            fire(from: p, angle: angle, kind: .bigArrow, damage: power, speed: 420, range: 320)
            shake = max(shake, 0.5)
        case "j_deadeye":
            for d in [-0.04, 0.0, 0.04] { fire(from: p, angle: angle + d, kind: .bigArrow, damage: power, speed: 380, range: 300) }
        case "j_volley":
            for k in 0..<8 { fire(from: p, angle: angle + (Double(k) - 3.5) * 0.1, kind: .arrow, damage: power, speed: 240, range: 175) }
        case "j_net":
            for k in 1...3 {
                traps.append(RpgTrap(map: p.map, pos: ahead(p, Double(k) * 22), ownerID: p.id, damage: power, expires: time + 20, armedAt: time + 0.4))
            }
            toast("그물 덫 설치!")
        case "j_inferno":
            let c = ahead(p, 50)
            for k in 0..<6 {
                let at = CGPoint(x: c.x + CGFloat(rand(-16, 16)), y: c.y + CGFloat(rand(-12, 12)))
                schedule(Double(k) * 0.18, p.map, at, radius: 34, damage: power, owner: p.id, element: .fire, fx: .burst(radius: 30))
            }
        case "j_firestorm":
            for k in 0..<5 {
                let a = rand(0, .pi * 2), d = rand(20, 100)
                let c = CGPoint(x: p.pos.x + CGFloat(cos(a) * d), y: p.pos.y + CGFloat(sin(a) * d * 0.7))
                effect(.telegraph(radius: 28), p.map, c, .fire, duration: 0.25 + Double(k) * 0.16)
                schedule(0.25 + Double(k) * 0.16, p.map, c, radius: 30, damage: power, owner: p.id, element: .fire, fx: .meteor(radius: 30))
            }
        case "j_frost":
            effect(.ice(radius: 60), p.map, p.pos, .ice, duration: 0.5)
            hitArea(p.pos, 64, p, power, .ice)
        case "j_glacier":
            let c = ahead(p, 55)
            for k in 0..<12 { schedule(Double(k) * 0.3, p.map, c, radius: 46, damage: power, owner: p.id, element: .ice, fx: .ice(radius: 40)) }
        default:
            refund = true
        }
        if !refund {
            players[i].mp -= Double(def.mp)
            players[i].cooldowns[skill] = def.cooldown
        }
    }

    private func mageBlast(at target: CGPoint, _ p: RpgPlayer, _ power: Double) {
        switch p.element {
        case .fire:
            effect(.burst(radius: 30), p.map, target, .fire, duration: 0.35)
            hitArea(target, 32, p, power * 1.1, .fire)
        case .ice:
            effect(.ice(radius: 30), p.map, target, .ice, duration: 0.4)
            hitArea(target, 32, p, power * 0.95, .ice)
        case .thunder:
            effect(.strike, p.map, target, .thunder, duration: 0.3)
            hitArea(target, 30, p, power, .thunder)
        case .cosmic:
            effect(.meteor(radius: 38), p.map, target, .cosmic, duration: 0.45)
            hitArea(target, 40, p, power * 1.35, .cosmic)
            shake = max(shake, 1.2)
        default:
            effect(.burst(radius: 28), p.map, target, p.element, duration: 0.3)
            hitArea(target, 30, p, power, p.element)
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

    private func stepPending() {
        guard !pending.isEmpty else { return }
        let due = pending.filter { time >= $0.at }
        pending.removeAll { time >= $0.at }
        for h in due {
            if let k = h.fx { effect(k, h.map, h.pos, h.element, duration: 0.35) }
            if h.fromPlayer {
                for v in mobIDs(near: h.pos, radius: h.radius, map: h.map) {
                    damageMob(v, map: h.map, base: h.damage, by: h.ownerID, element: h.element, skill: true, stun: h.stun)
                }
            } else {
                for i in players.indices where players[i].map == h.map && !players[i].dead && dist(players[i].pos, h.pos) < h.radius {
                    hurtPlayer(i, h.damage, from: h.pos, by: mobName(h.ownerID))
                }
                shake = max(shake, 1)
            }
        }
    }

    private func stepTraps() {
        guard !traps.isEmpty else { return }
        var keep: [RpgTrap] = []
        for t in traps {
            let triggered = time >= t.armedAt && !mobIDs(near: t.pos, radius: 10, map: t.map).isEmpty
            if triggered || time >= t.expires {
                if triggered {
                    effect(.burst(radius: 30), t.map, t.pos, .fire, duration: 0.4)
                    for v in mobIDs(near: t.pos, radius: 32, map: t.map) { damageMob(v, map: t.map, base: t.damage, by: t.ownerID, element: .base, skill: true, stun: 1.5) }
                }
                continue
            }
            keep.append(t)
        }
        traps = keep
    }

    // MARK: damage

    private func damageMob(_ id: Int, map: RpgMapID, base: Double, by playerID: Int, element: RpgElement, skill: Bool, splash: Bool = false, stun: Double = 0) {
        guard var list = mobs[map], let k = list.firstIndex(where: { $0.id == id }), !list[k].dead, !list[k].airborne,
              let pi = pIndex(playerID) else { return }
        let p = players[pi]
        var m = list[k]
        let crit = !splash && Double(rng.int(1000)) / 1000 < p.critChance(at: time)
        var dmg = max(1, base - Double(m.def.defense) * 0.6) * rand(0.9, 1.1)
        if crit { dmg *= 1.7 }
        m.hp -= dmg
        m.hurtFlash = 0.12
        m.lastHitBy = playerID
        if m.def.behavior == .boss { m.contributors.insert(playerID); if m.engagedAt == 0 { m.engagedAt = time } }
        if m.def.behavior != .boss {
            let dx = Double(m.pos.x - p.pos.x), dy = Double(m.pos.y - p.pos.y), d = max(1, hypot(dx, dy))
            m.knock = CGVector(dx: dx / d * (skill ? 140 : 90), dy: dy / d * (skill ? 140 : 90))
        }
        m.targetID = playerID
        m.aggroUntil = time + 8
        if stun > 0 { m.stunUntil = max(m.stunUntil, time + (m.def.behavior == .boss ? stun * 0.3 : stun)) }
        switch element {
        case .fire: m.dotTicks = 3; m.dotDamage = dmg * 0.15; m.nextDot = time + 0.6; m.dotElement = .fire
        case .poison: m.dotTicks = 8; m.dotDamage = dmg * 0.3; m.nextDot = time + 0.5; m.dotElement = .poison
        case .ice: m.slowUntil = time + 1.8
        case .thunder where rng.int(100) < 18: m.stunUntil = max(m.stunUntil, time + (m.def.behavior == .boss ? 0.2 : 0.7))
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
        if let mm = mobs[map]?.first(where: { $0.id == id }), mm.hp <= 0, !mm.dead { killMob(id, map: map, by: playerID) }
    }

    private func killMob(_ id: Int, map: RpgMapID, by playerID: Int) {
        guard var list = mobs[map], let k = list.firstIndex(where: { $0.id == id }) else { return }
        var m = list[k]
        m.dead = true
        m.diedAt = time
        m.dotTicks = 0
        m.respawnAt = m.summoned || map == .tower ? .infinity : time + (m.def.behavior == .boss ? 90 : (m.def.behavior == .coward ? 30 : Self.respawnDelay))
        list[k] = m
        mobs[map] = list
        if m.def.behavior == .boss {
            effect(.burst(radius: 50), map, m.pos, .holy, duration: 0.6)
            shake = 2
            toast("\(m.def.name)을(를) 쓰러뜨렸다!", to: nil)
            pending.removeAll { !$0.fromPlayer && $0.map == map }
        }
        // Everyone in the killer's party on this map and nearby shares the kill.
        let killerPos = player(playerID)?.pos ?? m.pos
        let boss = m.def.behavior == .boss
        var shared = partyMembers(of: playerID).filter { id in
            guard let p = player(id), p.map == map, !p.dead else { return false }
            return id == playerID || boss || dist(p.pos, killerPos) < 320
        }
        if boss { shared = Array(Set(shared).union(m.contributors.filter { pIndex($0) != nil })).sorted() }
        if shared.isEmpty { shared = [playerID] }
        if !m.summoned, let ki = pIndex(playerID) {
            players[ki].combo += 1
            players[ki].comboUntil = time + Self.comboWindow
            players[ki].bestCombo = max(players[ki].bestCombo, players[ki].combo)
            if [5, 10, 25, 50, 100].contains(players[ki].combo) { toast("콤보 ×\(players[ki].combo)!", to: playerID) }
        }
        let eliteMul: Double = m.elite ? 4 : 1
        let comboGold = (1 + Self.comboBonus(player(playerID)?.combo ?? 0)) * eliteMul
        if !m.summoned || rng.int(3) == 0 {
            let gold = Int(Double(Int.random(in: m.def.gold) / (m.summoned ? 3 : 1) * (boss ? shared.count : 1)) * comboGold)
            drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(9) - 4), y: m.pos.y + CGFloat(rng.int(5) - 2)),
                                    gold: gold, item: nil, at: time))
        }
        if !m.summoned {
            // Bosses roll their loot once per participant (personal loot); other monsters roll once and the
            // item is reserved for the next party member in turn.
            var rolls = boss ? shared : [shared[lootTurn % shared.count]]
            if !boss { lootTurn += 1 }
            if boss {
                // Personal boss loot once per 30 minutes per player; locked players still get XP and gold.
                let now = Date().timeIntervalSince1970
                rolls = rolls.filter { id in
                    guard let pi = pIndex(id) else { return false }
                    if let last = players[pi].bossLoot[m.def.id], now - last < Self.bossLootLockout {
                        toast("\(m.def.name) 보상 쿨타임 — \(Int((Self.bossLootLockout - (now - last)) / 60) + 1)분 남음", to: id)
                        return false
                    }
                    players[pi].bossLoot[m.def.id] = now
                    return true
                }
                // Raid bonus (3+ players): a bundle of stones each and a small shot at mythic gear.
                if shared.count >= 3 {
                    for owner in rolls {
                        guard let p = player(owner) else { continue }
                        let mythic = p.cls == .warrior ? "sword8" : (p.cls == .archer ? "bow8" : "staff8")
                        var bonus = Array(repeating: "stone", count: 3 + shared.count)
                        if rng.int(1000) < 15 + 2 * m.def.level / 10 { bonus.append(rng.int(2) == 0 ? mythic : "armor7") }
                        for item in bonus {
                            drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(41) - 20), y: m.pos.y + CGFloat(rng.int(21) - 10)),
                                                    gold: 0, item: item, at: time, owner: owner))
                        }
                        toast("레이드 보상 획득!", to: owner)
                    }
                }
            }
            for owner in rolls {
                let luck = ((player(owner)?.hardcore ?? false) ? Self.hardcoreReward : 1) * (m.elite ? 3 : 1)
                for d in m.def.drops where Double(rng.int(10_000)) / 10_000 < d.chance * luck {
                    drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(31) - 15), y: m.pos.y + CGFloat(rng.int(17) - 8)),
                                            gold: 0, item: d.item, at: time, owner: shared.count > 1 ? owner : nil))
                }
            }
        }
        if m.elite {
            drops.append(RpgDropped(id: newID(), map: map, pos: CGPoint(x: m.pos.x + CGFloat(rng.int(15) - 7), y: m.pos.y + CGFloat(rng.int(9) - 4)),
                                    gold: 0, item: "stone", at: time, owner: shared.count > 1 ? playerID : nil))
            toast("★ 황금 \(m.def.name)을(를) 쓰러뜨렸다!", to: nil)
        }
        for id in shared {
            guard let pi = pIndex(id) else { continue }
            if !m.summoned { players[pi].kills[m.def.id, default: 0] += 1 }
            if m.elite { players[pi].eliteKills += 1 }
            checkAchievements(pi)
            for q in players[pi].quests.indices where players[pi].quests[q].monster == m.def.id && !players[pi].quests[q].done {
                players[pi].quests[q].progress += 1
                if players[pi].quests[q].done { toast("의뢰 달성! 의뢰소에서 보상을 받으세요", to: id) }
            }
        }
        // XP: each member gets max(40%, (1 + 10% per extra member) / members) of the kill.
        let n = Double(shared.count)
        let share = max(0.4, (1 + 0.1 * (n - 1)) / n)
        for id in shared {
            // Farming far below your level barely pays: move on to the next zone.
            let gap = (player(id)?.level ?? 1) - m.def.level
            let base = Double(m.summoned ? m.def.xp / 3 : m.def.xp) * (shared.count > 1 ? share : 1)
            let bonus = (1 + Self.comboBonus(player(id)?.combo ?? 0)) * eliteMul
            grantXP(id, max(1, Int((gap > 5 ? base / 5 : base) * bonus)))
        }
    }

    func partyMembers(of id: Int) -> [Int] {
        guard let p = player(id), let party = p.partyID else { return [id] }
        return players.filter { $0.partyID == party }.map(\.id)
    }

    private func leaveParty(_ i: Int) {
        guard let party = players[i].partyID else { return }
        let name = players[i].name
        players[i].partyID = nil
        let rest = players.indices.filter { players[$0].partyID == party }
        for k in rest { toast("\(name) 님이 파티를 나갔어요", to: players[k].id) }
        // A party of one is no party.
        if rest.count == 1 { players[rest[0]].partyID = nil }
    }

    private func grantXP(_ playerID: Int, _ amount: Int) {
        guard let i = pIndex(playerID) else { return }
        float("+\(amount) XP", players[i].map, CGPoint(x: players[i].pos.x, y: players[i].pos.y - 10), .xp)
        guard players[i].level < RpgMaps.maxLevel else { return }
        players[i].xp += players[i].hardcore ? Int(Double(amount) * Self.hardcoreReward) : amount
        while players[i].level < RpgMaps.maxLevel, players[i].xp >= RpgMaps.xpNeeded(players[i].level) {
            players[i].xp -= RpgMaps.xpNeeded(players[i].level)
            players[i].level += 1
            players[i].sp += players[i].level % 10 == 0 ? 2 : 1
            players[i].hp = players[i].maxHP
            players[i].mp = players[i].maxMP
            effect(.levelUp, players[i].map, players[i].pos, .holy, duration: 1.0)
            toast("레벨 업! Lv\(players[i].level)  (스킬 포인트 +\(players[i].level % 10 == 0 ? 2 : 1))")
            let unlock = RpgSkills.all.filter { $0.cls == players[i].cls && $0.minLevel == players[i].level }
            for s in unlock { toast("\(s.name) 스킬북을 쓸 수 있는 레벨이 됐어요") }
            if players[i].level == RpgJobs.advanceLevel, players[i].job == 0 { toast("마을의 전직관을 찾아가 2차 전직을 하세요!") }
            learnJobSkills(i)
            checkAchievements(i)
        }
    }

    private func mobName(_ id: Int) -> String {
        for list in mobs.values { if let m = list.first(where: { $0.id == id }) { return m.def.name } }
        return "알 수 없는 힘"
    }

    private func hurtPlayer(_ i: Int, _ raw: Double, from p: CGPoint, by cause: String = "알 수 없는 힘") {
        guard !players[i].dead, players[i].invulnerable <= 0, players[i].dash == nil else { return }
        let previousActor = actor
        actor = players[i].id
        defer { actor = previousActor }
        var dmg = max(1, raw - players[i].defense * 0.5) * rand(0.9, 1.1)
        if players[i].hardcore { dmg *= Self.hardcoreDamage }
        if time < players[i].ironUntil { dmg *= 0.6 }
        if time < players[i].shieldUntil {
            let toMP = min(players[i].mp, dmg * 0.7)
            players[i].mp -= toMP
            dmg -= toMP
        }
        players[i].hp -= dmg
        players[i].invulnerable = 0.55
        players[i].hurtFlash = 0.2
        players[i].lastHurt = time
        float("-\(Int(dmg))", players[i].map, players[i].pos, .hurt)
        shake = max(shake, 0.6)
        let dx = Double(players[i].pos.x - p.x), dy = Double(players[i].pos.y - p.y), d = max(1, hypot(dx, dy))
        let shove = CGPoint(x: players[i].pos.x + CGFloat(dx / d * 6), y: players[i].pos.y + CGFloat(dy / d * 6))
        if map(players[i].map).canStand(shove) { players[i].pos = shove }
        if players[i].hp <= 0, players[i].hardcore {
            // Hardcore: no coming back. A tombstone marks the spot for everyone who passes by.
            players[i].hp = 0
            players[i].dead = true
            players[i].fallen = true
            players[i].respawnAt = .infinity
            players[i].cycloneUntil = 0
            let p = players[i]
            let grave = RpgGrave(name: p.name, cls: p.cls, level: p.level, map: p.map, x: Double(p.pos.x), y: Double(p.pos.y),
                                 cause: cause, date: Date().timeIntervalSince1970)
            addGraves([grave])
            effect(.burst(radius: 30), p.map, p.pos, .cosmic, duration: 0.6)
            toast("☠ Lv\(p.level) \(p.name) 님이 \(cause)에게 쓰러져 영원히 잠들었습니다", to: nil)
            return
        }
        if players[i].hp <= 0 {
            players[i].hp = 0
            players[i].dead = true
            players[i].respawnAt = time + 3
            players[i].cycloneUntil = 0
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
        // Raid scaling: a boss grows (never shrinks mid-fight) with everyone standing in its room.
        let crowd = Double(max(1, players.filter { $0.map == mapID }.count))
        for k in list.indices where list[k].def.behavior == .boss && !list[k].dead {
            let want = 1 + 0.9 * (crowd - 1)
            if want > list[k].hpScale { list[k].hp *= want / list[k].hpScale; list[k].hpScale = want }
        }
        var spawned: [RpgMob] = []
        for k in list.indices {
            var mob = list[k]
            if mob.dead {
                if time >= mob.respawnAt {
                    let p = mob.def.behavior == .boss ? mob.home : randomSpawn(m)
                    mob = newMob(id: mob.id, def: mob.def, at: p, canBeElite: !mob.summoned)
                }
                list[k] = mob
                continue
            }
            mob.hurtFlash = max(0, mob.hurtFlash - dt)
            mob.attackTimer = max(0, mob.attackTimer - dt)
            if mob.dotTicks > 0, time >= mob.nextDot {
                mob.dotTicks -= 1
                mob.nextDot = time + (mob.dotElement == .poison ? 0.5 : 0.6)
                mob.hp -= mob.dotDamage
                floaters.append(RpgFloater(text: "\(Int(mob.dotDamage))", map: mapID, pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 16), life: 0.6,
                                           style: mob.dotElement == .poison ? .poison : .crit))
                if mob.hp <= 0 {
                    list[k] = mob
                    mobs[mapID] = list
                    killMob(mob.id, map: mapID, by: mob.lastHitBy ?? players.first?.id ?? 0)
                    list = mobs[mapID] ?? list
                    continue
                }
            }
            if hypot(mob.knock.dx, mob.knock.dy) > 1 {
                let np = CGPoint(x: mob.pos.x + mob.knock.dx * CGFloat(dt), y: mob.pos.y + mob.knock.dy * CGFloat(dt))
                if mob.flies || m.canStand(np) { mob.pos = np }
                mob.knock = CGVector(dx: mob.knock.dx * CGFloat(max(0, 1 - dt * 10)), dy: mob.knock.dy * CGFloat(max(0, 1 - dt * 10)))
            }
            if time < mob.stunUntil { list[k] = mob; continue }
            let speedK = time < mob.slowUntil ? 0.5 : 1.0
            let nearest = here.min { dist(players[$0].pos, mob.pos) < dist(players[$1].pos, mob.pos) }
            if let t = mob.targetID, !here.contains(where: { players[$0].id == t }) { mob.targetID = nil }
            if mob.targetID == nil, let n = nearest {
                let d = dist(players[n].pos, mob.pos)
                let aggro: Double = switch mob.def.behavior {
                case .aggressive: 80
                case .flyer: 90
                case .ranged: 120
                case .boss: 200
                case .swarm: 100
                case .charger: 110
                case .exploder: 100
                default: 0
                }
                if d < aggro { mob.targetID = players[n].id; mob.aggroUntil = time + 8 }
            }
            // A pack moves as one: when one swarm monster has a target, the idle ones of its kind nearby join in.
            if mob.def.behavior == .swarm, let t = mob.targetID {
                for b in list.indices where b != k && !list[b].dead && list[b].targetID == nil && list[b].def.id == mob.def.id && dist(list[b].pos, mob.pos) < 90 {
                    list[b].targetID = t
                    list[b].aggroUntil = time + 8
                }
            }
            if mob.targetID != nil, time > mob.aggroUntil, mob.def.behavior == .passive { mob.targetID = nil }
            if dist(mob.pos, mob.home) > 260, mob.def.behavior != .boss, !mob.summoned { mob.targetID = nil; mob.wanderTo = mob.home }

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
                    walk(to: CGPoint(x: mob.pos.x * 2 - players[n].pos.x, y: mob.pos.y * 2 - players[n].pos.y), mob.def.speed)
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
                        let magic = mob.def.id == "shadowmage"
                        shots.append(RpgShot(pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 6), vel: CGVector(dx: dx / l * 150, dy: dy / l * 150), map: mapID,
                                             fromPlayer: false, ownerID: mob.id, damage: Double(mob.def.attack) * (mob.elite ? Self.eliteAttack : 1), element: magic ? .cosmic : .base,
                                             kind: magic ? .bossOrb : .mobArrow, life: 1.4))
                    }
                } else if let w = wanderGoal(&mob) { walk(to: w, mob.def.speed * 0.45) }
            case .charger:
                if let t = target {
                    let tp = players[t].pos, d = dist(tp, mob.pos)
                    let power = Double(mob.def.attack) * (mob.elite ? Self.eliteAttack : 1)
                    if let dir = mob.chargeDir {
                        // Dashing in a straight line: hits whoever is in the way, then needs a moment to recover.
                        let np = CGPoint(x: mob.pos.x + dir.dx * CGFloat(260 * speedK * dt), y: mob.pos.y + dir.dy * CGFloat(260 * speedK * dt))
                        if m.canStand(np) { mob.pos = np }
                        mob.facingRight = dir.dx > 0
                        let blocked = !m.canStand(np)
                        if dist(players[t].pos, mob.pos) < 14 {
                            hurtPlayer(t, power * 1.6, from: mob.pos, by: mob.def.name)
                            mob.chargeDir = nil; mob.stunUntil = time + 0.8; mob.attackTimer = 1.5
                        } else if blocked || time >= mob.phaseUntil {
                            mob.chargeDir = nil; mob.stunUntil = time + 1.2; mob.attackTimer = 1.5
                        }
                    } else if let w = mob.windup {
                        mob.windup = w - dt
                        mob.facingRight = tp.x > mob.pos.x
                        if w - dt <= 0 {
                            mob.windup = nil
                            let l = max(1, d)
                            mob.chargeDir = CGVector(dx: (tp.x - mob.pos.x) / l, dy: (tp.y - mob.pos.y) / l)
                            mob.phaseUntil = time + 0.55
                        }
                    } else if d < 110, d > 24, mob.attackTimer <= 0 {
                        mob.windup = 0.6
                    } else if d >= 20 {
                        walk(to: tp, mob.def.speed)
                    }
                } else if let w = wanderGoal(&mob) { walk(to: w, mob.def.speed * 0.45) }
            case .exploder:
                if let t = target {
                    let tp = players[t].pos, d = dist(tp, mob.pos)
                    if let w = mob.windup {
                        mob.windup = w - dt
                        if w - dt <= 0 {
                            // Blows itself up: no XP or drops for it, but it hurts everyone close.
                            effect(.burst(radius: 40), mapID, mob.pos, .fire, duration: 0.4)
                            shake = max(shake, 0.6)
                            for i in here where dist(players[i].pos, mob.pos) < 38 {
                                hurtPlayer(i, Double(mob.def.attack) * 2.2 * (mob.elite ? Self.eliteAttack : 1), from: mob.pos, by: mob.def.name)
                            }
                            mob.dead = true
                            mob.diedAt = time
                            mob.respawnAt = time + Self.respawnDelay + 2
                            mob.windup = nil
                        }
                    } else if d < 26 {
                        mob.windup = 0.8
                    } else {
                        walk(to: tp, mob.def.speed)
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
                            if dist(players[t].pos, mob.pos) < 20 { hurtPlayer(t, Double(mob.def.attack) * (mob.elite ? Self.eliteAttack : 1), from: mob.pos, by: mob.def.name) }
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
            // Touching a monster hurts (bosses have their own body slam); the hit's brief invulnerability
            // keeps standing in a crowd from melting you instantly.
            if mob.def.attack > 0, mob.def.behavior != .boss, !mob.airborne, !mob.dead {
                for i in here where dist(players[i].pos, mob.pos) < Double(mob.radius) + 7 {
                    hurtPlayer(i, Double(mob.def.attack) * 0.7 * (mob.elite ? Self.eliteAttack : 1), from: mob.pos, by: mob.def.name)
                }
            }
            list[k] = mob
        }
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
        list.removeAll { $0.dead && $0.summoned && time - $0.diedAt > 1 }
        list += spawned
        mobs[mapID] = list
    }

    private func wanderGoal(_ mob: inout RpgMob) -> CGPoint? {
        if time >= mob.nextWander {
            mob.nextWander = time + rand(2, 5)
            let a = rand(0, .pi * 2), r = rand(10, 50)
            mob.wanderTo = CGPoint(x: mob.home.x + CGFloat(cos(a) * r), y: mob.home.y + CGFloat(sin(a) * r))
        }
        if let w = mob.wanderTo, dist(w, mob.pos) < 3 { mob.wanderTo = nil }
        return mob.wanderTo
    }

    private enum BossMove { case chase, jump, ring, summon, marks, charge, blink }

    private func bossMoves(_ style: RpgBossStyle) -> [BossMove] {
        switch style {
        case .slime: return [.chase, .jump, .ring, .summon]
        case .golem: return [.chase, .jump, .marks, .ring, .summon]
        case .yeti: return [.chase, .charge, .ring, .summon, .charge, .jump]
        case .skeleton: return [.chase, .ring, .summon, .marks, .jump]
        case .demon: return [.chase, .blink, .marks, .ring, .summon, .blink, .jump]
        }
    }

    /// Bosses cycle through their move list; below 40% HP everything comes faster and harder.
    private func bossThink(_ mob: inout RpgMob, _ target: RpgPlayer, _ dt: Double, _ mapID: RpgMapID, _ spawned: inout [RpgMob]) {
        let enraged = mob.hp < Double(mob.def.hp) * mob.hpScale * 0.4
        // Eight minutes after the first hit the boss goes berserk: triple damage, double speed.
        let berserk = mob.engagedAt > 0 && time - mob.engagedAt > Self.berserkAfter
        let pace = berserk ? 0.45 : (enraged ? 0.7 : 0.9)
        let raid = false   // reserved for a future heroic mode
        let moves = bossMoves(mob.def.bossStyle)
        let atk = Double(mob.def.attack) * (1 + 0.03 * (mob.hpScale - 1)) * (berserk ? 3 : 1)
        let el = mob.def.element
        if time >= mob.phaseUntil {
            mob.phase = (mob.phase + 1) % moves.count
            mob.chargeDir = nil
            switch moves[mob.phase] {
            case .chase:
                mob.phaseUntil = time + 2.6 * pace
            case .jump:
                mob.jumpTarget = target.pos
                mob.airborne = true
                mob.phaseUntil = time + 1.0 * pace
                effect(.telegraph(radius: 34), mapID, target.pos, .base, duration: 1.0 * pace)
                schedule(1.0 * pace, mapID, target.pos, radius: 34, damage: atk * 1.5, owner: mob.id, fromPlayer: false, element: el, fx: .burst(radius: 34))
            case .ring:
                mob.phaseUntil = time + 1.6 * pace
                for wave in 0..<((enraged ? 3 : 2) + (raid ? 1 : 0)) {
                    let n = mob.def.bossStyle == .demon ? 16 : 12
                    for k in 0..<n {
                        let a = Double(k) / Double(n) * .pi * 2 + Double(wave) * 0.26
                        let sp = 95 + Double(wave) * 30
                        shots.append(RpgShot(pos: CGPoint(x: mob.pos.x, y: mob.pos.y - 12), vel: CGVector(dx: cos(a) * sp, dy: sin(a) * sp), map: mapID,
                                             fromPlayer: false, ownerID: mob.id, damage: atk * 0.7, element: el,
                                             kind: mob.def.bossStyle == .slime ? .slimeBall : .bossOrb, life: 2.4))
                    }
                }
            case .summon:
                mob.phaseUntil = time + 1.2 * pace
                let alive = (mobs[mapID] ?? []).filter { !$0.dead && $0.summoned }.count + spawned.count
                if alive < 8 {
                    for k in 0..<(enraged ? 4 : 3) {
                        let a = Double(k) / 3 * .pi * 2
                        let p = CGPoint(x: mob.pos.x + CGFloat(cos(a) * 34), y: mob.pos.y + CGFloat(sin(a) * 22))
                        let def = RpgMonsters.def(mob.def.minion)
                        var s = RpgMob(id: newID(), def: def, pos: p, home: p, hp: Double(def.hp))
                        s.targetID = target.id
                        s.aggroUntil = time + 30
                        s.summoned = true
                        spawned.append(s)
                    }
                    effect(.burst(radius: 34), mapID, mob.pos, .wind, duration: 0.4)
                }
            case .marks:
                mob.phaseUntil = time + 1.8 * pace
                let count = (enraged ? 7 : 5) + (raid ? 2 : 0)
                for k in 0..<count {
                    let jitter = k == 0 ? CGPoint.zero : CGPoint(x: rand(-60, 60), y: rand(-40, 40))
                    let c = CGPoint(x: target.pos.x + jitter.x, y: target.pos.y + jitter.y)
                    let delay = 0.9 + Double(k) * 0.12
                    effect(.telegraph(radius: 26), mapID, c, el, duration: delay)
                    schedule(delay, mapID, c, radius: 26, damage: atk * 1.3, owner: mob.id, fromPlayer: false, element: el,
                             fx: mob.def.bossStyle == .demon ? .meteor(radius: 26) : .burst(radius: 26))
                }
            case .charge:
                mob.phaseUntil = time + 0.9
                let dx = Double(target.pos.x - mob.pos.x), dy = Double(target.pos.y - mob.pos.y), l = max(1, hypot(dx, dy))
                mob.chargeDir = CGVector(dx: dx / l, dy: dy / l)
                effect(.telegraph(radius: 20), mapID, mob.pos, el, duration: 0.3)
            case .blink:
                mob.phaseUntil = time + 0.8
                effect(.burst(radius: 30), mapID, mob.pos, .cosmic, duration: 0.3)
                let a = rand(0, .pi * 2)
                let p = CGPoint(x: target.pos.x + CGFloat(cos(a) * 50), y: target.pos.y + CGFloat(sin(a) * 34))
                if map(mapID).canStand(p, radius: 10) { mob.pos = p }
                effect(.burst(radius: 30), mapID, mob.pos, .cosmic, duration: 0.3)
            }
        }
        switch moves[mob.phase] {
        case .chase:
            let dx = Double(target.pos.x - mob.pos.x), dy = Double(target.pos.y - mob.pos.y), d = hypot(dx, dy)
            if d > 4 {
                let s = min(d, mob.def.speed * (enraged ? 1.4 : 1) * dt)
                let np = CGPoint(x: mob.pos.x + CGFloat(dx / d * s), y: mob.pos.y + CGFloat(dy / d * s))
                if map(mapID).canStand(np, radius: 8) { mob.pos = np }
                mob.facingRight = dx > 0
            }
            if d < 24, mob.attackTimer <= 0, let ti = pIndex(target.id) {
                mob.attackTimer = 1
                hurtPlayer(ti, atk, from: mob.pos, by: mob.def.name)
            }
        case .jump:
            if let jt = mob.jumpTarget, time >= mob.phaseUntil - 0.05 {
                mob.pos = jt
                mob.airborne = false
                mob.jumpTarget = nil
                shake = max(shake, 2)
                mob.phaseUntil = time + 0.5
            }
        case .charge:
            if let dir = mob.chargeDir {
                let np = CGPoint(x: mob.pos.x + dir.dx * CGFloat(260 * dt), y: mob.pos.y + dir.dy * CGFloat(260 * dt))
                if map(mapID).canStand(np, radius: 8) { mob.pos = np } else { mob.chargeDir = nil; shake = max(shake, 1.5) }
                mob.facingRight = dir.dx > 0
                for i in players.indices where players[i].map == mapID && dist(players[i].pos, mob.pos) < 22 { hurtPlayer(i, atk * 1.3, from: mob.pos, by: mob.def.name) }
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
            let tile = m.at(Int(foot.x / 16), Int(foot.y / 16))
            if m.isBlocked(foot), tile != .water, tile != .lava {
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
                        damageMob(v, map: s.map, base: s.damage, by: s.ownerID, element: s.element, skill: s.kind == .bigArrow || s.kind == .poisonArrow)
                    }
                    if !s.pierce { done = true; break }
                }
                if done { continue }
            } else if let i = players.indices.first(where: { players[$0].map == s.map && !players[$0].dead && dist(players[$0].pos, foot) < 8 }) {
                hurtPlayer(i, s.damage, from: s.pos, by: mobName(s.ownerID))
                continue
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
            let reserved = d.owner != nil && time - d.at < 30
            guard time - d.at > 0.35,
                  let i = players.indices.first(where: {
                      players[$0].map == d.map && !players[$0].dead && dist(players[$0].pos, d.pos) < 26 && (!reserved || players[$0].id == d.owner)
                  })
            else { keep.append(d); continue }
            collect(d, by: i)
        }
        drops = keep
    }

    /// Hands a drop to player `i` (a pet fetching it counts as its owner picking it up).
    private func collect(_ d: RpgDropped, by i: Int) {
        actor = players[i].id
        defer { actor = nil }
        if d.gold > 0 {
            // Gold is split between party members on the same map.
            let mates = partyMembers(of: players[i].id).compactMap(pIndex).filter { players[$0].map == d.map }
            let each = max(1, d.gold / max(1, mates.count))
            for k in mates { players[k].gold += each }
            float(mates.count > 1 ? "+\(each)G ×\(mates.count)" : "+\(d.gold)G", d.map, d.pos, .gold)
        }
        if let item = d.item, let it = RpgItems.item(item) {
            players[i].inventory[item, default: 0] += 1
            toast("\(RpgItems.rarityName[it.rarity]) \(it.name) 획득!")
            if it.rarity >= 2 { effect(.levelUp, d.map, players[i].pos, .holy, duration: 0.8) }
        }
    }
}

// MARK: - 거래

extension RpgWorld {
    private func tradeIndex(of id: Int) -> Int? { trades.firstIndex { $0.a == id || $0.b == id } }

    private func canTrade(_ x: Int, _ y: Int) -> Bool {
        guard let a = player(x), let b = player(y), a.id != b.id, !a.dead, !b.dead, a.map == b.map else { return false }
        return dist(a.pos, b.pos) < RpgTrades.range
    }

    /// The trade `id` is in, seen from their side (a client reads the copy the host sent).
    func tradeView(for id: Int) -> RpgTradeView? {
        if isMirror { return mirrorTrade }
        guard let k = tradeIndex(of: id) else { return nil }
        let t = trades[k], other = t.partner(of: id)
        guard let name = player(other)?.name else { return nil }
        return RpgTradeView(partnerID: other, partnerName: name, mine: t.offers[id] ?? RpgTradeOffer(), theirs: t.offers[other] ?? RpgTradeOffer())
    }

    /// True while `id` is in a trade, so the host can send their view every tick.
    func tradeActive(for id: Int) -> Bool { tradeIndex(of: id) != nil }

    fileprivate func stepTrades() {
        guard !isMirror else { return }
        for k in trades.indices.reversed() where k < trades.count && !canTrade(trades[k].a, trades[k].b) {
            cancelTrade(k, "거래 상대가 멀어져서 거래가 취소됐어요")
        }
        for i in players.indices {
            if let from = players[i].tradeFrom, player(from) == nil { players[i].tradeFrom = nil }
        }
    }

    private func cancelTrade(_ k: Int, _ message: String) {
        let t = trades.remove(at: k)
        toast(message, to: t.a)
        toast(message, to: t.b)
    }

    fileprivate func handleTrade(_ action: RpgAction, _ i: Int) {
        let id = players[i].id
        switch action {
        case .tradeRequest(let target):
            guard let t = pIndex(target), tradeIndex(of: id) == nil, tradeIndex(of: target) == nil, canTrade(id, target) else {
                toast("거래할 수 없어요 (같은 맵에서 가까이 있어야 해요)")
                return
            }
            players[t].tradeFrom = id
            toast("\(players[t].name) 님에게 거래를 요청했어요")
            toast("\(players[i].name) 님의 거래 요청! 거래창(T)에서 수락하세요", to: target)
        case .tradeAccept:
            guard let from = players[i].tradeFrom, tradeIndex(of: id) == nil, tradeIndex(of: from) == nil, canTrade(id, from) else {
                players[i].tradeFrom = nil
                toast("거래 요청이 사라졌어요")
                return
            }
            players[i].tradeFrom = nil
            trades.append(RpgTrade(a: from, b: id, offers: [from: RpgTradeOffer(), id: RpgTradeOffer()]))
            toast("거래를 시작했어요", to: id)
            toast("거래를 시작했어요", to: from)
        case .tradeDecline:
            players[i].tradeFrom = nil
        case .tradeCancel:
            if let k = tradeIndex(of: id) { cancelTrade(k, "거래를 취소했어요") }
        case .tradeOffer(let item, let count):
            guard let k = tradeIndex(of: id) else { return }
            guard RpgTrades.tradable(item, players[i]) else { toast("이 아이템은 거래할 수 없어요 (강화한 장비)"); return }
            var offer = trades[k].offers[id] ?? RpgTradeOffer()
            let n = min(max(count, 0), players[i].inventory[item] ?? 0)
            if n == 0 {
                offer.items[item] = nil
            } else {
                if offer.items[item] == nil, offer.items.count >= RpgTrades.maxDistinct { toast("한 번에 \(RpgTrades.maxDistinct)종류까지 올릴 수 있어요"); return }
                offer.items[item] = n
            }
            setOffer(k, id, offer)
        case .tradeGold(let gold):
            guard let k = tradeIndex(of: id) else { return }
            var offer = trades[k].offers[id] ?? RpgTradeOffer()
            offer.gold = min(max(gold, 0), players[i].gold)
            setOffer(k, id, offer)
        case .tradeConfirm(let ok):
            guard let k = tradeIndex(of: id) else { return }
            trades[k].offers[id, default: RpgTradeOffer()].ok = ok
            let other = trades[k].partner(of: id)
            if ok, trades[k].offers[other]?.ok == true { commitTrade(k) }
        default:
            break
        }
    }

    /// Replaces one side's offer; any change clears both confirmations.
    private func setOffer(_ k: Int, _ id: Int, _ offer: RpgTradeOffer) {
        var o = offer
        o.ok = false
        trades[k].offers[id] = o
        for key in trades[k].offers.keys { trades[k].offers[key]?.ok = false }
    }

    /// Swaps both offers in one step, after checking again that each side still owns what it offered.
    private func commitTrade(_ k: Int) {
        let t = trades[k]
        guard let ai = pIndex(t.a), let bi = pIndex(t.b), canTrade(t.a, t.b) else { cancelTrade(k, "거래가 취소됐어요"); return }
        let offerA = t.offers[t.a] ?? RpgTradeOffer(), offerB = t.offers[t.b] ?? RpgTradeOffer()
        func valid(_ p: RpgPlayer, _ o: RpgTradeOffer) -> Bool {
            o.gold >= 0 && o.gold <= p.gold && o.items.allSatisfy { $0.value > 0 && (p.inventory[$0.key] ?? 0) >= $0.value && RpgTrades.tradable($0.key, p) }
        }
        guard valid(players[ai], offerA), valid(players[bi], offerB) else { cancelTrade(k, "보유량이 바뀌어서 거래가 취소됐어요"); return }
        func move(_ offer: RpgTradeOffer, from f: Int, to g: Int) {
            for (item, n) in offer.items {
                let left = (players[f].inventory[item] ?? 0) - n
                players[f].inventory[item] = left > 0 ? left : nil
                players[g].inventory[item, default: 0] += n
            }
            players[f].gold -= offer.gold
            players[g].gold += offer.gold
        }
        move(offerA, from: ai, to: bi)
        move(offerB, from: bi, to: ai)
        trades.remove(at: k)
        toast("거래 완료!", to: t.a)
        toast("거래 완료!", to: t.b)
    }
}

// MARK: - 무한의 탑

extension RpgWorld {
    /// The monsters of tower floor `n`: levels climb two per floor (capped at 58), every 5th floor is all golden
    /// elites, every 10th is a boss with escorts.
    static func towerWave(floor n: Int) -> (defs: [RpgMonsterDef], elite: Bool, boss: Bool) {
        let normal = RpgMonsters.all.filter { $0.behavior != .boss }
        let bosses = RpgMonsters.all.filter { $0.behavior == .boss }.sorted { $0.level < $1.level }
        let target = min(58, 3 + n * 2)
        var pool = normal.filter { abs($0.level - target) <= 5 }
        if pool.isEmpty { pool = Array(normal.sorted { abs($0.level - target) < abs($1.level - target) }.prefix(3)) }
        let count = min(16, 5 + n / 2)
        let isBoss = n % 10 == 0 && !bosses.isEmpty
        var defs: [RpgMonsterDef] = []
        for k in 0..<(isBoss ? 4 : count) { defs.append(pool[(k * 7 + n) % pool.count]) }
        if isBoss { defs.insert(bosses[min(bosses.count - 1, n / 10 - 1)], at: 0) }
        return (defs, n % 5 == 0 && !isBoss, isBoss)
    }

    fileprivate func stepTower() {
        guard !isMirror, players.contains(where: { $0.map == .tower && !$0.dead }) else { return }
        if towerFloor == 0 { startTowerFloor(1); return }
        guard !(mobs[.tower] ?? []).contains(where: { !$0.dead }) else { return }
        guard let cleared = towerClearedAt else { clearTowerFloor(); return }
        if time - cleared >= 3 { startTowerFloor(towerFloor + 1) }
    }

    private func startTowerFloor(_ n: Int) {
        towerFloor = n
        towerClearedAt = nil
        let m = map(.tower)
        let wave = Self.towerWave(floor: n)
        // Past floor 25 the monster levels stop climbing, so their HP keeps growing instead.
        let growth = 1 + 0.1 * Double(max(0, n - 25))
        var list: [RpgMob] = []
        for def in wave.defs {
            let boss = def.behavior == .boss
            let p = boss ? CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2 - 24) : randomSpawn(m)
            var mob = RpgMob(id: newID(), def: def, pos: p, home: p, hp: Double(def.hp))
            var scale = growth
            if wave.elite, !boss { mob.elite = true; scale *= Self.eliteHP }
            mob.hpScale = scale
            mob.hp = Double(def.hp) * scale
            list.append(mob)
        }
        mobs[.tower] = list
        let label = "무한의 탑 \(n)층" + (wave.boss ? " — 보스!" : wave.elite ? " — 황금 엘리트 웨이브!" : "")
        for pl in players where pl.map == .tower { toast(label, to: pl.id) }
    }

    /// Floor cleared: record it, and every 5th floor drops stones (plus gear every 10th) for each climber.
    private func clearTowerFloor() {
        towerClearedAt = time
        let floor = towerFloor
        let center = CGPoint(x: map(.tower).pixelSize.width / 2, y: map(.tower).pixelSize.height / 2)
        for i in players.indices where players[i].map == .tower && !players[i].dead {
            players[i].bestFloor = max(players[i].bestFloor, floor)
            toast("\(floor)층 클리어!", to: players[i].id)
            var rewards: [String] = []
            if floor % 5 == 0 { rewards += Array(repeating: "stone", count: 1 + floor / 10) }
            if floor % 10 == 0 {
                let tier = floor >= 30 ? 7 : 6
                let weapon = (players[i].cls == .warrior ? "sword" : players[i].cls == .archer ? "bow" : "staff") + "\(tier)"
                rewards.append(floor % 20 == 10 ? weapon : "armor\(tier)")
            }
            for (k, item) in rewards.enumerated() where RpgItems.item(item) != nil {
                drops.append(RpgDropped(id: newID(), map: .tower, pos: CGPoint(x: center.x + CGFloat(k * 9 - rewards.count * 4), y: center.y + 12),
                                        gold: 0, item: item, at: time, owner: players[i].id))
            }
            if !rewards.isEmpty { toast("층 보상이 바닥에 떨어졌어요!", to: players[i].id) }
            checkAchievements(i)
        }
    }
}

// MARK: - pets

extension RpgWorld {
    private static let petSpeed = 95.0
    private static let petAttackGap = 1.1
    private static let petLootRadius = 150.0
    private static let petFightRadius = 90.0

    /// The pet's special attack: its real strongest move hits everything around the target, with the move's name
    /// floating up and an effect matching the move's type.
    fileprivate func petSpecial(_ info: RpgPetInfo, owner p: RpgPlayer, at target: CGPoint) {
        let element = info.moveType.map { RpgPetFactory.element(for: [$0]) } ?? info.element
        let name = info.moveName ?? "필살기"
        float(name, p.map, CGPoint(x: target.x, y: target.y - 10), .info)
        let fx: RpgFX.Kind
        switch element {
        case .ice: fx = .ice(radius: 30)
        case .thunder: fx = .strike
        case .cosmic: fx = .meteor(radius: 34)
        case .wind: fx = .slash(angle: 0, radius: 24)
        case .fire, .holy, .poison, .base: fx = .burst(radius: element == .base ? 26 : 32)
        }
        effect(fx, p.map, target, element, duration: 0.4)
        shake = max(shake, 0.4)
        let damage = Double(info.power) * Double(info.movePower ?? 60) / 80 * 0.9 + p.attack(at: time) * 0.9
        for v in mobIDs(near: target, radius: 34, map: p.map) { damageMob(v, map: p.map, base: damage, by: p.id, element: element, skill: true) }
    }

    /// Pets follow their owner, hit monsters near them and fetch drops. Only the host simulates them.
    fileprivate func stepPets(_ dt: Double) {
        guard !isMirror else { return }
        for p in players {
            guard let info = p.petInfo else { pets[p.id] = nil; continue }
            var s = pets[p.id] ?? RpgPetState(owner: p.id, map: p.map, pos: CGPoint(x: p.pos.x - 14, y: p.pos.y), info: info)
            s.info = info
            // Through a portal, or too far behind: rejoin the owner.
            if s.map != p.map || dist(s.pos, p.pos) > 260 { s.map = p.map; s.pos = p.pos }
            defer { pets[p.id] = s }
            guard !p.dead, let i = pIndex(p.id) else { s.moving = false; continue }
            let m = map(p.map)

            var goal: CGPoint?
            var arrive = 4.0
            let target = (mobs[p.map] ?? []).filter { !$0.dead && !$0.airborne && dist($0.pos, p.pos) < Self.petFightRadius }
                .min { dist($0.pos, s.pos) < dist($1.pos, s.pos) }
            // A drop near the owner is fetched unless a fight is on; drops reserved for someone else are left alone.
            let fighting = target.map { dist($0.pos, p.pos) < 50 } ?? false
            let loot: RpgDropped? = fighting ? nil : drops.filter { d in
                d.map == p.map && time - d.at > 0.35 && dist(d.pos, p.pos) < Self.petLootRadius
                    && !(d.owner != nil && time - d.at < 30 && d.owner != p.id)
            }.min { dist($0.pos, s.pos) < dist($1.pos, s.pos) }
            if let loot {
                goal = loot.pos
                arrive = 6
                if dist(s.pos, loot.pos) < 10 {
                    collect(loot, by: i)
                    drops.removeAll { $0.id == loot.id }
                }
            } else if let target {
                goal = target.pos
                arrive = 20
                if dist(s.pos, target.pos) < 30, time >= s.attackAt {
                    s.attackAt = time + Self.petAttackGap
                    s.facingRight = target.pos.x > s.pos.x
                    effect(.slash(angle: atan2(Double(target.pos.y - s.pos.y), Double(target.pos.x - s.pos.x)), radius: 9), p.map,
                           CGPoint(x: target.pos.x, y: target.pos.y - 6), info.element, duration: 0.25)
                    damageMob(target.id, map: p.map, base: Double(info.power) * 0.4 + p.attack(at: time) * 0.35, by: p.id,
                              element: info.element, skill: false)
                }
                if time >= s.skillAt, dist(s.pos, target.pos) < 60 {
                    s.skillAt = time + rand(6, 8)
                    petSpecial(info, owner: p, at: target.pos)
                }
            } else if dist(s.pos, p.pos) > 34 {
                goal = CGPoint(x: p.pos.x + (p.facingRight ? -18 : 18), y: p.pos.y)
            }

            s.moving = false
            guard let goal else { continue }
            let dx = Double(goal.x - s.pos.x), dy = Double(goal.y - s.pos.y), d = hypot(dx, dy)
            guard d > arrive else { continue }
            let step = min(d, Self.petSpeed * dt)
            let nx = CGPoint(x: s.pos.x + CGFloat(dx / d * step), y: s.pos.y + CGFloat(dy / d * step))
            if m.canStand(nx) { s.pos = nx }
            else if m.canStand(CGPoint(x: nx.x, y: s.pos.y)) { s.pos.x = nx.x }
            else if m.canStand(CGPoint(x: s.pos.x, y: nx.y)) { s.pos.y = nx.y }
            s.moving = true
            if abs(dx) > 1 { s.facingRight = dx > 0 }
        }
        pets = pets.filter { entry in players.contains { $0.id == entry.key } }
    }
}

// MARK: - multiplayer

extension RpgWorld {
    var nextPlayerID: Int { (players.map(\.id).max() ?? 0) + 1 }

    func addPlayer(_ player: RpgPlayer) {
        var p = player
        p.visited.insert(p.map)
        p.posLockUntil = time + 0.6
        players.removeAll { $0.id == p.id }
        players.append(p)
        _ = map(p.map)
        spawnMobsIfNeeded(p.map)
        toast("\(p.name) 님이 들어왔어요", to: nil)
    }

    func removePlayer(_ id: Int) {
        guard let i = pIndex(id) else { return }
        leaveParty(i)
        while let k = trades.firstIndex(where: { $0.a == id || $0.b == id }) { cancelTrade(k, "상대가 나가서 거래가 취소됐어요") }
        let p = players.remove(at: i)
        leaveMapIfEmpty(p.map)
        toast("\(p.name) 님이 나갔어요", to: nil)
    }

    /// A chat line: a bubble over the speaker's head and an entry in everyone's chat log.
    func say(_ id: Int, _ text: String) {
        guard let i = pIndex(id) else { return }
        let line = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !line.isEmpty else { return }
        let partyOnly = line.hasPrefix("/p ") && players[i].partyID != nil
        let body = partyOnly ? String(line.dropFirst(3)) : line
        if !partyOnly { players[i].bubble = body; players[i].bubbleUntil = time + 5 }
        chatLog.append(RpgChat(name: players[i].name, text: body, at: time, party: partyOnly ? players[i].partyID : nil))
        if chatLog.count > 30 { chatLog.removeFirst() }
    }

    // MARK: host → clients

    func snapshot() -> RpgSnapshot {
        let occupied = Set(players.map(\.map))
        let pubs = players.map { p in
            RpgPlayerPub(id: p.id, name: p.name, cls: p.cls, level: p.level, map: p.map, x: Double(p.pos.x), y: Double(p.pos.y),
                         fx: Double(p.facing.dx), fy: Double(p.facing.dy), facingRight: p.facingRight, moving: p.moving, hp: p.hp, mp: p.mp,
                         dead: p.dead, weapon: p.weapon, weaponPlus: p.plus[p.weapon] ?? 0,
                         rage: max(0, p.rageUntil - time), iron: max(0, p.ironUntil - time), focus: max(0, p.focusUntil - time),
                         shield: max(0, p.shieldUntil - time), cyclone: max(0, p.cycloneUntil - time), invulnerable: p.invulnerable > 0,
                         bubble: time < p.bubbleUntil ? p.bubble : nil, bubbleLeft: max(0, p.bubbleUntil - time), partyID: p.partyID, hardcore: p.hardcore, fallen: p.fallen, job: p.job,
                         combo: p.combo, comboLeft: max(0, p.comboUntil - time))
        }
        var mobPubs: [RpgMobPub] = []
        for mapID in occupied {
            for m in mobs[mapID] ?? [] where !m.dead || time - m.diedAt < 0.5 {
                mobPubs.append(RpgMobPub(id: m.id, def: m.def.id, map: mapID, x: Double(m.pos.x), y: Double(m.pos.y), hp: m.hp, dead: m.dead,
                                         diedAgo: time - m.diedAt, airborne: m.airborne, jx: m.jumpTarget.map { Double($0.x) },
                                         jy: m.jumpTarget.map { Double($0.y) }, phaseLeft: m.phaseUntil - time, hurt: m.hurtFlash > 0,
                                         stunLeft: max(0, m.stunUntil - time), slowLeft: max(0, m.slowUntil - time),
                                         dot: m.dotTicks > 0 ? m.dotElement : nil, windup: m.windup != nil, facingRight: m.facingRight,
                                         summoned: m.summoned, hpScale: m.hpScale, berserkIn: m.engagedAt > 0 ? Self.berserkAfter - (time - m.engagedAt) : nil, elite: m.elite ? true : nil))
            }
        }
        return RpgSnapshot(time: time, players: pubs, mobs: mobPubs, shots: shots.filter { occupied.contains($0.map) },
                           fx: fx.filter { occupied.contains($0.map) }, floaters: floaters.filter { occupied.contains($0.map) },
                           drops: drops.filter { occupied.contains($0.map) }, traps: traps.filter { occupied.contains($0.map) },
                           toasts: toasts, chat: Array(chatLog.suffix(10)), shake: shake, graves: graves.filter { occupied.contains($0.map) },
                           pets: pets.values.filter { occupied.contains($0.map) }.map { st in
                               RpgPetPub(owner: st.owner, map: st.map, x: Double(st.pos.x), y: Double(st.pos.y), facingRight: st.facingRight,
                                         moving: st.moving, speciesID: st.info.speciesID, shiny: st.info.shiny, name: st.info.name)
                           })
    }

    func privateState(for id: Int) -> RpgPrivate? {
        guard let p = player(id) else { return nil }
        return RpgPrivate(save: RpgSaveStore.snapshot(p), hp: p.hp, mp: p.mp, cooldowns: p.cooldowns, offers: boardOffers(for: id),
                          respawnIn: max(0, p.respawnAt - time), inviteFrom: p.inviteFrom, trade: tradeView(for: id), tradeFrom: p.tradeFrom)
    }

    // MARK: client mirror

    /// Fill the mirror from a host snapshot. The local player keeps its own predicted position unless the
    /// host moved it somewhere else (portal, dash, respawn).
    func apply(_ s: RpgSnapshot, localID: Int) {
        time = s.time
        var next: [RpgPlayer] = []
        for pub in s.players {
            let target = CGPoint(x: pub.x, y: pub.y)
            var p = player(pub.id) ?? RpgPlayer(id: pub.id, name: pub.name, cls: pub.cls, weapon: pub.weapon, pos: target)
            if pub.id == localID {
                if pub.map != p.map || hypot(target.x - p.pos.x, target.y - p.pos.y) > 40 { p.pos = target }
            } else {
                p.facing = CGVector(dx: pub.fx, dy: pub.fy)
                p.facingRight = pub.facingRight
                p.moving = pub.moving
                if pub.map != p.map || hypot(target.x - p.pos.x, target.y - p.pos.y) > 60 { p.pos = target }
                netTargets["p\(pub.id)"] = target
            }
            p.map = pub.map
            p.name = pub.name
            p.level = pub.level
            p.hp = pub.hp
            p.mp = pub.mp
            p.dead = pub.dead
            p.weapon = pub.weapon
            p.plus[pub.weapon] = pub.weaponPlus
            p.rageUntil = time + pub.rage
            p.ironUntil = time + pub.iron
            p.focusUntil = time + pub.focus
            p.shieldUntil = time + pub.shield
            p.cycloneUntil = time + pub.cyclone
            p.invulnerable = pub.invulnerable ? 0.1 : 0
            p.bubble = pub.bubble
            p.bubbleUntil = time + pub.bubbleLeft
            p.partyID = pub.partyID
            p.hardcore = pub.hardcore ?? false
            if pub.id != localID { p.fallen = pub.fallen ?? false }
            if pub.id == localID, pub.fallen == true { p.fallen = true; p.respawnAt = .infinity }
            p.job = pub.job ?? 0
            p.combo = pub.combo ?? 0
            p.comboUntil = time + (pub.comboLeft ?? 0)
            next.append(p)
        }
        if !next.contains(where: { $0.id == localID }), let me = player(localID) { next.append(me) }
        players = next
        var byMap: [RpgMapID: [RpgMob]] = [:]
        for mp in s.mobs {
            let target = CGPoint(x: mp.x, y: mp.y)
            var m = mobs[mp.map]?.first { $0.id == mp.id } ?? RpgMob(id: mp.id, def: RpgMonsters.def(mp.def), pos: target, home: target, hp: mp.hp)
            m.hp = mp.hp
            m.dead = mp.dead
            m.diedAt = time - mp.diedAgo
            m.airborne = mp.airborne
            m.jumpTarget = mp.jx.flatMap { x in mp.jy.map { CGPoint(x: x, y: $0) } }
            m.phaseUntil = time + mp.phaseLeft
            m.hurtFlash = mp.hurt ? 0.1 : 0
            m.stunUntil = time + mp.stunLeft
            m.slowUntil = time + mp.slowLeft
            m.dotTicks = mp.dot == nil ? 0 : 1
            m.dotElement = mp.dot ?? .fire
            m.windup = mp.windup ? 0.1 : nil
            m.facingRight = mp.facingRight
            m.summoned = mp.summoned
            m.hpScale = mp.hpScale
            m.elite = mp.elite ?? false
            m.engagedAt = mp.berserkIn.map { time - (Self.berserkAfter - $0) } ?? 0
            if hypot(target.x - m.pos.x, target.y - m.pos.y) > 60 { m.pos = target }
            netTargets["m\(mp.id)"] = target
            byMap[mp.map, default: []].append(m)
        }
        mobs = byMap
        var nextPets: [Int: RpgPetState] = [:]
        for pub in s.pets ?? [] {
            let target = CGPoint(x: pub.x, y: pub.y)
            var st = pets[pub.owner] ?? RpgPetState(owner: pub.owner, map: pub.map, pos: target, info: RpgPetInfo(speciesID: pub.speciesID, shiny: pub.shiny, name: pub.name, power: 0, element: .base))
            if st.map != pub.map || hypot(target.x - st.pos.x, target.y - st.pos.y) > 80 { st.pos = target }
            st.map = pub.map
            st.facingRight = pub.facingRight
            st.moving = pub.moving
            st.info = RpgPetInfo(speciesID: pub.speciesID, shiny: pub.shiny, name: pub.name, power: 0, element: .base)
            netTargets["t\(pub.owner)"] = target
            nextPets[pub.owner] = st
        }
        pets = nextPets
        shots = s.shots
        fx = s.fx
        floaters = s.floaters
        drops = s.drops
        traps = s.traps
        toasts = s.toasts
        chatLog = s.chat
        shake = max(shake, s.shake)
        towerFloor = s.towerFloor ?? 0
        addGraves(s.graves)
    }

    func applyPrivate(_ s: RpgPrivate, localID: Int) {
        guard let i = pIndex(localID) else { return }
        let d = s.save
        players[i].level = d.level
        players[i].xp = d.xp
        players[i].gold = d.gold
        players[i].inventory = d.inventory
        players[i].weapon = d.weapon
        players[i].armor = d.armor
        players[i].plus = d.plus ?? [:]
        players[i].skills = d.skills ?? players[i].skills
        players[i].sp = d.sp ?? players[i].sp
        players[i].slots = d.slots ?? players[i].slots
        players[i].quests = d.quests ?? []
        players[i].bossLoot = d.bossLoot ?? [:]
        players[i].hardcore = d.hardcore ?? false
        if d.fallen == true { players[i].fallen = true }
        players[i].visited = Set(d.visited ?? [])
        players[i].playTime = d.playTime
        mirrorTrade = s.trade
        players[i].tradeFrom = s.tradeFrom
        players[i].job = d.job ?? 0
        players[i].kills = RpgAchievements.cleanKills(d.kills)
        players[i].eliteKills = min(max(d.eliteKills ?? 0, 0), 10_000_000)
        players[i].bestCombo = min(max(d.bestCombo ?? 0, 0), 10_000)
        players[i].bestFloor = min(max(d.bestFloor ?? 0, 0), 1000)
        players[i].achievements = Set((d.achievements ?? []).filter { RpgAchievements.ids.contains($0) })
        players[i].hp = s.hp
        players[i].mp = s.mp
        players[i].cooldowns = s.cooldowns
        players[i].respawnAt = time + s.respawnIn
        players[i].inviteFrom = s.inviteFrom
        offers = s.offers
    }

    /// Client-side movement of the local player so walking feels instant.
    func predict(_ id: Int, input: RpgInput, dt: Double) {
        guard let i = pIndex(id), !players[i].dead else { return }
        let m = map(players[i].map)
        let mv = input.move
        let len = hypot(mv.dx, mv.dy)
        players[i].moving = len > 0.01
        guard len > 0.01 else { return }
        let dir = CGVector(dx: mv.dx / len, dy: mv.dy / len)
        players[i].facing = dir
        if abs(dir.dx) > 0.2 { players[i].facingRight = dir.dx > 0 }
        let step = CGFloat(players[i].cls.speed * dt)
        let nx = CGPoint(x: players[i].pos.x + dir.dx * step, y: players[i].pos.y)
        if m.canStand(nx) { players[i].pos = nx }
        let ny = CGPoint(x: players[i].pos.x, y: players[i].pos.y + dir.dy * step)
        if m.canStand(ny) { players[i].pos = ny }
    }

    /// Between snapshots: advance the clock and glide remote players and monsters toward the host's positions.
    func mirrorTick(_ dt: Double, localID: Int) {
        time += dt
        shake = max(0, shake - dt * 8)
        let k = CGFloat(min(1, dt * 12))
        for i in players.indices where players[i].id != localID {
            guard let t = netTargets["p\(players[i].id)"] else { continue }
            players[i].pos.x += (t.x - players[i].pos.x) * k
            players[i].pos.y += (t.y - players[i].pos.y) * k
        }
        for (owner, var st) in pets {
            guard let t = netTargets["t\(owner)"] else { continue }
            st.pos.x += (t.x - st.pos.x) * k
            st.pos.y += (t.y - st.pos.y) * k
            pets[owner] = st
        }
        for (mapID, list) in mobs {
            var moved = list
            for j in moved.indices {
                guard let t = netTargets["m\(moved[j].id)"] else { continue }
                moved[j].pos.x += (t.x - moved[j].pos.x) * k
                moved[j].pos.y += (t.y - moved[j].pos.y) * k
            }
            mobs[mapID] = moved
        }
        for j in floaters.indices { floaters[j].life -= dt; floaters[j].pos.y -= CGFloat(dt * 18) }
        floaters.removeAll { $0.life <= 0 }
    }
}

// MARK: - hardcore graves

struct RpgGrave: Codable, Sendable, Equatable {
    var id = UUID().uuidString
    let name: String
    let cls: RpgClass
    let level: Int
    let map: RpgMapID
    let x: Double
    let y: Double
    let cause: String
    let date: Double
}

extension RpgWorld {
    /// Merge tombstones (new deaths, or ones another player brings into the world); keeps the newest per map.
    func addGraves(_ list: [RpgGrave]) {
        let known = Set(graves.map(\.id))
        let fresh = list.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        var all = graves + fresh
        for mapID in Set(all.map(\.map)) {
            let here = all.filter { $0.map == mapID }.sorted { $0.date > $1.date }
            if here.count > Self.gravesPerMap {
                let drop = Set(here.dropFirst(Self.gravesPerMap).map(\.id))
                all.removeAll { drop.contains($0.id) }
            }
        }
        graves = all
        onGraves?()
    }
}

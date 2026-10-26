import CryptoKit
import Foundation

// SPIKE: 픽셀 모험's character save. The JSON body travels with an HMAC so a hand-edited file (more gold,
// a legendary weapon) is rejected instead of loaded. The key ships with the app, so this keeps honest
// people honest rather than stopping someone who reads the source. Version 2 adds skills, enhancement,
// quests and visited zones as optional fields so version-1 saves still load.

struct RpgSaveData: Codable, Sendable {
    var version = 2
    var name: String
    var cls: RpgClass
    var level: Int
    var xp: Int
    var gold: Int
    var inventory: [String: Int]
    var weapon: String
    var armor: String?
    var map: RpgMapID
    var x: Double
    var y: Double
    var playTime: Double
    var plus: [String: Int]?
    var skills: [String: Int]?
    var sp: Int?
    var ap: Int?
    var stats: [Int]?
    var slots: [String?]?
    var quests: [RpgQuest]?
    var visited: [RpgMapID]?
    var bossLoot: [String: Double]?
    var hardcore: Bool?
    var fallen: Bool?
    var job: Int?
    var tier: Int?
    var kills: [String: Int]?
    var eliteKills: Int?
    var bestCombo: Int?
    var achievements: [String]?
    var bestFloor: Int?
    var ring: String?
    var amulet: String?
    var helmet: String?
    var boots: String?
    /// Customization [hair, skin, accent] (`RpgLook`); nil on characters made before it existed (class default).
    var look: [Int]?
}

enum RpgSaveStore {
    enum LoadResult { case none, ok(RpgSaveData), tampered }

    /// Three character slots. Slot 1 keeps the original `rpg-save.json`, so saves from before slots just work.
    static let slotCount = 3
    /// The slot the running game saves to, chosen on the title screen.
    nonisolated(unsafe) static var slot = 1

    private static func url(_ slot: Int) -> URL {
        AppStatePaths.directory().appendingPathComponent(slot == 1 ? "rpg-save.json" : "rpg-save-\(slot).json")
    }
    private static let key = SymmetricKey(data: Data("ptb-pixel-adventure/v1/7f3a9c1e5b".utf8))

    private struct Envelope: Codable {
        let body: Data
        let mac: String
    }

    private static func mac(_ body: Data) -> String {
        HMAC<SHA256>.authenticationCode(for: body, using: key).map { String(format: "%02x", $0) }.joined()
    }

    static func load(slot: Int = RpgSaveStore.slot) -> LoadResult {
        guard (1...slotCount).contains(slot), let raw = try? Data(contentsOf: url(slot)) else { return .none }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: raw), mac(env.body) == env.mac,
              let data = try? JSONDecoder().decode(RpgSaveData.self, from: env.body) else { return .tampered }
        return .ok(data)
    }

    static func save(_ data: RpgSaveData, slot: Int = RpgSaveStore.slot) {
        guard (1...slotCount).contains(slot), let body = try? JSONEncoder().encode(data),
              let raw = try? JSONEncoder().encode(Envelope(body: body, mac: mac(body))) else { return }
        try? FileManager.default.createDirectory(at: url(slot).deletingLastPathComponent(), withIntermediateDirectories: true)
        try? raw.write(to: url(slot), options: .atomic)
    }

    /// Removes one character slot (other slots are untouched).
    static func delete(slot: Int) {
        guard (1...slotCount).contains(slot) else { return }
        try? FileManager.default.removeItem(at: url(slot))
    }

    /// Keeps a rejected file next to the new save instead of silently overwriting it.
    static func quarantine(slot: Int = RpgSaveStore.slot) {
        guard (1...slotCount).contains(slot) else { return }
        let dest = url(slot).deletingLastPathComponent().appendingPathComponent("rpg-save\(slot == 1 ? "" : "-\(slot)").rejected-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url(slot), to: dest)
    }

    static func snapshot(_ p: RpgPlayer) -> RpgSaveData {
        // Boss rooms resume in town; everywhere else resumes where you stood.
        let inBoss = RpgMaps.def(p.map).kind == .boss
        let safeMap: RpgMapID = inBoss ? .town : p.map
        let spot = inBoss ? RpgMap.center(RpgWorld.townSpawn) : p.pos
        return RpgSaveData(name: p.name, cls: p.cls, level: p.level, xp: p.xp, gold: p.gold, inventory: p.inventory,
                           weapon: p.weapon, armor: p.armor, map: safeMap, x: Double(spot.x), y: Double(spot.y), playTime: p.playTime,
                           plus: p.plus, skills: p.skills, sp: p.sp, ap: p.ap, stats: p.stats, slots: p.slots, quests: p.quests, visited: Array(p.visited), bossLoot: p.bossLoot, hardcore: p.hardcore, fallen: p.fallen, job: p.job, tier: p.tier,
                           kills: p.kills, eliteKills: p.eliteKills, bestCombo: p.bestCombo, achievements: p.achievements.sorted(), bestFloor: p.bestFloor,
                           ring: p.ring, amulet: p.amulet, helmet: p.helmet, boots: p.boots, look: p.look)
    }

    static func player(from s: RpgSaveData, id: Int) -> RpgPlayer {
        var p = RpgPlayer(id: id, name: s.name, cls: s.cls, weapon: s.weapon, pos: CGPoint(x: s.x, y: s.y))
        p.level = s.level
        p.xp = s.xp
        p.gold = s.gold
        p.inventory = s.inventory
        p.armor = s.armor
        p.map = s.map
        p.playTime = s.playTime
        p.plus = s.plus ?? [:]
        p.skills = s.skills ?? starterSkills(s.cls)
        // Version-1 characters get the skill points their levels would have earned.
        p.sp = s.sp ?? (1..<max(1, s.level)).reduce(0) { $0 + (($1 + 1) % 10 == 0 ? 2 : 1) }
        (p.ap, p.stats) = RpgStats.clean(ap: s.ap, stats: s.stats, level: s.level)
        p.slots = s.slots.map { $0 + Array(repeating: nil, count: max(0, RpgWorld.slotCount - $0.count)) } ?? starterSlots(s.cls)
        p.quests = s.quests ?? []
        p.visited = Set(s.visited ?? [.town, s.map])
        p.bossLoot = s.bossLoot ?? [:]
        p.hardcore = s.hardcore ?? false
        p.fallen = s.fallen ?? false
        p.job = RpgJobs.def(s.cls, s.job ?? 0) == nil ? 0 : (s.job ?? 0)
        p.tier = RpgStats.cleanTier(s.tier, job: p.job)
        p.kills = RpgAchievements.cleanKills(s.kills)
        p.eliteKills = min(max(s.eliteKills ?? 0, 0), 10_000_000)
        p.bestCombo = min(max(s.bestCombo ?? 0, 0), 10_000)
        p.achievements = Set((s.achievements ?? []).filter { RpgAchievements.ids.contains($0) })
        p.bestFloor = min(max(s.bestFloor ?? 0, 0), 1000)
        p.ring = s.ring.flatMap { RpgItems.item($0)?.kind == .ring ? $0 : nil }
        p.amulet = s.amulet.flatMap { RpgItems.item($0)?.kind == .amulet ? $0 : nil }
        p.helmet = s.helmet.flatMap { RpgItems.item($0)?.kind == .helmet ? $0 : nil }
        p.boots = s.boots.flatMap { RpgItems.item($0)?.kind == .boots ? $0 : nil }
        p.look = RpgLook.clean(s.look, cls: s.cls)
        p.hp = p.maxHP
        p.mp = p.maxMP
        // A position from an older map layout might now be inside a wall.
        let m = RpgMap(RpgMaps.def(p.map))
        if !m.canStand(p.pos) { p.map = .town; p.pos = RpgMap.center(RpgWorld.townSpawn) }
        return p
    }

    private static func starterSkills(_ cls: RpgClass) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: cls.skills.filter(\.starter).map { ($0.id, 1) })
    }

    private static func starterSlots(_ cls: RpgClass) -> [String?] {
        let starters = cls.skills.filter(\.starter).map(\.id)
        return (0..<RpgWorld.slotCount).map { $0 < starters.count ? starters[$0] : nil }
    }

    static func newPlayer(name: String, cls: RpgClass, id: Int, hardcore: Bool = false, look: [Int]? = nil) -> RpgPlayer {
        var p = RpgPlayer(id: id, name: name, cls: cls, weapon: cls.starterWeapon, pos: RpgMap.center(RpgWorld.townSpawn))
        p.hardcore = hardcore
        p.look = RpgLook.clean(look, cls: cls)
        if hardcore { p.inventory["hp1"] = 5 }
        p.gold = 150
        p.inventory = ["hp0": 6, "mp0": 4, "scroll": 2]
        p.armor = "armor0"
        p.skills = starterSkills(cls)
        p.slots = starterSlots(cls)
        p.hp = p.maxHP
        p.mp = p.maxMP
        return p
    }
}

/// Tombstones of fallen hardcore characters, kept on this Mac (plain JSON: nothing to cheat by editing).
enum RpgGraveStore {
    private static var url: URL { AppStatePaths.directory().appendingPathComponent("rpg-graves.json") }

    static func load() -> [RpgGrave] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([RpgGrave].self, from: data)) ?? []
    }

    static func save(_ graves: [RpgGrave]) {
        guard let data = try? JSONEncoder().encode(graves) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

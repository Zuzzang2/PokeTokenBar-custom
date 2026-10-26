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
    var slots: [String?]?
    var quests: [RpgQuest]?
    var visited: [RpgMapID]?
    var bossLoot: [String: Double]?
    var hardcore: Bool?
    var fallen: Bool?
}

enum RpgSaveStore {
    enum LoadResult { case none, ok(RpgSaveData), tampered }

    private static var url: URL { AppStatePaths.directory().appendingPathComponent("rpg-save.json") }
    private static let key = SymmetricKey(data: Data("ptb-pixel-adventure/v1/7f3a9c1e5b".utf8))

    private struct Envelope: Codable {
        let body: Data
        let mac: String
    }

    private static func mac(_ body: Data) -> String {
        HMAC<SHA256>.authenticationCode(for: body, using: key).map { String(format: "%02x", $0) }.joined()
    }

    static func load() -> LoadResult {
        guard let raw = try? Data(contentsOf: url) else { return .none }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: raw), mac(env.body) == env.mac,
              let data = try? JSONDecoder().decode(RpgSaveData.self, from: env.body) else { return .tampered }
        return .ok(data)
    }

    static func save(_ data: RpgSaveData) {
        guard let body = try? JSONEncoder().encode(data),
              let raw = try? JSONEncoder().encode(Envelope(body: body, mac: mac(body))) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? raw.write(to: url, options: .atomic)
    }

    /// Keeps a rejected file next to the new save instead of silently overwriting it.
    static func quarantine() {
        let dest = url.deletingLastPathComponent().appendingPathComponent("rpg-save.rejected-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: dest)
    }

    static func snapshot(_ p: RpgPlayer) -> RpgSaveData {
        // Boss rooms resume in town; everywhere else resumes where you stood.
        let inBoss = RpgMaps.def(p.map).kind == .boss
        let safeMap: RpgMapID = inBoss ? .town : p.map
        let spot = inBoss ? RpgMap.center(RpgWorld.townSpawn) : p.pos
        return RpgSaveData(name: p.name, cls: p.cls, level: p.level, xp: p.xp, gold: p.gold, inventory: p.inventory,
                           weapon: p.weapon, armor: p.armor, map: safeMap, x: Double(spot.x), y: Double(spot.y), playTime: p.playTime,
                           plus: p.plus, skills: p.skills, sp: p.sp, slots: p.slots, quests: p.quests, visited: Array(p.visited), bossLoot: p.bossLoot, hardcore: p.hardcore, fallen: p.fallen)
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
        p.slots = s.slots.map { $0 + Array(repeating: nil, count: max(0, RpgWorld.slotCount - $0.count)) } ?? starterSlots(s.cls)
        p.quests = s.quests ?? []
        p.visited = Set(s.visited ?? [.town, s.map])
        p.bossLoot = s.bossLoot ?? [:]
        p.hardcore = s.hardcore ?? false
        p.fallen = s.fallen ?? false
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

    static func newPlayer(name: String, cls: RpgClass, id: Int, hardcore: Bool = false) -> RpgPlayer {
        var p = RpgPlayer(id: id, name: name, cls: cls, weapon: cls.starterWeapon, pos: RpgMap.center(RpgWorld.townSpawn))
        p.hardcore = hardcore
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

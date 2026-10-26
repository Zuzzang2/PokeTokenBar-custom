import CryptoKit
import Foundation

// SPIKE: 픽셀 모험's character save. The JSON body travels with an HMAC so a hand-edited file (more gold,
// a legendary weapon) is rejected instead of loaded. The key ships with the app, so this keeps honest
// people honest rather than stopping someone who reads the source.

struct RpgSaveData: Codable, Sendable {
    var version = 1
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

    static func delete() { try? FileManager.default.removeItem(at: url) }

    static func snapshot(_ p: RpgPlayer) -> RpgSaveData {
        // Saving inside a dungeon resumes at its entrance; the boss room resumes in town.
        let safeMap: RpgMapID = p.map == .boss ? .town : p.map
        let spot = p.map == .boss ? RpgMap.center(RpgWorld.townSpawn) : p.pos
        return RpgSaveData(name: p.name, cls: p.cls, level: p.level, xp: p.xp, gold: p.gold, inventory: p.inventory,
                           weapon: p.weapon, armor: p.armor, map: safeMap, x: Double(spot.x), y: Double(spot.y), playTime: p.playTime)
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
        p.hp = p.maxHP
        p.mp = p.maxMP
        return p
    }

    static func newPlayer(name: String, cls: RpgClass, id: Int) -> RpgPlayer {
        var p = RpgPlayer(id: id, name: name, cls: cls, weapon: cls.starterWeapon, pos: RpgMap.center(RpgWorld.townSpawn))
        p.gold = 120
        p.inventory = ["hp0": 5, "mp0": 3, "scroll": 1]
        p.armor = "armor0"
        p.hp = p.maxHP
        p.mp = p.maxMP
        return p
    }
}

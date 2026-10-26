import CoreGraphics
import Foundation

// SPIKE: wire types for 픽셀 모험 multiplayer. The host runs the one real `RpgWorld`; ~20 times a second it
// sends everyone a public snapshot (players, monsters on occupied maps, projectiles, effects, drops,
// toasts, chat) and, a few times a second, each player their private state (bag, skills, quests…).
// Clients send their input (and where they stand on their own screen) and menu actions back.

struct RpgPlayerPub: Codable, Sendable {
    let id: Int
    let name: String
    let cls: RpgClass
    let level: Int
    let map: RpgMapID
    let x: Double, y: Double
    let fx: Double, fy: Double
    let facingRight: Bool
    let moving: Bool
    let hp: Double
    let mp: Double
    let dead: Bool
    let weapon: String
    let weaponPlus: Int
    let rage: Double, iron: Double, focus: Double, shield: Double, cyclone: Double
    let invulnerable: Bool
    let bubble: String?
    let bubbleLeft: Double
    var partyID: Int? = nil
    var hardcore: Bool? = nil
    var fallen: Bool? = nil
    /// 2차 전직 (nil or 0 = not advanced); optional so peers on an older build still decode snapshots.
    var job: Int? = nil
    var tier: Int? = nil
    var combo: Int? = nil
    var comboLeft: Double? = nil
    /// Seconds of stealth left (nil or 0 = visible).
    var stealth: Double? = nil
}

struct RpgMobPub: Codable, Sendable {
    let id: Int
    let def: String
    let map: RpgMapID
    let x: Double, y: Double
    let hp: Double
    let dead: Bool
    let diedAgo: Double
    let airborne: Bool
    let jx: Double?, jy: Double?
    let phaseLeft: Double
    let hurt: Bool
    let stunLeft: Double
    let slowLeft: Double
    let dot: RpgElement?
    let windup: Bool
    let facingRight: Bool
    let summoned: Bool
    var hpScale: Double = 1
    var berserkIn: Double? = nil
    var elite: Bool? = nil
}

struct RpgSnapshot: Codable, Sendable {
    let time: Double
    let players: [RpgPlayerPub]
    let mobs: [RpgMobPub]
    let shots: [RpgShot]
    let fx: [RpgFX]
    let floaters: [RpgFloater]
    let drops: [RpgDropped]
    let traps: [RpgTrap]
    let toasts: [RpgToast]
    let chat: [RpgChat]
    let shake: Double
    var graves: [RpgGrave] = []
    var pets: [RpgPetPub]? = nil
    var towerFloor: Int? = nil
}

struct RpgPrivate: Codable, Sendable {
    let save: RpgSaveData
    let hp: Double
    let mp: Double
    let cooldowns: [String: Double]
    let offers: [RpgQuest]
    let respawnIn: Double
    var inviteFrom: Int? = nil
    var trade: RpgTradeView? = nil
    var tradeFrom: Int? = nil
    /// Seconds left on each buff item, so a client can show and apply them.
    var buffLeft: [String: Double]? = nil
}

enum RpgNetMessage: Codable, Sendable {
    /// Presence: who I am and whether I am running a world others can join.
    case hello(peer: String, hosting: Bool, name: String)
    /// Client → host: my character, please add me.
    case join(peer: String, save: RpgSaveData)
    /// Host → client: you are player `id` in my world.
    case welcome(peer: String, id: Int)
    case input(peer: String, input: RpgInput)
    case action(peer: String, action: RpgAction)
    case chat(peer: String, text: String)
    case snapshot(RpgSnapshot)
    case privateState(peer: String, state: RpgPrivate)
    /// Client → host: tombstones this player has seen, so they appear for everyone.
    case graves(peer: String, list: [RpgGrave])
}

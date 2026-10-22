import Foundation

// SPIKE: throwaway battle prototype. Level-50 party battle with switching, damage only (no status, abilities, items).

struct BattleMove: Codable, Sendable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let type: String
    let power: Int
    let accuracy: Int?          // nil = never misses
    let isPhysical: Bool
    let priority: Int
}

struct BattleMon: Codable, Sendable, Equatable {
    let trainer: String
    let name: String
    let speciesID: Int
    let isShiny: Bool
    let types: [String]
    let stats: [String: Int]    // hp, attack, defense, special-attack, special-defense, speed
    let moves: [BattleMove]

    var maxHP: Int { stats["hp"] ?? 1 }
}

enum BattleAction: Codable, Sendable, Equatable {
    case move(Int)
    case switchTo(Int)
}

/// What happened during the last step, in order, so the scene can replay it with animation.
enum BattleEvent: Sendable, Equatable {
    case message(String)
    case switchIn(side: Int, slot: Int)
    case attack(side: Int, type: String, physical: Bool)
    case damage(side: Int, hp: Int, critical: Bool, effectiveness: Double)
    case miss(side: Int)
    case faint(side: Int)
}

struct BattleState: Sendable, Equatable {
    var hp: [[Int]]             // [side][party slot]; side 0 = host, 1 = guest
    var active = [0, 0]
    var turn = 0
    /// Increments on every resolve/replace; the scene replays `events` when it changes.
    var step = 0
    var log: [String] = []
    var events: [BattleEvent] = []
    var winner: Int?
    /// Sides whose active Pokémon fainted and must send in another before the next turn.
    var needsReplacement: [Bool] = [false, false]

    func activeHP(_ side: Int) -> Int { hp[side][active[side]] }
    func canSwitch(_ side: Int, to slot: Int) -> Bool { slot != active[side] && hp[side][slot] > 0 }
    var awaitingReplacement: Bool { needsReplacement.contains(true) }

    mutating func say(_ text: String) {
        log.append(text)
        events.append(.message(text))
    }

    /// Starts a new step with an empty event list.
    mutating func beginStep() {
        step += 1
        events = []
    }
}

/// SplitMix64 — identical sequence on both peers for the same seed.
struct BattleRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func roll(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

enum BattleEngine {
    static func initialState(_ teams: [[BattleMon]]) -> BattleState {
        BattleState(hp: teams.map { $0.map(\.maxHP) })
    }

    /// Resolves one turn. Pure: both peers call it with the same inputs and get the same result.
    /// Switches go first, then moves by priority and speed.
    static func resolve(_ state: BattleState, teams: [[BattleMon]], actions: [BattleAction], seed: UInt64) -> BattleState {
        guard state.winner == nil, !state.awaitingReplacement else { return state }
        var next = state
        next.turn += 1
        next.beginStep()
        var rng = BattleRNG(seed: seed &+ UInt64(next.turn) &* 0x2545_F491_4F6C_DD1D)
        next.log.append("— \(next.turn)턴 —")

        for side in 0..<2 {
            if case .switchTo(let slot) = actions[side], next.canSwitch(side, to: slot) {
                next.say("\(teams[side][next.active[side]].name), 돌아와!")
                next.active[side] = slot
                next.events.append(.switchIn(side: side, slot: slot))
                next.say("가라, \(teams[side][slot].name)!")
            }
        }

        let movers = (0..<2).filter { if case .move = actions[$0] { return true } else { return false } }
        let moves: [BattleMove?] = (0..<2).map { side in
            guard case .move(let i) = actions[side] else { return nil }
            let mon = teams[side][next.active[side]]
            return mon.moves[min(max(0, i), mon.moves.count - 1)]
        }
        let order = movers.count == 2
            ? turnOrder(mons: [teams[0][next.active[0]], teams[1][next.active[1]]], moves: [moves[0]!, moves[1]!], rng: &rng)
            : movers

        for attacker in order {
            let defender = 1 - attacker
            guard next.activeHP(attacker) > 0, next.activeHP(defender) > 0, let move = moves[attacker] else { continue }
            let atkMon = teams[attacker][next.active[attacker]]
            let defMon = teams[defender][next.active[defender]]
            next.say("\(atkMon.name)의 \(move.name)!")
            next.events.append(.attack(side: attacker, type: move.type, physical: move.isPhysical))
            if let acc = move.accuracy, rng.roll(100) >= acc {
                next.events.append(.miss(side: defender))
                next.say("공격이 빗나갔다!")
                continue
            }
            let hit = damage(attacker: atkMon, defender: defMon, move: move, rng: &rng)
            next.hp[defender][next.active[defender]] = max(0, next.activeHP(defender) - hit.amount)
            next.events.append(.damage(side: defender, hp: next.activeHP(defender), critical: hit.critical,
                                       effectiveness: hit.effectiveness))
            if hit.critical { next.say("급소에 맞았다!") }
            if hit.effectiveness == 0 { next.say("효과가 없는 것 같다…") }
            else if hit.effectiveness > 1 { next.say("효과가 굉장했다!") }
            else if hit.effectiveness < 1 { next.say("효과가 별로인 듯하다…") }
            if next.activeHP(defender) == 0 {
                next.events.append(.faint(side: defender))
                next.say("\(KoreanParticle.subject.attach(to: defMon.name)) 쓰러졌다!")
                if next.hp[defender].allSatisfy({ $0 == 0 }) {
                    next.winner = attacker
                    next.say("\(atkMon.trainer)의 승리!")
                } else {
                    next.needsReplacement[defender] = true
                }
            }
        }
        return next
    }

    /// Applies the forced send-ins after a faint. `choices[side]` is ignored for sides that need none.
    static func replace(_ state: BattleState, teams: [[BattleMon]], choices: [Int?]) -> BattleState {
        var next = state
        next.beginStep()
        for side in 0..<2 where next.needsReplacement[side] {
            guard let slot = choices[side], next.hp[side][slot] > 0 else { continue }
            next.active[side] = slot
            next.needsReplacement[side] = false
            next.events.append(.switchIn(side: side, slot: slot))
            next.say("가라, \(teams[side][slot].name)!")
        }
        return next
    }

    static func turnOrder(mons: [BattleMon], moves: [BattleMove], rng: inout BattleRNG) -> [Int] {
        if moves[0].priority != moves[1].priority { return moves[0].priority > moves[1].priority ? [0, 1] : [1, 0] }
        let s0 = mons[0].stats["speed"] ?? 0, s1 = mons[1].stats["speed"] ?? 0
        if s0 != s1 { return s0 > s1 ? [0, 1] : [1, 0] }
        return rng.roll(2) == 0 ? [0, 1] : [1, 0]
    }

    struct Hit { let amount: Int; let effectiveness: Double; let critical: Bool }

    /// Gen V damage formula at level 50.
    static func damage(attacker: BattleMon, defender: BattleMon, move: BattleMove, rng: inout BattleRNG) -> Hit {
        let atk = attacker.stats[move.isPhysical ? "attack" : "special-attack"] ?? 1
        let def = max(1, defender.stats[move.isPhysical ? "defense" : "special-defense"] ?? 1)
        let level = 50
        var base = Double((2 * level / 5 + 2) * move.power * atk / def / 50 + 2)
        let critical = rng.roll(16) == 0
        if critical { base *= 2 }
        base *= Double(85 + rng.roll(16)) / 100
        if attacker.types.contains(move.type) { base *= 1.5 }
        let eff = TypeChart.multiplier(move.type, against: defender.types)
        base *= eff
        let amount = eff == 0 ? 0 : max(1, Int(base))
        return Hit(amount: amount, effectiveness: eff, critical: critical)
    }
}

enum TypeChart {
    static func multiplier(_ attack: String, against defenders: [String]) -> Double {
        defenders.reduce(1) { $0 * single(attack, $1) }
    }

    static func single(_ attack: String, _ defense: String) -> Double {
        if immune[attack]?.contains(defense) == true { return 0 }
        if strong[attack]?.contains(defense) == true { return 2 }
        if weak[attack]?.contains(defense) == true { return 0.5 }
        return 1
    }

    // Gen VI+ chart (fairy included; PokéAPI reports current types).
    private static let strong: [String: Set<String>] = [
        "fire": ["grass", "ice", "bug", "steel"],
        "water": ["fire", "ground", "rock"],
        "electric": ["water", "flying"],
        "grass": ["water", "ground", "rock"],
        "ice": ["grass", "ground", "flying", "dragon"],
        "fighting": ["normal", "ice", "rock", "dark", "steel"],
        "poison": ["grass", "fairy"],
        "ground": ["fire", "electric", "poison", "rock", "steel"],
        "flying": ["grass", "fighting", "bug"],
        "psychic": ["fighting", "poison"],
        "bug": ["grass", "psychic", "dark"],
        "rock": ["fire", "ice", "flying", "bug"],
        "ghost": ["psychic", "ghost"],
        "dragon": ["dragon"],
        "dark": ["psychic", "ghost"],
        "steel": ["ice", "rock", "fairy"],
        "fairy": ["fighting", "dragon", "dark"],
    ]
    private static let weak: [String: Set<String>] = [
        "normal": ["rock", "steel"],
        "fire": ["fire", "water", "rock", "dragon"],
        "water": ["water", "grass", "dragon"],
        "electric": ["electric", "grass", "dragon"],
        "grass": ["fire", "grass", "poison", "flying", "bug", "dragon", "steel"],
        "ice": ["fire", "water", "ice", "steel"],
        "fighting": ["poison", "flying", "psychic", "bug", "fairy"],
        "poison": ["poison", "ground", "rock", "ghost"],
        "ground": ["grass", "bug"],
        "flying": ["electric", "rock", "steel"],
        "psychic": ["psychic", "steel"],
        "bug": ["fire", "fighting", "poison", "flying", "ghost", "steel", "fairy"],
        "rock": ["fighting", "ground", "steel"],
        "ghost": ["dark"],
        "dragon": ["steel"],
        "dark": ["fighting", "dark", "fairy"],
        "steel": ["fire", "water", "electric", "steel"],
        "fairy": ["fire", "poison", "steel"],
    ]
    private static let immune: [String: Set<String>] = [
        "normal": ["ghost"], "fighting": ["ghost"], "poison": ["steel"], "ground": ["flying"],
        "electric": ["ground"], "psychic": ["dark"], "ghost": ["normal"], "dragon": ["fairy"],
    ]
}

import Foundation

// SPIKE: 2:2 team battle. Four trainers (0 and 1 = team 0, 2 and 3 = team 1), each with their own
// party and one active Pokémon. Every peer runs this pure engine with the same inputs and seed, like
// `BattleEngine`; damage and the type chart are shared with it.

enum TeamAction: Codable, Sendable, Equatable {
    /// Move index and the foe trainer it targets (retargeted if that foe is already down).
    case move(Int, target: Int)
    case switchTo(Int)
}

enum TeamEvent: Sendable, Equatable {
    case message(String)
    case switchIn(trainer: Int, slot: Int)
    case attack(from: Int, to: Int, type: String, physical: Bool)
    case damage(trainer: Int, hp: Int, critical: Bool, effectiveness: Double)
    case miss(trainer: Int)
    case faint(trainer: Int)
}

struct TeamBattleState: Sendable, Equatable {
    var hp: [[Int]]                         // [trainer][party slot]
    var active = [0, 0, 0, 0]
    var turn = 0
    /// Increments on every resolve/replace; the view replays `events` when it changes.
    var step = 0
    var log: [String] = []
    var events: [TeamEvent] = []
    var winner: Int?                        // winning team (0 or 1)
    /// Trainers whose active Pokémon fainted and who still have others to send in.
    var needsReplacement = [false, false, false, false]

    static func team(of trainer: Int) -> Int { trainer / 2 }
    static func foes(of trainer: Int) -> [Int] { team(of: trainer) == 0 ? [2, 3] : [0, 1] }
    static func partner(of trainer: Int) -> Int { trainer ^ 1 }

    /// A trainer with no Pokémon left stands aside for the rest of the match.
    func isOut(_ trainer: Int) -> Bool { hp[trainer].allSatisfy { $0 == 0 } }
    func activeHP(_ trainer: Int) -> Int { hp[trainer][active[trainer]] }
    func canSwitch(_ trainer: Int, to slot: Int) -> Bool { slot != active[trainer] && hp[trainer][slot] > 0 }
    func canTarget(_ trainer: Int) -> Bool { !isOut(trainer) && activeHP(trainer) > 0 }
    var awaitingReplacement: Bool { needsReplacement.contains(true) }

    mutating func say(_ text: String) {
        log.append(text)
        events.append(.message(text))
    }

    mutating func beginStep() {
        step += 1
        events = []
    }
}

enum TeamBattleEngine {
    static func initialState(_ teams: [[BattleMon]]) -> TeamBattleState {
        TeamBattleState(hp: teams.map { $0.map(\.maxHP) })
    }

    /// Trainers whose action the next turn waits for.
    static func trainersToAct(_ state: TeamBattleState) -> [Int] {
        (0..<4).filter { !state.isOut($0) }
    }

    /// Resolves one turn. `actions[t]` is nil only for trainers that are out.
    /// Switches go first (trainer order), then moves by priority, speed, and a seeded coin flip.
    static func resolve(_ state: TeamBattleState, teams: [[BattleMon]], actions: [TeamAction?],
                        seed: UInt64) -> TeamBattleState {
        guard state.winner == nil, !state.awaitingReplacement else { return state }
        var next = state
        next.turn += 1
        next.beginStep()
        var rng = BattleRNG(seed: seed &+ UInt64(next.turn) &* 0x2545_F491_4F6C_DD1D)
        next.log.append("— \(next.turn)턴 —")

        for t in 0..<4 {
            if case .switchTo(let slot)? = actions[t], !next.isOut(t), next.canSwitch(t, to: slot) {
                next.say("\(teams[t][next.active[t]].name), 돌아와!")
                next.active[t] = slot
                next.events.append(.switchIn(trainer: t, slot: slot))
                next.say("가라, \(teams[t][slot].name)!")
            }
        }

        var movers: [(trainer: Int, move: BattleMove, target: Int, tie: Int)] = []
        for t in 0..<4 {
            guard case .move(let i, let target)? = actions[t], !next.isOut(t), next.activeHP(t) > 0 else { continue }
            let mon = teams[t][next.active[t]]
            movers.append((t, mon.moves[min(max(0, i), mon.moves.count - 1)], target, rng.roll(1000)))
        }
        movers.sort { a, b in
            if a.move.priority != b.move.priority { return a.move.priority > b.move.priority }
            let sa = teams[a.trainer][next.active[a.trainer]].stats["speed"] ?? 0
            let sb = teams[b.trainer][next.active[b.trainer]].stats["speed"] ?? 0
            if sa != sb { return sa > sb }
            return a.tie > b.tie
        }

        for mover in movers where next.winner == nil {
            let attacker = mover.trainer
            guard next.activeHP(attacker) > 0 else { continue }
            let foes = TeamBattleState.foes(of: attacker)
            let target = foes.contains(mover.target) && next.canTarget(mover.target)
                ? mover.target : foes.first { next.canTarget($0) }
            guard let target else { continue }
            let atkMon = teams[attacker][next.active[attacker]]
            let defMon = teams[target][next.active[target]]
            next.say("\(atkMon.name)의 \(mover.move.name)!")
            next.events.append(.attack(from: attacker, to: target, type: mover.move.type, physical: mover.move.isPhysical))
            if let acc = mover.move.accuracy, rng.roll(100) >= acc {
                next.events.append(.miss(trainer: target))
                next.say("공격이 빗나갔다!")
                continue
            }
            let hit = BattleEngine.damage(attacker: atkMon, defender: defMon, move: mover.move, rng: &rng)
            next.hp[target][next.active[target]] = max(0, next.activeHP(target) - hit.amount)
            next.events.append(.damage(trainer: target, hp: next.activeHP(target), critical: hit.critical,
                                       effectiveness: hit.effectiveness))
            if hit.critical { next.say("급소에 맞았다!") }
            if hit.effectiveness == 0 { next.say("효과가 없는 것 같다…") }
            else if hit.effectiveness > 1 { next.say("효과가 굉장했다!") }
            else if hit.effectiveness < 1 { next.say("효과가 별로인 듯하다…") }
            guard next.activeHP(target) == 0 else { continue }
            next.events.append(.faint(trainer: target))
            next.say("\(KoreanParticle.subject.attach(to: defMon.name)) 쓰러졌다!")
            if next.isOut(target) {
                next.say("\(defMon.trainer)의 포켓몬이 모두 쓰러졌다!")
            } else {
                next.needsReplacement[target] = true
            }
            if let winner = winningTeam(next) {
                next.winner = winner
                next.needsReplacement = [false, false, false, false]
                let names = (0..<4).filter { TeamBattleState.team(of: $0) == winner }.map { teams[$0][0].trainer }
                next.say("\(names.joined(separator: "·")) 팀의 승리!")
            }
        }
        return next
    }

    /// Applies the forced send-ins after a faint. `choices[t]` is ignored for trainers that need none.
    static func replace(_ state: TeamBattleState, teams: [[BattleMon]], choices: [Int?]) -> TeamBattleState {
        var next = state
        next.beginStep()
        for t in 0..<4 where next.needsReplacement[t] {
            guard let slot = choices[t], next.hp[t][slot] > 0 else { continue }
            next.active[t] = slot
            next.needsReplacement[t] = false
            next.events.append(.switchIn(trainer: t, slot: slot))
            next.say("가라, \(teams[t][slot].name)!")
        }
        return next
    }

    static func winningTeam(_ state: TeamBattleState) -> Int? {
        if state.isOut(0) && state.isOut(1) { return 1 }
        if state.isOut(2) && state.isOut(3) { return 0 }
        return nil
    }
}

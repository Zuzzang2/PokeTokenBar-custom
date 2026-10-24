import Foundation
import Observation

// SPIKE: one 2:2 team battle in the plaza. Four trainers: the roster order is
// [host, host's partner, foe 1, foe 2]; indexes 0 and 1 are team 0. Everyone sends their team,
// the host picks the seed, and each turn every standing trainer sends an action to the other three.
// Once all actions are known each peer resolves the turn locally with the same pure engine.

enum TeamBattleMessage: Codable, Sendable {
    case hello([BattleMon])
    case seed(UInt64)
    case action(turn: Int, TeamAction)
    case replace(turn: Int, slot: Int)
}

@MainActor
@Observable
final class TeamBattleMatch {
    enum Phase: Equatable { case starting, battling, finished, disconnected }

    /// Plaza IDs by trainer index.
    let roster: [String]
    let myIndex: Int
    private(set) var phase: Phase = .starting
    private(set) var teams: [[BattleMon]?] = [nil, nil, nil, nil]
    private(set) var state: TeamBattleState?
    private(set) var status = "참가자 정보 받는 중…"

    private let send: (TeamBattleMessage, Int) -> Void   // message, destination trainer index
    /// Called once, with whether this side's team won, when the battle ends normally.
    var onFinished: ((Bool) -> Void)?
    private var seed: UInt64?
    /// Inputs by turn: a faster peer's next-turn action can arrive before this turn is resolved here.
    private var actionsByTurn: [Int: [TeamAction?]] = [:]
    private var replacementsByTurn: [Int: [Int?]] = [:]
    private static let empty4: [Int?] = [nil, nil, nil, nil]

    init(me: [BattleMon], roster: [String], myIndex: Int, send: @escaping (TeamBattleMessage, Int) -> Void) {
        self.roster = roster
        self.myIndex = myIndex
        self.send = send
        teams[myIndex] = me
        broadcast(.hello(me))
        if myIndex == 0 {
            let s = UInt64.random(in: 1...UInt64.max)
            seed = s
            broadcast(.seed(s))
        }
    }

    var myTeam: [BattleMon]? { teams[myIndex] }
    var isOver: Bool { phase == .finished || phase == .disconnected }
    var iAmOut: Bool { state?.isOut(myIndex) == true }
    var mustReplace: Bool {
        guard let state else { return false }
        return state.needsReplacement[myIndex] && replacement(of: myIndex, turn: state.turn) == nil
    }
    /// True once my action (or replacement) for this step is in.
    var hasActed: Bool {
        guard let state else { return false }
        if state.awaitingReplacement { return replacement(of: myIndex, turn: state.turn) != nil }
        return action(of: myIndex, turn: state.turn + 1) != nil
    }
    /// Trainers whose input the current step is still waiting for.
    var waitingFor: [Int] {
        guard let state else { return [] }
        if state.awaitingReplacement {
            return (0..<4).filter { state.needsReplacement[$0] && replacement(of: $0, turn: state.turn) == nil }
        }
        return TeamBattleEngine.trainersToAct(state).filter { action(of: $0, turn: state.turn + 1) == nil }
    }
    private func action(of trainer: Int, turn: Int) -> TeamAction? { actionsByTurn[turn]?[trainer] ?? nil }
    private func replacement(of trainer: Int, turn: Int) -> Int? { replacementsByTurn[turn]?[trainer] ?? nil }
    private func store(action: TeamAction, trainer: Int, turn: Int) {
        var row = actionsByTurn[turn] ?? [nil, nil, nil, nil]
        row[trainer] = action
        actionsByTurn[turn] = row
    }
    private func store(replacement slot: Int, trainer: Int, turn: Int) {
        var row = replacementsByTurn[turn] ?? Self.empty4
        row[trainer] = slot
        replacementsByTurn[turn] = row
    }
    func trainerName(_ index: Int) -> String { teams[index]?.first?.trainer ?? "?" }

    func act(_ action: TeamAction) {
        guard phase == .battling, let state, !state.awaitingReplacement, !state.isOut(myIndex),
              self.action(of: myIndex, turn: state.turn + 1) == nil else { return }
        store(action: action, trainer: myIndex, turn: state.turn + 1)
        broadcast(.action(turn: state.turn + 1, action))
        resolveIfReady()
    }

    func replace(with slot: Int) {
        guard mustReplace, let state, state.hp[myIndex][slot] > 0 else { return }
        store(replacement: slot, trainer: myIndex, turn: state.turn)
        broadcast(.replace(turn: state.turn, slot: slot))
        resolveIfReady()
    }

    func receive(_ message: TeamBattleMessage, from trainer: Int) {
        guard (0..<4).contains(trainer), trainer != myIndex else { return }
        switch message {
        case .hello(let team): teams[trainer] = team
        case .seed(let s): if trainer == 0 { seed = s }
        case .action(let turn, let action): store(action: action, trainer: trainer, turn: turn)
        case .replace(let turn, let slot): store(replacement: slot, trainer: trainer, turn: turn)
        }
        startIfReady()
        resolveIfReady()
    }

    func participantLeft() {
        guard !isOver else { return }
        phase = .disconnected
        status = "참가자 한 명과 연결이 끊겨 대결이 끝났어요."
    }

    private func broadcast(_ message: TeamBattleMessage) {
        for t in 0..<4 where t != myIndex { send(message, t) }
    }

    private func startIfReady() {
        guard state == nil, seed != nil, teams.allSatisfy({ $0 != nil }) else { return }
        let all = teams.compactMap { $0 }
        var initial = TeamBattleEngine.initialState(all)
        initial.beginStep()
        let a = all[0][0].trainer + "·" + all[1][0].trainer
        let b = all[2][0].trainer + "·" + all[3][0].trainer
        initial.say("\(a) 팀과 \(b) 팀의 2:2 대결!")
        for t in 0..<4 {
            initial.events.append(.switchIn(trainer: t, slot: 0))
            initial.say("\(all[t][0].trainer)의 \(all[t][0].name)!")
        }
        state = initial
        phase = .battling
        status = ""
    }

    private func resolveIfReady() {
        guard let state, let seed, teams.allSatisfy({ $0 != nil }) else { return }
        let all = teams.compactMap { $0 }
        if state.awaitingReplacement {
            guard waitingFor.isEmpty else { return }
            self.state = TeamBattleEngine.replace(state, teams: all, choices: replacementsByTurn[state.turn] ?? Self.empty4)
            replacementsByTurn[state.turn] = nil
            resolveIfReady()   // next-turn actions may already be in
            return
        }
        guard waitingFor.isEmpty else { return }
        let next = TeamBattleEngine.resolve(state, teams: all, actions: actionsByTurn[state.turn + 1] ?? [nil, nil, nil, nil],
                                            seed: seed)
        self.state = next
        actionsByTurn[state.turn + 1] = nil
        if let winner = next.winner {
            phase = .finished
            let won = TeamBattleState.team(of: myIndex) == winner
            status = won ? "승리!" : "패배…"
            onFinished?(won)
        }
    }
}

import Foundation
import Observation

// SPIKE: one battle between this player and one opponent in the plaza. Transport-agnostic: the
// plaza routes `BattleMessage`s to and from the opponent through `send`/`receive`.
// Challenger = host (index 0) and picks the RNG seed. Each turn both sides send an action (move or
// switch); once both are known each side resolves the turn locally with the same pure engine.
// After a faint, the fainted side sends a replacement slot before the next turn.

enum BattleMessage: Codable, Sendable {
    case hello([BattleMon])
    case seed(UInt64)
    case action(turn: Int, BattleAction)
    case replace(turn: Int, slot: Int)
}

@MainActor
@Observable
final class BattleMatch {
    enum Phase: Equatable { case starting, battling, finished, disconnected }

    let opponentID: String
    let myIndex: Int
    private(set) var phase: Phase = .starting
    private(set) var teams: [[BattleMon]?] = [nil, nil]
    private(set) var state: BattleState?
    private(set) var waitingForOpponent = false
    private(set) var status = "상대 정보 받는 중…"

    private let send: (BattleMessage) -> Void
    private var seed: UInt64?
    private var myAction: BattleAction?
    private var theirAction: BattleAction?
    private var myReplacement: Int?
    private var theirReplacement: Int?

    init(me: [BattleMon], isHost: Bool, opponentID: String, send: @escaping (BattleMessage) -> Void) {
        self.opponentID = opponentID
        self.myIndex = isHost ? 0 : 1
        self.send = send
        teams[myIndex] = me
        send(.hello(me))
        if isHost {
            let s = UInt64.random(in: 1...UInt64.max)
            seed = s
            send(.seed(s))
        }
    }

    var theirIndex: Int { 1 - myIndex }
    var myTeam: [BattleMon]? { teams[myIndex] }
    var theirTeam: [BattleMon]? { teams[theirIndex] }
    var mustReplace: Bool { state?.needsReplacement[myIndex] == true && myReplacement == nil }
    var isOver: Bool { phase == .finished || phase == .disconnected }

    func act(_ action: BattleAction) {
        guard phase == .battling, myAction == nil, let state, !state.awaitingReplacement else { return }
        myAction = action
        waitingForOpponent = true
        send(.action(turn: state.turn + 1, action))
        resolveIfReady()
    }

    func replace(with slot: Int) {
        guard mustReplace, let state, state.hp[myIndex][slot] > 0 else { return }
        myReplacement = slot
        waitingForOpponent = true
        send(.replace(turn: state.turn, slot: slot))
        resolveIfReady()
    }

    func receive(_ message: BattleMessage) {
        switch message {
        case .hello(let team): teams[theirIndex] = team
        case .seed(let s): seed = s
        case .action(_, let action): theirAction = action
        case .replace(_, let slot): theirReplacement = slot
        }
        startIfReady()
        resolveIfReady()
    }

    func opponentLeft() {
        guard !isOver else { return }
        phase = .disconnected
        status = "상대와 연결이 끊겼어요."
    }

    private func startIfReady() {
        guard state == nil, seed != nil, let a = teams[0], let b = teams[1] else { return }
        var initial = BattleEngine.initialState([a, b])
        let mine = myIndex == 0 ? a : b, theirs = myIndex == 0 ? b : a
        initial.beginStep()
        initial.say("\(KoreanParticle.subject.attach(to: theirs[0].trainer)) 승부를 걸어왔다!")
        initial.events.append(.switchIn(side: theirIndex, slot: 0))
        initial.say("\(KoreanParticle.subject.attach(to: theirs[0].trainer)) \(KoreanParticle.object.attach(to: theirs[0].name)) 내보냈다!")
        initial.events.append(.switchIn(side: myIndex, slot: 0))
        initial.say("가라, \(mine[0].name)!")
        state = initial
        phase = .battling
        status = ""
    }

    private func resolveIfReady() {
        guard let state, let seed, let a = teams[0], let b = teams[1] else { return }
        if state.awaitingReplacement {
            let needMine = state.needsReplacement[myIndex], needTheirs = state.needsReplacement[theirIndex]
            guard !needMine || myReplacement != nil, !needTheirs || theirReplacement != nil else { return }
            let choices = myIndex == 0 ? [myReplacement, theirReplacement] : [theirReplacement, myReplacement]
            self.state = BattleEngine.replace(state, teams: [a, b], choices: choices)
            myReplacement = nil
            theirReplacement = nil
            waitingForOpponent = false
            return
        }
        guard let mine = myAction, let theirs = theirAction else { return }
        let actions = myIndex == 0 ? [mine, theirs] : [theirs, mine]
        let next = BattleEngine.resolve(state, teams: [a, b], actions: actions, seed: seed)
        self.state = next
        myAction = nil
        theirAction = nil
        waitingForOpponent = false
        if let winner = next.winner {
            phase = .finished
            status = winner == myIndex ? "승리!" : "패배…"
        }
    }
}

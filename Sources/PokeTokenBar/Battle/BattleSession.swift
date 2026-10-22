import Foundation
@preconcurrency import MultipeerConnectivity
import Observation

// SPIKE: peer-to-peer battle session over MultipeerConnectivity (no server).
// Inviter = host (index 0) and picks the RNG seed. Each turn both peers send an action (move or
// switch); once both are known each side resolves the turn locally with the same pure engine.
// After a faint, the fainted side sends a replacement slot before the next turn.

enum BattleMessage: Codable {
    case hello([BattleMon])
    case seed(UInt64)
    case action(turn: Int, BattleAction)
    case replace(turn: Int, slot: Int)
}

@MainActor
@Observable
final class BattleSession: NSObject {
    static let serviceType = "ptb-battle"

    enum Phase: Equatable { case lobby, connecting, battling, finished, disconnected }

    private(set) var phase: Phase = .lobby
    private(set) var nearby: [MCPeerID] = []
    private(set) var pendingInviter: MCPeerID?
    private(set) var teams: [[BattleMon]?] = [nil, nil]
    private(set) var state: BattleState?
    private(set) var myIndex = 0
    private(set) var waitingForOpponent = false
    private(set) var status = ""

    let me: [BattleMon]
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var inviteHandler: ((Bool, MCSession?) -> Void)?
    private var opponent: MCPeerID?
    private var seed: UInt64?
    private var myAction: BattleAction?
    private var theirAction: BattleAction?
    private var myReplacement: Int?
    private var theirReplacement: Int?

    init(me: [BattleMon]) {
        self.me = me
        let trainer = me.first?.trainer ?? "트레이너"
        peerID = MCPeerID(displayName: "\(trainer) · \(me.map(\.name).joined(separator: ", "))")
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        status = "근처 상대를 찾는 중…"
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    var myTeam: [BattleMon]? { teams[myIndex] }
    var theirTeam: [BattleMon]? { teams[1 - myIndex] }
    var theirIndex: Int { 1 - myIndex }
    var mustReplace: Bool { state?.needsReplacement[myIndex] == true && myReplacement == nil }

    func invite(_ peer: MCPeerID) {
        myIndex = 0
        opponent = peer
        phase = .connecting
        status = "\(peer.displayName)에게 대결 신청 중…"
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func answerInvite(_ accept: Bool) {
        guard let handler = inviteHandler else { return }
        if accept {
            myIndex = 1
            opponent = pendingInviter
            phase = .connecting
            status = "연결 중…"
        }
        handler(accept, accept ? session : nil)
        inviteHandler = nil
        pendingInviter = nil
    }

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

    // MARK: - Internals

    private func send(_ message: BattleMessage) {
        guard let opponent, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: [opponent], with: .reliable)
    }

    private func didConnect(_ peer: MCPeerID) {
        guard peer == opponent || opponent == nil else { return }
        opponent = peer
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        teams[myIndex] = me
        send(.hello(me))
        if myIndex == 0 {
            let s = UInt64.random(in: 1...UInt64.max)
            seed = s
            send(.seed(s))
        }
        status = "상대 정보 받는 중…"
        startIfReady()
    }

    private func receive(_ message: BattleMessage) {
        switch message {
        case .hello(let team): teams[1 - myIndex] = team
        case .seed(let s): seed = s
        case .action(_, let action): theirAction = action
        case .replace(_, let slot): theirReplacement = slot
        }
        startIfReady()
        resolveIfReady()
    }

    private func startIfReady() {
        guard state == nil, seed != nil, let a = teams[0], let b = teams[1] else { return }
        var initial = BattleEngine.initialState([a, b])
        let mine = myIndex == 0 ? a : b, theirs = myIndex == 0 ? b : a
        initial.log.append("\(KoreanParticle.subject.attach(to: theirs[0].trainer)) 승부를 걸어왔다!")
        initial.log.append("가라, \(mine[0].name)! / 상대는 \(KoreanParticle.object.attach(to: theirs[0].name)) 내보냈다!")
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

    private func peerLost(_ peer: MCPeerID) {
        nearby.removeAll { $0 == peer }
    }

    private func peerDisconnected(_ peer: MCPeerID) {
        guard peer == opponent, phase == .battling || phase == .connecting else { return }
        phase = .disconnected
        status = "상대와 연결이 끊겼어요."
    }
}

extension BattleSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.didConnect(peerID)
            case .notConnected: self.peerDisconnected(peerID)
            default: break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(BattleMessage.self, from: data) else { return }
        Task { @MainActor in self.receive(message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                             fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension BattleSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        nonisolated(unsafe) let invitationHandler = invitationHandler
        Task { @MainActor in
            guard self.phase == .lobby, self.inviteHandler == nil else { invitationHandler(false, nil); return }
            self.pendingInviter = peerID
            self.inviteHandler = invitationHandler
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.status = "광고 실패: \(text)" }
    }
}

extension BattleSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !self.nearby.contains(peerID) { self.nearby.append(peerID) }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.peerLost(peerID) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.status = "검색 실패: \(text)" }
    }
}

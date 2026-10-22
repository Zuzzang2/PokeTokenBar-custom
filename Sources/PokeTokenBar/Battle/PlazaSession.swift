import Foundation
@preconcurrency import MultipeerConnectivity
import Observation

// SPIKE: the plaza — everyone nearby joins one MultipeerConnectivity mesh (no server).
// Carries presence, walking positions, chat, challenges, and the battle messages of a match.
// MCSession holds at most 8 peers including this one, so the plaza is capped at 8 people.
// To avoid double invites, only the peer with the smaller plaza ID invites; the other auto-accepts.

struct PlazaProfile: Codable, Sendable, Equatable {
    let id: String
    let trainer: String
    let speciesID: Int
    let shiny: Bool
    let leadName: String
}

enum PlazaMessage: Codable, Sendable {
    case presence(PlazaProfile, x: Double, y: Double, busy: Bool)
    case position(x: Double, y: Double)
    case chat(String)
    case busy(Bool)
    case challenge
    case challengeReply(accept: Bool)
    case battle(BattleMessage)
}

struct PlazaPlayer: Identifiable, Equatable {
    var id: String { profile.id }
    let profile: PlazaProfile
    var x: Double
    var y: Double
    var facingLeft = false
    var busy = false
    var bubble: String?
}

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let text: String
}

@MainActor
@Observable
final class PlazaSession: NSObject {
    static let serviceType = "ptb-battle"
    static let capacity = 8
    static let size = CGSize(width: 400, height: 300)

    private(set) var me: PlazaPlayer
    private(set) var players: [String: PlazaPlayer] = [:]
    private(set) var chat: [ChatLine] = []
    private(set) var incomingChallenge: String?
    private(set) var outgoingChallenge: String?
    private(set) var match: BattleMatch?
    private(set) var notice = ""

    let team: [BattleMon]
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var peers: [String: MCPeerID] = [:]      // plaza ID → peer
    private var lastPositionSent = Date.distantPast

    init(team: [BattleMon]) {
        self.team = team
        let lead = team[0]
        let profile = PlazaProfile(id: UUID().uuidString, trainer: lead.trainer, speciesID: lead.speciesID,
                                   shiny: lead.isShiny, leadName: lead.name)
        me = PlazaPlayer(profile: profile, x: Double.random(in: 80...320), y: Double.random(in: 200...260))
        peerID = MCPeerID(displayName: lead.trainer)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["id": profile.id],
                                               serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    var isFull: Bool { session.connectedPeers.count >= Self.capacity - 1 }
    var everyone: [PlazaPlayer] { [me] + players.values.sorted { $0.id < $1.id } }

    // MARK: - Actions

    func walk(dx: Double, dy: Double) {
        guard match == nil else { return }
        let next = PlazaPlayer(profile: me.profile,
                               x: min(Self.size.width - 24, max(24, me.x + dx)),
                               y: min(Self.size.height - 20, max(70, me.y + dy)),
                               facingLeft: dx == 0 ? me.facingLeft : dx < 0,
                               busy: me.busy, bubble: me.bubble)
        me = next
        if Date().timeIntervalSince(lastPositionSent) > 0.06 {
            lastPositionSent = Date()
            broadcast(.position(x: me.x, y: me.y), reliable: false)
        }
    }

    func say(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !trimmed.isEmpty else { return }
        broadcast(.chat(trimmed), reliable: true)
        appendChat(from: me.profile.trainer, text: trimmed)
        showBubble(trimmed, for: me.id)
    }

    func challenge(_ id: String) {
        guard match == nil, outgoingChallenge == nil, let target = players[id], !target.busy else { return }
        outgoingChallenge = id
        notice = "\(KoreanParticle.direction.attach(to: target.profile.trainer)) 대결 신청을 보냈어요…"
        send(.challenge, to: id)
    }

    func answerChallenge(_ accept: Bool) {
        guard let id = incomingChallenge else { return }
        incomingChallenge = nil
        send(.challengeReply(accept: accept), to: id)
        if accept { startMatch(with: id, isHost: false) }
    }

    func leaveMatch() {
        match = nil
        setBusy(false)
    }

    // MARK: - Internals

    private func startMatch(with id: String, isHost: Bool) {
        outgoingChallenge = nil
        notice = ""
        match = BattleMatch(me: team, isHost: isHost, opponentID: id) { [weak self] message in
            self?.send(.battle(message), to: id)
        }
        setBusy(true)
    }

    private func setBusy(_ busy: Bool) {
        me = PlazaPlayer(profile: me.profile, x: me.x, y: me.y, facingLeft: me.facingLeft, busy: busy, bubble: me.bubble)
        broadcast(.busy(busy), reliable: true)
    }

    private func appendChat(from name: String, text: String) {
        chat = Array((chat + [ChatLine(name: name, text: text)]).suffix(50))
    }

    private func showBubble(_ text: String, for id: String) {
        update(id) { $0.bubble = text }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            self?.update(id) { if $0.bubble == text { $0.bubble = nil } }
        }
    }

    /// Replaces one player value (self or remote) with a modified copy.
    private func update(_ id: String, _ change: (inout PlazaPlayer) -> Void) {
        if id == me.id {
            var copy = me
            change(&copy)
            me = copy
        } else if var copy = players[id] {
            change(&copy)
            players = players.merging([id: copy]) { _, new in new }
        }
    }

    private func encode(_ message: PlazaMessage) -> Data? { try? JSONEncoder().encode(message) }

    private func send(_ message: PlazaMessage, to id: String) {
        guard let peer = peers[id], let data = encode(message) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func broadcast(_ message: PlazaMessage, reliable: Bool) {
        let targets = session.connectedPeers
        guard !targets.isEmpty, let data = encode(message) else { return }
        try? session.send(data, toPeers: targets, with: reliable ? .reliable : .unreliable)
    }

    private func presence() -> PlazaMessage { .presence(me.profile, x: me.x, y: me.y, busy: me.busy) }

    private func didConnect(_ peer: MCPeerID) {
        guard let data = encode(presence()) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func didDisconnect(_ peer: MCPeerID) {
        guard let id = peers.first(where: { $0.value == peer })?.key else { return }
        peers = peers.filter { $0.key != id }
        let name = players[id]?.profile.trainer
        players = players.filter { $0.key != id }
        if let name { appendChat(from: "광장", text: "\(KoreanParticle.subject.attach(to: name)) 떠났어요.") }
        if incomingChallenge == id { incomingChallenge = nil }
        if outgoingChallenge == id { outgoingChallenge = nil; notice = "" }
        if match?.opponentID == id { match?.opponentLeft() }
    }

    private func receive(_ message: PlazaMessage, from peer: MCPeerID) {
        if case .presence(let profile, let x, let y, let busy) = message {
            let isNew = players[profile.id] == nil
            peers = peers.merging([profile.id: peer]) { _, new in new }
            players = players.merging([profile.id: PlazaPlayer(profile: profile, x: x, y: y, busy: busy)]) { _, new in new }
            if isNew { appendChat(from: "광장", text: "\(KoreanParticle.subject.attach(to: profile.trainer)) 들어왔어요.") }
            return
        }
        guard let id = peers.first(where: { $0.value == peer })?.key else { return }
        switch message {
        case .presence: break
        case .position(let x, let y):
            update(id) { p in
                if x != p.x { p.facingLeft = x < p.x }
                p.x = x
                p.y = y
            }
        case .chat(let text):
            appendChat(from: players[id]?.profile.trainer ?? "?", text: text)
            showBubble(text, for: id)
        case .busy(let busy):
            update(id) { $0.busy = busy }
        case .challenge:
            if match != nil || incomingChallenge != nil || outgoingChallenge != nil {
                send(.challengeReply(accept: false), to: id)
            } else {
                incomingChallenge = id
            }
        case .challengeReply(let accept):
            guard outgoingChallenge == id else { return }
            if accept {
                startMatch(with: id, isHost: true)
            } else {
                outgoingChallenge = nil
                notice = "\(KoreanParticle.subject.attach(to: players[id]?.profile.trainer ?? "상대")) 거절했어요."
            }
        case .battle(let battleMessage):
            if match?.opponentID == id { match?.receive(battleMessage) }
        }
    }

    private func found(_ peer: MCPeerID, id: String?) {
        // Smaller ID invites; the other side waits for the invitation.
        guard let id, me.id < id, !session.connectedPeers.contains(peer), !isFull else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }
}

extension PlazaSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.didConnect(peerID)
            case .notConnected: self.didDisconnect(peerID)
            default: break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(PlazaMessage.self, from: data) else { return }
        Task { @MainActor in self.receive(message, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                             fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PlazaSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        nonisolated(unsafe) let invitationHandler = invitationHandler
        Task { @MainActor in
            invitationHandler(!self.isFull, self.isFull ? nil : self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.notice = "광장 공개 실패: \(text)" }
    }
}

extension PlazaSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let id = info?["id"]
        Task { @MainActor in self.found(peerID, id: id) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.notice = "광장 검색 실패: \(text)" }
    }
}

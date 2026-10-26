import Foundation
@preconcurrency import MultipeerConnectivity
import Observation

// SPIKE: the 메아리 lobby — everyone nearby with the 메아리 window open joins one MultipeerConnectivity mesh
// (same pattern as the kart lobby, its own service type). The trainer with the smallest lobby ID hosts and
// owns the loop: it starts loops, collects everyone's runs into echoes and decides clears.
// Live positions go unreliable ~30 times a second; everything that changes the loop goes reliable.

struct EchoPlayerInfo: Codable, Sendable, Equatable {
    let id: String
    var trainer: String
    var speciesID: Int?
    var isShiny: Bool
    var pokemonName: String
    var inGame: Bool
}

struct EchoRosterEntry: Codable, Sendable, Equatable {
    let id: String
    let trainer: String
    let pokemonName: String
    let speciesID: Int?
    let isShiny: Bool
}

struct EchoStart: Codable, Sendable, Equatable {
    let gameID: String
    let hostID: String
    let roster: [EchoRosterEntry]
}

/// The host's word on the loop everyone plays next.
struct EchoLoopStart: Codable, Sendable, Equatable {
    let gameID: String
    let level: Int
    let loop: Int
    let echoes: [EchoOwned]
    /// Players whose echo budget was full when the last loop ended.
    let full: [String]
}

enum EchoRequest: String, Codable, Sendable { case rewind, erase }

enum EchoMessage: Codable, Sendable {
    case hello(EchoPlayerInfo)
    case start(EchoStart)
    case loop(EchoLoopStart)
    case state(gameID: String, loop: Int, id: String, x: Float, y: Float, facing: Int8, alive: Bool)
    case request(gameID: String, loop: Int, id: String, kind: EchoRequest)
    case exited(gameID: String, loop: Int, id: String)
    case died(gameID: String, loop: Int, id: String)
    case endLoop(gameID: String, loop: Int, by: String?)
    case recording(gameID: String, loop: Int, run: EchoOwned)
    case cleared(gameID: String, level: Int, loops: Int)
    case finished(gameID: String, loops: Int, echoes: Int)
}

@MainActor
@Observable
final class EchoSession: NSObject {
    static let serviceType = "ptb-echo1"
    static let capacity = 4

    private(set) var me: EchoPlayerInfo
    private(set) var players: [String: EchoPlayerInfo] = [:]
    private(set) var notice = ""

    @ObservationIgnored var onMessage: ((EchoMessage) -> Void)?
    @ObservationIgnored var onPeerLeft: ((String) -> Void)?

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private let advertiser: MCNearbyServiceAdvertiser
    @ObservationIgnored private let browser: MCNearbyServiceBrowser
    @ObservationIgnored private var peers: [String: MCPeerID] = [:]
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var activity: NSObjectProtocol?

    init(me: EchoPlayerInfo) {
        self.me = me
        let display = String(me.trainer.prefix(20))
        peerID = MCPeerID(displayName: display.isEmpty ? "trainer" : display)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["id": me.id], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                        reason: "메아리 co-op networking")
        // Presence is re-sent now and then so a missed hello heals on its own.
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.broadcastHello()
            }
        }
    }

    func stop() {
        heartbeat?.cancel()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    // MARK: lobby

    var everyone: [EchoPlayerInfo] { [me] + players.values.sorted { $0.id < $1.id } }
    var hostID: String { everyone.map(\.id).min() ?? me.id }
    var isHost: Bool { hostID == me.id }
    var isFull: Bool { session.connectedPeers.count >= Self.capacity - 1 }
    /// Trainers the host's start button takes along (everyone not already mid-game).
    var waiting: [EchoPlayerInfo] { everyone.filter { !$0.inGame || $0.id == me.id } }

    func update(_ change: (inout EchoPlayerInfo) -> Void) {
        var copy = me
        change(&copy)
        guard copy != me else { return }
        me = copy
        broadcastHello()
    }

    /// Host only: everyone waiting plays together.
    func startGame() {
        guard isHost else { return }
        let roster = waiting.map {
            EchoRosterEntry(id: $0.id, trainer: $0.trainer, pokemonName: $0.pokemonName, speciesID: $0.speciesID,
                            isShiny: $0.isShiny)
        }
        let start = EchoStart(gameID: UUID().uuidString, hostID: me.id, roster: roster)
        send(.start(start))
    }

    /// Sends to everyone and hands the same message to this machine, so the host's own actions take the
    /// exact path a peer's would.
    func send(_ message: EchoMessage) {
        broadcast(message, reliable: !Self.isState(message))
        onMessage?(message)
    }

    /// Live position: only to the others, unreliable.
    func sendState(_ message: EchoMessage) { broadcast(message, reliable: false) }

    private static func isState(_ m: EchoMessage) -> Bool {
        if case .state = m { return true }
        return false
    }

    // MARK: transport

    private func broadcastHello() { broadcast(.hello(me), reliable: true) }

    private func broadcast(_ message: EchoMessage, reliable: Bool) {
        let targets = session.connectedPeers
        guard !targets.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: targets, with: reliable ? .reliable : .unreliable)
    }

    private func found(_ peer: MCPeerID, id: String?) {
        // Smaller ID invites; the other side waits for the invitation.
        guard let id, me.id < id, !session.connectedPeers.contains(peer), !isFull else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    private func didConnect(_ peer: MCPeerID) {
        guard let data = try? JSONEncoder().encode(EchoMessage.hello(me)) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func didDisconnect(_ peer: MCPeerID) {
        guard let id = peers.first(where: { $0.value == peer })?.key else { return }
        peers = peers.filter { $0.key != id }
        if let name = players[id]?.trainer { notice = "\(name) 님이 나갔어요." }
        players = players.filter { $0.key != id }
        onPeerLeft?(id)
    }

    private func receive(_ message: EchoMessage, from peer: MCPeerID) {
        if case .hello(let info) = message {
            if players[info.id] == nil { notice = "\(info.trainer) 님이 들어왔어요." }
            peers = peers.merging([info.id: peer]) { _, new in new }
            players = players.merging([info.id: info]) { _, new in new }
            return
        }
        if case .start(let start) = message, !start.roster.contains(where: { $0.id == me.id }) { return }
        onMessage?(message)
    }
}

extension EchoSession: MCSessionDelegate {
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
        guard let message = try? JSONDecoder().decode(EchoMessage.self, from: data) else { return }
        Task { @MainActor in self.receive(message, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                             fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension EchoSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        nonisolated(unsafe) let invitationHandler = invitationHandler
        Task { @MainActor in
            invitationHandler(!self.isFull, self.isFull ? nil : self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.notice = "대기방 공개 실패: \(text)" }
    }
}

extension EchoSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let id = info?["id"]
        Task { @MainActor in self.found(peerID, id: id) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.notice = "대기방 검색 실패: \(text)" }
    }
}

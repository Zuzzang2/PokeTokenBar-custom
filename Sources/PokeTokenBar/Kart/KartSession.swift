import Foundation
@preconcurrency import MultipeerConnectivity
import Observation

// SPIKE: the kart lobby — everyone nearby with the kart window open joins one MultipeerConnectivity
// mesh (no server, same pattern as the plaza, its own service type). The trainer with the smallest
// lobby ID hosts: only the host can start a race, and the host simulates the CPU karts.
// During a race each machine drives its own kart and broadcasts its state ~30 times a second over
// the unreliable channel; the others extrapolate and ease toward it. Starts and finishes go reliable.

struct KartPlayerInfo: Codable, Sendable, Equatable {
    let id: String
    var trainer: String
    var speciesID: Int?
    var isShiny: Bool
    var level: Int
    var pokemonName: String
    var inRace: Bool
    var build: String?
}

struct KartRosterEntry: Codable, Sendable, Equatable {
    let id: String
    let trainer: String
    let pokemonName: String
    let speciesID: Int?
    let isShiny: Bool
    let level: Int
    let isCPU: Bool
    /// CPU top-speed factor picked by the host, so every machine draws the same pack.
    let skill: Double
}

struct KartRaceStart: Codable, Sendable, Equatable {
    let raceID: String
    let hostID: String
    let roster: [KartRosterEntry]
}

/// One kart's snapshot on the wire. Floats keep the packet small at 30 Hz.
struct KartNetKart: Codable, Sendable {
    let id: String
    let seq: UInt32
    let x: Float, y: Float
    let vx: Float, vy: Float
    let heading: Float
    let speed: Float
    /// -1 = not drifting, else the drift charge tier (0…2).
    let drift: Int8
    let boost: Bool
    let hop: Bool
    let progress: Int32
    let finish: Double?
}

enum KartMessage: Codable, Sendable {
    case hello(KartPlayerInfo)
    case start(KartRaceStart)
    case state(raceID: String, karts: [KartNetKart])
    case finished(raceID: String, id: String, time: Double)
}

@MainActor
@Observable
final class KartSession: NSObject {
    static let serviceType = "ptb-kart1"
    static let capacity = 8
    static let myBuild: String? = Bundle.main.object(forInfoDictionaryKey: "PTBBuild") as? String

    private(set) var me: KartPlayerInfo
    private(set) var players: [String: KartPlayerInfo] = [:]
    private(set) var notice = ""

    @ObservationIgnored var onStart: ((KartRaceStart) -> Void)?
    @ObservationIgnored var onState: ((String, [KartNetKart]) -> Void)?
    @ObservationIgnored var onFinished: ((String, String, Double) -> Void)?
    @ObservationIgnored var onPeerLeft: ((String) -> Void)?

    @ObservationIgnored private let peerID: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private let advertiser: MCNearbyServiceAdvertiser
    @ObservationIgnored private let browser: MCNearbyServiceBrowser
    @ObservationIgnored private var peers: [String: MCPeerID] = [:]
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var activity: NSObjectProtocol?

    init(me: KartPlayerInfo) {
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
                                                        reason: "Kart race networking")
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

    var everyone: [KartPlayerInfo] { [me] + players.values.sorted { $0.id < $1.id } }
    var hostID: String { everyone.map(\.id).min() ?? me.id }
    var isHost: Bool { hostID == me.id }
    var isFull: Bool { session.connectedPeers.count >= Self.capacity - 1 }
    /// Trainers the host's start button would take along (everyone not already mid-race).
    var waiting: [KartPlayerInfo] { everyone.filter { !$0.inRace || $0.id == me.id } }

    func update(_ change: (inout KartPlayerInfo) -> Void) {
        var copy = me
        change(&copy)
        guard copy != me else { return }
        me = copy
        broadcastHello()
    }

    /// Host only: everyone waiting in the lobby races; `cpus` fill the remaining grid slots.
    func startRace(cpus: [KartRosterEntry]) {
        guard isHost else { return }
        var roster = waiting.shuffled().map {
            KartRosterEntry(id: $0.id, trainer: $0.trainer, pokemonName: $0.pokemonName, speciesID: $0.speciesID,
                            isShiny: $0.isShiny, level: $0.level, isCPU: false, skill: 1)
        }
        roster += cpus.prefix(max(0, Self.capacity - roster.count))
        let start = KartRaceStart(raceID: UUID().uuidString, hostID: me.id, roster: roster)
        broadcast(.start(start), reliable: true)
        onStart?(start)
    }

    func sendState(raceID: String, karts: [KartNetKart]) {
        broadcast(.state(raceID: raceID, karts: karts), reliable: false)
    }

    func sendFinished(raceID: String, id: String, time: Double) {
        broadcast(.finished(raceID: raceID, id: id, time: time), reliable: true)
    }

    // MARK: transport

    private func broadcastHello() { broadcast(.hello(me), reliable: true) }

    private func broadcast(_ message: KartMessage, reliable: Bool) {
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
        guard let data = try? JSONEncoder().encode(KartMessage.hello(me)) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func didDisconnect(_ peer: MCPeerID) {
        guard let id = peers.first(where: { $0.value == peer })?.key else { return }
        peers = peers.filter { $0.key != id }
        if let name = players[id]?.trainer { notice = "\(name) 님이 나갔어요." }
        players = players.filter { $0.key != id }
        onPeerLeft?(id)
    }

    private func receive(_ message: KartMessage, from peer: MCPeerID) {
        switch message {
        case .hello(let info):
            if players[info.id] == nil { notice = "\(info.trainer) 님이 들어왔어요." }
            peers = peers.merging([info.id: peer]) { _, new in new }
            players = players.merging([info.id: info]) { _, new in new }
        case .start(let start):
            guard start.roster.contains(where: { $0.id == me.id }) else { return }
            onStart?(start)
        case .state(let raceID, let karts):
            onState?(raceID, karts)
        case .finished(let raceID, let id, let time):
            onFinished?(raceID, id, time)
        }
    }
}

extension KartSession: MCSessionDelegate {
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
        guard let message = try? JSONDecoder().decode(KartMessage.self, from: data) else { return }
        Task { @MainActor in self.receive(message, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                             fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension KartSession: MCNearbyServiceAdvertiserDelegate {
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

extension KartSession: MCNearbyServiceBrowserDelegate {
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

import Foundation
@preconcurrency import MultipeerConnectivity

// SPIKE: the 픽셀 모험 mesh. Everyone nearby with the game open joins one MultipeerConnectivity session
// (own service type, max 8). Each player starts hosting their own world; whenever two hosts meet, the
// one with the larger key yields and joins the other, so the group always ends up in one world. If the
// host leaves, the remaining player with the smallest key starts hosting and the rest join them.
// Snapshots are LZFSE-compressed; small ones go over the unreliable channel, the rest reliably.

@MainActor
final class RpgSession: NSObject {
    static let serviceType = "ptb-rpg1"
    static let capacity = 8

    struct Peer {
        let mc: MCPeerID
        var hosting: Bool
        var name: String
    }

    let key = UUID().uuidString
    private(set) var hosting = true
    private(set) var peers: [String: Peer] = [:]
    var onMessage: ((RpgNetMessage, String) -> Void)?
    var onPeerLeft: ((String) -> Void)?
    var onPeersChanged: (() -> Void)?
    var name: String

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var heartbeat: Timer?
    private var activity: NSObjectProtocol?

    init(name: String) {
        self.name = name
        let display = String(name.prefix(20))
        peerID = MCPeerID(displayName: display.isEmpty ? "모험가" : display)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["id": key], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Pixel adventure networking")
        heartbeat = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sayHello() }
        }
    }

    func stop() {
        heartbeat?.invalidate()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    var connectedCount: Int { peers.count }

    /// The host this player should be in: the smallest key among hosts, counting itself when hosting.
    var electedHost: String? {
        var hosts = peers.filter(\.value.hosting).map(\.key)
        if hosting { hosts.append(key) }
        return hosts.min()
    }

    func setHosting(_ on: Bool) {
        hosting = on
        sayHello()
    }

    func sayHello() { broadcast(.hello(peer: key, hosting: hosting, name: name), reliable: true) }

    // MARK: transport

    private func encode(_ message: RpgNetMessage) -> (Data, Bool)? {
        guard let raw = try? JSONEncoder().encode(message) else { return nil }
        let packed = (try? (raw as NSData).compressed(using: .lzfse) as Data) ?? raw
        var out = Data([packed.count < raw.count ? 1 : 0])
        out.append(packed.count < raw.count ? packed : raw)
        return (out, out.count < 7000)
    }

    nonisolated private static func decode(_ data: Data) -> RpgNetMessage? {
        guard let flag = data.first else { return nil }
        let body = data.dropFirst()
        let raw = flag == 1 ? (try? (Data(body) as NSData).decompressed(using: .lzfse) as Data) : Data(body)
        guard let raw else { return nil }
        return try? JSONDecoder().decode(RpgNetMessage.self, from: raw)
    }

    func broadcast(_ message: RpgNetMessage, reliable: Bool) {
        let targets = session.connectedPeers
        guard !targets.isEmpty, let (data, small) = encode(message) else { return }
        try? session.send(data, toPeers: targets, with: reliable || !small ? .reliable : .unreliable)
    }

    func send(_ message: RpgNetMessage, to peerKey: String, reliable: Bool) {
        guard let peer = peers[peerKey]?.mc, let (data, small) = encode(message) else { return }
        try? session.send(data, toPeers: [peer], with: reliable || !small ? .reliable : .unreliable)
    }

    private func found(_ peer: MCPeerID, id: String?) {
        guard let id, key < id, !session.connectedPeers.contains(peer), session.connectedPeers.count < Self.capacity - 1 else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    private func didConnect(_ peer: MCPeerID) {
        guard let (data, _) = encode(.hello(peer: key, hosting: hosting, name: name)) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func didDisconnect(_ peer: MCPeerID) {
        guard let k = peers.first(where: { $0.value.mc == peer })?.key else { return }
        peers.removeValue(forKey: k)
        onPeerLeft?(k)
        onPeersChanged?()
    }

    private func receive(_ message: RpgNetMessage, from mc: MCPeerID) {
        if case .hello(let k, let isHosting, let n) = message {
            let changed = peers[k]?.hosting != isHosting || peers[k] == nil
            peers[k] = Peer(mc: mc, hosting: isHosting, name: n)
            if changed { onPeersChanged?() }
            return
        }
        guard let from = peers.first(where: { $0.value.mc == mc })?.key else { return }
        onMessage?(message, from)
    }
}

extension RpgSession: MCSessionDelegate {
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
        guard let message = Self.decode(data) else { return }
        Task { @MainActor in self.receive(message, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
                             with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
                             at localURL: URL?, withError error: Error?) {}
}

extension RpgSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        nonisolated(unsafe) let invitationHandler = invitationHandler
        Task { @MainActor in
            let full = self.session.connectedPeers.count >= Self.capacity - 1
            invitationHandler(!full, full ? nil : self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

extension RpgSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let id = info?["id"]
        Task { @MainActor in self.found(peerID, id: id) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

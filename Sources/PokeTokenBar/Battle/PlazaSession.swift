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
    /// Optional so presence from builds before the trainer picker still decodes.
    var trainerDesign: String?
    /// Builds before collection sharing omit this, so a peer without it cannot answer a request.
    var sharesCollection: Bool?
    /// Same idea for 2:2 team battles: builds without it cannot answer an invitation.
    var teamBattle: Bool?
    /// Popularity other trainers gave this one; omitted by builds without it.
    var popularity: Int?
}

/// Who is in a 2:2 team battle: `ids` = [host, host's partner, foe 1, foe 2].
struct TeamRoster: Codable, Sendable, Equatable {
    let matchID: String
    let ids: [String]
    let names: [String]
}

/// The host picking a partner and two foes in the plaza.
struct TeamDraft: Equatable {
    let partner: String
    var foes: [String] = []
}

/// An invitation (or, for the host, the wait for everyone's answer) before a team battle starts.
struct PendingTeam: Equatable {
    let roster: TeamRoster
    let isHost: Bool
    var accepted: Set<String> = []
    var answered = false
}

/// One owned Pokémon in the collection a trainer shares when another trainer asks to see it.
struct CollectionEntry: Codable, Sendable, Equatable {
    let speciesID: Int
    let name: String
    let shiny: Bool
    /// Cap on what one trainer shares, keeping the reliable message small.
    static let maxShared = 300
}

/// The collection the local player is looking at; `entries` is nil until the owner answers.
struct ViewedCollection: Equatable {
    let playerID: String
    let trainer: String
    var entries: [CollectionEntry]?
    /// No answer within `PlazaSession.collectionTimeout`.
    var timedOut = false
}

enum PlazaMessage: Codable, Sendable {
    case presence(PlazaProfile, x: Double, y: Double, busy: Bool)
    case position(x: Double, y: Double)
    case chat(String)
    case busy(Bool)
    case challenge
    case challengeReply(accept: Bool)
    case battle(BattleMessage)
    case collectionRequest
    case collection([CollectionEntry])
    case teamInvite(TeamRoster)
    case teamReply(matchID: String, accept: Bool)
    case teamStart(matchID: String)
    case teamCancel(matchID: String)
    case team(TeamBattleMessage)
    case popularityVote
    case popularity(Int)
}

struct PlazaPlayer: Identifiable, Equatable {
    var id: String { profile.id }
    var profile: PlazaProfile
    var x: Double               // authoritative position (own input, or last network update)
    var y: Double
    var shownX: Double          // drawn position; eases toward x/y for remote players
    var shownY: Double
    var followerX: Double       // lead Pokémon trailing behind
    var followerY: Double
    var facing: PlazaFacing = .down
    var walked = 0.0            // distance walked; drives the walking frames
    var moving = false
    var busy = false
    var bubble: String?

    init(profile: PlazaProfile, x: Double, y: Double, busy: Bool = false) {
        self.profile = profile
        self.x = x
        self.y = y
        shownX = x
        shownY = y
        let behind = PlazaMotion.offset(.down)
        followerX = x - behind.width
        followerY = y - behind.height
        self.busy = busy
    }

    var walkFrame: Int { moving ? Int(walked / PlazaMotion.stepLength) % 2 : 0 }
}

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let text: String
}

@MainActor
@Observable
final class PlazaSession: NSObject {
    /// Bumped with the town map: older builds use a 400×267 space and must not share a plaza.
    static let serviceType = "ptb-plaza2"
    static let capacity = 8
    nonisolated static var size: CGSize { PlazaMap.size }
    nonisolated static func isWalkable(x: Double, y: Double) -> Bool { PlazaMap.isWalkable(x: x, y: y) }

    private(set) var me: PlazaPlayer
    private(set) var players: [String: PlazaPlayer] = [:]
    private(set) var chat: [ChatLine] = []
    private(set) var incomingChallenge: String?
    private(set) var outgoingChallenge: String?
    private(set) var match: BattleMatch?
    private(set) var notice = ""
    private(set) var viewedCollection: ViewedCollection?
    private(set) var moveTarget: CGPoint?
    private(set) var teamDraft: TeamDraft?
    private(set) var pendingTeam: PendingTeam?
    private(set) var teamMatch: TeamBattleMatch?
    /// When this player last gave popularity; one vote per calendar day, to anyone.
    private(set) var lastVoteDate = UserDefaults.standard.object(forKey: PlazaSession.lastVoteKey) as? Date
    private var votersThisSession: Set<String> = []

    let team: [BattleMon]
    private let collection: [CollectionEntry]
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var peers: [String: MCPeerID] = [:]      // plaza ID → peer
    private var lastPositionSent = Date.distantPast
    private var heldKeys: Set<PlazaFacing> = []
    private var pressedAt: [PlazaFacing: Date] = [:]
    private var pendingRelease: Set<PlazaFacing> = []
    /// Keeps App Nap from throttling the 60 fps ticker while the plaza is open.
    private var activity: NSObjectProtocol?
    private var ticker: Task<Void, Never>?

    init(team: [BattleMon], collection: [CollectionEntry] = [], trainerDesign: String) {
        self.team = team
        self.collection = Array(collection.prefix(CollectionEntry.maxShared))
        let lead = team[0]
        let profile = PlazaProfile(id: UUID().uuidString, trainer: lead.trainer, speciesID: lead.speciesID,
                                   shiny: lead.isShiny, leadName: lead.name, trainerDesign: trainerDesign,
                                   sharesCollection: true, teamBattle: true,
                                   popularity: Self.storedPopularity)
        let spawn = PlazaMap.randomSpawn()
        me = PlazaPlayer(profile: profile, x: spawn.x, y: spawn.y)
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
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                        reason: "Plaza movement and interpolation")
        startTicker()
    }

    func stop() {
        ticker?.cancel()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    var isFull: Bool { session.connectedPeers.count >= Self.capacity - 1 }
    var everyone: [PlazaPlayer] { [me] + players.values.sorted { $0.id < $1.id } }

    // MARK: - Actions

    /// A tap still walks one short step: a key counts as held for at least `minimumHold` seconds.
    static let minimumHold = 0.12

    func setKey(_ direction: PlazaFacing, pressed: Bool) {
        if pressed {
            // A new press (not a key repeat) restarts the hold, cancelling a pending tap release.
            if !heldKeys.contains(direction) || pendingRelease.contains(direction) {
                pressedAt = pressedAt.merging([direction: Date()]) { _, new in new }
                pendingRelease = pendingRelease.subtracting([direction])
            }
            heldKeys = heldKeys.union([direction])
            return
        }
        let heldFor = Date().timeIntervalSince(pressedAt[direction] ?? .distantPast)
        let remaining = Self.minimumHold - heldFor
        guard remaining > 0 else { heldKeys = heldKeys.subtracting([direction]); return }
        let pressStart = pressedAt[direction]
        pendingRelease = pendingRelease.union([direction])
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard let self, self.pendingRelease.contains(direction), self.pressedAt[direction] == pressStart else { return }
            self.pendingRelease = self.pendingRelease.subtracting([direction])
            self.heldKeys = self.heldKeys.subtracting([direction])
        }
    }

    func releaseAllKeys() { heldKeys = [] }

    /// Right-click: walk to a world point, until it is reached, blocked or a key is pressed.
    func walk(to point: CGPoint) {
        guard match == nil, teamMatch == nil else { return }
        moveTarget = point
    }

    /// One frame of motion for everyone, ~60 times a second while the plaza is open.
    private func startTicker() {
        ticker = Task { [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date()
                self?.tick(dt: min(0.05, now.timeIntervalSince(last)))
                last = now
            }
        }
    }

    private func tick(dt: Double) {
        let wasMoving = me.moving
        let inBattle = match != nil || teamMatch != nil
        let held = inBattle ? [] : heldKeys
        if !held.isEmpty || inBattle { moveTarget = nil }   // keys win over a pending click
        if held.isEmpty == false || moveTarget != nil || me.moving
            || me.followerX != me.shownX - PlazaMotion.offset(me.facing).width {
            me = PlazaMotion.walk(me, held: held, dt: dt, toward: moveTarget)
            if let target = moveTarget, !me.moving || hypot(target.x - me.x, target.y - me.y) < 0.5 {
                moveTarget = nil   // arrived or blocked
            }
        }
        if me.moving, Date().timeIntervalSince(lastPositionSent) > 1.0 / 15 {
            lastPositionSent = Date()
            broadcast(.position(x: me.x, y: me.y), reliable: false)
        } else if wasMoving, !me.moving {
            broadcast(.position(x: me.x, y: me.y), reliable: true)   // land exactly where we stopped
        }
        let settled = players.values.allSatisfy { p in
            !p.moving && p.shownX == p.x && p.shownY == p.y
                && abs(p.followerX - (p.shownX - PlazaMotion.offset(p.facing).width)) < 0.3
        }
        if !settled { players = players.mapValues { PlazaMotion.follow($0, dt: dt) } }
    }

    func say(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !trimmed.isEmpty else { return }
        broadcast(.chat(trimmed), reliable: true)
        appendChat(from: me.profile.trainer, text: trimmed)
        showBubble(trimmed, for: me.id)
    }

    func challenge(_ id: String) {
        guard match == nil, outgoingChallenge == nil, !isInTeamFlow, let target = players[id], !target.busy else { return }
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

    // MARK: - Popularity

    private static let popularityKey = "plazaPopularity"
    private static let lastVoteKey = "plazaLastPopularityVote"
    static var storedPopularity: Int { UserDefaults.standard.integer(forKey: popularityKey) }

    var canVoteToday: Bool { lastVoteDate.map { !Calendar.current.isDateInToday($0) } ?? true }

    /// Gives `id` one popularity point. Once per calendar day in total, not per trainer.
    func raisePopularity(of id: String) {
        guard canVoteToday, id != me.id, let target = players[id] else { return }
        let now = Date()
        UserDefaults.standard.set(now, forKey: Self.lastVoteKey)
        lastVoteDate = now
        send(.popularityVote, to: id)
        notice = "\(KoreanParticle.object.attach(to: target.profile.trainer)) 응원했어요 ♥ 인기도가 올라갔어요!"
    }

    private func receivePopularity(_ message: PlazaMessage, from id: String) {
        switch message {
        case .popularityVote:
            // A trainer can give one point per session here, on top of their own once-a-day limit.
            guard votersThisSession.insert(id).inserted else { return }
            let total = Self.storedPopularity + 1
            UserDefaults.standard.set(total, forKey: Self.popularityKey)
            update(me.id) { $0.profile.popularity = total }
            broadcast(.popularity(total), reliable: true)
            appendChat(from: "광장", text: "\(KoreanParticle.subject.attach(to: players[id]?.profile.trainer ?? "누군가")) 인기도를 올려줬어요 ♥ (\(total))")
        case .popularity(let total):
            update(id) { $0.profile.popularity = total }
        default:
            break
        }
    }

    // MARK: - 2:2 team battle

    private var isInTeamFlow: Bool { teamDraft != nil || pendingTeam != nil || teamMatch != nil }
    static let teamInviteTimeout = 25.0

    func canJoinTeam(_ player: PlazaPlayer) -> Bool { player.profile.teamBattle == true && !player.busy }

    /// Host step 1: `partner` becomes the teammate; the next two picks are the opponents.
    func beginTeamDraft(partner id: String) {
        guard match == nil, outgoingChallenge == nil, incomingChallenge == nil, !isInTeamFlow,
              let target = players[id], canJoinTeam(target) else { return }
        teamDraft = TeamDraft(partner: id)
        notice = ""
    }

    func cancelTeamDraft() { teamDraft = nil }

    /// Host step 2: pick opponents; the second one sends the invitations.
    func draftPick(_ id: String) {
        guard var draft = teamDraft, id != me.id, id != draft.partner, !draft.foes.contains(id),
              let target = players[id], canJoinTeam(target) else { return }
        draft.foes.append(id)
        guard draft.foes.count == 2 else { teamDraft = draft; return }
        teamDraft = nil
        let ids = [me.id, draft.partner] + draft.foes
        let roster = TeamRoster(matchID: UUID().uuidString, ids: ids,
                                names: ids.map { id in everyone.first { $0.id == id }?.profile.trainer ?? "?" })
        pendingTeam = PendingTeam(roster: roster, isHost: true, answered: true)
        for other in ids.dropFirst() { send(.teamInvite(roster), to: other) }
        expireTeamInvite(roster.matchID)
    }

    func answerTeamInvite(_ accept: Bool) {
        guard var pending = pendingTeam, !pending.isHost, !pending.answered else { return }
        let host = pending.roster.ids[0]
        send(.teamReply(matchID: pending.roster.matchID, accept: accept), to: host)
        if accept {
            pending.answered = true
            pendingTeam = pending
        } else {
            pendingTeam = nil
        }
    }

    /// Host: abandon an invitation round and tell everyone who was asked.
    func cancelPendingTeam() {
        guard let pending = pendingTeam else { return }
        if pending.isHost {
            for other in pending.roster.ids.dropFirst() { send(.teamCancel(matchID: pending.roster.matchID), to: other) }
        } else {
            send(.teamReply(matchID: pending.roster.matchID, accept: false), to: pending.roster.ids[0])
        }
        pendingTeam = nil
    }

    func leaveTeamMatch() {
        teamMatch = nil
        setBusy(false)
    }

    private func expireTeamInvite(_ matchID: String) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.teamInviteTimeout))
            guard let self, self.pendingTeam?.roster.matchID == matchID, self.teamMatch == nil else { return }
            self.notice = "팀 대결 신청에 응답이 없어 취소됐어요."
            self.cancelPendingTeam()
        }
    }

    private func startTeamMatch(_ roster: TeamRoster) {
        guard let myIndex = roster.ids.firstIndex(of: me.id) else { return }
        pendingTeam = nil
        notice = ""
        teamMatch = TeamBattleMatch(me: team, roster: roster.ids, myIndex: myIndex) { [weak self] message, to in
            self?.send(.team(message), to: roster.ids[to])
        }
        setBusy(true)
    }

    private func receiveTeam(_ message: PlazaMessage, from id: String) {
        switch message {
        case .teamInvite(let roster):
            guard roster.ids.count == 4, roster.ids[0] == id, roster.ids.contains(me.id),
                  roster.names.count == 4 else { return }
            if match != nil || incomingChallenge != nil || outgoingChallenge != nil || isInTeamFlow || me.busy {
                send(.teamReply(matchID: roster.matchID, accept: false), to: id)
            } else {
                pendingTeam = PendingTeam(roster: roster, isHost: false)
                expireTeamInvite(roster.matchID)
            }
        case .teamReply(let matchID, let accept):
            guard var pending = pendingTeam, pending.isHost, pending.roster.matchID == matchID,
                  pending.roster.ids.contains(id) else { return }
            guard accept else {
                notice = "\(KoreanParticle.subject.attach(to: players[id]?.profile.trainer ?? "참가자")) 거절해서 팀 대결이 취소됐어요."
                cancelPendingTeam()
                return
            }
            pending.accepted.insert(id)
            pendingTeam = pending
            if pending.accepted.count == 3 {
                for other in pending.roster.ids.dropFirst() { send(.teamStart(matchID: matchID), to: other) }
                startTeamMatch(pending.roster)
            }
        case .teamStart(let matchID):
            guard let pending = pendingTeam, !pending.isHost, pending.answered,
                  pending.roster.matchID == matchID, pending.roster.ids[0] == id else { return }
            startTeamMatch(pending.roster)
        case .teamCancel(let matchID):
            guard let pending = pendingTeam, !pending.isHost, pending.roster.matchID == matchID,
                  pending.roster.ids[0] == id else { return }
            pendingTeam = nil
            notice = "팀 대결이 취소됐어요."
        case .team(let battle):
            guard let teamMatch, let index = teamMatch.roster.firstIndex(of: id) else { return }
            teamMatch.receive(battle, from: index)
        default:
            break
        }
    }

    func requestCollection(_ id: String) {
        guard let target = players[id] else { return }
        viewedCollection = ViewedCollection(playerID: id, trainer: target.profile.trainer, entries: nil)
        send(.collectionRequest, to: id)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.collectionTimeout))
            guard let self, self.viewedCollection?.playerID == id, self.viewedCollection?.entries == nil else { return }
            self.viewedCollection?.timedOut = true
        }
    }

    static let collectionTimeout = 6.0

    func closeCollection() { viewedCollection = nil }

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
        update(me.id) { $0.busy = busy }
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
        if viewedCollection?.playerID == id { viewedCollection = nil }
        if teamDraft?.partner == id || teamDraft?.foes.contains(id) == true { teamDraft = nil }
        if let pending = pendingTeam, pending.roster.ids.contains(id) {
            notice = "참가자가 떠나 팀 대결이 취소됐어요."
            if pending.isHost { cancelPendingTeam() } else { pendingTeam = nil }
        }
        if teamMatch?.roster.contains(id) == true { teamMatch?.participantLeft() }
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
            update(id) { p in   // target only; the ticker eases the drawn position toward it
                p.x = x
                p.y = y
            }
        case .chat(let text):
            appendChat(from: players[id]?.profile.trainer ?? "?", text: text)
            showBubble(text, for: id)
        case .busy(let busy):
            update(id) { $0.busy = busy }
        case .challenge:
            if match != nil || incomingChallenge != nil || outgoingChallenge != nil || isInTeamFlow {
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
        case .collectionRequest:
            send(.collection(collection), to: id)
        case .collection(let entries):
            guard viewedCollection?.playerID == id else { return }
            viewedCollection?.entries = Array(entries.prefix(CollectionEntry.maxShared))
        case .teamInvite, .teamReply, .teamStart, .teamCancel, .team:
            receiveTeam(message, from: id)
        case .popularityVote, .popularity:
            receivePopularity(message, from: id)
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

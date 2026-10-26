import AppKit
import QuartzCore

// SPIKE: the 메아리 game screen, solo or co-op. Every machine simulates its own Pokémon with EchoCore at a
// fixed 60 Hz and replays the shared echoes; live teammates arrive as positions over the network and count
// as plate-pressers and platforms. The host additionally runs EchoMatch and broadcasts loop decisions; in
// solo this machine is the host and `send` just loops back. Drawing lives in EchoGameView+Draw.swift.

@MainActor
final class EchoGameView: NSView {
    enum Mode { case waiting, play, spectate, rewind, clear, ending }

    struct Peer {
        var frame: EchoFrame
        var alive: Bool
        var loop: Int
    }

    struct Particle {
        var x: Double, y: Double, vx: Double, vy: Double
        var life: Double
        let maxLife: Double
        let color: CGColor
    }

    /// Called when the player leaves (Esc); the window goes back to the lobby.
    var onExit: (() -> Void)?

    let roster: [EchoRosterEntry]
    let meID: String
    let gameID: String
    let isHost: Bool
    private let send: (EchoMessage) -> Void
    private let sendState: (EchoMessage) -> Void

    // Shared state, as the host last announced it.
    private(set) var levelIndex: Int
    private(set) var loop = -1
    private(set) var echoes: [EchoOwned] = []
    var level: EchoLevel { EchoLevels.all[min(levelIndex, EchoLevels.all.count - 1)] }

    // This machine's run.
    private(set) var world: EchoWorld
    private(set) var frames: [EchoFrame] = []
    private(set) var mode = Mode.waiting
    private(set) var peers: [String: Peer] = [:]
    private(set) var exitedIDs: Set<String> = []
    private(set) var deadIDs: Set<String> = []
    private(set) var rewindFrame = 0.0
    private(set) var rewindSource: [EchoFrame] = []
    private(set) var montageFrame = 0.0
    private(set) var banner: (text: String, until: Double)?
    private(set) var stats = (loops: 0, echoes: 0)
    var particles: [Particle] = []

    // Host only.
    private var match: EchoMatch?
    private var collectStartedAt: Double?
    private var advanceAt: Double?
    private var echoesUsed = 0

    // Loop timing.
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var acc = 0.0
    private(set) var clock = 0.0
    private var sendClock = 0.0
    private var keys = Set<UInt16>()

    // Drawing caches (used by the Draw extension).
    var frameContext: CGContext?
    var terrainImage: CGImage?
    var sprites: [String: CGImage] = [:]
    var tintedSprites: [String: CGImage] = [:]
    var lastScale: CGFloat = 2
    var lastOrigin = CGPoint.zero

    init(frame: NSRect, roster: [EchoRosterEntry], meID: String, hostID: String, gameID: String, startLevel: Int,
         send: @escaping (EchoMessage) -> Void, sendState: @escaping (EchoMessage) -> Void) {
        self.roster = roster
        self.meID = meID
        self.gameID = gameID
        self.isHost = hostID == meID
        self.send = send
        self.sendState = sendState
        self.levelIndex = startLevel
        self.world = EchoCore.makeWorld(EchoLevels.all[startLevel], echoes: [])
        super.init(frame: frame)
        terrainImage = EchoArt.terrain(level)
        if isHost { match = EchoMatch(players: roster.map(\.id), level: startLevel) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    var maxEchoes: Int { level.maxEchoes }
    func entry(_ id: String) -> EchoRosterEntry? { roster.first { $0.id == id } }
    func echoCount(of id: String) -> Int { echoes.filter { $0.owner == id }.count }

    func setSprite(_ image: NSImage, for id: String) {
        guard let img = KartArt.rider(from: image, height: 19) else { return }
        sprites[id] = img
        tintedSprites = tintedSprites.filter { !$0.key.hasPrefix("\(id)#") }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    /// Host: announce the first loop once the view is on screen.
    func begin() {
        guard isHost, let match else { return }
        send(.loop(EchoLoopStart(gameID: gameID, level: match.level, loop: match.loop, echoes: [], full: [])))
    }

    // MARK: messages

    func handle(_ message: EchoMessage) {
        switch message {
        case .hello, .start:
            break
        case .loop(let start):
            guard start.gameID == gameID else { return }
            beginLoop(start)
        case let .state(g, l, id, x, y, facing, alive):
            guard g == gameID, id != meID else { return }
            peers[id] = Peer(frame: EchoFrame(x: Double(x), y: Double(y), facing: Int(facing)), alive: alive, loop: l)
        case let .request(g, l, id, kind):
            guard g == gameID, isHost, l == loop else { return }
            hostRequest(kind, from: id)
        case let .exited(g, l, id):
            guard g == gameID, l == loop else { return }
            exitedIDs.insert(id)
            if id != meID { burst(at: peers[id]?.frame, color: KartArt.rgb(170, 255, 200), count: 18) }
            hostUpdate { $0.playerExited(id) }
        case let .died(g, l, id):
            guard g == gameID, l == loop else { return }
            deadIDs.insert(id)
            if id != meID { burst(at: peers[id]?.frame, color: KartArt.rgb(220, 70, 90), count: 18) }
            hostUpdate { $0.playerDied(id) }
        case let .endLoop(g, l, by):
            guard g == gameID, l == loop else { return }
            endLoop(by: by)
        case let .recording(g, l, run):
            guard g == gameID, l == loop, isHost else { return }
            match?.receive(run)
            hostMaybeStartNextLoop()
        case let .cleared(g, lvl, loops):
            guard g == gameID, lvl == levelIndex else { return }
            stats.loops = loops
            mode = .clear
            montageFrame = 0
            showBanner("클리어!", seconds: 3)
        case let .finished(g, loops, used):
            guard g == gameID else { return }
            stats = (loops, used)
            mode = .ending
            clock = 0
        }
    }

    func markLeft(_ id: String) {
        peers[id] = nil
        guard isHost else { return }
        hostUpdate { $0.playerLeft(id) }
        hostMaybeStartNextLoop()
    }

    private func beginLoop(_ start: EchoLoopStart) {
        if start.level != levelIndex {
            levelIndex = start.level
            terrainImage = EchoArt.terrain(level)
            showBanner(level.title, seconds: 2)
        } else if start.loop == 0 {
            showBanner(level.title, seconds: 2)
        }
        loop = start.loop
        echoes = start.echoes
        world = EchoCore.makeWorld(level, echoes: start.echoes.map(\.rec))
        frames = [EchoCore.snapshot(world.player)]
        peers = peers.mapValues { var p = $0; p.alive = true; return p }
        exitedIDs = []
        deadIDs = []
        acc = 0
        mode = .play
        if start.full.contains(meID) { showBanner("메아리 자리가 가득 찼어요 · ⌫로 하나 지우기", seconds: 3) }
    }

    private func endLoop(by: String?) {
        if isHost {
            match?.beginCollecting()
            collectStartedAt = clock
        }
        let died = deadIDs.contains(meID)
        let run = EchoOwned(owner: meID, speciesID: entry(meID)?.speciesID, isShiny: entry(meID)?.isShiny ?? false,
                            rec: EchoRecording(frames: frames, end: died ? .dead : .rewind))
        send(.recording(gameID: gameID, loop: loop, run: run))
        rewindSource = frames
        rewindFrame = Double(frames.count - 1)
        mode = .rewind
        if let by, by != meID, let name = entry(by)?.trainer { showBanner("\(name) 님이 되감았어요", seconds: 1.4) }
    }

    // MARK: host

    private func hostUpdate(_ change: (inout EchoMatch) -> Void) {
        guard isHost, var m = match else { return }
        change(&m)
        match = m
        if m.isCleared, advanceAt == nil {
            echoesUsed += m.echoes.count
            send(.cleared(gameID: gameID, level: m.level, loops: m.totalLoops + 1))
            advanceAt = clock + 3.4
        } else if m.allDone, !m.collecting {
            send(.endLoop(gameID: gameID, loop: m.loop, by: nil))
        }
    }

    private func hostRequest(_ kind: EchoRequest, from id: String) {
        guard var m = match, !m.collecting, advanceAt == nil else { return }
        switch kind {
        case .rewind:
            send(.endLoop(gameID: gameID, loop: m.loop, by: id))
        case .erase:
            guard m.echoCount(of: id) > 0 else { return }
            m.erase(lastOf: id)
            match = m
            send(.loop(EchoLoopStart(gameID: gameID, level: m.level, loop: m.loop, echoes: m.echoes, full: [])))
        }
    }

    /// Next loop once every run is in (or after a grace period), but never before the rewind has played.
    private func hostMaybeStartNextLoop() {
        guard isHost, var m = match, m.collecting, let started = collectStartedAt else { return }
        let ready = m.hasEveryRecording || clock - started > 2.5
        guard ready, clock - started > 0.9 else { return }
        let full = m.startNextLoop(maxPerPlayer: level.maxEchoes)
        match = m
        collectStartedAt = nil
        send(.loop(EchoLoopStart(gameID: gameID, level: m.level, loop: m.loop, echoes: m.echoes, full: full)))
    }

    private func hostTick() {
        guard isHost, var m = match else { return }
        hostMaybeStartNextLoop()
        if let at = advanceAt, clock >= at {
            advanceAt = nil
            if m.level + 1 < EchoLevels.all.count {
                m.advanceLevel()
                match = m
                send(.loop(EchoLoopStart(gameID: gameID, level: m.level, loop: m.loop, echoes: [], full: [])))
            } else {
                send(.finished(gameID: gameID, loops: m.totalLoops + 1, echoes: echoesUsed))
            }
        }
    }

    // MARK: loop

    /// Runs `n` fixed steps without a display link (offscreen previews and tests).
    func advance(frames n: Int) {
        for _ in 0..<n {
            clock += EchoCore.dt
            tick()
            hostTick()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, link == nil {
            let l = displayLink(target: self, selector: #selector(step(_:)))
            l.add(to: .main, forMode: .common)
            link = l
            lastTick = CACurrentMediaTime()
        } else if window == nil {
            stop()
        }
    }

    @objc private func step(_ sender: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTick, 0), 0.25)
        lastTick = now
        clock += dt
        acc += dt
        while acc >= EchoCore.dt {
            acc -= EchoCore.dt
            tick()
        }
        hostTick()
        needsDisplay = true
    }

    private func tick() {
        particles = particles.compactMap { p in
            var q = p
            q.x += q.vx * EchoCore.dt
            q.y += q.vy * EchoCore.dt
            q.vy += 500 * EchoCore.dt
            q.life -= EchoCore.dt
            return q.life > 0 ? q : nil
        }
        switch mode {
        case .play: tickPlay()
        case .spectate:
            // Keep echoes and the timer running while waiting for the loop to end.
            world.frame += 1
            if world.frame >= level.limit, isHost, match?.collecting == false {
                send(.endLoop(gameID: gameID, loop: loop, by: nil))
            }
        case .rewind:
            rewindFrame = max(0, rewindFrame - max(4, Double(rewindSource.count) / 50))
        case .clear:
            montageFrame += 2
        case .waiting, .ending:
            break
        }
    }

    private func livePeers() -> [EchoFrame] {
        peers.compactMap { id, p in
            p.alive && p.loop == loop && !exitedIDs.contains(id) && !deadIDs.contains(id) ? p.frame : nil
        }
    }

    private func tickPlay() {
        world = EchoCore.step(world, playerInput(), peers: livePeers())
        frames.append(EchoCore.snapshot(world.player))
        if world.landed { dust() }
        sendClock += EchoCore.dt
        if sendClock >= 1.0 / 30 || world.status != .play {
            sendClock = 0
            let p = world.player
            sendState(.state(gameID: gameID, loop: loop, id: meID, x: Float(p.x), y: Float(p.y),
                             facing: Int8(p.facing), alive: world.status == .play))
        }
        switch world.status {
        case .play: break
        case .won:
            mode = .spectate
            burst(at: EchoCore.snapshot(world.player), color: KartArt.rgb(170, 255, 200), count: 30)
            send(.exited(gameID: gameID, loop: loop, id: meID))
        case .dead:
            mode = .spectate
            burst(at: EchoCore.snapshot(world.player), color: KartArt.rgb(220, 70, 90), count: 30)
            if world.cause == .crush { showBanner("닫히는 문에 끼였어요", seconds: 1.4) }
            send(.died(gameID: gameID, loop: loop, id: meID))
        case .timeout:
            mode = .spectate
            if isHost, match?.collecting == false { send(.endLoop(gameID: gameID, loop: loop, by: nil)) }
        }
    }

    // MARK: input

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onExit?()
        case 15:
            guard !event.isARepeat, mode == .play || mode == .spectate else { return }
            send(.request(gameID: gameID, loop: loop, id: meID, kind: .rewind))
        case 51:
            guard !event.isARepeat, mode == .play || mode == .spectate, echoCount(of: meID) > 0 else { return }
            send(.request(gameID: gameID, loop: loop, id: meID, kind: .erase))
        default: keys.insert(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    override func resignFirstResponder() -> Bool {
        keys.removeAll()
        return true
    }

    private func playerInput() -> EchoInput {
        func held(_ codes: UInt16...) -> Bool { codes.contains { keys.contains($0) } }
        return EchoInput(left: held(123, 0), right: held(124, 2), jump: held(49, 126, 13))
    }

    // MARK: effects

    func showBanner(_ text: String, seconds: Double) { banner = (text, clock + seconds) }

    private func burst(at f: EchoFrame?, color: CGColor, count: Int) {
        guard let f else { return }
        let cx = f.x + EchoCore.P.w / 2, cy = f.y + EchoCore.P.h / 2
        particles += (0..<count).map { i in
            let a = Double(i) / Double(count) * .pi * 2
            let sp = 90 + Double((i * 37) % 160)
            return Particle(x: cx, y: cy, vx: cos(a) * sp, vy: sin(a) * sp - 80, life: 0.9, maxLife: 0.9, color: color)
        }
    }

    private func dust() {
        let p = world.player
        particles += (0..<5).map { i in
            Particle(x: p.x + EchoCore.P.w / 2, y: p.y + EchoCore.P.h, vx: Double(i - 2) * 30, vy: -40, life: 0.3,
                     maxLife: 0.3, color: KartArt.rgb(230, 230, 210))
        }
    }
}

import AppKit
import QuartzCore

// SPIKE: single-player kart race against three CPU karts, top-down. The world is simulated and drawn in
// low-res pixels (one frame bitmap per tick) and scaled up with nearest-neighbour; the HUD is drawn on
// top at full resolution. Controls: arrows/WASD, Space or Shift to drift (release to boost), R restart.

struct KartEntrant {
    let name: String
    let speciesID: Int?
    let isShiny: Bool
    let isPlayer: Bool
    let level: Int
}

@MainActor
final class KartGameView: NSView {
    static let totalLaps = 3
    private static let countdown: TimeInterval = 3
    private static let baseMaxSpeed: CGFloat = 118
    private static let accel: CGFloat = 92

    private struct Racer {
        let name: String
        let isPlayer: Bool
        let paint: KartPaint
        var rider: CGImage?
        var maxSpeed: CGFloat
        var pos: CGPoint
        var vel = CGPoint.zero
        var heading: CGFloat
        var speed: CGFloat = 0
        var idx: Int
        /// Samples driven since the start line, negative on the grid. Laps = progress / track.count.
        var progress: Int
        var lapStart: TimeInterval = 0
        var bestLap: TimeInterval?
        var finishTime: TimeInterval?
        var drifting = false
        var driftDir: CGFloat = 0
        var driftCharge: TimeInterval = 0
        var hop: TimeInterval = 0
        var boost: TimeInterval = 0
        var offRoad = false
        var facingRight = false
        var laneOffset: CGFloat = 0
        var lanePhase: CGFloat = 0
        var rubber: CGFloat = 1
        /// Highest whole lap already counted, so reversing over the line can't count a lap twice.
        var lapsCounted = -1
    }

    private struct Input {
        var throttle = false, brake = false, drift = false
        var steer: CGFloat = 0
    }

    private struct Particle {
        var pos: CGPoint
        var vel: CGPoint
        var life: TimeInterval
        let maxLife: TimeInterval
        let color: CGColor
        let size: CGFloat
    }

    private enum Phase { case countdown, racing, finished }

    private let track: KartTrack
    private let trackImage: CGImage?
    private let entrants: [KartEntrant]
    private var racers: [Racer] = []
    private var particles: [Particle] = []
    private var phase = Phase.countdown
    private var clock: TimeInterval = 0
    private var raceStart: TimeInterval = 0
    private var keys = Set<UInt16>()
    private var shiftHeld = false
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var rng = KartRNG(seed: UInt64.random(in: 1...UInt64.max))
    private var frameContext: CGContext?

    init(frame: NSRect, track: KartTrack, entrants: [KartEntrant]) {
        self.track = track
        self.trackImage = KartArt.renderTrack(track)
        self.entrants = entrants
        super.init(frame: frame)
        resetRace()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    func setRider(_ image: NSImage, at index: Int) {
        guard racers.indices.contains(index) else { return }
        racers[index].rider = KartArt.rider(from: image, height: 18)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    // MARK: race setup

    private func resetRace() {
        let n = track.count
        // Grid behind the start line: CPUs in front, the player at the back for a chase.
        let order = entrants.indices.sorted { a, b in (entrants[a].isPlayer ? 1 : 0) < (entrants[b].isPlayer ? 1 : 0) }
        let skills: [CGFloat] = [0.95, 0.92, 0.89, 0.86].shuffled()
        let previousRiders = racers.map(\.rider)
        racers = []
        // Racers stay in entrant order so `setRider(_:at:)` indexes stay valid; `slot` is the grid spot.
        for (i, e) in entrants.enumerated() {
            let slot = order.firstIndex(of: i) ?? i
            let back = 8 + (slot / 2) * 14
            let side: CGFloat = slot % 2 == 0 ? -10 : 10
            let idx = track.wrap(-back)
            let levelBonus = 1 + CGFloat(min(max(e.level, 1), 100)) / 100 * 0.06
            racers.append(Racer(
                name: e.name, isPlayer: e.isPlayer, paint: KartArt.paints[min(i, KartArt.paints.count - 1)],
                rider: previousRiders.indices.contains(i) ? previousRiders[i] : nil,
                maxSpeed: e.isPlayer ? Self.baseMaxSpeed * levelBonus : Self.baseMaxSpeed * skills[slot % skills.count],
                pos: track.point(at: idx, offset: side), heading: track.angles[idx], idx: idx, progress: -back,
                laneOffset: CGFloat(rng.int(21)) - 10, lanePhase: CGFloat(rng.int(628)) / 100))
        }
        particles = []
        phase = .countdown
        clock = 0
        raceStart = Self.countdown
    }

    private var playerIndex: Int { racers.firstIndex(where: \.isPlayer) ?? 0 }

    // MARK: loop

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
        let dt = min(max(now - lastTick, 0), 1.0 / 30)
        lastTick = now
        update(dt)
        needsDisplay = true
    }

    private func update(_ dt: TimeInterval) {
        clock += dt
        if phase == .countdown, clock >= raceStart {
            phase = .racing
            for i in racers.indices { racers[i].lapStart = clock }
        }
        if phase != .countdown {
            let lead = racers[playerIndex].progress
            for i in racers.indices {
                if !racers[i].isPlayer {
                    // Light rubber band so the pack stays in sight without being unbeatable.
                    let gap = racers[i].progress - lead
                    let third = track.count / 3
                    racers[i].rubber = gap > third ? 0.9 : (gap < -third ? 1.08 : 1)
                }
                let input = racers[i].isPlayer && racers[i].finishTime == nil ? playerInput() : aiInput(i, dt: dt)
                drive(i, input, dt: CGFloat(dt))
            }
            collide()
        }
        updateParticles(dt)
    }

    // MARK: input

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: window?.performClose(nil)
        case 15: if !event.isARepeat { resetRace() }
        default: keys.insert(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    override func flagsChanged(with event: NSEvent) { shiftHeld = event.modifierFlags.contains(.shift) }

    override func resignFirstResponder() -> Bool {
        keys.removeAll()
        shiftHeld = false
        return true
    }

    private func playerInput() -> Input {
        func held(_ codes: UInt16...) -> Bool { codes.contains { keys.contains($0) } }
        var input = Input()
        input.throttle = held(126, 13)
        input.brake = held(125, 1)
        input.drift = held(49) || shiftHeld
        input.steer = (held(124, 2) ? 1 : 0) - (held(123, 0) ? 1 : 0)
        return input
    }

    private func aiInput(_ i: Int, dt: TimeInterval) -> Input {
        var r = racers[i]
        r.lanePhase += CGFloat(dt) * 0.5
        racers[i].lanePhase = r.lanePhase
        let look = 10 + Int(max(0, r.speed) * 0.12)
        let target = track.point(at: r.idx + look, offset: r.laneOffset + sin(r.lanePhase) * 6)
        let desired = atan2(target.y - r.pos.y, target.x - r.pos.x)
        let diff = Self.wrapAngle(desired - r.heading)
        let bend = abs(Self.wrapAngle(track.angles[track.wrap(r.idx + look * 2)] - track.angles[r.idx]))
        var input = Input()
        input.steer = max(-1, min(1, diff * 2.2))
        input.throttle = !(bend > 0.9 && r.speed > r.maxSpeed * 0.72)
        input.brake = bend > 1.3 && r.speed > r.maxSpeed * 0.6
        return input
    }

    static func wrapAngle(_ a: CGFloat) -> CGFloat {
        var a = a.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        return a
    }

    // MARK: physics

    private func drive(_ i: Int, _ input: Input, dt: CGFloat) {
        var r = racers[i]
        var cap = r.maxSpeed * r.rubber * (r.offRoad ? 0.5 : 1)
        if r.boost > 0 {
            cap *= 1.5
            r.boost -= Double(dt)
            r.speed = min(cap, r.speed + 300 * dt)
        }
        if input.throttle {
            r.speed += Self.accel * dt
        } else if input.brake {
            r.speed -= (r.speed > 0 ? 220 : 70) * dt
        } else {
            r.speed -= r.speed * 1.4 * dt
        }
        if r.speed > cap { r.speed = max(cap, r.speed - 260 * dt) }
        r.speed = max(r.speed, -45)

        // Drift: hop in, keep turning toward the drift side, charge sparks; release for a boost.
        if input.drift, !r.drifting, abs(input.steer) > 0.1, r.speed > 55, !r.offRoad {
            r.drifting = true
            r.driftDir = input.steer > 0 ? 1 : -1
            r.driftCharge = 0
            r.hop = 0.14
        }
        if r.drifting, !input.drift || r.speed < 35 {
            switch Self.driftTier(r.driftCharge) {
            case 2: r.boost = max(r.boost, 1.1)
            case 1: r.boost = max(r.boost, 0.55)
            default: break
            }
            r.drifting = false
        }
        var steer = input.steer
        if r.drifting {
            steer = r.driftDir * 0.6 + input.steer * 0.55
            let leaning = input.steer * r.driftDir > 0.1
            r.driftCharge += Double(dt) * (leaning ? 1.25 : 0.8)
        }
        let turnScale = min(1, abs(r.speed) / 45)
        let rate: CGFloat = r.drifting ? 2.9 : 2.4
        r.heading += steer * rate * turnScale * dt * (r.speed >= 0 ? 1 : -1)

        let dir = CGPoint(x: cos(r.heading), y: sin(r.heading))
        let grip: CGFloat = r.drifting ? 3.2 : (r.offRoad ? 6 : 10)
        let k = min(1, grip * dt)
        r.vel.x += (dir.x * r.speed - r.vel.x) * k
        r.vel.y += (dir.y * r.speed - r.vel.y) * k
        r.pos.x += r.vel.x * dt
        r.pos.y += r.vel.y * dt
        let clamped = CGPoint(x: min(max(r.pos.x, 6), track.size.width - 6), y: min(max(r.pos.y, 6), track.size.height - 6))
        if clamped != r.pos { r.pos = clamped; r.speed *= 0.5 }
        r.hop = max(0, r.hop - Double(dt))
        if abs(dir.x) > 0.25 { r.facingRight = dir.x > 0 }

        // Track position, laps and pads.
        let near = track.nearest(to: r.pos, near: r.idx)
        r.progress += track.delta(from: r.idx, to: near.index)
        r.idx = near.index
        r.offRoad = near.distance > track.halfWidth + 2
        for pad in track.padIndexes where abs(track.delta(from: pad, to: r.idx)) < 5 {
            let c = track.samples[pad]
            if hypot(c.x - r.pos.x, c.y - r.pos.y) < 10 { r.boost = max(r.boost, 0.9) }
        }
        let lapsDone = r.progress >= 0 ? r.progress / track.count : -1
        if lapsDone > r.lapsCounted {
            r.lapsCounted = lapsDone
            if lapsDone >= 1 {
                let lapTime = clock - r.lapStart
                r.bestLap = min(r.bestLap ?? lapTime, lapTime)
            }
            r.lapStart = clock
            if lapsDone >= Self.totalLaps, r.finishTime == nil {
                r.finishTime = clock - raceStart
                if r.isPlayer { phase = .finished }
            }
        }
        racers[i] = r
        emitParticles(for: r, dt: dt)
    }

    static func driftTier(_ charge: TimeInterval) -> Int { charge >= 1.3 ? 2 : (charge >= 0.55 ? 1 : 0) }

    private func collide() {
        for a in racers.indices {
            for b in racers.indices where b > a {
                let dx = racers[b].pos.x - racers[a].pos.x, dy = racers[b].pos.y - racers[a].pos.y
                let d = hypot(dx, dy)
                guard d < 9, d > 0.01 else { continue }
                let push = (9 - d) / 2, nx = dx / d, ny = dy / d
                racers[a].pos.x -= nx * push; racers[a].pos.y -= ny * push
                racers[b].pos.x += nx * push; racers[b].pos.y += ny * push
                racers[a].speed *= 0.94
                racers[b].speed *= 0.94
            }
        }
    }

    // MARK: particles

    private func emitParticles(for r: Racer, dt: CGFloat) {
        guard particles.count < 700 else { return }
        let dir = CGPoint(x: cos(r.heading), y: sin(r.heading))
        let nrm = CGPoint(x: -dir.y, y: dir.x)
        func jitter(_ s: CGFloat) -> CGFloat { (CGFloat(rng.int(1000)) / 500 - 1) * s }
        func emit(at p: CGPoint, vel: CGPoint, life: TimeInterval, color: CGColor, size: CGFloat = 1) {
            particles.append(Particle(pos: p, vel: vel, life: life, maxLife: life, color: color, size: size))
        }
        let rear = CGPoint(x: r.pos.x - dir.x * 7, y: r.pos.y - dir.y * 7)
        if r.drifting, r.driftCharge > 0.15 {
            let color: CGColor = switch Self.driftTier(r.driftCharge) {
            case 2: KartArt.rgb(255, 150, 40)
            case 1: KartArt.rgb(110, 180, 255)
            default: KartArt.rgb(235, 235, 235)
            }
            for side: CGFloat in [-5, 5] {
                let p = CGPoint(x: rear.x + nrm.x * side, y: rear.y + nrm.y * side)
                emit(at: p, vel: CGPoint(x: -dir.x * 25 + jitter(30), y: -dir.y * 25 + jitter(30)), life: 0.25, color: color)
            }
        }
        if r.boost > 0 {
            let flame = [KartArt.rgb(255, 230, 90), KartArt.rgb(255, 130, 30), KartArt.rgb(255, 80, 40)]
            for _ in 0..<2 {
                emit(at: rear, vel: CGPoint(x: -dir.x * 60 + jitter(12), y: -dir.y * 60 + jitter(12)),
                     life: 0.22, color: flame[rng.int(flame.count)], size: 2)
            }
        }
        if r.offRoad, abs(r.speed) > 30, rng.int(2) == 0 {
            emit(at: rear, vel: CGPoint(x: jitter(14), y: jitter(14) - 6), life: 0.4, color: KartArt.rgb(150, 116, 70), size: 2)
        }
    }

    private func updateParticles(_ dt: TimeInterval) {
        let d = CGFloat(dt)
        for i in particles.indices {
            particles[i].pos.x += particles[i].vel.x * d
            particles[i].pos.y += particles[i].vel.y * d
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: drawing

    private var pixelScale: CGFloat { max(2, (bounds.height / 210).rounded()) }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scale = pixelScale
        let vw = Int((bounds.width / scale).rounded(.up)), vh = Int((bounds.height / scale).rounded(.up))
        if frameContext?.width != vw || frameContext?.height != vh {
            frameContext = KartArt.context(width: vw, height: vh)
        }
        guard let f = frameContext else { return }

        let me = racers[playerIndex]
        let world = track.size
        func center(_ v: CGFloat, view: Int, size: CGFloat) -> CGFloat {
            CGFloat(view) >= size ? size / 2 : min(max(v, CGFloat(view) / 2), size - CGFloat(view) / 2)
        }
        let cam = CGPoint(x: center(me.pos.x + me.vel.x * 0.3, view: vw, size: world.width),
                          y: center(me.pos.y + me.vel.y * 0.3, view: vh, size: world.height))
        let origin = CGPoint(x: (cam.x - CGFloat(vw) / 2).rounded(), y: (cam.y - CGFloat(vh) / 2).rounded())

        KartArt.fill(f, KartArt.rgb(52, 110, 48), 0, 0, CGFloat(vw), CGFloat(vh))
        f.saveGState()
        f.translateBy(x: -origin.x, y: -origin.y)
        if let trackImage { KartArt.draw(trackImage, in: f, rect: CGRect(origin: .zero, size: world)) }
        for p in particles where p.size > 1 { drawParticle(p, in: f) }
        for r in racers.sorted(by: { $0.pos.y < $1.pos.y }) { drawRacer(r, in: f) }
        for p in particles where p.size <= 1 { drawParticle(p, in: f) }
        f.restoreGState()

        if let frame = f.makeImage() {
            ctx.interpolationQuality = .none
            KartArt.draw(frame, in: ctx, rect: CGRect(x: 0, y: 0, width: CGFloat(vw) * scale, height: CGFloat(vh) * scale))
        }
        drawHUD(ctx)
    }

    private func drawParticle(_ p: Particle, in f: CGContext) {
        f.setAlpha(CGFloat(max(0, p.life / p.maxLife)))
        KartArt.fill(f, p.color, p.pos.x.rounded(), p.pos.y.rounded(), p.size, p.size)
        f.setAlpha(1)
    }

    private func drawRacer(_ r: Racer, in f: CGContext) {
        let p = CGPoint(x: r.pos.x.rounded(), y: r.pos.y.rounded())
        let lift: CGFloat = r.hop > 0 ? 2 : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 3, width: 14, height: 8))
        KartArt.local(f, at: CGPoint(x: p.x, y: p.y - lift), angle: r.heading) { KartArt.kart($0, paint: r.paint) }
        let bob: CGFloat = abs(r.speed) > 10 && Int(clock * 12) % 2 == 0 ? 1 : 0
        var top = p.y - lift - 8
        if let rider = r.rider {
            let w = CGFloat(rider.width), h = CGFloat(rider.height)
            let rect = CGRect(x: p.x - (w / 2).rounded(), y: p.y - lift - h + 3 - bob, width: w, height: h)
            KartArt.draw(rider, in: f, rect: rect, flipX: r.facingRight)
            top = rect.minY
        }
        if r.isPlayer {
            // Little yellow arrow over the player's head.
            let y = top - 5
            KartArt.fill(f, KartArt.rgb(30, 30, 30), p.x - 3, y - 1, 7, 2)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), p.x - 2, y - 1, 5, 1)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), p.x - 1, y, 3, 1)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), p.x, y + 1, 1, 1)
        }
    }

    // MARK: HUD

    private func standings() -> [Int] {
        racers.indices.sorted { a, b in
            switch (racers[a].finishTime, racers[b].finishTime) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return racers[a].progress > racers[b].progress
            }
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let cs = Int((max(0, t) * 100).rounded())
        return String(format: "%d:%02d.%02d", cs / 6000, cs / 100 % 60, cs % 100)
    }

    private func text(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor = .white,
                      weight: NSFont.Weight = .heavy, align: NSTextAlignment = .left, mono: Bool = false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 0
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .shadow: shadow]
        let str = NSAttributedString(string: s, attributes: attrs)
        let w = str.size().width
        let x = align == .center ? p.x - w / 2 : (align == .right ? p.x - w : p.x)
        str.draw(at: NSPoint(x: x, y: p.y))
    }

    private func panel(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
    }

    private func drawHUD(_ ctx: CGContext) {
        let me = racers[playerIndex]
        let raceTime = phase == .countdown ? 0 : (me.finishTime ?? clock - raceStart)
        let lap = min(Self.totalLaps, max(1, me.progress / track.count + 1))
        let order = standings()
        let rank = (order.firstIndex(of: playerIndex) ?? 0) + 1

        panel(ctx, CGRect(x: 12, y: 12, width: 210, height: 92))
        text("LAP \(lap)/\(Self.totalLaps)", at: CGPoint(x: 24, y: 18), size: 26)
        text("TIME \(Self.format(raceTime))", at: CGPoint(x: 24, y: 52), size: 16, mono: true)
        text("BEST \(me.bestLap.map(Self.format) ?? "-:--.--")", at: CGPoint(x: 24, y: 76), size: 13,
             color: NSColor(white: 0.85, alpha: 1), mono: true)

        panel(ctx, CGRect(x: 12, y: bounds.height - 86, width: 150, height: 74))
        text("\(rank)위", at: CGPoint(x: 24, y: bounds.height - 84), size: 44,
             color: rank == 1 ? NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1) : .white)
        text("/ \(racers.count)", at: CGPoint(x: 104, y: bounds.height - 50), size: 16)

        drawMinimap(ctx)
        drawGauges(ctx, me)

        text("←→ 조향   ↑ 가속   ↓ 브레이크   Space 드리프트(떼면 부스트)   R 재시작   Esc 닫기",
             at: CGPoint(x: bounds.midX, y: bounds.height - 24), size: 11, color: NSColor(white: 1, alpha: 0.75),
             weight: .semibold, align: .center)

        switch phase {
        case .countdown:
            let left = raceStart - clock
            text("\(Int(left.rounded(.up)))", at: CGPoint(x: bounds.midX, y: bounds.midY - 80), size: 110, align: .center)
        case .racing:
            if clock - raceStart < 0.8 {
                text("GO!", at: CGPoint(x: bounds.midX, y: bounds.midY - 80), size: 110,
                     color: NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1), align: .center)
            }
        case .finished:
            drawResults(ctx, order)
        }
    }

    private func drawMinimap(_ ctx: CGContext) {
        let box = CGRect(x: bounds.width - 192, y: 12, width: 180, height: 126)
        panel(ctx, box)
        let s = min((box.width - 20) / track.size.width, (box.height - 20) / track.size.height)
        let ox = box.midX - track.size.width * s / 2, oy = box.midY - track.size.height * s / 2
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * s, y: oy + p.y * s) }
        let path = CGMutablePath()
        path.addLines(between: stride(from: 0, to: track.count, by: 4).map { map(track.samples[$0]) })
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.85).cgColor)
        ctx.setLineWidth(5)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor(white: 0.3, alpha: 1).cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()
        for r in racers.sorted(by: { !$0.isPlayer && $1.isPlayer }) {
            let p = map(r.pos), rad: CGFloat = r.isPlayer ? 5 : 3.5
            if r.isPlayer {
                ctx.setFillColor(.white)
                ctx.fillEllipse(in: CGRect(x: p.x - rad - 1.5, y: p.y - rad - 1.5, width: rad * 2 + 3, height: rad * 2 + 3))
            }
            ctx.setFillColor(r.paint.body)
            ctx.fillEllipse(in: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2))
        }
    }

    private func drawGauges(_ ctx: CGContext, _ me: Racer) {
        let box = CGRect(x: bounds.width - 222, y: bounds.height - 86, width: 210, height: 74)
        panel(ctx, box)
        let frac = max(0, min(1, me.speed / (Self.baseMaxSpeed * 1.5)))
        let bar = CGRect(x: box.minX + 12, y: box.minY + 34, width: box.width - 24, height: 10)
        ctx.setFillColor(NSColor(white: 1, alpha: 0.15).cgColor)
        ctx.fill(bar)
        ctx.setFillColor((me.boost > 0 ? NSColor.orange : NSColor(red: 0.4, green: 0.85, blue: 1, alpha: 1)).cgColor)
        ctx.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width * frac, height: bar.height))
        text("\(Int(max(0, me.speed) * 1.1)) km/h", at: CGPoint(x: box.minX + 12, y: box.minY + 8), size: 15, mono: true)
        let tier = me.drifting ? Self.driftTier(me.driftCharge) : 0
        let label = me.boost > 0 ? "BOOST!" : (me.drifting ? ["DRIFT", "DRIFT ▶ 미니 부스트", "DRIFT ▶ 슈퍼 부스트"][tier] : "")
        let color: NSColor = me.boost > 0 ? .orange : (tier == 2 ? .orange : (tier == 1 ? NSColor(red: 0.45, green: 0.72, blue: 1, alpha: 1) : .white))
        text(label, at: CGPoint(x: box.minX + 12, y: box.minY + 50), size: 12, color: color)
    }

    private func drawResults(_ ctx: CGContext, _ order: [Int]) {
        let rowH: CGFloat = 32
        let rect = CGRect(x: bounds.midX - 200, y: bounds.midY - 120, width: 400, height: 110 + rowH * CGFloat(order.count))
        panel(ctx, rect)
        text("FINISH!", at: CGPoint(x: rect.midX, y: rect.minY + 14), size: 34,
             color: NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1), align: .center)
        for (place, i) in order.enumerated() {
            let r = racers[i]
            let y = rect.minY + 62 + rowH * CGFloat(place)
            let color: NSColor = r.isPlayer ? NSColor(red: 1, green: 0.84, blue: 0.2, alpha: 1) : .white
            text("\(place + 1)위", at: CGPoint(x: rect.minX + 24, y: y), size: 18, color: color)
            text(r.name + (r.isPlayer ? " (나)" : ""), at: CGPoint(x: rect.minX + 80, y: y), size: 18, color: color, weight: .bold)
            text(r.finishTime.map(Self.format) ?? "주행 중…", at: CGPoint(x: rect.maxX - 24, y: y), size: 18,
                 color: color, align: .right, mono: true)
        }
        text("R 다시 하기   ·   Esc 닫기", at: CGPoint(x: rect.midX, y: rect.maxY - 36), size: 13,
             color: NSColor(white: 1, alpha: 0.8), weight: .semibold, align: .center)
    }
}

import AppKit
import QuartzCore

// SPIKE: draws and drives `ArenaSim`. Low-res pixel world scaled up (same pipeline as the kart race),
// crisp HUD on top. Controls: right or left click to move / attack the unit under the cursor, Q W E R
// cast toward the mouse, S stop, B recall, Esc leaves. After a win or loss, R plays again.

@MainActor
enum ArenaArt {
    static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor { KartArt.rgb(r, g, b, a) }

    static func typeColor(_ type: String?) -> CGColor {
        switch type {
        case "fire": return rgb(255, 120, 40, 1)
        case "water": return rgb(70, 150, 255, 1)
        case "grass": return rgb(90, 200, 80, 1)
        case "electric": return rgb(255, 220, 50, 1)
        case "ice": return rgb(150, 230, 255, 1)
        case "fighting": return rgb(200, 80, 50, 1)
        case "poison": return rgb(170, 80, 200, 1)
        case "ground": return rgb(210, 170, 90, 1)
        case "flying": return rgb(160, 180, 255, 1)
        case "psychic": return rgb(255, 90, 160, 1)
        case "bug": return rgb(170, 200, 40, 1)
        case "rock": return rgb(180, 160, 100, 1)
        case "ghost": return rgb(110, 90, 180, 1)
        case "dragon": return rgb(120, 80, 240, 1)
        case "dark": return rgb(90, 70, 80, 1)
        case "steel": return rgb(180, 190, 210, 1)
        case "fairy": return rgb(255, 160, 220, 1)
        case nil: return rgb(255, 240, 180, 1)
        default: return rgb(240, 240, 230, 1)
        }
    }

    static func teamColor(_ team: ArenaTeam) -> CGColor {
        team == .blue ? KartArt.rgb(70, 130, 240) : KartArt.rgb(230, 70, 70)
    }

    static func teamDark(_ team: ArenaTeam) -> CGColor {
        team == .blue ? KartArt.rgb(30, 60, 140) : KartArt.rgb(130, 30, 34)
    }

    static func teamLight(_ team: ArenaTeam) -> CGColor {
        team == .blue ? KartArt.rgb(170, 210, 255) : KartArt.rgb(255, 180, 170)
    }

    static func renderMap() -> CGImage? {
        let size = ArenaSim.size
        let w = Int(size.width), h = Int(size.height)
        guard let ctx = KartArt.context(width: w, height: h) else { return nil }
        let fill = KartArt.fill
        var rng = KartRNG(seed: 0x4152_454E_41)

        // Forest outside the walkable area, grass inside.
        fill(ctx, rgb(36, 80, 40, 1), 0, 0, CGFloat(w), CGFloat(h))
        for _ in 0..<1400 {
            let x = CGFloat(rng.int(w)), y = CGFloat(rng.int(h))
            fill(ctx, rng.int(2) == 0 ? rgb(28, 64, 32, 1) : rgb(48, 100, 50, 1), x, y, 3, 3)
        }
        func grass(_ rect: CGRect) {
            fill(ctx, rgb(82, 150, 70, 1), rect.minX, rect.minY, rect.width, rect.height)
            for _ in 0..<Int(rect.width * rect.height / 10) {
                let x = rect.minX + CGFloat(rng.int(Int(rect.width))), y = rect.minY + CGFloat(rng.int(Int(rect.height)))
                fill(ctx, rng.int(2) == 0 ? rgb(70, 136, 60, 1) : rgb(100, 170, 84, 1), x, y, 1, 1)
            }
        }
        grass(CGRect(x: 14, y: 86, width: 972, height: 128))
        grass(CGRect(x: 14, y: 66, width: 124, height: 168))
        grass(CGRect(x: 862, y: 66, width: 124, height: 168))

        // Tall grass patches along the edges (decorative).
        for (x, y) in [(260, 88), (520, 200), (700, 88), (380, 200), (820, 200), (160, 200), (600, 88)] {
            for k in 0..<40 {
                let bx = CGFloat(x + rng.int(46)), by = CGFloat(y + rng.int(12))
                fill(ctx, k % 3 == 0 ? rgb(40, 110, 50, 1) : rgb(56, 128, 60, 1), bx, by, 1, 3)
            }
        }

        // Dirt lane with pebbles.
        fill(ctx, rgb(150, 120, 80, 1), 20, ArenaSim.laneY - 40, 960, 80)
        fill(ctx, rgb(186, 156, 108, 1), 20, ArenaSim.laneY - 37, 960, 74)
        for _ in 0..<1600 {
            let x = CGFloat(20 + rng.int(960)), y = ArenaSim.laneY - 36 + CGFloat(rng.int(72))
            fill(ctx, rng.int(3) == 0 ? rgb(160, 132, 92, 1) : rgb(206, 178, 128, 1), x, y, 1, 1)
        }
        for _ in 0..<70 {
            let x = CGFloat(20 + rng.int(960)), y = ArenaSim.laneY - 34 + CGFloat(rng.int(68))
            fill(ctx, rgb(130, 120, 110, 1), x, y, 2, 2)
            fill(ctx, rgb(170, 160, 150, 1), x, y, 1, 1)
        }

        // River across the middle of the lane.
        fill(ctx, rgb(60, 120, 200, 1), 472, 86, 56, 128)
        fill(ctx, rgb(90, 160, 230, 1), 476, 86, 48, 128)
        for _ in 0..<160 {
            let x = CGFloat(478 + rng.int(44)), y = CGFloat(88 + rng.int(124))
            fill(ctx, rgb(170, 220, 255, 1), x, y, CGFloat(2 + rng.int(3)), 1)
        }

        // Bases: tiled platforms tinted with the team colour, fountain circles.
        for team in [ArenaTeam.blue, .red] {
            let x0: CGFloat = team == .blue ? 14 : 862
            let tile = team == .blue ? rgb(96, 120, 170, 1) : rgb(170, 100, 100, 1)
            let line = team == .blue ? rgb(70, 92, 140, 1) : rgb(140, 72, 72, 1)
            fill(ctx, tile, x0, 70, 124, 160)
            for gx in stride(from: x0, to: x0 + 124, by: 12) { fill(ctx, line, gx, 70, 1, 160) }
            for gy in stride(from: CGFloat(70), to: 230, by: 12) { fill(ctx, line, x0, gy, 124, 1) }
            let f = ArenaSim.fountain(team)
            ctx.setFillColor(rgb(120, 200, 255, 0.35))
            ctx.fillEllipse(in: CGRect(x: f.x - 38, y: f.y - 38, width: 76, height: 76))
            ctx.setFillColor(rgb(200, 240, 255, 0.5))
            ctx.fillEllipse(in: CGRect(x: f.x - 10, y: f.y - 10, width: 20, height: 20))
        }
        return ctx.makeImage()
    }

    static func minion(_ ctx: CGContext, _ u: ArenaUnit, bob: CGFloat) {
        let x = u.pos.x.rounded(), y = (u.pos.y - bob).rounded()
        let fill = KartArt.fill
        fill(ctx, KartArt.rgb(0, 0, 0, 0.25), x - 4, u.pos.y.rounded() + 1, 8, 2)
        fill(ctx, teamDark(u.team), x - 4, y - 7, 8, 7)
        fill(ctx, u.hitFlash > 0 ? KartArt.rgb(255, 255, 255) : teamColor(u.team), x - 3, y - 6, 6, 5)
        fill(ctx, teamLight(u.team), x - 3, y - 6, 3, 1)
        let eye: CGFloat = u.facingRight ? 1 : -2
        fill(ctx, KartArt.rgb(255, 255, 255), x + eye, y - 5, 1, 2)
        fill(ctx, KartArt.rgb(255, 255, 255), x + eye + (u.facingRight ? -3 : 3), y - 5, 1, 2)
        if u.kind == .rangedMinion {
            fill(ctx, teamDark(u.team), x - 2, y - 10, 4, 3)        // pointy hat
            fill(ctx, KartArt.rgb(255, 230, 120), x - 1, y - 11, 2, 1)
        }
    }

    static func tower(_ ctx: CGContext, _ u: ArenaUnit, pulse: Bool) {
        let x = u.pos.x.rounded(), y = u.pos.y.rounded()
        let fill = KartArt.fill
        if u.dead {
            fill(ctx, rgb(90, 90, 96), x - 6, y - 4, 12, 6)
            fill(ctx, rgb(110, 110, 118), x - 4, y - 7, 5, 3)
            return
        }
        fill(ctx, rgb(0, 0, 0, 0.3), x - 8, y + 1, 16, 4)
        fill(ctx, rgb(96, 96, 106), x - 7, y - 6, 14, 8)
        fill(ctx, rgb(140, 140, 152), x - 5, y - 24, 10, 18)
        for row in stride(from: CGFloat(-22), to: -6, by: 4) { fill(ctx, rgb(118, 118, 130), x - 5, y + row, 10, 1) }
        fill(ctx, rgb(170, 170, 182), x - 5, y - 24, 2, 18)
        fill(ctx, teamDark(u.team), x - 7, y - 28, 14, 4)
        fill(ctx, teamColor(u.team), x - 6, y - 27, 12, 2)
        fill(ctx, pulse ? rgb(255, 255, 255) : teamLight(u.team), x - 2, y - 34, 4, 6)
        fill(ctx, teamColor(u.team), x - 1, y - 33, 2, 4)
    }

    static func core(_ ctx: CGContext, _ u: ArenaUnit, time: TimeInterval) {
        let x = u.pos.x.rounded(), y = u.pos.y.rounded()
        let fill = KartArt.fill
        if u.dead {
            fill(ctx, KartArt.rgb(80, 80, 90), x - 8, y - 4, 16, 6)
            return
        }
        let glow = 0.25 + 0.15 * sin(time * 3)
        ctx.setFillColor(teamLight(u.team).copy(alpha: CGFloat(glow)) ?? teamLight(u.team))
        ctx.fillEllipse(in: CGRect(x: x - 16, y: y - 26, width: 32, height: 32))
        fill(ctx, KartArt.rgb(0, 0, 0, 0.3), x - 10, y + 1, 20, 4)
        fill(ctx, KartArt.rgb(110, 110, 120), x - 9, y - 4, 18, 6)
        for (dy, half) in [(-28, 1), (-26, 3), (-23, 5), (-20, 6), (-16, 6), (-12, 5), (-8, 3)] as [(CGFloat, CGFloat)] {
            fill(ctx, teamColor(u.team), x - half, y + dy, half * 2, 4)
        }
        fill(ctx, teamLight(u.team), x - 3, y - 24, 2, 12)
        fill(ctx, KartArt.rgb(255, 255, 255), x - 2, y - 22, 1, 4)
    }
}

@MainActor
final class ArenaView: NSView {
    var onExit: (() -> Void)?
    var onRestart: (() -> Void)?

    private let sim: ArenaSim
    private let mapImage: CGImage?
    private var sprites: [Int: CGImage] = [:]
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var frameContext: CGContext?
    private var origin = CGPoint.zero
    private var scale: CGFloat = 3
    private var mouseInView = CGPoint.zero
    private var clickMarker: (pos: CGPoint, life: TimeInterval, attack: Bool)?
    private var camera = CGPoint(x: 100, y: ArenaSim.laneY)

    init(frame: NSRect, sim: ArenaSim) {
        self.sim = sim
        self.mapImage = ArenaArt.renderMap()
        super.init(frame: frame)
        if let me = sim.unit(sim.playerID) { camera = me.pos }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setSprite(_ image: NSImage, for unitID: Int) {
        if let img = KartArt.rider(from: image, height: 24) { sprites[unitID] = img }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, link == nil {
            let l = displayLink(target: self, selector: #selector(step(_:)))
            l.add(to: .main, forMode: .common)
            link = l
            lastTick = CACurrentMediaTime()
            window?.acceptsMouseMovedEvents = true
        } else if window == nil {
            stop()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    @objc private func step(_ sender: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTick, 0), 1.0 / 30)
        lastTick = now
        sim.step(dt)
        if var m = clickMarker {
            m.life -= dt
            clickMarker = m.life > 0 ? m : nil
        }
        if let me = sim.unit(sim.playerID) {
            let k = CGFloat(min(1, dt * 8))
            camera.x += (me.pos.x - camera.x) * k
            camera.y += (me.pos.y - camera.y) * k
        }
        needsDisplay = true
    }

    // MARK: input

    private func world(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x / scale + origin.x, y: viewPoint.y / scale + origin.y)
    }

    private var aim: CGPoint { world(mouseInView) }

    override func mouseMoved(with event: NSEvent) { mouseInView = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) { mouseInView = convert(event.locationInWindow, from: nil) }
    override func rightMouseDragged(with event: NSEvent) { mouseInView = convert(event.locationInWindow, from: nil) }
    override func mouseDown(with event: NSEvent) { click(event) }
    override func rightMouseDown(with event: NSEvent) { click(event) }

    private func click(_ event: NSEvent) {
        window?.makeFirstResponder(self)
        mouseInView = convert(event.locationInWindow, from: nil)
        let p = aim
        guard let me = sim.unit(sim.playerID) else { return }
        // Clicking near an enemy attacks it; anywhere else walks there.
        let target = sim.units
            .filter { sim.isValidTarget($0, for: me.team) && hypot($0.pos.x - p.x, $0.pos.y - 8 - p.y) < $0.radius + 10 }
            .min { hypot($0.pos.x - p.x, $0.pos.y - p.y) < hypot($1.pos.x - p.x, $1.pos.y - p.y) }
        if let target {
            sim.apply(.attack(target.id), for: me.id)
            clickMarker = (target.pos, 0.35, true)
        } else {
            sim.apply(.move(p), for: me.id)
            clickMarker = (ArenaSim.clampWalkable(p), 0.35, false)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        let id = sim.playerID
        if sim.winner != nil {
            switch event.keyCode {
            case 15: onRestart?()
            case 53: onExit?()
            default: break
            }
            return
        }
        switch event.keyCode {
        case 12: sim.apply(.cast(slot: 0, aim: aim), for: id)
        case 13: sim.apply(.cast(slot: 1, aim: aim), for: id)
        case 14: sim.apply(.cast(slot: 2, aim: aim), for: id)
        case 15: sim.apply(.cast(slot: 3, aim: aim), for: id)
        case 1: sim.apply(.stop, for: id)
        case 11: sim.apply(.recall, for: id)
        case 53: onExit?()
        default: break
        }
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        scale = max(2, (bounds.height / 215).rounded())
        let vw = Int((bounds.width / scale).rounded(.up)), vh = Int((bounds.height / scale).rounded(.up))
        if frameContext?.width != vw || frameContext?.height != vh { frameContext = KartArt.context(width: vw, height: vh) }
        guard let f = frameContext else { return }
        let world = ArenaSim.size
        func center(_ v: CGFloat, view: Int, size: CGFloat) -> CGFloat {
            CGFloat(view) >= size ? size / 2 : min(max(v, CGFloat(view) / 2), size - CGFloat(view) / 2)
        }
        origin = CGPoint(x: (center(camera.x, view: vw, size: world.width) - CGFloat(vw) / 2).rounded(),
                         y: (center(camera.y, view: vh, size: world.height) - CGFloat(vh) / 2).rounded())

        KartArt.fill(f, KartArt.rgb(30, 70, 36), 0, 0, CGFloat(vw), CGFloat(vh))
        f.saveGState()
        f.translateBy(x: -origin.x, y: -origin.y)
        if let mapImage { KartArt.draw(mapImage, in: f, rect: CGRect(origin: .zero, size: world)) }
        drawTelegraphs(f)
        for u in sim.units.sorted(by: { $0.pos.y < $1.pos.y }) { drawUnit(u, in: f) }
        drawProjectiles(f)
        drawRings(f)
        if let m = clickMarker {
            let c = m.attack ? KartArt.rgb(255, 80, 80) : KartArt.rgb(120, 255, 140)
            let r = CGFloat(3 + (0.35 - m.life) * 14)
            f.setStrokeColor(c)
            f.setLineWidth(1)
            f.strokeEllipse(in: CGRect(x: m.pos.x - r, y: m.pos.y - r / 2, width: r * 2, height: r))
        }
        f.restoreGState()
        if let frame = f.makeImage() {
            ctx.interpolationQuality = .none
            KartArt.draw(frame, in: ctx, rect: CGRect(x: 0, y: 0, width: CGFloat(vw) * scale, height: CGFloat(vh) * scale))
        }
        drawOverlayText()
        drawHUD(ctx)
    }

    private func drawTelegraphs(_ f: CGContext) {
        for b in sim.blasts {
            let left = max(0, b.detonateAt - sim.time)
            let c = ArenaArt.typeColor(b.moveType)
            f.setFillColor(c.copy(alpha: 0.18 + 0.25 * CGFloat(1 - left / 0.45)) ?? c)
            f.fillEllipse(in: CGRect(x: b.pos.x - b.radius, y: b.pos.y - b.radius * 0.6, width: b.radius * 2, height: b.radius * 1.2))
            f.setStrokeColor(c)
            f.setLineWidth(1)
            f.strokeEllipse(in: CGRect(x: b.pos.x - b.radius, y: b.pos.y - b.radius * 0.6, width: b.radius * 2, height: b.radius * 1.2))
        }
    }

    private func drawUnit(_ u: ArenaUnit, in f: CGContext) {
        switch u.kind {
        case .tower:
            ArenaArt.tower(f, u, pulse: u.attackFlash > 0)
            if !u.dead { hpBar(f, u, width: 20, yOffset: 40) }
        case .core:
            ArenaArt.core(f, u, time: sim.time)
            if !u.dead { hpBar(f, u, width: 26, yOffset: 34) }
        case .minion, .rangedMinion:
            if u.dead { f.setAlpha(max(0, 1 - CGFloat(sim.time - u.diedAt) * 2)) }
            let bob: CGFloat = u.moving && Int(sim.time * 8) % 2 == 0 ? 1 : 0
            ArenaArt.minion(f, u, bob: bob)
            f.setAlpha(1)
            if !u.dead, u.hp < u.maxHP { hpBar(f, u, width: 8, yOffset: 12) }
        case .champion:
            drawChampion(u, in: f)
        }
    }

    private func drawChampion(_ u: ArenaUnit, in f: CGContext) {
        guard !u.dead else { return }
        let p = CGPoint(x: u.pos.x.rounded(), y: u.pos.y.rounded())
        // Team ring under the feet; gold for the player.
        f.setStrokeColor(u.isPlayer ? KartArt.rgb(255, 214, 60) : ArenaArt.teamColor(u.team))
        f.setLineWidth(1)
        f.strokeEllipse(in: CGRect(x: p.x - 8, y: p.y - 3, width: 16, height: 6))
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.25))
        f.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 2, width: 12, height: 4))
        if u.recallAt != nil {
            f.setStrokeColor(KartArt.rgb(150, 220, 255, 0.8))
            let r = CGFloat(10 + 3 * sin(sim.time * 10))
            f.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - 26, width: r * 2, height: 28))
        }
        let bob: CGFloat = u.moving && Int(sim.time * 10) % 2 == 0 ? 1 : 0
        let lunge: CGFloat = u.attackFlash > 0 ? (u.facingRight ? 2 : -2) : 0
        if let img = sprites[u.id] {
            let w = CGFloat(img.width), h = CGFloat(img.height)
            let rect = CGRect(x: p.x - (w / 2).rounded() + lunge, y: p.y - h + 1 - bob, width: w, height: h)
            if u.hitFlash > 0 { f.setAlpha(0.55) }
            KartArt.draw(img, in: f, rect: rect, flipX: u.facingRight)
            f.setAlpha(1)
        } else {
            KartArt.fill(f, ArenaArt.teamColor(u.team), p.x - 5, p.y - 14, 10, 12)
        }
        if u.shield > 0 {
            f.setStrokeColor(KartArt.rgb(255, 255, 255, 0.7))
            f.strokeEllipse(in: CGRect(x: p.x - 12, y: p.y - 28, width: 24, height: 30))
        }
        hpBar(f, u, width: 22, yOffset: 32)
    }

    private func hpBar(_ f: CGContext, _ u: ArenaUnit, width: CGFloat, yOffset: CGFloat) {
        let x = (u.pos.x - width / 2).rounded(), y = (u.pos.y - yOffset).rounded()
        let color: CGColor = u.isPlayer ? KartArt.rgb(90, 220, 90)
            : (u.team == sim.unit(sim.playerID)?.team ? KartArt.rgb(80, 160, 255) : KartArt.rgb(240, 70, 70))
        KartArt.fill(f, KartArt.rgb(20, 20, 24), x - 1, y - 1, width + 2, 4)
        KartArt.fill(f, color, x, y, (width * u.hpRatio).rounded(), 2)
        if u.shield > 0 {
            let s = min(width, width * u.shield / u.maxHP)
            KartArt.fill(f, KartArt.rgb(240, 240, 240), x + (width * u.hpRatio).rounded(), y, s.rounded(), 2)
        }
        if !sim.isTargetable(u) {
            KartArt.fill(f, KartArt.rgb(160, 160, 170), x, y, width, 2)    // shielded structure
        }
    }

    private func drawProjectiles(_ f: CGContext) {
        for p in sim.projectiles {
            let c = ArenaArt.typeColor(p.moveType)
            let s = p.size
            let speed = max(0.001, hypot(p.vel.x, p.vel.y))
            for k in 1...3 {
                let t = CGFloat(k) * 3
                f.setAlpha(0.5 - CGFloat(k) * 0.12)
                KartArt.fill(f, c, (p.pos.x - p.vel.x / speed * t).rounded(), (p.pos.y - p.vel.y / speed * t).rounded(), s - 1, s - 1)
            }
            f.setAlpha(1)
            KartArt.fill(f, KartArt.rgb(255, 255, 255), p.pos.x.rounded() - s / 2, p.pos.y.rounded() - s / 2, s, s)
            KartArt.fill(f, c, p.pos.x.rounded() - s / 2 + 1, p.pos.y.rounded() - s / 2 + 1, max(1, s - 1), max(1, s - 1))
        }
    }

    private func drawRings(_ f: CGContext) {
        for r in sim.rings {
            let k = CGFloat(r.life / r.maxLife)
            let rad = r.radius * (1.2 - 0.4 * k)
            let c = ArenaArt.typeColor(r.moveType)
            f.setFillColor(c.copy(alpha: 0.3 * k) ?? c)
            f.fillEllipse(in: CGRect(x: r.pos.x - rad, y: r.pos.y - rad * 0.6, width: rad * 2, height: rad * 1.2))
            f.setStrokeColor(c.copy(alpha: k) ?? c)
            f.setLineWidth(1)
            f.strokeEllipse(in: CGRect(x: r.pos.x - rad, y: r.pos.y - rad * 0.6, width: rad * 2, height: rad * 1.2))
        }
    }

    // MARK: HUD

    private func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) * scale, y: (p.y - origin.y) * scale) }

    private func text(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor = .white,
                      weight: NSFont.Weight = .heavy, align: NSTextAlignment = .left, mono: Bool = false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .shadow: shadow])
        let w = str.size().width
        let x = align == .center ? p.x - w / 2 : (align == .right ? p.x - w : p.x)
        str.draw(at: NSPoint(x: x, y: p.y))
    }

    private func panel(_ ctx: CGContext, _ rect: CGRect, alpha: CGFloat = 0.5) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
    }

    /// Names, levels and damage numbers pinned to world positions, drawn crisp.
    private func drawOverlayText() {
        guard let me = sim.unit(sim.playerID) else { return }
        for u in sim.units where u.kind == .champion && !u.dead {
            let s = screen(CGPoint(x: u.pos.x, y: u.pos.y - 40))
            let ally = u.team == me.team
            let color: NSColor = u.isPlayer ? NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                : (ally ? NSColor(red: 0.6, green: 0.8, blue: 1, alpha: 1) : NSColor(red: 1, green: 0.6, blue: 0.6, alpha: 1))
            text("Lv\(u.level) \(u.name)", at: CGPoint(x: s.x, y: s.y - 14), size: 11, color: color, weight: .bold, align: .center)
        }
        for fl in sim.floaters {
            let s = screen(fl.pos)
            let a = CGFloat(min(1, fl.life / 0.3))
            let (color, size): (NSColor, CGFloat) = switch fl.style {
            case .normal: (.white, 13)
            case .strong: (NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), 16)
            case .weak: (NSColor(white: 0.7, alpha: 1), 11)
            case .hurt: (NSColor(red: 1, green: 0.35, blue: 0.35, alpha: 1), 14)
            case .gold: (NSColor(red: 1, green: 0.9, blue: 0.3, alpha: 1), 14)
            }
            text(fl.text, at: s, size: size, color: color.withAlphaComponent(a), align: .center)
        }
        // Aim reticle.
        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx?.setLineWidth(1.5)
        ctx?.strokeEllipse(in: CGRect(x: mouseInView.x - 6, y: mouseInView.y - 6, width: 12, height: 12))
    }

    private func drawHUD(_ ctx: CGContext) {
        guard let me = sim.unit(sim.playerID) else { return }
        let gold = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)

        // Score and clock.
        panel(ctx, CGRect(x: bounds.midX - 120, y: 8, width: 240, height: 54))
        let blueC = NSColor(red: 0.5, green: 0.72, blue: 1, alpha: 1), redC = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1)
        text("\(sim.score[0])", at: CGPoint(x: bounds.midX - 60, y: 10), size: 26, color: blueC, align: .center)
        text("\(sim.score[1])", at: CGPoint(x: bounds.midX + 60, y: 10), size: 26, color: redC, align: .center)
        let t = Int(sim.time)
        text(String(format: "%d:%02d", t / 60, t % 60), at: CGPoint(x: bounds.midX, y: 14), size: 16, align: .center, mono: true)
        for team in [ArenaTeam.blue, .red] {
            let towers = sim.units.filter { $0.kind == .tower && $0.team == team }.sorted { $0.tier < $1.tier }
            let icons = towers.map { $0.dead ? "○" : "●" }.joined(separator: " ")
            text(icons, at: CGPoint(x: bounds.midX + (team == .blue ? -60 : 60), y: 42), size: 10,
                 color: team == .blue ? blueC : redC, weight: .bold, align: .center)
        }
        let next = Int(max(0, sim.nextWave - sim.time).rounded(.up))
        text("미니언 \(next)초", at: CGPoint(x: bounds.midX, y: 40), size: 10, color: NSColor(white: 1, alpha: 0.7),
             weight: .semibold, align: .center)

        // Kill feed.
        for (k, item) in sim.feed.suffix(4).enumerated() {
            let c: NSColor = item.team == .blue ? blueC : (item.team == .red ? redC : gold)
            text(item.text, at: CGPoint(x: bounds.midX, y: 70 + CGFloat(k) * 18), size: 13, color: c, weight: .bold, align: .center)
        }

        drawMinimap(ctx)
        drawStatus(ctx, me)
        drawSkillBar(ctx, me)

        text("클릭 이동·공격   Q W E R 스킬(마우스 방향)   S 정지   B 귀환   Esc 나가기",
             at: CGPoint(x: bounds.midX, y: bounds.height - 18), size: 10, color: NSColor(white: 1, alpha: 0.65),
             weight: .semibold, align: .center)

        if me.dead, sim.winner == nil {
            let left = Int(max(0, me.respawnAt - sim.time).rounded(.up))
            panel(ctx, CGRect(x: bounds.midX - 150, y: bounds.midY - 50, width: 300, height: 70), alpha: 0.6)
            text("쓰러졌어요…", at: CGPoint(x: bounds.midX, y: bounds.midY - 44), size: 22, align: .center)
            text("\(left)초 후 부활", at: CGPoint(x: bounds.midX, y: bounds.midY - 14), size: 15,
                 color: NSColor(white: 0.85, alpha: 1), align: .center)
        }
        if let w = sim.winner {
            let won = w == me.team
            panel(ctx, CGRect(x: bounds.midX - 200, y: bounds.midY - 90, width: 400, height: 150), alpha: 0.7)
            text(won ? "승리!" : "패배…", at: CGPoint(x: bounds.midX, y: bounds.midY - 84), size: 46,
                 color: won ? gold : NSColor(white: 0.85, alpha: 1), align: .center)
            text("\(me.name)  \(me.kills)킬 \(me.deaths)데스  Lv\(me.level)", at: CGPoint(x: bounds.midX, y: bounds.midY - 20),
                 size: 16, align: .center)
            text("R 다시 하기   ·   Esc 나가기", at: CGPoint(x: bounds.midX, y: bounds.midY + 20), size: 13,
                 color: NSColor(white: 1, alpha: 0.8), weight: .semibold, align: .center)
        }
    }

    private func drawMinimap(_ ctx: CGContext) {
        let box = CGRect(x: bounds.width - 232, y: 8, width: 224, height: 76)
        panel(ctx, box)
        let s = (box.width - 12) / ArenaSim.size.width
        let ox = box.minX + 6, oy = box.midY - ArenaSim.size.height * s / 2
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * s, y: oy + p.y * s) }
        ctx.setFillColor(NSColor(calibratedRed: 0.6, green: 0.5, blue: 0.35, alpha: 0.8).cgColor)
        let lane = map(CGPoint(x: 20, y: ArenaSim.laneY - 37))
        ctx.fill(CGRect(x: lane.x, y: lane.y, width: 960 * s, height: 74 * s))
        let myTeam = sim.unit(sim.playerID)?.team
        for u in sim.units where !u.dead {
            let p = map(u.pos)
            let c = ArenaArt.teamColor(u.team)
            ctx.setFillColor(c)
            switch u.kind {
            case .tower, .core:
                ctx.fill(CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
            case .minion, .rangedMinion:
                ctx.fill(CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2))
            case .champion:
                let r: CGFloat = u.isPlayer ? 4.5 : 3.5
                if u.isPlayer || u.team == myTeam {
                    ctx.setFillColor(u.isPlayer ? NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor : NSColor.white.cgColor)
                    ctx.fillEllipse(in: CGRect(x: p.x - r - 1, y: p.y - r - 1, width: r * 2 + 2, height: r * 2 + 2))
                    ctx.setFillColor(c)
                }
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }
        }
        // Camera frame.
        let tl = map(origin)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: tl.x, y: tl.y, width: bounds.width / scale * s, height: bounds.height / scale * s))
    }

    private func drawStatus(_ ctx: CGContext, _ me: ArenaUnit) {
        let box = CGRect(x: 10, y: bounds.height - 96, width: 250, height: 70)
        panel(ctx, box)
        if let img = sprites[me.id] {
            ctx.interpolationQuality = .none
            let h: CGFloat = 52, w = h * CGFloat(img.width) / CGFloat(img.height)
            KartArt.draw(img, in: ctx, rect: CGRect(x: box.minX + 8, y: box.minY + 9, width: min(w, 56), height: h))
        }
        let x = box.minX + 72
        text("Lv\(me.level) \(me.name)", at: CGPoint(x: x, y: box.minY + 6), size: 13, weight: .bold)
        let bar = CGRect(x: x, y: box.minY + 28, width: box.width - 84, height: 12)
        ctx.setFillColor(NSColor(white: 0.15, alpha: 1).cgColor)
        ctx.fill(bar)
        ctx.setFillColor(NSColor(red: 0.35, green: 0.85, blue: 0.35, alpha: 1).cgColor)
        ctx.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width * me.hpRatio, height: bar.height))
        text("\(Int(me.hp)) / \(Int(me.maxHP))", at: CGPoint(x: bar.midX, y: bar.minY - 1), size: 10, weight: .bold, align: .center, mono: true)
        let xpBar = CGRect(x: x, y: box.minY + 46, width: box.width - 84, height: 6)
        ctx.setFillColor(NSColor(white: 0.15, alpha: 1).cgColor)
        ctx.fill(xpBar)
        let need = ArenaSim.xpNeeded(me.level)
        let frac = me.level >= ArenaSim.maxLevel ? 1 : min(1, me.xp / need)
        ctx.setFillColor(NSColor(red: 0.6, green: 0.5, blue: 1, alpha: 1).cgColor)
        ctx.fill(CGRect(x: xpBar.minX, y: xpBar.minY, width: xpBar.width * frac, height: xpBar.height))
        text("\(me.kills)킬 \(me.deaths)데스", at: CGPoint(x: x, y: box.minY + 54), size: 10,
             color: NSColor(white: 0.85, alpha: 1), weight: .semibold)
    }

    private func drawSkillBar(_ ctx: CGContext, _ me: ArenaUnit) {
        let keys = ["Q", "W", "E", "R"]
        let shapes = ["스킬샷", "범위", "돌진", "궁극기"]
        let size: CGFloat = 64, gap: CGFloat = 8
        let total = size * 4 + gap * 3
        let y = bounds.height - size - 30
        for (k, skill) in me.skills.enumerated() {
            let x = bounds.midX - total / 2 + CGFloat(k) * (size + gap)
            let rect = CGRect(x: x, y: y, width: size, height: size)
            panel(ctx, rect, alpha: 0.65)
            ctx.setFillColor(ArenaArt.typeColor(skill.move.type))
            ctx.fill(CGRect(x: x + 4, y: y + size - 8, width: size - 8, height: 4))
            text(keys[k], at: CGPoint(x: x + 6, y: y + 3), size: 15)
            text(shapes[k], at: CGPoint(x: x + size - 6, y: y + 6), size: 9, color: NSColor(white: 0.75, alpha: 1),
                 weight: .semibold, align: .right)
            let name = skill.move.name.count > 6 ? String(skill.move.name.prefix(6)) : skill.move.name
            text(name, at: CGPoint(x: x + size / 2, y: y + 26), size: 11, weight: .bold, align: .center)
            let locked = k == 3 && me.level < 3
            if locked || skill.remaining > 0 {
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
                let frac = locked ? 1 : CGFloat(skill.remaining / skill.cooldown)
                ctx.fill(CGRect(x: x, y: y + size * (1 - frac), width: size, height: size * frac))
                text(locked ? "Lv3" : "\(Int(skill.remaining.rounded(.up)))", at: CGPoint(x: x + size / 2, y: y + 20),
                     size: locked ? 14 : 22, color: locked ? NSColor(white: 0.8, alpha: 1) : .white, align: .center)
            }
        }
    }
}

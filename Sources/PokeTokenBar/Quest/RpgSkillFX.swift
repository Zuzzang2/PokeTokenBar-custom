import AppKit
import CoreGraphics

// SPIKE: signature looks for every skill and basic attack. The world stamps what a cast makes (`RpgFXStamp`: skill id,
// facing, caster position, order) and this file draws each stamped effect, projectile and trap with that skill's own
// painter (`RpgArt.looks`, filled in RpgSkillLooks.swift); anything unstamped — monsters, pets, an older host — keeps the
// generic element-tinted look. Everything is chunky pixels into the low-res frame: hard edges, white-hot cores, glows
// stacked from translucent ellipses, no blur. Colours are made once (palettes are static), never per pixel.

extension RpgArt {
    // MARK: palettes

    /// Five tones of one look: white-hot core, light, mid, dark rim and an accent.
    struct FXPal {
        let hi: CGColor, lt: CGColor, md: CGColor, dk: CGColor, ac: CGColor
        /// Identifies the palette in the sprite cache.
        let key: Int

        init(_ hi: UInt32, _ lt: UInt32, _ md: UInt32, _ dk: UInt32, _ ac: UInt32) {
            func c(_ v: UInt32) -> CGColor { CGColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
            (self.hi, self.lt, self.md, self.dk, self.ac) = (c(hi), c(lt), c(md), c(dk), c(ac))
            key = [hi, lt, md, dk, ac].reduce(17) { $0 &* 1_000_003 &+ Int($1) }
        }
    }

    /// Up to four colours for the particle helpers, passed without allocating an array.
    struct Tones {
        let c0: CGColor, c1: CGColor, c2: CGColor, c3: CGColor
        let count: Int
        init(_ a: CGColor, _ b: CGColor? = nil, _ c: CGColor? = nil, _ d: CGColor? = nil) {
            (c0, c1, c2, c3) = (a, b ?? a, c ?? b ?? a, d ?? c ?? b ?? a)
            count = d != nil ? 4 : (c != nil ? 3 : (b != nil ? 2 : 1))
        }
        subscript(_ i: Int) -> CGColor {
            switch i % count {
            case 0: c0
            case 1: c1
            case 2: c2
            default: c3
            }
        }
    }

    /// The element's palette (weapon colours on basic attacks, accents on skills).
    static func elemPal(_ e: RpgElement) -> FXPal { elemPals[e] ?? elemPals[.base]! }
    private static let elemPals: [RpgElement: FXPal] = [
        .base: FXPal(0xFFFFFF, 0xDCE4F0, 0x9AA6C0, 0x4A5470, 0xFFE9A0),
        .fire: FXPal(0xFFF8C8, 0xFFC63C, 0xEC561E, 0x8C1E14, 0xFFE070),
        .ice: FXPal(0xFFFFFF, 0xAAEEFF, 0x46A6EE, 0x1E4C9A, 0xDCFAFF),
        .thunder: FXPal(0xFFFFE6, 0xFFE850, 0xECA61E, 0x7A4A10, 0xFFFFFF),
        .wind: FXPal(0xF0FFF0, 0x96F0AA, 0x38A864, 0x165036, 0xFFFFFF),
        .holy: FXPal(0xFFFFFF, 0xFFF0AA, 0xECBA3C, 0x8A5E14, 0xFFFFFF),
        .cosmic: FXPal(0xFFF0FF, 0xCC8CFF, 0x6E3CC8, 0x2C1460, 0x78DCFF),
        .poison: FXPal(0xE6FFC8, 0x96E650, 0x5A9628, 0x284A14, 0xC878FF),
    ]

    // MARK: looks

    /// One frame of one effect, as a painter sees it.
    struct FXF {
        /// Where the effect is, how far along (0…1), seconds since it began, its length and the world clock.
        let x: Double, y: Double, t: Double, age: Double, dur: Double, now: Double
        /// The caster's facing and feet when the skill went off, and this effect's order within the cast.
        let dir: Double, ox: Double, oy: Double, seq: Int
        /// Stable per effect, for scattering particles the same way every frame.
        let seed: UInt64
        /// The effect's radius: from its kind, else the skill's template, else 20.
        let r: Double
        let kind: RpgFX.Kind
        let el: RpgElement
        let crit: Bool
        let pal: FXPal
    }

    /// One frame of one projectile.
    struct ShotF {
        let x: Double, y: Double
        /// Unit direction of flight and speed (px/s).
        let ux: Double, uy: Double, speed: Double
        let now: Double
        /// The caster's feet when it was fired and its order among the cast's shots.
        let ox: Double, oy: Double, seq: Int
        let seed: UInt64
        let kind: RpgShot.Kind
        let el: RpgElement
        let pal: FXPal
    }

    /// A placed trap or turret this frame.
    struct TrapF {
        let x: Double, y: Double, now: Double
        let armed: Bool
        /// Seconds until it expires.
        let left: Double
        /// The caster's facing when it was placed, and its order among the cast's traps.
        let dir: Double, seq: Int
        let pal: FXPal
    }

    /// Draws one effect; false hands it to the generic look.
    typealias FXPaint = @MainActor (CGContext, FXF) -> Bool
    typealias ShotPaint = @MainActor (CGContext, ShotF) -> Void
    typealias TrapPaint = @MainActor (CGContext, TrapF) -> Void

    /// How one skill (or basic attack) looks.
    struct FXLook {
        let pal: FXPal
        /// Its effects other than hit sparks and heals.
        var draw: FXPaint? = nil
        /// Ground marks drawn under the units (cracks, rune circles, scorch).
        var floor: FXPaint? = nil
        /// Hit sparks on monsters; nil = the shared impact in this look's colours.
        var hit: FXPaint? = nil
        /// Heals it hands out (`RpgFXStamp.heal`); nil = the shared heal in this look's colours.
        var heal: FXPaint? = nil
        var shot: ShotPaint? = nil
        var trap: TrapPaint? = nil
    }

    /// Every look by style id: skill ids, "basic:<class>" (tables in RpgSkillLooks.swift).
    static let looks: [String: FXLook] = [basicLooks, warriorLooks, archerLooks, mageLooks, rogueLooks, clericLooks, monkLooks, summonerLooks, mechanicLooks].reduce(into: [:]) { $0.merge($1) { a, _ in a } }

    // MARK: drawing

    /// Effects of `map`. `ground` draws only the ground marks (call it before the units), otherwise everything else.
    static func drawEffects(_ f: CGContext, _ list: [RpgFX], map: RpgMapID, time: Double, ground: Bool = false) {
        for e in list where e.map == map && time >= e.start {
            if ground {
                // Ground marks belong to the main effect, never to its hit sparks or heals.
                if let s = e.stamp, s.heal != true, !e.kind.isSpark, let look = looks[s.style], let floor = look.floor {
                    _ = floor(f, fxFrame(e, s, look, time: time, progress: progress(e, time)))
                }
            } else if !drawStyled(f, e, time: time) {
                drawGeneric(f, e, progress: progress(e, time))
            }
        }
    }

    /// Draws `e` in its skill's look; false when there is none (no stamp, a style this build does not know, or a
    /// painter that leaves this kind of effect to the generic look).
    static func drawStyled(_ f: CGContext, _ e: RpgFX, time: Double) -> Bool {
        guard let s = e.stamp, let look = looks[s.style] else { return false }
        return paint(f, look, s, fxFrame(e, s, look, time: time, progress: progress(e, time)))
    }

    private static func progress(_ e: RpgFX, _ time: Double) -> Double { max(0, min(0.999, (time - e.start) / e.duration)) }

    private static func paint(_ f: CGContext, _ look: FXLook, _ s: RpgFXStamp, _ frame: FXF) -> Bool {
        if case .spark = frame.kind { return (look.hit ?? impact)(f, frame) }
        if s.heal == true { return (look.heal ?? healGlow)(f, frame) }
        return look.draw?(f, frame) ?? false
    }

    private static func fxFrame(_ e: RpgFX, _ s: RpgFXStamp, _ look: FXLook, time: Double, progress: Double) -> FXF {
        var r = 20.0, crit = false
        switch e.kind {
        case .slash(_, let radius), .burst(let radius), .ice(let radius), .meteor(let radius), .rain(let radius), .telegraph(let radius): r = radius
        case .spark(let c): crit = c
        default:
            // Templates draw their blasts at 0.9 (zone) or 0.7 (line) of the hit radius (`RpgWorld.castTemplate`).
            if let t = RpgSkills.def(s.style)?.fx { r = t.radius * (t.shape == .line ? 0.7 : (t.shape == .zone ? 0.9 : 1)) }
        }
        let seed = UInt64(truncatingIfNeeded: Int(e.start * 1000)) &* 31 &+ UInt64(truncatingIfNeeded: Int(e.pos.x) &* 7 &+ Int(e.pos.y)) &+ UInt64(s.seq)
        return FXF(x: Double(e.pos.x), y: Double(e.pos.y), t: progress, age: time - e.start, dur: e.duration, now: time,
                   dir: s.dir, ox: Double(s.from.x), oy: Double(s.from.y), seq: s.seq, seed: seed, r: r, kind: e.kind, el: e.element, crit: crit, pal: look.pal)
    }

    /// Projectiles of `map`.
    static func drawShots(_ f: CGContext, _ list: [RpgShot], map: RpgMapID, time: Double) {
        for s in list where s.map == map {
            let speed = max(1, hypot(Double(s.vel.dx), Double(s.vel.dy)))
            let ux = Double(s.vel.dx) / speed, uy = Double(s.vel.dy) / speed
            if let st = s.stamp, let look = looks[st.style], let paint = look.shot {
                let seed = UInt64(truncatingIfNeeded: st.seq &* 977 &+ s.ownerID &* 131 &+ Int(st.from.x) &+ Int(st.from.y) &* 3)
                paint(f, ShotF(x: Double(s.pos.x), y: Double(s.pos.y), ux: ux, uy: uy, speed: speed, now: time, ox: Double(st.from.x), oy: Double(st.from.y),
                               seq: st.seq, seed: seed, kind: s.kind, el: s.element, pal: look.pal))
                continue
            }
            drawShotGeneric(f, s, ux: ux, uy: uy)
        }
    }

    /// A trap or turret, in its skill's look when it has one.
    static func drawTrap(_ f: CGContext, _ t: RpgTrap, time: Double) {
        if let st = t.stamp, let look = looks[st.style], let paint = look.trap {
            paint(f, TrapF(x: Double(t.pos.x), y: Double(t.pos.y), now: time, armed: time >= t.armedAt, left: t.expires - time, dir: st.dir, seq: st.seq, pal: look.pal))
        } else if t.turret == true {
            turret(f, at: t.pos, time: time)
        } else {
            trap(f, at: t.pos, time: time)
        }
    }

    // MARK: shared impact and heal

    /// A hit spark in a look's colours; crits get a bigger, ringed burst.
    static func impact(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal
        let s = [2, 4, 5, 3][min(3, Int(f.t * 4))]
        star(c, f.x, f.y, s + (f.crit ? 2 : 0), p.md, p.hi)
        if f.crit, f.t > 0.2 { ring(c, f.x, f.y, 3 + f.t * 10, p.lt) }
        return true
    }

    /// A heal on an ally in a look's colours: a widening ring at the feet and pluses rising off the body.
    static func healGlow(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.6, 1)) {
            glow(c, f.x, f.y - 8, 10, p.lt, 0.5 * (1 - f.t))
            circle(c, f.x, f.y, 4 + 9 * u, p.lt, squash: 0.4)
            circle(c, f.x, f.y, 2 + 6 * u, p.hi, squash: 0.4, dash: 2)
        }
        var r = KartRNG(seed: f.seed)
        for i in 0..<5 {
            let d = Double(i) * 0.12, v = win(f.t, d, d + 0.55)
            guard v > 0, v < 1 else { continue }
            let x = f.x - 7 + Double(r.int(15)), y = f.y - 4 - v * 18
            fade(c, 1 - v * v) { plus(c, x, y, i % 2 == 0 ? p.hi : p.lt, p.md) }
        }
        return true
    }

    /// A 3×3 plus with a darker outline-free shadow, for heals.
    static func plus(_ c: CGContext, _ x: Double, _ y: Double, _ col: CGColor, _ shade: CGColor) {
        box(c, x, y - 1, 1, 3, col); box(c, x - 1, y, 3, 1, col); px(c, x + 1, y + 1, shade)
    }

    // MARK: generic (unstamped) look

    static func drawGeneric(_ f: CGContext, _ e: RpgFX, progress: Double) {
        let frame = Int(progress * 6)
        switch e.kind {
        case .slash(let angle, let radius): slash(f, at: e.pos, angle: angle, frame: frame, element: e.element, radius: radius)
        case .burst(let radius): burst(f, at: e.pos, frame: frame, element: e.element, radius: radius)
        case .ice(let radius): iceSpikes(f, at: e.pos, frame: frame, radius: radius)
        case .meteor(let radius): meteor(f, at: e.pos, frame: frame, radius: radius)
        case .chain(let points):
            let el = elem(e.element)
            for k in 0..<(points.count - 1) where frame < 5 {
                bolt(f, from: points[k], to: points[k + 1], seed: UInt64(truncatingIfNeeded: frame * 13 + k), el)
                star(f, Double(points[k + 1].x), Double(points[k + 1].y), 2, el.edge, el.core)
            }
        case .strike:
            let el = elem(.thunder)
            if frame < 4 { bolt(f, from: CGPoint(x: e.pos.x + 4, y: e.pos.y - 70), to: e.pos, seed: UInt64(truncatingIfNeeded: frame * 7 + Int(e.pos.x)), el) }
            burst(f, at: e.pos, frame: frame, element: .thunder, radius: 22)
        case .rain(let radius): arrowRain(f, at: e.pos, frame: Int(progress * 30) % 6, radius: radius, seed: UInt64(truncatingIfNeeded: Int(progress * 30)))
        case .spark(let crit): hitSpark(f, at: e.pos, frame: Int(progress * 4), crit: crit, element: e.element)
        case .levelUp: levelUp(f, at: e.pos, frame: Int(progress * 12) % 6, element: e.element)
        case .telegraph(let radius):
            let k = CGFloat(progress)
            f.setFillColor(KartArt.rgb(0, 0, 0, 0.15 + 0.35 * k))
            f.fillEllipse(in: CGRect(x: e.pos.x - radius * k, y: e.pos.y - radius * 0.5 * k, width: radius * 2 * k, height: radius * k))
            ring(f, Double(e.pos.x), Double(e.pos.y), radius, KartArt.rgb(255, 80, 80), squash: 0.5)
        }
    }

    static func drawShotGeneric(_ f: CGContext, _ s: RpgShot, ux: Double, uy: Double) {
        let e = elem(s.element)
        let x = Double(s.pos.x), y = Double(s.pos.y)
        switch s.kind {
        case .arrow, .bigArrow, .mobArrow, .poisonArrow:
            let len = s.kind == .bigArrow ? 12.0 : 7.0
            if s.kind != .mobArrow {
                for k in 1...6 { dot(f, x - ux * (len + Double(k) * 1.6), y - uy * (len + Double(k) * 1.6), (k < 3 ? e.mid : e.edge).copy(alpha: 1 - Double(k) * 0.14) ?? e.mid) }
            }
            line(f, x - ux * len, y - uy * len, x, y, s.kind == .mobArrow ? KartArt.rgb(200, 190, 170) : KartArt.rgb(150, 100, 56))
            dot(f, x + ux, y + uy, s.kind == .mobArrow ? KartArt.rgb(230, 226, 210) : e.core, s.kind == .bigArrow ? 2 : 1)
            if s.kind == .bigArrow { disc(f, x, y, 3, e.mid.copy(alpha: 0.5) ?? e.mid) }
        case .orb, .bossOrb:
            let r = s.kind == .bossOrb ? 3.4 : 2.6
            for k in 1...5 { dot(f, x - ux * Double(k) * 1.8, y - uy * Double(k) * 1.8, e.mid.copy(alpha: 1 - Double(k) * 0.18) ?? e.mid) }
            disc(f, x, y, r, e.edge); disc(f, x, y, r * 0.6, e.mid); dot(f, x, y, e.core)
        case .slimeBall:
            disc(f, x, y, 3, KartArt.rgb(46, 140, 80)); disc(f, x - 0.5, y - 0.5, 2, KartArt.rgb(110, 220, 130))
            dot(f, x - 1, y - 1, KartArt.rgb(240, 255, 240))
        }
    }
}

extension RpgFX.Kind {
    var isSpark: Bool { if case .spark = self { true } else { false } }
}

// MARK: - primitives (world pixels, y down)

extension RpgArt {
    private static var fxAlpha: CGFloat = 1

    /// Runs `body` at opacity `a` (nests: a fade inside a fade multiplies).
    static func fade(_ c: CGContext, _ a: Double, _ body: () -> Void) {
        let prev = fxAlpha, next = prev * CGFloat(max(0, min(1, a)))
        guard next > 0.02 else { return }
        fxAlpha = next; c.setAlpha(next)
        body()
        fxAlpha = prev; c.setAlpha(prev)
    }

    /// 0 before `a`, 1 after `b`, linear between.
    static func win(_ t: Double, _ a: Double, _ b: Double) -> Double { max(0, min(1, (t - a) / (b - a))) }
    static func easeOut(_ t: Double) -> Double { 1 - pow(1 - max(0, min(1, t)), 3) }
    static func easeIn(_ t: Double) -> Double { pow(max(0, min(1, t)), 2) }
    /// Snaps to full by `at`, holds a beat (the hit-stop), then decays to 0 at the end.
    static func punch(_ t: Double, at: Double = 0.12, hold: Double = 0.12) -> Double {
        t < at ? t / at : (t < at + hold ? 1 : max(0, 1 - (t - at - hold) / max(0.01, 1 - at - hold)))
    }

    /// A square pixel (or `s`×`s` block) centred on (x, y).
    @inline(__always) static func px(_ c: CGContext, _ x: Double, _ y: Double, _ col: CGColor, _ s: Double = 1) {
        let h = (s - 1) / 2
        c.setFillColor(col)
        c.fill(CGRect(x: (x - h).rounded(), y: (y - h).rounded(), width: s, height: s))
    }

    static func box(_ c: CGContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: CGColor) {
        c.setFillColor(col)
        c.fill(CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded()))
    }

    /// A straight line `w` px thick.
    static func seg(_ c: CGContext, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ col: CGColor, _ w: Double = 1) {
        let n = max(1, Int(max(abs(x1 - x0), abs(y1 - y0))))
        let h = (w - 1) / 2
        c.setFillColor(col)
        for i in 0...n {
            let t = Double(i) / Double(n)
            c.fill(CGRect(x: (x0 + (x1 - x0) * t - h).rounded(), y: (y0 + (y1 - y0) * t - h).rounded(), width: w, height: w))
        }
    }

    /// A line from (x, y) along `a` for `len`, thinning from `w` to 1: rays, streaks, spikes.
    static func spike(_ c: CGContext, _ x: Double, _ y: Double, _ a: Double, _ len: Double, _ col: CGColor, _ w: Double = 2, squash: Double = 1) {
        let n = max(1, Int(len))
        c.setFillColor(col)
        for i in 0...n {
            let t = Double(i) / Double(n), s = max(1, (w * (1 - t)).rounded())
            c.fill(CGRect(x: (x + cos(a) * len * t - (s - 1) / 2).rounded(), y: (y + sin(a) * len * t * squash - (s - 1) / 2).rounded(), width: s, height: s))
        }
    }

    /// A circle (or part of one) one pixel wide; `dash` > 0 leaves gaps.
    static func circle(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ col: CGColor, squash: Double = 1,
                       from a0: Double = 0, to a1: Double = 2 * .pi, dash: Int = 0) {
        guard r >= 0.5 else { px(c, x, y, col); return }
        let n = max(6, Int(abs(a1 - a0) * r * 1.3))
        c.setFillColor(col)
        for i in 0...n {
            if dash > 0, (i / dash) % 2 == 1 { continue }
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            c.fill(CGRect(x: (x + cos(a) * r).rounded(), y: (y + sin(a) * r * squash).rounded(), width: 1, height: 1))
        }
    }

    /// A regular polygon outline (triangles, diamonds, hexes), turned by `rot`.
    static func poly(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ sides: Int, _ rot: Double, _ col: CGColor, squash: Double = 1) {
        for i in 0..<sides {
            let a = rot + Double(i) / Double(sides) * 2 * .pi, b = rot + Double(i + 1) / Double(sides) * 2 * .pi
            seg(c, x + cos(a) * r, y + sin(a) * r * squash, x + cos(b) * r, y + sin(b) * r * squash, col)
        }
    }

    /// A ring with `n` sharp points (roars, screams, shatter fronts).
    static func jag(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ col: CGColor, n: Int = 12, amp: Double = 2.5, squash: Double = 1, rot: Double = 0) {
        let m = n * 2
        for i in 0..<m {
            let a = rot + Double(i) / Double(m) * 2 * .pi, b = rot + Double(i + 1) / Double(m) * 2 * .pi
            let ra = r + (i % 2 == 0 ? amp : -amp), rb = r + (i % 2 == 0 ? -amp : amp)
            seg(c, x + cos(a) * ra, y + sin(a) * ra * squash, x + cos(b) * rb, y + sin(b) * rb * squash, col)
        }
    }

    /// A small sword along `a`: grip, a cross-guard and a bright blade `len` long.
    static func blade(_ c: CGContext, _ x: Double, _ y: Double, _ a: Double, _ len: Double, _ p: FXPal) {
        let ux = cos(a), uy = sin(a), nx = -uy, ny = ux
        seg(c, x - ux * 3, y - uy * 3, x, y, p.dk)
        seg(c, x + nx * 2, y + ny * 2, x - nx * 2, y - ny * 2, p.ac)
        seg(c, x + ux, y + uy, x + ux * len, y + uy * len, p.lt, 2)
        seg(c, x + ux, y + uy, x + ux * len, y + uy * len, p.hi)
    }

    /// A shock ring `w` px thick: white leading edge, then light, mid and a dark trailing rim.
    static func shock(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ w: Int, _ p: FXPal, squash: Double = 1) {
        let tones = Tones(p.hi, p.lt, p.md, p.dk)
        for k in 0..<max(1, w) where r - Double(k) > 0.5 {
            circle(c, x, y, r - Double(k), tones[min(3, k * 4 / max(1, w))], squash: squash)
        }
    }

    /// A ring `a` px along `rot` and `b` px across it (ki rings, shock fronts seen edge-on).
    static func oval(_ c: CGContext, _ x: Double, _ y: Double, _ a: Double, _ b: Double, _ rot: Double, _ col: CGColor, from a0: Double = 0, to a1: Double = 2 * .pi) {
        let n = max(8, Int(abs(a1 - a0) * max(a, b) * 1.3))
        let ux = cos(rot), uy = sin(rot)
        c.setFillColor(col)
        for i in 0...n {
            let th = a0 + (a1 - a0) * Double(i) / Double(n)
            let u = cos(th) * a, v = sin(th) * b
            c.fill(CGRect(x: (x + ux * u - uy * v).rounded(), y: (y + uy * u + ux * v).rounded(), width: 1, height: 1))
        }
    }

    static func ellipse(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ col: CGColor, squash: Double = 1) {
        guard r > 0.4 else { return }
        c.setFillColor(col)
        c.fillEllipse(in: CGRect(x: (x - r).rounded(), y: (y - r * squash).rounded(), width: (r * 2).rounded(), height: max(1, (r * 2 * squash).rounded())))
    }

    /// Soft light: stacked translucent ellipses, faint and wide to strong and small.
    static func glow(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ col: CGColor, _ a: Double = 1, squash: Double = 1) {
        fade(c, a * 0.22) { ellipse(c, x, y, r, col, squash: squash) }
        fade(c, a * 0.3) { ellipse(c, x, y, r * 0.66, col, squash: squash) }
        fade(c, a * 0.45) { ellipse(c, x, y, r * 0.36, col, squash: squash) }
    }

    /// A blade arc around (x, y) at radius `r` from `a0` to `a1` (the leading end), up to `w` px thick and tapering
    /// at both ends, its outer edge white-hot and its inner side darkening.
    static func crescent(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ w: Double, _ p: FXPal,
                         squash: Double = 1, lead: Double = 0.75, rim: CGColor? = nil) {
        let span = a1 - a0
        let n = max(4, Int(abs(span) * (r + w) * 1.2))
        let tones = Tones(p.hi, p.lt, p.md, p.dk)
        for i in 0...n {
            let u = Double(i) / Double(n)
            let a = a0 + span * u
            // Thickest near the leading end, a sharp point at the head, a long fade at the tail.
            let th = u < lead ? w * pow(u / lead, 0.8) : w * (1 - (u - lead) / (1 - lead) * 0.85)
            let k = max(1, Int(th.rounded()))
            let ca = cos(a), sa = sin(a) * squash
            if let rim, k > 1 {
                c.setFillColor(rim)
                c.fill(CGRect(x: (x + ca * (r + th / 2 + 1)).rounded(), y: (y + sa * (r + th / 2 + 1)).rounded(), width: 1, height: 1))
            }
            for j in 0..<k {
                let rr = r + th / 2 - Double(j)
                c.setFillColor(tones[min(3, j * 4 / max(1, k) + (u < 0.25 ? 1 : 0))])
                c.fill(CGRect(x: (x + ca * rr).rounded(), y: (y + sa * rr).rounded(), width: 1, height: 1))
            }
        }
    }

    /// A filled ring sector between radii `r0` and `r1` (a swept fan, a cone of breath).
    static func wedge(_ c: CGContext, _ x: Double, _ y: Double, _ r0: Double, _ r1: Double, _ a0: Double, _ a1: Double, _ col: CGColor, squash: Double = 1) {
        let n = max(3, Int(abs(a1 - a0) * r1 / 3))
        c.beginPath()
        for i in 0...n {
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            let q = CGPoint(x: x + cos(a) * r1, y: y + sin(a) * r1 * squash)
            if i == 0 { c.move(to: q) } else { c.addLine(to: q) }
        }
        for i in stride(from: n, through: 0, by: -1) {
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            c.addLine(to: CGPoint(x: x + cos(a) * r0, y: y + sin(a) * r0 * squash))
        }
        c.closePath()
        c.setFillColor(col)
        c.fillPath()
    }

    /// Lightning between two points: a jagged three-tone bolt (`w` 1-3) with a branch or two.
    static func zap(_ c: CGContext, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ p: FXPal, seed: UInt64, jag: Double = 3,
                    w: Int = 3, branches: Int = 1) {
        var r = KartRNG(seed: seed)
        let len = hypot(x1 - x0, y1 - y0)
        let n = max(2, Int(len / 6))
        let nx = -(y1 - y0) / max(1, len), ny = (x1 - x0) / max(1, len)
        var px0 = x0, py0 = y0
        for i in 1...n {
            let t = Double(i) / Double(n)
            let off = i == n ? 0 : (Double(r.int(201)) / 100 - 1) * jag
            let qx = x0 + (x1 - x0) * t + nx * off, qy = y0 + (y1 - y0) * t + ny * off
            if w >= 3 { seg(c, px0 - 1, py0, qx - 1, qy, p.dk); seg(c, px0 + 1, py0, qx + 1, qy, p.md) }
            if w >= 2 { seg(c, px0, py0 + 1, qx, qy + 1, p.lt) }
            seg(c, px0, py0, qx, qy, p.hi)
            if branches > 0, i == n / 2 || (branches > 1 && i == n / 3) {
                let ba = atan2(y1 - y0, x1 - x0) + (r.int(2) == 0 ? 0.8 : -0.8)
                let bl = len * 0.18
                var bx = qx, by = qy
                for _ in 0..<3 {
                    let ex = bx + cos(ba) * bl / 3 + Double(r.int(5) - 2), ey = by + sin(ba) * bl / 3 + Double(r.int(5) - 2)
                    seg(c, bx, by, ex, ey, p.lt); bx = ex; by = ey
                }
            }
            px0 = qx; py0 = qy
        }
    }

    /// A straight beam `w` px wide: dark rim, mid body, light band and a white-hot core.
    static func beam(_ c: CGContext, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ w: Double, _ p: FXPal) {
        let len = max(1, hypot(x1 - x0, y1 - y0))
        let nx = -(y1 - y0) / len, ny = (x1 - x0) / len
        let half = Int((w / 2).rounded())
        for k in stride(from: half, through: 0, by: -1) {
            let col = k == 0 ? p.hi : (k == half ? p.dk : (k == half - 1 ? p.md : p.lt))
            seg(c, x0 + nx * Double(k), y0 + ny * Double(k), x1 + nx * Double(k), y1 + ny * Double(k), col)
            if k > 0 { seg(c, x0 - nx * Double(k), y0 - ny * Double(k), x1 - nx * Double(k), y1 - ny * Double(k), col) }
        }
    }

    /// A vertical column of light from above down to (x, y).
    static func pillar(_ c: CGContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ p: FXPal, _ a: Double = 1) {
        fade(c, a * 0.35) { box(c, x - w / 2 - 1, y - h, w + 2, h, p.md) }
        fade(c, a * 0.6) { box(c, x - w / 2, y - h, w, h, p.lt) }
        fade(c, a) { box(c, x - max(1, w / 4), y - h, max(1, w / 2), h, p.hi) }
    }

    /// `n` sharp rays out of (x, y), alternating long and short.
    static func rays(_ c: CGContext, _ x: Double, _ y: Double, _ n: Int, _ len: Double, _ rot: Double, _ p: FXPal, squash: Double = 1, w: Double = 2) {
        for k in 0..<n {
            let a = rot + Double(k) / Double(n) * 2 * .pi
            let l = k % 2 == 0 ? len : len * 0.55
            spike(c, x, y, a, l, k % 2 == 0 ? p.lt : p.md, w, squash: squash)
            spike(c, x, y, a, l * 0.6, p.hi, 1, squash: squash)
        }
    }

    /// A zigzag crack in the ground from (x, y) along `a`, glowing from inside, with short side branches.
    static func crack(_ c: CGContext, _ x: Double, _ y: Double, _ a: Double, _ len: Double, _ p: FXPal, seed: UInt64, glow g: Double = 1) {
        var r = KartRNG(seed: seed)
        var cx = x, cy = y, done = 0.0
        while done < len {
            let step = 3 + Double(r.int(3))
            let ang = a + (Double(r.int(121)) / 100 - 0.6)
            let nx = cx + cos(ang) * step, ny = cy + sin(ang) * step * 0.6
            seg(c, cx, cy + 1, nx, ny + 1, p.dk)
            seg(c, cx, cy, nx, ny, g > 0.5 ? p.lt : p.md)
            if g > 0.7 { px(c, (cx + nx) / 2, (cy + ny) / 2 - 1, p.hi) }
            if r.int(4) == 0 {
                let ba = ang + (r.int(2) == 0 ? 1.1 : -1.1)
                seg(c, nx, ny, nx + cos(ba) * 3, ny + sin(ba) * 2, p.md)
            }
            cx = nx; cy = ny; done += step
        }
    }

    /// A flickering tongue of flame `h` px tall standing on (x, y).
    static func flame(_ c: CGContext, _ x: Double, _ y: Double, _ h: Double, _ w: Double, _ p: FXPal, phase: Double) {
        let rows = max(2, Int(h))
        for i in 0..<rows {
            let u = Double(i) / Double(rows)
            let half = max(0.5, w / 2 * (1 - u * u) * (u < 0.15 ? 0.7 + u * 2 : 1))
            let sway = sin(phase + u * 4) * u * 1.6
            let col = u > 0.8 ? p.dk : (u > 0.55 ? p.md : (u > 0.25 ? p.lt : p.hi))
            box(c, x + sway - half, y - Double(i), half * 2, 1, col)
            if u < 0.5, half > 2 { box(c, x + sway - half, y - Double(i), 1, 1, p.md); box(c, x + sway + half - 1, y - Double(i), 1, 1, p.md) }
        }
    }

    /// A puff of smoke or cloud: a dark lower half under a lit upper half.
    static func puff(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ light: CGColor, _ shade: CGColor) {
        ellipse(c, x + r * 0.15, y + r * 0.2, r, shade, squash: 0.8)
        ellipse(c, x - r * 0.1, y - r * 0.1, r * 0.82, light, squash: 0.8)
    }

    /// Particles flung out of (x, y) and falling back: sparks, debris, droplets. `t` 0…1 over their flight.
    static func fling(_ c: CGContext, _ x: Double, _ y: Double, _ n: Int, _ speed: Double, _ t: Double, seed: UInt64, _ cols: Tones,
                      dir: Double? = nil, spread: Double = .pi, gravity: Double = 60, size: Double = 1) {
        var r = KartRNG(seed: seed)
        for i in 0..<n {
            let a = (dir ?? -.pi / 2) + (Double(r.int(201)) / 100 - 1) * spread
            let v = speed * (0.5 + Double(r.int(51)) / 100)
            let life = 0.6 + Double(r.int(41)) / 100
            let u = t / life
            guard u < 1 else { continue }
            let tt = t * 0.5
            let qx = x + cos(a) * v * tt, qy = y + sin(a) * v * tt + gravity * tt * tt
            px(c, qx, qy, cols[i % cols.count], u < 0.5 ? size : max(1, size - 1))
        }
    }

    /// Particles rising and swaying from a disc around (x, y): embers, motes, bubbles. `t` 0…1.
    static func rise(_ c: CGContext, _ x: Double, _ y: Double, _ n: Int, _ spread: Double, _ height: Double, _ t: Double, seed: UInt64,
                     _ cols: Tones, size: Double = 1) {
        var r = KartRNG(seed: seed)
        for i in 0..<n {
            let a = Double(r.int(628)) / 100, d = spread * Double(r.int(101)) / 100
            let delay = Double(r.int(40)) / 100
            let u = (t - delay) / (1 - delay)
            guard u > 0, u < 1 else { continue }
            let qx = x + cos(a) * d + sin(u * 6 + Double(i)) * 1.5, qy = y + sin(a) * d * 0.5 - u * height
            px(c, qx, qy, cols[min(cols.count - 1, Int(u * Double(cols.count)))], u < 0.4 ? size : max(1, size - 1))
        }
    }

    /// Particles falling onto a disc around (x, y): flakes, petals, feathers. `t` 0…1.
    static func fall(_ c: CGContext, _ x: Double, _ y: Double, _ n: Int, _ spread: Double, _ height: Double, _ t: Double, seed: UInt64,
                     _ cols: Tones, sway: Double = 2) {
        var r = KartRNG(seed: seed)
        for i in 0..<n {
            let a = Double(r.int(628)) / 100, d = spread * Double(r.int(101)) / 100
            let delay = Double(r.int(50)) / 100
            let u = (t - delay) / (1 - delay)
            guard u > 0, u < 1 else { continue }
            let qx = x + cos(a) * d + sin(u * 5 + Double(i)) * sway, qy = y + sin(a) * d * 0.5 - (1 - u) * height
            px(c, qx, qy, cols[i % cols.count])
        }
    }

    /// The element's own particles sprinkled over an effect.
    static func spice(_ c: CGContext, _ x: Double, _ y: Double, _ spread: Double, _ e: RpgElement, _ t: Double, seed: UInt64, n: Int = 5) {
        let p = elemPal(e)
        switch e {
        case .fire: rise(c, x, y, n, spread, 16, t, seed: seed, Tones(p.hi, p.lt, p.md, p.dk), size: 2)
        case .ice: fall(c, x, y, n, spread, 12, t, seed: seed, Tones(p.hi, p.lt), sway: 1)
        case .thunder:
            var r = KartRNG(seed: seed &+ UInt64(truncatingIfNeeded: Int(t * 12)))
            for _ in 0..<max(1, n / 2) {
                let qx = x + Double(r.int(Int(spread * 2) + 1)) - spread, qy = y + Double(r.int(Int(spread) + 1)) - spread / 2
                seg(c, qx, qy, qx + 2, qy + 2, p.lt); seg(c, qx + 2, qy + 2, qx + 1, qy + 4, p.hi)
            }
        case .wind:
            var r = KartRNG(seed: seed)
            for i in 0..<n {
                let qx = x + Double(r.int(Int(spread * 2) + 1)) - spread + t * 14, qy = y + Double(r.int(Int(spread) + 1)) - spread / 2
                fade(c, 1 - t) { seg(c, qx, qy, qx + 4, qy - 1, i % 2 == 0 ? p.lt : p.hi) }
            }
        case .holy:
            var r = KartRNG(seed: seed)
            for i in 0..<n where (Int(t * 10) + i) % 3 != 0 {
                let qx = x + Double(r.int(Int(spread * 2) + 1)) - spread, qy = y + Double(r.int(Int(spread) + 1)) - spread / 2 - t * 6
                star(c, qx, qy, 1, p.lt, p.hi)
            }
        case .cosmic:
            var r = KartRNG(seed: seed)
            for i in 0..<n {
                let qx = x + Double(r.int(Int(spread * 2) + 1)) - spread, qy = y + Double(r.int(Int(spread) + 1)) - spread / 2
                star(c, qx, qy, (Int(t * 8) + i) % 2 + 1, i % 2 == 0 ? p.lt : p.ac, p.hi)
            }
        case .poison:
            var r = KartRNG(seed: seed)
            for i in 0..<n {
                let qx = x + Double(r.int(Int(spread * 2) + 1)) - spread, qy = y + Double(r.int(Int(spread) + 1)) - spread / 2 - t * 10
                circle(c, qx, qy, i % 2 == 0 ? 1.2 : 0.8, i % 3 == 0 ? p.ac : p.lt)
            }
        case .base: break
        }
    }

    // MARK: sprites

    private struct FXSpriteKey: Hashable { let name: String, pal: Int, flip: Bool, turn: Int }
    private static var fxSprites: [FXSpriteKey: CGImage] = [:]

    /// A small pixel sprite in four facings (right, down, up; left is right mirrored).
    struct FXSprite {
        let name: String
        let right: RpgGrid, down: RpgGrid, up: RpgGrid
        init(_ name: String, _ g: RpgGrid) {
            self.name = name
            right = g
            down = RpgArt.turned(g)
            up = RpgArt.turned(RpgArt.turned(down))
        }
    }

    /// `s` facing the nearest main direction to `dir`, centred on (x, y).
    static func glyph(_ c: CGContext, _ s: FXSprite, _ p: FXPal, _ x: Double, _ y: Double, dir: Double = 0) {
        let cx = cos(dir), cy = sin(dir)
        if abs(cx) >= abs(cy) * 0.9 { glyph(c, s.name, s.right, p, x, y, flip: cx < 0) }
        else { glyph(c, s.name, cy > 0 ? s.down : s.up, p, x, y, turn: cy > 0 ? 1 : 3) }
    }

    /// A small pixel sprite from a letter grid in a look's colours, cached: h l m d a = the palette's tones,
    /// k = outline, w = white, '.' = clear. Drawn centred on (x, y).
    static func glyph(_ c: CGContext, _ name: String, _ grid: RpgGrid, _ p: FXPal, _ x: Double, _ y: Double, flip: Bool = false, turn: Int = 0) {
        let key = FXSpriteKey(name: name, pal: p.key, flip: flip, turn: turn)
        var img = fxSprites[key]
        if img == nil {
            let w = grid.map(\.count).max() ?? 1, h = grid.count
            guard let ctx = KartArt.context(width: w, height: h) else { return }
            let tone: [Character: CGColor] = ["h": p.hi, "l": p.lt, "m": p.md, "d": p.dk, "a": p.ac, "k": outline, "w": rgb(255, 255, 255)]
            for (row, line) in grid.enumerated() {
                for (col, ch) in line.enumerated() {
                    guard let t = tone[ch] else { continue }
                    KartArt.fill(ctx, t, CGFloat(flip ? w - 1 - col : col), CGFloat(row), 1, 1)
                }
            }
            img = ctx.makeImage()
            fxSprites[key] = img
        }
        guard let img else { return }
        KartArt.draw(img, in: c, rect: CGRect(x: (x - Double(img.width) / 2).rounded(), y: (y - Double(img.height) / 2).rounded(),
                                               width: CGFloat(img.width), height: CGFloat(img.height)))
    }

    /// A grid turned a quarter clockwise (for sprites that point along the four main directions).
    nonisolated static func turned(_ g: RpgGrid) -> RpgGrid {
        let rows = g.map(Array.init), h = rows.count, w = rows.map(\.count).max() ?? 0
        return (0..<w).map { x in String((0..<h).reversed().map { y in x < rows[y].count ? rows[y][x] : "." }) }
    }
}

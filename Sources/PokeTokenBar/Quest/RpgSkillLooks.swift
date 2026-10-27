import CoreGraphics

// SPIKE: the signature looks of `RpgArt.looks` — one per basic attack and per skill, themed on the skill's name and
// description. Every look keeps its own palette, silhouette and motion; the weapon's element still colours basic attacks
// and sprinkles its particles over skills. Painters see one effect at a time (`FXF`) and know which part of the cast it is
// from its kind and `seq`.

extension RpgArt {
    // MARK: shared colours

    static let woodPal = FXPal(0xE0B070, 0xB07A44, 0x8A5A30, 0x5A3818, 0xFFFFFF)
    static let smokePal = FXPal(0xF4F4F4, 0xD0D0D4, 0xA0A0A8, 0x60606C, 0xFFFFFF)
    static let rogueSteel = FXPal(0xFFFFFF, 0xE0E6F0, 0xA0A8BC, 0x50566A, 0xE8304A)
    static let monkKi = FXPal(0xFFFBE0, 0xFFD87A, 0xF0963A, 0x9A4A1A, 0xFFF4C0)
    static let ghostFire = FXPal(0xF0FFFF, 0x8CF0FF, 0x7A6CFF, 0x3A2A8A, 0xC8A0FF)
    static let brassPal = FXPal(0xFFF6C8, 0xFFD25A, 0xC8962A, 0x6A4A14, 0xFF8A3A)
    static let holyGold = FXPal(0xFFFFFF, 0xFFF4B0, 0xF4C850, 0xA87820, 0xFFFFE0)

    /// The weapon's colours, or the class's own when the weapon has no element.
    static func weaponPal(_ e: RpgElement, base: FXPal) -> FXPal { e == .base ? base : elemPal(e) }

    static let fistSprite = FXSprite("fist", [
        ".kkkk..",
        "klllhk.",
        "kllllhk",
        "kmllllk",
        "kmmmlk.",
        ".kkkk..",
    ])

    // MARK: basic attacks

    static let basicLooks: [String: FXLook] = [
        "basic:warrior": FXLook(pal: elemPal(.base), draw: withProc(warriorSwing), hit: warriorCut),
        "basic:archer": FXLook(pal: elemPal(.base), draw: withProc(nil), hit: archerPin, shot: archerArrow),
        "basic:mage": FXLook(pal: elemPal(.cosmic), draw: withProc(mageOrbBlast), hit: mageSpark, shot: mageOrb),
        "basic:rogue": FXLook(pal: rogueSteel, draw: withProc(rogueTwin), hit: rogueNick),
        "basic:cleric": FXLook(pal: holyGold, draw: withProc(nil), hit: clericCross, shot: clericBall),
        "basic:monk": FXLook(pal: monkKi, draw: withProc(monkPunch), hit: monkImpact),
        "basic:summoner": FXLook(pal: ghostFire, draw: withProc(nil), hit: summonerFlare, shot: summonerWisp),
        "basic:mechanic": FXLook(pal: brassPal, draw: withProc(mechanicMuzzle), hit: mechanicPing, shot: mechanicBullet),
    ]

    /// A basic attack's painter that also draws the cosmic weapon's meteor proc (`RpgWorld.damageMob`).
    private static func withProc(_ draw: FXPaint?) -> FXPaint {
        { c, f in
            if case .meteor(let r) = f.kind { return starProc(c, f, r) }
            return draw?(c, f) ?? false
        }
    }

    /// A little star drops out of the sky onto the struck monster and bursts.
    private static func starProc(_ c: CGContext, _ f: FXF, _ r: Double) -> Bool {
        let p = elemPal(.cosmic)
        if f.t < 0.3 {
            let u = easeIn(f.t / 0.3), hx = f.x + 16 * (1 - u), hy = f.y - 50 * (1 - u)
            for k in 0..<6 { fade(c, 1 - Double(k) / 6) { px(c, hx + Double(k) * 1.2, hy - Double(k) * 3.5, k < 2 ? p.hi : p.lt) } }
            star(c, hx, hy, 2, p.ac, p.hi)
            return true
        }
        let u = easeOut(win(f.t, 0.3, 1))
        fade(c, 1 - u) {
            pentagram(c, f.x, f.y - 4, 4 + r * 0.5 * u, u * 2, p.lt)
            circle(c, f.x, f.y, r * u, p.md, squash: 0.5)
        }
        return true
    }

    /// Broad crescent, always swung top to bottom, sparks thrown off the tip.
    private static func warriorSwing(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, let rad) = f.kind else { return false }
        let p = elemPal(f.el)
        let s: Double = cos(ang) < -0.01 ? -1 : 1
        let a0 = ang - 1.8 * s, a1 = ang + 1.5 * s
        let head = easeOut(win(f.t, 0, 0.42)), tail = win(f.t, 0.18, 0.92)
        let from = a0 + (a1 - a0) * tail, to = a0 + (a1 - a0) * head
        let r = rad + 4
        if abs(to - from) > 0.08 {
            fade(c, 0.25 * (1 - f.t)) { wedge(c, f.x, f.y, 3, r, from, to, p.lt, squash: 0.8) }
            fade(c, 0.4) { crescent(c, f.x, f.y, r + 5, from, to - 0.15 * s, 2, p, squash: 0.8) }
            crescent(c, f.x, f.y, r, from, to, 8, p, squash: 0.8, rim: p.dk)
        }
        let tx = f.x + cos(to) * (r + 3), ty = f.y + sin(to) * (r + 3) * 0.8
        if f.t > 0.1, f.t < 0.85 {
            fling(c, tx, ty, 7, 55, win(f.t, 0.1, 0.85), seed: f.seed, Tones(p.hi, p.lt, p.ac), dir: to + .pi / 2 * s, spread: 0.6, gravity: 90, size: 2)
        }
        if f.t > 0.36, f.t < 0.62 { star(c, tx, ty, 4, p.lt, p.hi) }
        spice(c, f.x + cos(ang) * r, f.y + sin(ang) * r * 0.8, 8, f.el, f.t, seed: f.seed)
        return true
    }

    /// A bright cut across the target; crits ring and spray.
    private static func warriorCut(_ c: CGContext, _ f: FXF) -> Bool {
        let p = elemPal(f.el)
        let k = punch(f.t, at: 0.15, hold: 0.2)
        let len = f.crit ? 8.0 : 5.0
        let a = f.dir + .pi / 2 + 0.6
        let dx = cos(a) * len, dy = sin(a) * len
        fade(c, k) {
            seg(c, f.x - dx, f.y - dy, f.x + dx, f.y + dy, p.lt, f.crit ? 3 : 2)
            seg(c, f.x - dx, f.y - dy, f.x + dx, f.y + dy, p.hi)
        }
        fling(c, f.x, f.y, f.crit ? 10 : 5, f.crit ? 70 : 45, f.t, seed: f.seed, Tones(p.hi, p.lt, p.ac), dir: f.dir, spread: 1.2, gravity: 80)
        if f.crit {
            fade(c, 1 - f.t) { shock(c, f.x, f.y, 3 + f.t * 14, 2, p, squash: 0.8) }
            if f.t < 0.5 { star(c, f.x, f.y, 5, p.md, p.hi) }
        }
        return true
    }

    /// Fletched arrow with a fading motion streak.
    private static func archerArrow(_ c: CGContext, _ s: ShotF) {
        let p = elemPal(s.el), w = woodPal
        let x = s.x, y = s.y, ux = s.ux, uy = s.uy, nx = -uy, ny = ux
        for k in 0..<10 { fade(c, 0.7 - Double(k) * 0.065) { px(c, x - ux * (12 + Double(k) * 1.6), y - uy * (12 + Double(k) * 1.6), k < 4 ? p.hi : p.lt) } }
        seg(c, x - ux * 11 + ny * 0.5, y - uy * 11, x - ux * 2, y - uy * 2, w.dk)
        seg(c, x - ux * 11, y - uy * 11, x - ux * 2, y - uy * 2, w.lt)
        px(c, x + ux, y + uy, p.hi); px(c, x, y, p.hi); px(c, x - ux, y - uy, p.lt)
        px(c, x - ux * 1.5 + nx, y - uy * 1.5 + ny, p.md); px(c, x - ux * 1.5 - nx, y - uy * 1.5 - ny, p.md)
        for k in 0..<3 {
            let bx = x - ux * Double(9 + k), by = y - uy * Double(9 + k)
            px(c, bx + nx * 1.4, by + ny * 1.4, k == 0 ? w.hi : (k == 1 ? p.lt : p.md)); px(c, bx - nx * 1.4, by - ny * 1.4, k == 0 ? w.hi : (k == 1 ? p.lt : p.md))
        }
        if s.el != .base { spice(c, x - ux * 6, y - uy * 6, 3, s.el, (s.now * 2).truncatingRemainder(dividingBy: 1), seed: s.seed, n: 2) }
    }

    /// The arrow stays pinned in the target, quivering, pointing back at the archer.
    private static func archerPin(_ c: CGContext, _ f: FXF) -> Bool {
        let p = elemPal(f.el), w = woodPal
        let a = f.dir + .pi
        let q = sin(f.age * 70) * (1 - f.t) * 1.2
        let nx = -sin(a), ny = cos(a)
        let ex = f.x + cos(a) * 7 + nx * q, ey = f.y + sin(a) * 7 + ny * q
        fade(c, 1 - win(f.t, 0.7, 1)) {
            seg(c, f.x, f.y, ex, ey, w.md)
            px(c, ex + nx, ey + ny, w.hi); px(c, ex - nx, ey - ny, w.hi)
            px(c, f.x - cos(a), f.y - sin(a), p.hi)
        }
        if f.t < 0.4 {
            let u = f.t / 0.4
            fade(c, 1 - u) { circle(c, f.x, f.y, 2 + u * (f.crit ? 12 : 7), p.lt, squash: 0.7) }
            star(c, f.x, f.y, f.crit ? 4 : 2, p.md, p.hi)
        }
        if f.crit { fling(c, f.x, f.y, 8, 60, f.t, seed: f.seed, Tones(p.hi, p.lt), dir: f.dir, spread: 0.8) }
        return true
    }

    /// Runic orb: glowing core, circling rune motes and a twinkling trail.
    private static func mageOrb(_ c: CGContext, _ s: ShotF) {
        let p = elemPal(s.el == .base ? .cosmic : s.el)
        var r = KartRNG(seed: s.seed)
        for k in 0..<7 {
            let d = 4 + Double(k) * 2.6, j = Double(r.int(5)) - 2
            guard (Int(s.now * 24) + k) % 3 != 0 else { continue }
            let tx = s.x - s.ux * d - s.uy * j, ty = s.y - s.uy * d + s.ux * j
            if k % 3 == 0 { star(c, tx, ty, 1, p.lt, p.hi) } else { px(c, tx, ty, k < 3 ? p.lt : p.md) }
        }
        glow(c, s.x, s.y, 8, p.lt, 1)
        glyph(c, "orb", orbGrid, p, s.x, s.y)
        for k in 0..<3 {
            let a = s.now * 9 + Double(k) * 2.094
            px(c, s.x + cos(a) * 5.5, s.y + sin(a) * 3.5, sin(a) > 0 ? p.hi : p.ac, 2)
        }
    }

    static let orbGrid: RpgGrid = [".mmm.", "mllhm", "mlhhl", "mlllm", ".mmm."]

    /// The orb bursts in its element's shape.
    private static func mageSpark(_ c: CGContext, _ f: FXF) -> Bool {
        let e = f.el == .base ? RpgElement.cosmic : f.el
        let p = elemPal(e)
        let u = easeOut(f.t), s = f.crit ? 1.5 : 1.0
        fade(c, 1 - win(f.t, 0.5, 1)) {
            switch e {
            case .fire:
                glow(c, f.x, f.y, 8 * s * u, p.lt)
                for i in 0..<6 { spike(c, f.x, f.y, Double(i) * 1.047 + 0.3, 7 * s * u, i % 2 == 0 ? p.lt : p.md, 2) }
            case .ice:
                for i in 0..<4 { spike(c, f.x, f.y, Double(i) * .pi / 2 + .pi / 4, 7 * s * u, p.lt, 2) }
                circle(c, f.x, f.y, 3 + 6 * u * s, p.hi, squash: 0.7)
            case .thunder:
                for i in 0..<3 {
                    let a = Double(i) * 2.1 + f.age * 20
                    zap(c, f.x, f.y, f.x + cos(a) * 9 * s, f.y + sin(a) * 7 * s, p, seed: f.seed &+ UInt64(i), jag: 2, w: 1, branches: 0)
                }
            case .wind:
                circle(c, f.x, f.y, 3 + 7 * u, p.lt, squash: 0.6, from: f.age * 14, to: f.age * 14 + 4)
                circle(c, f.x, f.y, 2 + 4 * u, p.hi, squash: 0.6, from: f.age * 14 + 3, to: f.age * 14 + 6)
            case .holy:
                seg(c, f.x, f.y - 7 * u * s, f.x, f.y + 5 * u * s, p.hi, 2)
                seg(c, f.x - 5 * u * s, f.y - 2, f.x + 5 * u * s, f.y - 2, p.hi, 2)
            case .poison:
                for i in 0..<5 { circle(c, f.x + cos(Double(i) * 1.3) * 6 * u, f.y + sin(Double(i) * 1.3) * 4 * u - f.t * 4, 1.3, i % 2 == 0 ? p.lt : p.ac) }
            default:
                star(c, f.x, f.y, Int(3 + 3 * u * s), p.lt, p.hi)
                circle(c, f.x, f.y, 2 + 8 * u * s, p.md, squash: 0.6, dash: 2)
            }
            star(c, f.x, f.y, f.crit ? 4 : 2, p.md, p.hi)
        }
        return true
    }

    /// A fire orb going off: rune ring, flash and embers.
    private static func mageOrbBlast(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = elemPal(.fire), u = easeOut(f.t)
        fade(c, 1 - f.t) {
            circle(c, f.x, f.y, f.r * (0.6 + 0.4 * u), p.ac, squash: 0.5, dash: 3)
            glow(c, f.x, f.y, f.r * u, p.lt)
            shock(c, f.x, f.y, f.r * u, 2, p, squash: 0.6)
        }
        rise(c, f.x, f.y, 8, f.r * 0.5, 14, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md, p.dk), size: 2)
        return true
    }

    /// Two quick crossing cuts with after-images, then a stab flash.
    private static func rogueTwin(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, let rad) = f.kind else { return false }
        let p = weaponPal(f.el, base: rogueSteel)
        let s: Double = cos(ang) < -0.01 ? -1 : 1
        let cx = f.x + cos(ang) * 5, cy = f.y + sin(ang) * 4
        let bx = cos(ang) * 4, by = sin(ang) * 4
        func cut(_ a0: Double, _ a1: Double, _ h: Double, _ t: Double, _ r: Double) {
            guard h > t + 0.02 else { return }
            let from = a0 + (a1 - a0) * t, to = a0 + (a1 - a0) * h
            fade(c, 0.3) { crescent(c, cx - bx, cy - by, r, from, to, 3, p, squash: 0.75) }
            fade(c, 0.55) { crescent(c, cx - bx / 2, cy - by / 2, r, from, to, 3, p, squash: 0.75) }
            crescent(c, cx, cy, r, from, to, 4, p, squash: 0.75, rim: p.dk)
        }
        cut(ang - 1.4 * s, ang + 1.0 * s, easeOut(win(f.t, 0, 0.35)), win(f.t, 0.15, 0.6), rad + 2)
        cut(ang + 1.2 * s, ang - 0.9 * s, easeOut(win(f.t, 0.22, 0.55)), win(f.t, 0.35, 0.8), rad)
        if f.t > 0.45 {
            let u = win(f.t, 0.45, 1), len = 8 + 10 * easeOut(u)
            fade(c, 1 - u * u) {
                seg(c, cx, cy, cx + cos(ang) * len, cy + sin(ang) * len, p.lt, 2)
                seg(c, cx, cy, cx + cos(ang) * len, cy + sin(ang) * len, p.hi)
                star(c, cx + cos(ang) * len, cy + sin(ang) * len, 4, p.ac, p.hi)
            }
        }
        return true
    }

    private static func rogueNick(_ c: CGContext, _ f: FXF) -> Bool {
        let p = weaponPal(f.el, base: rogueSteel)
        let l = f.crit ? 7.0 : 4.0
        fade(c, punch(f.t, at: 0.1, hold: 0.15)) {
            seg(c, f.x - l, f.y - l * 0.6, f.x + l, f.y + l * 0.6, p.hi)
            seg(c, f.x - l, f.y + l * 0.6, f.x + l, f.y - l * 0.6, p.lt)
        }
        if f.crit {
            fade(c, 1 - f.t) { circle(c, f.x, f.y, 4 + f.t * 10, p.ac, squash: 0.8) }
            fling(c, f.x, f.y, 6, 40, f.t, seed: f.seed, Tones(p.ac, rogueSteel.ac), dir: f.dir, spread: 1, gravity: 120)
        }
        return true
    }

    /// Radiant ball with a halo and slowly turning cross rays.
    private static func clericBall(_ c: CGContext, _ s: ShotF) {
        let p = weaponPal(s.el == .holy ? .base : s.el, base: holyGold)
        for k in 1...4 where (Int(s.now * 20) + k) % 2 == 0 { star(c, s.x - s.ux * Double(k) * 3.5, s.y - s.uy * Double(k) * 3.5, 1, p.lt, p.hi) }
        glow(c, s.x, s.y, 7, p.lt, 0.8)
        circle(c, s.x, s.y - 1, 5, p.md, squash: 0.4)
        let rot = s.now * 3
        for k in 0..<4 { spike(c, s.x, s.y, rot + Double(k) * .pi / 2, 6, p.lt, 1) }
        ellipse(c, s.x, s.y, 3, p.md); ellipse(c, s.x, s.y, 2, p.lt); px(c, s.x, s.y, p.hi)
    }

    /// A cross of light where it lands.
    private static func clericCross(_ c: CGContext, _ f: FXF) -> Bool {
        let p = weaponPal(f.el == .holy ? .base : f.el, base: holyGold)
        let u = easeOut(win(f.t, 0, 0.35)), s = f.crit ? 1.5 : 1.0
        fade(c, 1 - win(f.t, 0.45, 1)) {
            let v = 9 * u * s, h = 6 * u * s
            box(c, f.x - 1, f.y - v, 3, v * 1.6, p.lt); box(c, f.x - h, f.y - v * 0.35 - 1, h * 2 + 1, 3, p.lt)
            box(c, f.x, f.y - v, 1, v * 1.6, p.hi); box(c, f.x - h, f.y - v * 0.35, h * 2 + 1, 1, p.hi)
            circle(c, f.x, f.y - 2, 3 + 7 * u * s, p.md, squash: 0.7)
            if f.crit { rays(c, f.x, f.y - 2, 8, 12 * u, .pi / 8, p) }
        }
        return true
    }

    /// Each of the three punches: a fist thrust with a ki ring and shock lines; the third lands harder.
    private static func monkPunch(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, _) = f.kind else { return false }
        let p = weaponPal(f.el, base: monkKi)
        let d = f.dir, big = f.seq >= 2
        let ext = easeOut(win(f.t, 0, 0.3))
        let side = (ang - d) * 7
        let hx = f.x + cos(d) * (-8 + 9 * ext) - sin(d) * side * 0.4, hy = f.y - 7 + sin(d) * (-8 + 9 * ext) + side * 0.5
        let k = 1 - win(f.t, 0.6, 1)
        fade(c, k * 0.5) { for i in 1...3 { seg(c, hx - cos(d) * Double(2 + i * 2), hy - sin(d) * Double(2 + i * 2) + Double(i - 2), hx - cos(d) * Double(5 + i * 2), hy - sin(d) * Double(5 + i * 2) + Double(i - 2), p.lt) } }
        fade(c, k) { glyph(c, fistSprite, p, hx, hy, dir: d) }
        if f.t > 0.2 {
            let u = easeOut(win(f.t, 0.2, 0.8))
            let fx = hx + cos(d) * 4, fy = hy + sin(d) * 4
            fade(c, 1 - u) {
                oval(c, fx, fy, 1.5 + u * 2, (4 + u * 6) * (big ? 1.5 : 1), d, p.hi)
                if big { oval(c, fx - cos(d) * 3, fy - sin(d) * 3, 1 + u, 3 + u * 4, d, p.lt) }
                for i in 0..<3 { let a = d + (Double(i) - 1) * 0.55; spike(c, fx + cos(a) * (3 + u * 4), fy + sin(a) * (3 + u * 4), a, 3 + u * (big ? 6 : 4), p.lt, 1) }
            }
        }
        return true
    }

    private static func monkImpact(_ c: CGContext, _ f: FXF) -> Bool {
        let p = weaponPal(f.el, base: monkKi)
        let u = easeOut(win(f.t, 0, 0.4)), s = f.crit ? 1.6 : 1.0
        fade(c, 1 - win(f.t, 0.4, 1)) {
            for i in 0..<5 { let a = f.dir + (Double(i) - 2) * 0.45; spike(c, f.x + cos(a) * 3 * u, f.y + sin(a) * 3 * u, a, (4 + 5 * u) * s, p.lt, 1) }
            oval(c, f.x, f.y, 2 + 2 * u, (4 + 6 * u) * s, f.dir, p.hi)
            if f.crit { star(c, f.x, f.y, 4, p.md, p.hi); circle(c, f.x, f.y, 6 + 10 * u, p.md, squash: 0.7) }
        }
        return true
    }

    /// A ghost-fire wisp weaving along a spiral, its flames trailing behind.
    private static func summonerWisp(_ c: CGContext, _ s: ShotF) {
        let p = weaponPal(s.el == .cosmic ? .base : s.el, base: ghostFire)
        let nx = -s.uy, ny = s.ux
        let ph = s.now * 11 + Double(s.seed % 7)
        for k in stride(from: 9, through: 1, by: -1) {
            let back = Double(k) * 2.6, w = sin(ph - Double(k) * 0.7) * 4
            let qx = s.x - s.ux * back + nx * w, qy = s.y - s.uy * back + ny * w - Double(k) * 0.4
            fade(c, 1 - Double(k) * 0.08) { px(c, qx, qy, k > 6 ? p.dk : (k > 3 ? p.md : p.lt), k < 4 ? 2 : 1) }
        }
        let w = sin(ph) * 4
        let hx = s.x + nx * w, hy = s.y + ny * w
        glow(c, hx, hy, 8, p.lt, 0.8)
        // A flame-shaped head licking upward, with two dark eyes.
        let lick = Double(Int(s.now * 16) % 3)
        flame(c, hx, hy + 3, 8 + lick, 7, p, phase: s.now * 22)
        px(c, hx - 1.5, hy, p.dk); px(c, hx + 1.5, hy, p.dk)
    }

    private static func summonerFlare(_ c: CGContext, _ f: FXF) -> Bool {
        let p = weaponPal(f.el == .cosmic ? .base : f.el, base: ghostFire)
        let u = easeOut(f.t), s = f.crit ? 1.4 : 1.0
        fade(c, 1 - win(f.t, 0.5, 1)) {
            circle(c, f.x, f.y, 2 + 7 * u * s, p.lt, squash: 0.6)
            for i in 0..<4 { flame(c, f.x - 4 + Double(i) * 2.7, f.y + 2, (5 + Double(i % 2) * 3) * (1 - f.t * 0.6) * s, 3, p, phase: f.age * 30 + Double(i)) }
        }
        rise(c, f.x, f.y, 4, 4, 12, f.t, seed: f.seed, Tones(p.lt, p.md, p.dk))
        return true
    }

    /// A bright slug with a tracer behind it.
    private static func mechanicBullet(_ c: CGContext, _ s: ShotF) {
        let p = weaponPal(s.el, base: brassPal)
        for k in 0..<14 { fade(c, 0.9 - Double(k) * 0.06) { px(c, s.x - s.ux * Double(k + 2), s.y - s.uy * Double(k + 2), k < 4 ? p.hi : (k < 8 ? p.lt : p.md)) } }
        seg(c, s.x - s.ux * 2, s.y - s.uy * 2, s.x + s.ux, s.y + s.uy, p.hi, 2)
        px(c, s.x + s.ux * 2, s.y + s.uy * 2, p.lt)
    }

    /// Muzzle flash, a puff of smoke and two shell casings bouncing on the floor.
    private static func mechanicMuzzle(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = weaponPal(f.el, base: brassPal)
        if f.t < 0.25 {
            let u = f.t / 0.25
            fade(c, 1 - u) {
                glow(c, f.x, f.y, 6, p.lt)
                spike(c, f.x, f.y, f.dir, 7, p.lt, 3); spike(c, f.x, f.y, f.dir - 0.7, 4, p.md, 2); spike(c, f.x, f.y, f.dir + 0.7, 4, p.md, 2)
                star(c, f.x, f.y, 2, p.lt, p.hi)
            }
        }
        fade(c, 0.5 * (1 - f.t)) { puff(c, f.x + cos(f.dir) * 3, f.y - f.t * 6, 2 + f.t * 3, smokePal.lt, smokePal.md) }
        let back: Double = cos(f.dir) >= 0 ? -1 : 1
        for k in 0..<2 {
            let t = f.age - Double(k) * 0.07
            guard t > 0 else { continue }
            let floor = f.y + 7 + Double(k)
            var y = f.y - 2 - 70 * t + 260 * t * t
            if y > floor { y = floor - abs(sin(t * 16)) * 2 }
            let x = f.x - cos(f.dir) * 6 + back * (34 + Double(k) * 10) * t
            box(c, x, y, 2, 1, brassPal.md); px(c, x + (Int(t * 30) % 2 == 0 ? 0 : 1), y, brassPal.hi)
        }
        return true
    }

    private static func mechanicPing(_ c: CGContext, _ f: FXF) -> Bool {
        let p = weaponPal(f.el, base: brassPal)
        if f.t < 0.35 { star(c, f.x, f.y, f.crit ? 4 : 2, p.md, p.hi) }
        fling(c, f.x, f.y, f.crit ? 8 : 4, f.crit ? 60 : 40, f.t, seed: f.seed, Tones(p.hi, p.lt), dir: f.dir + .pi, spread: 0.9, gravity: 90)
        if f.crit { fade(c, 1 - f.t) { circle(c, f.x, f.y, 3 + f.t * 10, p.lt) } }
        return true
    }
}

// MARK: - warrior

extension RpgArt {
    static let dustPal = FXPal(0xFFF8E8, 0xE8D8B8, 0xC0A880, 0x7A6448, 0xFFFFFF)
    static let steelPal = FXPal(0xFFFFFF, 0xCFE6FF, 0x7FA8D8, 0x34507A, 0xFFD27A)
    static let rushPal = FXPal(0xFFFFFF, 0xFFE2B0, 0xE89A50, 0x6A3A1A, 0xFFF0C0)
    static let earthPal = FXPal(0xFFF2C0, 0xFFB050, 0xC8682A, 0x4A2E1E, 0x8A7A6A)
    static let ragePal = FXPal(0xFFF0E0, 0xFF8A6A, 0xE02828, 0x701010, 0xFFC040)
    static let ironPal = FXPal(0xFFFFFF, 0xE4ECF4, 0xA8B4C4, 0x5A6678, 0x9ED4FF)
    static let galePal = FXPal(0xFFFFFF, 0xD0F4FF, 0x8CC8E0, 0x3C6C88, 0xE8FFFF)
    static let slamPal = FXPal(0xFFFFFF, 0xFFE68A, 0xE8A23A, 0x6A4A2A, 0xFFF4C8)
    static let stormPal = FXPal(0xFFFFFF, 0xFFF59A, 0xF0C83C, 0x6A3AC8, 0xB49CFF)
    static let knightPal = FXPal(0xFFFFFF, 0xBCD8FF, 0x4A7AE0, 0x1E3A8A, 0xFFD24A)
    static let sanctumPal = FXPal(0xFFFFFF, 0xFFF0B0, 0xE8C050, 0x4A6AB0, 0x9ED0FF)
    static let bloodPal = FXPal(0xFFE0E0, 0xFF5A5A, 0xC01828, 0x4A0410, 0x200008)
    static let berserkPal = FXPal(0xFFD0C0, 0xFF4A3A, 0xA01020, 0x300610, 0xFFE040)
    static let skysplitPal = FXPal(0xFFFFFF, 0xFFF6C0, 0xF2CC5A, 0x7A5A20, 0xFFFFFF)
    static let phalanxPal = FXPal(0xFFFFFF, 0xD8E4F4, 0x8CA0C0, 0x3A4A6A, 0xFFD24A)
    static let divineSwordPal = FXPal(0xFFFFFF, 0xE8F4FF, 0x9CC8FF, 0x3A5AA0, 0xFFE070)
    static let willPal = FXPal(0xFFFFF0, 0xFFD870, 0xF08A30, 0x8A2A10, 0xFFFFFF)
    static let crushPal = FXPal(0xFFF0B0, 0xFF9A30, 0xD04A18, 0x3A2420, 0x7A6A5A)
    static let thirstPal = FXPal(0xFFC8D8, 0xE0386A, 0x9A0A3A, 0x3A0418, 0x7A2AA0)
    static let slaughterPal = FXPal(0xFFFFFF, 0xFF7070, 0xB01A2A, 0x2A0A10, 0xC8C8D8)
    static let madKingPal = FXPal(0xFFF8E0, 0xFFD24A, 0xA03AC8, 0x3A0A5A, 0xFF4AA0)

    static let angerGrid: RpgGrid = [".m.m.", "mm.mm", ".....", "mm.mm", ".m.m."]
    static let kiteGrid: RpgGrid = [
        "kkkkkkkkk", "khhlalmmk", "khllallmk", "kaaaaaaak", "klllallmk", "klllalmmk",
        ".kllammk.", ".kmlamdk.", "..kmadk..", "...kdk...", "....k....",
    ]
    static let towerGrid: RpgGrid = [
        "kkkkkkk", "khllmmk", "klllmmk", "klaaamk", "klamamk", "klaaamk", "klllmmk", "klllmmk", "klllmdk", "kmmmddk", "kkkkkkk",
    ]
    static let swordGrid: RpgGrid = [
        "...k...", "..kak..", "...k...", "..kdk..", "..kdk..", "kkkakkk", "kaaaaak", "kkhlmkk", ".khlmk.", ".khlmk.",
        ".khlmk.", ".khlmk.", ".khlmk.", ".khlmk.", ".khlmk.", ".khlmk.", "..hlm..", "..khk..", "...h...",
    ]
    static let crownGrid: RpgGrid = ["k.k.k.k", "kakakak", "kaaaaak", "kahamak", "kkkkkkk"]

    static let warriorLooks: [String: FXLook] = [
        "w_whirl": FXLook(pal: steelPal, draw: whirl),
        "w_dash": FXLook(pal: rushPal, draw: rushDash),
        "w_quake": FXLook(pal: earthPal, draw: quake, floor: quakeCrack),
        "w_rage": FXLook(pal: ragePal, draw: rage),
        "w_iron": FXLook(pal: ironPal, draw: ironWall),
        "w_cyclone": FXLook(pal: galePal, draw: { c, f in cyclone(c, f, galePal, blood: false) }),
        "w_slam": FXLook(pal: slamPal, draw: slam, floor: slamCracks),
        "w_ult": FXLook(pal: stormPal, draw: thunderFall, floor: scorch),
        "j_bash": FXLook(pal: knightPal, draw: shieldBash),
        "j_aegis": FXLook(pal: sanctumPal, draw: aegis, floor: aegisSigil),
        "j_bloodslash": FXLook(pal: bloodPal, draw: bloodClaw),
        "j_frenzy": FXLook(pal: berserkPal, draw: frenzy),
        "t2_wa1a": FXLook(pal: skysplitPal, draw: skySplit, floor: skySplitLine),
        "t2_wa1b": FXLook(pal: phalanxPal, draw: phalanx),
        "t3_wa1a": FXLook(pal: divineSwordPal, draw: divineSword, floor: divineSwordMark),
        "t3_wa1b": FXLook(pal: willPal, draw: unbowed),
        "t2_wa2a": FXLook(pal: crushPal, draw: crushStomp, floor: crater),
        "t2_wa2b": FXLook(pal: thirstPal, draw: bloodlust),
        "t3_wa2a": FXLook(pal: slaughterPal, draw: slaughterStorm),
        "t3_wa2b": FXLook(pal: madKingPal, draw: madRoar),
    ]

    /// 회전베기: two blades spinning a full circle and a half around the warrior, wind curling off.
    private static func whirl(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let rad) = f.kind else { return true }
        let p = steelPal
        let spin = easeOut(f.t) * 2.8 * .pi
        let r = rad * (0.55 + 0.3 * easeOut(f.t))
        let k = 1 - win(f.t, 0.7, 1)
        fade(c, 0.35 * k) { circle(c, f.x, f.y, r + 3, p.lt, squash: 0.5, dash: 3) }
        fade(c, 0.25 * k) { wedge(c, f.x, f.y, r * 0.4, r, f.dir + spin - 1.6, f.dir + spin, p.lt, squash: 0.5) }
        fade(c, k) {
            for b in 0..<2 {
                let a = f.dir + spin + Double(b) * .pi
                crescent(c, f.x, f.y, r, a - 2.3, a, 6, p, squash: 0.5, rim: p.dk)
            }
            for i in 0..<5 {
                let a = f.dir + spin * 0.85 + Double(i) * 1.26
                circle(c, f.x, f.y, r + 6 + Double(i % 2) * 3, p.hi, squash: 0.5, from: a, to: a + 0.45)
            }
        }
        fling(c, f.x, f.y, 10, 70, f.t, seed: f.seed, Tones(p.hi, p.ac, p.lt), spread: .pi, gravity: 40)
        spice(c, f.x, f.y, r, f.el, f.t, seed: f.seed, n: 6)
        return true
    }

    /// 돌진베기: dust kicked up along the charge, skid marks, and a ram shockwave where it ends.
    private static func rushDash(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = rushPal, d = dustPal
        let ex = f.x, ey = f.y + 6
        let len = max(1, hypot(ex - f.ox, ey - f.oy))
        let run = min(1, f.age * 420 / len)
        let ux = cos(f.dir), uy = sin(f.dir)
        let n = max(1, Int(len / 8))
        for i in 0...n {
            let u = Double(i) / Double(n)
            guard u <= run else { break }
            let age = f.age - u * len / 420, a = 1 - min(1, age / 0.45)
            guard a > 0 else { continue }
            fade(c, a * 0.85) { puff(c, f.ox + ux * len * u - ux * age * 12, f.oy + uy * len * u - 2 - age * 9, 2 + age * 7, d.lt, d.md) }
        }
        fade(c, 0.7 * (1 - f.t)) {
            let hx = f.ox + ux * len * run, hy = f.oy + uy * len * run
            seg(c, f.ox - uy * 3, f.oy + ux * 2, hx - uy * 3, hy + ux * 2, d.dk)
            seg(c, f.ox + uy * 3, f.oy - ux * 2, hx + uy * 3, hy - ux * 2, d.dk)
        }
        if run >= 1 {
            let u = win(f.age, len / 420, f.dur)
            let rx = ex + ux * 6, ry = ey - 7 + uy * 6
            fade(c, 1 - u) {
                for k in 0..<3 {
                    let q = easeOut(u) * 16 + Double(k) * 4
                    oval(c, rx + ux * q, ry + uy * q, 2 + Double(k), 7 + q * 0.6, f.dir, k == 0 ? p.hi : (k == 1 ? p.lt : p.md), from: -1.3, to: 1.3)
                }
                star(c, rx, ry, Int(5 * (1 - u)) + 1, p.ac, p.hi)
            }
            fling(c, rx, ry, 6, 60, u, seed: f.seed, Tones(p.hi, p.ac), dir: f.dir, spread: 0.8, gravity: 80)
        }
        return true
    }

    /// 대지 가르기: each step of the wave cracks the ground (drawn under the units) and throws up rocks.
    private static func quakeCrack(_ c: CGContext, _ f: FXF) -> Bool {
        let p = earthPal, ux = cos(f.dir), uy = sin(f.dir)
        let g = 1 - win(f.t, 0.35, 1)
        fade(c, 1 - win(f.t, 0.75, 1)) {
            crack(c, f.x - ux * 10, f.y - uy * 6, f.dir, 20, p, seed: f.seed, glow: g)
            crack(c, f.x, f.y, f.dir + (f.seq % 2 == 0 ? 1 : -1), 7, p, seed: f.seed &+ 9, glow: g * 0.6)
        }
        return true
    }

    private static func quake(_ c: CGContext, _ f: FXF) -> Bool {
        let p = earthPal
        fade(c, 0.6 * (1 - f.t)) { glow(c, f.x, f.y - 2, 10, p.lt, 1, squash: 0.5) }
        fling(c, f.x, f.y, 6, 80, f.t, seed: f.seed, Tones(p.ac, p.dk, p.md), spread: 0.45, gravity: 240, size: 2)
        fade(c, 0.7 * (1 - f.t)) { puff(c, f.x, f.y - 3 - f.t * 7, 3 + f.t * 5, dustPal.lt, dustPal.md) }
        return true
    }

    /// 분노: a red outburst ring, flames licking up around the body and an anger mark over the head.
    private static func rage(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = ragePal, k = 1 - win(f.t, 0.7, 1)
        if f.t < 0.35 { let u = f.t / 0.35; fade(c, 1 - u) { shock(c, f.x, f.y - 2, 4 + u * 28, 3, p, squash: 0.45) } }
        fade(c, k * 0.85) {
            for i in 0..<7 {
                let a = Double(i) / 7 * 2 * .pi + f.age * 3
                let h = 8 + 3 * sin(f.age * 9 + Double(i)) + 5 * punch(f.t, at: 0.2, hold: 0.3)
                flame(c, f.x + cos(a) * 9, f.y + sin(a) * 3.5, h, 4, p, phase: f.age * 25 + Double(i) * 1.7)
            }
        }
        if f.t > 0.1, f.t < 0.75 { glyph(c, "anger", angerGrid, p, f.x + 7, f.y - 28 - win(f.t, 0.1, 0.25) * 3 + sin(f.age * 30) * 0.6) }
        rise(c, f.x, f.y - 4, 10, 8, 28, f.t, seed: f.seed, Tones(p.hi, p.ac, p.lt, p.md), size: 2)
        return true
    }

    /// 철벽: a dome of steel hex plates rising around the warrior, a glint sweeping across it.
    private static func ironWall(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = ironPal
        let up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.65, 1)
        if f.t < 0.3 { fade(c, 1 - f.t / 0.3) { shock(c, f.x, f.y, 5 + f.t / 0.3 * 18, 2, p, squash: 0.4) } }
        fade(c, k * 0.9) {
            for row in 0..<3 {
                let ry = f.y - 2 - Double(row) * 7 * up, rr = 13 - Double(row) * 3.5
                for i in 0..<(6 - row) {
                    let a = Double(i) / Double(6 - row) * 2 * .pi + Double(row) * 0.4
                    let hx = f.x + cos(a) * rr, hy = ry + sin(a) * rr * 0.35
                    poly(c, hx, hy, 2.6, 6, 0, sin(a) > 0 ? p.lt : p.md)
                    px(c, hx, hy, p.hi)
                }
            }
            poly(c, f.x, f.y - 23 * up, 2.6, 6, 0, p.hi)
        }
        if f.t > 0.3, f.t < 0.8 {
            let gx = f.x - 13 + 26 * win(f.t, 0.3, 0.8)
            seg(c, gx, f.y - 23, gx - 5, f.y - 1, p.hi)
        }
        return true
    }

    /// 회오리검 (and the cyclones of 광기 / 피의 갈증): a funnel of wind with blades orbiting at three heights.
    private static func cyclone(_ c: CGContext, _ f: FXF, _ p: FXPal, blood: Bool) -> Bool {
        guard case .slash = f.kind else { return false }
        let spin = f.now * 14
        for k in 0..<3 {
            let y = f.y + 4 - Double(k) * 7, r = 19 - Double(k) * 4.5
            circle(c, f.x, y, r, k == 0 ? p.lt : p.md, squash: 0.35, from: spin + Double(k), to: spin + Double(k) + 4.4, dash: 3)
            circle(c, f.x, y - 1, r - 2, p.hi, squash: 0.35, from: spin + Double(k) + 2, to: spin + Double(k) + 3)
        }
        for b in 0..<3 {
            let a = spin * 1.3 + Double(b) * 2.09
            blade(c, f.x + cos(a) * (17 - Double(b) * 4), f.y + 3 - Double(b) * 7 + sin(a) * 5, a + .pi / 2, 6, p)
        }
        if blood { fling(c, f.x, f.y, 6, 70, f.t, seed: f.seed, Tones(p.md, p.dk, p.lt), spread: .pi, gravity: 120, size: 2) }
        spice(c, f.x, f.y, 16, f.el, f.t, seed: f.seed, n: 3)
        return true
    }

    /// 내려찍기: the blade's light falls, then a flat shockwave, cracks spidering out and rocks bouncing.
    private static func slamCracks(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.t > 0.15 else { return true }
        let g = 1 - win(f.t, 0.4, 1)
        fade(c, 1 - win(f.t, 0.8, 1)) {
            ellipse(c, f.x, f.y, 8, earthPal.dk, squash: 0.45)
            for i in 0..<7 { crack(c, f.x, f.y, Double(i) * 0.9 + 0.3, f.r * 0.6, earthPal, seed: f.seed &+ UInt64(i), glow: g) }
        }
        return true
    }

    private static func slam(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = slamPal
        if f.t < 0.15 {
            let u = f.t / 0.15
            beam(c, f.x, f.y - 46, f.x, f.y - 46 + 44 * u, 3, p)
            return true
        }
        let u = easeOut(win(f.t, 0.15, 1))
        fade(c, 1 - win(f.t, 0.6, 1)) {
            shock(c, f.x, f.y, f.r * u, 3, p, squash: 0.45)
            shock(c, f.x, f.y, f.r * u * 0.6, 2, p, squash: 0.45)
        }
        if u < 0.4 { glow(c, f.x, f.y - 4, 18, p.hi, 1 - u / 0.4, squash: 0.6); star(c, f.x, f.y - 3, 6, p.lt, p.hi) }
        fling(c, f.x, f.y, 12, 100, win(f.t, 0.15, 1), seed: f.seed, Tones(earthPal.ac, earthPal.dk, earthPal.md), spread: 0.9, gravity: 280, size: 2)
        spice(c, f.x, f.y, f.r * 0.6, f.el, f.t, seed: f.seed, n: 6)
        return true
    }

    /// 천둥 강림: a huge forked bolt from the sky, a white flash and arcs crawling over the ground.
    private static func thunderFall(_ c: CGContext, _ f: FXF) -> Bool {
        let p = stormPal
        if f.t < 0.45, Int(f.age * 30) % 3 != 2 {
            zap(c, f.x + 10, f.y - 130, f.x, f.y - 2, p, seed: f.seed &+ UInt64(truncatingIfNeeded: Int(f.age * 30)), jag: 7, w: 3, branches: 2)
        }
        if f.t < 0.2 { glow(c, f.x, f.y - 6, 22, p.hi, 1 - f.t / 0.2, squash: 0.7) }
        let u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.5, 1)) {
            shock(c, f.x, f.y, 6 + 24 * u, 2, p, squash: 0.45)
            for i in 0..<5 {
                let a = Double(i) * 1.26 + f.age * 6, r1 = 6 + 20 * u
                zap(c, f.x + cos(a) * 4, f.y + sin(a) * 2, f.x + cos(a) * r1, f.y + sin(a) * r1 * 0.45, p, seed: f.seed &+ UInt64(truncatingIfNeeded: i * 7 + Int(f.age * 20)), jag: 2, w: 1, branches: 0)
            }
        }
        return true
    }

    /// A scorched patch under a strike.
    private static func scorch(_ c: CGContext, _ f: FXF) -> Bool {
        fade(c, 0.45 * (1 - win(f.t, 0.6, 1))) { ellipse(c, f.x, f.y, 9, outline, squash: 0.45) }
        return true
    }

    /// 방패 강타: the shield drives forward, a blue impact front and stun stars over the struck spot.
    private static func shieldBash(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return true }
        let p = knightPal, ux = cos(f.dir), uy = sin(f.dir)
        let thrust = easeOut(win(f.t, 0, 0.25))
        let sx = f.x - ux * (14 - 12 * thrust), sy = f.y - 5 - uy * (14 - 12 * thrust)
        fade(c, 1 - win(f.t, 0.6, 1)) { glyph(c, "kite", kiteGrid, p, sx, sy) }
        if f.t > 0.2 {
            let u = easeOut(win(f.t, 0.2, 1))
            fade(c, 1 - u) {
                oval(c, sx + ux * 7, sy + uy * 7, 3 + u * 4, 9 + u * 14, f.dir, p.hi, from: -1.4, to: 1.4)
                oval(c, sx + ux * 5, sy + uy * 5, 2 + u * 3, 6 + u * 9, f.dir, p.lt, from: -1.4, to: 1.4)
                shock(c, f.x, f.y, f.r * u, 2, p, squash: 0.45)
            }
            for k in 0..<3 { let a = f.age * 9 + Double(k) * 2.09; star(c, f.x + cos(a) * 8, f.y - 17 + sin(a) * 3, 1, p.ac, p.hi) }
        }
        return true
    }

    /// 수호의 성역: a turning golden sigil on the ground, light rising at its corners, a shield over the head.
    private static func aegisSigil(_ c: CGContext, _ f: FXF) -> Bool {
        let p = sanctumPal, u = easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.75, 1)) {
            poly(c, f.x, f.y, 24 * u, 4, f.age * 0.8, p.md, squash: 0.45)
            poly(c, f.x, f.y, 17 * u, 4, -f.age * 0.8 + 0.78, p.lt, squash: 0.45)
            circle(c, f.x, f.y, 12 * u, p.ac, squash: 0.45, dash: 2)
        }
        return true
    }

    private static func aegis(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = sanctumPal, k = 1 - win(f.t, 0.7, 1)
        for i in 0..<4 {
            let a = f.age * 0.8 + Double(i) * .pi / 2
            pillar(c, f.x + cos(a) * 24, f.y + sin(a) * 24 * 0.45, 3, 28 * easeOut(win(f.t, 0.1, 0.4)), p, k * 0.8)
        }
        fade(c, punch(f.t, at: 0.25, hold: 0.4)) { glyph(c, "kite", kiteGrid, p, f.x, f.y - 30 - easeOut(f.t) * 8) }
        return true
    }

    /// 피의 일격: three blood crescents raked side by side like a claw, blood flying.
    private static func bloodClaw(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, let rad) = f.kind else { return false }
        let p = bloodPal, t = win(f.t, Double(f.seq) * 0.1, 1)
        let s: Double = cos(f.dir) < -0.01 ? -1 : 1
        let a0 = ang - 1.5 * s, a1 = ang + 1.2 * s
        let h = easeOut(win(t, 0, 0.45)), tl = win(t, 0.2, 1)
        if h > tl + 0.02 {
            let off = Double(f.seq - 1) * 6
            let cx = f.x - sin(f.dir) * off - cos(f.dir) * 6, cy = f.y + cos(f.dir) * off * 0.6 - sin(f.dir) * 6
            crescent(c, cx, cy, rad, a0 + (a1 - a0) * tl, a0 + (a1 - a0) * h, 6, p, squash: 0.7, rim: p.ac)
        }
        if f.seq == 1 {
            fade(c, 0.4 * (1 - f.t)) { glow(c, f.x, f.y, 20, p.dk, 1, squash: 0.6) }
            fling(c, f.x + cos(f.dir) * 10, f.y, 14, 80, f.t, seed: f.seed, Tones(p.lt, p.md, p.dk), dir: f.dir, spread: 1.2, gravity: 160, size: 2)
        }
        return true
    }

    /// 광기: jagged scream rings and dark flames; its cyclone runs red and sprays blood.
    private static func frenzy(_ c: CGContext, _ f: FXF) -> Bool {
        let p = berserkPal
        switch f.kind {
        case .levelUp:
            for k in 0..<3 {
                let u = win(f.t, Double(k) * 0.12, Double(k) * 0.12 + 0.5)
                guard u > 0, u < 1 else { continue }
                fade(c, 1 - u) { jag(c, f.x, f.y - 10, 6 + u * 28, k == 0 ? p.lt : p.md, n: 9, amp: 3, squash: 0.6, rot: Double(k)) }
            }
            fade(c, 1 - win(f.t, 0.6, 1)) {
                for i in 0..<5 { flame(c, f.x - 8 + Double(i) * 4, f.y + 1, 10 + Double(i % 2) * 6, 4, p, phase: f.age * 20 + Double(i)) }
            }
            rise(c, f.x, f.y, 8, 10, 24, f.t, seed: f.seed, Tones(p.ac, p.lt, p.md, p.dk), size: 2)
            return true
        case .slash: return cyclone(c, f, p, blood: true)
        default: return false
        }
    }

    /// 대지 가르기 (근위기사): a straight fissure of light, beams shooting up out of it.
    private static func skySplitLine(_ c: CGContext, _ f: FXF) -> Bool {
        let p = skysplitPal, ux = cos(f.dir), uy = sin(f.dir)
        fade(c, 1 - win(f.t, 0.6, 1)) {
            seg(c, f.x - ux * 10, f.y - uy * 6, f.x + ux * 10, f.y + uy * 6, p.dk, 3)
            seg(c, f.x - ux * 10, f.y - uy * 6, f.x + ux * 10, f.y + uy * 6, p.hi)
        }
        return true
    }

    private static func skySplit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = skysplitPal
        var r = KartRNG(seed: f.seed)
        for _ in 0..<3 {
            let o = Double(r.int(17)) - 8
            pillar(c, f.x + cos(f.dir) * o, f.y + sin(f.dir) * o * 0.6, 2, (16 + Double(r.int(18))) * punch(f.t, at: 0.15, hold: 0.2), p, 0.9)
        }
        rise(c, f.x, f.y, 6, 9, 20, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md))
        return true
    }

    /// 철벽 진형: a ring of tower shields rises around every ally.
    private static func phalanx(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = phalanxPal
        let up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.7, 1)
        for front in [false, true] {
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * .pi + 0.26
                guard (sin(a) > 0) == front else { continue }
                fade(c, k * (front ? 0.7 : 1)) { glyph(c, "tower", towerGrid, p, f.x + cos(a) * 15, f.y + sin(a) * 6 - 2 - 6 * up) }
            }
        }
        if f.t < 0.3 { fade(c, 1 - f.t / 0.3) { shock(c, f.x, f.y, 8 + f.t / 0.3 * 14, 2, p, squash: 0.45) } }
        return true
    }

    /// 신검 강림: a sword-shaped mark on the ground, then a giant sword plunges in with a splash of light.
    private static func divineSwordMark(_ c: CGContext, _ f: FXF) -> Bool {
        let p = divineSwordPal
        switch f.kind {
        case .telegraph(let r):
            let u = easeOut(f.t)
            fade(c, 0.4 + 0.5 * f.t) {
                circle(c, f.x, f.y, r * u, p.lt, squash: 0.45)
                seg(c, f.x - r * 0.6 * u, f.y, f.x + r * 0.6 * u, f.y, p.md)
                seg(c, f.x, f.y - r * 0.3 * u, f.x, f.y + r * 0.3 * u, p.md)
            }
        case .meteor:
            guard f.t > 0.18 else { break }
            fade(c, 1 - win(f.t, 0.5, 1)) { for i in 0..<5 { crack(c, f.x, f.y, Double(i) * 1.26, 12, p, seed: f.seed &+ UInt64(i), glow: 1 - f.t) } }
        default: break
        }
        return true
    }

    private static func divineSword(_ c: CGContext, _ f: FXF) -> Bool {
        let p = divineSwordPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            let fall = easeIn(win(f.t, 0, 0.18))
            let tip = f.y - 80 * (1 - fall)
            if f.t < 0.18 { pillar(c, f.x, tip - 18, 3, 40, p, 0.5) }
            fade(c, 1 - win(f.t, 0.7, 1)) { glyph(c, "dsword", swordGrid, p, f.x, tip - 9) }
            if f.t > 0.18 {
                let u = easeOut(win(f.t, 0.18, 1))
                fade(c, 1 - u) {
                    shock(c, f.x, f.y, r * u, 2, p, squash: 0.45)
                    rays(c, f.x, f.y - 2, 8, 16 * u, 0, p, squash: 0.6)
                }
            }
            return true
        default: return false
        }
    }

    /// 불굴의 의지: a column of gold, a mane of flames over the head and roaring rings.
    private static func unbowed(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = willPal, k = 1 - win(f.t, 0.7, 1)
        pillar(c, f.x, f.y, 12 * easeOut(win(f.t, 0, 0.2)), 44, p, k * 0.6)
        fade(c, k) {
            for i in 0..<7 {
                let a = .pi + Double(i) / 6 * .pi
                flame(c, f.x + cos(a) * 10, f.y - 16 + sin(a) * 8, 7 + 3 * sin(f.age * 12 + Double(i)), 3, p, phase: f.age * 20 + Double(i))
            }
        }
        for j in 0..<2 {
            let u = win(f.t, Double(j) * 0.18, Double(j) * 0.18 + 0.45)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { jag(c, f.x, f.y - 12, 6 + u * 26, p.lt, n: 10, amp: 2, squash: 0.6) }
        }
        return true
    }

    /// 분쇄의 질주: each stomp leaves a glowing crater and blasts up chunks of rock and fire.
    private static func crater(_ c: CGContext, _ f: FXF) -> Bool {
        let p = crushPal
        fade(c, 1 - win(f.t, 0.6, 1)) {
            ellipse(c, f.x, f.y, 8, p.dk, squash: 0.45)
            circle(c, f.x, f.y, 8, p.md, squash: 0.45)
            circle(c, f.x, f.y - 1, 6, p.lt, squash: 0.45, dash: 2)
        }
        return true
    }

    private static func crushStomp(_ c: CGContext, _ f: FXF) -> Bool {
        let p = crushPal
        fling(c, f.x, f.y, 5, 90, f.t, seed: f.seed, Tones(p.ac, p.dk), spread: 0.5, gravity: 300, size: 3)
        fling(c, f.x, f.y, 5, 70, f.t, seed: f.seed &+ 3, Tones(p.hi, p.lt), spread: 0.7, gravity: 160, size: 1)
        fade(c, 1 - win(f.t, 0.4, 1)) {
            flame(c, f.x - 3, f.y, 9 * punch(f.t, at: 0.1, hold: 0.1), 4, p, phase: f.age * 30)
            flame(c, f.x + 4, f.y + 1, 6 * punch(f.t, at: 0.15, hold: 0.1), 3, p, phase: f.age * 30 + 2)
            shock(c, f.x, f.y, 4 + easeOut(f.t) * 12, 2, p, squash: 0.45)
        }
        return true
    }

    /// 피의 갈증: blood spirals into the warrior and bursts in a crimson pulse; its cyclone runs crimson and violet.
    private static func bloodlust(_ c: CGContext, _ f: FXF) -> Bool {
        let p = thirstPal
        switch f.kind {
        case .levelUp:
            for i in 0..<14 {
                let ph = Double(i) / 14
                let u = win(f.t, ph * 0.3, ph * 0.3 + 0.5)
                guard u > 0, u < 1 else { continue }
                let a = Double(i) * 2.4 + u * 4, r = 26 * (1 - u)
                px(c, f.x + cos(a) * r, f.y - 9 + sin(a) * r * 0.6, i % 3 == 0 ? p.lt : p.md, 2)
            }
            if f.t > 0.55 {
                let u = win(f.t, 0.55, 1)
                fade(c, 1 - u) { shock(c, f.x, f.y - 6, 4 + u * 20, 2, p, squash: 0.6); glow(c, f.x, f.y - 8, 12, p.md, 1 - u) }
            }
            return true
        case .slash: return cyclone(c, f, p, blood: true)
        default: return false
        }
    }

    /// 학살의 폭풍: swords wheel around the warrior and dark crescents sweep the whole circle.
    private static func slaughterStorm(_ c: CGContext, _ f: FXF) -> Bool {
        let p = slaughterPal
        let spin = f.now * 8 + Double(f.seq)
        let r = f.r * (0.7 + 0.2 * easeOut(f.t))
        fade(c, 1 - win(f.t, 0.5, 1)) {
            crescent(c, f.x, f.y - 4, r, spin, spin + 2.4, 5, p, squash: 0.45, rim: p.dk)
            if f.seq % 2 == 0 {
                for b in 0..<6 {
                    let a = spin * 1.2 + Double(b) * 1.047
                    blade(c, f.x + cos(a) * r * 0.8, f.y - 4 + sin(a) * r * 0.36, a + .pi / 2, 7, p)
                }
            }
        }
        fling(c, f.x, f.y, 6, 90, f.t, seed: f.seed, Tones(p.md, p.lt, p.dk), spread: .pi, gravity: 120)
        return true
    }

    /// 광왕의 포효: the roar rolls out to each foe, bursting in jagged rings under a flashing crown.
    private static func madRoar(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = madKingPal, u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.5, 1)) {
            jag(c, f.x, f.y - 6, 4 + u * 17, p.lt, n: 10, amp: 2, squash: 0.7)
            jag(c, f.x, f.y - 6, 2 + u * 10, p.ac, n: 8, amp: 1.5, squash: 0.7, rot: 0.3)
            glyph(c, "crown", crownGrid, p, f.x, f.y - 22 - u * 4)
        }
        if f.t < 0.4 {
            let v = f.t / 0.4, a = atan2(f.y - f.oy, f.x - f.ox)
            fade(c, 1 - v) { oval(c, f.ox + (f.x - f.ox) * v, f.oy - 10 + (f.y + 4 - f.oy) * v, 2, 7, a, p.lt, from: -1.2, to: 1.2) }
        }
        return true
    }
}

// MARK: - archer

extension RpgArt {
    static let triplePal = FXPal(0xF0FFF0, 0xA8F0A0, 0x48B860, 0x1E5A32, 0xE0FF80)
    static let piercePal = FXPal(0xFFFFFF, 0xC0F8FF, 0x50C8F0, 0x1A5A8A, 0xFFFFFF)
    static let rainWoodPal = FXPal(0xFFFFFF, 0xF0E6D0, 0xB08A5A, 0x5A3A1E, 0xE8E8E8)
    static let venomPal = FXPal(0xF0FFD0, 0xB8F050, 0x6AB828, 0x2A5014, 0xC060FF)
    static let backstepPal = FXPal(0xFFFFFF, 0xDCEEFF, 0x96BEE6, 0x3A5A8A, 0xFFE070)
    static let trapPal = FXPal(0xFFF0C0, 0xFFB040, 0xE0501E, 0x5A2A10, 0x9AA0AA)
    static let focusPal = FXPal(0xFFFFFF, 0xC8FFD8, 0x50D88A, 0x1A6A44, 0xFF5A5A)
    static let stormArrowPal = FXPal(0xFFFFFF, 0xC8E8FF, 0x5A8AE8, 0x22306A, 0xFFF06A)
    static let sniperPal = FXPal(0xFFFFFF, 0xFFF4E0, 0xFFC890, 0x8A5A3A, 0xFF3A3A)
    static let deadeyePal = FXPal(0xFFE0E0, 0xFF6A6A, 0xD01A2A, 0x3A0610, 0x2A2A2A)
    static let volleyPal = FXPal(0xFFFBE0, 0xFFD070, 0xF08A2A, 0x7A3A10, 0xFFF0A0)
    static let netPal = FXPal(0xFFF8E0, 0xE8D8A8, 0xB09A6A, 0x5A4A30, 0xA0A0A0)
    static let needlePal = FXPal(0xFFFFFF, 0xD8FAFF, 0x6AD0F8, 0x1A4A7A, 0xE0FFFF)
    static let markPal = FXPal(0xFFFFFF, 0xFFD8B0, 0xFF7A3A, 0x8A2A10, 0xFFE040)
    static let fatalPal = FXPal(0xFFFFFF, 0xFF8A8A, 0xC8102A, 0x1A0408, 0xFFD24A)
    static let fatalRingPal = FXPal(0xFF8A8A, 0xC8102A, 0x5A0410, 0x1A0408, 0x000000)
    static let starPal = FXPal(0xFFFFFF, 0xFFF4B0, 0x9AB0FF, 0x2A2A7A, 0xFFE070)
    static let windRainPal = FXPal(0xF4FFF4, 0xB8F4C8, 0x5AC88A, 0x1E6A4A, 0xE0FFF0)
    static let hazePal = FXPal(0xF8E8FF, 0xD8A0FF, 0x9A50D8, 0x3A1A5A, 0x9AE050)
    static let typhoonPal = FXPal(0xFFFFFF, 0xD8FFF8, 0x7AE0D0, 0x1E6A70, 0xFFFFFF)
    static let forestPal = FXPal(0xF0FFD0, 0x9AE060, 0x4A9A30, 0x3A2A14, 0x8A5A2A)

    static let bearTrapGrid: RpgGrid = ["..kkkkkkkkk..", ".kmlmlmlmlmk.", "kml.l.l.l.lmk", "km....a....mk", "kml.l.l.l.lmk", ".kmlmlmlmlmk.", "..kkkkkkkkk.."]
    static let bearTrapShutGrid: RpgGrid = ["..kkkkkkkkk..", ".kmmmmmmmmmk.", ".klhlhlhlhlk.", ".kmmmmmmmmmk.", "..kkkkkkkkk.."]
    static let netGrid: RpgGrid = ["d...m...m...d", ".m.m.m.m.m.m.", "..m...m...m..", ".m.m.m.m.m.m.", "d...m...m...d"]
    static let eyeGrid: RpgGrid = ["..kkk..", ".klllk.", "klmamlk", ".klllk.", "..kkk.."]
    static let skullGrid: RpgGrid = [".kkkk.", "klllhk", "kdlldk", "klkklk", ".kmmk."]

    static let archerLooks: [String: FXLook] = [
        "a_triple": FXLook(pal: triplePal, hit: leafHit, shot: tripleArrow),
        "a_pierce": FXLook(pal: piercePal, hit: pierceHit, shot: pierceArrow),
        "a_rain": FXLook(pal: rainWoodPal, draw: arrowVolley, floor: volleyMark),
        "a_poison": FXLook(pal: venomPal, hit: venomSplash, shot: venomArrow),
        "a_back": FXLook(pal: backstepPal, draw: backstepKick, shot: backstepArrow),
        "a_trap": FXLook(pal: trapPal, draw: trapBlast, trap: bearTrap),
        "a_focus": FXLook(pal: focusPal, draw: focusSight),
        "a_ult": FXLook(pal: stormArrowPal, hit: stormHit, shot: stormArrow),
        "j_snipe": FXLook(pal: sniperPal, hit: crosshairHit, shot: sniperShot),
        "j_deadeye": FXLook(pal: deadeyePal, hit: deadeyeHit, shot: deadeyeShot),
        "j_volley": FXLook(pal: volleyPal, hit: emberHit, shot: emberArrow),
        "j_net": FXLook(pal: netPal, draw: netSnap, trap: netTrap),
        "t2_ar1a": FXLook(pal: needlePal, hit: pierceHit, shot: needleShot),
        "t2_ar1b": FXLook(pal: markPal, hit: markHit, shot: markedArrow),
        "t3_ar1a": FXLook(pal: fatalPal, hit: fatalHit, shot: fatalArrow),
        "t3_ar1b": FXLook(pal: starPal, draw: starfall, floor: starMark),
        "t2_ar2a": FXLook(pal: windRainPal, draw: windVolley, floor: windMark),
        "t2_ar2b": FXLook(pal: hazePal, hit: hazeHit, shot: hazeArrow),
        "t3_ar2a": FXLook(pal: typhoonPal, hit: swirlHit, shot: typhoonArrow),
        "t3_ar2b": FXLook(pal: forestPal, draw: forestVines, floor: forestRing),
    ]

    /// Shaft, head and fletching of an arrow pointing along the shot.
    static func arrowBody(_ c: CGContext, _ s: ShotF, _ head: FXPal, shaft: CGColor, fletch: CGColor, len: Double = 10, big: Bool = false) {
        let x = s.x, y = s.y, ux = s.ux, uy = s.uy, nx = -uy, ny = ux
        seg(c, x - ux * len, y - uy * len, x - ux * 2, y - uy * 2, shaft, big ? 2 : 1)
        px(c, x + ux, y + uy, head.hi); px(c, x, y, head.hi); px(c, x - ux, y - uy, head.lt)
        px(c, x - ux * 1.5 + nx, y - uy * 1.5 + ny, head.md); px(c, x - ux * 1.5 - nx, y - uy * 1.5 - ny, head.md)
        if big {
            px(c, x + ux * 2, y + uy * 2, head.hi)
            px(c, x - ux * 2.5 + nx * 2, y - uy * 2.5 + ny * 2, head.md); px(c, x - ux * 2.5 - nx * 2, y - uy * 2.5 - ny * 2, head.md)
        }
        for k in 0..<3 {
            let bx = x - ux * (len - 1 + Double(k)), by = y - uy * (len - 1 + Double(k))
            px(c, bx + nx * 1.4, by + ny * 1.4, fletch); px(c, bx - nx * 1.4, by - ny * 1.4, fletch)
        }
    }

    /// Distance a shot has flown from the caster's hand.
    static func flown(_ s: ShotF) -> Double { hypot(s.x - s.ox, s.y - s.oy + 7) }

    /// A five-pointed star outline.
    static func pentagram(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ rot: Double, _ col: CGColor, squash: Double = 1) {
        for i in 0..<5 {
            let a = rot - .pi / 2 + Double(i) * 4 * .pi / 5, b = rot - .pi / 2 + Double(i + 1) * 4 * .pi / 5
            seg(c, x + cos(a) * r, y + sin(a) * r * squash, x + cos(b) * r, y + sin(b) * r * squash, col)
        }
    }

    /// 삼연사: green arrows trailing a ribbon of wind.
    private static func tripleArrow(_ c: CGContext, _ s: ShotF) {
        let p = triplePal, nx = -s.uy, ny = s.ux, d = flown(s)
        for k in 0..<12 {
            let back = 8 + Double(k) * 1.6, w = sin((d - back) / 4) * 2.5
            fade(c, 1 - Double(k) / 12) { px(c, s.x - s.ux * back + nx * w, s.y - s.uy * back + ny * w, k < 4 ? p.hi : p.lt) }
        }
        arrowBody(c, s, p, shaft: woodPal.lt, fletch: p.md, len: 10)
    }

    private static func leafHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.4, 1)) { circle(c, f.x, f.y, 2 + u * (f.crit ? 12 : 7), p.lt, squash: 0.7) }
        fling(c, f.x, f.y, f.crit ? 9 : 5, 50, f.t, seed: f.seed, Tones(p.md, p.lt, p.ac), dir: f.dir, spread: 1.3, gravity: 40, size: 2)
        if f.t < 0.3 { star(c, f.x, f.y, f.crit ? 4 : 2, p.md, p.hi) }
        return true
    }

    /// 관통 화살: a long glowing shaft in a helix of wind, sonic rings left standing along its path.
    private static func pierceArrow(_ c: CGContext, _ s: ShotF) {
        let p = piercePal, nx = -s.uy, ny = s.ux, d = flown(s), a = atan2(s.uy, s.ux)
        var m = 22.0
        while m < d {
            let age = (d - m) / s.speed
            if age < 0.25 { let q = age / 0.25; fade(c, 1 - q) { oval(c, s.x - s.ux * (d - m), s.y - s.uy * (d - m), 1.5 + q * 2, 3 + q * 7, a, p.lt) } }
            m += 22
        }
        for k in 0..<16 {
            let back = Double(k) * 1.2, ph = (d - back) / 3
            fade(c, 1 - Double(k) / 16) {
                px(c, s.x - s.ux * back + nx * sin(ph) * 3, s.y - s.uy * back + ny * sin(ph) * 3, p.hi)
                px(c, s.x - s.ux * back - nx * sin(ph) * 3, s.y - s.uy * back - ny * sin(ph) * 3, p.md)
            }
        }
        glow(c, s.x, s.y, 6, p.lt, 0.7)
        arrowBody(c, s, p, shaft: p.md, fletch: p.lt, len: 14, big: true)
    }

    /// A bright line punched straight through the target.
    private static func pierceHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, ux = cos(f.dir), uy = sin(f.dir)
        let l = (f.crit ? 16.0 : 10.0) * easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.35, 1)) {
            seg(c, f.x - ux * l, f.y - uy * l, f.x + ux * l * 1.4, f.y + uy * l * 1.4, p.lt, 2)
            seg(c, f.x - ux * l, f.y - uy * l, f.x + ux * l * 1.4, f.y + uy * l * 1.4, p.hi)
            if f.crit { oval(c, f.x, f.y, 3, 9, f.dir, p.md) }
        }
        fling(c, f.x, f.y, 4, 50, f.t, seed: f.seed, Tones(p.hi, p.lt), dir: f.dir, spread: 0.5, gravity: 30)
        return true
    }

    /// 화살비: six volleys streak down from the sky and stick in the ground, puffing dust.
    private static func arrowVolley(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .rain(let r) = f.kind else { return false }
        guard f.dur > 1 else { return true }
        let p = rainWoodPal, w = woodPal, lean = cos(f.dir) >= 0 ? -1.0 : 1.0
        var rng = KartRNG(seed: f.seed)
        let gone = 1 - win(f.age, f.dur - 0.25, f.dur)
        for i in 0..<30 {
            let a = Double(rng.int(628)) / 100, d = r * sqrt(Double(rng.int(100)) / 100)
            let gx = f.x + cos(a) * d, gy = f.y + sin(a) * d * 0.5
            let t = f.age - Double(i / 5) * 0.2 - Double(i % 5) * 0.025
            guard t > 0 else { continue }
            if t < 0.12 {
                let u = t / 0.12, hx = gx + lean * 16 * (1 - u), hy = gy - 56 * (1 - u)
                seg(c, hx + lean * 4, hy - 14, hx, hy, p.hi)
                seg(c, hx + lean * 2, hy - 7, hx, hy, w.lt)
            } else {
                fade(c, gone) {
                    seg(c, gx + lean * 2, gy - 6, gx, gy, w.md)
                    px(c, gx + lean * 2, gy - 6, p.lt); px(c, gx + lean * 3, gy - 6, p.lt)
                }
                let s = t - 0.12
                if s < 0.15 { fade(c, 1 - s / 0.15) { circle(c, gx, gy, 2 + s * 30, dustPal.lt, squash: 0.5) } }
            }
        }
        return true
    }

    private static func volleyMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .rain(let r) = f.kind, f.dur > 1 else { return true }
        fade(c, 0.5 * (1 - win(f.t, 0.8, 1))) { circle(c, f.x, f.y, r, rainWoodPal.lt, squash: 0.5, dash: 3) }
        return true
    }

    /// 독화살: a green-headed arrow dripping venom.
    private static func venomArrow(_ c: CGContext, _ s: ShotF) {
        let p = venomPal, d = flown(s)
        for k in 0..<12 { fade(c, 0.8 - Double(k) * 0.06) { px(c, s.x - s.ux * (9 + Double(k) * 2), s.y - s.uy * (9 + Double(k) * 2), k < 5 ? p.lt : p.md, 2) } }
        for k in 0..<5 {
            let back = 6 + Double(k) * 7 + d.truncatingRemainder(dividingBy: 7), fell = back / s.speed
            px(c, s.x - s.ux * back, s.y - s.uy * back + 2 + 140 * fell * fell, k % 2 == 0 ? p.lt : p.md, 2)
        }
        glow(c, s.x, s.y, 7, p.lt, 0.8)
        arrowBody(c, s, p, shaft: woodPal.dk, fletch: p.ac, len: 11, big: true)
    }

    private static func venomSplash(_ c: CGContext, _ f: FXF) -> Bool {
        let p = venomPal, u = easeOut(f.t)
        fling(c, f.x, f.y, f.crit ? 12 : 7, 55, f.t, seed: f.seed, Tones(p.lt, p.md, p.hi), spread: 1.4, gravity: 140, size: 2)
        fade(c, 1 - win(f.t, 0.4, 1)) {
            circle(c, f.x, f.y, 2 + 8 * u, p.md, squash: 0.6)
            if f.crit { glyph(c, "skull", skullGrid, p, f.x, f.y - 10 - u * 4) }
        }
        return true
    }

    /// 백스텝 사격: dust thrown forward as the archer leaps back, then a fan of arrows with after-images.
    private static func backstepKick(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = backstepPal, ux = cos(f.dir), uy = sin(f.dir), u = easeOut(f.t)
        fade(c, 1 - f.t) {
            for k in 0..<4 { puff(c, f.x + ux * (4 + Double(k) * 5) * u, f.y - 2 - Double(k) + uy * 5 * u, 3 + Double(k), dustPal.lt, dustPal.md) }
            oval(c, f.x - ux * 16 * u, f.y - 8 - uy * 16 * u, 3, 9, f.dir + .pi, p.lt, from: -1.2, to: 1.2)
            oval(c, f.x - ux * 10 * u, f.y - 8 - uy * 10 * u, 2, 6, f.dir + .pi, p.hi, from: -1.2, to: 1.2)
        }
        return true
    }

    private static func backstepArrow(_ c: CGContext, _ s: ShotF) {
        let p = backstepPal
        var ghost = s
        for k in [2.0, 1.0] {
            ghost = ShotF(x: s.x - s.ux * 5 * k, y: s.y - s.uy * 5 * k, ux: s.ux, uy: s.uy, speed: s.speed, now: s.now, ox: s.ox, oy: s.oy, seq: s.seq, seed: s.seed, kind: s.kind, el: s.el, pal: s.pal)
            fade(c, 0.45 / k) { arrowBody(c, ghost, p, shaft: p.md, fletch: p.lt, len: 9) }
        }
        arrowBody(c, s, p, shaft: woodPal.lt, fletch: p.hi, len: 10)
    }

    /// 폭발 덫: a toothed trap with a lit fuse; it snaps shut and blows up.
    private static func bearTrap(_ c: CGContext, _ t: TrapF) {
        let p = trapPal
        fade(c, t.armed ? (t.left < 2 && Int(t.now * 8) % 2 == 0 ? 0.45 : 1) : 0.5) { glyph(c, "beartrap", bearTrapGrid, p, t.x, t.y) }
        if t.armed, Int(t.now * 3) % 2 == 0 { glow(c, t.x, t.y, 3, p.md, 0.7); px(c, t.x, t.y, p.hi) }
    }

    private static func trapBlast(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = trapPal
        if f.t < 0.2 { glyph(c, "beartrapShut", bearTrapShutGrid, p, f.x, f.y) }
        let u = easeOut(win(f.t, 0.08, 1))
        fade(c, 1 - win(f.t, 0.5, 1)) {
            glow(c, f.x, f.y - 4, f.r * 0.7 * u, p.lt)
            shock(c, f.x, f.y, f.r * u, 3, p, squash: 0.5)
        }
        fling(c, f.x, f.y, 10, 100, f.t, seed: f.seed, Tones(p.ac, p.dk, p.lt), spread: 1, gravity: 220, size: 2)
        fade(c, 0.6 * (1 - f.t)) { for k in 0..<3 { puff(c, f.x - 8 + Double(k) * 8, f.y - 6 - f.t * 16, 4 + f.t * 7, smokePal.md, smokePal.dk) } }
        return true
    }

    /// 집중: a crosshair closes in on the archer, an eye opens over the head, green wind rises.
    private static func focusSight(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = focusPal, u = easeOut(win(f.t, 0, 0.45)), k = 1 - win(f.t, 0.7, 1)
        let r = 30 - 20 * u, cy = f.y - 10
        fade(c, k) {
            circle(c, f.x, cy, r, p.lt, squash: 0.8)
            circle(c, f.x, cy, r * 0.6, p.md, squash: 0.8, dash: 2)
            for i in 0..<4 { let a = Double(i) * .pi / 2 + f.age * 1.5; spike(c, f.x + cos(a) * (r + 6), cy + sin(a) * (r + 6) * 0.8, a + .pi, 5, p.hi, 1) }
            if u > 0.9 { glyph(c, "eye", eyeGrid, p, f.x, f.y - 31) }
        }
        rise(c, f.x, f.y, 8, 10, 26, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md))
        return true
    }

    /// 폭풍의 화살: huge arrows wrapped in a dark storm spiral, lightning crackling along the shaft.
    private static func stormArrow(_ c: CGContext, _ s: ShotF) {
        let p = stormArrowPal, nx = -s.uy, ny = s.ux, d = flown(s)
        for k in 0..<22 {
            let back = Double(k) * 1.3, ph = (d - back) / 4, w = 5 * (1 - Double(k) / 30)
            fade(c, 1 - Double(k) / 22) {
                px(c, s.x - s.ux * back + nx * sin(ph) * w, s.y - s.uy * back + ny * sin(ph) * w, p.dk, 2)
                px(c, s.x - s.ux * back - nx * sin(ph) * w, s.y - s.uy * back - ny * sin(ph) * w, p.lt)
            }
        }
        glow(c, s.x, s.y, 9, p.lt, 0.9)
        arrowBody(c, s, p, shaft: p.md, fletch: p.lt, len: 15, big: true)
        zap(c, s.x - s.ux * 20, s.y - s.uy * 20, s.x + s.ux * 3, s.y + s.uy * 3, p, seed: UInt64(truncatingIfNeeded: Int(s.now * 30)) &+ s.seed, jag: 3, w: 1, branches: 1)
    }

    private static func stormHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = stormArrowPal, u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.4, 1)) {
            for i in 0..<4 { let a = Double(i) * 1.57 + f.age * 10; zap(c, f.x, f.y, f.x + cos(a) * (6 + 6 * u), f.y + sin(a) * (4 + 4 * u), p, seed: f.seed &+ UInt64(i), jag: 2, w: 1, branches: 0) }
            circle(c, f.x, f.y, 3 + 9 * u * (f.crit ? 1.5 : 1), p.lt, squash: 0.7)
        }
        return true
    }

    /// 저격: a white-hot needle, its contrail running all the way back to the bow, a ring at launch.
    private static func sniperShot(_ c: CGContext, _ s: ShotF) {
        let p = sniperPal
        let sx = s.ox + s.ux * 6, sy = s.oy - 7 + s.uy * 6
        let d = hypot(s.x - sx, s.y - sy)
        for k in 0..<8 {
            let a = Double(k) / 8, b = Double(k + 1) / 8
            fade(c, 0.12 + 0.6 * b) { seg(c, sx + (s.x - sx) * a, sy + (s.y - sy) * a, sx + (s.x - sx) * b, sy + (s.y - sy) * b, p.lt) }
        }
        let age = d / s.speed
        if age < 0.2 { let q = age / 0.2; fade(c, 1 - q) { oval(c, sx + s.ux * 4, sy + s.uy * 4, 2 + q * 3, 4 + q * 11, atan2(s.uy, s.ux), p.hi) } }
        seg(c, s.x - s.ux * 7, s.y - s.uy * 7, s.x + s.ux, s.y + s.uy, p.hi, 2)
        px(c, s.x + s.ux * 2, s.y + s.uy * 2, p.ac)
    }

    private static func crosshairHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, r = 10 - 6 * easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.5, 1)) {
            circle(c, f.x, f.y, r, p.lt)
            for i in 0..<4 { let a = Double(i) * .pi / 2; seg(c, f.x + cos(a) * (r - 2), f.y + sin(a) * (r - 2), f.x + cos(a) * (r + 4), f.y + sin(a) * (r + 4), p.hi) }
            px(c, f.x, f.y, p.ac, f.crit ? 3 : 2)
        }
        if f.crit { fling(c, f.x, f.y, 8, 60, f.t, seed: f.seed, Tones(p.hi, p.ac), dir: f.dir, spread: 0.7, gravity: 60) }
        return true
    }

    /// 데드아이: blood-red arrows riding their own laser sight; an eye glares over the archer as they fly.
    private static func deadeyeShot(_ c: CGContext, _ s: ShotF) {
        let p = deadeyePal
        fade(c, 0.45) { seg(c, s.x, s.y, s.x + s.ux * 60, s.y + s.uy * 60, p.md) }
        for k in 0..<6 { fade(c, 0.7 - Double(k) * 0.1) { px(c, s.x - s.ux * (14 + Double(k) * 2), s.y - s.uy * (14 + Double(k) * 2), p.lt) } }
        arrowBody(c, s, p, shaft: p.ac, fletch: p.md, len: 12, big: true)
        if s.seq == 1, flown(s) / s.speed < 0.35 { glyph(c, "eye", eyeGrid, p, s.ox, s.oy - 30) }
    }

    private static func deadeyeHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = deadeyePal, l = (f.crit ? 8.0 : 5.0) * easeOut(win(f.t, 0, 0.2))
        fade(c, 1 - win(f.t, 0.45, 1)) {
            seg(c, f.x - l, f.y - l, f.x + l, f.y + l, p.lt, 2); seg(c, f.x - l, f.y + l, f.x + l, f.y - l, p.lt, 2)
            seg(c, f.x - l, f.y - l, f.x + l, f.y + l, p.hi); seg(c, f.x - l, f.y + l, f.x + l, f.y - l, p.hi)
            circle(c, f.x, f.y, l + 4, p.md)
        }
        return true
    }

    /// 속사: warm arrows shedding embers.
    private static func emberArrow(_ c: CGContext, _ s: ShotF) {
        let p = volleyPal
        var r = KartRNG(seed: s.seed &+ UInt64(truncatingIfNeeded: Int(s.now * 20)))
        for k in 0..<5 {
            let back = 9 + Double(k) * 3
            px(c, s.x - s.ux * back + Double(r.int(3)) - 1, s.y - s.uy * back - Double(k) * 0.8 + Double(r.int(3)) - 1, k < 2 ? p.hi : (k < 4 ? p.lt : p.md))
        }
        arrowBody(c, s, p, shaft: woodPal.md, fletch: p.md, len: 10)
    }

    private static func emberHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = volleyPal
        if f.t < 0.3 { star(c, f.x, f.y, f.crit ? 4 : 2, p.md, p.hi) }
        rise(c, f.x, f.y, f.crit ? 8 : 5, 4, 14, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md, p.dk))
        return true
    }

    /// 사냥꾼의 그물: a net spread on the ground that springs up over whatever steps on it.
    private static func netTrap(_ c: CGContext, _ t: TrapF) {
        fade(c, t.armed ? (t.left < 2 && Int(t.now * 8) % 2 == 0 ? 0.45 : 0.9) : 0.45) { glyph(c, "net", netGrid, netPal, t.x, t.y) }
    }

    private static func netSnap(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = netPal, up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.65, 1)
        fade(c, k) {
            let h = 18 * up, r = 12.0
            for i in 0..<7 {
                let a = Double(i) / 6 * .pi
                let bx = f.x + cos(a + .pi) * r
                seg(c, bx, f.y, f.x + cos(a + .pi) * r * 0.3, f.y - h, p.md)
            }
            for j in 1...3 { let hh = h * Double(j) / 4, rr = r * (1 - Double(j) / 4.5); circle(c, f.x, f.y - hh, rr, p.lt, squash: 0.35) }
            for i in 0..<4 { px(c, f.x + cos(Double(i) * 1.57) * r, f.y + sin(Double(i) * 1.57) * 4, p.dk, 2) }
        }
        fade(c, 0.6 * (1 - f.t)) { puff(c, f.x, f.y - 2, 4 + f.t * 6, dustPal.lt, dustPal.md) }
        return true
    }

    /// 관통 저격: an icy needle; spiralling shock rings stand along its path.
    private static func needleShot(_ c: CGContext, _ s: ShotF) {
        let p = needlePal
        let sx = s.ox + s.ux * 6, sy = s.oy - 7 + s.uy * 6, d = hypot(s.x - sx, s.y - sy), a = atan2(s.uy, s.ux)
        for k in 0..<8 {
            let u0 = Double(k) / 8, u1 = Double(k + 1) / 8
            fade(c, 0.1 + 0.5 * u1) { seg(c, sx + (s.x - sx) * u0, sy + (s.y - sy) * u0, sx + (s.x - sx) * u1, sy + (s.y - sy) * u1, p.md) }
        }
        var m = 18.0
        while m < d {
            let age = (d - m) / s.speed
            if age < 0.35 {
                let q = age / 0.35, rx = sx + s.ux * m, ry = sy + s.uy * m
                fade(c, 1 - q) { oval(c, rx, ry, 1.5 + q * 2, 3 + q * 6, a, p.lt, from: q * 6, to: q * 6 + 4.5) }
            }
            m += 26
        }
        glow(c, s.x, s.y, 7, p.lt, 0.8)
        seg(c, s.x - s.ux * 10, s.y - s.uy * 10, s.x + s.ux * 2, s.y + s.uy * 2, p.lt, 2)
        seg(c, s.x - s.ux * 10, s.y - s.uy * 10, s.x + s.ux * 2, s.y + s.uy * 2, p.hi)
        if Int(s.now * 20) % 2 == 0 { star(c, s.x - s.ux * 5, s.y - s.uy * 5, 1, p.lt, p.hi) }
    }

    /// 표식 난사: each arrow carries a turning target ring.
    private static func markedArrow(_ c: CGContext, _ s: ShotF) {
        let p = markPal, rot = s.now * 10
        arrowBody(c, s, p, shaft: woodPal.md, fletch: p.md, len: 11, big: true)
        circle(c, s.x, s.y, 5, p.lt, from: rot, to: rot + 1.2); circle(c, s.x, s.y, 5, p.lt, from: rot + 3.14, to: rot + 4.34)
        for i in 0..<4 { let a = rot + Double(i) * .pi / 2; px(c, s.x + cos(a) * 7, s.y + sin(a) * 7, p.ac) }
    }

    private static func markHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = markPal, r = 12 - 8 * easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.5, 1)) {
            poly(c, f.x, f.y, r, 4, 0, p.lt)
            poly(c, f.x, f.y, r * 0.5, 4, 0, p.ac)
            px(c, f.x, f.y, p.hi, f.crit ? 3 : 1)
        }
        return true
    }

    /// 일격필살: a massive black-and-crimson arrow behind its own crescent shock front.
    private static func fatalArrow(_ c: CGContext, _ s: ShotF) {
        let p = fatalPal, a = atan2(s.uy, s.ux)
        for k in 0..<20 { fade(c, 0.9 - Double(k) * 0.04) { px(c, s.x - s.ux * (14 + Double(k) * 2), s.y - s.uy * (14 + Double(k) * 2), k % 3 == 0 ? p.md : p.dk, 2) } }
        glow(c, s.x, s.y, 10, p.md, 0.7)
        oval(c, s.x + s.ux * 4, s.y + s.uy * 4, 3, 10, a, p.lt, from: -1.3, to: 1.3)
        oval(c, s.x + s.ux * 2, s.y + s.uy * 2, 2, 7, a, p.hi, from: -1.3, to: 1.3)
        arrowBody(c, s, p, shaft: p.dk, fletch: p.md, len: 16, big: true)
        let age = flown(s) / s.speed
        if age < 0.15 { fade(c, 1 - age / 0.15) { shock(c, s.ox + s.ux * 8, s.oy - 7 + s.uy * 8, 4 + age * 90, 2, p, squash: 0.8) } }
    }

    /// The target ruptures: a tall crimson spike up and down through it inside a black shock ring.
    private static func fatalHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = fatalPal, u = easeOut(win(f.t, 0, 0.2)), h = (f.crit ? 24.0 : 17.0) * u
        fade(c, 1 - win(f.t, 0.45, 1)) {
            shock(c, f.x, f.y, 4 + 18 * easeOut(f.t), 2, fatalRingPal, squash: 0.6)
            for a in [-Double.pi / 2, Double.pi / 2, 0, Double.pi] {
                let l = a == -.pi / 2 ? h : (a == .pi / 2 ? h * 0.55 : h * 0.3)
                spike(c, f.x, f.y, a, l, p.md, 4); spike(c, f.x, f.y, a, l * 0.85, p.hi, 1)
            }
        }
        fling(c, f.x, f.y, f.crit ? 12 : 8, 70, f.t, seed: f.seed, Tones(p.md, p.dk, p.lt), spread: 1.5, gravity: 160, size: 2)
        return true
    }

    /// 별빛 사격: a star traced on the ground, then a shooting star dives in and bursts into a five-point flare.
    private static func starMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.35 + 0.5 * f.t) {
            pentagram(c, f.x, f.y, r * 0.8 * easeOut(f.t), f.age * 0.6, starPal.lt, squash: 0.5)
            circle(c, f.x, f.y, r * easeOut(f.t), starPal.md, squash: 0.5, dash: 2)
        }
        return true
    }

    private static func starfall(_ c: CGContext, _ f: FXF) -> Bool {
        let p = starPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.2 {
                let u = easeIn(f.t / 0.2), hx = f.x + 50 * (1 - u), hy = f.y - 70 * (1 - u)
                for k in 0..<10 { let q = Double(k) * 3.5; fade(c, 1 - Double(k) / 10) { px(c, hx + q * 0.6, hy - q * 0.85, k % 3 == 0 ? p.hi : p.lt, k < 3 ? 2 : 1) } }
                star(c, hx, hy, 3, p.ac, p.hi)
                return true
            }
            let u = easeOut(win(f.t, 0.2, 1))
            fade(c, 1 - win(f.t, 0.4, 1)) {
                pentagram(c, f.x, f.y - 4, 6 + r * 0.5 * u, u, p.ac)
                circle(c, f.x, f.y, r * u, p.lt, squash: 0.5)
                star(c, f.x, f.y - 4, Int(6 * (1 - u)) + 1, p.ac, p.hi)
            }
            fall(c, f.x, f.y, 8, r * 0.7, 24, win(f.t, 0.2, 1), seed: f.seed, Tones(p.hi, p.ac, p.lt), sway: 1)
            return true
        default: return false
        }
    }

    /// 화살비 (폭풍 사수): a wind spiral marks the ground; arrows corkscrew down into it and kick up a little twister.
    private static func windMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.4 + 0.5 * f.t) {
            for k in 0..<3 { let a = f.age * 4 + Double(k) * 2.09; circle(c, f.x, f.y, r * easeOut(f.t) * (0.5 + Double(k) * 0.22), windRainPal.lt, squash: 0.5, from: a, to: a + 2.4) }
        }
        return true
    }

    private static func windVolley(_ c: CGContext, _ f: FXF) -> Bool {
        let p = windRainPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.25 {
                let u = f.t / 0.25
                for j in 0..<3 {
                    let a = Double(j) * 2.09 + u * 8, rad = 14 * (1 - u), h = 46 * (1 - u)
                    let hx = f.x + cos(a) * rad, hy = f.y - h + sin(a) * rad * 0.5
                    seg(c, hx, hy - 8, hx, hy, woodPal.lt); px(c, hx, hy + 1, p.hi)
                    fade(c, 0.6) { seg(c, hx - 1, hy - 14, hx, hy - 8, p.lt) }
                }
                return true
            }
            let u = win(f.t, 0.25, 1)
            fade(c, 1 - u) {
                for k in 0..<4 { let a = f.age * 14 + Double(k); circle(c, f.x, f.y - Double(k) * 5 * u * 2, 4 + Double(k) * 3 + u * 4, p.lt, squash: 0.4, from: a, to: a + 3.5) }
                circle(c, f.x, f.y, r * easeOut(u), p.md, squash: 0.5)
            }
            fling(c, f.x, f.y, 6, 60, u, seed: f.seed, Tones(p.md, p.lt, forestPal.md), spread: .pi, gravity: 30, size: 2)
            return true
        default: return false
        }
    }

    /// 독화살 난사: violet arrows trailing a sickly haze.
    private static func hazeArrow(_ c: CGContext, _ s: ShotF) {
        let p = hazePal
        fade(c, 0.35) { for k in 1...4 { ellipse(c, s.x - s.ux * Double(k) * 5, s.y - s.uy * Double(k) * 5 - Double(k) * 0.5, 1.5 + Double(k) * 0.6, k % 2 == 0 ? p.md : p.ac) } }
        arrowBody(c, s, p, shaft: p.dk, fletch: p.ac, len: 10)
    }

    private static func hazeHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = hazePal, u = easeOut(f.t)
        fade(c, 0.7 * (1 - win(f.t, 0.3, 1))) {
            puff(c, f.x - 3, f.y - 3 - u * 4, 3 + u * 4, p.lt, p.md)
            puff(c, f.x + 3, f.y - 1 - u * 3, 2 + u * 3, p.md, p.dk)
        }
        rise(c, f.x, f.y, 4, 5, 10, f.t, seed: f.seed, Tones(p.ac, p.lt))
        return true
    }

    /// 태풍 사격: arrows weaving along a sine path inside teal swirling ribbons.
    private static func typhoonArrow(_ c: CGContext, _ s: ShotF) {
        let p = typhoonPal, nx = -s.uy, ny = s.ux, d = flown(s)
        let off = sin(d / 9 + Double(s.seq)) * 3
        for k in 0..<14 {
            let back = Double(k) * 1.8, o = sin((d - back) / 9 + Double(s.seq)) * 3
            fade(c, 0.9 - Double(k) * 0.06) { px(c, s.x - s.ux * back + nx * (o + 2.5 * sin(Double(k) * 0.9)), s.y - s.uy * back + ny * (o + 2.5 * sin(Double(k) * 0.9)), k < 5 ? p.hi : p.lt) }
        }
        let moved = ShotF(x: s.x + nx * off, y: s.y + ny * off, ux: s.ux, uy: s.uy, speed: s.speed, now: s.now, ox: s.ox, oy: s.oy, seq: s.seq, seed: s.seed, kind: s.kind, el: s.el, pal: s.pal)
        arrowBody(c, moved, p, shaft: woodPal.lt, fletch: p.md, len: 9)
    }

    private static func swirlHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, u = easeOut(f.t)
        fade(c, 1 - win(f.t, 0.4, 1)) {
            for k in 0..<3 { let a = f.age * 18 + Double(k) * 2.1; circle(c, f.x, f.y - Double(k) * 3, 3 + Double(k) * 2 + u * 3, p.lt, squash: 0.5, from: a, to: a + 3) }
        }
        return true
    }

    /// 숲의 심판: a leaf rune on the ground, thorned vines bursting up through it, leaves flying.
    private static func forestRing(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.seq % 3 == 0 else { return true }
        let p = forestPal
        fade(c, 0.6 * (1 - win(f.t, 0.6, 1))) {
            circle(c, f.x, f.y, f.r, p.md, squash: 0.5)
            circle(c, f.x, f.y, f.r * 0.8, p.lt, squash: 0.5, dash: 3)
            for i in 0..<8 { let a = Double(i) * .pi / 4 + Double(f.seq); px(c, f.x + cos(a) * f.r * 0.9, f.y + sin(a) * f.r * 0.45, p.hi, 2) }
        }
        return true
    }

    private static func forestVines(_ c: CGContext, _ f: FXF) -> Bool {
        let p = forestPal
        var r = KartRNG(seed: f.seed)
        let h = punch(f.t, at: 0.25, hold: 0.25)
        for _ in 0..<6 {
            let a = Double(r.int(628)) / 100, d = f.r * 0.85 * sqrt(Double(r.int(100)) / 100)
            let vx = f.x + cos(a) * d, vy = f.y + sin(a) * d * 0.5
            fade(c, 0.5 * h) { crack(c, vx - 4, vy, 0, 8, earthPal, seed: f.seed &+ UInt64(truncatingIfNeeded: Int(vx)), glow: 0.2) }
            vine(c, vx, vy, (16 + Double(r.int(12))) * h, (Double(r.int(3)) - 1) * 2, p)
        }
        fling(c, f.x, f.y, 6, 50, f.t, seed: f.seed &+ 1, Tones(p.lt, p.md), spread: .pi, gravity: 20, size: 2)
        return true
    }

    /// A thorned vine `h` px tall bending by `lean`.
    static func vine(_ c: CGContext, _ x: Double, _ y: Double, _ h: Double, _ lean: Double, _ p: FXPal) {
        let n = Int(h)
        guard n > 1 else { return }
        for i in 0..<n {
            let u = Double(i) / Double(n), w = max(1, (5 * (1 - u)).rounded())
            let vx = x + lean * u * u * 3
            box(c, vx - w / 2 - 1, y - Double(i), w + 2, 1, p.dk)
            box(c, vx - w / 2, y - Double(i), w, 1, u < 0.45 ? p.ac : p.md)
            if i % 3 == 1 {
                let side = i % 6 == 1 ? 1.0 : -1.0
                px(c, vx + side * (w / 2 + 1), y - Double(i), p.lt); px(c, vx + side * (w / 2 + 2), y - Double(i) - 1, p.hi)
            }
        }
        px(c, x + lean * 3, y - h, p.hi)
    }
}

// MARK: - mage

extension RpgArt {
    static let arcanePal = FXPal(0xFFFFFF, 0xE6D2FF, 0xA87CFF, 0x4A2A9A, 0x8AF0FF)
    static let chainPal = FXPal(0xFFFFFF, 0xE8D8FF, 0xA87CFF, 0x3A1A8A, 0xFFF06A)
    static let blinkPal = FXPal(0xFFFFFF, 0xE0C8FF, 0x9A6AFF, 0x3A1A7A, 0x6AE8FF)
    static let manaPal = FXPal(0xFFFFFF, 0xB0E8FF, 0x4A9AFF, 0x1A3A9A, 0xA0FFFF)
    static let blizzardPal = FXPal(0xFFFFFF, 0xE0F4FF, 0x9ACCEE, 0x4A6A9A, 0xC8E8FF)
    static let pillarPal = FXPal(0xFFFFE0, 0xFFE070, 0xFF8A20, 0xA02A10, 0xFFFFFF)
    static let mHealPal = FXPal(0xFFFFFF, 0xC8FFB0, 0x6AD860, 0x2A7A3A, 0xFFF0A0)
    static let meteorPal = FXPal(0xFFFFE0, 0xFFC050, 0xF05A20, 0x5A2A1A, 0x8A6A5A)
    static let hellPal = FXPal(0xFFE0A0, 0xFF6A2A, 0xB01A10, 0x2A0808, 0x6A2AA0)
    static let firestormPal = FXPal(0xFFFFF0, 0xFFE89A, 0xFFA030, 0xC04A10, 0xFF6A6A)
    static let frostPal = FXPal(0xFFFFFF, 0xD8F4FF, 0x7AC8F8, 0x2A5A9A, 0xFFFFFF)
    static let glacierPal = FXPal(0xFFFFFF, 0xB8ECFF, 0x4AA8E0, 0x1A4A8A, 0xE0FFFF)
    static let lavaPal = FXPal(0xFFF4A0, 0xFFB030, 0xE04A10, 0x3A1A10, 0xFF7A2A)
    static let fireOrbPal = FXPal(0xFFFFE8, 0xFFD060, 0xFF7A1A, 0x9A2A0A, 0xFFF0C0)
    static let swarmPal = FXPal(0xFFFFFF, 0xFFE0A0, 0xFF9040, 0x7A2A10, 0xFFCFCF)
    static let sunPal = FXPal(0xFFFFFF, 0xFFFAB0, 0xFFC830, 0xE0601A, 0xFFFFE0)
    static let vortexPal = FXPal(0xFFFFFF, 0xE8F8FF, 0xA8D8F0, 0x5A8AB0, 0xFFFFFF)
    static let icebergPal = FXPal(0xFFFFFF, 0xC8F0FF, 0x6AB8E8, 0x2A5A90, 0xE8FFFF)
    static let zeroPal = FXPal(0xFFFFFF, 0xF0FAFF, 0xB0DCF8, 0x3A6AA8, 0x9AF0FF)
    static let iceSpearPal = FXPal(0xFFFFFF, 0xD0F4FF, 0x7AC0F0, 0x2A5A9A, 0xFFFFFF)

    static let plusGrid: RpgGrid = ["..kkk..", "..klk..", "kkklkkk", "kllhllk", "kkklkkk", "..klk..", "..kkk.."]
    static let icebergGrid: RpgGrid = [
        "....kkk.....", "...khhlk....", "..khhllmk...", ".khhllllmk..", "khhlllllmmk.", "klllllllmmmk", "kllllllmmmdk", ".kmlllmmmdk.", "..kmmmmddk..", "...kkkkkk...",
    ]

    static let mageLooks: [String: FXLook] = [
        "m_blast": FXLook(pal: arcanePal, draw: elementBlast, floor: blastRune),
        "m_chain": FXLook(pal: chainPal, draw: arcaneChain),
        "m_blink": FXLook(pal: blinkPal, draw: blink),
        "m_shield": FXLook(pal: manaPal, draw: manaShield),
        "m_blizzard": FXLook(pal: blizzardPal, draw: blizzard, floor: frostPatch),
        "m_pillar": FXLook(pal: pillarPal, draw: firePillar, floor: magmaRing),
        "m_heal": FXLook(pal: mHealPal, draw: natureHeal),
        "m_ult": FXLook(pal: meteorPal, draw: meteorStorm, floor: meteorMark),
        "j_inferno": FXLook(pal: hellPal, draw: hellfire, floor: scorch),
        "j_firestorm": FXLook(pal: firestormPal, draw: fireComet, floor: emberSpiral),
        "j_frost": FXLook(pal: frostPal, draw: frostWave, floor: frostGround),
        "j_glacier": FXLook(pal: glacierPal, draw: glacier),
        "t2_ma1a": FXLook(pal: lavaPal, draw: lavaGeyser, floor: lavaPool),
        "t2_ma1b": FXLook(pal: fireOrbPal, draw: fireSphere, floor: sphereShadow),
        "t3_ma1a": FXLook(pal: swarmPal, draw: meteorSwarm, floor: swarmMark),
        "t3_ma1b": FXLook(pal: sunPal, draw: solarBurst),
        "t2_ma2a": FXLook(pal: vortexPal, draw: snowVortex),
        "t2_ma2b": FXLook(pal: icebergPal, draw: icebergDrop, floor: icebergShadow),
        "t3_ma2a": FXLook(pal: zeroPal, draw: absoluteZero, floor: frostLattice),
        "t3_ma2b": FXLook(pal: iceSpearPal, hit: shatterHit, shot: iceSpear),
    ]

    /// A magic circle: two rings, an inscribed hexagram and six glowing nodes.
    static func runeCircle(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ rot: Double, _ p: FXPal, squash: Double = 0.5) {
        guard r > 2 else { return }
        circle(c, x, y, r, p.lt, squash: squash)
        circle(c, x, y, r * 0.8, p.md, squash: squash)
        poly(c, x, y, r * 0.8, 3, rot, p.lt, squash: squash)
        poly(c, x, y, r * 0.8, 3, rot + .pi, p.lt, squash: squash)
        for i in 0..<6 { let a = rot + Double(i) * .pi / 3 + .pi / 6; px(c, x + cos(a) * r * 0.9, y + sin(a) * r * 0.9 * squash, p.hi, 2) }
    }

    /// A six-armed snowflake.
    static func flake(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ col: CGColor, _ tip: CGColor) {
        for i in 0..<3 {
            let a = Double(i) * .pi / 3
            seg(c, x - cos(a) * r, y - sin(a) * r, x + cos(a) * r, y + sin(a) * r, col)
        }
        if r >= 3 { for i in 0..<6 { let a = Double(i) * .pi / 3; px(c, x + cos(a) * r, y + sin(a) * r, tip) } }
    }

    /// A block of ice rising out of the ground: lit top, light face, shaded side.
    static func iceBlock(_ c: CGContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ p: FXPal) {
        guard h > 1 else { return }
        box(c, x - w / 2 - 1, y - h - 3, w + 5, h + 4, p.dk)
        box(c, x - w / 2, y - h, w, h, p.lt)
        box(c, x + w / 2, y - h - 1, 3, h, p.md)
        box(c, x - w / 2 + 1, y - h - 2, w + 1, 2, p.hi)
        seg(c, x - w / 2 + 2, y - h + 2, x - w / 2 + 2, y - 2, p.hi)
    }

    /// 원소 폭발: a magic circle flashes on the ground, then the weapon's element bursts out of it.
    private static func blastRune(_ c: CGContext, _ f: FXF) -> Bool {
        let u = easeOut(win(f.t, 0, 0.25))
        fade(c, 1 - win(f.t, 0.55, 0.95)) { runeCircle(c, f.x, f.y, f.r * 0.95 * u, f.age * 3, arcanePal) }
        return true
    }

    private static func elementBlast(_ c: CGContext, _ f: FXF) -> Bool {
        let e = f.el == .base ? RpgElement.cosmic : f.el
        let p = elemPal(e), u = easeOut(win(f.t, 0.12, 1)), k = 1 - win(f.t, 0.55, 1)
        switch e {
        case .fire:
            fade(c, k) {
                glow(c, f.x, f.y - 6, f.r * u, p.lt)
                for i in 0..<8 { let a = Double(i) * .pi / 4 + 0.2; spike(c, f.x, f.y - 5, a, f.r * 0.75 * u, p.md, 4, squash: 0.7); spike(c, f.x, f.y - 5, a, f.r * 0.5 * u, p.lt, 2, squash: 0.7) }
                shock(c, f.x, f.y, f.r * u, 2, p, squash: 0.5)
            }
            rise(c, f.x, f.y, 10, f.r * 0.6, 20, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md, p.dk), size: 2)
        case .ice:
            fade(c, k) {
                for i in 0..<6 {
                    let a = Double(i) * .pi / 3 + 0.3, d = f.r * 0.7 * u
                    let sx = f.x + cos(a) * d, sy = f.y - 6 + sin(a) * d * 0.6
                    poly(c, sx, sy, 3, 4, a, p.lt); px(c, sx, sy, p.hi, 2)
                }
                circle(c, f.x, f.y, f.r * u, p.lt, squash: 0.5)
                flake(c, f.x, f.y - 6, 6 * (1 - u) + 2, p.hi, p.lt)
            }
            fall(c, f.x, f.y, 8, f.r * 0.7, 18, f.t, seed: f.seed, Tones(p.hi, p.lt))
        case .thunder:
            if f.t < 0.4, Int(f.age * 30) % 3 != 1 { zap(c, f.x, f.y - 80, f.x, f.y - 4, p, seed: f.seed &+ UInt64(truncatingIfNeeded: Int(f.age * 30)), jag: 4, w: 3, branches: 1) }
            fade(c, k) {
                shock(c, f.x, f.y, f.r * u, 2, p, squash: 0.5)
                for i in 0..<6 { let a = Double(i) * 1.05 + f.age * 8; zap(c, f.x, f.y - 3, f.x + cos(a) * f.r * 0.7 * u, f.y + sin(a) * f.r * 0.35 * u, p, seed: f.seed &+ UInt64(i), jag: 2, w: 1, branches: 0) }
            }
        default:
            // Arcane (and the other elements): a ring collapses into a turning star, then bursts.
            let pull = f.t < 0.3
            fade(c, k) {
                if pull { circle(c, f.x, f.y - 6, f.r * (1 - f.t / 0.3) + 3, p.lt, squash: 0.6) }
                else { shock(c, f.x, f.y, f.r * u, 3, p, squash: 0.5) }
                let s = pull ? 4 + 8 * f.t / 0.3 : 12 * (1 - u) + 3
                rays(c, f.x, f.y - 6, 8, s, f.age * 4, p, squash: 0.8)
            }
            spice(c, f.x, f.y - 6, f.r * 0.6, e, f.t, seed: f.seed, n: 8)
        }
        return true
    }

    /// 연쇄 마법: the arcane bolt reaches from foe to foe in turn, a sigil flaring on each.
    private static func arcaneChain(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .chain(let pts) = f.kind, pts.count > 1 else { return false }
        let p = f.el == .thunder ? chainPal : elemPal(f.el)
        for k in 0..<(pts.count - 1) {
            let on = Double(k) * 0.12
            let reach = win(f.age, on, on + 0.06), live = f.age - on
            guard reach > 0, live < 0.5 else { continue }
            let a = pts[k], b = pts[k + 1]
            let ex = Double(a.x + (b.x - a.x) * reach), ey = Double(a.y + (b.y - a.y) * reach)
            let k2 = 1 - win(live, 0.3, 0.5)
            fade(c, 0.35 * k2) { seg(c, Double(a.x), Double(a.y), ex, ey, p.md, 4) }
            if Int(f.age * 30) % 4 != 3 { fade(c, k2) { zap(c, Double(a.x), Double(a.y), ex, ey, p, seed: f.seed &+ UInt64(truncatingIfNeeded: k * 7 + Int(f.age * 24)), jag: 4, w: 3, branches: 1) } }
            if reach >= 1 {
                let s = 7 * punch(win(live, 0.06, 0.5), at: 0.2, hold: 0.3)
                glow(c, Double(b.x), Double(b.y), s + 4, p.lt, 0.8)
                poly(c, Double(b.x), Double(b.y), s, 4, f.age * 6, p.lt)
                poly(c, Double(b.x), Double(b.y), s * 0.6, 4, -f.age * 6, p.hi)
                star(c, Double(b.x), Double(b.y), Int(s / 2), p.ac, p.hi)
            }
        }
        return true
    }

    /// 순간이동: the spot left behind sucks in and bursts; a slit of light opens where the mage lands.
    private static func blink(_ c: CGContext, _ f: FXF) -> Bool {
        let p = blinkPal
        switch f.kind {
        case .burst(let r):
            if f.t < 0.35 {
                let q = 1 - f.t / 0.35
                for i in 0..<12 {
                    let a = Double(i) / 12 * 2 * .pi + f.t * 9
                    px(c, f.x + cos(a) * r * q, f.y - 8 + sin(a) * r * q * 0.6, i % 2 == 0 ? p.lt : p.ac, 2)
                }
                ellipse(c, f.x, f.y - 9, 2 + 4 * q, p.md, squash: 2.2)
                ellipse(c, f.x, f.y - 9, 1 + 2 * q, p.hi, squash: 2.2)
            } else {
                let v = easeOut(win(f.t, 0.35, 1))
                fade(c, 1 - v) { shock(c, f.x, f.y, r * v, 2, p, squash: 0.5); rays(c, f.x, f.y - 8, 8, 12 * v + 3, 0, p) }
            }
            return true
        case .levelUp:
            let o = punch(f.t, at: 0.25, hold: 0.15)
            fade(c, o) {
                ellipse(c, f.x, f.y - 11, 2 + 4 * o, p.md, squash: 3)
                box(c, f.x, f.y - 28, 1, 30, p.hi)
            }
            fall(c, f.x, f.y, 10, 9, 22, f.t, seed: f.seed, Tones(p.hi, p.ac, p.lt), sway: 1)
            return true
        default: return false
        }
    }

    /// 마나 실드: a lattice of blue hexagons domes up over the mage while mana motes rise.
    private static func manaShield(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = manaPal, up = easeOut(win(f.t, 0, 0.4)), k = 1 - win(f.t, 0.7, 1)
        let top = f.y - 28 * up
        fade(c, 0.22 * k) { ellipse(c, f.x, (f.y + top) / 2 + 2, 15, p.md, squash: max(0.2, (f.y - top) / 30)) }
        fade(c, k) {
            for row in 0..<4 {
                let ry = f.y - 2 - Double(row) * 7
                guard ry > top else { continue }
                let half = 14 * sqrt(max(0, 1 - pow((f.y - ry) / 29, 2)))
                var hx = f.x - half + Double(row % 2) * 3.5
                while hx <= f.x + half { poly(c, hx, ry, 3, 6, 0, row % 2 == 0 ? p.lt : p.ac, squash: 0.8); hx += 7 }
            }
            circle(c, f.x, f.y, 15, p.hi, squash: 0.35)
        }
        rise(c, f.x, f.y, 8, 12, 26, f.t, seed: f.seed, Tones(p.hi, p.ac, p.lt))
        return true
    }

    /// 블리자드: wind-driven snow slanting across the area under a frost cloud.
    private static func blizzard(_ c: CGContext, _ f: FXF) -> Bool {
        let p = blizzardPal
        var r = KartRNG(seed: f.seed)
        fade(c, punch(f.t, at: 0.2, hold: 0.5)) {
            for i in 0..<16 {
                let sx = f.x - f.r + Double(r.int(Int(f.r * 2))), sy = f.y - f.r * 0.5 + Double(r.int(Int(f.r)))
                let drift = (f.now * 90 + Double(i) * 13).truncatingRemainder(dividingBy: 24) - 12
                seg(c, sx + drift, sy - 14 + drift * 0.5, sx + drift + 5, sy - 11 + drift * 0.5, i % 3 == 0 ? p.hi : p.lt)
            }
            for j in 0..<4 { puff(c, f.x - 18 + Double(j) * 12, f.y - 36 + sin(f.now * 2 + Double(j)) * 2, 6, p.lt, p.md) }
        }
        fall(c, f.x, f.y, 10, f.r, 30, f.t, seed: f.seed &+ 5, Tones(p.hi, p.lt), sway: 3)
        return true
    }

    private static func frostPatch(_ c: CGContext, _ f: FXF) -> Bool {
        fade(c, 0.25 * punch(f.t, at: 0.3, hold: 0.4)) { ellipse(c, f.x, f.y, f.r, blizzardPal.lt, squash: 0.5) }
        return true
    }

    /// 화염 기둥: columns of fire erupt one after another, each from a ring of magma.
    private static func firePillar(_ c: CGContext, _ f: FXF) -> Bool {
        let p = pillarPal, h = 34 * punch(f.t, at: 0.15, hold: 0.3)
        fade(c, 1 - win(f.t, 0.75, 1)) {
            glow(c, f.x, f.y - h / 2, 10, p.md, 0.6, squash: 1.6)
            flame(c, f.x - 3, f.y + 1, h * 0.6, 5, p, phase: f.age * 30 + 1)
            flame(c, f.x + 3, f.y + 1, h * 0.7, 5, p, phase: f.age * 28 + 2)
            flame(c, f.x, f.y, h, 9, p, phase: f.age * 24 + Double(f.seq))
        }
        rise(c, f.x, f.y - h * 0.6, 6, 5, 18, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md))
        return true
    }

    private static func magmaRing(_ c: CGContext, _ f: FXF) -> Bool {
        fade(c, 1 - win(f.t, 0.6, 1)) {
            ellipse(c, f.x, f.y, 8, pillarPal.dk, squash: 0.45)
            circle(c, f.x, f.y, 8, pillarPal.md, squash: 0.45)
            circle(c, f.x, f.y, 5, pillarPal.lt, squash: 0.45, dash: 2)
        }
        return true
    }

    /// 치유: leaves spiral up around each ally and a big green plus rises.
    private static func natureHeal(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = mHealPal
        fade(c, 1 - win(f.t, 0.7, 1)) { circle(c, f.x, f.y, 6 + 9 * easeOut(f.t), p.lt, squash: 0.4); glow(c, f.x, f.y - 10, 12, p.lt, 0.5) }
        for i in 0..<8 {
            let u = win(f.t, Double(i) * 0.05, Double(i) * 0.05 + 0.6)
            guard u > 0, u < 1 else { continue }
            let a = Double(i) * 0.8 + u * 7, lx = f.x + cos(a) * 10 * (1 - u * 0.4), ly = f.y - 2 - u * 26 + sin(a) * 3
            fade(c, 1 - u * u) { px(c, lx, ly, p.md, 2); px(c, lx + 1, ly - 1, p.lt) }
        }
        fade(c, punch(f.t, at: 0.3, hold: 0.3)) { glyph(c, "plus", plusGrid, p, f.x, f.y - 32 - f.t * 6) }
        return true
    }

    /// 메테오 스톰: a shadow grows inside a burning target ring; a blazing rock streaks down and leaves a molten crater.
    private static func meteorMark(_ c: CGContext, _ f: FXF) -> Bool {
        let p = meteorPal
        switch f.kind {
        case .telegraph(let r):
            fade(c, 0.15 + 0.3 * f.t) { ellipse(c, f.x, f.y, r * 0.7 * easeOut(f.t), outline, squash: 0.5) }
            fade(c, 0.5 + 0.5 * f.t) {
                circle(c, f.x, f.y, r, p.md, squash: 0.5, dash: 2)
                circle(c, f.x, f.y, r * (1 - f.t) + 2, p.lt, squash: 0.5)
            }
        case .meteor(let r):
            guard f.t > 0.25 else { break }
            fade(c, 1 - win(f.t, 0.6, 1)) {
                ellipse(c, f.x, f.y, r * 0.45, outline, squash: 0.5)
                for i in 0..<6 { crack(c, f.x, f.y, Double(i) * 1.05, r * 0.6, p, seed: f.seed &+ UInt64(i), glow: 1 - f.t) }
            }
        default: break
        }
        return true
    }

    private static func meteorStorm(_ c: CGContext, _ f: FXF) -> Bool {
        let p = meteorPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.25 {
                let u = easeIn(f.t / 0.25), hx = f.x + 60 * (1 - u), hy = f.y - 90 * (1 - u)
                for k in 0..<14 { let q = Double(k) * 3; fade(c, 1 - Double(k) / 14) { px(c, hx + q * 0.55, hy - q * 0.85, k < 3 ? p.hi : (k < 7 ? p.lt : p.md), k < 6 ? 3 : 2) } }
                glow(c, hx, hy, 9, p.lt)
                ellipse(c, hx, hy, 4, p.dk); ellipse(c, hx - 1, hy - 1, 2.6, p.ac); px(c, hx - 2, hy - 2, p.lt)
                return true
            }
            let u = easeOut(win(f.t, 0.25, 1))
            if u < 0.3 { glow(c, f.x, f.y - 6, r, p.hi, 1 - u / 0.3, squash: 0.7) }
            fade(c, 1 - win(f.t, 0.55, 1)) { shock(c, f.x, f.y, r * u, 3, p, squash: 0.5) }
            fling(c, f.x, f.y, 10, 110, win(f.t, 0.25, 1), seed: f.seed, Tones(p.lt, p.md, p.ac), spread: 0.8, gravity: 260, size: 2)
            fade(c, 0.6 * (1 - u)) { for k in 0..<3 { puff(c, f.x - 6 + Double(k) * 6, f.y - 8 - u * 16 - Double(k % 2) * 4, 4 + u * 6, smokePal.md, smokePal.dk) } }
            return true
        default: return false
        }
    }

    /// 지옥불: geysers of dark hellfire with black smoke.
    private static func hellfire(_ c: CGContext, _ f: FXF) -> Bool {
        let p = hellPal, h = 28 * punch(f.t, at: 0.15, hold: 0.25)
        fade(c, 1 - win(f.t, 0.7, 1)) {
            glow(c, f.x, f.y - 8, f.r * 0.6, p.md, 0.6, squash: 0.8)
            flame(c, f.x - 6, f.y + 1, h * 0.6, 5, p, phase: f.age * 26)
            flame(c, f.x + 6, f.y + 1, h * 0.65, 5, p, phase: f.age * 22 + 3)
            flame(c, f.x, f.y, h, 8, p, phase: f.age * 24 + 1)
            shock(c, f.x, f.y, f.r * easeOut(f.t), 2, p, squash: 0.5)
        }
        fade(c, 0.6 * win(f.t, 0.2, 0.5) * (1 - win(f.t, 0.7, 1))) { for k in 0..<3 { puff(c, f.x - 6 + Double(k) * 6, f.y - h - 4 - f.t * 10, 4, p.ac, outline) } }
        return true
    }

    /// 화염 폭풍: an ember spiral marks the spot; a ball of flame drops and spins up a fire twister.
    private static func emberSpiral(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = firestormPal
        fade(c, 0.4 + 0.5 * f.t) {
            for i in 0..<18 {
                let u = Double(i) / 18, a = u * 4 * .pi + f.age * 3, d = r * u * easeOut(f.t)
                px(c, f.x + cos(a) * d, f.y + sin(a) * d * 0.5, i % 3 == 0 ? p.lt : p.md)
            }
        }
        return true
    }

    private static func fireComet(_ c: CGContext, _ f: FXF) -> Bool {
        let p = firestormPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.22 {
                let u = easeIn(f.t / 0.22), hx = f.x - 20 * (1 - u), hy = f.y - 80 * (1 - u)
                for k in 0..<12 {
                    let q = Double(k) * 3, a = Double(k) * 0.9 + f.age * 30
                    px(c, hx - q * 0.25 + cos(a) * 3, hy - q + sin(a) * 1.5, k < 4 ? p.hi : p.lt, 2)
                }
                glow(c, hx, hy, 8, p.lt)
                flame(c, hx, hy + 3, 9, 6, p, phase: f.age * 40)
                return true
            }
            let u = easeOut(win(f.t, 0.22, 1)), k = 1 - win(f.t, 0.6, 1)
            fade(c, k) {
                for j in 0..<4 {
                    let a = f.age * 16 + Double(j) * 1.6, ry = f.y - Double(j) * 7 * u
                    circle(c, f.x, ry, r * 0.4 * (1 - Double(j) * 0.15), j % 2 == 0 ? p.lt : p.md, squash: 0.35, from: a, to: a + 4)
                    flame(c, f.x + cos(a) * r * 0.35, ry + 2, 6 + Double(j), 3, p, phase: f.age * 30 + Double(j))
                }
            }
            rise(c, f.x, f.y, 10, r * 0.4, 30, win(f.t, 0.22, 1), seed: f.seed, Tones(p.hi, p.lt, p.md, p.dk), size: 2)
            return true
        default: return false
        }
    }

    /// 서리 파동: a frost ring rolls out with snowflakes along it and leaves the ground frozen.
    private static func frostGround(_ c: CGContext, _ f: FXF) -> Bool {
        let p = frostPal, u = easeOut(f.t)
        fade(c, 0.35 * (1 - win(f.t, 0.6, 1))) { ellipse(c, f.x, f.y, f.r * u, p.lt, squash: 0.5) }
        fade(c, 0.7 * (1 - win(f.t, 0.6, 1))) { for i in 0..<6 { crack(c, f.x, f.y, Double(i) * 1.05 + 0.4, f.r * u * 0.8, p, seed: f.seed &+ UInt64(i), glow: 0.8) } }
        return true
    }

    private static func frostWave(_ c: CGContext, _ f: FXF) -> Bool {
        let p = frostPal, u = easeOut(f.t), r = f.r * u
        if f.t < 0.15 { glow(c, f.x, f.y - 6, 16, p.hi, 1 - f.t / 0.15) }
        fade(c, 1 - win(f.t, 0.6, 1)) {
            shock(c, f.x, f.y, r, 3, p, squash: 0.5)
            for i in 0..<10 { let a = Double(i) / 10 * 2 * .pi; flake(c, f.x + cos(a) * r, f.y + sin(a) * r * 0.5 - 2, 3, p.lt, p.hi) }
        }
        return true
    }

    /// 빙하: great blocks of ice heave up out of the ground and sink back in mist.
    private static func glacier(_ c: CGContext, _ f: FXF) -> Bool {
        let p = glacierPal
        var r = KartRNG(seed: f.seed)
        let h = punch(f.t, at: 0.2, hold: 0.4)
        for _ in 0..<3 {
            let a = Double(r.int(628)) / 100, d = f.r * 0.7 * sqrt(Double(r.int(100)) / 100)
            let bx = f.x + cos(a) * d, by = f.y + sin(a) * d * 0.5
            let w = 7 + Double(r.int(5)), tall = (10 + Double(r.int(10))) * h
            iceBlock(c, bx, by, w, tall, p)
            fade(c, 0.5 * h) { puff(c, bx, by + 1, 4, p.hi, p.lt) }
        }
        return true
    }

    /// 용암 분출: lava blobs geyser up and splash back into a crusted pool.
    private static func lavaPool(_ c: CGContext, _ f: FXF) -> Bool {
        let p = lavaPal
        fade(c, 1 - win(f.t, 0.65, 1)) { ellipse(c, f.x, f.y, 9, p.dk, squash: 0.45); ellipse(c, f.x, f.y, 6, p.md, squash: 0.45); ellipse(c, f.x - 1, f.y - 1, 3, p.lt, squash: 0.45) }
        return true
    }

    private static func lavaGeyser(_ c: CGContext, _ f: FXF) -> Bool {
        let p = lavaPal
        fade(c, 1 - win(f.t, 0.5, 1)) { flame(c, f.x, f.y, 16 * punch(f.t, at: 0.12, hold: 0.15), 7, p, phase: f.age * 20) }
        fling(c, f.x, f.y - 4, 7, 110, f.t, seed: f.seed, Tones(p.lt, p.md, p.ac), spread: 0.45, gravity: 360, size: 3)
        return true
    }

    /// 화염 구체: a swirling sphere of fire sinks onto its shadow and bursts into a ring of flames.
    private static func sphereShadow(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = fireOrbPal
        glow(c, f.x, f.y, r * 0.6 * easeOut(f.t), p.md, 0.5 + 0.4 * f.t, squash: 0.5)
        fade(c, 0.5 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.7, p.lt, squash: 0.5)
            for i in 0..<6 { let a = Double(i) * 1.05 + f.age * 2; px(c, f.x + cos(a) * r * 0.7, f.y + sin(a) * r * 0.35, p.hi, 2) }
        }
        return true
    }

    private static func fireSphere(_ c: CGContext, _ f: FXF) -> Bool {
        let p = fireOrbPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.3 {
                let u = easeIn(f.t / 0.3), cy = f.y - 8 - 80 * (1 - u)
                glow(c, f.x, cy, 12, p.lt)
                ellipse(c, f.x, cy, 6, p.md); ellipse(c, f.x, cy, 4.5, p.lt)
                for j in 0..<3 { let a = f.age * 14 + Double(j) * 2.1; circle(c, f.x, cy, 5, p.hi, from: a, to: a + 1.2) }
                px(c, f.x - 2, cy - 2, p.hi, 2)
                return true
            }
            let u = easeOut(win(f.t, 0.3, 1)), k = 1 - win(f.t, 0.65, 1)
            fade(c, k) {
                for i in 0..<10 {
                    let a = Double(i) / 10 * 2 * .pi
                    flame(c, f.x + cos(a) * r * 0.75 * u, f.y + sin(a) * r * 0.37 * u + 1, 9 * (1 - u * 0.5), 4, p, phase: f.age * 30 + Double(i))
                }
                shock(c, f.x, f.y, r * u, 2, p, squash: 0.5)
            }
            return true
        default: return false
        }
    }

    /// 메테오 스웜: small white-hot meteors streak in fast and parallel, each punching a glowing pit.
    private static func swarmMark(_ c: CGContext, _ f: FXF) -> Bool {
        let p = swarmPal
        switch f.kind {
        case .telegraph(let r):
            fade(c, 0.3 + 0.6 * f.t) { let s = 4.0; seg(c, f.x - s, f.y - s * 0.5, f.x + s, f.y + s * 0.5, p.md); seg(c, f.x - s, f.y + s * 0.5, f.x + s, f.y - s * 0.5, p.md); circle(c, f.x, f.y, r * 0.5, p.dk, squash: 0.5, dash: 2) }
        case .meteor:
            guard f.t > 0.15 else { break }
            fade(c, 1 - win(f.t, 0.5, 1)) { ellipse(c, f.x, f.y, 6, p.dk, squash: 0.5); circle(c, f.x, f.y, 6, p.md, squash: 0.5) }
        default: break
        }
        return true
    }

    private static func meteorSwarm(_ c: CGContext, _ f: FXF) -> Bool {
        let p = swarmPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.15 {
                let u = f.t / 0.15, hx = f.x - 70 * (1 - u), hy = f.y - 70 * (1 - u)
                seg(c, hx - 18, hy - 18, hx, hy, p.md, 1); seg(c, hx - 10, hy - 10, hx, hy, p.lt, 2)
                px(c, hx, hy, p.hi, 3)
                return true
            }
            let u = easeOut(win(f.t, 0.15, 1))
            fade(c, 1 - u) { shock(c, f.x, f.y, r * 0.6 * u, 2, p, squash: 0.5); star(c, f.x, f.y - 3, Int(5 * (1 - u)) + 1, p.lt, p.hi) }
            fling(c, f.x, f.y, 8, 80, win(f.t, 0.15, 1), seed: f.seed, Tones(p.hi, p.lt, p.md), spread: 0.9, gravity: 200)
            return true
        default: return false
        }
    }

    /// 태양 폭발: a little sun flares over the mage, corona spinning, and its light rolls out over the ground.
    private static func solarBurst(_ c: CGContext, _ f: FXF) -> Bool {
        let p = sunPal, u = easeOut(f.t), k = 1 - win(f.t, 0.6, 1)
        let sy = f.y - 34
        fade(c, k) {
            glow(c, f.x, sy, 18, p.lt)
            for i in 0..<12 { let a = Double(i) / 12 * 2 * .pi + f.now * 1.5 + Double(f.seq); spike(c, f.x + cos(a) * 8, sy + sin(a) * 8, a, i % 2 == 0 ? 9 : 5, p.md, 2) }
            ellipse(c, f.x, sy, 8, p.md); ellipse(c, f.x, sy, 6, p.lt); ellipse(c, f.x - 1, sy - 1, 3.5, p.hi)
            shock(c, f.x, f.y, f.r * u, 3, p, squash: 0.5)
            if f.seq == 0 { glow(c, f.x, f.y - 10, f.r * 0.6, p.lt, 0.5 * (1 - u), squash: 0.6) }
        }
        return true
    }

    /// 눈보라 (서리 대마도사): three arms of snow spiral round the mage, frost ringing outward.
    private static func snowVortex(_ c: CGContext, _ f: FXF) -> Bool {
        let p = vortexPal, k = punch(f.t, at: 0.2, hold: 0.4)
        fade(c, 0.18 * k) { ellipse(c, f.x, f.y - 4, f.r * 0.9, p.lt, squash: 0.45) }
        fade(c, k) {
            for arm in 0..<4 {
                for i in 0..<18 {
                    let d = 8 + Double(i) / 18 * (f.r - 8), a = Double(arm) * 1.57 + d / 20 + f.now * 4
                    let x = f.x + cos(a) * d, y = f.y - 6 + sin(a) * d * 0.45
                    seg(c, x, y, x - sin(a) * 3, y + cos(a) * 1.4, i % 3 == 0 ? p.hi : p.lt)
                    if i % 4 == 0 { px(c, x, y, p.hi, 2) }
                }
            }
            circle(c, f.x, f.y, f.r * easeOut(f.t), p.md, squash: 0.5, dash: 3)
            circle(c, f.x, f.y, f.r * easeOut(f.t) - 2, p.hi, squash: 0.5, dash: 5)
        }
        return true
    }

    /// 빙산 낙하: a frost-cracked shadow, then a jagged chunk of ice crashes down and shatters.
    private static func icebergShadow(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.12 + 0.25 * f.t) { ellipse(c, f.x, f.y, r * 0.6 * easeOut(f.t), icebergPal.dk, squash: 0.5) }
        fade(c, 0.4 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.65, icebergPal.lt, squash: 0.5, dash: 3)
            for i in 0..<4 { crack(c, f.x, f.y, Double(i) * 1.57 + 0.5, r * 0.6 * f.t, icebergPal, seed: f.seed &+ UInt64(i), glow: 0.6) }
        }
        return true
    }

    private static func icebergDrop(_ c: CGContext, _ f: FXF) -> Bool {
        let p = icebergPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.22 {
                let u = easeIn(f.t / 0.22)
                glyph(c, "iceberg", icebergGrid, p, f.x, f.y - 8 - 80 * (1 - u))
                return true
            }
            let u = easeOut(win(f.t, 0.22, 1))
            fling(c, f.x, f.y - 6, 14, 100, win(f.t, 0.22, 1), seed: f.seed, Tones(p.hi, p.lt, p.md), spread: 1.1, gravity: 240, size: 2)
            fade(c, 1 - win(f.t, 0.5, 1)) { shock(c, f.x, f.y, r * u, 2, p, squash: 0.5); flake(c, f.x, f.y - 6, 7 * (1 - u) + 2, p.hi, p.lt) }
            fade(c, 0.5 * (1 - u)) { puff(c, f.x, f.y - 2, 6 + u * 6, p.hi, p.lt) }
            return true
        default: return false
        }
    }

    /// 절대영도: a frost lattice races out over the ground in six branching arms; ice dust hangs in the air.
    private static func frostLattice(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.seq % 2 == 0 else { return true }
        let p = zeroPal, u = easeOut(win(f.t, 0, 0.5)), reach = f.r * u
        fade(c, 0.85 * (1 - win(f.t, 0.6, 1))) {
            fade(c, 0.25) { ellipse(c, f.x, f.y, reach, p.lt, squash: 0.5) }
            for i in 0..<6 {
                let a = Double(i) * .pi / 3 + Double(f.seq) * 0.26
                let ux = cos(a), uy = sin(a) * 0.5
                seg(c, f.x, f.y, f.x + ux * reach, f.y + uy * reach, p.lt)
                var d = 12.0
                while d < reach {
                    let bx = f.x + ux * d, by = f.y + uy * d, bl = min(10, (reach - d) * 0.5)
                    for s in [-1.0, 1.0] { let b = a + s * .pi / 3; seg(c, bx, by, bx + cos(b) * bl, by + sin(b) * bl * 0.5, p.md) }
                    d += 14
                }
                px(c, f.x + ux * reach, f.y + uy * reach, p.hi, 2)
            }
        }
        return true
    }

    private static func absoluteZero(_ c: CGContext, _ f: FXF) -> Bool {
        let p = zeroPal
        if f.seq == 0, f.t < 0.2 { glow(c, f.x, f.y - 8, 40, p.hi, 1 - f.t / 0.2, squash: 0.6) }
        let reach = f.r * easeOut(win(f.t, 0, 0.5))
        fade(c, 1 - win(f.t, 0.6, 1)) {
            for i in 0..<6 {
                let a = Double(i) * .pi / 3 + Double(f.seq) * 0.26
                let tx = f.x + cos(a) * reach, ty = f.y + sin(a) * reach * 0.5
                spike(c, tx, ty, -.pi / 2, 7, p.lt, 3); spike(c, tx, ty, -.pi / 2, 5, p.hi, 1)
            }
        }
        fall(c, f.x, f.y, 12, f.r * 0.8, 20, f.t, seed: f.seed, Tones(p.hi, p.ac), sway: 2)
        return true
    }

    /// 얼음 군주의 창: crystal lances trailing frost.
    private static func iceSpear(_ c: CGContext, _ s: ShotF) {
        let p = iceSpearPal, nx = -s.uy, ny = s.ux
        for k in 0..<5 { let back = 20 + Double(k) * 4; fade(c, 0.8 - Double(k) * 0.15) { flake(c, s.x - s.ux * back + nx * Double(k % 2 * 2 - 1) * 2, s.y - s.uy * back + ny * Double(k % 2 * 2 - 1) * 2, 1.5, p.lt, p.hi) } }
        glow(c, s.x - s.ux * 6, s.y - s.uy * 6, 8, p.lt, 0.6)
        seg(c, s.x - s.ux * 18 + nx, s.y - s.uy * 18 + ny, s.x - s.ux * 2 + nx, s.y - s.uy * 2 + ny, p.dk)
        seg(c, s.x - s.ux * 18 - nx, s.y - s.uy * 18 - ny, s.x - s.ux * 2 - nx, s.y - s.uy * 2 - ny, p.md)
        seg(c, s.x - s.ux * 18, s.y - s.uy * 18, s.x + s.ux * 2, s.y + s.uy * 2, p.lt)
        seg(c, s.x - s.ux * 12, s.y - s.uy * 12, s.x + s.ux * 3, s.y + s.uy * 3, p.hi)
    }

    /// Ice breaking off the target.
    private static func shatterHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal
        fling(c, f.x, f.y, f.crit ? 12 : 7, 60, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md), spread: 1.4, gravity: 120, size: 2)
        fade(c, 1 - win(f.t, 0.4, 1)) { flake(c, f.x, f.y, 3 + 5 * easeOut(f.t), p.lt, p.hi) }
        return true
    }
}

// MARK: - rogue

extension RpgArt {
    static let flurryPal = FXPal(0xFFFFFF, 0xF0F4FF, 0xB0B8D0, 0x4A4A66, 0xFF3A50)
    static let shadowPal = FXPal(0xE8D8FF, 0xA08AD8, 0x5A3A8A, 0x1A1028, 0x8A5AC8)
    static let venomBladePal = FXPal(0xF0FFE0, 0xC0F070, 0x70C030, 0x2A5014, 0xB050E0)
    static let smokeBombPal = FXPal(0xFFFFFF, 0xD8D8E0, 0x9A9AAA, 0x4A4A5A, 0xC0C0D0)
    static let stabPal = FXPal(0xFFFFFF, 0xFFD0D8, 0xE0304A, 0x5A0A18, 0xFFFFFF)
    static let bladesPal = FXPal(0xFFFFFF, 0xE0ECFF, 0x9AB0D8, 0x3A4A6A, 0xFFE070)
    static let vanishPal = FXPal(0xE0D0FF, 0x9A7AD8, 0x4A2A7A, 0x120A1E, 0x6AE8C8)
    static let moonPal = FXPal(0xFFFFFF, 0xD8E4FF, 0x7A8ED8, 0x1A1A4A, 0xFF4A6A)
    static let raidPal = FXPal(0xFFE0E0, 0xFF6A7A, 0xC0102A, 0x1A0408, 0x000000)
    static let reaperPal = FXPal(0xF0FFF0, 0xA8F0C8, 0x4AB088, 0x0A2A20, 0x2A2A3A)
    static let toxicPal = FXPal(0xE8FFD0, 0xB0E060, 0x6AA030, 0x2A4A14, 0x3A3A1A)
    static let miasmaPal = FXPal(0xFFE8FF, 0xE0A0F0, 0xA050C0, 0x3A1A4A, 0x9AE050)
    static let chainAssPal = FXPal(0xF8E8FF, 0xC89AFF, 0x7A3AD8, 0x1E0A3A, 0xFFFFFF)
    static let bloodWindPal = FXPal(0xFFE0E8, 0xFF7A8A, 0xD02040, 0x4A0A18, 0xFFFFFF)
    static let dancePal = FXPal(0xFFFFFF, 0xD0D0E8, 0x7A7A9A, 0x1A1A2A, 0xC0102A)
    static let clonePal = FXPal(0xD8C8FF, 0x8A6AC8, 0x3A2A5A, 0x0E0818, 0x6AE8C8)
    static let fogPal = FXPal(0xF0FFE0, 0xC8F0A0, 0x8AC860, 0x3A5A28, 0xD0FF80)
    static let acidPal = FXPal(0xFFFFE0, 0xF0F070, 0xB0D030, 0x4A5A10, 0xE0F0FF)
    static let plaguePal = FXPal(0xF0F0C0, 0xC8C860, 0x8A8A30, 0x2A2A10, 0x1A1A1A)
    static let fangPal = FXPal(0xFFFFFF, 0xF0E0FF, 0xB070E0, 0x3A0A5A, 0x80F040)

    static let flaskGrid: RpgGrid = [".kk.", ".ak.", "kaak", "kllk", "kmlk", "kmmk", ".kk."]
    static let figureGrid: RpgGrid = ["..kkk..", ".kdddk.", ".kadak.", ".kdddk.", "..kdk..", ".kdddk.", "kdddddk", "kdkdkdk", "..kdk..", ".kd.dk.", ".kd.dk.", ".kk.kk."]

    static let rogueLooks: [String: FXLook] = [
        "r_flurry": FXLook(pal: flurryPal, draw: flurryCut),
        "r_step": FXLook(pal: shadowPal, draw: { c, f in shadowStep(c, f, shadowPal, blades: false) }),
        "r_venom": FXLook(pal: venomBladePal, draw: venomFan),
        "r_smoke": FXLook(pal: smokeBombPal, draw: smokeBomb),
        "r_stab": FXLook(pal: stabPal, hit: vitalStab),
        "r_blades": FXLook(pal: bladesPal, hit: { c, f in impact(c, f) }, shot: spinDagger),
        "r_vanish": FXLook(pal: vanishPal, draw: vanish),
        "r_ult": FXLook(pal: moonPal, draw: moonSlash),
        "j_ass1": FXLook(pal: raidPal, draw: { c, f in shadowStep(c, f, raidPal, blades: true) }),
        "j_ass2": FXLook(pal: reaperPal, draw: reaperScythe),
        "j_poi1": FXLook(pal: toxicPal, draw: toxicCloud),
        "j_poi2": FXLook(pal: miasmaPal, draw: miasmaPulse),
        "t2_ro1a": FXLook(pal: chainAssPal, draw: chainAssassin),
        "t2_ro1b": FXLook(pal: bloodWindPal, draw: bloodWind),
        "t3_ro1a": FXLook(pal: dancePal, draw: deathDance),
        "t3_ro1b": FXLook(pal: clonePal, draw: shadowClones),
        "t2_ro2a": FXLook(pal: fogPal, draw: poisonFog),
        "t2_ro2b": FXLook(pal: acidPal, draw: acidFlask, floor: acidMark),
        "t3_ro2a": FXLook(pal: plaguePal, draw: plague),
        "t3_ro2b": FXLook(pal: fangPal, draw: venomFangs),
    ]

    /// 난도질: four straight cuts criss-crossing in front of the rogue, each with an after-image; the last closes an X.
    private static func flurryCut(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = flurryPal, cx = f.x, cy = f.y - 7
        let a = f.dir + (f.seq % 2 == 0 ? 0.9 : -0.9)
        let reach = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.4, 1)
        let l = 11.0 + Double(f.seq) * 1.5
        let x0 = cx - cos(a) * l, y0 = cy - sin(a) * l * 0.8
        let x1 = x0 + cos(a) * 2 * l * reach, y1 = y0 + sin(a) * 2 * l * reach * 0.8
        fade(c, 0.35 * k) { seg(c, x0 - cos(f.dir) * 3, y0 - sin(f.dir) * 3, x1 - cos(f.dir) * 3, y1 - sin(f.dir) * 3, p.md, 2) }
        fade(c, k) {
            seg(c, x0, y0 + 1, x1, y1 + 1, p.ac)
            seg(c, x0, y0, x1, y1, p.hi, 2)
        }
        if f.seq == 3, f.t > 0.2 { star(c, cx, cy, Int(6 * (1 - f.t)) + 1, p.ac, p.hi) }
        fling(c, cx, cy, 4, 50, f.t, seed: f.seed, Tones(p.ac, p.hi), dir: f.dir, spread: 1, gravity: 100)
        return true
    }

    /// 그림자 걸음 / 그림자 습격: smoky after-images of the rogue along the path and a dark cut where it ends
    /// (그림자 습격 runs crimson, with blades in the trail).
    private static func shadowStep(_ c: CGContext, _ f: FXF, _ p: FXPal, blades: Bool) -> Bool {
        guard case .slash(let ang, let rad) = f.kind else { return false }
        let ex = f.x, ey = f.y + 6, len = max(1, hypot(ex - f.ox, ey - f.oy))
        let run = min(1, f.age * 420 / len), ux = cos(f.dir), uy = sin(f.dir)
        for i in 0..<5 {
            let u = Double(i + 1) / 6
            guard u <= run else { break }
            let gx = f.ox + ux * len * u, gy = f.oy + uy * len * u
            let a = (1 - f.t) * (0.3 + 0.12 * Double(i))
            fade(c, a) { glyph(c, blades ? "figureR" : "figure", figureGrid, p, gx, gy - 6) }
            if blades, i % 2 == 0 { fade(c, a) { blade(c, gx - ux * 4, gy - 8, f.dir, 6, p) } }
        }
        fade(c, 0.6 * (1 - f.t)) { for i in 0..<3 { puff(c, f.ox + ux * len * Double(i) / 3, f.oy - 4 - f.t * 8, 3 + f.t * 4, p.md, p.dk) } }
        if run >= 1 {
            let u = win(f.age, len / 420, f.dur)
            let s: Double = cos(ang) < -0.01 ? -1 : 1
            fade(c, 1 - u) {
                crescent(c, ex + ux * 4, ey - 7, rad + 2, ang - 1.4 * s, ang - 1.4 * s + 2.6 * s * easeOut(min(1, u * 3)), 5, p, squash: 0.8, rim: p.dk)
                if blades { crescent(c, ex + ux * 4, ey - 7, rad, ang + 1.3 * s, ang + 1.3 * s - 2.4 * s * easeOut(min(1, u * 3)), 4, p, squash: 0.8) }
            }
            if blades, u < 0.5 { px(c, ex - 2, ey - 16, p.lt); px(c, ex + 2, ey - 16, p.lt) }
        }
        return true
    }

    /// 독날: a ring of venom-green blades flung outward, dripping.
    private static func venomFan(_ c: CGContext, _ f: FXF) -> Bool {
        let p = venomBladePal, u = easeOut(f.t), k = 1 - win(f.t, 0.55, 1)
        fade(c, k) {
            for i in 0..<10 {
                let a = Double(i) / 10 * 2 * .pi + f.t * 2, d = 6 + f.r * u
                let bx = f.x + cos(a) * d, by = f.y - 4 + sin(a) * d * 0.5
                blade(c, bx, by, a + f.age * 20, 4, p)
                px(c, bx, by + 2 + f.t * 6, p.md)
            }
            circle(c, f.x, f.y, f.r * u, p.lt, squash: 0.5)
        }
        rise(c, f.x, f.y, 8, f.r * 0.6, 14, f.t, seed: f.seed, Tones(p.ac, p.lt, p.md))
        return true
    }

    /// 연막: a white pop, then a thick cloud of smoke that boils, lingers and thins.
    private static func smokeBomb(_ c: CGContext, _ f: FXF) -> Bool {
        let p = smokeBombPal
        if f.age < 0.12 { glow(c, f.x, f.y - 6, 14, p.hi, 1 - f.age / 0.12) }
        let grow = easeOut(win(f.age, 0, 0.35)), k = 1 - win(f.t, 0.7, 1)
        var r = KartRNG(seed: f.seed)
        fade(c, k * 0.7) {
            for i in 0..<11 {
                let a = Double(r.int(628)) / 100 + f.age * (i % 2 == 0 ? 0.6 : -0.6), d = f.r * 0.75 * grow * Double(30 + r.int(70)) / 100
                let px0 = f.x + cos(a) * d, py0 = f.y - 6 + sin(a) * d * 0.55 - f.age * 4
                let s = (5 + Double(r.int(4))) * (0.5 + grow * 0.6)
                puff(c, px0, py0, s, i % 3 == 0 ? p.hi : p.lt, p.md)
                px(c, px0 - s * 0.4, py0 - s * 0.45, p.hi)
            }
        }
        return true
    }

    /// 급소 찌르기: a needle-thin thrust from the rogue straight into the target and a crimson critical mark;
    /// the hit itself is a small red burst.
    private static func vitalStab(_ c: CGContext, _ f: FXF) -> Bool {
        let p = stabPal
        guard f.seq == 0 else {
            if f.t < 0.4 { star(c, f.x, f.y, 3, p.md, p.hi) }
            return true
        }
        let a = atan2(f.y - (f.oy - 7), f.x - f.ox), d = hypot(f.x - f.ox, f.y - (f.oy - 7))
        let reach = easeOut(win(f.t, 0, 0.25))
        fade(c, 1 - win(f.t, 0.4, 1)) {
            let sx = f.ox + cos(a) * 6, sy = f.oy - 7 + sin(a) * 6
            seg(c, sx, sy, sx + cos(a) * (d - 6) * reach, sy + sin(a) * (d - 6) * reach, p.md, 3)
            seg(c, sx, sy, sx + cos(a) * (d - 6) * reach, sy + sin(a) * (d - 6) * reach, p.hi)
        }
        if f.t > 0.2 {
            let u = win(f.t, 0.2, 1)
            fade(c, 1 - u) {
                poly(c, f.x, f.y, 4 + 8 * easeOut(u), 4, .pi / 4, p.md)
                spike(c, f.x, f.y, -.pi / 2, 10 * (1 - u) + 4, p.hi, 2); spike(c, f.x, f.y, .pi / 2, 7 * (1 - u) + 3, p.hi, 2)
                spike(c, f.x, f.y, 0, 6, p.lt, 1); spike(c, f.x, f.y, .pi, 6, p.lt, 1)
            }
            fling(c, f.x, f.y, 8, 50, u, seed: f.seed, Tones(p.md, p.dk), dir: a, spread: 0.8, gravity: 150, size: 2)
        }
        return true
    }

    /// 비수 난무: daggers spinning end over end.
    private static func spinDagger(_ c: CGContext, _ s: ShotF) {
        let p = bladesPal, a = s.now * 30 + Double(s.seq)
        fade(c, 0.4) { seg(c, s.x - s.ux * 10, s.y - s.uy * 10, s.x - s.ux * 3, s.y - s.uy * 3, p.lt) }
        let ux = cos(a) * 4, uy = sin(a) * 4
        seg(c, s.x - ux * 0.6, s.y - uy * 0.6, s.x + ux, s.y + uy, p.lt, 2)
        seg(c, s.x - ux * 0.6, s.y - uy * 0.6, s.x + ux, s.y + uy, p.hi)
        seg(c, s.x - ux * 0.6, s.y - uy * 0.6, s.x - ux, s.y - uy, p.dk, 2)
        px(c, s.x - uy * 0.4, s.y + ux * 0.4, p.ac)
    }

    /// 은신: the rogue's outline crumbles into drifting dark motes, a ring fades and two eyes close.
    private static func vanish(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = vanishPal
        var r = KartRNG(seed: f.seed)
        for i in 0..<24 {
            let u = win(f.t, Double(i % 6) * 0.04, Double(i % 6) * 0.04 + 0.7)
            guard u > 0, u < 1 else { continue }
            let sx = f.x - 5 + Double(r.int(11)), sy = f.y - 2 - Double(r.int(20))
            fade(c, 1 - u) { px(c, sx + u * Double(r.int(13) - 6), sy - u * 14, i % 4 == 0 ? p.ac : (i % 2 == 0 ? p.md : p.dk), 2) }
        }
        fade(c, 1 - win(f.t, 0, 0.6)) { circle(c, f.x, f.y, 6 + 14 * easeOut(f.t), p.lt, squash: 0.4) }
        if f.t < 0.5 {
            let open = 1 - win(f.t, 0.3, 0.5)
            fade(c, open) { box(c, f.x - 4, f.y - 17, 2, max(1, 2 * open), p.ac); box(c, f.x + 2, f.y - 17, 2, max(1, 2 * open), p.ac) }
        }
        return true
    }

    /// 암살: a shadow flickers on each foe in turn and a silver crescent moon cuts through it.
    private static func moonSlash(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, let rad) = f.kind else { return false }
        let p = moonPal
        if f.t < 0.2 { fade(c, 0.6 * (1 - f.t / 0.2)) { ellipse(c, f.x, f.y - 6, 8, p.dk, squash: 1.3) } }
        let h = easeOut(win(f.t, 0.1, 0.45)), tl = win(f.t, 0.3, 1)
        if h > tl + 0.02 {
            crescent(c, f.x, f.y - 6, rad, ang - 2 + 3.6 * tl, ang - 2 + 3.6 * h, 7, p, squash: 0.9, rim: p.dk)
        }
        if f.t > 0.35, f.t < 0.7 { star(c, f.x, f.y - 8, 3, p.ac, p.hi) }
        fade(c, 0.5 * (1 - win(f.t, 0, 0.4))) { seg(c, f.ox, f.oy - 8, f.x, f.y - 8, p.dk) }
        return true
    }

    /// 사신의 일격: a ghostly scythe reaps each foe in turn, souls rising from the cut.
    private static func reaperScythe(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, _) = f.kind else { return false }
        let p = reaperPal, sw = easeOut(win(f.t, 0, 0.4)), k = 1 - win(f.t, 0.55, 1)
        let a = ang - 1.6 + 3 * sw, hx = f.x - cos(a) * 8, hy = f.y - 10 - sin(a) * 5
        fade(c, k) {
            seg(c, hx, hy, hx + cos(a) * 18, hy + sin(a) * 9, p.ac, 2)
            crescent(c, hx + cos(a) * 18, hy + sin(a) * 9, 9, a - .pi / 2 - 0.2, a - .pi / 2 + 2.2, 4, p, squash: 0.8, rim: p.dk)
            if sw > 0.3 { crescent(c, f.x, f.y - 6, 13, ang - 1.6, a, 2, p, squash: 0.7) }
        }
        rise(c, f.x, f.y - 4, 5, 5, 26, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md))
        return true
    }

    /// 맹독 구름: green clouds billow out, bubbles rise and a skull floats up through them.
    private static func toxicCloud(_ c: CGContext, _ f: FXF) -> Bool {
        let p = toxicPal, grow = easeOut(win(f.t, 0, 0.45)), k = 1 - win(f.t, 0.7, 1)
        var r = KartRNG(seed: f.seed)
        fade(c, k * 0.85) {
            for i in 0..<9 {
                let a = Double(i) / 9 * 2 * .pi + Double(r.int(60)) / 100, d = f.r * 0.6 * grow
                puff(c, f.x + cos(a) * d, f.y - 6 + sin(a) * d * 0.5 - f.t * 6, 6 * (0.6 + grow * 0.5), i % 2 == 0 ? p.lt : p.md, p.dk)
            }
        }
        rise(c, f.x, f.y, 10, f.r * 0.6, 22, f.t, seed: f.seed, Tones(p.hi, p.lt))
        if f.t > 0.2 { fade(c, k) { glyph(c, "skull", skullGrid, p, f.x, f.y - 22 - f.t * 10) } }
        return true
    }

    /// 독안개 폭발: purple mist bursts outward in a thick band, three times.
    private static func miasmaPulse(_ c: CGContext, _ f: FXF) -> Bool {
        let p = miasmaPal, u = easeOut(f.t), r = f.r * (0.4 + 0.7 * u)
        fade(c, 0.5 * (1 - f.t)) { for w in 0..<5 { circle(c, f.x, f.y - 4, r - Double(w), w < 2 ? p.lt : p.md, squash: 0.5) } }
        fade(c, 1 - f.t) { circle(c, f.x, f.y - 4, r + 1, p.hi, squash: 0.5, dash: 3) }
        fling(c, f.x, f.y - 4, 10, 60, f.t, seed: f.seed, Tones(p.ac, p.lt, p.md), spread: .pi, gravity: 60, size: 2)
        return true
    }

    /// 연환 암살: a violet streak from the rogue to each foe and an X cut on it.
    private static func chainAssassin(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = chainAssPal, l = 9 * easeOut(win(f.t, 0.05, 0.3)), k = 1 - win(f.t, 0.5, 1)
        fade(c, 0.6 * (1 - win(f.t, 0, 0.3))) { seg(c, f.ox, f.oy - 8, f.x, f.y - 6, p.md, 2) }
        fade(c, k) {
            seg(c, f.x - l, f.y - 6 - l * 0.7, f.x + l, f.y - 6 + l * 0.7, p.lt, 2); seg(c, f.x - l, f.y - 6 + l * 0.7, f.x + l, f.y - 6 - l * 0.7, p.lt, 2)
            seg(c, f.x - l, f.y - 6 - l * 0.7, f.x + l, f.y - 6 + l * 0.7, p.hi); seg(c, f.x - l, f.y - 6 + l * 0.7, f.x + l, f.y - 6 - l * 0.7, p.hi)
        }
        if f.t < 0.3 { star(c, f.x, f.y - 6, 3, p.md, p.hi) }
        return true
    }

    /// 혈풍: crimson crescents whirl round the rogue in a blood-red wind.
    private static func bloodWind(_ c: CGContext, _ f: FXF) -> Bool {
        let p = bloodWindPal, spin = f.now * 16 + Double(f.seq) * 1.3, r = f.r * (0.6 + 0.3 * easeOut(f.t))
        fade(c, 1 - win(f.t, 0.4, 1)) {
            for b in 0..<3 { let a = spin + Double(b) * 2.09; crescent(c, f.x, f.y - 5, r, a - 1.6, a, 4, p, squash: 0.45, rim: p.dk) }
            for i in 0..<5 { let a = spin * 0.7 + Double(i) * 1.26; circle(c, f.x, f.y - 5, r + 5, p.lt, squash: 0.45, from: a, to: a + 0.4) }
        }
        fling(c, f.x, f.y - 5, 5, 70, f.t, seed: f.seed, Tones(p.md, p.lt), spread: .pi, gravity: 90)
        return true
    }

    /// 죽음의 무도: a four-bladed pinwheel spins through each foe, scattering dark red petals.
    private static func deathDance(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = dancePal, rot = f.age * 22, s = 13 * punch(f.t, at: 0.15, hold: 0.35)
        fade(c, 1 - win(f.t, 0.6, 1)) {
            circle(c, f.x, f.y - 7, s + 2, p.ac, squash: 0.85, from: rot, to: rot + 4)
            for b in 0..<4 {
                let a = rot + Double(b) * .pi / 2
                crescent(c, f.x, f.y - 7, s, a, a + 1.2, 4, p, squash: 0.85, rim: p.dk)
            }
            px(c, f.x, f.y - 7, p.ac, 3)
        }
        fall(c, f.x, f.y, 9, 14, 22, f.t, seed: f.seed, Tones(p.ac, p.dk), sway: 3)
        return true
    }

    /// The shadow figure with a glowing violet edge, so it shows on dark floors.
    static let cloneGrid: RpgGrid = figureGrid.map { $0.replacingOccurrences(of: "k", with: "l") }

    /// 그림자 분신: three shadow copies split off the rogue and fade, violet smoke curling.
    private static func shadowClones(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = clonePal, u = easeOut(win(f.t, 0, 0.5)), k = 1 - win(f.t, 0.6, 1)
        for i in 0..<3 {
            let dx = i == 0 ? -18.0 : (i == 1 ? 18 : 0)
            let gx = f.x + dx * u, gy = f.y - 9 - (i == 2 ? 6 * u : 0)
            fade(c, k * 0.8) { glyph(c, "clone", cloneGrid, p, gx, gy) }
        }
        fade(c, 0.6 * k) { for i in 0..<4 { puff(c, f.x - 9 + Double(i) * 6, f.y - 3 - f.t * 10, 3 + f.t * 3, p.md, p.dk) } }
        return true
    }

    /// 독무 확산: a low green fog creeps outward and swirls.
    private static func poisonFog(_ c: CGContext, _ f: FXF) -> Bool {
        let p = fogPal, k = punch(f.t, at: 0.3, hold: 0.3)
        var r = KartRNG(seed: f.seed)
        fade(c, 0.45 * k) {
            for _ in 0..<6 {
                let a = Double(r.int(628)) / 100, d = f.r * 0.7 * Double(r.int(100)) / 100
                ellipse(c, f.x + cos(a) * d + f.age * 8, f.y + sin(a) * d * 0.45, 10 + Double(r.int(8)), p.md, squash: 0.35)
            }
        }
        fade(c, 0.7 * k) {
            for i in 0..<3 { let a = f.now * 2 + Double(i) * 2.1 + Double(f.seq); circle(c, f.x, f.y - 2, f.r * (0.4 + 0.2 * Double(i)), p.lt, squash: 0.35, from: a, to: a + 1.6) }
        }
        rise(c, f.x, f.y, 5, f.r * 0.7, 10, f.t, seed: f.seed &+ 3, Tones(p.ac, p.lt))
        return true
    }

    /// 산성 폭탄: a flask tumbles from the rogue's hand onto the mark and bursts into a sizzling acid splash.
    private static func acidMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.4 + 0.5 * f.t) { circle(c, f.x, f.y, r * 0.8, acidPal.md, squash: 0.5, dash: 2) }
        return true
    }

    private static func acidFlask(_ c: CGContext, _ f: FXF) -> Bool {
        let p = acidPal
        switch f.kind {
        case .telegraph(let r):
            // The flask's flight, over the telegraph's lifetime: from the rogue's hand to the mark.
            let u = f.t, hx = f.ox + (f.x - f.ox) * u, hy = f.oy - 10 + (f.y - f.oy + 4) * u - sin(u * .pi) * (20 + r)
            glyph(c, "flask", flaskGrid, p, hx, hy)
            return true
        case .meteor(let r):
            let u = easeOut(f.t)
            fling(c, f.x, f.y - 3, 12, 80, f.t, seed: f.seed, Tones(p.lt, p.md, p.ac), spread: 1.2, gravity: 200, size: 2)
            fade(c, 1 - win(f.t, 0.5, 1)) {
                ellipse(c, f.x, f.y, r * 0.7 * u, p.md, squash: 0.45)
                ellipse(c, f.x, f.y, r * 0.5 * u, p.lt, squash: 0.45)
            }
            rise(c, f.x, f.y, 10, r * 0.6, 12, f.t, seed: f.seed &+ 1, Tones(p.hi, p.lt), size: 1)
            return true
        default: return false
        }
    }

    /// 대역병: flies swarm in a buzzing cloud over a sickly miasma ring.
    private static func plague(_ c: CGContext, _ f: FXF) -> Bool {
        let p = plaguePal, k = punch(f.t, at: 0.2, hold: 0.5)
        fade(c, 0.6 * k) { circle(c, f.x, f.y, f.r * (0.5 + 0.5 * easeOut(f.t)), p.md, squash: 0.5); circle(c, f.x, f.y, f.r * (0.45 + 0.5 * easeOut(f.t)), p.lt, squash: 0.5, dash: 4) }
        var r = KartRNG(seed: f.seed)
        fade(c, k) {
            for i in 0..<26 {
                let a = Double(r.int(628)) / 100 + f.now * (1 + Double(i % 3)), d = f.r * 0.8 * Double(r.int(100)) / 100
                let jx = sin(f.now * 40 + Double(i)) * 1.5, jy = cos(f.now * 37 + Double(i) * 1.7) * 1.5
                px(c, f.x + cos(a) * d + jx, f.y - 8 + sin(a) * d * 0.45 + jy, i % 5 == 0 ? p.lt : p.ac)
            }
        }
        return true
    }

    /// 독왕의 송곳니: two venom fangs snap shut on each foe, purple venom spraying.
    private static func venomFangs(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = fangPal, shut = easeIn(win(f.t, 0, 0.25)), k = 1 - win(f.t, 0.55, 1)
        let gap = 12 * (1 - shut)
        fade(c, k) {
            for j in 0..<2 {
                let s = j == 0 ? -1.0 : 1.0, jy = f.y - 8 + s * (gap + 6)
                oval(c, f.x, jy, 10, 5, 0, p.dk, from: s < 0 ? .pi : 0, to: s < 0 ? 2 * .pi : .pi)
                oval(c, f.x, jy, 9, 4, 0, p.md, from: s < 0 ? .pi : 0, to: s < 0 ? 2 * .pi : .pi)
                for side in 0..<2 {
                    let fx = f.x + (side == 0 ? -5 : 5)
                    spike(c, fx, jy - s * 2, s < 0 ? .pi / 2 : -.pi / 2, 8, p.lt, 3)
                    spike(c, fx, jy - s * 2, s < 0 ? .pi / 2 : -.pi / 2, 7, p.hi, 1)
                    px(c, fx, jy - s * 10, p.ac, 2)
                }
            }
        }
        if shut >= 1 { fling(c, f.x, f.y - 8, 10, 60, win(f.t, 0.25, 1), seed: f.seed, Tones(p.md, p.ac, p.lt), spread: 1.4, gravity: 140, size: 2) }
        return true
    }
}

// MARK: - cleric

extension RpgArt {
    static let smitePal = FXPal(0xFFFFFF, 0xFFF8C8, 0xFFD860, 0xB08A20, 0xFFFFFF)
    static let cHealPal = FXPal(0xFFFFFF, 0xFFF6C0, 0xF8D870, 0xB89030, 0xD8FFD0)
    static let blessPal = FXPal(0xFFFFFF, 0xFFF0D8, 0xFFC8A0, 0xC07A50, 0xFFE070)
    static let novaPal = FXPal(0xFFFFFF, 0xFFFAD8, 0xFFE070, 0xC09A30, 0xA0E8FF)
    static let wardPal = FXPal(0xFFFFFF, 0xE8F0FF, 0xA8C0F0, 0x4A5A9A, 0xFFD860)
    static let judgePal = FXPal(0xFFFFFF, 0xFFF6B0, 0xFFD040, 0x8A6A10, 0xFFFFFF)
    static let purifyPal = FXPal(0xFFFFFF, 0xD0F4FF, 0x7AD0F0, 0x2A6A9A, 0xFFFFFF)
    static let heavenPal = FXPal(0xFFFFFF, 0xFFF8E0, 0xFFE090, 0xC0A060, 0xE0C8FF)
    static let pal1Pal = FXPal(0xFFFFFF, 0xFFF0B0, 0xE0B040, 0x6A4A10, 0x4A7AE0)
    static let hammerPal = FXPal(0xFFFFFF, 0xFFF0A0, 0xE8B030, 0x6A4A10, 0xC0C8D8)
    static let arc1Pal = FXPal(0xFFFFFF, 0xFFE0F0, 0xF0A0C8, 0x9A4A7A, 0xFFE070)
    static let gracePal = FXPal(0xFFFFFF, 0xF8F0FF, 0xD8C8F8, 0x8A7AB8, 0xFFE070)
    static let flashCutPal = FXPal(0xFFFFFF, 0xF0FAFF, 0xB8E0FF, 0x4A7AB0, 0xFFF0A0)
    static let oathPal = FXPal(0xFFFFFF, 0xE8F0FF, 0xA0B8E8, 0x3A4A8A, 0xFFE070)
    static let punishPal = FXPal(0xFFFFFF, 0xFFF7A0, 0xFFC830, 0x7A5A10, 0xFFFFFF)
    static let inviolPal = FXPal(0xFFFFFF, 0xFFF4D0, 0xF0D080, 0x9A7A30, 0xFFFFFF)
    static let massHealPal = FXPal(0xFFFFFF, 0xD8FFE0, 0x8AE0A0, 0x3A8A5A, 0xFFFFFF)
    static let heavenlyPal = FXPal(0xFFFFFF, 0xFFFBE0, 0xFFE8A0, 0xC8A860, 0xFFFFFF)
    static let songPal = FXPal(0xFFFFFF, 0xFFF0C8, 0xFFC860, 0x9A6A20, 0xC8F0FF)
    static let angelPal = FXPal(0xFFFFFF, 0xFFFFF0, 0xF0E8D0, 0xB0A080, 0xFFE070)

    static let hammerGrid: RpgGrid = [
        "....kdk....", "....kdk....", "....kdk....", "....kdk....", "....kdk....", "....kak....",
        "kkkkkkkkkkk", "khhhllllmmk", "khllllllmmk", "klllllllmmk", "kmmmmmmmmdk", "kkkkkkkkkkk",
    ]
    static let wingGrid: RpgGrid = ["......kk", "...kkkhk", ".kkhhhlk", "khhllllk", ".kllmmk.", "..kkkk.."]
    static let noteGrid: RpgGrid = ["..kk", "..kh", "..k.", "kkk.", "khk.", "kkk."]
    static let angelGrid: RpgGrid = [
        "...kaaak...", "....khk....", "kk..khk..kk", "khk.klk.khk", "khhkllkkhhk", ".khhllllhk.", "..kllllllk.", "...kllllk..", "....kmmk...", ".....kk....",
    ]

    static let clericLooks: [String: FXLook] = [
        "c_smite": FXLook(pal: smitePal, hit: radiantHit, shot: smiteLance),
        "c_heal": FXLook(pal: cHealPal, heal: lightFalls),
        "c_bless": FXLook(pal: blessPal, draw: blessing),
        "c_nova": FXLook(pal: novaPal, draw: holyNova),
        "c_ward": FXLook(pal: wardPal, draw: holyWard),
        "c_judge": FXLook(pal: judgePal, draw: judgement, floor: scorchGold),
        "c_purify": FXLook(pal: purifyPal, heal: purify),
        "c_ult": FXLook(pal: heavenPal, draw: heavenSpear, floor: heavenMark),
        "j_pal1": FXLook(pal: pal1Pal, heal: paladinShield),
        "j_pal2": FXLook(pal: hammerPal, draw: judgeHammer, floor: hammerCracks),
        "j_arc1": FXLook(pal: arc1Pal, heal: roseWindow),
        "j_arc2": FXLook(pal: gracePal, draw: graceWings),
        "t2_cl1a": FXLook(pal: flashCutPal, draw: flashCut),
        "t2_cl1b": FXLook(pal: oathPal, draw: oath),
        "t3_cl1a": FXLook(pal: punishPal, draw: holyThunder, floor: punishMark),
        "t3_cl1b": FXLook(pal: inviolPal, draw: inviolable),
        "t2_cl2a": FXLook(pal: massHealPal, draw: { c, f in true }, heal: healingRain),
        "t2_cl2b": FXLook(pal: heavenlyPal, draw: heavenlyLight),
        "t3_cl2a": FXLook(pal: songPal, draw: song),
        "t3_cl2b": FXLook(pal: angelPal, draw: angelDescent, floor: haloMark),
    ]

    /// 성광: a lance of light leaving halo rings in the air.
    private static func smiteLance(_ c: CGContext, _ s: ShotF) {
        let p = smitePal, a = atan2(s.uy, s.ux), d = flown(s)
        var m = 16.0
        while m < d {
            let age = (d - m) / s.speed
            if age < 0.2 { let q = age / 0.2; fade(c, 1 - q) { oval(c, s.x - s.ux * (d - m), s.y - s.uy * (d - m), 1 + q, 3 + q * 5, a, p.lt) } }
            m += 16
        }
        glow(c, s.x - s.ux * 4, s.y - s.uy * 4, 9, p.lt, 0.8)
        beam(c, s.x - s.ux * 14, s.y - s.uy * 14, s.x + s.ux * 2, s.y + s.uy * 2, 3, p)
        star(c, s.x + s.ux * 2, s.y + s.uy * 2, 2, p.md, p.hi)
        for k in 1...3 where (Int(s.now * 20) + k) % 2 == 0 { star(c, s.x - s.ux * (16 + Double(k) * 4), s.y - s.uy * (16 + Double(k) * 4) + Double(k % 2 * 2 - 1) * 2, 1, p.lt, p.hi) }
    }

    /// An eight-pointed flare of light on the target.
    private static func radiantHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, u = easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.4, 1)) { rays(c, f.x, f.y, 8, (f.crit ? 12 : 8) * u + 2, 0, p) }
        return true
    }

    /// 치유의 빛: golden light streams down onto each ally, pluses rising off them.
    private static func lightFalls(_ c: CGContext, _ f: FXF) -> Bool {
        let p = cHealPal
        var r = KartRNG(seed: f.seed)
        fade(c, 1 - win(f.t, 0.6, 1)) {
            for i in 0..<7 {
                let x = f.x - 10 + Double(r.int(21)), ph = (f.age * 2.5 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                let top = f.y - 42 + ph * 32
                seg(c, x, top, x, top + 9, i % 2 == 0 ? p.hi : p.lt)
            }
            glow(c, f.x, f.y - 10, 12, p.lt, 0.6)
            circle(c, f.x, f.y, 8 + 5 * easeOut(f.t), p.md, squash: 0.4)
        }
        return healGlow(c, f)
    }

    /// 축복: a halo settles over each ally while feathers drift down.
    private static func blessing(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = blessPal, k = 1 - win(f.t, 0.7, 1)
        let hy = f.y - 27 - easeOut(win(f.t, 0, 0.3)) * 3
        fade(c, k) { circle(c, f.x, hy, 6, p.ac, squash: 0.35); circle(c, f.x, hy - 1, 5, p.hi, squash: 0.35) }
        for i in 0..<7 {
            let u = win(f.t, Double(i) * 0.07, Double(i) * 0.07 + 0.7)
            guard u > 0, u < 1 else { continue }
            let tilt = sin(u * 8 + Double(i))
            let fx = f.x - 14 + Double(i) * 4.5 + tilt * 3, fy = f.y - 36 + u * 30
            fade(c, 1 - u * u) { seg(c, fx - 2, fy - tilt, fx + 2, fy + tilt, p.lt); px(c, fx - 2, fy - tilt, p.hi) }
        }
        if f.t < 0.4 { rise(c, f.x, f.y - 6, 8, 6, 24, f.t / 0.4, seed: f.seed, Tones(p.hi, p.ac, p.lt)) }
        return true
    }

    /// 성스러운 폭발: a flash, a ring of holy light and a cross-shaped starburst.
    private static func holyNova(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return false }
        let p = novaPal, u = easeOut(f.t)
        if f.t < 0.15 { glow(c, f.x, f.y - 8, r * 0.7, p.hi, 1 - f.t / 0.15) }
        fade(c, 1 - win(f.t, 0.5, 1)) {
            shock(c, f.x, f.y - 2, r * u, 3, p, squash: 0.55)
            for i in 0..<8 {
                let a = Double(i) * .pi / 4, l = (i % 2 == 0 ? r * 0.9 : r * 0.45) * u
                spike(c, f.x, f.y - 8, a, l, i % 2 == 0 ? p.lt : p.md, 3, squash: 0.7)
                spike(c, f.x, f.y - 8, a, l * 0.7, p.hi, 1, squash: 0.7)
            }
        }
        return true
    }

    /// 수호 방벽: a shining bubble closes over each ally with a cross on top and runes turning underfoot.
    private static func holyWard(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = wardPal, up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.7, 1)
        fade(c, 0.22 * k) { ellipse(c, f.x, f.y - 10, 14 * up, p.lt, squash: 1.1) }
        fade(c, k) {
            circle(c, f.x, f.y - 10, 14 * up, p.lt, squash: 1.1)
            circle(c, f.x - 3, f.y - 16, 5 * up, p.hi, from: 3.4, to: 4.6)
            let cy = f.y - 10 - 16 * up
            box(c, f.x - 1, cy - 4, 3, 8, p.ac); box(c, f.x - 3, cy - 2, 7, 3, p.ac); box(c, f.x, cy - 3, 1, 6, p.hi)
            for i in 0..<6 { let a = f.age * 2 + Double(i) * 1.05; px(c, f.x + cos(a) * 14, f.y + sin(a) * 5, p.md, 2) }
        }
        return true
    }

    /// 심판: a pillar of light drops on each foe.
    private static func judgement(_ c: CGContext, _ f: FXF) -> Bool {
        let p = judgePal, o = punch(f.t, at: 0.1, hold: 0.3)
        pillar(c, f.x, f.y, 10 * o + 2, 110, p, o)
        fade(c, 1 - win(f.t, 0.4, 1)) {
            shock(c, f.x, f.y, 4 + 16 * easeOut(f.t), 2, p, squash: 0.45)
            rays(c, f.x, f.y - 4, 8, 12 * easeOut(f.t), 0, p, squash: 0.5)
        }
        return true
    }

    private static func scorchGold(_ c: CGContext, _ f: FXF) -> Bool {
        fade(c, 0.5 * (1 - win(f.t, 0.5, 1))) { ellipse(c, f.x, f.y, 9, judgePal.md, squash: 0.45); circle(c, f.x, f.y, 9, judgePal.lt, squash: 0.45) }
        return true
    }

    /// 정화: ripples spread from each ally and bubbles of clear light rise.
    private static func purify(_ c: CGContext, _ f: FXF) -> Bool {
        let p = purifyPal
        for j in 0..<3 {
            let u = win(f.t, Double(j) * 0.15, Double(j) * 0.15 + 0.6)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { circle(c, f.x, f.y, 3 + u * 17, j == 0 ? p.hi : p.lt, squash: 0.4) }
        }
        var r = KartRNG(seed: f.seed)
        for i in 0..<8 {
            let u = win(f.t, Double(r.int(40)) / 100, 1)
            guard u > 0, u < 1 else { continue }
            let bx = f.x - 9 + Double(r.int(19)) + sin(u * 6 + Double(i)) * 1.5, by = f.y - 2 - u * 26
            fade(c, 1 - u) { circle(c, bx, by, i % 3 == 0 ? 1.6 : 1, i % 2 == 0 ? p.lt : p.hi) }
        }
        return true
    }

    /// 천상의 심판: golden circles with a falling cross; a spear of light stabs down into each and bursts.
    private static func heavenMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = heavenPal
        fade(c, 0.4 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.8, p.md, squash: 0.5)
            let s = r * 0.5 * (1 - f.t) + 3
            seg(c, f.x - s, f.y, f.x + s, f.y, p.lt); seg(c, f.x, f.y - s * 0.5, f.x, f.y + s * 0.5, p.lt)
        }
        return true
    }

    private static func heavenSpear(_ c: CGContext, _ f: FXF) -> Bool {
        let p = heavenPal
        switch f.kind {
        case .telegraph: return true
        case .burst(let r):
            if f.t < 0.2 {
                let u = easeIn(f.t / 0.2), tip = f.y - 90 * (1 - u)
                beam(c, f.x, tip - 30, f.x, tip, 3, p)
                px(c, f.x, tip + 1, p.hi, 2)
                return true
            }
            let u = easeOut(win(f.t, 0.2, 1))
            fade(c, 1 - win(f.t, 0.5, 1)) {
                let v = r * 0.8 * u
                box(c, f.x - 1, f.y - 4 - v * 0.7, 3, v * 1.1, p.lt); box(c, f.x - v * 0.6, f.y - 4 - v * 0.3, v * 1.2, 3, p.lt)
                box(c, f.x, f.y - 4 - v * 0.7, 1, v * 1.1, p.hi); box(c, f.x - v * 0.6, f.y - 3 - v * 0.3, v * 1.2, 1, p.hi)
                circle(c, f.x, f.y, r * u, p.md, squash: 0.5)
            }
            return true
        default: return false
        }
    }

    /// 성스러운 방패: a golden shield with a blue cross shines before each ally.
    private static func paladinShield(_ c: CGContext, _ f: FXF) -> Bool {
        let p = pal1Pal, o = punch(f.t, at: 0.2, hold: 0.4)
        fade(c, o) { glow(c, f.x + 7, f.y - 10, 10, p.lt, 0.6); glyph(c, "kiteGold", kiteGrid, p, f.x + 7, f.y - 10) }
        if f.t < 0.5 { star(c, f.x + 4, f.y - 15, Int(3 * (1 - f.t * 2)) + 1, p.lt, p.hi) }
        return true
    }

    /// 심판의 망치: a giant golden hammer drops, light cracks out of the ground and a ring rolls away.
    private static func hammerCracks(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.t > 0.18 else { return true }
        fade(c, 1 - win(f.t, 0.7, 1)) { for i in 0..<8 { crack(c, f.x, f.y, Double(i) * 0.785 + 0.2, f.r * 0.55, hammerPal, seed: f.seed &+ UInt64(i), glow: 1 - f.t) } }
        return true
    }

    private static func judgeHammer(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return false }
        let p = hammerPal
        if f.t < 0.18 { glyph(c, "hammer", hammerGrid, p, f.x, f.y - 10 - 60 * (1 - easeIn(f.t / 0.18))); return true }
        let u = easeOut(win(f.t, 0.18, 1))
        fade(c, 1 - win(f.t, 0.3, 0.6)) { glyph(c, "hammer", hammerGrid, p, f.x, f.y - 10) }
        if u < 0.3 { glow(c, f.x, f.y - 5, 22, p.hi, 1 - u / 0.3, squash: 0.6) }
        fade(c, 1 - win(f.t, 0.5, 1)) { shock(c, f.x, f.y, r * u, 3, p, squash: 0.45); rays(c, f.x, f.y - 3, 10, r * 0.5 * u, 0.3, p, squash: 0.5) }
        return true
    }

    /// 대치유: a rose window of light unfolds under each ally.
    private static func roseWindow(_ c: CGContext, _ f: FXF) -> Bool {
        let p = arc1Pal, u = easeOut(win(f.t, 0, 0.5)), k = 1 - win(f.t, 0.6, 1)
        fade(c, k) {
            for i in 0..<8 { let a = Double(i) * .pi / 4 + f.age; circle(c, f.x + cos(a) * 9 * u, f.y - 1 + sin(a) * 4 * u, 4 * u, i % 2 == 0 ? p.lt : p.md, squash: 0.5) }
            circle(c, f.x, f.y - 1, 15 * u, p.md, squash: 0.45)
            circle(c, f.x, f.y - 1, 5 * u, p.ac, squash: 0.45)
        }
        rise(c, f.x, f.y - 2, 8, 8, 24, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md), size: 2)
        return true
    }

    /// 신의 은총: angel wings unfold behind each ally under a halo.
    private static func graceWings(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = gracePal, open = easeOut(win(f.t, 0, 0.35)), k = 1 - win(f.t, 0.7, 1)
        fade(c, k) {
            glyph(c, "wing", wingGrid, p, f.x - 7 - 6 * open, f.y - 15)
            glyph(c, "wing", wingGrid, p, f.x + 7 + 6 * open, f.y - 15, flip: true)
            circle(c, f.x, f.y - 28, 5, p.ac, squash: 0.35)
        }
        rise(c, f.x, f.y - 4, 8, 10, 22, f.t, seed: f.seed, Tones(p.hi, p.ac, p.lt))
        return true
    }

    /// 성광 일섬: a blade of light flashes along the line, glinting at its tip.
    private static func flashCut(_ c: CGContext, _ f: FXF) -> Bool {
        let p = flashCutPal, ux = cos(f.dir), uy = sin(f.dir) * 0.6, o = punch(f.t, at: 0.12, hold: 0.2)
        fade(c, o) { beam(c, f.x - ux * 12, f.y - 8 - uy * 12, f.x + ux * 12, f.y - 8 + uy * 12, 3, p) }
        if f.t < 0.5 { star(c, f.x + ux * 12, f.y - 8 + uy * 12, Int(4 * o) + 1, p.ac, p.hi) }
        fall(c, f.x, f.y - 8, 4, 10, 10, f.t, seed: f.seed, Tones(p.hi, p.lt))
        return true
    }

    /// 수호의 서약: a shield and two crossed swords rise before each ally inside a ring.
    private static func oath(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = oathPal, up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.75, 1)
        fade(c, k) {
            let cx = f.x + 9, cy = f.y - 6 - 6 * up
            blade(c, cx - 5, cy + 5, -.pi / 4 - .pi / 2 + 0.3, 11, p)
            blade(c, cx + 5, cy + 5, -.pi / 4 - 0.3, 11, p)
            glyph(c, "towerOath", towerGrid, p, cx, cy)
            circle(c, f.x, f.y, 13, p.md, squash: 0.4, dash: 2)
        }
        return true
    }

    /// A small grey storm cloud lit gold from inside.
    private static func stormCloud(_ c: CGContext, _ x: Double, _ y: Double, _ age: Double) {
        for k in 0..<3 { puff(c, x - 8 + Double(k) * 8, y + Double(k % 2) * 2, 5, smokePal.lt, smokePal.md) }
        if Int(age * 12) % 3 == 0 { glow(c, x, y + 2, 7, punishPal.lt, 0.8) }
    }

    /// 천벌: a little golden storm cloud gathers over the mark and strikes.
    private static func punishMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.4 + 0.5 * f.t) { circle(c, f.x, f.y, r * 0.8, punishPal.md, squash: 0.5); circle(c, f.x, f.y, r * 0.6, punishPal.lt, squash: 0.5, dash: 2) }
        return true
    }

    private static func holyThunder(_ c: CGContext, _ f: FXF) -> Bool {
        let p = punishPal
        switch f.kind {
        case .telegraph:
            fade(c, f.t) { stormCloud(c, f.x, f.y - 62, f.age) }
            return true
        case .meteor(let r):
            fade(c, 1 - win(f.t, 0.6, 1)) { stormCloud(c, f.x, f.y - 62, f.age) }
            if f.t < 0.4, Int(f.age * 30) % 3 != 2 { zap(c, f.x, f.y - 58, f.x, f.y - 2, p, seed: f.seed &+ UInt64(truncatingIfNeeded: Int(f.age * 30)), jag: 4, w: 3, branches: 1) }
            if f.t < 0.15 { glow(c, f.x, f.y - 4, 16, p.hi, 1 - f.t / 0.15) }
            fade(c, 1 - win(f.t, 0.4, 1)) { shock(c, f.x, f.y, r * easeOut(f.t), 2, p, squash: 0.5); rays(c, f.x, f.y - 3, 8, 10 * easeOut(f.t), 0, p, squash: 0.5) }
            return true
        default: return false
        }
    }

    /// 신성 불가침: four blades of light circle each ally before a standing cross.
    private static func inviolable(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = inviolPal, k = 1 - win(f.t, 0.75, 1), up = easeOut(win(f.t, 0, 0.3))
        fade(c, 0.6 * k) { box(c, f.x - 1, f.y - 34, 3, 32 * up, p.lt); box(c, f.x - 8, f.y - 26, 17, 3, p.lt) }
        fade(c, k) {
            for b in 0..<4 {
                let a = f.age * 5 + Double(b) * .pi / 2
                blade(c, f.x + cos(a) * 14 * up, f.y - 9 + sin(a) * 5 * up, a + .pi / 2, 7, p)
            }
        }
        return true
    }

    /// 집단 치유: healing rain falls round each ally.
    private static func healingRain(_ c: CGContext, _ f: FXF) -> Bool {
        let p = massHealPal
        var r = KartRNG(seed: f.seed)
        fade(c, 1 - win(f.t, 0.7, 1)) {
            for i in 0..<12 {
                let ph = (f.age * 1.8 + Double(r.int(100)) / 100).truncatingRemainder(dividingBy: 1)
                let x = f.x - 13 + Double(r.int(27)), y = f.y - 38 + ph * 36
                seg(c, x, y, x, y + 2, i % 2 == 0 ? p.hi : p.lt)
                if ph > 0.9 { px(c, x - 1, f.y - 1, p.lt); px(c, x + 1, f.y - 1, p.lt) }
            }
        }
        return healGlow(c, f)
    }

    /// 천상의 빛: slanting rays of light pour over the area as a soft dome swells.
    private static func heavenlyLight(_ c: CGContext, _ f: FXF) -> Bool {
        let p = heavenlyPal, o = punch(f.t, at: 0.25, hold: 0.3)
        var r = KartRNG(seed: f.seed)
        fade(c, 0.45 * o) {
            for _ in 0..<5 {
                let x = f.x - f.r + Double(r.int(Int(f.r * 2))), y = f.y + Double(r.int(Int(f.r * 0.6))) - f.r * 0.3
                seg(c, x - 20, y - 64, x, y, p.lt, 3)
            }
        }
        fade(c, o) {
            circle(c, f.x, f.y, f.r * (0.5 + 0.5 * easeOut(f.t)), p.md, squash: 0.5)
            glow(c, f.x, f.y - 6, f.r * 0.5, p.hi, 0.4, squash: 0.6)
        }
        fall(c, f.x, f.y, 10, f.r * 0.7, 26, f.t, seed: f.seed &+ 4, Tones(p.hi, p.lt))
        return true
    }

    /// 부활의 노래: notes dance up around each ally inside golden sound rings.
    private static func song(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = songPal
        for i in 0..<5 {
            let u = win(f.t, Double(i) * 0.1, Double(i) * 0.1 + 0.6)
            guard u > 0, u < 1 else { continue }
            let a = Double(i) * 1.3 + u * 3
            fade(c, 1 - u * u) { glyph(c, "note", noteGrid, p, f.x + cos(a) * 13, f.y - 10 - u * 22 + sin(a) * 3) }
        }
        for j in 0..<2 {
            let u = win(f.t, Double(j) * 0.25, Double(j) * 0.25 + 0.5)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { circle(c, f.x, f.y - 10, 6 + u * 16, p.lt, squash: 0.7, from: -0.8, to: 0.8); circle(c, f.x, f.y - 10, 6 + u * 16, p.lt, squash: 0.7, from: 2.34, to: 3.94) }
        }
        return true
    }

    /// 천사 강림: halos mark the ground, an angel descends on each and drives a spear of light down.
    private static func haloMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        fade(c, 0.4 + 0.5 * f.t) { circle(c, f.x, f.y, r * 0.5, angelPal.ac, squash: 0.35); circle(c, f.x, f.y - 1, r * 0.5 - 1, angelPal.hi, squash: 0.35) }
        return true
    }

    private static func angelDescent(_ c: CGContext, _ f: FXF) -> Bool {
        let p = angelPal
        switch f.kind {
        case .telegraph(let r):
            let u = f.t
            fade(c, u) { pillar(c, f.x, f.y - 26, 4, 50, p, 0.4); glyph(c, "angel", angelGrid, p, f.x, f.y - 70 + 40 * easeOut(u) - r * 0) }
            return true
        case .meteor(let r):
            if f.t < 0.15 { glyph(c, "angel", angelGrid, p, f.x, f.y - 30); beam(c, f.x, f.y - 24, f.x, f.y - 24 + 24 * easeIn(f.t / 0.15), 3, p) }
            let u = easeOut(win(f.t, 0.15, 1))
            fade(c, 1 - win(f.t, 0.5, 1)) {
                rays(c, f.x, f.y - 3, 4, r * 0.7 * u, 0, p, squash: 0.6)
                circle(c, f.x, f.y, r * u, p.md, squash: 0.5)
            }
            fall(c, f.x, f.y, 8, r * 0.6, 26, win(f.t, 0.1, 1), seed: f.seed, Tones(p.hi, p.lt, p.md), sway: 3)
            return true
        default: return false
        }
    }
}

// MARK: - monk

extension RpgArt {
    static let punchPal = FXPal(0xFFFFFF, 0xFFE6A0, 0xFFA040, 0x9A4A10, 0xFFF4D0)
    static let spinKickPal = FXPal(0xFFFFFF, 0xFFE8C0, 0xE8A060, 0x7A4A20, 0xF0D8B0)
    static let palmPal = FXPal(0xFFFFFF, 0xC8F0FF, 0x6AC8F0, 0x1A5A8A, 0xFFFFFF)
    static let qiPal = FXPal(0xFFFFFF, 0xFFF0A0, 0xFFC040, 0xC06A10, 0xFFFFD0)
    static let dragonFistPal = FXPal(0xFFFFE0, 0xFFD050, 0xFF6A20, 0x8A1A10, 0xFFF0A0)
    static let barragePal = FXPal(0xFFFFFF, 0xF0E0D0, 0xD0A080, 0x6A4A30, 0xFFE0A0)
    static let vajraPal = FXPal(0xFFFFFF, 0xFFF0B0, 0xE8B830, 0x7A5410, 0xFFFFE0)
    static let heavenFistPal = FXPal(0xFFFFFF, 0xE0F0FF, 0x9AC8F8, 0x3A5A9A, 0xFFE070)
    static let blastFistPal = FXPal(0xFFFFE0, 0xFFC050, 0xF0601A, 0x6A1A10, 0xFFFFFF)
    static let furyPal = FXPal(0xFFF0E0, 0xFF8A5A, 0xE0281A, 0x5A0A0A, 0xFFD040)
    static let lotusPal = FXPal(0xFFFFFF, 0xFFE0F0, 0xF0A0C8, 0x8A3A6A, 0x8AF0E0)
    static let counterPal = FXPal(0xFFFFFF, 0xC8E8FF, 0x5AA8F0, 0x1A4A8A, 0xFFFFFF)
    static let chainFistPal = FXPal(0xFFFFF0, 0xFFD890, 0xF08A30, 0x7A3A10, 0xFFFFFF)
    static let shockwavePal = FXPal(0xFFFFFF, 0xE0FFF0, 0x9AE8C0, 0x3A8A6A, 0xFFFFFF)
    static let collapsePal = FXPal(0xFFF0D0, 0xD8B890, 0x9A7A5A, 0x3A2A1A, 0x6A6A7A)
    static let taijiPal = FXPal(0xFFFFFF, 0xE8E8F0, 0xA0A0B0, 0x1A1A22, 0xFFD060)
    static let bellPal = FXPal(0xFFF8E0, 0xE8C080, 0xB07A30, 0x5A3A10, 0xFFE070)
    static let shoutPal = FXPal(0xFFFFFF, 0xFFF4C0, 0xFFC850, 0x8A5A10, 0xFFFFFF)
    static let mandorlaPal = FXPal(0xFFFFFF, 0xFFF0C0, 0xFFC040, 0xA05A10, 0xFFFFFF)
    static let nirvanaPal = FXPal(0xFFFFFF, 0xFFF4C8, 0xFFD060, 0x9A6A20, 0xFFC0E0)

    static let bigFistSprite = FXSprite("bigfist", [
        "..kkkkk...", ".kllllhk..", "klllllllk.", "kllllllhk.", "kmllllllkk", "kmllllllhk", "kmmmllllk.", ".kmmmmmk..", "..kkkkk...",
    ])
    static let palmGrid: RpgGrid = [".k.k.k.", "klklklk", "klklklk", "klllllk", "kllllllk", "kllhllk.", ".kllllk.", "..kllk..", "...kk..."]
    static let lotusGrid: RpgGrid = ["......h......", "....k.l.k....", "..k.klmlk.k..", ".klkllmllklk.", "kllmllmllmllk", ".kkkkkkkkkkk."]
    static let bellGrid: RpgGrid = ["...kkk...", "...kak...", "..kllmk..", ".klllmmk.", ".klhlmmk.", ".klllmmk.", "klllllmmk", "kaaaaaaak", "kkkkkkkkk", "....k...."]

    static let monkLooks: [String: FXLook] = [
        "k_punch": FXLook(pal: punchPal, draw: straightPunch),
        "k_spin": FXLook(pal: spinKickPal, draw: spinKick),
        "k_palm": FXLook(pal: palmPal, hit: { c, f in kiHit(c, f) }, shot: kiWave),
        "k_qi": FXLook(pal: qiPal, draw: qiAura),
        "k_dragon": FXLook(pal: dragonFistPal, draw: risingDragon),
        "k_barrage": FXLook(pal: barragePal, draw: { c, f in fistFlurry(c, f, barragePal, last: 7, fiery: false) }),
        "k_iron": FXLook(pal: vajraPal, draw: vajraBody),
        "k_ult": FXLook(pal: heavenFistPal, draw: heavenBarrage),
        "j_fk1": FXLook(pal: blastFistPal, draw: blastFist),
        "j_fk2": FXLook(pal: furyPal, draw: { c, f in fistFlurry(c, f, furyPal, last: 11, fiery: true) }),
        "j_asc1": FXLook(pal: lotusPal, draw: meditate),
        "j_asc2": FXLook(pal: counterPal, draw: counterKi),
        "t2_mo1a": FXLook(pal: chainFistPal, draw: chainFists),
        "t2_mo1b": FXLook(pal: shockwavePal, draw: airShock),
        "t3_mo1a": FXLook(pal: collapsePal, draw: skyFall, floor: collapseCracks),
        "t3_mo1b": FXLook(pal: taijiPal, draw: taijiFist),
        "t2_mo2a": FXLook(pal: bellPal, draw: templeBell),
        "t2_mo2b": FXLook(pal: shoutPal, draw: arhatShout),
        "t3_mo2a": FXLook(pal: mandorlaPal, draw: mandorla),
        "t3_mo2b": FXLook(pal: nirvanaPal, hit: { c, f in kiHit(c, f) }, shot: palmShot),
    ]

    /// A ki ring and shock lines where a blow lands.
    static func kiHit(_ c: CGContext, _ f: FXF) -> Bool {
        let p = f.pal, u = easeOut(win(f.t, 0, 0.4)), s = f.crit ? 1.5 : 1.0
        fade(c, 1 - win(f.t, 0.4, 1)) {
            oval(c, f.x, f.y, 2 + 2 * u, (4 + 6 * u) * s, f.dir, p.hi)
            for i in 0..<4 { let a = f.dir + (Double(i) - 1.5) * 0.5; spike(c, f.x, f.y, a, (4 + 6 * u) * s, p.lt, 1) }
        }
        return true
    }

    /// 정권: a big fist drives through a cone of shock chevrons.
    private static func straightPunch(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = punchPal, ux = cos(f.dir), uy = sin(f.dir)
        let ext = easeOut(win(f.t, 0, 0.25)), k = 1 - win(f.t, 0.55, 1)
        let hx = f.x - ux * (12 - 12 * ext), hy = f.y - 8 - uy * (12 - 12 * ext)
        fade(c, k * 0.5) { for i in 1...4 { seg(c, hx - ux * Double(4 + i * 3), hy - uy * Double(4 + i * 3) + Double(i - 2) * 1.5, hx - ux * Double(9 + i * 3), hy - uy * Double(9 + i * 3) + Double(i - 2) * 1.5, p.lt) } }
        fade(c, k) { glyph(c, bigFistSprite, p, hx, hy, dir: f.dir) }
        if f.t > 0.15 {
            let u = easeOut(win(f.t, 0.15, 1))
            fade(c, 1 - u) {
                for j in 0..<3 {
                    let q = 6 + Double(j) * 5 + u * 10
                    oval(c, hx + ux * q, hy + uy * q, 1.5, 4 + q * 0.5, f.dir, j == 0 ? p.hi : p.lt, from: -1.2, to: 1.2)
                }
                oval(c, hx + ux * 5, hy + uy * 5, 2, 7 + u * 8, f.dir, p.ac)
            }
        }
        return true
    }

    /// 회축: a low flat sweep of the leg all the way round, kicking dust off its edge.
    private static func spinKick(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return true }
        let p = spinKickPal, spin = easeOut(f.t) * 2.2 * .pi, k = 1 - win(f.t, 0.6, 1)
        fade(c, k) {
            for b in 0..<2 {
                let a = f.dir + spin + Double(b) * .pi
                crescent(c, f.x, f.y + 2, r * 0.75, a - 2.4, a, 5, p, squash: 0.3, rim: p.dk)
            }
            circle(c, f.x, f.y + 2, r * 0.9, p.lt, squash: 0.3, dash: 3)
        }
        for i in 0..<6 {
            let a = f.dir + spin + Double(i) * 1.05
            fade(c, k * 0.7) { puff(c, f.x + cos(a) * r * 0.9, f.y + 2 + sin(a) * r * 0.27 - f.t * 6, 2 + f.t * 3, dustPal.lt, dustPal.md) }
        }
        return true
    }

    /// 장풍: a widening crescent of ki rippling as it flies.
    private static func kiWave(_ c: CGContext, _ s: ShotF) {
        let p = palmPal, a = atan2(s.uy, s.ux), d = flown(s)
        let w = 4 + min(6, d / 18)
        for j in 1...3 { fade(c, 0.6 - Double(j) * 0.15) { oval(c, s.x - s.ux * Double(j) * 5, s.y - s.uy * Double(j) * 5, 2, w - Double(j), a, p.md, from: -1.3, to: 1.3) } }
        glow(c, s.x, s.y, w + 3, p.lt, 0.7)
        oval(c, s.x, s.y, 3, w, a, p.lt, from: -1.4, to: 1.4)
        oval(c, s.x + s.ux, s.y + s.uy, 2, w - 1, a, p.hi, from: -1.3, to: 1.3)
        oval(c, s.x - s.ux, s.y - s.uy, 2, w - 2, a, p.md, from: -1.3, to: 1.3)
    }

    /// 기공: a flaring golden aura licks up all round the body as ki rings climb.
    private static func qiAura(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = qiPal, k = 1 - win(f.t, 0.7, 1), flare = punch(f.t, at: 0.2, hold: 0.4)
        fade(c, k * 0.8) {
            for i in 0..<9 {
                let x = f.x - 9 + Double(i) * 2.2, h = (10 + 8 * sin(Double(i) / 8 * .pi)) * (0.6 + 0.6 * flare)
                flame(c, x, f.y + 1, h + 3 * sin(f.age * 14 + Double(i)), 3, p, phase: f.age * 24 + Double(i))
            }
        }
        for j in 0..<3 {
            let u = win(f.t, Double(j) * 0.15, Double(j) * 0.15 + 0.6)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { circle(c, f.x, f.y - u * 28, 8 - u * 3, p.lt, squash: 0.35) }
        }
        rise(c, f.x, f.y - 4, 8, 8, 30, f.t, seed: f.seed, Tones(p.hi, p.lt, p.ac), size: 2)
        return true
    }

    /// 승룡권: a dragon of fire coils up out of the ground and soars.
    private static func risingDragon(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = dragonFistPal, up = easeOut(win(f.t, 0, 0.45)), k = 1 - win(f.t, 0.65, 1)
        let top = 46 * up
        fade(c, k) {
            var i = 0.0
            while i < top {
                let u = i / 46, w = 4.5 * (1 - u * 0.5)
                let x = f.x + sin(u * 9 - f.age * 8) * 6 * (0.4 + u)
                ellipse(c, x, f.y - i, w, i.truncatingRemainder(dividingBy: 6) < 3 ? p.md : p.dk, squash: 0.6)
                ellipse(c, x - 1, f.y - i - 1, w * 0.55, p.lt, squash: 0.6)
                i += 2.5
            }
            let hx = f.x + sin(9 * top / 46 - f.age * 8) * 6 * (0.4 + top / 46), hy = f.y - top
            ellipse(c, hx, hy, 4, p.md); ellipse(c, hx - 1, hy - 1, 2.5, p.lt)
            px(c, hx + 1, hy - 1, p.hi); seg(c, hx - 2, hy - 3, hx - 4, hy - 7, p.ac); seg(c, hx + 2, hy - 3, hx + 4, hy - 7, p.ac)
        }
        rise(c, f.x, f.y - 6, 12, 8, 40, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md), size: 2)
        if f.t < 0.25 { fade(c, 1 - f.t / 0.25) { shock(c, f.x, f.y, 6 + f.t * 60, 2, p, squash: 0.45) } }
        return true
    }

    /// 연환권 / 분노의 연타: fists land all over the target spot, the last one heaviest.
    private static func fistFlurry(_ c: CGContext, _ f: FXF, _ p: FXPal, last: Int, fiery: Bool) -> Bool {
        guard case .slash = f.kind else { return false }
        var r = KartRNG(seed: f.seed)
        let jx = Double(r.int(13)) - 6, jy = Double(r.int(11)) - 5
        let big = f.seq >= last, ext = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.45, 1)
        let hx = f.x + jx - cos(f.dir) * (6 - 6 * ext), hy = f.y - 8 + jy - sin(f.dir) * (6 - 6 * ext)
        fade(c, k) { glyph(c, big ? bigFistSprite : fistSprite, p, hx, hy, dir: f.dir) }
        if f.t > 0.2 {
            let u = win(f.t, 0.2, 1)
            fade(c, 1 - u) {
                star(c, hx + cos(f.dir) * 4, hy + sin(f.dir) * 4, big ? 6 : 3, p.ac, p.hi)
                if big { shock(c, hx, hy + 6, 6 + 14 * easeOut(u), 2, p, squash: 0.5) }
            }
        }
        if fiery { rise(c, hx, hy, 3, 2, 8, f.t, seed: f.seed, Tones(p.ac, p.lt, p.md)) }
        return true
    }

    /// 금강불괴: the body flashes gold as diamonds circle it in two rings.
    private static func vajraBody(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = vajraPal, k = 1 - win(f.t, 0.7, 1)
        if f.t < 0.25 { glow(c, f.x, f.y - 10, 14, p.lt, 1 - f.t / 0.25, squash: 1.3) }
        fade(c, k) {
            for ring in 0..<2 {
                for i in 0..<5 {
                    let a = f.age * (ring == 0 ? 4 : -3) + Double(i) * 1.26
                    let dx = f.x + cos(a) * (12 - Double(ring) * 3), dy = f.y - 4 - Double(ring) * 12 + sin(a) * 4
                    poly(c, dx, dy, 2.5, 4, 0, p.md); px(c, dx, dy, sin(a) > 0 ? p.hi : p.lt)
                }
            }
        }
        if f.t > 0.3, f.t < 0.6 { star(c, f.x + 5, f.y - 18, 3, p.ac, p.hi) }
        return true
    }

    /// 천상 연타: shock rings and stars burst where an unseen fist lands, speed lines rushing in; the last blow is huge.
    private static func heavenBarrage(_ c: CGContext, _ f: FXF) -> Bool {
        let p = heavenFistPal, big = f.seq >= 11
        var r = KartRNG(seed: f.seed)
        let x = f.x + Double(r.int(15)) - 7, y = f.y - 6 + Double(r.int(11)) - 5
        let u = easeOut(f.t), k = 1 - win(f.t, 0.4, 1), s = big ? 2.0 : 1.0
        fade(c, k) {
            shock(c, x, y, (3 + 10 * u) * s, 2, p, squash: 0.7)
            star(c, x, y, Int(4 * s * (1 - f.t)) + 1, p.ac, p.hi)
            for i in 0..<6 {
                let a = Double(i) * 1.05 + Double(f.seq), d0 = (22 - 14 * u) * s
                seg(c, x + cos(a) * d0, y + sin(a) * d0 * 0.7, x + cos(a) * (d0 + 6), y + sin(a) * (d0 + 6) * 0.7, p.lt)
            }
        }
        if big { glow(c, x, y, 24, p.hi, 1 - f.t, squash: 0.7) }
        return true
    }

    /// 폭권: a giant fist punches out and the air in front of it explodes.
    private static func blastFist(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return false }
        let p = blastFistPal, ux = cos(f.dir), uy = sin(f.dir)
        if f.t < 0.2 {
            let ext = easeOut(f.t / 0.2)
            glyph(c, bigFistSprite, p, f.x - ux * (16 - 12 * ext), f.y - 8 - uy * (16 - 12 * ext), dir: f.dir)
            return true
        }
        let u = easeOut(win(f.t, 0.2, 1))
        if u < 0.3 { glow(c, f.x, f.y - 8, r * 0.8, p.hi, 1 - u / 0.3) }
        fade(c, 1 - win(f.t, 0.5, 1)) {
            glow(c, f.x, f.y - 8, r * 0.7 * u, p.lt)
            shock(c, f.x, f.y - 4, r * u, 3, p, squash: 0.6)
            shock(c, f.x, f.y - 4, r * u * 0.6, 2, p, squash: 0.6)
        }
        fade(c, 0.6 * (1 - u)) { for k in 0..<3 { puff(c, f.x - 6 + Double(k) * 6, f.y - 12 - u * 12, 3 + u * 5, smokePal.md, smokePal.dk) } }
        fling(c, f.x, f.y - 8, 10, 90, win(f.t, 0.2, 1), seed: f.seed, Tones(p.hi, p.lt, p.md), dir: f.dir, spread: 1, gravity: 120, size: 2)
        return true
    }

    /// 참선: a lotus of light opens under the monk and calm rings drift up.
    private static func meditate(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = lotusPal, k = 1 - win(f.t, 0.75, 1)
        fade(c, k * easeOut(win(f.t, 0, 0.3))) { glyph(c, "lotus", lotusGrid, p, f.x, f.y) }
        for j in 0..<3 {
            let u = win(f.t, Double(j) * 0.2, Double(j) * 0.2 + 0.7)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { circle(c, f.x, f.y - 6 - u * 24, 10 - u * 4, p.ac, squash: 0.35) }
        }
        rise(c, f.x, f.y - 2, 6, 10, 24, f.t, seed: f.seed, Tones(p.hi, p.lt, p.ac))
        return true
    }

    /// 반격의 기: a dome of blue ki slams outward, wind streaming off it.
    private static func counterKi(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return false }
        let p = counterPal, u = easeOut(f.t), k = 1 - win(f.t, 0.5, 1)
        fade(c, 0.3 * k) { ellipse(c, f.x, f.y - 8, r * 0.6 * u, p.lt, squash: 0.8) }
        fade(c, k) {
            circle(c, f.x, f.y - 8, r * 0.6 * u, p.hi, squash: 0.8)
            shock(c, f.x, f.y, r * u, 3, p, squash: 0.45)
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi, d = r * u
                seg(c, f.x + cos(a) * d * 0.7, f.y + sin(a) * d * 0.35, f.x + cos(a) * (d + 6), f.y + sin(a) * (d + 6) * 0.45, p.lt)
            }
        }
        return true
    }

    /// 연환 폭권: fist marks blink in all over the area, each going off like a firecracker.
    private static func chainFists(_ c: CGContext, _ f: FXF) -> Bool {
        let p = chainFistPal
        var r = KartRNG(seed: f.seed)
        let a = Double(r.int(628)) / 100, d = f.r * 0.7 * sqrt(Double(r.int(100)) / 100)
        let x = f.x + cos(a) * d, y = f.y + sin(a) * d * 0.5 - 6
        if f.t < 0.2 { glyph(c, fistSprite, p, x - cos(f.dir) * 4, y, dir: f.dir); return true }
        let u = easeOut(win(f.t, 0.2, 1))
        fade(c, 1 - u) {
            glow(c, x, y, 9 * u + 3, p.lt)
            rays(c, x, y, 8, 9 * u + 2, Double(f.seq), p)
        }
        return true
    }

    /// 충격파: crescents of compressed air roll forward one after another.
    private static func airShock(_ c: CGContext, _ f: FXF) -> Bool {
        let p = shockwavePal, u = easeOut(f.t), k = 1 - win(f.t, 0.5, 1)
        fade(c, k) {
            for j in 0..<3 {
                let q = Double(j) * 4 + u * 10
                oval(c, f.x + cos(f.dir) * q, f.y - 6 + sin(f.dir) * q * 0.6, 2 + u * 2, 8 + q * 0.4, f.dir, j == 0 ? p.hi : p.lt, from: -1.3, to: 1.3)
            }
        }
        spice(c, f.x, f.y - 6, 8, .wind, f.t, seed: f.seed, n: 4)
        return true
    }

    /// 천지 붕괴: the ground splits in great radial cracks and rocks rain down out of the sky.
    private static func collapseCracks(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.seq % 2 == 0 else { return true }
        fade(c, 1 - win(f.t, 0.6, 1)) { for i in 0..<6 { crack(c, f.x, f.y, Double(i) * 1.05 + Double(f.seq) * 0.3, f.r * 0.7 * easeOut(f.t), earthPal, seed: f.seed &+ UInt64(i), glow: 0.5) } }
        return true
    }

    private static func skyFall(_ c: CGContext, _ f: FXF) -> Bool {
        let p = collapsePal
        var r = KartRNG(seed: f.seed)
        for i in 0..<4 {
            let a = Double(r.int(628)) / 100, d = f.r * 0.85 * sqrt(Double(r.int(100)) / 100)
            let gx = f.x + cos(a) * d, gy = f.y + sin(a) * d * 0.5
            let land = 0.2 + Double(i) * 0.1, fall = win(f.t, land - 0.2, land)
            if fall < 1 {
                let ry = gy - 70 * (1 - easeIn(fall))
                ellipse(c, gx, ry - 3, 4, p.dk); ellipse(c, gx - 1, ry - 4, 2.5, p.ac)
            } else {
                let u = win(f.t, land, land + 0.4)
                if u < 1 {
                    fade(c, 1 - u) { shock(c, gx, gy, 3 + 12 * easeOut(u), 2, p, squash: 0.45); puff(c, gx, gy - 3 - u * 6, 3 + u * 5, dustPal.lt, dustPal.md) }
                    fling(c, gx, gy, 4, 60, u, seed: f.seed &+ UInt64(i), Tones(p.dk, p.md), spread: 0.8, gravity: 220, size: 2)
                }
            }
        }
        return true
    }

    /// 무극 권: a turning yin-yang flares on each foe.
    private static func taijiFist(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = taijiPal, s = 7 * punch(f.t, at: 0.15, hold: 0.3), rot = f.age * 10, cy = f.y - 8
        guard s > 1 else { return true }
        fade(c, 1 - win(f.t, 0.6, 1)) {
            ellipse(c, f.x, cy, s + 1, outline)
            wedge(c, f.x, cy, 0, s, rot, rot + .pi, p.hi)
            wedge(c, f.x, cy, 0, s, rot + .pi, rot + 2 * .pi, p.dk)
            ellipse(c, f.x + cos(rot) * s / 2, cy + sin(rot) * s / 2, s / 2, p.hi)
            ellipse(c, f.x - cos(rot) * s / 2, cy - sin(rot) * s / 2, s / 2, p.dk)
            px(c, f.x + cos(rot) * s / 2, cy + sin(rot) * s / 2, p.dk); px(c, f.x - cos(rot) * s / 2, cy - sin(rot) * s / 2, p.hi)
            circle(c, f.x, cy, s + 4 + easeOut(f.t) * 8, p.ac)
        }
        return true
    }

    /// 금강불괴 (선승): a bronze temple bell rings over the monk, sound rolling out of it.
    private static func templeBell(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = bellPal, k = 1 - win(f.t, 0.75, 1), drop = easeOut(win(f.t, 0, 0.25))
        let swing = sin(f.age * 14) * (1 - f.t) * 2
        fade(c, k) { glyph(c, "bell", bellGrid, p, f.x + swing, f.y - 34 + 6 * drop) }
        for j in 0..<3 {
            let u = win(f.t, 0.2 + Double(j) * 0.15, 0.2 + Double(j) * 0.15 + 0.5)
            guard u > 0, u < 1 else { continue }
            fade(c, 1 - u) { circle(c, f.x, f.y - 26, 6 + u * 18, p.lt, squash: 0.6, from: 0.3, to: 2.8) }
        }
        return true
    }

    /// 나한의 일갈: a golden shout wave bursts out in curved sound lines.
    private static func arhatShout(_ c: CGContext, _ f: FXF) -> Bool {
        let p = shoutPal, u = easeOut(f.t), k = 1 - win(f.t, 0.5, 1)
        fade(c, k) {
            jag(c, f.x, f.y - 6, f.r * u, p.lt, n: 16, amp: 2, squash: 0.5)
            for i in 0..<8 {
                let a = Double(i) * .pi / 4, d = f.r * 0.5 * u
                for j in 0..<3 { circle(c, f.x + cos(a) * d, f.y - 8 + sin(a) * d * 0.5, 2 + Double(j) * 2.5, p.hi, from: a - 0.6, to: a + 0.6) }
            }
        }
        if f.t < 0.2 { glow(c, f.x, f.y - 10, 18, p.hi, 1 - f.t / 0.2) }
        return true
    }

    /// 불멸의 몸: a golden mandorla of flame rises behind each ally.
    private static func mandorla(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = mandorlaPal, k = 1 - win(f.t, 0.75, 1), up = easeOut(win(f.t, 0, 0.35))
        let cy = f.y - 12
        fade(c, 0.3 * k) { ellipse(c, f.x, cy, 10 * up, p.lt, squash: 1.7) }
        fade(c, k) {
            for i in 0..<16 {
                let a = Double(i) / 16 * 2 * .pi
                let ex = f.x + cos(a) * 10 * up, ey = cy + sin(a) * 17 * up
                flame(c, ex, ey + 2, 4 + 2 * sin(f.age * 16 + Double(i)), 2, p, phase: f.age * 20 + Double(i))
            }
        }
        return true
    }

    /// 해탈 장풍: golden palm prints fly out, lotus petals trailing.
    private static func palmShot(_ c: CGContext, _ s: ShotF) {
        let p = nirvanaPal
        for k in 0..<5 {
            let back = 8 + Double(k) * 4, sway = sin(s.now * 10 + Double(k)) * 2
            fade(c, 0.8 - Double(k) * 0.14) { px(c, s.x - s.ux * back - s.uy * sway, s.y - s.uy * back + s.ux * sway, k % 2 == 0 ? p.ac : p.lt, 2) }
        }
        glow(c, s.x, s.y, 9, p.lt, 0.8)
        glyph(c, "palm", palmGrid, p, s.x, s.y)
    }
}

// MARK: - summoner

extension RpgArt {
    static let spiritPal = FXPal(0xFFFFFF, 0xC8FFF0, 0x5AE0C8, 0x1A6A6A, 0xFFE0A0)
    static let wolfPal = FXPal(0xFFFFFF, 0xC8E0FF, 0x7AA0E8, 0x2A3A7A, 0xE0F0FF)
    static let golemPal = FXPal(0xF0F0E0, 0xB8B8A8, 0x8A8A7A, 0x3A3A34, 0x7AB050)
    static let cursePal = FXPal(0xF0D0FF, 0xB070E0, 0x6A2A9A, 0x1A0828, 0x9AE050)
    static let batPal = FXPal(0xE0C8E8, 0x8A5A9A, 0x4A2A5A, 0x140818, 0xFF3A3A)
    static let drainPal = FXPal(0xFFE0E8, 0xFF6A8A, 0xC0183A, 0x4A0414, 0x9AE050)
    static let breathPal = FXPal(0xFFFFE0, 0xFFD060, 0xFF7020, 0xA02A10, 0x5AB040)
    static let greenDragonPal = FXPal(0xFFFFFF, 0xC8F0A0, 0x5AB040, 0x1A4A14, 0x5AB040)
    static let demonPal = FXPal(0xFFD0E0, 0xFF4A6A, 0x9A0A3A, 0x1A0410, 0xA04AFF)
    static let hellfireVioletPal = FXPal(0xFFE0FF, 0xD080FF, 0x8A2AD0, 0x2A0A3A, 0xFF4A6A)
    static let bonePal = FXPal(0xFFFFF0, 0xE8E4D0, 0xB0AC98, 0x4A4838, 0x7AF07A)
    static let deathPal = FXPal(0xE8D0FF, 0x9A6AD0, 0x4A1A7A, 0x0E0418, 0x7AF07A)
    static let beastPal = FXPal(0xFFF8E8, 0xF0D0A0, 0xC08A50, 0x5A3A1A, 0xFFFFFF)
    static let spiritKingPal = FXPal(0xFFFFFF, 0xD0FFD8, 0x6AE0A0, 0x1A6A4A, 0xFFE060)
    static let wraithPal = FXPal(0xF0F0FF, 0xC8C8E8, 0x8A8AB8, 0x2A2A4A, 0xA0FFE0)
    static let boneSpearPal = FXPal(0xFFFFF8, 0xF0ECD8, 0xC8C0A0, 0x5A5440, 0x7AF07A)
    static let doomPal = FXPal(0xF0FFE0, 0x8AF05A, 0x3AA02A, 0x140A1A, 0xFF3A3A)
    static let harvestPal = FXPal(0xFFFFFF, 0xC8D8FF, 0x7A8AE8, 0x1A1A4A, 0xA0FFFF)
    static let fireDragonPal = FXPal(0xFFFFE0, 0xFFC050, 0xE8501A, 0x6A1A0A, 0xFFE070)
    static let stampedePal = FXPal(0xFFF0D8, 0xD8B080, 0x9A6A3A, 0x3A2410, 0xFFFFFF)
    static let divineBeastPal = FXPal(0xFFFFFF, 0xD0FFF4, 0x6AE0C8, 0x1A6A6A, 0xFFE070)
    static let spiritStormPal = FXPal(0xFFFFFF, 0xE0FFF0, 0x8AE8C0, 0x2A6A5A, 0xFFE070)
    static let spiritOrbs: [FXPal] = [elemPal(.fire), elemPal(.ice), elemPal(.wind), elemPal(.holy)]

    static let wolfHead = FXSprite("wolf", ["..k......", ".klk.....", ".kllkkk..", "kllhlllkk", "kllllllak", ".kllmmkk.", "..kkkk..."])
    static let golemFistGrid: RpgGrid = ["..kkkkkkkk..", ".kllllllllk.", "kllaalllllmk", "kllllllllmmk", "klllllllmmmk", "kkkkkkkkkkkk", "klmklmklmklk", "kmmkmmkmmkmk", ".kkkkkkkkkk."]
    static let batUpGrid: RpgGrid = ["k.......k", "kk.kkk.kk", "kmmmammmk", ".kmmmmmk.", "..k...k.."]
    static let batDownGrid: RpgGrid = ["...kkk...", ".kkmamkk.", "kmmmmmmmk", "kk.....kk", "k.......k"]
    static let dragonHead = FXSprite("dragonhead", ["..kk......", ".kaak.....", "kaaaakkkk.", "kahaaaaaak", "kaaaaakkk.", ".kaaak....", "..kkkkkkk."])
    static let skeletonGrid: RpgGrid = [".kkkk..", "klllhk.", "kakkak.", ".kllk..", "..kk...", ".klllk.", "kl.l.lk", "..klk..", ".kl.lk.", ".k...k."]
    static let pawGrid: RpgGrid = ["d.d.d", ".....", ".ddd.", "ddddd", ".ddd."]
    static let ghostGrid: RpgGrid = [".kkkkk.", "kllhllk", "kldldlk", "klllllk", "kllmllk", "klllllk", "klllllk", "kl.l.lk", "k.k.k.k"]
    static let birdGrid: RpgGrid = ["k.........k", "kk.......kk", "klk.kkk.klk", ".kllkhkllk.", "..kklllkk..", "....kmk...."]

    static let summonerLooks: [String: FXLook] = [
        "s_orb": FXLook(pal: spiritPal, shot: spiritOrb),
        "s_wolf": FXLook(pal: wolfPal, draw: spectralWolf),
        "s_golem": FXLook(pal: golemPal, draw: golemFist, floor: golemCrack),
        "s_curse": FXLook(pal: cursePal, draw: curse, floor: curseSigil),
        "s_bats": FXLook(pal: batPal, draw: batSwarm),
        "s_drain": FXLook(pal: drainPal, draw: lifeDrain),
        "s_dragon": FXLook(pal: breathPal, draw: dragonBreath),
        "s_ult": FXLook(pal: demonPal, draw: demonFall, floor: demonEye),
        "j_nec1": FXLook(pal: bonePal, draw: skeletonRise),
        "j_nec2": FXLook(pal: deathPal, draw: deathWave),
        "j_beast1": FXLook(pal: beastPal, draw: beastClaw, floor: pawTrack),
        "j_beast2": FXLook(pal: spiritKingPal, draw: spiritKing, floor: natureRune),
        "t2_su1a": FXLook(pal: wraithPal, draw: wraithLegion),
        "t2_su1b": FXLook(pal: boneSpearPal, draw: boneSpears),
        "t3_su1a": FXLook(pal: doomPal, draw: apocalypse, floor: doomRune),
        "t3_su1b": FXLook(pal: harvestPal, draw: soulHarvest),
        "t2_su2a": FXLook(pal: fireDragonPal, draw: fireDragon),
        "t2_su2b": FXLook(pal: stampedePal, draw: stampede, floor: pawTrack),
        "t3_su2a": FXLook(pal: divineBeastPal, draw: divineBeast, floor: featherMark),
        "t3_su2b": FXLook(pal: spiritStormPal, draw: spiritStorm),
    ]

    /// 정령탄: a crystal spirit orb with two fairy lights circling it.
    private static func spiritOrb(_ c: CGContext, _ s: ShotF) {
        let p = spiritPal
        for k in 1...5 { fade(c, 0.6 - Double(k) * 0.1) { ellipse(c, s.x - s.ux * Double(k) * 3, s.y - s.uy * Double(k) * 3, 2.5 - Double(k) * 0.35, p.md) } }
        glow(c, s.x, s.y, 9, p.lt, 0.9)
        ellipse(c, s.x, s.y, 3.6, p.md); ellipse(c, s.x - 0.5, s.y - 0.5, 2.6, p.lt); px(c, s.x - 1, s.y - 1, p.hi, 2)
        for k in 0..<2 {
            let a = s.now * 12 + Double(k) * .pi
            let fx = s.x + cos(a) * 7, fy = s.y + sin(a) * 4
            px(c, fx, fy, p.ac, 2); px(c, fx - cos(a) * 2, fy - sin(a), p.lt)
        }
    }

    /// 늑대 소환: a spectral wolf bounds down the line, raking claws as it goes and biting at the end.
    private static func spectralWolf(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = wolfPal, k = 1 - win(f.t, 0.4, 1)
        let leap = sin(win(f.t, 0, 0.5) * .pi) * 5
        fade(c, k) { glyph(c, wolfHead, p, f.x, f.y - 10 - leap, dir: f.dir) }
        fade(c, 0.4 * k) { glyph(c, wolfHead, p, f.x - cos(f.dir) * 8, f.y - 10 - sin(f.dir) * 8, dir: f.dir) }
        if f.t > 0.15 {
            fade(c, 1 - win(f.t, 0.3, 1)) {
                for j in -1...1 {
                    let o = Double(j) * 3
                    seg(c, f.x - 4 + o, f.y - 10 - 4, f.x + 2 + o, f.y - 10 + 4, j == 0 ? p.hi : p.lt)
                }
            }
        }
        if f.seq == 5, f.t > 0.2 {
            let u = win(f.t, 0.2, 0.6), g = 6 * (1 - u)
            fade(c, 1 - win(f.t, 0.5, 1)) {
                crescent(c, f.x + cos(f.dir) * 6, f.y - 10 - g, 5, .pi * 0.15, .pi * 0.85, 2, p)
                crescent(c, f.x + cos(f.dir) * 6, f.y - 10 + g, 5, -.pi * 0.15, -.pi * 0.85, 2, p)
            }
        }
        return true
    }

    /// 골렘 소환: a stone golem's fist slams down four times, rocks flying.
    private static func golemCrack(_ c: CGContext, _ f: FXF) -> Bool {
        guard f.t > 0.25 else { return true }
        fade(c, 1 - win(f.t, 0.7, 1)) { for i in 0..<5 { crack(c, f.x, f.y, Double(i) * 1.26 + Double(f.seq), f.r * 0.7, earthPal, seed: f.seed &+ UInt64(i), glow: 0.3) } }
        return true
    }

    private static func golemFist(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst(let r) = f.kind else { return false }
        let p = golemPal
        if f.t < 0.25 {
            let u = easeIn(f.t / 0.25)
            fade(c, 0.4) { ellipse(c, f.x, f.y, 8 * u + 2, outline, squash: 0.5) }
            glyph(c, "golemfist", golemFistGrid, p, f.x, f.y - 8 - 60 * (1 - u))
            return true
        }
        let u = easeOut(win(f.t, 0.25, 1))
        fade(c, 1 - win(f.t, 0.25, 0.55)) { glyph(c, "golemfist", golemFistGrid, p, f.x, f.y - 8) }
        fade(c, 1 - win(f.t, 0.5, 1)) { shock(c, f.x, f.y, r * u, 2, earthPal, squash: 0.45) }
        fling(c, f.x, f.y, 10, 90, win(f.t, 0.25, 1), seed: f.seed, Tones(p.md, p.dk, p.ac), spread: 0.9, gravity: 260, size: 2)
        fade(c, 0.6 * (1 - u)) { for k in 0..<3 { puff(c, f.x - 8 + Double(k) * 8, f.y - 2 - u * 6, 3 + u * 4, dustPal.lt, dustPal.md) } }
        return true
    }

    /// 저주: a violet pentagram burns into the ground and wailing wisps rise from it.
    private static func curseSigil(_ c: CGContext, _ f: FXF) -> Bool {
        let p = cursePal, u = easeOut(win(f.t, 0, 0.3))
        fade(c, 1 - win(f.t, 0.7, 1)) {
            circle(c, f.x, f.y, f.r * u, p.md, squash: 0.5)
            circle(c, f.x, f.y, f.r * u - 2, p.dk, squash: 0.5)
            pentagram(c, f.x, f.y, f.r * 0.9 * u, f.age * 0.5, p.lt, squash: 0.5)
        }
        return true
    }

    private static func curse(_ c: CGContext, _ f: FXF) -> Bool {
        let p = cursePal
        var r = KartRNG(seed: f.seed)
        for i in 0..<5 {
            let u = win(f.t, Double(i) * 0.1, Double(i) * 0.1 + 0.6)
            guard u > 0, u < 1 else { continue }
            let a = Double(r.int(628)) / 100, d = f.r * 0.6 * Double(r.int(100)) / 100
            let wx = f.x + cos(a) * d + sin(u * 7) * 3, wy = f.y + sin(a) * d * 0.5 - u * 28
            fade(c, 1 - u) { glyph(c, "skull", skullGrid, p, wx, wy); px(c, wx, wy + 4, p.md); px(c, wx, wy + 6, p.dk) }
        }
        rise(c, f.x, f.y, 10, f.r * 0.7, 18, f.t, seed: f.seed &+ 2, Tones(p.ac, p.lt, p.md))
        return true
    }

    /// 박쥐떼: bats flap round the summoner in a ring, red eyes glinting.
    private static func batSwarm(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, _) = f.kind else { return false }
        let p = batPal, k = 1 - win(f.t, 0.6, 1)
        let a = ang - .pi / 2 + f.t * 1.4
        let bx = f.ox + cos(a) * 28, by = f.oy - 10 + sin(a) * 14
        let up = Int(f.age * 18) % 2 == 0
        fade(c, 0.4 * k) { for j in 1...3 { let b = a - Double(j) * 0.18; px(c, f.ox + cos(b) * 28, f.oy - 10 + sin(b) * 14, p.md) } }
        fade(c, k) { glyph(c, up ? "batU" : "batD", up ? batUpGrid : batDownGrid, p, bx, by) }
        return true
    }

    /// 생명 흡수: blood flows out of each foe into the summoner, who glows red as motes are drawn in.
    private static func lifeDrain(_ c: CGContext, _ f: FXF) -> Bool {
        let p = drainPal
        switch f.kind {
        case .burst:
            let tx = f.ox, ty = f.oy - 10
            for i in 0..<8 {
                let u = (f.age * 1.6 + Double(i) / 8).truncatingRemainder(dividingBy: 1)
                let x = f.x + (tx - f.x) * u, y = f.y - 6 + (ty - f.y + 6) * u - sin(u * .pi) * 8
                fade(c, 1 - win(f.t, 0.7, 1)) { px(c, x, y, i % 3 == 0 ? p.lt : p.md, 2) }
            }
            fade(c, 1 - f.t) { circle(c, f.x, f.y - 6, 3 + 3 * sin(f.age * 20), p.md, squash: 0.8) }
            return true
        case .levelUp:
            for i in 0..<12 {
                let u = win(f.t, Double(i % 4) * 0.08, Double(i % 4) * 0.08 + 0.5)
                guard u > 0, u < 1 else { continue }
                let a = Double(i) * 0.52, d = 22 * (1 - u)
                px(c, f.x + cos(a) * d, f.y - 10 + sin(a) * d * 0.6, i % 2 == 0 ? p.lt : p.md, 2)
            }
            glow(c, f.x, f.y - 10, 12, p.md, 0.6 * (1 - f.t))
            return true
        default: return false
        }
    }

    /// 용 소환: a dragon's head rears at the summoner and its breath billows forward in a widening cone of fire.
    private static func dragonBreath(_ c: CGContext, _ f: FXF) -> Bool {
        let p = breathPal
        if f.seq == 0 { fade(c, 1 - win(f.t, 0.6, 1)) { glyph(c, dragonHead, greenDragonPal, f.ox + cos(f.dir) * 10, f.oy - 14, dir: f.dir) } }
        let grow = easeOut(f.t), s = f.r * (0.5 + 0.12 * Double(f.seq))
        fade(c, 1 - win(f.t, 0.5, 1)) {
            glow(c, f.x, f.y - 6, s * grow + 4, p.lt)
            for i in 0..<5 {
                let a = Double(i) * 1.26 + f.age * 6
                flame(c, f.x + cos(a) * s * 0.5 * grow, f.y + sin(a) * s * 0.25 * grow, (8 + Double(f.seq) * 2) * (1 - f.t * 0.5), 5, p, phase: f.age * 30 + Double(i))
            }
        }
        rise(c, f.x, f.y - 4, 6, s * 0.5, 18, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md, p.dk), size: 2)
        return true
    }

    /// 대악마 강림: a demon's eye opens on the ground; black hellfire meteors smash into it.
    private static func demonEye(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = demonPal, open = easeOut(f.t)
        fade(c, 0.5 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.8, p.dk, squash: 0.5)
            circle(c, f.x, f.y, r * 0.8 - 1, p.md, squash: 0.5, dash: 2)
            ellipse(c, f.x, f.y, r * 0.35, p.md, squash: 0.45 * open + 0.02)
            ellipse(c, f.x, f.y, r * 0.12, p.dk, squash: 1.2 * open + 0.05)
        }
        return true
    }

    private static func demonFall(_ c: CGContext, _ f: FXF) -> Bool {
        let p = demonPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.22 {
                let u = easeIn(f.t / 0.22), hx = f.x + 18 * (1 - u), hy = f.y - 90 * (1 - u)
                for k in 0..<10 { let q = Double(k) * 3; fade(c, 1 - Double(k) / 10) { px(c, hx + q * 0.2, hy - q, k < 3 ? p.ac : p.md, k < 5 ? 3 : 2) } }
                ellipse(c, hx, hy, 4.5, p.dk); ellipse(c, hx, hy, 2.5, p.md); px(c, hx, hy, p.hi)
                return true
            }
            let u = easeOut(win(f.t, 0.22, 1)), k = 1 - win(f.t, 0.55, 1)
            fade(c, k) {
                glow(c, f.x, f.y - 6, r * 0.8 * u, p.ac, 0.7)
                shock(c, f.x, f.y, r * u, 3, p, squash: 0.5)
                spike(c, f.x - 6, f.y - 2, -.pi / 2 - 0.5, 12 * u, p.dk, 3); spike(c, f.x + 6, f.y - 2, -.pi / 2 + 0.5, 12 * u, p.dk, 3)
                for i in 0..<5 { flame(c, f.x - 10 + Double(i) * 5, f.y + 1, 10 * (1 - u * 0.5), 4, hellfireVioletPal, phase: f.age * 28 + Double(i)) }
            }
            return true
        default: return false
        }
    }

    /// 해골 병사 소환: skeleton soldiers claw up out of the ground and swing bone blades.
    private static func skeletonRise(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = bonePal, up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.7, 1)
        fade(c, 0.6 * k) { ellipse(c, f.x, f.y, 6, outline, squash: 0.4) }
        fade(c, k) { glyph(c, "skeleton", skeletonGrid, p, f.x, f.y - 5 * up) }
        if f.t > 0.3 {
            let sw = easeOut(win(f.t, 0.3, 0.6))
            fade(c, k) { crescent(c, f.x, f.y - 6, 9, f.dir - 1.4, f.dir - 1.4 + 2.6 * sw, 2, p) }
        }
        fling(c, f.x, f.y, 4, 40, f.t, seed: f.seed, Tones(dustPal.md, dustPal.dk), spread: 0.8, gravity: 120)
        return true
    }

    /// 죽음의 파동: dark rings roll outward with skulls riding them.
    private static func deathWave(_ c: CGContext, _ f: FXF) -> Bool {
        let p = deathPal, u = easeOut(f.t), r = f.r * u, k = 1 - win(f.t, 0.5, 1)
        fade(c, 0.45 * k) { for w in 0..<4 { circle(c, f.x, f.y - 4, r - Double(w), w < 2 ? p.md : p.dk, squash: 0.5) } }
        fade(c, k) {
            circle(c, f.x, f.y - 4, r + 1, p.lt, squash: 0.5)
            for i in 0..<6 { let a = Double(i) * 1.05 + f.age; glyph(c, "skullD", skullGrid, p, f.x + cos(a) * r, f.y - 6 + sin(a) * r * 0.5) }
        }
        return true
    }

    /// 맹수 소환: claws rake along five lines, paw prints left behind.
    private static func beastClaw(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let a, _) = f.kind else { return false }
        let p = beastPal, sw = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.5, 1)
        let nx = -sin(a), ny = cos(a)
        fade(c, k) {
            for j in -1...1 {
                let o = Double(j) * 3, l = 7 * sw
                seg(c, f.x + nx * o - cos(a + 0.6) * l, f.y - 6 + ny * o - sin(a + 0.6) * l, f.x + nx * o + cos(a + 0.6) * l, f.y - 6 + ny * o + sin(a + 0.6) * l, j == 0 ? p.hi : p.lt, 2)
            }
        }
        return true
    }

    private static func pawTrack(_ c: CGContext, _ f: FXF) -> Bool {
        fade(c, 0.55 * (1 - win(f.t, 0.6, 1))) { glyph(c, "paw", pawGrid, beastPal, f.x, f.y) }
        return true
    }

    /// 정령왕 강림: a leafy rune marks the ground; spirit lights of every colour dive in and burst.
    private static func natureRune(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = spiritKingPal
        fade(c, 0.4 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.8, p.md, squash: 0.5)
            for i in 0..<6 { let a = Double(i) * 1.05 + f.age; px(c, f.x + cos(a) * r * 0.8, f.y + sin(a) * r * 0.4, p.ac, 2); px(c, f.x + cos(a) * r * 0.6, f.y + sin(a) * r * 0.3, p.lt) }
        }
        return true
    }

    private static func spiritKing(_ c: CGContext, _ f: FXF) -> Bool {
        let p = spiritKingPal
        let tints = Tones(p.lt, elemPal(.fire).lt, elemPal(.ice).lt, p.ac)
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.25 {
                let u = easeIn(f.t / 0.25), hx = f.x - 14 * (1 - u), hy = f.y - 80 * (1 - u)
                for k in 0..<8 { px(c, hx - Double(k) * 1.5 + sin(Double(k) + f.age * 20) * 2, hy - Double(k) * 3.5, tints[k % 4], k < 3 ? 2 : 1) }
                glow(c, hx, hy, 8, tints[f.seq % 4]); ellipse(c, hx, hy, 2.5, p.hi)
                return true
            }
            let u = easeOut(win(f.t, 0.25, 1))
            fade(c, 1 - u) {
                for i in 0..<8 { let a = Double(i) * .pi / 4; px(c, f.x + cos(a) * r * 0.8 * u, f.y - 4 + sin(a) * r * 0.4 * u, tints[i % 4], 2) }
                circle(c, f.x, f.y, r * u, p.lt, squash: 0.5)
            }
            fling(c, f.x, f.y, 6, 50, win(f.t, 0.25, 1), seed: f.seed, Tones(forestPal.lt, forestPal.md), spread: .pi, gravity: 30, size: 2)
            return true
        default: return false
        }
    }

    /// 망령 군단: wailing ghosts swoop back and forth over the area.
    private static func wraithLegion(_ c: CGContext, _ f: FXF) -> Bool {
        let p = wraithPal
        var r = KartRNG(seed: f.seed)
        for _ in 0..<3 {
            let a0 = Double(r.int(628)) / 100, sweep = f.t * 3
            func at(_ s: Double) -> (Double, Double) {
                (f.x + cos(a0 + s) * f.r * 0.6, f.y - 10 + sin(a0 + s) * f.r * 0.3 - sin(f.t * .pi) * 6)
            }
            let (gx, gy) = at(sweep)
            fade(c, 0.85 * sin(f.t * .pi)) {
                for j in 1...3 { let (tx, ty) = at(sweep - Double(j) * 0.18); fade(c, 0.35 - Double(j) * 0.08) { glyph(c, "ghost", ghostGrid, p, tx, ty) } }
                glow(c, gx, gy, 8, p.ac, 0.6)
                glyph(c, "ghost", ghostGrid, p, gx, gy)
            }
        }
        return true
    }

    /// 뼈 창: ivory spikes punch up out of the ground in a line, green light at their roots.
    private static func boneSpears(_ c: CGContext, _ f: FXF) -> Bool {
        let p = boneSpearPal, h = punch(f.t, at: 0.12, hold: 0.35)
        var r = KartRNG(seed: f.seed)
        fade(c, 0.6 * h) { ellipse(c, f.x, f.y, 7, p.ac, squash: 0.4) }
        for _ in 0..<3 {
            let ox = Double(r.int(11)) - 5, oy = Double(r.int(5)) - 2, tall = (12 + Double(r.int(10))) * h
            let lean = (Double(r.int(5)) - 2) * 0.08
            guard tall > 1 else { continue }
            let tipx = f.x + ox + sin(lean) * tall, tipy = f.y + oy - tall
            seg(c, f.x + ox - 2, f.y + oy, tipx, tipy, p.dk); seg(c, f.x + ox + 2, f.y + oy, tipx, tipy, p.md)
            seg(c, f.x + ox, f.y + oy, tipx, tipy, p.lt); px(c, tipx, tipy, p.hi)
        }
        return true
    }

    /// 묵시록: red doom runes; black meteors trailing green fire hammer down.
    private static func doomRune(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = doomPal
        fade(c, 0.4 + 0.5 * f.t) {
            circle(c, f.x, f.y, r * 0.75, p.ac, squash: 0.5)
            let s = r * 0.4
            seg(c, f.x - s, f.y - s * 0.5, f.x + s, f.y + s * 0.5, p.ac); seg(c, f.x - s, f.y + s * 0.5, f.x + s, f.y - s * 0.5, p.ac)
        }
        return true
    }

    private static func apocalypse(_ c: CGContext, _ f: FXF) -> Bool {
        let p = doomPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.22 {
                let u = easeIn(f.t / 0.22), hx = f.x - 40 * (1 - u), hy = f.y - 80 * (1 - u)
                for k in 0..<12 { let q = Double(k) * 3; fade(c, 1 - Double(k) / 12) { px(c, hx - q * 0.45, hy - q * 0.9, k < 4 ? p.lt : p.md, k < 6 ? 3 : 2) } }
                ellipse(c, hx, hy, 4.5, p.dk); px(c, hx, hy, p.ac, 2)
                return true
            }
            let u = easeOut(win(f.t, 0.22, 1))
            fade(c, 1 - win(f.t, 0.55, 1)) {
                glow(c, f.x, f.y - 6, r * 0.7 * u, p.md, 0.8)
                shock(c, f.x, f.y, r * u, 3, p, squash: 0.5)
                for i in 0..<4 { flame(c, f.x - 8 + Double(i) * 5, f.y + 1, 9 * (1 - u * 0.5), 4, p, phase: f.age * 30 + Double(i)) }
            }
            return true
        default: return false
        }
    }

    /// 영혼 수확: a blue scythe cuts each foe and its soul flies back to the summoner.
    private static func soulHarvest(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash(let ang, _) = f.kind else { return false }
        let p = harvestPal, sw = easeOut(win(f.t, 0, 0.35))
        fade(c, 1 - win(f.t, 0.4, 0.7)) {
            let a = ang - 1.6 + 3 * sw
            crescent(c, f.x, f.y - 8, 11, a - 2, a, 4, p, squash: 0.8, rim: p.dk)
        }
        if f.t > 0.3 {
            let u = easeIn(win(f.t, 0.3, 1)), sx = f.x + (f.ox - f.x) * u, sy = f.y - 10 + (f.oy - 14 - f.y + 10) * u - sin(u * .pi) * 10
            glow(c, sx, sy, 5, p.lt, 0.8); ellipse(c, sx, sy, 2, p.hi)
            fade(c, 0.5) { for j in 1...3 { px(c, sx - (f.ox - f.x) * 0.04 * Double(j), sy + Double(j), p.ac) } }
        }
        return true
    }

    /// 화룡 강림: a fire dragon's body sweeps along the line over a carpet of flame, its head leading.
    private static func fireDragon(_ c: CGContext, _ f: FXF) -> Bool {
        let p = fireDragonPal, k = 1 - win(f.t, 0.55, 1), bob = sin(f.age * 10 + Double(f.seq)) * 3
        fade(c, k) {
            for i in 0..<3 { flame(c, f.x - 6 + Double(i) * 6, f.y + 1, 8 + Double(i % 2) * 4, 5, p, phase: f.age * 28 + Double(i)) }
            let bx = f.x, by = f.y - 18 + bob
            ellipse(c, bx, by, 6, p.dk); ellipse(c, bx, by - 1, 5, p.md); ellipse(c, bx - 1, by - 2, 2.5, p.lt)
            for s in 0..<3 { let sx = bx - 3 + Double(s) * 3; seg(c, sx, by - 5, sx + 1, by - 8, p.ac) }
            if f.seq == 6 { glyph(c, dragonHead, p, bx + cos(f.dir) * 9, by - 2, dir: f.dir) }
        }
        return true
    }

    /// 야수 대군: beasts stampede across the area in dust, paw prints and claw marks everywhere.
    private static func stampede(_ c: CGContext, _ f: FXF) -> Bool {
        let p = stampedePal, k = 1 - win(f.t, 0.6, 1)
        var r = KartRNG(seed: f.seed)
        for _ in 0..<2 {
            let ox = Double(r.int(Int(f.r))) - f.r / 2, oy = Double(r.int(Int(f.r / 2))) - f.r / 4
            let run = (f.t - 0.5) * 50
            let bx = f.x + ox + cos(f.dir) * run, by = f.y + oy + sin(f.dir) * run * 0.5
            fade(c, k) {
                ellipse(c, bx, by - 5, 5, p.dk, squash: 0.7); ellipse(c, bx - 1, by - 6, 3, p.md, squash: 0.7)
                seg(c, bx + cos(f.dir) * 4, by - 7, bx + cos(f.dir) * 7, by - 10, p.hi)
            }
            fade(c, 0.6 * k) { puff(c, bx - cos(f.dir) * 6, by - 2, 3 + f.t * 3, dustPal.lt, dustPal.md) }
        }
        return true
    }

    /// 신수 강림: feathers circle the mark; a great spirit bird dives in and bursts in a gust.
    private static func featherMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = divineBeastPal
        fade(c, 0.4 + 0.5 * f.t) { for i in 0..<6 { let a = Double(i) * 1.05 + f.age * 2; seg(c, f.x + cos(a) * r * 0.7, f.y + sin(a) * r * 0.35, f.x + cos(a + 0.3) * r * 0.7, f.y + sin(a + 0.3) * r * 0.35, p.lt) } }
        return true
    }

    private static func divineBeast(_ c: CGContext, _ f: FXF) -> Bool {
        let p = divineBeastPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.25 {
                let u = easeIn(f.t / 0.25), hx = f.x + 30 * (1 - u), hy = f.y - 8 - 70 * (1 - u)
                fade(c, 0.5) { for k in 1...4 { px(c, hx + Double(k) * 4, hy - Double(k) * 8, p.lt, 2) } }
                glyph(c, "bird", birdGrid, p, hx, hy)
                return true
            }
            let u = easeOut(win(f.t, 0.25, 1))
            fade(c, 1 - win(f.t, 0.5, 1)) {
                for k in 0..<3 { let a = f.age * 16 + Double(k) * 2.1; circle(c, f.x, f.y - Double(k) * 4, 5 + Double(k) * 3 + u * 6, p.lt, squash: 0.4, from: a, to: a + 3) }
                circle(c, f.x, f.y, r * u, p.md, squash: 0.5)
            }
            fall(c, f.x, f.y, 8, r * 0.7, 26, win(f.t, 0.2, 1), seed: f.seed, Tones(p.hi, p.lt, p.ac), sway: 4)
            return true
        default: return false
        }
    }

    /// 정령 대폭풍: four elemental spirits race round the summoner in a great vortex, trailing their colours.
    private static func spiritStorm(_ c: CGContext, _ f: FXF) -> Bool {
        let p = spiritStormPal, k = punch(f.t, at: 0.2, hold: 0.4)
        let orbs = spiritOrbs
        fade(c, k) {
            circle(c, f.x, f.y, f.r * 0.9, p.md, squash: 0.45, dash: 4)
            for (i, o) in orbs.enumerated() {
                let a = f.now * 3 + Double(i) * .pi / 2 + Double(f.seq) * 0.4
                let rr = f.r * (0.45 + 0.35 * sin(f.now * 2 + Double(i)))
                for j in 1...5 { let b = a - Double(j) * 0.12; fade(c, 1 - Double(j) * 0.18) { px(c, f.x + cos(b) * rr, f.y - 8 + sin(b) * rr * 0.45, o.md, 2) } }
                let ox = f.x + cos(a) * rr, oy = f.y - 8 + sin(a) * rr * 0.45
                glow(c, ox, oy, 6, o.lt, 0.8); ellipse(c, ox, oy, 2.5, o.lt); px(c, ox, oy, o.hi)
            }
        }
        return true
    }
}

// MARK: - mechanic

extension RpgArt {
    static let plasmaPal = FXPal(0xFFFFFF, 0xC0FFFF, 0x40D8F0, 0x105A7A, 0xFFFFFF)
    static let turretPal = FXPal(0xFFF0C0, 0xFFB050, 0xD8701A, 0x4A2A10, 0x9AA8B8)
    static let rocketPal = FXPal(0xFFFFFF, 0xE8E8F0, 0xA0A8B8, 0x3A3A4A, 0xFF5A3A)
    static let minePal = FXPal(0xFFF0C0, 0xFFA040, 0xE04A1A, 0x2A2A30, 0x6A6A78)
    static let flamerPal = FXPal(0xFFFFFF, 0xFFE070, 0xFF8A20, 0xB02A10, 0x60A0FF)
    static let barrierPal = FXPal(0xFFFFFF, 0xB0FFF0, 0x40E0C0, 0x0A5A50, 0xFFFFFF)
    static let dronePal = FXPal(0xFFFFFF, 0xD0E8FF, 0x7AA0C8, 0x2A3A4A, 0xFF4A4A)
    static let laserPal = FXPal(0xFFFFFF, 0xFFB0F0, 0xF040D0, 0x5A0A6A, 0x80FFFF)
    static let heavyMGPal = FXPal(0xFFFFE0, 0xFFC060, 0xFF6A20, 0x6A2A10, 0xA0A0A0)
    static let shellPal = FXPal(0xFFFFE0, 0xFFD070, 0xD07A30, 0x2A2A20, 0x8A8A70)
    static let twinTurretPal = FXPal(0xFFFFFF, 0xB0FFC0, 0x40D070, 0x0A4A2A, 0xA0A8B8)
    static let robotPal = FXPal(0xFFFFFF, 0xFFE070, 0xE0A020, 0x3A3A44, 0x60D0FF)
    static let railPal = FXPal(0xFFFFFF, 0xD0E0FF, 0x7A8AFF, 0x1A1A6A, 0x80FFFF)
    static let clusterPal = FXPal(0xFFFFE0, 0xFFC050, 0xF06A20, 0x3A3A30, 0x8A8A6A)
    static let orbitalPal = FXPal(0xFFFFFF, 0xFFC0F0, 0xE050C0, 0x4A0A4A, 0xFF3A3A)
    static let tankPal = FXPal(0xFFFFFF, 0xC8D0C0, 0x8A9A7A, 0x2A3A20, 0xFFC040)
    static let legionPal = FXPal(0xFFFFFF, 0xB0D8FF, 0x4A8AE8, 0x10306A, 0xA0A8B8)
    static let squadPal = FXPal(0xFFFFFF, 0xFFF0A0, 0xE8C040, 0x4A3A10, 0xFF6A3A)
    static let fortressPal = FXPal(0xFFF0E0, 0xD0A0A0, 0x9A5A5A, 0x2A1414, 0xFF3A3A)
    static let teslaPal = FXPal(0xFFFFFF, 0xFFF8A0, 0xF0D030, 0x3A3A44, 0x80E0FF)

    static let turretGrid: RpgGrid = ["...kkkkk...", "..kmmmmmk..", ".kmmllhmmk.", "..kmmmmmk..", "...kkkkk...", "....kdk....", "...kdddk...", "..kd.d.dk..", ".kk..k..kk."]
    static let quadTurretGrid: RpgGrid = ["..kkk..", ".kmlhk.", "kmmmmmk", ".kdddk.", "kd.d.dk"]
    static let fortressGrid: RpgGrid = ["....kkkkk....", "..kkmmmmmkk..", ".kmmllllhmmk.", "kmmlllllllmmk", "kmmmmmmmmmmmk", "kdddddddddddk", "kkkkkkkkkkkkk"]
    static let mineGrid: RpgGrid = [".kkkkk.", "kmmammk", "kdddddk", ".kkkkk."]
    static let droneGrid: RpgGrid = ["lll...lll", "..kkkkk..", ".kmmmmmk.", "..kmakk.."]
    static let bigDroneGrid: RpgGrid = ["hhhh...hhhh", "..k.....k..", "..kkkkkkk..", ".kmlllllmk.", ".kmmmmmmmk.", "..kkmamkk..", "....kkk...."]
    static let mechFist = FXSprite("mechfist", ["..kkkk..", ".kllllk.", "kllhllkk", "kmllllaa", "kmmlllkk", ".kmmmk..", "..kkkk.."])

    static let mechanicLooks: [String: FXLook] = [
        "x_burst": FXLook(pal: plasmaPal, hit: { c, f in impact(c, f) }, shot: plasmaBolt),
        "x_turret": FXLook(pal: turretPal, shot: { c, s in tracer(c, s, turretPal, len: 9) }, trap: { c, t in turretArt(c, t, "turret", turretGrid, barrels: 1, turretPal) }),
        "x_rocket": FXLook(pal: rocketPal, hit: rocketBoom, shot: rocket),
        "x_mine": FXLook(pal: minePal, draw: mineBlast, trap: mine),
        "x_flame": FXLook(pal: flamerPal, draw: flamethrower),
        "x_barrier": FXLook(pal: barrierPal, draw: energyCurtain, floor: hexFloor),
        "x_drone": FXLook(pal: dronePal, draw: { c, f in droneStrike(c, f, dronePal, squad: false) }),
        "x_ult": FXLook(pal: laserPal, draw: overdriveLaser),
        "j_x1a": FXLook(pal: heavyMGPal, hit: { c, f in impact(c, f) }, shot: { c, s in tracer(c, s, heavyMGPal, len: 14, thick: true) }),
        "j_x1b": FXLook(pal: shellPal, hit: rocketBoom, shot: tankShell),
        "j_x2a": FXLook(pal: twinTurretPal, shot: { c, s in tracer(c, s, twinTurretPal, len: 10) }, trap: { c, t in turretArt(c, t, "turret", turretGrid, barrels: 2, twinTurretPal) }),
        "j_x2b": FXLook(pal: robotPal, draw: rocketFist),
        "t2_me1a": FXLook(pal: railPal, hit: pierceHit, shot: railSlug),
        "t2_me1b": FXLook(pal: clusterPal, draw: clusterBomb, floor: targetMark),
        "t3_me1a": FXLook(pal: orbitalPal, draw: orbitalStrike, floor: targetMark),
        "t3_me1b": FXLook(pal: tankPal, draw: steelTank),
        "t2_me2a": FXLook(pal: legionPal, shot: { c, s in tracer(c, s, legionPal, len: 7) }, trap: { c, t in turretArt(c, t, "quadTurret", quadTurretGrid, barrels: 1, legionPal) }),
        "t2_me2b": FXLook(pal: squadPal, draw: { c, f in droneStrike(c, f, squadPal, squad: true) }),
        "t3_me2a": FXLook(pal: fortressPal, shot: { c, s in tracer(c, s, fortressPal, len: 12, thick: true) }, trap: { c, t in turretArt(c, t, "fortress", fortressGrid, barrels: 3, fortressPal) }),
        "t3_me2b": FXLook(pal: teslaPal, draw: teslaJudgement),
    ]

    /// A gear outline with square teeth.
    static func cog(_ c: CGContext, _ x: Double, _ y: Double, _ r: Double, _ teeth: Int, _ rot: Double, _ col: CGColor, squash: Double = 1) {
        circle(c, x, y, r, col, squash: squash)
        for i in 0..<teeth {
            let a = rot + Double(i) / Double(teeth) * 2 * .pi
            seg(c, x + cos(a) * r, y + sin(a) * r * squash, x + cos(a) * (r + 3), y + sin(a) * (r + 3) * squash, col, 2)
        }
    }

    /// 연사탄: plasma pellets, capsule-shaped, glowing cyan.
    private static func plasmaBolt(_ c: CGContext, _ s: ShotF) {
        let p = plasmaPal
        for k in 0..<6 { fade(c, 0.6 - Double(k) * 0.1) { px(c, s.x - s.ux * Double(4 + k * 2), s.y - s.uy * Double(4 + k * 2), p.md, 2) } }
        glow(c, s.x, s.y, 6, p.lt, 0.8)
        seg(c, s.x - s.ux * 3, s.y - s.uy * 3, s.x + s.ux * 2, s.y + s.uy * 2, p.lt, 3)
        seg(c, s.x - s.ux * 2, s.y - s.uy * 2, s.x + s.ux, s.y + s.uy, p.hi, 1)
    }

    /// A bullet with a tracer line; heavy guns fire thicker rounds.
    static func tracer(_ c: CGContext, _ s: ShotF, _ p: FXPal, len: Double, thick: Bool = false) {
        for k in 0..<Int(len) { fade(c, 0.9 - Double(k) / len * 0.8) { px(c, s.x - s.ux * Double(k + 1), s.y - s.uy * Double(k + 1), k < 3 ? p.hi : (k < Int(len / 2) ? p.lt : p.md), thick ? 2 : 1) } }
        px(c, s.x, s.y, p.hi, thick ? 3 : 2)
    }

    /// A turret on its tripod, barrel(s) sweeping round the way it was set facing, a light blinking.
    static func turretArt(_ c: CGContext, _ t: TrapF, _ name: String, _ grid: RpgGrid, barrels: Int, _ p: FXPal) {
        let fading = t.left < 2 && Int(t.now * 8) % 2 == 0
        let aim = t.dir + sin(t.now * 1.5 + Double(t.seq)) * 0.7
        let hx = t.x, hy = t.y - Double(grid.count) + 2
        fade(c, fading ? 0.5 : 1) {
            KartArt.fill(c, rgb(0, 0, 0, 0.25), CGFloat(t.x - 6), CGFloat(t.y), 12, 2)
            glyph(c, name, grid, p, t.x, t.y - Double(grid.count) / 2)
            let ux = cos(aim), uy = sin(aim) * 0.6, nx = -uy, ny = ux
            for b in 0..<barrels {
                let o = (Double(b) - Double(barrels - 1) / 2) * 2
                seg(c, hx + nx * o, hy + ny * o, hx + nx * o + ux * 7, hy + ny * o + uy * 7, p.dk, 2)
                seg(c, hx + nx * o, hy + ny * o, hx + nx * o + ux * 7, hy + ny * o + uy * 7, p.ac)
            }
            if (t.now * 2).truncatingRemainder(dividingBy: 1) < 0.12 { star(c, hx + ux * 9, hy + uy * 9, 2, p.lt, p.hi) }
            px(c, hx - 1, hy + 1, Int(t.now * 5) % 2 == 0 ? p.hi : p.md)
        }
    }

    /// 로켓 발사: a finned rocket with an exhaust flame and a trail of smoke puffs.
    private static func rocket(_ c: CGContext, _ s: ShotF) {
        let p = rocketPal, nx = -s.uy, ny = s.ux, d = flown(s)
        for k in 0..<6 {
            let back = 12 + Double(k) * 6 + d.truncatingRemainder(dividingBy: 6)
            fade(c, 0.6 - Double(k) * 0.09) { puff(c, s.x - s.ux * back, s.y - s.uy * back - Double(k) * 0.6, 2 + Double(k) * 0.6, smokePal.lt, smokePal.md) }
        }
        flame(c, s.x - s.ux * 9, s.y - s.uy * 9 + 2, 4 + Double(Int(s.now * 30) % 2), 3, flamerPal, phase: s.now * 40)
        seg(c, s.x - s.ux * 8, s.y - s.uy * 8, s.x + s.ux * 2, s.y + s.uy * 2, p.md, 3)
        seg(c, s.x - s.ux * 8, s.y - s.uy * 8, s.x + s.ux * 2, s.y + s.uy * 2, p.lt)
        px(c, s.x + s.ux * 3, s.y + s.uy * 3, p.ac, 2)
        for f in [-1.0, 1.0] { seg(c, s.x - s.ux * 8, s.y - s.uy * 8, s.x - s.ux * 10 + nx * 3 * f, s.y - s.uy * 10 + ny * 3 * f, p.ac) }
    }

    /// A rocket or shell going off on the target.
    private static func rocketBoom(_ c: CGContext, _ f: FXF) -> Bool {
        let p = flamerPal, u = easeOut(f.t), s = f.crit ? 1.4 : 1.0
        if f.t < 0.2 { glow(c, f.x, f.y, 12 * s, p.hi, 1 - f.t / 0.2) }
        fade(c, 1 - win(f.t, 0.4, 1)) { glow(c, f.x, f.y, 10 * s * u, p.lt); shock(c, f.x, f.y + 4, 14 * s * u, 2, p, squash: 0.5) }
        fade(c, 0.6 * (1 - u)) { puff(c, f.x, f.y - 4 - u * 8, 3 + u * 5, smokePal.md, smokePal.dk) }
        fling(c, f.x, f.y, 8, 80, f.t, seed: f.seed, Tones(p.hi, p.lt, smokePal.dk), spread: 1.4, gravity: 160, size: 2)
        return true
    }

    /// 지뢰: half-buried mines with a blinking light; they blow shrapnel everywhere.
    private static func mine(_ c: CGContext, _ t: TrapF) {
        let p = minePal
        fade(c, t.armed ? (t.left < 2 && Int(t.now * 8) % 2 == 0 ? 0.4 : 1) : 0.45) { glyph(c, "mine", mineGrid, p, t.x, t.y) }
        if t.armed, Int(t.now * 4 + Double(t.seq)) % 2 == 0 { glow(c, t.x, t.y - 1, 3, p.md, 0.8); px(c, t.x, t.y - 1, p.hi) }
    }

    private static func mineBlast(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .burst = f.kind else { return false }
        let p = minePal, u = easeOut(f.t)
        if f.t < 0.15 { glow(c, f.x, f.y - 4, 20, p.hi, 1 - f.t / 0.15) }
        fade(c, 1 - win(f.t, 0.45, 1)) {
            glow(c, f.x, f.y - 6, f.r * 0.6 * u, p.lt)
            shock(c, f.x, f.y, f.r * u, 3, p, squash: 0.5)
        }
        fling(c, f.x, f.y - 2, 14, 130, f.t, seed: f.seed, Tones(p.ac, p.dk, p.lt), spread: 1.3, gravity: 220, size: 2)
        fade(c, 0.6 * (1 - u)) { for k in 0..<3 { puff(c, f.x - 7 + Double(k) * 7, f.y - 8 - u * 14, 4 + u * 6, smokePal.md, smokePal.dk) } }
        return true
    }

    /// 화염방사기: a roaring jet of flame, blue at the nozzle, widening as it goes.
    private static func flamethrower(_ c: CGContext, _ f: FXF) -> Bool {
        let p = flamerPal, k = 1 - win(f.t, 0.6, 1), w = 4 + Double(f.seq) * 1.3
        fade(c, k) {
            if f.seq == 0 { glow(c, f.ox + cos(f.dir) * 10, f.oy - 8, 6, p.ac, 0.9) }
            glow(c, f.x, f.y - 8, w + 4, p.lt, 0.7)
            for i in 0..<4 {
                let a = f.age * 30 + Double(i) * 1.6 + Double(f.seq)
                let fx = f.x + cos(a) * w * 0.4, fy = f.y - 6 + sin(a) * w * 0.25
                flame(c, fx, fy, w + 3 * sin(f.age * 25 + Double(i)), w * 0.7, p, phase: f.age * 40 + Double(i))
            }
        }
        rise(c, f.x, f.y - 8, 4, w * 0.5, 14, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md, smokePal.md))
        return true
    }

    /// 에너지 방벽: hex tiles light up on the ground and a curtain of energy rises around each ally, scanlines climbing.
    private static func hexFloor(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return true }
        let p = barrierPal, u = easeOut(win(f.t, 0, 0.3))
        fade(c, 0.8 * (1 - win(f.t, 0.7, 1))) {
            for i in 0..<7 {
                let a = Double(i) * 1.047, d = i == 6 ? 0 : 9 * u
                poly(c, f.x + cos(a) * d, f.y + sin(a) * d * 0.5, 4.5 * u, 6, 0, i == 6 ? p.lt : p.md, squash: 0.5)
            }
        }
        return true
    }

    private static func energyCurtain(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = barrierPal, up = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.7, 1), h = 28 * up
        fade(c, 0.25 * k) { box(c, f.x - 13, f.y - h, 26, h, p.md) }
        fade(c, k) {
            seg(c, f.x - 13, f.y, f.x - 13, f.y - h, p.lt); seg(c, f.x + 13, f.y, f.x + 13, f.y - h, p.lt)
            circle(c, f.x, f.y - h, 13, p.hi, squash: 0.3)
            for j in 0..<3 {
                let sy = f.y - (f.age * 40 + Double(j) * 10).truncatingRemainder(dividingBy: max(1, h))
                seg(c, f.x - 12, sy, f.x + 12, sy, p.lt)
            }
        }
        return true
    }

    /// 드론 소환 / 드론 편대: drones zip from the mechanic to each foe and zap it (the squadron: three gold drones with lasers).
    private static func droneStrike(_ c: CGContext, _ f: FXF, _ p: FXPal, squad: Bool) -> Bool {
        guard case .slash = f.kind else { return false }
        let fly = easeOut(win(f.t, 0, 0.3)), k = 1 - win(f.t, 0.7, 1)
        let dx = f.ox + (f.x - f.ox) * fly, dy = f.oy - 18 + (f.y - 20 - f.oy + 18) * fly
        let n = squad ? 3 : 1
        for i in 0..<n {
            let o = squad ? (Double(i) - 1) * 7 : 0, back = squad ? abs(Double(i) - 1) * 4 : 0
            let x = dx + o - cos(f.dir) * back, y = dy - back * 0.5 + sin(f.age * 20 + Double(i)) * 1
            fade(c, k) {
                if !squad { glow(c, x, y + 3, 7, p.ac, 0.5) }
                glyph(c, squad ? "droneS" : "drone", squad ? droneGrid : bigDroneGrid, p, x, y)
                if Int(f.age * 10 + Double(i)) % 2 == 0 { px(c, x, y + (squad ? 2 : 3), p.ac) }
            }
            if fly >= 1, f.t < 0.6 {
                if squad { fade(c, 0.8) { seg(c, x, y + 2, f.x, f.y - 6, p.lt); seg(c, x + 1, y + 2, f.x + 1, f.y - 6, p.hi) } }
                else if Int(f.age * 30) % 3 != 2 { zap(c, x, y + 3, f.x, f.y - 6, elemPal(.thunder), seed: f.seed &+ UInt64(truncatingIfNeeded: Int(f.age * 30)), jag: 2, w: 3, branches: 1) }
            }
        }
        if fly >= 1, f.t < 0.6 { star(c, f.x, f.y - 6, 3, p.lt, p.hi) }
        return true
    }

    /// 오버드라이브 레이저: a beam of magenta light tears forward to the end of the line, flaring where it reaches.
    private static func overdriveLaser(_ c: CGContext, _ f: FXF) -> Bool {
        let p = laserPal, k = 1 - win(f.t, 0.55, 1)
        let ux = cos(f.dir), uy = sin(f.dir)
        let x0 = f.seq == 0 ? f.ox + ux * 8 : f.x - ux * 18, y0 = f.seq == 0 ? f.oy - 8 + uy * 8 : f.y - 8 - uy * 18
        fade(c, k) {
            beam(c, x0, y0, f.x, f.y - 8, 7 * (1 - f.t * 0.5), p)
            if f.seq == 0 { glow(c, f.ox + ux * 8, f.oy - 8, 10, p.lt) }
            star(c, f.x, f.y - 8, Int(5 * (1 - f.t)) + 1, p.ac, p.hi)
        }
        fling(c, f.x, f.y - 8, 3, 40, f.t, seed: f.seed, Tones(p.hi, p.ac), spread: .pi, gravity: 0)
        return true
    }

    /// 전차포: a heavy shell with a ring blasted out of the muzzle behind it.
    private static func tankShell(_ c: CGContext, _ s: ShotF) {
        let p = shellPal, d = flown(s), age = d / s.speed
        if age < 0.25 { let q = age / 0.25; fade(c, 1 - q) { shock(c, s.ox + s.ux * 9, s.oy - 7 + s.uy * 9, 4 + q * 14, 2, p, squash: 0.7); puff(c, s.ox + s.ux * 9, s.oy - 9 - q * 6, 3 + q * 5, smokePal.md, smokePal.dk) } }
        for k in 1...4 { fade(c, 0.5 - Double(k) * 0.1) { circle(c, s.x - s.ux * Double(k) * 7, s.y - s.uy * Double(k) * 7, 1.5 + Double(k) * 0.5, smokePal.lt) } }
        seg(c, s.x - s.ux * 6, s.y - s.uy * 6, s.x + s.ux * 2, s.y + s.uy * 2, p.dk, 4)
        seg(c, s.x - s.ux * 5, s.y - s.uy * 5, s.x + s.ux, s.y + s.uy, p.ac, 2)
        px(c, s.x + s.ux * 2, s.y + s.uy * 2, p.lt, 2)
    }

    /// 전투 로봇: a rocket-propelled mech fist flies at each foe and lands with sparks and arcs.
    private static func rocketFist(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .slash = f.kind else { return false }
        let p = robotPal, fly = easeIn(win(f.t, 0, 0.25))
        let a = atan2(f.y - f.oy, f.x - f.ox)
        let x = f.ox + (f.x - f.ox) * fly, y = f.oy - 8 + (f.y - f.oy + 2) * fly
        if f.t < 0.35 {
            flame(c, x - cos(a) * 6, y + 2, 4, 3, flamerPal, phase: f.age * 40)
            glyph(c, mechFist, p, x, y, dir: a)
        }
        if fly >= 1 {
            let u = win(f.t, 0.25, 1)
            fade(c, 1 - u) {
                star(c, f.x, f.y - 6, Int(5 * (1 - u)) + 1, p.lt, p.hi)
                for i in 0..<3 { let b = Double(i) * 2.1 + f.age * 12; zap(c, f.x, f.y - 6, f.x + cos(b) * 9, f.y - 6 + sin(b) * 6, elemPal(.thunder), seed: f.seed &+ UInt64(i), jag: 2, w: 1, branches: 0) }
            }
            fling(c, f.x, f.y - 6, 6, 60, u, seed: f.seed, Tones(p.hi, p.lt), spread: 1.3, gravity: 140)
        }
        return true
    }

    /// 레일건: an electric slug with a crackling beam left hanging between it and the barrel.
    private static func railSlug(_ c: CGContext, _ s: ShotF) {
        let p = railPal
        let sx = s.ox + s.ux * 8, sy = s.oy - 7 + s.uy * 8
        fade(c, 0.5) { seg(c, sx, sy, s.x, s.y, p.md, 2) }
        if Int(s.now * 30) % 3 != 2 { zap(c, sx, sy, s.x, s.y, p, seed: UInt64(truncatingIfNeeded: Int(s.now * 30)) &+ s.seed, jag: 2, w: 1, branches: 0) }
        glow(c, s.x, s.y, 8, p.lt, 0.9)
        seg(c, s.x - s.ux * 5, s.y - s.uy * 5, s.x + s.ux * 2, s.y + s.uy * 2, p.lt, 3)
        seg(c, s.x - s.ux * 4, s.y - s.uy * 4, s.x + s.ux * 2, s.y + s.uy * 2, p.hi)
        let ring = flown(s).truncatingRemainder(dividingBy: 14)
        oval(c, s.x - s.ux * ring, s.y - s.uy * ring, 1.5, 4, atan2(s.uy, s.ux), p.ac)
    }

    /// A red crosshair painted on the ground (cluster bombs, orbital strikes).
    private static func targetMark(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .telegraph(let r) = f.kind else { return true }
        let p = f.pal, s = r * 0.6 * (1.4 - 0.4 * f.t)
        fade(c, 0.4 + 0.5 * f.t) {
            circle(c, f.x, f.y, s, p.ac, squash: 0.5)
            seg(c, f.x - s - 3, f.y, f.x - s + 4, f.y, p.ac); seg(c, f.x + s - 4, f.y, f.x + s + 3, f.y, p.ac)
            seg(c, f.x, f.y - s * 0.5 - 2, f.x, f.y - s * 0.5 + 2, p.ac); seg(c, f.x, f.y + s * 0.5 - 2, f.x, f.y + s * 0.5 + 2, p.ac)
        }
        return true
    }

    /// 집속 폭탄: a canister drops, splits into bomblets and they pop all around the mark.
    private static func clusterBomb(_ c: CGContext, _ f: FXF) -> Bool {
        let p = clusterPal
        switch f.kind {
        case .telegraph: return true
        case .meteor(let r):
            if f.t < 0.12 {
                let u = easeIn(f.t / 0.12)
                box(c, f.x - 2, f.y - 70 * (1 - u) - 12, 4, 7, p.dk); px(c, f.x, f.y - 70 * (1 - u) - 12, p.ac)
                return true
            }
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 + 0.6, bx = f.x + cos(a) * r * 0.45, by = f.y + sin(a) * r * 0.22
                let land = 0.12 + Double(i) * 0.06, u = win(f.t, land, land + 0.35)
                if f.t < land {
                    let q = win(f.t, 0.12, land)
                    px(c, f.x + (bx - f.x) * q, f.y - 12 + (by - f.y + 12) * q - sin(q * .pi) * 6, p.dk, 2)
                } else if u < 1 {
                    fade(c, 1 - u) { glow(c, bx, by - 3, 7 * easeOut(u) + 2, p.lt); shock(c, bx, by, 9 * easeOut(u), 2, p, squash: 0.5) }
                }
            }
            return true
        default: return false
        }
    }

    /// 궤도 폭격: a thin targeting laser from the sky, then a thick column of light slams down.
    private static func orbitalStrike(_ c: CGContext, _ f: FXF) -> Bool {
        let p = orbitalPal
        switch f.kind {
        case .telegraph:
            fade(c, 0.3 + 0.5 * f.t) { seg(c, f.x, f.y - 140, f.x, f.y, p.ac) }
            return true
        case .meteor(let r):
            let o = punch(f.t, at: 0.08, hold: 0.25)
            fade(c, o) { pillar(c, f.x, f.y, 4 + 10 * o, 150, p, 1); glow(c, f.x, f.y - 4, r * 0.8, p.lt, 0.8, squash: 0.5) }
            let u = easeOut(f.t)
            fade(c, 1 - win(f.t, 0.5, 1)) { shock(c, f.x, f.y, r * u, 3, p, squash: 0.5) }
            fling(c, f.x, f.y, 8, 90, f.t, seed: f.seed, Tones(p.hi, p.lt, p.md), spread: 1.2, gravity: 160)
            return true
        default: return false
        }
    }

    /// 철벽 전차: armour plates bolt on round each ally from four sides, gears turning, exhaust puffing.
    private static func steelTank(_ c: CGContext, _ f: FXF) -> Bool {
        guard case .levelUp = f.kind else { return false }
        let p = tankPal, k = 1 - win(f.t, 0.75, 1)
        fade(c, k) {
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 + .pi / 4, land = 0.08 + Double(i) * 0.06
                let d = 12 + 20 * (1 - easeIn(win(f.t, 0, land + 0.12)))
                let bx = f.x + cos(a) * d, by = f.y - 10 + sin(a) * d * 0.7
                box(c, bx - 4, by - 3, 8, 6, p.dk); box(c, bx - 3, by - 2, 6, 4, p.md); px(c, bx - 2, by - 1, p.lt); px(c, bx + 2, by + 1, p.lt)
            }
            cog(c, f.x + 12, f.y - 24, 4, 6, f.age * 6, p.ac)
        }
        fade(c, 0.6 * k) { puff(c, f.x - 12, f.y - 18 - f.t * 10, 3 + f.t * 3, smokePal.md, smokePal.dk) }
        return true
    }

    /// 기계 군주의 심판: a giant cog turns round the mechanic and lightning arcs out to its rim.
    private static func teslaJudgement(_ c: CGContext, _ f: FXF) -> Bool {
        let p = teslaPal, k = 1 - win(f.t, 0.6, 1), r = f.r * (0.6 + 0.4 * easeOut(f.t))
        fade(c, k) {
            cog(c, f.x, f.y - 4, r, 16, f.now * 0.8, p.md, squash: 0.45)
            if Int(f.age * 30) % 3 != 2 {
                for i in 0..<6 {
                    let a = Double(i) * 1.05 + Double(f.seq) * 0.5
                    zap(c, f.x, f.y - 10, f.x + cos(a) * r, f.y - 4 + sin(a) * r * 0.45, p, seed: f.seed &+ UInt64(truncatingIfNeeded: i * 3 + Int(f.age * 30)), jag: 4, w: 2, branches: 1)
                }
            }
        }
        if f.t < 0.2 { glow(c, f.x, f.y - 10, 14, p.hi, 1 - f.t / 0.2) }
        return true
    }
}

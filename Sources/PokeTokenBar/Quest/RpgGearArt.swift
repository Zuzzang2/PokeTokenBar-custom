import AppKit
import CoreGraphics

// SPIKE: paper-doll gear for 픽셀 모험. A character's look is its class sprite with the equipped gear
// layered on: armor repaints the chest by tier, boots repaint the feet, a helmet replaces the top of the
// head (or decorates a wizard hat), a necklace adds a gem on the chest, and the weapon is drawn as its own
// small sprite in the front hand (swinging while attacking). Legendary / mythic gear adds a soft aura and
// a +10 weapon gets orbiting sparkles. Bodies are composed once per class + job + gear and cached.

/// What a character wears: enough to draw it, and small enough to send in every snapshot.
struct RpgLook: Hashable, Sendable {
    var cls: RpgClass
    var job = 0
    var weapon: String
    var plus = 0
    var armor: String? = nil
    var helmet: String? = nil
    var boots: String? = nil
    var ring: String? = nil
    var amulet: String? = nil
}

/// Spare rows above the 16×16 body for plumes, horns and crowns.
private let gearPad = 4

@MainActor
enum RpgGearArt {
    static let spriteSize = CGSize(width: 16, height: 16 + gearPad)

    // MARK: anchors

    /// Where things sit on each class sprite (16×16 grid coordinates).
    private struct Anchor {
        /// Row with the eyes; a helmet replaces everything above it.
        let face: Int
        /// Chest and arm rows that armor repaints.
        let torso: ClosedRange<Int>
        let backHand: (x: Int, y: Int)
        /// Front hand (the sprite faces right): the weapon's grip goes here.
        let hand: (x: Int, y: Int)
        /// Leg and foot rows for boots; empty for long robes (boots peek out under the hem).
        let feet: [Int]
        /// Row of the necklace gem.
        let gem: Int
        /// Wizard hats are decorated instead of replaced.
        let hat: Bool
    }

    private static func anchor(_ cls: RpgClass) -> Anchor {
        switch cls {
        case .warrior: return Anchor(face: 5, torso: 8...11, backHand: (3, 11), hand: (12, 11), feet: [13, 14], gem: 9, hat: false)
        case .archer: return Anchor(face: 5, torso: 8...11, backHand: (4, 10), hand: (11, 10), feet: [13, 14], gem: 9, hat: false)
        case .mage, .summoner: return Anchor(face: 6, torso: 9...11, backHand: (4, 11), hand: (11, 11), feet: [], gem: 10, hat: true)
        case .rogue, .cleric, .monk: return Anchor(face: 4, torso: 6...9, backHand: (4, 8), hand: (11, 8), feet: [13, 14], gem: 7, hat: false)
        }
    }

    private struct Canvas {
        var px: [[CGColor?]] = Array(repeating: Array(repeating: nil, count: 16), count: 16 + gearPad)
        subscript(x: Int, y: Int) -> CGColor? {
            get { (0..<16).contains(x) && (-gearPad..<16).contains(y) ? px[y + gearPad][x] : nil }
            set { if (0..<16).contains(x) && (-gearPad..<16).contains(y) { px[y + gearPad][x] = newValue } }
        }
    }

    private struct Tones { let main: CGColor, shade: CGColor, accent: CGColor, extra: CGColor }
    private static func tones(_ m: (Int, Int, Int), _ s: (Int, Int, Int), _ a: (Int, Int, Int), _ e: (Int, Int, Int)? = nil) -> Tones {
        let x = e ?? a
        return Tones(main: RpgArt.rgb(m.0, m.1, m.2), shade: RpgArt.rgb(s.0, s.1, s.2), accent: RpgArt.rgb(a.0, a.1, a.2), extra: RpgArt.rgb(x.0, x.1, x.2))
    }

    // MARK: armor

    /// armor0 천 옷 keeps the class's own clothes; then leather, chain, mithril, dragon scale, desert, glacier, demon plate.
    private static let armorTones: [Tones] = [
        tones((0, 0, 0), (0, 0, 0), (0, 0, 0)),
        tones((156, 100, 56), (108, 66, 36), (214, 170, 90)),
        tones((188, 196, 210), (118, 128, 146), (230, 236, 246)),
        tones((150, 214, 248), (84, 150, 214), (240, 252, 255)),
        tones((214, 62, 52), (140, 32, 34), (244, 192, 60)),
        tones((224, 194, 126), (168, 136, 80), (52, 150, 124)),
        tones((228, 244, 255), (130, 186, 236), (70, 140, 226)),
        tones((78, 36, 86), (46, 18, 52), (255, 56, 112)),
    ]

    private static func armor(_ cv: inout Canvas, _ t: Int, _ a: Anchor, _ ch: (Int, Int) -> Character) {
        guard t > 0 else { return }
        let p = armorTones[t]
        for y in a.torso {
            for x in 3...12 {
                let c = ch(x, y)
                guard c != "K", c != "." else { continue }
                if (x == a.hand.x && y == a.hand.y) || (x == a.backHand.x && y == a.backHand.y) { continue }
                let edge = ch(x - 1, y) == "K" || ch(x + 1, y) == "K"
                let top = y == a.torso.lowerBound
                let center = x == 7 || x == 8
                let color: CGColor
                switch t {
                case 1: // leather: brown with a dark strap across the chest and a buckle
                    color = x + y == 11 + a.torso.lowerBound ? p.shade : (edge ? p.shade : p.main)
                case 2: // chain mail: grey rings in stripes
                    color = (y + (edge ? 1 : 0)) % 2 == 0 ? p.main : p.shade
                case 3: // mithril: pale blue with a white sheen
                    color = (x + y) % 5 == 0 ? p.accent : (edge ? p.shade : p.main)
                case 4: // dragon scale: red checker with a gold collar
                    color = top && center ? p.accent : ((x + y) % 2 == 0 ? p.main : p.shade)
                case 5: // desert: sand with a teal sash
                    color = center ? p.accent : (edge ? p.shade : p.main)
                case 6: // glacier: ice white with blue frost
                    color = (x + y) % 3 == 0 ? p.shade : (top && edge ? p.accent : p.main)
                default: // demon plate: dark purple, red core and shoulder spikes
                    color = center && !top ? p.accent : (top && edge ? p.accent : ((x + y) % 3 == 0 ? p.shade : p.main))
                }
                cv[x, y] = color
            }
        }
    }

    // MARK: boots

    /// cloth, leather, chain, mithril, dragon, frost, demon, starlight.
    private static let bootTones: [Tones] = [
        tones((150, 124, 96), (110, 88, 66), (150, 124, 96)),
        tones((150, 96, 52), (100, 60, 34), (150, 96, 52)),
        tones((188, 196, 210), (118, 128, 146), (230, 236, 246)),
        tones((150, 214, 248), (84, 150, 214), (240, 252, 255)),
        tones((214, 62, 52), (140, 32, 34), (244, 192, 60)),
        tones((228, 244, 255), (130, 186, 236), (90, 170, 240)),
        tones((78, 36, 86), (46, 18, 52), (255, 56, 112)),
        tones((255, 216, 90), (214, 152, 40), (120, 220, 255)),
    ]

    private static func boots(_ cv: inout Canvas, _ t: Int, _ a: Anchor, _ ch: (Int, Int) -> Character) {
        let p = bootTones[t]
        guard let foot = a.feet.last else {
            // Under a robe only the toes show.
            for x in [5, 6, 9, 10] { cv[x, 15] = (x == 6 || x == 10) && t >= 4 ? p.accent : p.main }
            return
        }
        let rows = t >= 2 ? a.feet : [foot]
        for y in rows {
            for x in 3...12 {
                let c = ch(x, y)
                guard c != "K", c != "." else { continue }
                let toe = ch(x + 1, y) == "K"
                if y == foot { cv[x, y] = toe && t >= 4 ? p.accent : (t >= 2 ? p.shade : p.main) } else { cv[x, y] = p.main }
            }
        }
    }

    // MARK: helmets

    /// leather cap, iron, silver, mithril, dragon, frost, demon, starlight.
    private static let helmTones: [Tones] = [
        tones((170, 116, 64), (118, 76, 42), (214, 170, 100)),
        tones((178, 184, 198), (112, 118, 134), (236, 240, 248)),
        tones((228, 234, 244), (156, 164, 184), (220, 48, 48)),
        tones((150, 214, 248), (84, 150, 214), (255, 255, 255)),
        tones((214, 62, 52), (140, 32, 34), (255, 220, 100), (244, 192, 60)),
        tones((228, 244, 255), (130, 186, 236), (150, 230, 255)),
        tones((78, 36, 86), (46, 18, 52), (255, 56, 112), (232, 222, 200)),
        tones((255, 216, 90), (214, 152, 40), (110, 220, 255), (255, 80, 130)),
    ]

    /// Rows are face-6 … face (the last row overlays the face: cheek guards, glowing eyes); columns are 3 … 13.
    /// K outline, B metal, b shade, J accent (gem / plume / spikes), h horns, W shine; "." leaves it empty.
    private static let helmetGrids: [[String]] = [
        [ // 가죽 모자: leather cap with a brim
            "...........", "...........", "...KKKK....", "..KBBBBK...", ".KBBJBBBK..", ".KbbbbbbbbK", "...........",
        ],
        [ // 철 투구: round iron helm with cheek guards
            "...........", "...........", "...KKKK....", "..KBBWBK...", ".KBBBBBBK..", ".KbbbbbbK..", "..b....b...",
        ],
        [ // 은빛 투구: knight helm with a red crest
            "....JJ.....", "...JJ......", "...KJJK....", "..KBBWBK...", ".KBBBBBBK..", ".KbbbbbbK..", "..b....b...",
        ],
        [ // 미스릴 투구: same knight helm, mithril with a white crest
            "....JJ.....", "...JJ......", "...KJJK....", "..KBBWBK...", ".KBBBBBBK..", ".KbbbbbbK..", "..b....b...",
        ],
        [ // 용의 투구: red helm with curved golden horns
            "...........", "h........h.", "h..KKKK..h.", ".hKBBBBKh..", ".KBBBJBBK..", ".KbbbbbbK..", "..b....b...",
        ],
        [ // 서리 투구: ice spikes
            "....JJ.....", "..J.JJ.J...", "..KJBBJK...", ".KBBBWBBK..", ".KBBBBBBK..", ".KbbbbbbK..", "..b....b...",
        ],
        [ // 마왕의 투구: dark helm, big bone horns, glowing eyes
            "h........h.", "h........h.", ".h.KKKK.h..", "..hBBBBh...", ".KBBBBBBK..", ".KbbbbbbK..", "..bJ..Jb...",
        ],
        [ // 별빛 투구: golden crown with gems
            "...........", ".J..JJ..J..", ".B.KBBK.B..", ".BKBBBBKB..", ".KBhBBhBK..", ".KbbbbbbK..", "...........",
        ],
    ]

    private static func helmet(_ cv: inout Canvas, _ t: Int, _ a: Anchor, _ ch: (Int, Int) -> Character) {
        let p = helmTones[t]
        if a.hat { hatBand(&cv, t, a, p, ch); return }
        for y in -gearPad..<a.face { for x in 0..<16 { cv[x, y] = nil } }
        for (r, line) in helmetGrids[t].enumerated() {
            for (c, ch) in line.enumerated() {
                let color: CGColor
                switch ch {
                case "K": color = RpgArt.outline
                case "B": color = p.main
                case "b": color = p.shade
                case "J": color = p.accent
                case "h": color = p.extra
                case "W": color = RpgArt.rgb(255, 255, 255)
                default: continue
                }
                cv[3 + c, a.face - 6 + r] = color
            }
        }
    }

    /// Mages and summoners keep their hat: the helmet becomes a metal band with a gem, plus plume, horns, ice or crown points.
    private static func hatBand(_ cv: inout Canvas, _ t: Int, _ a: Anchor, _ p: Tones, _ ch: (Int, Int) -> Character) {
        let band = a.face - 2
        for x in 3...12 where ch(x, band) != "K" && ch(x, band) != "." { cv[x, band] = p.main }
        for x in 3...12 where ch(x, a.face - 1) != "K" && ch(x, a.face - 1) != "." { cv[x, a.face - 1] = p.shade }
        cv[7, band] = p.accent; cv[8, band] = p.accent
        let k = RpgArt.outline
        switch t {
        case 2, 3: // feather sweeping back
            for (x, y) in [(4, band - 2), (3, band - 3), (2, band - 3), (2, band - 4)] { cv[x, y] = p.accent }
        case 4, 6: // horns from the brim
            for (x, y) in [(3, band - 1), (2, band - 2), (2, band - 3), (12, band - 1), (13, band - 2), (13, band - 3)] { cv[x, y] = p.extra }
            cv[1, band - 3] = k; cv[14, band - 3] = k
        case 5: // ice crystals on the band
            for (x, y) in [(5, band - 1), (10, band - 1), (5, band - 2), (10, band - 2)] { cv[x, y] = p.accent }
        case 7: // crown points around the hat
            for (x, y) in [(5, band - 1), (5, band - 2), (8, band - 1), (10, band - 1), (10, band - 2)] { cv[x, y] = p.main }
            cv[5, band - 3] = p.accent; cv[10, band - 3] = p.accent; cv[8, band - 2] = p.extra
        default: break
        }
    }

    // MARK: composition

    private struct Composite { let body: CGImage; let glow: CGImage?; let glowColor: CGColor? }
    private static var cache: [RpgLook: Composite] = [:]
    private static var weaponCache: [String: CGImage] = [:]

    private static func tier(_ id: String?) -> Int? { id.flatMap(RpgItems.item).map { min(7, $0.tier) } }

    /// Highest rarity among everything worn: 3 전설 → gold aura, 4 신화 → pink aura.
    static func auraRarity(_ look: RpgLook) -> Int {
        ([look.weapon] + [look.armor, look.helmet, look.boots, look.ring, look.amulet].compactMap { $0 })
            .compactMap(RpgItems.item).map(\.rarity).max() ?? 0
    }

    private static func composite(_ look: RpgLook) -> Composite? {
        var key = look
        key.plus = 0
        if let c = cache[key] { return c }
        guard let spec = RpgArt.specs[look.cls.rawValue] else { return nil }
        let weapon = RpgItems.item(look.weapon)
        let tint = RpgArt.classTint(look.cls, weapon: weapon).merging(RpgJobs.tint(look.cls, look.job)) { w, _ in w }
        let colors = RpgArt.palette.merging(spec.swap) { _, n in n }.merging(tint) { _, n in n }
        let a = anchor(look.cls)
        let chars = spec.grid.map { Array($0) }
        let ch: (Int, Int) -> Character = { x, y in
            (0..<chars.count).contains(y) && (0..<chars[y].count).contains(x) ? chars[y][x] : "."
        }
        var cv = Canvas()
        for y in 0..<16 { for x in 0..<16 { cv[x, y] = colors[ch(x, y)] } }
        if let t = tier(look.armor) { armor(&cv, t, a, ch) }
        if let t = tier(look.boots) { boots(&cv, t, a, ch) }
        if let t = tier(look.helmet) { helmet(&cv, t, a, ch) }
        if let item = look.amulet.flatMap(RpgItems.item) {
            let c = RpgArt.itemColors(item)
            let gem = c["J"] ?? RpgArt.rgb(120, 200, 255)
            cv[7, a.gem] = gem
            cv[8, a.gem] = item.rarity >= 3 ? RpgArt.rgb(255, 255, 255) : gem
            if let metal = c["B"] { cv[6, a.gem - 1] = metal; cv[9, a.gem - 1] = metal }
        }
        let w = 16, h = 16 + gearPad
        guard let ctx = KartArt.context(width: w, height: h) else { return nil }
        for y in 0..<h { for x in 0..<w { if let c = cv.px[y][x] { KartArt.fill(ctx, c, CGFloat(x), CGFloat(y), 1, 1) } } }
        guard let body = ctx.makeImage() else { return nil }
        var glow: CGImage?
        var glowColor: CGColor?
        let rarity = auraRarity(look)
        if rarity >= 3, let g = KartArt.context(width: w, height: h) {
            let color = rarity >= 4 ? RpgArt.rgb(255, 96, 150) : RpgArt.rgb(255, 204, 80)
            for y in 0..<h {
                for x in 0..<w where cv.px[y][x] == nil {
                    let near = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                        let nx = x + dx, ny = y + dy
                        return (0..<w).contains(nx) && (0..<h).contains(ny) && cv.px[ny][nx] != nil
                    }
                    if near { KartArt.fill(g, color, CGFloat(x), CGFloat(y), 1, 1) }
                }
            }
            glow = g.makeImage()
            glowColor = color
        }
        let comp = Composite(body: body, glow: glow, glowColor: glowColor)
        cache[key] = comp
        return comp
    }

    // MARK: held weapons

    /// Small held-weapon sprites in the icon's letters (so they take the icon's tier colours); `grip` sits in the hand.
    private static func weaponArt(_ cls: RpgClass) -> (grid: RpgGrid, grip: (x: Int, y: Int)) {
        switch cls {
        case .warrior: return ([
            "..K..", ".KBK.", ".KBK.", ".KBK.", ".KBK.", ".KEK.", "KGGGK", ".KHK.", ".KJK.", "..K..",
        ], (2, 7))
        case .rogue: return ([
            "..K..", ".KBK.", ".KBK.", "KGGGK", ".KHK.", "..K..",
        ], (2, 4))
        case .cleric: return ([
            ".KKK.", "KBWBK", "KBBEK", ".KEK.", ".KHK.", ".KHK.", ".KHK.", "..K..",
        ], (2, 5))
        case .monk: return ([
            "KKK....", "KGGBBBK", "KGGKKK.", "KGGBBBK", "KKK....",
        ], (1, 2))
        case .archer: return ([
            "KK...", "KWBK.", ".W.BK", ".W.BK", ".W.GK", ".W.GK", ".W.GK", ".W.BK", ".W.BK", "KWBK.", "KK...",
        ], (1, 5))
        case .mage: return ([
            ".KKK.", "KOJOK", "KOOOK", ".KGK.", ".KBK.", ".KBK.", ".KBK.", ".KBK.", ".KBK.", ".KHK.", ".KHK.", "..K..",
        ], (2, 7))
        case .summoner: return ([
            "KK.KK", "KOKOK", "KGGGK", ".KGK.", ".KBK.", ".KBK.", ".KBK.", ".KHK.", ".KHK.", "..K..",
        ], (2, 6))
        }
    }

    private static func weaponImage(_ item: RpgItem, _ cls: RpgClass) -> CGImage? {
        if let img = weaponCache[item.id] { return img }
        let art = weaponArt(cls)
        let colors = RpgArt.palette.merging(RpgArt.itemColors(item)) { _, n in n }
        let w = art.grid.map(\.count).max() ?? 1
        guard let ctx = KartArt.context(width: w, height: art.grid.count) else { return nil }
        for (y, line) in art.grid.enumerated() {
            for (x, ch) in line.enumerated() {
                guard ch != ".", let c = colors[ch] else { continue }
                KartArt.fill(ctx, c, CGFloat(x), CGFloat(y), 1, 1)
            }
        }
        let img = ctx.makeImage()
        weaponCache[item.id] = img
        return img
    }

    // MARK: drawing

    /// Draws a character in its gear with its feet at `pos` (same footprint as the plain 16×16 sprite).
    /// `swing` runs 1 → 0 over a basic attack; `alpha` fades the whole character (dead / invulnerable blink).
    static func draw(_ look: RpgLook, in f: CGContext, at pos: CGPoint, facingRight: Bool, bob: CGFloat = 0, time t: Double,
                     swing: Double = 0, alpha: CGFloat = 1) {
        guard let comp = composite(look) else { return }
        let ox = (pos.x - 8).rounded(), oy = (pos.y - 15 - bob).rounded() - CGFloat(gearPad)
        let rect = CGRect(x: ox, y: oy, width: 16, height: 16 + CGFloat(gearPad))
        let a = anchor(look.cls)
        let weapon = RpgItems.item(look.weapon)
        let white = RpgArt.rgb(255, 255, 255)
        let sparkColor = (weapon?.element ?? .base) == .base ? RpgArt.rgb(255, 236, 140) : RpgArt.elem(weapon?.element ?? .base).mid
        let dir: CGFloat = facingRight ? 1 : -1

        // +10 and up: sparkles orbit the character (the far half behind it).
        func sparkles(front: Bool) {
            guard look.plus >= 10 else { return }
            let n = look.plus >= 13 ? 4 : 3
            f.setAlpha(alpha)
            for k in 0..<n {
                let ang = t * 2.4 + Double(k) * 2 * .pi / Double(n)
                guard (sin(ang) >= 0) == front else { continue }
                let x = Double(pos.x) + cos(ang) * 9, y = Double(pos.y - bob) - 7 + sin(ang) * 3.5
                if (Int(t * 8) + k) % 3 == 0 { RpgArt.star(f, x, y, 1, sparkColor, white) } else { RpgArt.dot(f, x, y, sparkColor) }
            }
        }

        sparkles(front: false)
        if let glow = comp.glow {
            f.setAlpha(alpha * CGFloat(0.24 + 0.12 * sin(t * 3)))
            KartArt.draw(glow, in: f, rect: rect, flipX: !facingRight)
        }
        f.setAlpha(alpha)
        KartArt.draw(comp.body, in: f, rect: rect, flipX: !facingRight)

        if let w = weapon, case .weapon(let wc) = w.kind, let img = weaponImage(w, wc) {
            let art = weaponArt(wc)
            let ww = CGFloat(img.width), wh = CGFloat(img.height)
            let gx = CGFloat(art.grip.x), gy = CGFloat(art.grip.y)
            let hx = CGFloat(a.hand.x), hy = CGFloat(a.hand.y + gearPad)
            let grip = CGPoint(x: facingRight ? ox + hx + 0.5 : ox + 16 - hx - 0.5, y: oy + hy + 0.5)
            let s = CGFloat(max(0, min(1, swing)))
            let arc = s > 0 ? sin((1 - s) * .pi) : 0
            var angle: CGFloat = 0, dx: CGFloat = 0, dy: CGFloat = 0
            switch wc {
            case .warrior, .rogue, .cleric: angle = dir * 1.3 * arc; dx = dir * arc
            case .monk: dx = dir * 3 * arc
            case .archer: dx = -dir * arc
            case .mage, .summoner: dx = dir * arc; dy = -2 * arc
            }
            f.saveGState()
            f.translateBy(x: grip.x + dx.rounded(), y: grip.y + dy.rounded())
            if angle != 0 { f.rotate(by: angle) }
            let r = CGRect(x: facingRight ? -gx - 0.5 : gx + 0.5 - ww, y: -gy - 0.5, width: ww, height: wh)
            KartArt.draw(img, in: f, rect: r, flipX: !facingRight)
            f.restoreGState()
        }

        // A ring glints on the back hand now and then.
        if let ring = look.ring.flatMap(RpgItems.item), (t * 0.7).truncatingRemainder(dividingBy: 1) < 0.1 {
            let bx = facingRight ? ox + CGFloat(a.backHand.x) : ox + 15 - CGFloat(a.backHand.x)
            let by = oy + CGFloat(a.backHand.y + gearPad)
            RpgArt.star(f, Double(bx), Double(by), 1, RpgArt.itemColors(ring)["J"] ?? white, white)
        }
        // Mythic gear: motes drift up through the aura.
        if let c = comp.glowColor, auraRarity(look) >= 4 {
            for k in 0..<2 {
                let rise = (t * 12 + Double(k) * 9).truncatingRemainder(dividingBy: 18)
                RpgArt.dot(f, Double(pos.x) + sin(t * 2 + Double(k) * 3) * 6, Double(pos.y - bob) - rise, c)
            }
        }
        // The old glint on a well-enhanced weapon, now at the held weapon's tip side.
        if look.plus >= 7, look.plus < 10, Int(t * 6) % 4 == 0 {
            KartArt.fill(f, white, pos.x + (facingRight ? 5 : -6), pos.y - 14, 1, 1)
        }
        sparkles(front: true)
        f.setAlpha(alpha)
    }
}

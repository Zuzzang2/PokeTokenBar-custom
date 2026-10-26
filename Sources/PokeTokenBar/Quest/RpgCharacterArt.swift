import AppKit
import CoreGraphics

// SPIKE: 픽셀 모험's heroes as a layered paper doll, drawn in code. A hero is a 32×32 frame whose feet sit on
// row 29 at column 16 (the old 16×16 sprites stood on their bottom row at the same spot, so positions and
// hitboxes are unchanged): ~23 px tall chibi with a 12 px head. Three views — side (drawn facing right and
// mirrored for left), front (facing down) and back (facing up). Parts are letter grids layered per view:
// back gear (cape, quiver, pack, wings), off arm, legs, torso, armour pieces, head, hair and class headgear.
// The weapon arm and the weapon are drawn per frame on top so the weapon can turn freely along a swing.
// Body frames are cached by (class, look, gear, job, view, pose); weapons by (item, angle step).
//
// Hero palette letters (see `heroPalette`):
//   K outline · S/s skin · H/h/I hair (main/shade/light) · o eye · w eye shine · x blush · X white
//   Q/q outfit accent (customizable) · U/u armour piece (tier colours) · J/j/! helmet metal/shade/gem · B/b boots
//   1/2 sleeves and 3 hands, 5/6 trousers — mapped per class to its own letters
//   class letters follow the old 16×16 sprites so `RpgJobs.tint` recolours them per advanced job:
//   warrior M/m plate, R/r tabard, Y trim · archer G/g · mage P/p, Y · rogue Z/z, R · cleric W, Y, C
//   monk F/f · summoner E/e, A, O · mechanic F/f, O, Z/z · plus per-class shades derived after the tint.

// MARK: - customization

/// Picked at creation, saved as `look: [hair, skin, accent]` (indices into these tables) and sent to other players.
enum RpgLook {
    typealias RGB = (r: Int, g: Int, b: Int)
    struct Swatch: Sendable {
        let name: String
        let main: RGB
        let shade: RGB
        let light: RGB
    }

    static let hair: [Swatch] = [
        Swatch(name: "흑발", main: (58, 52, 70), shade: (32, 28, 44), light: (110, 106, 136)),
        Swatch(name: "갈색", main: (124, 80, 48), shade: (84, 52, 32), light: (176, 124, 78)),
        Swatch(name: "적갈색", main: (156, 64, 44), shade: (104, 38, 30), light: (210, 110, 76)),
        Swatch(name: "금발", main: (244, 204, 98), shade: (198, 146, 56), light: (255, 242, 176)),
        Swatch(name: "주황", main: (232, 116, 46), shade: (168, 66, 30), light: (255, 178, 98)),
        Swatch(name: "은발", main: (214, 220, 236), shade: (148, 158, 186), light: (255, 255, 255)),
        Swatch(name: "파랑", main: (74, 124, 222), shade: (42, 72, 162), light: (138, 186, 255)),
        Swatch(name: "분홍", main: (242, 134, 182), shade: (190, 82, 132), light: (255, 200, 226)),
        Swatch(name: "초록", main: (82, 172, 112), shade: (44, 112, 72), light: (152, 228, 162)),
        Swatch(name: "보라", main: (152, 98, 216), shade: (98, 58, 160), light: (204, 164, 252)),
        Swatch(name: "빨강", main: (214, 52, 62), shade: (142, 26, 42), light: (255, 124, 124)),
    ]
    static let skin: [Swatch] = [
        Swatch(name: "밝은", main: (255, 226, 200), shade: (228, 178, 150), light: (255, 240, 226)),
        Swatch(name: "기본", main: (244, 196, 152), shade: (206, 146, 112), light: (255, 222, 188)),
        Swatch(name: "황갈", main: (222, 164, 116), shade: (176, 118, 80), light: (240, 192, 146)),
        Swatch(name: "갈색", main: (170, 112, 74), shade: (124, 76, 48), light: (198, 140, 100)),
        Swatch(name: "짙은", main: (116, 76, 52), shade: (82, 50, 34), light: (146, 102, 74)),
    ]
    static let accent: [Swatch] = [
        Swatch(name: "빨강", main: (216, 58, 58), shade: (146, 32, 40), light: (255, 132, 120)),
        Swatch(name: "파랑", main: (62, 112, 216), shade: (36, 66, 150), light: (130, 176, 255)),
        Swatch(name: "초록", main: (66, 170, 86), shade: (36, 110, 54), light: (140, 226, 140)),
        Swatch(name: "금색", main: (242, 194, 62), shade: (190, 132, 30), light: (255, 236, 150)),
        Swatch(name: "보라", main: (152, 82, 204), shade: (96, 46, 142), light: (206, 150, 250)),
        Swatch(name: "청록", main: (40, 182, 182), shade: (24, 116, 124), light: (130, 236, 226)),
        Swatch(name: "분홍", main: (242, 122, 172), shade: (182, 70, 122), light: (255, 190, 216)),
        Swatch(name: "흰색", main: (240, 240, 236), shade: (178, 184, 202), light: (255, 255, 255)),
        Swatch(name: "검정", main: (62, 60, 76), shade: (34, 32, 46), light: (110, 108, 130)),
        Swatch(name: "주황", main: (250, 142, 42), shade: (196, 90, 24), light: (255, 200, 120)),
    ]

    /// The look a class starts with (and that characters from before customization get).
    static func defaults(_ cls: RpgClass) -> [Int] {
        switch cls {
        case .warrior: return [1, 1, 0]
        case .archer: return [3, 1, 9]
        case .mage: return [5, 1, 3]
        case .rogue: return [0, 2, 0]
        case .cleric: return [3, 0, 1]
        case .monk: return [0, 2, 0]
        case .summoner: return [9, 1, 3]
        case .mechanic: return [4, 1, 1]
        }
    }

    /// A saved or received look made safe: three in-range indices, class defaults for anything missing.
    static func clean(_ look: [Int]?, cls: RpgClass) -> [Int] {
        let base = defaults(cls), counts = [hair.count, skin.count, accent.count]
        return (0..<3).map { k in
            guard let look, k < look.count else { return base[k] }
            return min(max(look[k], 0), counts[k] - 1)
        }
    }
}

// MARK: - pose

enum RpgHeroView: Int, CaseIterable, Sendable { case side, front, back }

/// What a hero's body is doing this frame, worked out only from fields every machine has for every player
/// (host and mirrors alike): facing, `moving`, `attackAt`, `castAt`, `hurtFlash`, `dead`, `dash`, plus the
/// drawn speed and distance walked that the view measures.
struct RpgHeroPose: Equatable, Sendable {
    enum Action: Int, CaseIterable, Sendable { case idle, attack, cast, hurt, dash, dead }
    var action: Action
    var view: RpgHeroView
    /// Facing left: the right-facing art is drawn mirrored.
    var flip: Bool
    /// Legs are walking (also while attacking or casting) and the walk cycle frame 0-3.
    var moving: Bool
    var step: Int
    /// Seconds into the attack / cast / hurt / death; the world clock while idle (breathing, blinking).
    var t: Double
    /// Attack direction in the drawn (unmirrored) space: radians, y down, 0 = forward.
    var aim: Double
}

extension RpgArt {
    static let heroSize = 32
    /// Where the feet stand in the 32×32 frame (the world position maps to this pixel corner).
    static let heroAnchor = (x: 16, y: 29)
    /// Pixels walked per walk-cycle frame, and how long the swing / cast poses last.
    static let heroStride = 7.0
    static let heroCastTime = 0.42

    /// Length of the attack pose: the class's attack interval, kept between a quick jab and a long recover.
    static func heroAttackTime(_ p: RpgPlayer, time: Double) -> Double { min(0.5, max(0.24, p.attackInterval(at: time))) }

    static func heroPose(_ p: RpgPlayer, time: Double, speed: Double = 0, walked: Double = 0) -> RpgHeroPose {
        let fx = Double(p.facing.dx), fy = Double(p.facing.dy)
        let view: RpgHeroView = abs(fy) > abs(fx) + 0.15 ? (fy > 0 ? .front : .back) : .side
        let flip = !p.facingRight
        let world = hypot(fx, fy) < 0.01 ? (p.facingRight ? 0 : Double.pi) : atan2(fy, fx)
        let aim = flip ? Double.pi - world : world
        let moving = !p.dead && (p.moving || speed > 24)
        var pose = RpgHeroPose(action: .idle, view: view, flip: flip, moving: moving, step: moving ? Int(walked / heroStride) % 4 : 0, t: time, aim: aim)
        let attackAge = time - p.attackAt, castAge = time - p.castAt
        if p.dead {
            pose.action = .dead
        } else if p.hurtFlash > 0.05 {
            pose.action = .hurt
            pose.t = max(0, 0.2 - p.hurtFlash)
        } else if p.dash != nil || speed > 210 {
            pose.action = .dash
        } else if castAge >= 0, castAge < heroCastTime, castAge <= max(attackAge, 0) || attackAge < 0 || attackAge >= heroAttackTime(p, time: time) {
            pose.action = .cast
            pose.t = castAge
        } else if attackAge >= 0, attackAge < heroAttackTime(p, time: time) {
            pose.action = .attack
            pose.t = attackAge
        }
        return pose
    }
}

// MARK: - parts

extension RpgArt {
    fileprivate enum HeroBack { case none, cape, quiver, pack, scarf, tails }
    fileprivate enum HeroGrip { case sword, dagger, mace, claw, bow, staff, rod, gun }

    /// A letter grid placed at (x, y) in the 32×32 frame.
    fileprivate struct HeroPart {
        let x: Int, y: Int
        let g: RpgGrid
    }

    fileprivate struct HeroClassArt {
        /// Class colours under the letters of the old sprite, so `RpgJobs.tint` can recolour them.
        let colors: [Character: CGColor]
        /// Shades recomputed after the job tint: (letter, from letter, brightness factor).
        var derived: [(Character, Character, CGFloat)] = []
        let sleeve: (Character, Character)
        let hand: Character
        let pants: (Character, Character)
        /// Default boots; nil = barefoot.
        let boots: (CGColor, CGColor)?
        /// What `J` / `j` / `!` in the head grid show without a helmet.
        var bare: (Character, Character, Character) = ("Q", "q", "Y")
        var robe = false
        let back: HeroBack
        let grip: HeroGrip
        /// Hair and class headgear per view (side, front, back); `J`/`j`/`!` turn to metal under a helmet.
        let head: [HeroPart]
        /// Replaces `head` while a helmet is worn (classes whose headgear cannot simply be plated).
        var helm: [HeroPart]? = nil
        let torso: [HeroPart]
    }

    fileprivate static func part(_ y: Int, _ rows: [String], x: Int = 8) -> HeroPart { HeroPart(x: x, y: y, g: rows) }

    // MARK: base head (face) — x 8, y 7; the head is 12 px wide (x 10-21)

    fileprivate static let headBase: [HeroPart] = [
        part(7, [
            ".....KKKKKK.....", "....KSSSSSSK....", "...KSSSSSSSSK...", "..KSSSSSSSSSSK..", "..KSSSSSSSSSSK..", "..KSSSSSSooSSK..",
            "..KSSSSSSwoSSK..", "..KSSSSSSooSSK..", "..KsSSSSSSSxSK..", "...KsSSSSSSSK...", "....KKsSSSSK....", "......KKKKK.....",
        ]),
        part(7, [
            ".....KKKKKK.....", "....KSSSSSSK....", "...KSSSSSSSSK...", "..KSSSSSSSSSSK..", "..KSSSSSSSSSSK..", "..KSSooSSooSSK..",
            "..KSSwoSSwoSSK..", "..KSSooSSooSSK..", "..KSxSSSSSSxSK..", "...KsSSSSSSsK...", "....KKsSSsKK....", "......KKKK......",
        ]),
        part(7, [
            ".....KKKKKK.....", "....KSSSSSSK....", "...KSSSSSSSSK...", "..KSSSSSSSSSSK..", "..KSSSSSSSSSSK..", "..KSSSSSSSSSSK..",
            "..KSSSSSSSSSSK..", "..KSSSSSSSSSSK..", "..KsSSSSSSSSsK..", "...KsSSSSSSsK...", "....KKsSSsKK....", "......KKKK......",
        ]),
    ]

    /// Eye pixels (canvas x, y of each eye's top-left; eyes are 2×3) per view.
    fileprivate static let eyeSpots: [[(Int, Int)]] = [[(17, 12)], [(13, 12), (17, 12)], []]

    // MARK: legs — x 8, y 22; per view: stand, walk 0-3, dash

    fileprivate static let legs: [[RpgGrid]] = [
        [ // side (facing right)
            ["....K6655555K...", "....K6655555K...", "....K6655555K...", ".....K66K555K...", ".....K66K55K....", ".....KbbKBBK....", ".....KbbbKBBBK..", ".....KKKKKKKKK.."],
            ["....K6655555K...", "....K6655555K...", "....K665K555K...", "...K66K.K555K...", "..K66K...K55K...", "..Kbb.K..KBBK...", "..KbbbK..KBBBK..", "..KKKKK..KKKKK.."],
            ["....K6655555K...", "....K6655555K...", "....K6655555K...", ".....K66K55K....", ".....K66KBBK....", ".....KbbKBBBK...", ".....KbbbKKKK...", ".....KKKKK......"],
            ["....K6655555K...", "....K6655555K...", "....K665K555K...", "...K55K.K666K...", "..K55K...K66K...", "..KBB.K..KbbK...", "..KBBBK..KbbbK..", "..KKKKK..KKKKK.."],
            ["....K6655555K...", "....K6655555K...", "....K6655555K...", ".....K55K66K....", ".....K55KbbK....", ".....KBBKbbbK...", ".....KBBBKKKK...", ".....KKKKK......"],
            ["....K6655555K...", "....K6655555K...", "...K665K.K555K..", "..K66K...K555K..", ".K66K.....K55K..", ".Kbb.K....KBBBK.", ".KbbbK....KBBBBK", ".KKKKK....KKKKKK"],
        ],
        [ // front
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....K56KK56K....", "....KBbKKBbK....", "...KBBbKKBBbK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....K56KKBbK....", "....KBbKKBBbK...", "...KBBbKKKKKK...", "...KKKKK........"],
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....K56KK56K....", "....KBbKKBbK....", "...KBBbKKBBbK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....KBbKK56K....", "...KBBbKKBbK....", "...KKKKKKBBbK...", "........KKKKK..."],
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....K56KK56K....", "....KBbKKBbK....", "...KBBbKKBBbK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K555556K....", "....K555556K....", "....K56KK56K....", "....K56KK56K....", "....KBbKKBbK....", "...KBBbKKBBbK...", "...KKKKKKKKKK..."],
        ],
        [ // back
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....K65KK65K....", "....KbBKKbBK....", "...KbBBKKbBBK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....K65KKbBK....", "....KbBKKbBBK...", "...KbBBKKKKKK...", "...KKKKK........"],
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....K65KK65K....", "....KbBKKbBK....", "...KbBBKKbBBK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....KbBKK65K....", "...KbBBKKbBK....", "...KKKKKKbBBK...", "........KKKKK..."],
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....K65KK65K....", "....KbBKKbBK....", "...KbBBKKbBBK...", "...KKKKKKKKKK..."],
            ["....K555555K....", "....K655555K....", "....K655555K....", "....K65KK65K....", "....K65KK65K....", "....KbBKKbBK....", "...KbBBKKbBBK...", "...KKKKKKKKKK..."],
        ],
    ]

    // MARK: armour pieces by tier band (1: tiers 2-5 shoulder pads, 2: 6-8 + chest plate, 3: 9+ big pauldrons) — x 8, y 17

    fileprivate static let armorParts: [[HeroPart]] = [
        [ // side
            part(18, ["......KKKK......", ".....KUUUuK.....", ".....KuuuuK.....", "......KKKK......"]),
            part(18, ["......KKKK......", ".....KUUUuK.....", ".....KuuuuK.....", "......KKKKUK....", ".........KUK....", "..........K....."]),
            part(17, [".....KKKKKK.....", "....KUUUUUuK....", "....KUuuuuuK....", ".....KuKKuK.....", "......K..KUK....", ".........KUuK...", "..........KK...."]),
        ],
        [ // front
            part(18, ["..KKKK....KKKK..", ".KUUUuK..KuUUUK.", ".KuuuK....KuuuK.", "..KKK......KKK.."]),
            part(18, ["..KKKK....KKKK..", ".KUUUuKKKKuUUUK.", ".KuuuKUUUUKuuuK.", "..KKKKUuuUKKKK..", "......KUUK......", ".......KK......."]),
            part(17, [".KKKK......KKKK.", "KUUUuK....KuUUUK", "KuUuuKKKKKKuuUuK", ".KuuKUUUUUUKuuK.", "..KKKUu!!uUKKK..", "......KUUK......", ".......KK......."]),
        ],
        [ // back
            part(18, ["..KKKK....KKKK..", ".KUUUuK..KuUUUK.", ".KuuuK....KuuuK.", "..KKK......KKK.."]),
            part(18, ["..KKKK....KKKK..", ".KUUUuK..KuUUUK.", ".KuuuK....KuuuK.", "..KKK......KKK.."]),
            part(17, [".KKKK......KKKK.", "KUUUuK....KuUUUK", "KuUuuK....KuuUuK", ".KuuK......KuuK.", "..KK........KK.."]),
        ],
    ]
}

// MARK: - classes

extension RpgArt {
    fileprivate static let leather = (rgb(150, 96, 52), rgb(104, 64, 36))
    fileprivate static let steelBoots = (rgb(120, 112, 120), rgb(78, 72, 84))

    fileprivate static let heroClasses: [RpgClass: HeroClassArt] = [
        .warrior: HeroClassArt(
            colors: ["M": rgb(186, 196, 210), "m": rgb(120, 132, 152), "R": rgb(206, 54, 54), "r": rgb(140, 30, 34), "Y": rgb(240, 190, 50),
                     "L": rgb(130, 84, 48), "l": rgb(92, 58, 34), "V": rgb(72, 76, 98), "v": rgb(50, 52, 70)],
            derived: [("N", "M", 1.3)],
            sleeve: ("M", "m"), hand: "L", pants: ("V", "v"), boots: steelBoots, back: .cape, grip: .sword,
            head: [
                part(4, ["....K..K........", "...KHKKHK.......", "..KHHHHHHKK.....", ".KHHHHHHHHHK....", ".KHHHIIHHHHHK...", ".KHHIHHHHHHHHK..",
                         ".KHHHHHHHHHHHHK.", ".KHHHHHHHHhSSK..", ".KHHHHHHK.......", ".KHHHHHK........", ".KhHHHK.........", "..KhhK..........", "...KK..........."]),
                part(4, ["......K...K.....", ".....KHK.KHKK...", "....KHHHKHHHHK..", "...KHHIIHHHHHHK.", "..KHHIHHHHHHHHK.", ".KHHIHHHHHHHHHK.",
                         ".KHHHHHHHHHHHHK.", ".KHhHHHhhHHHhHK.", ".KHK...hh...KHK.", ".KHK........KHK.", ".KhK........KhK.", "..K..........K.."]),
                part(4, [".....K...K......", "...KKHK.KHK.....", "..KHHHHKHHHK....", ".KHHHHHHIIHHK...", ".KHHHHHHHHIHHK..", ".KHHHHHHHHHIHHK.",
                         ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KhHHHHHHHHHHhK.", ".KhhHHHHHHHHhhK.", "..KhhhHhhHhhhK..", "...KKhKKKKhKK..."]),
            ],
            helm: [
                part(2, ["....KK..........", "...KQQK.........", "..KQqQQK........", "...KQqK.KK......", ".....KKJJJK.....", "...KKJJJXXJK....",
                         "..KJJJJXJJJJK...", ".KJJJJXJJJJJJK..", ".KJJJJJJJJJJJJK.", ".KjjjjjjjJ!JjjK.", ".KJJJJJJK...jK..", ".KJJJJJK........",
                         ".KjJJJK.........", "..KjjK..........", "...KK..........."]),
                part(2, [".......KK.......", "......KQQK......", ".....KQQqQK.....", "......KQqK......", ".....KJJJJK.....", "...KKJJXXJJKK...",
                         "..KJJJXJJJJJJK..", ".KJJJXJJJJJJJJK.", ".KJJJJJJJJJJJJK.", ".KjjjjJ!!JjjjjK.", ".KJjK..jj..KjJK.", ".KJK...jj...KJK.",
                         ".KjK........KjK.", "..K..........K.."]),
                part(2, [".......KK.......", "......KQQK......", ".....KQqQQK.....", "......KqQK......", ".....KJJJJK.....", "...KKJJJJJJKK...",
                         "..KJJJJJJJJXJK..", ".KJJJJJJJJJXJJK.", ".KJJJJJJJJJJJJK.", ".KjjjjjjjjjjjjK.", ".KJJJJJJJJJJJJK.", ".KjJJJJJJJJJJjK.",
                         ".KjjJJJJJJJJjjK.", "..KjjjjjjjjjjK..", "...KKKKKKKKKK..."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KMNNMRRK....", "....KMMMmRRK....", "....KLLLLYLK....", "....KmMMKRRK....", "....KmmmKrrK....", "....KKKKKKKK...."]),
                part(18, ["...KKKKKKKKKK...", "...KNMMRRMMNK...", "...KMMmRRmMMK...", "...KLLLYYLLLK...", "...KmMKRRKMmK...", "...KmmKrrKmmK...", "...KKKKKKKKKK..."]),
                part(18, ["...KKKKKKKKKK...", "...KMNMMMMNMK...", "...KMMMmmMMMK...", "...KLLLLLLLLK...", "...KmMMKKMMmK...", "...KmmmKKmmmK...", "...KKKKKKKKKK..."]),
            ]),
        .archer: HeroClassArt(
            colors: ["G": rgb(72, 164, 76), "g": rgb(40, 104, 48), "L": rgb(150, 96, 52), "l": rgb(104, 64, 36), "Y": rgb(240, 190, 50),
                     "T": rgb(176, 132, 84), "t": rgb(124, 88, 52)],
            derived: [("N", "G", 1.3)],
            sleeve: ("G", "g"), hand: "L", pants: ("T", "t"), boots: leather, bare: ("G", "g", "Y"), back: .quiver, grip: .bow,
            head: [
                part(4, ["....KKKK........", "...KGGGGKK......", "..KGGGGNNGK.....", ".KGGGGNGGGGK....", ".KGGGGGGGGGGK...", "KGGGGGGGGGGGGK..",
                         "KGGGGGGGGJJJJK..", "KGGGGGGGKHHIHK..", "KgGGGGGGK...hK..", "KgGGGGGK........", ".KgGGGK.........", ".KgGGK..........",
                         "..KgK...........", "...K............"]),
                part(4, ["......KKKK......", "....KKGGGGKK....", "...KGGGNNGGGK...", "..KGGGNGGGGGGK..", "..KGGNGGGGGGGK..", ".KGGGGGGGGGGGGK.",
                         ".KGGGJJJJJJGGGK.", ".KGGKHHIHHHKGGK.", ".KGKh......hKGK.", ".KGK........KGK.", ".KgK........KgK.", ".KgK........KgK.",
                         "..KgK......KgK..", "...KK......KK..."]),
                part(4, ["......KKKK......", "....KKGGGGKK....", "...KGGGGGGGGK...", "..KGGGGGGNGGGK..", "..KGGGGGNGGGGK..", ".KGGGGGGGGGGGGK.",
                         ".KGGGGGGGGGGGGK.", ".KGGGGGGGGGGGGK.", ".KGgGGGGGGGGgGK.", ".KGgGGGGGGGGgGK.", ".KggGGGGGGGGggK.", "..KggGGGGGGggK..",
                         "...KggGGGGggK...", "....KKggggKK....", "......KggK......", "......KggK......", ".......KK......."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KQQQQQQK....", "....KLGGGNGK....", "....KgLGGGGK....", "....KLLLLYLK....", "...KgGGGGGGGK...", "...KKKKKKKKKK..."]),
                part(18, ["...KKKKKKKKKK...", "...KQQQQQQQQK...", "...KGLGGGGNGK...", "...KGGLGGGGGK...", "...KLLLYLLLLK...", "..KgGGGGGGGGgK..", "..KKKKKKKKKKKK.."]),
                part(18, ["...KKKKKKKKKK...", "...KQQQQQQQQK...", "...KGGGGGGLGK...", "...KGGGGGLGGK...", "...KLLLLLLLLK...", "..KgGGGGGGGGgK..", "..KKKKKKKKKKKK.."]),
            ]),
        .mage: HeroClassArt(
            colors: ["P": rgb(126, 74, 188), "p": rgb(82, 42, 134), "Y": rgb(240, 190, 50), "T": rgb(70, 54, 90), "t": rgb(46, 36, 62)],
            derived: [("N", "P", 1.3)],
            sleeve: ("P", "p"), hand: "S", pants: ("T", "t"), boots: (rgb(90, 64, 110), rgb(60, 40, 76)), robe: true, back: .none, grip: .staff,
            head: [
                part(0, ["...KK...........", "...KPK..........", "....KPK.........", "....KPPK........", ".....KPPK.......", ".....KPPPK......",
                         "....KPPPYPK.....", "...KPPPPPNPK....", "...KJJJJJ!JJK...", "KKpPPPPPPPPPPpKK", "KppppppppppppppK", ".KHHHHHHHHIHSK..",
                         ".KHHHHHHK.......", ".KHHHHHHK.......", ".KHHHHHK........", ".KHhHHK.........", ".KhhHK..........", "..KhK...........", "...K............"]),
                part(0, ["..........KK....", ".........KPK....", "........KPPK....", ".......KPPK.....", "......KPPPK.....", ".....KPPPPPK....",
                         ".....KPYPPPK....", "....KPPPPPNPK...", "...KJJJ!JJJJJK..", ".KKpPPPPPPPPPpKK", "KppppppppppppppK", ".KKHHHIHHHHHHKK.",
                         "..KHh......hHK..", "..KH........HK..", ".KHH........HHK.", ".KHH........HHK.", ".KHhK......KhHK.", "..KhK......KhK..", "...K........K..."]),
                part(0, ["........KK......", ".......KPK......", ".......KPPK.....", "......KPPK......", "......KPPPK.....", ".....KPPPPPK....",
                         ".....KPPPPPK....", "....KPNPPPPPK...", "...KJJJJJJJJJK..", ".KKpPPPPPPPPPpKK", "KppppppppppppppK", ".KHHHHHHHHHHHHK.",
                         ".KHHHIHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHhHHHHHHHHhHK.", ".KHhHHHHHHHHhHK.", ".KhhHHHHHHHHhhK.", "..KhhHHHHHHhhK..",
                         "...KhhhhhhhhK...", "....KKKKKKKK...."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KPPPPYYK....", "....KPPPYPPK....", "....KPPPPPpK....", "....KQQQQQQK....", "...KpPPPPPPPK...",
                          "...KpPPPPPPPK...", "..KppPPPPPPPPK..", "..KYYYYYYYYYYK..", "..KKKKKKKKKKKK.."]),
                part(18, ["...KKKKKKKKKK...", "...KPYPPPPYPK...", "...KPPYPPYPPK...", "...KPNPYYPPpK...", "...KQQQQqQQQK...", "..KpPPPqQPPPpK..",
                          "..KpPPPPqPPPpK..", ".KppPPPPPPPPppK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
                part(18, ["...KKKKKKKKKK...", "...KPPPPPPPPK...", "...KPPPPPPPPK...", "...KpPPPPPPpK...", "...KQQQQQQQQK...", "..KpPPPQQPPPpK..",
                          "..KpPPQqqQPPpK..", ".KppPPPPPPPPppK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
            ]),
        .rogue: HeroClassArt(
            colors: ["Z": rgb(96, 100, 128), "z": rgb(62, 64, 88), "R": rgb(206, 54, 54), "L": rgb(110, 76, 50), "l": rgb(76, 52, 36)],
            derived: [("N", "Z", 1.3), ("n", "Z", 0.58)],
            sleeve: ("Z", "z"), hand: "n", pants: ("z", "n"), boots: (rgb(70, 60, 64), rgb(46, 40, 44)), bare: ("z", "n", "R"), back: .scarf, grip: .dagger,
            head: [
                part(5, [".....KKKK.......", "...KKZZZZKK.....", "..KZZZZNNZZK....", ".KZZZZZNZZZZK...", ".KZZZZZZZZZZZK..", "KZZZZZZZZZZZZZK.",
                         "KZZZZZZZZKHHHK..", "KZZZZZZZK...HK..", "KzZZZZZK........", "KzZZZZK.........", ".KzZZKjjjjjjjK..", "..KKKKjjjjjjK...", "......KKKKKK...."]),
                part(5, ["......KKKK......", "....KKZZZZKK....", "...KZZZNNZZZK...", "..KZZZNZZZZZZK..", ".KZZZZZZZZZZZZK.", ".KZZZZZZZZZZZZK.",
                         ".KZZKHHHIHHKZZK.", ".KZKH......HKZK.", ".KZK........KZK.", ".KzK........KzK.", ".KzKjjjjjjjjKzK.", "..KKjjjjjjjjKK..", "....KKKKKKKK...."]),
                part(5, ["......KKKK......", "....KKZZZZKK....", "...KZZZZZZZZK...", "..KZZZZZZNZZZK..", ".KZZZZZZNZZZZZK.", ".KZZZZZZZZZZZZK.",
                         ".KZZZZZZZZZZZZK.", ".KZZZZZZZZZZZZK.", ".KZzZZZZZZZZzZK.", ".KzzZZZZZZZZzzK.", "..KzzZZZZZZzzK..", "...KzzjjjjzzK...", ".....KjKKjK.....", "......K..K......"]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KZLZZZZK....", "....KZZLZZZK....", "....KZNZRZZK....", "....KLLLLLLK....", "....KzzXzzzK....", "....KKKKKKKK...."]),
                part(18, ["...KKKKKKKKKK...", "...KZLZZZZLZK...", "...KZZLZZLZZK...", "...KZNZRRZZzK...", "...KLLLLLLLLK...", "...KzZXZZXZzK...", "...KKKKKKKKKK..."]),
                part(18, ["...KKKKKKKKKK...", "...KZLZZZZLZK...", "...KZZLZZLZZK...", "...KZZZLLZZZK...", "...KLLLLLLLLK...", "...KzZZZZZZzK...", "...KKKKKKKKKK..."]),
            ]),
        .cleric: HeroClassArt(
            colors: ["W": rgb(250, 250, 246), "Y": rgb(240, 190, 50), "C": rgb(244, 226, 186)],
            derived: [("V", "W", 0.8), ("T", "Y", 0.72), ("c", "C", 0.8)],
            sleeve: ("W", "V"), hand: "S", pants: ("C", "c"), boots: (rgb(200, 170, 120), rgb(150, 120, 80)), robe: true, back: .none, grip: .mace,
            head: [
                part(2, ["...TYYYYT.......", "..Y......Y......", "...TYYYYT.......", "................", ".....KKKKK......", "...KKHHHHHKK....",
                         "..KHHHHHIIHHK...", ".KHHHHHIHHHHHK..", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHhSSK..", ".KHHHHHHK.......", ".KHHHHHHK.......",
                         ".KHHHHHK........", ".KHHHHHK........", ".KhHHHK.........", ".KhhHK..........", "..KKK..........."]),
                part(2, ["....TYYYYYYT....", "...Y........Y...", "....TYYYYYYT....", "................", "......KKKK......", "....KKHHHHKK....",
                         "...KHHHIIHHHK...", "..KHHHIHHHHHHK..", ".KHHHIHHHHHHHHK.", ".KHHHHhSShHHHHK.", ".KHHK......KHHK.", ".KHHK......KHHK.",
                         ".KHHK......KHHK.", ".KHHK......KHHK.", ".KhhK......KhhK.", ".KhhK......KhhK.", "..KK........KK.."]),
                part(2, ["....TYYYYYYT....", "...Y........Y...", "....TYYYYYYT....", "................", "......KKKK......", "....KKHHHHKK....",
                         "...KHHHHHHHHK...", "..KHHHHHHIHHHK..", ".KHHHHHHIHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.",
                         ".KHhHHHHHHHHhHK.", ".KHhHHHHHHHHhHK.", ".KhhHHHHHHHHhhK.", ".KhhhHHHHHHhhhK.", "..KKKKKKKKKKKK.."]),
            ],
            helm: [
                part(0, ["...TYYYYT.......", "..Y......Y......", "...TYYYYT.......", "......KK........", ".....KJJK.......", "....KJJJJK......",
                         "...KJJ!JJJK.....", "...KJ!!!JJK.....", "..KJJJ!JJJJK....", ".KjJJJJJJJJJK...", ".KjjjjjjjjjjjK..", ".KHHHHHHHHhSSK..",
                         ".KHHHHHHK.......", ".KHHHHHHK.......", ".KHHHHHK........", ".KHHHHHK........", ".KhHHHK.........", ".KhhHK..........", "..KKK..........."]),
                part(0, ["....TYYYYYYT....", "...Y........Y...", "....TYYYYYYT....", ".......KK.......", "......KJJK......", ".....KJJJJK.....",
                         "....KJJ!!JJK....", "...KJ!!!!!!JK...", "..KJJJJ!!JJJJK..", ".KjJJJJ!!JJJJjK.", ".KjjjjjjjjjjjjK.", ".KHHHHhSShHHHHK.",
                         ".KHHK......KHHK.", ".KHHK......KHHK.", ".KHHK......KHHK.", ".KHHK......KHHK.", ".KhhK......KhhK.", ".KhhK......KhhK.", "..KK........KK.."]),
                part(0, ["....TYYYYYYT....", "...Y........Y...", "....TYYYYYYT....", ".......KK.......", "......KJJK......", ".....KJJJJK.....",
                         "....KJJJJJJK....", "...KJJJJJJJJK...", "..KJJJJJJJJJJK..", ".KjJJJJJJJJJJjK.", ".KjjjjjjjjjjjjK.", ".KHHHHHHHHHHHHK.",
                         ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHhHHHHHHHHhHK.", ".KHhHHHHHHHHhHK.", ".KhhHHHHHHHHhhK.", ".KhhhHHHHHHhhhK.", "..KKKKKKKKKKKK.."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KWWWWQWK....", "....KWWWWQWK....", "....KWWWWQWK....", "....KVWWWQWK....", "...KVWWWWQWWK...",
                          "...KVWWWWQWWK...", "..KVVWWWWQWWWK..", "..KYYYYYYYYYYK..", "..KKKKKKKKKKKK.."]),
                part(18, ["...KKKKKKKKKK...", "...KWQWWWWQWK...", "...KWQWYYWQWK...", "...KWQYYYYQWK...", "...KVQWYYWQVK...", "..KVWQWWWWQWVK..",
                          "..KVWQWWWWQWVK..", ".KVVWQWWWWQWVVK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
                part(18, ["...KKKKKKKKKK...", "...KWQWWWWQWK...", "...KWQWWWWQWK...", "...KWWWWWWWWK...", "...KVWWWWWWVK...", "..KVWWWYYWWWVK..",
                          "..KVWWYYYYWWVK..", ".KVVWWWYYWWWVVK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
            ]),
        .monk: HeroClassArt(
            colors: ["F": rgb(255, 140, 40), "f": rgb(255, 220, 90)],
            derived: [("N", "F", 0.72)],
            sleeve: ("S", "s"), hand: "X", pants: ("F", "N"), boots: nil, back: .tails, grip: .claw,
            head: [
                part(3, ["....KKKK........", "...KHIHHK.......", "....KQQK........", "...KHHHHK.......", "..KHHHIIHHKK....", ".KHHHIHHHHHHK...",
                         ".KHHHHHHHHHHHK..", ".KQQQQQQQQQQQQK.", ".KqQQQQQQQQJJqK.", ".KHHHHHK........", ".KhHHHK.........", "..KhhK..........", "...KK..........."]),
                part(3, ["......KKKK......", ".....KHIHHK.....", "......KQQK......", ".....KHHHHK.....", "....KHHIIHHK....", "...KHHIHHHHHK...",
                         "..KHHIHHHHHHHK..", "..KQQQQQQQQQQK..", "..KqQQQJJQQQqK..", "..KH........HK..", "..KK........KK.."]),
                part(3, ["......KKKK......", ".....KHHIHK.....", "......KQQK......", ".....KHHHHK.....", "....KHHHHHHK....", "...KHHHHHHHHK...",
                         "..KHHHHHHHHHHK..", "..KQQQQQQQQQQK..", "..KqQQQQQQQQqK..", "..KHHHHHHHHHHK..", "..KhHHHHHHHHhK..", "...KhhhhhhhhK...", "....KKKKKKKK...."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KFFFFSSK....", "....KFfFFFSK....", "....KFFfFFFK....", "....KQQQQQQK....", "....KNFFFQqK....", "....KKKKKKKK...."]),
                part(18, ["...KKKKKKKKKK...", "...KFfSSSSfFK...", "...KFFfSSfFFK...", "...KNFFffFFNK...", "...KQQQQQQQQK...", "...KNFFqQFFNK...", "...KKKKKKKKKK..."]),
                part(18, ["...KKKKKKKKKK...", "...KFFFFFFFFK...", "...KFfFFFFfFK...", "...KFFFFFFFFK...", "...KQQQQQQQQK...", "...KNFFFFFFNK...", "...KKKKKKKKKK..."]),
            ]),
        .summoner: HeroClassArt(
            colors: ["E": rgb(70, 150, 170), "e": rgb(40, 100, 120), "A": rgb(116, 72, 156), "O": rgb(110, 226, 255), "Y": rgb(240, 190, 50)],
            derived: [("a", "A", 0.66), ("N", "A", 1.3)],
            sleeve: ("E", "e"), hand: "S", pants: ("e", "a"), boots: (rgb(70, 56, 90), rgb(46, 36, 60)), bare: ("A", "a", "O"), robe: true, back: .none, grip: .rod,
            head: [
                part(3, ["...KK...........", "...KAK..........", "...KaAKKKK......", "....KAAAAAKK....", "...KAAANNAAAK...", "..KAAAANAAAAAK..",
                         ".KAAAAJJJJJ!JK..", ".KAAAAAAAAAAAAK.", ".KAAAAAAAKHHIK..", ".KAAAAAAK...HK..", ".KaAAAAK........", "KaAAAAK.........",
                         "KaaAAK..........", ".KaaK...........", "..KK............"]),
                part(3, ["..KK........KK..", "..KAK......KAK..", "..KaAKKKKKKAaK..", "...KAAAAAAAAK...", "..KAANNAAAAAAK..", ".KAANAAAAAAAAAK.",
                         ".KAJJJJ!!JJJJAK.", ".KAAAAAAAAAAAAK.", ".KAAKHHIHHHKAAK.", ".KAKH......HKAK.", ".KAK........KAK.", ".KaK........KaK.",
                         ".KaK........KaK.", "..KK........KK.."]),
                part(3, ["..KK........KK..", "..KAK......KAK..", "..KaAKKKKKKAaK..", "...KAAAAAAAAK...", "..KAAAAAAAAAAK..", ".KAAAAAAAANAAAK.",
                         ".KAJJJJJJJJJJAK.", ".KAAAAAAAAAAAAK.", ".KAAAAAAAAAAAAK.", ".KAaAAAAAAAAaAK.", ".KAaAAAAAAAAaAK.", ".KaaAAAAAAAAaaK.",
                         "..KaaAAAAAAaaK..", "...KaaAAAAaaK...", "....KKaaaaKK....", "......KaaK......", ".......KK......."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KAAAAOAK....", "....KaAAAAAK....", "....KEKaaaaK....", "....KEEEEQQK....", "...KeEEEEEQQK...",
                          "...KeEEEEEQQK...", "..KeeEEEEEEQQK..", "..KYYYYYYYYYYK..", "..KKKKKKKKKKKK.."]),
                part(18, ["...KKKKKKKKKK...", "...KAAAOOAAAK...", "...KaAAAAAAaK...", "...KEKaaaaKEK...", "...KEEEQQEEeK...", "..KeEEEQQEEEeK..",
                          "..KeEEEQQEEEeK..", ".KeeEEEQQEEEeeK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
                part(18, ["...KKKKKKKKKK...", "...KAAAAAAAAK...", "...KAAAAAAAAK...", "...KaAAAAAAaK...", "...KEaaaaaaEK...", "..KeEEEEEEEEeK..",
                          "..KeEEEEEEEEeK..", ".KeeEEEEEEEEeeK.", ".KYYYYYYYYYYYYK.", ".KKKKKKKKKKKKKK."]),
            ]),
        .mechanic: HeroClassArt(
            colors: ["F": rgb(255, 140, 40), "f": rgb(255, 220, 90), "O": rgb(110, 226, 255), "Z": rgb(150, 150, 165), "z": rgb(100, 100, 116),
                     "L": rgb(110, 76, 50), "l": rgb(76, 52, 36)],
            derived: [("N", "F", 0.72)],
            sleeve: ("F", "N"), hand: "z", pants: ("F", "N"), boots: (rgb(84, 80, 92), rgb(56, 52, 64)), back: .pack, grip: .gun,
            head: [
                part(4, ["...K..K.........", "..KHKKHKK.......", "..KHHHHHHKK.....", ".KHHHHIIHHHK....", ".KHHHIHHHHHHK...", ".KZZZZZZZZZZZZK.",
                         ".KHHHHHHHZKOOKK.", ".KHHHHHHHZKOXK..", ".KHHHHHHK.......", ".KHHHHHK........", ".KhHHHK.........", "..KhhK..........", "...KK..........."]),
                part(4, ["....K..K..K.....", "...KHKKHKKHK....", "...KHHHHHHHHK...", "..KHHIHHHHHHHK..", ".KHHIHHHHHHHHHK.", ".KZZZZZZZZZZZZK.",
                         ".KZKOOKZZKOOKZK.", ".KHKOXKHHKOXKHK.", ".KHHK......KHHK.", ".KHK........KHK.", ".KhK........KhK.", "..K..........K.."]),
                part(4, [".....K..K..K....", "....KHKKHKKHK...", "...KHHHHHHHHK...", "..KHHHHHHHIHHK..", ".KHHHHHHHHHIHHK.", ".KZZZZZZZZZZZZK.",
                         ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KhHHHHHHHHHHhK.", ".KhhHHHHHHHHhhK.", "..KhhhHhhHhhhK..", "...KKhKKKKhKK..."]),
            ],
            helm: [
                part(4, [".....KKKK.......", "...KKJJJJKK.....", "..KJJJJXXJJK....", ".KJJJJXJJJJJK...", ".KJJJJJJJJJ!JK..", "KjjjjjjjjjjjjjjK",
                         ".KHHHHHHHZKOOKK.", ".KHHHHHHHZKOXK..", ".KHHHHHHK.......", ".KHHHHHK........", ".KhHHHK.........", "..KhhK..........", "...KK..........."]),
                part(4, ["......KKKK......", "....KKJJJJKK....", "...KJJXJJJJJK...", "..KJJXJJ!JJJJK..", ".KJJJJJJJJJJJJK.", "KjjjjjjjjjjjjjjK",
                         ".KZKOOKZZKOOKZK.", ".KHKOXKHHKOXKHK.", ".KHHK......KHHK.", ".KHK........KHK.", ".KhK........KhK.", "..K..........K.."]),
                part(4, ["......KKKK......", "....KKJJJJKK....", "...KJJJJJJJJK...", "..KJJJJJJJXJJK..", ".KJJJJJJJJXJJJK.", "KjjjjjjjjjjjjjjK",
                         ".KZZZZZZZZZZZZK.", ".KHHHHHHHHHHHHK.", ".KHHHHHHHHHHHHK.", ".KhHHHHHHHHHHhK.", ".KhhHHHHHHHHhhK.", "..KhhhHhhHhhhK..", "...KKhKKKKhKK..."]),
            ],
            torso: [
                part(18, ["....KKKKKKKK....", "....KZFFQQQK....", "....KZFfFFFK....", "....KZFfFFNK....", "....KLLZLLXK....", "....KNFFFFNK....", "....KKKKKKKK...."]),
                part(18, ["...KKKKKKKKKK...", "...KZQQQQQQZK...", "...KZFfFFFFZK...", "...KZFfFFFNZK...", "...KLLXLLLZLK...", "...KNFFFFFFNK...", "...KKKKKKKKKK..."]),
                part(18, ["...KKKKKKKKKK...", "...KFQQQQQQFK...", "...KFFFFFFFFK...", "...KFFFFFFFFK...", "...KLLLLLLLLK...", "...KNFFFFFFNK...", "...KKKKKKKKKK..."]),
            ]),
    ]
}

// MARK: - cloth and gear behind / over the body

extension RpgArt {
    /// Back gear per view (side, front, back) and cloth frame (0 still, then 1 and 2 alternating while moving): x 4 (24 wide).
    fileprivate static let backParts: [HeroBack: [[HeroPart]]] = [
        .cape: [
            [part(18, ["........KK..............", ".......KQqK.............", "......KQQqK.............", "......KQQqK.............", ".....KQQQqK.............",
                       ".....KQQQqK.............", "....KQQQqqK.............", "....KQqQqqK.............", "...KQqQQqqK.............", "...KKKKKKKK............."], x: 4),
             part(18, ["........KK..............", "......KKQK..............", "....KKQQqK..............", "..KKQQQQqK..............", ".KQQQQQqqK..............",
                       "KQQQqqqqK...............", ".KKQQqqK................", "...KKKK................."], x: 4),
             part(18, ["........KK..............", ".......KQK..............", ".....KKQqK..............", "...KKQQQqK..............", "..KQQQQqqK..............",
                       ".KQQqQqqqK..............", "..KKQqKKqK..............", "....KK..KK.............."], x: 4)],
            [part(19, [".....KKKKKKKKKKKKKK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQqK.....",
                       ".....KqQQQQQQQQQQqK.....", ".....KqQqQQQQQQqQqK.....", ".....KqqQqQQQQqQqqK.....", ".....KKKKKKKKKKKKKK....."], x: 4),
             part(19, [".....KKKKKKKKKKKKKK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQqK.....", "....KqQQQQQQQQQQQqK.....", "....KqQQQQQQQQQQQqK.....",
                       "...KqQQQQQQQQQQQQqK.....", "...KqQqQQQQQQQQqQqK.....", "...KqqQqQQQQQQqQqqK.....", "...KKKKKKKKKKKKKKKK....."], x: 4),
             part(19, [".....KKKKKKKKKKKKKK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQqK.....", ".....KqQQQQQQQQQQQqK....", ".....KqQQQQQQQQQQQqK....",
                       ".....KqQQQQQQQQQQQQqK...", ".....KqQqQQQQQQQQqQqK...", ".....KqqQqQQQQQQqQqqK...", ".....KKKKKKKKKKKKKKKK..."], x: 4)],
            [part(18, ["......KKKKKKKKKKKK......", "......KQQQQQQQQQQK......", "......KQQQQQQQQQQK......", "......KQqQQQQQQqQK......", ".....KQQqQQQQQQqQQK.....",
                       ".....KQQqQQQQQQqQQK.....", ".....KQqQQQqQQQQqQK.....", ".....KqQQqQQQqQQqqK.....", ".....KqQqQQqQQqQqQK.....", ".....KKKKKKKKKKKKKK....."], x: 4),
             part(18, ["......KKKKKKKKKKKK......", "......KQQQQQQQQQQK......", "......KQQQQQQQQQQK......", "......KQqQQQQQQqQK......", ".....KQQqQQQQQQqQQK.....",
                       "....KQQQqQQQQQQqQK......", "....KQqQQQqQQQQqQK......", "....KqQQqQQQqQQqK.......", "....KqQqQQqQQqQqK.......", "....KKKKKKKKKKKKK......."], x: 4),
             part(18, ["......KKKKKKKKKKKK......", "......KQQQQQQQQQQK......", "......KQQQQQQQQQQK......", "......KQqQQQQQQqQK......", ".....KQQqQQQQQQqQQK.....",
                       "......KQqQQQQQQqQQQK....", "......KQqQQQqQQQQqQK....", ".......KqQQqQQQqQQqK....", ".......KqQqQQqQQqQqK....", ".......KKKKKKKKKKKKK...."], x: 4)],
        ],
        .quiver: [
            [part(10, ["....XK..................", "...XXXK.................", "...KXXK.................", "....KLK.................", "....KLlK................",
                       ".....KLlK...............", ".....KLlK...............", "......KLlK..............", "......KYlK..............", ".......KLlK.............",
                       ".......KLlK.............", "........KLK.............", "........KK.............."], x: 4)],
            [part(13, ["...KXK..................", "..KXXK..................", "...KKK.................."], x: 4)],
            [part(12, ["...............KXK......", "..............KXXXK.....", "..............KLXXK.....", ".............KLLlK......", "............KLLlK.......",
                       "...........KLLlK........", "..........KYYlK.........", ".........KLLlK..........", "........KLLlK...........", ".......KLLlK............",
                       "......KLLlK.............", "......KKKK.............."], x: 4)],
        ],
        .pack: [
            [part(13, ["....K...................", "....O...................", "....K...................", ".KKKKKK.................", ".KZZZZK.................",
                       ".KZXZzK.................", ".KZZZzK.................", ".KZOZzK.................", ".KZZZzK.................", ".KzzzzK.................", ".KKKKKK................."], x: 4)],
            [part(12, ["..................K.....", "..................O.....", "..................K.....", "..................K....."], x: 4)],
            [part(13, [".................K......", ".................O......", ".................K......", ".......KKKKKKKKKKK......", ".......KZZZZZZZZZK......",
                       ".......KZXZZZZZXZK......", ".......KZZOOOOOZZK......", ".......KZZZZZZZZZK......", ".......KzzzzzzzzzK......", ".......KKKKKKKKKKK......"], x: 4)],
        ],
        .scarf: [
            [part(17, [".......KKK..............", "......KQQK..............", ".....KQqK...............", ".....KQqK...............", "......KqK...............", ".......K................"], x: 4),
             part(17, [".......KKK..............", "..KKKKKQQK..............", ".KQQQQQqK...............", "..KqqKKK................", "...KK..................."], x: 4),
             part(17, [".......KKK..............", "....KKKQQK..............", "..KKQQQqK...............", ".KQqqKKK................", "..KK...................."], x: 4)],
            [part(17, [".......KKKKKKKKKK.......", ".......KQQQQQQQQK.......", "........KKKKKQqK........", "............KQqK........", "............KqK.........", ".............K.........."], x: 4),
             part(17, [".......KKKKKKKKKK.......", ".......KQQQQQQQQK.......", "........KKKKKQqK........", ".............KQqK.......", ".............KqK........", "..............K........."], x: 4)],
            [part(17, [".......KKKKKKKKKK.......", ".......KQQQQQQQQK.......", "..........KQQK..........", "..........KQqK..........", "..........KqqK..........", "...........KK..........."], x: 4),
             part(17, [".......KKKKKKKKKK.......", ".......KQQQQQQQQK.......", "..........KQQK..........", ".........KQqK...........", "........KqqK............", "........KK.............."], x: 4)],
        ],
        .tails: [
            [part(10, [".....KK.................", "....KQqK................", "....KQqK................", "...KQqK.................", "...KqK..................", "....K..................."], x: 4),
             part(10, ["..KKKKK.................", "KKQQQqK.................", "KQqqKK..................", ".KK....................."], x: 4),
             part(10, ["...KKKK.................", ".KKQQqK.................", "KQQqKK..................", "KqKK....................", ".K......................"], x: 4)],
            [],
            [part(10, [".........KKKK...........", ".........KQQK...........", "........KQqqQK..........", "........KqKKqK..........", "........KqK.KqK.........", ".........K...K.........."], x: 4)],
        ],
    ]

    /// Layer of the back gear: 0 behind the body, 1 over the torso (under the head), 2 over the head.
    fileprivate static func backLayer(_ b: HeroBack, _ view: Int) -> Int {
        switch (b, view) {
        case (.scarf, 1): return 2
        case (.tails, 2): return 2
        case (_, 2): return 1
        default: return 0
        }
    }

    /// 4차 wings: per view, flap 0/1, x 2 (28 wide). `9`/`0`/`8` = wing main/shade/light.
    fileprivate static let wingParts: [[HeroPart]] = [
        [part(6, ["...KK.......................", "..K88K......................", ".K8999K.....................", "K89990K.....................", "K899900K....................", "K8999000K...................", ".K899000K...................", "..K89900K...................", "...K89000K..................", "....K8900K..................", ".....K900K..................", "......K00K..................", ".......KK..................."], x: 2),
         part(9, ["KK..........................", "K8KK........................", "K899KK......................", ".K89990K....................", "..K899900K..................", "...K89900K..................", "....KK900K..................", "......K00K..................", ".......KK..................."], x: 2)],
        [part(8, ["..KK....................KK..", ".K88K..................K88K.", "K8999K................K9998K", "K89990K..............K09998K", ".K89900K............K00998K.", "..K89900............00998K..", "...K8900............0098K...", "....K900............009K....", ".....KK0............0KK.....", ".......K............K......."], x: 2),
         part(11, ["KKK......................KKK", "K889KK................KK988K", ".K89990K............K09998K.", "..K89900............00998K..", "...KK900............009KK...", ".....KK0............0KK.....", ".......K............K......."], x: 2)],
        [part(8, ["..KK....................KK..", ".K88K..................K88K.", "K8999K................K9998K", "K89990K..............K09998K", ".K89900K............K00998K.", "..K899900K........K009998K..", "...K89900K........K00998K...", "....K8900K........K0098K....", ".....K900K........K009K.....", "......KK0K........K0KK......", "........K..........K........"], x: 2),
         part(11, ["KKK......................KKK", "K889KK................KK988K", ".K89990K............K09998K.", "..K899900K........K009998K..", "...KK9900K........K0099KK...", ".....KK90K........K09KK.....", ".......KKK........KKK......."], x: 2)],
    ]
}

// MARK: - frames

extension RpgArt {
    fileprivate struct HeroLookKey: Hashable {
        let cls: RpgClass
        let hair: Int, skin: Int, accent: Int
        let armor: String?, helmet: String?, boots: String?
        let job: Int, tier: Int
    }

    fileprivate struct HeroFrameKey: Hashable {
        let look: HeroLookKey
        let view: Int
        /// 0 stand, 1-4 walk cycle, 5 dash, 6 ghost tail.
        let legs: Int
        /// Upper body offset in pixels (-1 up … 1 down).
        let bob: Int
        /// Off arm: 0 rest, 1 forward, 2 back, 3 guard, 4 raised, 5 trailing, 6 flinch.
        let arm: Int
        /// 0 open, 1 blink, 2 hurt.
        let face: Int
        let flap: Int
        /// 0 normal, 1 white flash, 2 ghost.
        let tone: Int
    }

    fileprivate static var heroPalettes: [HeroLookKey: [Character: CGColor]] = [:]
    fileprivate static var heroFrames: [HeroFrameKey: CGImage] = [:]

    fileprivate static func col(_ t: RpgLook.RGB, _ a: CGFloat = 1) -> CGColor { rgb(t.r, t.g, t.b, a) }

    /// Darker below 1, toward white above 1.
    fileprivate static func scaled(_ c: CGColor, _ f: CGFloat) -> CGColor {
        guard let k = c.components, k.count >= 3 else { return c }
        let m: (CGFloat) -> CGFloat = { f <= 1 ? $0 * f : $0 + (1 - $0) * (f - 1) }
        return CGColor(srgbRed: m(k[0]), green: m(k[1]), blue: m(k[2]), alpha: k.count > 3 ? k[3] : 1)
    }

    fileprivate static func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
        guard let x = a.components, let y = b.components, x.count >= 3, y.count >= 3 else { return a }
        return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t, green: x[1] + (y[1] - x[1]) * t, blue: x[2] + (y[2] - x[2]) * t, alpha: 1)
    }

    /// Armour pieces by tier: none for cloth and leather, then shoulder pads, a chest plate and, from tier 9, big pauldrons.
    static func heroArmorBand(_ item: RpgItem?) -> Int {
        guard let item else { return 0 }
        let byTier = item.tier >= 9 ? 3 : item.tier >= 6 ? 2 : item.tier >= 2 ? 1 : 0
        return max(byTier, item.rarity >= 4 ? 3 : item.rarity >= 3 ? 2 : item.rarity >= 2 ? 1 : 0)
    }

    fileprivate static func heroPalette(_ k: HeroLookKey) -> [Character: CGColor] {
        if let p = heroPalettes[k] { return p }
        guard let art = heroClasses[k.cls] else { return [:] }
        var c = art.colors.merging(RpgJobs.tint(k.cls, k.job)) { _, new in new }
        for (letter, from, f) in art.derived { if let base = c[from] { c[letter] = scaled(base, f) } }
        let hair = RpgLook.hair[k.hair], skin = RpgLook.skin[k.skin], acc = RpgLook.accent[k.accent]
        c["K"] = outline
        c["X"] = rgb(255, 255, 255)
        c["o"] = rgb(36, 28, 52)
        c["w"] = rgb(255, 255, 255)
        c["H"] = col(hair.main); c["h"] = col(hair.shade); c["I"] = col(hair.light)
        c["S"] = col(skin.main); c["s"] = col(skin.shade)
        c["x"] = mix(col(skin.main), rgb(240, 96, 110), 0.35)
        c["Q"] = col(acc.main); c["q"] = col(acc.shade)
        if let a = k.armor.flatMap(RpgItems.item) {
            let ic = iconColors(a)
            c["U"] = ic["B"]; c["u"] = ic["E"]
            c["!"] = ic["E"]
        }
        if let h = k.helmet.flatMap(RpgItems.item) {
            let ic = iconColors(h)
            let metal = ic["B"] ?? rgb(200, 200, 210)
            c["J"] = metal; c["j"] = scaled(metal, 0.7); c["!"] = ic["J"] ?? metal
        } else {
            let bare = art.bare
            c["J"] = c[bare.0]; c["j"] = c[bare.1]; c["!"] = c[bare.2]
        }
        if let b = k.boots.flatMap(RpgItems.item) {
            let metal = iconColors(b)["B"] ?? art.boots?.0 ?? leather.0
            c["B"] = metal; c["b"] = scaled(metal, 0.68)
        } else if let boots = art.boots {
            c["B"] = boots.0; c["b"] = boots.1
        } else {
            c["B"] = c["S"]; c["b"] = c["s"]
        }
        c["1"] = c[art.sleeve.0]; c["2"] = c[art.sleeve.1]; c["3"] = c[art.hand]
        c["5"] = c[art.pants.0]; c["6"] = c[art.pants.1]
        if k.tier >= 3 {
            let wing = heroWingColors(k.cls, palette: c)
            c["9"] = wing.0; c["0"] = wing.1; c["8"] = wing.2
        }
        heroPalettes[k] = c
        return c
    }

    /// 4차 wings: feathers for the bright classes, leather for the dark ones, glowing plates for the rest.
    fileprivate static func heroWingColors(_ cls: RpgClass, palette c: [Character: CGColor]) -> (CGColor, CGColor, CGColor) {
        let glow = heroGlow(cls, palette: c)
        switch cls {
        case .archer, .cleric: return (rgb(250, 250, 255), mix(rgb(190, 200, 225), glow, 0.35), glow)
        case .rogue, .summoner: return (mix(rgb(70, 50, 90), glow, 0.25), rgb(40, 28, 54), glow)
        case .mechanic: return (rgb(170, 176, 196), rgb(110, 114, 134), glow)
        case .warrior, .mage, .monk: return (mix(glow, rgb(255, 255, 255), 0.35), glow, rgb(255, 255, 255))
        }
    }

    /// The class colour that reads as "its" glow (job-tinted): auras, wings, the familiar.
    fileprivate static func heroGlow(_ cls: RpgClass, palette c: [Character: CGColor]) -> CGColor {
        let letter: Character = switch cls {
        case .warrior: "R"
        case .archer: "G"
        case .mage: "P"
        case .rogue: "R"
        case .cleric: "Y"
        case .monk: "F"
        case .summoner: "O"
        case .mechanic: "O"
        }
        return scaled(c[letter] ?? rgb(255, 240, 170), 1.25)
    }

    fileprivate static func paint(_ g: RpgGrid, _ ox: Int, _ oy: Int, _ px: inout [Character]) {
        let n = heroSize
        for (row, line) in g.enumerated() {
            let y = oy + row
            guard y >= 0, y < n else { continue }
            var x = ox
            for ch in line {
                if ch != ".", x >= 0, x < n { px[y * n + x] = ch }
                x += 1
            }
        }
    }

    /// Bresenham points between two 2×2 arm blocks.
    fileprivate static func armLine(_ a: (Int, Int), _ b: (Int, Int)) -> [(Int, Int)] {
        var pts: [(Int, Int)] = []
        var x = a.0, y = a.1
        let dx = abs(b.0 - a.0), dy = -abs(b.1 - a.1), sx = a.0 < b.0 ? 1 : -1, sy = a.1 < b.1 ? 1 : -1
        var err = dx + dy
        while true {
            pts.append((x, y))
            if x == b.0 && y == b.1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
        }
        return pts
    }

    /// An outlined arm: sleeve blocks from the shoulder, a 2×2 hand at the end. `emit(x, y, w, h, letter)`.
    fileprivate static func arm(from s: (Int, Int), to h: (Int, Int), sleeve: Character, hand: Character, _ emit: (Int, Int, Int, Int, Character) -> Void) {
        let pts = armLine(s, h)
        for p in pts { emit(p.0 - 1, p.1 - 1, 4, 4, "K") }
        for (i, p) in pts.enumerated() { emit(p.0, p.1, 2, 2, i == pts.count - 1 ? hand : sleeve) }
    }

    fileprivate static func heroLookKey(_ p: RpgPlayer) -> HeroLookKey {
        let k = p.look
        let d = RpgLook.defaults(p.cls)
        func at(_ i: Int, _ n: Int) -> Int { i < k.count ? min(max(k[i], 0), n - 1) : d[i] }
        return HeroLookKey(cls: p.cls, hair: at(0, RpgLook.hair.count), skin: at(1, RpgLook.skin.count), accent: at(2, RpgLook.accent.count),
                           armor: p.armor, helmet: p.helmet, boots: p.boots, job: p.job, tier: p.job == 0 ? 0 : p.tier)
    }

    /// Shoulder (top-left of the 2×2 arm block) of the weapon arm and the off arm, per view.
    fileprivate static let weaponShoulder = [(15, 19), (21, 19), (9, 19)]
    fileprivate static let offShoulder = [(14, 19), (9, 19), (21, 19)]

    /// Off-arm hand offsets from its shoulder per view and arm pose (rest, forward, back, guard, raised, trailing, flinch).
    fileprivate static let offHands: [[(Int, Int)]] = [
        [(0, 3), (3, 2), (-3, 2), (3, 0), (1, -5), (-4, 1), (2, -1)],
        [(0, 3), (0, 2), (0, 3), (2, 0), (-1, -5), (-1, 3), (2, -1)],
        [(0, 3), (0, 3), (0, 2), (-2, 0), (1, -5), (1, 3), (-2, -1)],
    ]

    fileprivate static func heroBody(_ k: HeroFrameKey) -> CGImage? {
        if let img = heroFrames[k] { return img }
        guard let art = heroClasses[k.look.cls] else { return nil }
        let pal = heroPalette(k.look)
        let n = heroSize
        var px = [Character](repeating: ".", count: n * n)
        let v = k.view, up = k.bob
        let helmeted = k.look.helmet != nil
        let band = heroArmorBand(k.look.armor.flatMap(RpgItems.item))
        let back = backParts[art.back]
        let backPart = back.flatMap { views in views[v].isEmpty ? nil : views[v][min(k.flap & 3, views[v].count - 1)] }
        let layer = backLayer(art.back, v)
        func put(_ part: HeroPart, _ dy: Int = 0) { paint(part.g, part.x, part.y + dy, &px) }
        func offArm() {
            let s = offShoulder[v], o = offHands[v][k.arm]
            arm(from: (s.0, s.1 + up), to: (s.0 + o.0, s.1 + o.1 + up), sleeve: v == 0 ? "2" : "1", hand: "3") { x, y, w, h, ch in
                for yy in y..<(y + h) where yy >= 0 && yy < n { for xx in x..<(x + w) where xx >= 0 && xx < n { px[yy * n + xx] = ch } }
            }
        }
        let wings = k.look.tier >= 3 && k.tone != 2 ? wingParts[v][(k.flap >> 2) & 1] : nil
        if v != 2, let w = wings { put(w, up) }
        if layer == 0, let b = backPart { put(b, up) }
        if v == 0 { offArm() }
        if k.legs == 6 {
            paint(["....K555555K....", ".....K5555K.....", "......K55K......", ".......KK......."], 8, 22 + up, &px)
        } else {
            paint(legs[v][k.legs], 8, 22, &px)
        }
        put(art.torso[v], up)
        if band > 0 { put(armorParts[v][band - 1], up) }
        if layer == 1, let b = backPart { put(b, up) }
        if v == 2, let w = wings { put(w, up) }
        if v != 0 { offArm() }
        put(headBase[v], up)
        if k.face != 0 {
            for (i, e) in eyeSpots[v].enumerated() {
                for dy in 0..<3 { for dx in 0..<2 { px[(e.1 + dy + up) * n + e.0 + dx] = "S" } }
                if k.face == 1 {
                    px[(e.1 + 1 + up) * n + e.0] = "o"; px[(e.1 + 1 + up) * n + e.0 + 1] = "o"
                } else {
                    // Squeezed shut: > <
                    let near = (v == 1 && i == 1) ? 1 : 0
                    px[(e.1 + up) * n + e.0 + near] = "o"; px[(e.1 + 1 + up) * n + e.0 + 1 - near] = "o"; px[(e.1 + 2 + up) * n + e.0 + near] = "o"
                }
            }
            if k.face == 2 {
                if v == 1 { px[(16 + up) * n + 15] = "o"; px[(16 + up) * n + 16] = "o" } else if v == 0 { px[(16 + up) * n + 19] = "o" }
            }
        }
        put(helmeted ? (art.helm?[v] ?? art.head[v]) : art.head[v], up)
        if layer == 2, let b = backPart { put(b, up) }
        let img = heroImage(px, pal, tone: k.tone)
        heroFrames[k] = img
        return img
    }

    fileprivate static func heroImage(_ px: [Character], _ pal: [Character: CGColor], tone: Int) -> CGImage? {
        let n = heroSize
        guard let ctx = KartArt.context(width: n, height: n) else { return nil }
        let ghostLine = rgb(120, 150, 210, 0.85), white = rgb(255, 255, 255)
        for y in 0..<n {
            for x in 0..<n {
                let ch = px[y * n + x]
                guard ch != ".", let c = pal[ch], c.alpha > 0 else { continue }
                let out: CGColor
                switch tone {
                case 1: out = white
                case 2:
                    if ch == "K" { out = ghostLine } else {
                        let k = c.components ?? [1, 1, 1]
                        let l = 0.3 * k[0] + 0.59 * k[1] + 0.11 * k[2]
                        out = CGColor(srgbRed: 0.62 + l * 0.34, green: 0.74 + l * 0.24, blue: 0.94, alpha: 0.85)
                    }
                default: out = c
                }
                KartArt.fill(ctx, out, CGFloat(x), CGFloat(y), 1, 1)
            }
        }
        return ctx.makeImage()
    }
}

// MARK: - weapons in hand

extension RpgArt {
    /// Held weapons point right (+x) with the grip at `pivot`; letters as in the icons (B/E blade, G guard, H handle, J/O gem/orb).
    fileprivate struct HeldWeapon {
        let grid: RpgGrid
        let pivot: (Int, Int)
    }

    fileprivate static let heldWeapons: [HeroGrip: (HeldWeapon, HeldWeapon)] = [
        .sword: (HeldWeapon(grid: ["....KK..........", "....KGKKKKKKKKK.", "KKKKKGBBBBBBBBBK", "KJHHHGEEEEEEEEK.", "KKKKKGKKKKKKKK..", "....KK.........."], pivot: (2, 3)),
                 HeldWeapon(grid: ["....KKK............", "...KGGGKKKKKKKKKK..", "KKKKGJGBBBBBBBBBBK.", "KJHHGJGXBBBBBBBBBBK", "KKKKGJGEEEEEEEEEEK.",
                                   "...KGGGKKKKKKKKKK..", "....KKK............"], pivot: (2, 3))),
        .dagger: (HeldWeapon(grid: ["...K.......", "KKKGKKKKK..", "KHHGBBBBXK.", "KKKGEEEKK..", "...K......."], pivot: (1, 2)),
                  HeldWeapon(grid: ["...KK.........", "KKKGGKKKKKK...", "KHHGJBBBBBBXK.", "KKKGGEEEEEKK..", "...KK........."], pivot: (1, 2))),
        .mace: (HeldWeapon(grid: ["..........KKK.", ".........KBWBK", "KKKKKKKKKBBBEK", "KHHHHHHHGBBEEK", "KKKKKKKKKBEEK.", ".........KKK.."], pivot: (2, 3)),
                HeldWeapon(grid: ["..........K.K.K.", ".........KBKBKBK", "........KBWBBBEK", "KKKKKKKKGBBJBBEK", "KHHHHHHHGBBBBEEK", "KKKKKKKKGBBBBEK.",
                                  "........KBKBKBK.", ".........K.K.K.."], pivot: (2, 4))),
        .claw: (HeldWeapon(grid: ["..KKKK...", ".KGBBWK..", ".KGKKKK..", ".KGBBBWK.", ".KGKKKK..", ".KGBBWK..", "..KKKK..."], pivot: (1, 3)),
                HeldWeapon(grid: ["..KKKKK...", ".KGBBBWK..", ".KOKKKKK..", ".KGBBBBBWK", ".KOKKKKK..", ".KGBBBWK..", "..KKKKK..."], pivot: (1, 3))),
        .staff: (HeldWeapon(grid: ["...........KKK..", "..........KOOOK.", "KKKKKKKKKKGOJOOK", "KHHBBBBBBBGOOOOK", "KKKKKKKKKKGOOOK.", "...........KKK.."], pivot: (5, 3)),
                 HeldWeapon(grid: ["............KKK...", "...........KOOOK..", "..........KOWJOOK.", "KKKKKKKKKKGOJJOOOK", "KHHBBBBBBBGOOOOOOK", "KKKKKKKKKKGOOOOOK.",
                                   "...........KOOOK..", "............KKK..."], pivot: (5, 4))),
        .rod: (HeldWeapon(grid: ["..........K...", ".........K@K..", "KKKKKKKKK@%@K.", "KHHBBBBBG%%%@K", "KKKKKKKKK@%@K.", ".........K@K..", "..........K..."], pivot: (2, 3)),
               HeldWeapon(grid: ["...........K....", "..........K@K...", ".........K@%@K..", "KKKKKKKKK@%%%@K.", "KHHBBBBBG%%%%%@K", "KKKKKKKKK@%%%@K.",
                                 ".........K@%@K..", "..........K@K...", "...........K...."], pivot: (2, 4))),
        .gun: (HeldWeapon(grid: ["..KKKKKKKKKK.", ".KBWBBBBBBBEK", ".KBBBBBBBBBEK", ".KKGGKKKKKKK.", "..KHHK.......", "..KHHK.......", "..KKKK......."], pivot: (3, 4)),
               HeldWeapon(grid: ["..KKKKKKKKKKKKK.", ".KBWBBBBBBBBBBEK", ".KBBBBGGBBBBBBEK", ".KBBBBBBBBBBBBEK", ".KKGGKKKKKKKKKK.", "..KHHK..........", "..KHHK..........", "..KKKK.........."], pivot: (3, 5))),
    ]

    /// The bow: limbs as `)` with the string pulled `draw` pixels back and an arrow nocked while drawn.
    fileprivate static func bowGrid(big: Bool, draw: Int) -> HeldWeapon {
        let limbs = big
            ? ["KK.......", "KBK......", ".KBK.....", "..KBbK...", "...KBbK..", "...KBbK..", "....KBbK.", "....KBbK.", "....KGGK.", "....KGGK.", "....KGGK.",
               "....KBbK.", "....KBbK.", "...KBbK..", "...KBbK..", "..KBbK...", ".KBK.....", "KBK......", "KK......."]
            : [".KKK....", ".KBBK...", "..KBbK..", "...KBbK.", "...KBbK.", "....KBbK", "....KBbK", "....KGGK", "....KGGK", "....KGGK",
               "....KBbK", "....KBbK", "...KBbK.", "...KBbK.", "..KBbK..", ".KBBK...", ".KKK...."]
        let mid = big ? 9 : 8, top = big ? 2 : 1, bottom = big ? 16 : 15
        let w = 19, off = 4
        var rows = limbs.map { Array(String(repeating: ".", count: off) + $0 + String(repeating: ".", count: w - off - $0.count)) }
        let nock = (off + 2 - draw, mid)
        for (a, b) in [((off + 2, top), nock), (nock, (off + 2, bottom))] {
            for p in armLine(a, b) where rows[p.1][p.0] == "." || p == nock { rows[p.1][p.0] = "W" }
        }
        if draw > 0 {
            // A nocked arrow: shaft through the bow, steel head in front, white fletching at the string.
            let tip = min(w - 1, nock.0 + 13)
            for x in (nock.0 + 1)..<tip where rows[mid][x] == "." || rows[mid][x] == "W" { rows[mid][x] = "L" }
            rows[mid][tip] = "A"; rows[mid - 1][tip - 1] = "A"; rows[mid + 1][tip - 1] = "A"
            rows[mid - 1][nock.0] = "X"; rows[mid + 1][nock.0] = "X"
        }
        return HeldWeapon(grid: rows.map { String($0) }, pivot: (off + 5, mid))
    }

    fileprivate static func heroGrip(_ cls: RpgClass) -> HeroGrip { heroClasses[cls]?.grip ?? .sword }

    /// Late weapons (tier 9+, or region gear of that power) are drawn bigger with an aura.
    static func heroBigWeapon(_ item: RpgItem) -> Bool { item.tier >= 9 || item.attack >= 170 }

    fileprivate struct WeaponKey: Hashable {
        let id: String
        let draw: Int
        let step: Int
    }

    static let heroWeaponSteps = 32
    fileprivate static var weaponCache: [WeaponKey: (CGImage, Int)] = [:]

    /// The weapon turned to `angle` (radians, y down), its grip at pixel (r, r) of the returned image.
    fileprivate static func heroWeapon(_ item: RpgItem, grip: HeroGrip, angle: Double, draw: Int = 0) -> (image: CGImage, r: Int)? {
        let steps = heroWeaponSteps
        let step = ((Int((angle / (2 * .pi) * Double(steps)).rounded()) % steps) + steps) % steps
        let key = WeaponKey(id: item.id, draw: draw, step: step)
        if let hit = weaponCache[key] { return (hit.0, hit.1) }
        let big = heroBigWeapon(item)
        let held: HeldWeapon
        if grip == .bow { held = bowGrid(big: big, draw: draw) } else if let pair = heldWeapons[grip] { held = big ? pair.1 : pair.0 } else { return nil }
        var colors = iconColors(item)
        colors["L"] = rgb(150, 100, 56); colors["A"] = rgb(220, 226, 236); colors["X"] = rgb(255, 255, 255)
        if let limb = colors["B"] { colors["b"] = scaled(limb, 0.72) }
        // The summoner's crystal glows in the weapon's element (spirit violet when plain).
        let spirit = elem(item.element == .base ? .cosmic : item.element)
        colors["@"] = spirit.mid; colors["%"] = spirit.core
        // Index the template (padded by a transparent pixel so Scale2x sees the edges).
        var table: [CGColor] = [rgb(0, 0, 0, 0)]
        var index: [Character: Int] = [:]
        let w = (held.grid.map(\.count).max() ?? 0) + 2, h = held.grid.count + 2
        var src = [Int](repeating: 0, count: w * h)
        for (y, line) in held.grid.enumerated() {
            for (x, ch) in line.enumerated() where ch != "." {
                guard let c = colors[ch] else { continue }
                var i = index[ch] ?? 0
                if i == 0 { table.append(c); i = table.count - 1; index[ch] = i }
                src[(y + 1) * w + x + 1] = i
            }
        }
        var up = src, uw = w, uh = h
        for _ in 0..<3 { up = scale2x(up, uw, uh); uw *= 2; uh *= 2 }
        let px = Double(held.pivot.0 + 1) + 0.5, py = Double(held.pivot.1 + 1) + 0.5
        let reach = [(0.0, 0.0), (Double(w), 0), (0, Double(h)), (Double(w), Double(h))].map { hypot($0.0 - px, $0.1 - py) }.max() ?? 8
        let r = Int(reach.rounded(.up)) + 2, n = 2 * r + 1
        let ca = cos(angle), sa = sin(angle)
        var out = [Int](repeating: 0, count: n * n)
        for oy in 0..<n {
            for ox in 0..<n {
                let dx = Double(ox - r), dy = Double(oy - r)
                let u = dx * ca + dy * sa, v = -dx * sa + dy * ca
                let sx = Int(((px + u) * 8).rounded(.down)), sy = Int(((py + v) * 8).rounded(.down))
                if sx >= 0, sy >= 0, sx < uw, sy < uh { out[oy * n + ox] = up[sy * uw + sx] }
            }
        }
        guard let ctx = KartArt.context(width: n, height: n) else { return nil }
        // Element glow (and a wider rarity aura on late weapons) hugging the silhouette.
        let glowColor: CGColor? = item.element != .base ? elem(item.element).mid : (big ? rgb(255, 230, 150) : nil)
        if let g = glowColor {
            let rings = big ? 2 : 1
            var mask = out.map { $0 != 0 }
            for ring in 0..<rings {
                var next = mask
                for y in 0..<n {
                    for x in 0..<n where !mask[y * n + x] {
                        let near = (x > 0 && mask[y * n + x - 1]) || (x < n - 1 && mask[y * n + x + 1]) || (y > 0 && mask[(y - 1) * n + x]) || (y < n - 1 && mask[(y + 1) * n + x])
                        if near {
                            next[y * n + x] = true
                            KartArt.fill(ctx, g.copy(alpha: ring == 0 ? 0.42 : 0.16) ?? g, CGFloat(x), CGFloat(y), 1, 1)
                        }
                    }
                }
                mask = next
            }
        }
        for y in 0..<n { for x in 0..<n where out[y * n + x] != 0 { KartArt.fill(ctx, table[out[y * n + x]], CGFloat(x), CGFloat(y), 1, 1) } }
        guard let img = ctx.makeImage() else { return nil }
        weaponCache[key] = (img, r)
        return (img, r)
    }

    /// Scale2x (EPX): doubles a pixel-art image keeping hard edges; three passes then a nearest sample give clean rotations.
    fileprivate static func scale2x(_ s: [Int], _ w: Int, _ h: Int) -> [Int] {
        var o = [Int](repeating: 0, count: w * h * 4)
        let ow = w * 2
        for y in 0..<h {
            for x in 0..<w {
                let p = s[y * w + x]
                let a = y > 0 ? s[(y - 1) * w + x] : 0, b = x < w - 1 ? s[y * w + x + 1] : 0
                let c = x > 0 ? s[y * w + x - 1] : 0, d = y < h - 1 ? s[(y + 1) * w + x] : 0
                o[2 * y * ow + 2 * x] = (c == a && c != d && a != b) ? a : p
                o[2 * y * ow + 2 * x + 1] = (a == b && a != c && b != d) ? b : p
                o[(2 * y + 1) * ow + 2 * x] = (d == c && d != b && c != a) ? c : p
                o[(2 * y + 1) * ow + 2 * x + 1] = (b == d && b != a && d != c) ? d : p
            }
        }
        return o
    }
}

// MARK: - drawing

extension RpgArt {
    /// Where the weapon hand is (top-left of its 2×2 block in the unmirrored frame) and how the weapon is turned.
    fileprivate struct HeroHold {
        var hand: (Double, Double)
        var angle: Double
        var draw = 0
        /// Muzzle / tip flash strength 0…1.
        var flash = 0.0
    }

    /// Weapon angle at rest per view (side, front, back), unmirrored.
    fileprivate static func restAngle(_ g: HeroGrip, _ v: Int) -> Double {
        switch g {
        case .sword: return [0.55, -0.95, -2.19][v]
        case .dagger: return [0.5, 1.0, 2.14][v]
        case .mace: return [-0.6, -0.95, -2.19][v]
        case .claw: return [0.3, 1.4, 1.74][v]
        case .bow: return [-0.15, 0, .pi][v]
        case .staff: return [-1.2, -1.4, -1.74][v]
        case .rod: return [-0.7, -0.95, -2.19][v]
        case .gun: return [0.35, 1.2, 1.94][v]
        }
    }

    /// How far the weapon's business end reaches from the grip (for sparkles and flashes).
    fileprivate static func gripLength(_ g: HeroGrip, big: Bool) -> Double {
        let base: Double = switch g {
        case .sword: 12
        case .dagger: 7
        case .mace: 10
        case .claw: 7
        case .bow: 3
        case .staff: 10
        case .rod: 9
        case .gun: 9
        }
        return base + (big ? 2 : 0)
    }

    fileprivate static func ease(_ x: Double) -> Double { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }

    fileprivate static func turn(_ a: Double, _ b: Double, _ t: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
        return a + d * t
    }

    fileprivate static func heroHold(_ g: HeroGrip, _ pose: RpgHeroPose, attackTime: Double) -> HeroHold {
        let v = pose.view.rawValue
        let s = weaponShoulder[v]
        let sx = Double(s.0), sy = Double(s.1)
        // Bows and staves are held out in front so they read clear of the body.
        let restHand: (Double, Double) = v == 0 ? (g == .bow || g == .staff ? (sx + 3, sy + 2) : (sx + 1, sy + 3)) : (sx, sy + 3)
        let rest = restAngle(g, v)
        var h = HeroHold(hand: restHand, angle: rest)
        let sweep = pose.flip ? -1.0 : 1.0
        func reach(_ a: Double, _ r: Double) -> (Double, Double) { (sx + cos(a) * r, sy + 1 + sin(a) * r) }
        let t = pose.t
        switch pose.action {
        case .idle:
            if pose.moving {
                if v == 0 {
                    h.hand.0 += [-2, 0, 2, 0][pose.step]
                    h.angle += [0.2, 0, -0.2, 0][pose.step]
                } else {
                    h.hand.1 += [1, 0, -1, 0][pose.step]
                }
            }
        case .attack:
            switch g {
            case .sword, .dagger:
                let head = min(1, 0.25 + (g == .sword ? 6.0 : 9.0) * t)
                let a = pose.aim + sweep * (-1.6 + 3.0 * head)
                h = HeroHold(hand: reach(a, 3.5), angle: a)
            case .mace:
                let head = min(1, 0.2 + 7 * t)
                let a = pose.aim + sweep * (-1.5 + 2.0 * head)
                h = HeroHold(hand: reach(a, 3.5), angle: a, flash: max(0, 1 - t / 0.14))
            case .claw:
                let k = min(2, Int(t / 0.06)), local = t - Double(k) * 0.06
                let ext = local < 0.03 ? local / 0.03 : max(0, 1 - (local - 0.03) / 0.05)
                let a = pose.aim + sweep * Double(k - 1) * 0.45
                h = HeroHold(hand: reach(a, 1.5 + 4.5 * ext), angle: a)
            case .bow:
                let drawn = t < 0.07 ? 0 : min(3, 1 + Int((t - 0.07) / max(0.05, attackTime * 0.5) * 3))
                h = HeroHold(hand: reach(pose.aim, 4), angle: pose.aim, draw: drawn)
            case .gun:
                let kick = max(0, 1 - t / 0.08)
                h = HeroHold(hand: reach(pose.aim, 4.5 - 1.5 * kick), angle: pose.aim - 0.35 * kick, flash: t < 0.05 ? 1 : 0)
            case .staff, .rod:
                let push = ease(t / 0.08)
                h = HeroHold(hand: reach(pose.aim, 1.5 + 2.5 * push), angle: turn(rest, pose.aim, push), flash: max(0, 1 - t / 0.16))
            }
            if g != .bow, g != .gun {
                // Melee and casting swings settle back to the ready stance before the next attack.
                let back = ease((t - attackTime * 0.55) / (attackTime * 0.45))
                h.hand = (h.hand.0 + (restHand.0 - h.hand.0) * back, h.hand.1 + (restHand.1 - h.hand.1) * back)
                h.angle = turn(h.angle, rest, back)
            }
        case .cast:
            let raise = ease(t / 0.08) * (1 - ease((t - heroCastTime + 0.12) / 0.12))
            let top = (sx + 0.5, sy - 5)
            h.hand = (restHand.0 + (top.0 - restHand.0) * raise, restHand.1 + (top.1 - restHand.1) * raise)
            h.angle = turn(rest, -.pi / 2, raise)
            h.flash = raise
        case .hurt:
            h.hand = (sx - 1, sy + 2)
            h.angle = rest + 0.5 * sweep
        case .dash:
            if v == 0 {
                h.hand = (sx - 3, sy + 2)
                h.angle = 2.5
            }
        case .dead:
            break
        }
        return h
    }

    /// Frame bits for a pose: (legs, bob, off arm, face, cloth flutter).
    fileprivate static func heroBits(_ pose: RpgHeroPose, time: Double, seed: Double) -> (legs: Int, bob: Int, arm: Int, face: Int, cloth: Int) {
        let walk = pose.moving ? 1 + pose.step : 0
        let cloth = pose.action == .dash ? 1 : pose.moving ? 1 + (pose.step / 2) % 2 : 0
        switch pose.action {
        case .idle:
            if pose.moving { return (walk, pose.step % 2 == 1 ? -1 : 0, pose.view == .side ? [1, 0, 2, 0][pose.step] : 0, 0, cloth) }
            let blink = (time + seed * 3).truncatingRemainder(dividingBy: 3.4) < 0.13 ? 1 : 0
            return (0, Int((time + seed) / 0.6) % 2, 0, blink, 0)
        case .attack: return (walk, 0, 3, 0, cloth)
        case .cast: return (walk, -1, 4, 0, cloth)
        case .hurt: return (0, 1, 6, 2, 0)
        case .dash: return (5, 1, 5, 0, 1)
        case .dead: return (6, 0, 0, 1, 0)
        }
    }

    /// Draws a hero standing at `p.pos`: body frame, weapon and weapon arm, and the small extras (familiar, aura motes,
    /// element sparks, ring and amulet glints). `alpha` < 1 for stealth, afterimages and the like.
    fileprivate static func heroFrameKey(_ p: RpgPlayer, pose: RpgHeroPose, time: Double, tone: Int? = nil) -> HeroFrameKey {
        let seed = Double(p.id % 7) * 0.37
        let bits = heroBits(pose, time: time, seed: seed)
        let wing = Int((time + seed) * 2.2) % 2
        return HeroFrameKey(look: heroLookKey(p), view: pose.view.rawValue, legs: bits.legs, bob: bits.bob, arm: bits.arm, face: bits.face,
                            flap: bits.cloth + 4 * wing, tone: tone ?? (pose.action == .dead ? 2 : 0))
    }

    /// The cached 32×32 body frame for a pose (everything but the weapon arm and the weapon).
    static func heroFrame(_ p: RpgPlayer, pose: RpgHeroPose, time: Double) -> CGImage? { heroBody(heroFrameKey(p, pose: pose, time: time)) }

    /// The hero's weapon turned to `angle` as it is drawn in the hand.
    static func heroWeaponImage(_ item: RpgItem, cls: RpgClass, angle: Double, draw: Int = 0) -> CGImage? {
        heroWeapon(item, grip: heroGrip(cls), angle: angle, draw: draw)?.image
    }

    static func drawHero(_ c: CGContext, _ p: RpgPlayer, pose: RpgHeroPose, time: Double, alpha: CGFloat = 1, extras: Bool = true) {
        guard let art = heroClasses[p.cls] else { return }
        let key = heroFrameKey(p, pose: pose, time: time)
        let look = key.look
        let pal = heroPalette(look)
        let v = pose.view.rawValue
        let seed = Double(p.id % 7) * 0.37
        let bits = (legs: key.legs, bob: key.bob, arm: key.arm, face: key.face)
        let ghost = pose.action == .dead
        guard let body = heroBody(key) else { return }
        let ax = Double(p.pos.x.rounded()), ay = Double(p.pos.y.rounded()) - (ghost ? 5 + (sin(time * 2.4 + seed) * 1.5).rounded() : 0)
        func wx(_ cx: Double, _ w: Double = 1) -> CGFloat { CGFloat(pose.flip ? ax + 16 - cx - w : ax - 16 + cx) }
        func wy(_ cy: Double) -> CGFloat { CGFloat(ay - 29 + cy) }
        c.saveGState()
        defer { c.restoreGState() }
        c.setAlpha(alpha * (ghost ? 0.8 : 1))
        let glow = heroGlow(p.cls, palette: pal)
        if pose.action == .cast, art.robe || p.cls == .cleric {
            // Casters stand in a turning rune circle.
            let r = 9 + ease(pose.t / 0.1) * 3
            ring(c, ax, ay, r, glow.copy(alpha: 0.75) ?? glow, squash: 0.38)
            for k in 0..<6 {
                let a = time * 3 + Double(k) * .pi / 3
                dot(c, ax + cos(a) * r, ay + sin(a) * r * 0.38, rgb(255, 255, 255))
            }
        }
        let weapon = ghost ? nil : p.weaponItem
        let hold = heroHold(art.grip, pose, attackTime: heroAttackTime(p, time: time))
        let hx = Int(hold.hand.0.rounded()), hy = Int(hold.hand.1.rounded()) + bits.bob
        func drawWeapon() {
            guard let w = weapon, let held = heroWeapon(w, grip: art.grip, angle: hold.angle, draw: hold.draw) else { return }
            let n = Double(2 * held.r + 1), x0 = Double(hx + 1 - held.r), y0 = Double(hy + 1 - held.r)
            KartArt.draw(held.image, in: c, rect: CGRect(x: wx(x0, n), y: wy(y0), width: CGFloat(n), height: CGFloat(n)), flipX: pose.flip)
        }
        let familiar = p.cls == .summoner && !ghost && extras
        let orbit = time * 2.6 + seed
        if familiar, sin(orbit) < 0 { heroFamiliar(c, ax: ax, ay: ay, orbit: orbit, time: time, color: glow) }
        if v == 2 { drawWeapon() }
        KartArt.draw(body, in: c, rect: CGRect(x: ax - 16, y: ay - 29, width: 32, height: 32), flipX: pose.flip)
        if pose.action == .hurt, let flash = heroBody(heroFrameKey(p, pose: pose, time: time, tone: 1)) {
            c.setAlpha(alpha * CGFloat(0.7 * max(0, 1 - pose.t / 0.2)))
            KartArt.draw(flash, in: c, rect: CGRect(x: ax - 16, y: ay - 29, width: 32, height: 32), flipX: pose.flip)
            c.setAlpha(alpha)
        }
        if v != 2 { drawWeapon() }
        if !ghost {
            let shoulder = weaponShoulder[v]
            arm(from: (shoulder.0, shoulder.1 + bits.bob), to: (hx, hy), sleeve: "1", hand: "3") { x, y, w, h, ch in
                guard let col = pal[ch] else { return }
                KartArt.fill(c, col, wx(Double(x), Double(w)), wy(Double(y)), CGFloat(w), CGFloat(h))
            }
        }
        if familiar, sin(orbit) >= 0 { heroFamiliar(c, ax: ax, ay: ay, orbit: orbit, time: time, color: glow) }
        guard !ghost, extras else { return }
        // Sparks at the business end: element colour, and a flash on shots, thrusts and casts.
        if let w = weapon {
            let len = gripLength(art.grip, big: heroBigWeapon(w))
            let tx = Double(hx) + 1 + cos(hold.angle) * len, ty = Double(hy) + 1 + sin(hold.angle) * len
            let px = Double(wx(tx)), py = Double(wy(ty))
            if hold.flash > 0.05 {
                let e = elem(w.element == .base ? (art.grip == .gun ? .fire : .holy) : w.element)
                star(c, px, py, Int((hold.flash * 3).rounded()), e.mid, e.core)
            }
            if w.element != .base {
                let e = elem(w.element)
                let k = Int(time * 9 + seed * 5)
                if k % 3 != 0 {
                    let jx = Double((k * 7) % 5) - 2, jy = Double((k * 3) % 5) - 2 - (w.element == .fire ? Double(k % 4) : 0)
                    dot(c, px + jx, py + jy, k % 2 == 0 ? e.spark : e.core)
                }
            }
            if (p.plus[w.id] ?? 0) >= 7 {
                // A glint runs up the weapon on highly enhanced gear.
                let g = (time * 1.6 + seed).truncatingRemainder(dividingBy: 1.6)
                if g < 0.5 {
                    let f = g / 0.5 * len
                    let gx = Double(wx(Double(hx) + 1 + cos(hold.angle) * f)), gy = Double(wy(Double(hy) + 1 + sin(hold.angle) * f))
                    star(c, gx, gy, 1, rgb(255, 255, 220), rgb(255, 255, 255))
                }
            }
        }
        // Ring and amulet of legendary rarity or better twinkle now and then.
        if let ring = p.ringItem, ring.rarity >= 3, (time + seed).truncatingRemainder(dividingBy: 1.4) < 0.24 {
            star(c, Double(wx(Double(hx) + 1.5)), Double(wy(Double(hy) + 1.5)), 1, rarityGlint(ring.rarity), rgb(255, 255, 255))
        }
        if let amulet = p.amuletItem, amulet.rarity >= 3, (time + seed + 0.7).truncatingRemainder(dividingBy: 1.9) < 0.24 {
            star(c, Double(wx(16)), Double(wy(19 + Double(bits.bob))), 1, rarityGlint(amulet.rarity), rgb(255, 255, 255))
        }
        // 3차 and 4차 heroes shed a few motes of their colour.
        if p.job != 0, p.tier >= 2 {
            for k in 0..<(p.tier >= 3 ? 4 : 2) {
                let life = (time * 0.9 + Double(k) * 0.37 + seed).truncatingRemainder(dividingBy: 1)
                let a = Double(k) * 2.4 + seed * 4
                dot(c, ax + cos(a) * 8, ay - 2 - life * 22, glow.copy(alpha: 1 - life) ?? glow)
            }
        }
    }

    fileprivate static func rarityGlint(_ rarity: Int) -> CGColor { rarity >= 4 ? rgb(255, 120, 170) : rgb(255, 220, 110) }

    /// The summoner's familiar: a little spirit circling at shoulder height with a short tail.
    fileprivate static func heroFamiliar(_ c: CGContext, ax: Double, ay: Double, orbit: Double, time: Double, color: CGColor) {
        for k in 0..<4 {
            let a = orbit - Double(k) * 0.22
            let x = ax + cos(a) * 11, y = ay - 15 + sin(a) * 3.5 + sin(time * 5) * 1.2
            if k == 0 {
                dot(c, x - 1, y, color); dot(c, x + 1, y, color); dot(c, x, y - 1, color); dot(c, x, y + 1, color)
                dot(c, x, y, rgb(255, 255, 255))
            } else {
                dot(c, x, y, color.copy(alpha: 0.7 - Double(k) * 0.18) ?? color)
            }
        }
    }

    /// Height of a class's tallest frame above the feet (hats and halos included), for name tags and chat bubbles.
    static func heroHeight(_ cls: RpgClass) -> CGFloat {
        guard let art = heroClasses[cls] else { return 24 }
        let top = art.head.map { part in part.y + (part.g.firstIndex { $0.contains { $0 != "." } } ?? 0) }.min() ?? 7
        return CGFloat(heroAnchor.y - top)
    }

    /// A finished hero picture (body and weapon) for menus: `size`×`size` with the feet near the bottom.
    static func heroPreview(_ p: RpgPlayer, pose: RpgHeroPose, time: Double, size: Int = 48) -> CGImage? {
        guard let ctx = KartArt.context(width: size, height: size) else { return nil }
        var q = p
        q.pos = CGPoint(x: size / 2, y: size - 6)
        drawHero(ctx, q, pose: pose, time: time)
        return ctx.makeImage()
    }
}

// MARK: - motion, ground and bursts

/// What the view remembers about each hero between frames: drawn speed and distance walked (they drive the walk
/// cycle for everyone, remote players included), footstep dust, dash afterimages, blink streaks and level-up bursts.
@MainActor
final class RpgHeroTracker {
    struct Motion {
        var map: RpgMapID
        var pos: CGPoint
        var at: Double
        var speed = 0.0
        var walked = 0.0
        /// Recent positions while dashing, oldest first (afterimages).
        var trail: [CGPoint] = []
        var trailAt = -10.0
        var blinkFrom = CGPoint.zero, blinkTo = CGPoint.zero, blinkAt = -10.0
        /// Footstep puffs: where and when.
        var dust: [(pos: CGPoint, at: Double)] = []
        var lastStep = -1
        var level: Int, job: Int, tier: Int
        var burstAt = -10.0
        var burstBig = false
    }

    private var motions: [Int: Motion] = [:]
    private var prunedAt = 0.0

    func update(_ p: RpgPlayer, time now: Double) -> Motion {
        if now - prunedAt > 3 {
            prunedAt = now
            motions = motions.filter { abs(now - $0.value.at) < 5 }
        }
        guard var m = motions[p.id], m.map == p.map, abs(now - m.at) < 0.5 else {
            let fresh = Motion(map: p.map, pos: p.pos, at: now, level: p.level, job: p.job, tier: p.tier)
            motions[p.id] = fresh
            return fresh
        }
        // A mirror's clock can step back a little when a snapshot lands: just hold still then.
        let dt = max(0, now - m.at)
        let d = Double(hypot(p.pos.x - m.pos.x, p.pos.y - m.pos.y))
        if d > 26, dt < 0.1 {
            m.blinkFrom = m.pos; m.blinkTo = p.pos; m.blinkAt = now
            m.trail.removeAll(keepingCapacity: true)
        } else if dt > 0 {
            m.speed += (d / dt - m.speed) * min(1, dt * 14)
            m.walked += d
        }
        if p.dash != nil || m.speed > 210 {
            if now - m.trailAt > 0.03 {
                m.trail.append(p.pos)
                if m.trail.count > 5 { m.trail.removeFirst() }
                m.trailAt = now
            }
        } else if !m.trail.isEmpty, now - m.trailAt > 0.06 {
            m.trail.removeFirst()
            m.trailAt = now
        }
        let step = Int(m.walked / RpgArt.heroStride)
        if !p.dead, p.moving || m.speed > 24, step != m.lastStep, step % 2 == 0 {
            m.dust.append((p.pos, now))
            if m.dust.count > 4 { m.dust.removeFirst() }
        }
        m.lastStep = step
        m.dust.removeAll { now - $0.at > 0.35 }
        if p.level > m.level || p.job != m.job || p.tier > m.tier {
            m.burstAt = now
            m.burstBig = p.job != m.job || p.tier > m.tier
        }
        (m.level, m.job, m.tier) = (p.level, p.job, p.tier)
        m.pos = p.pos
        m.at = now
        motions[p.id] = m
        return m
    }
}

extension RpgArt {
    /// Under the hero: a crisp shadow, footstep dust, dash afterimages and the streak a blink leaves behind.
    static func drawHeroGround(_ c: CGContext, _ p: RpgPlayer, motion m: RpgHeroTracker.Motion, pose: RpgHeroPose, time: Double) {
        let x = p.pos.x.rounded(), y = p.pos.y.rounded()
        let shade = rgb(0, 0, 0, pose.action == .dead ? 0.16 : 0.3)
        KartArt.fill(c, shade, x - 4, y - 1, 8, 1)
        KartArt.fill(c, shade, x - 6, y, 12, 1)
        KartArt.fill(c, shade, x - 4, y + 1, 8, 1)
        for puff in m.dust {
            let a = (time - puff.at) / 0.35
            guard a >= 0, a < 1 else { continue }
            let col = rgb(236, 226, 206, 0.75 * (1 - a))
            let back: Double = p.facingRight ? -1 : 1
            dot(c, Double(puff.pos.x) + back * (2 + a * 5), Double(puff.pos.y) - a * 3, col)
            dot(c, Double(puff.pos.x) + back * (4 + a * 7), Double(puff.pos.y) - 1 - a * 2, col)
            if a < 0.5 { dot(c, Double(puff.pos.x) + back * 3, Double(puff.pos.y) + 1, col) }
        }
        let n = m.trail.count
        for (i, at) in m.trail.enumerated() where hypot(at.x - p.pos.x, at.y - p.pos.y) > 3 {
            var ghost = p
            ghost.pos = at
            drawHero(c, ghost, pose: pose, time: time, alpha: CGFloat(0.12 + 0.3 * Double(i + 1) / Double(n + 1)), extras: false)
        }
        let age = time - m.blinkAt
        if age >= 0, age < 0.3 {
            let e = elem(p.element == .base ? .cosmic : p.element)
            let k = 1 - age / 0.3
            var from = p
            from.pos = m.blinkFrom
            drawHero(c, from, pose: pose, time: time, alpha: CGFloat(0.35 * k), extras: false)
            let steps = 10
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                guard t > age / 0.3 else { continue }
                let px = Double(m.blinkFrom.x + (m.blinkTo.x - m.blinkFrom.x) * t), py = Double(m.blinkFrom.y + (m.blinkTo.y - m.blinkFrom.y) * t) - 9
                dot(c, px, py + Double((i * 5) % 7) - 3, (i % 2 == 0 ? e.mid : e.core).copy(alpha: k) ?? e.mid)
            }
        }
    }

    /// Over the hero: the level-up pillar (bigger and in the hero's colour for a job advance).
    static func drawHeroBurst(_ c: CGContext, _ p: RpgPlayer, motion m: RpgHeroTracker.Motion, time: Double) {
        let age = time - m.burstAt, life = m.burstBig ? 1.6 : 1.2
        guard age >= 0, age < life else { return }
        let k = age / life
        let x = Double(p.pos.x.rounded()), y = Double(p.pos.y.rounded())
        let gold = rgb(255, 226, 110), core = rgb(255, 255, 230)
        let tone = m.burstBig ? heroGlow(p.cls, palette: heroPalette(heroLookKey(p))) : gold
        let fade = 1 - k
        // A column of light that opens then thins out.
        let w = (m.burstBig ? 14.0 : 10.0) * (k < 0.15 ? k / 0.15 : 1) * (0.4 + 0.6 * fade)
        for row in 0..<34 {
            let a = fade * 0.45 * (1 - Double(row) / 34)
            c.setFillColor(tone.copy(alpha: a) ?? tone)
            c.fill(CGRect(x: (x - w / 2).rounded(), y: y - 2 - Double(row) * 1.5, width: w.rounded(), height: 2))
        }
        ring(c, x, y, 6 + k * (m.burstBig ? 20 : 14), (k < 0.5 ? core : tone).copy(alpha: fade) ?? tone, squash: 0.4)
        if m.burstBig { ring(c, x, y, 3 + k * 12, tone.copy(alpha: fade) ?? tone, squash: 0.4) }
        for i in 0..<(m.burstBig ? 10 : 7) {
            let rise = (k * 1.4 + Double(i) * 0.13).truncatingRemainder(dividingBy: 1)
            let sx = x + sin(Double(i) * 2.3) * (5 + Double(i % 3) * 3)
            let sy = y - 4 - rise * 36
            star(c, sx, sy, i % 3 == 0 ? 2 : 1, tone.copy(alpha: fade) ?? tone, core)
        }
    }
}

// MARK: - showcase (title screen)

extension RpgArt {
    /// A looping demo for menus: stand facing you, walk right, swing, cast, walk away, turn back. `still` only breathes.
    static func heroShowcasePose(_ p: RpgPlayer, time: Double, still: Bool = false) -> RpgHeroPose {
        var pose = RpgHeroPose(action: .idle, view: .front, flip: false, moving: false, step: 0, t: time, aim: .pi / 2)
        guard !still else { return pose }
        let loop = 9.0, t = time.truncatingRemainder(dividingBy: loop)
        let step = Int(time * 8) % 4
        switch t {
        case ..<1.6: break
        case ..<3.2: (pose.view, pose.moving, pose.step, pose.aim) = (.side, true, step, 0)
        case ..<4.6:
            let swing = heroAttackTime(p, time: 0) + 0.12
            (pose.view, pose.action, pose.aim, pose.t) = (.side, .attack, 0, (t - 3.2).truncatingRemainder(dividingBy: swing))
        case ..<5.4: (pose.view, pose.action, pose.aim, pose.t) = (.side, .cast, 0, min(t - 4.6, heroCastTime - 0.01))
        case ..<7.0: (pose.view, pose.moving, pose.step, pose.aim) = (.back, true, step, -.pi / 2)
        case ..<7.8: (pose.view, pose.action, pose.aim, pose.t) = (.front, .attack, .pi / 2, (t - 7.0).truncatingRemainder(dividingBy: heroAttackTime(p, time: 0) + 0.12))
        default: (pose.view, pose.flip, pose.moving, pose.step, pose.aim) = (.side, true, true, step, 0)
        }
        return pose
    }
}

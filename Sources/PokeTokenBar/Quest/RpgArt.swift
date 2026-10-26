import AppKit
import CoreGraphics

// SPIKE: all of 픽셀 모험's art, drawn in code: 16×16 character and monster sprites (character grids +
// palettes, recoloured per zone, doubled with a crown for bosses), weapon and item icons, the tile set
// for every zone, town buildings, portals and the skill / weapon effects. Sprites and icons are baked
// once into CGImages; effects are drawn per frame into the low-res frame bitmap.

typealias RpgGrid = [String]

@MainActor
enum RpgArt {
    static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor { KartArt.rgb(r, g, b, a) }
    static let outline = rgb(28, 22, 38)

    static let palette: [Character: CGColor] = [
        "K": rgb(28, 22, 38), "S": rgb(244, 196, 152), "s": rgb(206, 146, 112),
        "M": rgb(186, 196, 210), "m": rgb(120, 132, 152), "R": rgb(206, 54, 54), "r": rgb(140, 30, 34),
        "Y": rgb(240, 190, 50), "B": rgb(226, 236, 246), "L": rgb(150, 96, 52), "l": rgb(104, 64, 36),
        "G": rgb(72, 164, 76), "g": rgb(40, 104, 48), "P": rgb(126, 74, 188), "p": rgb(82, 42, 134),
        "O": rgb(110, 226, 255), "W": rgb(250, 250, 250), "H": rgb(112, 70, 40),
        "E": rgb(96, 206, 116), "e": rgb(50, 144, 74), "A": rgb(116, 72, 156), "a": rgb(76, 44, 108),
        "C": rgb(244, 226, 186), "c": rgb(204, 172, 132), "X": rgb(232, 226, 210), "x": rgb(170, 162, 146),
        "F": rgb(255, 140, 40), "f": rgb(255, 220, 90), "Z": rgb(150, 150, 165), "z": rgb(100, 100, 116),
        "N": rgb(130, 122, 112), "n": rgb(92, 86, 80), "Q": rgb(255, 150, 60), "T": rgb(200, 150, 70), "t": rgb(140, 96, 40),
    ]

    private static func overlay(_ g: RpgGrid, _ marks: [(Int, Int, Character)]) -> RpgGrid {
        var rows = g.map { Array($0) }
        for (x, y, c) in marks where y < rows.count && x < rows[y].count { rows[y][x] = c }
        return rows.map { String($0) }
    }

    // MARK: sprite grids

    static let warrior: RpgGrid = [
        "......KKKK......", ".....KMMMMK.....", "....KMMBMMMK....", "....KMMMMMMK....", "....KKKKKKKK....", "....KSKSSKSK....",
        "....KSSSSSSK....", ".....KSSSSK.....", "...KKRKKKKRKK...", "..KRRMMMMMMRRK..", "..KRKMMYYMMKRK..", "..KSKmMMMMmKSK..",
        "...KKLLLLLLKK...", "....KMMKKMMK....", "....KmmKKmmK....", "....KKK..KKK....",
    ]
    static let archer: RpgGrid = overlay([
        "................", ".....KKKKKK.....", "....KGGGGGGK....", "...KGGGGGGGGK...", "...KgKKKKKKgK...", "....KSKSSKSK....",
        "....KSSSSSSK....", ".....KSSSSK.....", "....KKGGGGKK....", "...KLKGGGGKLK...", "...KSKgLLgKSK...", "....KKGGGGKK....",
        "....KgGKKGgK....", "....KLLKKLLK....", "....KllKKllK....", "....KKK..KKK....",
    ], [(13, 6, "K"), (13, 7, "L"), (14, 5, "K"), (14, 6, "Y"), (13, 8, "L")])
    static let mage: RpgGrid = [
        ".......KK.......", "......KPPK......", ".....KPPPPK.....", "....KPPYPPPK....", "..KKPPPPPPPPKK..", "..KppppppppppK..",
        "....KSKSSKSK....", "....KSSSSSSK....", ".....KSSSSK.....", "....KKPPPPKK....", "...KPKPPPPKPK...", "...KSKpPPpKSK...",
        "....KPPPPPPK....", "...KPPPPPPPPK...", "...KppppppppK...", "....KKKKKKKK....",
    ]
    static let villager: RpgGrid = [
        "......KKKK......", ".....KHHHHK.....", "....KHHHHHHK....", "....KHSSSSHK....", "....KSKSSKSK....", "....KSSSSSSK....",
        ".....KSSSSK.....", "....KKWWWWKK....", "...KCKWWWWKCK...", "...KSKWWWWKSK...", "....KKWWWWKK....", "....KCCCCCCK....",
        "....KCCKKCCK....", "....KccKKccK....", "....KKK..KKK....", "................",
    ]
    static let slime: RpgGrid = [
        "................", "................", "................", "................", "................", "......KKKK......",
        "....KKEEEEKK....", "...KEEWEEEEEK...", "..KEEWWEEEEEEK..", "..KEEEEEEEEEEK..", ".KEEEKEEEEKEEEK.", ".KEEEKEEEEKEEEK.",
        ".KeEEEEEEEEEEeK.", ".KeeEEEKKEEEeeK.", "..KeeeeeeeeeeK..", "...KKKKKKKKKK...",
    ]
    static let bat: RpgGrid = [
        "................", "................", "................", "KK............KK", "KAK....KK....KAK", "KAAK..KAAK..KAAK",
        "KAAAKKAAAAKKAAAK", "KAAAAAAAAAAAAAAK", ".KAaAAWAAWAAaAK.", "..KaAAAAAAAAaK..", "...KAAKWWKAAK...", "....KK.KK.KK....",
        "................", "................", "................", "................",
    ]
    static let mushroom: RpgGrid = [
        "................", "................", "......KKKK......", "....KKRRRRKK....", "...KRRWWRRRRK...", "..KRRWWRRRWWRK..",
        "..KRRRRRRRWWRK..", ".KRRWWRRRRRRRRK.", ".KrRWWRRRRRWWrK.", ".KKKKKKKKKKKKKK.", "....KCCCCCCK....", "....KCKCCKCK....",
        "....KCCCCCCK....", "....KcCCCCcK....", "...KKKK..KKKK...", "................",
    ]
    static let skeleton: RpgGrid = [
        "......KKKK......", ".....KXXXXK.....", "....KXXXXXXK....", "....KXKXXKXK....", "....KXXXXXXK....", ".....KXKKXK.....",
        "......KXXK......", "....KKXXXXKK....", "...KXKxKKxKXK...", "...KXKXXXXKXK...", "...KXKxKKxKXK...", "....K.KXXK.K....",
        ".....KXKKXK.....", ".....KXK.KXK....", "....KXXK.KXXK...", "....KKK...KKK...",
    ]
    static let wolf: RpgGrid = [
        "................", "................", "................", "...K............", "..KZK......KKK..", "..KZZKKKKKKZZZK.",
        ".KZZZZZZZZZZZK..", "KRZKZZZZZZZZZK..", "KZZZZZZZZZZZZZK.", ".KKzZZZZZZZZZZZK", "...KZzKKKKZZKzK.", "...KZK....KZKK..",
        "...KzK....KzK...", "...KK.....KK....", "................", "................",
    ]
    static let golem: RpgGrid = [
        "................", "....KKKKKKKK....", "...KNNNNNNNNK...", "...KNQNNNNQNK...", "...KNNNNNNNNK...", ".KKKKNNNNNNKKKK.",
        "KNNNKNNnnNNKNNNK", "KNNNKNnNNnNKNNNK", "KNNKNNNNNNNNKNNK", ".KKKNNNNNNNNKKK.", "....KNNNNNNK....", "....KNNKKNNK....",
        "...KNNNKKNNNK...", "...KnnnK.KnnnK..", "...KKKKK.KKKKK..", "................",
    ]
    static let scorpion: RpgGrid = [
        "................", "..........KK....", ".........KTTK...", ".........KTK....", "..........KTK...", "...........KTK..",
        "....KKKKKKKKTK..", "..KKTTTTTTTTK...", ".KTKTtTTtTTTTK..", "KTTKTTTTTTTTTTK.", "KKKTTRTTRTTTTK..", "..KtKtKtKtKtK...",
        ".K.K.K.K.K.K.K..", "................", "................", "................",
    ]
    static let crown: RpgGrid = ["K.K.K.K", "KYKYKYK", "KYYYYYK", "KYRYOYK", "KKKKKKK"]

    private struct SpriteSpec {
        let grid: RpgGrid
        let swap: [Character: CGColor]
        var boss = false
    }

    private static let specs: [String: SpriteSpec] = [
        "warrior": SpriteSpec(grid: warrior, swap: [:]), "archer": SpriteSpec(grid: archer, swap: [:]),
        "mage": SpriteSpec(grid: mage, swap: [:]), "villager": SpriteSpec(grid: villager, swap: [:]),
        "slime": SpriteSpec(grid: slime, swap: [:]),
        "blueslime": SpriteSpec(grid: slime, swap: ["E": rgb(100, 160, 255), "e": rgb(50, 96, 200)]),
        "goldslime": SpriteSpec(grid: slime, swap: ["E": rgb(255, 214, 70), "e": rgb(214, 150, 30)]),
        "bat": SpriteSpec(grid: bat, swap: [:]),
        "cavebat": SpriteSpec(grid: bat, swap: ["A": rgb(70, 74, 100), "a": rgb(44, 46, 66), "W": rgb(255, 80, 80)]),
        "mushroom": SpriteSpec(grid: mushroom, swap: [:]),
        "brownshroom": SpriteSpec(grid: mushroom, swap: ["R": rgb(170, 110, 60), "r": rgb(120, 76, 40)]),
        "skeleton": SpriteSpec(grid: skeleton, swap: [:]),
        "skelarcher": SpriteSpec(grid: overlay(skeleton, [(1, 6, "L"), (0, 7, "L"), (0, 8, "L"), (0, 9, "L"), (1, 10, "L"), (2, 7, "W"), (2, 8, "W"), (2, 9, "W")]), swap: [:]),
        "wolf": SpriteSpec(grid: wolf, swap: [:]),
        "golem": SpriteSpec(grid: golem, swap: [:]),
        "sandslime": SpriteSpec(grid: slime, swap: ["E": rgb(230, 200, 120), "e": rgb(180, 140, 70)]),
        "scorpion": SpriteSpec(grid: scorpion, swap: [:]),
        "mummy": SpriteSpec(grid: skeleton, swap: ["X": rgb(224, 210, 168), "x": rgb(170, 150, 104)]),
        "sandgolem": SpriteSpec(grid: golem, swap: ["N": rgb(204, 172, 112), "n": rgb(150, 120, 76), "Q": rgb(255, 230, 120)]),
        "iceslime": SpriteSpec(grid: slime, swap: ["E": rgb(176, 232, 255), "e": rgb(100, 170, 230)]),
        "snowwolf": SpriteSpec(grid: wolf, swap: ["Z": rgb(236, 242, 252), "z": rgb(170, 190, 214), "R": rgb(80, 160, 255)]),
        "icebat": SpriteSpec(grid: bat, swap: ["A": rgb(130, 200, 240), "a": rgb(70, 130, 190), "W": rgb(255, 255, 255)]),
        "yeti": SpriteSpec(grid: golem, swap: ["N": rgb(240, 244, 250), "n": rgb(180, 200, 222), "Q": rgb(80, 160, 255)]),
        "magmaslime": SpriteSpec(grid: slime, swap: ["E": rgb(255, 120, 40), "e": rgb(180, 50, 30), "W": rgb(255, 240, 120)]),
        "firebat": SpriteSpec(grid: bat, swap: ["A": rgb(220, 74, 40), "a": rgb(140, 30, 20), "W": rgb(255, 230, 90)]),
        "flameskel": SpriteSpec(grid: skeleton, swap: ["X": rgb(255, 156, 84), "x": rgb(200, 84, 40)]),
        "lavagolem": SpriteSpec(grid: golem, swap: ["N": rgb(74, 52, 52), "n": rgb(40, 30, 30), "Q": rgb(255, 120, 40)]),
        "darkknight": SpriteSpec(grid: warrior, swap: ["M": rgb(74, 64, 96), "m": rgb(44, 36, 60), "R": rgb(150, 40, 200), "r": rgb(90, 20, 130), "B": rgb(200, 180, 255), "S": rgb(170, 160, 190)]),
        "shadowmage": SpriteSpec(grid: mage, swap: ["P": rgb(52, 42, 72), "p": rgb(30, 24, 44), "S": rgb(180, 170, 200), "Y": rgb(255, 60, 60)]),
        "demonbat": SpriteSpec(grid: bat, swap: ["A": rgb(140, 30, 60), "a": rgb(90, 20, 40), "W": rgb(255, 230, 60)]),
        "gargoyle": SpriteSpec(grid: golem, swap: ["N": rgb(120, 100, 150), "n": rgb(80, 64, 110), "Q": rgb(255, 60, 200)]),
        "bogshroom": SpriteSpec(grid: mushroom, swap: ["R": rgb(90, 130, 60), "r": rgb(50, 84, 40)]),
        "bogwolf": SpriteSpec(grid: wolf, swap: ["Z": rgb(96, 110, 80), "z": rgb(60, 72, 50), "R": rgb(200, 220, 80)]),
        "mossgolem": SpriteSpec(grid: golem, swap: ["N": rgb(100, 140, 80), "n": rgb(60, 94, 50), "Q": rgb(190, 255, 120)]),
        "ruinbat": SpriteSpec(grid: bat, swap: ["A": rgb(150, 130, 100), "a": rgb(100, 84, 62), "W": rgb(120, 255, 200)]),
        "ruinskel": SpriteSpec(grid: skeleton, swap: ["X": rgb(190, 180, 150), "x": rgb(120, 110, 86)]),
        "ruinwarden": SpriteSpec(grid: golem, swap: ["N": rgb(150, 144, 130), "n": rgb(100, 94, 82), "Q": rgb(80, 230, 200)]),
        "wraith": SpriteSpec(grid: mage, swap: ["P": rgb(90, 100, 130), "p": rgb(50, 58, 84), "S": rgb(200, 220, 240), "Y": rgb(120, 255, 255)]),
        "bonelord": SpriteSpec(grid: skeleton, swap: ["X": rgb(120, 110, 150), "x": rgb(70, 60, 100)]),
        "cryptguard": SpriteSpec(grid: golem, swap: ["N": rgb(60, 60, 84), "n": rgb(34, 34, 52), "Q": rgb(120, 255, 255)]),
        "fieldswarm": SpriteSpec(grid: slime, swap: ["E": rgb(150, 235, 120), "e": rgb(70, 160, 70)]),
        "fieldcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(176, 130, 80), "z": rgb(120, 84, 50), "R": rgb(255, 200, 80)]),
        "fieldexploder": SpriteSpec(grid: mushroom, swap: ["R": rgb(255, 210, 60), "r": rgb(220, 140, 30)]),
        "forestswarm": SpriteSpec(grid: bat, swap: ["A": rgb(70, 120, 70), "a": rgb(40, 76, 44), "W": rgb(255, 255, 120)]),
        "forestcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(150, 100, 80), "z": rgb(100, 60, 46), "R": rgb(255, 230, 200)]),
        "forestexploder": SpriteSpec(grid: mushroom, swap: ["R": rgb(170, 90, 200), "r": rgb(110, 50, 140)]),
        "cave1swarm": SpriteSpec(grid: scorpion, swap: ["T": rgb(80, 80, 96), "t": rgb(46, 46, 60), "R": rgb(255, 80, 80)]),
        "cave1charger": SpriteSpec(grid: skeleton, swap: ["X": rgb(220, 160, 140), "x": rgb(160, 90, 80)]),
        "cave1exploder": SpriteSpec(grid: slime, swap: ["E": rgb(255, 150, 70), "e": rgb(200, 80, 30), "W": rgb(255, 255, 160)]),
        "cave2swarm": SpriteSpec(grid: scorpion, swap: ["T": rgb(150, 150, 160), "t": rgb(100, 100, 112), "R": rgb(120, 220, 255)]),
        "cave2charger": SpriteSpec(grid: golem, swap: ["N": rgb(150, 130, 120), "n": rgb(100, 84, 76), "Q": rgb(255, 110, 60)]),
        "cave2exploder": SpriteSpec(grid: skeleton, swap: ["X": rgb(255, 110, 90), "x": rgb(190, 50, 40)]),
        "desertswarm": SpriteSpec(grid: scorpion, swap: ["T": rgb(240, 210, 120), "t": rgb(190, 150, 70), "R": rgb(255, 120, 40)]),
        "desertcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(224, 190, 120), "z": rgb(170, 132, 76), "R": rgb(255, 230, 120)]),
        "desertexploder": SpriteSpec(grid: mushroom, swap: ["R": rgb(90, 190, 90), "r": rgb(50, 130, 60)]),
        "snowswarm": SpriteSpec(grid: slime, swap: ["E": rgb(225, 245, 255), "e": rgb(150, 190, 225), "W": rgb(120, 200, 255)]),
        "snowcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(190, 215, 240), "z": rgb(120, 150, 190), "R": rgb(80, 160, 255)]),
        "snowexploder": SpriteSpec(grid: slime, swap: ["E": rgb(255, 255, 255), "e": rgb(190, 210, 240), "W": rgb(255, 90, 90)]),
        "volcanoswarm": SpriteSpec(grid: scorpion, swap: ["T": rgb(230, 90, 40), "t": rgb(150, 40, 20), "R": rgb(255, 230, 90)]),
        "volcanocharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(110, 60, 50), "z": rgb(60, 30, 28), "R": rgb(255, 130, 40)]),
        "volcanoexploder": SpriteSpec(grid: skeleton, swap: ["X": rgb(255, 210, 90), "x": rgb(230, 120, 40)]),
        "castleswarm": SpriteSpec(grid: skeleton, swap: ["X": rgb(130, 130, 150), "x": rgb(80, 80, 100)]),
        "castlecharger": SpriteSpec(grid: warrior, swap: ["M": rgb(130, 40, 50), "m": rgb(80, 20, 30), "R": rgb(255, 120, 60), "r": rgb(180, 60, 30), "B": rgb(255, 210, 200)]),
        "castleexploder": SpriteSpec(grid: mage, swap: ["P": rgb(190, 80, 220), "p": rgb(110, 40, 150), "Y": rgb(255, 255, 120)]),
        "swampswarm": SpriteSpec(grid: slime, swap: ["E": rgb(70, 110, 60), "e": rgb(40, 70, 40), "W": rgb(200, 255, 120)]),
        "swampcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(86, 100, 64), "z": rgb(52, 62, 40), "R": rgb(220, 240, 120)]),
        "swampexploder": SpriteSpec(grid: mushroom, swap: ["R": rgb(220, 230, 90), "r": rgb(160, 170, 50)]),
        "ruinsswarm": SpriteSpec(grid: scorpion, swap: ["T": rgb(190, 180, 150), "t": rgb(130, 120, 96), "R": rgb(120, 255, 200)]),
        "ruinscharger": SpriteSpec(grid: golem, swap: ["N": rgb(190, 175, 140), "n": rgb(130, 116, 90), "Q": rgb(120, 255, 200)]),
        "ruinsexploder": SpriteSpec(grid: skeleton, swap: ["X": rgb(190, 110, 220), "x": rgb(110, 50, 150)]),
        "cryptswarm": SpriteSpec(grid: skeleton, swap: ["X": rgb(150, 240, 240), "x": rgb(70, 160, 170)]),
        "cryptcharger": SpriteSpec(grid: wolf, swap: ["Z": rgb(222, 218, 200), "z": rgb(150, 146, 128), "R": rgb(120, 255, 255)]),
        "cryptexploder": SpriteSpec(grid: mage, swap: ["P": rgb(70, 70, 100), "p": rgb(36, 36, 60), "Y": rgb(255, 80, 120)]),
        "slimeking": SpriteSpec(grid: slime, swap: ["E": rgb(110, 220, 130), "e": rgb(46, 140, 80)], boss: true),
        "sandking": SpriteSpec(grid: golem, swap: ["N": rgb(214, 180, 116), "n": rgb(160, 128, 80), "Q": rgb(255, 80, 40)], boss: true),
        "yetiking": SpriteSpec(grid: golem, swap: ["N": rgb(244, 248, 255), "n": rgb(170, 196, 226), "Q": rgb(60, 140, 255)], boss: true),
        "skelking": SpriteSpec(grid: skeleton, swap: ["X": rgb(255, 170, 90), "x": rgb(210, 80, 40)], boss: true),
        "demonking": SpriteSpec(grid: mage, swap: ["P": rgb(60, 20, 50), "p": rgb(36, 10, 30), "S": rgb(210, 160, 190), "Y": rgb(255, 40, 60)], boss: true),
    ]

    private static var spriteCache: [String: CGImage] = [:]

    /// A sprite as a 16×16 image (32×40 with a crown for bosses), optionally tinted for weapon colours.
    static func sprite(_ key: String, tint: [Character: CGColor] = [:]) -> CGImage? {
        let cacheKey = key + tint.keys.sorted().map(String.init).joined() + tint.values.map { "\($0.components ?? [])" }.joined()
        if let img = spriteCache[cacheKey] { return img }
        guard let spec = specs[key] else { return nil }
        let colors = palette.merging(spec.swap) { _, new in new }.merging(tint) { _, new in new }
        let scale = spec.boss ? 2 : 1
        let crownSpace = spec.boss ? 8 : 0
        guard let ctx = KartArt.context(width: 16 * scale, height: 16 * scale + crownSpace) else { return nil }
        for (row, line) in spec.grid.enumerated() {
            for (col, ch) in line.enumerated() {
                guard let c = colors[ch] else { continue }
                KartArt.fill(ctx, c, CGFloat(col * scale), CGFloat(row * scale + crownSpace), CGFloat(scale), CGFloat(scale))
            }
        }
        if spec.boss {
            // Crown sits on the first opaque row of the sprite.
            let top = spec.grid.firstIndex { $0.contains("K") } ?? 0
            for (row, line) in crown.enumerated() {
                for (col, ch) in line.enumerated() {
                    guard let c = colors[ch] else { continue }
                    KartArt.fill(ctx, c, CGFloat(9 + col * 2), CGFloat(top * 2 + crownSpace - 10 + row * 2), 2, 2)
                }
            }
        }
        let img = ctx.makeImage()
        spriteCache[cacheKey] = img
        return img
    }

    /// Weapon tint on the class sprite: blade, bowstring or staff orb take the element colour.
    static func classTint(_ cls: RpgClass, weapon: RpgItem?) -> [Character: CGColor] {
        guard let w = weapon, w.element != .base else { return [:] }
        let e = elem(w.element)
        switch cls {
        case .warrior: return ["B": e.mid]
        case .archer, .mage: return ["Y": e.mid]
        }
    }

    // MARK: icons

    private static let swordT: RpgGrid = [
        "..............KK", ".............KBK", "............KBEK", "...........KBEK.", "..........KBEK..", ".........KBEK...",
        "........KBEK....", ".......KBEK.....", "..KK..KBEK......", "..KGKKBEK.......", "...KGGEK........", "....KGGK........",
        "...KHKKGK.......", "..KHK..KGK......", ".KJK....KK......", ".KK.............",
    ]
    private static let bowT: RpgGrid = [
        "....KK..........", "...KWBK.........", "...KW.KBK.......", "...KW..KBK......", "...KW...KBK.....", "...KW....KBK....",
        "...KW....KGK....", "...KW....KGK....", "...KW....KGK....", "...KW....KBK....", "...KW...KBK.....", "...KW..KBK......",
        "...KW.KBK.......", "...KWBK.........", "....KK..........", "................",
    ]
    private static let staffT: RpgGrid = [
        "..........KKK...", ".........KOOOK..", "........KOOJOOK.", "........KOOOOOK.", "........KOOOOOK.", ".........KOOOK..",
        "........KGKKK...", ".......KBK......", "......KBK.......", ".....KBK........", "....KBK.........", "...KBK..........",
        "..KBK...........", ".KHK............", ".KK.............", "................",
    ]
    private static let armorT: RpgGrid = [
        "................", "...KKK....KKK...", "..KBBBKKKKBBBK..", ".KBBBBBEEBBBBBK.", ".KBBKBBBBBBKBBK.", ".KBK.KBBBBK.KBK.",
        ".KK..KBBBBK..KK.", ".....KBEEBK.....", ".....KBBBBK.....", ".....KBBBBK.....", ".....KEBBEK.....", ".....KBBBBK.....",
        ".....KKKKKK.....", "................", "................", "................",
    ]
    private static let potionT: RpgGrid = [
        "................", "......KKKK......", "......KCCK......", "......KCCK......", ".....KKBBKK.....", "....KBBBBBBK....",
        "...KBWBBBBBBK...", "...KBWBBBBBBK...", "...KBBBBBBBBK...", "...KEBBBBBBEK...", "....KEEEEEEK....", ".....KKKKKK.....",
        "................", "................", "................", "................",
    ]
    private static let scrollT: RpgGrid = [
        "................", "................", "...KKKKKKKKKK...", "..KCCCCCCCCCCK..", "..KcKKKKKKKKcK..", "...KCCCCCCCCK...",
        "...KCKKKKKKCK...", "...KCCCCCCCCK...", "...KCKKKKKKCK...", "...KCCCCCCCCK...", "..KcKKKKKKKKcK..", "..KCCCCCCCCCCK..",
        "...KKKKKKKKKK...", "................", "................", "................",
    ]
    private static let bookT: RpgGrid = [
        "................", "...KKKKKKKKKK...", "..KBBBBBBBBBBK..", "..KBEEEEEEEEBK..", "..KBEWWWWWWEBK..", "..KBEWJJJJWEBK..",
        "..KBEWJWWJWEBK..", "..KBEWJJJJWEBK..", "..KBEWWWWWWEBK..", "..KBEEEEEEEEBK..", "..KBBBBBBBBBBK..", "..KCCCCCCCCCCK..",
        "..KcccccccccccK.", "...KKKKKKKKKKK..", "................", "................",
    ]
    private static let ringT: RpgGrid = [
        "................", "......KKKK......", ".....KJWWJK.....", ".....KJJJJK.....", "......KKKK......", "....KKKBBKKK....",
        "...KBBKKKKBBK...", "..KBBKK..KKBBK..", "..KBK......KBK..", "..KBK......KBK..", "..KBBK....KBBK..", "...KBBKKKKBBK...",
        "....KKBBBBKK....", ".....KKKKKK.....", "................", "................",
    ]
    private static let helmetT: RpgGrid = [
        "................", "................", ".....KKKKKK.....", "....KBBBBBBK....", "...KBBJBBJBBK...", "..KBBBBBBBBBBK..",
        "..KBBBBBBBBBBK..", "..KBBKKKKKKBBK..", "..KBK......KBK..", "..KBK......KBK..", "..KKK......KKK..", "................",
        "................", "................", "................", "................",
    ]
    private static let bootsT: RpgGrid = [
        "................", "................", "................", "....KKKK........", "...KBBBBK.......", "...KBJBBK.......",
        "...KBBBBK.......", "...KBBBBKKKK....", "...KBBBBBBBBK...", "..KBBBBBBBBBBK..", "..KKKKKKKKKKKK..", "................",
        "................", "................", "................", "................",
    ]
    private static let amuletT: RpgGrid = [
        "................", "..K..........K..", "..KB........BK..", "...KB......BK...", "....KB....BK....", ".....KB..BK.....",
        "......KBBK......", ".....KKKKKK.....", "....KBBBBBBK....", "...KBBJWWJBBK...", "...KBBJJJJBBK...", "...KBBBBBBBBK...",
        "....KBBBBBBK....", ".....KKKKKK.....", "................", "................",
    ]
    private static let stoneT: RpgGrid = [
        "................", "................", "......KKKK......", ".....KBWBBK.....", "....KBWBBBEK....", "...KBBBBBBBEK...",
        "..KBBBBBBBBBEK..", "..KEBBBBBBBEEK..", "...KEBBBBBEEK...", "....KEEBBEEK....", ".....KEEEEK.....", "......KKKK......",
        "................", "................", "................", "................",
    ]

    private static func itemColors(_ item: RpgItem) -> [Character: CGColor] {
        switch item.kind {
        case .weapon(let cls):
            let swords: [[Character: CGColor]] = [
                ["B": rgb(196, 150, 96), "E": rgb(140, 96, 56), "G": rgb(120, 80, 44), "H": rgb(96, 64, 36), "J": rgb(150, 110, 70)],
                ["B": rgb(230, 236, 246), "E": rgb(150, 162, 186), "G": rgb(120, 130, 150), "H": rgb(110, 70, 40), "J": rgb(90, 150, 240)],
                ["B": rgb(255, 214, 90), "E": rgb(236, 86, 30), "G": rgb(160, 40, 30), "H": rgb(70, 40, 30), "J": rgb(255, 120, 40)],
                ["B": rgb(220, 250, 255), "E": rgb(80, 170, 240), "G": rgb(60, 110, 190), "H": rgb(40, 60, 110), "J": rgb(170, 238, 255)],
                ["B": rgb(255, 246, 170), "E": rgb(236, 170, 30), "G": rgb(70, 70, 90), "H": rgb(40, 40, 56), "J": rgb(255, 232, 80)],
                ["B": rgb(255, 255, 255), "E": rgb(236, 190, 60), "G": rgb(240, 200, 70), "H": rgb(70, 90, 200), "J": rgb(120, 220, 255)],
                ["B": rgb(240, 226, 180), "E": rgb(190, 160, 90), "G": rgb(60, 150, 120), "H": rgb(90, 60, 40), "J": rgb(90, 230, 180)],
                ["B": rgb(255, 160, 70), "E": rgb(170, 40, 20), "G": rgb(60, 30, 30), "H": rgb(40, 20, 20), "J": rgb(255, 230, 90)],
                ["B": rgb(250, 240, 255), "E": rgb(170, 90, 240), "G": rgb(60, 20, 70), "H": rgb(30, 10, 40), "J": rgb(255, 60, 120)],
            ]
            let bows: [[Character: CGColor]] = [
                ["B": rgb(170, 116, 64), "G": rgb(110, 70, 40), "W": rgb(240, 240, 230)],
                ["B": rgb(170, 180, 200), "G": rgb(90, 60, 40), "W": rgb(240, 240, 230)],
                ["B": rgb(236, 96, 40), "G": rgb(120, 40, 30), "W": rgb(255, 220, 90)],
                ["B": rgb(110, 190, 250), "G": rgb(50, 90, 160), "W": rgb(220, 250, 255)],
                ["B": rgb(90, 200, 120), "G": rgb(40, 110, 70), "W": rgb(220, 255, 230)],
                ["B": rgb(250, 220, 110), "G": rgb(70, 90, 200), "W": rgb(255, 255, 255)],
                ["B": rgb(214, 180, 110), "G": rgb(120, 90, 50), "W": rgb(150, 240, 200)],
                ["B": rgb(170, 230, 255), "G": rgb(60, 120, 190), "W": rgb(255, 255, 255)],
                ["B": rgb(60, 40, 110), "G": rgb(240, 200, 80), "W": rgb(200, 150, 255)],
            ]
            let staffs: [[Character: CGColor]] = [
                ["B": rgb(170, 116, 64), "G": rgb(110, 70, 40), "H": rgb(90, 60, 36), "O": rgb(150, 220, 120), "J": rgb(230, 255, 220)],
                ["B": rgb(150, 110, 80), "G": rgb(180, 190, 210), "H": rgb(90, 60, 36), "O": rgb(150, 200, 255), "J": rgb(255, 255, 255)],
                ["B": rgb(120, 50, 40), "G": rgb(240, 190, 60), "H": rgb(70, 30, 26), "O": rgb(255, 120, 40), "J": rgb(255, 240, 160)],
                ["B": rgb(80, 110, 170), "G": rgb(200, 230, 255), "H": rgb(40, 60, 110), "O": rgb(120, 220, 255), "J": rgb(255, 255, 255)],
                ["B": rgb(70, 70, 96), "G": rgb(240, 200, 60), "H": rgb(40, 40, 56), "O": rgb(255, 232, 80), "J": rgb(255, 255, 230)],
                ["B": rgb(60, 40, 110), "G": rgb(240, 200, 80), "H": rgb(30, 20, 60), "O": rgb(170, 110, 255), "J": rgb(120, 230, 255)],
                ["B": rgb(200, 230, 250), "G": rgb(120, 180, 230), "H": rgb(80, 120, 170), "O": rgb(200, 245, 255), "J": rgb(255, 255, 255)],
                ["B": rgb(60, 30, 30), "G": rgb(255, 130, 40), "H": rgb(30, 14, 14), "O": rgb(255, 80, 30), "J": rgb(255, 230, 120)],
                ["B": rgb(40, 10, 40), "G": rgb(255, 60, 120), "H": rgb(20, 6, 20), "O": rgb(120, 30, 160), "J": rgb(255, 140, 240)],
            ]
            let table = cls == .warrior ? swords : (cls == .archer ? bows : staffs)
            return table[min(item.tier, table.count - 1)]
        case .armor:
            let tones: [(CGColor, CGColor)] = [
                (rgb(220, 210, 180), rgb(170, 160, 130)), (rgb(170, 116, 64), rgb(120, 80, 44)), (rgb(180, 190, 206), rgb(120, 130, 150)),
                (rgb(170, 230, 255), rgb(90, 160, 220)), (rgb(220, 70, 60), rgb(240, 190, 60)), (rgb(220, 190, 120), rgb(60, 150, 120)),
                (rgb(220, 245, 255), rgb(80, 150, 230)), (rgb(70, 30, 70), rgb(255, 60, 120)),
            ]
            let t = tones[min(item.tier, tones.count - 1)]
            return ["B": t.0, "E": t.1]
        case .potionHP:
            switch item.id {
            case "hp1": return ["B": rgb(255, 150, 50), "E": rgb(200, 90, 30)]
            case "hp2": return ["B": rgb(250, 250, 250), "E": rgb(190, 200, 214)]
            case "hp3": return ["B": rgb(255, 210, 60), "E": rgb(220, 120, 30)]
            default: return ["B": rgb(230, 60, 60), "E": rgb(160, 30, 40)]
            }
        case .potionMP:
            return item.id == "mp1" ? ["B": rgb(170, 110, 255), "E": rgb(110, 60, 200)] : ["B": rgb(80, 140, 255), "E": rgb(40, 80, 190)]
        case .scroll:
            return [:]
        case .book(let skill):
            let cls = RpgSkills.def(skill)?.cls ?? .warrior
            let cover: (CGColor, CGColor) = switch cls {
            case .warrior: (rgb(190, 60, 50), rgb(120, 30, 30))
            case .archer: (rgb(60, 150, 80), rgb(30, 90, 50))
            case .mage: (rgb(110, 70, 190), rgb(60, 36, 120))
            }
            return ["B": cover.0, "E": cover.1, "J": rgb(240, 200, 70)]
        case .stone:
            return ["B": rgb(120, 220, 255), "E": rgb(50, 120, 200)]
        case .ring, .amulet, .helmet, .boots:
            // Metal by tier, with a gem.
            let metals = [rgb(190, 120, 70), rgb(205, 210, 222), rgb(240, 200, 80), rgb(220, 230, 255), rgb(255, 150, 60), rgb(170, 225, 255), rgb(70, 40, 80), rgb(255, 240, 150)]
            let gems = [rgb(120, 200, 110), rgb(120, 170, 255), rgb(235, 60, 70), rgb(60, 110, 235), rgb(255, 110, 40), rgb(120, 230, 255), rgb(255, 60, 150), rgb(255, 255, 255)]
            let t = min(item.tier, 7)
            return ["B": metals[t], "J": gems[t], "W": rgb(255, 255, 255)]
        case .material:
            let tones: [String: (CGColor, CGColor)] = [
                "mat_jelly": (rgb(130, 230, 120), rgb(60, 160, 70)), "mat_hide": (rgb(176, 126, 80), rgb(110, 70, 40)),
                "mat_bone": (rgb(236, 230, 210), rgb(170, 160, 140)), "mat_sting": (rgb(230, 190, 90), rgb(160, 110, 40)),
                "mat_ice": (rgb(200, 240, 255), rgb(100, 170, 230)), "mat_magma": (rgb(255, 130, 50), rgb(170, 50, 20)),
                "mat_dark": (rgb(150, 90, 200), rgb(70, 30, 110)), "mat_wraith": (rgb(150, 240, 240), rgb(60, 150, 170)),
            ]
            let tone = tones[item.id] ?? (rgb(200, 200, 200), rgb(120, 120, 120))
            return ["B": tone.0, "E": tone.1]
        case .buff(let id):
            let tones: [String: (CGColor, CGColor)] = [
                "atk": (rgb(255, 110, 80), rgb(170, 50, 40)), "xp": (rgb(255, 225, 110), rgb(200, 150, 40)),
                "luck": (rgb(120, 230, 150), rgb(50, 150, 90)), "speed": (rgb(130, 200, 255), rgb(60, 120, 210)),
            ]
            let tone = tones[id] ?? (rgb(200, 200, 200), rgb(120, 120, 120))
            return ["B": tone.0, "E": tone.1]
        }
    }

    private static var iconCache: [String: CGImage] = [:]

    /// 16×16 item icon with a rarity aura for epic and better gear.
    static func icon(_ item: RpgItem) -> CGImage? {
        if let img = iconCache[item.id] { return img }
        let template: RpgGrid
        switch item.kind {
        case .weapon(let cls): template = cls == .warrior ? swordT : (cls == .archer ? bowT : staffT)
        case .armor: template = armorT
        case .potionHP, .potionMP: template = potionT
        case .scroll: template = scrollT
        case .book: template = bookT
        case .stone, .material: template = stoneT
        case .ring: template = ringT
        case .amulet: template = amuletT
        case .buff: template = potionT
        case .helmet: template = helmetT
        case .boots: template = bootsT
        }
        let colors = palette.merging(itemColors(item)) { _, new in new }
        guard let ctx = KartArt.context(width: 18, height: 18) else { return nil }
        if item.rarity >= 2, item.isEquipment {
            let glowColor = item.rarity == 4 ? rgb(255, 90, 140) : elem(item.element == .base ? .holy : item.element).mid
            let glow = glowColor.copy(alpha: item.rarity >= 3 ? 0.6 : 0.38) ?? outline
            for (row, line) in template.enumerated() {
                for (col, ch) in line.enumerated() where ch != "." {
                    for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                        let nx = col + dx, ny = row + dy
                        let outside = ny < 0 || ny >= template.count || nx < 0 || nx >= line.count || Array(template[ny])[nx] == "."
                        if outside { KartArt.fill(ctx, glow, CGFloat(1 + nx), CGFloat(1 + ny), 1, 1) }
                    }
                }
            }
        }
        for (row, line) in template.enumerated() {
            for (col, ch) in line.enumerated() {
                guard let c = colors[ch] else { continue }
                KartArt.fill(ctx, c, CGFloat(1 + col), CGFloat(1 + row), 1, 1)
            }
        }
        let img = ctx.makeImage()
        iconCache[item.id] = img
        return img
    }

    static let rarityColors: [NSColor] = [
        NSColor(white: 0.8, alpha: 1), NSColor(red: 0.45, green: 0.68, blue: 1, alpha: 1), NSColor(red: 0.78, green: 0.52, blue: 1, alpha: 1),
        NSColor(red: 1, green: 0.68, blue: 0.2, alpha: 1), NSColor(red: 1, green: 0.38, blue: 0.55, alpha: 1),
    ]

    // MARK: tiles

    private static func ground(_ kind: RpgMapKind, zone: RpgMapKind?) -> (CGColor, CGColor, CGColor) {
        switch zone ?? kind {
        case .desert: return (rgb(226, 196, 132), rgb(206, 174, 112), rgb(240, 214, 150))
        case .snow: return (rgb(232, 240, 250), rgb(204, 218, 236), rgb(250, 252, 255))
        case .volcano: return (rgb(70, 56, 56), rgb(52, 40, 40), rgb(96, 74, 70))
        case .castle: return (rgb(70, 64, 86), rgb(54, 48, 68), rgb(90, 84, 108))
        default: return (rgb(80, 72, 66), rgb(66, 58, 54), rgb(98, 88, 80))
        }
    }

    static func renderMap(_ map: RpgMap) -> CGImage? {
        let size = map.pixelSize
        guard let ctx = KartArt.context(width: Int(size.width), height: Int(size.height)) else { return nil }
        var rng = KartRNG(seed: map.def.seed &+ 99)
        let fill = KartArt.fill
        func speckle(_ px: CGFloat, _ py: CGFloat, _ n: Int, _ a: CGColor, _ b: CGColor) {
            for _ in 0..<n { fill(ctx, rng.int(2) == 0 ? a : b, px + CGFloat(rng.int(16)), py + CGFloat(rng.int(16)), 1, 1) }
        }
        let g = ground(map.def.kind, zone: map.def.zone)
        for y in 0..<map.height {
            for x in 0..<map.width {
                let px = CGFloat(x * 16), py = CGFloat(y * 16)
                let t = map.at(x, y)
                switch t {
                case .grass, .flower, .darkGrass:
                    let dark = t == .darkGrass
                    fill(ctx, dark ? rgb(70, 140, 66) : rgb(104, 180, 84), px, py, 16, 16)
                    speckle(px, py, 10, dark ? rgb(58, 120, 56) : rgb(88, 160, 72), dark ? rgb(88, 160, 78) : rgb(128, 200, 100))
                    if rng.int(5) == 0 { let tx = px + CGFloat(rng.int(13)), ty = py + CGFloat(rng.int(13)); fill(ctx, rgb(60, 130, 56), tx, ty, 1, 2); fill(ctx, rgb(60, 130, 56), tx + 2, ty, 1, 2) }
                    if t == .flower {
                        let colors = [rgb(255, 255, 255), rgb(255, 120, 160), rgb(255, 220, 60), rgb(170, 140, 255)]
                        for _ in 0..<3 {
                            let fx = px + 2 + CGFloat(rng.int(12)), fy = py + 2 + CGFloat(rng.int(12))
                            fill(ctx, colors[rng.int(colors.count)], fx - 1, fy, 1, 1); fill(ctx, colors[rng.int(colors.count)], fx + 1, fy, 1, 1)
                            fill(ctx, rgb(255, 240, 120), fx, fy, 1, 1)
                        }
                    }
                case .path:
                    let snowy = map.def.kind == .snow
                    fill(ctx, snowy ? rgb(196, 206, 222) : rgb(206, 176, 124), px, py, 16, 16)
                    speckle(px, py, 8, snowy ? rgb(176, 188, 206) : rgb(184, 152, 104), snowy ? rgb(214, 222, 236) : rgb(222, 196, 146))
                case .sand, .dune:
                    fill(ctx, rgb(230, 204, 146), px, py, 16, 16)
                    speckle(px, py, 8, rgb(214, 184, 124), rgb(244, 222, 168))
                    if t == .dune {
                        for k in 0..<10 { fill(ctx, rgb(206, 174, 112), px + CGFloat(k + 3), py + 8 + CGFloat(Int(sin(Double(k) * 0.7) * 2)), 1, 1) }
                    }
                case .stone:
                    fill(ctx, rgb(190, 178, 158), px, py, 16, 16)
                    fill(ctx, rgb(166, 154, 136), px, py, 16, 1); fill(ctx, rgb(166, 154, 136), px, py, 1, 16)
                    fill(ctx, rgb(166, 154, 136), px, py + 8, 16, 1); fill(ctx, rgb(166, 154, 136), px + CGFloat((y % 2) * 8), py, 1, 8)
                case .snow:
                    fill(ctx, rgb(236, 242, 250), px, py, 16, 16)
                    speckle(px, py, 6, rgb(210, 222, 238), rgb(255, 255, 255))
                case .ash:
                    fill(ctx, rgb(74, 60, 58), px, py, 16, 16)
                    speckle(px, py, 8, rgb(56, 44, 44), rgb(96, 78, 72))
                    if rng.int(7) == 0 { fill(ctx, rgb(255, 120, 40), px + CGFloat(rng.int(14)), py + CGFloat(rng.int(14)), 1, 1) }
                case .castleFloor, .carpet:
                    fill(ctx, rgb(78, 72, 94), px, py, 16, 16)
                    fill(ctx, rgb(62, 56, 78), px, py, 16, 1); fill(ctx, rgb(62, 56, 78), px, py, 1, 16)
                    if t == .carpet {
                        fill(ctx, rgb(140, 30, 50), px, py, 16, 16)
                        fill(ctx, rgb(200, 160, 60), px, py + 1, 16, 1); fill(ctx, rgb(200, 160, 60), px, py + 14, 16, 1)
                        speckle(px, py, 4, rgb(120, 24, 40), rgb(160, 40, 60))
                    }
                case .tree, .pine, .cactus:
                    let base: CGColor = switch map.def.kind {
                    case .forest: rgb(70, 140, 66)
                    case .snow: rgb(236, 242, 250)
                    case .desert: rgb(230, 204, 146)
                    default: rgb(104, 180, 84)
                    }
                    fill(ctx, base, px, py, 16, 16)
                    fill(ctx, rgb(0, 0, 0, 0.2), px + 2, py + 12, 12, 3)
                    if t == .cactus {
                        fill(ctx, outline, px + 6, py + 2, 5, 13); fill(ctx, rgb(70, 160, 80), px + 7, py + 3, 3, 12)
                        fill(ctx, outline, px + 2, py + 5, 5, 5); fill(ctx, rgb(70, 160, 80), px + 3, py + 6, 3, 3)
                        fill(ctx, outline, px + 10, py + 7, 5, 4); fill(ctx, rgb(70, 160, 80), px + 11, py + 8, 3, 2)
                        fill(ctx, rgb(130, 210, 120), px + 8, py + 4, 1, 8)
                    } else if t == .pine {
                        fill(ctx, rgb(104, 66, 36), px + 7, py + 11, 3, 4)
                        for r in 0..<11 { let w = CGFloat(2 + r); fill(ctx, r % 4 == 0 ? rgb(240, 248, 255) : rgb(40, 100, 70), px + 8 - w / 2, py + CGFloat(r), w, 1) }
                    } else {
                        fill(ctx, rgb(104, 66, 36), px + 7, py + 9, 3, 6)
                        ctx.setFillColor(outline); ctx.fillEllipse(in: CGRect(x: px, y: py - 1, width: 16, height: 13))
                        ctx.setFillColor(map.def.kind == .forest ? rgb(36, 100, 50) : rgb(46, 120, 56)); ctx.fillEllipse(in: CGRect(x: px + 1, y: py, width: 14, height: 11))
                        ctx.setFillColor(map.def.kind == .forest ? rgb(60, 136, 66) : rgb(80, 160, 76)); ctx.fillEllipse(in: CGRect(x: px + 3, y: py + 1, width: 7, height: 5))
                    }
                case .water:
                    fill(ctx, rgb(70, 140, 220), px, py, 16, 16)
                    for _ in 0..<2 { fill(ctx, rgb(170, 220, 255), px + CGFloat(rng.int(12)), py + CGFloat(rng.int(15)), CGFloat(2 + rng.int(3)), 1) }
                case .lava:
                    fill(ctx, rgb(220, 70, 20), px, py, 16, 16)
                    for _ in 0..<3 { fill(ctx, rgb(255, 180, 60), px + CGFloat(rng.int(12)), py + CGFloat(rng.int(15)), CGFloat(2 + rng.int(3)), 1) }
                    if rng.int(3) == 0 { fill(ctx, rgb(255, 240, 150), px + CGFloat(rng.int(14)), py + CGFloat(rng.int(14)), 2, 1) }
                case .rock, .iceRock:
                    let base: CGColor = switch map.def.kind {
                    case .forest: rgb(70, 140, 66)
                    case .snow: rgb(236, 242, 250)
                    case .desert: rgb(230, 204, 146)
                    case .volcano: rgb(74, 60, 58)
                    default: rgb(104, 180, 84)
                    }
                    fill(ctx, base, px, py, 16, 16)
                    let ice = t == .iceRock
                    ctx.setFillColor(outline); ctx.fillEllipse(in: CGRect(x: px + 1, y: py + 3, width: 14, height: 12))
                    ctx.setFillColor(ice ? rgb(150, 210, 240) : (map.def.kind == .volcano ? rgb(60, 50, 50) : rgb(150, 146, 140)))
                    ctx.fillEllipse(in: CGRect(x: px + 2, y: py + 4, width: 12, height: 10))
                    fill(ctx, ice ? rgb(230, 250, 255) : rgb(190, 186, 180), px + 5, py + 6, 4, 2)
                case .caveFloor, .torch, .bossFloor:
                    fill(ctx, g.0, px, py, 16, 16)
                    speckle(px, py, 7, g.1, g.2)
                    if rng.int(6) == 0 { fill(ctx, g.2, px + CGFloat(rng.int(13)), py + CGFloat(rng.int(13)), 2, 2) }
                    if t == .torch {
                        fill(ctx, rgb(100, 70, 40), px + 7, py + 4, 2, 9)
                        fill(ctx, outline, px + 6, py + 3, 4, 2)
                    }
                case .caveWall, .castleWall:
                    let castle = t == .castleWall || map.def.zone == .castle
                    fill(ctx, castle ? rgb(36, 32, 50) : rgb(40, 34, 40), px, py, 16, 16)
                    if !map.at(x, y + 1).blocks {
                        fill(ctx, castle ? rgb(90, 84, 112) : rgb(96, 84, 82), px, py + 8, 16, 8)
                        fill(ctx, castle ? rgb(120, 112, 140) : rgb(120, 108, 100), px, py + 8, 16, 2)
                        for bx in stride(from: 0, to: 16, by: castle ? 8 : 5) { fill(ctx, castle ? rgb(70, 64, 90) : rgb(70, 62, 60), px + CGFloat(bx + (y % 2) * 3), py + 11, 1, 5) }
                    }
                    for _ in 0..<3 { fill(ctx, castle ? rgb(50, 44, 66) : rgb(56, 48, 56), px + CGFloat(rng.int(15)), py + CGFloat(rng.int(8)), 2, 1) }
                case .pillar:
                    fill(ctx, rgb(78, 72, 94), px, py, 16, 16)
                    fill(ctx, rgb(0, 0, 0, 0.3), px + 2, py + 12, 12, 3)
                    fill(ctx, outline, px + 3, py - 6, 10, 20)
                    fill(ctx, rgb(150, 140, 170), px + 4, py - 5, 8, 18)
                    fill(ctx, rgb(190, 180, 210), px + 5, py - 5, 2, 18)
                    fill(ctx, rgb(110, 100, 130), px + 3, py - 7, 10, 2)
                case .fountain:
                    fill(ctx, rgb(190, 178, 158), px, py, 16, 16)
                }
            }
        }
        if map.def.kind == .town {
            let fx: CGFloat = 15 * 16, fy: CGFloat = 12 * 16
            ctx.setFillColor(outline); ctx.fillEllipse(in: CGRect(x: fx - 1, y: fy + 3, width: 34, height: 28))
            ctx.setFillColor(rgb(150, 150, 160)); ctx.fillEllipse(in: CGRect(x: fx, y: fy + 4, width: 32, height: 26))
            ctx.setFillColor(rgb(90, 170, 240)); ctx.fillEllipse(in: CGRect(x: fx + 3, y: fy + 7, width: 26, height: 20))
            fill(ctx, rgb(150, 150, 160), fx + 15, fy - 2, 3, 14)
            fill(ctx, rgb(200, 240, 255), fx + 13, fy - 5, 7, 3)
            for b in map.buildings { building(ctx, b) }
        }
        return ctx.makeImage()
    }

    private static func building(_ ctx: CGContext, _ b: RpgBuilding) {
        let fill = KartArt.fill
        let x = CGFloat(b.x * 16), y = CGFloat(b.y * 16), w = CGFloat(b.w * 16), h = CGFloat(b.h * 16)
        if b.place == .board {
            // A wooden notice board with pinned papers.
            fill(ctx, rgb(0, 0, 0, 0.25), x + 4, y + h - 2, w - 6, 4)
            fill(ctx, outline, x + 6, y + 10, 3, h - 10); fill(ctx, outline, x + w - 9, y + 10, 3, h - 10)
            fill(ctx, rgb(110, 70, 40), x + 7, y + 10, 1, h - 10); fill(ctx, rgb(110, 70, 40), x + w - 8, y + 10, 1, h - 10)
            fill(ctx, outline, x + 2, y + 2, w - 4, 20); fill(ctx, rgb(170, 120, 70), x + 3, y + 3, w - 6, 18)
            for (k, px) in [x + 6, x + 18, x + 30].enumerated() {
                fill(ctx, rgb(244, 232, 200), px, y + 5 + CGFloat(k % 2), 9, 12)
                fill(ctx, rgb(200, 60, 60), px + 4, y + 5 + CGFloat(k % 2), 1, 1)
                for l in 0..<3 { fill(ctx, rgb(150, 140, 120), px + 1, y + 8 + CGFloat(l * 3 + k % 2), 7, 1) }
            }
            return
        }
        let roof: (CGColor, CGColor) = switch b.place {
        case .shop(.weapon): (rgb(70, 110, 200), rgb(50, 80, 160))
        case .shop(.armor): (rgb(200, 70, 60), rgb(150, 50, 44))
        case .shop(.potion): (rgb(80, 160, 90), rgb(56, 120, 66))
        case .shop(.skill): (rgb(120, 70, 190), rgb(84, 46, 140))
        case .jobMaster: (rgb(214, 170, 60), rgb(168, 126, 36))
        default: (rgb(110, 110, 120), rgb(80, 80, 90))
        }
        let roofH = h * 0.45
        fill(ctx, rgb(0, 0, 0, 0.25), x + 4, y + h - 2, w, 5)
        fill(ctx, outline, x + 3, y + roofH - 1, w - 6, h - roofH + 1)
        let wall = b.place == .smith ? rgb(170, 150, 130) : rgb(240, 226, 196)
        fill(ctx, wall, x + 4, y + roofH, w - 8, h - roofH - 1)
        let rows = Int(roofH)
        for r in 0..<rows {
            let inset = CGFloat(rows - r) * 0.5
            fill(ctx, r % 4 == 3 ? roof.1 : roof.0, x + inset, y + CGFloat(r), w - inset * 2, 1)
        }
        fill(ctx, outline, x, y + roofH - 1, w, 1)
        let dx = x + w / 2 - 6
        fill(ctx, outline, dx, y + h - 17, 12, 17); fill(ctx, rgb(140, 90, 50), dx + 1, y + h - 16, 10, 16)
        fill(ctx, rgb(240, 190, 50), dx + 8, y + h - 9, 1, 1)
        for wx in [x + 8, x + w - 20] {
            fill(ctx, outline, wx, y + roofH + 5, 12, 10)
            fill(ctx, b.place == .smith ? rgb(255, 150, 60) : rgb(140, 210, 255), wx + 1, y + roofH + 6, 10, 8)
        }
        if b.place == .smith {
            // Chimney with a glow.
            fill(ctx, outline, x + w - 16, y - 6, 8, 14); fill(ctx, rgb(120, 100, 90), x + w - 15, y - 5, 6, 12)
        }
        let sx = x + w / 2 - 9, sy = y + 4
        fill(ctx, outline, sx, sy, 18, 13); fill(ctx, rgb(170, 120, 70), sx + 1, sy + 1, 16, 11)
        let sample: RpgItem? = switch b.place {
        case .shop(.weapon): RpgItems.item("sword1")
        case .shop(.armor): RpgItems.item("armor2")
        case .shop(.potion): RpgItems.item("hp0")
        case .shop(.skill): RpgItems.item("book_m_blink")
        default: RpgItems.item("stone")
        }
        if let s = sample, let ic = icon(s) { KartArt.draw(ic, in: ctx, rect: CGRect(x: sx + 4, y: sy + 1, width: 10, height: 10)) }
    }

    // MARK: portals & pickups

    static func portal(_ ctx: CGContext, at p: CGPoint, time: Double, locked: Bool, waypoint: Bool = false) {
        let base: (CGColor, CGColor, CGColor) = locked
            ? (rgb(120, 60, 60), rgb(200, 90, 90), rgb(255, 180, 180))
            : (waypoint ? (rgb(150, 90, 30), rgb(255, 200, 80), rgb(255, 250, 210)) : (rgb(60, 80, 200), rgb(120, 170, 255), rgb(220, 240, 255)))
        ctx.setFillColor(rgb(0, 0, 0, 0.3)); ctx.fillEllipse(in: CGRect(x: p.x - 9, y: p.y + 2, width: 18, height: 6))
        ctx.setFillColor(base.0); ctx.fillEllipse(in: CGRect(x: p.x - 8, y: p.y - 18, width: 16, height: 22))
        ctx.setFillColor(base.1); ctx.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 16, width: 12, height: 18))
        for k in 0..<6 {
            let a = time * 3 + Double(k) * .pi / 3
            let r = 4.5 + sin(time * 2 + Double(k)) * 1.5
            KartArt.fill(ctx, base.2, (p.x + cos(a) * r).rounded(), (p.y - 7 + sin(a) * r * 1.4).rounded(), 1, 1)
        }
        ctx.setFillColor(base.2.copy(alpha: 0.7) ?? base.2); ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 10, width: 4, height: 6))
    }

    static func coin(_ ctx: CGContext, at p: CGPoint, time: Double) {
        let bob = (sin(time * 5) * 1.5).rounded()
        KartArt.fill(ctx, rgb(0, 0, 0, 0.25), p.x - 3, p.y + 2, 6, 2)
        KartArt.fill(ctx, outline, p.x - 3, p.y - 6 + bob, 6, 7)
        KartArt.fill(ctx, rgb(255, 210, 60), p.x - 2, p.y - 5 + bob, 4, 5)
        KartArt.fill(ctx, rgb(255, 250, 190), p.x - 1, p.y - 5 + bob, 1, 2)
    }

    static func trap(_ ctx: CGContext, at p: CGPoint, time: Double) {
        let blink = Int(time * 4) % 2 == 0
        KartArt.fill(ctx, outline, p.x - 5, p.y - 2, 10, 5)
        KartArt.fill(ctx, rgb(120, 120, 130), p.x - 4, p.y - 1, 8, 3)
        for k in 0..<4 { KartArt.fill(ctx, rgb(200, 200, 210), p.x - 4 + CGFloat(k * 2), p.y - 3, 1, 2) }
        KartArt.fill(ctx, blink ? rgb(255, 80, 80) : rgb(120, 30, 30), p.x, p.y - 1, 1, 1)
    }

    // MARK: effects

    struct Elem { let core: CGColor, mid: CGColor, edge: CGColor, spark: CGColor }

    static func elem(_ e: RpgElement) -> Elem {
        switch e {
        case .base: return Elem(core: rgb(255, 255, 255), mid: rgb(214, 222, 236), edge: rgb(140, 150, 176), spark: rgb(255, 255, 255))
        case .fire: return Elem(core: rgb(255, 250, 200), mid: rgb(255, 196, 60), edge: rgb(236, 86, 30), spark: rgb(196, 40, 30))
        case .ice: return Elem(core: rgb(255, 255, 255), mid: rgb(170, 238, 255), edge: rgb(70, 166, 238), spark: rgb(220, 250, 255))
        case .thunder: return Elem(core: rgb(255, 255, 230), mid: rgb(255, 232, 80), edge: rgb(236, 166, 30), spark: rgb(255, 255, 255))
        case .wind: return Elem(core: rgb(240, 255, 240), mid: rgb(150, 240, 170), edge: rgb(56, 168, 100), spark: rgb(255, 255, 255))
        case .holy: return Elem(core: rgb(255, 255, 255), mid: rgb(255, 240, 170), edge: rgb(236, 186, 60), spark: rgb(255, 255, 255))
        case .cosmic: return Elem(core: rgb(255, 240, 255), mid: rgb(204, 140, 255), edge: rgb(110, 60, 200), spark: rgb(120, 220, 255))
        case .poison: return Elem(core: rgb(230, 255, 200), mid: rgb(150, 230, 80), edge: rgb(90, 150, 40), spark: rgb(200, 120, 255))
        }
    }

    static func dot(_ c: CGContext, _ x: Double, _ y: Double, _ color: CGColor, _ s: CGFloat = 1) {
        KartArt.fill(c, color, CGFloat(x.rounded()), CGFloat(y.rounded()), s, s)
    }

    static func ring(_ c: CGContext, _ cx: Double, _ cy: Double, _ r: Double, _ color: CGColor, squash: Double = 1) {
        var a = 0.0
        while a < .pi * 2 { dot(c, cx + cos(a) * r, cy + sin(a) * r * squash, color); a += 0.5 / max(r, 1) }
    }

    static func disc(_ c: CGContext, _ cx: Double, _ cy: Double, _ r: Double, _ color: CGColor, squash: Double = 1) {
        c.setFillColor(color)
        c.fillEllipse(in: CGRect(x: cx - r, y: cy - r * squash, width: r * 2, height: r * 2 * squash))
    }

    static func line(_ c: CGContext, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ color: CGColor) {
        let n = max(1, Int(max(abs(x1 - x0), abs(y1 - y0))))
        for i in 0...n { let t = Double(i) / Double(n); dot(c, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, color) }
    }

    static func star(_ c: CGContext, _ x: Double, _ y: Double, _ len: Int, _ color: CGColor, _ core: CGColor) {
        guard len > 0 else { return }
        for k in 1...len {
            let a = k == len ? color : core
            let d = Double(k)
            dot(c, x + d, y, a); dot(c, x - d, y, a); dot(c, x, y + d, a); dot(c, x, y - d, a)
            if k <= len / 2 { dot(c, x + d, y + d, color); dot(c, x - d, y - d, color); dot(c, x + d, y - d, color); dot(c, x - d, y + d, color) }
        }
        dot(c, x, y, core)
    }

    static func bolt(_ c: CGContext, from: CGPoint, to: CGPoint, seed: UInt64, _ e: Elem) {
        var r = KartRNG(seed: seed)
        var pts = [from]
        let n = max(3, Int(hypot(to.x - from.x, to.y - from.y) / 6))
        for i in 1..<n {
            let t = CGFloat(i) / CGFloat(n)
            pts.append(CGPoint(x: from.x + (to.x - from.x) * t + CGFloat(r.int(7) - 3), y: from.y + (to.y - from.y) * t + CGFloat(r.int(5) - 2)))
        }
        pts.append(to)
        for i in 0..<(pts.count - 1) {
            line(c, Double(pts[i].x) - 1, pts[i].y, Double(pts[i + 1].x) - 1, pts[i + 1].y, e.edge)
            line(c, Double(pts[i].x) + 1, pts[i].y, Double(pts[i + 1].x) + 1, pts[i + 1].y, e.mid)
            line(c, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, e.core)
        }
    }

    /// Weapon swing arc around the attacker, facing `angle`; frame 0…5.
    static func slash(_ c: CGContext, at p: CGPoint, angle: Double, frame k: Int, element: RpgElement, radius: Double = 11) {
        let e = elem(element)
        let start = angle - 1.6, end = angle + 1.4
        let head = [0.25, 0.55, 0.85, 1.0, 1.0, 1.0][min(5, k)], tail = [0.0, 0.0, 0.0, 0.35, 0.65, 0.92][min(5, k)]
        let cur = start + (end - start) * head, from = start + (end - start) * tail
        var a = from
        while a <= cur {
            let age = (cur - a) / (end - start)
            let thick = max(1, 4.5 * (1 - age * 1.3) * (k >= 4 ? 0.6 : 1))
            var r = radius
            while r < radius + thick {
                let color = age < 0.12 ? e.core : (age < 0.4 ? e.mid : e.edge)
                dot(c, p.x + cos(a) * r, p.y + sin(a) * r, r > radius + thick - 1 ? e.edge : color)
                r += 0.5
            }
            a += 0.025
        }
        var rnd = KartRNG(seed: UInt64(31 + k))
        switch element {
        case .fire where k >= 1:
            for i in 0..<10 {
                let aa = from + (cur - from) * Double(i) / 10
                dot(c, p.x + cos(aa) * (radius + 1 + Double(rnd.int(4))), p.y + sin(aa) * (radius + 1) - Double(k * 2 + i % 3),
                    [e.spark, e.edge, e.mid][i % 3], i % 4 == 0 ? 2 : 1)
            }
        case .ice where k >= 2:
            for i in 0..<6 {
                let aa = start + (end - start) * Double(i) / 5, d = radius + 2 + Double(k - 1) * 3
                let x = p.x + cos(aa) * d, y = p.y + sin(aa) * d
                dot(c, x, y - 1, e.core); dot(c, x - 1, y, e.mid); dot(c, x + 1, y, e.mid); dot(c, x, y + 1, e.edge)
            }
        case .holy where k >= 2:
            star(c, p.x + cos(angle) * (radius + 2), p.y + sin(angle) * (radius + 2), [0, 0, 3, 6, 7, 4][min(5, k)], e.mid, e.core)
        case .wind where k >= 1:
            for i in 0..<8 { let aa = from + (cur - from) * Double(i) / 8; dot(c, p.x + cos(aa) * (radius + 4), p.y + sin(aa) * (radius + 4), e.mid) }
        default:
            if k == 3 { star(c, p.x + cos(end) * radius, p.y + sin(end) * radius, 2, e.mid, e.core) }
        }
    }

    static func burst(_ c: CGContext, at p: CGPoint, frame k: Int, element: RpgElement, radius: Double) {
        let e = elem(element)
        let r = radius * [0.4, 0.75, 1.0, 1.1, 1.15, 1.2][min(5, k)]
        if k < 4 {
            disc(c, p.x, p.y, r, e.edge.copy(alpha: 0.55) ?? e.edge, squash: 0.6)
            disc(c, p.x, p.y, r * 0.6, e.mid.copy(alpha: 0.75) ?? e.mid, squash: 0.6)
            disc(c, p.x, p.y, r * 0.25, e.core, squash: 0.6)
        }
        ring(c, p.x, p.y, r + 1, k >= 4 ? e.edge : e.spark, squash: 0.6)
        var rnd = KartRNG(seed: UInt64(k * 3 + 1))
        for _ in 0..<10 {
            let a = Double(rnd.int(628)) / 100, d = r + Double(rnd.int(4))
            dot(c, p.x + cos(a) * d, p.y + sin(a) * d * 0.6 - Double(k), [e.spark, e.mid, e.edge][rnd.int(3)])
        }
    }

    static func iceSpikes(_ c: CGContext, at p: CGPoint, frame k: Int, radius: Double) {
        let e = elem(.ice)
        var rnd = KartRNG(seed: 77)
        for i in 0..<7 {
            let a = Double(i) / 7 * .pi * 2
            let x = p.x + cos(a) * radius * 0.6 * Double(rnd.int(100)) / 100, y = p.y + sin(a) * radius * 0.35 * Double(rnd.int(100)) / 100
            let grow = [0.2, 0.6, 1.0, 1.0, 0.8, 0.4][min(5, max(0, k - i % 2))]
            let h = 12 * grow
            guard h >= 1 else { continue }
            for yy in 0..<Int(h) {
                let w = max(0, 2.5 * (1 - Double(yy) / h))
                for dx in Int(-w)...Int(w) { dot(c, x + Double(dx), y - Double(yy), dx < 0 ? e.core : (dx == 0 ? e.mid : e.edge)) }
            }
        }
        ring(c, p.x, p.y, radius * 0.8 + Double(k), e.mid.copy(alpha: 0.6) ?? e.mid, squash: 0.4)
    }

    static func meteor(_ c: CGContext, at p: CGPoint, frame k: Int, radius: Double) {
        let e = elem(.cosmic), f = elem(.fire)
        if k < 3 {
            let t = Double(k) / 3
            let x = p.x + 24 * (1 - t), y = p.y - 40 * (1 - t)
            for i in 0..<10 { dot(c, x + Double(i), y - Double(i) * 1.6, i < 3 ? f.mid : (i < 6 ? e.mid : e.edge), i < 5 ? 2 : 1) }
            disc(c, x, y, 3.5, rgb(110, 80, 70)); disc(c, x - 0.5, y + 0.5, 2.2, rgb(150, 110, 90))
        } else {
            burst(c, at: p, frame: (k - 3) * 2, element: .cosmic, radius: radius)
            burst(c, at: p, frame: (k - 3) * 2 + 1, element: .fire, radius: radius * 0.6)
        }
    }

    /// Arrows dropping from the sky onto a circle.
    static func arrowRain(_ c: CGContext, at p: CGPoint, frame k: Int, radius: Double, seed: UInt64) {
        var r = KartRNG(seed: seed)
        let e = elem(.base)
        for _ in 0..<9 {
            let a = Double(r.int(628)) / 100, d = Double(r.int(Int(radius)))
            let x = p.x + cos(a) * d, y = p.y + sin(a) * d * 0.5
            let fall = Double(max(0, 4 - k)) * 6
            line(c, x, y - 8 - fall, x, y - fall, rgb(150, 100, 56))
            dot(c, x, y - fall, e.core)
            if k >= 4 { star(c, x, y, 1, e.mid, e.core) }
        }
        ring(c, p.x, p.y, radius, rgb(255, 255, 255, 0.4), squash: 0.5)
    }

    static func hitSpark(_ c: CGContext, at p: CGPoint, frame k: Int, crit: Bool, element: RpgElement) {
        let e = elem(crit ? .fire : element)
        let s = [2, 4, 5, 3][min(3, k)]
        star(c, p.x, p.y, s + (crit ? 2 : 0), e.mid, e.core)
        if crit, k >= 1 { ring(c, p.x, p.y, Double(k * 3 + 3), e.edge) }
    }

    static func levelUp(_ c: CGContext, at p: CGPoint, frame k: Int, element: RpgElement = .holy) {
        let e = elem(element)
        ring(c, p.x, p.y + 2, Double(5 + k * 2), e.mid, squash: 0.35)
        for i in 0..<6 {
            let x = p.x - 10 + Double(i) * 4, y = p.y - Double((k * 5 + i * 7) % 30)
            line(c, x, y, x, y + 3, i % 2 == 0 ? e.mid : e.edge)
            dot(c, x, y - 1, e.core)
        }
    }

    static func aura(_ c: CGContext, at p: CGPoint, time: Double, color: CGColor) {
        let r = 9 + sin(time * 6) * 1.5
        ring(c, p.x, p.y, r, color, squash: 0.4)
        for k in 0..<3 {
            let a = time * 4 + Double(k) * 2.1
            dot(c, p.x + cos(a) * r, p.y - 6 - Double((Int(time * 20) + k * 5) % 14), color)
        }
    }
}

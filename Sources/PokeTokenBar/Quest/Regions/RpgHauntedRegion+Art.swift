import CoreGraphics
import Foundation

// 유령 마을 sprites and item icons. New bodies face right (the view mirrors them when a monster walks left).

/// Paints single pixels over a grid (`RpgArt.overlay` is private to RpgArt.swift).
private func hauntMark(_ g: RpgGrid, _ marks: [(Int, Int, Character)]) -> RpgGrid {
    var rows = g.map { Array($0) }
    for (x, y, c) in marks where y < rows.count && x < rows[y].count { rows[y][x] = c }
    return rows.map { String($0) }
}

extension RpgArt {
    static let hauntedCrow: RpgGrid = [
        "................", "................", "................", "................",
        "........KKK.....", ".......KNNNK....", ".......KNRNKKK..", "....KK.KNNNKYYK.",
        "...KNNKKNNNKKK..", "..KNNNNNNNNK....", ".KNnNNNNNNNK....", "KnnnNNNNNNK.....",
        ".KKnnNNNNK......", "...KKKKKK.......", "....KY.KY.......", "....Y...Y.......",
    ]
    static let hauntedScarecrow: RpgGrid = [
        "......KKKK......", ".....KLLLLK.....", "....KLLLLLLK....", "..KKLLLLLLLLKK..",
        ".KLLLLLLLLLLLLK.", "..KKKCCCCCCKKK..", "....KCKCCKCK....", "....KCCCCCCK....",
        "....KCKKKKCK....", "KKKKKKCCCCKKKKKK", "YLLLLKRRRRKLLLLY", "KYKKKRRGRRRKKKYK",
        "....KRRRRRRK....", "....KKKLLKKK....", "......KLLK......", ".....KKKKKK.....",
    ]
    static let hauntedPumpkin: RpgGrid = [
        "................", "................", ".......KK.......", "......KGGK......",
        "...KKKKGKKKKK...", "..KFFQFFFFQFFK..", ".KFFQFFFFFFQFFK.", ".KFYYYFFFFYYYFK.",
        "KFFKYKFFFFKYKFFK", "KFFFFFFKKFFFFFFK", "KFQFFFFFFFFFFQFK", "KFFKYKYKYKYKYFFK",
        ".KFFKYYYYYYYKFK.", ".KFFQFKKKKKFQFK.", "..KKFFFFFFFFKK..", "....KKKKKKKK....",
    ]
    static let hauntedGhost: RpgGrid = [
        "................", "......KKKK......", "....KKWWWWKK....", "...KWWWWWWWWK...",
        "...KWWWWWWWWK...", "..KWWKKWWKKWWK..", "..KWWKKWWKKWWK..", ".KWWWWWWWWWWWWK.",
        ".KWWWWWKKWWWWWK.", ".KWWWWWKKWWWWWK.", ".KBBWWWWWWWWBBK.", ".KBBWWWWWWWWBBK.",
        ".KBBWWWWWWWWBBK.", ".KBBWKWWWWKWBBK.", "..KWK.KWWK.KWK..", "...K...KK...K...",
    ]
    static let hauntedCat: RpgGrid = [
        "................", "........KK..KK..", "........KNKKNK..", "........KNNNNNK.",
        "........KNYNNYK.", "........KNNPNNK.", ".........KNNNK..", "..KK....KNNNNK..",
        ".KNK...KNNNNNNK.", ".KNK..KNNNNNNNK.", ".KNK.KNNNNNNNNK.", "..KNKNNNNNNNNNK.",
        "...KNNNNNNNNNNK.", "...KNNNNNNNNNNK.", "....KNNKNNKNNNK.", ".....KK.KK.KKK..",
    ]
    static let hauntedCandle: RpgGrid = [
        "......KK........", ".....KFFK.......", "....KFYYFK......", "....KFYWYFK.....",
        "...KFYWWWYFK....", "...KFYKWKYFK....", "....KFYYYFK.....", ".....KFFFK......",
        "....KKKLKKK.....", "...KCCCCCCCK....", "...KCWCCCCCK....", "...KCWCCCCcK....",
        "...KCcCCCCcK....", "...KCCCCCcCK....", "..KKcCCCCCCKK...", "..KKKKKKKKKKK...",
    ]
    static let hauntedDoll: RpgGrid = [
        "................", "....KKKKKKK.....", "...KHHHHHHHK....", "..KHHHHHHHHHK...",
        "..KHSSSSSSSHK...", "..KHSKKSKKSHK...", "..KHSKKSKKSHK...", "..KHSSSSSSSHK...",
        "..KHSRKRKRSHK...", "...KKSSSSSKK....", "..KSKPPPPPKSK...", "..KSKPWPWPKSK...",
        "...KPPPPPPPK....", "..KPPPPPPPPPK...", "...KKSKKKSKK....", "....KK...KK.....",
    ]
    static let hauntedGhoul: RpgGrid = [
        "................", "................", "........KKKK....", ".......KSSSSK.K.",
        ".......KSRSRK.L.", "....KKKKSSSSK.L.", "...KAAAAKSSK..L.", "..KAAAAAAKKSK.L.",
        "..KAAAAAAKSSSSL.", "..KAAAaAAKKKK.L.", "...KAAaAAK....L.", "...KAAAAAK...KMK",
        "....KSKKSK...KMK", "....KSK.KSK..KMK", "...KSSK.KSSK.KMK", "...KKKK.KKKK..K.",
    ]
    static let hauntedWitch: RpgGrid = [
        ".........K......", "........KPK.....", ".......KPPK.....", "......KPPPK.....",
        ".....KPPPPPK....", "..KKKPPPPPPPKK..", ".KPPPPPPPPPPPPK.", "..KKHHSSSSSKK...",
        "....KHSSKSSK....", "....KHSSSSSSK...", ".....KSSSSKK....", "....KPPPPPPK....",
        "LLLLKPPPPPPKLLLL", "YYYKKPPPPPPKK...", "YYYY.KKK.KKK....", "YYY.............",
    ]
    static let hauntedToad: RpgGrid = [
        "................", "................", "................", "................",
        "................", "....KKK..KKK....", "...KGWGKKGWGK...", "...KGKGGGGKGK...",
        "..KKGGGGGGGGKK..", ".KGgGGGGgGGGGGK.", ".KGGGKKKKKKgGGK.", ".KGGGCCCCCCGGGK.",
        ".KgGCCCCCCCCGgK.", ".KGGCCCCCCCCGGK.", "..KKGCCCCCCGKK..", "....KKGGGGKK....",
    ]
    static let hauntedBats: RpgGrid = [
        "................", "K.......K.......", "KAK...KAK.......", "KAAK.KAAK.......",
        "KAAAAAAAK.......", ".KARAARK........", "..KWAWK..KK...KK", "...KKK...KAK.KAK",
        ".........KAAAAAK", "..........KRARK.", "...KK...KK.KKK..", "...KAK.KAK......",
        "...KAAAAAK......", "....KRARK.......", ".....KKK........", "................",
    ]
    static let hauntedRinger: RpgGrid = [
        "...........KK...", "..........KYYK..", ".........KYYYYK.", ".....KKK.KYyYYK.",
        "....KSSSKKYyYYK.", "...KSWKSKYYYYYYK", "..KKSSSSKKKSRKK.", ".KAAKKKKAAASK...",
        "KAAaAAAAAAASK...", "KAAAAAaAAAAK....", "KSKAAAAAAAAK....", "KSKAAaAAAAAK....",
        "KSKAAAAAAAK.....", ".KKKSSKKSSK.....", "...KSSK.KSSK....", "...KKKK.KKKK....",
    ]
    static let hauntedCountess: RpgGrid = [
        "......KKKK......", ".....KHHHHK.....", "..K.KHHHHHHK.K..", ".KRKKHSSSSHKKRK.",
        ".KRRKSRSSRSKRRK.", ".KRRKSSSSSSKRRK.", ".KRRRKSWWSKRRRK.", "..KRRRKSSKRRRK..",
        "..KPKKPPPPKKPK..", ".KSKPPPYPPPPKSK.", ".KSKPPPPPPPPKSK.", "..KKPPPPPPPPKK..",
        "..KPPPPPPPPPPK..", ".KPPPPPPPPPPPPK.", ".KPPPpPPPPpPPPK.", "..KKKKKKKKKKKK..",
    ]

    static let specsHaunted: [String: SpriteSpec] = [
        "haunted_crow": SpriteSpec(grid: hauntedCrow, swap: ["N": rgb(52, 50, 70), "n": rgb(86, 82, 110), "R": rgb(255, 60, 60), "Y": rgb(240, 190, 60)]),
        "haunted_scarecrow": SpriteSpec(grid: hauntedScarecrow, swap: ["L": rgb(170, 130, 70), "C": rgb(214, 190, 140), "R": rgb(150, 60, 50), "G": rgb(90, 120, 70),
                                                                   "Y": rgb(240, 210, 110)]),
        "haunted_pumpkin": SpriteSpec(grid: hauntedPumpkin, swap: ["F": rgb(240, 130, 40), "Q": rgb(190, 80, 20), "Y": rgb(255, 236, 110), "G": rgb(90, 130, 60)]),
        "haunted_zombie": SpriteSpec(grid: hauntMark(villager, [
            (5, 4, "R"), (12, 8, "S"), (13, 8, "S"), (14, 8, "K"), (12, 9, "K"), (13, 9, "K"), (7, 8, "S"), (8, 10, "s"), (6, 12, "S"),
        ]), swap: ["S": rgb(140, 176, 116), "s": rgb(96, 128, 84), "H": rgb(70, 60, 50), "W": rgb(170, 160, 130), "C": rgb(90, 100, 140), "c": rgb(60, 66, 100),
                   "R": rgb(255, 80, 60)]),
        "haunted_ghost": SpriteSpec(grid: hauntMark(hauntedGhost, [(5, 7, "O"), (10, 7, "O"), (5, 8, "O"), (10, 9, "O"), (7, 8, "W"), (8, 8, "W"), (6, 9, "K"), (9, 9, "K")]),
                                    swap: ["W": rgb(232, 238, 255), "B": rgb(170, 184, 222), "O": rgb(110, 196, 255)]),
        "haunted_cat": SpriteSpec(grid: hauntMark(hauntedCat, [(11, 7, "W"), (11, 8, "W"), (12, 8, "W")]),
                                  swap: ["N": rgb(58, 52, 76), "Y": rgb(200, 255, 80), "P": rgb(255, 140, 170), "W": rgb(140, 132, 160)]),
        "haunted_wisp": SpriteSpec(grid: hauntedCandle, swap: ["F": rgb(110, 200, 255), "Y": rgb(190, 240, 255), "W": rgb(255, 255, 255), "C": rgb(236, 230, 214),
                                                         "c": rgb(190, 180, 160), "L": rgb(60, 50, 40)]),
        "haunted_doll": SpriteSpec(grid: hauntMark(hauntedDoll, [(1, 3, "M"), (2, 4, "M"), (12, 7, "M"), (13, 8, "M"), (14, 9, "W"), (9, 12, "c"), (10, 13, "c")]),
                                   swap: ["H": rgb(190, 70, 60), "S": rgb(236, 220, 200), "P": rgb(120, 90, 150), "R": rgb(150, 40, 50), "M": rgb(190, 196, 210),
                                          "c": rgb(80, 60, 100)]),
        "haunted_ghoul": SpriteSpec(grid: hauntedGhoul, swap: ["S": rgb(150, 160, 140), "R": rgb(255, 220, 80), "A": rgb(84, 76, 70), "a": rgb(56, 50, 46),
                                                         "L": rgb(130, 96, 60), "M": rgb(170, 176, 186)]),
        "haunted_banshee": SpriteSpec(grid: hauntMark(hauntedGhost, [
            (3, 3, "H"), (2, 4, "H"), (2, 5, "H"), (1, 6, "H"), (1, 7, "H"), (1, 8, "H"), (1, 9, "H"), (12, 3, "H"), (13, 4, "H"), (13, 5, "H"), (14, 6, "H"),
            (14, 7, "H"), (14, 8, "H"), (14, 9, "H"), (7, 10, "K"), (8, 10, "K"), (7, 11, "R"), (8, 11, "R"), (5, 5, "R"), (10, 5, "R"),
        ]), swap: ["W": rgb(200, 240, 220), "B": rgb(140, 196, 176), "H": rgb(236, 240, 246), "R": rgb(120, 255, 200)]),
        "haunted_witch": SpriteSpec(grid: hauntedWitch, swap: ["P": rgb(60, 40, 90), "H": rgb(40, 30, 40), "S": rgb(150, 210, 120), "L": rgb(130, 90, 50),
                                                         "Y": rgb(220, 190, 110)]),
        "haunted_toad": SpriteSpec(grid: hauntMark(hauntedToad, [(6, 3, "O"), (9, 2, "O"), (11, 4, "O")]),
                                   swap: ["G": rgb(110, 150, 70), "g": rgb(170, 90, 160), "C": rgb(200, 210, 130), "W": rgb(255, 230, 90), "O": rgb(190, 255, 120)]),
        "haunted_armor": SpriteSpec(grid: hauntMark(warrior, [
            (6, 5, "O"), (9, 5, "O"), (3, 11, "M"), (12, 11, "M"), (5, 0, "O"), (10, 0, "O"), (7, 0, "O"),
            (13, 7, "M"), (14, 6, "M"), (15, 5, "W"), (12, 8, "Y"),
        ]), swap: ["M": rgb(150, 142, 136), "m": rgb(100, 92, 88), "S": rgb(26, 22, 36), "R": rgb(110, 60, 140), "r": rgb(70, 36, 96), "B": rgb(200, 190, 180),
                   "O": rgb(120, 255, 230), "Y": rgb(200, 170, 80), "L": rgb(70, 50, 40)]),
        "haunted_bats": SpriteSpec(grid: hauntedBats, swap: ["A": rgb(110, 30, 50), "R": rgb(255, 230, 80), "W": rgb(250, 250, 250)]),
        "haunted_butler": SpriteSpec(grid: hauntMark(hauntedGhost, [
            (6, 7, "H"), (7, 7, "H"), (8, 7, "H"), (9, 7, "H"), (7, 8, "W"), (8, 8, "W"), (7, 9, "W"), (8, 9, "W"),
            (2, 10, "Z"), (3, 10, "Z"), (4, 10, "Z"), (5, 10, "Z"), (6, 10, "R"), (7, 10, "R"), (8, 10, "R"), (9, 10, "R"), (10, 10, "Z"), (11, 10, "Z"),
            (12, 10, "Z"), (13, 10, "Z"), (2, 11, "Z"), (3, 11, "Z"), (4, 11, "Z"), (5, 11, "Z"), (6, 11, "Z"), (7, 11, "C"), (8, 11, "C"), (9, 11, "Z"),
            (10, 11, "Z"), (11, 11, "Z"), (12, 11, "Z"), (13, 11, "Z"), (2, 12, "Z"), (3, 12, "Z"), (4, 12, "Z"), (5, 12, "Z"), (6, 12, "Z"), (7, 12, "C"),
            (8, 12, "C"), (9, 12, "Z"), (10, 12, "Z"), (11, 12, "Z"), (12, 12, "Z"), (13, 12, "Z"), (3, 13, "Z"), (12, 13, "Z"),
        ]), swap: ["W": rgb(214, 206, 240), "B": rgb(164, 154, 204), "H": rgb(90, 80, 110), "Z": rgb(46, 40, 60), "R": rgb(200, 40, 60), "C": rgb(240, 240, 250)]),
        "haunted_bellringer": SpriteSpec(grid: hauntedRinger, swap: ["S": rgb(196, 170, 140), "W": rgb(255, 240, 200), "A": rgb(92, 82, 104), "a": rgb(62, 54, 72),
                                                               "Y": rgb(210, 166, 64), "y": rgb(150, 110, 40), "R": rgb(90, 60, 30)], boss: true),
        "haunted_countess": SpriteSpec(grid: hauntedCountess, swap: ["H": rgb(40, 30, 50), "S": rgb(236, 226, 236), "R": rgb(200, 30, 50), "P": rgb(110, 16, 40),
                                                               "p": rgb(70, 10, 26), "Y": rgb(255, 210, 80)], boss: true),
    ]

    static let iconsHaunted: [String: [Character: CGColor]] = [
        "haunted_ecto": ["B": rgb(214, 255, 226), "E": rgb(110, 190, 160)],
        "haunted_thread": ["B": rgb(170, 110, 200), "E": rgb(90, 50, 120)],
        "haunted_heart": ["B": rgb(220, 40, 60), "E": rgb(120, 10, 30), "W": rgb(255, 180, 190)],
        "haunted_candy": ["B": rgb(245, 140, 40), "E": rgb(190, 80, 20)],
        "haunted_tea": ["B": rgb(150, 200, 110), "E": rgb(90, 130, 60)],
        "haunted_charm": ["B": rgb(70, 66, 90), "E": rgb(36, 32, 50), "W": rgb(170, 160, 210)],
        "haunted_helmet": ["B": rgb(240, 130, 40), "J": rgb(255, 236, 110)],
        "haunted_boots": ["B": rgb(200, 210, 236), "J": rgb(120, 255, 230)],
        "haunted_ring": ["B": rgb(60, 56, 76), "J": rgb(255, 50, 60)],
        "haunted_amulet": ["B": rgb(200, 200, 214), "J": rgb(140, 220, 255)],
        "haunted_mace": ["B": rgb(205, 160, 60), "E": rgb(140, 100, 40), "G": rgb(110, 80, 50), "H": rgb(70, 50, 40), "O": rgb(110, 80, 50), "W": rgb(255, 240, 190)],
        "haunted_broom": ["B": rgb(140, 100, 56), "E": rgb(90, 60, 30), "G": rgb(220, 190, 110), "H": rgb(70, 50, 30), "O": rgb(150, 255, 90), "W": rgb(230, 255, 210)],
    ]
}

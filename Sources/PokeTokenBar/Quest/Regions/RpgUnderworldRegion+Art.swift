import CoreGraphics
import Foundation

// 지하 마계 sprites and item icons. New bodies face right (the view mirrors them when a monster walks left).

/// Paints single pixels over a grid (`RpgArt.overlay` is private to RpgArt.swift).
private func uwMark(_ g: RpgGrid, _ marks: [(Int, Int, Character)]) -> RpgGrid {
    var rows = g.map { Array($0) }
    for (x, y, c) in marks where y < rows.count && x < rows[y].count { rows[y][x] = c }
    return rows.map { String($0) }
}

extension RpgArt {
    static let underworldImp: RpgGrid = [
        "................", "................", "................", ".....K...K......",
        ".....KK.KK.....M", "....KRRRRRK..M.M", "....KRWKWKK..MMM", "....KRRRRRK...M.",
        "..K..KRRRK....M.", ".KAK.KRRRK...KM.", "KAAAKRRRRRKKKSM.", "KAAAKRRRRRK...M.",
        ".KKKKRRRRRK...M.", ".....KRKKRK...M.", ".....KRK.KRK..M.", "....KKK...KK....",
    ]
    static let underworldWorm: RpgGrid = [
        "................", "........KKKK....", ".......KRRRRK...", "......KRRRRRRK..",
        "......KRWKRRKKK.", "......KRRRRKWWWK", ".......KRRRKKKK.", "........KRQK....",
        ".......KRQRK....", ".......KQRRK....", "......KRRQRK....", ".....KRQRRRRK...",
        "....KRRRRQRRK...", "...KRRQRRRRRRK..", "..KRRRRRRQRRRRK.", ".KKKKKKKKKKKKKKK",
    ]
    static let underworldHound: RpgGrid = [
        ".....KKKKKK.....", ".KKKKKZZZZKKKKK.", "KZZZZKRZZRKZZZZK", "KRZZRKZKKZKRZZRK",
        "KZKKZKKWWKKZKKZK", "KKWWKKZZZZKKWWKK", ".KZZKZZZZZZKZZK.", "..KZZZZZZZZZZK..",
        ".KZZZZZZZZZZZZK.", "KZZZZZZZZZZZZZZK", "KZZzZZZZZZZZzZZK", ".KZZZZZZZZZZZZK.",
        "..KZZKKKKKKZZK..", "..KZZK....KZZK..", "..KzzK....KzzK..", "..KKKK....KKKK..",
    ]
    static let underworldDemon: RpgGrid = [
        "..K..........K..", "..KK.KKKKKK.KK..", "...KKRRRRRRKK...", "....KRYRRYRK....",
        "....KRRRRRRK....", "....KRWKKWRK....", "..KKKKRRRRKKKK..", ".KRRRRRRRRRRRRK.",
        "KRRKRRRRRRRRKRRK", "KRRKRRrrrrRRKRRK", "KRRKRRRRRRRRKRRK", "KKKKLLLLLLLLKKKK",
        "...KrrrKKrrrK...", "...KrrrKKrrrK...", "...KLLK..KLLK...", "...KKKK..KKKK...",
    ]
    static let underworldExec: RpgGrid = [
        "................", "....KKKKKK......", "...KAAAAAAK...KK", "...KAAAAAAK..KMM",
        "...KARAARAK..KMM", "...KAAAAAAK..KMK", "..KKAAAAAAKK..L.", ".KSSKSSSSKSSK.L.",
        "KSSKSSSSSSKSSKL.", "KSSKSSsSSSKSSSL.", "KSSKSSSSSSK.KKL.", "KKKKLLLLLLKK..L.",
        "...KAAAAAAK...L.", "...KAAKKAAK...L.", "...KLLK.KLLK....", "...KKKK.KKKK....",
    ]
    static let underworldFlame: RpgGrid = [
        ".......K........", "......KOK.......", ".....KOOK...K...", ".....KOOOK.KOK..",
        "....KOOWOOKKOK..", "...KOOWWWOOOOK..", "...KOWWWWWOOK...", "..KOOWKWWKWOOK..",
        "..KOWWKWWKWWOK..", "..KOWWWWWWWWOK..", "..KOWWWKKWWWOK..", "...KOWWWWWWOK...",
        "....KOOWWOOK....", ".....KKOOKK.....", ".......KK.......", "................",
    ]
    static let underworldMoth: RpgGrid = [
        "................", "...K........K...", "....K......K....", ".KKKKK.KK.KKKKK.",
        "KFFFFFKOOKFFFFFK", "KFYYFFKOOKFFYYFK", "KFYKYFKOOKFYKYFK", "KFFYFFKOOKFFYFFK",
        ".KFFFFKOOKFFFFK.", "..KKKFKOOKFKKK..", "..KQQQKOOKQQQK..", "..KQQKKOOKKQQK..",
        "...KK.KOOK.KK...", "......KOOK......", ".......KK.......", "................",
    ]
    static let underworldUrn: RpgGrid = [
        "....K......K....", "...KOK....KOK...", "....KOK..KOK....", ".....KKKKKK.....",
        "....KMMMMMMK....", ".....KNNNNK.....", "....KNNNNNNK....", "...KNNNNNNNNK...",
        "..KNNKKNNKKNNK..", "..KNNRKNNKRNNK..", "..KNNNNNNNNNNK..", "..KNNNKKKKNNNK..",
        "...KNNKRRKNNK...", "....KNNNNNNK....", ".....KMMMMK.....", ".....KKKKKK.....",
    ]
    static let underworldWinged: RpgGrid = [
        "................", "K.....K..K.....K", "KA...KRKKRK...AK", "KAA..KRRRRK..AAK",
        "KAAA.KYRRYK.AAAK", "KAaAAKRRRRKAAaAK", "KAaaAAKRRKAAaaAK", ".KAaAKRRRRKAaAK.",
        "..KAAKRRRRKAAK..", "...KAKRRRRKAK...", "....KKRRRRKK....", "......KRRK......",
        ".....KRKKRK.....", ".....KRK.KRK....", ".....KKK.KKK....", "................",
    ]
    static let underworldOverlord: RpgGrid = [
        ".K............K.", ".KK..........KK.", "..KK.KKKKKK.KK..", "...KKRRRRRRKK...",
        "....KRYRRYRK....", "....KRRRRRRK....", "..KKKKWKKWKKKK..", ".KMMMKRRRRKMMMK.",
        "KMMMKPRRRRPKMMMK", "KPKKPPRYYRPPKKPK", "KPPKRRRRRRRRKPPK", "KPPKRrRRRRrRKPPK",
        "KPPPKRRKKRRKPPPK", "KPPPKrrK.KrrKPPK", "KPPPKLLK.KLLKPPK", "KKKKKKKK.KKKKKKK",
    ]

    static let specsUnderworld: [String: SpriteSpec] = [
        "underworld_sulfurslime": SpriteSpec(grid: uwMark(slime, [
            (7, 1, "K"), (6, 2, "K"), (7, 2, "Y"), (8, 2, "K"), (10, 2, "K"), (5, 3, "K"), (6, 3, "Y"), (7, 3, "y"), (8, 3, "K"), (9, 3, "K"), (10, 3, "Y"),
            (11, 3, "K"), (4, 4, "K"), (5, 4, "Y"), (6, 4, "y"), (7, 4, "Y"), (8, 4, "y"), (9, 4, "Y"), (10, 4, "y"), (11, 4, "Y"), (12, 4, "K"),
            (5, 5, "K"), (10, 5, "K"), (11, 5, "K"), (2, 6, "W"), (14, 4, "W"), (14, 8, "W"),
        ]), swap: ["E": rgb(214, 206, 84), "e": rgb(150, 140, 40), "W": rgb(255, 255, 210), "Y": rgb(255, 244, 130), "y": rgb(210, 176, 50)]),
        "underworld_imps": SpriteSpec(grid: underworldImp, swap: ["R": rgb(232, 86, 40), "A": rgb(120, 40, 30), "S": rgb(232, 86, 40), "W": rgb(255, 240, 120),
                                                         "M": rgb(196, 198, 210)]),
        "underworld_worm": SpriteSpec(grid: underworldWorm, swap: ["R": rgb(196, 70, 40), "Q": rgb(255, 190, 60)]),
        "underworld_thief": SpriteSpec(grid: uwMark(underworldImp, [
            (15, 4, "."), (13, 5, "."), (15, 5, "."), (13, 6, "."), (14, 6, "."), (15, 6, "."), (14, 7, "."), (14, 8, "."), (13, 9, "."), (14, 9, "."),
            (13, 10, "O"), (14, 10, "K"), (14, 11, "."), (14, 12, "."), (14, 13, "."), (14, 14, "."),
            (1, 7, "K"), (2, 7, "K"), (3, 7, "K"), (0, 8, "K"), (1, 8, "C"), (2, 8, "Y"), (3, 8, "C"), (4, 8, "K"), (0, 9, "K"), (1, 9, "C"), (2, 9, "C"),
            (3, 9, "Y"), (4, 9, "K"), (0, 10, "K"), (1, 10, "Y"), (2, 10, "C"), (3, 10, "C"), (4, 10, "K"), (0, 11, "K"), (1, 11, "C"), (2, 11, "C"),
            (3, 11, "C"), (4, 11, "K"), (0, 12, "."), (1, 12, "K"), (2, 12, "K"), (3, 12, "K"), (4, 12, "K"),
        ]), swap: ["R": rgb(150, 72, 200), "W": rgb(255, 255, 255), "C": rgb(200, 160, 100), "Y": rgb(255, 220, 60), "O": rgb(100, 255, 200)]),
        "underworld_cerberus": SpriteSpec(grid: underworldHound, swap: ["Z": rgb(122, 66, 58), "z": rgb(78, 40, 38), "R": rgb(255, 176, 40)]),
        "underworld_chain": SpriteSpec(grid: uwMark(underworldDemon, [
            (5, 8, "M"), (6, 9, "M"), (7, 9, "M"), (8, 10, "M"), (9, 10, "M"), (10, 9, "M"), (11, 8, "M"),
            (1, 12, "M"), (1, 13, "M"), (0, 14, "M"), (14, 12, "M"), (14, 13, "M"), (15, 14, "M"),
        ]), swap: ["R": rgb(150, 40, 60), "r": rgb(100, 24, 40), "Y": rgb(255, 220, 80), "L": rgb(60, 50, 50), "M": rgb(176, 180, 196)]),
        "underworld_wisp": SpriteSpec(grid: underworldFlame, swap: ["O": rgb(120, 240, 170), "W": rgb(222, 255, 232)]),
        "underworld_smith": SpriteSpec(grid: uwMark(underworldDemon, [
            (5, 9, "L"), (6, 9, "L"), (7, 9, "L"), (8, 9, "L"), (9, 9, "L"), (10, 9, "L"), (5, 10, "L"), (6, 10, "L"), (7, 10, "L"), (8, 10, "L"),
            (9, 10, "L"), (10, 10, "L"), (6, 8, "Q"), (9, 7, "Q"), (2, 9, "Q"),
            (13, 3, "K"), (14, 3, "K"), (15, 3, "K"), (13, 4, "M"), (14, 4, "M"), (15, 4, "M"), (13, 5, "K"), (14, 5, "M"), (15, 5, "K"),
            (14, 6, "l"), (14, 7, "l"),
        ]), swap: ["R": rgb(74, 64, 68), "r": rgb(46, 38, 42), "Y": rgb(255, 150, 40), "L": rgb(120, 80, 50), "Q": rgb(255, 140, 40), "M": rgb(150, 150, 160),
                   "l": rgb(100, 70, 40)]),
        "underworld_nightmare": SpriteSpec(grid: uwMark(mage, [
            (4, 2, "W"), (3, 1, "W"), (11, 2, "W"), (12, 1, "W"),
            (2, 8, "K"), (1, 9, "K"), (2, 9, "A"), (0, 10, "K"), (1, 10, "A"), (2, 10, "A"), (0, 11, "K"), (1, 11, "A"), (2, 11, "K"), (0, 12, "K"), (1, 12, "K"),
            (13, 8, "K"), (14, 9, "K"), (13, 9, "A"), (15, 10, "K"), (14, 10, "A"), (13, 10, "A"), (15, 11, "K"), (14, 11, "A"), (13, 11, "K"), (15, 12, "K"),
            (14, 12, "K"),
        ]), swap: ["P": rgb(72, 30, 92), "p": rgb(42, 16, 58), "S": rgb(210, 180, 230), "Y": rgb(255, 90, 200), "A": rgb(96, 44, 116), "W": rgb(240, 232, 220)]),
        "underworld_furnace": SpriteSpec(grid: uwMark(golem, [
            (6, 7, "K"), (7, 7, "K"), (8, 7, "K"), (9, 7, "K"), (6, 8, "K"), (7, 8, "F"), (8, 8, "F"), (9, 8, "K"), (6, 9, "K"), (7, 9, "Q"), (8, 9, "Q"),
            (9, 9, "K"), (9, 0, "K"), (10, 0, "K"), (11, 0, "K"),
        ]), swap: ["N": rgb(112, 100, 104), "n": rgb(70, 62, 66), "Q": rgb(255, 160, 50), "F": rgb(255, 232, 120)]),
        "underworld_miner": SpriteSpec(grid: uwMark(skeleton, [
            (5, 0, "K"), (6, 0, "T"), (7, 0, "Y"), (8, 0, "Y"), (9, 0, "T"), (10, 0, "K"), (4, 1, "K"), (5, 1, "T"), (6, 1, "T"), (7, 1, "T"), (8, 1, "T"),
            (9, 1, "T"), (10, 1, "T"), (11, 1, "K"), (3, 2, "K"), (4, 2, "T"), (11, 2, "T"), (12, 2, "K"),
            (11, 4, "M"), (12, 3, "M"), (13, 3, "M"), (14, 3, "M"), (15, 4, "M"), (13, 4, "L"), (13, 5, "L"), (13, 6, "L"), (13, 7, "L"), (13, 8, "L"),
            (13, 9, "L"), (12, 9, "X"),
        ]), swap: ["X": rgb(186, 214, 230), "x": rgb(120, 150, 172), "T": rgb(200, 170, 70), "Y": rgb(255, 250, 180), "M": rgb(170, 176, 190),
                   "L": rgb(120, 86, 50)]),
        "underworld_moths": SpriteSpec(grid: underworldMoth, swap: ["F": rgb(255, 122, 40), "Y": rgb(255, 232, 100), "Q": rgb(200, 60, 30), "O": rgb(92, 52, 42)]),
        "underworld_judge": SpriteSpec(grid: underworldExec, swap: ["A": rgb(42, 32, 44), "R": rgb(255, 60, 40), "S": rgb(190, 122, 110), "s": rgb(140, 80, 70),
                                                           "L": rgb(84, 62, 50), "M": rgb(200, 206, 216)]),
        "underworld_urn": SpriteSpec(grid: underworldUrn, swap: ["N": rgb(190, 170, 140), "M": rgb(140, 110, 70), "O": rgb(150, 255, 200), "R": rgb(120, 255, 200)]),
        "underworld_scout": SpriteSpec(grid: underworldWinged, swap: ["R": rgb(170, 50, 60), "A": rgb(82, 30, 40), "a": rgb(50, 16, 26), "Y": rgb(255, 220, 80)]),
        "underworld_hellguard": SpriteSpec(grid: uwMark(underworldDemon, [
            (5, 3, "K"), (6, 3, "Y"), (7, 3, "Y"), (8, 3, "Y"), (9, 3, "Y"), (10, 3, "K"), (5, 5, "M"), (6, 5, "M"), (7, 5, "M"), (8, 5, "M"), (9, 5, "M"),
            (10, 5, "M"), (5, 8, "M"), (6, 8, "M"), (9, 8, "M"), (10, 8, "M"),
            (0, 7, "K"), (1, 7, "K"), (2, 7, "K"), (3, 7, "K"), (0, 8, "K"), (1, 8, "N"), (2, 8, "N"), (3, 8, "K"), (0, 9, "K"), (1, 9, "Y"), (2, 9, "N"),
            (3, 9, "K"), (0, 10, "K"), (1, 10, "N"), (2, 10, "N"), (3, 10, "K"), (0, 11, "K"), (1, 11, "N"), (2, 11, "N"), (3, 11, "K"), (1, 12, "K"),
            (2, 12, "K"), (15, 0, "M"), (15, 1, "M"), (14, 1, "M"), (15, 2, "L"), (15, 3, "L"), (15, 4, "L"), (15, 5, "L"), (15, 6, "L"), (15, 7, "L"),
        ]), swap: ["R": rgb(62, 58, 74), "r": rgb(36, 32, 46), "Y": rgb(255, 120, 40), "W": rgb(62, 58, 74), "L": rgb(110, 40, 40), "M": rgb(150, 150, 166),
                   "N": rgb(120, 30, 40)]),
        "underworld_forgelord": SpriteSpec(grid: uwMark(golem, [
            (3, 0, "K"), (4, 0, "K"), (11, 0, "K"), (12, 0, "K"), (2, 1, "K"), (3, 1, "W"), (12, 1, "W"), (13, 1, "K"),
            (6, 7, "Q"), (9, 8, "Q"), (5, 9, "Q"), (10, 10, "Q"), (7, 12, "Q"),
            (13, 2, "K"), (14, 2, "K"), (15, 2, "K"), (13, 3, "M"), (14, 3, "M"), (15, 3, "M"), (13, 4, "K"), (14, 4, "M"), (15, 4, "K"), (14, 5, "L"),
        ]), swap: ["N": rgb(66, 48, 46), "n": rgb(42, 28, 28), "Q": rgb(255, 170, 40), "W": rgb(230, 220, 200), "M": rgb(150, 150, 164),
                   "L": rgb(110, 70, 40)], boss: true),
        "underworld_overlord": SpriteSpec(grid: underworldOverlord, swap: ["R": rgb(150, 22, 40), "r": rgb(100, 10, 26), "Y": rgb(255, 220, 60), "M": rgb(64, 58, 74),
                                                                  "P": rgb(64, 12, 54), "L": rgb(42, 32, 32)], boss: true),
    ]

    static let iconsUnderworld: [String: [Character: CGColor]] = [
        "underworld_brimstone": ["B": rgb(240, 226, 90), "E": rgb(170, 150, 30)],
        "underworld_soul": ["B": rgb(160, 176, 255), "E": rgb(70, 80, 200), "W": rgb(240, 240, 255)],
        "underworld_hellsteel": ["B": rgb(110, 60, 60), "E": rgb(50, 20, 24), "W": rgb(255, 140, 60)],
        "underworld_elixir": ["B": rgb(255, 110, 40), "E": rgb(180, 40, 20)],
        "underworld_oil": ["B": rgb(120, 200, 255), "E": rgb(40, 120, 200)],
        "underworld_pepper": ["B": rgb(230, 40, 30), "E": rgb(140, 20, 20)],
        "underworld_helmet": ["B": rgb(70, 62, 74), "J": rgb(255, 100, 40)],
        "underworld_boots": ["B": rgb(110, 50, 40), "J": rgb(255, 170, 50)],
        "underworld_ring": ["B": rgb(60, 20, 30), "J": rgb(255, 40, 60)],
        "underworld_amulet": ["B": rgb(170, 150, 110), "J": rgb(130, 255, 190)],
        "underworld_sword": ["B": rgb(255, 150, 60), "E": rgb(170, 40, 20), "G": rgb(60, 30, 30), "H": rgb(40, 20, 20), "J": rgb(255, 230, 90)],
        "underworld_claw": ["B": rgb(110, 90, 140), "E": rgb(60, 40, 90), "G": rgb(140, 255, 200), "H": rgb(40, 30, 50), "O": rgb(140, 255, 200), "W": rgb(230, 255, 240)],
    ]
}

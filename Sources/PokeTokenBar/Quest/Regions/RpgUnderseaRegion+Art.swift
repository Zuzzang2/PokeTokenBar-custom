import CoreGraphics
import Foundation

// 해저 신전 sprites and item icons. New bodies face right (the view mirrors them when a monster walks left).

/// Paints single pixels over a grid (`RpgArt.overlay` is private to RpgArt.swift).
private func usMark(_ g: RpgGrid, _ marks: [(Int, Int, Character)]) -> RpgGrid {
    var rows = g.map { Array($0) }
    for (x, y, c) in marks where y < rows.count && x < rows[y].count { rows[y][x] = c }
    return rows.map { String($0) }
}

extension RpgArt {
    static let underseaPuffer: RpgGrid = [
        "................", "........X.......", ".....X......X...", "......KKKKKK....",
        ".....KNNNNNNK.X.", "K...KNWNNNNNNK..", "nK.KNNNNNNNWWNK.", "KnKKNNNNNNNWKNK.",
        ".KnnNNNNNNNNNNKX", "KnKKNNNnnNNNNRK.", "nK.KCCCCnCCCCCK.", "K...KCCCCCCCCK..",
        ".....KCCCCCCK.X.", "......KKKKKK....", ".....X......X...", "........X.......",
    ]
    static let underseaUrchin: RpgGrid = [
        "................", "......X..X......", "...X..x..x..X...", "....x.KKKK.x....",
        ".X..KKNNNNKK..X.", "..xKNNnnNNNNKx..", "...KNnnnNNNNK...", "XxKNNnnNNNNNNKxX",
        "..KNNNNNNNNNNK..", "..KNNNWNNWNNNK..", "XxKNNNKNNKNNNKxX", "...KNNNNNNNNK...",
        "..xKNNNNNNNNKx..", ".X..KKNNNNKK..X.", "....x.KKKK.x....", "...X..x..x..X...",
    ]
    static let underseaSeahorse: RpgGrid = [
        "................", "......K.K.......", ".....KYKYK......", "....KNNNNNK.....",
        "....KNNWKNNKKKK.", "....KNNNNNNNNNNK", ".....KNNNNKKKKK.", "...KK.KNNNK....W",
        "..KnnKKNCCNK..M.", "..KnnnKNCCNK.M..", "...KnnKNCCNKM...", "....KKKNCCNMK...",
        "......KNNCNNK...", ".......KNNNK....", "....KKK.KNNK....", "...KNNNKKNK.....",
    ]
    static let underseaStar: RpgGrid = [
        "................", ".......KK.......", "......KNNK......", "......KNCK......",
        "......KNNK......", ".KKKKKKNNKKKKKK.", "KNNCNNNNNNNNCNNK", ".KKNNNNnnNNNNKK.",
        "...KNNWnnWNNK...", "...KNNKnnKNNK...", "...KNNNNNNNNK...", "..KNNCNKKNCNNK..",
        "..KNNNK..KNNNK..", ".KNNNK....KNNNK.", ".KCNK......KNCK.", "..KK........KK..",
    ]
    static let underseaMerfolk: RpgGrid = [
        "................", "......KKKK......", ".....KHHHHK.....", "....KHHHSSSK....",
        "....KHHSKSKK....", "....KHHSSSSK....", ".....KKSSSKK....", "....KSKCCCKSK...",
        "...KSKKCCCKKSK..", "....K.KNNNNK.K..", "......KNNNNK....", "......KNnNNK....",
        ".......KnNNK....", "......KKKnKK....", ".....KFFKKFFK...", "....KFFK..KFFK..",
    ]
    static let underseaClam: RpgGrid = [
        "................", "................", ".....KKKKKK.....", "...KKNNnNNnKK...",
        "..KNnNNnNNnNNK..", ".KNNnNNnNNnNNNK.", ".KKKKKKKKKKKKKK.", ".KRWKRRRRRRWKRK.",
        ".KRRRRRWWRRRRRK.", ".KRRRRWBBWRRRRK.", ".KKKKKKWWKKKKKK.", ".KnNNnNNnNNnNnK.",
        "..KnNNnNNnNNnK..", "...KKnNNNNnKK...", ".....KKKKKK.....", "................",
    ]
    static let underseaEel: RpgGrid = [
        "................", "................", "................", "...........KKKK.",
        "..........KYYWKK", "..........KYYYYK", "..........KcYYYR", "....KKK...KcYKK.",
        "...KYYYKKKYcYK..", "..KYcccYYYccK...", ".KYcKKKcccKK....", ".KYcK..KKK......",
        "KYcK............", "KYcK............", ".KK.............", "................",
    ]
    static let underseaAngler: RpgGrid = [
        "................", ".......llll.....", ".......l..KK....", ".......l.KYYK...",
        ".....KKlKKYYK...", "....KNNlNNKK....", "..KKNNNNNNNNK...", ".KNNNNNNNWWNNK..",
        "KnKNNNNNNWKNNNK.", "KnnKNNNNNNNNKKK.", "KnnNNNNNNNNKWKW.", "KnnNNNNNNNNKRRRK",
        "KnKNNNNNNNNKWKWK", ".K.KCCCCCCCNKKK.", "....KKCCCCCKK...", "......KKKKK.....",
    ]
    static let underseaTurtle: RpgGrid = [
        "................", "................", "................", "................",
        ".....KKKK.......", "...KKNNNNKK.....", "..KNnNNNnNNK....", ".KNNNNNNNNNNK...",
        ".KNNNNnNNNNNKKK.", "KNNnNNNNNNnNKSSK", "KNNNNNNNNNNNKSWK", "KcccccccccccKSSK",
        "KCCCCCCCCCCCKSRK", ".KSSSKKKSSSKKKK.", ".KSSSK.KSSSK....", "..KKK...KKK.....",
    ]
    static let underseaRay: RpgGrid = [
        "................", "................", "................", "......KKKK......",
        "....KKNNNNKK....", "..KKNNNNNNNNKK..", ".KNNNNWNNWNNNNK.", "KNNNNNKNNKNNNNNK",
        ".KNNNNNNNNNNNNK.", "..KKNNNNNNNNKK..", "....KKNnnNKK....", "......KnnK......",
        "......KnnK......", "......KnnK......", ".......KK.......", "................",
    ]
    static let underseaShark: RpgGrid = [
        "................", "................", "................", "................",
        "................", "................", "......K.........", "K....KNK........",
        "NK..KNNKKKKKK...", "KNKKNNNNNNNNNKK.", ".KNNNNNNNNNNWKNK", ".KNNNNNNNNNNNNNK",
        "KNKCCCCCCCCKWKWK", "NK.KCCCCCCKKKKK.", "K....KCCK.......", "......KK........",
    ]
    static let underseaSquid: RpgGrid = [
        ".......KK.......", "......KNNK......", ".....KNNNNK.....", "..K.KNNnNNNK.K..",
        ".KNKNNNNNnNNKNK.", "..KNNNnNNNNNNK..", "...KNNNNNnNNK...", "...KNWWNNWWNK...",
        "...KNWKNNWKNK...", "...KNNNNNNNNK...", "..KNNNNNNNNNNK..", "..KNNKNNNNKNNK..",
        ".KNNKKNNNNKKNNK.", ".KNK.KNKKNK.KNK.", "..KNK.KNNK.KNK..", "...K...KK...K...",
    ]

    static let specsUndersea: [String: SpriteSpec] = [
        "undersea_shellslime": SpriteSpec(grid: usMark(slime, [
            (9, 0, "K"), (10, 0, "K"), (8, 1, "K"), (9, 1, "C"), (10, 1, "c"), (11, 1, "K"), (7, 2, "K"), (8, 2, "C"), (9, 2, "C"), (10, 2, "c"), (11, 2, "K"),
            (6, 3, "K"), (7, 3, "C"), (8, 3, "c"), (9, 3, "C"), (10, 3, "C"), (11, 3, "K"), (5, 4, "K"), (6, 4, "C"), (7, 4, "C"), (8, 4, "C"), (9, 4, "c"),
            (10, 4, "C"), (11, 4, "K"), (5, 5, "K"), (6, 5, "c"), (7, 5, "C"), (8, 5, "C"), (9, 5, "C"), (10, 5, "c"), (11, 5, "K"),
        ]), swap: ["E": rgb(140, 220, 205), "e": rgb(60, 150, 150), "W": rgb(230, 255, 250), "C": rgb(255, 222, 205), "c": rgb(232, 150, 145)]),
        "undersea_puffer": SpriteSpec(grid: underseaPuffer, swap: ["N": rgb(245, 205, 90), "n": rgb(205, 140, 50), "C": rgb(255, 245, 205), "X": rgb(255, 250, 235),
                                                             "R": rgb(235, 100, 90)]),
        "undersea_seahorse": SpriteSpec(grid: underseaSeahorse, swap: ["N": rgb(250, 150, 80), "n": rgb(200, 90, 60), "C": rgb(255, 215, 160), "Y": rgb(255, 230, 90),
                                                                 "M": rgb(200, 210, 230)]),
        "undersea_starfish": SpriteSpec(grid: underseaStar, swap: ["N": rgb(255, 140, 130), "n": rgb(210, 80, 90), "C": rgb(255, 232, 180)]),
        "undersea_merman": SpriteSpec(grid: usMark(underseaMerfolk, [
            (13, 0, "M"), (15, 0, "M"), (13, 1, "M"), (14, 1, "M"), (15, 1, "M"), (14, 2, "L"), (14, 3, "L"), (14, 4, "L"), (14, 5, "L"), (14, 6, "L"),
            (14, 7, "L"), (14, 8, "L"), (13, 9, "S"), (14, 9, "S"), (14, 10, "L"), (14, 11, "L"), (14, 12, "L"),
        ]), swap: ["H": rgb(60, 150, 140), "S": rgb(170, 220, 200), "C": rgb(240, 200, 120), "N": rgb(50, 160, 150), "n": rgb(30, 110, 110),
                   "F": rgb(120, 220, 200), "M": rgb(215, 225, 240), "L": rgb(160, 110, 60)]),
        "undersea_clam": SpriteSpec(grid: underseaClam, swap: ["N": rgb(176, 156, 206), "n": rgb(110, 90, 150), "R": rgb(255, 170, 180), "B": rgb(215, 220, 245)]),
        "undersea_eel": SpriteSpec(grid: usMark(underseaEel, [(7, 5, "O"), (8, 6, "O"), (2, 6, "O"), (1, 7, "O"), (13, 10, "O"), (14, 11, "O"), (5, 12, "O")]),
                                   swap: ["Y": rgb(240, 220, 80), "c": rgb(190, 235, 215), "O": rgb(150, 235, 255), "R": rgb(220, 80, 70)]),
        "undersea_angler": SpriteSpec(grid: underseaAngler, swap: ["N": rgb(72, 62, 104), "n": rgb(50, 40, 76), "C": rgb(124, 104, 156), "R": rgb(200, 60, 90),
                                                             "l": rgb(110, 100, 130), "Y": rgb(255, 250, 150)]),
        "undersea_mermage": SpriteSpec(grid: usMark(underseaMerfolk, [
            (13, 0, "K"), (14, 0, "O"), (15, 0, "K"), (13, 1, "O"), (14, 1, "W"), (15, 1, "O"), (13, 2, "K"), (14, 2, "O"), (15, 2, "K"),
            (14, 3, "L"), (14, 4, "L"), (14, 5, "L"), (14, 6, "L"), (14, 7, "L"), (14, 8, "L"), (13, 9, "S"), (14, 9, "S"), (14, 10, "L"), (14, 11, "L"),
            (6, 1, "C"), (7, 0, "K"), (8, 0, "C"), (9, 1, "C"),
        ]), swap: ["H": rgb(150, 90, 200), "S": rgb(205, 228, 245), "C": rgb(110, 205, 225), "N": rgb(112, 82, 172), "n": rgb(72, 52, 122),
                   "F": rgb(185, 145, 240), "O": rgb(120, 255, 230), "L": rgb(120, 80, 50)]),
        "undersea_turtle": SpriteSpec(grid: usMark(underseaTurtle, [(4, 6, "X"), (8, 5, "X"), (9, 8, "X"), (3, 9, "X"), (6, 7, "X"), (10, 6, "X")]),
                                      swap: ["N": rgb(92, 140, 92), "n": rgb(60, 100, 70), "c": rgb(200, 180, 120), "C": rgb(230, 210, 150),
                                             "S": rgb(140, 190, 120), "R": rgb(200, 80, 80), "X": rgb(235, 230, 215)]),
        "undersea_ray": SpriteSpec(grid: underseaRay, swap: ["N": rgb(86, 80, 128), "n": rgb(54, 48, 84), "W": rgb(160, 255, 240)]),
        "undersea_urchin": SpriteSpec(grid: underseaUrchin, swap: ["N": rgb(124, 62, 146), "n": rgb(84, 38, 104), "x": rgb(204, 124, 224), "X": rgb(244, 206, 255),
                                                             "W": rgb(255, 240, 120)]),
        "undersea_shark": SpriteSpec(grid: underseaShark, swap: ["N": rgb(118, 138, 162), "C": rgb(230, 236, 242)]),
        "undersea_squid": SpriteSpec(grid: underseaSquid, swap: ["N": rgb(222, 92, 82), "n": rgb(160, 52, 62), "W": rgb(255, 240, 150)]),
        // Bosses: a turtle with a fortress on its back, and the sea-serpent empress with a cobra hood and a golden trident.
        "undersea_tortuga": SpriteSpec(grid: usMark(underseaTurtle, [
            (3, 0, "K"), (4, 0, "R"), (5, 0, "K"), (8, 0, "K"), (9, 0, "R"), (10, 0, "K"),
            (3, 1, "K"), (4, 1, "M"), (5, 1, "K"), (6, 1, "K"), (7, 1, "K"), (8, 1, "K"), (9, 1, "M"), (10, 1, "K"),
            (3, 2, "K"), (4, 2, "M"), (5, 2, "M"), (6, 2, "M"), (7, 2, "M"), (8, 2, "M"), (9, 2, "M"), (10, 2, "K"),
            (3, 3, "K"), (4, 3, "M"), (5, 3, "K"), (6, 3, "M"), (7, 3, "M"), (8, 3, "K"), (9, 3, "M"), (10, 3, "K"),
            (3, 4, "K"), (4, 4, "M"), (5, 4, "M"), (6, 4, "M"), (7, 4, "M"), (8, 4, "M"), (9, 4, "M"), (10, 4, "K"),
            (4, 6, "M"), (8, 6, "M"), (6, 8, "M"), (10, 8, "M"),
        ]), swap: ["N": rgb(124, 112, 92), "n": rgb(82, 72, 60), "c": rgb(196, 176, 136), "C": rgb(224, 206, 160), "S": rgb(100, 160, 110),
                   "R": rgb(220, 70, 60), "M": rgb(176, 176, 190)], boss: true),
        "undersea_naga": SpriteSpec(grid: usMark(underseaMerfolk, [
            (3, 2, "K"), (3, 3, "H"), (3, 4, "H"), (3, 5, "H"), (3, 6, "K"), (12, 2, "K"), (12, 3, "H"), (12, 4, "H"), (12, 5, "H"), (12, 6, "K"),
            (2, 3, "K"), (2, 4, "K"), (2, 5, "K"), (13, 3, "K"), (13, 4, "K"), (13, 5, "K"),
            (14, 0, "Y"), (13, 1, "Y"), (14, 1, "Y"), (15, 1, "Y"), (14, 2, "Y"), (14, 3, "Y"), (14, 4, "Y"), (14, 5, "Y"), (14, 6, "Y"), (14, 7, "Y"),
            (14, 8, "Y"), (13, 9, "S"), (14, 9, "S"), (14, 10, "Y"), (14, 11, "Y"),
        ]), swap: ["H": rgb(40, 118, 88), "S": rgb(165, 212, 172), "C": rgb(232, 190, 70), "N": rgb(62, 170, 110), "n": rgb(30, 110, 70),
                   "F": rgb(240, 200, 80), "Y": rgb(255, 214, 80)], boss: true),
    ]

    static let iconsUndersea: [String: [Character: CGColor]] = [
        "undersea_scale": ["B": rgb(120, 222, 204), "E": rgb(40, 140, 140)],
        "undersea_coral": ["B": rgb(255, 122, 122), "E": rgb(180, 50, 70)],
        "undersea_pearl": ["B": rgb(74, 64, 96), "E": rgb(30, 24, 42), "W": rgb(200, 180, 255)],
        "undersea_soup": ["B": rgb(92, 172, 92), "E": rgb(50, 110, 60)],
        "undersea_bubble": ["B": rgb(160, 232, 255), "E": rgb(60, 160, 220)],
        "undersea_song": ["B": rgb(255, 204, 222), "E": rgb(222, 130, 170)],
        "undersea_ring": ["B": rgb(122, 202, 232), "J": rgb(60, 120, 255)],
        "undersea_helmet": ["B": rgb(255, 142, 132), "J": rgb(255, 242, 205)],
        "undersea_boots": ["B": rgb(62, 172, 162), "J": rgb(122, 232, 255)],
        "undersea_amulet": ["B": rgb(240, 220, 160), "J": rgb(250, 246, 255)],
        "undersea_trident": ["B": rgb(232, 246, 255), "E": rgb(100, 170, 222), "G": rgb(240, 200, 80), "H": rgb(40, 90, 130), "J": rgb(122, 255, 222)],
        "undersea_staff": ["B": rgb(60, 122, 152), "G": rgb(232, 212, 122), "H": rgb(30, 70, 100), "O": rgb(100, 232, 255), "J": rgb(255, 255, 255)],
    ]
}

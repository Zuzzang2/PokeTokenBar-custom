import CoreGraphics
import Foundation

// 정글 대륙 (Lv10-30). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
// Monster stats follow the curve documented in `RpgCoastRegion.swift` (shipped monsters interpolated, per-behaviour factors).
//   frog 11 aggr · monkey 12 swarm · toucan 13 flyer · croc 15 charger · snake 16 aggr · flytrap 17 ranged · wasp 19 swarm
//   idol 20 tank · mosquito 21 flyer · toad 22 exploder · shaman 24 ranged · jaguar 25 charger · gorilla 26 tank · thunderbird 28 flyer
//   bosses: rafflesia 22 (30x HP), kongga 30 (40x HP). Signature gear spends the tier-3 accessory / tier-6 weapon / armor-5 budgets.

enum RpgJungleRegion {
    private static func door(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, gate: Int = 1) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func weapons(tier t: Int, _ chance: Double) -> [(String, Double)] { RpgClass.allCases.map { ("\($0.weaponPrefix)\(t)", chance) } }
    private static let books22 = ["book_w_cyclone", "book_a_trap", "book_m_pillar", "book_r_blades", "book_c_judge", "book_k_barrage", "book_s_drain"]
    private static let books28 = ["book_w_slam", "book_a_focus", "book_m_heal", "book_r_vanish", "book_c_purify", "book_k_iron", "book_s_dragon"]

    static let region = RpgRegion(
        id: "jungle", name: "정글 대륙", blurb: "덩굴이 삼킨 고대 신전 너머로 부족의 북소리가 울리는 밀림",
        minLevel: 8, entry: RpgMapID("jungle_1"), entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: RpgMapID("jungle_1"), name: "넝쿨 입구", levelText: "Lv10~13", width: 50, height: 30, kind: .forest, seed: 2001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), door(48, 15, "jungle_2", 4, 15, gate: 12)],
                      monsters: RpgMaps.sp([("jungle_frog", 11), ("jungle_monkey", 10), ("jungle_toucan", 8)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .tree, pool: .water, decor: .flower, tint: .init(r: 0.75, g: 1, b: 0.35), tintAlpha: 0.18,
                                      blend: .softLight),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("jungle_2"), name: "악어 강", levelText: "Lv12~16", width: 50, height: 30, kind: .field, seed: 2002,
                      portals: [door(1, 15, "jungle_1", 45, 15, gate: 8), door(48, 15, "jungle_3", 4, 15, gate: 15)],
                      monsters: RpgMaps.sp([("jungle_frog", 7), ("jungle_monkey", 8), ("jungle_toucan", 8), ("jungle_croc", 5)]),
                      theme: RpgTheme(floor: .grass, obstacle: .tree, pool: .water, decor: .water, tint: .init(r: 0.4, g: 0.8, b: 0.5), tintAlpha: 0.15, blend: .softLight)),
            RpgMapDef(id: RpgMapID("jungle_3"), name: "수관 위 폐허", levelText: "Lv15~19", width: 50, height: 30, kind: .forest, seed: 2003,
                      portals: [door(1, 15, "jungle_2", 45, 15, gate: 12), door(48, 15, "jungle_4", 4, 16, gate: 18)],
                      monsters: RpgMaps.sp([("jungle_croc", 5), ("jungle_snake", 10), ("jungle_flytrap", 7), ("jungle_wasp", 8)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .castleWall, pool: .water, decor: .flower, tint: .init(r: 0.3, g: 0.6, b: 0.3), tintAlpha: 0.2,
                                      blend: .multiply, darkness: 0.15),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("jungle_4"), name: "덩굴 신전", levelText: "Lv18~21", width: 50, height: 32, kind: .castle, seed: 2004,
                      portals: [door(1, 16, "jungle_3", 45, 15, gate: 15), door(48, 16, "jungle_5", 4, 15, gate: 20), door(25, 1, "jungle_b1", 14, 17, gate: 19)],
                      monsters: RpgMaps.sp([("jungle_flytrap", 7), ("jungle_wasp", 9), ("jungle_idol", 4), ("jungle_mosquito", 9)]),
                      theme: RpgTheme(tint: .init(r: 0.3, g: 0.8, b: 0.35), tintAlpha: 0.38, blend: .color, darkness: 0.45)),
            RpgMapDef(id: RpgMapID("jungle_5"), name: "독안개 늪", levelText: "Lv20~24", width: 50, height: 30, kind: .forest, seed: 2005,
                      portals: [door(1, 15, "jungle_4", 45, 16, gate: 18), door(48, 15, "jungle_6", 4, 15, gate: 23)],
                      monsters: RpgMaps.sp([("jungle_wasp", 9), ("jungle_idol", 4), ("jungle_mosquito", 10), ("jungle_toad", 4)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .tree, pool: .water, decor: .water, tint: .init(r: 0.7, g: 0.9, b: 0.2), tintAlpha: 0.45,
                                      blend: .color, darkness: 0.2),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("jungle_6"), name: "토템 광장", levelText: "Lv23~27", width: 50, height: 30, kind: .field, seed: 2006,
                      portals: [door(1, 15, "jungle_5", 45, 15, gate: 20), door(48, 15, "jungle_7", 4, 15, gate: 26)],
                      monsters: RpgMaps.sp([("jungle_toad", 4), ("jungle_shaman", 11), ("jungle_jaguar", 6), ("jungle_gorilla", 5)]),
                      theme: RpgTheme(floor: .grass, obstacle: .pillar, pool: .water, decor: .path, tint: .init(r: 1, g: 0.55, b: 0.25), tintAlpha: 0.25,
                                      blend: .overlay)),
            RpgMapDef(id: RpgMapID("jungle_7"), name: "천둥 폭포 동굴", levelText: "Lv26~29", width: 50, height: 30, kind: .cave, seed: 2007,
                      portals: [door(1, 15, "jungle_6", 45, 15, gate: 23), door(25, 1, "jungle_b2", 14, 17, gate: 27)],
                      monsters: RpgMaps.sp([("jungle_jaguar", 7), ("jungle_gorilla", 5), ("jungle_thunderbird", 13)]),
                      theme: RpgTheme(tint: .init(r: 0.3, g: 0.7, b: 1), tintAlpha: 0.35, blend: .color, darkness: 0.5), waypoint: true),
            RpgMapDef(id: RpgMapID("jungle_b1"), name: "식인화의 둥지", levelText: "보스 Lv22", width: 28, height: 22, kind: .boss, seed: 2008,
                      portals: [door(14, 20, "jungle_4", 25, 4, gate: 18)], monsters: RpgMaps.sp([("jungle_rafflesia", 1)]), zone: .forest,
                      theme: RpgTheme(tint: .init(r: 0.4, g: 0.75, b: 0.3), tintAlpha: 0.35, blend: .color)),
            RpgMapDef(id: RpgMapID("jungle_b2"), name: "대족장의 북 무대", levelText: "보스 Lv30", width: 28, height: 22, kind: .boss, seed: 2009,
                      portals: [door(14, 20, "jungle_7", 25, 4, gate: 26)], monsters: RpgMaps.sp([("jungle_kongga", 1)]), zone: .volcano,
                      theme: RpgTheme(tint: .init(r: 1, g: 0.5, b: 0.2), tintAlpha: 0.25, blend: .overlay)),
        ],
        monsters: [
            RpgMonsters.m("jungle_frog", "독화살 개구리", "jungle_frog", 11, 260, 34, 9, 44, 64, 22...34, .aggressive,
                          [("hp1", 0.1), ("jungle_leaf", 0.1), ("jungle_banana", 0.03), ("armor2", 0.01), ("dagger2", 0.008), ("stone", 0.055)]),
            RpgMonsters.m("jungle_monkey", "장난꾸러기 원숭이", "jungle_monkey", 12, 115, 28, 5, 64, 40, 13...20, .swarm,
                          [("hp1", 0.1), ("jungle_banana", 0.05), ("jungle_leaf", 0.05), ("stone", 0.035)]),
            RpgMonsters.m("jungle_toucan", "왕부리새", "jungle_toucan", 13, 245, 41, 8, 50, 83, 25...39, .flyer,
                          [("mp0", 0.12), ("jungle_leaf", 0.06), ("jungle_banana", 0.04), ("stone", 0.055)]),
            RpgMonsters.m("jungle_croc", "늪 악어", "jungle_croc", 15, 560, 54, 14, 34, 190, 50...80, .charger,
                          [("hp1", 0.1), ("jungle_fang", 0.08), ("armor3", 0.008), ("stone", 0.045)]),
            RpgMonsters.m("jungle_snake", "덩굴 뱀", "jungle_snake", 16, 500, 56, 16, 40, 185, 45...75, .aggressive,
                          [("hp1", 0.1), ("jungle_fang", 0.06), ("jungle_leaf", 0.06), ("rod2", 0.008), ("dagger4", 0.008), ("stone", 0.07)]),
            RpgMonsters.m("jungle_flytrap", "파리지옥", "jungle_flytrap", 17, 420, 56, 12, 12, 190, 50...75, .ranged,
                          [("mp0", 0.12), ("hp1", 0.06), ("jungle_leaf", 0.1), ("jungle_amber", 0.008), ("staff2", 0.008), ("stone", 0.07)]),
            RpgMonsters.m("jungle_wasp", "독침 말벌 떼", "jungle_wasp", 19, 265, 48, 10, 70, 125, 30...47, .swarm,
                          [("hp1", 0.1), ("jungle_amber", 0.006), ("stone", 0.045)]),
            RpgMonsters.m("jungle_idol", "이끼 낀 토템", "jungle_idol", 20, 1000, 71, 25, 20, 310, 70...110, .aggressive,
                          [("hp2", 0.06), ("jungle_amber", 0.02), ("armor5", 0.005), ("mace4", 0.006), ("claw4", 0.006), ("jungle_mask", 0.003), ("stone", 0.11)]
                          + books22.map { ($0, 0.004) }),
            RpgMonsters.m("jungle_mosquito", "흡혈 왕모기", "jungle_mosquito", 21, 580, 73, 16, 56, 265, 55...90, .flyer,
                          [("mp0", 0.1), ("hp2", 0.05), ("jungle_amber", 0.01), ("stone", 0.08)]),
            RpgMonsters.m("jungle_toad", "독두꺼비", "jungle_toad", 22, 520, 104, 12, 42, 380, 75...120, .exploder,
                          [("hp2", 0.1), ("jungle_leaf", 0.08), ("jungle_paint", 0.03), ("stone", 0.055)]),
            RpgMonsters.m("jungle_shaman", "원숭이 주술사", "jungle_shaman", 24, 750, 87, 20, 34, 395, 75...115, .ranged,
                          [("mp1", 0.06), ("hp2", 0.06), ("jungle_fang", 0.08), ("jungle_paint", 0.04), ("jungle_amulet", 0.003), ("staff6", 0.004), ("rod6", 0.004),
                           ("stone", 0.09)] + books22.map { ($0, 0.004) }),
            RpgMonsters.m("jungle_jaguar", "황금 재규어", "jungle_jaguar", 25, 1430, 103, 29, 50, 595, 105...165, .charger,
                          [("hp2", 0.1), ("jungle_fang", 0.1), ("jungle_boots", 0.003), ("claw6", 0.004), ("stone", 0.06)]),
            RpgMonsters.m("jungle_gorilla", "고릴라 전사", "jungle_gorilla", 26, 1610, 104, 37, 30, 550, 100...155, .aggressive,
                          [("hp2", 0.08), ("jungle_banana", 0.06), ("jungle_fang", 0.06), ("armor5", 0.006), ("sword6", 0.004), ("mace6", 0.004), ("jungle_ring", 0.003),
                           ("stone", 0.13)]),
            RpgMonsters.m("jungle_thunderbird", "천둥새", "jungle_thunderbird", 28, 1160, 112, 26, 58, 520, 85...135, .flyer,
                          [("mp1", 0.06), ("hp2", 0.06), ("jungle_amber", 0.015), ("bow6", 0.004), ("stone", 0.1)]),
            RpgMonsters.boss("jungle_rafflesia", "식인화 라플레시아", "jungle_rafflesia", 22, 26000, 114, 24, 24, 2425, 600...850, .skeleton,
                             minion: "jungle_snake", element: .poison,
                             [("hp2", 1), ("jungle_leaf", 1), ("jungle_leaf", 1), ("jungle_amber", 0.5), ("jungle_banana", 0.6), ("jungle_mask", 0.2), ("jungle_boots", 0.2),
                              ("armor5", 0.12)] + weapons(tier: 5, 0.04) + books22.map { ($0, 0.06) }),
            RpgMonsters.boss("jungle_kongga", "대족장 콩가", "jungle_kongga", 30, 81500, 193, 42, 38, 7320, 1400...2150, .yeti, minion: "jungle_shaman",
                             element: .thunder,
                             [("hp2", 1), ("jungle_fang", 1), ("jungle_fang", 1), ("jungle_amber", 0.7), ("jungle_paint", 0.6), ("jungle_bow", 0.2), ("jungle_claw", 0.2),
                              ("jungle_armor", 0.2), ("jungle_ring", 0.15), ("jungle_amulet", 0.15), ("jungle_mask", 0.15), ("jungle_boots", 0.15), ("armor6", 0.08),
                              ("armor5", 0.12), ("ring3", 0.05), ("amulet3", 0.05), ("helmet3", 0.05), ("boots3", 0.05)]
                             + weapons(tier: 6, 0.08) + weapons(tier: 7, 0.03) + books22.map { ($0, 0.08) } + books28.map { ($0, 0.04) }),
        ],
        items: [
            RpgItem(id: "jungle_leaf", name: "거대 정글잎", kind: .material, rarity: 0, attack: 0, defense: 0, heal: 0, price: 90, element: .base, inShop: false),
            RpgItem(id: "jungle_fang", name: "맹수의 송곳니", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 300, element: .base, inShop: false),
            RpgItem(id: "jungle_amber", name: "모기 든 호박석", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 1500, element: .base, inShop: false),
            RpgItem(id: "jungle_banana", name: "황금 바나나", kind: .potionHP, rarity: 1, attack: 0, defense: 0, heal: 420, price: 200, element: .base, inShop: false),
            RpgItem(id: "jungle_paint", name: "부족 전투 물감", kind: .buff("speed"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 400, element: .base, inShop: false),
            // Tier-3 accessories (Lv20-30), weapons between tier 6 and 7, armor between armor 5 and 6.
            RpgItem(id: "jungle_ring", name: "맹수 이빨 반지", kind: .ring, rarity: 2, attack: 0, defense: 0, heal: 0, price: 8000, element: .base, inShop: false,
                    bonusHP: 150, bonusCrit: 0.04, bonusAttack: 0.11),
            RpgItem(id: "jungle_amulet", name: "주술사의 뼈 목걸이", kind: .amulet, rarity: 2, attack: 0, defense: 12, heal: 0, price: 8000, element: .base, inShop: false,
                    bonusHP: 480, bonusMP: 50),
            RpgItem(id: "jungle_mask", name: "부족장의 가면", kind: .helmet, rarity: 2, attack: 0, defense: 12, heal: 0, price: 7500, element: .base, inShop: false, bonusHP: 220),
            RpgItem(id: "jungle_boots", name: "재규어 가죽 신발", kind: .boots, rarity: 2, attack: 0, defense: 5, heal: 0, price: 7500, element: .base, inShop: false,
                    bonusSpeed: 0.065),
            RpgItem(id: "jungle_bow", name: "독침 대나무 활", kind: .weapon(.archer), rarity: 2, attack: 48, defense: 0, heal: 0, price: 12000, element: .poison, inShop: false),
            RpgItem(id: "jungle_claw", name: "재규어 발톱 권갑", kind: .weapon(.monk), rarity: 2, attack: 50, defense: 0, heal: 0, price: 12000, element: .thunder, inShop: false),
            RpgItem(id: "jungle_armor", name: "덩굴 갑주", kind: .armor, rarity: 2, attack: 0, defense: 56, heal: 0, price: 20000, element: .base, inShop: false),
        ],
        // ponytail: generic band materials only (see the note in RpgCoastRegion.swift).
        recipes: [
            RpgRecipe(id: "jungle_ring", output: "jungle_ring", count: 1, materials: ["mat_sting": 8, "mat_ice": 5, "stone": 4], gold: 7000),
            RpgRecipe(id: "jungle_amulet", output: "jungle_amulet", count: 1, materials: ["mat_sting": 8, "mat_ice": 4, "stone": 4], gold: 6500),
            RpgRecipe(id: "jungle_mask", output: "jungle_mask", count: 1, materials: ["mat_bone": 8, "mat_sting": 6, "stone": 2], gold: 6000),
            RpgRecipe(id: "jungle_boots", output: "jungle_boots", count: 1, materials: ["mat_bone": 6, "mat_sting": 7, "stone": 2], gold: 6000),
            RpgRecipe(id: "jungle_bow", output: "jungle_bow", count: 1, materials: ["mat_sting": 10, "mat_ice": 6, "stone": 6], gold: 11000),
            RpgRecipe(id: "jungle_claw", output: "jungle_claw", count: 1, materials: ["mat_sting": 10, "mat_ice": 6, "stone": 6], gold: 11000),
            RpgRecipe(id: "jungle_armor", output: "jungle_armor", count: 1, materials: ["mat_sting": 10, "mat_ice": 8, "stone": 7], gold: 12000),
        ])
}

/// `top` drawn over `base` at column `x`, row `y`; dots in `top` keep the base pixel.
private func paint(_ base: RpgGrid, _ top: RpgGrid, x: Int = 0, y: Int = 0) -> RpgGrid {
    var rows = base.map { Array($0) }
    for (dy, line) in top.enumerated() {
        for (dx, ch) in line.enumerated() where ch != "." && rows.indices.contains(y + dy) && rows[y + dy].indices.contains(x + dx) { rows[y + dy][x + dx] = ch }
    }
    return rows.map { String($0) }
}
private func mirrored(_ g: RpgGrid) -> RpgGrid { g.map { String($0.reversed()) } }

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsJungle: [String: SpriteSpec] = [
        "jungle_frog": SpriteSpec(grid: jungleFrog, swap: ["G": rgb(60, 140, 230), "g": rgb(30, 70, 160)]),
        "jungle_monkey": SpriteSpec(grid: jungleMonkey, swap: ["H": rgb(140, 90, 50), "S": rgb(235, 195, 150)]),
        "jungle_toucan": SpriteSpec(grid: paint(coastBird, jungleBeak), swap: ["W": rgb(245, 240, 225), "Z": rgb(34, 30, 40), "z": rgb(20, 18, 26), "F": rgb(255, 150, 40)]),
        "jungle_croc": SpriteSpec(grid: jungleCroc, swap: ["G": rgb(80, 130, 64), "g": rgb(48, 86, 44)]),
        "jungle_snake": SpriteSpec(grid: jungleSnake, swap: ["G": rgb(110, 190, 60), "g": rgb(60, 120, 40), "Y": rgb(230, 220, 90)]),
        "jungle_flytrap": SpriteSpec(grid: junglePlant, swap: ["G": rgb(80, 170, 70), "R": rgb(220, 60, 80)]),
        "jungle_wasp": SpriteSpec(grid: jungleWasp, swap: ["Y": rgb(250, 200, 40), "W": rgb(215, 240, 255)]),
        "jungle_idol": SpriteSpec(grid: jungleTiki, swap: ["N": rgb(150, 112, 70), "n": rgb(104, 74, 44), "Q": rgb(255, 90, 40), "G": rgb(90, 160, 70)]),
        "jungle_mosquito": SpriteSpec(grid: jungleMosquito, swap: ["R": rgb(150, 40, 50), "r": rgb(70, 30, 40), "W": rgb(200, 230, 255), "M": rgb(110, 100, 90)]),
        "jungle_toad": SpriteSpec(grid: paint(jungleFrog, jungleToadSac), swap: ["G": rgb(130, 118, 64), "g": rgb(88, 76, 42), "t": rgb(96, 84, 40), "C": rgb(240, 200, 120)]),
        "jungle_shaman": SpriteSpec(grid: paint(jungleMonkey, jungleShamanMask), swap: ["H": rgb(110, 76, 56), "S": rgb(220, 180, 130), "Y": rgb(255, 220, 60)]),
        // The wolf grid faces left and this id has no "wolf" in it, so it is mirrored to face right like the other side views.
        "jungle_jaguar": SpriteSpec(grid: mirrored(paint(wolf, jungleSpots)), swap: ["Z": rgb(240, 166, 40), "z": rgb(186, 110, 30), "R": rgb(90, 220, 90)]),
        "jungle_gorilla": SpriteSpec(grid: jungleGorilla, swap: ["z": rgb(64, 60, 70), "S": rgb(140, 118, 106)]),
        "jungle_thunderbird": SpriteSpec(grid: paint(coastBird, coastCrest, y: 1),
                                         swap: ["W": rgb(130, 200, 255), "Z": rgb(40, 74, 170), "z": rgb(24, 44, 116), "Y": rgb(255, 230, 60), "R": rgb(255, 240, 90)]),
        "jungle_rafflesia": SpriteSpec(grid: junglePlant, swap: ["G": rgb(70, 130, 60), "R": rgb(200, 40, 60)], boss: true),
        "jungle_kongga": SpriteSpec(grid: paint(jungleGorilla, jungleWarPaint), swap: ["z": rgb(120, 116, 128), "S": rgb(150, 120, 100)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsJungle: [String: [Character: CGColor]] = [
        "jungle_leaf": ["B": rgb(90, 190, 80), "E": rgb(40, 110, 40)],
        "jungle_fang": ["B": rgb(245, 240, 220), "E": rgb(190, 170, 130)],
        "jungle_amber": ["B": rgb(255, 180, 50), "E": rgb(190, 100, 20)],
        "jungle_banana": ["B": rgb(250, 236, 90), "E": rgb(120, 170, 50)],
        "jungle_paint": ["B": rgb(70, 50, 50), "E": rgb(200, 50, 40)],
        "jungle_ring": ["B": rgb(200, 170, 120), "J": rgb(255, 240, 220)],
        "jungle_amulet": ["B": rgb(240, 230, 210), "J": rgb(200, 60, 60)],
        "jungle_mask": ["B": rgb(150, 112, 70), "J": rgb(220, 60, 50)],
        "jungle_boots": ["B": rgb(240, 170, 50), "J": rgb(60, 40, 30)],
        "jungle_bow": ["B": rgb(190, 200, 90), "G": rgb(90, 140, 50), "W": rgb(240, 240, 220)],
        "jungle_claw": ["B": rgb(250, 240, 210), "E": rgb(200, 180, 140), "G": rgb(240, 166, 40), "H": rgb(90, 60, 30)],
        "jungle_armor": ["B": rgb(80, 140, 60), "E": rgb(150, 100, 50)],
    ]

    // MARK: jungle body grids (side views face right)

    static let jungleFrog: RpgGrid = [
        "................", "................", "................", "..KKKK....KKKK..", ".KWWWWK..KWWWWK.", ".KWWKWK..KWKWWK.",
        ".KWWWWKKKKWWWWK.", "KGGKKGGGGGGKKGGK", "KGGGGGKGGGGGGGGK", "KgGGGGGGGGKGGGgK", ".KgKKKKKKKKKKgK.", ".KGGKGGGGGGGGGK.",
        "KGGKgGGGGKGgKGGK", "KGGGKgGGGGgKGGGK", "KKKKKKKKKKKKKKKK", "................",
    ]
    static let jungleMonkey: RpgGrid = [
        "................", "................", ".....KKKKKK.....", "...KKHHHHHHKK...", "..KSKHHHHHHKSK..", "..KSKSSSSSSKSK..",
        "...KSKSSSSKSK...", "....KSSKKSSK....", ".....KKSSKK.....", "....KHHHHHHK....", "...KSKHSSHKSK..K", "...KSKHSSHKSK.KH",
        "....KKHHHHKK.KHK", "....KHHKKHHKKHK.", "....KSSK.KSSKK..", "....KKK...KKK...",
    ]
    static let jungleCroc: RpgGrid = [
        "................", "................", "................", "................", "................", "...........KK...",
        "..K.K.K.K.KGWK..", ".KGKGKGKGKGGGKKK", "KGGGGGGGGGGGGGGK", "KgGGGGGGGGGWKWKK", ".KggggggggggKKKK", "..KgKKKKKgKK....",
        "..KgK...KgK.....", "..KKK...KKK.....", "................", "................",
    ]
    /// Also the aqueduct serpent's body (ancient region).
    static let jungleSnake: RpgGrid = [
        "................", "................", "..........KKKK..", ".........KGGGGK.", ".........KGWGGKK", ".........KGGGGGR",
        "..........KGGKKR", "...........KGK..", "...KKKKK...KGK..", "..KGGGGGK..KGK..", ".KGGKKKGGKKGGK..", ".KGK...KGGGGK...",
        ".KGGK...KKKK....", "..KGGKKKKKKKKK..", "...KgYgYgYgYgYK.", "....KKKKKKKKKK..",
    ]
    /// Also the spore cannon's body (mushroom region).
    static let junglePlant: RpgGrid = [
        "................", "...KKKKKK.......", "..KGGGGGGKK.....", ".KGGWGGGGGGK....", ".KGGRRRRRWKWK...", ".KGRRRRRRR......",
        ".KGRRRRRRR......", ".KGGRRRRRWKWK...", ".KGGGGWGGGGK....", "..KGGGGGGKK.....", "...KKKKgK.......", "....KKgGK.KK....",
        "...KGGKgKKGGK...", "..KGGGGKgKGGGGK.", "..KKKKKKKKKKKKK.", "................",
    ]
    /// Also the firefly's body (mushroom region).
    static let jungleWasp: RpgGrid = [
        "................", "................", "................", "......KKK.KKK...", ".....KWWWKWWWK..", ".....KWWWWWWWK..",
        "......KKWWWKK...", "...KKKKKKKKKKKK.", "..KYYKKYYKKYYKYK", "KKKYYKKYYKKYKYYK", "..KYYKKYYKKYYKKK", "...KKKKKKKKKKK..",
        ".....K.K.K.K....", "................", "................", "................",
    ]
    static let jungleGorilla: RpgGrid = [
        "................", ".....KKKKKK.....", "....KzzzzzzK....", "...KzzzzzzzzK...", "...KzKSSSSKzK...", "...KzSKSSKSzK...",
        "..KKzSSSSSSzKK..", ".KzzKSSKKSSKzzK.", "KzzzzKSSSSKzzzzK", "KzzzzzzzzzzzzzzK", "KzzKzzzzzzzzKzzK", "KzzKzzSSSSzzKzzK",
        "KSSKzzzzzzzzKSSK", "KSSKzzzKKzzzKSSK", ".KKKzzzK.KzzzKK.", "....KKKK.KKKK...",
    ]
    static let jungleTiki: RpgGrid = [
        "....KKKKKKKK....", "...KNGNNNGGNK...", "..KNnNNNNNNnNK..", "..KNKKKNNKKKNK..", "..KNKQKNNKQKNK..", "..KNNKNNNNKNNK..",
        "..KNNNNKKNNNNK..", "..KNKKKKKKKKNK..", "..KNKWWWWWWKNK..", "..KNKKKKKKKKNK..", "..KNNNNGNNNNNK..", ".KKNnNNNNNNnNKK.",
        "KNNKNNNNNNNNKNNK", "KnnKNNnnnnNNKnnK", ".KKKNNNNNNNNKKK.", "...KKKKKKKKKK...",
    ]
    static let jungleMosquito: RpgGrid = [
        "................", "................", "....KK..KK......", "...KWWKKWWK.....", "...KWWWWWWK.....", "....KWWWWK......",
        "........KK.KKK..", ".KKKKKKKMMKRWK..", "KRrRrRrKMMKRRKKK", ".KKKKKKKMKKKKK..", "......K.K.K.....", ".....K..K..K....",
        "....K...K...K...", "...K....K....K..", "................", "................",
    ]

    private static let jungleBeak: RpgGrid = ["................", "................", "................", "..............K.", ".............KFK", "............KFFF",
                                             "............KFFK", "..............K."]
    private static let jungleToadSac: RpgGrid = [
        "................", "................", "................", "................", "................", "................",
        "................", "...t........t...", "......t...t.....", "..t..........t..", "....KKKKKKKK....", "...KCCCCCCCCK...",
        "..KCCWCCCCCCCK..", "..KCCCCCCCCCCK..",
    ]
    private static let jungleShamanMask: RpgGrid = ["..R..Y..R..Y....", "..KRKYKKRKKYK...", "...KRYRYRYRK....", "....KWWWWWWK....", "....KWKWWKWK....",
                                                   "....KWRWWRWK....", "....KWWKKWWK....", ".....KKWWKK....."]
    private static let jungleSpots: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                              "..K..K....K.....", ".....K..K...K...", "...K....K..K....", "..........K....."]
    private static let jungleWarPaint: RpgGrid = ["................", "................", "................", "................", ".......RR.......", "................",
                                                 ".....R....R.....", "................", "................", "...X.X.XX.X.X..."]
}

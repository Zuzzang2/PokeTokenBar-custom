import CoreGraphics
import Foundation

// 혼돈의 궁전 (Lv88-100), the hardest content: the blood-red gate, a hall of living chess pieces, the twisted banquet, the
// endless stair (the Mad Queen's tea room, Lv97), the burning garden, the mirror maze and the heart of chaos, where the
// Emperor of Chaos waits — the strongest regular boss in the game (Lv100). Owned by exactly one author; see `RpgRegions.swift`.
//
// Balance — the same curves as the frost region (see `RpgFrostRegion.swift`): normals on the power-law fits of the built-in
// Lv58-100 monsters of their behaviour, ±6% per-monster tilts; the region is hard because it packs chargers, exploders and
// casters together, not because its numbers leave the curve:
//   behaviour      Lv88 HP/ATK/DEF/XP          Lv94                        Lv100
//   aggressive     33.5k/614/217/15.4k         39.0k/668/236/19.7k         45.0k/724/255/24.7k   (heavy: ×1.3 HP and DEF, ×1.05 ATK, ×1.2 XP)
//   ranged         26.9k/614/153/15.4k         31.4k/669/167/19.4k         36.2k/725/182/24.2k
//   flyer          28.5k/553/153/14.2k         33.2k/602/167/17.7k         38.3k/653/181/21.6k
//   charger        35.2k/615/218/19.3k         41.0k/670/237/24.6k         47.3k/726/257/30.9k
//   swarm          13.4k/369/ 87/8.3k          15.6k/401/ 95/10.5k         17.9k/434/102/13.2k
//   exploder       16.8k/767/109/16.2k         19.5k/836/119/20.9k         22.5k/907/130/26.6k
// Bosses: the Mad Queen Lv97 on the built-in late-boss curve (2.46M HP / 1020 ATK / 1.52M XP, half the built-in loot rates);
// the Emperor of Chaos Lv100 sits above the Lv100 void lord on every stat (3.1M / 1150 / 275 DEF / 2.2M XP vs 2.6M / 1050 /
// 255 / 1.79M) and drops the full built-in loot table plus its own.
// Gear: weapon tier 11/12 at Lv<92/≥92, armor and accessories tier 10/11 at Lv<89/≥89. Signature gear keeps the tier-11/12
// budget with a different spread; weapons stay at the tier-12 attack of 380.

enum RpgChaosRegion {
    static let region = RpgRegion(id: "chaos", name: "혼돈의 궁전",
                                  blurb: "체스 말이 걸어 다니고 복도가 뒤틀리는 궁전 깊은 곳에서 혼돈의 황제가 옥좌를 지켜요.",
                                  minLevel: 86, entry: RpgMapID("chaos_1"), entryTile: RpgTile(x: 4, y: 15),
                                  maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static func p(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, _ gate: Int) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    // MARK: maps

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: RpgMapID("chaos_1"), name: "핏빛 정문", levelText: "Lv88~92", width: 50, height: 30, kind: .volcano, seed: 14001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), p(48, 15, "chaos_2", 4, 16, 90)],
                  monsters: RpgMaps.sp([("chaos_card", 6), ("chaos_pawn", 6), ("chaos_jester", 4), ("chaos_crown", 1)]),
                  theme: RpgTheme(tint: tint(0.9, 0.2, 0.25), tintAlpha: 0.5, blend: .color, darkness: 0.3), waypoint: true),
        RpgMapDef(id: RpgMapID("chaos_2"), name: "체스판 대전당", levelText: "Lv90~94", width: 50, height: 32, kind: .castle, seed: 14002,
                  portals: [p(1, 16, "chaos_1", 45, 15, 86), p(48, 16, "chaos_3", 4, 16, 91)],
                  monsters: RpgMaps.sp([("chaos_pawn", 4), ("chaos_knight", 5), ("chaos_rook", 4), ("chaos_bishop", 4)]),
                  theme: RpgTheme(tint: tint(0.55, 0.55, 0.6), tintAlpha: 0.75, blend: .color, darkness: 0.35)),
        RpgMapDef(id: RpgMapID("chaos_3"), name: "뒤틀린 연회장", levelText: "Lv91~95", width: 50, height: 32, kind: .castle, seed: 14003,
                  portals: [p(1, 16, "chaos_2", 45, 16, 90), p(48, 16, "chaos_4", 4, 15, 93)],
                  monsters: RpgMaps.sp([("chaos_jester", 5), ("chaos_knight", 4), ("chaos_dice", 4), ("chaos_gargoyle", 4)]),
                  theme: RpgTheme(tint: tint(0.75, 0.25, 0.8), tintAlpha: 0.55, blend: .color, darkness: 0.4), waypoint: true),
        RpgMapDef(id: RpgMapID("chaos_4"), name: "무한 계단", levelText: "Lv93~97", width: 48, height: 30, kind: .cave, seed: 14004,
                  portals: [p(1, 15, "chaos_3", 45, 16, 91), p(46, 15, "chaos_5", 4, 15, 94), p(24, 1, "chaos_b1", 14, 17, 93)],
                  monsters: RpgMaps.sp([("chaos_dice", 4), ("chaos_gargoyle", 4), ("chaos_hound", 4), ("chaos_mirror", 4)]),
                  theme: RpgTheme(tint: tint(0.9, 0.15, 0.2), tintAlpha: 0.5, blend: .color, darkness: 0.7)),
        RpgMapDef(id: RpgMapID("chaos_5"), name: "불타는 정원", levelText: "Lv94~98", width: 48, height: 30, kind: .forest, seed: 14005,
                  portals: [p(1, 15, "chaos_4", 43, 15, 93), p(46, 15, "chaos_6", 4, 16, 96)],
                  monsters: RpgMaps.sp([("chaos_gargoyle", 4), ("chaos_hound", 4), ("chaos_witch", 5), ("chaos_chimera", 4)]),
                  theme: RpgTheme(tint: tint(1.0, 0.35, 0.15), tintAlpha: 0.5, blend: .color, darkness: 0.2), waypoint: true),
        RpgMapDef(id: RpgMapID("chaos_6"), name: "거울 미궁", levelText: "Lv96~100", width: 50, height: 32, kind: .castle, seed: 14006,
                  portals: [p(1, 16, "chaos_5", 43, 15, 94), p(48, 16, "chaos_7", 4, 15, 98)],
                  monsters: RpgMaps.sp([("chaos_mirror", 6), ("chaos_witch", 4), ("chaos_chimera", 4), ("chaos_lord", 4)]),
                  theme: RpgTheme(tint: tint(0.5, 0.9, 1.0), tintAlpha: 0.5, blend: .color, darkness: 0.35)),
        RpgMapDef(id: RpgMapID("chaos_7"), name: "혼돈의 심장", levelText: "Lv98~100", width: 50, height: 30, kind: .volcano, seed: 14007,
                  portals: [p(1, 15, "chaos_6", 45, 16, 96), p(25, 1, "chaos_b2", 14, 17, 98)],
                  monsters: RpgMaps.sp([("chaos_imp", 6), ("chaos_chimera", 4), ("chaos_lord", 5), ("chaos_witch", 4)]),
                  theme: RpgTheme(tint: tint(0.7, 0.1, 0.4), tintAlpha: 0.6, blend: .color, darkness: 0.55), waypoint: true),
        RpgMapDef(id: RpgMapID("chaos_b1"), name: "미친 여왕의 다과회", levelText: "보스 Lv97", width: 28, height: 22, kind: .boss, seed: 14008,
                  portals: [p(14, 20, "chaos_4", 24, 4, 93)], monsters: RpgMaps.sp([("chaos_queen", 1)]), zone: .castle,
                  theme: RpgTheme(tint: tint(0.9, 0.3, 0.5), tintAlpha: 0.5, blend: .color, darkness: 0.5)),
        RpgMapDef(id: RpgMapID("chaos_b2"), name: "혼돈의 옥좌", levelText: "보스 Lv100", width: 28, height: 22, kind: .boss, seed: 14009,
                  portals: [p(14, 20, "chaos_7", 25, 4, 98)], monsters: RpgMaps.sp([("chaos_emperor", 1)]), zone: .volcano,
                  theme: RpgTheme(tint: tint(0.6, 0.1, 0.3), tintAlpha: 0.6, blend: .color, darkness: 0.6)),
    ]

    // MARK: monsters

    private static let monsters: [RpgMonsterDef] = {
        let m = RpgMonsters.m
        var list: [RpgMonsterDef] = [
            m("chaos_card", "카드 병정떼", "chaos_card", 88, 13400, 370, 87, 64, 8350, 935...1350, .swarm, [("hp5", 0.1), ("staff11", 0.004), ("dagger11", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.18), ("chaos_ember", 0.05)]),
            m("chaos_pawn", "혼돈의 폰", "chaos_pawn", 89, 29600, 500, 198, 28, 15300, 1730...2450, .passive, [("hp5", 0.08), ("mace11", 0.004), ("claw11", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.282), ("chaos_ember", 0.06), ("chaos_wine", 0.02)]),
            m("chaos_jester", "광기의 광대", "chaos_jester", 90, 28350, 630, 158, 36, 16650, 1970...2850, .ranged, [("hp5", 0.08), ("mp3", 0.08), ("rod11", 0.004), ("sword11", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.284), ("chaos_ember", 0.06), ("chaos_draught", 0.02)]),
            m("chaos_crown", "도망치는 왕관", "chaos_crown", 90, 24650, 0, 257, 56, 21800, 7900...11300, .coward, [("hp5", 0.1), ("stone", 0.3), ("chaos_ember", 0.5), ("chaos_wine", 0.3), ("chaos_draught", 0.2), ("chaos_helm", 0.01)]),
            m("chaos_knight", "흑마 나이트", "chaos_knight", 91, 38050, 670, 218, 46, 21800, 2425...3500, .charger, [("hp5", 0.1), ("dagger11", 0.004), ("mace11", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.186), ("chaos_ember", 0.05)]),
            m("chaos_dice", "혼돈의 주사위", "chaos_dice", 92, 18550, 815, 116, 50, 19250, 2080...3000, .exploder, [("hp5", 0.1), ("claw12", 0.004), ("rod12", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.188), ("chaos_ember", 0.05), ("chaos_wine", 0.03)]),
            m("chaos_rook", "룩 성채병", "chaos_rook", 93, 51650, 665, 318, 22, 22950, 2580...3700, .aggressive, [("hp5", 0.08), ("sword12", 0.004), ("bow12", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.29), ("chaos_ember", 0.06), ("chaos_boots", 0.002)]),
            m("chaos_bishop", "광신 비숍", "chaos_bishop", 94, 31350, 670, 167, 32, 19400, 2200...3150, .ranged, [("hp5", 0.08), ("mp3", 0.08), ("staff12", 0.004), ("dagger12", 0.004), ("armor11", 0.004), ("ring11", 0.004), ("stone", 0.292), ("chaos_ember", 0.06), ("chaos_draught", 0.02)]),
            m("chaos_gargoyle", "뒤틀린 가고일", "chaos_gargoyle", 95, 34050, 610, 169, 56, 18300, 2165...3100, .flyer, [("hp5", 0.08), ("mp3", 0.08), ("mace12", 0.004), ("claw12", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.294), ("chaos_essence", 0.06)]),
            m("chaos_hound", "혼돈의 사냥개", "chaos_hound", 96, 43050, 690, 243, 46, 26550, 2775...4000, .charger, [("hp5", 0.1), ("rod12", 0.004), ("sword12", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.196), ("chaos_essence", 0.05), ("chaos_wine", 0.02)]),
            m("chaos_mirror", "거울 망령", "chaos_mirror", 97, 35750, 630, 174, 58, 19600, 2280...3250, .flyer, [("hp5", 0.08), ("mp3", 0.08), ("bow12", 0.004), ("staff12", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.298), ("chaos_essence", 0.06), ("chaos_amulet", 0.002)]),
            m("chaos_witch", "혼돈의 마녀", "chaos_witch", 98, 34550, 705, 177, 34, 22500, 2440...3500, .ranged, [("hp5", 0.08), ("mp3", 0.08), ("dagger12", 0.004), ("mace12", 0.004), ("armor11", 0.004), ("ring11", 0.004), ("stone", 0.3), ("chaos_essence", 0.06), ("chaos_draught", 0.03), ("chaos_ring", 0.002)]),
            m("chaos_chimera", "혼돈 키메라", "chaos_chimera", 99, 57400, 755, 332, 26, 29250, 3020...4300, .aggressive, [("hp5", 0.08), ("claw12", 0.004), ("rod12", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.302), ("chaos_essence", 0.06), ("chaos_draught", 0.02)]),
            m("chaos_imp", "꼬마 악마떼", "chaos_imp", 99, 17550, 430, 101, 68, 12700, 1255...1800, .swarm, [("hp5", 0.1), ("sword12", 0.004), ("bow12", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.202), ("chaos_essence", 0.04), ("chaos_wine", 0.02)]),
            m("chaos_lord", "혼돈 군주", "chaos_lord", 100, 44950, 725, 255, 40, 24700, 2575...3700, .aggressive, [("hp5", 0.08), ("staff12", 0.004), ("dagger12", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.304), ("chaos_essence", 0.06), ("chaos_helm", 0.002)]),
        ]
        list.append(RpgMonsters.boss("chaos_queen", "미친 여왕 레드", "chaos_queen", 97, 2_462_000, 1020, 243, 38, 1_521_000, 126_500...210_500, .skeleton,
                                     minion: "chaos_card", element: .fire,
                                     RpgMonsters.endgameBossLoot(weapon: 12, armor: [11, 10], gear: 11, rate: 0.5)
                                         + [("chaos_crownshard", 1), ("chaos_amulet", 0.12), ("chaos_boots", 0.12), ("chaos_ember", 1), ("chaos_ember", 1),
                                            ("chaos_wine", 0.5), ("hp5", 1)]))
        list.append(RpgMonsters.boss("chaos_emperor", "혼돈의 황제 카오스", "chaos_emperor", 100, 3_100_000, 1150, 275, 40, 2_200_000, 160_000...270_000, .demon,
                                     minion: "chaos_hound", element: .thunder,
                                     RpgMonsters.endgameBossLoot(weapon: 12, armor: [11, 10], gear: 11, rate: 1)
                                         + [("chaos_heart", 1), ("chaos_claw", 0.12), ("chaos_sword", 0.12), ("chaos_ring", 0.1), ("chaos_helm", 0.1),
                                            ("chaos_essence", 1), ("chaos_essence", 1), ("chaos_essence", 1), ("hp5", 1), ("mp3", 1)]))
        return list
    }()

    // MARK: items

    private static let items: [RpgItem] = [
        RpgItem(id: "chaos_ember", name: "혼돈의 불씨", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 22000, element: .base, inShop: false),
        RpgItem(id: "chaos_essence", name: "혼돈의 정수", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 30000, element: .base, inShop: false),
        RpgItem(id: "chaos_crownshard", name: "미친 여왕의 왕관 조각", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 70000, element: .base, inShop: false),
        RpgItem(id: "chaos_heart", name: "황제의 혼돈 심장", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 120_000, element: .base, inShop: false),
        RpgItem(id: "chaos_wine", name: "광기의 포도주", kind: .buff("xp"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1600, element: .base, inShop: false),
        RpgItem(id: "chaos_draught", name: "혼돈의 영약", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 9000, price: 6800, element: .base, inShop: false),
        // Tier 11 helmet (4600 HP / 150) → more HP, less plate: 1.26 + 0.74.
        RpgItem(id: "chaos_helm", name: "광대왕의 가면 투구", kind: .helmet, rarity: 4, attack: 0, defense: 111, heal: 0, price: 1_500_000, element: .base, inShop: false,
                bonusHP: 5800),
        // Tier 11 boots (14% / 105) → the knight's move: 1.21 + 0.79.
        RpgItem(id: "chaos_boots", name: "체스판 장화", kind: .boots, rarity: 4, attack: 0, defense: 83, heal: 0, price: 1_500_000, element: .base, inShop: false,
                bonusSpeed: 0.17),
        // Tier 11 ring (4300 HP / 18% / 50%) → crits: 0.56 + 1.67 + 0.78.
        RpgItem(id: "chaos_ring", name: "광기의 반지", kind: .ring, rarity: 4, attack: 0, defense: 0, heal: 0, price: 1_600_000, element: .base, inShop: false,
                bonusHP: 2400, bonusCrit: 0.30, bonusAttack: 0.39),
        // Tier 11 amulet (6500 HP / 1200 MP / 190) → life first: 1.29 + 0.75 + 0.96.
        RpgItem(id: "chaos_amulet", name: "혼돈의 목걸이", kind: .amulet, rarity: 4, attack: 0, defense: 182, heal: 0, price: 1_600_000, element: .base, inShop: false,
                bonusHP: 8400, bonusMP: 900),
        // The tier-12 attack (380, cosmic) with another element; nothing in this region beats the real top tier.
        RpgItem(id: "chaos_claw", name: "혼돈의 권갑", kind: .weapon(.monk), rarity: 4, attack: 380, defense: 0, heal: 0, price: 800_000, element: .thunder, inShop: false),
        RpgItem(id: "chaos_sword", name: "황제의 혼돈검", kind: .weapon(.warrior), rarity: 4, attack: 380, defense: 0, heal: 0, price: 800_000, element: .fire, inShop: false),
    ]

    // MARK: recipes (the smith)

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "chaos_helm", output: "chaos_helm", count: 1, materials: ["chaos_ember": 22, "chaos_crownshard": 1, "stone": 40], gold: 1_500_000),
        RpgRecipe(id: "chaos_boots", output: "chaos_boots", count: 1, materials: ["chaos_ember": 20, "chaos_essence": 8, "stone": 40], gold: 1_500_000),
        RpgRecipe(id: "chaos_ring", output: "chaos_ring", count: 1, materials: ["chaos_essence": 22, "chaos_heart": 1, "mat_void": 14, "stone": 50], gold: 1_600_000),
        RpgRecipe(id: "chaos_amulet", output: "chaos_amulet", count: 1, materials: ["chaos_essence": 20, "chaos_crownshard": 1, "mat_void": 12, "stone": 45], gold: 1_600_000),
        RpgRecipe(id: "chaos_claw", output: "chaos_claw", count: 1, materials: ["chaos_heart": 2, "chaos_essence": 26, "mat_void": 16, "stone": 50], gold: 800_000),
        RpgRecipe(id: "chaos_sword", output: "chaos_sword", count: 1, materials: ["chaos_heart": 2, "chaos_essence": 26, "mat_void": 16, "stone": 50], gold: 800_000),
        RpgRecipe(id: "chaos_draught", output: "chaos_draught", count: 2, materials: ["chaos_ember": 1], gold: 4000),
    ]
}

// MARK: art

extension RpgArt {
    static let chaosCard: RpgGrid = [
        "................", ".....KKKKKK.....", "....KWWWWWWK....", "....KWRWWWWK....", "....KWWSSWWK....", "....KWSKSKWK....",
        "...KKWWSSWWKK...", "..KSKWWRRWWKSK..", "..KSKWRRRRWKSK..", "....KWWRRWWK....", "....KWWWWWRK....", "....KWWWWWWK....",
        ".....KKKKKK.....", ".....KMK.KMK....", ".....KMK.KMK....", ".....KK..KK.....",
    ]
    static let chaosPawn: RpgGrid = [
        "................", "................", "................", "......KKKK......", ".....KWWWWK.....", "....KWWWWWWK....",
        "....KWGWWGWK....", "....KWWWWWWK....", ".....KWWWWK.....", "......KWWK......", ".....KWWWWK.....", ".....KWwWWK.....",
        "....KKKKKKKK....", "...KWWWWWWWWK...", "..KWwWWWWWWwWK..", "..KKKKKKKKKKKK..",
    ]
    static let chaosJester: RpgGrid = [
        ".Y............Y.", ".KK..........KK.", ".KRK........KPK.", "..KRK.KKKK.KPK..", "...KRKRRPPKPK...", "....KRRRPPPK....",
        "....KKKKKKKK....", "....KWWWWWWK....", "....KWKWWKWK....", "....KWWRRWWK....", "..KKKKWWWWKKKK..", ".KRPKRRPPRPKPRK.",
        ".KWKKPRRPPRKKWK.", "....KRRKKPPK....", "....KPPK.KRRK...", "....KKKK.KKKK...",
    ]
    static let chaosCrown: RpgGrid = [
        "................", "................", "................", "..K..K..K..K..K.", ".KYK.KYKKYK.KYK.", ".KYYKYYYYYYKYYK.",
        ".KYRYYYBYYYYRYK.", ".KYYYYYYYYYYYYK.", ".KYYKYYYYKYYYYK.", ".KYYYYYKKYYYYYK.", ".KyyyyyyyyyyyyK.", "..KKKKKKKKKKKK..",
        "....KYK..KYK....", "....KYK..KYK....", "....KK....KK....", "................",
    ]
    static let chaosKnight: RpgGrid = [
        "................", "......KKK.......", ".....KWWWKK.....", "....KWWRWWWK....", "...KWWWWWWWWK...", "..KWWWWWWWWWWK..",
        ".KWWWKKKKWWWK...", ".KWK.....KWWK...", "........KWWWK...", ".......KWWWWKK..", "......KWWwWWMK..", ".....KWWWWWWMK..",
        "....KKKKKKKKKK..", "...KWWWWWWWWWWK.", "..KWwWWWWWWWWwWK", "..KKKKKKKKKKKKKK",
    ]
    static let chaosRook: RpgGrid = [
        "................", "..KKK.KKKK.KKK..", "..KWK.KWWK.KWK..", "..KWKKKWWKKKWK..", "..KWWWWWWWWWWK..", "...KKKKKKKKKK...",
        "...KWWWWWWWWK...", "...KWRKWWKRWK...", "...KWWWWWWWWK...", "...KWWKKKKWWK...", "...KWWWWWWWWK...", "...KWwWWWWwWK...",
        "..KKKKKKKKKKKK..", "..KWWWWWWWWWWK..", ".KWwWWWWWWWWwWK.", ".KKKKKKKKKKKKKK.",
    ]
    static let chaosDice: RpgGrid = [
        "................", "................", "......KKKK......", "....KKWWWWKK....", "..KKWWRWWWWWKK..", ".KwKKWWWWWWKKWK.",
        ".KwwwKKWWKKWWWK.", ".KwRwwwKKWWRWWK.", ".KwwwwwKWWWWWWK.", ".KwwRwwKWRKKRWK.", ".KwwwwwKWWWWWWK.", ".KwwwRwKWRKKRWK.",
        "..KKwwwKWWWWKK..", "....KKwKWWKK....", "......KKKK......", "................",
    ]
    static let chaosMirror: RpgGrid = [
        ".....KKKKKK.....", "....KYYYYYYK....", "...KYKKKKKKYK...", "...KYKOOOOKYK...", "..KYKOWOOOOKYK..", "..KYKOKOOKOKYK..",
        "..KYKOOOOOOKYK..", "..KYKOOKKOOKYK..", "..KYKOORROOKYK..", "..KYKOOKKOOKYK..", "..KYKOOOOOWKYK..", "..KYKOOOOOOKYK..",
        "...KYKKKKKKYK...", "....KKYYYYKK....", ".....KyyyyK.....", "......KKKK......",
    ]
    static let chaosLord: RpgGrid = [
        ".K............K.", "KXK..........KXK", "KXXK.KKKKKK.KXXK", ".KXXKZZZZZZKXXK.", "..KKZZZZZZZZKK..", "...KZYKZZKYZK...",
        "...KZZZZZZZZK...", "...KZZKWWKZZK...", "..KRKZZZZZZKRK..", ".KRRKKAAAAKKRRK.", ".KRRKAAYYAAKRRK.", "KRRRKAAAAAAKRRRK",
        "KRRKAAAAAAAAKRRK", "KRKKAAKKKKAAKKRK", ".K.KAAK..KAAK.K.", "...KKKK..KKKK...",
    ]
    static let chaosQueen: RpgGrid = [
        "................", "....KKKKKK......", "...KHHHHHHK.....", "..KHHHKKHHHK....", "..KHHKSSKHHK....", "...KKSSSSKK.....",
        "...KSKSSKSK.....", "...KSSRRSSK.....", "....KSSSSK......", "...KKWWWWKK.....", "..KWWKWWKWWK....", "..KWWYWWYWWK....",
        ".KWwWWWWWWwWK...", ".KWWWWWWWWWWK...", "KWwWWWWWWWWwWK..", "KKKKKKKKKKKKKK..",
    ]
    static let chaosImp: RpgGrid = [
        "................", "................", "....K......K....", "...KXK....KXK...", "....KXKKKKXK....", ".K..KRRRRRRK..K.",
        "KAK.KRYRRYRK.KAK", "KAAKKRRRRRRKKAAK", "KAAAKKRWWRKKAAAK", ".KAAKRRRRRRKAAK.", "..KKKRRRRRRKKK..", "....KrRRRRrK.KK.",
        ".....KRKKRK.KRK.", ".....KK..KK..KK.", "................", "................",
    ]

    /// Bishop: the pawn under a split mitre.
    private static let chaosBishop = endgameStamp(chaosPawn, [".......KK.......", "......KWRK......", ".....KWRWWK.....", ".....KRWWWK.....", "....KYYYYYYK...."])
    /// Gargoyle: the bat as a horned, tailed stone thing.
    private static let chaosGargoyle = endgameStamp(bat, [
        "................", "......K..K......", ".....KXKKXK.....", "................", "................", "................",
        "................", "................", "................", "................", "................", ".......KK.......",
        "........KAK.....", ".........KK.....",
    ])
    /// Hound of chaos: the wolf turned right, horned, with a burning mane.
    private static let chaosHound = endgameMirror(endgameStamp(wolf, ["...KK...........", "..KXXK..........", "...KXK.f.f......", "....KFfFfFf.....", "....KFFFFFF....."]))
    /// Witch of chaos: horns through the hat.
    private static let chaosWitch = endgameStamp(mage, [".KK..........KK.", "KXXK........KXXK", ".KXXK......KXXK.", "..KXK......KXK.."])
    /// Chimera: the lion with goat horns and a snake for a tail.
    private static let chaosChimera = endgameStamp(celestialLion, [
        ".........KK..KK.", "........KXK.KXK.", ".........KXKXK..", "................", "................", "................",
        "................", "................", "................", "KGGK............", "KgK.............", "KGK.............",
        ".KGK............", "..KK............",
    ])

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsChaos: [String: SpriteSpec] = [
        "chaos_card": SpriteSpec(grid: chaosCard, swap: ["W": rgb(250, 250, 245), "R": rgb(210, 40, 50), "S": rgb(244, 196, 152), "M": rgb(60, 50, 70)]),
        "chaos_pawn": SpriteSpec(grid: chaosPawn, swap: ["W": rgb(40, 36, 50), "w": rgb(24, 20, 30), "G": rgb(255, 60, 80)]),
        "chaos_jester": SpriteSpec(grid: chaosJester, swap: ["R": rgb(210, 40, 60), "P": rgb(110, 60, 200), "W": rgb(250, 250, 250), "Y": rgb(255, 214, 80)]),
        "chaos_crown": SpriteSpec(grid: chaosCrown, swap: ["Y": rgb(255, 214, 80), "y": rgb(210, 150, 40), "R": rgb(230, 40, 60), "B": rgb(90, 170, 255)]),
        "chaos_knight": SpriteSpec(grid: chaosKnight, swap: ["W": rgb(40, 36, 50), "w": rgb(24, 20, 30), "R": rgb(255, 60, 80), "M": rgb(220, 40, 60)]),
        "chaos_dice": SpriteSpec(grid: chaosDice, swap: ["W": rgb(250, 250, 250), "w": rgb(200, 200, 210), "R": rgb(210, 40, 60)]),
        "chaos_rook": SpriteSpec(grid: chaosRook, swap: ["W": rgb(236, 232, 226), "w": rgb(170, 164, 160), "R": rgb(220, 40, 60)]),
        "chaos_bishop": SpriteSpec(grid: chaosBishop, swap: ["W": rgb(40, 36, 50), "w": rgb(24, 20, 30), "G": rgb(255, 60, 80), "R": rgb(210, 40, 60),
                                                             "Y": rgb(255, 214, 80)]),
        "chaos_gargoyle": SpriteSpec(grid: chaosGargoyle, swap: ["A": rgb(120, 120, 135), "a": rgb(80, 80, 95), "W": rgb(255, 80, 60), "X": rgb(200, 200, 210)]),
        "chaos_hound": SpriteSpec(grid: chaosHound, swap: ["R": rgb(255, 200, 60), "Z": rgb(70, 30, 40), "z": rgb(40, 14, 24), "X": rgb(240, 226, 200),
                                                           "F": rgb(255, 120, 40), "f": rgb(255, 210, 90)]),
        "chaos_mirror": SpriteSpec(grid: chaosMirror, swap: ["Y": rgb(255, 214, 80), "y": rgb(200, 140, 40), "O": rgb(150, 230, 255), "W": rgb(255, 255, 255),
                                                             "R": rgb(255, 60, 120)]),
        "chaos_witch": SpriteSpec(grid: chaosWitch, swap: ["P": rgb(120, 20, 40), "p": rgb(70, 10, 24), "S": rgb(200, 190, 220), "Y": rgb(255, 60, 80),
                                                           "X": rgb(240, 226, 200)]),
        "chaos_chimera": SpriteSpec(grid: chaosChimera, swap: ["Y": rgb(120, 90, 60), "y": rgb(80, 60, 40), "T": rgb(200, 170, 110), "t": rgb(150, 120, 70),
                                                               "X": rgb(240, 226, 200), "G": rgb(90, 160, 60), "g": rgb(50, 100, 40)]),
        "chaos_imp": SpriteSpec(grid: chaosImp, swap: ["R": rgb(200, 40, 50), "r": rgb(130, 20, 30), "X": rgb(240, 226, 200), "Y": rgb(255, 214, 80), "A": rgb(90, 30, 50)]),
        "chaos_lord": SpriteSpec(grid: chaosLord, swap: ["R": rgb(170, 30, 40), "r": rgb(110, 16, 24), "Z": rgb(60, 40, 60), "Y": rgb(255, 214, 80), "A": rgb(90, 70, 100),
                                                         "X": rgb(240, 226, 200)]),
        "chaos_queen": SpriteSpec(grid: chaosQueen, swap: ["W": rgb(230, 40, 60), "w": rgb(150, 20, 40), "H": rgb(255, 120, 60), "S": rgb(250, 230, 220),
                                                           "R": rgb(255, 255, 255), "Y": rgb(255, 214, 80)], boss: true),
        "chaos_emperor": SpriteSpec(grid: chaosLord, swap: ["R": rgb(40, 20, 60), "r": rgb(20, 10, 34), "Z": rgb(110, 20, 40), "Y": rgb(255, 230, 90),
                                                            "A": rgb(30, 24, 40), "X": rgb(255, 214, 80), "W": rgb(255, 255, 255)], boss: true),
    ]

    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsChaos: [String: [Character: CGColor]] = [
        "chaos_ember": ["B": rgb(255, 120, 60), "E": rgb(140, 20, 40)],
        "chaos_essence": ["B": rgb(220, 60, 120), "E": rgb(60, 14, 50)],
        "chaos_crownshard": ["B": rgb(255, 214, 80), "E": rgb(230, 40, 60)],
        "chaos_heart": ["B": rgb(255, 80, 100), "E": rgb(40, 10, 30)],
        "chaos_wine": ["B": rgb(170, 30, 80), "E": rgb(90, 10, 40)],
        "chaos_draught": ["B": rgb(255, 90, 140), "E": rgb(120, 30, 160)],
        "chaos_helm": ["B": rgb(250, 250, 250), "J": rgb(210, 40, 60), "W": rgb(110, 60, 200)],
        "chaos_boots": ["B": rgb(40, 36, 50), "J": rgb(250, 250, 250), "W": rgb(255, 255, 255)],
        "chaos_ring": ["B": rgb(255, 214, 80), "J": rgb(230, 40, 60), "W": rgb(255, 255, 255)],
        "chaos_amulet": ["B": rgb(60, 40, 60), "J": rgb(255, 60, 80), "W": rgb(255, 255, 255)],
        "chaos_claw": ["B": rgb(60, 40, 70), "E": rgb(255, 230, 90), "G": rgb(170, 30, 40), "H": rgb(30, 14, 30), "O": rgb(170, 30, 40), "W": rgb(255, 255, 160)],
        "chaos_sword": ["B": rgb(255, 120, 60), "E": rgb(150, 20, 40), "G": rgb(60, 40, 60), "H": rgb(30, 14, 30), "J": rgb(255, 214, 80)],
    ]
}

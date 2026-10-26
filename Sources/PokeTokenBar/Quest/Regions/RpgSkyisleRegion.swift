import CoreGraphics
import Foundation

// 하늘 섬 (Lv35-57): floating islands above the clouds (not the late 천공의 섬), seven islands in a chain from the 차원문, the griffin queen
// (Lv47) off island 4 and the storm lord (Lv57) off island 7. Monsters use the same fitted curve and behaviour ratios as `RpgCrystalRegion`:
//   Lv35 3203/164/54/1082/245 · Lv45 5710/246/83/1977/405 · Lv55 9059/339/118/3201/605 (base HP/attack/defense/XP/gold).
// Everything stays below Lv58: the content checks count Lv58+ monsters as the late game (sprite == id, exactly six late bosses).
// Bosses: HP 98× base, the rest on the shipped boss curve (see `RpgCrystalRegion`). Gear: accessories on the tier-6 budget (wind ring: more crit, less HP;
// feather boots: tier-8 speed with little defense), weapons 112 attack (tier 7 is 84, tier 8 130).
// Recipes take the region's own materials plus gold and stones; the materials also sell, priced so a kill here is worth ~8% more
// than a main-line kill of its level (4-14% by monster).

enum RpgSkyisleRegion {
    private static let s1 = RpgMapID("skyisle_1"), s2 = RpgMapID("skyisle_2"), s3 = RpgMapID("skyisle_3"), s4 = RpgMapID("skyisle_4")
    private static let s5 = RpgMapID("skyisle_5"), s6 = RpgMapID("skyisle_6"), s7 = RpgMapID("skyisle_7")
    private static let b1 = RpgMapID("skyisle_b1"), b2 = RpgMapID("skyisle_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { .init(r: r / 255, g: g / 255, b: b / 255) }

    static let region = RpgRegion(id: "skyisle", name: "하늘 섬", blurb: "구름 위를 떠도는 섬마다 그리핀의 바람이 불어요.", minLevel: 33,
                                  entry: s1, entryTile: RpgTile(x: 4, y: 15), maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: s1, name: "구름 선착장", levelText: "Lv35~38", width: 50, height: 30, kind: .field, seed: 7001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), RpgMaps.p(48, 15, s2, 4, 14, minLevel: 38)],
                  monsters: RpgMaps.sp([("skyisle_puff", 9), ("skyisle_sparrow", 8), ("skyisle_sheep", 5)]),
                  theme: RpgTheme(tint: tint(120, 230, 200), tintAlpha: 0.25), waypoint: true),
        RpgMapDef(id: s2, name: "민들레 언덕", levelText: "Lv38~41", width: 48, height: 28, kind: .field, seed: 7002,
                  portals: [RpgMaps.p(1, 14, s1, 45, 15, minLevel: 33), RpgMaps.p(46, 14, s3, 4, 15, minLevel: 41)],
                  monsters: RpgMaps.sp([("skyisle_sparrow", 7), ("skyisle_sheep", 5), ("skyisle_kite", 7), ("skyisle_harpy", 6)]),
                  theme: RpgTheme(tint: tint(255, 225, 120), tintAlpha: 0.3)),
        RpgMapDef(id: s3, name: "새벽 구름바다", levelText: "Lv41~44", width: 50, height: 30, kind: .snow, seed: 7003,
                  portals: [RpgMaps.p(1, 15, s2, 43, 14, minLevel: 38), RpgMaps.p(48, 15, s4, 4, 16, minLevel: 44)],
                  monsters: RpgMaps.sp([("skyisle_kite", 7), ("skyisle_harpy", 7), ("skyisle_griffin", 7)]),
                  theme: RpgTheme(obstacle: .iceRock, pool: .water, tint: tint(255, 190, 225), tintAlpha: 0.22), waypoint: true),
        RpgMapDef(id: s4, name: "바람의 신전", levelText: "Lv44~47", width: 50, height: 32, kind: .castle, seed: 7004,
                  portals: [RpgMaps.p(1, 16, s3, 45, 15, minLevel: 41), RpgMaps.p(48, 16, s5, 4, 15, minLevel: 47), RpgMaps.p(25, 1, b1, 14, 17, minLevel: 45)],
                  monsters: RpgMaps.sp([("skyisle_griffin", 6), ("skyisle_chick", 2), ("skyisle_statue", 6), ("skyisle_thunder", 4)]),
                  theme: RpgTheme(tint: tint(200, 255, 240), tintAlpha: 0.5, blend: .overlay, darkness: 0.08)),
        RpgMapDef(id: s5, name: "그리핀 둥지 절벽", levelText: "Lv47~50", width: 50, height: 30, kind: .desert, seed: 7005,
                  portals: [RpgMaps.p(1, 15, s4, 45, 16, minLevel: 44), RpgMaps.p(48, 15, s6, 4, 15, minLevel: 50)],
                  monsters: RpgMaps.sp([("skyisle_statue", 6), ("skyisle_thunder", 4), ("skyisle_gull", 8)]),
                  theme: RpgTheme(obstacle: .rock, pool: .water, tint: tint(255, 150, 100), tintAlpha: 0.25), waypoint: true),
        RpgMapDef(id: s6, name: "뇌운층", levelText: "Lv50~53", width: 48, height: 30, kind: .snow, seed: 7006,
                  portals: [RpgMaps.p(1, 15, s5, 45, 15, minLevel: 47), RpgMaps.p(46, 15, s7, 4, 16, minLevel: 53)],
                  monsters: RpgMaps.sp([("skyisle_gull", 7), ("skyisle_rider", 5), ("skyisle_stormharpy", 7)]),
                  theme: RpgTheme(obstacle: .iceRock, pool: .water, tint: tint(90, 100, 170), tintAlpha: 0.45, blend: .multiply, darkness: 0.3)),
        RpgMapDef(id: s7, name: "천둥 첨탑", levelText: "Lv53~56", width: 50, height: 32, kind: .castle, seed: 7007,
                  portals: [RpgMaps.p(1, 16, s6, 43, 15, minLevel: 50), RpgMaps.p(25, 1, b2, 14, 17, minLevel: 55)],
                  monsters: RpgMaps.sp([("skyisle_rider", 5), ("skyisle_stormharpy", 7), ("skyisle_whale", 7)]),
                  theme: RpgTheme(tint: tint(150, 110, 255), tintAlpha: 0.45, darkness: 0.4), waypoint: true),
        RpgMapDef(id: b1, name: "그리핀 여왕의 둥지", levelText: "보스 Lv47", width: 28, height: 22, kind: .boss, seed: 7008,
                  portals: [RpgMaps.p(14, 20, s4, 25, 4, minLevel: 44)], monsters: RpgMaps.sp([("skyisle_griffinqueen", 1)]), zone: .desert,
                  theme: RpgTheme(tint: tint(255, 200, 120), tintAlpha: 0.25, darkness: 0.15)),
        RpgMapDef(id: b2, name: "뇌우의 왕좌", levelText: "보스 Lv57", width: 28, height: 22, kind: .boss, seed: 7009,
                  portals: [RpgMaps.p(14, 20, s7, 25, 4, minLevel: 53)], monsters: RpgMaps.sp([("skyisle_thunderbird", 1)]), zone: .snow,
                  theme: RpgTheme(tint: tint(110, 110, 200), tintAlpha: 0.4, blend: .multiply, darkness: 0.3)),
    ]

    private static let monsters: [RpgMonsterDef] = [
        RpgMonsters.m("skyisle_puff", "솜사탕 구름", "skyisle_puff", 35, 2800, 156, 54, 30, 1080, 190...275, .passive,
                      [("hp3", 0.05), ("skyisle_feather", 0.08), ("skyisle_tea", 0.04), ("sword7", 0.004), ("bow7", 0.004), ("armor6", 0.004), ("stone", 0.115)]),
        RpgMonsters.m("skyisle_sparrow", "깃털 참새떼", "skyisle_sparrow", 37, 1150, 128, 29, 70, 605, 105...150, .swarm,
                      [("hp2", 0.1), ("skyisle_feather", 0.08), ("stone", 0.07)]),
        RpgMonsters.m("skyisle_sheep", "박치기 솜양", "skyisle_sheep", 38, 4550, 199, 60, 46, 1670, 255...370, .charger,
                      [("hp2", 0.1), ("skyisle_feather", 0.08), ("stone", 0.071)]),
        RpgMonsters.m("skyisle_kite", "바람연 정령", "skyisle_kite", 40, 3050, 203, 56, 60, 1390, 225...320, .flyer,
                      [("hp3", 0.05), ("mp1", 0.08), ("skyisle_feather", 0.08), ("skyisle_tea", 0.04), ("staff7", 0.004), ("dagger7", 0.004), ("armor6", 0.004), ("stone", 0.13)]),
        RpgMonsters.m("skyisle_harpy", "깃털 하피", "skyisle_harpy", 42, 3900, 227, 59, 38, 1680, 290...415, .ranged,
                      [("hp3", 0.05), ("mp1", 0.08), ("skyisle_feather", 0.08), ("skyisle_tea", 0.04), ("book_w_slam", 0.003), ("book_a_focus", 0.003), ("book_m_heal", 0.003), ("book_r_vanish", 0.003), ("mace7", 0.004), ("claw7", 0.004), ("armor6", 0.004), ("stone", 0.136)]),
        RpgMonsters.m("skyisle_griffin", "새끼 그리핀", "skyisle_griffin", 44, 5000, 237, 80, 44, 1870, 300...435, .aggressive,
                      [("hp3", 0.05), ("skyisle_feather", 0.08), ("skyisle_cloud", 0.06), ("skyisle_tea", 0.04), ("skyisle_scroll", 0.01), ("book_c_purify", 0.003), ("book_k_iron", 0.003), ("book_s_dragon", 0.003), ("rod7", 0.004), ("bow7", 0.004), ("armor6", 0.004), ("stone", 0.142)]),
        RpgMonsters.m("skyisle_statue", "하늘 수호 석상", "skyisle_statue", 46, 6600, 254, 91, 22, 2130, 355...515, .aggressive,
                      [("hp3", 0.05), ("skyisle_cloud", 0.08), ("skyisle_gem", 0.01), ("skyisle_tea", 0.04), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001), ("book_r_ult", 0.001), ("sword7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("stone", 0.178)]),
        RpgMonsters.m("skyisle_thunder", "번개 먹구름", "skyisle_thunder", 48, 3650, 351, 48, 52, 2540, 345...495, .exploder,
                      [("hp3", 0.1), ("skyisle_cloud", 0.06), ("stone", 0.081)]),
        RpgMonsters.m("skyisle_gull", "폭풍 갈매기", "skyisle_gull", 49, 4850, 282, 79, 58, 2260, 335...480, .flyer,
                      [("hp3", 0.05), ("mp1", 0.08), ("skyisle_cloud", 0.06), ("skyisle_tea", 0.04), ("dagger7", 0.004), ("mace7", 0.004), ("armor6", 0.004), ("stone", 0.157)]),
        RpgMonsters.m("skyisle_rider", "그리핀 기사", "skyisle_rider", 52, 9400, 328, 104, 46, 3550, 480...690, .charger,
                      [("hp3", 0.1), ("skyisle_cloud", 0.06), ("skyisle_gem", 0.01), ("stone", 0.085)]),
        RpgMonsters.m("skyisle_stormharpy", "폭풍 하피", "skyisle_stormharpy", 53, 6650, 329, 89, 36, 2930, 460...665, .ranged,
                      [("hp3", 0.05), ("mp1", 0.08), ("skyisle_cloud", 0.06), ("skyisle_gem", 0.01), ("skyisle_tea", 0.04), ("skyisle_scroll", 0.01), ("claw7", 0.004), ("rod7", 0.004), ("armor6", 0.004), ("armor7", 0.002), ("claw8", 0.0015), ("rod8", 0.0015), ("stone", 0.169)]),
        RpgMonsters.m("skyisle_whale", "구름 고래", "skyisle_whale", 55, 9950, 339, 124, 26, 3260, 510...735, .aggressive,
                      [("hp3", 0.05), ("skyisle_cloud", 0.08), ("skyisle_gem", 0.02), ("skyisle_tea", 0.04), ("skyisle_halo", 0.003), ("skyisle_featherboots", 0.003), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001), ("book_r_ult", 0.001), ("book_c_ult", 0.001), ("book_k_ult", 0.001), ("book_s_ult", 0.001), ("bow7", 0.004), ("sword7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("armor7", 0.002), ("bow8", 0.0015), ("sword8", 0.0015), ("staff8", 0.0015), ("stone", 0.205)]),
        RpgMonsters.m("skyisle_chick", "황금 깃털 병아리", "skyisle_chick", 45, 4550, 0, 50, 52, 2570, 1995...2865, .coward,
                      [("hp3", 0.3), ("skyisle_feather", 0.5), ("skyisle_cloud", 0.3), ("skyisle_scroll", 0.12), ("stone", 0.3)]),
        RpgMonsters.boss("skyisle_griffinqueen", "그리핀 여왕 하늘깃", "skyisle_griffinqueen", 47, 620000, 384, 82, 40, 44000, 13300...20000, .yeti, minion: "skyisle_sparrow", element: .wind,
                         [("skyisle_feather", 1), ("skyisle_feather", 1), ("skyisle_cloud", 0.6), ("skyisle_gem", 0.35), ("skyisle_halo", 0.12), ("skyisle_featherboots", 0.12), ("skyisle_scroll", 0.3), ("skyisle_tea", 1), ("sword7", 0.07), ("bow7", 0.07), ("staff7", 0.07), ("dagger7", 0.07), ("mace7", 0.07), ("claw7", 0.07), ("rod7", 0.07), ("armor6", 0.15), ("book_w_ult", 0.03), ("book_a_ult", 0.03), ("book_m_ult", 0.03), ("book_r_ult", 0.03), ("book_c_ult", 0.03), ("book_k_ult", 0.03), ("book_s_ult", 0.03), ("hp3", 1)]),
        RpgMonsters.boss("skyisle_thunderbird", "뇌우의 군주 썬더버드", "skyisle_thunderbird", 57, 965000, 491, 108, 40, 85000, 29700...44500, .demon, minion: "skyisle_gull", element: .thunder,
                         [("skyisle_gem", 1), ("skyisle_gem", 0.5), ("skyisle_cloud", 1), ("skyisle_cloud", 1), ("skyisle_bow", 0.15), ("skyisle_dagger", 0.15), ("skyisle_rod", 0.15), ("skyisle_windring", 0.12), ("skyisle_amulet", 0.12), ("skyisle_halo", 0.08), ("skyisle_featherboots", 0.08), ("sword8", 0.05), ("bow8", 0.05), ("staff8", 0.05), ("dagger8", 0.05), ("mace8", 0.05), ("claw8", 0.05), ("rod8", 0.05), ("armor7", 0.12), ("ring6", 0.06), ("amulet6", 0.06), ("book_w_ult", 0.05), ("book_a_ult", 0.05), ("book_m_ult", 0.05), ("book_r_ult", 0.05), ("book_c_ult", 0.05), ("book_k_ult", 0.05), ("book_s_ult", 0.05), ("hp3", 1)]),
    ]

    private static let items: [RpgItem] = [
        RpgItem(id: "skyisle_feather", name: "그리핀 깃털", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 900, element: .base, inShop: false),
        RpgItem(id: "skyisle_cloud", name: "뭉게구름 솜", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 1620, element: .base, inShop: false),
        RpgItem(id: "skyisle_gem", name: "바람의 결정", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 4500, element: .base, inShop: false),
        RpgItem(id: "skyisle_tea", name: "구름 꿀차", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 2200, price: 1400, element: .base, inShop: false),
        RpgItem(id: "skyisle_scroll", name: "순풍의 두루마리", kind: .buff("xp"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1500, element: .base, inShop: false),
        RpgItem(id: "skyisle_windring", name: "순풍의 반지", kind: .ring, rarity: 4, attack: 0, defense: 0, heal: 0, price: 110_000, element: .base, inShop: false,
                bonusHP: 500, bonusCrit: 0.14, bonusAttack: 0.18),
        RpgItem(id: "skyisle_amulet", name: "구름 깃털 목걸이", kind: .amulet, rarity: 4, attack: 0, defense: 42, heal: 0, price: 105_000, element: .base, inShop: false,
                bonusHP: 1000, bonusMP: 520),
        RpgItem(id: "skyisle_halo", name: "천사의 고리", kind: .helmet, rarity: 4, attack: 0, defense: 26, heal: 0, price: 100_000, element: .base, inShop: false, bonusHP: 1500),
        RpgItem(id: "skyisle_featherboots", name: "바람깃 장화", kind: .boots, rarity: 4, attack: 0, defense: 15, heal: 0, price: 105_000, element: .base, inShop: false, bonusSpeed: 0.11),
        RpgItem(id: "skyisle_bow", name: "그리핀 깃 활", kind: .weapon(.archer), rarity: 3, attack: 112, defense: 0, heal: 0, price: 95000, element: .wind, inShop: false),
        RpgItem(id: "skyisle_dagger", name: "번개깃 단검", kind: .weapon(.rogue), rarity: 3, attack: 112, defense: 0, heal: 0, price: 95000, element: .thunder, inShop: false),
        RpgItem(id: "skyisle_rod", name: "구름 정령 소환봉", kind: .weapon(.summoner), rarity: 3, attack: 112, defense: 0, heal: 0, price: 95000, element: .holy, inShop: false),
    ]

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "skyisle_windring", output: "skyisle_windring", count: 1, materials: ["skyisle_feather": 12, "skyisle_cloud": 8, "stone": 10], gold: 100_000),
        RpgRecipe(id: "skyisle_amulet", output: "skyisle_amulet", count: 1, materials: ["skyisle_feather": 12, "skyisle_cloud": 7, "stone": 8], gold: 95000),
        RpgRecipe(id: "skyisle_halo", output: "skyisle_halo", count: 1, materials: ["skyisle_feather": 10, "skyisle_cloud": 7, "stone": 6], gold: 90000),
        RpgRecipe(id: "skyisle_featherboots", output: "skyisle_featherboots", count: 1, materials: ["skyisle_feather": 12, "skyisle_cloud": 7, "stone": 6], gold: 95000),
        RpgRecipe(id: "skyisle_bow", output: "skyisle_bow", count: 1, materials: ["skyisle_cloud": 10, "skyisle_gem": 3, "stone": 12], gold: 90000),
        RpgRecipe(id: "skyisle_dagger", output: "skyisle_dagger", count: 1, materials: ["skyisle_cloud": 10, "skyisle_gem": 3, "stone": 12], gold: 90000),
        RpgRecipe(id: "skyisle_rod", output: "skyisle_rod", count: 1, materials: ["skyisle_cloud": 10, "skyisle_gem": 3, "stone": 12], gold: 90000),
        RpgRecipe(id: "skyisle_tea", output: "skyisle_tea", count: 3, materials: ["skyisle_feather": 1, "skyisle_cloud": 1], gold: 1200),
    ]
}

extension RpgArt {
    static let skyisleCloud: RpgGrid = [
        "................", "................", "................", "................", "......KKKK......", "....KKWWWWK.....",
        "...KWWWWWWWKKK..", "..KWWWWWWWWWWWK.", ".KWWWWWWWWWWWWBK", "KWWWWKWWWWKWWWBK", "KWWWWWWWWWWWWWBK", "KBWWWWWKKWWWWBBK",
        ".KBBWWWWWWWWBBK.", "..KKBBBBBBBBKK..", "....KKKKKKKK....", "................",
    ]
    static let skyisleBird: RpgGrid = [
        "................", "................", "................", "................", "................", "......KKKK......",
        ".....KTTTTK.....", "....KTTTTKTK....", "....KTTTTTTKKK..", "...KTTTTTTTKYYK.", "..KtTTTTTTTTKK..", ".KttTTTCCCCTK...",
        ".KKtttCCCCCK....", "...KKKKKKKK.....", ".....KY.KY......", ".....K..K.......",
    ]
    static let skyisleSheep: RpgGrid = [
        "................", "................", "................", "................", "......KKKK......", "....KKWWWWKK....",
        "...KWWWWWWWWKKK.", "..KWWWWWWWWWKzzK", ".KWWWWWWWWWWKzKz", ".KWWWWWWWWWWKzzK", ".KBWWWWWWWWWBKK.", "..KBBBWWWWBBBK..",
        "...KKKKKKKKKK...", "....KzK..KzK....", "....KzK..KzK....", "....KKK..KKK....",
    ]
    static let skyisleGriffin: RpgGrid = [
        "................", "...........KKK..", "..........KWWWK.", "..KKK....KWWKWKK", ".KTTTK...KWWWWYK", ".KTTTTK.KWWWWKKK",
        "..KTTTTKKWWWWK..", "...KKTTTKWWWK...", "..KTTKTTTTTTK...", ".KtTTTTTTTTTTK..", "KtKTTTTTTTTTTK..", "Kt.KtTTTTTTTtK..",
        "K...KtKKKKKtK...", "....KtK...KtK...", "....KYK...KYK...", "....KKK...KKK...",
    ]
    static let skyisleEagle: RpgGrid = [
        "................", "................", "................", "KK............KK", "KBK..........KBK", "KBBK...KKK..KBBK",
        "KBBBK.KWWWKKBBBK", ".KBBBKWWKWYKBBK.", "..KBBBWWWWKBBBK.", "...KBBBWWBBBBK..", "....KBBBBBBBK...", ".....KBBBBBK....",
        "......KBKBK.....", "......KY.YK.....", "................", "................",
    ]
    static let skyisleWhale: RpgGrid = [
        "................", "................", "................", ".KK.............", "KZZK....KKKKK...", "KZZZK.KKZZZZZKK.",
        ".KZZZKZZZZZZZZZK", "..KZZZZZZZZZZKZK", "..KZZZZZZZZZZZZK", ".KZZZZZZZZZZZZZK", "KZZKBBBBBBBBBBBK", "KZK.KBBBBBBBBBK.",
        ".K...KKBBBBBKK..", ".......KKKKK....", "................", "................",
    ]
    static let skyisleHarpy: RpgGrid = [
        "................", ".K..............", "KTK.......KKK...", "KTTK.....KHHHK..", "KTTTK...KHHSSK..", ".KTTTK.KHHSKSKK.",
        ".KTtTTKKHHSSSK..", "..KTtTTKKKSSK...", "..KTTtTTKCCCK...", "...KTTtTKCCCCK..", "....KKTTKCCCCK..", "......KKTTTTK...",
        "......KTTTTTTK..", ".......KYKKYK...", ".......KYK.KYK..", ".......KK..KK...",
    ]
    static let skyisleKite: RpgGrid = [
        ".......KK.......", "......KRRK......", ".....KRRYRK.....", "....KRRRYRRK....", "...KRRRRYRRRK...", "..KRRKKRYKKRRK..",
        ".KRRKWWKYKWKRRK.", "KYYYYYYYYYYYYYYK", "KRRRKWWKYKWKRRRK", ".KRRRKKRYKKRRRK.", "..KRRRRRYRRRRK..", "...KRRRRYRRRK...",
        "....KRRRYRRK....", ".....KRRYRK.....", "......KRRKK.....", ".......KK.KfK...",
    ]

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsSkyisle: [String: SpriteSpec] = [
        "skyisle_puff": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleCloud, [(4, 10, "Q"), (11, 10, "Q")]), swap: ["W": rgb(255, 248, 252), "B": rgb(238, 198, 228), "Q": rgb(255, 160, 192)]),
        "skyisle_sparrow": SpriteSpec(grid: skyisleBird, swap: [:]),
        "skyisle_sheep": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleSheep, [(12, 5, "K"), (13, 5, "c"), (12, 6, "c"), (13, 6, "K"), (14, 6, "c"), (11, 7, "c")]), swap: ["c": rgb(214, 186, 140)]),
        "skyisle_kite": SpriteSpec(grid: skyisleKite, swap: [:]),
        "skyisle_harpy": SpriteSpec(grid: skyisleHarpy, swap: [:]),
        "skyisle_griffin": SpriteSpec(grid: skyisleGriffin, swap: [:]),
        "skyisle_chick": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleBird, [(7, 4, "K"), (8, 4, "K"), (8, 3, "T")]), swap: ["T": rgb(255, 222, 92), "t": rgb(226, 166, 42), "C": rgb(255, 248, 202), "Y": rgb(255, 142, 42)]),
        "skyisle_statue": SpriteSpec(grid: RpgCrystalRegion.mark(golem, [(0, 0, "K"), (1, 0, "K"), (0, 1, "K"), (1, 1, "B"), (2, 1, "B"), (3, 1, "K"), (0, 2, "K"), (1, 2, "B"), (2, 2, "b"), (3, 2, "B"), (4, 2, "K"), (0, 3, "K"), (1, 3, "B"), (2, 3, "b"), (3, 3, "K"), (1, 4, "K"), (2, 4, "K"), (14, 0, "K"), (15, 0, "K"), (12, 1, "K"), (13, 1, "B"), (14, 1, "B"), (15, 1, "K"), (11, 2, "K"), (12, 2, "B"), (13, 2, "b"), (14, 2, "B"), (15, 2, "K"), (12, 3, "K"), (13, 3, "b"), (14, 3, "B"), (15, 3, "K"), (13, 4, "K"), (14, 4, "K")]), swap: ["N": rgb(226, 224, 214), "n": rgb(168, 164, 154), "Q": rgb(110, 222, 255), "B": rgb(250, 250, 255), "b": rgb(200, 210, 225)]),
        "skyisle_thunder": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleCloud, [(4, 8, "K"), (5, 8, "K"), (10, 8, "K"), (11, 8, "K"), (5, 9, "Y"), (10, 9, "Y"), (8, 13, "Y"), (7, 14, "Y"), (8, 14, "Y"), (6, 15, "Y")]), swap: ["W": rgb(124, 126, 154), "B": rgb(84, 84, 112), "Y": rgb(255, 236, 80)]),
        "skyisle_gull": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleEagle, [(0, 3, "K"), (1, 3, "K"), (0, 4, "K"), (1, 4, "z"), (14, 3, "K"), (15, 3, "K"), (14, 4, "z"), (15, 4, "K")]), swap: ["B": rgb(184, 190, 202), "W": rgb(252, 252, 255), "Y": rgb(255, 172, 42), "z": rgb(70, 72, 84)]),
        "skyisle_rider": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleGriffin, [(11, 1, "M"), (12, 1, "M"), (13, 1, "K"), (11, 0, "R"), (12, 0, "R"), (10, 2, "K"), (11, 2, "M"), (5, 7, "R"), (6, 7, "R"), (7, 7, "R"), (5, 8, "R")]), swap: ["T": rgb(152, 122, 92), "t": rgb(102, 78, 56), "W": rgb(232, 232, 242), "M": rgb(172, 182, 204), "R": rgb(204, 52, 62)]),
        "skyisle_stormharpy": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleHarpy, [(10, 1, "Y"), (12, 1, "Y"), (10, 2, "K"), (11, 2, "Y"), (12, 2, "K")]), swap: ["T": rgb(88, 98, 152), "t": rgb(56, 62, 106), "H": rgb(222, 232, 255), "C": rgb(112, 122, 182), "S": rgb(232, 222, 242), "Y": rgb(255, 238, 92)]),
        "skyisle_whale": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleWhale, [(9, 3, "W"), (10, 3, "W"), (10, 2, "W")]), swap: ["Z": rgb(132, 182, 226), "B": rgb(240, 250, 255), "W": rgb(255, 255, 255)]),
        "skyisle_griffinqueen": SpriteSpec(grid: skyisleGriffin, swap: ["T": rgb(246, 206, 96), "t": rgb(196, 146, 56), "W": rgb(255, 255, 255), "Y": rgb(255, 172, 42)], boss: true),
        "skyisle_thunderbird": SpriteSpec(grid: RpgCrystalRegion.mark(skyisleEagle, [(1, 5, "Y"), (2, 6, "Y"), (3, 7, "Y"), (14, 5, "Y"), (13, 6, "Y"), (12, 7, "Y")]), swap: ["B": rgb(62, 72, 152), "W": rgb(112, 122, 202), "Y": rgb(255, 240, 82)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsSkyisle: [String: [Character: CGColor]] = [
        "skyisle_feather": ["B": rgb(255, 248, 220), "E": rgb(220, 180, 110)],
        "skyisle_cloud": ["B": rgb(255, 230, 245), "E": rgb(220, 180, 210)],
        "skyisle_gem": ["B": rgb(200, 255, 130), "E": rgb(100, 180, 60)],
        "skyisle_tea": ["B": rgb(200, 235, 255), "E": rgb(255, 210, 120)],
        "skyisle_scroll": ["B": rgb(170, 200, 255), "E": rgb(110, 130, 230)],
        "skyisle_windring": ["B": rgb(235, 245, 255), "J": rgb(120, 255, 200), "W": rgb(255, 255, 255)],
        "skyisle_amulet": ["B": rgb(240, 230, 200), "J": rgb(150, 210, 255), "W": rgb(255, 255, 255)],
        "skyisle_halo": ["B": rgb(255, 250, 222), "J": rgb(255, 210, 80)],
        "skyisle_featherboots": ["B": rgb(240, 240, 250), "J": rgb(120, 220, 255)],
        "skyisle_bow": ["B": rgb(250, 230, 170), "G": rgb(190, 140, 80), "W": rgb(200, 255, 230)],
        "skyisle_dagger": ["B": rgb(255, 250, 200), "E": rgb(240, 200, 60), "G": rgb(90, 100, 170), "H": rgb(60, 60, 110)],
        "skyisle_rod": ["O": rgb(255, 250, 220), "W": rgb(255, 255, 255), "E": rgb(230, 200, 120), "G": rgb(150, 200, 255), "B": rgb(240, 240, 250), "H": rgb(150, 160, 190)],
    ]
}

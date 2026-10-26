import CoreGraphics
import Foundation

// 차원 균열 (Lv80-100): reality comes apart from the shattered border inward — floating debris, warped corridors, the void
// caves where the Eye of the Rift watches (Lv92), an inverted forest, ruins where time stopped, and the devourer at the core
// (Lv99). Owned by exactly one author; see `RpgRegions.swift`.
//
// Balance — the same curves as the frost region (see `RpgFrostRegion.swift`): normals on the power-law fits of the built-in
// Lv58-100 monsters of their behaviour, ±6% per-monster tilts:
//   behaviour      Lv80 HP/ATK/DEF/XP          Lv90                        Lv99
//   aggressive     26.9k/542/192/10.9k         35.2k/632/223/16.8k         43.9k/715/252/23.8k   (heavy: ×1.3 HP and DEF, ×1.05 ATK, ×1.2 XP)
//   ranged         21.6k/543/135/10.9k         28.4k/632/158/16.6k         35.3k/715/179/23.3k
//   flyer          22.9k/488/136/10.4k         30.1k/569/158/15.3k         37.5k/644/179/20.9k
//   charger        28.3k/543/193/13.6k         37.1k/633/224/20.9k         46.2k/717/253/29.7k
//   swarm          10.8k/326/ 77/5.9k          14.1k/379/ 89/9.0k          17.5k/429/101/12.7k
//   exploder       13.5k/677/ 96/11.2k         17.6k/790/113/17.7k         22.0k/895/128/25.6k
// Bosses on the built-in late-boss curve: the Eye of the Rift Lv92 2.24M HP / 955 ATK / 1.13M XP (half the built-in boss loot
// rates), the devourer Lv99 2.55M / 1040 / 1.70M, just under the Lv100 void lord (3/4 rates).
// Gear: weapon tiers 10/11/12 at Lv<82/<92/≥92, armor and accessories 10/11 at Lv<89/≥89; signature gear keeps the budget
// of the tier it drops at with a different spread.

enum RpgRiftRegion {
    static let region = RpgRegion(id: "rift", name: "차원 균열",
                                  blurb: "깨진 하늘 아래 잔해가 떠다니고, 픽셀이 찢긴 괴물들이 시간이 멈춘 폐허를 헤매요.",
                                  minLevel: 78, entry: RpgMapID("rift_1"), entryTile: RpgTile(x: 4, y: 15),
                                  maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static func p(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, _ gate: Int) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    // MARK: maps

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: RpgMapID("rift_1"), name: "부서진 경계", levelText: "Lv80~84", width: 50, height: 30, kind: .field, seed: 13001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), p(48, 15, "rift_2", 4, 15, 83)],
                  monsters: RpgMaps.sp([("rift_voidling", 6), ("rift_glitchslime", 6), ("rift_cube", 5), ("rift_chest", 1)]),
                  theme: RpgTheme(obstacle: .caveWall, tint: tint(0.85, 0.3, 1.0), tintAlpha: 0.75, blend: .hue), waypoint: true),
        RpgMapDef(id: RpgMapID("rift_2"), name: "떠다니는 잔해 섬", levelText: "Lv83~88", width: 50, height: 30, kind: .desert, seed: 13002,
                  portals: [p(1, 15, "rift_1", 45, 15, 78), p(48, 15, "rift_3", 4, 16, 86)],
                  monsters: RpgMaps.sp([("rift_chest", 1), ("rift_debrisgolem", 4), ("rift_glitchwolf", 5), ("rift_eye", 4)]),
                  theme: RpgTheme(obstacle: .caveWall, pool: .water, decor: .stone, tint: tint(0.4, 0.9, 1.0), tintAlpha: 0.45, blend: .color)),
        RpgMapDef(id: RpgMapID("rift_3"), name: "비틀린 복도", levelText: "Lv86~91", width: 50, height: 32, kind: .castle, seed: 13003,
                  portals: [p(1, 16, "rift_2", 45, 15, 83), p(48, 16, "rift_4", 4, 15, 88)],
                  monsters: RpgMaps.sp([("rift_glitchwolf", 4), ("rift_eye", 4), ("rift_shardbomb", 4), ("rift_mirrorknight", 5)]),
                  theme: RpgTheme(tint: tint(0.2, 1.0, 0.6), tintAlpha: 0.45, blend: .color, darkness: 0.45), waypoint: true),
        RpgMapDef(id: RpgMapID("rift_4"), name: "공허 동굴", levelText: "Lv88~93", width: 48, height: 30, kind: .cave, seed: 13004,
                  portals: [p(1, 15, "rift_3", 45, 16, 86), p(46, 15, "rift_5", 4, 15, 90), p(24, 1, "rift_b1", 14, 17, 88)],
                  monsters: RpgMaps.sp([("rift_shardbomb", 4), ("rift_mirrorknight", 4), ("rift_manta", 5), ("rift_tesseract", 4)]),
                  theme: RpgTheme(tint: tint(0.9, 0.3, 0.8), tintAlpha: 0.5, blend: .color, darkness: 0.7)),
        RpgMapDef(id: RpgMapID("rift_5"), name: "역전된 숲", levelText: "Lv90~95", width: 48, height: 30, kind: .forest, seed: 13005,
                  portals: [p(1, 15, "rift_4", 43, 15, 88), p(46, 15, "rift_6", 4, 15, 93)],
                  monsters: RpgMaps.sp([("rift_manta", 4), ("rift_tesseract", 4), ("rift_echomage", 5), ("rift_shardswarm", 5)]),
                  theme: RpgTheme(tint: tint(0.7, 0.3, 1.0), tintAlpha: 0.9, blend: .hue), waypoint: true),
        RpgMapDef(id: RpgMapID("rift_6"), name: "시간이 멈춘 폐허", levelText: "Lv93~98", width: 50, height: 30, kind: .desert, seed: 13006,
                  portals: [p(1, 15, "rift_5", 43, 15, 90), p(48, 15, "rift_7", 4, 15, 95)],
                  monsters: RpgMaps.sp([("rift_echomage", 4), ("rift_shardswarm", 4), ("rift_nullgolem", 4), ("rift_hourglass", 4)]),
                  theme: RpgTheme(obstacle: .rock, decor: .stone, tint: tint(0.55, 0.55, 0.6), tintAlpha: 0.9, blend: .color)),
        RpgMapDef(id: RpgMapID("rift_7"), name: "차원의 핵", levelText: "Lv95~100", width: 50, height: 30, kind: .volcano, seed: 13007,
                  portals: [p(1, 15, "rift_6", 45, 15, 93), p(25, 1, "rift_b2", 14, 17, 95)],
                  monsters: RpgMaps.sp([("rift_shardswarm", 4), ("rift_nullgolem", 4), ("rift_hourglass", 4), ("rift_jelly", 6)]),
                  theme: RpgTheme(tint: tint(0.6, 0.2, 1.0), tintAlpha: 0.6, blend: .color, darkness: 0.5), waypoint: true),
        RpgMapDef(id: RpgMapID("rift_b1"), name: "균열의 눈동자", levelText: "보스 Lv92", width: 28, height: 22, kind: .boss, seed: 13008,
                  portals: [p(14, 20, "rift_4", 24, 4, 88)], monsters: RpgMaps.sp([("rift_azatho", 1)]), zone: .castle,
                  theme: RpgTheme(tint: tint(0.9, 0.25, 0.7), tintAlpha: 0.5, blend: .color, darkness: 0.55)),
        RpgMapDef(id: RpgMapID("rift_b2"), name: "포식자의 아가리", levelText: "보스 Lv99", width: 28, height: 22, kind: .boss, seed: 13009,
                  portals: [p(14, 20, "rift_7", 25, 4, 95)], monsters: RpgMaps.sp([("rift_devourer", 1)]), zone: .volcano,
                  theme: RpgTheme(tint: tint(0.55, 0.2, 0.95), tintAlpha: 0.6, blend: .color, darkness: 0.5)),
    ]

    // MARK: monsters

    private static let monsters: [RpgMonsterDef] = {
        let m = RpgMonsters.m
        var list: [RpgMonsterDef] = [
            m("rift_voidling", "공허 꼬물이", "rift_voidling", 80, 10750, 325, 77, 64, 5900, 735...1050, .swarm, [("hp4", 0.1), ("dagger10", 0.004), ("mace10", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.164), ("rift_shard", 0.05)]),
            m("rift_glitchslime", "깨진 슬라임", "rift_glitchslime", 81, 23800, 440, 176, 28, 10800, 1365...1950, .passive, [("hp4", 0.08), ("claw10", 0.004), ("rod10", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.266), ("rift_shard", 0.06), ("rift_tonic", 0.02)]),
            m("rift_cube", "떠도는 정육면체", "rift_cube", 82, 24250, 505, 140, 56, 11250, 1495...2150, .flyer, [("hp4", 0.08), ("mp2", 0.08), ("sword11", 0.004), ("bow11", 0.004), ("armor10", 0.004), ("boots10", 0.004), ("stone", 0.268), ("rift_shard", 0.06)]),
            m("rift_chest", "도망치는 보물상자", "rift_chest", 83, 20450, 0, 232, 56, 16200, 6400...9200, .coward, [("hp4", 0.1), ("stone", 0.3), ("rift_shard", 0.5), ("rift_tonic", 0.3), ("rift_elixir", 0.2), ("rift_amulet", 0.01)]),
            m("rift_debrisgolem", "잔해 골렘", "rift_debrisgolem", 84, 39250, 605, 266, 24, 15450, 1990...2850, .aggressive, [("hp4", 0.08), ("mace11", 0.004), ("claw11", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.272), ("rift_shard", 0.06), ("rift_elixir", 0.02)]),
            m("rift_glitchwolf", "픽셀 늑대", "rift_glitchwolf", 85, 32500, 610, 200, 46, 16950, 2040...2950, .charger, [("hp4", 0.1), ("rod11", 0.004), ("sword11", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.174), ("rift_shard", 0.05), ("rift_tonic", 0.02)]),
            m("rift_eye", "공허의 눈", "rift_eye", 87, 26250, 605, 151, 30, 14750, 1810...2600, .ranged, [("hp4", 0.08), ("mp2", 0.08), ("bow11", 0.004), ("staff11", 0.004), ("armor10", 0.004), ("boots10", 0.004), ("stone", 0.278), ("rift_shard", 0.06), ("rift_amulet", 0.002)]),
            m("rift_shardbomb", "불안정한 파편", "rift_shardbomb", 88, 16750, 765, 109, 50, 16200, 1860...2700, .exploder, [("hp5", 0.1), ("dagger11", 0.004), ("mace11", 0.004), ("armor10", 0.004), ("ring10", 0.004), ("stone", 0.18), ("rift_shard", 0.05)]),
            m("rift_mirrorknight", "거울상 기사", "rift_mirrorknight", 89, 34350, 625, 220, 40, 16100, 1920...2750, .aggressive, [("hp5", 0.08), ("claw11", 0.004), ("rod11", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.282), ("rift_shard", 0.06), ("rift_elixir", 0.02)]),
            m("rift_manta", "차원 가오리", "rift_manta", 91, 30850, 575, 160, 58, 15850, 1940...2750, .flyer, [("hp5", 0.08), ("mp3", 0.08), ("sword11", 0.004), ("bow11", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.286), ("rift_core", 0.06), ("rift_tonic", 0.02)]),
            m("rift_tesseract", "구르는 테서랙트", "rift_tesseract", 92, 41000, 620, 242, 42, 22700, 2495...3600, .charger, [("hp5", 0.1), ("staff12", 0.004), ("dagger12", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.188), ("rift_core", 0.05), ("rift_boots", 0.002)]),
            m("rift_echomage", "메아리 마법사", "rift_echomage", 94, 31350, 670, 167, 34, 19400, 2200...3150, .ranged, [("hp5", 0.08), ("mp3", 0.08), ("mace12", 0.004), ("claw12", 0.004), ("armor11", 0.004), ("ring11", 0.004), ("stone", 0.292), ("rift_core", 0.06), ("rift_elixir", 0.02)]),
            m("rift_shardswarm", "차원 파편떼", "rift_shardswarm", 95, 15950, 405, 96, 66, 10950, 1130...1650, .swarm, [("hp5", 0.1), ("rod12", 0.004), ("sword12", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.194), ("rift_core", 0.04)]),
            m("rift_nullgolem", "널 거상", "rift_nullgolem", 96, 53450, 725, 319, 24, 25950, 2795...4000, .aggressive, [("hp5", 0.08), ("bow12", 0.004), ("staff12", 0.004), ("armor11", 0.004), ("helmet11", 0.004), ("stone", 0.296), ("rift_core", 0.06), ("rift_ring", 0.002)]),
            m("rift_hourglass", "역설의 모래시계", "rift_hourglass", 98, 21450, 885, 126, 48, 24600, 2440...3500, .exploder, [("hp5", 0.1), ("dagger12", 0.004), ("mace12", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.2), ("rift_core", 0.05), ("rift_tonic", 0.03)]),
            m("rift_jelly", "차원 해파리", "rift_jelly", 99, 37450, 645, 179, 56, 20950, 2400...3400, .flyer, [("hp5", 0.08), ("mp3", 0.08), ("claw12", 0.004), ("rod12", 0.004), ("armor11", 0.004), ("ring11", 0.004), ("stone", 0.302), ("rift_core", 0.06), ("rift_elixir", 0.02)]),
        ]
        list.append(RpgMonsters.boss("rift_azatho", "균열의 눈 아자토", "rift_azatho", 92, 2_238_000, 955, 226, 38, 1_132_000, 108_000...180_000, .skeleton,
                                     minion: "rift_voidling", element: .cosmic,
                                     RpgMonsters.endgameBossLoot(weapon: 12, armor: [11, 10], gear: 11, rate: 0.5)
                                         + [("rift_lens", 1), ("rift_rod", 0.12), ("rift_amulet", 0.12), ("rift_shard", 1), ("rift_shard", 1), ("rift_elixir", 0.5), ("hp5", 1)]))
        list.append(RpgMonsters.boss("rift_devourer", "차원 포식자", "rift_devourer", 99, 2_554_000, 1040, 251, 39, 1_697_000, 134_500...223_500, .demon,
                                     minion: "rift_shardswarm", element: .cosmic,
                                     RpgMonsters.endgameBossLoot(weapon: 12, armor: [11, 10], gear: 11, rate: 0.75)
                                         + [("rift_fang", 1), ("rift_dagger", 0.12), ("rift_ring", 0.1), ("rift_boots", 0.1), ("rift_core", 1), ("rift_core", 1), ("hp5", 1)]))
        return list
    }()

    // MARK: items

    private static let items: [RpgItem] = [
        RpgItem(id: "rift_shard", name: "차원 조각", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 16000, element: .base, inShop: false),
        RpgItem(id: "rift_core", name: "공허 핵", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 24000, element: .base, inShop: false),
        RpgItem(id: "rift_lens", name: "아자토의 수정체", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 60000, element: .base, inShop: false),
        RpgItem(id: "rift_fang", name: "포식자의 이빨", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 100_000, element: .base, inShop: false),
        RpgItem(id: "rift_tonic", name: "차원 안정제", kind: .buff("speed"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 500, element: .base, inShop: false),
        RpgItem(id: "rift_elixir", name: "공허의 엘릭서", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 8000, price: 6000, element: .base, inShop: false),
        // Armor between tiers 10 (250) and 11 (330), close to 11: crafted from the inner rift.
        RpgItem(id: "rift_armor", name: "차원 직조 갑옷", kind: .armor, rarity: 4, attack: 0, defense: 310, heal: 0, price: 760_000, element: .base, inShop: false),
        // Tier 11 boots (14% / 105) → heavy: 0.64 + 1.35.
        RpgItem(id: "rift_boots", name: "중력 부츠", kind: .boots, rarity: 4, attack: 0, defense: 142, heal: 0, price: 1_500_000, element: .base, inShop: false,
                bonusSpeed: 0.09),
        // Tier 11 ring (4300 HP / 18% / 50%) → all-in on damage: 0.60 + 1.11 + 1.30.
        RpgItem(id: "rift_ring", name: "역설의 반지", kind: .ring, rarity: 4, attack: 0, defense: 0, heal: 0, price: 1_600_000, element: .base, inShop: false,
                bonusHP: 2600, bonusCrit: 0.20, bonusAttack: 0.65),
        // Tier 10 amulet (5100 HP / 950 MP / 150) → life over mana: 1.43 + 0.53 + 1.03.
        RpgItem(id: "rift_amulet", name: "테서랙트 목걸이", kind: .amulet, rarity: 4, attack: 0, defense: 155, heal: 0, price: 1_000_000, element: .base, inShop: false,
                bonusHP: 7300, bonusMP: 500),
        // Same attack as the tier they drop at (rod11 290 poison, dagger12 380 cosmic), another element.
        RpgItem(id: "rift_rod", name: "공허 소환봉", kind: .weapon(.summoner), rarity: 4, attack: 290, defense: 0, heal: 0, price: 480_000, element: .thunder, inShop: false),
        RpgItem(id: "rift_dagger", name: "균열 단검", kind: .weapon(.rogue), rarity: 4, attack: 380, defense: 0, heal: 0, price: 800_000, element: .poison, inShop: false),
    ]

    // MARK: recipes (the smith)

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "rift_armor", output: "rift_armor", count: 1, materials: ["rift_shard": 22, "rift_core": 6, "stone": 25], gold: 750_000),
        RpgRecipe(id: "rift_boots", output: "rift_boots", count: 1, materials: ["rift_core": 18, "rift_lens": 1, "stone": 35], gold: 1_500_000),
        RpgRecipe(id: "rift_ring", output: "rift_ring", count: 1, materials: ["rift_core": 22, "rift_fang": 1, "mat_void": 12, "stone": 45], gold: 1_600_000),
        RpgRecipe(id: "rift_amulet", output: "rift_amulet", count: 1, materials: ["rift_shard": 20, "mat_time": 10, "stone": 30], gold: 1_000_000),
        RpgRecipe(id: "rift_rod", output: "rift_rod", count: 1, materials: ["rift_shard": 16, "rift_lens": 1, "stone": 30], gold: 480_000),
        RpgRecipe(id: "rift_dagger", output: "rift_dagger", count: 1, materials: ["rift_fang": 2, "rift_core": 26, "mat_void": 14, "stone": 45], gold: 800_000),
        RpgRecipe(id: "rift_elixir", output: "rift_elixir", count: 2, materials: ["rift_shard": 1], gold: 3000),
    ]
}

// MARK: art

extension RpgArt {
    static let riftCube: RpgGrid = [
        "................", "......KKKK......", "....KKPPPPKK....", "..KKPPPPPPPPKK..", ".KPPPPPPPPPPPPK.", ".KAAPPPPPPPPOOK.",
        ".KAAAAPPPPOOOOK.", ".KAAAAAKKOOOOOK.", ".KAAAAKWWKOOOOK.", ".KAAAAKWRKOOOOK.", ".KAAAAAKKOOOOOK.", ".KAAAAAAKOOOOOK.",
        "..KKAAAAKOOOKK..", "....KKAAKOKK....", "......KKKK......", "................",
    ]
    static let riftVoidling: RpgGrid = [
        "................", "................", "................", "................", "................", "......KKKK......",
        "....KKPPPPKK....", "...KPPPPPPPPK...", "..KPPKKKKPPPPK..", "..KPKWWWWKPPPK..", "..KPKWOOWKPPPK..", "..KPPKKKKPPPPK..",
        "..KPPPPPPPPPPK..", ".KPKpKpKKpKpKPK.", ".K.K.K.K.K.K.K..", "................",
    ]
    static let riftEye: RpgGrid = [
        "..K....K....K...", ".KOK..KOK..KOK..", "..KK...K...KK...", "...KK..K..KK....", "....KKKKKKK.....", "...KPPPPPPPK....",
        "..KPPWWWWWPPK...", ".KPPWWWWWWWPPK..", ".KPWWWKKKWWWPK..", ".KPWWKKRKKWWPK..", ".KPWWWKKKWWWPK..", ".KPPWWWWWWWPPK..",
        "..KPPKKKKKPPK...", "...KPWKWKPPK....", "....KKKKKKK.....", "................",
    ]
    static let riftShard: RpgGrid = [
        "................", ".......KK.......", "......KOOK......", "......KOWK......", ".....KOOWOK.....", ".....KOOWOK.....",
        "....KOOOWOOK....", "....KOKOOKoK....", "....KOOOOOoK....", ".....KOOOoK.....", ".....KOOOoK.....", "......KOoK......",
        "......KOoK......", ".......KK.......", "................", "................",
    ]
    static let riftChest: RpgGrid = [
        "................", "................", "................", "................", "...KKKKKKKKKK...", "..KLLLLLLLLLLK..",
        "..KLlLLLLLLlLK..", "..KYYYYYYYYYYK..", "..KKKKKKKKKKKK..", "..KLWKLLLLKWLK..", "..KLKKLYYLKKLK..", "..KLLLLKKLLLLK..",
        "..KLlLLLLLLlLK..", "...KKKKKKKKKK...", "....KLK..KLK....", "....KK....KK....",
    ]
    static let riftHourglass: RpgGrid = [
        "................", "...KKKKKKKKKK...", "...KYYYYYYYYK...", "...KKKKKKKKKK...", "....KWSSSSWK....", "....KWSSSSWK....",
        ".....KWSSWK.....", "......KWSK......", "......KWSK......", ".....KWWSWK.....", "....KWWSSWWK....", "....KWSSSSWK....",
        "...KKKKKKKKKK...", "...KYYYYYYYYK...", "...KKKKKKKKKK...", "................",
    ]
    static let riftDevourer: RpgGrid = [
        "................", ".....KKKKKK.....", "...KKPPPPPPKK...", "..KPPOKPPOKPPK..", ".KPPPKKPPKKPPPK.", ".KPPpPPOKPPPpPK.",
        "KPPPPPPKKPPPPPPK", "KPKKKKKKKKKKKKPK", "KPKWKWKWKWKWKKPK", "KPKRRRRRRRRRRKPK", "KPKKWKWKWKWKWKPK", "KPPKKKKKKKKKKPPK",
        ".KPPPPpPPpPPPPK.", ".KPKPKPKKPKPKPK.", ".K.KPK.KK.KPK.K.", "...KK......KK...",
    ]

    /// Tears a body like a broken signal: row y slides `dx` pixels (positive to the right).
    private static func riftGlitch(_ g: RpgGrid, _ shifts: [Int: Int]) -> RpgGrid {
        var rows = g
        for (y, dx) in shifts where rows.indices.contains(y) {
            let r = Array(rows[y])
            rows[y] = String(r.indices.map { x in r.indices.contains(x - dx) ? r[x - dx] : "." })
        }
        return rows
    }
    private static let riftGlitchSlime = riftGlitch(endgameStamp(slime, [
        "................", "................", "................", "................", ".............OO.", ".............OO.",
        "...........R....", "................", ".R..............", "................", "..............O.",
    ]), [9: 2, 10: 1, 13: -1])
    private static let riftGlitchWolf = riftGlitch(endgameMirror(endgameStamp(wolf, [
        "................", "................", ".W..............", "WW..............", "................", "................",
        "................", "...............O",
    ])), [6: 1, 8: -2, 9: 1])
    private static let riftMirrorKnight = riftGlitch(warrior, [2: 1, 9: -1, 13: 1])
    /// Debris golem: the head and arms float loose, cracks glow.
    private static let riftDebrisGolem = endgameStamp(golem, [
        "................", "................", "................", "................", "................", "_____OO______OO__",
        ".....O.........O", "................", "................", ".....OO...OO....",
    ])
    /// Manta: the bat's wings with a long tail and glowing spots.
    private static let riftManta = endgameStamp(bat, [
        "................", "................", "................", "................", "................", "................",
        "................", "................", "..O..........O..", "................", "................", ".......KK.......",
        "......KAAK......", ".......KAK......", "........KAK.....", ".........KK.....",
    ])
    /// Echo mage: the caster trailed by its own afterimage.
    private static let riftEchoMage = endgameStamp(mage, [
        ".....xKK........", "....x.PPK.......", "...x..PPPK......", "..x...........", "x.............", "x...............",
        "..x.............", "..x.............", "...x............", "..x.............", ".x..............", ".x..............",
        "..x.............", ".x..............", ".x..............", "..x.............",
    ])
    /// Null colossus: a hole into nothing where the chest should be.
    private static let riftNullGolem = endgameStamp(golem, [
        "................", "................", "................", "................", "................", "................",
        "......pppp......", ".....pKKKKp.....", ".....pKKKKp.....", "......pppp......",
    ])
    /// Tesseract: a cube inside the cube.
    private static let riftTesseract = endgameStamp(riftCube, [
        "................", "................", "................", "................", "......KKKK......", ".....KCCCCK.....",
        ".....KCWWCK.....", ".....KCWRCK.....", ".....KCCCCK.....", "......KKKK......",
    ])
    /// Jellyfish: the voidling's body as a bell over long trailing arms.
    private static let riftJelly: RpgGrid = [
        "................", "................", ".....KKKKKK.....", "...KKPPPPPPKK...", "..KPPWWPPPPPPK..", ".KPPWPPPPPPPPPK.",
        ".KPPPKPPPPKPPPK.", ".KPPPPPPPPPPPPK.", ".KKpKKpKKpKKpKK.", "..KpK.KpK.KpK...", "..KOK.KOK.KOK...", "...KpK.KpK.KpK..",
        "...KOK.KOK.KOK..", "....K...K...K...", "................", "................",
    ]
    /// Shard swarm: a second splinter flying with the shard.
    private static let riftShardSwarm = endgameStamp(riftShard, ["....K", "...KOK", "...KOK", "....K"], 9, 8)

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsRift: [String: SpriteSpec] = [
        "rift_voidling": SpriteSpec(grid: riftVoidling, swap: ["P": rgb(60, 30, 110), "p": rgb(36, 14, 70), "W": rgb(255, 255, 255), "O": rgb(255, 80, 200)]),
        "rift_glitchslime": SpriteSpec(grid: riftGlitchSlime, swap: ["E": rgb(90, 255, 200), "e": rgb(40, 160, 160), "W": rgb(255, 255, 255), "R": rgb(255, 60, 160),
                                                                     "O": rgb(80, 220, 255)]),
        "rift_cube": SpriteSpec(grid: riftCube, swap: ["P": rgb(170, 90, 255), "A": rgb(110, 50, 190), "O": rgb(230, 150, 255), "W": rgb(255, 255, 255), "R": rgb(255, 60, 140)]),
        "rift_chest": SpriteSpec(grid: riftChest, swap: ["L": rgb(170, 110, 60), "l": rgb(120, 76, 40), "Y": rgb(255, 214, 80), "W": rgb(255, 255, 255)]),
        "rift_debrisgolem": SpriteSpec(grid: riftDebrisGolem, swap: ["N": rgb(120, 110, 140), "n": rgb(80, 70, 100), "Q": rgb(120, 255, 255), "O": rgb(120, 255, 255)]),
        "rift_glitchwolf": SpriteSpec(grid: riftGlitchWolf, swap: ["Z": rgb(60, 230, 200), "z": rgb(30, 140, 130), "R": rgb(255, 60, 140), "O": rgb(255, 60, 140),
                                                                   "W": rgb(120, 240, 255)]),
        "rift_eye": SpriteSpec(grid: riftEye, swap: ["P": rgb(120, 40, 160), "p": rgb(80, 20, 110), "W": rgb(245, 240, 255), "R": rgb(255, 40, 80), "O": rgb(200, 120, 255)]),
        "rift_shardbomb": SpriteSpec(grid: riftShard, swap: ["O": rgb(120, 240, 255), "W": rgb(255, 255, 255), "o": rgb(60, 150, 220)]),
        "rift_mirrorknight": SpriteSpec(grid: riftMirrorKnight, swap: ["M": rgb(50, 50, 70), "m": rgb(24, 24, 40), "B": rgb(255, 255, 255), "R": rgb(90, 240, 255),
                                                                       "r": rgb(40, 160, 200), "S": rgb(200, 220, 255), "Y": rgb(255, 60, 160), "L": rgb(30, 30, 50)]),
        "rift_manta": SpriteSpec(grid: riftManta, swap: ["A": rgb(40, 90, 120), "a": rgb(20, 50, 80), "W": rgb(120, 240, 255), "O": rgb(120, 240, 255)]),
        "rift_tesseract": SpriteSpec(grid: riftTesseract, swap: ["P": rgb(90, 200, 255), "A": rgb(40, 110, 190), "O": rgb(170, 230, 255), "C": rgb(255, 120, 220),
                                                                 "W": rgb(255, 255, 255), "R": rgb(60, 20, 120)]),
        "rift_echomage": SpriteSpec(grid: riftEchoMage, swap: ["P": rgb(40, 30, 70), "p": rgb(20, 14, 40), "S": rgb(190, 170, 230), "Y": rgb(120, 255, 255),
                                                               "x": rgb(150, 110, 220)]),
        "rift_shardswarm": SpriteSpec(grid: riftShardSwarm, swap: ["O": rgb(255, 110, 220), "W": rgb(255, 230, 250), "o": rgb(190, 50, 160)]),
        "rift_nullgolem": SpriteSpec(grid: riftNullGolem, swap: ["N": rgb(232, 232, 240), "n": rgb(170, 170, 190), "Q": rgb(40, 20, 80), "p": rgb(120, 40, 200)]),
        "rift_hourglass": SpriteSpec(grid: riftHourglass, swap: ["Y": rgb(230, 180, 80), "S": rgb(255, 230, 150), "W": rgb(230, 240, 255)]),
        "rift_jelly": SpriteSpec(grid: riftJelly, swap: ["P": rgb(200, 140, 255), "p": rgb(150, 90, 220), "W": rgb(255, 255, 255), "O": rgb(255, 120, 220)]),
        "rift_azatho": SpriteSpec(grid: riftEye, swap: ["P": rgb(150, 20, 50), "p": rgb(90, 10, 30), "W": rgb(255, 230, 200), "R": rgb(40, 200, 255), "O": rgb(255, 90, 60)],
                                  boss: true),
        "rift_devourer": SpriteSpec(grid: riftDevourer, swap: ["P": rgb(70, 30, 120), "p": rgb(40, 14, 80), "W": rgb(255, 255, 255), "R": rgb(220, 30, 90),
                                                               "O": rgb(120, 240, 255)], boss: true),
    ]

    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsRift: [String: [Character: CGColor]] = [
        "rift_shard": ["B": rgb(140, 240, 255), "E": rgb(60, 120, 220)],
        "rift_core": ["B": rgb(170, 90, 255), "E": rgb(40, 14, 80)],
        "rift_lens": ["B": rgb(255, 230, 200), "E": rgb(150, 20, 50)],
        "rift_fang": ["B": rgb(250, 250, 255), "E": rgb(220, 30, 90)],
        "rift_tonic": ["B": rgb(120, 255, 220), "E": rgb(60, 150, 200)],
        "rift_elixir": ["B": rgb(200, 120, 255), "E": rgb(90, 30, 160)],
        "rift_armor": ["B": rgb(60, 40, 110), "E": rgb(120, 240, 255)],
        "rift_boots": ["B": rgb(80, 80, 110), "J": rgb(170, 90, 255), "W": rgb(255, 255, 255)],
        "rift_ring": ["B": rgb(40, 30, 70), "J": rgb(255, 60, 160), "W": rgb(255, 255, 255)],
        "rift_amulet": ["B": rgb(170, 90, 255), "J": rgb(120, 240, 255), "W": rgb(255, 255, 255)],
        "rift_rod": ["B": rgb(60, 30, 110), "E": rgb(120, 240, 255), "G": rgb(255, 240, 90), "H": rgb(30, 14, 60), "O": rgb(255, 240, 90), "W": rgb(255, 255, 255)],
        "rift_dagger": ["B": rgb(160, 255, 140), "E": rgb(70, 160, 80), "G": rgb(120, 40, 160), "H": rgb(40, 14, 70)],
    ]
}

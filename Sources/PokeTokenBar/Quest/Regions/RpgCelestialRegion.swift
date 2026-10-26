import CoreGraphics
import Foundation

// 신들의 정원 (Lv70-95): from the cloud road through the gods' flower garden, the constellation corridor and the golden temple
// courtyard (the zodiac lion's altar, Lv86) to the angels' garden, the milky-way bridge and the sanctum of the archangel (Lv95).
// Owned by exactly one author; see `RpgRegions.swift`.
//
// Balance — the same curves as the frost region (see `RpgFrostRegion.swift`): normals on the power-law fits of the built-in
// Lv58-100 monsters of their behaviour, ±6% per-monster tilts:
//   behaviour      Lv70 HP/ATK/DEF/XP          Lv80                        Lv92
//   aggressive     19.7k/456/162/6.7k          26.9k/542/192/10.9k         37.1k/650/229/18.2k   (heavy: ×1.3 HP and DEF, ×1.05 ATK, ×1.2 XP)
//   ranged         15.9k/457/113/6.8k          21.6k/543/135/10.9k         29.8k/650/163/18.0k
//   flyer          16.8k/410/114/6.7k          22.9k/488/136/10.4k         31.6k/586/163/16.4k
//   charger        20.8k/456/163/8.3k          28.3k/543/193/13.6k         39.0k/651/231/22.7k
//   swarm           7.9k/275/ 65/3.7k          10.8k/326/ 77/5.9k          14.8k/390/ 92/9.8k
//   exploder        9.9k/568/ 80/6.7k          13.5k/677/ 96/11.2k         18.6k/813/116/19.3k
// Bosses on the built-in late-boss curve: the zodiac lion Lv86 1.98M HP / 869 ATK / 766k XP (half the built-in boss loot
// rates), the archangel Lv95 2.40M / 1010 / 1.38M — a notch above the Lv95 lich so bosses still climb with level (3/4 rates).
// Gear: weapon tiers 10/11/12 at Lv<82/<92/≥92, armor and accessories 9/10/11 at Lv<77/<89/≥89; signature gear keeps the
// budget of the tier it drops at with a different spread.

enum RpgCelestialRegion {
    static let region = RpgRegion(id: "celestial", name: "신들의 정원",
                                  blurb: "구름 계단 너머 별자리가 살아 움직이고, 천사들이 황금 신전의 꽃밭을 가꾸어요.",
                                  minLevel: 68, entry: RpgMapID("celestial_1"), entryTile: RpgTile(x: 4, y: 15),
                                  maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static func p(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, _ gate: Int) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    // MARK: maps

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: RpgMapID("celestial_1"), name: "천상의 구름길", levelText: "Lv70~74", width: 50, height: 30, kind: .desert, seed: 12001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), p(48, 15, "celestial_2", 4, 15, 73)],
                  monsters: RpgMaps.sp([("celestial_cherub", 6), ("celestial_sheep", 6), ("celestial_bee", 6), ("celestial_goose", 1)]),
                  theme: RpgTheme(obstacle: .water, pool: .water, tint: tint(1.0, 0.86, 0.94), tintAlpha: 0.6, blend: .color), waypoint: true),
        RpgMapDef(id: RpgMapID("celestial_2"), name: "신들의 화원", levelText: "Lv73~78", width: 50, height: 30, kind: .field, seed: 12002,
                  portals: [p(1, 15, "celestial_1", 45, 15, 68), p(48, 15, "celestial_3", 4, 16, 76)],
                  monsters: RpgMaps.sp([("celestial_bee", 5), ("celestial_comet", 4), ("celestial_lion", 5), ("celestial_goose", 1)]),
                  theme: RpgTheme(floor: .flower, decor: .grass, tint: tint(1.0, 0.85, 0.45), tintAlpha: 0.45, blend: .softLight)),
        RpgMapDef(id: RpgMapID("celestial_3"), name: "별자리 회랑", levelText: "Lv76~81", width: 50, height: 32, kind: .castle, seed: 12003,
                  portals: [p(1, 16, "celestial_2", 45, 15, 73), p(48, 16, "celestial_4", 4, 15, 79)],
                  monsters: RpgMaps.sp([("celestial_comet", 4), ("celestial_lion", 4), ("celestial_priest", 5), ("celestial_starsprite", 6)]),
                  theme: RpgTheme(tint: tint(0.25, 0.3, 0.75), tintAlpha: 0.5, blend: .color, darkness: 0.45), waypoint: true),
        RpgMapDef(id: RpgMapID("celestial_4"), name: "황금 신전 앞뜰", levelText: "Lv79~84", width: 50, height: 30, kind: .desert, seed: 12004,
                  portals: [p(1, 15, "celestial_3", 45, 16, 76), p(48, 15, "celestial_5", 4, 15, 83), p(25, 1, "celestial_b1", 14, 17, 81)],
                  monsters: RpgMaps.sp([("celestial_priest", 4), ("celestial_starsprite", 4), ("celestial_guardian", 4), ("celestial_scorpio", 6)]),
                  theme: RpgTheme(obstacle: .pillar, pool: .water, decor: .stone, tint: tint(1.0, 0.82, 0.35), tintAlpha: 0.25, blend: .color)),
        RpgMapDef(id: RpgMapID("celestial_5"), name: "천사의 정원", levelText: "Lv83~88", width: 48, height: 30, kind: .snow, seed: 12005,
                  portals: [p(1, 15, "celestial_4", 45, 15, 79), p(46, 15, "celestial_6", 4, 15, 86)],
                  monsters: RpgMaps.sp([("celestial_guardian", 4), ("celestial_scorpio", 5), ("celestial_pegasus", 4), ("celestial_seraph", 5)]),
                  theme: RpgTheme(obstacle: .tree, pool: .water, tint: tint(1.0, 0.92, 0.75), tintAlpha: 0.4, blend: .softLight), waypoint: true),
        RpgMapDef(id: RpgMapID("celestial_6"), name: "은하수 다리", levelText: "Lv86~91", width: 50, height: 30, kind: .volcano, seed: 12006,
                  portals: [p(1, 15, "celestial_5", 43, 15, 83), p(48, 15, "celestial_7", 4, 15, 89)],
                  monsters: RpgMaps.sp([("celestial_pegasus", 4), ("celestial_seraph", 4), ("celestial_bell", 4), ("celestial_oracle", 5)]),
                  theme: RpgTheme(tint: tint(0.3, 0.4, 1.0), tintAlpha: 0.6, blend: .color, darkness: 0.4)),
        RpgMapDef(id: RpgMapID("celestial_7"), name: "황금 신전 성소", levelText: "Lv89~94", width: 50, height: 30, kind: .desert, seed: 12007,
                  portals: [p(1, 15, "celestial_6", 45, 15, 86), p(25, 1, "celestial_b2", 14, 17, 90)],
                  monsters: RpgMaps.sp([("celestial_seraph", 4), ("celestial_bell", 4), ("celestial_oracle", 4), ("celestial_sphinx", 4)]),
                  theme: RpgTheme(floor: .stone, obstacle: .pillar, pool: .water, decor: .sand, tint: tint(1.0, 0.8, 0.3), tintAlpha: 0.4, blend: .color, darkness: 0.15),
                  waypoint: true),
        RpgMapDef(id: RpgMapID("celestial_b1"), name: "황도의 제단", levelText: "보스 Lv86", width: 28, height: 22, kind: .boss, seed: 12008,
                  portals: [p(14, 20, "celestial_4", 25, 4, 79)], monsters: RpgMaps.sp([("celestial_leo", 1)]), zone: .castle,
                  theme: RpgTheme(tint: tint(0.3, 0.35, 0.85), tintAlpha: 0.5, blend: .color, darkness: 0.5)),
        RpgMapDef(id: RpgMapID("celestial_b2"), name: "빛의 옥좌", levelText: "보스 Lv95", width: 28, height: 22, kind: .boss, seed: 12009,
                  portals: [p(14, 20, "celestial_7", 25, 4, 89)], monsters: RpgMaps.sp([("celestial_archangel", 1)]), zone: .desert,
                  theme: RpgTheme(tint: tint(1.0, 0.9, 0.55), tintAlpha: 0.45, blend: .softLight, darkness: 0.25)),
    ]

    // MARK: monsters

    private static let monsters: [RpgMonsterDef] = {
        let m = RpgMonsters.m
        var list: [RpgMonsterDef] = [
            m("celestial_cherub", "큐피드 아기천사", "celestial_cherub", 70, 16850, 410, 114, 58, 6700, 1000...1450, .flyer, [("hp3", 0.08), ("mp2", 0.08), ("rod10", 0.004), ("sword10", 0.004), ("armor9", 0.004), ("boots9", 0.004), ("stone", 0.244), ("celestial_feather", 0.06), ("celestial_nectar", 0.02)]),
            m("celestial_sheep", "솜구름 양", "celestial_sheep", 71, 17550, 370, 149, 26, 6650, 980...1400, .passive, [("hp3", 0.08), ("bow10", 0.004), ("staff10", 0.004), ("armor9", 0.004), ("ring9", 0.004), ("stone", 0.246), ("celestial_feather", 0.06)]),
            m("celestial_bee", "황금 꿀벌떼", "celestial_bee", 73, 8700, 290, 68, 66, 4250, 585...850, .swarm, [("hp4", 0.1), ("dagger10", 0.004), ("mace10", 0.004), ("armor9", 0.004), ("amulet9", 0.004), ("stone", 0.15), ("celestial_feather", 0.05)]),
            m("celestial_goose", "황금알 거위", "celestial_goose", 74, 15700, 0, 200, 52, 10600, 4800...6900, .coward, [("hp4", 0.1), ("stone", 0.3), ("celestial_feather", 0.5), ("celestial_candy", 0.3), ("celestial_ring", 0.01)]),
            m("celestial_comet", "별똥별 폭탄", "celestial_comet", 75, 11600, 620, 88, 50, 8750, 1245...1800, .exploder, [("hp4", 0.1), ("sword10", 0.004), ("bow10", 0.004), ("armor9", 0.004), ("boots9", 0.004), ("stone", 0.154), ("celestial_feather", 0.05), ("celestial_candy", 0.02)]),
            m("celestial_lion", "황금 사자상", "celestial_lion", 77, 26900, 500, 191, 40, 11800, 1590...2300, .charger, [("hp4", 0.1), ("staff10", 0.004), ("dagger10", 0.004), ("armor10", 0.004), ("ring10", 0.004), ("stone", 0.158), ("celestial_feather", 0.06), ("celestial_boots", 0.002)]),
            m("celestial_priest", "태양 신전 사제", "celestial_priest", 79, 21000, 535, 133, 32, 10450, 1420...2050, .ranged, [("hp4", 0.08), ("mp2", 0.08), ("mace10", 0.004), ("claw10", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.262), ("celestial_feather", 0.06), ("celestial_nectar", 0.03)]),
            m("celestial_starsprite", "별자리 정령", "celestial_starsprite", 80, 22900, 490, 136, 60, 10400, 1405...2000, .flyer, [("hp4", 0.08), ("mp2", 0.08), ("rod10", 0.004), ("sword10", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.264), ("celestial_feather", 0.06), ("celestial_candy", 0.02), ("celestial_ring", 0.002)]),
            m("celestial_guardian", "황금 수호상", "celestial_guardian", 82, 37100, 590, 258, 24, 14050, 1870...2700, .aggressive, [("hp4", 0.08), ("bow11", 0.004), ("staff11", 0.004), ("armor10", 0.004), ("boots10", 0.004), ("stone", 0.268), ("celestial_stardust", 0.06)]),
            m("celestial_scorpio", "전갈자리", "celestial_scorpio", 84, 12050, 345, 82, 64, 7050, 830...1200, .swarm, [("hp4", 0.1), ("dagger11", 0.004), ("mace11", 0.004), ("armor10", 0.004), ("ring10", 0.004), ("stone", 0.172), ("celestial_stardust", 0.04)]),
            m("celestial_pegasus", "페가수스", "celestial_pegasus", 86, 33400, 595, 212, 46, 17700, 2105...3050, .charger, [("hp4", 0.1), ("claw11", 0.004), ("rod11", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.176), ("celestial_stardust", 0.05), ("celestial_nectar", 0.02)]),
            m("celestial_seraph", "세라핌 기사", "celestial_seraph", 88, 33450, 615, 217, 40, 15450, 1865...2650, .aggressive, [("hp5", 0.08), ("sword11", 0.004), ("bow11", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.28), ("celestial_stardust", 0.06), ("celestial_helm", 0.002)]),
            m("celestial_bell", "심판의 종", "celestial_bell", 90, 17650, 790, 113, 46, 17700, 1970...2850, .exploder, [("hp5", 0.1), ("staff11", 0.004), ("dagger11", 0.004), ("armor11", 0.004), ("boots11", 0.004), ("stone", 0.184), ("celestial_stardust", 0.05), ("celestial_candy", 0.02)]),
            m("celestial_oracle", "별을 읽는 무녀", "celestial_oracle", 92, 29850, 650, 163, 34, 18000, 2085...3000, .ranged, [("hp5", 0.08), ("mp3", 0.08), ("mace12", 0.004), ("claw12", 0.004), ("armor11", 0.004), ("ring11", 0.004), ("stone", 0.288), ("celestial_stardust", 0.06), ("celestial_nectar", 0.03), ("celestial_amulet", 0.002)]),
            m("celestial_sphinx", "황금 스핑크스", "celestial_sphinx", 93, 49650, 695, 305, 26, 22950, 2580...3700, .aggressive, [("hp5", 0.08), ("rod12", 0.004), ("sword12", 0.004), ("armor11", 0.004), ("amulet11", 0.004), ("stone", 0.29), ("celestial_stardust", 0.06)]),
        ]
        list.append(RpgMonsters.boss("celestial_leo", "황도의 사자 레굴루스", "celestial_leo", 86, 1_982_000, 869, 208, 38, 766_000, 88_000...147_000, .golem,
                                     minion: "celestial_starsprite", element: .holy,
                                     RpgMonsters.endgameBossLoot(weapon: 11, armor: [10, 9], gear: 10, rate: 0.5)
                                         + [("celestial_mane", 1), ("celestial_staff", 0.12), ("celestial_boots", 0.12), ("celestial_feather", 1), ("celestial_feather", 1),
                                            ("celestial_nectar", 0.5), ("hp4", 1)]))
        list.append(RpgMonsters.boss("celestial_archangel", "빛의 대천사 아스트라엘", "celestial_archangel", 95, 2_400_000, 1010, 238, 39, 1_380_000, 120_000...200_000, .demon,
                                     minion: "celestial_seraph", element: .holy,
                                     RpgMonsters.endgameBossLoot(weapon: 12, armor: [11, 10], gear: 11, rate: 0.75)
                                         + [("celestial_halo", 1), ("celestial_mace", 0.12), ("celestial_amulet", 0.1), ("celestial_helm", 0.1), ("celestial_ring", 0.1),
                                            ("celestial_stardust", 1), ("celestial_stardust", 1), ("hp5", 1)]))
        return list
    }()

    // MARK: items

    private static let items: [RpgItem] = [
        RpgItem(id: "celestial_feather", name: "천사의 깃털", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 12000, element: .base, inShop: false),
        RpgItem(id: "celestial_stardust", name: "별가루", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 20000, element: .base, inShop: false),
        RpgItem(id: "celestial_mane", name: "레굴루스의 황금 갈기", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 50000, element: .base, inShop: false),
        RpgItem(id: "celestial_halo", name: "대천사의 광륜", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 90000, element: .base, inShop: false),
        RpgItem(id: "celestial_nectar", name: "신들의 넥타르", kind: .potionMP, rarity: 3, attack: 0, defense: 0, heal: 1000, price: 1450, element: .base, inShop: false),
        RpgItem(id: "celestial_candy", name: "행운의 별사탕", kind: .buff("luck"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1300, element: .base, inShop: false),
        // Armor between tiers 10 (250) and 11 (330): a crafted bridge for the Lv84-89 stretch.
        RpgItem(id: "celestial_armor", name: "천상의 예복", kind: .armor, rarity: 4, attack: 0, defense: 290, heal: 0, price: 680_000, element: .base, inShop: false),
        // Tier 10 boots (13% / 84) → plated: 0.77 + 1.23.
        RpgItem(id: "celestial_boots", name: "황금 신전 경갑화", kind: .boots, rarity: 4, attack: 0, defense: 103, heal: 0, price: 950_000, element: .base, inShop: false,
                bonusSpeed: 0.10),
        // Tier 10 ring (3300 HP / 16% / 43%) → steady: 1.30 + 0.81 + 0.88.
        RpgItem(id: "celestial_ring", name: "별빛 맹세 반지", kind: .ring, rarity: 4, attack: 0, defense: 0, heal: 0, price: 1_000_000, element: .base, inShop: false,
                bonusHP: 4300, bonusCrit: 0.13, bonusAttack: 0.38),
        // Tier 11 helmet (4600 HP / 150) → more plate, less HP: 0.78 + 1.22.
        RpgItem(id: "celestial_helm", name: "세라핌의 날개 투구", kind: .helmet, rarity: 4, attack: 0, defense: 183, heal: 0, price: 1_500_000, element: .base, inShop: false,
                bonusHP: 3600),
        // Tier 11 amulet (6500 HP / 1200 MP / 190) → for casters: 0.80 + 1.58 + 0.63.
        RpgItem(id: "celestial_amulet", name: "광륜 목걸이", kind: .amulet, rarity: 4, attack: 0, defense: 120, heal: 0, price: 1_600_000, element: .base, inShop: false,
                bonusHP: 5200, bonusMP: 1900),
        // Same attack as the tier they drop at (staff11 290 fire, mace12 380 cosmic), holy instead.
        RpgItem(id: "celestial_staff", name: "별자리 지팡이", kind: .weapon(.mage), rarity: 4, attack: 290, defense: 0, heal: 0, price: 480_000, element: .holy, inShop: false),
        RpgItem(id: "celestial_mace", name: "태양의 성철퇴", kind: .weapon(.cleric), rarity: 4, attack: 380, defense: 0, heal: 0, price: 800_000, element: .holy, inShop: false),
    ]

    // MARK: recipes (the smith)

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "celestial_armor", output: "celestial_armor", count: 1, materials: ["celestial_feather": 22, "mat_time": 8, "stone": 20], gold: 650_000),
        RpgRecipe(id: "celestial_boots", output: "celestial_boots", count: 1, materials: ["celestial_feather": 18, "celestial_mane": 1, "stone": 20], gold: 900_000),
        RpgRecipe(id: "celestial_ring", output: "celestial_ring", count: 1, materials: ["celestial_stardust": 16, "mat_time": 10, "stone": 30], gold: 1_000_000),
        RpgRecipe(id: "celestial_helm", output: "celestial_helm", count: 1, materials: ["celestial_stardust": 20, "celestial_halo": 1, "stone": 35], gold: 1_400_000),
        RpgRecipe(id: "celestial_amulet", output: "celestial_amulet", count: 1, materials: ["celestial_stardust": 22, "celestial_halo": 1, "mat_void": 10, "stone": 40], gold: 1_500_000),
        RpgRecipe(id: "celestial_staff", output: "celestial_staff", count: 1, materials: ["celestial_feather": 14, "celestial_mane": 1, "stone": 25], gold: 480_000),
        RpgRecipe(id: "celestial_mace", output: "celestial_mace", count: 1, materials: ["celestial_halo": 2, "celestial_stardust": 26, "mat_void": 14, "stone": 45], gold: 800_000),
        RpgRecipe(id: "celestial_nectar", output: "celestial_nectar", count: 3, materials: ["celestial_feather": 1], gold: 1500),
    ]
}

// MARK: art

extension RpgArt {
    static let celestialAngel: RpgGrid = [
        "................", ".....KYYYYK.....", "......KKKK......", ".KK...KCCK...KK.", "KBBK.KCCCCK.KBBK", "KBBBKCSSSSCKBBBK",
        "KBBBKSKSSKSKBBBK", ".KBBKSSSSSSKBBK.", ".KBBBKSSSSKBBBK.", "..KBBKWWWWKBBK..", "...KKWWWWWWKK...", "....KWWYYWWK....",
        "....KWwWWwWK....", "...KWWWWWWWWK...", "...KwWWWWWWwK...", "....KKKKKKKK....",
    ]
    static let celestialLion: RpgGrid = [
        "................", "................", "..........KKKK..", ".........KYYYYK.", "........KYYyYYYK", "........KYTTTTYK",
        "........KYKTKTYK", "...KKKKKKYTTtTYK", "..KTTTTTKYYTTYYK", ".KTTTTTTTKYYYYK.", "KTKTTTTTTTKKKK..", "KTKTTTTTTTTTK...",
        ".KKTTKKKKTTKK...", "...KTK...KTK....", "...KtK...KtK....", "...KK....KK.....",
    ]
    static let celestialStar: RpgGrid = [
        "................", ".......KK.......", "......KYYK......", "......KYYK......", ".....KYWYYK.....", "KKKKKKYWYYKKKKKK",
        "KYYYYYYYYYYYYYyK", ".KYYYKYYYYKYYyK.", "..KYYYYYYYYYyK..", "...KYYYKKYYyK...", "...KYYYYYYYyK...", "..KYYYYKKYYYyK..",
        "..KYYYK..KYYyK..", ".KYYK......KyyK.", ".KKK........KKK.", "................",
    ]
    static let celestialSheep: RpgGrid = [
        "................", "................", "................", "................", ".....KK.KK......", "...KKWWKWWKK....",
        "..KWWWWWWWWWKK..", ".KWWWwWWWWWWWWK.", "KWWWWWWWWWKKKSSK", "KWWwWWWWWKSSSKSK", "KWWWWWWWWKSSSSSK", ".KWWWWWwWWKSSKK.",
        "..KWWWWWWWWKK...", "...KKSKKKSKK....", "....KSK.KSK.....", "....KK..KK......",
    ]
    /// A bumblebee, facing right.
    static let celestialBee: RpgGrid = endgameMirror([
        "................", "................", "................", "................", ".....KK..KK.....", "....KWWKKWWK....",
        "....KWWWKWWK....", ".....KWWKWK.....", "...KKKYYKKKK....", "..KYYKYYKYYYK...", ".KYKYKYYKYYYKK..", ".KYYYKYYKYYYKYK.",
        "..KYKKYYKYYKK...", "...KK.KK.KK.....", "................", "................",
    ])
    static let celestialGoose: RpgGrid = [
        "................", "................", ".........KKK....", "........KWWWK...", "........KWKWOK..", "........KWWWOOK.",
        ".........KWWK...", ".........KWWK...", "...KKKKKKKWWK...", "..KYYYYYYYWWK...", ".KYYWYYYYWWWK...", "KYYYYYYYYYWWK...",
        ".KYYYYYYYYYK....", "..KKKKKKKKK.....", ".....KOK.KOK....", ".....KK..KK.....",
    ]
    static let celestialBell: RpgGrid = [
        "................", ".......KK.......", "......KYYK......", ".....KKKKKK.....", "....KYYYYYYK....", "...KYWYYYYYyK...",
        "...KYWYYYYYyK...", "...KYYKYYKYyK...", "..KYYYYYYYYYyK..", "..KYYYYKKYYYyK..", ".KYYYYYYYYYYYyK.", ".KyyyyyyyyyyyyK.",
        ".KKKKKKKKKKKKKK.", ".......KK.......", "......KRRK......", ".......KK.......",
    ]
    static let celestialComet: RpgGrid = [
        "................", "................", ".........KKKK...", ".......KKYYYYK..", ".....KKFYWWYYYK.", "...KKFFYWWWYYYK.",
        ".KKFFFYYKYYKYYK.", "KFfFFYYYYYYYYYK.", ".KKFFFYYYKKYYYK.", "...KKFFYYYYYYK..", ".....KKFYYYYK...", ".......KKKKK....",
        "................", "................", "................", "................",
    ]

    /// Cupid: a heart-tipped arrow in hand.
    private static let celestialCherub = endgameStamp(celestialAngel, ["...KK...", "..KRRK..", "...KLLK.", "....KLLK", ".....KK."], 8, 8)
    /// Seraph knight: helmet, breastplate and a sword.
    private static let celestialSeraph = endgameStamp(celestialAngel, [
        "................", "................", "......KKKK......", ".....KMMMMK.....", ".....KMMMMK..KBK", ".....KSKSKSK.KMK",
        "...............M", "...............M", "...............M", ".....KMMMMK...KM", "....KMMRRMMK.KYK", "....KMmMMmMK..K.",
    ])
    /// Oracle: a veil over the hair and a robe of stars.
    private static let celestialOracle = endgameStamp(celestialAngel, [
        "................", "................", "................", "......KKKK......", ".....KPPPPK.....", "....KPSSSSPK....",
        "....KSKSSKSK....", "................", "................", "......KyWyK.....", ".....KWWWWyK....", ".....KWyWWWK....",
        "....KWWWWyWK....", "...KWyWWWWWWK...", "...KwWWWyWWwK...",
    ])
    /// Sun priest: the robed caster with a sun staff.
    private static let celestialPriest = endgameStamp(mage, [
        "...............O", "..............OWO", "...............O", "..............KL", "..............KL", "..............KL",
        "..............KL", "..............KL", "..............KL", "..............KL", "..............KL", "..............KL",
        "..............KL", "..............KK",
    ])
    /// Golden guardian: a halo and small wings on the stone body.
    private static let celestialGuardian = endgameStamp(golem, [
        "...KYYYYYYYYK...", "................", "................", "................", "................", "KWK............KW",
        "KWWK..........KWWK", ".KWK..........KWK.",
    ])
    /// Pegasus: the deer without antlers, with a mane and wings.
    private static let celestialPegasus = endgameStamp(frostDeer, [
        "________________", "________________", "..........KK.K__", "..K.......KK_KK_", ".KWK......KCCK..", ".KWWK....KCHKHKK",
        "..KWWK...KCHHHHK", "...KWWKKKCHHHKK.", "....KWWwK.......",
    ])
    /// Scorpio: the scorpion turned right and dotted with stars.
    private static let celestialScorpio = endgameMirror(endgameStamp(scorpion, [
        "................", "..........KK....", ".........KTWK...", ".........KTK....", "..........KTK...", "...........KWK..",
        "................", ".......W........", "....W.....W.....", "......T.......W.",
    ]))
    /// Sphinx: the lion with a human face under a striped headdress.
    private static let celestialSphinx = endgameStamp(celestialLion, [
        "................", "................", "..........KKKK..", ".........KGYGYK.", "........KYGYGYGK", "........KGSSSSYK",
        "........KYKSKSGK", "...KKKKKKGSSSSYK", "..KTTTTTKYKSSKGK", ".KTTTTTTTKGYGYK.",
    ])

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsCelestial: [String: SpriteSpec] = [
        "celestial_cherub": SpriteSpec(grid: celestialCherub, swap: ["Y": rgb(255, 220, 90), "C": rgb(255, 190, 120), "S": rgb(255, 214, 190), "W": rgb(255, 196, 220),
                                                                     "w": rgb(230, 140, 180), "B": rgb(255, 255, 255), "L": rgb(200, 140, 60), "R": rgb(230, 50, 90)]),
        "celestial_sheep": SpriteSpec(grid: celestialSheep, swap: ["W": rgb(252, 252, 255), "w": rgb(210, 215, 235), "S": rgb(255, 226, 200)]),
        "celestial_bee": SpriteSpec(grid: celestialBee, swap: ["Y": rgb(255, 210, 60), "W": rgb(220, 240, 255)]),
        "celestial_goose": SpriteSpec(grid: celestialGoose, swap: ["W": rgb(255, 255, 255), "O": rgb(255, 160, 40), "Y": rgb(255, 214, 60)]),
        "celestial_comet": SpriteSpec(grid: celestialComet, swap: ["Y": rgb(255, 220, 120), "W": rgb(255, 255, 230), "F": rgb(255, 120, 40), "f": rgb(255, 210, 90)]),
        "celestial_lion": SpriteSpec(grid: celestialLion, swap: ["Y": rgb(250, 200, 70), "y": rgb(200, 140, 40), "T": rgb(255, 230, 140), "t": rgb(220, 180, 90)]),
        "celestial_priest": SpriteSpec(grid: celestialPriest, swap: ["P": rgb(250, 246, 230), "p": rgb(230, 190, 90), "S": rgb(244, 200, 160), "Y": rgb(255, 210, 60),
                                                                     "L": rgb(200, 160, 70), "O": rgb(255, 230, 90), "W": rgb(255, 255, 255)]),
        "celestial_starsprite": SpriteSpec(grid: celestialStar, swap: ["Y": rgb(200, 230, 255), "y": rgb(120, 160, 240), "W": rgb(255, 255, 255)]),
        "celestial_guardian": SpriteSpec(grid: celestialGuardian, swap: ["N": rgb(240, 200, 90), "n": rgb(190, 140, 50), "Q": rgb(120, 230, 255), "Y": rgb(255, 240, 150),
                                                                         "W": rgb(255, 255, 255)]),
        "celestial_scorpio": SpriteSpec(grid: celestialScorpio, swap: ["T": rgb(50, 60, 140), "t": rgb(30, 36, 96), "R": rgb(255, 255, 255), "W": rgb(255, 255, 200)]),
        "celestial_pegasus": SpriteSpec(grid: celestialPegasus, swap: ["H": rgb(245, 245, 255), "h": rgb(200, 205, 225), "C": rgb(170, 220, 255), "T": rgb(245, 245, 255),
                                                                       "W": rgb(255, 255, 255), "w": rgb(200, 220, 250)]),
        "celestial_seraph": SpriteSpec(grid: celestialSeraph, swap: ["Y": rgb(255, 220, 90), "C": rgb(255, 214, 120), "S": rgb(250, 214, 180), "W": rgb(214, 222, 236),
                                                                     "w": rgb(150, 160, 190), "B": rgb(255, 255, 255), "M": rgb(214, 222, 236), "m": rgb(150, 160, 190),
                                                                     "R": rgb(90, 160, 255)]),
        "celestial_bell": SpriteSpec(grid: celestialBell, swap: ["Y": rgb(250, 200, 70), "y": rgb(200, 140, 40), "W": rgb(255, 250, 210), "R": rgb(210, 60, 60)]),
        "celestial_oracle": SpriteSpec(grid: celestialOracle, swap: ["Y": rgb(255, 220, 90), "S": rgb(250, 214, 180), "W": rgb(60, 50, 120), "w": rgb(40, 30, 90),
                                                                     "B": rgb(210, 200, 255), "P": rgb(60, 50, 120), "y": rgb(255, 255, 200)]),
        "celestial_sphinx": SpriteSpec(grid: celestialSphinx, swap: ["Y": rgb(60, 90, 200), "y": rgb(40, 60, 150), "T": rgb(250, 214, 120), "t": rgb(210, 170, 80),
                                                                     "G": rgb(255, 214, 80), "S": rgb(230, 180, 130)]),
        "celestial_leo": SpriteSpec(grid: celestialLion, swap: ["Y": rgb(255, 150, 40), "y": rgb(200, 90, 30), "T": rgb(255, 214, 110), "t": rgb(210, 150, 60)], boss: true),
        "celestial_archangel": SpriteSpec(grid: celestialAngel, swap: ["Y": rgb(255, 230, 120), "C": rgb(255, 240, 200), "S": rgb(250, 220, 190), "W": rgb(255, 214, 90),
                                                                       "w": rgb(210, 150, 50), "B": rgb(255, 255, 255)], boss: true),
    ]

    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCelestial: [String: [Character: CGColor]] = [
        "celestial_feather": ["B": rgb(255, 255, 255), "E": rgb(190, 210, 240)],
        "celestial_stardust": ["B": rgb(255, 240, 160), "E": rgb(110, 120, 220)],
        "celestial_mane": ["B": rgb(255, 190, 70), "E": rgb(200, 100, 30)],
        "celestial_halo": ["B": rgb(255, 250, 200), "E": rgb(240, 190, 60)],
        "celestial_nectar": ["B": rgb(255, 230, 120), "E": rgb(230, 150, 200)],
        "celestial_candy": ["B": rgb(255, 210, 240), "E": rgb(120, 200, 255)],
        "celestial_armor": ["B": rgb(255, 255, 250), "E": rgb(240, 200, 80)],
        "celestial_boots": ["B": rgb(255, 214, 90), "J": rgb(255, 255, 255), "W": rgb(255, 255, 255)],
        "celestial_ring": ["B": rgb(255, 230, 140), "J": rgb(140, 170, 255), "W": rgb(255, 255, 255)],
        "celestial_helm": ["B": rgb(240, 244, 255), "J": rgb(255, 214, 90), "W": rgb(255, 255, 255)],
        "celestial_amulet": ["B": rgb(255, 230, 140), "J": rgb(255, 250, 220), "W": rgb(255, 255, 255)],
        "celestial_staff": ["B": rgb(60, 60, 140), "G": rgb(255, 220, 110), "H": rgb(30, 30, 90), "O": rgb(200, 220, 255), "J": rgb(255, 255, 255)],
        "celestial_mace": ["B": rgb(255, 220, 90), "E": rgb(220, 150, 40), "G": rgb(255, 250, 220), "H": rgb(160, 110, 50), "W": rgb(255, 255, 255)],
    ]
}

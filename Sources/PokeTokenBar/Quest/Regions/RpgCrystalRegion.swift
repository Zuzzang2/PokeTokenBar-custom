import CoreGraphics
import Foundation

// 수정 광산 (Lv25-46): seven mine levels in a chain from the 차원문, the 두더지 왕 (Lv37) off level 4 and the 수정 거신 (Lv46) off level 7.
// Balance: every normal monster sits on the curve fitted to the main-line Lv22-58 monsters (the same curve the factory and sky-isle regions use):
//   base HP 0.9·L^2.3, attack 115·(L/28)^1.6, defense 0.03·L²+0.5·L, XP 0.213·L^2.4, gold 0.2·L² (±18%)
//   e.g. Lv25 1477/96/31/482/125 · Lv35 3203/164/54/1082/245 · Lv45 5710/246/83/1977/405 · Lv55 9059/339/118/3201/605
// times the average ratio of the existing monsters of that behaviour (hp/atk/def/xp/gold):
//   passive .88/.95/1/1/.95 · aggressive .92/1/1/1/.95 · golem-like tank 1.1/1/1.05/1.02/1.03 · flyer .7/1/.82/.93/.85 · ranged .8/1.03/.8/1/1
//   charger 1.18/1.06/.97/1.27/1.08 · swarm .31/.71/.49/.49/.46 · exploder .55/1.29/.52/1.1/.91 · treasure coward .8/0/.6/1.3/6
// Bosses: HP 98× the base HP of their level (the shipped bosses run 95-127×); attack, defense, XP and gold follow the shipped bosses'
// multiples, interpolated between 설인 왕 (Lv32), 화염 해골왕 (Lv42) and 마왕 (Lv58), so all bosses rise in that order.
// Gear: accessories on the tier-4/5 budget with a different spread (more crit, MP or speed, less HP), weapons 80 attack (tier 7 is 84).
// Recipes take the region's own materials plus gold and stones; the materials also sell, priced so a kill here is worth ~8% more
// than a main-line kill of its level (4-14% by monster).

enum RpgCrystalRegion {
    private static let c1 = RpgMapID("crystal_1"), c2 = RpgMapID("crystal_2"), c3 = RpgMapID("crystal_3"), c4 = RpgMapID("crystal_4")
    private static let c5 = RpgMapID("crystal_5"), c6 = RpgMapID("crystal_6"), c7 = RpgMapID("crystal_7")
    private static let b1 = RpgMapID("crystal_b1"), b2 = RpgMapID("crystal_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { .init(r: r / 255, g: g / 255, b: b / 255) }

    /// A grid with some cells repainted (the art overlay helper is private to `RpgArt`); shared by the crystal, factory and sky-isle sprites.
    static func mark(_ g: RpgGrid, _ marks: [(Int, Int, Character)]) -> RpgGrid {
        var rows = g.map { Array($0) }
        for (x, y, c) in marks where y < rows.count && x < rows[y].count { rows[y][x] = c }
        return rows.map { String($0) }
    }

    static let region = RpgRegion(id: "crystal", name: "수정 광산", blurb: "버려진 광산 깊은 곳에서 수정들이 숨을 쉬어요.", minLevel: 23,
                                  entry: c1, entryTile: RpgTile(x: 4, y: 14), maps: maps, monsters: monsters, items: items, recipes: recipes)

    // Gates: each door forward needs the next level's first level; doors back carry the gate of the map they lead to.
    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: c1, name: "버려진 갱도 입구", levelText: "Lv25~28", width: 46, height: 28, kind: .cave, seed: 5001,
                  portals: [RpgMaps.p(1, 14, .town, 4, 11), RpgMaps.p(44, 14, c2, 4, 16, minLevel: 28)],
                  monsters: RpgMaps.sp([("crystal_slime", 9), ("crystal_miner", 7), ("crystal_mole", 8)]),
                  theme: RpgTheme(tint: tint(255, 170, 80), tintAlpha: 0.28, darkness: 0.62), waypoint: true),
        RpgMapDef(id: c2, name: "광차 선로", levelText: "Lv28~31", width: 50, height: 32, kind: .castle, seed: 5002,
                  portals: [RpgMaps.p(1, 16, c1, 41, 14, minLevel: 23), RpgMaps.p(48, 16, c3, 4, 15, minLevel: 31)],
                  monsters: RpgMaps.sp([("crystal_miner", 6), ("crystal_mole", 7), ("crystal_bat", 6), ("crystal_cart", 5)]),
                  theme: RpgTheme(tint: tint(170, 110, 60), tintAlpha: 0.45, darkness: 0.5)),
        RpgMapDef(id: c3, name: "푸른 수정 동굴", levelText: "Lv31~34", width: 48, height: 30, kind: .cave, seed: 5003,
                  portals: [RpgMaps.p(1, 15, c2, 45, 16, minLevel: 28), RpgMaps.p(46, 15, c4, 4, 15, minLevel: 34)],
                  monsters: RpgMaps.sp([("crystal_bat", 7), ("crystal_cart", 5), ("crystal_tnt", 4), ("crystal_golem", 6)]),
                  theme: RpgTheme(tint: tint(80, 200, 255), tintAlpha: 0.42, darkness: 0.68), waypoint: true),
        RpgMapDef(id: c4, name: "자수정 갱도", levelText: "Lv34~37", width: 48, height: 30, kind: .cave, seed: 5004,
                  portals: [RpgMaps.p(1, 15, c3, 43, 15, minLevel: 31), RpgMaps.p(46, 15, c5, 4, 15, minLevel: 37), RpgMaps.p(24, 1, b1, 14, 17, minLevel: 35)],
                  monsters: RpgMaps.sp([("crystal_tnt", 4), ("crystal_golem", 6), ("crystal_thief", 2), ("crystal_eye", 7)]),
                  theme: RpgTheme(tint: tint(170, 90, 255), tintAlpha: 0.45, darkness: 0.7)),
        RpgMapDef(id: c5, name: "지하 수정 호수", levelText: "Lv37~40", width: 50, height: 30, kind: .volcano, seed: 5005,
                  portals: [RpgMaps.p(1, 15, c4, 43, 15, minLevel: 34), RpgMaps.p(48, 15, c6, 4, 15, minLevel: 40)],
                  monsters: RpgMaps.sp([("crystal_eye", 7), ("crystal_spider", 8), ("crystal_ghost", 7)]),
                  theme: RpgTheme(floor: .caveFloor, obstacle: .iceRock, pool: .water, tint: tint(60, 220, 210), tintAlpha: 0.3, darkness: 0.5), waypoint: true),
        RpgMapDef(id: c6, name: "루비 광맥", levelText: "Lv40~43", width: 50, height: 30, kind: .volcano, seed: 5006,
                  portals: [RpgMaps.p(1, 15, c5, 45, 15, minLevel: 37), RpgMaps.p(48, 15, c7, 4, 15, minLevel: 43)],
                  monsters: RpgMaps.sp([("crystal_spider", 6), ("crystal_ghost", 6), ("crystal_lizard", 5), ("crystal_beetle", 8)]),
                  theme: RpgTheme(tint: tint(255, 40, 120), tintAlpha: 0.35, darkness: 0.45)),
        RpgMapDef(id: c7, name: "수정 심장부", levelText: "Lv43~46", width: 50, height: 30, kind: .cave, seed: 5007,
                  portals: [RpgMaps.p(1, 15, c6, 45, 15, minLevel: 40), RpgMaps.p(25, 1, b2, 14, 17, minLevel: 44)],
                  monsters: RpgMaps.sp([("crystal_lizard", 5), ("crystal_beetle", 8), ("crystal_diamond", 7)]),
                  theme: RpgTheme(tint: tint(120, 255, 190), tintAlpha: 0.4, darkness: 0.5), waypoint: true),
        RpgMapDef(id: b1, name: "두더지 왕의 굴", levelText: "보스 Lv37", width: 28, height: 22, kind: .boss, seed: 5008,
                  portals: [RpgMaps.p(14, 20, c4, 24, 4, minLevel: 34)], monsters: RpgMaps.sp([("crystal_moleking", 1)]), zone: .cave,
                  theme: RpgTheme(tint: tint(190, 120, 70), tintAlpha: 0.35)),
        RpgMapDef(id: b2, name: "수정 거신의 제단", levelText: "보스 Lv46", width: 28, height: 22, kind: .boss, seed: 5009,
                  portals: [RpgMaps.p(14, 20, c7, 25, 4, minLevel: 43)], monsters: RpgMaps.sp([("crystal_colossus", 1)]), zone: .cave,
                  theme: RpgTheme(tint: tint(170, 120, 255), tintAlpha: 0.4)),
    ]

    private static let monsters: [RpgMonsterDef] = [
        RpgMonsters.m("crystal_slime", "반짝 수정 슬라임", "crystal_slime", 25, 1300, 91, 31, 32, 480, 95...140, .passive,
                      [("hp2", 0.08), ("crystal_shard", 0.08), ("crystal_dew", 0.04), ("sword6", 0.006), ("bow6", 0.006), ("armor5", 0.006), ("stone", 0.085)]),
        RpgMonsters.m("crystal_miner", "야근 해골 광부", "crystal_miner", 27, 1600, 108, 35, 36, 580, 115...165, .aggressive,
                      [("hp2", 0.08), ("crystal_shard", 0.08), ("crystal_dew", 0.04), ("staff6", 0.006), ("dagger6", 0.006), ("armor5", 0.006), ("stone", 0.091)]),
        RpgMonsters.m("crystal_mole", "굴착 두더지떼", "crystal_mole", 28, 590, 82, 18, 66, 310, 60...85, .swarm,
                      [("hp2", 0.1), ("crystal_shard", 0.08), ("stone", 0.061)]),
        RpgMonsters.m("crystal_bat", "보석눈 박쥐", "crystal_bat", 30, 1550, 128, 34, 56, 695, 125...180, .flyer,
                      [("hp2", 0.08), ("mp1", 0.08), ("crystal_shard", 0.08), ("crystal_dew", 0.04), ("mace6", 0.006), ("claw6", 0.006), ("armor5", 0.006), ("stone", 0.1)]),
        RpgMonsters.m("crystal_cart", "폭주 광차", "crystal_cart", 31, 2850, 143, 43, 46, 1030, 170...245, .charger,
                      [("hp2", 0.1), ("crystal_shard", 0.08), ("stone", 0.064)]),
        RpgMonsters.m("crystal_tnt", "다이너마이트 꾸러미", "crystal_tnt", 34, 1650, 202, 27, 50, 1110, 175...250, .exploder,
                      [("hp2", 0.1), ("crystal_shard", 0.08), ("crystal_amethyst", 0.06), ("stone", 0.067)]),
        RpgMonsters.m("crystal_golem", "자수정 골렘", "crystal_golem", 35, 3500, 164, 57, 24, 1100, 205...300, .aggressive,
                      [("hp3", 0.05), ("crystal_shard", 0.08), ("crystal_amethyst", 0.08), ("crystal_dew", 0.04), ("book_w_slam", 0.003), ("book_a_focus", 0.003), ("book_m_heal", 0.003), ("book_r_vanish", 0.003), ("rod7", 0.004), ("sword7", 0.004), ("armor6", 0.004), ("stone", 0.145)]),
        RpgMonsters.m("crystal_eye", "프리즘 눈알", "crystal_eye", 38, 3100, 193, 50, 34, 1320, 235...340, .ranged,
                      [("hp3", 0.05), ("mp1", 0.08), ("crystal_shard", 0.08), ("crystal_amethyst", 0.06), ("crystal_dew", 0.04), ("book_c_purify", 0.003), ("book_k_iron", 0.003), ("book_s_dragon", 0.003), ("staff7", 0.004), ("bow7", 0.004), ("armor6", 0.004), ("stone", 0.124)]),
        RpgMonsters.m("crystal_spider", "수정등 거미", "crystal_spider", 39, 3800, 195, 65, 40, 1400, 235...340, .aggressive,
                      [("hp3", 0.05), ("crystal_amethyst", 0.06), ("crystal_dew", 0.04), ("dagger7", 0.004), ("mace7", 0.004), ("armor6", 0.004), ("stone", 0.127)]),
        RpgMonsters.m("crystal_ghost", "길 잃은 광부 유령", "crystal_ghost", 41, 3250, 212, 58, 52, 1470, 235...335, .flyer,
                      [("hp3", 0.05), ("mp1", 0.08), ("crystal_amethyst", 0.06), ("crystal_core", 0.01), ("crystal_dew", 0.04), ("claw7", 0.004), ("rod7", 0.004), ("armor6", 0.004), ("stone", 0.133)]),
        RpgMonsters.m("crystal_lizard", "루비 도롱뇽", "crystal_lizard", 42, 5750, 233, 72, 44, 2130, 310...450, .charger,
                      [("hp3", 0.1), ("crystal_amethyst", 0.06), ("crystal_core", 0.01), ("stone", 0.075)]),
        RpgMonsters.m("crystal_beetle", "에메랄드 풍뎅이떼", "crystal_beetle", 43, 1600, 162, 38, 62, 870, 140...200, .swarm,
                      [("hp3", 0.1), ("crystal_amethyst", 0.06), ("stone", 0.076)]),
        RpgMonsters.m("crystal_diamond", "금강석 골렘", "crystal_diamond", 45, 6300, 246, 87, 22, 2020, 340...490, .aggressive,
                      [("hp3", 0.05), ("crystal_amethyst", 0.08), ("crystal_core", 0.02), ("crystal_dew", 0.04), ("crystal_helmet", 0.003), ("crystal_boots", 0.003), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001), ("book_r_ult", 0.001), ("book_c_ult", 0.001), ("book_k_ult", 0.001), ("book_s_ult", 0.001), ("sword7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("stone", 0.175)]),
        RpgMonsters.m("crystal_thief", "보석 도둑 두더지", "crystal_thief", 36, 2750, 0, 34, 46, 1500, 1275...1835, .coward,
                      [("hp3", 0.3), ("crystal_shard", 0.5), ("crystal_amethyst", 0.3), ("crystal_charm", 0.12), ("stone", 0.3)]),
        RpgMonsters.boss("crystal_moleking", "두더지 왕 드릴로", "crystal_moleking", 37, 355000, 268, 57, 34, 21000, 5700...8500, .yeti, minion: "crystal_mole", element: .base,
                         [("crystal_shard", 1), ("crystal_shard", 1), ("crystal_amethyst", 0.6), ("crystal_core", 0.35), ("crystal_helmet", 0.12), ("crystal_boots", 0.12), ("crystal_charm", 0.25), ("crystal_dew", 1), ("sword7", 0.06), ("bow7", 0.06), ("staff7", 0.06), ("dagger7", 0.06), ("mace7", 0.06), ("claw7", 0.06), ("rod7", 0.06), ("armor6", 0.15), ("book_w_slam", 0.05), ("book_a_focus", 0.05), ("book_m_heal", 0.05), ("book_r_vanish", 0.05), ("book_c_purify", 0.05), ("book_k_iron", 0.05), ("book_s_dragon", 0.05), ("hp3", 1)]),
        RpgMonsters.boss("crystal_colossus", "수정 거신 젬하트", "crystal_colossus", 46, 590000, 373, 80, 30, 41000, 12100...18200, .golem, minion: "crystal_eye", element: .ice,
                         [("crystal_core", 1), ("crystal_core", 0.5), ("crystal_amethyst", 1), ("crystal_amethyst", 1), ("crystal_pickaxe", 0.15), ("crystal_staff", 0.15), ("crystal_ring", 0.12), ("crystal_amulet", 0.12), ("crystal_helmet", 0.08), ("crystal_boots", 0.08), ("crystal_charm", 0.3), ("sword7", 0.1), ("bow7", 0.1), ("staff7", 0.1), ("dagger7", 0.1), ("mace7", 0.1), ("claw7", 0.1), ("rod7", 0.1), ("armor6", 0.2), ("ring5", 0.05), ("amulet5", 0.05), ("book_w_ult", 0.04), ("book_a_ult", 0.04), ("book_m_ult", 0.04), ("book_r_ult", 0.04), ("book_c_ult", 0.04), ("book_k_ult", 0.04), ("book_s_ult", 0.04), ("hp3", 1)]),
    ]

    private static let items: [RpgItem] = [
        RpgItem(id: "crystal_shard", name: "푸른 수정 조각", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 360, element: .base, inShop: false),
        RpgItem(id: "crystal_amethyst", name: "자수정 원석", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 900, element: .base, inShop: false),
        RpgItem(id: "crystal_core", name: "빛나는 수정핵", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 3000, element: .base, inShop: false),
        RpgItem(id: "crystal_dew", name: "수정 이슬", kind: .potionHP, rarity: 2, attack: 0, defense: 0, heal: 900, price: 500, element: .base, inShop: false),
        RpgItem(id: "crystal_charm", name: "광부의 행운 원석", kind: .buff("luck"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1200, element: .base, inShop: false),
        RpgItem(id: "crystal_ring", name: "프리즘 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 30000, element: .base, inShop: false,
                bonusHP: 200, bonusCrit: 0.10, bonusAttack: 0.12),
        RpgItem(id: "crystal_amulet", name: "광부의 등불 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 22, heal: 0, price: 28000, element: .base, inShop: false,
                bonusHP: 400, bonusMP: 260),
        RpgItem(id: "crystal_helmet", name: "광부의 안전모", kind: .helmet, rarity: 3, attack: 0, defense: 21, heal: 0, price: 26000, element: .base, inShop: false, bonusHP: 320),
        RpgItem(id: "crystal_boots", name: "수정 징 장화", kind: .boots, rarity: 3, attack: 0, defense: 6, heal: 0, price: 26000, element: .base, inShop: false, bonusSpeed: 0.08),
        RpgItem(id: "crystal_pickaxe", name: "수정 곡괭이", kind: .weapon(.warrior), rarity: 3, attack: 80, defense: 0, heal: 0, price: 36000, element: .ice, inShop: false),
        RpgItem(id: "crystal_staff", name: "프리즘 지팡이", kind: .weapon(.mage), rarity: 3, attack: 80, defense: 0, heal: 0, price: 36000, element: .holy, inShop: false),
    ]

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "crystal_ring", output: "crystal_ring", count: 1, materials: ["crystal_shard": 10, "crystal_amethyst": 5, "stone": 4], gold: 26000),
        RpgRecipe(id: "crystal_amulet", output: "crystal_amulet", count: 1, materials: ["crystal_shard": 10, "crystal_amethyst": 4, "stone": 3], gold: 24000),
        RpgRecipe(id: "crystal_helmet", output: "crystal_helmet", count: 1, materials: ["crystal_shard": 8, "crystal_amethyst": 4], gold: 22000),
        RpgRecipe(id: "crystal_boots", output: "crystal_boots", count: 1, materials: ["crystal_shard": 8, "crystal_amethyst": 4], gold: 22000),
        RpgRecipe(id: "crystal_pickaxe", output: "crystal_pickaxe", count: 1, materials: ["crystal_amethyst": 8, "crystal_core": 2, "stone": 8], gold: 32000),
        RpgRecipe(id: "crystal_staff", output: "crystal_staff", count: 1, materials: ["crystal_amethyst": 8, "crystal_core": 2, "stone": 8], gold: 32000),
        RpgRecipe(id: "crystal_dew", output: "crystal_dew", count: 3, materials: ["crystal_shard": 2], gold: 400),
    ]
}

extension RpgArt {
    static let crystalMole: RpgGrid = [
        "................", "................", "................", "................", ".....KKKKK......", "....KNNNNNKK....",
        "...KNNNNNNNNK...", "..KNNNNNNNKNNK..", "..KNNNNNNNNNNSK.", ".KNNNNNNNNNNSSK.", ".KNNNNCCCCNNKK..", ".KnNNCCCCCKSSK..",
        ".KnNNCCCCCKSKSK.", "..KnnNNNNNnKKK..", "...KSSK..KSSK...", "...KKKK..KKKK...",
    ]
    static let crystalCart: RpgGrid = [
        "................", "................", "................", "......KK..KK....", "....KKOOKKQQK...", "...KOOBOKQQQQK..",
        ".KKKKKKKKKKKKKK.", ".KMMMMMMMMMMMMK.", "..KLLLLLLKWKLK..", "..KlLLLLLKKKLK..", "..KLLLLLLLLLLK..", "...KmmmmmmmmK...",
        "..KKKK....KKKK..", ".KZzzZK..KZzzZK.", ".KzKKzK..KzKKzK.", "..KKKK....KKKK..",
    ]
    static let crystalTNT: RpgGrid = [
        ".........W......", "........fYf.....", ".........K......", "........K.......", "....KKK.KKK.KKK.", "...KRRrKRRrKRRrK",
        "...KRRrKRRrKRRrK", "...KRRrKRRrKRRrK", "...KCCCCCCCCCCCK", "...KCCKCCCCKCCCK", "...KCCCCKKCCCCCK", "...KRRrKRRrKRRrK",
        "...KRRrKRRrKRRrK", "...KRRrKRRrKRRrK", "....KKK.KKK.KKK.", "................",
    ]
    static let crystalGem: RpgGrid = [
        ".......KK.......", "......KBOK......", ".....KBOOOK.....", "....KBOOOOOK....", "...KBOOOOOOOK...", "..KBOKKKKKOOOK..",
        ".KBOKWWWWWKOOOK.", "KBOKWWWWWKKKOOPK", "KOOKWWWWWKKKOOPK", ".KOOKWWWWWKOOPK.", "..KOOKKKKKOOPK..", "...KPOOOOOOPK...",
        "....KPOOOOPK....", ".....KPPPPK.....", "......KPPK......", ".......KK.......",
    ]
    static let crystalSpider: RpgGrid = [
        "................", "................", "................", "......KKKK......", ".....KOBOOK.....", "....KOOBOOOK....",
        "..KKKAAAAAAKKK..", ".KAAAAAAAAAAAAK.", "KAKAAAAAAAAKRKRK", "KAKaAAAAAAAAAAAK", ".KKaaaaaaaaAAKK.", "..KK.KK..KK.KK..",
        ".K.K.K.KK.K.K.K.", "K..K.K..K.K..K.K", "...K..K....K....", "................",
    ]
    static let crystalGhost: RpgGrid = [
        "................", ".....KKKKKK.....", "....KYYYYYYK....", "...KYYYfYYYYK...", "...KKKKKKKKKK...", "...KBBBBBBBBK...",
        "..KBBKBBBBKBBK..", "..KBBKBBBBKBBK..", "..KBBBBKKBBBBKKK", "..KBBBBBBBBBBKfK", "..KBBBBBBBBBBKfK", "..KBBBBBBBBBBBKK",
        "..KBBBBBBBBBBBK.", "..KBBKBBBKBBBK..", "..KBK.KBK.KBK...", "..KK...K...KK...",
    ]
    static let crystalLizard: RpgGrid = [
        "................", "................", "................", "................", "................", "......K.K.K.....",
        ".....KWKWKWK....", "....KRRRRRRRKKK.", "KK.KRRRRRRRKRRRK", "KRKRRRRRRRRRRKRK", "KRRRRRRRRRRRRRRK", ".KrrRRRRRRRRRrK.",
        "..KKrrrrrrrrrK..", "....KrK.KrK.KK..", "....KK..KK......", "................",
    ]
    static let crystalBeetle: RpgGrid = [
        "................", "................", "................", "................", "......KKKKK.....", "....KKGGBGGKK...",
        "...KGGGGGBGGGK..", "..KGGGGGKGGGGKK.", "..KGGGGGKGGGGKKK", "..KgGGGGKGGGGKWK", "..KggggGKGggKKKK", "...KggggKgggK.K.",
        "...KKKKKKKKKK...", "..K.K..K..K..K..", ".K..K..K..K...K.", "................",
    ]
    static let crystalColossus: RpgGrid = [
        "......K..K......", ".....KOK.KOK....", "..K..KOOKOOK..K.", ".KOK.KOOKOOK.KOK", ".KOOKKKKKKKKKOOK", "..KKNNNNNNNNNKK.",
        "...KNOONNNOONK..", "..KKNNNNNNNNNKK.", ".KNNKNNKOKNNKNNK", "KNNNKNKOOOKNKNNK", "KNNKKNNKOKNNKKNK", ".KK.KNNNNNNNK.KK",
        "....KNNKKKNNK...", "...KNNNK.KNNNK..", "...KnnnK.KnnnK..", "...KKKKK.KKKKK..",
    ]

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsCrystal: [String: SpriteSpec] = [
        "crystal_slime": SpriteSpec(grid: RpgCrystalRegion.mark(slime, [(6, 2, "K"), (5, 3, "K"), (6, 3, "B"), (7, 3, "K"), (5, 4, "K"), (6, 4, "O"), (7, 4, "K"), (5, 5, "K"), (6, 5, "O"), (10, 3, "K"), (9, 4, "K"), (10, 4, "B"), (11, 4, "K"), (10, 5, "O"), (11, 5, "K")]), swap: ["E": rgb(206, 168, 245), "e": rgb(146, 108, 208), "W": rgb(255, 255, 255), "O": rgb(110, 236, 255), "B": rgb(230, 255, 255)]),
        "crystal_bat": SpriteSpec(grid: RpgCrystalRegion.mark(bat, [(0, 1, "K"), (0, 2, "O"), (1, 2, "K"), (0, 3, "O"), (1, 3, "B"), (2, 3, "K"), (15, 1, "K"), (14, 2, "K"), (15, 2, "O"), (13, 3, "K"), (14, 3, "B"), (15, 3, "O"), (7, 6, "O"), (8, 6, "O")]), swap: ["A": rgb(66, 62, 88), "a": rgb(42, 38, 58), "W": rgb(120, 240, 255), "O": rgb(120, 240, 255), "B": rgb(230, 255, 255)]),
        "crystal_miner": SpriteSpec(grid: RpgCrystalRegion.mark(skeleton, [(5, 0, "K"), (6, 0, "K"), (7, 0, "K"), (8, 0, "K"), (9, 0, "K"), (10, 0, "K"), (4, 1, "K"), (5, 1, "Y"), (6, 1, "Y"), (7, 1, "Y"), (8, 1, "Y"), (9, 1, "f"), (10, 1, "W"), (11, 1, "K"), (3, 2, "K"), (4, 2, "K"), (5, 2, "K"), (6, 2, "K"), (7, 2, "K"), (8, 2, "K"), (9, 2, "K"), (10, 2, "K"), (11, 2, "K"), (12, 2, "K"), (13, 4, "K"), (14, 4, "K"), (15, 4, "K"), (12, 5, "K"), (13, 5, "M"), (14, 5, "M"), (15, 5, "M"), (12, 6, "K"), (13, 6, "L"), (14, 6, "K"), (15, 6, "K"), (11, 7, "K"), (12, 7, "L"), (13, 7, "K"), (11, 8, "L"), (12, 8, "K")]), swap: ["X": rgb(214, 204, 182), "x": rgb(150, 140, 120)]),
        "crystal_mole": SpriteSpec(grid: RpgCrystalRegion.mark(crystalMole, [(5, 2, "K"), (6, 2, "K"), (7, 2, "K"), (8, 2, "K"), (4, 3, "K"), (5, 3, "Y"), (6, 3, "Y"), (7, 3, "Y"), (8, 3, "Y"), (9, 3, "K"), (10, 3, "K"), (3, 4, "K"), (4, 4, "Y"), (5, 4, "Y"), (6, 4, "Y"), (7, 4, "Y"), (8, 4, "Y"), (9, 4, "f"), (10, 4, "W"), (11, 4, "K"), (3, 5, "K"), (4, 5, "K"), (5, 5, "K"), (6, 5, "K"), (7, 5, "K"), (8, 5, "K"), (9, 5, "K"), (10, 5, "K"), (11, 5, "K"), (12, 5, "K")]), swap: ["N": rgb(98, 90, 124), "n": rgb(66, 60, 88), "C": rgb(198, 188, 216), "S": rgb(250, 160, 182)]),
        "crystal_cart": SpriteSpec(grid: crystalCart, swap: [:]),
        "crystal_tnt": SpriteSpec(grid: crystalTNT, swap: [:]),
        "crystal_golem": SpriteSpec(grid: RpgCrystalRegion.mark(golem, [(5, 0, "K"), (7, 0, "K"), (9, 0, "K"), (5, 1, "O"), (7, 1, "O"), (9, 1, "O"), (1, 2, "K"), (0, 3, "K"), (1, 3, "O"), (2, 3, "K"), (0, 4, "K"), (1, 4, "O"), (2, 4, "O"), (3, 4, "K"), (14, 2, "K"), (13, 3, "K"), (14, 3, "O"), (15, 3, "K"), (12, 4, "K"), (13, 4, "O"), (14, 4, "O"), (15, 4, "K")]), swap: ["N": rgb(152, 102, 204), "n": rgb(100, 62, 150), "Q": rgb(255, 236, 255), "O": rgb(255, 196, 250)]),
        "crystal_thief": SpriteSpec(grid: RpgCrystalRegion.mark(crystalMole, [(7, 7, "K"), (8, 7, "K"), (9, 7, "K"), (10, 7, "W"), (11, 7, "K"), (12, 7, "K"), (4, 6, "R"), (3, 7, "R"), (4, 7, "R"), (1, 4, "K"), (2, 4, "K"), (0, 5, "K"), (1, 5, "T"), (2, 5, "T"), (3, 5, "K"), (0, 6, "K"), (1, 6, "T"), (2, 6, "Y"), (3, 6, "T"), (4, 6, "K"), (0, 7, "K"), (1, 7, "T"), (2, 7, "T"), (0, 8, "K"), (1, 8, "Y"), (2, 8, "T"), (0, 9, "K"), (1, 9, "T"), (2, 9, "T"), (1, 10, "K")]), swap: ["N": rgb(150, 112, 74), "n": rgb(102, 72, 46), "C": rgb(232, 212, 172), "S": rgb(250, 170, 160), "T": rgb(206, 168, 96), "R": rgb(200, 40, 60)]),
        "crystal_eye": SpriteSpec(grid: crystalGem, swap: [:]),
        "crystal_spider": SpriteSpec(grid: crystalSpider, swap: [:]),
        "crystal_ghost": SpriteSpec(grid: crystalGhost, swap: ["B": rgb(204, 238, 236)]),
        "crystal_lizard": SpriteSpec(grid: crystalLizard, swap: ["W": rgb(255, 196, 222)]),
        "crystal_beetle": SpriteSpec(grid: crystalBeetle, swap: ["G": rgb(44, 200, 124), "g": rgb(22, 122, 82), "B": rgb(196, 255, 228), "W": rgb(255, 255, 196)]),
        "crystal_diamond": SpriteSpec(grid: crystalColossus, swap: ["N": rgb(206, 220, 236), "n": rgb(150, 166, 192), "O": rgb(110, 226, 255)]),
        "crystal_moleking": SpriteSpec(grid: RpgCrystalRegion.mark(crystalMole, [(11, 10, "K"), (12, 10, "M"), (13, 10, "K"), (10, 11, "K"), (11, 11, "M"), (12, 11, "M"), (13, 11, "m"), (14, 11, "K"), (10, 12, "K"), (11, 12, "M"), (12, 12, "M"), (13, 12, "M"), (14, 12, "m"), (15, 12, "K"), (10, 13, "K"), (11, 13, "m"), (12, 13, "m"), (13, 13, "m"), (14, 13, "K"), (10, 14, "K"), (11, 14, "K")]), swap: ["N": rgb(124, 78, 62), "n": rgb(82, 50, 38), "C": rgb(240, 212, 156), "S": rgb(255, 176, 164), "M": rgb(200, 206, 220), "m": rgb(130, 138, 158)], boss: true),
        "crystal_colossus": SpriteSpec(grid: crystalColossus, swap: ["N": rgb(112, 98, 164), "n": rgb(72, 62, 112), "O": rgb(120, 240, 255)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCrystal: [String: [Character: CGColor]] = [
        "crystal_shard": ["B": rgb(90, 230, 210), "E": rgb(30, 150, 140)],
        "crystal_amethyst": ["B": rgb(240, 120, 210), "E": rgb(150, 50, 140)],
        "crystal_core": ["B": rgb(255, 200, 255), "E": rgb(90, 200, 255)],
        "crystal_dew": ["B": rgb(255, 150, 190), "E": rgb(210, 80, 130), "C": rgb(200, 236, 245)],
        "crystal_charm": ["B": rgb(90, 220, 200), "E": rgb(230, 180, 60)],
        "crystal_ring": ["B": rgb(200, 220, 240), "J": rgb(150, 230, 255), "W": rgb(255, 255, 255)],
        "crystal_amulet": ["B": rgb(190, 140, 80), "J": rgb(255, 210, 90), "W": rgb(255, 255, 220)],
        "crystal_helmet": ["B": rgb(240, 196, 50), "J": rgb(255, 255, 200)],
        "crystal_boots": ["B": rgb(110, 100, 130), "J": rgb(150, 240, 255)],
        "crystal_pickaxe": ["B": rgb(170, 235, 255), "E": rgb(80, 160, 220), "G": rgb(120, 90, 60), "H": rgb(100, 64, 36), "J": rgb(170, 235, 255)],
        "crystal_staff": ["O": rgb(230, 200, 255), "J": rgb(255, 255, 255), "G": rgb(200, 170, 90), "B": rgb(110, 90, 150), "H": rgb(70, 56, 100)],
    ]
}

import CoreGraphics
import Foundation

// 기계 공장 (Lv30-54): an abandoned steam factory, seven halls in a chain from the 차원문, the boiler (Lv44) off hall 4 and the
// factory master (Lv54) off hall 7. Monsters use the same fitted curve and behaviour ratios as `RpgCrystalRegion` (see the table there):
//   Lv30 2247/128/42/747/180 · Lv40 4355/203/68/1490/320 · Lv50 7276/291/100/2546/500 (base HP/attack/defense/XP/gold).
// Bosses: HP 30× / 38× base, attack 1.5× / 1.45×, XP 10× / 13×. Gear: accessories on the tier-5 budget (gear ring: more attack, less HP;
// piston boots: tier-7 speed with little defense), weapons and armor between tier 7 (84 / 75) and tier 8 (130 / 112).
// Recipes take the band's banded `mat_*` materials: the content checks accept no other recipe input yet, so the region's own
// materials are sell loot for now, priced so a kill here is worth ~8% more than a main-line kill of its level (4-14% by monster).

enum RpgFactoryRegion {
    private static let f1 = RpgMapID("factory_1"), f2 = RpgMapID("factory_2"), f3 = RpgMapID("factory_3"), f4 = RpgMapID("factory_4")
    private static let f5 = RpgMapID("factory_5"), f6 = RpgMapID("factory_6"), f7 = RpgMapID("factory_7")
    private static let b1 = RpgMapID("factory_b1"), b2 = RpgMapID("factory_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { .init(r: r / 255, g: g / 255, b: b / 255) }

    static let region = RpgRegion(id: "factory", name: "기계 공장", blurb: "멈추지 않는 기계들이 주인 없는 공장을 지켜요.", minLevel: 28,
                                  entry: f1, entryTile: RpgTile(x: 4, y: 15), maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: f1, name: "녹슨 고철장", levelText: "Lv30~33", width: 50, height: 30, kind: .volcano, seed: 6001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), RpgMaps.p(48, 15, f2, 4, 16, minLevel: 33)],
                  monsters: RpgMaps.sp([("factory_oilslime", 9), ("factory_rat", 8), ("factory_robot", 7), ("factory_drone", 6)]),
                  theme: RpgTheme(obstacle: .castleWall, pool: .water, tint: tint(200, 120, 70), tintAlpha: 0.3, darkness: 0.15), waypoint: true),
        RpgMapDef(id: f2, name: "컨베이어 홀", levelText: "Lv33~37", width: 50, height: 32, kind: .castle, seed: 6002,
                  portals: [RpgMaps.p(1, 16, f1, 45, 15, minLevel: 28), RpgMaps.p(48, 16, f3, 4, 14, minLevel: 37)],
                  monsters: RpgMaps.sp([("factory_robot", 6), ("factory_drone", 6), ("factory_forklift", 5), ("factory_bomb", 4)]),
                  theme: RpgTheme(tint: tint(200, 210, 225), tintAlpha: 0.6, darkness: 0.3)),
        RpgMapDef(id: f3, name: "배관 터널", levelText: "Lv37~40", width: 46, height: 28, kind: .cave, seed: 6003,
                  portals: [RpgMaps.p(1, 14, f2, 45, 16, minLevel: 33), RpgMaps.p(44, 14, f4, 4, 16, minLevel: 40)],
                  monsters: RpgMaps.sp([("factory_forklift", 5), ("factory_bomb", 4), ("factory_turret", 6), ("factory_spider", 7)]),
                  theme: RpgTheme(tint: tint(110, 220, 120), tintAlpha: 0.35, darkness: 0.68), waypoint: true),
        RpgMapDef(id: f4, name: "증기 보일러실", levelText: "Lv40~44", width: 50, height: 32, kind: .castle, seed: 6004,
                  portals: [RpgMaps.p(1, 16, f3, 41, 14, minLevel: 37), RpgMaps.p(48, 16, f5, 4, 15, minLevel: 44), RpgMaps.p(25, 1, b1, 14, 17, minLevel: 42)],
                  monsters: RpgMaps.sp([("factory_turret", 5), ("factory_spider", 6), ("factory_mouse", 2), ("factory_golem", 6)]),
                  theme: RpgTheme(tint: tint(255, 90, 40), tintAlpha: 0.5, darkness: 0.35)),
        RpgMapDef(id: f5, name: "용광로 구역", levelText: "Lv44~47", width: 50, height: 30, kind: .volcano, seed: 6005,
                  portals: [RpgMaps.p(1, 15, f4, 45, 16, minLevel: 40), RpgMaps.p(48, 15, f6, 4, 15, minLevel: 47)],
                  monsters: RpgMaps.sp([("factory_golem", 6), ("factory_ironslime", 8), ("factory_bomber", 6), ("factory_guard", 6)]),
                  theme: RpgTheme(obstacle: .castleWall, tint: tint(255, 110, 40), tintAlpha: 0.3, darkness: 0.35), waypoint: true),
        RpgMapDef(id: f6, name: "냉각수 저장고", levelText: "Lv47~51", width: 50, height: 30, kind: .volcano, seed: 6006,
                  portals: [RpgMaps.p(1, 15, f5, 45, 15, minLevel: 44), RpgMaps.p(48, 15, f7, 4, 16, minLevel: 51)],
                  monsters: RpgMaps.sp([("factory_bomber", 6), ("factory_guard", 6), ("factory_tank", 5), ("factory_laser", 6)]),
                  theme: RpgTheme(floor: .castleFloor, obstacle: .pillar, pool: .water, tint: tint(120, 220, 230), tintAlpha: 0.45, darkness: 0.25)),
        RpgMapDef(id: f7, name: "중앙 제어실", levelText: "Lv51~54", width: 50, height: 32, kind: .castle, seed: 6007,
                  portals: [RpgMaps.p(1, 16, f6, 45, 15, minLevel: 47), RpgMaps.p(25, 1, b2, 14, 17, minLevel: 52)],
                  monsters: RpgMaps.sp([("factory_tank", 5), ("factory_laser", 7), ("factory_android", 7)]),
                  theme: RpgTheme(tint: tint(80, 255, 170), tintAlpha: 0.35, darkness: 0.48), waypoint: true),
        RpgMapDef(id: b1, name: "보일러 심장부", levelText: "보스 Lv44", width: 28, height: 22, kind: .boss, seed: 6008,
                  portals: [RpgMaps.p(14, 20, f4, 25, 4, minLevel: 40)], monsters: RpgMaps.sp([("factory_boiler", 1)]), zone: .volcano,
                  theme: RpgTheme(tint: tint(255, 120, 50), tintAlpha: 0.35)),
        RpgMapDef(id: b2, name: "공장장 집무실", levelText: "보스 Lv54", width: 28, height: 22, kind: .boss, seed: 6009,
                  portals: [RpgMaps.p(14, 20, f7, 25, 4, minLevel: 51)], monsters: RpgMaps.sp([("factory_gigaton", 1)]), zone: .castle,
                  theme: RpgTheme(tint: tint(120, 255, 200), tintAlpha: 0.3)),
    ]

    private static let monsters: [RpgMonsterDef] = [
        RpgMonsters.m("factory_oilslime", "기름때 슬라임", "factory_oilslime", 30, 2000, 122, 42, 30, 745, 140...200, .passive,
                      [("hp2", 0.08), ("factory_bolt", 0.08), ("factory_oil", 0.04), ("sword6", 0.006), ("bow6", 0.006), ("armor5", 0.006), ("stone", 0.1)]),
        RpgMonsters.m("factory_rat", "태엽 쥐떼", "factory_rat", 32, 810, 101, 23, 68, 425, 75...110, .swarm,
                      [("hp2", 0.1), ("factory_bolt", 0.08), ("stone", 0.065)]),
        RpgMonsters.m("factory_robot", "퇴근 못한 청소봇", "factory_robot", 33, 2550, 150, 49, 34, 940, 170...245, .aggressive,
                      [("hp2", 0.08), ("factory_bolt", 0.08), ("factory_oil", 0.04), ("factory_battery", 0.02), ("staff6", 0.006), ("dagger6", 0.006), ("armor6", 0.004), ("stone", 0.109)]),
        RpgMonsters.m("factory_drone", "감시 드론", "factory_drone", 34, 2100, 157, 42, 58, 940, 160...230, .flyer,
                      [("hp2", 0.08), ("mp1", 0.08), ("factory_bolt", 0.08), ("factory_oil", 0.04), ("mace7", 0.004), ("claw7", 0.004), ("armor6", 0.004), ("stone", 0.112)]),
        RpgMonsters.m("factory_forklift", "폭주 지게차", "factory_forklift", 36, 4050, 182, 55, 48, 1470, 230...330, .charger,
                      [("hp2", 0.1), ("factory_bolt", 0.08), ("stone", 0.069)]),
        RpgMonsters.m("factory_bomb", "자폭 깡통", "factory_bomb", 37, 2000, 232, 31, 48, 1360, 205...295, .exploder,
                      [("hp2", 0.1), ("factory_bolt", 0.08), ("stone", 0.07)]),
        RpgMonsters.m("factory_spider", "정비 거미봇", "factory_spider", 40, 4000, 203, 68, 42, 1490, 250...360, .aggressive,
                      [("hp3", 0.05), ("factory_bolt", 0.08), ("factory_gear", 0.06), ("factory_oil", 0.04), ("book_w_slam", 0.003), ("book_a_focus", 0.003), ("book_m_heal", 0.003), ("book_r_vanish", 0.003), ("rod7", 0.004), ("sword7", 0.004), ("armor6", 0.004), ("stone", 0.13)]),
        RpgMonsters.m("factory_turret", "자동 포탑", "factory_turret", 39, 3300, 201, 52, 26, 1400, 250...360, .ranged,
                      [("hp3", 0.05), ("mp1", 0.08), ("factory_bolt", 0.08), ("factory_gear", 0.06), ("factory_oil", 0.04), ("book_c_purify", 0.003), ("book_k_iron", 0.003), ("book_s_dragon", 0.003), ("bow7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("stone", 0.127)]),
        RpgMonsters.m("factory_golem", "증기 골렘", "factory_golem", 43, 5650, 228, 81, 24, 1810, 310...450, .aggressive,
                      [("hp3", 0.05), ("factory_gear", 0.08), ("factory_core", 0.01), ("factory_oil", 0.04), ("factory_battery", 0.02), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001), ("book_r_ult", 0.001), ("dagger7", 0.004), ("mace7", 0.004), ("armor6", 0.004), ("stone", 0.169)]),
        RpgMonsters.m("factory_ironslime", "쇳물 슬라임", "factory_ironslime", 45, 5000, 233, 83, 30, 1980, 315...455, .passive,
                      [("hp3", 0.05), ("factory_gear", 0.06), ("factory_oil", 0.04), ("staff7", 0.004), ("dagger7", 0.004), ("armor6", 0.004), ("stone", 0.145)]),
        RpgMonsters.m("factory_bomber", "폭격 드론", "factory_bomber", 46, 4200, 254, 71, 56, 1940, 295...425, .flyer,
                      [("hp3", 0.05), ("mp1", 0.08), ("factory_gear", 0.06), ("factory_oil", 0.04), ("claw7", 0.004), ("rod7", 0.004), ("armor6", 0.004), ("stone", 0.148)]),
        RpgMonsters.m("factory_guard", "강철 경비병", "factory_guard", 47, 5800, 263, 90, 38, 2190, 345...495, .aggressive,
                      [("hp3", 0.05), ("factory_gear", 0.06), ("factory_core", 0.01), ("factory_oil", 0.04), ("sword7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("stone", 0.151)]),
        RpgMonsters.m("factory_tank", "미니 전차", "factory_tank", 50, 8600, 308, 97, 40, 3230, 445...635, .charger,
                      [("hp3", 0.1), ("factory_gear", 0.06), ("factory_core", 0.01), ("stone", 0.083)]),
        RpgMonsters.m("factory_laser", "레이저 포탑", "factory_laser", 51, 6100, 309, 83, 24, 2670, 425...615, .ranged,
                      [("hp3", 0.05), ("mp1", 0.08), ("factory_gear", 0.06), ("factory_core", 0.01), ("factory_oil", 0.04), ("bow7", 0.004), ("dagger7", 0.004), ("armor6", 0.004), ("armor7", 0.002), ("stone", 0.163)]),
        RpgMonsters.m("factory_android", "시제품 안드로이드", "factory_android", 53, 9150, 319, 116, 30, 2990, 475...685, .aggressive,
                      [("hp3", 0.05), ("factory_gear", 0.08), ("factory_core", 0.02), ("factory_oil", 0.04), ("factory_goggles", 0.003), ("factory_pistonboots", 0.003), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001), ("book_r_ult", 0.001), ("book_c_ult", 0.001), ("book_k_ult", 0.001), ("book_s_ult", 0.001), ("mace7", 0.004), ("claw7", 0.004), ("rod7", 0.004), ("armor6", 0.004), ("armor7", 0.002), ("mace8", 0.0015), ("claw8", 0.0015), ("rod8", 0.0015), ("stone", 0.199)]),
        RpgMonsters.m("factory_mouse", "황금 태엽쥐", "factory_mouse", 41, 3700, 0, 43, 50, 2060, 1655...2380, .coward,
                      [("hp3", 0.3), ("factory_bolt", 0.5), ("factory_gear", 0.3), ("factory_battery", 0.15), ("stone", 0.3)]),
        RpgMonsters.boss("factory_boiler", "폭주 보일러 빵빵이", "factory_boiler", 44, 165000, 356, 76, 36, 18500, 4600...7000, .skeleton, minion: "factory_bomb", element: .fire,
                         [("factory_bolt", 1), ("factory_bolt", 1), ("factory_gear", 0.6), ("factory_core", 0.35), ("factory_goggles", 0.12), ("factory_pistonboots", 0.12), ("factory_battery", 0.4), ("factory_oil", 1), ("sword7", 0.07), ("bow7", 0.07), ("staff7", 0.07), ("dagger7", 0.07), ("mace7", 0.07), ("claw7", 0.07), ("rod7", 0.07), ("armor6", 0.15), ("book_w_ult", 0.03), ("book_a_ult", 0.03), ("book_m_ult", 0.03), ("book_r_ult", 0.03), ("book_c_ult", 0.03), ("book_k_ult", 0.03), ("book_s_ult", 0.03), ("hp3", 1)]),
        RpgMonsters.boss("factory_gigaton", "공장장 기가톤", "factory_gigaton", 54, 330000, 477, 109, 38, 40000, 9300...14000, .demon, minion: "factory_spider", element: .thunder,
                         [("factory_core", 1), ("factory_core", 0.5), ("factory_gear", 1), ("factory_gear", 1), ("factory_wrench", 0.15), ("factory_drillfist", 0.15), ("factory_armor", 0.12), ("factory_gearring", 0.12), ("factory_amulet", 0.12), ("factory_goggles", 0.08), ("factory_pistonboots", 0.08), ("sword7", 0.1), ("bow7", 0.1), ("staff7", 0.1), ("dagger7", 0.1), ("mace7", 0.1), ("claw7", 0.1), ("rod7", 0.1), ("sword8", 0.03), ("bow8", 0.03), ("staff8", 0.03), ("dagger8", 0.03), ("mace8", 0.03), ("claw8", 0.03), ("rod8", 0.03), ("armor7", 0.08), ("ring6", 0.05), ("amulet6", 0.05), ("book_w_ult", 0.05), ("book_a_ult", 0.05), ("book_m_ult", 0.05), ("book_r_ult", 0.05), ("book_c_ult", 0.05), ("book_k_ult", 0.05), ("book_s_ult", 0.05), ("hp3", 1)]),
    ]

    private static let items: [RpgItem] = [
        RpgItem(id: "factory_bolt", name: "녹슨 볼트", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 540, element: .base, inShop: false),
        RpgItem(id: "factory_gear", name: "정밀 톱니바퀴", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 1260, element: .base, inShop: false),
        RpgItem(id: "factory_core", name: "증기 동력핵", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 3600, element: .base, inShop: false),
        RpgItem(id: "factory_oil", name: "고급 윤활유", kind: .potionMP, rarity: 2, attack: 0, defense: 0, heal: 350, price: 480, element: .base, inShop: false),
        RpgItem(id: "factory_battery", name: "과충전 배터리", kind: .buff("speed"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 400, element: .base, inShop: false),
        RpgItem(id: "factory_gearring", name: "톱니바퀴 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 60000, element: .base, inShop: false,
                bonusHP: 320, bonusCrit: 0.05, bonusAttack: 0.20),
        RpgItem(id: "factory_amulet", name: "태엽 심장 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 26, heal: 0, price: 55000, element: .base, inShop: false,
                bonusHP: 1400, bonusMP: 100),
        RpgItem(id: "factory_goggles", name: "증기 고글", kind: .helmet, rarity: 3, attack: 0, defense: 30, heal: 0, price: 52000, element: .base, inShop: false, bonusHP: 560),
        RpgItem(id: "factory_pistonboots", name: "피스톤 부츠", kind: .boots, rarity: 3, attack: 0, defense: 10, heal: 0, price: 56000, element: .base, inShop: false, bonusSpeed: 0.10),
        RpgItem(id: "factory_wrench", name: "거대 몽키 스패너", kind: .weapon(.cleric), rarity: 3, attack: 100, defense: 0, heal: 0, price: 70000, element: .thunder, inShop: false),
        RpgItem(id: "factory_drillfist", name: "드릴 권갑", kind: .weapon(.monk), rarity: 3, attack: 100, defense: 0, heal: 0, price: 70000, element: .wind, inShop: false),
        RpgItem(id: "factory_armor", name: "강철 작업복", kind: .armor, rarity: 3, attack: 0, defense: 92, heal: 0, price: 85000, element: .base, inShop: false),
    ]

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "factory_gearring", output: "factory_gearring", count: 1, materials: ["mat_magma": 10, "mat_dark": 6, "stone": 6], gold: 55000),
        RpgRecipe(id: "factory_amulet", output: "factory_amulet", count: 1, materials: ["mat_magma": 10, "mat_dark": 5, "stone": 5], gold: 50000),
        RpgRecipe(id: "factory_goggles", output: "factory_goggles", count: 1, materials: ["mat_magma": 9, "mat_dark": 6], gold: 46000),
        RpgRecipe(id: "factory_pistonboots", output: "factory_pistonboots", count: 1, materials: ["mat_magma": 8, "mat_dark": 7, "stone": 4], gold: 50000),
        RpgRecipe(id: "factory_wrench", output: "factory_wrench", count: 1, materials: ["mat_dark": 10, "mat_wraith": 5, "stone": 10], gold: 65000),
        RpgRecipe(id: "factory_drillfist", output: "factory_drillfist", count: 1, materials: ["mat_dark": 10, "mat_wraith": 5, "stone": 10], gold: 65000),
        RpgRecipe(id: "factory_armor", output: "factory_armor", count: 1, materials: ["mat_dark": 12, "mat_wraith": 6, "stone": 8], gold: 70000),
        RpgRecipe(id: "factory_battery", output: "factory_battery", count: 3, materials: ["mat_magma": 2], gold: 300),
    ]
}

extension RpgArt {
    static let factoryRobot: RpgGrid = [
        "........K.......", ".......KRK......", "........K.......", ".....KKKKKKK....", "....KMMMMMMMK...", "....KMKKKKKMK...",
        "....KMKOKKOMK...", "....KMKKKKKMK...", "....KmmmmmmmK...", "...KKKKKKKKKKK..", "..KMKMMMMMMKMK..", "..KMKMMYYMMKMKK.",
        "..KKKmmmmmmKKMMK", "....KmmmmmmK.KK.", "...KZZZKKZZZK...", "...KKKKKKKKKK...",
    ]
    static let factoryDrone: RpgGrid = [
        "................", "................", ".ZZZZZ....ZZZZZ.", "...KK......KK...", "...KK......KK...", "..KKKKKKKKKKKK..",
        "..KMMMMMMMMMMK..", "...KMMMMMKKKK...", "...KMMMMKOOOOK..", "...KMRMMKOWOOK..", "...KmMMMKOOOOK..", "....KmmmmKKKK...",
        ".....K.....K....", "....KK.....KK...", "................", "................",
    ]
    static let factoryBomb: RpgGrid = [
        "................", "...........KK...", "..........KRRK..", "...........KK...", "...........K....", "......KKKKKK....",
        "....KKzzzzzzKK..", "...KzzZzzzzzzzK.", "..KzzZzzzzzKWKzK", "..KzZzzzzzzKKKzK", "..KYYYYYYYYYYYYK", "..KzzzzzzzzzzzzK",
        "...KzzzzzzzzzzK.", "....KKzzzzzzKK..", "....KMK....KMK..", "....KKK....KKK..",
    ]
    static let factoryTurret: RpgGrid = [
        "................", "................", "................", "................", ".....KKKKK......", "....KMMMMMK.....",
        "...KMMRRMMKKKKK.", "...KMMRWMMMMMMMK", "...KMMMMMMKKKKK.", "...KmmmmmmK.....", "..KKKKKKKKKK....", "..KZZZZZZZZK....",
        "...KZzzzzZK.....", "..KZK.KK.KZK....", ".KZK..KK..KZK...", ".KK...KK...KK...",
    ]
    static let factoryTank: RpgGrid = [
        "................", "................", "................", "................", "................", "......KKKKK.....",
        ".....KGGGGGKKKKK", ".....KGGKGGGGGGK", "...KKKKKKKKKKKK.", "..KGGGGGGGGGGGGK", "..KgGGGYGGGYGGgK", ".KKKKKKKKKKKKKKK",
        ".KzKzKzKzKzKzKzK", ".KzzzzzzzzzzzzzK", "..KKKKKKKKKKKKK.", "................",
    ]

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsFactory: [String: SpriteSpec] = [
        "factory_oilslime": SpriteSpec(grid: RpgCrystalRegion.mark(slime, [(7, 3, "K"), (8, 3, "K"), (9, 3, "K"), (6, 4, "K"), (7, 4, "M"), (8, 4, "K"), (9, 4, "M"), (10, 4, "K"), (9, 8, "O"), (10, 9, "P"), (11, 8, "O")]), swap: ["E": rgb(98, 72, 46), "e": rgb(62, 44, 28), "W": rgb(255, 222, 132), "M": rgb(176, 182, 196), "O": rgb(120, 230, 200), "P": rgb(190, 130, 255)]),
        "factory_rat": SpriteSpec(grid: RpgCrystalRegion.mark(crystalMole, [(9, 2, "K"), (10, 2, "K"), (8, 3, "K"), (9, 3, "S"), (10, 3, "S"), (11, 3, "K"), (8, 4, "K"), (9, 4, "S"), (10, 4, "K"), (0, 12, "K"), (0, 13, "z"), (1, 14, "z"), (2, 14, "K"), (0, 6, "K"), (1, 6, "Y"), (0, 7, "Y"), (1, 7, "Y"), (2, 7, "K"), (0, 8, "K"), (1, 8, "Y")]), swap: ["N": rgb(166, 172, 188), "n": rgb(112, 118, 134), "C": rgb(212, 216, 226), "S": rgb(255, 166, 176), "z": rgb(120, 120, 136), "Y": rgb(222, 182, 72)]),
        "factory_robot": SpriteSpec(grid: factoryRobot, swap: [:]),
        "factory_drone": SpriteSpec(grid: factoryDrone, swap: [:]),
        "factory_forklift": SpriteSpec(grid: RpgCrystalRegion.mark(crystalCart, [(13, 2, "K"), (13, 3, "K"), (14, 3, "z"), (13, 4, "K"), (14, 4, "z"), (14, 5, "z"), (14, 6, "z"), (13, 10, "K"), (14, 10, "M"), (15, 10, "M"), (13, 11, "K"), (14, 11, "M"), (15, 11, "M")]), swap: ["L": rgb(240, 196, 54), "l": rgb(190, 140, 30), "M": rgb(92, 92, 104), "m": rgb(60, 60, 70), "O": rgb(204, 154, 76), "Q": rgb(150, 104, 54), "B": rgb(242, 222, 162), "W": rgb(255, 90, 60), "z": rgb(70, 70, 80)]),
        "factory_bomb": SpriteSpec(grid: factoryBomb, swap: [:]),
        "factory_spider": SpriteSpec(grid: RpgCrystalRegion.mark(crystalSpider, [(7, 1, "R"), (7, 2, "K")]), swap: ["A": rgb(162, 168, 182), "a": rgb(104, 110, 126), "O": rgb(255, 112, 72), "B": rgb(255, 222, 200), "R": rgb(120, 255, 255)]),
        "factory_turret": SpriteSpec(grid: factoryTurret, swap: [:]),
        "factory_mouse": SpriteSpec(grid: RpgCrystalRegion.mark(crystalMole, [(9, 2, "K"), (10, 2, "K"), (8, 3, "K"), (9, 3, "S"), (10, 3, "S"), (11, 3, "K"), (8, 4, "K"), (9, 4, "S"), (10, 4, "K"), (0, 12, "K"), (0, 13, "z"), (1, 14, "z"), (2, 14, "K"), (0, 6, "K"), (1, 6, "Y"), (0, 7, "Y"), (1, 7, "Y"), (2, 7, "K"), (0, 8, "K"), (1, 8, "Y")]), swap: ["N": rgb(255, 214, 72), "n": rgb(214, 150, 32), "C": rgb(255, 242, 178), "S": rgb(255, 150, 120), "z": rgb(214, 150, 32), "Y": rgb(255, 255, 200)]),
        "factory_golem": SpriteSpec(grid: RpgCrystalRegion.mark(golem, [(9, 0, "K"), (10, 0, "K"), (11, 0, "K"), (9, 1, "K"), (10, 1, "W"), (11, 1, "K"), (7, 8, "K"), (8, 8, "W"), (9, 8, "K"), (1, 6, "Y"), (14, 6, "Y"), (5, 10, "Y"), (10, 10, "Y")]), swap: ["N": rgb(192, 116, 70), "n": rgb(126, 72, 42), "Q": rgb(120, 255, 222), "W": rgb(236, 236, 228), "Y": rgb(255, 214, 120)]),
        "factory_ironslime": SpriteSpec(grid: RpgCrystalRegion.mark(slime, [(3, 9, "F"), (8, 10, "F"), (9, 10, "F"), (12, 11, "F"), (5, 12, "F"), (7, 14, "F"), (8, 14, "f"), (7, 15, "f"), (5, 4, "f"), (10, 3, "f"), (9, 4, "F")]), swap: ["E": rgb(150, 154, 170), "e": rgb(92, 94, 110), "W": rgb(230, 236, 250), "F": rgb(255, 130, 30), "f": rgb(255, 220, 100)]),
        "factory_bomber": SpriteSpec(grid: RpgCrystalRegion.mark(factoryDrone, [(7, 12, "K"), (8, 12, "K"), (6, 13, "K"), (7, 13, "z"), (8, 13, "z"), (9, 13, "K"), (7, 14, "K"), (8, 14, "K")]), swap: ["M": rgb(204, 66, 52), "m": rgb(132, 36, 30), "O": rgb(255, 222, 92), "R": rgb(255, 255, 130), "Z": rgb(196, 196, 206), "z": rgb(60, 60, 70)]),
        "factory_guard": SpriteSpec(grid: RpgCrystalRegion.mark(warrior, [(5, 5, "z"), (6, 5, "O"), (7, 5, "O"), (8, 5, "O"), (9, 5, "O"), (10, 5, "z"), (5, 6, "z"), (6, 6, "z"), (7, 6, "z"), (8, 6, "z"), (9, 6, "z"), (10, 6, "z"), (6, 7, "z"), (7, 7, "z"), (8, 7, "z"), (9, 7, "z")]), swap: ["M": rgb(132, 142, 158), "m": rgb(82, 90, 106), "R": rgb(255, 152, 40), "r": rgb(182, 92, 22), "B": rgb(255, 232, 122), "S": rgb(104, 112, 128), "z": rgb(44, 46, 58), "O": rgb(120, 255, 255), "L": rgb(70, 70, 84), "Y": rgb(255, 152, 40)]),
        "factory_tank": SpriteSpec(grid: factoryTank, swap: ["G": rgb(116, 136, 74), "g": rgb(74, 90, 46), "Y": rgb(255, 212, 64)]),
        "factory_laser": SpriteSpec(grid: RpgCrystalRegion.mark(factoryTurret, [(15, 7, "R")]), swap: ["M": rgb(66, 66, 86), "m": rgb(40, 40, 56), "R": rgb(255, 44, 92), "W": rgb(255, 204, 230), "Z": rgb(112, 112, 132), "z": rgb(72, 72, 92)]),
        "factory_android": SpriteSpec(grid: RpgCrystalRegion.mark(factoryRobot, [(8, 0, "."), (7, 1, "."), (8, 1, "."), (9, 1, "."), (8, 2, "."), (3, 4, "K"), (3, 5, "K"), (4, 5, "O"), (3, 6, "K"), (4, 6, "O"), (12, 4, "K"), (12, 5, "O"), (13, 5, "K"), (12, 6, "O"), (13, 6, "K"), (13, 11, "K"), (14, 11, "R"), (15, 11, "K"), (13, 12, "M"), (14, 12, "R"), (15, 12, "R")]), swap: ["M": rgb(234, 238, 248), "m": rgb(170, 178, 198), "O": rgb(255, 66, 102), "R": rgb(120, 255, 255), "Y": rgb(120, 255, 255), "Z": rgb(92, 98, 112)]),
        "factory_boiler": SpriteSpec(grid: RpgCrystalRegion.mark(factoryBomb, [(10, 1, "K"), (11, 1, "K"), (12, 1, "K"), (13, 1, "K"), (10, 2, "K"), (11, 2, "M"), (12, 2, "M"), (13, 2, "K"), (10, 3, "K"), (11, 3, "M"), (12, 3, "M"), (13, 3, "K"), (10, 4, "K"), (11, 4, "M"), (12, 4, "M"), (13, 4, "K"), (11, 0, "W"), (12, 0, "W")]), swap: ["z": rgb(192, 102, 52), "Z": rgb(246, 172, 102), "Y": rgb(255, 226, 112), "R": rgb(255, 92, 42), "M": rgb(112, 112, 124), "W": rgb(255, 255, 255)], boss: true),
        "factory_gigaton": SpriteSpec(grid: RpgCrystalRegion.mark(factoryRobot, [(4, 2, "K"), (3, 3, "K"), (4, 3, "Y"), (5, 3, "K"), (12, 2, "K"), (11, 3, "K"), (12, 3, "Y"), (13, 3, "K")]), swap: ["M": rgb(98, 98, 118), "m": rgb(62, 62, 78), "O": rgb(255, 62, 62), "R": rgb(255, 212, 62), "Y": rgb(255, 212, 62), "Z": rgb(62, 62, 72)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsFactory: [String: [Character: CGColor]] = [
        "factory_bolt": ["B": rgb(180, 120, 80), "E": rgb(110, 66, 40)],
        "factory_gear": ["B": rgb(170, 190, 215), "E": rgb(90, 105, 130)],
        "factory_core": ["B": rgb(255, 245, 120), "E": rgb(90, 200, 255)],
        "factory_oil": ["B": rgb(90, 70, 40), "E": rgb(50, 36, 20), "W": rgb(255, 220, 130)],
        "factory_battery": ["B": rgb(200, 255, 80), "E": rgb(60, 60, 70), "C": rgb(200, 200, 210)],
        "factory_gearring": ["B": rgb(210, 160, 70), "J": rgb(120, 255, 220), "W": rgb(255, 255, 255)],
        "factory_amulet": ["B": rgb(150, 160, 180), "J": rgb(255, 90, 70), "W": rgb(255, 230, 200)],
        "factory_goggles": ["B": rgb(140, 100, 60), "J": rgb(120, 230, 255)],
        "factory_pistonboots": ["B": rgb(120, 130, 150), "J": rgb(255, 180, 60)],
        "factory_wrench": ["B": rgb(180, 190, 205), "W": rgb(255, 255, 255), "E": rgb(110, 120, 140), "G": rgb(220, 60, 50), "H": rgb(90, 90, 100)],
        "factory_drillfist": ["B": rgb(210, 215, 225), "W": rgb(255, 255, 255), "E": rgb(130, 135, 150), "G": rgb(240, 190, 50), "H": rgb(100, 80, 50)],
        "factory_armor": ["B": rgb(120, 130, 150), "E": rgb(255, 170, 40)],
    ]
}

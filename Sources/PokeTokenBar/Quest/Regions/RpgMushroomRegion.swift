import CoreGraphics
import Foundation

// 버섯 왕국 (Lv15-36). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
// Monster stats follow the curve documented in `RpgCoastRegion.swift` (shipped monsters interpolated, per-behaviour factors).
//   snail 15 passive · soldier 17 aggr · pixie 19 flyer · pig 20 charger · puffball 21 exploder · firefly 22 swarm · gnome 23 aggr
//   wizard 25 ranged · moth 28 flyer · wolf 29 charger · spore cannon 31 ranged · golem 32 tank · guard 33 aggr · jester 34 coward
//   bosses: spore queen 28 (30x HP), mushroom king 36 (40x HP). Signature gear spends the tier-4 accessory / tier-6-7 weapon budgets.

enum RpgMushroomRegion {
    private static func door(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, gate: Int = 1) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func weapons(tier t: Int, _ chance: Double) -> [(String, Double)] { RpgClass.allCases.map { ("\($0.weaponPrefix)\(t)", chance) } }
    private static let books28 = ["book_w_slam", "book_a_focus", "book_m_heal", "book_r_vanish", "book_c_purify", "book_k_iron", "book_s_dragon"]
    private static let books35 = ["book_w_ult", "book_a_ult", "book_m_ult", "book_r_ult", "book_c_ult", "book_k_ult", "book_s_ult"]

    static let region = RpgRegion(
        id: "mushroom", name: "버섯 왕국", blurb: "반짝이는 포자가 흩날리는, 버섯 왕이 다스리는 동화 속 왕국",
        minLevel: 13, entry: RpgMapID("mushroom_1"), entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: RpgMapID("mushroom_1"), name: "포자 들판", levelText: "Lv15~18", width: 50, height: 30, kind: .field, seed: 3001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), door(48, 15, "mushroom_2", 4, 15, gate: 17)],
                      monsters: RpgMaps.sp([("mushroom_snail", 11), ("mushroom_soldier", 10), ("mushroom_pixie", 7)]),
                      theme: RpgTheme(floor: .grass, obstacle: .tree, pool: .water, decor: .flower, tint: .init(r: 1, g: 0.55, b: 0.8), tintAlpha: 0.22, blend: .overlay),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("mushroom_2"), name: "거대버섯 숲", levelText: "Lv17~21", width: 50, height: 30, kind: .forest, seed: 3002,
                      portals: [door(1, 15, "mushroom_1", 45, 15, gate: 13), door(48, 15, "mushroom_3", 4, 15, gate: 20)],
                      monsters: RpgMaps.sp([("mushroom_soldier", 8), ("mushroom_pixie", 9), ("mushroom_pig", 5), ("mushroom_bomb", 4)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .tree, pool: .water, decor: .flower, tint: .init(r: 0.3, g: 0.8, b: 0.75), tintAlpha: 0.75, blend: .hue)),
            RpgMapDef(id: RpgMapID("mushroom_3"), name: "반딧불 동굴", levelText: "Lv20~24", width: 50, height: 30, kind: .cave, seed: 3003,
                      portals: [door(1, 15, "mushroom_2", 45, 15, gate: 17), door(48, 15, "mushroom_4", 4, 15, gate: 23)],
                      monsters: RpgMaps.sp([("mushroom_bomb", 4), ("mushroom_firefly", 10), ("mushroom_gnome", 9), ("mushroom_pig", 4)]),
                      theme: RpgTheme(tint: .init(r: 0.5, g: 1, b: 0.65), tintAlpha: 0.32, blend: .color, darkness: 0.62), waypoint: true),
            RpgMapDef(id: RpgMapID("mushroom_4"), name: "버섯 마을", levelText: "Lv23~27", width: 50, height: 30, kind: .field, seed: 3004,
                      portals: [door(1, 15, "mushroom_3", 45, 15, gate: 20), door(48, 15, "mushroom_5", 4, 15, gate: 26), door(25, 1, "mushroom_b1", 14, 17, gate: 25)],
                      monsters: RpgMaps.sp([("mushroom_gnome", 8), ("mushroom_firefly", 7), ("mushroom_wizard", 8), ("mushroom_moth", 6)]),
                      theme: RpgTheme(floor: .grass, obstacle: .tree, pool: .water, decor: .path, tint: .init(r: 1, g: 0.75, b: 0.45), tintAlpha: 0.2, blend: .softLight)),
            RpgMapDef(id: RpgMapID("mushroom_5"), name: "하얀 포자 숲", levelText: "Lv26~30", width: 50, height: 30, kind: .snow, seed: 3005,
                      portals: [door(1, 15, "mushroom_4", 45, 15, gate: 23), door(48, 15, "mushroom_6", 4, 15, gate: 29)],
                      monsters: RpgMaps.sp([("mushroom_wizard", 9), ("mushroom_moth", 11), ("mushroom_wolf", 6)]),
                      theme: RpgTheme(floor: .snow, obstacle: .tree, pool: .water, tint: .init(r: 0.82, g: 0.68, b: 1), tintAlpha: 0.35, blend: .multiply),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("mushroom_6"), name: "썩은 균사 황무지", levelText: "Lv29~33", width: 50, height: 30, kind: .volcano, seed: 3006,
                      portals: [door(1, 15, "mushroom_5", 45, 15, gate: 26), door(48, 15, "mushroom_7", 4, 16, gate: 32)],
                      monsters: RpgMaps.sp([("mushroom_moth", 11), ("mushroom_wolf", 6), ("mushroom_cannon", 9), ("mushroom_golem", 5)]),
                      theme: RpgTheme(floor: .ash, obstacle: .rock, pool: .water, decor: .ash, tint: .init(r: 0.62, g: 0.38, b: 0.85), tintAlpha: 0.4, blend: .color,
                                      darkness: 0.25)),
            RpgMapDef(id: RpgMapID("mushroom_7"), name: "버섯 왕성", levelText: "Lv32~35", width: 50, height: 32, kind: .castle, seed: 3007,
                      portals: [door(1, 16, "mushroom_6", 45, 15, gate: 29), door(25, 1, "mushroom_b2", 14, 17, gate: 33)],
                      monsters: RpgMaps.sp([("mushroom_cannon", 8), ("mushroom_golem", 4), ("mushroom_guard", 12), ("mushroom_jester", 2)]),
                      theme: RpgTheme(tint: .init(r: 1, g: 0.5, b: 0.75), tintAlpha: 0.4, blend: .color, darkness: 0.3), waypoint: true),
            RpgMapDef(id: RpgMapID("mushroom_b1"), name: "포자 여왕의 정원", levelText: "보스 Lv28", width: 28, height: 22, kind: .boss, seed: 3008,
                      portals: [door(14, 20, "mushroom_4", 25, 4, gate: 23)], monsters: RpgMaps.sp([("mushroom_queen", 1)]), zone: .snow,
                      theme: RpgTheme(tint: .init(r: 0.85, g: 0.6, b: 1), tintAlpha: 0.35, blend: .multiply)),
            RpgMapDef(id: RpgMapID("mushroom_b2"), name: "버섯 왕의 옥좌", levelText: "보스 Lv36", width: 28, height: 22, kind: .boss, seed: 3009,
                      portals: [door(14, 20, "mushroom_7", 25, 4, gate: 32)], monsters: RpgMaps.sp([("mushroom_king", 1)]), zone: .castle,
                      theme: RpgTheme(tint: .init(r: 1, g: 0.55, b: 0.75), tintAlpha: 0.4, blend: .color, darkness: 0.45)),
        ],
        monsters: [
            RpgMonsters.m("mushroom_snail", "이끼 달팽이", "mushroom_snail", 15, 440, 50, 15, 14, 155, 40...63, .passive,
                          [("hp1", 0.12), ("mushroom_spore", 0.1), ("mushroom_dew", 0.03), ("stone", 0.065)]),
            RpgMonsters.m("mushroom_soldier", "버섯 병정", "mushroom_soldier", 17, 560, 59, 17, 34, 205, 50...80, .aggressive,
                          [("hp1", 0.1), ("mushroom_spore", 0.08), ("mushroom_soup", 0.02), ("sword3", 0.008), ("armor3", 0.01), ("stone", 0.07)]),
            RpgMonsters.m("mushroom_pixie", "포자 요정", "mushroom_pixie", 19, 505, 63, 14, 58, 210, 50...80, .flyer,
                          [("mp0", 0.12), ("mushroom_dew", 0.05), ("mushroom_spore", 0.06), ("stone", 0.075)]),
            RpgMonsters.m("mushroom_pig", "송로 돼지", "mushroom_pig", 20, 955, 75, 21, 42, 355, 80...125, .charger,
                          [("hp1", 0.1), ("mushroom_truffle", 0.02), ("mushroom_cap", 0.05), ("stone", 0.05)]),
            RpgMonsters.m("mushroom_bomb", "펑펑 말불버섯", "mushroom_bomb", 21, 485, 98, 12, 46, 340, 75...115, .exploder,
                          [("hp1", 0.1), ("mushroom_spore", 0.1), ("stone", 0.05)]),
            RpgMonsters.m("mushroom_firefly", "반딧불 떼", "mushroom_firefly", 22, 330, 59, 12, 66, 175, 35...55, .swarm,
                          [("hp2", 0.1), ("mushroom_spore", 0.06), ("stone", 0.05)]),
            RpgMonsters.m("mushroom_gnome", "곡괭이 노움", "mushroom_gnome", 23, 930, 87, 26, 36, 385, 75...115, .aggressive,
                          [("hp2", 0.08), ("mushroom_cap", 0.06), ("mushroom_truffle", 0.008), ("armor5", 0.004), ("claw6", 0.004), ("mace6", 0.004), ("stone", 0.09)]),
            RpgMonsters.m("mushroom_wizard", "버섯갓 마법사", "mushroom_wizard", 25, 845, 93, 22, 32, 430, 80...125, .ranged,
                          [("mp1", 0.06), ("hp2", 0.05), ("mushroom_cap", 0.06), ("mushroom_clover", 0.02), ("staff6", 0.004), ("mushroom_amulet", 0.003), ("stone", 0.09)]
                          + books28.map { ($0, 0.004) }),
            RpgMonsters.m("mushroom_moth", "독가루 나방", "mushroom_moth", 28, 1160, 112, 26, 50, 520, 85...135, .flyer,
                          [("mp1", 0.06), ("hp2", 0.06), ("mushroom_spore", 0.08), ("mushroom_dew", 0.04), ("stone", 0.1)]),
            RpgMonsters.m("mushroom_wolf", "균사 늑대", "mushroom_wolf", 29, 2300, 129, 37, 50, 850, 135...215, .charger,
                          [("hp2", 0.1), ("mushroom_cap", 0.08), ("mushroom_boots", 0.003), ("sword6", 0.004), ("dagger6", 0.004), ("stone", 0.07)]),
            RpgMonsters.m("mushroom_cannon", "포자 대포 버섯", "mushroom_cannon", 31, 1720, 128, 32, 12, 735, 115...185, .ranged,
                          [("mp1", 0.08), ("hp2", 0.06), ("mushroom_spore", 0.1), ("mushroom_truffle", 0.01), ("bow7", 0.003), ("stone", 0.11)]
                          + books28.map { ($0, 0.004) }),
            RpgMonsters.m("mushroom_golem", "버섯 골렘", "mushroom_golem", 32, 2920, 141, 52, 22, 870, 145...230, .aggressive,
                          [("hp2", 0.08), ("mushroom_cap", 0.08), ("mushroom_truffle", 0.015), ("armor6", 0.004), ("mushroom_helmet", 0.003), ("stone", 0.15)]),
            RpgMonsters.m("mushroom_guard", "버섯 근위병", "mushroom_guard", 33, 2540, 148, 47, 38, 885, 145...225, .aggressive,
                          [("hp2", 0.08), ("mushroom_soup", 0.04), ("mushroom_ring", 0.003), ("sword7", 0.003), ("mace7", 0.003), ("armor6", 0.004), ("stone", 0.115)]),
            RpgMonsters.m("mushroom_jester", "도망치는 궁정 광대", "mushroom_jester", 34, 2130, 0, 48, 50, 1120, 790...1235, .coward,
                          [("hp2", 0.3), ("mushroom_truffle", 0.3), ("mushroom_clover", 0.15), ("ring4", 0.03), ("amulet4", 0.03), ("mushroom_ring", 0.01),
                           ("mushroom_amulet", 0.01), ("stone", 0.3)]),
            RpgMonsters.boss("mushroom_queen", "포자 여왕 티타니아", "mushroom_queen", 28, 48500, 163, 35, 40, 4290, 850...1250, .demon,
                             minion: "mushroom_pixie", element: .poison,
                             [("hp2", 1), ("mushroom_spore", 1), ("mushroom_spore", 1), ("mushroom_truffle", 0.5), ("mushroom_dew", 0.6), ("mushroom_boots", 0.2),
                              ("mushroom_amulet", 0.2), ("armor6", 0.08), ("armor5", 0.12)] + weapons(tier: 6, 0.05) + books28.map { ($0, 0.06) }),
            RpgMonsters.boss("mushroom_king", "버섯 대왕 송이", "mushroom_king", 36, 122500, 255, 54, 32, 10600, 2300...3400, .slime, minion: "mushroom_soldier",
                             element: .holy,
                             [("hp3", 1), ("mushroom_cap", 1), ("mushroom_cap", 1), ("mushroom_truffle", 0.7), ("mushroom_soup", 0.6), ("mushroom_staff", 0.2),
                              ("mushroom_mace", 0.2), ("mushroom_armor", 0.2), ("mushroom_ring", 0.15), ("mushroom_amulet", 0.15), ("mushroom_helmet", 0.15),
                              ("mushroom_boots", 0.15), ("armor6", 0.15), ("ring4", 0.05), ("amulet4", 0.05), ("helmet4", 0.05), ("boots4", 0.05)]
                             + weapons(tier: 7, 0.08) + weapons(tier: 6, 0.06) + books28.map { ($0, 0.08) } + books35.map { ($0, 0.03) }),
        ],
        items: [
            RpgItem(id: "mushroom_spore", name: "반짝이 포자", kind: .material, rarity: 0, attack: 0, defense: 0, heal: 0, price: 150, element: .base, inShop: false),
            RpgItem(id: "mushroom_cap", name: "무지개 버섯갓", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 500, element: .base, inShop: false),
            RpgItem(id: "mushroom_truffle", name: "황금 송로버섯", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 2400, element: .base, inShop: false),
            RpgItem(id: "mushroom_soup", name: "요정 버섯 수프", kind: .potionHP, rarity: 2, attack: 0, defense: 0, heal: 900, price: 450, element: .base, inShop: false),
            RpgItem(id: "mushroom_dew", name: "이슬 맺힌 버섯", kind: .potionMP, rarity: 1, attack: 0, defense: 0, heal: 120, price: 160, element: .base, inShop: false),
            RpgItem(id: "mushroom_clover", name: "네잎 포자 부적", kind: .buff("luck"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1200, element: .base, inShop: false),
            // Tier-4 accessories (Lv26-36), weapons between tier 6 and 7, armor between armor 5 and 6.
            RpgItem(id: "mushroom_ring", name: "요정의 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 24000, element: .base, inShop: false,
                    bonusHP: 300, bonusCrit: 0.08, bonusAttack: 0.11),
            RpgItem(id: "mushroom_amulet", name: "포자 여왕의 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 17, heal: 0, price: 24000, element: .base, inShop: false,
                    bonusHP: 480, bonusMP: 190),
            RpgItem(id: "mushroom_helmet", name: "버섯갓 투구", kind: .helmet, rarity: 3, attack: 0, defense: 11, heal: 0, price: 22000, element: .base, inShop: false, bonusHP: 620),
            RpgItem(id: "mushroom_boots", name: "폭신폭신 버섯 신발", kind: .boots, rarity: 3, attack: 0, defense: 9, heal: 0, price: 22000, element: .base, inShop: false,
                    bonusSpeed: 0.07),
            RpgItem(id: "mushroom_staff", name: "포자 요정의 지팡이", kind: .weapon(.mage), rarity: 3, attack: 64, defense: 0, heal: 0, price: 25000, element: .poison, inShop: false),
            RpgItem(id: "mushroom_mace", name: "버섯 대왕의 홀", kind: .weapon(.cleric), rarity: 3, attack: 66, defense: 0, heal: 0, price: 25000, element: .holy, inShop: false),
            RpgItem(id: "mushroom_armor", name: "포자 망토", kind: .armor, rarity: 3, attack: 0, defense: 64, heal: 0, price: 28000, element: .base, inShop: false),
        ],
        // ponytail: generic band materials only (see the note in RpgCoastRegion.swift).
        recipes: [
            RpgRecipe(id: "mushroom_ring", output: "mushroom_ring", count: 1, materials: ["mat_ice": 8, "mat_magma": 5, "stone": 6], gold: 20000),
            RpgRecipe(id: "mushroom_amulet", output: "mushroom_amulet", count: 1, materials: ["mat_ice": 8, "mat_magma": 4, "stone": 6], gold: 18000),
            RpgRecipe(id: "mushroom_helmet", output: "mushroom_helmet", count: 1, materials: ["mat_sting": 8, "mat_ice": 7, "stone": 4], gold: 17000),
            RpgRecipe(id: "mushroom_boots", output: "mushroom_boots", count: 1, materials: ["mat_sting": 7, "mat_ice": 7, "stone": 4], gold: 17000),
            RpgRecipe(id: "mushroom_staff", output: "mushroom_staff", count: 1, materials: ["mat_ice": 10, "mat_magma": 6, "stone": 8], gold: 22000),
            RpgRecipe(id: "mushroom_mace", output: "mushroom_mace", count: 1, materials: ["mat_ice": 10, "mat_magma": 6, "stone": 8], gold: 22000),
            RpgRecipe(id: "mushroom_armor", output: "mushroom_armor", count: 1, materials: ["mat_ice": 10, "mat_magma": 8, "stone": 9], gold: 24000),
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

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsMushroom: [String: SpriteSpec] = [
        "mushroom_snail": SpriteSpec(grid: mushroomSnail, swap: ["C": rgb(140, 196, 110), "c": rgb(84, 140, 70), "S": rgb(176, 196, 216), "s": rgb(124, 144, 176)]),
        "mushroom_soldier": SpriteSpec(grid: paint(mushroomMan, coastHarpoon, y: 1), swap: [:]),
        "mushroom_pixie": SpriteSpec(grid: mushroomPixie, swap: ["O": rgb(190, 255, 225), "H": rgb(255, 170, 220), "P": rgb(200, 120, 220)]),
        "mushroom_pig": SpriteSpec(grid: mushroomPig, swap: ["S": rgb(240, 172, 182), "s": rgb(200, 120, 140)]),
        "mushroom_bomb": SpriteSpec(grid: mushroomPuff, swap: ["C": rgb(242, 232, 204), "c": rgb(196, 176, 140), "P": rgb(170, 120, 80)]),
        "mushroom_firefly": SpriteSpec(grid: paint(jungleWasp, mushroomGlowTail), swap: ["Y": rgb(96, 76, 56), "W": rgb(200, 230, 255), "f": rgb(220, 255, 120)]),
        "mushroom_gnome": SpriteSpec(grid: paint(mushroomGnome, mushroomPickaxe), swap: ["B": rgb(70, 110, 190)]),
        "mushroom_wizard": SpriteSpec(grid: paint(mage, mushroomCapHat), swap: ["P": rgb(70, 90, 160), "p": rgb(40, 56, 110)]),
        "mushroom_moth": SpriteSpec(grid: mushroomMoth, swap: ["A": rgb(156, 124, 186), "a": rgb(104, 82, 134), "Y": rgb(255, 220, 90)]),
        // The id contains "wolf", so the game already faces the (left-facing) wolf grid the right way.
        "mushroom_wolf": SpriteSpec(grid: paint(wolf, mushroomFungi), swap: ["Z": rgb(150, 140, 120), "z": rgb(100, 92, 80), "R": rgb(200, 255, 120), "D": rgb(214, 60, 60)]),
        "mushroom_cannon": SpriteSpec(grid: paint(junglePlant, mushroomSporePuffs), swap: ["G": rgb(180, 150, 200), "g": rgb(120, 96, 150), "R": rgb(90, 50, 120)]),
        "mushroom_golem": SpriteSpec(grid: paint(golem, mushroomGolemCap), swap: ["N": rgb(170, 140, 110), "n": rgb(120, 96, 70), "Q": rgb(255, 255, 160)]),
        "mushroom_guard": SpriteSpec(grid: paint(warrior, mushroomCapHelm), swap: ["M": rgb(240, 236, 220), "m": rgb(190, 180, 160)]),
        "mushroom_jester": SpriteSpec(grid: paint(mushroomGnome, mushroomJesterHat), swap: ["B": rgb(230, 80, 160), "P": rgb(120, 70, 200)]),
        "mushroom_queen": SpriteSpec(grid: mushroomPixie, swap: ["O": rgb(255, 180, 240), "H": rgb(255, 230, 120), "P": rgb(180, 60, 160)], boss: true),
        "mushroom_king": SpriteSpec(grid: mushroomMan, swap: ["R": rgb(240, 196, 60), "r": rgb(190, 140, 30)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsMushroom: [String: [Character: CGColor]] = [
        "mushroom_spore": ["B": rgb(220, 250, 180), "E": rgb(130, 200, 110)],
        "mushroom_cap": ["B": rgb(230, 90, 160), "E": rgb(150, 50, 110)],
        "mushroom_truffle": ["B": rgb(255, 215, 90), "E": rgb(160, 110, 40)],
        "mushroom_soup": ["B": rgb(230, 170, 110), "E": rgb(170, 110, 60)],
        "mushroom_dew": ["B": rgb(150, 230, 255), "E": rgb(80, 160, 220)],
        "mushroom_clover": ["B": rgb(160, 240, 120), "E": rgb(80, 170, 60)],
        "mushroom_ring": ["B": rgb(255, 190, 230), "J": rgb(190, 255, 220)],
        "mushroom_amulet": ["B": rgb(240, 220, 255), "J": rgb(255, 120, 220)],
        "mushroom_helmet": ["B": rgb(220, 60, 60), "J": rgb(255, 255, 255)],
        "mushroom_boots": ["B": rgb(240, 230, 200), "J": rgb(200, 80, 80)],
        "mushroom_staff": ["B": rgb(200, 170, 220), "G": rgb(120, 200, 120), "H": rgb(100, 70, 120), "O": rgb(230, 255, 170), "J": rgb(255, 255, 255)],
        "mushroom_mace": ["B": rgb(240, 196, 60), "E": rgb(190, 140, 30), "G": rgb(255, 255, 255), "H": rgb(150, 110, 70)],
        "mushroom_armor": ["B": rgb(130, 90, 170), "E": rgb(220, 200, 240)],
    ]

    // MARK: mushroom body grids (side views face right)

    static let mushroomSnail: RpgGrid = [
        "................", "................", "................", "....KKKKK.......", "...KCCCCCK....K.", "..KCcKKKcCK..KWK",
        ".KCcKCCCKcCK.KK.", ".KCKCcKCKCcK.KK.", ".KCKCKKcKCCK.KK.", ".KCcKCCKcCK.KSSK", "..KCcKKcCCKKSSSK", "...KKCCCCKSSSSSK",
        "..KSSKKKKSSSSSK.", ".KsSSSSSSSSSsK..", "..KKKKKKKKKKK...", "................",
    ]
    /// A walking toadstool: the soldiers and their king.
    static let mushroomMan: RpgGrid = [
        "................", ".....KKKKKK.....", "...KKRRRRRRKK...", "..KRRWWRRRWWRK..", ".KRRWWRRRRWWRRK.", ".KRRRRRRRRRRRRK.",
        ".KrRRWWRRRRRRrK.", ".KKKKKKKKKKKKKK.", "....KCCCCCCK....", "....KCKCCKCK....", "...KCCCCCCCCK...", "..KCKCCKKCCKCK..",
        "....KCCCCCCK....", "....KCCKKCCK....", "....KccKKccK....", "....KKK..KKK....",
    ]
    static let mushroomPixie: RpgGrid = [
        "................", "......KKKK......", ".KK..KHHHHK..KK.", "KOOK.KSKKSK.KOOK", "KOOOKKSSSSKKOOOK", ".KOOOKKSSKKOOOK.",
        "..KOOKPPPPKOOK..", "...KKKPPPPKKK...", "..KOOKPPPPKOOK..", ".KOOOKKPPKKOOOK.", ".KOOK.KSSK.KOOK.", "..KK..KSSK..KK..",
        "......KK.KK.....", "................", "................", "................",
    ]
    static let mushroomPig: RpgGrid = [
        "................", "................", "................", "................", "............KK..", "...........KSSK.",
        "...KKKKKKKKKSSK.", "..KSSSSSSSSSSSKK", ".KSSSSSSSSSSKSSK", "KSKSSSSSSSSSSKsK", ".KKSSSSSSSSSSKsK", "...KSSSSSSSSSSK.",
        "...KsSKsKKsSKsK.", "...KsK.KK.KsK...", "...KKK....KKK...", "................",
    ]
    /// The gnome miner and the court jester.
    static let mushroomGnome: RpgGrid = [
        ".......KK.......", "......KRRK......", "......KRRRK.....", ".....KRRRRK.....", "....KRRRRRRK....", "...KKKKKKKKKK...",
        "....KSKSSKSK....", "....KSSSRSSK....", "...KWWSSSSWWK...", "..KKWWWWWWWWKK..", ".KSKBWWWWWWBKSK.", "..KKBBWWWWBBKK..",
        "...KBBBBBBBBK...", "...KBBKKKKBBK...", "...KLLK..KLLK...", "...KKK....KKK...",
    ]
    static let mushroomMoth: RpgGrid = [
        "................", "..K..........K..", "...K..KKKK..K...", "..KKKKAAAAKKKK..", ".KAAAAKAAKAAAAK.", "KAWYAAKAAKAAYWAK",
        "KAYAAAKAAKAAAYAK", "KAAAAKKAAKKAAAAK", ".KKKKKaAAaKKKKK.", ".KaaaKaAAaKaaaK.", "KaaYaaKaaKaaYaaK", ".KaaaKKaaKKaaaK.",
        "..KKK..KK..KKK..", "................", "................", "................",
    ]
    /// A puffball with a lit sprout: the exploding spore bomb.
    static let mushroomPuff: RpgGrid = [
        "........fW......", ".......KK.......", ".....KKKKKK.....", "....KCCCCCCK....", "...KCWCCCCCCK...", "..KCWCCPCCCCCK..",
        "..KCCKKCCKKCCK..", "..KCCRKCCKRCCK..", "..KCPCCCCCCPCK..", "..KcCCKKKKCCcK..", "...KcCCCCCCcK...", "....KKcccKKK....",
        ".....KPPPPK.....", "....KPPPPPPK....", "....KKKKKKKK....", "................",
    ]

    private static let mushroomPickaxe: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                                  "............KKK.", "...........KMMMK", "............KLK.", "............KL..", ".............L.."]
    private static let mushroomCapHat: RpgGrid = ["................", "................", "....KKKKKKKK....", "..KKRRWRRRWRKK..", ".KRRWWRRRRRWRRK.", "KKKKKKKKKKKKKKKK"]
    private static let mushroomCapHelm: RpgGrid = ["....KKKKKKKK....", "..KKRRWWRRRRKK..", ".KRRWWRRRRWWRRK.", "KRRRRRRRRRWWRRRK", "KKKKKKKKKKKKKKKK"]
    private static let mushroomFungi: RpgGrid = ["................", "................", ".....KKK.KKK....", "....KDWDKDWDK...", ".....KlK.KlK...."]
    private static let mushroomGolemCap: RpgGrid = ["....KKKKKKKK....", "..KKRRWRRRRWKK..", ".KRRWWRRRRRRWRK.", "KKKKKKKKKKKKKKKK", "...KNQNNNNQNK..."]
    private static let mushroomSporePuffs: RpgGrid = ["................", "................", "................", "..............W.", "................", "............W..W",
                                                     ".............W..", "...............W"]
    private static let mushroomGlowTail: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                                   "................", "................", "..KffKKffK......", "KKKffKKffK......", "..KffKKffK......"]
    private static let mushroomJesterHat: RpgGrid = ["..Y..........Y..", ".KRK........KPK.", "..KRRK....KPPK..", "...KRRRKKPPPK...", "....KRRRPPPK....", "...KKKKKKKKKK..."]
}

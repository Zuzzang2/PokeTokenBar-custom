import CoreGraphics
import Foundation

// 해안 대륙 (Lv5-22). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
//
// Balance (shared by the four early regions: coast, jungle, mushroom, ancient). Normal monsters sit on a base curve
// interpolated between the shipped melee monsters of nearby levels — HP / XP / gold geometrically, attack / defense linearly:
//   Lv   5    7    10   16   19   24    31    35    42
//   HP   95   130  230  500  700  1000  2300  2800  5200      (독버섯 늑대 해골병사 늪버섯 미라 설원늑대 고대해골 불꽃해골 암흑기사)
//   ATK  14   18   30   56   66   92    135   160   230
//   DEF  3    4    8    16   20   28    44    50    80
//   XP   22   30   52   185  250  430   800   980   1700
//   GOLD 11   14   24   60   78   100   158   220   375       (average of the range; range = avg x0.78-1.22)
// times a per-behaviour factor measured on shipped pairs of the same level (hp/atk/def/xp/gold):
//   passive 1/0.97/1/1.05/1 · flyer 0.72/0.96/0.7/0.85/0.85 · ranged 0.75/0.95/0.72/0.92/0.95 · swarm 0.38/0.72/0.5/0.5/0.5
//   charger 1.27/1.05/0.95/1.27/1.27 · exploder 0.6/1.28/0.5/1.1/1.1 · coward 0.8/0/1/1.2/5 (golden slime is 15x in a hidden room)
//   tank (slow aggressive) HP 1.4 at Lv13 fading to 1.15 at Lv38, def 1.15, XP 1.15 fading to 1, gold 1.1
// The curve reproduces the shipped monsters within about ±10%. Bosses: mid boss 30x / final boss 40x a same-level
// normal's HP, 1.4x / 1.5x attack, 7x / 10x XP, 8x / 12x gold (the shipped bosses run ~100-225x HP; raise `hp` to match them).
// Signature gear spends the budget of one shipped tier in a different spread and is never better than the next tier on every stat.

enum RpgCoastRegion {
    private static func door(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, gate: Int = 1) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func weapons(tier t: Int, _ chance: Double) -> [(String, Double)] { RpgClass.allCases.map { ("\($0.weaponPrefix)\(t)", chance) } }
    private static let books16 = ["book_w_iron", "book_a_back", "book_m_blizzard", "book_r_stab", "book_c_ward", "book_k_dragon", "book_s_bats"]
    private static let books22 = ["book_w_cyclone", "book_a_trap", "book_m_pillar", "book_r_blades", "book_c_judge", "book_k_barrage", "book_s_drain"]

    static let region = RpgRegion(
        id: "coast", name: "해안 대륙", blurb: "파도 소리와 해적의 뱃노래가 뒤섞이는 햇살 가득한 해안",
        minLevel: 3, entry: RpgMapID("coast_1"), entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: RpgMapID("coast_1"), name: "조개껍질 해변", levelText: "Lv5~8", width: 50, height: 30, kind: .desert, seed: 1001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), door(48, 15, "coast_2", 4, 15, gate: 7)],
                      monsters: RpgMaps.sp([("coast_crab", 11), ("coast_starfish", 9), ("coast_hermit", 9)]),
                      theme: RpgTheme(floor: .sand, obstacle: .water, pool: .water, decor: .dune), waypoint: true),
            RpgMapDef(id: RpgMapID("coast_2"), name: "조수 웅덩이", levelText: "Lv7~10", width: 50, height: 30, kind: .desert, seed: 1002,
                      portals: [door(1, 15, "coast_1", 45, 15, gate: 3), door(48, 15, "coast_3", 4, 15, gate: 9)],
                      monsters: RpgMaps.sp([("coast_starfish", 9), ("coast_hermit", 8), ("coast_gull", 10), ("coast_urchin", 6)]),
                      theme: RpgTheme(floor: .sand, obstacle: .rock, pool: .water, decor: .water, tint: .init(r: 0.4, g: 0.75, b: 0.85), tintAlpha: 0.14, blend: .softLight)),
            RpgMapDef(id: RpgMapID("coast_3"), name: "갈매기 절벽", levelText: "Lv9~12", width: 50, height: 30, kind: .field, seed: 1003,
                      portals: [door(1, 15, "coast_2", 45, 15, gate: 7), door(48, 15, "coast_4", 4, 15, gate: 11)],
                      monsters: RpgMaps.sp([("coast_gull", 13), ("coast_urchin", 7), ("coast_seal", 5), ("coast_jelly", 6)]),
                      theme: RpgTheme(floor: .grass, obstacle: .rock, pool: .water, decor: .flower, tint: .init(r: 0.55, g: 0.8, b: 1), tintAlpha: 0.16, blend: .softLight),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("coast_4"), name: "난파선 모래톱", levelText: "Lv11~14", width: 50, height: 30, kind: .desert, seed: 1004,
                      portals: [door(1, 15, "coast_3", 45, 15, gate: 9), door(48, 15, "coast_5", 4, 15, gate: 13), door(25, 1, "coast_b1", 14, 17, gate: 12)],
                      monsters: RpgMaps.sp([("coast_seal", 4), ("coast_jelly", 4), ("coast_deckhand", 12), ("coast_crossbow", 8)]),
                      theme: RpgTheme(floor: .sand, obstacle: .water, pool: .water, decor: .caveFloor, tint: .init(r: 0.55, g: 0.62, b: 0.72), tintAlpha: 0.3, blend: .color)),
            RpgMapDef(id: RpgMapID("coast_5"), name: "해적 동굴", levelText: "Lv13~16", width: 50, height: 30, kind: .cave, seed: 1005,
                      portals: [door(1, 15, "coast_4", 45, 15, gate: 11), door(48, 15, "coast_6", 4, 16, gate: 15)],
                      monsters: RpgMaps.sp([("coast_deckhand", 11), ("coast_crossbow", 9), ("coast_keg", 4), ("coast_mimic", 2)]),
                      theme: RpgTheme(tint: .init(r: 1, g: 0.62, b: 0.25), tintAlpha: 0.28, blend: .overlay, darkness: 0.72), waypoint: true),
            RpgMapDef(id: RpgMapID("coast_6"), name: "밀수꾼의 창고", levelText: "Lv15~18", width: 50, height: 32, kind: .castle, seed: 1006,
                      portals: [door(1, 16, "coast_5", 45, 15, gate: 13), door(48, 16, "coast_7", 4, 15, gate: 17)],
                      monsters: RpgMaps.sp([("coast_crossbow", 8), ("coast_keg", 4), ("coast_parrot", 11), ("coast_kelpgolem", 5)]),
                      theme: RpgTheme(tint: .init(r: 0.66, g: 0.46, b: 0.26), tintAlpha: 0.55, blend: .color, darkness: 0.42)),
            RpgMapDef(id: RpgMapID("coast_7"), name: "노을 등대 곶", levelText: "Lv17~21", width: 50, height: 30, kind: .field, seed: 1007,
                      portals: [door(1, 15, "coast_6", 45, 16, gate: 15), door(25, 1, "coast_b2", 14, 17, gate: 19)],
                      monsters: RpgMaps.sp([("coast_parrot", 12), ("coast_kelpgolem", 5), ("coast_harpooner", 11)]),
                      theme: RpgTheme(floor: .grass, obstacle: .rock, pool: .water, decor: .flower, tint: .init(r: 1, g: 0.5, b: 0.35), tintAlpha: 0.35, blend: .multiply,
                                      darkness: 0.15),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("coast_b1"), name: "집게 대왕의 모래굴", levelText: "보스 Lv15", width: 28, height: 22, kind: .boss, seed: 1008,
                      portals: [door(14, 20, "coast_4", 25, 4, gate: 11)], monsters: RpgMaps.sp([("coast_kingcrab", 1)]), zone: .desert,
                      theme: RpgTheme(tint: .init(r: 0.9, g: 0.7, b: 0.4), tintAlpha: 0.2, blend: .overlay)),
            RpgMapDef(id: RpgMapID("coast_b2"), name: "유령선 선장실", levelText: "보스 Lv22", width: 28, height: 22, kind: .boss, seed: 1009,
                      portals: [door(14, 20, "coast_7", 25, 4, gate: 17)], monsters: RpgMaps.sp([("coast_captain", 1)]), zone: .castle,
                      theme: RpgTheme(tint: .init(r: 0.6, g: 0.42, b: 0.24), tintAlpha: 0.5, blend: .color, darkness: 0.5)),
        ],
        monsters: [
            RpgMonsters.m("coast_crab", "꽃게", "coast_crab", 5, 95, 14, 3, 34, 22, 9...13, .aggressive,
                          [("hp0", 0.12), ("coast_shell", 0.1), ("armor1", 0.01), ("stone", 0.04)]),
            RpgMonsters.m("coast_starfish", "불가사리 떼", "coast_starfish", 6, 40, 12, 2, 50, 13, 5...8, .swarm,
                          [("hp0", 0.1), ("coast_shell", 0.06), ("stone", 0.025)]),
            RpgMonsters.m("coast_hermit", "소라게", "coast_hermit", 7, 130, 17, 4, 24, 32, 11...17, .passive,
                          [("hp0", 0.12), ("mp0", 0.05), ("coast_shell", 0.12), ("coast_pearl", 0.005), ("stone", 0.045)]),
            RpgMonsters.m("coast_gull", "도둑 갈매기", "coast_gull", 8, 115, 21, 4, 50, 31, 11...17, .flyer,
                          [("mp0", 0.12), ("coast_coconut", 0.04), ("coast_shell", 0.05), ("ring0", 0.008), ("stone", 0.045)]),
            RpgMonsters.m("coast_urchin", "가시 성게", "coast_urchin", 9, 240, 27, 6, 34, 55, 20...31, .charger,
                          [("hp1", 0.1), ("coast_shell", 0.08), ("armor1", 0.015), ("stone", 0.035)]),
            RpgMonsters.m("coast_seal", "뚱보 물범", "coast_seal", 11, 365, 34, 11, 24, 74, 24...38, .aggressive,
                          [("hp1", 0.1), ("coast_coconut", 0.05), ("coast_pearl", 0.012), ("armor2", 0.012), ("mace2", 0.008), ("claw2", 0.008), ("stone", 0.07)]),
            RpgMonsters.m("coast_jelly", "찌릿 해파리", "coast_jelly", 12, 180, 49, 5, 40, 87, 28...44, .exploder,
                          [("hp1", 0.1), ("mp0", 0.08), ("coast_pearl", 0.01), ("stone", 0.04)]),
            RpgMonsters.m("coast_deckhand", "해골 갑판원", "coast_deckhand", 13, 340, 43, 12, 36, 98, 30...46, .aggressive,
                          [("hp1", 0.1), ("coast_coin", 0.08), ("coast_rum", 0.03), ("sword2", 0.008), ("dagger3", 0.008), ("armor2", 0.01), ("stone", 0.065)]),
            RpgMonsters.m("coast_crossbow", "석궁 해적", "coast_crossbow", 14, 290, 45, 10, 32, 110, 33...51, .ranged,
                          [("mp0", 0.12), ("hp1", 0.06), ("coast_coin", 0.08), ("coast_rum", 0.03), ("bow2", 0.008), ("bow3", 0.008), ("coast_hat", 0.003),
                           ("stone", 0.065)]),
            RpgMonsters.m("coast_mimic", "보물상자 미믹", "coast_mimic", 14, 310, 0, 13, 46, 145, 170...270, .coward,
                          [("hp1", 0.3), ("coast_coin", 0.6), ("coast_pearl", 0.15), ("ring1", 0.03), ("amulet1", 0.03), ("coast_ring", 0.01), ("coast_amulet", 0.01),
                           ("stone", 0.3)]),
            RpgMonsters.m("coast_keg", "화약통 폭탄", "coast_keg", 16, 300, 72, 8, 48, 205, 50...80, .exploder,
                          [("hp1", 0.1), ("coast_rum", 0.05), ("coast_coin", 0.05), ("stone", 0.05)]),
            RpgMonsters.m("coast_parrot", "수다쟁이 앵무", "coast_parrot", 17, 405, 57, 12, 54, 175, 43...68, .flyer,
                          [("mp0", 0.12), ("coast_coin", 0.06), ("coast_coconut", 0.05), ("stone", 0.07)] + books16.map { ($0, 0.003) }),
            RpgMonsters.m("coast_kelpgolem", "해초 골렘", "coast_kelpgolem", 18, 845, 63, 21, 22, 255, 60...95, .aggressive,
                          [("hp1", 0.1), ("coast_shell", 0.1), ("coast_pearl", 0.02), ("armor3", 0.012), ("staff4", 0.006), ("rod3", 0.006), ("coast_boots", 0.003),
                           ("stone", 0.1)]),
            RpgMonsters.m("coast_harpooner", "유령 작살꾼", "coast_harpooner", 20, 565, 68, 16, 34, 255, 60...95, .ranged,
                          [("hp2", 0.06), ("mp0", 0.1), ("coast_coin", 0.08), ("coast_pearl", 0.015), ("coast_ring", 0.003), ("coast_amulet", 0.003), ("stone", 0.08)]
                          + books16.map { ($0, 0.004) }),
            RpgMonsters.boss("coast_kingcrab", "집게 대왕", "coast_kingcrab", 15, 13000, 72, 14, 30, 1050, 350...500, .golem, minion: "coast_crab", element: .ice,
                             [("hp1", 1), ("coast_shell", 1), ("coast_shell", 1), ("coast_pearl", 0.5), ("coast_coconut", 0.6), ("coast_boots", 0.25), ("coast_hat", 0.2),
                              ("armor3", 0.15), ("armor4", 0.06)] + weapons(tier: 5, 0.03)),
            RpgMonsters.boss("coast_captain", "외눈 선장 그로그", "coast_captain", 22, 34500, 122, 25, 36, 3460, 850...1300, .skeleton, minion: "coast_deckhand",
                             element: .fire,
                             [("hp2", 1), ("coast_coin", 1), ("coast_coin", 1), ("coast_pearl", 0.6), ("coast_rum", 0.6), ("coast_cutlass", 0.2), ("coast_rod", 0.2),
                              ("coast_coat", 0.2), ("coast_ring", 0.15), ("coast_amulet", 0.15), ("coast_hat", 0.15), ("coast_boots", 0.15), ("armor5", 0.1), ("armor4", 0.12),
                              ("ring2", 0.05), ("amulet2", 0.05), ("helmet2", 0.05), ("boots2", 0.05)]
                             + weapons(tier: 6, 0.05) + weapons(tier: 5, 0.07) + books16.map { ($0, 0.08) } + books22.map { ($0, 0.04) }),
        ],
        items: [
            RpgItem(id: "coast_shell", name: "무지개 조개껍데기", kind: .material, rarity: 0, attack: 0, defense: 0, heal: 0, price: 45, element: .base, inShop: false),
            RpgItem(id: "coast_coin", name: "해적 금화", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 150, element: .base, inShop: false),
            RpgItem(id: "coast_pearl", name: "흑진주", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 900, element: .base, inShop: false),
            RpgItem(id: "coast_coconut", name: "코코넛 주스", kind: .potionHP, rarity: 1, attack: 0, defense: 0, heal: 300, price: 140, element: .base, inShop: false),
            RpgItem(id: "coast_rum", name: "해적의 럼주", kind: .buff("atk"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 600, element: .base, inShop: false),
            // Tier-2 accessories (Lv14-22), weapons between tier 5 and 6, a coat between armor 4 and 5.
            RpgItem(id: "coast_ring", name: "파도 소리 반지", kind: .ring, rarity: 2, attack: 0, defense: 0, heal: 0, price: 3500, element: .base, inShop: false,
                    bonusHP: 50, bonusCrit: 0.05, bonusAttack: 0.07),
            RpgItem(id: "coast_amulet", name: "등대지기의 목걸이", kind: .amulet, rarity: 2, attack: 0, defense: 6, heal: 0, price: 3500, element: .base, inShop: false,
                    bonusHP: 110, bonusMP: 75),
            RpgItem(id: "coast_hat", name: "해적 삼각모", kind: .helmet, rarity: 2, attack: 0, defense: 7, heal: 0, price: 3200, element: .base, inShop: false, bonusHP: 100),
            RpgItem(id: "coast_boots", name: "물갈퀴 장화", kind: .boots, rarity: 2, attack: 0, defense: 3, heal: 0, price: 3200, element: .base, inShop: false, bonusSpeed: 0.05),
            RpgItem(id: "coast_cutlass", name: "폭풍우 커틀러스", kind: .weapon(.rogue), rarity: 2, attack: 29, defense: 0, heal: 0, price: 7000, element: .thunder, inShop: false),
            RpgItem(id: "coast_rod", name: "산호초 소환봉", kind: .weapon(.summoner), rarity: 2, attack: 30, defense: 0, heal: 0, price: 7000, element: .ice, inShop: false),
            RpgItem(id: "coast_coat", name: "선장의 붉은 코트", kind: .armor, rarity: 2, attack: 0, defense: 38, heal: 0, price: 13000, element: .base, inShop: false),
        ],
        // ponytail: ContentChecks only accepts generic band materials in recipes, so these use the band's mat_* drops; switch to
        // coast_shell / coast_coin / coast_pearl once that check also counts the region monsters' drops.
        recipes: [
            RpgRecipe(id: "coast_ring", output: "coast_ring", count: 1, materials: ["mat_bone": 8, "mat_sting": 4, "stone": 2], gold: 3200),
            RpgRecipe(id: "coast_amulet", output: "coast_amulet", count: 1, materials: ["mat_bone": 8, "mat_sting": 3, "stone": 2], gold: 3000),
            RpgRecipe(id: "coast_hat", output: "coast_hat", count: 1, materials: ["mat_hide": 6, "mat_bone": 6], gold: 2600),
            RpgRecipe(id: "coast_boots", output: "coast_boots", count: 1, materials: ["mat_hide": 8, "mat_bone": 4], gold: 2600),
            RpgRecipe(id: "coast_cutlass", output: "coast_cutlass", count: 1, materials: ["mat_bone": 10, "mat_sting": 6, "stone": 4], gold: 6000),
            RpgRecipe(id: "coast_rod", output: "coast_rod", count: 1, materials: ["mat_bone": 10, "mat_sting": 6, "stone": 4], gold: 6000),
            RpgRecipe(id: "coast_coat", output: "coast_coat", count: 1, materials: ["mat_bone": 8, "mat_sting": 8, "stone": 5], gold: 8000),
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
    static let specsCoast: [String: SpriteSpec] = [
        "coast_crab": SpriteSpec(grid: coastCrab, swap: [:]),
        "coast_starfish": SpriteSpec(grid: coastStar, swap: ["F": rgb(255, 130, 110), "f": rgb(255, 200, 170)]),
        "coast_hermit": SpriteSpec(grid: coastHermit, swap: ["C": rgb(250, 210, 220), "c": rgb(220, 150, 170), "F": rgb(255, 120, 60)]),
        "coast_gull": SpriteSpec(grid: coastBird, swap: ["Z": rgb(170, 180, 196), "z": rgb(120, 130, 150)]),
        "coast_urchin": SpriteSpec(grid: coastUrchin, swap: [:]),
        "coast_seal": SpriteSpec(grid: coastSeal, swap: ["Z": rgb(150, 160, 175), "z": rgb(100, 110, 128), "C": rgb(214, 220, 230)]),
        "coast_jelly": SpriteSpec(grid: coastJelly, swap: ["A": rgb(150, 200, 255), "a": rgb(90, 140, 230)]),
        "coast_deckhand": SpriteSpec(grid: paint(skeleton, coastBandana), swap: [:]),
        "coast_crossbow": SpriteSpec(grid: paint(paint(warrior, coastTricorn), coastCrossbow, y: 8),
                                     swap: ["M": rgb(60, 70, 120), "m": rgb(36, 42, 80), "R": rgb(230, 230, 230), "D": rgb(40, 36, 52), "B": rgb(90, 70, 60)]),
        "coast_mimic": SpriteSpec(grid: coastChest, swap: [:]),
        "coast_keg": SpriteSpec(grid: coastBarrel, swap: [:]),
        "coast_parrot": SpriteSpec(grid: paint(coastBird, coastCrest, y: 1),
                                   swap: ["W": rgb(230, 60, 50), "Z": rgb(60, 170, 80), "z": rgb(40, 110, 60), "Y": rgb(250, 210, 60), "R": rgb(250, 210, 60)]),
        "coast_kelpgolem": SpriteSpec(grid: paint(golem, coastKelp), swap: ["N": rgb(84, 112, 110), "n": rgb(52, 76, 78), "Q": rgb(120, 255, 220)]),
        "coast_harpooner": SpriteSpec(grid: paint(paint(mage, coastSouwester), coastHarpoon),
                                      swap: ["P": rgb(230, 190, 50), "p": rgb(180, 140, 30), "S": rgb(190, 235, 235), "Y": rgb(240, 200, 60)]),
        "coast_kingcrab": SpriteSpec(grid: coastCrab, swap: ["R": rgb(230, 110, 40), "r": rgb(160, 60, 30)], boss: true),
        "coast_captain": SpriteSpec(grid: paint(warrior, coastCaptainHat),
                                    swap: ["M": rgb(170, 40, 40), "m": rgb(110, 24, 30), "R": rgb(240, 190, 50), "D": rgb(30, 28, 40), "H": rgb(40, 30, 30), "L": rgb(40, 30, 30)],
                                    boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCoast: [String: [Character: CGColor]] = [
        "coast_shell": ["B": rgb(255, 200, 214), "E": rgb(200, 120, 150)],
        "coast_coin": ["B": rgb(255, 215, 80), "E": rgb(190, 140, 30)],
        "coast_pearl": ["B": rgb(80, 70, 100), "E": rgb(34, 28, 50)],
        "coast_coconut": ["B": rgb(245, 240, 225), "E": rgb(150, 100, 60)],
        "coast_rum": ["B": rgb(180, 96, 40), "E": rgb(110, 50, 20)],
        "coast_ring": ["B": rgb(220, 230, 240), "J": rgb(60, 170, 230)],
        "coast_amulet": ["B": rgb(240, 200, 80), "J": rgb(255, 244, 160)],
        "coast_hat": ["B": rgb(44, 40, 58), "J": rgb(240, 200, 60)],
        "coast_boots": ["B": rgb(60, 150, 130), "J": rgb(240, 240, 240)],
        "coast_cutlass": ["B": rgb(230, 236, 246), "E": rgb(150, 162, 186), "G": rgb(240, 190, 60), "H": rgb(90, 50, 30)],
        "coast_rod": ["B": rgb(240, 150, 150), "E": rgb(190, 80, 100), "G": rgb(255, 250, 240), "H": rgb(120, 60, 60), "O": rgb(255, 120, 140)],
        "coast_coat": ["B": rgb(180, 44, 44), "E": rgb(240, 190, 50)],
    ]

    // MARK: coast body grids (side views face right; the game mirrors them when the monster walks left)

    static let coastCrab: RpgGrid = [
        "................", ".KK..KK..KK..KK.", "KRRKKWK..KWKKRRK", "KR.K.KK..KK.K.RK", "KRRK..K..K..KRRK", ".KRK..K..K..KRK.",
        "..KRKKKKKKKKRK..", "...KRRRRRRRRK...", "..KRRRRRRRRRRK..", ".KRRRRRKKRRRRRK.", "KKRrRRRRRRRRrRKK", "K.KrrRRRRRRrrK.K",
        ".K.KrrrrrrrrK.K.", ".K..KKKKKKKK..K.", "K..............K", "................",
    ]
    static let coastStar: RpgGrid = [
        ".......KK.......", "......KFFK......", "......KFfK......", ".....KFFFFK.....", "KKKKKKFfFFKKKKKK", "KFFfFFFFFFFFfFFK",
        ".KFFFFFFFFFFFFK.", "..KFFKFFFFKFFK..", "...KFFFFFFFFK...", "...KFFFKKFFFK...", "..KFFfFFFFFFFK..", "..KFFFFKKFFfFK..",
        ".KFFfFK..KFFFFK.", ".KFFFK....KFFFK.", "KFFKK......KKFFK", "KKK..........KKK",
    ]
    static let coastHermit: RpgGrid = [
        "................", "................", "....KKKKKK..K.K.", "..KKCCCCCCKKWKW.", ".KCCcKKKKcCKKKK.", ".KCcKCCCCKcK.KK.",
        "KCCKCcKKcCKCKFFK", "KCcKCKCCKCKcKFFK", "KCcKCcKKKCKcKKFK", "KCCcKCCCCKcCKFKK", ".KCCcKKKKcCCKFFK", "..KKCCCCCCKKFFK.",
        "...KKKKKKKKFFK..", "....KFK.KFK.KK..", "....K.K.K.K.....", "................",
    ]
    static let coastBird: RpgGrid = [
        "................", "................", "..........KKK...", ".........KWWWK..", "........KWWWKWK.", "........KWWWWWKY",
        "..KKK..KWWWWWKKK", ".KZZZKKWWWWWWK..", "KZZZZZWWWWWWWK..", ".KKZZZZZWWWWK...", "...KKZZZZWWK....", ".....KKKKKK.....",
        "......KY.KY.....", ".....KYK.KYK....", "................", "................",
    ]
    static let coastUrchin: RpgGrid = [
        "................", "....K..K..K.....", "..K.KK.K.KK.K...", "...KPPKPKPPK....", ".KKPPPPPPPPPKK..", "..KPPPPPPPPPPK..",
        "KKPPKWPPPKWPPPKK", "..KPPKPPPPKPPK..", "KKPPPPPPPPPPPPKK", "..KPPPKKKKPPPK..", ".KKpPPPPPPPPpKK.", "...KppPPPPppK...",
        "..K.KKpppKK.K...", "....K..K..K.....", "................", "................",
    ]
    static let coastSeal: RpgGrid = [
        "................", "................", "..........KKKK..", ".........KZZZZK.", "........KZZWKZZK", "........KZZZZZKK",
        "........KZZZZKzK", "...KK...KZZZZZK.", "..KZZKKKZZZZZK..", ".KZZZZZZZZZZZK..", ".KZZZZZZZZCCZK..", "KZZZZZZZZCCCZK..",
        "KzZZZZZZCCCCK...", ".KzzZZZZZZZKZK..", "..KKKKKKKKKKKKK.", "................",
    ]
    static let coastJelly: RpgGrid = [
        "................", "....KKKKKKKK....", "...KAAAAAAAAK...", "..KAWWAAAAAAAK..", "..KAWAAAAAAAAK..", ".KAAAKAAAAKAAAK.",
        ".KAAAAAAAAAAAAK.", ".KaAAAAKKAAAAaK.", ".KKaaaaaaaaaaKK.", "..KAKAKAKAKAK...", "..KAKaKAKaKAK...", "..K.KaK.KaK.K...",
        "...KaK.KaK.KaK..", "...K.K.KaK..K...", "......K..K......", "................",
    ]
    static let coastChest: RpgGrid = [
        "................", "................", "...KKKKKKKKKK...", "..KLLLLLLLLLLK..", ".KLLRKLLLLKRLLK.", ".KYYYYYYYYYYYYK.",
        ".KKWKWKWKWKWKKK.", ".KRRRRRRRRRRRRK.", ".KKWKWKWKWKWKKK.", ".KYYYYKYYKYYYYK.", ".KLLLKYYYYKLLLK.", ".KLlLLKKKKLLlLK.",
        ".KLLLLLLLLLLLLK.", ".KYYYYYYYYYYYYK.", "..KK.KK..KK.KK..", "................",
    ]
    static let coastBarrel: RpgGrid = [
        "........K.......", ".......KfK......", "........KF......", ".....KKKKKKK....", "....KLLLLLLLK...", "...KMMMMMMMMMK..",
        "...KLlLLLLLlLK..", "...KLLLLLLLLLK..", "...KLLKLLLKLLK..", "...KLlLLLLLlLK..", "...KLLLKKKLLLK..", "...KMMMMMMMMMK..",
        "...KLlLLLLLlLK..", "....KLLLLLLLK...", ".....KKKKKKK....", "................",
    ]
    /// A pole with a barbed head, held on the right; shared with the mushroom soldier and the stone hoplite.
    static let coastHarpoon: RpgGrid = [
        "................", "..............K.", ".............KMK", "..............L.", "..............L.", "..............L.",
        "..............L.", "..............L.", "..............L.", "..............L.", "..............L.", "..............L.",
        "..............L.", "..............L.",
    ]
    /// Two crest feathers over the bird grid's head (parrot, thunderbird).
    static let coastCrest: RpgGrid = ["..........R.R...", "...........RR..."]

    private static let coastBandana: RpgGrid = ["......KKKK......", ".....KRRRRK.....", "....KRRRRRRK....", "....KXKXXKRRK...", "..........KRK..."]
    private static let coastTricorn: RpgGrid = ["................", "....KKKKKKKK....", "...KDDDDDDDDK...", "..KYDDDDDDDDYK..", ".KYYKKKKKKKKYYK."]
    private static let coastCrossbow: RpgGrid = ["..............K.", ".............KLK", "...........KLLWK", ".............KLK", "..............K."]
    private static let coastKelp: RpgGrid = [
        "................", "................", "....G......G....", "....g..W...g....", ".....G....G.....", "................",
        ".G...W...G....G.", ".g...G...g....g.", ".G...g........G.", ".....G...G...W..", ".........g......", "................",
        "....G.......G...",
    ]
    private static let coastSouwester: RpgGrid = ["................", "................", "......KKKK......", ".....KYYYYK.....", "...KKYYYYYYKK...", "..KYYYYYYYYYYK.."]
    private static let coastCaptainHat: RpgGrid = [
        "..KK........KK..", ".KDDKKKKKKKKDDK.", ".KDDDDDWWDDDDDK.", "KYDDDDDWWDDDDDYK", "KYYKKKKKKKKKKYYK", "....KKKSSKSK....",
        "....KHHHHHHK....", ".....KHHHHK.....",
    ]
}

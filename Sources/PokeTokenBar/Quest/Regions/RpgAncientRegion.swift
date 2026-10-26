import CoreGraphics
import Foundation

// 고대 도시 (Lv20-42). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
// Monster stats follow the curve documented in `RpgCoastRegion.swift` (shipped monsters interpolated, per-behaviour factors).
//   pigeon 20 swarm · raider 21 aggr · eye 23 flyer · scout 24 aggr · merchant 26 ranged · statue 27 tank · serpent 29 charger
//   rusty 30 exploder · bookworm 32 swarm · scholar 33 ranged · guardian 34 tank · spider 36 charger · knight 37 aggr · star 38 flyer
//   sphinx 40 tank · bosses: naga 33 (30x HP), colossus 42 (40x HP). Signature gear spends the tier-5 accessory / tier-7 weapon budgets.

enum RpgAncientRegion {
    private static func door(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, gate: Int = 1) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func weapons(tier t: Int, _ chance: Double) -> [(String, Double)] { RpgClass.allCases.map { ("\($0.weaponPrefix)\(t)", chance) } }
    private static let books35 = ["book_w_ult", "book_a_ult", "book_m_ult", "book_r_ult", "book_c_ult", "book_k_ult", "book_s_ult"]

    static let region = RpgRegion(
        id: "ancient", name: "고대 도시", blurb: "물에 잠긴 돌의 도시, 태엽 수호자들이 아직도 학자들을 지킨다",
        minLevel: 18, entry: RpgMapID("ancient_1"), entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: RpgMapID("ancient_1"), name: "무너진 외성문", levelText: "Lv20~23", width: 50, height: 30, kind: .field, seed: 4001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), door(48, 15, "ancient_2", 4, 15, gate: 22)],
                      monsters: RpgMaps.sp([("ancient_pigeon", 10), ("ancient_raider", 10), ("ancient_eye", 8)]),
                      theme: RpgTheme(floor: .grass, obstacle: .castleWall, pool: .water, decor: .stone, tint: .init(r: 0.9, g: 0.85, b: 0.6), tintAlpha: 0.12,
                                      blend: .softLight),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("ancient_2"), name: "열주 광장", levelText: "Lv22~26", width: 50, height: 30, kind: .desert, seed: 4002,
                      portals: [door(1, 15, "ancient_1", 45, 15, gate: 18), door(48, 15, "ancient_3", 4, 15, gate: 25)],
                      monsters: RpgMaps.sp([("ancient_raider", 7), ("ancient_eye", 8), ("ancient_scout", 9), ("ancient_merchant", 6)]),
                      theme: RpgTheme(floor: .stone, obstacle: .pillar, pool: .water, decor: .dune)),
            RpgMapDef(id: RpgMapID("ancient_3"), name: "가라앉은 시장", levelText: "Lv25~29", width: 50, height: 30, kind: .desert, seed: 4003,
                      portals: [door(1, 15, "ancient_2", 45, 15, gate: 22), door(48, 15, "ancient_4", 4, 15, gate: 28)],
                      monsters: RpgMaps.sp([("ancient_scout", 9), ("ancient_merchant", 8), ("ancient_statue", 4), ("ancient_serpent", 5)]),
                      theme: RpgTheme(floor: .stone, obstacle: .water, pool: .water, decor: .caveFloor, tint: .init(r: 0.3, g: 0.72, b: 0.8), tintAlpha: 0.3, blend: .color),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("ancient_4"), name: "수로 지하도", levelText: "Lv28~32", width: 50, height: 30, kind: .cave, seed: 4004,
                      portals: [door(1, 15, "ancient_3", 45, 15, gate: 25), door(48, 15, "ancient_5", 4, 16, gate: 31), door(25, 1, "ancient_b1", 14, 17, gate: 30)],
                      monsters: RpgMaps.sp([("ancient_statue", 5), ("ancient_serpent", 8), ("ancient_rusty", 6), ("ancient_scholar", 7)]),
                      theme: RpgTheme(tint: .init(r: 0.2, g: 0.85, b: 0.8), tintAlpha: 0.35, blend: .color, darkness: 0.6)),
            RpgMapDef(id: RpgMapID("ancient_5"), name: "황금 문서고", levelText: "Lv31~35", width: 50, height: 32, kind: .castle, seed: 4005,
                      portals: [door(1, 16, "ancient_4", 45, 15, gate: 28), door(48, 16, "ancient_6", 4, 16, gate: 34)],
                      monsters: RpgMaps.sp([("ancient_rusty", 4), ("ancient_bookworm", 11), ("ancient_scholar", 9), ("ancient_guardian", 4)]),
                      theme: RpgTheme(tint: .init(r: 1, g: 0.8, b: 0.35), tintAlpha: 0.35, blend: .color, darkness: 0.35), waypoint: true),
            RpgMapDef(id: RpgMapID("ancient_6"), name: "태엽 공방", levelText: "Lv34~38", width: 50, height: 32, kind: .castle, seed: 4006,
                      portals: [door(1, 16, "ancient_5", 45, 16, gate: 31), door(48, 16, "ancient_7", 4, 15, gate: 37)],
                      monsters: RpgMaps.sp([("ancient_scholar", 8), ("ancient_guardian", 4), ("ancient_spider", 6), ("ancient_knight", 9)]),
                      theme: RpgTheme(tint: .init(r: 0.45, g: 0.6, b: 0.85), tintAlpha: 0.35, blend: .color, darkness: 0.4)),
            RpgMapDef(id: RpgMapID("ancient_7"), name: "별시계 첨탑", levelText: "Lv37~41", width: 50, height: 30, kind: .field, seed: 4007,
                      portals: [door(1, 15, "ancient_6", 45, 16, gate: 34), door(25, 1, "ancient_b2", 14, 17, gate: 39)],
                      monsters: RpgMaps.sp([("ancient_spider", 5), ("ancient_knight", 9), ("ancient_star", 10), ("ancient_sphinx", 4)]),
                      theme: RpgTheme(floor: .stone, obstacle: .pillar, pool: .water, decor: .grass, tint: .init(r: 0.25, g: 0.25, b: 0.6), tintAlpha: 0.45,
                                      blend: .multiply, darkness: 0.3),
                      waypoint: true),
            RpgMapDef(id: RpgMapID("ancient_b1"), name: "나가 여왕의 수조", levelText: "보스 Lv33", width: 28, height: 22, kind: .boss, seed: 4008,
                      portals: [door(14, 20, "ancient_4", 25, 4, gate: 28)], monsters: RpgMaps.sp([("ancient_naga", 1)]), zone: .cave,
                      theme: RpgTheme(tint: .init(r: 0.2, g: 0.8, b: 0.85), tintAlpha: 0.4, blend: .color, darkness: 0.55)),
            RpgMapDef(id: RpgMapID("ancient_b2"), name: "태엽 거신의 심장부", levelText: "보스 Lv42", width: 28, height: 22, kind: .boss, seed: 4009,
                      portals: [door(14, 20, "ancient_7", 25, 4, gate: 37)], monsters: RpgMaps.sp([("ancient_colossus", 1)]), zone: .castle,
                      theme: RpgTheme(tint: .init(r: 1, g: 0.8, b: 0.4), tintAlpha: 0.35, blend: .color, darkness: 0.5)),
        ],
        monsters: [
            RpgMonsters.m("ancient_pigeon", "석상 비둘기 떼", "ancient_pigeon", 20, 285, 51, 11, 62, 140, 32...50, .swarm,
                          [("hp1", 0.1), ("ancient_gear", 0.04), ("stone", 0.05)]),
            RpgMonsters.m("ancient_raider", "길 잃은 도굴꾼", "ancient_raider", 21, 805, 76, 23, 42, 310, 65...105, .aggressive,
                          [("hp2", 0.06), ("ancient_gear", 0.06), ("ancient_tablet", 0.04), ("dagger6", 0.004), ("armor5", 0.004), ("stone", 0.085)]),
            RpgMonsters.m("ancient_eye", "감시의 눈", "ancient_eye", 23, 670, 83, 18, 46, 330, 65...100, .flyer,
                          [("mp0", 0.1), ("ancient_crystal", 0.03), ("ancient_tablet", 0.03), ("stone", 0.085)]),
            RpgMonsters.m("ancient_scout", "태엽 정찰병", "ancient_scout", 24, 1000, 92, 28, 44, 430, 80...120, .aggressive,
                          [("hp2", 0.08), ("ancient_gear", 0.1), ("ancient_core", 0.005), ("claw6", 0.004), ("rod6", 0.004), ("stone", 0.09)]),
            RpgMonsters.m("ancient_merchant", "익사한 상인", "ancient_merchant", 26, 950, 99, 23, 30, 470, 85...130, .ranged,
                          [("mp1", 0.06), ("hp2", 0.05), ("ancient_tablet", 0.05), ("ancient_elixir", 0.02), ("ring3", 0.006), ("ancient_ring", 0.003), ("stone", 0.095)]),
            RpgMonsters.m("ancient_statue", "깨어난 석상 병사", "ancient_statue", 27, 1800, 110, 40, 20, 600, 105...165, .aggressive,
                          [("hp2", 0.08), ("ancient_tablet", 0.08), ("armor6", 0.003), ("sword6", 0.004), ("mace6", 0.004), ("ancient_helmet", 0.003), ("stone", 0.14)]),
            RpgMonsters.m("ancient_serpent", "수로 뱀", "ancient_serpent", 29, 2300, 129, 37, 40, 850, 135...215, .charger,
                          [("hp2", 0.1), ("ancient_crystal", 0.04), ("ancient_boots", 0.003), ("bow6", 0.004), ("stone", 0.07)]),
            RpgMonsters.m("ancient_rusty", "폭주 자동인형", "ancient_rusty", 30, 1230, 165, 21, 48, 805, 125...200, .exploder,
                          [("hp2", 0.1), ("ancient_gear", 0.12), ("ancient_core", 0.008), ("stone", 0.07)]),
            RpgMonsters.m("ancient_bookworm", "책벌레 떼", "ancient_bookworm", 32, 920, 102, 23, 58, 420, 65...105, .swarm,
                          [("hp2", 0.1), ("ancient_tablet", 0.04), ("ancient_scroll", 0.02), ("stone", 0.07)]),
            RpgMonsters.m("ancient_scholar", "학자 망령", "ancient_scholar", 33, 1900, 140, 34, 32, 815, 140...215, .ranged,
                          [("mp1", 0.08), ("hp2", 0.05), ("ancient_crystal", 0.05), ("ancient_scroll", 0.03), ("ancient_amulet", 0.003), ("staff7", 0.003), ("stone", 0.11)]
                          + books35.map { ($0, 0.0015) }),
            RpgMonsters.m("ancient_guardian", "황금 수호상", "ancient_guardian", 34, 3170, 154, 56, 22, 955, 175...270, .aggressive,
                          [("hp3", 0.04), ("ancient_tablet", 0.08), ("ancient_core", 0.015), ("armor6", 0.005), ("sword7", 0.003), ("ancient_armor", 0.002), ("stone", 0.16)]),
            RpgMonsters.m("ancient_spider", "태엽 거미", "ancient_spider", 36, 3880, 178, 52, 46, 1345, 235...370, .charger,
                          [("hp3", 0.1), ("ancient_gear", 0.1), ("ancient_core", 0.01), ("dagger7", 0.003), ("claw7", 0.003), ("stone", 0.085)]),
            RpgMonsters.m("ancient_knight", "자동인형 기사", "ancient_knight", 37, 3340, 180, 59, 38, 1145, 200...315, .aggressive,
                          [("hp3", 0.05), ("ancient_gear", 0.08), ("ancient_core", 0.01), ("ancient_ring", 0.003), ("armor6", 0.005), ("sword7", 0.003), ("mace7", 0.003),
                           ("stone", 0.13)] + books35.map { ($0, 0.0015) }),
            RpgMonsters.m("ancient_star", "유성 정령", "ancient_star", 38, 2630, 182, 44, 60, 1055, 185...285, .flyer,
                          [("mp1", 0.1), ("hp3", 0.04), ("ancient_crystal", 0.06), ("ancient_core", 0.006), ("staff7", 0.003), ("rod7", 0.003), ("stone", 0.13)]),
            RpgMonsters.m("ancient_sphinx", "별빛 스핑크스", "ancient_sphinx", 40, 5010, 210, 82, 30, 1450, 275...430, .aggressive,
                          [("hp3", 0.05), ("ancient_tablet", 0.1), ("ancient_core", 0.02), ("ancient_elixir", 0.04), ("armor6", 0.006), ("bow7", 0.003),
                           ("ancient_boots", 0.003), ("ancient_helmet", 0.003), ("stone", 0.19)] + books35.map { ($0, 0.002) }),
            RpgMonsters.boss("ancient_naga", "수로의 여왕 나가", "ancient_naga", 33, 76000, 206, 45, 36, 6200, 1200...1800, .yeti, minion: "ancient_eye", element: .ice,
                             [("hp2", 1), ("ancient_crystal", 1), ("ancient_crystal", 1), ("ancient_core", 0.5), ("ancient_elixir", 0.6), ("ancient_boots", 0.2),
                              ("ancient_helmet", 0.2), ("armor6", 0.12)] + weapons(tier: 7, 0.04) + weapons(tier: 6, 0.06) + books35.map { ($0, 0.04) }),
            RpgMonsters.boss("ancient_colossus", "태엽 거신 아틀라스", "ancient_colossus", 42, 208000, 345, 80, 30, 17000, 3600...5400, .golem,
                             minion: "ancient_rusty", element: .thunder,
                             [("hp3", 1), ("ancient_core", 1), ("ancient_gear", 1), ("ancient_tablet", 1), ("ancient_scroll", 0.6), ("ancient_sword", 0.2), ("ancient_rod", 0.2),
                              ("ancient_armor", 0.2), ("ancient_ring", 0.15), ("ancient_amulet", 0.15), ("ancient_helmet", 0.15), ("ancient_boots", 0.15), ("armor6", 0.2),
                              ("ring5", 0.05), ("amulet5", 0.05), ("helmet5", 0.05), ("boots5", 0.05)]
                             + weapons(tier: 7, 0.12) + books35.map { ($0, 0.1) }),
        ],
        items: [
            RpgItem(id: "ancient_gear", name: "녹슨 톱니바퀴", kind: .material, rarity: 1, attack: 0, defense: 0, heal: 0, price: 600, element: .base, inShop: false),
            RpgItem(id: "ancient_tablet", name: "고대 석판 조각", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 1500, element: .base, inShop: false),
            RpgItem(id: "ancient_core", name: "태엽 심장", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 4500, element: .base, inShop: false),
            RpgItem(id: "ancient_crystal", name: "고대 마나 결정", kind: .potionMP, rarity: 2, attack: 0, defense: 0, heal: 450, price: 600, element: .base, inShop: false),
            RpgItem(id: "ancient_elixir", name: "연금술사의 영약", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 1800, price: 1100, element: .base, inShop: false),
            RpgItem(id: "ancient_scroll", name: "대현자의 깨달음", kind: .buff("xp"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1500, element: .base, inShop: false),
            // Tier-5 accessories (Lv32-42), weapons just under tier 7, armor just under armor 6.
            RpgItem(id: "ancient_ring", name: "별시계 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 50000, element: .base, inShop: false,
                    bonusHP: 420, bonusCrit: 0.09, bonusAttack: 0.16),
            RpgItem(id: "ancient_amulet", name: "고대 학자의 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 26, heal: 0, price: 50000, element: .base, inShop: false,
                    bonusHP: 760, bonusMP: 300),
            RpgItem(id: "ancient_helmet", name: "수호자의 투구", kind: .helmet, rarity: 3, attack: 0, defense: 30, heal: 0, price: 48000, element: .base, inShop: false, bonusHP: 600),
            RpgItem(id: "ancient_boots", name: "태엽 장화", kind: .boots, rarity: 3, attack: 0, defense: 13, heal: 0, price: 48000, element: .base, inShop: false, bonusSpeed: 0.085),
            RpgItem(id: "ancient_sword", name: "고대 수호자의 대검", kind: .weapon(.warrior), rarity: 3, attack: 78, defense: 0, heal: 0, price: 38000, element: .thunder,
                    inShop: false),
            RpgItem(id: "ancient_rod", name: "별자리 소환봉", kind: .weapon(.summoner), rarity: 3, attack: 76, defense: 0, heal: 0, price: 38000, element: .cosmic, inShop: false),
            RpgItem(id: "ancient_armor", name: "자동인형 흉갑", kind: .armor, rarity: 3, attack: 0, defense: 70, heal: 0, price: 42000, element: .base, inShop: false),
        ],
        // ponytail: generic band materials only (see the note in RpgCoastRegion.swift).
        recipes: [
            RpgRecipe(id: "ancient_ring", output: "ancient_ring", count: 1, materials: ["mat_magma": 10, "mat_dark": 6, "stone": 10], gold: 40000),
            RpgRecipe(id: "ancient_amulet", output: "ancient_amulet", count: 1, materials: ["mat_magma": 10, "mat_dark": 5, "stone": 10], gold: 38000),
            RpgRecipe(id: "ancient_helmet", output: "ancient_helmet", count: 1, materials: ["mat_ice": 9, "mat_magma": 6, "stone": 8], gold: 36000),
            RpgRecipe(id: "ancient_boots", output: "ancient_boots", count: 1, materials: ["mat_ice": 8, "mat_magma": 7, "stone": 8], gold: 36000),
            RpgRecipe(id: "ancient_sword", output: "ancient_sword", count: 1, materials: ["mat_magma": 12, "mat_dark": 6, "stone": 12], gold: 34000),
            RpgRecipe(id: "ancient_rod", output: "ancient_rod", count: 1, materials: ["mat_magma": 12, "mat_dark": 6, "stone": 12], gold: 34000),
            RpgRecipe(id: "ancient_armor", output: "ancient_armor", count: 1, materials: ["mat_magma": 12, "mat_dark": 8, "stone": 12], gold: 38000),
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
    static let specsAncient: [String: SpriteSpec] = [
        "ancient_pigeon": SpriteSpec(grid: paint(coastBird, ancientPigeonNeck),
                                     swap: ["W": rgb(170, 180, 196), "Z": rgb(126, 132, 150), "z": rgb(88, 92, 110), "Y": rgb(230, 140, 60), "G": rgb(80, 200, 140),
                                            "P": rgb(170, 110, 200)]),
        "ancient_raider": SpriteSpec(grid: paint(paint(rogue, ancientExplorerHat), ancientTorch), swap: ["Z": rgb(184, 150, 100), "z": rgb(134, 100, 60)]),
        "ancient_eye": SpriteSpec(grid: ancientEye, swap: ["N": rgb(150, 144, 130), "O": rgb(80, 230, 200)]),
        "ancient_scout": SpriteSpec(grid: ancientBot, swap: ["O": rgb(120, 255, 255), "Y": rgb(255, 230, 120)]),
        "ancient_merchant": SpriteSpec(grid: paint(mage, ancientTurban), swap: ["P": rgb(60, 150, 150), "p": rgb(30, 100, 104), "S": rgb(180, 230, 220)]),
        "ancient_statue": SpriteSpec(grid: paint(paint(warrior, ancientHoplite), coastHarpoon, y: 1),
                                     swap: ["M": rgb(176, 170, 156), "m": rgb(130, 124, 112), "S": rgb(196, 190, 176), "s": rgb(150, 144, 130), "R": rgb(150, 144, 130),
                                            "r": rgb(110, 104, 94), "Y": rgb(150, 144, 130), "B": rgb(220, 216, 204), "L": rgb(130, 124, 112), "O": rgb(120, 255, 210)]),
        "ancient_serpent": SpriteSpec(grid: paint(jungleSnake, ancientFins), swap: ["G": rgb(60, 150, 164), "g": rgb(30, 100, 110), "Y": rgb(200, 232, 222)]),
        "ancient_rusty": SpriteSpec(grid: paint(ancientBot, ancientSteam), swap: ["T": rgb(170, 90, 50), "t": rgb(110, 56, 30), "O": rgb(255, 90, 50), "Y": rgb(255, 160, 60)]),
        "ancient_bookworm": SpriteSpec(grid: ancientBook, swap: ["G": rgb(130, 200, 90), "R": rgb(150, 50, 60)]),
        "ancient_scholar": SpriteSpec(grid: paint(paint(mage, ancientScholarFace), ancientBookHeld),
                                      swap: ["P": rgb(90, 110, 170), "p": rgb(56, 70, 120), "S": rgb(200, 220, 240), "Y": rgb(150, 220, 255)]),
        "ancient_guardian": SpriteSpec(grid: paint(golem, ancientCrest), swap: ["N": rgb(230, 190, 80), "n": rgb(170, 130, 40), "Q": rgb(255, 80, 60)]),
        "ancient_spider": SpriteSpec(grid: ancientSpider, swap: ["M": rgb(150, 160, 180), "m": rgb(100, 110, 130), "O": rgb(255, 80, 80), "Y": rgb(255, 210, 90)]),
        "ancient_knight": SpriteSpec(grid: paint(paint(ancientBot, ancientPlume), ancientLance, y: 4), swap: ["T": rgb(120, 140, 170), "t": rgb(80, 96, 120), "O": rgb(120, 255, 255)]),
        "ancient_star": SpriteSpec(grid: paint(coastStar, ancientSparkles), swap: ["F": rgb(255, 236, 140), "f": rgb(255, 255, 230)]),
        "ancient_sphinx": SpriteSpec(grid: ancientSphinx, swap: ["T": rgb(220, 190, 120), "t": rgb(170, 140, 80), "B": rgb(60, 90, 200), "S": rgb(230, 200, 150)]),
        "ancient_naga": SpriteSpec(grid: ancientNaga, swap: ["G": rgb(40, 130, 150), "g": rgb(20, 84, 104), "Y": rgb(240, 214, 110), "R": rgb(230, 60, 90)], boss: true),
        "ancient_colossus": SpriteSpec(grid: ancientBot, swap: ["T": rgb(210, 170, 80), "t": rgb(150, 110, 40), "O": rgb(255, 80, 200), "Y": rgb(120, 255, 255)], boss: true),
    ]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsAncient: [String: [Character: CGColor]] = [
        "ancient_gear": ["B": rgb(190, 150, 80), "E": rgb(120, 90, 40)],
        "ancient_tablet": ["B": rgb(190, 182, 160), "E": rgb(110, 104, 90)],
        "ancient_core": ["B": rgb(120, 255, 240), "E": rgb(40, 140, 160)],
        "ancient_crystal": ["B": rgb(120, 200, 255), "E": rgb(60, 110, 200)],
        "ancient_elixir": ["B": rgb(255, 140, 200), "E": rgb(190, 60, 140)],
        "ancient_scroll": ["B": rgb(240, 220, 150), "E": rgb(180, 140, 60)],
        "ancient_ring": ["B": rgb(60, 70, 120), "J": rgb(255, 240, 150)],
        "ancient_amulet": ["B": rgb(230, 200, 120), "J": rgb(90, 200, 255)],
        "ancient_helmet": ["B": rgb(210, 170, 80), "J": rgb(120, 255, 255)],
        "ancient_boots": ["B": rgb(190, 150, 80), "J": rgb(255, 90, 60)],
        "ancient_sword": ["B": rgb(220, 240, 255), "E": rgb(120, 170, 220), "G": rgb(230, 190, 80), "H": rgb(60, 60, 90), "J": rgb(120, 255, 255)],
        "ancient_rod": ["B": rgb(60, 60, 110), "E": rgb(100, 70, 200), "G": rgb(255, 230, 120), "H": rgb(40, 40, 70), "O": rgb(180, 140, 255)],
        "ancient_armor": ["B": rgb(200, 160, 80), "E": rgb(120, 255, 255)],
    ]

    // MARK: ancient body grids (side views face right)

    static let ancientEye: RpgGrid = [
        "................", "................", "..KK..KKKK..KK..", ".KMMKKNNNNKKMMK.", "KMMMKNNNNNNKMMMK", ".KKKNNKKKKNNKKK.",
        "...KNKWWWWKNK...", "...KNKWOOWKNK...", "...KNKWOKWKNK...", "...KNKWWWWKNK...", "....KNKKKKNK....", ".....KNNNNK.....",
        "......KKKK......", ".......KK.......", "................", "................",
    ]
    /// A wind-up automaton: scouts, the rusty bombs, the knights and the colossus.
    static let ancientBot: RpgGrid = [
        "................", "......KKKK......", ".....KTTTTK.....", "....KTKOOKTK....", "....KTTTTTTK....", ".....KKKKKK.....",
        "...KKTTTTTTKK.KK", "..KTKTtKKtTKTKKK", "..KTKTKYYKTKTKK.", "..KTKTtKKtTKTK..", "..KKKTTTTTTKKK..", "....KtTTTTtK....",
        "....KTTKKTTK....", "....KtK..KtK....", "...KKTK..KTKK...", "...KKKK..KKKK...",
    ]
    static let ancientSpider: RpgGrid = [
        "................", "................", "................", "K..K........K..K", ".K..K......K..K.", "..K..KKKKKK..K..",
        "KK.KKMMMMMMKK.KK", "..KKMMOMMOMMKK..", "KKKMMMMMMMMMMKKK", "..KKMmYYYYmMKK..", "KK.KKMmmmmMKK.KK", "..K..KKKKKK..K..",
        ".K..K......K..K.", "K..K........K..K", "................", "................",
    ]
    static let ancientSphinx: RpgGrid = [
        "................", "................", "..........KKKK..", ".........KYBYBK.", "........KYBSSSYK", "........KBYSKSYK",
        "........KYBSSSK.", "...KKKKKKBYSSK..", "..KTTTTTTKKKK...", ".KTTTTTTTTTTTK..", "KTKTTTTTTTTTTK..", "KK.KTTTTTTTTTK..",
        "...KTtKKKKtTTK..", "...KTK....KTK...", "..KTTK...KTTK...", "..KKKK...KKKK...",
    ]
    static let ancientBook: RpgGrid = [
        "................", "................", "................", "........KKK.....", ".......KGGGK....", "......KGWKWGK...",
        "......KGGGGGK...", ".......KGGK.....", "..KKKKKKGGKKKKK.", ".KWWWWWKGKWWWWWK", ".KWKKKWKKKWKKKWK", ".KWWWWWKWKWWWWWK",
        ".KWKKKWKWKWKKKWK", ".KRRRRRKRKRRRRRK", "..KKKKKKKKKKKKK.", "................",
    ]
    /// Front-facing so the boss crown lands on the hood.
    static let ancientNaga: RpgGrid = [
        "................", "......KKKK......", "....KKGGGGKK....", "...KGGGGGGGGK...", "..KGGGYGGYGGGK..", "..KGgGGGGGGgGK..",
        "..KGgGGRRGGgGK..", "...KgGGRGGGgK...", "....KKGGGGKK....", "......KGGK......", ".....KGYYGK.....", "...KKGGYYGGKK...",
        "..KGGGKKKKGGGK..", ".KGGKKGGGGKKGGK.", ".KgGGGGYYGGGGgK.", "..KKKKKKKKKKKK..",
    ]

    private static let ancientPigeonNeck: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                                    "........GP......", ".......PG......."]
    private static let ancientExplorerHat: RpgGrid = ["................", ".....KKKKKK.....", "....KLLLLLLK....", "..KKLLLLLLLLKK..", ".KLLLKKKKKKLLLK."]
    private static let ancientTorch: RpgGrid = ["................", "................", "................", "................", "..............F.", ".............FfF",
                                               "..............K.", "..............L.", "..............L.", "..............L."]
    private static let ancientTurban: RpgGrid = ["................", "......KKKK......", "....KKWWWWKK....", "...KWWWRWWWWK...", "...KWWWWWWWWK...", "..KKKKKKKKKKKK.."]
    private static let ancientHoplite: RpgGrid = [".......RR.......", "......RRRR......", "................", "................", "................", "......O..O......"]
    private static let ancientFins: RpgGrid = ["................", "................", "..........K.K...", ".........KOKOK.."]
    private static let ancientSteam: RpgGrid = ["............W.W.", ".............W..", "............W..."]
    private static let ancientScholarFace: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                                     "....KKWKKWKK....", "................", ".....KWWWWK.....", "....KKWWWWKK....", ".......WW......."]
    private static let ancientBookHeld: RpgGrid = ["................", "................", "................", "................", "................", "................",
                                                  "................", "................", "................", "................", "....KKKKKK......",
                                                  "...KRWWWWRK.....", "...KRWKKWRK.....", "...KRRRRRRK.....", "....KKKKKK......"]
    private static let ancientCrest: RpgGrid = ["......KKKK......", ".....KRYYRK.....", "....KRYYYYRK...."]
    private static let ancientPlume: RpgGrid = [".....KRRK.......", "....KRRRRK......", ".....KKKK......."]
    private static let ancientLance: RpgGrid = ["...............K", "..............KM", ".............KMK", "............KMK.", "...........KMK..", "..........KMK..."]
    private static let ancientSparkles: RpgGrid = ["W..............W", "................", "................", "...............W", "W..............."]
}

import CoreGraphics
import Foundation

// 얼음 대륙 (Lv60-88): seven hunting grounds from the blizzard plains to the Niflheim ice wall, the yeti jarl's mead hall (Lv78)
// off the mammoth tundra and the ice wyrm's nest (Lv88) at the end. Owned by exactly one author; see `RpgRegions.swift`.
//
// Balance — normals sit on the curves of the built-in Lv58-100 monsters of the same behaviour (power-law fits of skyhawk …
// voidknight, within ±3% of every built-in monster), with small per-monster tilts (±6%) that trade HP for attack or defense:
//   behaviour      Lv60 HP/ATK/DEF/XP          Lv74                        Lv87
//   aggressive     13.8k/374/134/3.8k          22.4k/490/174/8.2k          32.6k/605/214/14.8k   (heavy: ×1.3 HP and DEF, ×1.05 ATK, ×1.2 XP)
//   ranged         11.1k/374/ 92/3.9k          18.1k/491/122/8.3k          26.2k/605/151/14.7k
//   flyer          11.8k/335/ 93/4.0k          19.1k/441/122/8.0k          27.8k/544/151/13.7k
//   charger        14.6k/373/134/4.7k          23.6k/490/175/10.2k         34.3k/606/215/18.5k
//   swarm           5.6k/225/ 53/2.1k           9.0k/295/ 70/4.5k          13.0k/363/ 86/8.0k
//   exploder        6.9k/464/ 65/3.7k          11.2k/611/ 87/8.3k          16.3k/756/108/15.5k
//   passive = aggressive ×0.82 HP ×0.8 ATK ×0.9 DEF (the Lv58 cloud slime); coward = ×0.7 HP, no attack, ×1.3 XP, ×4 gold
//   (the golden slime of the late game: one per map, flees, drops stones and region loot).
// Bosses follow the built-in late bosses (kraken 70 … void lord 100) interpolated by level: Lv78 1.67M HP / 758 ATK / 440k XP,
// Lv88 2.07M / 897 / 878k (60-70× a same-level normal, like the built-in ones), and drop the late-boss loot table at half (mid
// boss) or three quarters (final boss) of the built-in rates, since this region adds two bosses to the band.
// Gear: weapon tiers 9/10/11 at Lv<70/<82/<92, armor and accessory tiers 8/9/10 at Lv<67/<77/<89. Signature gear keeps the
// budget of the tier it drops at (stats normalised by that tier add up to the same total) with a different spread.

enum RpgFrostRegion {
    static let region = RpgRegion(id: "frost", name: "얼음 대륙",
                                  blurb: "오로라가 춤추는 빙하 위, 뿔투구를 쓴 설인 부족이 꿀술잔을 들고 침입자를 기다려요.",
                                  minLevel: 58, entry: RpgMapID("frost_1"), entryTile: RpgTile(x: 4, y: 15),
                                  maps: maps, monsters: monsters, items: items, recipes: recipes)

    private static func p(_ x: Int, _ y: Int, _ to: String, _ ax: Int, _ ay: Int, _ gate: Int) -> RpgPortal {
        RpgMaps.p(x, y, RpgMapID(to), ax, ay, minLevel: gate)
    }
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    // MARK: maps

    private static let maps: [RpgMapDef] = [
        RpgMapDef(id: RpgMapID("frost_1"), name: "눈보라 빙원", levelText: "Lv60~64", width: 50, height: 30, kind: .snow, seed: 11001,
                  portals: [RpgMaps.p(1, 15, .town, 4, 11), p(48, 15, "frost_2", 4, 15, 63)],
                  monsters: RpgMaps.sp([("frost_seal", 6), ("frost_owl", 5), ("frost_lemming", 6), ("frost_reindeer", 1)]),
                  theme: RpgTheme(tint: tint(0.78, 0.84, 0.95), tintAlpha: 0.3, blend: .multiply), waypoint: true),
        RpgMapDef(id: RpgMapID("frost_2"), name: "얼어붙은 호수", levelText: "Lv63~68", width: 50, height: 30, kind: .snow, seed: 11002,
                  portals: [p(1, 15, "frost_1", 45, 15, 58), p(48, 15, "frost_3", 4, 16, 67)],
                  monsters: RpgMaps.sp([("frost_lemming", 5), ("frost_raider", 6), ("frost_walrus", 4), ("frost_reindeer", 1)]),
                  theme: RpgTheme(obstacle: .iceRock, pool: .water, tint: tint(0.55, 0.85, 1.0), tintAlpha: 0.2, blend: .color)),
        RpgMapDef(id: RpgMapID("frost_3"), name: "설인 부족 마을", levelText: "Lv67~72", width: 50, height: 32, kind: .castle, seed: 11003,
                  portals: [p(1, 16, "frost_2", 45, 15, 63), p(48, 16, "frost_4", 4, 15, 71)],
                  monsters: RpgMaps.sp([("frost_raider", 5), ("frost_walrus", 4), ("frost_spearman", 6), ("frost_meadbarrel", 4)]),
                  theme: RpgTheme(tint: tint(0.78, 0.52, 0.3), tintAlpha: 0.55, blend: .color, darkness: 0.2),
                  waypoint: true),
        RpgMapDef(id: RpgMapID("frost_4"), name: "매머드 툰드라", levelText: "Lv71~76", width: 50, height: 30, kind: .snow, seed: 11004,
                  portals: [p(1, 15, "frost_3", 45, 16, 67), p(48, 15, "frost_5", 4, 15, 75), p(25, 1, "frost_b1", 14, 17, 73)],
                  monsters: RpgMaps.sp([("frost_spearman", 4), ("frost_meadbarrel", 4), ("frost_mammoth", 5), ("frost_wisp", 4)]),
                  theme: RpgTheme(obstacle: .rock, pool: .ash, tint: tint(0.85, 0.78, 1.0), tintAlpha: 0.25, blend: .multiply)),
        RpgMapDef(id: RpgMapID("frost_5"), name: "오로라 설원", levelText: "Lv75~80", width: 50, height: 30, kind: .snow, seed: 11005,
                  portals: [p(1, 15, "frost_4", 45, 15, 71), p(48, 15, "frost_6", 4, 15, 79)],
                  monsters: RpgMaps.sp([("frost_mammoth", 4), ("frost_wisp", 6), ("frost_skald", 5), ("frost_iciclebat", 4)]),
                  theme: RpgTheme(pool: .water, tint: tint(0.55, 1.0, 0.8), tintAlpha: 0.4, blend: .multiply, darkness: 0.22), waypoint: true),
        RpgMapDef(id: RpgMapID("frost_6"), name: "빙하 균열", levelText: "Lv79~84", width: 48, height: 30, kind: .cave, seed: 11006,
                  portals: [p(1, 15, "frost_5", 45, 15, 75), p(46, 15, "frost_7", 4, 15, 83)],
                  monsters: RpgMaps.sp([("frost_skald", 4), ("frost_iciclebat", 6), ("frost_troll", 4), ("frost_berserker", 4)]),
                  theme: RpgTheme(tint: tint(0.5, 0.85, 1.0), tintAlpha: 0.4, blend: .color, darkness: 0.62)),
        RpgMapDef(id: RpgMapID("frost_7"), name: "니플헤임 빙벽", levelText: "Lv83~88", width: 50, height: 30, kind: .snow, seed: 11007,
                  portals: [p(1, 15, "frost_6", 43, 15, 79), p(25, 1, "frost_b2", 14, 17, 83)],
                  monsters: RpgMaps.sp([("frost_troll", 5), ("frost_berserker", 5), ("frost_valkyrie", 6)]),
                  theme: RpgTheme(obstacle: .caveWall, pool: .iceRock, tint: tint(0.35, 0.45, 0.9), tintAlpha: 0.35, blend: .multiply, darkness: 0.3),
                  waypoint: true),
        RpgMapDef(id: RpgMapID("frost_b1"), name: "대족장의 연회장", levelText: "보스 Lv78", width: 28, height: 22, kind: .boss, seed: 11008,
                  portals: [p(14, 20, "frost_4", 25, 4, 71)], monsters: RpgMaps.sp([("frost_jarl", 1)]), zone: .castle,
                  theme: RpgTheme(tint: tint(0.8, 0.5, 0.25), tintAlpha: 0.5, blend: .color, darkness: 0.45)),
        RpgMapDef(id: RpgMapID("frost_b2"), name: "니플헤임의 둥지", levelText: "보스 Lv88", width: 28, height: 22, kind: .boss, seed: 11009,
                  portals: [p(14, 20, "frost_7", 25, 4, 83)], monsters: RpgMaps.sp([("frost_wyrm", 1)]), zone: .snow,
                  theme: RpgTheme(tint: tint(0.5, 0.8, 1.0), tintAlpha: 0.35, blend: .color, darkness: 0.5)),
    ]

    // MARK: monsters

    private static let monsters: [RpgMonsterDef] = {
        let m = RpgMonsters.m
        var list: [RpgMonsterDef] = [
            m("frost_seal", "눈덩이 물범", "frost_seal", 60, 11900, 300, 120, 24, 3600, 640...900, .passive, [("hp3", 0.08), ("sword9", 0.004), ("bow9", 0.004), ("armor8", 0.004), ("ring8", 0.004), ("stone", 0.224), ("frost_fur", 0.06), ("frost_jerky", 0.02)]),
            m("frost_owl", "눈보라 올빼미", "frost_owl", 62, 12750, 350, 97, 56, 4500, 735...1050, .flyer, [("hp3", 0.08), ("mp1", 0.08), ("staff9", 0.004), ("dagger9", 0.004), ("armor8", 0.004), ("amulet8", 0.004), ("stone", 0.228), ("frost_fur", 0.06)]),
            m("frost_lemming", "레밍 눈뭉치떼", "frost_lemming", 64, 6450, 245, 58, 66, 2650, 420...600, .swarm, [("hp3", 0.1), ("mace9", 0.004), ("claw9", 0.004), ("armor8", 0.004), ("helmet8", 0.004), ("stone", 0.132), ("frost_fur", 0.05)]),
            m("frost_reindeer", "황금뿔 순록", "frost_reindeer", 65, 11650, 0, 170, 54, 6600, 3500...5000, .coward, [("hp3", 0.1), ("stone", 0.3), ("frost_fur", 0.5), ("frost_mead", 0.3), ("frost_boots", 0.01)]),
            m("frost_raider", "설인 약탈자", "frost_raider", 66, 17250, 425, 151, 38, 5350, 905...1300, .aggressive, [("hp3", 0.08), ("bow9", 0.004), ("staff9", 0.004), ("armor8", 0.004), ("ring8", 0.004), ("stone", 0.236), ("frost_fur", 0.06), ("frost_mead", 0.02)]),
            m("frost_walrus", "엄니 바다코끼리", "frost_walrus", 68, 24050, 460, 200, 22, 6750, 1160...1700, .aggressive, [("hp3", 0.08), ("dagger9", 0.004), ("mace9", 0.004), ("armor9", 0.004), ("amulet9", 0.004), ("stone", 0.24), ("frost_fur", 0.06), ("frost_jerky", 0.03)]),
            m("frost_spearman", "설인 투창수", "frost_spearman", 70, 15900, 455, 113, 34, 6800, 1050...1500, .ranged, [("hp3", 0.08), ("mp2", 0.08), ("claw10", 0.004), ("rod10", 0.004), ("armor9", 0.004), ("helmet9", 0.004), ("stone", 0.244), ("frost_fur", 0.06), ("frost_mead", 0.02)]),
            m("frost_meadbarrel", "꿀술통 폭탄", "frost_meadbarrel", 72, 10550, 590, 83, 46, 7450, 1125...1650, .exploder, [("hp4", 0.1), ("sword10", 0.004), ("bow10", 0.004), ("armor9", 0.004), ("boots9", 0.004), ("stone", 0.148), ("frost_fur", 0.05), ("frost_mead", 0.05)]),
            m("frost_mammoth", "털북숭이 매머드", "frost_mammoth", 74, 25050, 475, 183, 40, 10200, 1440...2100, .charger, [("hp4", 0.1), ("staff10", 0.004), ("dagger10", 0.004), ("armor9", 0.004), ("ring9", 0.004), ("stone", 0.152), ("frost_fur", 0.06), ("frost_jerky", 0.03), ("frost_boots", 0.002)]),
            m("frost_wisp", "오로라 도깨비불", "frost_wisp", 77, 21000, 465, 129, 60, 9150, 1275...1800, .flyer, [("hp4", 0.08), ("mp2", 0.08), ("mace10", 0.004), ("claw10", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.258), ("frost_aurora", 0.08)]),
            m("frost_skald", "룬 새김 주술사", "frost_skald", 79, 21000, 535, 133, 32, 10450, 1420...2050, .ranged, [("hp4", 0.08), ("mp2", 0.08), ("rod10", 0.004), ("sword10", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.262), ("frost_aurora", 0.05), ("frost_mead", 0.02)]),
            m("frost_iciclebat", "고드름 박쥐떼", "frost_iciclebat", 81, 11050, 330, 78, 64, 6200, 760...1100, .swarm, [("hp4", 0.1), ("bow10", 0.004), ("staff10", 0.004), ("armor10", 0.004), ("boots10", 0.004), ("stone", 0.166), ("frost_aurora", 0.04)]),
            m("frost_troll", "빙하 트롤", "frost_troll", 84, 39250, 605, 266, 26, 15450, 1990...2850, .aggressive, [("hp4", 0.08), ("dagger11", 0.004), ("mace11", 0.004), ("armor10", 0.004), ("ring10", 0.004), ("stone", 0.272), ("frost_aurora", 0.06), ("frost_jerky", 0.03)]),
            m("frost_berserker", "설인 광전사", "frost_berserker", 85, 32500, 615, 198, 44, 16950, 2040...2950, .charger, [("hp4", 0.1), ("claw11", 0.004), ("rod11", 0.004), ("armor10", 0.004), ("amulet10", 0.004), ("stone", 0.174), ("frost_aurora", 0.05), ("frost_mead", 0.03), ("frost_helm", 0.002)]),
            m("frost_valkyrie", "서리 발키리", "frost_valkyrie", 87, 27800, 545, 151, 58, 13700, 1735...2450, .flyer, [("hp4", 0.08), ("mp2", 0.08), ("sword11", 0.004), ("bow11", 0.004), ("armor10", 0.004), ("helmet10", 0.004), ("stone", 0.278), ("frost_aurora", 0.06), ("frost_ring", 0.002)]),
        ]
        list.append(RpgMonsters.boss("frost_jarl", "설인 대족장 요룬", "frost_jarl", 78, 1_666_000, 758, 184, 36, 440_000, 66_000...110_000, .yeti,
                                     minion: "frost_raider", element: .ice,
                                     RpgMonsters.endgameBossLoot(weapon: 10, armor: [10, 9], gear: 10, rate: 0.5)
                                         + [("frost_horn", 1), ("frost_helm", 0.15), ("frost_boots", 0.12), ("frost_fur", 1), ("frost_fur", 1), ("frost_mead", 0.5), ("hp4", 1)]))
        list.append(RpgMonsters.boss("frost_wyrm", "니플헤임의 빙룡", "frost_wyrm", 88, 2_066_000, 897, 214, 38, 878_000, 94_500...157_500, .golem,
                                     minion: "frost_iciclebat", element: .ice,
                                     RpgMonsters.endgameBossLoot(weapon: 11, armor: [11, 10], gear: 10, rate: 0.75)
                                         + [("frost_heart", 1), ("frost_axe", 0.12), ("frost_bow", 0.1), ("frost_ring", 0.1), ("frost_amulet", 0.1),
                                            ("frost_aurora", 1), ("frost_aurora", 1), ("hp5", 1)]))
        return list
    }()

    // MARK: items

    private static let items: [RpgItem] = [
        RpgItem(id: "frost_fur", name: "설인 털뭉치", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 9000, element: .base, inShop: false),
        RpgItem(id: "frost_aurora", name: "오로라 결정", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 15000, element: .base, inShop: false),
        RpgItem(id: "frost_horn", name: "대족장의 뿔나팔", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 45000, element: .base, inShop: false),
        RpgItem(id: "frost_heart", name: "빙룡의 심장", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 75000, element: .base, inShop: false),
        RpgItem(id: "frost_mead", name: "설인 꿀술", kind: .buff("atk"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 700, element: .base, inShop: false),
        RpgItem(id: "frost_jerky", name: "매머드 육포", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 6000, price: 4500, element: .base, inShop: false),
        // Armor between tiers 9 (190) and 10 (250): a crafted bridge for the Lv72-78 stretch.
        RpgItem(id: "frost_armor", name: "설인 털가죽 갑옷", kind: .armor, rarity: 3, attack: 0, defense: 220, heal: 0, price: 420_000, element: .base, inShop: false),
        // Tier 9 boots (12% / 66) → faster, thinner: 1.25 + 0.76.
        RpgItem(id: "frost_boots", name: "썰매꾼의 털장화", kind: .boots, rarity: 4, attack: 0, defense: 50, heal: 0, price: 600_000, element: .base, inShop: false,
                bonusSpeed: 0.15),
        // Tier 10 helmet (3700 HP / 118) → more HP, less defense: 1.19 + 0.81.
        RpgItem(id: "frost_helm", name: "대족장의 뿔투구", kind: .helmet, rarity: 4, attack: 0, defense: 96, heal: 0, price: 900_000, element: .base, inShop: false,
                bonusHP: 4400),
        // Tier 10 ring (3300 HP / 16% / 43%) → glass cannon: 0.61 + 1.31 + 1.07.
        RpgItem(id: "frost_ring", name: "오로라의 반지", kind: .ring, rarity: 4, attack: 0, defense: 0, heal: 0, price: 950_000, element: .base, inShop: false,
                bonusHP: 2000, bonusCrit: 0.21, bonusAttack: 0.46),
        // Tier 10 amulet (5100 HP / 950 MP / 150) → scales over size: 0.82 + 0.63 + 1.53.
        RpgItem(id: "frost_amulet", name: "빙룡 비늘 목걸이", kind: .amulet, rarity: 4, attack: 0, defense: 230, heal: 0, price: 1_000_000, element: .base, inShop: false,
                bonusHP: 4200, bonusMP: 600),
        // Same attack as the tier they drop at (sword11 290 fire, bow10 220 ice), another element.
        RpgItem(id: "frost_axe", name: "니플헤임 서리도끼", kind: .weapon(.warrior), rarity: 4, attack: 290, defense: 0, heal: 0, price: 480_000, element: .ice, inShop: false),
        RpgItem(id: "frost_bow", name: "오로라 장궁", kind: .weapon(.archer), rarity: 4, attack: 220, defense: 0, heal: 0, price: 300_000, element: .holy, inShop: false),
    ]

    // MARK: recipes (the smith)

    private static let recipes: [RpgRecipe] = [
        RpgRecipe(id: "frost_armor", output: "frost_armor", count: 1, materials: ["frost_fur": 20, "mat_pearl": 8, "stone": 15], gold: 400_000),
        RpgRecipe(id: "frost_boots", output: "frost_boots", count: 1, materials: ["frost_fur": 16, "frost_aurora": 6, "stone": 15], gold: 550_000),
        RpgRecipe(id: "frost_helm", output: "frost_helm", count: 1, materials: ["frost_horn": 1, "frost_aurora": 14, "stone": 20], gold: 800_000),
        RpgRecipe(id: "frost_ring", output: "frost_ring", count: 1, materials: ["frost_aurora": 18, "mat_time": 8, "stone": 30], gold: 950_000),
        RpgRecipe(id: "frost_bow", output: "frost_bow", count: 1, materials: ["frost_aurora": 16, "frost_fur": 10, "stone": 20], gold: 300_000),
        RpgRecipe(id: "frost_amulet", output: "frost_amulet", count: 1, materials: ["frost_heart": 1, "frost_aurora": 20, "stone": 35], gold: 1_000_000),
        RpgRecipe(id: "frost_axe", output: "frost_axe", count: 1, materials: ["frost_heart": 2, "frost_aurora": 24, "mat_void": 10, "stone": 40], gold: 480_000),
        RpgRecipe(id: "frost_jerky", output: "frost_jerky", count: 2, materials: ["frost_fur": 2], gold: 2000),
    ]
}

extension RpgMonsters {
    /// The built-in late-boss loot (every class's weapon of `weapon` and the tier below, two armor tiers, the four accessories of
    /// `gear`) at `rate` × the built-in chances (0.12 / 0.1 / 0.2 / 0.08). Shared by the frost, celestial, rift and chaos regions.
    static func endgameBossLoot(weapon: Int, armor: [Int], gear: Int, rate: Double) -> [(String, Double)] {
        let prefixes = ["sword", "bow", "staff", "dagger", "mace", "claw", "rod"]
        return prefixes.map { ("\($0)\(weapon)", 0.12 * rate) } + prefixes.map { ("\($0)\(weapon - 1)", 0.1 * rate) }
            + armor.map { ("armor\($0)", 0.2 * rate) } + ["ring", "amulet", "helmet", "boots"].map { ("\($0)\(gear)", 0.08 * rate) }
    }
}

// MARK: art

extension RpgArt {
    // Helpers shared by the frost, celestial, rift and chaos regions.
    /// Lays `top` over `base` with its top-left corner at (`x`, `y`): '.' keeps the pixel underneath, '_' clears it.
    static func endgameStamp(_ base: RpgGrid, _ top: RpgGrid, _ x: Int = 0, _ y: Int = 0) -> RpgGrid {
        var rows = base.map { Array($0) }
        for (dy, line) in top.enumerated() {
            for (dx, ch) in line.enumerated() where ch != "." {
                let yy = y + dy, xx = x + dx
                guard yy >= 0, yy < rows.count, xx >= 0, xx < rows[yy].count else { continue }
                rows[yy][xx] = ch == "_" ? "." : ch
            }
        }
        return rows.map { String($0) }
    }
    /// A left-facing body turned to face right (sprites are drawn facing right unless their id says otherwise).
    static func endgameMirror(_ g: RpgGrid) -> RpgGrid { g.map { String($0.reversed()) } }

    // Frost bodies (16×16, same letters as the built-in grids; colours come from each monster's swap).
    static let frostSeal: RpgGrid = [
        "................", "................", "................", "................", "................", "................",
        "..........KKKK..", ".........KWWWWK.", "........KWWWWWWK", "........KWKWWKWK", "...KKKKKKWWWDWWK", ".KKWWWWWWWWWWWWK",
        "KWWWWWWwWWWWwWK.", "KwKWWWWWWWWWWK..", ".KKKKwwKKKKwwK..", "....KKK...KKK...",
    ]
    static let frostOwl: RpgGrid = [
        "................", "...K........K...", "...KK......KK...", "...KWKKKKKKWK...", "..KWWWWWWWWWWK..", "..KWYYYWWYYYWK..",
        "..KWYKYWWYKYWK..", "..KWYYYOOYYYWK..", "..KWWWWOOWWWWK..", ".KWWzWWWWWWzWWK.", ".KWWWWzWWzWWWWK.", ".KWzWWWWWWWWzWK.",
        "..KWWWzWWzWWWK..", "...KWWWWWWWWK...", "....KKOKKOKK....", "................",
    ]
    static let frostLemming: RpgGrid = [
        "................", "................", "................", "................", "................", "................",
        "................", "................", "................", ".....KKKKK......", "...KKhhhhhKKK...", "..KHHHhhhHHHhK..",
        "..KHHHHHHHHKHHK.", ".KHHHHHHHHHHHHnK", ".KCCHHHHHHHCCCK.", "..KKKKKKKKKKKK..",
    ]
    static let frostDeer: RpgGrid = [
        ".........K.K.K..", ".........KTKTKK.", "..........KTTTK.", "...........KTK..", "..........KHHK..", ".........KHHKHKK",
        ".........KHHHHHK", "...KKKKKKHHHHKK.", ".KKHHHHHHHHHK...", "KCKHHHHHHHHHK...", ".KHHHHHHHHHHK...", ".KHHHHHHHHHHK...",
        "..KHKKKKKKKHK...", "..KHK.....KHK...", "..KhK.....KhK...", "..KK......KK....",
    ]
    static let frostViking: RpgGrid = [
        "................", ".K............K.", "KXK..KKKKKK..KXK", "KXXKKMMMMMMKKXXK", ".KXXMMMYYMMMXXK.", "..KKMMMMMMMMKK..",
        "..KWKSSSSSSKWKK.", "..KWSKSSSSKSWKMK", ".KWWSSSWWSSSWKMK", "KLLKWWWWWWWWKLMK", "KLYLKWWwWWWWKLK.", "KLLLKWWWWWWWKLK.",
        ".KLKWWWwWWWWKK..", "..KKWWKKKKWWK...", "...KwwK..KwwK...", "...KKKK..KKKK...",
    ]
    static let frostMammoth: RpgGrid = [
        "................", "................", ".....KKKKKK.....", "...KKHHHHHHKK...", "..KHHHHHHHHHHK..", ".KHHhHHHHHHHHHK.",
        "KHHHHHHhHHHHHHHK", "KHHHHHHHHHHHKHHK", "KHhHHHHhHHHHHHHK", "KHHHHHHHHHHXXHHK", "KHHHhHHHHHXKKHHK", ".KHHHHHHHXXK.KHK",
        ".KHHKKHHKXK..KHK", ".KHHK.KHHKK..KHK", ".KhhK.KhhK...KK.", ".KKKK.KKKK......",
    ]
    static let frostBarrel: RpgGrid = [
        "................", ".........f......", "........fFf.....", ".........K......", "........K.......", "....KKKKKKKK....",
        "...KWWWWWWWWK...", "...KMMMMMMMMK...", "..KLLlLLLLlLLK..", "..KLLKLLLLKLLK..", "..KLLLLKKLLLLK..", "..KLLlLLLLlLLK..",
        "...KMMMMMMMMK...", "...KLLLLLLLLK...", "....KKKKKKKK....", "................",
    ]
    static let frostWisp: RpgGrid = [
        "................", ".......K........", "......KOK.......", ".....KOOOK..K...", "..K.KOOWOOKKOK..", ".KOKOOWWWOOOOK..",
        ".KOOOWWWWWOOK...", "..KOOWKWWKWOOK..", "..KOOWWWWWWOOK..", "..KOOWWKKWWOOK..", "...KOOWWWWOOK...", "...KOOOOOOOOK...",
        "....KOOGGOOK....", ".....KGGGGK.....", "......KGGK......", ".......KK.......",
    ]
    static let frostDragon: RpgGrid = [
        ".K..........KK..", "KWK........KXK..", "KWWK......KOOK..", "KWWWK....KOOYOK.", ".KWWWK..KOOOOOOK", "..KWWWKKOOKKKKK.",
        "...KWWOOOOK.....", "....KOOOOOOK....", "..KKOOOoOOOOK...", ".KOOOOOOOWWOK...", "KOOoOOOOWWWOK...", "KOKKOOOOWWOOK...",
        ".K..KOOKKOOKOK..", "...KOOK.KOOKKOK.", "...KKKK.KKKK.KK.", "................",
    ]

    /// Walrus: the seal with tusks, whiskers and a darker muzzle.
    private static let frostWalrus = endgameStamp(frostSeal, ["KCCCK", "CXCXC", ".X.X.", ".K.K."], 10, 10)
    /// Spear thrower: a leather cap instead of the horned helmet, a javelin instead of the axe.
    private static let frostSpearman = endgameStamp(frostViking, [
        "______________M_", "______________M_", "_____KKKKKK___L_", "____KMMMMMMK__L_", "____KMMMMMMK__L_", "..KKMMMMMMMMKKL_",
        "..............L.", ".............KLK", ".............KLK", ".............KLK", ".............KK.", "................",
    ])
    /// Berserker: bare head with a wild mane and war paint, an axe in each hand.
    private static let frostBerserker = endgameStamp(frostViking, [
        "__.H...H..H.____", "_.KHK.KHK.KHK.__", "_KHHHKHHHKHHHK__", "KHHHHHHHHHHHHHK_", ".KHHHHHHHHHHHK._", "..KHHHHHHHHHHK..",
        "..KWKSRSSRSKWKK.", "...............K", "................", "KMMK............", "KMMLK...........", "KMMK............",
        ".KLK............",
    ])
    /// Skald: the robed caster with antlers on the hood, a white beard and a rune staff.
    private static let frostSkald = endgameStamp(mage, [
        "..KTK......KTK..", "..KTTK....KTTK..", "...KTTK..KTTK...", "....KK....KK.....", "...............O", "..............KL",
        "..............KL", "......WWWW....KL", ".....KWWWWK...KL", "..............KL", "..............KL", "..............KL",
        "..............KL", "..............KK",
    ])
    /// Icicle bats: icicles hanging under the wings and fangs.
    private static let frostIcicleBat = endgameStamp(bat, [
        "................", ".K............K.", ".O..K......K..O.", ".O..O......O..O.", "....O..KK..O....", ".......OO.......",
    ], 0, 9)
    /// Troll: a shaggy mane, tusks, a long nose and a club.
    private static let frostTroll = endgameStamp(golem, [
        "....KKHHKKH.....", "...KHHHHHHHHK...", "...KNQNNNNQNK...", "...KNNNnnNNNK...", "...KNWNNNNWNK...", ".KKKKNNNNNNKKKKL",
        "KNNNKNNnnNNKNNKL", "KNNNKNnNNnNKNNKL", "KNNKNNNNNNNNKKLL", ".KKKNNNNNNNNKLLL", "....KNNNNNNK.KLL", "............KK..",
    ], 0, 0)
    /// Valkyrie: the knight with a winged helmet and white wings.
    private static let frostValkyrie = endgameStamp(warrior, [
        "..KW..KKKK..WK..", ".KWWK.....KWWK..", "KWWK.......KWWK.", ".KK.........KK..", "................", "................",
        "................", "KK............KK", "KWK..........KWK", "KWWK........KWWK", "KWWK........KWWK", ".KWK........KWK.",
        "..K..........K..",
    ])

    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsFrost: [String: SpriteSpec] = [
        "frost_seal": SpriteSpec(grid: frostSeal, swap: ["W": rgb(246, 248, 255), "w": rgb(186, 204, 228), "D": rgb(60, 56, 80)]),
        "frost_owl": SpriteSpec(grid: frostOwl, swap: ["W": rgb(248, 250, 255), "z": rgb(140, 150, 175), "O": rgb(255, 170, 60), "Y": rgb(255, 214, 80)]),
        "frost_lemming": SpriteSpec(grid: frostLemming, swap: ["H": rgb(196, 140, 90), "h": rgb(90, 60, 40), "C": rgb(250, 236, 210), "n": rgb(240, 140, 150)]),
        "frost_reindeer": SpriteSpec(grid: frostDeer, swap: ["H": rgb(176, 112, 70), "h": rgb(120, 74, 44), "C": rgb(250, 244, 230), "T": rgb(255, 214, 70)]),
        "frost_raider": SpriteSpec(grid: frostViking, swap: ["W": rgb(238, 242, 250), "w": rgb(170, 186, 210), "S": rgb(120, 150, 190), "M": rgb(150, 160, 176),
                                                             "X": rgb(236, 226, 200), "L": rgb(150, 96, 52), "Y": rgb(240, 190, 50)]),
        "frost_walrus": SpriteSpec(grid: frostWalrus, swap: ["W": rgb(150, 104, 84), "w": rgb(110, 72, 58), "D": rgb(50, 34, 30), "C": rgb(214, 170, 140),
                                                             "X": rgb(255, 250, 230)]),
        "frost_spearman": SpriteSpec(grid: frostSpearman, swap: ["W": rgb(200, 206, 214), "w": rgb(140, 148, 160), "S": rgb(110, 130, 170), "M": rgb(130, 86, 50),
                                                                 "L": rgb(150, 96, 52), "Y": rgb(220, 70, 60)]),
        "frost_meadbarrel": SpriteSpec(grid: frostBarrel, swap: ["L": rgb(176, 112, 56), "l": rgb(120, 74, 36), "M": rgb(150, 150, 168), "W": rgb(255, 236, 150)]),
        "frost_mammoth": SpriteSpec(grid: frostMammoth, swap: ["H": rgb(150, 98, 66), "h": rgb(104, 64, 42), "X": rgb(250, 244, 226)]),
        "frost_wisp": SpriteSpec(grid: frostWisp, swap: ["O": rgb(110, 255, 190), "W": rgb(230, 255, 245), "G": rgb(190, 120, 255)]),
        "frost_skald": SpriteSpec(grid: frostSkald, swap: ["P": rgb(196, 206, 222), "p": rgb(120, 132, 160), "S": rgb(130, 160, 200), "Y": rgb(90, 230, 255),
                                                           "T": rgb(170, 120, 70), "W": rgb(250, 250, 255), "L": rgb(120, 80, 50), "O": rgb(110, 240, 255)]),
        "frost_iciclebat": SpriteSpec(grid: frostIcicleBat, swap: ["A": rgb(70, 90, 150), "a": rgb(40, 52, 96), "W": rgb(200, 240, 255), "O": rgb(200, 240, 255)]),
        "frost_troll": SpriteSpec(grid: frostTroll, swap: ["N": rgb(110, 150, 160), "n": rgb(70, 100, 112), "Q": rgb(255, 230, 90), "H": rgb(230, 240, 250),
                                                           "W": rgb(255, 255, 240), "L": rgb(120, 84, 56)]),
        "frost_berserker": SpriteSpec(grid: frostBerserker, swap: ["W": rgb(226, 214, 200), "w": rgb(160, 140, 120), "S": rgb(150, 160, 200), "H": rgb(220, 90, 40),
                                                                   "R": rgb(200, 30, 40), "M": rgb(200, 206, 220), "L": rgb(120, 76, 44), "Y": rgb(240, 190, 50)]),
        "frost_valkyrie": SpriteSpec(grid: frostValkyrie, swap: ["M": rgb(214, 226, 240), "m": rgb(140, 160, 190), "R": rgb(90, 150, 230), "r": rgb(50, 90, 170),
                                                                 "B": rgb(255, 230, 120), "W": rgb(250, 252, 255), "Y": rgb(255, 214, 80)]),
        "frost_jarl": SpriteSpec(grid: frostViking, swap: ["W": rgb(250, 250, 255), "w": rgb(190, 200, 220), "S": rgb(90, 120, 180), "M": rgb(240, 196, 70),
                                                           "X": rgb(255, 248, 230), "L": rgb(170, 40, 40), "Y": rgb(255, 226, 110)], boss: true),
        "frost_wyrm": SpriteSpec(grid: frostDragon, swap: ["O": rgb(150, 210, 250), "o": rgb(80, 130, 200), "W": rgb(232, 248, 255), "X": rgb(255, 255, 255),
                                                           "Y": rgb(60, 255, 230)], boss: true),
    ]

    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsFrost: [String: [Character: CGColor]] = [
        "frost_fur": ["B": rgb(240, 242, 248), "E": rgb(170, 180, 200)],
        "frost_aurora": ["B": rgb(140, 255, 210), "E": rgb(150, 90, 230)],
        "frost_horn": ["B": rgb(250, 238, 200), "E": rgb(200, 150, 60)],
        "frost_heart": ["B": rgb(170, 240, 255), "E": rgb(40, 110, 210)],
        "frost_mead": ["B": rgb(255, 200, 70), "E": rgb(200, 130, 30)],
        "frost_jerky": ["B": rgb(170, 90, 60), "E": rgb(110, 50, 34)],
        "frost_armor": ["B": rgb(236, 232, 222), "E": rgb(140, 100, 70)],
        "frost_boots": ["B": rgb(160, 110, 70), "J": rgb(240, 244, 255), "W": rgb(255, 255, 255)],
        "frost_helm": ["B": rgb(200, 206, 220), "J": rgb(250, 240, 210), "W": rgb(255, 255, 255)],
        "frost_ring": ["B": rgb(200, 230, 255), "J": rgb(120, 255, 200), "W": rgb(255, 255, 255)],
        "frost_amulet": ["B": rgb(170, 220, 250), "J": rgb(60, 140, 230), "W": rgb(255, 255, 255)],
        "frost_axe": ["B": rgb(230, 248, 255), "E": rgb(90, 170, 230), "G": rgb(240, 196, 70), "H": rgb(110, 70, 40), "J": rgb(120, 255, 255)],
        "frost_bow": ["B": rgb(150, 255, 210), "G": rgb(160, 100, 230), "W": rgb(240, 255, 250)],
    ]
}

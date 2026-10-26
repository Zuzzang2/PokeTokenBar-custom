import CoreGraphics
import Foundation

// 지하 마계 (Lv55-80, bosses Lv72 / Lv82). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
//
// Balance: every normal monster is interpolated (log-linear in level) between the existing monsters of the same behaviour, e.g.
//   melee    L48 뼈 군주 6200/270/88 xp2300 · L64 산호 게 16100/405/145 xp5050 · L69 사원 수호병 19150/450/160 · L75 파멸 기사 23000/500/175 xp8300
//   heavy    L52 지하묘지 수호상 10000/310/110 · L79 용인 수호병 34000/560/245 xp12150 · L85 흑요석 골렘 40500/615/270 xp16150
//   ranged   L62 바람 정령 12000/390/97 · L67 사이렌 14350/430/105 xp5650 · L76 용인 궁수 19150/510/125 xp8700 · L79 서리 마녀
//   flyer    L62 심해 해파리 12750/350/97 xp4500 · L70 임프 16850/410/115 xp6150 · L77 와이번 21000/465/130 · L83 불새 25000/510/140
//   swarm    L47 원혼떼 2275/183/44 · L65 심연 피라냐떼 6700/250/59 xp2900 · L68 시간 풍뎅이떼 · L74 아기 용떼 9000/295/70 xp4350
//   charger  L49 뼈 투우 · L64 뇌운 산양 16950/405/145 xp6300 · L71 시계 골렘 21500/465/165 xp8500 · L72 지옥견 22000/475/170
//   exploder L73 저주 폭탄 10900/600/85 xp7900 · L78 눈꽃 폭탄 12700/655/93 xp10100
//   passive  L30 용암 슬라임 1900/130/42 · L58 구름 슬라임 10300/285/115 xp3800
//   coward   황금 슬라임-style treasure on the melee curve: ~0.85x HP, no attack, 1.5x XP, 5x gold (half its ratio: these roam ordinary maps)
//   bosses   L70 심해의 크라켄 1.37M/650/160 xp220k · L80 고룡 바르가노스 1.74M/785/190 xp495k · L85 얼음 여왕 1.94M/855/205 xp710k
// Gear: helmet/boots on the tier-8 budget, ring/amulet on tier 9, the sword on tier 10 and the claw on tier 11
// (same sum of stats, a different spread; the weapons trade a little attack for fire and cosmic).

enum RpgUnderworldRegion {
    private static let m1 = RpgMapID("underworld_1"), m2 = RpgMapID("underworld_2"), m3 = RpgMapID("underworld_3"), m4 = RpgMapID("underworld_4")
    private static let m5 = RpgMapID("underworld_5"), m6 = RpgMapID("underworld_6"), m7 = RpgMapID("underworld_7")
    private static let b1 = RpgMapID("underworld_b1"), b2 = RpgMapID("underworld_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    static let region = RpgRegion(
        id: "underworld", name: "지하 마계", blurb: "용암강이 흐르는 땅속 지옥, 영혼을 벼리는 대장간의 불꽃",
        minLevel: 53, entry: m1, entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: m1, name: "유황 동굴", levelText: "Lv55~60", width: 50, height: 30, kind: .cave, seed: 10001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), RpgMaps.p(48, 15, m2, 4, 15, minLevel: 59)],
                      monsters: RpgMaps.sp([("underworld_sulfurslime", 8), ("underworld_imps", 7), ("underworld_worm", 6), ("underworld_thief", 2)]),
                      theme: RpgTheme(tint: tint(0.8, 0.8, 0.2), tintAlpha: 0.5, blend: .overlay, darkness: 0.7),
                      waypoint: true),
            RpgMapDef(id: m2, name: "잿빛 협곡", levelText: "Lv59~64", width: 50, height: 30, kind: .volcano, seed: 10002,
                      portals: [RpgMaps.p(1, 15, m1, 45, 15, minLevel: 53), RpgMaps.p(48, 15, m3, 4, 15, minLevel: 63)],
                      monsters: RpgMaps.sp([("underworld_worm", 5), ("underworld_thief", 2), ("underworld_cerberus", 4), ("underworld_chain", 6)]),
                      theme: RpgTheme(floor: .ash, obstacle: .rock, pool: .lava, decor: .ash, tint: tint(0.9, 0.6, 0.6), tintAlpha: 0.35, blend: .multiply)),
            RpgMapDef(id: m3, name: "용암강 나루", levelText: "Lv63~67", width: 50, height: 30, kind: .volcano, seed: 10003,
                      portals: [RpgMaps.p(1, 15, m2, 45, 15, minLevel: 59), RpgMaps.p(48, 15, m4, 4, 16, minLevel: 66)],
                      monsters: RpgMaps.sp([("underworld_chain", 5), ("underworld_wisp", 6), ("underworld_smith", 4), ("underworld_cerberus", 3)]),
                      theme: RpgTheme(floor: .ash, obstacle: .rock, pool: .lava, decor: .ash, tint: tint(1.0, 0.45, 0.2), tintAlpha: 0.3, blend: .overlay),
                      waypoint: true),
            RpgMapDef(id: m4, name: "영혼 대장간", levelText: "Lv66~70", width: 50, height: 32, kind: .castle, seed: 10004,
                      portals: [RpgMaps.p(1, 16, m3, 45, 15, minLevel: 63), RpgMaps.p(48, 16, m5, 4, 15, minLevel: 69),
                                RpgMaps.p(25, 1, b1, 14, 17, minLevel: 67)],
                      monsters: RpgMaps.sp([("underworld_smith", 5), ("underworld_nightmare", 6), ("underworld_wisp", 4), ("underworld_furnace", 3)]),
                      theme: RpgTheme(tint: tint(1.0, 0.5, 0.2), tintAlpha: 0.5, blend: .overlay, darkness: 0.5)),
            RpgMapDef(id: b1, name: "몰록의 용광로", levelText: "보스 Lv72", width: 28, height: 22, kind: .boss, seed: 10008,
                      portals: [RpgMaps.p(14, 20, m4, 25, 4, minLevel: 66)], monsters: RpgMaps.sp([("underworld_forgelord", 1)]), zone: .volcano,
                      theme: RpgTheme(tint: tint(1.0, 0.45, 0.15), tintAlpha: 0.45, blend: .overlay)),
            RpgMapDef(id: m5, name: "비명의 갱도", levelText: "Lv69~74", width: 48, height: 30, kind: .cave, seed: 10005,
                      portals: [RpgMaps.p(1, 15, m4, 45, 16, minLevel: 66), RpgMaps.p(46, 15, m6, 4, 15, minLevel: 72)],
                      monsters: RpgMaps.sp([("underworld_furnace", 4), ("underworld_miner", 7), ("underworld_moths", 6), ("underworld_nightmare", 4)]),
                      theme: RpgTheme(tint: tint(0.6, 0.2, 0.5), tintAlpha: 0.5, blend: .overlay, darkness: 0.85),
                      waypoint: true),
            RpgMapDef(id: m6, name: "형벌의 사막", levelText: "Lv72~77", width: 50, height: 30, kind: .desert, seed: 10006,
                      portals: [RpgMaps.p(1, 15, m5, 43, 15, minLevel: 69), RpgMaps.p(48, 15, m7, 4, 16, minLevel: 75)],
                      monsters: RpgMaps.sp([("underworld_moths", 6), ("underworld_judge", 6), ("underworld_urn", 3), ("underworld_scout", 4)]),
                      theme: RpgTheme(floor: .sand, obstacle: .cactus, pool: .lava, decor: .dune, tint: tint(0.85, 0.3, 0.25), tintAlpha: 0.65, blend: .multiply)),
            RpgMapDef(id: m7, name: "마계 왕좌 회랑", levelText: "Lv75~80", width: 50, height: 32, kind: .castle, seed: 10007,
                      portals: [RpgMaps.p(1, 16, m6, 45, 15, minLevel: 72), RpgMaps.p(25, 1, b2, 14, 17, minLevel: 77)],
                      monsters: RpgMaps.sp([("underworld_urn", 3), ("underworld_scout", 6), ("underworld_hellguard", 5), ("underworld_judge", 4)]),
                      theme: RpgTheme(tint: tint(0.75, 0.1, 0.2), tintAlpha: 0.5, blend: .overlay, darkness: 0.6),
                      waypoint: true),
            RpgMapDef(id: b2, name: "아스타로스의 옥좌", levelText: "보스 Lv82", width: 28, height: 22, kind: .boss, seed: 10009,
                      portals: [RpgMaps.p(14, 20, m7, 25, 4, minLevel: 75)], monsters: RpgMaps.sp([("underworld_overlord", 1)]), zone: .castle,
                      theme: RpgTheme(tint: tint(0.6, 0.05, 0.25), tintAlpha: 0.5, blend: .overlay)),
        ],
        monsters: [
            RpgMonsters.m("underworld_sulfurslime", "유황 슬라임", "underworld_sulfurslime", 55, 8600, 260, 103, 30, 3200, 500...730, .passive,
                          [("hp3", 0.05), ("mp1", 0.06), ("underworld_brimstone", 0.06), ("sword7", 0.004), ("staff7", 0.004), ("armor6", 0.004), ("stone", 0.215)]),
            RpgMonsters.m("underworld_imps", "불씨 도깨비떼", "underworld_imps", 57, 4150, 220, 52, 60, 1900, 295...425, .swarm,
                          [("hp3", 0.1), ("underworld_brimstone", 0.05), ("stone", 0.085)]),
            RpgMonsters.m("underworld_worm", "용암 지렁이", "underworld_worm", 58, 11250, 350, 120, 38, 3750, 635...915, .aggressive,
                          [("hp3", 0.08), ("underworld_brimstone", 0.07), ("sword9", 0.004), ("claw9", 0.004), ("armor8", 0.004), ("helmet8", 0.004), ("stone", 0.22)]),
            RpgMonsters.m("underworld_thief", "보석 도둑 꼬마악마", "underworld_thief", 60, 10800, 0, 128, 46, 6200, 3500...5000, .coward,
                          [("hp3", 0.3), ("underworld_brimstone", 0.3), ("underworld_hellsteel", 0.08), ("underworld_pepper", 0.1), ("stone", 0.3)]),
            RpgMonsters.m("underworld_cerberus", "머리 셋 지옥개", "underworld_cerberus", 62, 15750, 390, 137, 39, 5800, 905...1300, .charger,
                          [("hp3", 0.1), ("underworld_brimstone", 0.06), ("dagger9", 0.004), ("mace9", 0.004), ("armor8", 0.004), ("boots8", 0.004), ("stone", 0.128)]),
            RpgMonsters.m("underworld_chain", "사슬 악마", "underworld_chain", 63, 15150, 395, 141, 40, 4800, 800...1150, .aggressive,
                          [("hp3", 0.08), ("underworld_brimstone", 0.07), ("underworld_soul", 0.03), ("bow9", 0.004), ("rod9", 0.004), ("armor8", 0.004),
                           ("ring8", 0.004), ("book_w_ult", 0.002), ("book_k_ult", 0.002), ("stone", 0.23)]),
            RpgMonsters.m("underworld_wisp", "떠도는 넋불", "underworld_wisp", 65, 14150, 370, 103, 57, 5050, 830...1200, .flyer,
                          [("hp3", 0.08), ("mp1", 0.08), ("underworld_soul", 0.06), ("staff9", 0.004), ("dagger9", 0.004), ("armor8", 0.004), ("amulet8", 0.004),
                           ("stone", 0.234)]),
            RpgMonsters.m("underworld_smith", "풀무질 악마", "underworld_smith", 67, 19750, 430, 172, 26, 6550, 985...1400, .aggressive,
                          [("hp3", 0.08), ("underworld_soul", 0.06), ("underworld_pepper", 0.03), ("sword9", 0.004), ("mace9", 0.004), ("armor9", 0.004),
                           ("helmet9", 0.004), ("book_c_ult", 0.002), ("book_r_ult", 0.002), ("stone", 0.238)]),
            RpgMonsters.m("underworld_nightmare", "꿈먹는 몽마", "underworld_nightmare", 68, 14800, 440, 107, 34, 5950, 980...1400, .ranged,
                          [("mp2", 0.08), ("hp3", 0.08), ("underworld_soul", 0.06), ("underworld_oil", 0.04), ("staff10", 0.004), ("rod10", 0.004), ("armor9", 0.004),
                           ("amulet9", 0.004), ("book_m_ult", 0.002), ("book_s_ult", 0.002), ("stone", 0.24)]),
            RpgMonsters.m("underworld_furnace", "용광로 골렘", "underworld_furnace", 70, 20800, 455, 162, 43, 8150, 1250...1850, .charger,
                          [("hp4", 0.1), ("underworld_soul", 0.06), ("sword10", 0.004), ("claw10", 0.004), ("armor9", 0.004), ("boots9", 0.004), ("stone", 0.144)]),
            RpgMonsters.m("underworld_miner", "갱도 광부 망령", "underworld_miner", 71, 20400, 465, 165, 36, 6850, 1100...1550, .aggressive,
                          [("hp4", 0.08), ("underworld_soul", 0.06), ("underworld_elixir", 0.03), ("bow10", 0.004), ("dagger10", 0.004), ("armor9", 0.004),
                           ("ring9", 0.004), ("book_a_ult", 0.002), ("stone", 0.246)]),
            RpgMonsters.m("underworld_moths", "업화 나방떼", "underworld_moths", 73, 8700, 290, 69, 62, 4150, 585...840, .swarm,
                          [("hp4", 0.1), ("mp2", 0.04), ("underworld_soul", 0.05), ("stone", 0.15)]),
            RpgMonsters.m("underworld_judge", "형벌 집행관", "underworld_judge", 74, 17950, 490, 120, 36, 7900, 1200...1700, .ranged,
                          [("hp4", 0.08), ("mp2", 0.08), ("underworld_soul", 0.07), ("underworld_oil", 0.04), ("mace10", 0.004), ("staff10", 0.004), ("armor9", 0.004),
                           ("helmet9", 0.004), ("stone", 0.252)]),
            RpgMonsters.m("underworld_urn", "원혼 항아리", "underworld_urn", 76, 11950, 630, 90, 48, 9150, 1300...1850, .exploder,
                          [("hp4", 0.1), ("underworld_soul", 0.06), ("stone", 0.156)]),
            RpgMonsters.m("underworld_scout", "날개 악마 척후병", "underworld_scout", 78, 21600, 470, 132, 57, 9150, 1300...1850, .flyer,
                          [("hp4", 0.08), ("mp2", 0.08), ("underworld_soul", 0.07), ("bow10", 0.004), ("rod10", 0.004), ("armor10", 0.004), ("amulet10", 0.004),
                           ("stone", 0.26)]),
            RpgMonsters.m("underworld_hellguard", "지옥 근위병", "underworld_hellguard", 80, 35000, 570, 249, 26, 12750, 1750...2550, .aggressive,
                          [("hp4", 0.08), ("underworld_soul", 0.08), ("underworld_elixir", 0.04), ("sword10", 0.004), ("claw10", 0.004), ("armor10", 0.004),
                           ("boots10", 0.004), ("stone", 0.264)]),
            RpgMonsters.boss("underworld_forgelord", "영혼 대장장이 몰록", "underworld_forgelord", 72, 1_435_000, 675, 166, 36, 259_000, 51500...85500, .golem,
                             minion: "underworld_imps", element: .fire,
                             [("underworld_helmet", 0.2), ("underworld_boots", 0.2), ("underworld_sword", 0.12), ("underworld_hellsteel", 1), ("underworld_hellsteel", 0.5),
                              ("underworld_soul", 1), ("underworld_soul", 1), ("underworld_soul", 0.5),
                              ("sword10", 0.1), ("bow10", 0.1), ("staff10", 0.1), ("dagger10", 0.1), ("mace10", 0.1), ("claw10", 0.1), ("rod10", 0.1),
                              ("sword9", 0.1), ("bow9", 0.1), ("staff9", 0.1), ("dagger9", 0.1), ("mace9", 0.1), ("claw9", 0.1), ("rod9", 0.1),
                              ("armor9", 0.2), ("armor8", 0.2), ("ring9", 0.08), ("amulet9", 0.08), ("helmet9", 0.08), ("boots9", 0.08), ("hp4", 1)]),
            RpgMonsters.boss("underworld_overlord", "마계 군주 아스타로스", "underworld_overlord", 82, 1_815_000, 810, 196, 37, 572_000, 76500...127_000, .demon,
                             minion: "underworld_scout", element: .cosmic,
                             [("underworld_ring", 0.25), ("underworld_amulet", 0.2), ("underworld_claw", 0.12), ("underworld_hellsteel", 1), ("underworld_hellsteel", 1),
                              ("underworld_hellsteel", 0.5),
                              ("sword11", 0.1), ("bow11", 0.1), ("staff11", 0.1), ("dagger11", 0.1), ("mace11", 0.1), ("claw11", 0.1), ("rod11", 0.1),
                              ("sword10", 0.1), ("bow10", 0.1), ("staff10", 0.1), ("dagger10", 0.1), ("mace10", 0.1), ("claw10", 0.1), ("rod10", 0.1),
                              ("armor10", 0.2), ("armor9", 0.2), ("ring10", 0.08), ("amulet10", 0.08), ("helmet10", 0.08), ("boots10", 0.08), ("hp4", 1)]),
        ],
        items: [
            RpgItem(id: "underworld_brimstone", name: "유황석", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 4200, element: .base, inShop: false),
            RpgItem(id: "underworld_soul", name: "영혼 결정", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 9000, element: .base, inShop: false),
            RpgItem(id: "underworld_hellsteel", name: "지옥강 주괴", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 22000, element: .base, inShop: false),
            RpgItem(id: "underworld_elixir", name: "용암 엘릭서", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 6000, price: 4300, element: .base, inShop: false),
            RpgItem(id: "underworld_oil", name: "영혼 등잔 기름", kind: .potionMP, rarity: 3, attack: 0, defense: 0, heal: 1000, price: 1400, element: .base, inShop: false),
            RpgItem(id: "underworld_pepper", name: "지옥불 고추", kind: .buff("atk"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 600, element: .base, inShop: false),
            // 천공의 투구 (2300 / 72): defense over HP.
            RpgItem(id: "underworld_helmet", name: "뿔 달린 지옥 투구", kind: .helmet, rarity: 3, attack: 0, defense: 94, heal: 0, price: 380_000, element: .base, inShop: false,
                    bonusHP: 1600),
            // 천공의 장화 (11% / 52): defense over speed.
            RpgItem(id: "underworld_boots", name: "용암 걸음 장화", kind: .boots, rarity: 3, attack: 0, defense: 66, heal: 0, price: 380_000, element: .base, inShop: false,
                    bonusSpeed: 0.08),
            // 심해의 반지 (2500 / 14.5% / 37%): attack over HP — the devil's bargain.
            RpgItem(id: "underworld_ring", name: "악마 계약 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 650_000, element: .base, inShop: false,
                    bonusHP: 1600, bonusCrit: 0.15, bonusAttack: 0.49),
            // 심해 진주 목걸이 (4000 / 760 / 120): defense over HP and MP.
            RpgItem(id: "underworld_amulet", name: "영혼 등불 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 174, heal: 0, price: 650_000, element: .base, inShop: false,
                    bonusHP: 3200, bonusMP: 570),
            RpgItem(id: "underworld_sword", name: "지옥불 대검", kind: .weapon(.warrior), rarity: 3, attack: 215, defense: 0, heal: 0, price: 300_000, element: .fire, inShop: false),
            RpgItem(id: "underworld_claw", name: "영혼 수확 권갑", kind: .weapon(.monk), rarity: 3, attack: 275, defense: 0, heal: 0, price: 480_000, element: .cosmic, inShop: false),
        ],
        recipes: [
            RpgRecipe(id: "underworld_helmet", output: "underworld_helmet", count: 1, materials: ["underworld_brimstone": 14, "underworld_soul": 9, "stone": 18], gold: 360_000),
            RpgRecipe(id: "underworld_boots", output: "underworld_boots", count: 1, materials: ["underworld_brimstone": 13, "underworld_soul": 9, "stone": 18], gold: 360_000),
            RpgRecipe(id: "underworld_ring", output: "underworld_ring", count: 1, materials: ["underworld_soul": 16, "underworld_hellsteel": 3, "stone": 20], gold: 700_000),
            RpgRecipe(id: "underworld_amulet", output: "underworld_amulet", count: 1, materials: ["underworld_soul": 16, "underworld_hellsteel": 3, "stone": 20], gold: 660_000),
            RpgRecipe(id: "underworld_sword", output: "underworld_sword", count: 1, materials: ["underworld_soul": 18, "underworld_hellsteel": 4, "stone": 30], gold: 320_000),
            RpgRecipe(id: "underworld_claw", output: "underworld_claw", count: 1, materials: ["underworld_soul": 20, "underworld_hellsteel": 5, "stone": 35], gold: 520_000),
            RpgRecipe(id: "underworld_elixir", output: "underworld_elixir", count: 2, materials: ["underworld_brimstone": 2, "underworld_soul": 1], gold: 3000),
            RpgRecipe(id: "underworld_pepper", output: "underworld_pepper", count: 3, materials: ["underworld_brimstone": 2], gold: 200),
        ]
    )
}

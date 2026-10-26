import CoreGraphics
import Foundation

// 유령 마을 (Lv45-72, bosses Lv64 / Lv74). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
//
// Balance: every normal monster is interpolated (log-linear in level) between the existing monsters of the same behaviour, e.g.
//   melee    L42 암흑 기사 5200/230/80 xp1700 · L48 뼈 군주 6200/270/88 xp2300 · L64 산호 게 16100/405/145 xp5050
//   heavy    L38 용암 골렘 · L50 가고일 8000/290/100 xp2600 · L52 지하묘지 수호상 · L79 용인 수호병 34000/560/245
//   ranged   L45 그림자 마법사/망령 ~4500/252/67 xp1950 · L62 바람 정령 12000/390/97 · L67 사이렌 · L76 용인 궁수 19150/510/125 xp8700
//   flyer    L44 악마 박쥐 4000/240/60 · L62 심해 해파리 12750/350/97 xp4500 · L70 임프 16850/410/115 xp6150
//   swarm    L45 굶주린 구울떼 1924/168/42 xp925 · L68 시간 풍뎅이떼 7400/265/62 xp3250 · L74 아기 용떼 9000/295/70 xp4350
//   charger  L49 뼈 투우 9750/301/96 xp3300 · L64 뇌운 산양 16950/405/145 xp6300 · L71 시계 골렘 21500/465/165 xp8500
//   exploder L47 영혼 폭탄 3849/336/51 xp2405 · L49 죽음의 폭탄 · L73 저주 폭탄 10900/600/85 xp7900
//   coward   황금 슬라임-style treasure on the melee curve: ~0.85x HP, no attack, 1.5x XP, 5x gold (half its ratio: these roam ordinary maps)
//   bosses   L58 마왕 975k/500/110 xp90k · L70 심해의 크라켄 1.37M/650/160 xp220k · L80 고룡 바르가노스 1.74M/785/190 xp495k
// Gear: helmet/boots on the tier-7 budget, ring/amulet on tier 8, the mace on tier 9 and the broom on tier 10
// (same sum of stats, a different spread; the broom trades 15 attack for poison).

enum RpgHauntedRegion {
    private static let m1 = RpgMapID("haunted_1"), m2 = RpgMapID("haunted_2"), m3 = RpgMapID("haunted_3"), m4 = RpgMapID("haunted_4")
    private static let m5 = RpgMapID("haunted_5"), m6 = RpgMapID("haunted_6"), m7 = RpgMapID("haunted_7")
    private static let b1 = RpgMapID("haunted_b1"), b2 = RpgMapID("haunted_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    static let region = RpgRegion(
        id: "haunted", name: "유령 마을", blurb: "종소리가 멎은 폐마을, 허수아비와 마녀가 밤을 지킨다",
        minLevel: 43, entry: m1, entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: m1, name: "시든 허수아비 밭", levelText: "Lv45~50", width: 50, height: 30, kind: .desert, seed: 9001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), RpgMaps.p(48, 15, m2, 4, 15, minLevel: 49)],
                      monsters: RpgMaps.sp([("haunted_crow", 7), ("haunted_scarecrow", 7), ("haunted_pumpkin", 4), ("haunted_zombie", 4)]),
                      theme: RpgTheme(floor: .sand, obstacle: .tree, pool: .water, decor: .dune, tint: tint(0.9, 0.6, 0.5), tintAlpha: 0.45, blend: .multiply),
                      waypoint: true),
            RpgMapDef(id: m2, name: "안개 낀 폐마을", levelText: "Lv49~54", width: 50, height: 30, kind: .field, seed: 9002,
                      portals: [RpgMaps.p(1, 15, m1, 45, 15, minLevel: 43), RpgMaps.p(48, 15, m3, 4, 16, minLevel: 53)],
                      monsters: RpgMaps.sp([("haunted_zombie", 7), ("haunted_ghost", 6), ("haunted_pumpkin", 3), ("haunted_cat", 2)]),
                      theme: RpgTheme(floor: .grass, obstacle: .castleWall, pool: .water, decor: .stone, tint: tint(0.55, 0.55, 0.7), tintAlpha: 0.55)),
            RpgMapDef(id: m3, name: "무너진 예배당", levelText: "Lv53~58", width: 50, height: 32, kind: .castle, seed: 9003,
                      portals: [RpgMaps.p(1, 16, m2, 45, 15, minLevel: 49), RpgMaps.p(48, 16, m4, 4, 15, minLevel: 57)],
                      monsters: RpgMaps.sp([("haunted_ghost", 5), ("haunted_cat", 2), ("haunted_wisp", 6), ("haunted_doll", 4)]),
                      theme: RpgTheme(tint: tint(0.55, 0.65, 0.6), tintAlpha: 0.45, darkness: 0.55),
                      waypoint: true),
            RpgMapDef(id: m4, name: "까마귀 공동묘지", levelText: "Lv57~62", width: 50, height: 30, kind: .forest, seed: 9004,
                      portals: [RpgMaps.p(1, 15, m3, 45, 16, minLevel: 53), RpgMaps.p(48, 15, m5, 4, 15, minLevel: 61),
                                RpgMaps.p(25, 1, b1, 14, 17, minLevel: 59)],
                      monsters: RpgMaps.sp([("haunted_doll", 4), ("haunted_ghoul", 7), ("haunted_banshee", 5)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .pillar, pool: .water, decor: .stone, tint: tint(0.35, 0.5, 0.55), tintAlpha: 0.55, darkness: 0.3)),
            RpgMapDef(id: b1, name: "녹슨 종탑", levelText: "보스 Lv64", width: 28, height: 22, kind: .boss, seed: 9008,
                      portals: [RpgMaps.p(14, 20, m4, 25, 4, minLevel: 57)], monsters: RpgMaps.sp([("haunted_bellringer", 1)]), zone: .castle,
                      theme: RpgTheme(tint: tint(0.75, 0.55, 0.35), tintAlpha: 0.45)),
            RpgMapDef(id: m5, name: "마녀의 독늪", levelText: "Lv61~66", width: 48, height: 30, kind: .forest, seed: 9005,
                      portals: [RpgMaps.p(1, 15, m4, 45, 15, minLevel: 57), RpgMaps.p(46, 15, m6, 4, 15, minLevel: 64)],
                      monsters: RpgMaps.sp([("haunted_banshee", 5), ("haunted_witch", 6), ("haunted_toad", 3), ("haunted_armor", 3)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .water, pool: .water, decor: .flower, tint: tint(0.4, 0.65, 0.25), tintAlpha: 0.5, darkness: 0.3),
                      waypoint: true),
            RpgMapDef(id: m6, name: "시든 장미 정원", levelText: "Lv64~69", width: 50, height: 30, kind: .field, seed: 9006,
                      portals: [RpgMaps.p(1, 15, m5, 43, 15, minLevel: 61), RpgMaps.p(48, 15, m7, 4, 16, minLevel: 67)],
                      monsters: RpgMaps.sp([("haunted_toad", 3), ("haunted_armor", 4), ("haunted_bats", 6), ("haunted_witch", 4)]),
                      theme: RpgTheme(floor: .grass, obstacle: .tree, pool: .water, decor: .flower, tint: tint(0.6, 0.25, 0.55), tintAlpha: 0.45)),
            RpgMapDef(id: m7, name: "저주받은 저택", levelText: "Lv67~72", width: 50, height: 32, kind: .castle, seed: 9007,
                      portals: [RpgMaps.p(1, 16, m6, 45, 15, minLevel: 64), RpgMaps.p(25, 1, b2, 14, 17, minLevel: 69)],
                      monsters: RpgMaps.sp([("haunted_armor", 4), ("haunted_bats", 6), ("haunted_butler", 6)]),
                      theme: RpgTheme(tint: tint(0.55, 0.2, 0.6), tintAlpha: 0.55, blend: .overlay, darkness: 0.6),
                      waypoint: true),
            RpgMapDef(id: b2, name: "핏빛 무도회장", levelText: "보스 Lv74", width: 28, height: 22, kind: .boss, seed: 9009,
                      portals: [RpgMaps.p(14, 20, m7, 25, 4, minLevel: 67)], monsters: RpgMaps.sp([("haunted_countess", 1)]), zone: .castle,
                      theme: RpgTheme(tint: tint(0.85, 0.1, 0.2), tintAlpha: 0.45)),
        ],
        monsters: [
            RpgMonsters.m("haunted_crow", "까악 까마귀떼", "haunted_crow", 45, 1900, 170, 42, 62, 900, 160...240, .swarm,
                          [("hp3", 0.1), ("haunted_ecto", 0.05), ("stone", 0.08)]),
            RpgMonsters.m("haunted_scarecrow", "허수아비 파수꾼", "haunted_scarecrow", 46, 5850, 255, 85, 36, 2100, 365...535, .aggressive,
                          [("hp3", 0.06), ("haunted_ecto", 0.07), ("haunted_candy", 0.03), ("sword7", 0.004), ("bow7", 0.004), ("armor6", 0.004), ("stone", 0.17)]),
            RpgMonsters.m("haunted_pumpkin", "도깨비 호박", "haunted_pumpkin", 48, 4200, 350, 51, 44, 2600, 375...550, .exploder,
                          [("hp3", 0.1), ("haunted_ecto", 0.06), ("haunted_candy", 0.05), ("stone", 0.08)]),
            RpgMonsters.m("haunted_zombie", "밭갈이 좀비", "haunted_zombie", 49, 7600, 280, 97, 28, 2450, 425...615, .aggressive,
                          [("hp3", 0.08), ("haunted_ecto", 0.07), ("mace7", 0.004), ("claw7", 0.004), ("armor6", 0.004), ("helmet6", 0.003), ("stone", 0.185)]),
            RpgMonsters.m("haunted_ghost", "훌쩍 유령", "haunted_ghost", 52, 6850, 285, 75, 59, 2800, 450...665, .flyer,
                          [("hp3", 0.05), ("mp1", 0.08), ("haunted_ecto", 0.08), ("haunted_tea", 0.03), ("staff7", 0.004), ("dagger7", 0.004), ("ring6", 0.003),
                           ("stone", 0.2)]),
            RpgMonsters.m("haunted_cat", "행운의 검은 고양이", "haunted_cat", 53, 7100, 0, 103, 46, 4400, 2500...3650, .coward,
                          [("hp3", 0.3), ("haunted_ecto", 0.3), ("haunted_heart", 0.08), ("haunted_charm", 0.1), ("stone", 0.3)]),
            RpgMonsters.m("haunted_wisp", "촛농 도깨비불", "haunted_wisp", 55, 8000, 325, 83, 36, 3300, 540...780, .ranged,
                          [("mp1", 0.1), ("hp3", 0.04), ("haunted_ecto", 0.06), ("haunted_thread", 0.03), ("haunted_tea", 0.04), ("staff7", 0.004), ("rod7", 0.004),
                           ("amulet6", 0.003), ("book_c_ult", 0.002), ("book_s_ult", 0.002), ("stone", 0.215)]),
            RpgMonsters.m("haunted_doll", "저주 인형", "haunted_doll", 57, 13100, 355, 120, 38, 4650, 700...1000, .charger,
                          [("hp3", 0.1), ("haunted_thread", 0.06), ("dagger7", 0.004), ("rod7", 0.004), ("stone", 0.085)]),
            RpgMonsters.m("haunted_ghoul", "무덤 파는 구울", "haunted_ghoul", 59, 11950, 355, 124, 38, 3950, 665...955, .aggressive,
                          [("hp3", 0.08), ("mp1", 0.06), ("haunted_thread", 0.06), ("sword9", 0.004), ("mace9", 0.004), ("armor8", 0.004), ("helmet8", 0.004),
                           ("book_w_ult", 0.002), ("book_r_ult", 0.002), ("stone", 0.222)]),
            RpgMonsters.m("haunted_banshee", "곡소리 밴시", "haunted_banshee", 61, 11350, 380, 95, 36, 4500, 735...1050, .ranged,
                          [("mp1", 0.08), ("hp3", 0.08), ("haunted_thread", 0.06), ("haunted_tea", 0.04), ("staff9", 0.004), ("bow9", 0.004), ("armor8", 0.004),
                           ("amulet8", 0.004), ("stone", 0.226)]),
            RpgMonsters.m("haunted_witch", "빗자루 마녀", "haunted_witch", 63, 13200, 355, 99, 58, 4700, 770...1100, .flyer,
                          [("hp3", 0.08), ("mp1", 0.08), ("haunted_thread", 0.06), ("haunted_charm", 0.02), ("rod9", 0.004), ("staff9", 0.004), ("armor8", 0.004),
                           ("ring8", 0.004), ("stone", 0.23)]),
            RpgMonsters.m("haunted_toad", "부글 두꺼비", "haunted_toad", 64, 7850, 500, 71, 47, 5400, 770...1150, .exploder,
                          [("hp3", 0.1), ("haunted_thread", 0.05), ("stone", 0.132)]),
            RpgMonsters.m("haunted_armor", "떠도는 갑옷", "haunted_armor", 66, 18150, 420, 150, 41, 6850, 1100...1550, .charger,
                          [("hp3", 0.1), ("haunted_thread", 0.06), ("sword9", 0.004), ("claw9", 0.004), ("armor8", 0.004), ("boots8", 0.004), ("stone", 0.136)]),
            RpgMonsters.m("haunted_bats", "흡혈 박쥐떼", "haunted_bats", 69, 7650, 270, 63, 62, 3400, 510...730, .swarm,
                          [("hp3", 0.1), ("mp2", 0.04), ("haunted_thread", 0.05), ("stone", 0.142)]),
            RpgMonsters.m("haunted_butler", "유령 집사", "haunted_butler", 70, 15800, 455, 111, 35, 6500, 1050...1500, .ranged,
                          [("hp3", 0.08), ("mp2", 0.08), ("haunted_thread", 0.07), ("haunted_candy", 0.04), ("dagger10", 0.004), ("mace10", 0.004), ("armor9", 0.004),
                           ("ring9", 0.004), ("stone", 0.244)]),
            RpgMonsters.boss("haunted_bellringer", "종지기 거한 콰지모", "haunted_bellringer", 64, 1_155_000, 570, 133, 38, 141_000, 37500...63000, .golem,
                             minion: "haunted_zombie", element: .holy,
                             [("haunted_mace", 0.15), ("haunted_helmet", 0.2), ("haunted_boots", 0.2), ("haunted_heart", 1), ("haunted_heart", 0.5),
                              ("haunted_thread", 1), ("haunted_thread", 1), ("haunted_thread", 0.5),
                              ("sword9", 0.1), ("bow9", 0.1), ("staff9", 0.1), ("dagger9", 0.1), ("mace9", 0.1), ("claw9", 0.1), ("rod9", 0.1),
                              ("sword8", 0.05), ("bow8", 0.05), ("staff8", 0.05), ("dagger8", 0.05), ("mace8", 0.05), ("claw8", 0.05), ("rod8", 0.05),
                              ("armor8", 0.2), ("armor7", 0.1), ("ring8", 0.07), ("amulet8", 0.07), ("helmet8", 0.07), ("boots8", 0.07), ("hp3", 1)]),
            RpgMonsters.boss("haunted_countess", "피의 백작부인 엘리자", "haunted_countess", 74, 1_505_000, 700, 171, 36, 304_000, 56000...93000, .demon,
                             minion: "haunted_bats", element: .poison,
                             [("haunted_ring", 0.25), ("haunted_amulet", 0.2), ("haunted_broom", 0.15), ("haunted_heart", 1), ("haunted_heart", 1),
                              ("haunted_heart", 0.5),
                              ("sword10", 0.12), ("bow10", 0.12), ("staff10", 0.12), ("dagger10", 0.12), ("mace10", 0.12), ("claw10", 0.12), ("rod10", 0.12),
                              ("sword9", 0.1), ("bow9", 0.1), ("staff9", 0.1), ("dagger9", 0.1), ("mace9", 0.1), ("claw9", 0.1), ("rod9", 0.1),
                              ("armor9", 0.2), ("armor8", 0.2), ("ring9", 0.08), ("amulet9", 0.08), ("helmet9", 0.08), ("boots9", 0.08), ("hp4", 1)]),
        ],
        items: [
            RpgItem(id: "haunted_ecto", name: "엑토플라즘", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 3000, element: .base, inShop: false),
            RpgItem(id: "haunted_thread", name: "저주받은 실타래", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 6600, element: .base, inShop: false),
            RpgItem(id: "haunted_heart", name: "식지 않는 심장", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 16500, element: .base, inShop: false),
            RpgItem(id: "haunted_candy", name: "호박 사탕", kind: .potionHP, rarity: 2, attack: 0, defense: 0, heal: 3000, price: 1950, element: .base, inShop: false),
            RpgItem(id: "haunted_tea", name: "마녀의 허브차", kind: .potionMP, rarity: 2, attack: 0, defense: 0, heal: 450, price: 590, element: .base, inShop: false),
            RpgItem(id: "haunted_charm", name: "까마귀 깃털 부적", kind: .buff("luck"), rarity: 2, attack: 0, defense: 0, heal: 0, price: 1200, element: .base, inShop: false),
            // 별빛 투구 (1800 / 56): HP over defense.
            RpgItem(id: "haunted_helmet", name: "호박 투구", kind: .helmet, rarity: 3, attack: 0, defense: 34, heal: 0, price: 240_000, element: .base, inShop: false,
                    bonusHP: 2500),
            // 별빛 장화 (10% / 40): speed over defense.
            RpgItem(id: "haunted_boots", name: "유령 걸음 장화", kind: .boots, rarity: 3, attack: 0, defense: 28, heal: 0, price: 240_000, element: .base, inShop: false,
                    bonusSpeed: 0.13),
            // 천공의 반지 (1900 / 13% / 32%): crit over HP.
            RpgItem(id: "haunted_ring", name: "까마귀 눈 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 400_000, element: .base, inShop: false,
                    bonusHP: 1300, bonusCrit: 0.17, bonusAttack: 0.32),
            // 천공의 목걸이 (3100 / 600 / 95): HP over MP.
            RpgItem(id: "haunted_amulet", name: "유령 로켓 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 93, heal: 0, price: 400_000, element: .base, inShop: false,
                    bonusHP: 4100, bonusMP: 420),
            RpgItem(id: "haunted_mace", name: "종지기의 종망치", kind: .weapon(.cleric), rarity: 3, attack: 170, defense: 0, heal: 0, price: 190_000, element: .thunder, inShop: false),
            RpgItem(id: "haunted_broom", name: "마녀의 빗자루", kind: .weapon(.summoner), rarity: 3, attack: 205, defense: 0, heal: 0, price: 300_000, element: .poison, inShop: false),
        ],
        recipes: [
            RpgRecipe(id: "haunted_helmet", output: "haunted_helmet", count: 1, materials: ["haunted_ecto": 12, "haunted_thread": 9, "stone": 10], gold: 180_000),
            RpgRecipe(id: "haunted_boots", output: "haunted_boots", count: 1, materials: ["haunted_ecto": 11, "haunted_thread": 9, "stone": 10], gold: 180_000),
            RpgRecipe(id: "haunted_ring", output: "haunted_ring", count: 1, materials: ["haunted_thread": 16, "haunted_heart": 2, "stone": 20], gold: 400_000),
            RpgRecipe(id: "haunted_amulet", output: "haunted_amulet", count: 1, materials: ["haunted_thread": 16, "haunted_heart": 2, "stone": 20], gold: 380_000),
            RpgRecipe(id: "haunted_mace", output: "haunted_mace", count: 1, materials: ["haunted_thread": 16, "haunted_heart": 3, "stone": 20], gold: 200_000),
            RpgRecipe(id: "haunted_broom", output: "haunted_broom", count: 1, materials: ["haunted_thread": 18, "haunted_heart": 4, "stone": 30], gold: 320_000),
            RpgRecipe(id: "haunted_candy", output: "haunted_candy", count: 3, materials: ["haunted_ecto": 2], gold: 1500),
            RpgRecipe(id: "haunted_charm", output: "haunted_charm", count: 2, materials: ["haunted_ecto": 2, "haunted_thread": 1], gold: 600),
        ]
    )
}

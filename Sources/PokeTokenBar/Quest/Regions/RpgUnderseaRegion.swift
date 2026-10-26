import CoreGraphics
import Foundation

// 해저 신전 (Lv40-66, bosses Lv60 / Lv68). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.
//
// Balance: every normal monster is interpolated (log-linear in level) between the existing monsters of the same behaviour, e.g.
//   melee    L42 암흑 기사 5200/230/80 xp1700 · L48 뼈 군주 6200/270/88 xp2300 · L64 산호 게 16100/405/145 xp5050
//   heavy    L52 지하묘지 수호상 10000/310/110 xp3000 · L79 용인 수호병 34000/560/245 xp12150
//   ranged   L45 그림자 마법사/망령 ~4500/252/67 xp1950 · L62 바람 정령 12000/390/97 xp4750 · L67 사이렌 14350/430/105 xp5650
//   flyer    L44 악마 박쥐 4000/240/60 xp1800 · L60 천공 매 11800/335/93 xp4350
//   swarm    L45 굶주린 구울떼 1924/168/42 xp925 · L47 원혼떼 · L65 심연 피라냐떼 6700/250/59 xp2900
//   charger  L49 뼈 투우 9750/301/96 xp3300 · L64 뇌운 산양 16950/405/145 xp6300
//   exploder L35 폭발 해골 · L47 영혼 폭탄 3849/336/51 xp2405 · L73 저주 폭탄 10900/600/85 xp7900
//   passive  L30 용암 슬라임 1900/130/42 · L58 구름 슬라임 10300/285/115 xp3800
//   coward   황금 슬라임-style treasure on the melee curve: ~0.85x HP, no attack, 1.5x XP, 5x gold (half its ratio: these roam ordinary maps)
//   bosses   L58 마왕 975k/500/110 xp90k · L70 심해의 크라켄 1.37M/650/160 xp220k (the existing ~70x-normal boss curve)
// Gear: ring/helmet/boots on the tier-6 budget, amulet on tier 7, weapons on tier 9 (same sum of stats, a different spread).

enum RpgUnderseaRegion {
    private static let m1 = RpgMapID("undersea_1"), m2 = RpgMapID("undersea_2"), m3 = RpgMapID("undersea_3"), m4 = RpgMapID("undersea_4")
    private static let m5 = RpgMapID("undersea_5"), m6 = RpgMapID("undersea_6"), m7 = RpgMapID("undersea_7")
    private static let b1 = RpgMapID("undersea_b1"), b2 = RpgMapID("undersea_b2")
    private static func tint(_ r: Double, _ g: Double, _ b: Double) -> RpgTheme.RGB { RpgTheme.RGB(r: r, g: g, b: b) }

    static let region = RpgRegion(
        id: "undersea", name: "해저 신전", blurb: "가라앉은 산호 신전, 바다뱀 여제가 진주를 지키는 바다 밑",
        minLevel: 38, entry: m1, entryTile: RpgTile(x: 4, y: 15),
        maps: [
            RpgMapDef(id: m1, name: "산호초 여울", levelText: "Lv40~45", width: 50, height: 30, kind: .desert, seed: 8001,
                      portals: [RpgMaps.p(1, 15, .town, 4, 11), RpgMaps.p(48, 15, m2, 4, 15, minLevel: 44)],
                      monsters: RpgMaps.sp([("undersea_shellslime", 8), ("undersea_puffer", 4), ("undersea_seahorse", 5), ("undersea_starfish", 6)]),
                      theme: RpgTheme(floor: .sand, obstacle: .tree, pool: .water, decor: .dune, tint: tint(0.2, 0.7, 0.85), tintAlpha: 0.45),
                      waypoint: true),
            RpgMapDef(id: m2, name: "물결 해초숲", levelText: "Lv44~49", width: 48, height: 30, kind: .forest, seed: 8002,
                      portals: [RpgMaps.p(1, 15, m1, 45, 15, minLevel: 38), RpgMaps.p(46, 15, m3, 4, 15, minLevel: 48)],
                      monsters: RpgMaps.sp([("undersea_seahorse", 4), ("undersea_starfish", 6), ("undersea_merman", 7), ("undersea_puffer", 3)]),
                      theme: RpgTheme(floor: .darkGrass, obstacle: .tree, pool: .water, decor: .flower, tint: tint(0.15, 0.6, 0.75), tintAlpha: 0.5)),
            RpgMapDef(id: m3, name: "진주 모래톱", levelText: "Lv48~53", width: 50, height: 30, kind: .desert, seed: 8003,
                      portals: [RpgMaps.p(1, 15, m2, 43, 15, minLevel: 44), RpgMaps.p(48, 15, m4, 4, 16, minLevel: 52)],
                      monsters: RpgMaps.sp([("undersea_merman", 6), ("undersea_clam", 2), ("undersea_eel", 6), ("undersea_angler", 4)]),
                      theme: RpgTheme(floor: .sand, obstacle: .rock, pool: .water, decor: .dune, tint: tint(0.3, 0.6, 0.9), tintAlpha: 0.5),
                      waypoint: true),
            RpgMapDef(id: m4, name: "가라앉은 열주랑", levelText: "Lv52~57", width: 50, height: 32, kind: .castle, seed: 8004,
                      portals: [RpgMaps.p(1, 16, m3, 45, 15, minLevel: 48), RpgMaps.p(48, 16, m5, 4, 15, minLevel: 56),
                                RpgMaps.p(25, 1, b1, 14, 17, minLevel: 55)],
                      monsters: RpgMaps.sp([("undersea_eel", 4), ("undersea_angler", 5), ("undersea_mermage", 6), ("undersea_turtle", 4)]),
                      theme: RpgTheme(tint: tint(0.2, 0.75, 0.8), tintAlpha: 0.45, darkness: 0.35)),
            RpgMapDef(id: b1, name: "거북 등 요새", levelText: "보스 Lv60", width: 28, height: 22, kind: .boss, seed: 8008,
                      portals: [RpgMaps.p(14, 20, m4, 25, 4, minLevel: 52)], monsters: RpgMaps.sp([("undersea_tortuga", 1)]), zone: .cave,
                      theme: RpgTheme(tint: tint(0.25, 0.7, 0.6), tintAlpha: 0.45)),
            RpgMapDef(id: m5, name: "반딧불 해구", levelText: "Lv56~61", width: 50, height: 30, kind: .cave, seed: 8005,
                      portals: [RpgMaps.p(1, 15, m4, 45, 16, minLevel: 52), RpgMaps.p(48, 15, m6, 4, 16, minLevel: 59)],
                      monsters: RpgMaps.sp([("undersea_mermage", 5), ("undersea_turtle", 4), ("undersea_ray", 6), ("undersea_urchin", 3)]),
                      theme: RpgTheme(tint: tint(0.1, 0.5, 0.8), tintAlpha: 0.6, darkness: 0.68),
                      waypoint: true),
            RpgMapDef(id: m6, name: "산호 신전 본당", levelText: "Lv59~64", width: 50, height: 32, kind: .castle, seed: 8006,
                      portals: [RpgMaps.p(1, 16, m5, 45, 15, minLevel: 56), RpgMaps.p(48, 16, m7, 4, 15, minLevel: 62)],
                      monsters: RpgMaps.sp([("undersea_ray", 5), ("undersea_urchin", 3), ("undersea_shark", 4), ("undersea_squid", 5)]),
                      theme: RpgTheme(tint: tint(1.0, 0.45, 0.5), tintAlpha: 0.45, blend: .overlay, darkness: 0.45)),
            RpgMapDef(id: m7, name: "소용돌이 미궁", levelText: "Lv62~66", width: 48, height: 30, kind: .cave, seed: 8007,
                      portals: [RpgMaps.p(1, 15, m6, 45, 16, minLevel: 59), RpgMaps.p(24, 1, b2, 14, 17, minLevel: 63)],
                      monsters: RpgMaps.sp([("undersea_shark", 4), ("undersea_squid", 6), ("undersea_urchin", 3)]),
                      theme: RpgTheme(tint: tint(0.1, 0.4, 0.9), tintAlpha: 0.55, blend: .overlay, darkness: 0.86),
                      waypoint: true),
            RpgMapDef(id: b2, name: "여제의 산호 옥좌", levelText: "보스 Lv68", width: 28, height: 22, kind: .boss, seed: 8009,
                      portals: [RpgMaps.p(14, 20, m7, 24, 4, minLevel: 62)], monsters: RpgMaps.sp([("undersea_naga", 1)]), zone: .castle,
                      theme: RpgTheme(tint: tint(0.55, 0.25, 0.75), tintAlpha: 0.5, blend: .overlay)),
        ],
        monsters: [
            RpgMonsters.m("undersea_shellslime", "소라껍질 슬라임", "undersea_shellslime", 40, 3450, 170, 60, 33, 1300, 225...335, .passive,
                          [("hp3", 0.05), ("mp1", 0.06), ("undersea_scale", 0.06), ("sword7", 0.004), ("mace7", 0.004), ("armor6", 0.004), ("stone", 0.14)]),
            RpgMonsters.m("undersea_puffer", "빵빵 복어", "undersea_puffer", 43, 2900, 285, 42, 46, 1900, 275...415, .exploder,
                          [("hp3", 0.1), ("undersea_scale", 0.06), ("stone", 0.075)]),
            RpgMonsters.m("undersea_seahorse", "해마 창기병", "undersea_seahorse", 44, 6700, 245, 80, 40, 2300, 345...520, .charger,
                          [("hp3", 0.1), ("undersea_scale", 0.06), ("undersea_song", 0.03), ("bow7", 0.004), ("dagger7", 0.004), ("stone", 0.078)]),
            RpgMonsters.m("undersea_starfish", "별사탕 불가사리떼", "undersea_starfish", 46, 2100, 175, 43, 60, 1000, 170...250, .swarm,
                          [("hp3", 0.1), ("undersea_scale", 0.05), ("stone", 0.08)]),
            RpgMonsters.m("undersea_merman", "인어 창병", "undersea_merman", 47, 6000, 265, 87, 35, 2200, 380...555, .aggressive,
                          [("hp3", 0.06), ("undersea_scale", 0.07), ("undersea_soup", 0.03), ("sword7", 0.004), ("claw7", 0.004), ("armor6", 0.004), ("stone", 0.17)]),
            RpgMonsters.m("undersea_clam", "진주 품은 대합", "undersea_clam", 50, 5950, 0, 94, 46, 3800, 2200...3200, .coward,
                          [("hp3", 0.3), ("undersea_scale", 0.3), ("undersea_pearl", 0.08), ("undersea_song", 0.1), ("stone", 0.3)]),
            RpgMonsters.m("undersea_eel", "찌릿 뱀장어", "undersea_eel", 51, 6350, 295, 76, 37, 2650, 440...645, .ranged,
                          [("mp1", 0.1), ("hp3", 0.04), ("undersea_scale", 0.07), ("undersea_bubble", 0.03), ("staff7", 0.004), ("rod7", 0.004), ("stone", 0.19)]),
            RpgMonsters.m("undersea_angler", "초롱 아귀", "undersea_angler", 54, 7850, 295, 79, 59, 3100, 500...730, .flyer,
                          [("hp3", 0.06), ("mp1", 0.06), ("undersea_scale", 0.06), ("undersea_coral", 0.03), ("bow7", 0.004), ("mace7", 0.004), ("ring6", 0.003), ("stone", 0.2)]),
            RpgMonsters.m("undersea_mermage", "인어 주술사", "undersea_mermage", 55, 8000, 325, 83, 36, 3300, 540...780, .ranged,
                          [("mp1", 0.1), ("hp3", 0.05), ("undersea_coral", 0.05), ("undersea_bubble", 0.04), ("staff7", 0.004), ("rod7", 0.004), ("amulet6", 0.003),
                           ("book_m_ult", 0.002), ("book_s_ult", 0.002), ("stone", 0.2)]),
            RpgMonsters.m("undersea_turtle", "따개비 거북", "undersea_turtle", 57, 12550, 345, 128, 26, 3900, 625...905, .aggressive,
                          [("hp3", 0.08), ("undersea_coral", 0.06), ("undersea_soup", 0.04), ("sword7", 0.004), ("claw7", 0.004), ("armor6", 0.004), ("helmet6", 0.003),
                           ("book_w_ult", 0.002), ("book_k_ult", 0.002), ("stone", 0.24)]),
            RpgMonsters.m("undersea_ray", "그림자 가오리", "undersea_ray", 59, 11050, 330, 90, 58, 4100, 645...935, .flyer,
                          [("hp3", 0.08), ("mp1", 0.08), ("undersea_coral", 0.06), ("bow9", 0.004), ("dagger9", 0.004), ("armor8", 0.004), ("boots8", 0.004), ("stone", 0.222)]),
            RpgMonsters.m("undersea_urchin", "성게 기뢰", "undersea_urchin", 61, 7050, 470, 66, 46, 4750, 675...985, .exploder,
                          [("hp3", 0.1), ("undersea_coral", 0.05), ("stone", 0.126)]),
            RpgMonsters.m("undersea_shark", "톱날 상어", "undersea_shark", 63, 16350, 395, 141, 40, 6050, 950...1400, .charger,
                          [("hp3", 0.1), ("undersea_coral", 0.06), ("sword9", 0.004), ("claw9", 0.004), ("armor8", 0.004), ("ring8", 0.004), ("stone", 0.13)]),
            RpgMonsters.m("undersea_squid", "먹물 대왕오징어", "undersea_squid", 65, 13350, 415, 102, 35, 5250, 875...1250, .ranged,
                          [("hp3", 0.08), ("mp1", 0.08), ("undersea_coral", 0.06), ("undersea_bubble", 0.04), ("staff9", 0.004), ("rod9", 0.004), ("armor8", 0.004),
                           ("amulet8", 0.004), ("stone", 0.234)]),
            RpgMonsters.boss("undersea_tortuga", "요새거북 투르가", "undersea_tortuga", 60, 1_030_000, 520, 117, 39, 104_000, 32500...54000, .yeti,
                             minion: "undersea_starfish", element: .ice,
                             [("undersea_ring", 0.25), ("undersea_helmet", 0.2), ("undersea_boots", 0.2), ("undersea_pearl", 1), ("undersea_pearl", 0.5),
                              ("undersea_coral", 1), ("undersea_coral", 1), ("undersea_coral", 0.5),
                              ("sword9", 0.08), ("bow9", 0.08), ("staff9", 0.08), ("dagger9", 0.08), ("mace9", 0.08), ("claw9", 0.08), ("rod9", 0.08),
                              ("sword8", 0.06), ("bow8", 0.06), ("staff8", 0.06), ("dagger8", 0.06), ("mace8", 0.06), ("claw8", 0.06), ("rod8", 0.06),
                              ("armor8", 0.15), ("armor7", 0.1), ("ring8", 0.06), ("amulet8", 0.06), ("helmet8", 0.06), ("boots8", 0.06), ("hp3", 1)]),
            RpgMonsters.boss("undersea_naga", "바다뱀 여제 나가라", "undersea_naga", 68, 1_295_000, 620, 150, 37, 190_000, 44000...73000, .skeleton,
                             minion: "undersea_ray", element: .thunder,
                             [("undersea_amulet", 0.25), ("undersea_trident", 0.15), ("undersea_staff", 0.15), ("undersea_pearl", 1), ("undersea_pearl", 1),
                              ("undersea_pearl", 0.5),
                              ("sword10", 0.1), ("bow10", 0.1), ("staff10", 0.1), ("dagger10", 0.1), ("mace10", 0.1), ("claw10", 0.1), ("rod10", 0.1),
                              ("sword9", 0.1), ("bow9", 0.1), ("staff9", 0.1), ("dagger9", 0.1), ("mace9", 0.1), ("claw9", 0.1), ("rod9", 0.1),
                              ("armor9", 0.18), ("armor8", 0.2), ("ring9", 0.07), ("amulet9", 0.07), ("helmet9", 0.07), ("boots9", 0.07), ("hp3", 1)]),
        ],
        items: [
            RpgItem(id: "undersea_scale", name: "인어 비늘", kind: .material, rarity: 2, attack: 0, defense: 0, heal: 0, price: 2400, element: .base, inShop: false),
            RpgItem(id: "undersea_coral", name: "청산호 가지", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 6000, element: .base, inShop: false),
            RpgItem(id: "undersea_pearl", name: "용궁 흑진주", kind: .material, rarity: 4, attack: 0, defense: 0, heal: 0, price: 15000, element: .base, inShop: false),
            RpgItem(id: "undersea_soup", name: "해초 수프", kind: .potionHP, rarity: 2, attack: 0, defense: 0, heal: 2500, price: 1600, element: .base, inShop: false),
            RpgItem(id: "undersea_bubble", name: "공기방울 물약", kind: .potionMP, rarity: 2, attack: 0, defense: 0, heal: 400, price: 520, element: .base, inShop: false),
            RpgItem(id: "undersea_song", name: "인어의 노래 소라", kind: .buff("speed"), rarity: 1, attack: 0, defense: 0, heal: 0, price: 400, element: .base, inShop: false),
            // 마왕의 반지 (950 / 10% / 22%): less HP, more crit and attack.
            RpgItem(id: "undersea_ring", name: "해신의 소라 반지", kind: .ring, rarity: 3, attack: 0, defense: 0, heal: 0, price: 120_000, element: .base, inShop: false,
                    bonusHP: 550, bonusCrit: 0.13, bonusAttack: 0.24),
            // 마왕의 투구 (1200 / 38): defense over HP.
            RpgItem(id: "undersea_helmet", name: "산호 왕관 투구", kind: .helmet, rarity: 3, attack: 0, defense: 49, heal: 0, price: 115_000, element: .base, inShop: false,
                    bonusHP: 840),
            // 마왕의 장화 (8% / 26): speed over defense.
            RpgItem(id: "undersea_boots", name: "인어 지느러미 장화", kind: .boots, rarity: 3, attack: 0, defense: 16, heal: 0, price: 115_000, element: .base, inShop: false,
                    bonusSpeed: 0.11),
            // 별빛 목걸이 (2400 / 480 / 75): MP over HP and defense.
            RpgItem(id: "undersea_amulet", name: "해신의 진주 목걸이", kind: .amulet, rarity: 3, attack: 0, defense: 44, heal: 0, price: 250_000, element: .base, inShop: false,
                    bonusHP: 1700, bonusMP: 820),
            // Tier-9 attack (170) with another element.
            RpgItem(id: "undersea_trident", name: "해신의 삼지창", kind: .weapon(.warrior), rarity: 3, attack: 170, defense: 0, heal: 0, price: 190_000, element: .thunder, inShop: false),
            RpgItem(id: "undersea_staff", name: "물결 주술 지팡이", kind: .weapon(.mage), rarity: 3, attack: 170, defense: 0, heal: 0, price: 190_000, element: .ice, inShop: false),
        ],
        recipes: [
            RpgRecipe(id: "undersea_ring", output: "undersea_ring", count: 1, materials: ["undersea_scale": 12, "undersea_coral": 8], gold: 90000),
            RpgRecipe(id: "undersea_helmet", output: "undersea_helmet", count: 1, materials: ["undersea_scale": 11, "undersea_coral": 7], gold: 80000),
            RpgRecipe(id: "undersea_boots", output: "undersea_boots", count: 1, materials: ["undersea_scale": 10, "undersea_coral": 8], gold: 80000),
            RpgRecipe(id: "undersea_amulet", output: "undersea_amulet", count: 1, materials: ["undersea_coral": 15, "undersea_pearl": 2, "stone": 20], gold: 190_000),
            RpgRecipe(id: "undersea_trident", output: "undersea_trident", count: 1, materials: ["undersea_coral": 16, "undersea_pearl": 3, "stone": 20], gold: 200_000),
            RpgRecipe(id: "undersea_staff", output: "undersea_staff", count: 1, materials: ["undersea_coral": 16, "undersea_pearl": 3, "stone": 20], gold: 200_000),
            RpgRecipe(id: "undersea_soup", output: "undersea_soup", count: 3, materials: ["undersea_scale": 2], gold: 1200),
            RpgRecipe(id: "undersea_song", output: "undersea_song", count: 3, materials: ["undersea_scale": 2], gold: 300),
        ]
    )
}

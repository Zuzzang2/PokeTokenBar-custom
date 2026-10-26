import Foundation

// SPIKE: "픽셀 모험" — a real-time action RPG drawn entirely in code. This file is the static game
// data: classes and their 24 skills, items (gear in five rarities, skill books, enhancement stones),
// monsters per zone with bosses, the town's places and the fifteen maps joined by portals. Everything
// is a plain Sendable value so a lobby host can later run the same world for nearby players.

enum RpgClass: String, Codable, CaseIterable, Sendable {
    case warrior, archer, mage, rogue, cleric, monk, summoner

    private var index: Int { Self.allCases.firstIndex(of: self)! }
    var name: String { ["전사", "궁수", "마법사", "도적", "성직자", "격투가", "소환사"][index] }
    var blurb: String {
        switch self {
        case .warrior: return "튼튼한 몸과 검으로 앞에서 싸워요. 버프와 광역기가 강해요."
        case .archer: return "멀리서 활을 쏴요. 치명타와 연사, 덫과 독화살."
        case .mage: return "몸은 약하지만 강력한 원소 마법과 순간이동, 치유."
        case .rogue: return "빠르게 파고들어 베는 근접 직업. 치명타, 독, 은신과 암살."
        case .cleric: return "신성한 빛으로 적을 태우고 동료를 치유하고 지켜요."
        case .monk: return "맨손 연타와 기공의 달인. 빠른 공격과 단단한 몸."
        case .summoner: return "정령과 소환수를 불러 싸워요. 저주와 생명 흡수, 대악마 강림."
        }
    }
    var baseHP: Int { [130, 95, 80, 100, 110, 125, 85][index] }
    var hpPerLevel: Int { [22, 15, 12, 16, 18, 20, 13][index] }
    var baseMP: Int { [30, 40, 70, 35, 60, 40, 65][index] }
    var mpPerLevel: Int { [4, 5, 8, 4, 7, 5, 7][index] }
    var baseAttack: Int { [11, 10, 12, 11, 9, 10, 11][index] }
    var attackPerLevel: Double { [3.2, 3.2, 3.6, 3.4, 2.8, 3.2, 3.6][index] }
    var baseDefense: Int { [6, 4, 3, 4, 5, 5, 3][index] }
    var defensePerLevel: Double { [2.2, 1.4, 1.1, 1.4, 1.8, 1.9, 1.1][index] }
    var speed: Double { [72, 80, 68, 90, 70, 82, 70][index] }
    var attackInterval: Double { [0.42, 0.5, 0.6, 0.32, 0.55, 0.30, 0.65][index] }
    var critChance: Double { [0.08, 0.16, 0.08, 0.22, 0.06, 0.10, 0.07][index] }
    /// Item id prefix of this class's weapons ("sword" -> sword0...sword8).
    var weaponPrefix: String { ["sword", "bow", "staff", "dagger", "mace", "claw", "rod"][index] }
    var starterWeapon: String { weaponPrefix + "0" }
    var skills: [RpgSkillDef] { RpgSkills.all.filter { $0.cls == self } }
}

enum RpgElement: String, Codable, Sendable {
    case base, fire, ice, thunder, wind, holy, cosmic, poison

    var effectName: String {
        switch self {
        case .base: return ""
        case .fire: return "화상"
        case .ice: return "둔화"
        case .thunder: return "감전"
        case .wind: return "공속 증가"
        case .holy: return "범위 피해"
        case .cosmic: return "메테오"
        case .poison: return "중독"
        }
    }
}

// MARK: skills

struct RpgSkillDef: Sendable {
    let id: String
    let name: String
    let cls: RpgClass
    let minLevel: Int
    let mp: Int
    let cooldown: Double
    /// Damage multiplier at skill level 1 (0 for buffs); +12% per extra level.
    let power: Double
    let maxLevel: Int
    /// Skill-book price in the 마법서점; 0 means the book only drops.
    let price: Int
    let starter: Bool
    let desc: String

    var isUltimate: Bool { maxLevel == 5 }
}

enum RpgSkills {
    private static func s(_ id: String, _ name: String, _ cls: RpgClass, _ lv: Int, _ mp: Int, _ cd: Double, _ power: Double,
                          price: Int = 0, starter: Bool = false, max: Int = 10, _ desc: String) -> RpgSkillDef {
        RpgSkillDef(id: id, name: name, cls: cls, minLevel: lv, mp: mp, cooldown: cd, power: power, maxLevel: max, price: price,
                    starter: starter, desc: desc)
    }

    static let all: [RpgSkillDef] = [
        s("w_whirl", "회전베기", .warrior, 1, 10, 4, 1.8, starter: true, "주변의 모든 적을 벤다"),
        s("w_dash", "돌진베기", .warrior, 1, 8, 5, 2.0, starter: true, "앞으로 돌진하며 지나가는 적을 벤다 (무적)"),
        s("w_quake", "대지 가르기", .warrior, 8, 14, 6, 2.2, price: 700, "앞으로 일직선 충격파"),
        s("w_rage", "분노", .warrior, 12, 20, 25, 0, price: 1800, "12초간 공격력 +30% (레벨당 +3%)"),
        s("w_iron", "철벽", .warrior, 16, 20, 25, 0, "10초간 받는 피해 -40%"),
        s("w_cyclone", "회오리검", .warrior, 22, 30, 12, 0.7, "3.5초간 회전하며 계속 벤다 (이동 가능)"),
        s("w_slam", "내려찍기", .warrior, 28, 26, 9, 2.8, "넓은 범위를 내려찍어 기절시킨다"),
        s("w_ult", "천둥 강림", .warrior, 35, 60, 45, 4.0, max: 5, "주변 적들에게 낙뢰 6발 + 기절"),

        s("a_triple", "삼연사", .archer, 1, 10, 3.5, 0.95, starter: true, "화살 3발을 부채꼴로"),
        s("a_pierce", "관통 화살", .archer, 1, 14, 6, 2.6, starter: true, "모든 적을 꿰뚫는 화살"),
        s("a_rain", "화살비", .archer, 8, 18, 7, 0.8, price: 700, "앞쪽에 화살이 6번 쏟아진다"),
        s("a_poison", "독화살", .archer, 12, 14, 5, 1.2, price: 1800, "맞은 적에게 강한 중독"),
        s("a_back", "백스텝 사격", .archer, 16, 16, 7, 0.9, "뒤로 물러나며 화살 5발"),
        s("a_trap", "폭발 덫", .archer, 22, 20, 8, 2.5, "밟으면 터지며 묶는 덫 설치"),
        s("a_focus", "집중", .archer, 28, 24, 25, 0, "12초간 치명타 +40%, 공격속도 +30%"),
        s("a_ult", "폭풍의 화살", .archer, 35, 60, 40, 3.5, max: 5, "거대한 관통 화살 5발"),

        s("m_blast", "원소 폭발", .mage, 1, 16, 4, 2.2, starter: true, "앞쪽 범위 폭발 (무기 속성에 따라 변화)"),
        s("m_chain", "연쇄 마법", .mage, 1, 18, 6, 1.7, starter: true, "적 4마리를 차례로 잇는 마법"),
        s("m_blink", "순간이동", .mage, 8, 14, 6, 1.5, price: 700, "앞으로 순간이동, 떠난 자리 폭발"),
        s("m_shield", "마나 실드", .mage, 12, 20, 25, 0, price: 1800, "15초간 받는 피해 70%를 MP로"),
        s("m_blizzard", "블리자드", .mage, 16, 28, 12, 0.5, "4초간 얼음 장판 (둔화 + 지속 피해)"),
        s("m_pillar", "화염 기둥", .mage, 22, 24, 8, 1.6, "일직선으로 이어지는 불기둥"),
        s("m_heal", "치유", .mage, 28, 30, 14, 0, "HP 30% 회복 (레벨당 +3%)"),
        s("m_ult", "메테오 스톰", .mage, 35, 70, 45, 3.2, max: 5, "주변에 운석 8개 낙하"),

        s("r_flurry", "난도질", .rogue, 1, 8, 3, 0.7, starter: true, "전방을 4번 빠르게 벤다"),
        s("r_step", "그림자 걸음", .rogue, 1, 8, 5, 1.2, starter: true, "앞으로 파고들며 벤다 (무적)"),
        s("r_venom", "독날", .rogue, 8, 14, 6, 1.0, price: 700, "주변에 독을 뿌려 중독시킨다"),
        s("r_smoke", "연막", .rogue, 12, 18, 14, 0.6, price: 1800, "2초간 무적, 주변 적을 둔화"),
        s("r_stab", "급소 찌르기", .rogue, 16, 16, 7, 3.4, "가장 가까운 적의 급소를 찔러 큰 피해"),
        s("r_blades", "비수 난무", .rogue, 22, 22, 8, 0.9, "비수 7발을 부채꼴로 던진다"),
        s("r_vanish", "은신", .rogue, 28, 24, 25, 0, "10초간 몬스터에게 안 보임 (공격하면 풀리고 첫 공격은 치명타) + 치명·공속·이동속도 상승"),
        s("r_ult", "암살", .rogue, 35, 60, 40, 3.2, max: 5, "근처 적들을 차례로 순간 타격"),

        s("c_smite", "성광", .cleric, 1, 10, 3, 1.6, starter: true, "빛줄기를 쏜다 (신성)"),
        s("c_heal", "치유의 빛", .cleric, 1, 14, 6, 0, starter: true, "자신과 주변 동료 HP 25% 회복 (레벨당 +2.5%)"),
        s("c_bless", "축복", .cleric, 8, 18, 20, 0, price: 700, "주변 동료의 공격력을 12초간 올린다"),
        s("c_nova", "성스러운 폭발", .cleric, 12, 22, 9, 1.8, price: 1800, "주변을 폭발시키고 동료를 회복"),
        s("c_ward", "수호 방벽", .cleric, 16, 24, 25, 0, "주변 동료가 10초간 받는 피해 -40%"),
        s("c_judge", "심판", .cleric, 22, 26, 10, 1.1, "적 머리 위에 빛기둥 5발"),
        s("c_purify", "정화", .cleric, 28, 30, 18, 0, "주변 동료 HP 40% 회복 + 6초 피해 감소"),
        s("c_ult", "천상의 심판", .cleric, 35, 70, 45, 3.0, max: 5, "넓은 범위에 빛의 비 + 동료 회복"),

        s("k_punch", "정권", .monk, 1, 8, 3, 0.9, starter: true, "짧게 파고들며 3연타"),
        s("k_spin", "회축", .monk, 1, 10, 5, 1.7, starter: true, "회전하며 주변을 찬다"),
        s("k_palm", "장풍", .monk, 8, 14, 5, 2.0, price: 700, "기를 모아 쏘아 보낸다"),
        s("k_qi", "기공", .monk, 12, 20, 18, 0, price: 1800, "HP 20% 회복 + 12초간 공속 상승"),
        s("k_dragon", "승룡권", .monk, 16, 18, 8, 2.4, "올려쳐 적을 기절시킨다"),
        s("k_barrage", "연환권", .monk, 22, 22, 9, 0.7, "전방을 8번 연타"),
        s("k_iron", "금강불괴", .monk, 28, 24, 25, 0, "10초간 받는 피해 -40% + HP 15% 회복"),
        s("k_ult", "천상 연타", .monk, 35, 60, 40, 3.4, max: 5, "보이지 않는 연타 12번"),

        s("s_orb", "정령탄", .summoner, 1, 10, 3, 1.5, starter: true, "정령이 구슬을 쏜다"),
        s("s_wolf", "늑대 소환", .summoner, 1, 12, 5, 2.0, starter: true, "늑대가 직선으로 달려가 물어뜯는다"),
        s("s_golem", "골렘 소환", .summoner, 8, 18, 8, 0.9, price: 700, "골렘이 4번 내려찍는다"),
        s("s_curse", "저주", .summoner, 12, 20, 10, 0.5, price: 1800, "범위 중독과 둔화"),
        s("s_bats", "박쥐떼", .summoner, 16, 22, 8, 0.8, "박쥐 떼가 주변을 휘감는다"),
        s("s_drain", "생명 흡수", .summoner, 22, 24, 7, 2.2, "피해를 주고 HP를 회복"),
        s("s_dragon", "용 소환", .summoner, 28, 28, 10, 2.6, "용의 숨결이 전방을 쓸어낸다"),
        s("s_ult", "대악마 강림", .summoner, 35, 70, 45, 3.2, max: 5, "대악마가 주변을 폭격한다"),
    ]
    private static let byID: [String: RpgSkillDef] = Dictionary(uniqueKeysWithValues: (all + RpgJobs.skills).map { ($0.id, $0) })
    static func def(_ id: String) -> RpgSkillDef? { byID[id] }
    static func damage(_ s: RpgSkillDef, level: Int) -> Double { s.power * (1 + 0.12 * Double(max(1, level) - 1)) }
}

// MARK: items

enum RpgItemKind: Sendable, Equatable {
    case weapon(RpgClass)
    case armor
    case potionHP
    case potionMP
    case scroll
    case book(String)
    case stone
    case ring
    case amulet
    case helmet
    case boots
    /// Crafting ingredient (dropped by monsters, used at the smith).
    case material
    /// Timed buff; the payload is the `RpgBuffs` id.
    case buff(String)
}

struct RpgItem: Sendable {
    let id: String
    let name: String
    let kind: RpgItemKind
    /// 0 일반, 1 희귀, 2 영웅, 3 전설, 4 신화.
    let rarity: Int
    let attack: Int
    let defense: Int
    let heal: Int
    let price: Int
    let element: RpgElement
    /// Sold in a town shop; the best gear only drops.
    let inShop: Bool
    /// Accessory bonuses: flat HP / MP, crit chance and attack percent (0.1 = +10%).
    var bonusHP = 0
    var bonusMP = 0
    var bonusCrit = 0.0
    var bonusAttack = 0.0
    /// Boots: walking speed (0.05 = +5%).
    var bonusSpeed = 0.0

    var sellPrice: Int { max(1, price / 3) }
    var isEquipment: Bool {
        switch kind {
        case .weapon, .armor, .ring, .amulet, .helmet, .boots: return true
        default: return false
        }
    }
    var tier: Int { Int(id.last.flatMap { Int(String($0)) } ?? 0) }
}

enum RpgItems {
    static let rarityName = ["일반", "희귀", "영웅", "전설", "신화"]

    private static func weapons(_ cls: RpgClass, _ prefix: String, _ names: [String], _ elements: [RpgElement]) -> [RpgItem] {
        let rarity = [0, 1, 2, 2, 2, 3, 2, 3, 4]
        let attack = [3, 9, 18, 17, 17, 32, 52, 84, 130]
        let price = [40, 320, 1400, 1400, 1400, 9000, 14000, 40000, 120000]
        let shop = [true, true, true, true, true, false, true, false, false]
        return names.indices.map { i in
            RpgItem(id: "\(prefix)\(i)", name: names[i], kind: .weapon(cls), rarity: rarity[i], attack: attack[i], defense: 0,
                    heal: 0, price: price[i], element: elements[i], inShop: shop[i])
        }
    }

    static let all: [RpgItem] = {
        var items = weapons(.warrior, "sword", ["나무 검", "강철 검", "화염검", "서리검", "뇌전검", "별빛 성검", "사막의 시미터", "용암 대검", "마왕 토벌검"],
                            [.base, .base, .fire, .ice, .thunder, .holy, .wind, .fire, .holy])
        items += weapons(.archer, "bow", ["나무 활", "강철 활", "불꽃 활", "서리 활", "질풍 활", "천공의 활", "모래폭풍 활", "빙하 장궁", "별을 쏘는 활"],
                         [.base, .base, .fire, .ice, .wind, .holy, .wind, .ice, .cosmic])
        items += weapons(.mage, "staff", ["나무 지팡이", "수정 지팡이", "화염 지팡이", "빙결 지팡이", "뇌운 지팡이", "우주의 지팡이", "빙하의 지팡이", "화산 지팡이", "마왕의 홀"],
                         [.base, .base, .fire, .ice, .thunder, .cosmic, .ice, .fire, .cosmic])
        items += weapons(.rogue, "dagger", ["녹슨 단검", "강철 단검", "독니 단검", "서리 단검", "번개 단검", "그림자 단검", "사막의 쿠크리", "용암 단검", "별을 베는 단검"],
                         [.base, .base, .poison, .ice, .thunder, .cosmic, .wind, .fire, .cosmic])
        items += weapons(.cleric, "mace", ["나무 철퇴", "강철 철퇴", "화염 철퇴", "서리 철퇴", "뇌전 철퇴", "성스러운 철퇴", "사막의 홀", "빙하의 철퇴", "천상의 철퇴"],
                         [.base, .base, .fire, .ice, .thunder, .holy, .wind, .ice, .holy])
        items += weapons(.monk, "claw", ["가죽 권갑", "강철 권갑", "화염 권갑", "서리 권갑", "뇌전 권갑", "기공 권갑", "모래폭풍 권갑", "용암 권갑", "용왕의 권갑"],
                         [.base, .base, .fire, .ice, .thunder, .holy, .wind, .fire, .cosmic])
        items += weapons(.summoner, "rod", ["나무 소환봉", "뼈 소환봉", "화염 소환봉", "서리 소환봉", "뇌운 소환봉", "영혼의 소환봉", "빙하의 소환봉", "화산 소환봉", "대악마의 소환봉"],
                         [.base, .poison, .fire, .ice, .thunder, .cosmic, .ice, .fire, .cosmic])
        let armors: [(String, Int, Int, Int, Bool)] = [
            ("천 옷", 0, 2, 40, true), ("가죽 갑옷", 0, 6, 260, true), ("사슬 갑옷", 1, 12, 900, true), ("미스릴 갑옷", 2, 20, 3200, true),
            ("용비늘 갑옷", 3, 34, 12000, false), ("사막 전사의 갑옷", 2, 50, 16000, true), ("빙하 갑옷", 3, 75, 45000, false),
            ("마왕의 갑주", 4, 112, 130000, false),
        ]
        items += armors.enumerated().map { i, a in
            RpgItem(id: "armor\(i)", name: a.0, kind: .armor, rarity: a.1, attack: 0, defense: a.2, heal: 0, price: a.3, element: .base, inShop: a.4)
        }
        items += [
            RpgItem(id: "hp0", name: "빨간 물약", kind: .potionHP, rarity: 0, attack: 0, defense: 0, heal: 60, price: 20, element: .base, inShop: true),
            RpgItem(id: "hp1", name: "주황 물약", kind: .potionHP, rarity: 1, attack: 0, defense: 0, heal: 160, price: 70, element: .base, inShop: true),
            RpgItem(id: "hp2", name: "하얀 물약", kind: .potionHP, rarity: 2, attack: 0, defense: 0, heal: 500, price: 260, element: .base, inShop: true),
            RpgItem(id: "hp3", name: "엘릭서", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 1500, price: 900, element: .base, inShop: true),
            RpgItem(id: "mp0", name: "파란 물약", kind: .potionMP, rarity: 0, attack: 0, defense: 0, heal: 40, price: 30, element: .base, inShop: true),
            RpgItem(id: "mp1", name: "마나 엘릭서", kind: .potionMP, rarity: 2, attack: 0, defense: 0, heal: 200, price: 300, element: .base, inShop: true),
            RpgItem(id: "scroll", name: "귀환 주문서", kind: .scroll, rarity: 0, attack: 0, defense: 0, heal: 0, price: 40, element: .base, inShop: true),
            RpgItem(id: "stone", name: "강화석", kind: .stone, rarity: 1, attack: 0, defense: 0, heal: 0, price: 300, element: .base, inShop: false),
        ]
        // Rings: HP, crit and attack. Amulets: HP, MP and defense. The lower tiers are sold, the rest drops or is crafted.
        let rings: [(String, Int, Int, Double, Double, Int, Bool)] = [
            ("구리 반지", 0, 20, 0.01, 0.02, 200, true), ("은 반지", 1, 50, 0.02, 0.04, 900, true), ("루비 반지", 2, 110, 0.03, 0.07, 3500, true),
            ("사파이어 반지", 2, 200, 0.04, 0.09, 8000, true), ("용의 반지", 3, 360, 0.06, 0.13, 24000, false), ("서리의 반지", 3, 600, 0.07, 0.16, 50000, false),
            ("마왕의 반지", 4, 950, 0.10, 0.22, 120000, false), ("별빛 반지", 4, 1400, 0.12, 0.28, 250000, false),
        ]
        items += rings.enumerated().map { i, r in
            RpgItem(id: "ring\(i)", name: r.0, kind: .ring, rarity: r.1, attack: 0, defense: 0, heal: 0, price: r.5, element: .base, inShop: r.6,
                    bonusHP: r.2, bonusCrit: r.3, bonusAttack: r.4)
        }
        let amulets: [(String, Int, Int, Int, Int, Int, Bool)] = [
            ("나무 목걸이", 0, 40, 10, 1, 200, true), ("은 목걸이", 1, 90, 20, 3, 900, true), ("호박 목걸이", 2, 200, 45, 7, 3500, true),
            ("청옥 목걸이", 2, 380, 80, 12, 8000, true), ("용의 목걸이", 3, 650, 130, 20, 24000, false), ("서리의 목걸이", 3, 1000, 200, 32, 50000, false),
            ("마왕의 목걸이", 4, 1600, 320, 50, 120000, false), ("별빛 목걸이", 4, 2400, 480, 75, 250000, false),
        ]
        items += amulets.enumerated().map { i, a in
            RpgItem(id: "amulet\(i)", name: a.0, kind: .amulet, rarity: a.1, attack: 0, defense: a.4, heal: 0, price: a.5, element: .base, inShop: a.6,
                    bonusHP: a.2, bonusMP: a.3)
        }
        let helmets: [(String, Int, Int, Int, Int, Bool)] = [
            ("가죽 모자", 0, 30, 1, 150, true), ("철 투구", 1, 70, 2, 800, true), ("은빛 투구", 2, 150, 5, 3200, true), ("미스릴 투구", 2, 280, 9, 7500, true),
            ("용의 투구", 3, 480, 15, 22000, false), ("서리 투구", 3, 780, 24, 48000, false), ("마왕의 투구", 4, 1200, 38, 115000, false), ("별빛 투구", 4, 1800, 56, 240000, false),
        ]
        items += helmets.enumerated().map { i, h in
            RpgItem(id: "helmet\(i)", name: h.0, kind: .helmet, rarity: h.1, attack: 0, defense: h.3, heal: 0, price: h.4, element: .base, inShop: h.5, bonusHP: h.2)
        }
        let boots: [(String, Int, Double, Int, Int, Bool)] = [
            ("천 신발", 0, 0.02, 1, 150, true), ("가죽 장화", 1, 0.03, 2, 800, true), ("사슬 장화", 2, 0.04, 4, 3200, true), ("미스릴 장화", 2, 0.05, 7, 7500, true),
            ("용의 장화", 3, 0.06, 11, 22000, false), ("서리 장화", 3, 0.07, 17, 48000, false), ("마왕의 장화", 4, 0.08, 26, 115000, false), ("별빛 장화", 4, 0.10, 40, 240000, false),
        ]
        items += boots.enumerated().map { i, b in
            RpgItem(id: "boots\(i)", name: b.0, kind: .boots, rarity: b.1, attack: 0, defense: b.3, heal: 0, price: b.4, element: .base, inShop: b.5, bonusSpeed: b.2)
        }
        items += [
            RpgItem(id: "hp4", name: "신의 물약", kind: .potionHP, rarity: 3, attack: 0, defense: 0, heal: 4000, price: 2800, element: .base, inShop: true),
            RpgItem(id: "mp2", name: "마나 에센스", kind: .potionMP, rarity: 3, attack: 0, defense: 0, heal: 600, price: 800, element: .base, inShop: true),
            RpgItem(id: "scroll_protect", name: "강화 보호 주문서", kind: .material, rarity: 3, attack: 0, defense: 0, heal: 0, price: 2500, element: .base, inShop: false),
        ]
        let materials: [(String, String, Int, Int)] = [
            ("mat_jelly", "슬라임 젤리", 0, 8), ("mat_hide", "늑대 가죽", 0, 20), ("mat_bone", "해골 뼛조각", 1, 60), ("mat_sting", "전갈 독침", 1, 120),
            ("mat_ice", "얼음 조각", 2, 250), ("mat_magma", "용암 핵", 2, 500), ("mat_dark", "암흑 파편", 3, 900), ("mat_wraith", "망령의 잔재", 3, 1600),
        ]
        items += materials.map { m in
            RpgItem(id: m.0, name: m.1, kind: .material, rarity: m.2, attack: 0, defense: 0, heal: 0, price: m.3 * 3, element: .base, inShop: false)
        }
        let buffPrices = ["atk": 600, "xp": 1500, "luck": 1200, "speed": 400, "pet": 500]
        items += RpgBuffs.all.map { b in
            RpgItem(id: "buff_\(b.id)", name: b.name, kind: .buff(b.id), rarity: b.id == "xp" || b.id == "luck" ? 2 : 1, attack: 0, defense: 0, heal: 0,
                    price: buffPrices[b.id] ?? 500, element: .base, inShop: true)
        }
        items += RpgSkills.all.filter { !$0.starter }.map { s in
            RpgItem(id: "book_\(s.id)", name: "스킬북: \(s.name)", kind: .book(s.id), rarity: s.isUltimate ? 3 : (s.price > 0 ? 1 : 2),
                    attack: 0, defense: 0, heal: 0, price: s.price > 0 ? s.price : (s.isUltimate ? 30000 : 6000), element: .base, inShop: s.price > 0)
        }
        return items
    }()

    private static let byID: [String: RpgItem] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func item(_ id: String) -> RpgItem? { byID[id] }

    /// Enhancement: +7% of the base stat per level.
    static func boosted(_ base: Int, plus: Int) -> Double { Double(base) * (1 + 0.07 * Double(plus)) }
    static let maxPlus = 15
    static func enhanceCost(_ item: RpgItem, plus: Int) -> (gold: Int, stones: Int) {
        (gold: 80 * (plus + 1) * (plus + 1) * (item.rarity + 1), stones: plus / 2 + 1)
    }
    static func enhanceChance(_ plus: Int) -> Double {
        switch plus {
        case ..<3: return 1
        case 3..<6: return 0.8
        case 6..<9: return 0.55
        case 9..<12: return 0.35
        default: return 0.2
        }
    }
}

enum RpgShop: String, Sendable, CaseIterable {
    case weapon, armor, potion, skill

    var title: String {
        switch self {
        case .weapon: return "무기점"
        case .armor: return "방어구점"
        case .potion: return "물약 상점"
        case .skill: return "마법서점"
        }
    }
    var stock: [RpgItem] {
        RpgItems.all.filter { item in
            guard item.inShop else { return false }
            switch (self, item.kind) {
            case (.weapon, .weapon), (.armor, .armor), (.armor, .ring), (.armor, .amulet), (.armor, .helmet), (.armor, .boots), (.skill, .book): return true
            case (.potion, .potionHP), (.potion, .potionMP), (.potion, .scroll), (.potion, .buff): return true
            default: return false
            }
        }
    }
}

enum RpgPlace: Sendable, Equatable {
    case shop(RpgShop)
    case smith
    case board
    case jobMaster

    var title: String {
        switch self {
        case .shop(let s): return s.title
        case .smith: return "대장간"
        case .board: return "의뢰소"
        case .jobMaster: return "전직관"
        }
    }
}

// MARK: monsters

/// `swarm`: weak fast packs that call each other; `charger`: telegraphs, then dashes in a line; `exploder`: runs up
/// and blows itself up (no reward unless it is killed first).
enum RpgBehavior: Sendable { case passive, aggressive, ranged, flyer, coward, boss, swarm, charger, exploder }

/// What a boss does besides chasing, slamming and firing rings.
enum RpgBossStyle: Sendable { case slime, golem, yeti, skeleton, demon }

struct RpgDrop: Sendable {
    let item: String
    let chance: Double
}

struct RpgMonsterDef: Sendable {
    let id: String
    let name: String
    let sprite: String
    let level: Int
    let hp: Int
    let attack: Int
    let defense: Int
    let speed: Double
    let xp: Int
    let gold: ClosedRange<Int>
    let behavior: RpgBehavior
    let drops: [RpgDrop]
    var bossStyle: RpgBossStyle = .slime
    var minion: String = "slime"
    var element: RpgElement = .base
}

enum RpgMonsters {
    private static func m(_ id: String, _ name: String, _ sprite: String, _ lv: Int, _ hp: Int, _ atk: Int, _ def: Int, _ speed: Double,
                          _ xp: Int, _ gold: ClosedRange<Int>, _ behavior: RpgBehavior, _ drops: [(String, Double)]) -> RpgMonsterDef {
        RpgMonsterDef(id: id, name: name, sprite: sprite, level: lv, hp: hp, attack: atk, defense: def, speed: speed, xp: xp, gold: gold,
                      behavior: behavior, drops: drops.map { RpgDrop(item: $0.0, chance: $0.1) })
    }
    private static func boss(_ id: String, _ name: String, _ sprite: String, _ lv: Int, _ hp: Int, _ atk: Int, _ def: Int, _ speed: Double,
                             _ xp: Int, _ gold: ClosedRange<Int>, _ style: RpgBossStyle, minion: String, element: RpgElement,
                             _ drops: [(String, Double)]) -> RpgMonsterDef {
        var d = m(id, name, sprite, lv, hp, atk, def, speed, xp, gold, .boss, drops + Array(repeating: ("stone", 1.0), count: max(3, lv / 5)))
        d.bossStyle = style
        d.minion = minion
        d.element = element
        return d
    }

    static let all: [RpgMonsterDef] = [
        m("slime", "슬라임", "slime", 1, 28, 5, 0, 26, 6, 2...5, .passive, [("hp0", 0.12), ("stone", 0.01)]),
        m("blueslime", "파란 슬라임", "blueslime", 3, 50, 8, 1, 30, 11, 4...8, .passive, [("mp0", 0.1), ("armor0", 0.03), ("stone", 0.015)]),
        m("brownshroom", "갈색 버섯", "brownshroom", 2, 40, 7, 1, 22, 8, 3...6, .passive, [("hp0", 0.12), ("stone", 0.01)]),
        m("poisonshroom", "독버섯", "mushroom", 5, 95, 14, 3, 26, 22, 8...14, .aggressive,
          [("hp0", 0.15), ("sword1", 0.012), ("bow1", 0.012), ("staff1", 0.012), ("stone", 0.03), ("book_w_iron", 0.003), ("book_a_back", 0.003), ("book_m_blizzard", 0.003)]),
        m("wolf", "늑대", "wolf", 7, 130, 18, 4, 52, 30, 10...18, .aggressive, [("hp1", 0.08), ("armor1", 0.02), ("stone", 0.03)]),
        m("bat", "박쥐", "bat", 6, 70, 15, 2, 46, 18, 6...12, .flyer, [("mp0", 0.12), ("stone", 0.025)]),
        m("cavebat", "동굴 박쥐", "cavebat", 9, 130, 24, 4, 50, 36, 12...20, .flyer, [("mp0", 0.15), ("hp1", 0.06), ("stone", 0.04)]),
        m("skeleton", "해골병사", "skeleton", 10, 230, 30, 8, 34, 52, 18...30, .aggressive,
          [("hp1", 0.1), ("armor2", 0.015), ("sword2", 0.008), ("sword3", 0.008), ("stone", 0.05), ("book_w_iron", 0.004), ("book_a_back", 0.004), ("book_m_blizzard", 0.004)]),
        m("skelarcher", "해골 궁수", "skelarcher", 12, 190, 34, 6, 30, 70, 22...36, .ranged,
          [("hp1", 0.1), ("bow2", 0.01), ("bow3", 0.01), ("bow4", 0.01), ("stone", 0.05)]),
        m("golem", "골렘", "golem", 13, 480, 44, 14, 20, 115, 40...70, .aggressive,
          [("armor3", 0.02), ("staff2", 0.01), ("staff3", 0.01), ("staff4", 0.01), ("sword4", 0.01), ("stone", 0.08)]),
        m("goldslime", "황금 슬라임", "goldslime", 8, 110, 0, 5, 44, 45, 150...320, .coward, [("hp1", 0.3), ("stone", 0.3)]),
        boss("slimeking", "슬라임 킹", "slimeking", 15, 45000, 60, 10, 34, 1500, 500...800, .slime, minion: "slime", element: .base,
             [("sword5", 0.1), ("bow5", 0.1), ("staff5", 0.1), ("armor4", 0.15), ("hp1", 1)]),

        m("sandslime", "모래 슬라임", "sandslime", 15, 420, 52, 14, 32, 160, 40...70, .passive, [("hp1", 0.1), ("stone", 0.05)]),
        m("scorpion", "사막 전갈", "scorpion", 17, 520, 60, 18, 56, 200, 50...80, .aggressive,
          [("hp1", 0.1), ("stone", 0.06), ("book_w_cyclone", 0.004), ("book_a_trap", 0.004), ("book_m_pillar", 0.004)]),
        m("mummy", "미라", "mummy", 19, 700, 66, 20, 30, 250, 60...95, .aggressive, [("hp2", 0.06), ("armor5", 0.006), ("stone", 0.07)]),
        m("sandgolem", "모래 골렘", "sandgolem", 21, 1100, 78, 30, 22, 340, 80...130, .aggressive,
          [("sword6", 0.008), ("bow6", 0.008), ("staff6", 0.008), ("stone", 0.1), ("book_w_cyclone", 0.005), ("book_a_trap", 0.005), ("book_m_pillar", 0.005)]),
        boss("sandking", "모래골렘 왕", "sandking", 24, 225000, 140, 30, 30, 6000, 2000...3000, .golem, minion: "sandslime", element: .fire,
             [("sword6", 0.25), ("bow6", 0.25), ("staff6", 0.25), ("armor5", 0.3), ("book_w_cyclone", 0.15), ("book_a_trap", 0.15), ("book_m_pillar", 0.15)]),

        m("iceslime", "얼음 슬라임", "iceslime", 22, 900, 82, 26, 32, 380, 70...110, .passive, [("hp2", 0.08), ("stone", 0.07)]),
        m("snowwolf", "설원 늑대", "snowwolf", 24, 1000, 92, 28, 60, 430, 80...120, .aggressive,
          [("hp2", 0.08), ("stone", 0.08), ("book_w_slam", 0.004), ("book_a_focus", 0.004), ("book_m_heal", 0.004)]),
        m("icebat", "얼음 박쥐", "icebat", 25, 820, 96, 24, 52, 420, 70...110, .flyer, [("mp1", 0.06), ("stone", 0.08)]),
        m("yeti", "설인", "yeti", 28, 2000, 115, 40, 26, 650, 120...190, .aggressive,
          [("armor6", 0.004), ("bow7", 0.004), ("stone", 0.12), ("book_w_slam", 0.006), ("book_a_focus", 0.006), ("book_m_heal", 0.006)]),
        boss("yetiking", "설인 왕", "yetiking", 32, 330000, 210, 45, 34, 14000, 4000...6000, .yeti, minion: "snowwolf", element: .ice,
             [("armor6", 0.2), ("bow7", 0.2), ("staff6", 0.3), ("book_w_slam", 0.2), ("book_a_focus", 0.2), ("book_m_heal", 0.2)]),

        m("magmaslime", "용암 슬라임", "magmaslime", 30, 1900, 130, 42, 34, 720, 130...200, .passive, [("hp2", 0.1), ("stone", 0.1)]),
        m("firebat", "불꽃 박쥐", "firebat", 32, 1700, 140, 38, 56, 760, 130...200, .flyer, [("mp1", 0.08), ("stone", 0.1)]),
        m("flameskel", "불꽃 해골", "flameskel", 35, 2800, 160, 50, 36, 980, 180...260, .aggressive,
          [("hp3", 0.03), ("sword7", 0.004), ("staff7", 0.004), ("stone", 0.12)]),
        m("lavagolem", "용암 골렘", "lavagolem", 38, 4200, 185, 66, 24, 1300, 240...340, .aggressive,
          [("sword7", 0.005), ("staff7", 0.005), ("bow7", 0.005), ("stone", 0.15), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001)]),
        boss("skelking", "화염 해골왕", "skelking", 42, 525000, 330, 70, 36, 30000, 8000...12000, .skeleton, minion: "flameskel", element: .fire,
             [("sword7", 0.25), ("staff7", 0.25), ("bow7", 0.25), ("book_w_ult", 0.1), ("book_a_ult", 0.1), ("book_m_ult", 0.1)]),

        m("darkknight", "암흑 기사", "darkknight", 42, 5200, 230, 80, 40, 1700, 300...450, .aggressive, [("hp3", 0.05), ("stone", 0.15)]),
        m("shadowmage", "그림자 마법사", "shadowmage", 45, 4200, 250, 66, 34, 1900, 320...480, .ranged, [("mp1", 0.1), ("stone", 0.15)]),
        m("demonbat", "악마 박쥐", "demonbat", 44, 4000, 240, 60, 60, 1800, 300...450, .flyer, [("hp3", 0.04), ("stone", 0.15)]),
        m("gargoyle", "가고일", "gargoyle", 50, 8000, 290, 100, 28, 2600, 450...650, .aggressive,
          [("stone", 0.22), ("book_w_ult", 0.002), ("book_a_ult", 0.002), ("book_m_ult", 0.002)]),
        boss("demonking", "마왕", "demonking", 58, 975000, 500, 110, 40, 90000, 30000...50000, .demon, minion: "darkknight", element: .cosmic,
             [("sword8", 0.15), ("bow8", 0.15), ("staff8", 0.15), ("armor7", 0.2), ("book_w_ult", 0.25), ("book_a_ult", 0.25), ("book_m_ult", 0.25)]),

        // swamp (Lv16~20)
        m("bogshroom", "늪 버섯", "bogshroom", 16, 500, 56, 16, 28, 185, 45...75, .aggressive, [("hp1", 0.1), ("stone", 0.05)]),
        m("bogwolf", "늪 늑대", "bogwolf", 18, 650, 64, 19, 54, 235, 55...88, .aggressive,
          [("hp2", 0.05), ("stone", 0.06), ("book_w_cyclone", 0.004), ("book_a_trap", 0.004), ("book_m_pillar", 0.004)]),
        m("mossgolem", "이끼 골렘", "mossgolem", 20, 950, 72, 26, 22, 300, 70...115, .aggressive,
          [("sword6", 0.006), ("bow6", 0.006), ("staff6", 0.006), ("stone", 0.09)]),
        // ruins (Lv29~34)
        m("ruinbat", "유적 박쥐", "ruinbat", 29, 1800, 122, 38, 54, 690, 110...170, .flyer, [("mp1", 0.07), ("stone", 0.1)]),
        m("ruinskel", "고대 해골", "ruinskel", 31, 2300, 135, 44, 34, 800, 125...190, .aggressive,
          [("hp2", 0.08), ("stone", 0.11), ("book_w_slam", 0.005), ("book_a_focus", 0.005), ("book_m_heal", 0.005)]),
        m("ruinwarden", "유적 수호자", "ruinwarden", 34, 3000, 152, 54, 24, 920, 150...230, .aggressive,
          [("armor6", 0.005), ("sword7", 0.004), ("bow7", 0.004), ("stone", 0.13)]),
        // crypt (Lv45~52)
        m("wraith", "망령", "wraith", 45, 4800, 255, 68, 40, 2000, 330...480, .ranged, [("mp1", 0.1), ("hp3", 0.04), ("stone", 0.15)]),
        m("bonelord", "뼈 군주", "bonelord", 48, 6200, 270, 88, 34, 2300, 400...580, .aggressive,
          [("hp3", 0.05), ("stone", 0.18), ("book_w_ult", 0.001), ("book_a_ult", 0.001), ("book_m_ult", 0.001)]),
        m("cryptguard", "지하묘지 수호상", "cryptguard", 52, 10000, 310, 110, 26, 3000, 500...720, .aggressive,
          [("stone", 0.25), ("book_w_ult", 0.002), ("book_a_ult", 0.002), ("book_m_ult", 0.002)]),

        // Packs, chargers and bombs for every zone (see RpgBehavior.swarm / .charger / .exploder).
        m("fieldswarm", "초록 새끼슬라임", "fieldswarm", 2, 17, 5, 0, 52.0, 5, 2...4, .swarm, [("hp0", 0.1), ("stone", 0.033)]),
        m("fieldcharger", "들개", "fieldcharger", 4, 75, 9, 1, 30.0, 16, 5...10, .charger, [("hp0", 0.1), ("stone", 0.033)]),
        m("fieldexploder", "폭죽 버섯", "fieldexploder", 4, 35, 11, 0, 36.0, 14, 4...8, .exploder, [("hp0", 0.1), ("stone", 0.033)]),
        m("forestswarm", "숲 박쥐떼", "forestswarm", 5, 38, 11, 1, 62.0, 12, 4...7, .swarm, [("hp0", 0.1), ("stone", 0.037)]),
        m("forestcharger", "멧돼지", "forestcharger", 7, 165, 18, 3, 40.0, 37, 11...19, .charger, [("hp0", 0.1), ("stone", 0.037)]),
        m("forestexploder", "폭발 버섯", "forestexploder", 7, 77, 22, 1, 46.0, 32, 9...16, .exploder, [("hp0", 0.1), ("stone", 0.037)]),
        m("cave1swarm", "동굴 거미", "cave1swarm", 9, 70, 19, 3, 62.0, 22, 7...13, .swarm, [("hp1", 0.1), ("stone", 0.041)]),
        m("cave1charger", "돌진 해골", "cave1charger", 11, 300, 32, 6, 40.0, 67, 19...33, .charger, [("hp1", 0.1), ("stone", 0.041)]),
        m("cave1exploder", "폭탄 슬라임", "cave1exploder", 11, 140, 39, 3, 46.0, 58, 16...28, .exploder, [("hp1", 0.1), ("stone", 0.041)]),
        m("cave2swarm", "바위 거미", "cave2swarm", 11, 115, 26, 5, 52.0, 42, 13...22, .swarm, [("hp1", 0.1), ("stone", 0.043)]),
        m("cave2charger", "돌 파쇄자", "cave2charger", 13, 495, 43, 11, 30.0, 127, 33...58, .charger, [("hp1", 0.1), ("stone", 0.043)]),
        m("cave2exploder", "폭탄 해골", "cave2exploder", 13, 230, 53, 6, 36.0, 110, 28...49, .exploder, [("hp1", 0.1), ("stone", 0.043)]),
        m("desertswarm", "사막 전갈떼", "desertswarm", 17, 210, 43, 9, 67.0, 110, 27...45, .swarm, [("hp1", 0.1), ("stone", 0.05)]),
        m("desertcharger", "모래 늑대", "desertcharger", 19, 900, 71, 19, 45.0, 330, 71...117, .charger, [("hp1", 0.1), ("stone", 0.05)]),
        m("desertexploder", "선인장 폭탄", "desertexploder", 19, 420, 86, 10, 51.0, 286, 60...99, .exploder, [("hp1", 0.1), ("stone", 0.05)]),
        m("snowswarm", "서리 진드기", "snowswarm", 24, 350, 64, 14, 72.0, 215, 40...60, .swarm, [("hp2", 0.1), ("stone", 0.058)]),
        m("snowcharger", "빙하 멧돼지", "snowcharger", 26, 1500, 105, 30, 50.0, 645, 104...156, .charger, [("hp2", 0.1), ("stone", 0.058)]),
        m("snowexploder", "눈폭탄 슬라임", "snowexploder", 26, 700, 128, 16, 56.0, 559, 88...132, .exploder, [("hp2", 0.1), ("stone", 0.058)]),
        m("volcanoswarm", "불씨 전갈떼", "volcanoswarm", 33, 840, 105, 24, 62.0, 440, 75...115, .swarm, [("hp2", 0.1), ("stone", 0.068)]),
        m("volcanocharger", "용암 멧돼지", "volcanocharger", 35, 3600, 172, 52, 40.0, 1320, 195...299, .charger, [("hp2", 0.1), ("stone", 0.068)]),
        m("volcanoexploder", "폭발 해골", "volcanoexploder", 35, 1680, 210, 28, 46.0, 1144, 165...253, .exploder, [("hp2", 0.1), ("stone", 0.068)]),
        m("castleswarm", "굶주린 구울떼", "castleswarm", 45, 1924, 168, 42, 62.0, 925, 160...240, .swarm, [("hp3", 0.1), ("stone", 0.081)]),
        m("castlecharger", "돌격 기사", "castlecharger", 47, 8250, 276, 93, 40.0, 2775, 416...624, .charger, [("hp3", 0.1), ("stone", 0.081)]),
        m("castleexploder", "영혼 폭탄", "castleexploder", 47, 3849, 336, 51, 46.0, 2405, 352...528, .exploder, [("hp3", 0.1), ("stone", 0.081)]),
        m("swampswarm", "늪 거머리떼", "swampswarm", 17, 227, 42, 9, 62.0, 95, 25...42, .swarm, [("hp1", 0.1), ("stone", 0.05)]),
        m("swampcharger", "늪 멧돼지", "swampcharger", 19, 975, 69, 19, 40.0, 285, 65...110, .charger, [("hp1", 0.1), ("stone", 0.05)]),
        m("swampexploder", "포자 폭탄", "swampexploder", 19, 454, 84, 10, 46.0, 247, 55...93, .exploder, [("hp1", 0.1), ("stone", 0.05)]),
        m("ruinsswarm", "유적 전갈떼", "ruinsswarm", 30, 700, 96, 20, 62.0, 380, 65...100, .swarm, [("hp2", 0.1), ("stone", 0.064)]),
        m("ruinscharger", "석상 돌격병", "ruinscharger", 32, 3000, 158, 44, 40.0, 1140, 169...260, .charger, [("hp2", 0.1), ("stone", 0.064)]),
        m("ruinsexploder", "저주 폭탄", "ruinsexploder", 32, 1400, 193, 24, 46.0, 988, 143...220, .exploder, [("hp2", 0.1), ("stone", 0.064)]),
        m("cryptswarm", "원혼떼", "cryptswarm", 47, 2275, 183, 44, 58.0, 1100, 180...260, .swarm, [("hp3", 0.1), ("stone", 0.083)]),
        m("cryptcharger", "뼈 투우", "cryptcharger", 49, 9750, 301, 96, 36.0, 3300, 468...676, .charger, [("hp3", 0.1), ("stone", 0.083)]),
        m("cryptexploder", "죽음의 폭탄", "cryptexploder", 49, 4550, 366, 52, 42.0, 2860, 396...572, .exploder, [("hp3", 0.1), ("stone", 0.083)]),
    ]
    private static let byID: [String: RpgMonsterDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func def(_ id: String) -> RpgMonsterDef { byID[id]! }
}

// MARK: maps

enum RpgMapID: String, Codable, CaseIterable, Sendable {
    case town, field, forest, cave1, cave2, boss, pond
    case desert, desertBoss, snow, snowBoss, volcano, volcanoBoss, castle, castleBoss
    case swamp, ruins, crypt
    case tower
}

enum RpgMapKind: Sendable { case town, field, forest, cave, boss, pond, desert, snow, volcano, castle }

struct RpgTile: Hashable, Sendable {
    let x: Int
    let y: Int
}

struct RpgPortal: Sendable {
    let at: RpgTile
    let to: RpgMapID
    /// Where the traveller appears on the other side.
    let arrive: RpgTile
    let minLevel: Int
    let hidden: Bool
    /// The town's 차원문: opens the list of visited zones instead of leading to one map.
    var waypoint = false
}

struct RpgSpawn: Sendable {
    let monster: String
    let count: Int
}

struct RpgMapDef: Sendable {
    let id: RpgMapID
    let name: String
    let levelText: String
    let width: Int
    let height: Int
    let kind: RpgMapKind
    let seed: UInt64
    let portals: [RpgPortal]
    let monsters: [RpgSpawn]
    /// Boss rooms are lit like caves but use the zone's palette.
    var zone: RpgMapKind? = nil
}

enum RpgMaps {
    private static func p(_ x: Int, _ y: Int, _ to: RpgMapID, _ ax: Int, _ ay: Int, minLevel: Int = 1, hidden: Bool = false) -> RpgPortal {
        RpgPortal(at: RpgTile(x: x, y: y), to: to, arrive: RpgTile(x: ax, y: ay), minLevel: minLevel, hidden: hidden)
    }
    private static func sp(_ list: [(String, Int)]) -> [RpgSpawn] { list.map { RpgSpawn(monster: $0.0, count: $0.1) } }

    static let all: [RpgMapDef] = {
        var town = RpgPortal(at: RpgTile(x: 1, y: 11), to: .town, arrive: RpgTile(x: 4, y: 11), minLevel: 1, hidden: false)
        town.waypoint = true
        var maps: [RpgMapDef] = [
            RpgMapDef(id: .town, name: "마을", levelText: "안전지대", width: 32, height: 24, kind: .town, seed: 1,
                      portals: [p(30, 11, .field, 4, 14), p(28, 7, .tower, 14, 17, minLevel: 10), town], monsters: []),
            RpgMapDef(id: .field, name: "초원", levelText: "Lv1~4", width: 46, height: 28, kind: .field, seed: 11,
                      portals: [p(1, 14, .town, 28, 11), p(44, 14, .forest, 4, 15)],
                      monsters: sp([("slime", 10), ("blueslime", 5), ("brownshroom", 6), ("fieldswarm", 6), ("fieldcharger", 3), ("fieldexploder", 2)])),
            RpgMapDef(id: .forest, name: "숲", levelText: "Lv4~8", width: 46, height: 30, kind: .forest, seed: 23,
                      portals: [p(1, 15, .field, 41, 14), p(44, 15, .cave1, 4, 13), p(6, 3, .pond, 11, 11, hidden: true)],
                      monsters: sp([("poisonshroom", 8), ("wolf", 5), ("bat", 6), ("forestswarm", 6), ("forestcharger", 3), ("forestexploder", 2)])),
            RpgMapDef(id: .cave1, name: "동굴 1층", levelText: "Lv8~12", width: 42, height: 26, kind: .cave, seed: 37,
                      portals: [p(1, 13, .forest, 41, 15), p(40, 13, .cave2, 4, 13)],
                      monsters: sp([("cavebat", 8), ("skeleton", 7), ("cave1swarm", 6), ("cave1charger", 3), ("cave1exploder", 2)])),
            RpgMapDef(id: .cave2, name: "동굴 2층", levelText: "Lv10~14", width: 42, height: 26, kind: .cave, seed: 41,
                      portals: [p(1, 13, .cave1, 37, 13), p(21, 1, .boss, 14, 17, minLevel: 12)],
                      monsters: sp([("skelarcher", 6), ("golem", 4), ("skeleton", 4), ("cave2swarm", 6), ("cave2charger", 3), ("cave2exploder", 2)])),
            RpgMapDef(id: .boss, name: "슬라임 킹의 둥지", levelText: "보스 Lv15", width: 28, height: 22, kind: .boss, seed: 53,
                      portals: [p(14, 20, .cave2, 21, 4), p(26, 10, .desert, 4, 15, minLevel: 15)],
                      monsters: sp([("slimeking", 1)]), zone: .cave),
            RpgMapDef(id: .pond, name: "비밀 연못", levelText: "보너스", width: 24, height: 16, kind: .pond, seed: 61,
                      portals: [p(11, 14, .forest, 6, 6)], monsters: sp([("goldslime", 3)])),
            // 무한의 탑: no fixed monsters, `RpgWorld` fills each floor (see `towerWave`).
            RpgMapDef(id: .tower, name: "무한의 탑", levelText: "도전", width: 28, height: 22, kind: .boss, seed: 131,
                      portals: [p(14, 20, .town, 27, 7)], monsters: [], zone: .castle),

            RpgMapDef(id: .desert, name: "작열의 사막", levelText: "Lv15~22", width: 50, height: 30, kind: .desert, seed: 71,
                      portals: [p(1, 15, .boss, 23, 10), p(48, 15, .snow, 4, 15, minLevel: 22), p(25, 1, .desertBoss, 14, 17, minLevel: 20), p(25, 28, .swamp, 4, 15, minLevel: 16)],
                      monsters: sp([("sandslime", 9), ("scorpion", 7), ("mummy", 6), ("sandgolem", 4), ("desertswarm", 6), ("desertcharger", 3), ("desertexploder", 2)])),
            RpgMapDef(id: .desertBoss, name: "피라미드 심층", levelText: "보스 Lv24", width: 28, height: 22, kind: .boss, seed: 73,
                      portals: [p(14, 20, .desert, 25, 4)], monsters: sp([("sandking", 1)]), zone: .desert),
            RpgMapDef(id: .snow, name: "얼어붙은 설원", levelText: "Lv22~30", width: 50, height: 30, kind: .snow, seed: 79,
                      portals: [p(1, 15, .desert, 45, 15), p(48, 15, .volcano, 4, 15, minLevel: 30), p(25, 1, .snowBoss, 14, 17, minLevel: 28), p(25, 28, .ruins, 4, 15, minLevel: 29)],
                      monsters: sp([("iceslime", 9), ("snowwolf", 7), ("icebat", 6), ("yeti", 4), ("snowswarm", 6), ("snowcharger", 3), ("snowexploder", 2)])),
            RpgMapDef(id: .snowBoss, name: "빙하 동굴", levelText: "보스 Lv32", width: 28, height: 22, kind: .boss, seed: 83,
                      portals: [p(14, 20, .snow, 25, 4)], monsters: sp([("yetiking", 1)]), zone: .snow),
            RpgMapDef(id: .volcano, name: "불타는 화산", levelText: "Lv30~40", width: 50, height: 30, kind: .volcano, seed: 89,
                      portals: [p(1, 15, .snow, 45, 15), p(48, 15, .castle, 4, 15, minLevel: 40), p(25, 1, .volcanoBoss, 14, 17, minLevel: 37)],
                      monsters: sp([("magmaslime", 9), ("firebat", 7), ("flameskel", 6), ("lavagolem", 4), ("volcanoswarm", 6), ("volcanocharger", 3), ("volcanoexploder", 2)])),
            RpgMapDef(id: .volcanoBoss, name: "화산의 심장", levelText: "보스 Lv42", width: 28, height: 22, kind: .boss, seed: 97,
                      portals: [p(14, 20, .volcano, 25, 4)], monsters: sp([("skelking", 1)]), zone: .volcano),
            RpgMapDef(id: .castle, name: "마왕성", levelText: "Lv40~55", width: 50, height: 32, kind: .castle, seed: 101,
                      portals: [p(1, 16, .volcano, 45, 15), p(25, 1, .castleBoss, 14, 17, minLevel: 50), p(25, 30, .crypt, 4, 15, minLevel: 44)],
                      monsters: sp([("darkknight", 8), ("shadowmage", 6), ("demonbat", 6), ("gargoyle", 4), ("castleswarm", 6), ("castlecharger", 3), ("castleexploder", 2)])),
            RpgMapDef(id: .castleBoss, name: "마왕의 옥좌", levelText: "보스 Lv58", width: 28, height: 22, kind: .boss, seed: 103,
                      portals: [p(14, 20, .castle, 25, 4)], monsters: sp([("demonking", 1)]), zone: .castle),
            RpgMapDef(id: .swamp, name: "안개 늪", levelText: "Lv16~21", width: 46, height: 30, kind: .forest, seed: 107,
                      portals: [p(1, 15, .desert, 25, 25)],
                      monsters: sp([("bogshroom", 8), ("bogwolf", 6), ("mossgolem", 4), ("swampswarm", 6), ("swampcharger", 3), ("swampexploder", 2)])),
            RpgMapDef(id: .ruins, name: "잊힌 유적", levelText: "Lv29~34", width: 46, height: 30, kind: .cave, seed: 109,
                      portals: [p(1, 15, .snow, 25, 25)],
                      monsters: sp([("ruinbat", 7), ("ruinskel", 6), ("ruinwarden", 4), ("ruinsswarm", 6), ("ruinscharger", 3), ("ruinsexploder", 2)])),
            RpgMapDef(id: .crypt, name: "왕가의 지하묘지", levelText: "Lv44~52", width: 46, height: 30, kind: .castle, seed: 113,
                      portals: [p(1, 15, .castle, 25, 27)],
                      monsters: sp([("wraith", 7), ("bonelord", 6), ("cryptguard", 4), ("cryptswarm", 6), ("cryptcharger", 3), ("cryptexploder", 2)])),
        ]
        return maps
    }()
    static func def(_ id: RpgMapID) -> RpgMapDef { all.first { $0.id == id }! }

    /// Zones the 차원문 can open once visited.
    static let waypoints: [RpgMapID] = [.field, .forest, .cave1, .cave2, .desert, .swamp, .snow, .ruins, .volcano, .castle, .crypt]

    static func xpNeeded(_ level: Int) -> Int {
        let l = level
        return (15 * l + 5 * l * l) * 5 / 2 + (l > 15 ? 22 * (l - 15) * (l - 15) : 0) + (l > 35 ? 40 * (l - 35) * (l - 35) * (l - 35) / 10 : 0)
    }
    static let maxLevel = 60
}

import Foundation

// SPIKE: "픽셀 모험" — a small real-time action RPG drawn entirely in code. This file is the static
// game data: classes, items, monsters and the seven maps joined by portals. Everything is a plain
// Sendable value so a lobby host can later run the same world for nearby players.

enum RpgClass: String, Codable, CaseIterable, Sendable {
    case warrior, archer, mage

    private var index: Int { Self.allCases.firstIndex(of: self)! }
    var name: String { ["전사", "궁수", "마법사"][index] }
    var blurb: String {
        switch self {
        case .warrior: return "튼튼한 몸과 검으로 앞에서 싸워요. 회전베기와 돌진베기."
        case .archer: return "멀리서 활을 쏴요. 치명타가 잘 터지고 공격이 빨라요."
        case .mage: return "몸은 약하지만 강력한 원소 마법. 무기 속성에 따라 마법이 바뀌어요."
        }
    }
    var baseHP: Int { [130, 95, 80][index] }
    var hpPerLevel: Int { [20, 14, 11][index] }
    var baseMP: Int { [30, 40, 70][index] }
    var mpPerLevel: Int { [3, 4, 7][index] }
    var baseAttack: Int { [11, 10, 12][index] }
    var attackPerLevel: Double { [3, 3, 3.4][index] }
    var baseDefense: Int { [6, 4, 3][index] }
    var defensePerLevel: Double { [2, 1.2, 1][index] }
    var speed: Double { [72, 80, 68][index] }
    var attackInterval: Double { [0.42, 0.5, 0.6][index] }
    var critChance: Double { [0.08, 0.16, 0.08][index] }
    var skillNames: [String] {
        switch self {
        case .warrior: return ["회전베기", "돌진베기"]
        case .archer: return ["삼연사", "관통 화살"]
        case .mage: return ["원소 폭발", "연쇄 마법"]
        }
    }
    var skillCost: [Int] { [[10, 8], [10, 14], [16, 18]][index] }
    var skillCooldown: [Double] { [[4, 5], [3.5, 6], [4, 6]][index] }
    var starterWeapon: String { ["sword0", "bow0", "staff0"][index] }
}

enum RpgElement: String, Codable, Sendable {
    case base, fire, ice, thunder, wind, holy, cosmic

    var effectName: String {
        switch self {
        case .base: return ""
        case .fire: return "화상"
        case .ice: return "둔화"
        case .thunder: return "감전"
        case .wind: return "공속 증가"
        case .holy: return "범위 피해"
        case .cosmic: return "메테오"
        }
    }
}

enum RpgItemKind: Sendable, Equatable {
    case weapon(RpgClass)
    case armor
    case potionHP
    case potionMP
    case scroll
}

struct RpgItem: Sendable {
    let id: String
    let name: String
    let kind: RpgItemKind
    /// 0 일반, 1 희귀, 2 영웅, 3 전설.
    let rarity: Int
    let attack: Int
    let defense: Int
    let heal: Int
    let price: Int
    let element: RpgElement
    /// Sold in a town shop; legendaries only drop.
    let inShop: Bool

    var sellPrice: Int { max(1, price / 3) }
    var isEquipment: Bool {
        switch kind {
        case .weapon, .armor: return true
        default: return false
        }
    }
}

enum RpgItems {
    static let rarityName = ["일반", "희귀", "영웅", "전설"]

    private static func weapons(_ cls: RpgClass, _ prefix: String, _ names: [String]) -> [RpgItem] {
        let elements: [RpgElement] = [.base, .base, .fire, .ice, cls == .archer ? .wind : .thunder, cls == .mage ? .cosmic : .holy]
        let rarity = [0, 1, 2, 2, 2, 3]
        let attack = [3, 9, 18, 17, 17, 32]
        let price = [40, 320, 1400, 1400, 1400, 9000]
        return names.indices.map { i in
            RpgItem(id: "\(prefix)\(i)", name: names[i], kind: .weapon(cls), rarity: rarity[i], attack: attack[i], defense: 0,
                    heal: 0, price: price[i], element: elements[i], inShop: rarity[i] < 3)
        }
    }

    static let all: [RpgItem] = {
        var items = weapons(.warrior, "sword", ["나무 검", "강철 검", "화염검", "서리검", "뇌전검", "별빛 성검"])
        items += weapons(.archer, "bow", ["나무 활", "강철 활", "불꽃 활", "서리 활", "질풍 활", "천공의 활"])
        items += weapons(.mage, "staff", ["나무 지팡이", "수정 지팡이", "화염 지팡이", "빙결 지팡이", "뇌운 지팡이", "우주의 지팡이"])
        let armors: [(String, String, Int, Int, Int, Bool)] = [
            ("armor0", "천 옷", 0, 2, 40, true), ("armor1", "가죽 갑옷", 0, 6, 260, true), ("armor2", "사슬 갑옷", 1, 12, 900, true),
            ("armor3", "미스릴 갑옷", 2, 20, 3200, true), ("armor4", "용비늘 갑옷", 3, 34, 12000, false),
        ]
        items += armors.map {
            RpgItem(id: $0.0, name: $0.1, kind: .armor, rarity: $0.2, attack: 0, defense: $0.3, heal: 0, price: $0.4,
                    element: .base, inShop: $0.5)
        }
        items += [
            RpgItem(id: "hp0", name: "빨간 물약", kind: .potionHP, rarity: 0, attack: 0, defense: 0, heal: 60, price: 20, element: .base, inShop: true),
            RpgItem(id: "hp1", name: "주황 물약", kind: .potionHP, rarity: 1, attack: 0, defense: 0, heal: 160, price: 70, element: .base, inShop: true),
            RpgItem(id: "mp0", name: "파란 물약", kind: .potionMP, rarity: 0, attack: 0, defense: 0, heal: 40, price: 30, element: .base, inShop: true),
            RpgItem(id: "scroll", name: "귀환 주문서", kind: .scroll, rarity: 0, attack: 0, defense: 0, heal: 0, price: 40, element: .base, inShop: true),
        ]
        return items
    }()

    private static let byID: [String: RpgItem] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func item(_ id: String) -> RpgItem? { byID[id] }
}

enum RpgShop: String, Sendable, CaseIterable {
    case weapon, armor, potion

    var title: String {
        switch self {
        case .weapon: return "무기점"
        case .armor: return "방어구점"
        case .potion: return "물약 상점"
        }
    }
    var stock: [RpgItem] {
        RpgItems.all.filter { item in
            guard item.inShop else { return false }
            switch (self, item.kind) {
            case (.weapon, .weapon): return true
            case (.armor, .armor): return true
            case (.potion, .potionHP), (.potion, .potionMP), (.potion, .scroll): return true
            default: return false
            }
        }
    }
}

enum RpgBehavior: Sendable { case passive, aggressive, ranged, flyer, coward, boss }

struct RpgDrop: Sendable {
    let item: String
    let chance: Double
}

struct RpgMonsterDef: Sendable {
    let id: String
    let name: String
    let level: Int
    let hp: Int
    let attack: Int
    let defense: Int
    let speed: Double
    let xp: Int
    let gold: ClosedRange<Int>
    let behavior: RpgBehavior
    let drops: [RpgDrop]
}

enum RpgMonsters {
    private static func m(_ id: String, _ name: String, _ lv: Int, _ hp: Int, _ atk: Int, _ def: Int, _ speed: Double, _ xp: Int,
                          _ gold: ClosedRange<Int>, _ behavior: RpgBehavior, _ drops: [(String, Double)]) -> RpgMonsterDef {
        RpgMonsterDef(id: id, name: name, level: lv, hp: hp, attack: atk, defense: def, speed: speed, xp: xp, gold: gold,
                      behavior: behavior, drops: drops.map { RpgDrop(item: $0.0, chance: $0.1) })
    }

    static let all: [RpgMonsterDef] = [
        m("slime", "슬라임", 1, 28, 5, 0, 26, 6, 2...5, .passive, [("hp0", 0.12)]),
        m("blueslime", "파란 슬라임", 3, 50, 8, 1, 30, 11, 4...8, .passive, [("mp0", 0.1), ("armor0", 0.03)]),
        m("brownshroom", "갈색 버섯", 2, 40, 7, 1, 22, 8, 3...6, .passive, [("hp0", 0.12)]),
        m("poisonshroom", "독버섯", 5, 95, 14, 3, 26, 22, 8...14, .aggressive, [("hp0", 0.15), ("sword1", 0.012), ("bow1", 0.012), ("staff1", 0.012)]),
        m("wolf", "늑대", 7, 130, 18, 4, 52, 30, 10...18, .aggressive, [("hp1", 0.08), ("armor1", 0.02)]),
        m("bat", "박쥐", 6, 70, 15, 2, 46, 18, 6...12, .flyer, [("mp0", 0.12)]),
        m("cavebat", "동굴 박쥐", 9, 130, 24, 4, 50, 36, 12...20, .flyer, [("mp0", 0.15), ("hp1", 0.06)]),
        m("skeleton", "해골병사", 10, 230, 30, 8, 34, 52, 18...30, .aggressive, [("hp1", 0.1), ("armor2", 0.015), ("sword2", 0.008), ("sword3", 0.008)]),
        m("skelarcher", "해골 궁수", 12, 190, 34, 6, 30, 70, 22...36, .ranged, [("hp1", 0.1), ("bow2", 0.01), ("bow3", 0.01), ("bow4", 0.01)]),
        m("golem", "골렘", 13, 480, 44, 14, 20, 115, 40...70, .aggressive, [("armor3", 0.02), ("staff2", 0.01), ("staff3", 0.01), ("staff4", 0.01), ("sword4", 0.01)]),
        m("goldslime", "황금 슬라임", 8, 110, 0, 5, 44, 45, 150...320, .coward, [("hp1", 0.3)]),
        m("slimeking", "슬라임 킹", 15, 2600, 40, 10, 34, 1500, 500...800, .boss,
          [("sword5", 0.1), ("bow5", 0.1), ("staff5", 0.1), ("armor4", 0.15), ("hp1", 1)]),
    ]
    private static let byID: [String: RpgMonsterDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func def(_ id: String) -> RpgMonsterDef { byID[id]! }
}

enum RpgMapID: String, Codable, CaseIterable, Sendable {
    case town, field, forest, cave1, cave2, boss, pond
}

enum RpgMapKind: Sendable { case town, field, forest, cave, boss, pond }

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
}

enum RpgMaps {
    private static func p(_ x: Int, _ y: Int, _ to: RpgMapID, _ ax: Int, _ ay: Int, minLevel: Int = 1, hidden: Bool = false) -> RpgPortal {
        RpgPortal(at: RpgTile(x: x, y: y), to: to, arrive: RpgTile(x: ax, y: ay), minLevel: minLevel, hidden: hidden)
    }

    static let all: [RpgMapDef] = [
        RpgMapDef(id: .town, name: "마을", levelText: "안전지대", width: 32, height: 22, kind: .town, seed: 1,
                  portals: [p(30, 11, .field, 4, 14)], monsters: []),
        RpgMapDef(id: .field, name: "초원", levelText: "Lv1~4", width: 46, height: 28, kind: .field, seed: 11,
                  portals: [p(1, 14, .town, 28, 11), p(44, 14, .forest, 4, 15)],
                  monsters: [RpgSpawn(monster: "slime", count: 10), RpgSpawn(monster: "blueslime", count: 5), RpgSpawn(monster: "brownshroom", count: 6)]),
        RpgMapDef(id: .forest, name: "숲", levelText: "Lv4~8", width: 46, height: 30, kind: .forest, seed: 23,
                  portals: [p(1, 15, .field, 41, 14), p(44, 15, .cave1, 4, 13), p(6, 3, .pond, 11, 11, hidden: true)],
                  monsters: [RpgSpawn(monster: "poisonshroom", count: 8), RpgSpawn(monster: "wolf", count: 5), RpgSpawn(monster: "bat", count: 6)]),
        RpgMapDef(id: .cave1, name: "동굴 1층", levelText: "Lv8~12", width: 42, height: 26, kind: .cave, seed: 37,
                  portals: [p(1, 13, .forest, 41, 15), p(40, 13, .cave2, 4, 13)],
                  monsters: [RpgSpawn(monster: "cavebat", count: 8), RpgSpawn(monster: "skeleton", count: 7)]),
        RpgMapDef(id: .cave2, name: "동굴 2층", levelText: "Lv10~14", width: 42, height: 26, kind: .cave, seed: 41,
                  portals: [p(1, 13, .cave1, 37, 13), p(21, 1, .boss, 14, 17, minLevel: 12)],
                  monsters: [RpgSpawn(monster: "skelarcher", count: 6), RpgSpawn(monster: "golem", count: 4), RpgSpawn(monster: "skeleton", count: 4)]),
        RpgMapDef(id: .boss, name: "슬라임 킹의 둥지", levelText: "보스", width: 28, height: 22, kind: .boss, seed: 53,
                  portals: [p(14, 20, .cave2, 21, 4)], monsters: [RpgSpawn(monster: "slimeking", count: 1)]),
        RpgMapDef(id: .pond, name: "비밀 연못", levelText: "보너스", width: 24, height: 16, kind: .pond, seed: 61,
                  portals: [p(11, 14, .forest, 6, 6)], monsters: [RpgSpawn(monster: "goldslime", count: 3)]),
    ]
    static func def(_ id: RpgMapID) -> RpgMapDef { all.first { $0.id == id }! }

    static func xpNeeded(_ level: Int) -> Int { 15 * level + 5 * level * level }
    static let maxLevel = 20
}

import Foundation

// SPIKE: 소재, 제작, 버프 소모품. Monsters drop crafting materials by level band; the smith turns them (plus gold)
// into rings, amulets, buff items and enhancement stones. Buff items run for a while after use.

struct RpgBuffDef: Sendable {
    let id: String
    let name: String
    let seconds: Double
    let desc: String
}

enum RpgBuffs {
    static let all: [RpgBuffDef] = [
        RpgBuffDef(id: "atk", name: "공격 비약", seconds: 60, desc: "60초간 공격력 +30%"),
        RpgBuffDef(id: "xp", name: "경험치 두루마리", seconds: 600, desc: "10분간 경험치 +50%"),
        RpgBuffDef(id: "luck", name: "행운의 부적", seconds: 600, desc: "10분간 드롭 확률 +30%"),
        RpgBuffDef(id: "speed", name: "신속의 비약", seconds: 60, desc: "60초간 이동속도 +25%"),
        RpgBuffDef(id: "pet", name: "펫 간식", seconds: 300, desc: "5분간 펫의 공격과 필살기가 강해져요"),
    ]
    static func def(_ id: String) -> RpgBuffDef? { all.first { $0.id == id } }
}

enum RpgMaterials {
    /// Which monster levels drop which material (bands overlap, so a level can drop several kinds).
    static let bands: [(item: String, levels: ClosedRange<Int>)] = [
        ("mat_jelly", 1...8), ("mat_hide", 5...14), ("mat_bone", 9...20), ("mat_sting", 15...28),
        ("mat_ice", 22...34), ("mat_magma", 30...42), ("mat_dark", 38...52), ("mat_wraith", 44...60),
    ]
    /// Chance that a kill drops one material.
    static let chance = 0.16

    /// One material for a monster of `level`, picked with `roll` (any integer), or nil below level 1.
    static func pick(level: Int, roll: Int) -> String? {
        let fits = bands.filter { $0.levels.contains(level) }
        guard !fits.isEmpty else { return nil }
        return fits[abs(roll) % fits.count].item
    }
}

struct RpgRecipe: Sendable {
    let id: String
    let output: String
    let count: Int
    let materials: [String: Int]
    let gold: Int
}

enum RpgRecipes {
    private static let ladder = ["mat_jelly", "mat_hide", "mat_bone", "mat_sting", "mat_ice", "mat_magma", "mat_dark", "mat_wraith"]

    static let all: [RpgRecipe] = {
        var list: [RpgRecipe] = []
        // Rings and amulets: tier n needs the n-th and (n+1)-th material, the last one needs enhancement stones too.
        let ringGold = [200, 800, 3000, 7000, 20000, 40000, 90000, 200_000]
        let amuletGold = [200, 700, 2800, 6500, 18000, 38000, 85000, 190_000]
        let ringMats: [[String: Int]] = [
            ["mat_jelly": 5, "mat_hide": 3], ["mat_hide": 6, "mat_bone": 4], ["mat_bone": 8, "mat_sting": 5], ["mat_sting": 8, "mat_ice": 5],
            ["mat_ice": 8, "mat_magma": 6], ["mat_magma": 10, "mat_dark": 6], ["mat_dark": 12, "mat_wraith": 8], ["mat_wraith": 15, "stone": 20],
        ]
        let amuletMats: [[String: Int]] = [
            ["mat_jelly": 6, "mat_hide": 2], ["mat_hide": 6, "mat_bone": 3], ["mat_bone": 8, "mat_sting": 4], ["mat_sting": 8, "mat_ice": 4],
            ["mat_ice": 8, "mat_magma": 5], ["mat_magma": 10, "mat_dark": 5], ["mat_dark": 12, "mat_wraith": 6], ["mat_wraith": 15, "stone": 20],
        ]
        for t in 0..<8 { list.append(RpgRecipe(id: "ring\(t)", output: "ring\(t)", count: 1, materials: ringMats[t], gold: ringGold[t])) }
        for t in 0..<8 { list.append(RpgRecipe(id: "amulet\(t)", output: "amulet\(t)", count: 1, materials: amuletMats[t], gold: amuletGold[t])) }
        list += [
            RpgRecipe(id: "buff_atk", output: "buff_atk", count: 3, materials: ["mat_jelly": 3, "mat_sting": 2], gold: 100),
            RpgRecipe(id: "buff_xp", output: "buff_xp", count: 2, materials: ["mat_bone": 4, "mat_ice": 2], gold: 300),
            RpgRecipe(id: "buff_luck", output: "buff_luck", count: 2, materials: ["mat_hide": 4, "mat_magma": 2], gold: 250),
            RpgRecipe(id: "buff_speed", output: "buff_speed", count: 3, materials: ["mat_hide": 2, "mat_jelly": 3], gold: 80),
            RpgRecipe(id: "stone", output: "stone", count: 3, materials: ["mat_bone": 4, "mat_ice": 2], gold: 500),
            RpgRecipe(id: "buff_pet", output: "buff_pet", count: 3, materials: ["mat_jelly": 4, "mat_hide": 3], gold: 120),
            RpgRecipe(id: "scroll_protect", output: "scroll_protect", count: 1, materials: ["mat_magma": 3, "mat_dark": 2], gold: 3000),
        ]
        let helmetMats: [[String: Int]] = [
            ["mat_jelly": 4, "mat_hide": 4], ["mat_hide": 5, "mat_bone": 5], ["mat_bone": 7, "mat_sting": 5], ["mat_sting": 7, "mat_ice": 5],
            ["mat_ice": 7, "mat_magma": 6], ["mat_magma": 9, "mat_dark": 6], ["mat_dark": 11, "mat_wraith": 7], ["mat_wraith": 14, "stone": 18],
        ]
        let bootsMats: [[String: Int]] = [
            ["mat_jelly": 3, "mat_hide": 5], ["mat_hide": 6, "mat_bone": 3], ["mat_bone": 6, "mat_sting": 6], ["mat_sting": 6, "mat_ice": 6],
            ["mat_ice": 6, "mat_magma": 7], ["mat_magma": 8, "mat_dark": 7], ["mat_dark": 10, "mat_wraith": 8], ["mat_wraith": 13, "stone": 18],
        ]
        let gearGold = [150, 700, 2600, 6000, 17000, 36000, 80000, 180_000]
        for t in 0..<8 { list.append(RpgRecipe(id: "helmet\(t)", output: "helmet\(t)", count: 1, materials: helmetMats[t], gold: gearGold[t])) }
        for t in 0..<8 { list.append(RpgRecipe(id: "boots\(t)", output: "boots\(t)", count: 1, materials: bootsMats[t], gold: gearGold[t])) }
        return list
    }()

    static func def(_ id: String) -> RpgRecipe? { all.first { $0.id == id } }
}

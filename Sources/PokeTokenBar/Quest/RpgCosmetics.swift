import Foundation

// SPIKE: 외관 아이템 (메이플의 캐시 아이템처럼). They change only how a hero looks, never a stat. They are not inventory items: a
// character owns a `wardrobe` of cosmetic ids and wears at most one per slot (`worn`). Sources: the 의상실 shop (gold), the gacha
// (gold, with a pity counter), and drops from the continents' monsters and bosses. `RpgCharacterArt` draws what is worn.

enum RpgCosmeticSlot: String, Codable, CaseIterable, Sendable {
    case hat, outfit, cape, weaponSkin, aura, wings, steps, hair, face

    var title: String {
        switch self {
        case .hat: return "모자"
        case .outfit: return "옷"
        case .cape: return "망토"
        case .weaponSkin: return "무기 스킨"
        case .aura: return "오라"
        case .wings: return "날개"
        case .steps: return "발자국"
        case .hair: return "헤어"
        case .face: return "얼굴"
        }
    }
}

/// A look shared by every piece of a set: the colours the art is drawn in.
struct RpgCosmeticTheme: Sendable {
    typealias RGB = (r: Int, g: Int, b: Int)
    let key: String
    let name: String
    /// 0 starter … 4 mythic: sets the rarity of its pieces and how it is obtained.
    let tier: Int
    let main: RGB
    let trim: RGB
    let glow: RGB
}

struct RpgCosmetic: Sendable {
    let id: String
    let name: String
    let slot: RpgCosmeticSlot
    /// 0 일반 … 4 신화 (same scale as items).
    let rarity: Int
    /// Theme key, or "style" for hair and faces.
    let theme: String
    var price: Int { RpgCosmetics.prices[min(rarity, 4)] }
    /// Sold in the 의상실.
    let shop: Bool
    /// Can come out of the gacha.
    let gacha: Bool
    /// Index among a slot's shapes, for hair and face styles.
    var style = 0
}

enum RpgCosmetics {
    static let prices = [800, 3000, 9000, 30000, 100_000]
    static let gachaCost = 3000
    static let gachaTenCost = 27_000
    /// A pull that has not reached 영웅 or better this many times in a row is guaranteed one.
    static let pity = 30
    static let maxWardrobe = 400
    static let rarityName = ["일반", "희귀", "영웅", "전설", "신화"]
    /// Gacha odds in percent for rarity 0…3 (the pity rule supplies the rest); a pull is always one cosmetic.
    static let gachaOdds = [55, 30, 12, 3]

    static let themes: [RpgCosmeticTheme] = [
        RpgCosmeticTheme(key: "classic", name: "모험가", tier: 0, main: (176, 124, 78), trim: (240, 220, 160), glow: (255, 240, 190)),
        RpgCosmeticTheme(key: "festival", name: "축제", tier: 1, main: (232, 96, 120), trim: (255, 224, 120), glow: (255, 190, 220)),
        RpgCosmeticTheme(key: "coast", name: "해적", tier: 1, main: (40, 70, 130), trim: (230, 190, 70), glow: (120, 200, 255)),
        RpgCosmeticTheme(key: "jungle", name: "탐험가", tier: 1, main: (70, 130, 60), trim: (230, 200, 110), glow: (170, 255, 140)),
        RpgCosmeticTheme(key: "mushroom", name: "버섯 요정", tier: 2, main: (214, 70, 80), trim: (255, 245, 225), glow: (255, 160, 190)),
        RpgCosmeticTheme(key: "ancient", name: "고대 학자", tier: 2, main: (200, 170, 100), trim: (60, 150, 160), glow: (130, 255, 230)),
        RpgCosmeticTheme(key: "crystal", name: "수정 광부", tier: 2, main: (110, 90, 200), trim: (200, 170, 255), glow: (200, 150, 255)),
        RpgCosmeticTheme(key: "factory", name: "기계공", tier: 2, main: (110, 120, 140), trim: (240, 140, 50), glow: (255, 190, 90)),
        RpgCosmeticTheme(key: "skyisle", name: "천공 기사", tier: 3, main: (235, 240, 250), trim: (240, 200, 90), glow: (190, 225, 255)),
        RpgCosmeticTheme(key: "undersea", name: "해신", tier: 3, main: (30, 150, 170), trim: (220, 245, 230), glow: (110, 255, 220)),
        RpgCosmeticTheme(key: "haunted", name: "유령", tier: 3, main: (80, 70, 110), trim: (190, 200, 230), glow: (160, 150, 255)),
        RpgCosmeticTheme(key: "underworld", name: "마족", tier: 3, main: (140, 30, 40), trim: (255, 120, 40), glow: (255, 90, 60)),
        RpgCosmeticTheme(key: "frost", name: "설원 전사", tier: 3, main: (170, 215, 245), trim: (255, 255, 255), glow: (200, 240, 255)),
        RpgCosmeticTheme(key: "celestial", name: "천사", tier: 4, main: (255, 250, 230), trim: (255, 210, 90), glow: (255, 240, 170)),
        RpgCosmeticTheme(key: "rift", name: "차원 방랑자", tier: 4, main: (40, 24, 80), trim: (200, 90, 255), glow: (170, 90, 255)),
        RpgCosmeticTheme(key: "chaos", name: "혼돈 군주", tier: 4, main: (20, 14, 30), trim: (255, 60, 150), glow: (255, 70, 170)),
    ]

    static func theme(_ key: String) -> RpgCosmeticTheme? { themes.first { $0.key == key } }

    private static let hairStyles = ["단발", "포니테일", "트윈테일", "장발", "모히칸", "올백", "땋은 머리", "곱슬머리"]
    private static let faces = ["윙크", "졸린 눈", "반짝이는 눈", "무표정", "웃는 눈", "사나운 눈"]

    /// Every cosmetic: each theme's pieces (hat, outfit, cape, weapon skin; aura and steps from tier 2; wings from tier 3), then hair and face styles.
    static let all: [RpgCosmetic] = {
        var list: [RpgCosmetic] = []
        for t in themes {
            func add(_ slot: RpgCosmeticSlot, _ word: String, bump: Int = 0, shop: Bool) {
                list.append(RpgCosmetic(id: "\(slot.rawValue)_\(t.key)", name: "\(t.name) \(word)", slot: slot, rarity: min(4, t.tier + bump), theme: t.key,
                                        shop: shop && t.tier <= 2, gacha: t.tier >= 1))
            }
            add(.hat, "모자", shop: true)
            add(.outfit, "의상", shop: true)
            add(.cape, "망토", shop: true)
            add(.weaponSkin, "무기 스킨", shop: true)
            if t.tier >= 2 { add(.aura, "오라", bump: 1, shop: false); add(.steps, "발자국", shop: false) }
            if t.tier >= 3 { add(.wings, "날개", bump: 1, shop: false) }
        }
        for (i, n) in hairStyles.enumerated() { list.append(RpgCosmetic(id: "hair_\(i)", name: n, slot: .hair, rarity: i < 4 ? 0 : 1, theme: "style", shop: true, gacha: false, style: i)) }
        for (i, n) in faces.enumerated() { list.append(RpgCosmetic(id: "face_\(i)", name: n, slot: .face, rarity: i < 3 ? 0 : 1, theme: "style", shop: true, gacha: false, style: i)) }
        return list
    }()

    private static let byID: [String: RpgCosmetic] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func def(_ id: String) -> RpgCosmetic? { byID[id] }
    static var shop: [RpgCosmetic] { all.filter(\.shop) }

    /// Saved wardrobes and worn sets are untrusted: unknown ids go, the wardrobe is capped, and a slot only holds an owned cosmetic of that slot.
    static func clean(wardrobe: [String]?, worn: [String: String]?) -> (Set<String>, [String: String]) {
        let owned = Set((wardrobe ?? []).filter { byID[$0] != nil }.prefix(maxWardrobe))
        var out: [String: String] = [:]
        for (slot, id) in worn ?? [:] { if owned.contains(id), byID[id]?.slot.rawValue == slot { out[slot] = id } }
        return (owned, out)
    }

    /// The region (and so theme) a monster belongs to, if any.
    private static let monsterTheme: [String: (theme: String, boss: Bool)] = {
        var m: [String: (String, Bool)] = [:]
        for r in RpgRegions.all { for mo in r.monsters { m[mo.id] = (r.id, mo.behavior == .boss) } }
        return m
    }()

    /// Chance (0…1) that a kill of `monster` drops one of its region's cosmetics, and the theme.
    static func dropChance(_ monster: RpgMonsterDef) -> (theme: String, chance: Double)? {
        guard let t = monsterTheme[monster.id] else { return nil }
        return (t.theme, t.boss ? 0.35 : 0.0004)
    }

    /// One cosmetic of `theme` the player does not own yet (nil when they own all), chosen with `roll` (any integer).
    static func newPiece(theme: String, owned: Set<String>, roll: Int) -> String? {
        let pool = all.filter { $0.theme == theme && !owned.contains($0.id) }
        return pool.isEmpty ? nil : pool[abs(roll) % pool.count].id
    }

    /// Rarity of one gacha pull from a roll in 0..<100, forced to 영웅 or better when the pity counter is full.
    static func gachaRarity(roll: Int, pityCount: Int) -> Int {
        var acc = 0
        var r = 3
        for (k, p) in gachaOdds.enumerated() { acc += p; if roll < acc { r = k; break } }
        // Odds above sum to 100 (55+30+12+3); mythic only comes from pity upgrades and drops.
        if pityCount + 1 >= pity, r < 2 { r = 2 }
        return r
    }

    /// The piece a pull gives: a random gacha cosmetic of that rarity.
    static func gachaPiece(rarity: Int, roll: Int) -> String {
        let pool = all.filter { $0.gacha && $0.rarity == rarity }
        let any = pool.isEmpty ? all.filter(\.gacha) : pool
        return any[abs(roll) % any.count].id
    }

    /// Gold back for a duplicate.
    static func duplicateRefund(_ c: RpgCosmetic) -> Int { c.price / 3 }
}

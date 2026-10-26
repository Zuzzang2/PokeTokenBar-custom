import Foundation

// SPIKE: 3차·4차 전직 and data-driven skills. A character's `job` is its branch (1 or 2) and `tier` how far along it is:
// 1 = 2차 (Lv20), 2 = 3차 (Lv45), 3 = 4차 (Lv70). Each promotion costs gold at the 전직관, raises the job multipliers and teaches
// two skills. Those skills carry an `RpgSkillFX` template instead of a hand-written case in `castSkill`, so new skills are data.

/// How a skill plays out. `RpgWorld.castTemplate` turns it into shots, scheduled blasts, buffs and heals.
struct RpgSkillFX: Sendable {
    enum Shape: Sendable {
        /// `count` projectiles fanned by `spread` radians.
        case shot
        /// `count` blasts of `radius` at `dist` ahead (0 = on the caster), one every `interval` seconds.
        case zone
        /// `count` meteors at random spots within `dist` of the caster.
        case rain
        /// One strike on each of the nearest `count` monsters within `radius`.
        case chain
        /// `count` blasts in a line, `dist` apart.
        case line
        /// Buffs (`flags`) and heals (`heal` of max HP) for allies within `radius` for `seconds`.
        case buff
    }

    var shape: Shape
    var count = 1
    var radius = 40.0
    var spread = 0.1
    var dist = 0.0
    var interval = 0.2
    var speed = 320.0
    var range = 240.0
    var big = false
    var element: RpgElement?
    var stun = 0.0
    var heal = 0.0
    var seconds = 12.0
    /// Any of "rage", "iron", "focus", "frenzy", "stealth".
    var flags: [String] = []
}

extension RpgSkillFX {
    static func shot(_ n: Int, spread: Double = 0.1, big: Bool = false, speed: Double = 320, range: Double = 240, _ e: RpgElement? = nil) -> Self {
        Self(shape: .shot, count: n, spread: spread, speed: speed, range: range, big: big, element: e)
    }
    static func zone(_ n: Int, r: Double, ahead: Double = 0, every: Double = 0.2, stun: Double = 0, _ e: RpgElement? = nil) -> Self {
        Self(shape: .zone, count: n, radius: r, dist: ahead, interval: every, element: e, stun: stun)
    }
    static func rain(_ n: Int, r: Double = 30, scatter: Double = 110, _ e: RpgElement? = nil) -> Self {
        Self(shape: .rain, count: n, radius: r, dist: scatter, element: e)
    }
    static func chain(_ n: Int, reach: Double = 180, stun: Double = 0, _ e: RpgElement? = nil) -> Self {
        Self(shape: .chain, count: n, radius: reach, element: e, stun: stun)
    }
    static func line(_ n: Int, gap: Double = 16, r: Double = 18, every: Double = 0.05, stun: Double = 0, _ e: RpgElement? = nil) -> Self {
        Self(shape: .line, count: n, radius: r, dist: gap, interval: every, element: e, stun: stun)
    }
    static func buff(_ flags: [String], seconds: Double = 12, heal: Double = 0, r: Double = 90) -> Self {
        Self(shape: .buff, radius: r, heal: heal, seconds: seconds, flags: flags)
    }
}

enum RpgTiers {
    /// Level and gold needed for tier 2 (3차) and tier 3 (4차).
    static let levels = [2: 45, 3: 70]
    static let gold = [2: 30_000, 3: 250_000]
    /// Levels at which a tier's two skills are learned.
    static let skillLevels = [2: [45, 55], 3: [70, 85]]
    static let maxTier = 3

    /// How far each tier pushes the 2차 job's multipliers (and an all-round bonus on top).
    private static let growth: [Int: Double] = [1: 1, 2: 1.6, 3: 2.3]
    private static let flat: [Int: Double] = [1: 1, 2: 1.12, 3: 1.25]

    /// `names[branch]` = [3차 name, 4차 name]; blurbs in `blurbs`.
    private static let names: [String: [String]] = [
        "warrior1": ["근위기사", "천군 대장"], "warrior2": ["파괴자", "불멸의 광왕"],
        "archer1": ["스나이퍼", "천리안 명사수"], "archer2": ["폭풍 사수", "숲의 군주"],
        "mage1": ["불꽃 대마도사", "화염의 군주"], "mage2": ["서리 대마도사", "빙설의 여왕"],
        "rogue1": ["그림자 칼날", "밤의 군주"], "rogue2": ["맹독 연금술사", "역병의 군주"],
        "cleric1": ["성전사", "신성 군주"], "cleric2": ["추기경", "대천사"],
        "monk1": ["투신", "천무 대종사"], "monk2": ["선승", "열반의 성자"],
        "summoner1": ["리치", "죽음의 군주"], "summoner2": ["드래곤 테이머", "신수의 주인"],
    ]

    private static func key(_ cls: RpgClass, _ job: Int) -> String { "\(cls.rawValue)\(job)" }

    static func skillIDs(_ cls: RpgClass, _ job: Int, tier: Int) -> [String] {
        let c = String(cls.rawValue.prefix(2))
        return ["t\(tier)_\(c)\(job)a", "t\(tier)_\(c)\(job)b"]
    }

    /// The job definition for a branch at a tier: tier 1 is the stored 2차 job, higher tiers are derived from it.
    static func def(_ cls: RpgClass, _ job: Int, tier: Int) -> RpgJobDef? {
        guard let base = RpgJobs.all.first(where: { $0.cls == cls && $0.job == job }) else { return nil }
        guard tier > 1 else { return base }
        guard let g = growth[tier], let f = flat[tier], let nm = names[key(cls, job)], nm.indices.contains(tier - 2) else { return nil }
        func up(_ x: Double) -> Double { (1 + (x - 1) * g) * f }
        return RpgJobDef(cls: cls, job: job, name: nm[tier - 2], blurb: "\(base.name)의 길 끝에서 얻는 \(tier + 1)차 직업. 모든 능력이 한층 더 강해져요.",
                         hp: up(base.hp), mp: up(base.mp), attack: up(base.attack), defense: up(base.defense),
                         crit: base.crit * g + 0.03 * Double(tier - 1), interval: 1 + (base.interval - 1) * g,
                         skills: skillIDs(cls, job, tier: tier), tier: tier)
    }

    private static func s(_ id: String, _ name: String, _ cls: RpgClass, _ lv: Int, _ mp: Int, _ cd: Double, _ power: Double, _ desc: String, _ fx: RpgSkillFX) -> RpgSkillDef {
        RpgSkillDef(id: id, name: name, cls: cls, minLevel: lv, mp: mp, cooldown: cd, power: power, maxLevel: 10, price: 0, starter: false, desc: desc, fx: fx)
    }

    /// Two skills per tier per branch, ids from `skillIDs`.
    static let skills: [RpgSkillDef] = {
        var out: [RpgSkillDef] = []
        func add(_ cls: RpgClass, _ job: Int, _ rows: [(String, Int, Double, Double, String, RpgSkillFX)]) {
            for tier in [2, 3] {
                let ids = skillIDs(cls, job, tier: tier)
                for k in 0..<2 {
                    let r = rows[(tier - 2) * 2 + k]
                    out.append(s(ids[k], r.0, cls, skillLevels[tier]![k], r.1, r.2, r.3, r.4, r.5))
                }
            }
        }
        add(.warrior, 1, [
            ("대지 가르기", 36, 10, 4.0, "전방 일직선을 갈라 기절시킨다", .line(7, gap: 18, r: 20, stun: 1.0)),
            ("철벽 진형", 50, 30, 0, "주변 동료 15초간 피해 감소 + HP 30% 회복", .buff(["iron"], seconds: 15, heal: 0.3, r: 100)),
            ("신검 강림", 64, 14, 6.5, "하늘에서 신검이 여덟 번 떨어진다", .rain(8, r: 32, .holy)),
            ("불굴의 의지", 80, 45, 0, "20초간 피해 감소·공격력 상승 + HP 50% 회복", .buff(["iron", "rage"], seconds: 20, heal: 0.5, r: 110)),
        ])
        add(.warrior, 2, [
            ("분쇄의 질주", 38, 9, 4.4, "전방을 갈아엎으며 돌진하는 연타", .line(8, gap: 16, r: 22, .fire)),
            ("피의 갈증", 52, 32, 0, "14초간 광기와 공격력 상승", .buff(["frenzy", "rage"], seconds: 14)),
            ("학살의 폭풍", 66, 16, 2.6, "사방을 여덟 번 휩쓴다", .zone(8, r: 62, every: 0.14)),
            ("광왕의 포효", 84, 48, 7.0, "광기에 빠져 적들을 차례로 베어 넘긴다", .chain(10, reach: 190, stun: 0.5)),
        ])
        add(.archer, 1, [
            ("관통 저격", 36, 9, 7.0, "화면 끝까지 꿰뚫는 단 한 발", .shot(1, big: true, speed: 520, range: 440)),
            ("표식 난사", 50, 12, 3.4, "정밀한 관통 화살 다섯 발", .shot(5, spread: 0.05, big: true, speed: 420, range: 320)),
            ("일격필살", 64, 20, 13.0, "모든 것을 건 필살의 한 발", .shot(1, big: true, speed: 560, range: 480)),
            ("별빛 사격", 80, 26, 5.2, "별빛 화살이 열 번 쏟아진다", .rain(10, r: 26, .cosmic)),
        ])
        add(.archer, 2, [
            ("화살비", 38, 11, 4.2, "하늘에서 화살 여덟 발이 쏟아진다", .rain(8, r: 28, .wind)),
            ("독화살 난사", 52, 13, 1.7, "독화살 열두 발을 넓게 퍼붓는다", .shot(12, spread: 0.12, speed: 280, range: 220, .poison)),
            ("태풍 사격", 66, 15, 1.4, "화살 스무 발이 부채꼴로 폭풍처럼 날아간다", .shot(20, spread: 0.18, speed: 300, range: 230, .wind)),
            ("숲의 심판", 84, 24, 3.6, "숲의 힘이 앞쪽을 열 번 내리친다", .zone(10, r: 58, ahead: 80, every: 0.18, .wind)),
        ])
        add(.mage, 1, [
            ("용암 분출", 40, 10, 4.2, "전방 일직선에서 용암이 솟구친다", .line(6, gap: 20, r: 22, every: 0.07, .fire)),
            ("화염 구체", 54, 14, 4.6, "불의 구체가 일곱 번 떨어진다", .rain(7, r: 32, .fire)),
            ("메테오 스웜", 68, 22, 5.8, "열두 개의 운석이 쏟아진다", .rain(12, r: 34, scatter: 120, .fire)),
            ("태양 폭발", 90, 36, 9.0, "자신을 중심으로 태양이 세 번 폭발한다", .zone(3, r: 92, every: 0.3, .fire)),
        ])
        add(.mage, 2, [
            ("눈보라", 40, 10, 2.8, "주변에 눈보라가 여섯 번 몰아친다", .zone(6, r: 80, every: 0.3, .ice)),
            ("빙산 낙하", 54, 14, 4.6, "거대한 얼음덩이가 여섯 번 떨어진다", .rain(6, r: 36, .ice)),
            ("절대영도", 68, 24, 4.4, "주변 모든 것이 얼어붙는다", .zone(4, r: 112, every: 0.35, stun: 0.8, .ice)),
            ("얼음 군주의 창", 90, 32, 4.0, "얼음 창 일곱 자루를 던진다", .shot(7, spread: 0.09, big: true, speed: 360, range: 300, .ice)),
        ])
        add(.rogue, 1, [
            ("연환 암살", 36, 9, 3.6, "근처 적들을 열 번 연달아 벤다", .chain(10, reach: 180, .cosmic)),
            ("혈풍", 50, 12, 1.8, "순식간에 다섯 번 휘몰아친다", .zone(5, r: 52, every: 0.08, .wind)),
            ("죽음의 무도", 64, 18, 4.4, "열네 명을 차례로 베어 넘긴다", .chain(14, reach: 200, stun: 0.4, .cosmic)),
            ("그림자 분신", 80, 40, 0, "12초간 은신하고 공격 속도 상승", .buff(["stealth", "focus"], seconds: 12)),
        ])
        add(.rogue, 2, [
            ("독무 확산", 38, 11, 2.2, "앞쪽에서 독안개가 여덟 번 터진다", .zone(8, r: 60, ahead: 50, every: 0.22, .poison)),
            ("산성 폭탄", 52, 14, 4.2, "산성 폭탄 여섯 개를 던진다", .rain(6, r: 34, .poison)),
            ("대역병", 66, 20, 2.0, "역병이 주변에 열 번 퍼진다", .zone(10, r: 104, every: 0.4, .poison)),
            ("독왕의 송곳니", 84, 28, 4.8, "독 이빨이 여덟 명을 문다", .chain(8, reach: 190, stun: 0.4, .poison)),
        ])
        add(.cleric, 1, [
            ("성광 일섬", 38, 9, 4.2, "빛의 칼날이 일직선으로 뻗는다", .line(6, gap: 20, r: 20, .holy)),
            ("수호의 서약", 52, 30, 0, "주변 동료 15초간 피해 감소 + HP 20% 회복", .buff(["iron"], seconds: 15, heal: 0.2, r: 100)),
            ("천벌", 66, 15, 5.6, "하늘에서 여덟 번 벼락이 떨어진다", .rain(8, r: 30, .holy)),
            ("신성 불가침", 82, 45, 0, "12초간 피해 감소·공격력 상승 + HP 40% 회복", .buff(["iron", "rage"], seconds: 12, heal: 0.4, r: 110)),
        ])
        add(.cleric, 2, [
            ("집단 치유", 44, 12, 0, "주변 동료 HP 60% 회복", .buff([], seconds: 0, heal: 0.6, r: 120)),
            ("천상의 빛", 58, 14, 3.0, "성스러운 빛이 세 번 번지며 동료를 회복", .zone(3, r: 92, every: 0.3, .holy)),
            ("부활의 노래", 72, 40, 0, "주변 동료 HP를 전부 회복", .buff([], seconds: 0, heal: 1.0, r: 140)),
            ("천사 강림", 90, 36, 5.2, "천사들이 열 번 내려와 심판한다", .rain(10, r: 30, scatter: 120, .holy)),
        ])
        add(.monk, 1, [
            ("연환 폭권", 36, 8, 2.2, "전방을 여덟 번 연타한다", .zone(8, r: 38, ahead: 30, every: 0.07)),
            ("충격파", 50, 11, 3.6, "충격파가 일직선으로 번진다", .line(7, gap: 20, r: 22, every: 0.05, .wind)),
            ("천지 붕괴", 64, 18, 4.0, "하늘과 땅을 무너뜨려 기절시킨다", .zone(5, r: 102, every: 0.25, stun: 0.5)),
            ("무극 권", 80, 24, 5.4, "열두 명을 차례로 날려버린다", .chain(12, reach: 190, stun: 0.3)),
        ])
        add(.monk, 2, [
            ("금강불괴", 44, 30, 0, "18초간 피해 감소 + HP 30% 회복", .buff(["iron"], seconds: 18, heal: 0.3, r: 10)),
            ("나한의 일갈", 58, 14, 2.4, "일갈이 주변을 밀쳐내며 기절시킨다", .zone(2, r: 84, every: 0.2, stun: 1.2, .holy)),
            ("불멸의 몸", 72, 45, 0, "20초간 피해 감소 + HP 60% 회복", .buff(["iron"], seconds: 20, heal: 0.6, r: 110)),
            ("해탈 장풍", 90, 24, 5.0, "황금 장풍 세 줄기를 날린다", .shot(3, spread: 0.12, big: true, speed: 340, range: 300, .holy)),
        ])
        add(.summoner, 1, [
            ("망령 군단", 38, 11, 2.0, "망령들이 앞쪽을 여덟 번 휩쓴다", .zone(8, r: 52, ahead: 60, every: 0.2, .cosmic)),
            ("뼈 창", 52, 12, 3.8, "땅에서 뼈 창이 일렬로 솟는다", .line(8, gap: 18, r: 20, every: 0.06, .poison)),
            ("묵시록", 66, 24, 5.0, "종말의 운석 열두 개가 떨어진다", .rain(12, r: 34, scatter: 120, .cosmic)),
            ("영혼 수확", 84, 26, 5.6, "열두 명의 영혼을 차례로 거둔다", .chain(12, reach: 200, .cosmic)),
        ])
        add(.summoner, 2, [
            ("화룡 강림", 40, 11, 4.0, "화룡이 앞쪽 일직선을 불태운다", .line(7, gap: 20, r: 28, every: 0.06, .fire)),
            ("야수 대군", 54, 13, 2.6, "야수 무리가 앞쪽을 여섯 번 덮친다", .zone(6, r: 52, ahead: 40, every: 0.2)),
            ("신수 강림", 68, 22, 5.0, "신수가 하늘에서 열 번 내리꽂는다", .rain(10, r: 32, scatter: 120, .wind)),
            ("정령 대폭풍", 86, 30, 3.0, "정령들이 주변을 여섯 번 휘몰아친다", .zone(6, r: 112, every: 0.3, .wind)),
        ])
        return out
    }()
}

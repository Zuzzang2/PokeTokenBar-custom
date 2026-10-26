import CoreGraphics
import Foundation

// SPIKE: 2차 전직. At Lv20 the town's 전직관 lets a character pick one of two advanced jobs for its class.
// `RpgPlayer.cls` stays the base class (sprites, weapons, the 24 base skills); `RpgPlayer.job` is 0 before
// advancing and 1 or 2 after. A job multiplies the class stats and teaches two skills: the first on
// advancing, the second at Lv30.

struct RpgJobDef: Sendable {
    let cls: RpgClass
    let job: Int
    let name: String
    let blurb: String
    let hp: Double, mp: Double, attack: Double, defense: Double
    let crit: Double
    /// Multiplier on the attack interval (below 1 attacks faster).
    let interval: Double
    /// Skills taught at Lv20 and Lv30.
    let skills: [String]
}

enum RpgJobs {
    static let advanceLevel = 20
    static let secondSkillLevel = 30

    static let all: [RpgJobDef] = [
        RpgJobDef(cls: .warrior, job: 1, name: "기사", blurb: "방패로 버티며 적을 묶는 수호자. HP·방어력이 크게 올라요.",
                  hp: 1.35, mp: 1, attack: 0.95, defense: 1.4, crit: 0, interval: 1, skills: ["j_bash", "j_aegis"]),
        RpgJobDef(cls: .warrior, job: 2, name: "광전사", blurb: "방어를 버리고 공격에 모든 걸 건 전사. 공격력·치명타가 올라요.",
                  hp: 1.1, mp: 1, attack: 1.25, defense: 0.9, crit: 0.08, interval: 1, skills: ["j_bloodslash", "j_frenzy"]),
        RpgJobDef(cls: .archer, job: 1, name: "저격수", blurb: "한 발에 모든 걸 건 사수. 공격력·치명타가 오르고 연사는 느려져요.",
                  hp: 1, mp: 1, attack: 1.2, defense: 1, crit: 0.12, interval: 1.1, skills: ["j_snipe", "j_deadeye"]),
        RpgJobDef(cls: .archer, job: 2, name: "레인저", blurb: "화살을 쏟아붓는 사냥꾼. 공격속도가 빨라지고 그물을 써요.",
                  hp: 1.05, mp: 1, attack: 1.05, defense: 1, crit: 0.04, interval: 0.8, skills: ["j_volley", "j_net"]),
        RpgJobDef(cls: .mage, job: 1, name: "화염술사", blurb: "모든 걸 불태우는 마법사. 공격력·MP가 올라요.",
                  hp: 1, mp: 1.1, attack: 1.25, defense: 1, crit: 0, interval: 1, skills: ["j_inferno", "j_firestorm"]),
        RpgJobDef(cls: .mage, job: 2, name: "빙결술사", blurb: "적을 얼려 다루는 마법사. HP·MP가 오르고 광역 둔화를 써요.",
                  hp: 1.15, mp: 1.3, attack: 1.05, defense: 1, crit: 0, interval: 1, skills: ["j_frost", "j_glacier"]),
    ]

    /// Palette swaps on the class sprite so each advanced job looks different (knight blue cape, berserker dark red, ...).
    @MainActor static func tint(_ cls: RpgClass, _ job: Int) -> [Character: CGColor] {
        func c(_ r: Int, _ g: Int, _ b: Int) -> CGColor { RpgArt.rgb(r, g, b) }
        switch (cls, job) {
        case (.warrior, 1): return ["R": c(60, 110, 210), "r": c(36, 70, 150), "Y": c(255, 230, 120)]
        case (.warrior, 2): return ["M": c(150, 50, 50), "m": c(100, 30, 30), "R": c(60, 40, 50), "r": c(40, 28, 36)]
        case (.archer, 1): return ["G": c(70, 80, 100), "g": c(44, 52, 70)]
        case (.archer, 2): return ["G": c(200, 140, 50), "g": c(150, 96, 30)]
        case (.mage, 1): return ["P": c(220, 80, 40), "p": c(150, 40, 20)]
        case (.mage, 2): return ["P": c(70, 150, 230), "p": c(40, 100, 170)]
        default: return [:]
        }
    }

    static func options(for cls: RpgClass) -> [RpgJobDef] { all.filter { $0.cls == cls } }
    static func def(_ cls: RpgClass, _ job: Int) -> RpgJobDef? { all.first { $0.cls == cls && $0.job == job } }

    /// Job skills are kept out of `RpgSkills.all` so they never become skill books, shop stock or quest rewards.
    private static func s(_ id: String, _ name: String, _ cls: RpgClass, _ lv: Int, _ mp: Int, _ cd: Double, _ power: Double, _ desc: String) -> RpgSkillDef {
        RpgSkillDef(id: id, name: name, cls: cls, minLevel: lv, mp: mp, cooldown: cd, power: power, maxLevel: 10, price: 0, starter: false, desc: desc)
    }

    static let skills: [RpgSkillDef] = [
        s("j_bash", "방패 강타", .warrior, 20, 16, 6, 2.4, "앞의 적을 방패로 쳐서 기절시킨다"),
        s("j_aegis", "수호의 성역", .warrior, 30, 30, 28, 0, "HP 25% 회복 + 8초간 받는 피해 감소"),
        s("j_bloodslash", "피의 일격", .warrior, 20, 18, 6, 3.2, "앞쪽 넓은 범위를 강하게 벤다"),
        s("j_frenzy", "광기", .warrior, 30, 36, 30, 0, "10초간 공격력 상승 + 회오리검"),
        s("j_snipe", "저격", .archer, 20, 20, 7, 4.2, "아주 멀리 날아가는 강력한 관통 화살"),
        s("j_deadeye", "데드아이", .archer, 30, 34, 14, 2.4, "정밀한 관통 화살 3발"),
        s("j_volley", "속사", .archer, 20, 18, 5, 0.9, "화살 8발을 넓게 퍼붓는다"),
        s("j_net", "사냥꾼의 그물", .archer, 30, 28, 12, 2.2, "앞쪽에 적을 묶는 덫 3개"),
        s("j_inferno", "지옥불", .mage, 20, 24, 8, 1.5, "앞쪽에 불꽃이 6번 폭발한다"),
        s("j_firestorm", "화염 폭풍", .mage, 30, 44, 20, 2.6, "주변에 불의 운석 5개"),
        s("j_frost", "서리 파동", .mage, 20, 22, 7, 1.9, "주변을 얼려 피해와 둔화"),
        s("j_glacier", "빙하", .mage, 30, 44, 18, 0.7, "넓은 얼음 지대를 오래 만든다"),
    ]
}

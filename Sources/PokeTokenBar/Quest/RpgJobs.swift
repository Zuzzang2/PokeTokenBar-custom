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
    /// 1 = 2차 job, 2 = 3차, 3 = 4차 (see `RpgTiers`).
    var tier = 1
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
        RpgJobDef(cls: .rogue, job: 1, name: "암살자", blurb: "그림자처럼 다가가 한 방에 끝내는 암살자. 공격력·치명타가 크게 올라요.",
                  hp: 0.95, mp: 1, attack: 1.25, defense: 0.9, crit: 0.10, interval: 1, skills: ["j_ass1", "j_ass2"]),
        RpgJobDef(cls: .rogue, job: 2, name: "독술사", blurb: "독과 연막으로 적을 말려 죽이는 도적. 공속이 빨라지고 독 스킬을 써요.",
                  hp: 1.05, mp: 1.1, attack: 1.1, defense: 1, crit: 0.04, interval: 0.9, skills: ["j_poi1", "j_poi2"]),
        RpgJobDef(cls: .cleric, job: 1, name: "성기사", blurb: "방패와 신성한 힘으로 앞에서 버티는 성직자. HP·방어가 크게 올라요.",
                  hp: 1.3, mp: 1, attack: 1.1, defense: 1.35, crit: 0, interval: 1, skills: ["j_pal1", "j_pal2"]),
        RpgJobDef(cls: .cleric, job: 2, name: "대주교", blurb: "동료를 살리는 최고의 치유사. MP가 크게 오르고 강력한 회복·축복을 써요.",
                  hp: 1.05, mp: 1.35, attack: 0.95, defense: 1.1, crit: 0, interval: 1, skills: ["j_arc1", "j_arc2"]),
        RpgJobDef(cls: .monk, job: 1, name: "권왕", blurb: "주먹 하나로 정점에 선 격투가. 공격력·공속이 올라요.",
                  hp: 1.1, mp: 1, attack: 1.25, defense: 0.95, crit: 0.06, interval: 0.9, skills: ["j_fk1", "j_fk2"]),
        RpgJobDef(cls: .monk, job: 2, name: "수도승", blurb: "참선으로 몸을 단련한 수도승. HP·방어가 크게 올라요.",
                  hp: 1.3, mp: 1.1, attack: 1, defense: 1.3, crit: 0, interval: 1, skills: ["j_asc1", "j_asc2"]),
        RpgJobDef(cls: .summoner, job: 1, name: "사령술사", blurb: "죽은 자를 부리는 소환사. 공격력·MP가 크게 올라요.",
                  hp: 0.95, mp: 1.2, attack: 1.3, defense: 1, crit: 0.05, interval: 1, skills: ["j_nec1", "j_nec2"]),
        RpgJobDef(cls: .mechanic, job: 1, name: "중화기병", blurb: "화력과 방어를 겸비한 중장비 병사. 공격력·방어력이 올라요.",
                  hp: 1.2, mp: 1, attack: 1.2, defense: 1.25, crit: 0.04, interval: 1.1, skills: ["j_x1a", "j_x1b"]),
        RpgJobDef(cls: .mechanic, job: 2, name: "로봇공학자", blurb: "터렛과 로봇을 부리는 기술자. MP가 크게 오르고 공격이 빨라져요.",
                  hp: 1.1, mp: 1.4, attack: 1.1, defense: 1, crit: 0.05, interval: 0.95, skills: ["j_x2a", "j_x2b"]),
        RpgJobDef(cls: .summoner, job: 2, name: "야수 조련사", blurb: "맹수와 정령왕을 부리는 소환사. HP가 오르고 소환이 강해져요.",
                  hp: 1.25, mp: 1.1, attack: 1.1, defense: 1.1, crit: 0.03, interval: 0.95, skills: ["j_beast1", "j_beast2"]),
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
        case (.rogue, 1): return ["Z": c(60, 40, 70), "z": c(36, 24, 44), "R": c(200, 40, 60)]
        case (.rogue, 2): return ["Z": c(70, 120, 70), "z": c(40, 80, 44), "R": c(170, 230, 80)]
        case (.cleric, 1): return ["W": c(215, 225, 245), "Y": c(120, 170, 255), "C": c(180, 190, 210)]
        case (.cleric, 2): return ["W": c(250, 235, 255), "Y": c(220, 120, 255), "C": c(235, 210, 250)]
        case (.monk, 1): return ["F": c(220, 50, 40), "f": c(255, 160, 80)]
        case (.monk, 2): return ["F": c(60, 120, 200), "f": c(130, 190, 255)]
        case (.summoner, 1): return ["E": c(100, 60, 140), "e": c(60, 30, 90), "A": c(40, 40, 60)]
        case (.summoner, 2): return ["E": c(180, 120, 50), "e": c(120, 76, 30), "A": c(90, 140, 60)]
        case (.mechanic, 1): return ["F": c(90, 100, 120), "f": c(150, 160, 180), "O": c(255, 120, 60)]
        case (.mechanic, 2): return ["F": c(60, 150, 90), "f": c(130, 220, 150), "O": c(120, 255, 200)]
        default: return [:]
        }
    }

    static func options(for cls: RpgClass) -> [RpgJobDef] { all.filter { $0.cls == cls } }
    static func def(_ cls: RpgClass, _ job: Int, tier: Int = 1) -> RpgJobDef? { RpgTiers.def(cls, job, tier: tier) }

    /// Job skills are kept out of `RpgSkills.all` so they never become skill books, shop stock or quest rewards.
    private static func s(_ id: String, _ name: String, _ cls: RpgClass, _ lv: Int, _ mp: Int, _ cd: Double, _ power: Double, _ desc: String, fx: RpgSkillFX? = nil) -> RpgSkillDef {
        RpgSkillDef(id: id, name: name, cls: cls, minLevel: lv, mp: mp, cooldown: cd, power: power, maxLevel: 10, price: 0, starter: false, desc: desc, fx: fx)
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
        s("j_ass1", "그림자 습격", .rogue, 20, 18, 6, 2.6, "앞으로 순식간에 돌진하며 벤다 (무적)"),
        s("j_ass2", "사신의 일격", .rogue, 30, 40, 18, 3.0, "근처 적들을 차례로 베어 넘긴다"),
        s("j_poi1", "맹독 구름", .rogue, 20, 20, 8, 1.6, "앞쪽에 독구름을 터뜨린다"),
        s("j_poi2", "독안개 폭발", .rogue, 30, 38, 16, 2.0, "독이 퍼지며 세 번 터진다"),
        s("j_pal1", "성스러운 방패", .cleric, 20, 22, 20, 0, "주변 동료 12초간 피해 -40% + HP 10% 회복"),
        s("j_pal2", "심판의 망치", .cleric, 30, 34, 14, 3.0, "넓은 범위를 내려쳐 기절시킨다 (신성)"),
        s("j_arc1", "대치유", .cleric, 20, 28, 12, 0, "주변 동료 HP 50% 회복"),
        s("j_arc2", "신의 은총", .cleric, 30, 44, 30, 0, "주변 동료 공격력 상승 + 피해 감소 (12초)"),
        s("j_fk1", "폭권", .monk, 20, 20, 7, 2.8, "전방에 기를 터뜨려 크게 폭발시킨다"),
        s("j_fk2", "분노의 연타", .monk, 30, 36, 14, 0.8, "전방을 12번 두들긴다"),
        s("j_asc1", "참선", .monk, 20, 20, 20, 0, "HP 35% 회복 + 6초간 피해 감소"),
        s("j_asc2", "반격의 기", .monk, 30, 30, 16, 1.8, "주변을 밀쳐내며 기절시키고 8초간 피해 감소"),
        s("j_nec1", "해골 병사 소환", .summoner, 20, 22, 8, 1.2, "해골 병사들이 앞쪽을 쓸어낸다"),
        s("j_nec2", "죽음의 파동", .summoner, 30, 40, 14, 1.8, "죽음의 파동이 세 겹으로 퍼진다"),
        s("j_beast1", "맹수 소환", .summoner, 20, 24, 8, 1.7, "맹수들이 부채꼴로 덮친다"),
        s("j_beast2", "정령왕 강림", .summoner, 30, 46, 20, 2.3, "정령왕이 운석을 여덟 번 내리꽂는다"),
        s("j_x1a", "집중포화", .mechanic, 20, 22, 7, 0.9, "총알 열두 발을 넓게 퍼붓는다", fx: .shot(12, spread: 0.09, speed: 330, range: 190)),
        s("j_x1b", "전차포", .mechanic, 30, 38, 14, 5.0, "모든 것을 꿰뚫는 강력한 포탄", fx: .shot(1, big: true, speed: 260, range: 300)),
        s("j_x2a", "듀얼 터렛", .mechanic, 20, 28, 16, 0.7, "18초간 터렛 두 대를 설치한다", fx: .turret(2, seconds: 18)),
        s("j_x2b", "전투 로봇", .mechanic, 30, 40, 14, 2.2, "전투 로봇이 여덟 명을 차례로 공격한다", fx: .chain(8, reach: 200, .thunder)),
    ]
}

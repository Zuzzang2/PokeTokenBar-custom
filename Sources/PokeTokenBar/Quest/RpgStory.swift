import Foundation

// SPIKE: 스토리 퀘스트. One chain of steps that walks a character from the first slime to the end of the dimension, each with a short
// line of story, a goal checked against counters the character already keeps (lifetime kills, maps visited, level, job tier, tower floor),
// and a reward that grows with the step. Shown in the quest window's "스토리" tab; the step is claimed there.

struct RpgStoryStep: Sendable {
    enum Goal: Sendable {
        case kill(String, Int)
        case visit(RpgMapID)
        case level(Int)
        case tier(Int)
        case floor(Int)
    }
    enum Prize: Sendable { case none, item(String), weapon(Int) }

    let title: String
    let text: String
    let goal: Goal
    /// Level the reward is scaled to.
    let level: Int
    var prize = Prize.none

    var gold: Int { Int(150 * pow(Double(level), 1.4)) }
    var xp: Int { RpgMaps.xpNeeded(level) / 3 }
    var stones: Int { max(1, level / 10) }
}

enum RpgStory {
    private static func s(_ title: String, _ text: String, _ goal: RpgStoryStep.Goal, _ level: Int, _ prize: RpgStoryStep.Prize = .none) -> RpgStoryStep {
        RpgStoryStep(title: title, text: text, goal: goal, level: level, prize: prize)
    }

    static let steps: [RpgStoryStep] = [
        s("첫 사냥", "촌장: 마을 밖 초원에 슬라임이 늘었네. 열 마리만 잡아 주게.", .kill("slime", 10), 2),
        s("버섯 소동", "촌장: 갈색 버섯들이 밭을 망치고 있어. 여덟 마리를 부탁하네.", .kill("brownshroom", 8), 4),
        s("숲으로", "촌장: 숲 너머에 무언가 깨어났다는 소문이야. 먼저 숲을 둘러보게.", .visit(.forest), 5),
        s("늑대 무리", "나그네: 숲의 늑대들이 사나워졌소. 열두 마리를 쫓아내 주시오.", .kill("wolf", 12), 8, .item("hp1")),
        s("동굴 탐사", "촌장: 동굴 깊은 곳에서 슬라임 킹의 기운이 느껴진다네. 2층까지 가 보게.", .visit(.cave2), 11),
        s("해골 병사", "광부: 동굴을 해골들이 점령했어요! 열다섯 마리만 처치해 주세요.", .kill("skeleton", 15), 13),
        s("슬라임 킹", "촌장: 이제 슬라임 킹을 쓰러뜨릴 때일세. 자네라면 해낼 수 있어.", .kill("slimeking", 1), 15, .item("ring0")),
        s("사막으로", "상인: 슬라임 킹이 쓰러졌으니 사막 길이 열렸습니다. 먼저 사막에 가 보세요.", .visit(.desert), 18),
        s("전직의 길", "전직관: 힘을 갖췄군. 마을로 돌아와 2차 전직을 하게나.", .tier(1), 20, .item("scroll")),
        s("전갈 퇴치", "대상인: 사막 전갈 때문에 장사를 못 해요. 스무 마리만!", .kill("scorpion", 20), 21),
        s("안개 늪", "방랑자: 사막 남쪽 늪에 이상한 안개가 끼었다더군. 가 보겠나?", .visit(.swamp), 22),
        s("미라의 저주", "학자: 피라미드의 미라들이 되살아났소. 스물다섯 마리를 잠재워 주시오.", .kill("mummy", 25), 24),
        s("피라미드의 왕", "학자: 모래의 왕이 모든 저주의 뿌리라오. 부디 쓰러뜨려 주시오.", .kill("sandking", 1), 26, .item("amulet2")),
        s("설원", "탐험가: 동쪽 설원 너머로 길이 이어져 있어. 얼어붙은 땅을 밟아 봐.", .visit(.snow), 28),
        s("예티 사냥", "사냥꾼: 예티가 마을을 위협해. 스무 마리를 처치해 줘!", .kill("yeti", 20), 30),
        s("빙하의 왕", "사냥꾼: 얼음 동굴의 예티 킹을 쓰러뜨리면 설원에 평화가 올 거야.", .kill("yetiking", 1), 33, .item("helmet3")),
        s("화산", "대장장이: 화산의 열기로만 벼리는 금속이 있네. 화산에 다녀오게.", .visit(.volcano), 35),
        s("용암 골렘", "대장장이: 용암 골렘의 심장이 필요해. 스무 마리를 부숴 주게.", .kill("lavagolem", 20), 38),
        s("화산의 심장", "대장장이: 화산 깊은 곳의 해골왕을 쓰러뜨려야 화산이 잠잠해질 걸세.", .kill("skelking", 1), 42, .item("boots4")),
        s("3차 전직", "전직관: 자네는 한계를 넘었네. 3차 전직으로 더 높이 오르게.", .tier(2), 45, .weapon(6)),
        s("마왕성", "기사단장: 화산 너머 마왕성이 보인다. 적진을 정찰하고 오게.", .visit(.castle), 46),
        s("어둠의 기사", "기사단장: 마왕의 기사들이 길을 막고 있어. 서른 명을 베어 주게.", .kill("darkknight", 30), 50),
        s("왕가의 묘지", "수도사: 성 아래 지하묘지에 원혼들이 갇혀 있소. 위로해 주시오.", .visit(.crypt), 52),
        s("망령 사냥", "수도사: 망령들을 서른 마리 잠재워 주시오. 그래야 길이 열린다오.", .kill("wraith", 30), 54),
        s("마왕", "기사단장: 이제 마왕이다. 이 대륙의 운명이 자네 손에 달렸어!", .kill("demonking", 1), 58, .weapon(8)),
        s("하늘로", "바람의 정령: 마왕이 사라지자 하늘 길이 열렸어요. 천공의 섬으로 올라와 봐요.", .visit(.sky), 60),
        s("무한의 탑", "탑지기: 무한의 탑 20층까지 오르는 자만이 진짜 강자라네.", .floor(20), 62),
        s("심해의 공포", "해녀: 심해 신전에 거대한 크라켄이 살아요. 부디 쓰러뜨려 주세요.", .kill("kraken", 1), 70),
        s("4차 전직", "전직관: 마지막 경지가 기다리고 있네. 4차 전직을 하게.", .tier(3), 72, .weapon(10)),
        s("고룡", "용사의 망령: 용의 둥지에서 고룡 바르가노스가 깨어났다. 막아 다오.", .kill("dragonlord", 1), 80),
        s("얼음 여왕", "얼음 왕궁의 기사: 여왕을 쓰러뜨려야 영원한 겨울이 끝납니다.", .kill("icequeen", 1), 85),
        s("폭풍의 거인", "협곡의 노인: 폭풍의 눈에 거인이 살고 있네. 그를 잠재워 주게.", .kill("stormgiant", 1), 90, .weapon(11)),
        s("금서의 주인", "사서: 고대 도서관의 대사서 리치가 금서를 열었어요. 막아 주세요!", .kill("archivist", 1), 95),
        s("차원의 끝", "???: 모든 균열의 끝에 차원의 지배자가 기다린다. 이 이야기를 끝내라, 용사여.", .kill("voidlord", 1), 100, .weapon(12)),
    ]

    /// (current, goal) for a step, with the current value capped at the goal.
    static func progress(_ step: RpgStoryStep, _ p: RpgPlayer) -> (Int, Int) {
        switch step.goal {
        case .kill(let id, let n): return (min(n, p.kills[id] ?? 0), n)
        case .visit(let map): return (p.visited.contains(map) ? 1 : 0, 1)
        case .level(let l): return (min(l, p.level), l)
        case .tier(let t): return (min(t, p.tier), t)
        case .floor(let f): return (min(f, p.bestFloor), f)
        }
    }

    static func done(_ step: RpgStoryStep, _ p: RpgPlayer) -> Bool { let (a, b) = progress(step, p); return a >= b }

    static func goalText(_ step: RpgStoryStep) -> String {
        switch step.goal {
        case .kill(let id, let n): return n == 1 ? "\(RpgMonsters.def(id).name) 처치" : "\(RpgMonsters.def(id).name) \(n)마리 처치"
        case .visit(let map): return "\(RpgMaps.def(map).name) 방문"
        case .level(let l): return "Lv\(l) 달성"
        case .tier(let t): return "\(t + 1)차 전직"
        case .floor(let f): return "무한의 탑 \(f)층 클리어"
        }
    }

    static func prizeItem(_ step: RpgStoryStep, _ cls: RpgClass) -> String? {
        switch step.prize {
        case .none: return nil
        case .item(let id): return id
        case .weapon(let tier): return "\(cls.weaponPrefix)\(tier)"
        }
    }
}

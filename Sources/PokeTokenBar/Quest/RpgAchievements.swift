import Foundation

// SPIKE: 업적. Long-term goals over counters the character already keeps (kills per monster, golden elites,
// best combo, level, maps visited, job). Each pays gold and enhancement stones once when it is reached.

struct RpgAchievement: Sendable {
    enum Metric: Sendable { case kills, bossKills, eliteKills, bestCombo, level, mapsVisited, jobAdvanced }

    let id: String
    let name: String
    let desc: String
    let metric: Metric
    let goal: Int
    let gold: Int
    let stones: Int
}

enum RpgAchievements {
    private static func a(_ id: String, _ name: String, _ desc: String, _ metric: RpgAchievement.Metric, _ goal: Int, _ gold: Int, _ stones: Int) -> RpgAchievement {
        RpgAchievement(id: id, name: name, desc: desc, metric: metric, goal: goal, gold: gold, stones: stones)
    }

    static let all: [RpgAchievement] = [
        a("kill100", "초보 사냥꾼", "몬스터 100마리 처치", .kills, 100, 300, 2),
        a("kill1000", "숙련 사냥꾼", "몬스터 1,000마리 처치", .kills, 1000, 3000, 6),
        a("kill5000", "전설의 사냥꾼", "몬스터 5,000마리 처치", .kills, 5000, 15000, 15),
        a("boss1", "보스 슬레이어", "보스 1마리 처치", .bossKills, 1, 1000, 5),
        a("boss10", "보스 학살자", "보스 10마리 처치", .bossKills, 10, 8000, 15),
        a("elite1", "황금을 쫓는 자", "황금 엘리트 1마리 처치", .eliteKills, 1, 500, 3),
        a("elite10", "황금 사냥꾼", "황금 엘리트 10마리 처치", .eliteKills, 10, 5000, 10),
        a("combo25", "콤보 입문", "25콤보 달성", .bestCombo, 25, 500, 2),
        a("combo50", "콤보 마스터", "50콤보 달성", .bestCombo, 50, 2000, 5),
        a("combo100", "콤보의 신", "100콤보 달성", .bestCombo, 100, 8000, 12),
        a("lv20", "성장하는 모험가", "Lv20 달성", .level, 20, 500, 3),
        a("lv35", "베테랑", "Lv35 달성", .level, 35, 2000, 6),
        a("lv50", "고수", "Lv50 달성", .level, 50, 8000, 12),
        a("lv60", "만렙의 영광", "Lv60 달성", .level, 60, 20000, 25),
        a("job", "새로운 길", "2차 전직하기", .jobAdvanced, 1, 1000, 5),
        a("maps5", "탐험가", "5개 지역 방문", .mapsVisited, 5, 800, 3),
        a("maps12", "대륙의 여행자", "12개 지역 방문", .mapsVisited, 12, 5000, 10),
    ]

    static let ids: Set<String> = Set(all.map(\.id))

    static func value(_ metric: RpgAchievement.Metric, _ p: RpgPlayer) -> Int {
        switch metric {
        case .kills: return p.kills.values.reduce(0, +)
        case .bossKills:
            let bosses = Set(RpgMonsters.all.filter { $0.behavior == .boss }.map(\.id))
            return p.kills.filter { bosses.contains($0.key) }.values.reduce(0, +)
        case .eliteKills: return p.eliteKills
        case .bestCombo: return p.bestCombo
        case .level: return p.level
        case .mapsVisited: return p.visited.count
        case .jobAdvanced: return p.job > 0 ? 1 : 0
        }
    }

    /// Counters from a save file are untrusted: unknown monsters and absurd numbers are dropped.
    static func cleanKills(_ raw: [String: Int]?) -> [String: Int] {
        let known = Set(RpgMonsters.all.map(\.id))
        return (raw ?? [:]).filter { known.contains($0.key) }.mapValues { min(max($0, 0), 10_000_000) }
    }
}

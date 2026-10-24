import Foundation

// SPIKE: ranked play for the plaza. Everything lives on this Mac and trainers report their own rating,
// so it is a friendly ladder, not a tamper-proof one. A rated result is an Elo update that both peers
// compute from the same two numbers, so their books agree without a server.

/// A rank tier and where it starts. `name` is shown next to the rating.
struct RankTier: Equatable {
    let name: String
    let emoji: String
    let from: Int

    static let all: [RankTier] = [
        RankTier(name: "새싹", emoji: "🌱", from: 0),
        RankTier(name: "브론즈", emoji: "🥉", from: 900),
        RankTier(name: "실버", emoji: "🥈", from: 1100),
        RankTier(name: "골드", emoji: "🥇", from: 1300),
        RankTier(name: "플래티넘", emoji: "💠", from: 1500),
        RankTier(name: "다이아", emoji: "💎", from: 1700),
        RankTier(name: "마스터", emoji: "👑", from: 1900),
    ]

    static func tier(for rating: Int) -> RankTier {
        all.last { rating >= $0.from } ?? all[0]
    }

    /// Rating still needed for the next tier; nil at the top.
    static func pointsToNext(from rating: Int) -> Int? {
        all.first { $0.from > rating }.map { $0.from - rating }
    }

    var label: String { "\(emoji) \(name)" }
}

enum Elo {
    static let start = 1000
    static let kSolo = 32.0
    static let kTeam = 24.0
    static let floor = 100

    static func expected(_ rating: Int, against other: Int) -> Double {
        1 / (1 + pow(10, Double(other - rating) / 400))
    }

    /// Rating change for the player rated `rating`; `won` is the outcome. Zero-sum between equal Ks.
    static func delta(rating: Int, opponent: Int, won: Bool, k: Double = kSolo) -> Int {
        Int((k * ((won ? 1 : 0) - expected(rating, against: opponent))).rounded())
    }

    static func updated(_ rating: Int, by delta: Int) -> Int { max(floor, rating + delta) }
}

struct OpponentRecord: Codable, Equatable {
    var name: String
    var wins = 0
    var losses = 0
    var lastPlayed = Date.distantPast
}

/// What a finished match changed, for the result panel.
struct MatchResult: Equatable {
    let won: Bool
    let team: Bool
    let ratingBefore: Int
    let ratingAfter: Int
    let rated: Bool                     // false once the daily same-opponent limit is used
    let versus: [String]                // opponent names
    let record: OpponentRecord?         // 1:1 only: updated record against that trainer
    let streak: Int

    var delta: Int { ratingAfter - ratingBefore }
    var tier: RankTier { RankTier.tier(for: ratingAfter) }
    var tierChanged: Bool { RankTier.tier(for: ratingBefore) != tier }
}

struct BattleStats: Codable, Equatable {
    var playerID = UUID().uuidString
    var rating = Elo.start
    var wins = 0
    var losses = 0
    var teamWins = 0
    var teamLosses = 0
    var streak = 0                      // current win streak (reset by a loss)
    var bestStreak = 0
    var peak = Elo.start
    var opponents: [String: OpponentRecord] = [:]
    /// Rated games per opponent on one calendar day, "yyyy-MM-dd" → player id → count.
    var ratedToday: [String: [String: Int]] = [:]

    static let ratedPerOpponentPerDay = 5

    var tier: RankTier { RankTier.tier(for: rating) }
    var games: Int { wins + losses + teamWins + teamLosses }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Records a 1:1 result against `opponentID` and applies the rating change. Pure: returns the new stats
    /// and what to show. Older days are pruned so the book stays small.
    func recordingSolo(won: Bool, opponentID: String, opponentName: String, opponentRating: Int,
                       now: Date = Date()) -> (BattleStats, MatchResult) {
        var next = self
        let day = Self.dayKey(now)
        next.ratedToday = next.ratedToday.filter { $0.key == day }
        let count = next.ratedToday[day]?[opponentID] ?? 0
        let rated = count < Self.ratedPerOpponentPerDay
        if rated { next.ratedToday[day, default: [:]][opponentID] = count + 1 }
        let before = rating
        if rated { next.rating = Elo.updated(rating, by: Elo.delta(rating: rating, opponent: opponentRating, won: won)) }
        next.applyOutcome(won: won, team: false)
        var record = next.opponents[opponentID] ?? OpponentRecord(name: opponentName)
        record.name = opponentName
        if won { record.wins += 1 } else { record.losses += 1 }
        record.lastPlayed = now
        next.opponents[opponentID] = record
        return (next, MatchResult(won: won, team: false, ratingBefore: before, ratingAfter: next.rating, rated: rated,
                                  versus: [opponentName], record: record, streak: next.streak))
    }

    /// Team result: rated against the average of the two opposing ratings, with a smaller K.
    func recordingTeam(won: Bool, foeRatings: [Int], foeNames: [String]) -> (BattleStats, MatchResult) {
        var next = self
        let before = rating
        let average = foeRatings.isEmpty ? Elo.start : foeRatings.reduce(0, +) / foeRatings.count
        next.rating = Elo.updated(rating, by: Elo.delta(rating: rating, opponent: average, won: won, k: Elo.kTeam))
        next.applyOutcome(won: won, team: true)
        return (next, MatchResult(won: won, team: true, ratingBefore: before, ratingAfter: next.rating, rated: true,
                                  versus: foeNames, record: nil, streak: next.streak))
    }

    private mutating func applyOutcome(won: Bool, team: Bool) {
        switch (won, team) {
        case (true, false): wins += 1
        case (false, false): losses += 1
        case (true, true): teamWins += 1
        case (false, true): teamLosses += 1
        }
        streak = won ? streak + 1 : 0
        bestStreak = max(bestStreak, streak)
        peak = max(peak, rating)
    }

    /// Opponents by most games, then most recent.
    var rivals: [(id: String, record: OpponentRecord)] {
        opponents.map { (id: $0.key, record: $0.value) }.sorted {
            let a = $0.record.wins + $0.record.losses, b = $1.record.wins + $1.record.losses
            return a != b ? a > b : $0.record.lastPlayed > $1.record.lastPlayed
        }
    }
}

enum BattleStatsStore {
    static let key = "battleStats"

    static func load(_ defaults: UserDefaults = .standard) -> BattleStats {
        if let data = defaults.data(forKey: key), let stats = try? JSONDecoder().decode(BattleStats.self, from: data) {
            return stats
        }
        let fresh = BattleStats()
        save(fresh, to: defaults)   // keeps the generated player id stable from the first launch
        return fresh
    }

    static func save(_ stats: BattleStats, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: key) }
    }
}

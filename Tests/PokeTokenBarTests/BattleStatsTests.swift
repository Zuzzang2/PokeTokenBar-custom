import XCTest
@testable import PokeTokenBar

// SPIKE: plaza ladder — Elo, tiers, daily same-opponent limit, head-to-head records.
final class BattleStatsTests: XCTestCase {
    private let now = Date()

    func testEloIsSymmetricAndRewardsUpsets() {
        XCTAssertEqual(Elo.delta(rating: 1000, opponent: 1000, won: true), 16)
        XCTAssertEqual(Elo.delta(rating: 1000, opponent: 1000, won: false), -16)
        XCTAssertGreaterThan(Elo.delta(rating: 1000, opponent: 1400, won: true), 16)
        XCTAssertLessThan(Elo.delta(rating: 1400, opponent: 1000, won: true), 16)
        XCTAssertEqual(Elo.updated(120, by: -50), Elo.floor)
    }

    func testTiersAndProgress() {
        XCTAssertEqual(RankTier.tier(for: 899).name, "새싹")
        XCTAssertEqual(RankTier.tier(for: 1000).name, "브론즈")
        XCTAssertEqual(RankTier.tier(for: 1900).name, "마스터")
        XCTAssertEqual(RankTier.pointsToNext(from: 1000), 100)
        XCTAssertNil(RankTier.pointsToNext(from: 2500))
    }

    func testBothPeersAgreeOnASoloResult() {
        let a = BattleStats(), b = BattleStats()
        let (a1, ra) = a.recordingSolo(won: true, opponentID: b.playerID, opponentName: "B", opponentRating: b.rating, now: now)
        let (b1, rb) = b.recordingSolo(won: false, opponentID: a.playerID, opponentName: "A", opponentRating: a.rating, now: now)
        XCTAssertEqual(ra.delta, 16)
        XCTAssertEqual(rb.delta, -16)
        XCTAssertEqual(a1.opponents[b.playerID]?.wins, 1)
        XCTAssertEqual(b1.opponents[a.playerID]?.losses, 1)
        XCTAssertEqual(a1.streak, 1)
        XCTAssertEqual(b1.streak, 0)
    }

    func testSixthGameAgainstTheSameOpponentTodayIsUnrated() {
        var stats = BattleStats()
        var rated: [Bool] = []
        for _ in 0..<6 {
            let (next, result) = stats.recordingSolo(won: true, opponentID: "X", opponentName: "X", opponentRating: 1000, now: now)
            stats = next
            rated.append(result.rated)
        }
        XCTAssertEqual(rated, [true, true, true, true, true, false])
        XCTAssertEqual(stats.opponents["X"]?.wins, 6, "an unrated game still counts in the record")
        let tomorrow = now.addingTimeInterval(86_400 * 1.5)
        XCTAssertTrue(stats.recordingSolo(won: false, opponentID: "X", opponentName: "X", opponentRating: 1000, now: tomorrow).1.rated)
    }

    func testLossEndsTheStreakButKeepsTheBest() {
        var stats = BattleStats()
        for _ in 0..<3 { stats = stats.recordingSolo(won: true, opponentID: "X", opponentName: "X", opponentRating: 1000, now: now).0 }
        stats = stats.recordingSolo(won: false, opponentID: "Y", opponentName: "Y", opponentRating: 1000, now: now).0
        XCTAssertEqual(stats.streak, 0)
        XCTAssertEqual(stats.bestStreak, 3)
    }

    func testTeamResultUsesTheFoeAverage() {
        let (stats, result) = BattleStats().recordingTeam(won: true, foeRatings: [1000, 1200], foeNames: ["C", "D"])
        XCTAssertEqual(stats.teamWins, 1)
        XCTAssertGreaterThan(result.delta, 12)
        XCTAssertTrue(result.team)
    }

    func testRoundTripThroughDefaultsKeepsThePlayerID() {
        let defaults = UserDefaults(suiteName: "BattleStatsTests-\(UUID().uuidString)")!
        let first = BattleStatsStore.load(defaults)
        XCTAssertEqual(BattleStatsStore.load(defaults).playerID, first.playerID)
    }
}

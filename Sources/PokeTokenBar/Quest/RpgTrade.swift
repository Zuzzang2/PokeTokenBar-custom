import Foundation

// SPIKE: 플레이어 간 거래. Two players standing near each other offer items and gold, both press confirm, and
// the host swaps everything in one step. Changing an offer clears both confirmations; anything that stops
// being true (distance, map, stock, death, disconnect) cancels the trade. Only the host holds the real state;
// each trader receives a view of it (`RpgTradeView`) inside their private state.

/// One side's offer.
struct RpgTradeOffer: Codable, Sendable, Equatable {
    var items: [String: Int] = [:]
    var gold = 0
    var ok = false
}

/// What a trader sees: who they trade with and both offers.
struct RpgTradeView: Codable, Sendable, Equatable {
    let partnerID: Int
    let partnerName: String
    var mine: RpgTradeOffer
    var theirs: RpgTradeOffer
}

/// Host-side state of one trade between players `a` and `b`.
struct RpgTrade {
    let a: Int
    let b: Int
    var offers: [Int: RpgTradeOffer]

    func partner(of id: Int) -> Int { id == a ? b : a }
}

enum RpgTrades {
    /// How many different items one side can put up.
    static let maxDistinct = 8
    /// Traders must stand this close (pixels) on the same map.
    static let range = 200.0

    /// Equipped gear is not in the bag, so it cannot be offered. Enhancement levels are stored per item id, so an
    /// enhanced id stays with its owner instead of silently losing or duplicating its level.
    static func tradable(_ id: String, _ p: RpgPlayer) -> Bool {
        RpgItems.item(id) != nil && (p.plus[id] ?? 0) == 0
    }
}

import Foundation

// SPIKE: per-class tuning, fitted with `scripts/rpg-balance.sh` (bots hunt with every class and the kill rates are compared).
// `attack` scales a class's attack at a level (linear between the listed levels); 1 = untuned. Re-run the probe after changing
// content, classes or the damage rules, and nudge the numbers until every class sits near 1.00 of the median.

enum RpgBalance {
    /// (level, factor) points per class.
    static let attack: [RpgClass: [(Int, Double)]] = [
        .warrior: [(10, 1.0), (20, 1.1), (30, 1.1), (45, 1.7), (60, 1.5), (90, 1.5)],
        .archer: [(10, 2.0), (30, 1.35), (45, 2.1), (60, 1.7), (90, 3.0)],
        .mage: [(10, 1.15), (30, 0.85), (60, 1.0), (90, 0.75)],
        .rogue: [(10, 1.1), (30, 1.0), (60, 1.0), (90, 1.0)],
        .cleric: [(10, 1.95), (30, 1.9), (45, 2.3), (60, 2.7), (90, 4.3)],
        .monk: [(10, 0.47), (30, 0.5), (60, 0.42), (90, 0.35)],
        .summoner: [(10, 1.15), (30, 1.15), (60, 0.85), (90, 0.9)],
        .mechanic: [(10, 1.2), (30, 1.5), (60, 1.25), (90, 1.95)],
    ]


    static func attackFactor(_ cls: RpgClass, level: Int) -> Double {
        guard let pts = attack[cls], let first = pts.first else { return 1 }
        if level <= first.0 { return first.1 }
        for (a, b) in zip(pts, pts.dropFirst()) where level <= b.0 {
            let t = Double(level - a.0) / Double(b.0 - a.0)
            return a.1 + (b.1 - a.1) * t
        }
        return pts.last!.1
    }
}

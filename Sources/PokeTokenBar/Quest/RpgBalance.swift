import Foundation

// SPIKE: per-class tuning, fitted with `scripts/rpg-balance.sh` (bots hunt with every class and the kill rates are compared).
// `attack` scales a class's attack at a level (linear between the listed levels); 1 = untuned. Re-run the probe after changing
// content, classes or the damage rules, and nudge the numbers until every class sits near 1.00 of the median.

enum RpgBalance {
    /// (level, factor) points per class.
    static let attack: [RpgClass: [(Int, Double)]] = [:]

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

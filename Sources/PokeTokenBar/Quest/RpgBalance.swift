import Foundation

// SPIKE: per-class tuning, fitted with `scripts/rpg-balance.sh` (bots hunt with every class and the kill rates are compared).
// `attack` scales a class's attack at a level (linear between the listed levels); 1 = untuned. Re-run the probe after changing
// content, classes or the damage rules, and nudge the numbers until every class sits near 1.00 of the median.

enum RpgBalance {
    /// (level, factor) points per class.
    static let attack: [RpgClass: [(Int, Double)]] = [
        .warrior: [(10, 0.96), (20, 1.22), (30, 1.11), (45, 1.74), (60, 1.65), (75, 2.01), (90, 1.98), (100, 1.80)],
        .archer: [(10, 2.09), (20, 2.24), (30, 1.55), (45, 2.45), (60, 2.11), (75, 2.34), (90, 4.19), (100, 2.94)],
        .mage: [(10, 1.22), (20, 0.78), (30, 0.79), (45, 0.99), (60, 0.90), (75, 1.06), (90, 1.00), (100, 1.15)],
        .rogue: [(10, 1.12), (20, 0.97), (30, 0.97), (45, 1.00), (60, 0.88), (75, 1.17), (90, 1.14), (100, 1.33)],
        .cleric: [(10, 1.90), (20, 2.36), (30, 2.57), (45, 3.55), (60, 3.88), (75, 4.44), (90, 5.26), (100, 5.71)],
        .monk: [(10, 0.62), (20, 0.44), (30, 0.52), (45, 0.47), (60, 0.44), (75, 0.37), (90, 0.34), (100, 0.36)],
        .summoner: [(10, 0.91), (20, 1.23), (30, 1.10), (45, 0.92), (60, 0.83), (75, 1.01), (90, 0.76), (100, 0.88)],
        .mechanic: [(10, 1.31), (20, 1.46), (30, 1.32), (45, 1.52), (60, 1.72), (75, 1.46), (90, 2.28), (100, 1.85)],
    ]


    /// Boss HP multiplier by boss level: players outgrow the authored boss curve late, so the Lv80-100 bosses are thickened until a solo
    /// fight lasts about as long as at Lv50-65 (fitted with `BOSS=1 scripts/rpg-balance.sh`).
    static let bossHP: [(Int, Double)] = [(20, 1.0), (35, 1.0), (50, 1.0), (65, 1.2), (80, 2.0), (100, 2.7)]

    static func bossHPFactor(level: Int) -> Double { interpolate(bossHP, level) }

    private static func interpolate(_ pts: [(Int, Double)], _ level: Int) -> Double {
        guard let first = pts.first else { return 1 }
        if level <= first.0 { return first.1 }
        for (a, b) in zip(pts, pts.dropFirst()) where level <= b.0 {
            return a.1 + (b.1 - a.1) * Double(level - a.0) / Double(b.0 - a.0)
        }
        return pts.last!.1
    }

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

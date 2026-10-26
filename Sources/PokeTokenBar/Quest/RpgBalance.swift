import Foundation

// SPIKE: per-class tuning, fitted with `scripts/rpg-balance.sh` (bots hunt with every class and the kill rates are compared).
// `attack` scales a class's attack at a level (linear between the listed levels); 1 = untuned. Re-run the probe after changing
// content, classes or the damage rules, and nudge the numbers until every class sits near 1.00 of the median.

enum RpgBalance {
    /// (level, factor) points per class.
    static let attack: [RpgClass: [(Int, Double)]] = [
        .warrior: [(10, 1.00), (20, 1.36), (30, 1.14), (45, 1.89), (60, 1.76), (75, 2.23), (90, 2.01), (100, 1.84)],
        .archer: [(10, 2.13), (20, 2.38), (30, 1.54), (45, 2.60), (60, 2.48), (75, 2.72), (90, 4.44), (100, 3.08)],
        .mage: [(10, 1.35), (20, 0.85), (30, 0.79), (45, 0.96), (60, 1.04), (75, 0.97), (90, 1.00), (100, 1.10)],
        .rogue: [(10, 1.08), (20, 1.02), (30, 0.97), (45, 0.96), (60, 1.04), (75, 1.07), (90, 1.09), (100, 1.23)],
        .cleric: [(10, 1.42), (20, 1.97), (30, 2.08), (45, 3.18), (60, 3.56), (75, 4.09), (90, 5.26), (100, 5.71)],
        .monk: [(10, 0.83), (20, 0.65), (30, 0.83), (45, 0.66), (60, 0.63), (75, 0.54), (90, 0.46), (100, 0.51)],
        .summoner: [(10, 1.10), (20, 1.21), (30, 1.14), (45, 0.92), (60, 0.92), (75, 1.15), (90, 0.83), (100, 0.91)],
        .mechanic: [(10, 1.22), (20, 1.53), (30, 1.38), (45, 1.77), (60, 1.43), (75, 1.58), (90, 2.44), (100, 1.85)],
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

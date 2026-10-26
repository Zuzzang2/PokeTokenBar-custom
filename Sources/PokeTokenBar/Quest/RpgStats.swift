import Foundation

// SPIKE: 능력치 포인트. Every level gives `perLevel` points to put into 힘·민첩·체력·지력. They stack on top of
// class, job and gear, so two characters of the same class and level can be built differently.

enum RpgStats {
    static let perLevel = 5
    static let cap = 600
    static let names = ["힘", "민첩", "체력", "지력"]
    static let blurbs = ["공격력 +0.6%", "치명타 +0.15% · 공격 속도 +0.1%", "최대 HP +1% · 방어력 +0.6%", "최대 MP +1.2% · 스킬 위력 +0.5%"]

    static func resetCost(level: Int) -> Int { 300 * level }

    private static func v(_ s: [Int], _ k: Int) -> Double { s.indices.contains(k) ? Double(s[k]) : 0 }
    static func attackFactor(_ s: [Int]) -> Double { 1 + 0.006 * v(s, 0) }
    static func crit(_ s: [Int]) -> Double { min(0.3, 0.0015 * v(s, 1)) }
    static func intervalFactor(_ s: [Int]) -> Double { 1 - min(0.25, 0.001 * v(s, 1)) }
    static func hpFactor(_ s: [Int]) -> Double { 1 + 0.01 * v(s, 2) }
    static func defenseFactor(_ s: [Int]) -> Double { 1 + 0.006 * v(s, 2) }
    static func mpFactor(_ s: [Int]) -> Double { 1 + 0.012 * v(s, 3) }
    static func skillFactor(_ s: [Int]) -> Double { 1 + 0.005 * v(s, 3) }

    /// 0 without a job, otherwise 1...3 (saves from before tiers count as 2차).
    static func cleanTier(_ tier: Int?, job: Int) -> Int { job == 0 ? 0 : min(max(tier ?? 1, 1), RpgTiers.maxTier) }

    /// Saved numbers are untrusted: four non-negative stats, and no more points in total than the level has earned.
    /// A save from before stats gets every point its level would have earned.
    static func clean(ap: Int?, stats: [Int]?, level: Int) -> (Int, [Int]) {
        let earned = max(0, level - 1) * perLevel
        guard let ap, let stats, stats.count == names.count else { return (earned, [0, 0, 0, 0]) }
        let st = stats.map { min(max($0, 0), cap) }
        guard max(ap, 0) + st.reduce(0, +) <= earned else { return (earned, [0, 0, 0, 0]) }
        return (max(ap, 0), st)
    }
}

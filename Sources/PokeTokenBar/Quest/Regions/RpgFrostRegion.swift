import CoreGraphics
import Foundation

// 얼음 대륙 (Lv60-88). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgFrostRegion {
    static let region = RpgRegion(id: "frost", name: "얼음 대륙", blurb: "", minLevel: 1, entry: RpgMapID("frost_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsFrost: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsFrost: [String: [Character: CGColor]] = [:]
}

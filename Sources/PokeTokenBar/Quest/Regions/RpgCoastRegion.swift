import CoreGraphics
import Foundation

// 해안 대륙 (Lv5-22). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgCoastRegion {
    static let region = RpgRegion(id: "coast", name: "해안 대륙", blurb: "", minLevel: 1, entry: RpgMapID("coast_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsCoast: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCoast: [String: [Character: CGColor]] = [:]
}

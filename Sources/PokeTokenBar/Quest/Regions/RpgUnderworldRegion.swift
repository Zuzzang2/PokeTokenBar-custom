import CoreGraphics
import Foundation

// 지하 마계 (Lv55-80). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgUnderworldRegion {
    static let region = RpgRegion(id: "underworld", name: "지하 마계", blurb: "", minLevel: 1, entry: RpgMapID("underworld_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsUnderworld: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsUnderworld: [String: [Character: CGColor]] = [:]
}

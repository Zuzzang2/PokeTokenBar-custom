import CoreGraphics
import Foundation

// 해저 신전 (Lv40-66). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgUnderseaRegion {
    static let region = RpgRegion(id: "undersea", name: "해저 신전", blurb: "", minLevel: 1, entry: RpgMapID("undersea_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsUndersea: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsUndersea: [String: [Character: CGColor]] = [:]
}

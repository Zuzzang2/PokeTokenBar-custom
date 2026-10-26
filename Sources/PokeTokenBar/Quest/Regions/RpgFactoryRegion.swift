import CoreGraphics
import Foundation

// 기계 공장 (Lv30-54). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgFactoryRegion {
    static let region = RpgRegion(id: "factory", name: "기계 공장", blurb: "", minLevel: 1, entry: RpgMapID("factory_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsFactory: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsFactory: [String: [Character: CGColor]] = [:]
}

import CoreGraphics
import Foundation

// 차원 균열 (Lv80-100). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgRiftRegion {
    static let region = RpgRegion(id: "rift", name: "차원 균열", blurb: "", minLevel: 1, entry: RpgMapID("rift_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsRift: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsRift: [String: [Character: CGColor]] = [:]
}

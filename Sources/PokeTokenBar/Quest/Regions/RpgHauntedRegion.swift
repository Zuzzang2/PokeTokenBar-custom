import CoreGraphics
import Foundation

// 유령 마을 (Lv45-72). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgHauntedRegion {
    static let region = RpgRegion(id: "haunted", name: "유령 마을", blurb: "", minLevel: 1, entry: RpgMapID("haunted_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsHaunted: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsHaunted: [String: [Character: CGColor]] = [:]
}

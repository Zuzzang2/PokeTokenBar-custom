import CoreGraphics
import Foundation

// 버섯 왕국 (Lv15-36). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgMushroomRegion {
    static let region = RpgRegion(id: "mushroom", name: "버섯 왕국", blurb: "", minLevel: 1, entry: RpgMapID("mushroom_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsMushroom: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsMushroom: [String: [Character: CGColor]] = [:]
}

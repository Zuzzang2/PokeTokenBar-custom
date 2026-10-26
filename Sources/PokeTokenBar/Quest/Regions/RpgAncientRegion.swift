import CoreGraphics
import Foundation

// 고대 도시 (Lv20-42). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgAncientRegion {
    static let region = RpgRegion(id: "ancient", name: "고대 도시", blurb: "", minLevel: 1, entry: RpgMapID("ancient_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsAncient: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsAncient: [String: [Character: CGColor]] = [:]
}

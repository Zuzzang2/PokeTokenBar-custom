import CoreGraphics
import Foundation

// 정글 대륙 (Lv10-30). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgJungleRegion {
    static let region = RpgRegion(id: "jungle", name: "정글 대륙", blurb: "", minLevel: 1, entry: RpgMapID("jungle_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsJungle: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsJungle: [String: [Character: CGColor]] = [:]
}

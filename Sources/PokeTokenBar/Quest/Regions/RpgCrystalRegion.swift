import CoreGraphics
import Foundation

// 수정 광산 (Lv25-46). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgCrystalRegion {
    static let region = RpgRegion(id: "crystal", name: "수정 광산", blurb: "", minLevel: 1, entry: RpgMapID("crystal_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsCrystal: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCrystal: [String: [Character: CGColor]] = [:]
}

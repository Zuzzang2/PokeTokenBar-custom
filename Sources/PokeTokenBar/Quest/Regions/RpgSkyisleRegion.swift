import CoreGraphics
import Foundation

// 하늘 섬 (Lv35-60). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgSkyisleRegion {
    static let region = RpgRegion(id: "skyisle", name: "하늘 섬", blurb: "", minLevel: 1, entry: RpgMapID("skyisle_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsSkyisle: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsSkyisle: [String: [Character: CGColor]] = [:]
}

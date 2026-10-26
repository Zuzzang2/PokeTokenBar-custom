import CoreGraphics
import Foundation

// 신들의 정원 (Lv70-95). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgCelestialRegion {
    static let region = RpgRegion(id: "celestial", name: "신들의 정원", blurb: "", minLevel: 1, entry: RpgMapID("celestial_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsCelestial: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsCelestial: [String: [Character: CGColor]] = [:]
}

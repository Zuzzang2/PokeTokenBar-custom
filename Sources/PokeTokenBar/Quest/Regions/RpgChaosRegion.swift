import CoreGraphics
import Foundation

// 혼돈의 궁전 (Lv88-100). Owned by exactly one author; see `RpgRegions.swift` for how the pieces are picked up.

enum RpgChaosRegion {
    static let region = RpgRegion(id: "chaos", name: "혼돈의 궁전", blurb: "", minLevel: 1, entry: RpgMapID("chaos_1"), entryTile: RpgTile(x: 4, y: 15))
}

extension RpgArt {
    /// Monster sprites for this region, keyed by the monster's `sprite` id (see `RpgArt.specs` for the shape).
    static let specsChaos: [String: SpriteSpec] = [:]
    /// Item icon colour overrides by item id, merged over the tier defaults (letters as in the icon templates).
    static let iconsChaos: [String: [Character: CGColor]] = [:]
}

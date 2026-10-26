import CoreGraphics
import Foundation

// SPIKE: 대륙. A region is a self-contained chain of maps with its own monsters, items and recipes, entered from the town's
// 차원문 ("대륙" tab) once the player has the level. Each region lives in its own file under `Regions/` (one owner per file) and is
// listed in `RpgRegions.all`; `RpgMaps`, `RpgMonsters`, `RpgItems`, `RpgRecipes` and the sprite and icon tables pick the pieces up.

/// How a map is dressed beyond its `kind`: tile overrides for the outdoor kinds, and a colour wash over the finished picture.
struct RpgTheme: Sendable {
    struct RGB: Sendable { var r: Double, g: Double, b: Double }
    enum Blend: Sendable {
        case color, multiply, overlay, softLight, hue
        var cg: CGBlendMode {
            switch self {
            case .color: return .color
            case .multiply: return .multiply
            case .overlay: return .overlay
            case .softLight: return .softLight
            case .hue: return .hue
            }
        }
    }
    /// Outdoor kinds (field, forest, desert, snow, volcano) only: replace the floor, the blocking obstacle, the pools and the scatter decoration.
    var floor: RpgTileType? = nil
    var obstacle: RpgTileType? = nil
    var pool: RpgTileType? = nil
    var decor: RpgTileType? = nil
    /// Wash over the finished map picture (0-1 colour channels) at `tintAlpha`.
    var tint: RGB? = nil
    var tintAlpha = 0.35
    var blend = Blend.color
    /// Overrides how dark the map is (0 bright, 1 black).
    var darkness: Double? = nil
}

struct RpgRegion: Sendable {
    let id: String
    let name: String
    let blurb: String
    /// Level needed to enter from the 차원문.
    let minLevel: Int
    /// The first map of the chain, and the tile the traveller appears on.
    let entry: RpgMapID
    let entryTile: RpgTile
    var maps: [RpgMapDef] = []
    var monsters: [RpgMonsterDef] = []
    var items: [RpgItem] = []
    var recipes: [RpgRecipe] = []
}

enum RpgRegions {
    static let all: [RpgRegion] = [
        RpgCoastRegion.region,
        RpgJungleRegion.region,
        RpgMushroomRegion.region,
        RpgAncientRegion.region,
        RpgCrystalRegion.region,
        RpgFactoryRegion.region,
        RpgSkyisleRegion.region,
        RpgUnderseaRegion.region,
        RpgHauntedRegion.region,
        RpgUnderworldRegion.region,
        RpgFrostRegion.region,
        RpgCelestialRegion.region,
        RpgRiftRegion.region,
        RpgChaosRegion.region,
    ].filter { !$0.maps.isEmpty }

    static func entry(_ map: RpgMapID) -> RpgRegion? { all.first { $0.entry == map } }
    static func region(of map: RpgMapID) -> RpgRegion? { all.first { r in r.maps.contains { $0.id == map } } }
}

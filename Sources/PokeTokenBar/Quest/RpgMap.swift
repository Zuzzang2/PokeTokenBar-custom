import CoreGraphics
import Foundation

// SPIKE: tile maps for 픽셀 모험. The town is laid out by hand; the hunting grounds are generated from a
// fixed seed (same map every launch) and then corridors are carved between every portal so all of them
// are always reachable. 16-pixel tiles, world coordinates in pixels with y down.

enum RpgTileType: UInt8, Sendable {
    case grass, flower, path, stone, tree, water, rock, caveFloor, caveWall, torch, sand, bossFloor, fountain, darkGrass
    case cactus, snow, pine, iceRock, ash, lava, castleFloor, castleWall, pillar, carpet, dune

    var blocks: Bool {
        switch self {
        case .tree, .water, .rock, .caveWall, .fountain, .cactus, .pine, .iceRock, .lava, .castleWall, .pillar: return true
        default: return false
        }
    }
}

struct RpgBuilding: Sendable {
    let x: Int, y: Int, w: Int, h: Int
    let place: RpgPlace
    /// Pixel point in front of the door where the keeper stands.
    var door: CGPoint { CGPoint(x: CGFloat(x * 16 + w * 8), y: CGFloat((y + h) * 16 + 10)) }
}

struct RpgMap: Sendable {
    static let tile: CGFloat = 16

    let def: RpgMapDef
    private(set) var tiles: [RpgTileType]
    private(set) var buildings: [RpgBuilding] = []
    private(set) var torches: [RpgTile] = []
    private(set) var spawnTiles: [RpgTile] = []

    var width: Int { def.width }
    var height: Int { def.height }
    var pixelSize: CGSize { CGSize(width: CGFloat(width) * Self.tile, height: CGFloat(height) * Self.tile) }
    /// Caves and boss rooms are dark; the castle is dim.
    var darkness: Double {
        switch def.kind {
        case .cave: return 0.82
        case .boss: return def.zone == .castle ? 0.6 : 0.5
        case .castle: return 0.5
        case .volcano: return 0.25
        default: return 0
        }
    }

    func at(_ x: Int, _ y: Int) -> RpgTileType {
        guard x >= 0, y >= 0, x < width, y < height else { return wallType }
        return tiles[y * width + x]
    }

    private mutating func set(_ x: Int, _ y: Int, _ t: RpgTileType) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        tiles[y * width + x] = t
    }

    /// Solid at a pixel point: blocking tiles, buildings and the map edge.
    func isBlocked(_ p: CGPoint) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < pixelSize.width, p.y < pixelSize.height else { return true }
        let tx = Int(p.x / Self.tile), ty = Int(p.y / Self.tile)
        if at(tx, ty).blocks { return true }
        return buildings.contains { tx >= $0.x && tx < $0.x + $0.w && ty >= $0.y && ty < $0.y + $0.h }
    }

    /// A body's feet: a small box so units slide along walls instead of snagging on corners.
    func canStand(_ p: CGPoint, radius: CGFloat = 5) -> Bool {
        !isBlocked(CGPoint(x: p.x - radius, y: p.y - 2)) && !isBlocked(CGPoint(x: p.x + radius, y: p.y - 2))
            && !isBlocked(CGPoint(x: p.x - radius, y: p.y + 3)) && !isBlocked(CGPoint(x: p.x + radius, y: p.y + 3))
    }

    static func center(_ t: RpgTile) -> CGPoint { CGPoint(x: (CGFloat(t.x) + 0.5) * tile, y: (CGFloat(t.y) + 0.5) * tile) }

    // MARK: generation

    init(_ def: RpgMapDef) {
        self.def = def
        tiles = Array(repeating: .grass, count: def.width * def.height)
        var rng = KartRNG(seed: def.seed &* 0x9E37_79B9)
        switch def.kind {
        case .town: buildTown()
        case .field: buildOutdoor(&rng, floor: .grass, obstacle: .tree, density: 7, rocks: 3, pools: 2, poolTile: .water, decor: .flower, decorCount: 60)
        case .forest: buildOutdoor(&rng, floor: .darkGrass, obstacle: .tree, density: 20, rocks: 3, pools: 1, poolTile: .water, decor: .flower, decorCount: 25)
        case .desert: buildOutdoor(&rng, floor: .sand, obstacle: .cactus, density: 5, rocks: 4, pools: 1, poolTile: .water, decor: .dune, decorCount: 120)
        case .snow: buildOutdoor(&rng, floor: .snow, obstacle: .pine, density: 12, rocks: 4, pools: 2, poolTile: .iceRock, decor: .snow, decorCount: 0)
        case .volcano: buildOutdoor(&rng, floor: .ash, obstacle: .rock, density: 6, rocks: 3, pools: 4, poolTile: .lava, decor: .ash, decorCount: 0)
        case .castle: buildCastle(&rng)
        case .pond: buildPond(&rng)
        case .cave: buildCave(&rng)
        case .boss: buildBoss()
        }
        // Every portal and arrival point gets breathing room.
        for p in def.portals { clear(around: p.at, radius: 1) }
        for other in RpgMaps.all {
            for p in other.portals where p.to == def.id && !p.waypoint { clear(around: p.arrive, radius: 1) }
        }
        collectSpawns(&rng)
    }

    private var floorType: RpgTileType {
        switch def.kind {
        case .cave: return .caveFloor
        case .boss: return .bossFloor
        case .town: return .stone
        case .forest: return .darkGrass
        case .desert: return .sand
        case .snow: return .snow
        case .volcano: return .ash
        case .castle: return .castleFloor
        default: return .grass
        }
    }

    private var wallType: RpgTileType {
        switch def.kind {
        case .cave, .boss: return .caveWall
        case .castle: return .castleWall
        case .desert: return .cactus
        case .snow: return .pine
        case .volcano: return .rock
        default: return .tree
        }
    }

    private mutating func clear(around t: RpgTile, radius: Int) {
        for dy in -radius...radius {
            for dx in -radius...radius where at(t.x + dx, t.y + dy).blocks || at(t.x + dx, t.y + dy) == .torch {
                set(t.x + dx, t.y + dy, floorType)
            }
        }
    }

    private mutating func carve(from a: RpgTile, to b: RpgTile, with t: RpgTileType, width: Int = 3) {
        let half = width / 2
        var x = a.x, y = a.y
        func paint() { for dy in -half...half { for dx in -half...half { set(x + dx, y + dy, t) } } }
        paint()
        while x != b.x { x += x < b.x ? 1 : -1; paint() }
        while y != b.y { y += y < b.y ? 1 : -1; paint() }
    }

    private mutating func border(_ t: RpgTileType, thickness: Int = 2) {
        for y in 0..<height { for x in 0..<width where x < thickness || y < thickness || x >= width - thickness || y >= height - thickness { set(x, y, t) } }
    }

    private mutating func blob(_ cx: Int, _ cy: Int, rx: Double, ry: Double, _ t: RpgTileType) {
        for y in (cy - Int(ry) - 1)...(cy + Int(ry) + 1) {
            for x in (cx - Int(rx) - 1)...(cx + Int(rx) + 1) {
                let dx = Double(x - cx) / rx, dy = Double(y - cy) / ry
                if dx * dx + dy * dy <= 1 { set(x, y, t) }
            }
        }
    }

    private mutating func buildTown() {
        for i in tiles.indices { tiles[i] = .grass }
        for y in 4..<(height - 3) { for x in 3..<(width - 3) { set(x, y, .stone) } }
        border(.tree)
        // Openings in the hedge: east road to the field, west for the 차원문.
        for y in 9...13 { for x in (width - 3)..<width { set(x, y, .path) } }
        for x in 16..<(width - 1) { for y in 10...12 { set(x, y, .path) } }
        for y in 10...12 { for x in 0..<4 { set(x, y, .stone) } }
        set(15, 12, .fountain); set(16, 12, .fountain); set(15, 13, .fountain); set(16, 13, .fountain)
        buildings = [
            RpgBuilding(x: 4, y: 3, w: 5, h: 4, place: .shop(.weapon)),
            RpgBuilding(x: 13, y: 3, w: 5, h: 4, place: .shop(.armor)),
            RpgBuilding(x: 22, y: 3, w: 5, h: 4, place: .shop(.potion)),
            RpgBuilding(x: 5, y: 15, w: 5, h: 4, place: .smith),
            RpgBuilding(x: 22, y: 15, w: 5, h: 4, place: .shop(.skill)),
            RpgBuilding(x: 14, y: 16, w: 3, h: 2, place: .board),
            RpgBuilding(x: 8, y: 8, w: 4, h: 3, place: .jobMaster),
        ]
        for (x, y) in [(4, 20), (11, 20), (20, 20), (27, 20), (3, 14), (12, 14)] { set(x, y, .flower) }
    }

    private mutating func buildOutdoor(_ rng: inout KartRNG, floor: RpgTileType, obstacle: RpgTileType, density: Int, rocks: Int, pools: Int,
                                       poolTile: RpgTileType, decor: RpgTileType, decorCount: Int) {
        for i in tiles.indices { tiles[i] = floor }
        let rockTile: RpgTileType = def.kind == .snow ? .iceRock : .rock
        for y in 0..<height {
            for x in 0..<width {
                let r = rng.int(100)
                if r < density { set(x, y, obstacle) } else if r < density + rocks { set(x, y, rockTile) }
            }
        }
        for _ in 0..<pools {
            blob(6 + rng.int(width - 12), 5 + rng.int(height - 10), rx: Double(3 + rng.int(3)), ry: Double(2 + rng.int(2)), poolTile)
        }
        // Clearings for monsters to roam.
        for _ in 0..<6 { blob(5 + rng.int(width - 10), 4 + rng.int(height - 8), rx: Double(3 + rng.int(3)), ry: Double(3 + rng.int(2)), floor) }
        border(obstacle)
        let hub = RpgTile(x: width / 2, y: height / 2)
        for p in def.portals { carve(from: p.at, to: hub, with: def.kind == .volcano ? .ash : .path) }
        for _ in 0..<decorCount {
            let x = rng.int(width), y = rng.int(height)
            if at(x, y) == floor { set(x, y, decor) }
        }
    }

    private mutating func buildCastle(_ rng: inout KartRNG) {
        for i in tiles.indices { tiles[i] = .castleFloor }
        border(.castleWall)
        // Great halls separated by walls with doorways, pillars in rows.
        for wx in stride(from: 12, to: width - 4, by: 12) {
            for y in 2..<(height - 2) { set(wx, y, .castleWall) }
            for gap in [height / 4, height / 2, 3 * height / 4] { for y in (gap - 1)...(gap + 1) { set(wx, y, .castleFloor) } }
        }
        for y in stride(from: 5, to: height - 4, by: 6) {
            for x in stride(from: 4, to: width - 4, by: 4) where at(x, y) == .castleFloor && rng.int(3) > 0 { set(x, y, .pillar) }
        }
        let hub = RpgTile(x: width / 2, y: height / 2)
        for p in def.portals { carve(from: p.at, to: hub, with: .carpet) }
        var placed = 0, tries = 0
        while placed < 22, tries < 3000 {
            tries += 1
            let x = 2 + rng.int(width - 4), y = 3 + rng.int(height - 5)
            guard at(x, y) == .castleFloor, at(x, y - 1) == .castleWall else { continue }
            set(x, y, .torch)
            torches.append(RpgTile(x: x, y: y))
            placed += 1
        }
    }

    private mutating func buildPond(_ rng: inout KartRNG) {
        for i in tiles.indices { tiles[i] = .grass }
        blob(width / 2, height / 2 - 1, rx: 6.5, ry: 3.6, .water)
        blob(width / 2, height / 2 - 1, rx: 1.5, ry: 0.8, .sand)
        border(.tree)
        for _ in 0..<70 {
            let x = rng.int(width), y = rng.int(height)
            if at(x, y) == .grass { set(x, y, .flower) }
        }
        carve(from: def.portals[0].at, to: RpgTile(x: width / 2, y: height - 4), with: .path, width: 1)
    }

    private mutating func buildCave(_ rng: inout KartRNG) {
        for i in tiles.indices { tiles[i] = rng.int(100) < 44 ? .caveWall : .caveFloor }
        // Cellular smoothing turns noise into blobby caverns.
        for _ in 0..<4 {
            var next = tiles
            for y in 0..<height {
                for x in 0..<width {
                    var walls = 0
                    for dy in -1...1 { for dx in -1...1 where !(dx == 0 && dy == 0) && at(x + dx, y + dy) == .caveWall { walls += 1 } }
                    next[y * width + x] = walls >= 5 ? .caveWall : (walls <= 3 ? .caveFloor : tiles[y * width + x])
                }
            }
            tiles = next
        }
        border(.caveWall)
        let hub = RpgTile(x: width / 2, y: height / 2)
        for p in def.portals { carve(from: p.at, to: hub, with: .caveFloor) }
        var placed = 0, tries = 0
        while placed < 18, tries < 4000 {
            tries += 1
            let x = 2 + rng.int(width - 4), y = 2 + rng.int(height - 4)
            guard at(x, y) == .caveFloor, at(x, y - 1) == .caveWall else { continue }
            set(x, y, .torch)
            torches.append(RpgTile(x: x, y: y))
            placed += 1
        }
    }

    private mutating func buildBoss() {
        for i in tiles.indices { tiles[i] = .caveWall }
        blob(width / 2, height / 2 - 1, rx: 11, ry: 8, .bossFloor)
        for p in def.portals { carve(from: p.at, to: RpgTile(x: width / 2, y: height / 2), with: .bossFloor) }
        border(.caveWall, thickness: 1)
        for p in def.portals where p.at.x == 0 || p.at.x >= width - 2 || p.at.y == 0 || p.at.y >= height - 2 { clear(around: p.at, radius: 1) }
        for k in 0..<10 {
            let a = Double(k) / 10 * .pi * 2
            let x = width / 2 + Int((cos(a) * 9.5).rounded()), y = height / 2 - 1 + Int((sin(a) * 6.8).rounded())
            if at(x, y) == .bossFloor { set(x, y, .torch); torches.append(RpgTile(x: x, y: y)) }
        }
    }

    private mutating func collectSpawns(_ rng: inout KartRNG) {
        let keepAway = def.portals.map(\.at) + RpgMaps.all.flatMap { m in m.portals.filter { $0.to == def.id }.map(\.arrive) }
        for y in 0..<height {
            for x in 0..<width where !at(x, y).blocks {
                let near = keepAway.contains { abs($0.x - x) + abs($0.y - y) < 7 }
                if !near, !isBlocked(Self.center(RpgTile(x: x, y: y))) { spawnTiles.append(RpgTile(x: x, y: y)) }
            }
        }
    }
}

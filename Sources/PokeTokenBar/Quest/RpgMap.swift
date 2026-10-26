import CoreGraphics
import Foundation

// SPIKE: tile maps for 픽셀 모험. The town is laid out by hand; the hunting grounds are generated from a
// fixed seed (same map every launch) and then corridors are carved between every portal so all of them
// are always reachable. 16-pixel tiles, world coordinates in pixels with y down.

enum RpgTileType: UInt8, Sendable {
    case grass, flower, path, stone, tree, water, rock, caveFloor, caveWall, torch, sand, bossFloor, fountain, darkGrass

    var blocks: Bool {
        switch self {
        case .tree, .water, .rock, .caveWall, .fountain: return true
        default: return false
        }
    }
}

struct RpgBuilding: Sendable {
    let x: Int, y: Int, w: Int, h: Int
    let shop: RpgShop
    /// Pixel point in front of the door where the shopkeeper stands.
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

    func at(_ x: Int, _ y: Int) -> RpgTileType {
        guard x >= 0, y >= 0, x < width, y < height else { return def.kind == .cave || def.kind == .boss ? .caveWall : .tree }
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
        case .field: buildOutdoor(&rng, floor: .grass, treeDensity: 7, rockDensity: 3, ponds: 2, flowers: 60)
        case .forest: buildOutdoor(&rng, floor: .darkGrass, treeDensity: 20, rockDensity: 3, ponds: 1, flowers: 25)
        case .pond: buildPond(&rng)
        case .cave: buildCave(&rng)
        case .boss: buildBoss()
        }
        // Every portal and arrival point gets breathing room.
        for p in def.portals { clear(around: p.at, radius: 1) }
        for other in RpgMaps.all {
            for p in other.portals where p.to == def.id { clear(around: p.arrive, radius: 1) }
        }
        collectSpawns(&rng)
    }

    private var floorType: RpgTileType {
        switch def.kind {
        case .cave: return .caveFloor
        case .boss: return .bossFloor
        case .town: return .stone
        case .forest: return .darkGrass
        default: return .grass
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
        // Opening in the east hedge for the portal road.
        for y in 9...13 { for x in (width - 3)..<width { set(x, y, .path) } }
        for x in 16..<(width - 1) { for y in 10...12 { set(x, y, .path) } }
        set(15, 12, .fountain); set(16, 12, .fountain); set(15, 13, .fountain); set(16, 13, .fountain)
        buildings = [
            RpgBuilding(x: 4, y: 3, w: 5, h: 4, shop: .weapon),
            RpgBuilding(x: 13, y: 3, w: 5, h: 4, shop: .armor),
            RpgBuilding(x: 22, y: 3, w: 5, h: 4, shop: .potion),
        ]
        for (x, y) in [(4, 16), (8, 18), (24, 17), (27, 18), (3, 10), (11, 17)] { set(x, y, .flower) }
        for (x, y) in [(6, 15), (26, 15)] { set(x, y, .tree) }
    }

    private mutating func buildOutdoor(_ rng: inout KartRNG, floor: RpgTileType, treeDensity: Int, rockDensity: Int, ponds: Int, flowers: Int) {
        for i in tiles.indices { tiles[i] = floor }
        for y in 0..<height {
            for x in 0..<width {
                let r = rng.int(100)
                if r < treeDensity { set(x, y, .tree) } else if r < treeDensity + rockDensity { set(x, y, .rock) }
            }
        }
        for _ in 0..<ponds {
            blob(6 + rng.int(width - 12), 5 + rng.int(height - 10), rx: Double(3 + rng.int(3)), ry: Double(2 + rng.int(2)), .water)
        }
        // Clearings for monsters to roam.
        for _ in 0..<5 { blob(5 + rng.int(width - 10), 4 + rng.int(height - 8), rx: Double(3 + rng.int(3)), ry: Double(3 + rng.int(2)), floor) }
        border(.tree)
        let hub = RpgTile(x: width / 2, y: height / 2)
        for p in def.portals { carve(from: p.at, to: hub, with: .path) }
        for _ in 0..<flowers {
            let x = rng.int(width), y = rng.int(height)
            if at(x, y) == floor { set(x, y, .flower) }
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
        // Torches on floor tiles hugging a wall.
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
        carve(from: def.portals[0].at, to: RpgTile(x: width / 2, y: height / 2), with: .bossFloor)
        border(.caveWall, thickness: 1)
        for k in 0..<10 {
            let a = Double(k) / 10 * .pi * 2
            let x = width / 2 + Int((cos(a) * 9.5).rounded()), y = height / 2 - 1 + Int((sin(a) * 6.8).rounded())
            if at(x, y) == .bossFloor { set(x, y, .torch); torches.append(RpgTile(x: x, y: y)) }
        }
    }

    private mutating func collectSpawns(_ rng: inout KartRNG) {
        let keepAway = def.portals.map(\.at) + RpgMaps.all.flatMap { m in m.portals.filter { $0.to == def.id }.map(\.arrive) }
        for y in 0..<height {
            for x in 0..<width where !at(x, y).blocks && at(x, y) != .water {
                let near = keepAway.contains { abs($0.x - x) + abs($0.y - y) < 7 }
                if !near, !isBlocked(Self.center(RpgTile(x: x, y: y))) { spawnTiles.append(RpgTile(x: x, y: y)) }
            }
        }
    }
}

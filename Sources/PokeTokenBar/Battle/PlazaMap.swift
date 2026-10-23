import Foundation

// SPIKE: the town map — world size and collision shapes measured from assets/battle/town.png.
// Shapes are fractions of the art (1536×1024) scaled to the 1024×683 world every peer shares.

enum PlazaMap {
    static let size = CGSize(width: 1024, height: 683)

    private static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
    }

    static let fountain = (center: CGPoint(x: 0.454 * size.width, y: 0.474 * size.height),
                           radius: CGSize(width: 0.065 * size.width, height: 0.059 * size.height))

    static let houses: [CGRect] = [
        rect(0.182, 0.049, 0.137, 0.225),   // red, top left
        rect(0.013, 0.200, 0.143, 0.215),   // green, far left
        rect(0.498, 0.059, 0.146, 0.215),   // orange, top
        rect(0.654, 0.132, 0.140, 0.215),   // teal, right
        rect(0.029, 0.527, 0.153, 0.234),   // orange, bottom left
        rect(0.384, 0.645, 0.150, 0.225),   // blue, bottom
    ]

    static let pond = rect(0.797, 0.322, 0.108, 0.137)
    static let pondInlet = rect(0.758, 0.508, 0.049, 0.059)
    static let bridge = rect(0.778, 0.464, 0.075, 0.068)

    /// Dense tree corners and the right-hand tree line.
    static let trees: [CGRect] = [
        rect(0.00, 0.00, 0.17, 0.19),
        rect(0.80, 0.00, 0.20, 0.30),
        rect(0.88, 0.28, 0.12, 0.45),
        rect(0.72, 0.72, 0.28, 0.28),
        rect(0.00, 0.80, 0.20, 0.20),
    ]

    /// On the cobblestone ring just below the fountain.
    static let spawnCenter = CGPoint(x: 0.454 * size.width, y: 0.63 * size.height)

    static func isWalkable(x: Double, y: Double) -> Bool {
        let w = size.width, h = size.height
        guard x > w * 0.02, x < w * 0.97, y > h * 0.11, y < h * 0.84 else { return false }
        let p = CGPoint(x: x, y: y)
        let fx = (x - fountain.center.x) / fountain.radius.width
        let fy = (y - fountain.center.y) / fountain.radius.height
        if fx * fx + fy * fy <= 1 { return false }
        if bridge.contains(p) { return true }
        if pond.contains(p) || pondInlet.contains(p) { return false }
        return !(houses + trees).contains { $0.contains(p) }
    }

    static func randomSpawn() -> CGPoint {
        for _ in 0..<200 {
            let p = CGPoint(x: spawnCenter.x + Double.random(in: -110...110), y: spawnCenter.y + Double.random(in: -20...20))
            if isWalkable(x: p.x, y: p.y) { return p }
        }
        return spawnCenter
    }
}

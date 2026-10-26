import CoreGraphics
import Foundation

// SPIKE: one closed top-down race track for the kart prototype. Coordinates are low-res pixels, y down.
// The centerline is a closed Catmull-Rom spline resampled to even spacing, so a sample index doubles
// as race progress: lap = crossing from the last quarter of samples into the first.

struct KartTrack: Sendable {
    let size: CGSize
    let halfWidth: CGFloat
    let samples: [CGPoint]
    /// Heading of the centerline at each sample (radians, y down).
    let angles: [CGFloat]
    /// Samples carrying a boost pad.
    let padIndexes: [Int]

    var count: Int { samples.count }

    static let spacing: CGFloat = 2

    static let standard = KartTrack(
        controlPoints: [
            // First point = start line, on the left straight so the grid lines up behind it.
            CGPoint(x: 100, y: 290), CGPoint(x: 130, y: 140), CGPoint(x: 220, y: 80),
            CGPoint(x: 320, y: 100), CGPoint(x: 360, y: 190), CGPoint(x: 420, y: 250), CGPoint(x: 500, y: 220),
            CGPoint(x: 540, y: 130), CGPoint(x: 620, y: 90), CGPoint(x: 670, y: 160), CGPoint(x: 660, y: 280),
            CGPoint(x: 600, y: 340), CGPoint(x: 560, y: 410), CGPoint(x: 420, y: 420), CGPoint(x: 300, y: 370),
            CGPoint(x: 200, y: 430), CGPoint(x: 110, y: 400),
        ],
        size: CGSize(width: 720, height: 480), halfWidth: 24, padFractions: [0.2, 0.52, 0.83])

    init(controlPoints: [CGPoint], size: CGSize, halfWidth: CGFloat, padFractions: [CGFloat]) {
        self.size = size
        self.halfWidth = halfWidth
        let n = controlPoints.count
        var dense: [CGPoint] = []
        for i in 0..<n {
            let p0 = controlPoints[(i - 1 + n) % n], p1 = controlPoints[i]
            let p2 = controlPoints[(i + 1) % n], p3 = controlPoints[(i + 2) % n]
            for s in 0..<40 { dense.append(Self.catmullRom(p0, p1, p2, p3, CGFloat(s) / 40)) }
        }
        // Walk the dense polyline and drop a sample every `spacing` pixels of arc length.
        var out = [dense[0]]
        var carry: CGFloat = 0
        var prev = dense[0]
        for k in 1...dense.count {
            let next = dense[k % dense.count]
            var start = prev
            var segLen = hypot(next.x - start.x, next.y - start.y)
            while carry + segLen >= Self.spacing, segLen > 0 {
                let f = (Self.spacing - carry) / segLen
                let p = CGPoint(x: start.x + (next.x - start.x) * f, y: start.y + (next.y - start.y) * f)
                out.append(p)
                start = p
                segLen = hypot(next.x - start.x, next.y - start.y)
                carry = 0
            }
            carry += segLen
            prev = next
        }
        if let last = out.last, hypot(last.x - out[0].x, last.y - out[0].y) < Self.spacing * 0.5 { out.removeLast() }
        samples = out
        let c = out.count
        angles = (0..<c).map { i in
            let a = out[(i - 1 + c) % c], b = out[(i + 1) % c]
            return atan2(b.y - a.y, b.x - a.x)
        }
        padIndexes = padFractions.map { Int($0 * CGFloat(c)) }
    }

    private static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let t2 = t * t, t3 = t2 * t
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        }
        return CGPoint(x: axis(p0.x, p1.x, p2.x, p3.x), y: axis(p0.y, p1.y, p2.y, p3.y))
    }

    func wrap(_ i: Int) -> Int { ((i % count) + count) % count }

    /// Unit vector pointing to the right of the driving direction at sample `i`.
    func normal(at i: Int) -> CGPoint {
        let a = angles[wrap(i)]
        return CGPoint(x: -sin(a), y: cos(a))
    }

    func point(at i: Int, offset: CGFloat = 0) -> CGPoint {
        let s = samples[wrap(i)], n = normal(at: i)
        return CGPoint(x: s.x + n.x * offset, y: s.y + n.y * offset)
    }

    /// Nearest centerline sample. With a hint only the neighbourhood is scanned (karts move a few
    /// samples per frame); a far miss falls back to the whole track.
    func nearest(to p: CGPoint, near hint: Int? = nil) -> (index: Int, distance: CGFloat) {
        func scan(_ lo: Int, _ hi: Int) -> (Int, CGFloat) {
            var best = 0, bestD = CGFloat.greatestFiniteMagnitude
            for raw in lo...hi {
                let i = wrap(raw), s = samples[i]
                let d = (s.x - p.x) * (s.x - p.x) + (s.y - p.y) * (s.y - p.y)
                if d < bestD { bestD = d; best = i }
            }
            return (best, bestD.squareRoot())
        }
        if let hint {
            let r = scan(hint - 40, hint + 40)
            if r.1 < halfWidth * 3 { return r }
        }
        return scan(0, count - 1)
    }

    /// Signed sample distance from `a` to `b` along the loop, in -count/2 ..< count/2.
    func delta(from a: Int, to b: Int) -> Int {
        var d = wrap(b - a)
        if d >= count / 2 { d -= count }
        return d
    }
}

import AppKit
import CoreGraphics

// SPIKE: art for 메아리. Generated backgrounds, stone texture and the exit shrine live in assets/echo
// (bundled under Resources/echo by build-app.sh; a raw `swift run` reads the checkout). Everything has a
// drawn fallback. The world is drawn into a half-resolution bitmap (one art pixel = 2 world units,
// a tile = 15 px) and scaled up with nearest-neighbour, like the kart.

@MainActor
enum EchoArt {
    static let scale = 2.0
    static let width = Int(Double(EchoCore.cols) * EchoCore.tile / scale)
    static let height = Int(Double(EchoCore.rows) * EchoCore.tile / scale)
    static let tilePx = CGFloat(EchoCore.tile / scale)

    private static var cache: [String: CGImage] = [:]

    private static var directories: [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("echo")) }
        dirs.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../assets/echo").standardized)
        return dirs
    }

    private static func load(_ name: String) -> CGImage? {
        for dir in directories {
            if let img = NSImage(contentsOf: dir.appendingPathComponent("\(name).png")),
               let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) { return cg }
        }
        return nil
    }

    private static func cached(_ key: String, _ make: () -> CGImage?) -> CGImage? {
        if let hit = cache[key] { return hit }
        let img = make()
        if let img { cache[key] = img }
        return img
    }

    /// Background scaled to cover the frame.
    static func background(night: Bool) -> CGImage? {
        cached(night ? "bg-night" : "bg-day") {
            guard let src = load(night ? "forest_night" : "forest_day"),
                  let ctx = KartArt.context(width: width, height: height, flipped: false) else { return nil }
            ctx.interpolationQuality = .medium
            let s = max(Double(width) / Double(src.width), Double(height) / Double(src.height))
            let w = Double(src.width) * s, h = Double(src.height) * s
            ctx.draw(src, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
            return ctx.makeImage()
        }
    }

    /// The exit shrine, keyed out of its flat magenta backdrop and cropped.
    static var shrine: CGImage? {
        cached("shrine") {
            guard let src = load("shrine") else { return nil }
            return keyed(src, height: 34)
        }
    }

    private static var stone: CGImage? {
        cached("stone") {
            guard let src = load("stone"), let ctx = KartArt.context(width: 90, height: 90, flipped: false) else { return nil }
            ctx.interpolationQuality = .medium
            ctx.draw(src, in: CGRect(x: 0, y: 0, width: 90, height: 90))
            return ctx.makeImage()
        }
    }

    /// Removes a near-magenta background, crops to the subject and scales to `height` px.
    private static func keyed(_ src: CGImage, height: Int) -> CGImage? {
        let w = src.width, h = src.height
        guard let ctx = KartArt.context(width: w, height: h, flipped: false), let data = ctx.data else { return nil }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let i = y * ctx.bytesPerRow + x * 4
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                if r > 150, b > 150, g < 110, abs(r - b) < 90 {
                    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0
                } else {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX > minX, maxY > minY, let full = ctx.makeImage(),
              let cropped = full.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else { return nil }
        let s = Double(height) / Double(cropped.height)
        let tw = max(1, Int(Double(cropped.width) * s)), th = height
        guard let out = KartArt.context(width: tw, height: th, flipped: false) else { return nil }
        out.interpolationQuality = .medium
        out.draw(cropped, in: CGRect(x: 0, y: 0, width: tw, height: th))
        return out.makeImage()
    }

    // MARK: terrain

    /// Static layer for a level: stone blocks with grass on exposed tops and shading on exposed sides.
    static func terrain(_ level: EchoLevel) -> CGImage? {
        guard let ctx = KartArt.context(width: width, height: height) else { return nil }
        let t = tilePx
        let stone = self.stone
        for ty in 0..<EchoCore.rows {
            for tx in 0..<EchoCore.cols where EchoCore.isWall(level, tx, ty) {
                let x = CGFloat(tx) * t, y = CGFloat(ty) * t
                let rect = CGRect(x: x, y: y, width: t, height: t)
                if let stone {
                    ctx.saveGState()
                    ctx.clip(to: rect)
                    let ox = (x / 90).rounded(.down) * 90, oy = (y / 90).rounded(.down) * 90
                    KartArt.draw(stone, in: ctx, rect: CGRect(x: ox, y: oy, width: 90, height: 90))
                    ctx.restoreGState()
                } else {
                    KartArt.fill(ctx, KartArt.rgb(92, 98, 88), x, y, t, t)
                    KartArt.fill(ctx, KartArt.rgb(74, 80, 72), x, y + t - 3, t, 3)
                }
                let open = { (dx: Int, dy: Int) in !EchoCore.isWall(level, tx + dx, ty + dy) }
                // Deep blocks darken so the playable edges read first.
                if !open(0, -1) && !open(-1, 0) && !open(1, 0) && !open(0, 1) {
                    KartArt.fill(ctx, KartArt.rgb(10, 18, 14, 0.38), x, y, t, t)
                }
                if open(0, -1) {
                    KartArt.fill(ctx, KartArt.rgb(58, 128, 52), x, y, t, 4)
                    KartArt.fill(ctx, KartArt.rgb(112, 196, 78), x, y, t, 2)
                    for k in stride(from: 1, to: Int(t), by: 3) {
                        KartArt.fill(ctx, KartArt.rgb(140, 214, 96), x + CGFloat(k), y - 1, 1, 1)
                        if (tx * 7 + k) % 5 == 0 { KartArt.fill(ctx, KartArt.rgb(58, 128, 52), x + CGFloat(k), y + 4, 1, 2) }
                    }
                }
                if open(-1, 0) { KartArt.fill(ctx, KartArt.rgb(255, 255, 255, 0.10), x, y, 1, t) }
                if open(1, 0) { KartArt.fill(ctx, KartArt.rgb(0, 0, 0, 0.22), x + t - 1, y, 1, t) }
                if open(0, 1) { KartArt.fill(ctx, KartArt.rgb(0, 0, 0, 0.30), x, y + t - 1, t, 1) }
            }
        }
        for s in level.spikes { spikes(ctx, CGFloat(s.x / scale) - 2, CGFloat(s.y / scale) - 7) }
        return ctx.makeImage()
    }

    /// A row of thorny brambles filling one tile from (x, y).
    private static func spikes(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat) {
        KartArt.fill(ctx, KartArt.rgb(52, 30, 38), x, y + 10, tilePx, 5)
        for k in 0..<5 {
            let bx = x + CGFloat(k) * 3
            KartArt.fill(ctx, KartArt.rgb(150, 40, 60), bx + 1, y + 4, 1, 6)
            KartArt.fill(ctx, KartArt.rgb(220, 70, 90), bx + 1, y + 3, 1, 1)
            KartArt.fill(ctx, KartArt.rgb(110, 30, 46), bx, y + 7, 3, 1)
        }
    }

    // MARK: dynamic pieces

    static func plate(_ ctx: CGContext, _ r: EchoRect, lit: Bool) {
        let x = CGFloat(r.x / scale), y = CGFloat((r.y + r.h) / scale)
        let w = CGFloat(r.w / scale)
        KartArt.fill(ctx, KartArt.rgb(70, 74, 82), x, y - 3, w, 3)
        KartArt.fill(ctx, KartArt.rgb(150, 156, 166), x + 1, y - 3, w - 2, 1)
        let press: CGFloat = lit ? 1 : 0
        KartArt.fill(ctx, lit ? KartArt.rgb(255, 214, 70) : KartArt.rgb(220, 60, 60), x + 3, y - 5 + press, w - 6, 2)
        if lit { KartArt.fill(ctx, KartArt.rgb(255, 240, 150, 0.35), x - 1, y - 9, w + 2, 6) }
    }

    /// A closed door is an iron gate; an open one leaves its frame.
    static func door(_ ctx: CGContext, tx: Int, ty: Int, open: Bool, clock: Double) {
        let t = tilePx, x = CGFloat(tx) * t, y = CGFloat(ty) * t
        KartArt.fill(ctx, KartArt.rgb(64, 46, 34), x, y, 2, t)
        KartArt.fill(ctx, KartArt.rgb(64, 46, 34), x + t - 2, y, 2, t)
        guard !open else {
            KartArt.fill(ctx, KartArt.rgb(255, 255, 255, 0.10), x + 2, y, t - 4, t)
            return
        }
        for k in stride(from: 3, to: Int(t) - 2, by: 3) {
            KartArt.fill(ctx, KartArt.rgb(70, 76, 92), x + CGFloat(k), y, 2, t)
            KartArt.fill(ctx, KartArt.rgb(150, 160, 180), x + CGFloat(k), y, 1, t)
        }
        KartArt.fill(ctx, KartArt.rgb(90, 96, 112), x + 2, y + 2, t - 4, 1)
        let glow = 0.25 + 0.15 * sin(clock * 4)
        KartArt.fill(ctx, KartArt.rgb(255, 80, 90, glow), x + t / 2 - 1, y + t / 2 - 1, 3, 3)
    }

    static func exit(_ ctx: CGContext, _ r: EchoRect, clock: Double) {
        let cx = CGFloat((r.x + r.w / 2) / scale), bottom = CGFloat((r.y + r.h) / scale)
        let pulse = CGFloat(0.5 + 0.5 * sin(clock * 3))
        ctx.setFillColor(KartArt.rgb(170, 255, 200, 0.18 + 0.12 * pulse))
        ctx.fillEllipse(in: CGRect(x: cx - 14, y: bottom - 34, width: 28, height: 34))
        if let shrine {
            let w = CGFloat(shrine.width), h = CGFloat(shrine.height)
            KartArt.draw(shrine, in: ctx, rect: CGRect(x: (cx - w / 2).rounded(), y: bottom - h, width: w, height: h))
        } else {
            KartArt.fill(ctx, KartArt.rgb(90, 60, 40), cx - 10, bottom - 26, 20, 4)
            KartArt.fill(ctx, KartArt.rgb(120, 84, 56), cx - 8, bottom - 22, 3, 22)
            KartArt.fill(ctx, KartArt.rgb(120, 84, 56), cx + 5, bottom - 22, 3, 22)
            KartArt.fill(ctx, KartArt.rgb(190, 255, 210, 0.7), cx - 5, bottom - 20, 10, 20)
        }
        for k in 0..<3 {
            let p = CGFloat((clock * 0.5 + Double(k) / 3).truncatingRemainder(dividingBy: 1))
            KartArt.fill(ctx, KartArt.rgb(210, 255, 220, 0.8 * (1 - p)), cx - 6 + CGFloat(k) * 6, bottom - 6 - p * 26, 1, 1)
        }
    }

    // MARK: Pokémon

    /// A copy of `img` washed in `color` (echoes read as ghostly versions of the same Pokémon).
    static func tinted(_ img: CGImage, _ color: CGColor, amount: CGFloat) -> CGImage? {
        guard let ctx = KartArt.context(width: img.width, height: img.height, flipped: false) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: img.width, height: img.height)
        ctx.draw(img, in: rect)
        ctx.setBlendMode(.sourceAtop)
        ctx.setFillColor(color.copy(alpha: amount) ?? color)
        ctx.fill(rect)
        return ctx.makeImage()
    }

    static let echoTints: [CGColor] = [
        KartArt.rgb(150, 110, 255), KartArt.rgb(90, 200, 255), KartArt.rgb(255, 140, 210), KartArt.rgb(120, 230, 170),
    ]
}

import AppKit
import CoreGraphics

// SPIKE: pixel art for the kart prototype, all drawn in code: the track bitmap, kart bodies and the
// rider sprites (cached Pokémon PNGs cropped and shrunk). Everything renders into y-down bitmaps with
// antialiasing off so the low-res frame keeps hard pixel edges when scaled up.

struct KartPaint {
    let body: CGColor
    let dark: CGColor
    let light: CGColor
}

@MainActor
enum KartArt {
    static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }

    static let paints: [KartPaint] = [
        KartPaint(body: rgb(226, 58, 58), dark: rgb(140, 28, 34), light: rgb(255, 150, 140)),
        KartPaint(body: rgb(58, 110, 226), dark: rgb(28, 56, 140), light: rgb(150, 186, 255)),
        KartPaint(body: rgb(56, 176, 88), dark: rgb(26, 104, 48), light: rgb(150, 230, 160)),
        KartPaint(body: rgb(240, 186, 40), dark: rgb(160, 110, 18), light: rgb(255, 232, 140)),
    ]

    /// RGBA bitmap context. `flipped` puts the origin top-left with y down, like the game world.
    static func context(width: Int, height: Int, flipped: Bool = true) -> CGContext? {
        guard let ctx = CGContext(data: nil, width: max(1, width), height: max(1, height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        if flipped {
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
        }
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        return ctx
    }

    /// Draws an image upright into a y-down context (a plain `draw` would come out upside down).
    static func draw(_ img: CGImage, in ctx: CGContext, rect: CGRect, flipX: Bool = false) {
        ctx.saveGState()
        ctx.translateBy(x: flipX ? rect.maxX : rect.minX, y: rect.maxY)
        ctx.scaleBy(x: flipX ? -1 : 1, y: -1)
        ctx.draw(img, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }

    static func fill(_ ctx: CGContext, _ color: CGColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    /// Runs `body` in a frame centred on `p` and rotated so +x runs along `angle`.
    static func local(_ ctx: CGContext, at p: CGPoint, angle: CGFloat, _ body: (CGContext) -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: angle)
        body(ctx)
        ctx.restoreGState()
    }

    // MARK: track

    static func renderTrack(_ track: KartTrack) -> CGImage? {
        let w = Int(track.size.width), h = Int(track.size.height)
        guard let ctx = context(width: w, height: h) else { return nil }
        var rng = KartRNG(seed: 0x6B61_7274)
        let hw = track.halfWidth

        // Grass with mowing stripes and speckles.
        fill(ctx, rgb(84, 160, 70), 0, 0, CGFloat(w), CGFloat(h))
        for y in stride(from: 0, to: h, by: 24) { fill(ctx, rgb(92, 172, 78), 0, CGFloat(y), CGFloat(w), 12) }
        let grassDots = [rgb(70, 140, 60), rgb(116, 190, 94), rgb(64, 128, 56)]
        for _ in 0..<(w * h / 12) {
            fill(ctx, grassDots[rng.int(grassDots.count)], CGFloat(rng.int(w)), CGFloat(rng.int(h)), 1, 1)
        }

        let path = CGMutablePath()
        path.addLines(between: track.samples)
        path.closeSubpath()
        func stroke(_ color: CGColor, width: CGFloat, dash: [CGFloat] = []) {
            ctx.addPath(path)
            ctx.setStrokeColor(color)
            ctx.setLineWidth(width)
            ctx.setLineJoin(.round)
            ctx.setLineCap(dash.isEmpty ? .round : .butt)
            ctx.setLineDash(phase: 0, lengths: dash)
            ctx.strokePath()
        }
        stroke(rgb(212, 194, 138), width: hw * 2 + 16)                  // sand run-off
        stroke(rgb(242, 242, 242), width: hw * 2 + 6)                   // curb
        stroke(rgb(210, 50, 50), width: hw * 2 + 6, dash: [6, 6])
        stroke(rgb(82, 84, 94), width: hw * 2)                          // asphalt
        let asphaltDots = [rgb(94, 96, 106), rgb(70, 72, 82)]
        for i in 0..<track.count {
            for _ in 0..<3 {
                let p = track.point(at: i, offset: CGFloat(rng.int(Int(hw * 2) - 4)) - hw + 2)
                fill(ctx, asphaltDots[rng.int(2)], p.x.rounded(), p.y.rounded(), 1, 1)
            }
        }
        stroke(rgb(236, 232, 210, 0.6), width: 1, dash: [8, 10])        // centre line

        // Start / finish: two rows of checkers across the road.
        local(ctx, at: track.samples[0], angle: track.angles[0]) { c in
            for col in 0..<2 {
                for (row, y) in stride(from: -hw, to: hw, by: 3).enumerated() {
                    fill(c, (col + row) % 2 == 0 ? rgb(250, 250, 250) : rgb(24, 24, 28), CGFloat(col * 3 - 3), y, 3, 3)
                }
            }
        }

        // Boost pads: yellow plates with chevrons pointing along the track.
        for i in track.padIndexes {
            local(ctx, at: track.samples[i], angle: track.angles[i]) { c in
                fill(c, rgb(120, 70, 10), -8, -9, 16, 18)
                fill(c, rgb(250, 200, 40), -7, -8, 14, 16)
                for shift in [-5, 1] as [CGFloat] {
                    for k in 0..<4 {
                        let kk = CGFloat(k)
                        fill(c, rgb(232, 86, 28), shift + kk, -6 + kk, 2, 2)
                        fill(c, rgb(232, 86, 28), shift + kk, 4 - kk, 2, 2)
                    }
                }
            }
        }

        // Trees and flowers, kept clear of the road.
        var placed = 0, tries = 0
        while placed < 80, tries < 2000 {
            tries += 1
            let p = CGPoint(x: CGFloat(8 + rng.int(w - 16)), y: CGFloat(10 + rng.int(h - 20)))
            guard track.nearest(to: p).distance > hw + 22 else { continue }
            tree(ctx, p)
            placed += 1
        }
        let petals = [rgb(250, 250, 250), rgb(250, 120, 160), rgb(255, 220, 60)]
        for _ in 0..<160 {
            let p = CGPoint(x: CGFloat(rng.int(w)), y: CGFloat(rng.int(h)))
            guard track.nearest(to: p).distance > hw + 12 else { continue }
            fill(ctx, petals[rng.int(petals.count)], p.x, p.y, 1, 1)
        }
        return ctx.makeImage()
    }

    private static func tree(_ ctx: CGContext, _ p: CGPoint) {
        let x = p.x, y = p.y
        fill(ctx, rgb(0, 0, 0, 0.22), x - 4, y + 4, 9, 3)                 // shadow
        fill(ctx, rgb(104, 66, 36), x - 1, y + 2, 2, 4)                   // trunk
        fill(ctx, rgb(34, 98, 46), x - 4, y - 4, 8, 7)
        fill(ctx, rgb(34, 98, 46), x - 3, y - 6, 6, 2)
        fill(ctx, rgb(34, 98, 46), x - 3, y + 3, 6, 1)
        fill(ctx, rgb(62, 140, 64), x - 3, y - 5, 4, 3)                   // highlight
        fill(ctx, rgb(92, 170, 84), x - 2, y - 5, 2, 1)
    }

    // MARK: karts

    /// Kart body seen from above, nose along +x. Drawn in a local frame around the kart centre.
    static func kart(_ ctx: CGContext, paint: KartPaint) {
        let tyre = rgb(30, 30, 36)
        fill(ctx, tyre, -7, -6, 4, 3)
        fill(ctx, tyre, -7, 3, 4, 3)
        fill(ctx, tyre, 3, -6, 4, 3)
        fill(ctx, tyre, 3, 3, 4, 3)
        fill(ctx, paint.dark, -8, -4, 2, 8)          // rear spoiler
        fill(ctx, paint.body, -6, -4, 12, 8)
        fill(ctx, paint.light, -5, -4, 9, 1)
        fill(ctx, paint.dark, 5, -3, 3, 6)           // nose
        fill(ctx, rgb(36, 36, 44), -4, -2, 5, 4)     // seat
    }

    // MARK: riders

    /// The cached Pokémon sprite trimmed to its visible pixels and shrunk to `height` pixels.
    static func rider(from image: NSImage, height: Int) -> CGImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width, h = cg.height
        guard let scan = context(width: w, height: h, flipped: false) else { return nil }
        scan.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = scan.data else { return nil }
        let px = data.bindMemory(to: UInt8.self, capacity: scan.bytesPerRow * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px[y * scan.bytesPerRow + x * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let full = scan.makeImage(),
              let cropped = full.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else { return nil }
        let scale = min(CGFloat(height) / CGFloat(cropped.height), 26 / CGFloat(cropped.width))
        let tw = max(1, Int((CGFloat(cropped.width) * scale).rounded()))
        let th = max(1, Int((CGFloat(cropped.height) * scale).rounded()))
        guard let out = context(width: tw, height: th, flipped: false) else { return nil }
        out.interpolationQuality = .medium
        out.draw(cropped, in: CGRect(x: 0, y: 0, width: tw, height: th))
        return out.makeImage()
    }
}

/// Small deterministic generator so the track art is the same every launch.
struct KartRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upper: Int) -> Int { Int(next() % UInt64(max(1, upper))) }
}

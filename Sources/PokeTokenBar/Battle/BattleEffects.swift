import SwiftUI

// SPIKE: drawn battle effects — the thrown ball, its opening burst, and per-type move effects.
// Everything is procedural (Canvas + TimelineView) so it needs no extra art and stays crisp.

/// Red/white capture ball with a band and button.
struct CaptureBall: View {
    var size: CGFloat = 22

    var body: some View {
        Canvas { ctx, s in
            let r = CGRect(origin: .zero, size: s).insetBy(dx: 1, dy: 1)
            var top = Path(); top.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2,
                                         startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.fill(Path(ellipseIn: r), with: .color(.white))
            ctx.fill(top, with: .color(Color(red: 0.9, green: 0.15, blue: 0.15)))
            ctx.fill(Path(CGRect(x: r.minX, y: r.midY - s.height * 0.06, width: r.width, height: s.height * 0.12)),
                     with: .color(.black))
            ctx.stroke(Path(ellipseIn: r), with: .color(.black), lineWidth: max(1.5, s.width * 0.07))
            let b = s.width * 0.34
            ctx.fill(Path(ellipseIn: CGRect(x: r.midX - b / 2, y: r.midY - b / 2, width: b, height: b)), with: .color(.black))
            let w = b * 0.6
            ctx.fill(Path(ellipseIn: CGRect(x: r.midX - w / 2, y: r.midY - w / 2, width: w, height: w)), with: .color(.white))
            ctx.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.14,
                                            width: r.width * 0.22, height: r.height * 0.14)), with: .color(.white.opacity(0.6)))
        }
        .frame(width: size, height: size)
    }
}

/// Deterministic pseudo-random in 0..<1 for particle `i`, channel `k`.
private func rand(_ i: Int, _ k: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: i &* 7919 &+ k &* 104_729) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    return Double((x ^ (x >> 31)) % 10_000) / 10_000
}

/// One playing effect. `start` anchors the timeline; views draw `t` = seconds since start.
struct BattleEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        case ballOpen                                   // white flash + sparkles at `to`
        case move(type: String, physical: Bool)         // projectile/impact from `from` to `to`
        case impact(strong: Bool)                       // hit spark at `to`
    }
    let id = UUID()
    let kind: Kind
    let from: CGPoint
    let to: CGPoint
    let start = Date()

    var duration: Double {
        switch kind {
        case .ballOpen: 0.55
        case .move(_, let physical): physical ? 0.45 : 0.75
        case .impact: 0.35
        }
    }
}

struct BattleEffectLayer: View {
    let effects: [BattleEffect]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, _ in
                for effect in effects {
                    let t = timeline.date.timeIntervalSince(effect.start)
                    guard t >= 0, t <= effect.duration else { continue }
                    // Bright types glow when particles overlap; dark/earthy ones would vanish that way.
                    if case .move(let type, _) = effect.kind, ["ghost", "dark", "rock", "ground", "poison"].contains(type) {
                        ctx.blendMode = .normal
                    } else {
                        ctx.blendMode = .plusLighter
                    }
                    draw(effect, t: t, in: &ctx)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ e: BattleEffect, t: Double, in ctx: inout GraphicsContext) {
        switch e.kind {
        case .ballOpen: ballOpen(at: e.to, t: t / e.duration, ctx: &ctx)
        case .impact(let strong): impact(at: e.to, t: t / e.duration, strong: strong, ctx: &ctx)
        case .move(let type, let physical):
            let style = TypeStyle(type)
            if physical {
                burst(style, at: e.to, t: t / e.duration, ctx: &ctx)
            } else {
                // First 65%: stream of particles travelling; last part: burst on the target.
                let p = t / e.duration
                if p < 0.65 { stream(style, from: e.from, to: e.to, t: p / 0.65, ctx: &ctx) }
                if p > 0.5 { burst(style, at: e.to, t: (p - 0.5) / 0.5, ctx: &ctx) }
            }
        }
    }

    // MARK: Ball

    private func ballOpen(at c: CGPoint, t: Double, ctx: inout GraphicsContext) {
        let flash = max(0, 1 - t * 1.6)
        let r = 10 + t * 70
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(colors: [.white.opacity(flash), .white.opacity(0)]),
                                       center: c, startRadius: 0, endRadius: r))
        for i in 0..<14 {
            let a = Double(i) / 14 * .pi * 2 + rand(i, 1) * 0.4
            let d = t * (50 + rand(i, 2) * 40)
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.8)
            star(at: p, r: 4 * (1 - t) + 1, color: i % 3 == 0 ? Color(red: 1, green: 0.85, blue: 0.4) : .white,
                 opacity: 1 - t, ctx: &ctx)
        }
    }

    // MARK: Moves

    private func stream(_ s: TypeStyle, from a: CGPoint, to b: CGPoint, t: Double, ctx: inout GraphicsContext) {
        for i in 0..<30 {
            let lag = Double(i) / 30 * 0.45
            let p = min(1, max(0, (t - lag) / (1 - 0.45)))
            guard p > 0, p < 1 else { continue }
            let wobble = sin((p * 6 + rand(i, 3)) * .pi) * s.wobble
            let x = a.x + (b.x - a.x) * p + wobble * (rand(i, 4) - 0.5) * 2
            let y = a.y + (b.y - a.y) * p - sin(p * .pi) * s.arc + wobble
            particle(s, i: i, at: CGPoint(x: x, y: y), size: s.size * 1.5 * (0.7 + rand(i, 5) * 0.6), age: p, ctx: &ctx)
        }
        if s.shape == .bolt { bolt(from: a, to: b, t: t, color: s.colors[0], ctx: &ctx) }
    }

    private func burst(_ s: TypeStyle, at c: CGPoint, t: Double, ctx: inout GraphicsContext) {
        let glow = 30 + t * 45
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - glow, y: c.y - glow, width: glow * 2, height: glow * 2)),
                 with: .radialGradient(Gradient(colors: [.white.opacity(0.5 * (1 - t)), s.colors[0].opacity(0.6 * (1 - t)), .clear]),
                                       center: c, startRadius: 0, endRadius: glow))
        for i in 0..<26 {
            let a = rand(i, 6) * .pi * 2
            let d = t * (30 + rand(i, 7) * 50)
            let rise = s.rises ? -t * 26 : (s.falls ? t * 18 : 0)
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.7 + rise)
            particle(s, i: i, at: p, size: s.size * 1.7 * (1.2 - t * 0.6), age: t, ctx: &ctx)
        }
        if s.shape == .ring {
            for k in 0..<3 {
                let rr = (t * 1.4 - Double(k) * 0.2) * 46
                guard rr > 0 else { continue }
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr * 0.7, width: rr * 2, height: rr * 1.4)),
                           with: .color(s.colors[k % s.colors.count].opacity(max(0, 1 - t))), lineWidth: 3)
            }
        }
        if s.shape == .bolt, t < 0.6 { bolt(from: CGPoint(x: c.x, y: c.y - 70), to: c, t: 1, color: s.colors[0], ctx: &ctx) }
    }

    private func impact(at c: CGPoint, t: Double, strong: Bool, ctx: inout GraphicsContext) {
        let r = (strong ? 40 : 28) * (0.5 + t)
        var spark = Path()
        let spikes = 8
        for k in 0..<(spikes * 2) {
            let a = Double(k) / Double(spikes * 2) * .pi * 2
            let rr = k % 2 == 0 ? r : r * 0.4
            let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            k == 0 ? spark.move(to: p) : spark.addLine(to: p)
        }
        spark.closeSubpath()
        ctx.fill(spark, with: .color(Color(red: 1, green: 0.95, blue: 0.6).opacity(1 - t)))
        ctx.stroke(spark, with: .color(Color(red: 1, green: 0.55, blue: 0.1).opacity(1 - t)), lineWidth: 2)
    }

    private func particle(_ s: TypeStyle, i: Int, at p: CGPoint, size: Double, age: Double, ctx: inout GraphicsContext) {
        let color = s.colors[i % s.colors.count].opacity(max(0, 1 - age * 0.7))
        let rect = CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
        switch s.shape {
        case .orb, .ring, .bolt:
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: size * 0.3, dy: size * 0.3)), with: .color(.white.opacity(0.7 * (1 - age))))
        case .drop:
            var d = Path()
            d.move(to: CGPoint(x: p.x, y: p.y - size * 0.8))
            d.addQuadCurve(to: CGPoint(x: p.x, y: p.y + size / 2), control: CGPoint(x: p.x + size * 0.7, y: p.y + size * 0.2))
            d.addQuadCurve(to: CGPoint(x: p.x, y: p.y - size * 0.8), control: CGPoint(x: p.x - size * 0.7, y: p.y + size * 0.2))
            ctx.fill(d, with: .color(color))
        case .leaf:
            var c = ctx
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(age * 8 + Double(i)))
            c.fill(Path(ellipseIn: CGRect(x: -size, y: -size * 0.35, width: size * 2, height: size * 0.7)), with: .color(color))
        case .shard:
            var c = ctx
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(Double(i) * 0.7))
            var d = Path()
            d.move(to: CGPoint(x: 0, y: -size)); d.addLine(to: CGPoint(x: size * 0.45, y: 0))
            d.addLine(to: CGPoint(x: 0, y: size)); d.addLine(to: CGPoint(x: -size * 0.45, y: 0)); d.closeSubpath()
            c.fill(d, with: .color(color))
            c.stroke(d, with: .color(.white.opacity(0.6 * (1 - age))), lineWidth: 1)
        case .rock:
            ctx.fill(Path(roundedRect: rect, cornerRadius: size * 0.2), with: .color(color))
        case .star:
            star(at: p, r: size / 2, color: s.colors[i % s.colors.count], opacity: 1 - age, ctx: &ctx)
        }
    }

    private func star(at p: CGPoint, r: Double, color: Color, opacity: Double, ctx: inout GraphicsContext) {
        var d = Path()
        for k in 0..<8 {
            let a = Double(k) / 8 * .pi * 2
            let rr = k % 2 == 0 ? r : r * 0.35
            let q = CGPoint(x: p.x + cos(a) * rr, y: p.y + sin(a) * rr)
            k == 0 ? d.move(to: q) : d.addLine(to: q)
        }
        d.closeSubpath()
        ctx.fill(d, with: .color(color.opacity(max(0, opacity))))
    }

    private func bolt(from a: CGPoint, to b: CGPoint, t: Double, color: Color, ctx: inout GraphicsContext) {
        var d = Path()
        d.move(to: a)
        let segments = 7
        let end = Int(Double(segments) * min(1, t))
        guard end > 0 else { return }
        for k in 1...end {
            let f = Double(k) / Double(segments)
            let jitter = k == segments ? 0 : (rand(k, Int(t * 20)) - 0.5) * 22
            d.addLine(to: CGPoint(x: a.x + (b.x - a.x) * f + jitter, y: a.y + (b.y - a.y) * f + jitter * 0.5))
        }
        ctx.stroke(d, with: .color(.white), lineWidth: 5)
        ctx.stroke(d, with: .color(color), lineWidth: 2.5)
    }
}

/// Look of a move's particles by type.
private struct TypeStyle {
    enum Shape { case orb, drop, leaf, shard, rock, star, ring, bolt }
    let colors: [Color]
    let shape: Shape
    var size: Double = 9
    var arc: Double = 20
    var wobble: Double = 4
    var rises = false
    var falls = false

    init(_ type: String) {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch type {
        case "fire": self.init(colors: [rgb(1, 0.45, 0.1), rgb(1, 0.8, 0.2), rgb(0.95, 0.2, 0.1)], shape: .orb, size: 12, rises: true)
        case "water": self.init(colors: [rgb(0.25, 0.55, 1), rgb(0.55, 0.8, 1)], shape: .drop, size: 11, arc: 26)
        case "electric": self.init(colors: [rgb(1, 0.9, 0.2), rgb(1, 1, 0.7)], shape: .bolt, size: 7, arc: 0, wobble: 8)
        case "grass": self.init(colors: [rgb(0.3, 0.75, 0.3), rgb(0.55, 0.9, 0.35)], shape: .leaf, size: 8, arc: 30, wobble: 10)
        case "ice": self.init(colors: [rgb(0.6, 0.9, 1), rgb(0.85, 0.97, 1)], shape: .shard, size: 10, arc: 10)
        case "psychic": self.init(colors: [rgb(1, 0.4, 0.75), rgb(0.85, 0.5, 1)], shape: .ring, size: 8, arc: 0, wobble: 6)
        case "ghost": self.init(colors: [rgb(0.45, 0.3, 0.7), rgb(0.25, 0.15, 0.4)], shape: .orb, size: 13, arc: 16, wobble: 10)
        case "dark": self.init(colors: [rgb(0.25, 0.2, 0.3), rgb(0.5, 0.35, 0.55)], shape: .orb, size: 12)
        case "poison": self.init(colors: [rgb(0.65, 0.3, 0.8), rgb(0.8, 0.5, 0.95)], shape: .orb, size: 10, arc: 24, rises: true)
        case "rock", "ground": self.init(colors: [rgb(0.6, 0.45, 0.25), rgb(0.75, 0.6, 0.4)], shape: .rock, size: 10, arc: 34, falls: true)
        case "steel": self.init(colors: [rgb(0.7, 0.72, 0.78), rgb(0.9, 0.92, 0.96)], shape: .shard, size: 9)
        case "dragon": self.init(colors: [rgb(0.45, 0.35, 0.95), rgb(0.95, 0.4, 0.3)], shape: .orb, size: 13, arc: 18, wobble: 8)
        case "fairy": self.init(colors: [rgb(1, 0.6, 0.85), rgb(1, 0.85, 0.95)], shape: .star, size: 11)
        case "flying": self.init(colors: [rgb(0.85, 0.92, 1), .white], shape: .leaf, size: 9, arc: 12, wobble: 14)
        case "bug": self.init(colors: [rgb(0.6, 0.75, 0.2), rgb(0.8, 0.9, 0.3)], shape: .orb, size: 8, wobble: 12)
        case "fighting": self.init(colors: [rgb(0.85, 0.3, 0.2), rgb(1, 0.85, 0.5)], shape: .star, size: 13)
        default: self.init(colors: [.white, rgb(1, 0.95, 0.75)], shape: .star, size: 12)
        }
    }

    init(colors: [Color], shape: Shape, size: Double = 9, arc: Double = 20, wobble: Double = 4,
         rises: Bool = false, falls: Bool = false) {
        self.colors = colors
        self.shape = shape
        self.size = size
        self.arc = arc
        self.wobble = wobble
        self.rises = rises
        self.falls = falls
    }
}

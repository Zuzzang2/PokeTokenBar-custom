import AppKit

// SPIKE: drawing for the 메아리 screen. The world renders into a 480x270 bitmap scaled up by a whole
// number with nearest-neighbour and letterboxed; text and HUD draw on top at full resolution.

extension EchoGameView {
    private var pixelScale: CGFloat {
        max(1, min((bounds.width / CGFloat(EchoArt.width)).rounded(.down), (bounds.height / CGFloat(EchoArt.height)).rounded(.down)))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(KartArt.rgb(8, 14, 12))
        ctx.fill(bounds)
        if frameContext == nil { frameContext = KartArt.context(width: EchoArt.width, height: EchoArt.height) }
        guard let f = frameContext else { return }

        let scale = pixelScale
        let size = CGSize(width: CGFloat(EchoArt.width) * scale, height: CGFloat(EchoArt.height) * scale)
        let origin = CGPoint(x: ((bounds.width - size.width) / 2).rounded(), y: ((bounds.height - size.height) / 2).rounded())
        lastScale = scale
        lastOrigin = origin

        if mode == .ending {
            drawEndingWorld(f)
        } else {
            drawWorld(f)
        }
        if let image = f.makeImage() {
            ctx.interpolationQuality = .none
            KartArt.draw(image, in: ctx, rect: CGRect(origin: origin, size: size))
        }
        if mode == .rewind { drawRewindOverlay(ctx, CGRect(origin: origin, size: size)) }
        if mode == .ending { drawEndingText() } else { drawHUD(ctx, CGRect(origin: origin, size: size)) }
    }

    // MARK: world

    private var viewFrame: Int {
        switch mode {
        case .rewind: Int(rewindFrame)
        case .clear: Int(montageFrame)
        default: world.frame
        }
    }

    private func drawWorld(_ f: CGContext) {
        if let bg = EchoArt.background(night: false) {
            KartArt.draw(bg, in: f, rect: CGRect(x: 0, y: 0, width: EchoArt.width, height: EchoArt.height))
        } else {
            KartArt.fill(f, KartArt.rgb(130, 196, 236), 0, 0, CGFloat(EchoArt.width), CGFloat(EchoArt.height))
        }
        if let terrainImage {
            KartArt.draw(terrainImage, in: f, rect: CGRect(x: 0, y: 0, width: EchoArt.width, height: EchoArt.height))
        }

        let fr = viewFrame
        let ghosts = EchoCore.ghosts(echoes.map(\.rec), at: fr)
        let me = mode == .rewind ? rewindSource[min(fr, rewindSource.count - 1)] : EchoCore.snapshot(world.player)
        let pressed = mode == .play || mode == .spectate
            ? world.pressed
            : EchoCore.platesPressed(level, bodies: ghosts + [me])
        let open = EchoCore.doorsOpen(level, pressed: pressed)
        for (i, p) in level.plates.enumerated() { EchoArt.plate(f, p.rect, lit: pressed.contains(i)) }
        for d in level.doors { EchoArt.door(f, tx: d.tx, ty: d.ty, open: open[d.group] == true, clock: clock) }
        EchoArt.exit(f, level.exit, clock: clock)

        for (i, owned) in echoes.enumerated() {
            guard let g = ghosts[i] else { continue }
            drawPokemon(f, owner: owned.owner, at: g, tint: EchoArt.echoTints[i % EchoArt.echoTints.count], alpha: 0.62)
        }
        if mode == .play || mode == .spectate {
            for (id, p) in peers where p.loop == loop && !exitedIDs.contains(id) && !deadIDs.contains(id) {
                drawPokemon(f, owner: id, at: p.frame, tint: nil, alpha: 1)
            }
        }
        let meVisible = !(mode == .spectate && (exitedIDs.contains(meID) || deadIDs.contains(meID))) && mode != .clear
        if meVisible { drawPokemon(f, owner: meID, at: me, tint: nil, alpha: 1, marker: true) }

        for p in particles {
            f.setAlpha(CGFloat(max(0, p.life / p.maxLife)))
            KartArt.fill(f, p.color, CGFloat(p.x / EchoArt.scale).rounded(), CGFloat(p.y / EchoArt.scale).rounded(), 2, 2)
        }
        f.setAlpha(1)
        if mode == .clear {
            // Every echo plus everyone's final walk, all at once.
            f.setFillColor(KartArt.rgb(255, 255, 230, 0.10))
            f.fill(CGRect(x: 0, y: 0, width: EchoArt.width, height: EchoArt.height))
        }
    }

    /// A Pokémon standing with its feet on the hitbox bottom. Echoes use a tinted copy of their owner's sprite.
    private func drawPokemon(_ f: CGContext, owner: String, at fr: EchoFrame, tint: CGColor?, alpha: CGFloat, marker: Bool = false) {
        let cx = CGFloat((fr.x + EchoCore.P.w / 2) / EchoArt.scale)
        let feet = CGFloat((fr.y + EchoCore.P.h) / EchoArt.scale)
        f.setAlpha(alpha)
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.25))
        f.fillEllipse(in: CGRect(x: cx - 6, y: feet - 2, width: 12, height: 4))
        var top = feet - 13
        if let img = sprite(for: owner, tint: tint) {
            let w = CGFloat(img.width), h = CGFloat(img.height)
            let rect = CGRect(x: (cx - w / 2).rounded(), y: feet - h + 1, width: w, height: h)
            KartArt.draw(img, in: f, rect: rect, flipX: fr.facing > 0)
            top = rect.minY
        } else {
            KartArt.fill(f, tint ?? KartArt.rgb(255, 220, 80), cx - 4, feet - 13, 9, 13)
        }
        f.setAlpha(1)
        if marker {
            let y = top - 5
            KartArt.fill(f, KartArt.rgb(30, 30, 30), cx - 3, y - 1, 7, 2)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), cx - 2, y - 1, 5, 1)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), cx - 1, y, 3, 1)
            KartArt.fill(f, KartArt.rgb(255, 220, 50), cx, y + 1, 1, 1)
        }
    }

    private func sprite(for owner: String, tint: CGColor?) -> CGImage? {
        guard let base = sprites[owner] else { return nil }
        guard let tint else { return base }
        let key = "\(owner)#\(tint.components?.description ?? "")"
        if let hit = tintedSprites[key] { return hit }
        let img = EchoArt.tinted(base, tint, amount: 0.55)
        tintedSprites[key] = img
        return img
    }

    // MARK: overlays

    private func drawRewindOverlay(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setFillColor(KartArt.rgb(90, 40, 160, 0.30))
        ctx.fill(rect)
        for k in 0..<7 {
            let y = rect.minY + CGFloat((clock * 700 + Double(k) * 83).truncatingRemainder(dividingBy: Double(rect.height)))
            ctx.setFillColor(KartArt.rgb(255, 255, 255, 0.10))
            ctx.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: CGFloat(2 + k % 3)))
        }
        let cx = rect.midX, cy = rect.minY + 60
        ctx.setFillColor(KartArt.rgb(255, 255, 255, 0.9))
        for dx in [CGFloat(-26), 2] {
            ctx.move(to: CGPoint(x: cx + dx + 24, y: cy - 14))
            ctx.addLine(to: CGPoint(x: cx + dx, y: cy))
            ctx.addLine(to: CGPoint(x: cx + dx + 24, y: cy + 14))
            ctx.closePath()
        }
        ctx.fillPath()
    }

    // MARK: HUD

    func text(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor = .white, weight: NSFont.Weight = .heavy,
              align: NSTextAlignment = .left) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 0
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                    .foregroundColor: color, .shadow: shadow]
        let str = NSAttributedString(string: s, attributes: attrs)
        let w = str.size().width
        let x = align == .center ? p.x - w / 2 : (align == .right ? p.x - w : p.x)
        str.draw(at: NSPoint(x: x, y: p.y))
    }

    private func panel(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil))
        ctx.fillPath()
    }

    /// A small Pokéball: filled when the slot holds an echo.
    private func ball(_ ctx: CGContext, center c: CGPoint, filled: Bool) {
        let r: CGFloat = 8
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        ctx.setFillColor(filled ? KartArt.rgb(232, 64, 64) : KartArt.rgb(255, 255, 255, 0.18))
        ctx.saveGState()
        ctx.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: r))
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()
        ctx.setFillColor(filled ? KartArt.rgb(245, 245, 245) : KartArt.rgb(255, 255, 255, 0.10))
        ctx.saveGState()
        ctx.clip(to: CGRect(x: rect.minX, y: c.y, width: rect.width, height: r))
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()
        ctx.setStrokeColor(KartArt.rgb(20, 20, 24, filled ? 1 : 0.5))
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: rect)
        ctx.move(to: CGPoint(x: rect.minX, y: c.y))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: c.y))
        ctx.strokePath()
        ctx.setFillColor(KartArt.rgb(245, 245, 245))
        ctx.fillEllipse(in: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5))
    }

    private func drawHUD(_ ctx: CGContext, _ area: CGRect) {
        // Loop timer along the top edge of the play area.
        let progress = min(1, CGFloat(viewFrame) / CGFloat(max(1, level.limit)))
        ctx.setFillColor(KartArt.rgb(0, 0, 0, 0.45))
        ctx.fill(CGRect(x: area.minX, y: area.minY, width: area.width, height: 5))
        ctx.setFillColor(mode == .rewind ? KartArt.rgb(190, 140, 255) : KartArt.rgb(255, 220, 80))
        ctx.fill(CGRect(x: area.minX, y: area.minY, width: area.width * progress, height: 5))

        panel(ctx, CGRect(x: area.minX + 12, y: area.minY + 14, width: 170, height: 34))
        text(level.title, at: CGPoint(x: area.minX + 24, y: area.minY + 21), size: 15)

        if maxEchoes > 0 {
            let w = CGFloat(maxEchoes) * 22 + 70
            panel(ctx, CGRect(x: area.maxX - 12 - w, y: area.minY + 14, width: w, height: 34))
            text("메아리", at: CGPoint(x: area.maxX - w + 2, y: area.minY + 23), size: 12, weight: .bold)
            for i in 0..<maxEchoes {
                ball(ctx, center: CGPoint(x: area.maxX - w + 58 + CGFloat(i) * 22, y: area.minY + 31),
                     filled: i < echoCount(of: meID))
            }
        }

        if roster.count > 1 {
            var y = area.minY + 58
            for e in roster {
                let state = exitedIDs.contains(e.id) ? "도착" : (deadIDs.contains(e.id) ? "쓰러짐" : "진행 중")
                let color: NSColor = exitedIDs.contains(e.id) ? .systemGreen : (deadIDs.contains(e.id) ? .systemRed : .white)
                panel(ctx, CGRect(x: area.minX + 12, y: y, width: 170, height: 22))
                text("\(e.trainer) · \(state)", at: CGPoint(x: area.minX + 20, y: y + 4), size: 11, color: color, weight: .bold)
                y += 26
            }
            for (id, p) in peers where p.loop == loop && !exitedIDs.contains(id) && !deadIDs.contains(id) && mode == .play {
                let x = area.minX + CGFloat((p.frame.x + EchoCore.P.w / 2) / EchoArt.scale) * lastScale
                let ty = area.minY + CGFloat(p.frame.y / EchoArt.scale - 16) * lastScale
                text(entry(id)?.trainer ?? "", at: CGPoint(x: x, y: ty - 14), size: 11, color: .systemYellow, weight: .bold, align: .center)
            }
        }

        // Hint sits over the ceiling row so it never covers the floor the puzzles happen on.
        let controls = maxEchoes > 0 ? "←→ 이동   스페이스 점프   R 되감기   ⌫ 메아리 지우기   Esc 나가기" : "←→ 이동   스페이스 점프   Esc 나가기"
        panel(ctx, CGRect(x: area.midX - 230, y: area.minY + 14, width: 460, height: 42))
        text(level.hint, at: CGPoint(x: area.midX, y: area.minY + 17), size: 13, weight: .bold, align: .center)
        text(controls, at: CGPoint(x: area.midX, y: area.minY + 36), size: 10, color: NSColor.white.withAlphaComponent(0.75),
             weight: .medium, align: .center)

        if let banner, clock < banner.until {
            let big = mode == .clear
            text(banner.text, at: CGPoint(x: area.midX, y: area.midY - (big ? 60 : 30)), size: big ? 44 : 22, align: .center)
            if big {
                let n = echoes.count
                text(n == 0 ? "혼자서." : "메아리 \(n)개와 함께.", at: CGPoint(x: area.midX, y: area.midY - 6), size: 16,
                     weight: .bold, align: .center)
            }
        }
        if mode == .waiting {
            text("방장을 기다리는 중…", at: CGPoint(x: area.midX, y: area.midY), size: 18, align: .center)
        }
    }

    // MARK: ending

    private func drawEndingWorld(_ f: CGContext) {
        if let bg = EchoArt.background(night: true) {
            KartArt.draw(bg, in: f, rect: CGRect(x: 0, y: 0, width: EchoArt.width, height: EchoArt.height))
        } else {
            KartArt.fill(f, KartArt.rgb(14, 20, 48), 0, 0, CGFloat(EchoArt.width), CGFloat(EchoArt.height))
        }
        // One star per echo used, appearing one by one.
        let shown = min(stats.echoes, max(0, Int((clock - 3) / 0.25)))
        for i in 0..<shown {
            let x = 40 + CGFloat((i * 97) % 400)
            let y = 150 + CGFloat((i * 53) % 70)
            let tw = 0.6 + 0.4 * sin(clock * 2 + Double(i))
            let c = EchoArt.echoTints[i % EchoArt.echoTints.count]
            f.setFillColor(c.copy(alpha: 0.25 * tw) ?? c)
            f.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 9, height: 9))
            f.setFillColor(c.copy(alpha: tw) ?? c)
            f.fill(CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        }
        let feet = CGFloat(EchoArt.height) - 30
        for (i, e) in roster.enumerated() {
            let x = Double(EchoArt.width) / 2 - Double(roster.count - 1) * 14 + Double(i) * 28
            let fr = EchoFrame(x: x * EchoArt.scale - EchoCore.P.w / 2, y: Double(feet) * EchoArt.scale - EchoCore.P.h, facing: 1)
            drawPokemon(f, owner: e.id, at: fr, tint: nil, alpha: 1)
        }
    }

    private func drawEndingText() {
        let lines = [
            (1.0, "\(stats.loops)번 시간을 되감았다."),
            (3.5, "\(stats.echoes)개의 메아리가 발판을 지키고, 구덩이에 남고, 누군가의 계단이 되었다."),
            (7.0, "그들 중 누구도 신전에 닿지 못했다."),
            (9.5, "그리고 그들 모두가 여기까지 데려왔다."),
        ]
        let top = lastOrigin.y + 60
        for (i, (at, s)) in lines.enumerated() where clock >= at {
            let a = min(1, (clock - at) / 1.2)
            text(s, at: CGPoint(x: bounds.midX, y: top + CGFloat(i) * 34), size: 18,
                 color: NSColor.white.withAlphaComponent(a), weight: .bold, align: .center)
        }
        if clock >= 12 {
            text("메아리", at: CGPoint(x: bounds.midX, y: top + 170), size: 40, align: .center)
            text("지나간 시도는 실패가 아니다. 발판이다.     Esc 나가기", at: CGPoint(x: bounds.midX, y: top + 222), size: 13,
                 color: NSColor.white.withAlphaComponent(0.75), weight: .medium, align: .center)
        }
    }
}

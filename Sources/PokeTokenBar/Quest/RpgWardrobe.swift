import AppKit
import CoreGraphics

// SPIKE: 옷장과 의상실. Tab 0 옷장 (what you own; wear and take off), tab 1 상점 (gold, at the 의상실 only), tab 2 뽑기 (gacha).

extension RpgView {
    static let wardrobeTabs = ["옷장", "상점", "뽑기"]
    static let wardrobeColumns = 6

    func atWardrobe(_ p: RpgPlayer) -> Bool { world.nearbyPlace(for: p.id) == .wardrobe }

    /// What the grid of the current tab shows.
    func wardrobeList(_ p: RpgPlayer) -> [RpgCosmetic] {
        let order = RpgCosmeticSlot.allCases
        switch tab {
        case 0:
            return p.wardrobe.compactMap(RpgCosmetics.def).sorted {
                ($0.slot.rawValue == $1.slot.rawValue) ? ($0.rarity, $0.id) > ($1.rarity, $1.id) : order.firstIndex(of: $0.slot)! < order.firstIndex(of: $1.slot)!
            }
        case 1: return RpgCosmetics.shop
        default: return []
        }
    }

    /// A small icon for a cosmetic: the piece on your own hero, cropped to it, on a dark tile edged in its set's colours. A prism
    /// piece shimmers on a tile of slowly turning dark rainbow, with stars twinkling over it.
    func drawCosmeticIcon(_ ctx: CGContext, _ c: RpgCosmetic, in r: CGRect, owned: Bool = true, worn: Bool = false) {
        let theme = RpgCosmetics.theme(c.theme)
        let main = theme.map { NSColor(red: CGFloat($0.main.r) / 255, green: CGFloat($0.main.g) / 255, blue: CGFloat($0.main.b) / 255, alpha: 1) } ?? NSColor(white: 0.45, alpha: 1)
        let trim = theme.map { NSColor(red: CGFloat($0.trim.r) / 255, green: CGFloat($0.trim.g) / 255, blue: CGFloat($0.trim.b) / 255, alpha: 1) } ?? .white
        let tile = r.insetBy(dx: 4, dy: 4)
        let prism = c.theme == "prism"
        if prism {
            drawPrismTile(ctx, tile)
        } else {
            ctx.setFillColor((main.blended(withFraction: 0.72, of: NSColor(white: 0.08, alpha: 1)) ?? main).cgColor)
            ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.fillPath()
            ctx.setFillColor(main.cgColor)
            ctx.fill(CGRect(x: tile.minX + 4, y: tile.maxY - 4, width: tile.width - 8, height: 2))
            ctx.setFillColor(trim.cgColor)
            ctx.fill(CGRect(x: tile.minX + 4, y: tile.maxY - 2, width: tile.width - 8, height: 1))
        }
        if let me = world.player(localID), let img = RpgArt.cosmeticIcon(c, on: me, time: world.time) {
            // Whole or half-point steps keep the pixels square on a Retina screen.
            let box = tile.insetBy(dx: 2, dy: 3)
            let s = max(0.5, (min(box.width / CGFloat(img.width), box.height / CGFloat(img.height)) * 2).rounded(.down) / 2)
            let w = CGFloat(img.width) * s, h = CGFloat(img.height) * s
            ctx.interpolationQuality = .none
            KartArt.draw(img, in: ctx, rect: CGRect(x: (box.midX - w / 2).rounded(), y: (box.midY - h / 2).rounded(), width: w, height: h))
        } else {
            text(c.slot.title, at: CGPoint(x: r.midX, y: r.midY - 6), size: 11, color: .white, weight: .heavy, align: .center)
        }
        if prism { drawPrismTwinkles(ctx, tile, count: 3, seed: Double(c.slot.rawValue.count)) }
        if !owned { ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor); ctx.fill(tile) }
        if worn { text("착용", at: CGPoint(x: r.maxX - 6, y: r.minY + 6), size: 9, color: Self.gold, weight: .heavy, align: .right) }
    }

    private static let prismNight = CGColor(srgbRed: 0.06, green: 0.05, blue: 0.09, alpha: 1)
    private static let prismWhite = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

    /// A prism tile: near-black under bands of dark rainbow that drift round the wheel, and a rainbow stripe along the bottom.
    private func drawPrismTile(_ ctx: CGContext, _ tile: CGRect) {
        let t = world.time
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.clip()
        ctx.setFillColor(Self.prismNight)
        ctx.fill(tile)
        let bands = 6, h = tile.height / CGFloat(bands)
        ctx.saveGState()
        ctx.setAlpha(0.42)
        for k in 0..<bands {
            ctx.setFillColor(RpgArt.prismInk(Double(k) / Double(bands) * 0.7 - t * 0.35, .deep))
            ctx.fill(CGRect(x: tile.minX, y: tile.minY + CGFloat(k) * h, width: tile.width, height: h + 0.5))
        }
        ctx.restoreGState()
        let w = (tile.width - 8) / 6
        for k in 0..<6 {
            ctx.setFillColor(RpgArt.prismInk(Double(k) / 6 - t * 0.6, .vivid))
            ctx.fill(CGRect(x: tile.minX + 4 + CGFloat(k) * w, y: tile.maxY - 4, width: w + 0.5, height: 2))
        }
        ctx.setFillColor(Self.prismWhite)
        ctx.fill(CGRect(x: tile.minX + 4, y: tile.maxY - 2, width: tile.width - 8, height: 1))
        ctx.restoreGState()
    }

    /// Four-point stars that swell and fade in turn round a rect, each its own colour of the rainbow.
    private func drawPrismTwinkles(_ ctx: CGContext, _ r: CGRect, count: Int, seed: Double, size: CGFloat = 1.5) {
        let t = world.time
        for k in 0..<count {
            let life = (t * 0.9 + Double(k) / Double(count) + seed * 0.13).truncatingRemainder(dividingBy: 1)
            let s = size * CGFloat(sin(life * .pi))
            guard s > 0.3 else { continue }
            // Spots spread round the rect by the golden angle, moving on each time a star has faded.
            let spot = Double(k) * 2.399 + seed + Double(Int(t * 0.9 + Double(k) / Double(count) + seed * 0.13)) * 1.7
            let x = r.midX + CGFloat(cos(spot)) * r.width * 0.36, y = r.midY + CGFloat(sin(spot * 1.3)) * r.height * 0.36
            ctx.setFillColor(RpgArt.prismInk(Double(k) / Double(count) + t * 0.2, .pale))
            ctx.fill(CGRect(x: x - s * 2, y: y - s / 2, width: s * 4, height: s))
            ctx.fill(CGRect(x: x - s / 2, y: y - s * 2, width: s, height: s * 4))
            ctx.setFillColor(Self.prismWhite)
            ctx.fill(CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
        }
    }

    func drawWardrobe(_ ctx: CGContext, _ p: RpgPlayer) {
        let near = atWardrobe(p)
        let hint = tab == 2 ? "1 · Enter 1회 뽑기   0  10회 뽑기   Tab 탭 전환   \(bindings.label(.wardrobe))/Esc 닫기"
            : (tab == 1 ? "방향키 이동   Enter 구매   Tab 탭 전환   \(bindings.label(.wardrobe))/Esc 닫기" : "방향키 이동   Enter 착용·해제   Delete 해제   Tab 탭 전환   \(bindings.label(.wardrobe))/Esc 닫기")
        let area = frame(ctx, title: "옷장", hint: hint, tabs: Self.wardrobeTabs)
        text("\(p.gold) G", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 15, color: Self.gold, align: .right, mono: true)
        let cols = Self.wardrobeColumns, cell: CGFloat = 52, gap: CGFloat = 6
        let gridW = CGFloat(cols) * (cell + gap) - gap
        let card = CGRect(x: area.minX + gridW + 14, y: area.minY, width: area.width - gridW - 14, height: area.height)
        box(ctx, card, alpha: 0.5)
        // Preview: the hero as the selected piece would make them look.
        var look = p
        let list = wardrobeList(p)
        selection = min(selection, max(0, list.count - 1))
        let sel = list.indices.contains(selection) ? list[selection] : nil
        if let sel { look.worn[sel.slot.rawValue] = sel.id }
        if let img = RpgArt.heroPreview(look, pose: RpgArt.heroShowcasePose(look, time: world.time, still: false), time: world.time) {
            ctx.interpolationQuality = .none
            let h: CGFloat = 150, w = h * CGFloat(img.width) / CGFloat(img.height)
            KartArt.draw(img, in: ctx, rect: CGRect(x: card.midX - w / 2, y: card.minY + 8, width: w, height: h))
        }
        if tab == 2 {
            text("뽑기  1회 \(RpgCosmetics.gachaCost)G · 10회 \(RpgCosmetics.gachaTenCost)G", at: CGPoint(x: area.minX + 8, y: area.minY + 12), size: 14, weight: .bold)
            let odds = zip(RpgCosmetics.rarityName, RpgCosmetics.gachaOdds).filter { $0.1 > 0 }.map { "\($0) \($1)%" }.joined(separator: "  ·  ")
            text(odds, at: CGPoint(x: area.minX + 8, y: area.minY + 40), size: 12, color: Self.dim, weight: .semibold)
            text("\(RpgCosmetics.pity)번 안에 영웅 이상이 안 나오면 다음 뽑기는 영웅 이상 보장", at: CGPoint(x: area.minX + 8, y: area.minY + 62), size: 12, color: Self.dim, weight: .semibold)
            text("지금까지 \(p.gachaPity)회 연속 · 중복은 환급되지 않아요", at: CGPoint(x: area.minX + 8, y: area.minY + 84), size: 12, color: Self.gold, weight: .semibold)
            if !near { text("의상실 앞에서만 뽑을 수 있어요", at: CGPoint(x: area.minX + 8, y: area.minY + 120), size: 13, color: NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1), weight: .bold) }
            return
        }
        let rowsVisible = max(1, Int((area.height + gap) / (cell + gap)))
        let firstRow = max(0, min(selection / cols - rowsVisible / 2, max(0, (list.count - 1) / cols - rowsVisible + 1)))
        for k in 0..<(rowsVisible * cols) {
            let idx = firstRow * cols + k
            let r = CGRect(x: area.minX + CGFloat(k % cols) * (cell + gap), y: area.minY + CGFloat(k / cols) * (cell + gap), width: cell, height: cell)
            ctx.setFillColor(NSColor(white: 0.1, alpha: 0.85).cgColor)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.fillPath()
            guard idx < list.count else { continue }
            let c = list[idx]
            drawCosmeticIcon(ctx, c, in: r, owned: tab == 0 || !p.wardrobe.contains(c.id), worn: p.worn[c.slot.rawValue] == c.id)
            ctx.setStrokeColor((idx == selection ? Self.gold : rarityColor(c.rarity).withAlphaComponent(0.7)).cgColor)
            ctx.setLineWidth(idx == selection ? 3 : 1.5)
            ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.strokePath()
        }
        if list.isEmpty { text(tab == 0 ? "가진 외관이 없어요 (상점·뽑기·드랍으로 얻어요)" : "", at: CGPoint(x: area.minX + 8, y: area.minY + 20), size: 12, color: Self.dim) }
        if let sel {
            text(sel.name, at: CGPoint(x: card.midX, y: card.minY + 168), size: 15, color: rarityColor(sel.rarity), weight: .bold, align: .center)
            text("\(RpgCosmetics.rarityName[min(sel.rarity, 5)]) · \(sel.slot.title)", at: CGPoint(x: card.midX, y: card.minY + 190), size: 11, color: Self.dim, weight: .semibold, align: .center)
            if tab == 1 {
                let owned = p.wardrobe.contains(sel.id)
                text(owned ? "보유 중" : "\(sel.price) G", at: CGPoint(x: card.midX, y: card.minY + 214), size: 14, color: owned ? Self.dim : (p.gold >= sel.price ? Self.gold : NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)), weight: .bold, align: .center)
                if !near { text("의상실 앞에서만 살 수 있어요", at: CGPoint(x: card.midX, y: card.minY + 238), size: 11, color: NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1), weight: .bold, align: .center) }
            }
        }
    }

    /// Keys of the wardrobe window; true when used.
    func handleWardrobeKey(_ code: UInt16, repeatKey: Bool, _ p: RpgPlayer) -> Bool {
        let count = RpgView.wardrobeTabs.count
        switch code {
        case 48, 30:
            if !repeatKey { tab = (tab + 1) % count; selection = 0 }
            return true
        case 33:
            if !repeatKey { tab = (tab + count - 1) % count; selection = 0 }
            return true
        default: break
        }
        if tab == 2 {
            guard !repeatKey else { return true }
            switch code {
            case 18, 36: act(.gacha(1))
            case 29: act(.gacha(10))
            default: return false
            }
            return true
        }
        let list = wardrobeList(p)
        let cols = Self.wardrobeColumns
        switch code {
        case 123: selection = max(0, selection - 1)
        case 124: selection = min(max(0, list.count - 1), selection + 1)
        case 126: selection = selection >= cols ? selection - cols : selection
        case 125: selection = selection + cols < list.count ? selection + cols : selection
        case 36:
            guard !repeatKey, list.indices.contains(selection) else { return true }
            let c = list[selection]
            if tab == 1 { act(.buyCosmetic(c.id)) }
            else if p.worn[c.slot.rawValue] == c.id { act(.unwear(c.slot.rawValue)) } else { act(.wear(c.id)) }
        case 51:
            guard !repeatKey, tab == 0, list.indices.contains(selection) else { return true }
            act(.unwear(list[selection].slot.rawValue))
        default: return false
        }
        return true
    }
}

// MARK: gacha result

extension RpgView {
    /// Opens the result window when the host reports a new pull.
    func checkPullResult() {
        guard let me else { return }
        guard let seen = shownPullSeq else { shownPullSeq = me.pullSeq; return }
        if me.pullSeq != seen {
            shownPullSeq = me.pullSeq
            if !me.pulls.isEmpty { open(.pullResult) }
        }
    }

    /// 초월 cycles round the wheel in 24 steps: labels are cached per colour (`text`), and a smooth hue made every frame's
    /// banner and names a new label, laid out again and pushing the rest out of the cache.
    private static let ultraColors: [NSColor] = (0..<24).map { NSColor(hue: CGFloat($0) / 24, saturation: 0.55, brightness: 1, alpha: 1) }

    static func ultraColor(_ time: Double) -> NSColor { ultraColors[(Int((time * 0.6 * 24).rounded(.down)) % 24 + 24) % 24] }

    func rarityColor(_ rarity: Int) -> NSColor {
        if rarity >= 5 { return Self.ultraColor(world.time) }
        return RpgArt.rarityColors[min(rarity, 4)]
    }

    func drawPullResult(_ ctx: CGContext, _ p: RpgPlayer) {
        let pulls = p.pulls
        let best = pulls.compactMap { RpgCosmetics.def($0.id)?.rarity }.max() ?? 0
        let area = frame(ctx, title: pulls.count > 1 ? "뽑기 결과 (\(pulls.count)회)" : "뽑기 결과", hint: "Enter / Esc 확인")
        let t = world.time
        if best >= 5 {
            // A shimmering banner for the ultra-rare, stars twinkling round it.
            text("✨  초 월  ✨", at: CGPoint(x: area.midX, y: area.minY - 34), size: 22, color: rarityColor(5), weight: .heavy, align: .center)
            drawPrismTwinkles(ctx, CGRect(x: area.midX - 90, y: area.minY - 44, width: 180, height: 36), count: 5, seed: 0.5, size: 2)
        }
        let cols = pulls.count > 5 ? 5 : max(1, pulls.count)
        let cell: CGFloat = 104, gap: CGFloat = 14
        let rows = (pulls.count + cols - 1) / cols
        let totalW = CGFloat(cols) * cell + CGFloat(cols - 1) * gap
        let x0 = area.midX - totalW / 2
        let y0 = area.minY + (area.height - (CGFloat(rows) * (cell + 52) + CGFloat(rows - 1) * gap)) / 2
        func cardRect(_ k: Int) -> CGRect {
            CGRect(x: x0 + CGFloat(k % cols) * (cell + gap), y: y0 + CGFloat(k / cols) * (cell + 52 + gap), width: cell, height: cell)
        }
        // Rays behind every 초월 card first, so no card is drawn under another's light.
        for (k, pull) in pulls.enumerated() where (RpgCosmetics.def(pull.id)?.rarity ?? 0) >= 5 { drawPrismRays(ctx, around: cardRect(k), seed: Double(k)) }
        for (k, pull) in pulls.enumerated() {
            guard let c = RpgCosmetics.def(pull.id) else { continue }
            let r = cardRect(k)
            ctx.setFillColor(NSColor(white: 0.1, alpha: 0.9).cgColor)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 8, cornerHeight: 8, transform: nil))
            ctx.fillPath()
            drawCosmeticIcon(ctx, c, in: r.insetBy(dx: 6, dy: 6), owned: true, worn: false)
            let col = rarityColor(c.rarity)
            if c.rarity >= 5 {
                // A glow of the next colour round the cycling edge.
                ctx.saveGState()
                ctx.setStrokeColor(RpgArt.prismInk(t * 0.6 + 0.33, .soft))
                ctx.setAlpha(0.45)
                ctx.setLineWidth(7)
                ctx.addPath(CGPath(roundedRect: r.insetBy(dx: -2, dy: -2), cornerWidth: 10, cornerHeight: 10, transform: nil))
                ctx.strokePath()
                ctx.restoreGState()
            }
            ctx.setStrokeColor(col.cgColor)
            ctx.setLineWidth(c.rarity >= 3 ? 4 : 2)
            ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerWidth: 8, cornerHeight: 8, transform: nil))
            ctx.strokePath()
            if c.rarity >= 5 { drawPrismTwinkles(ctx, r.insetBy(dx: -14, dy: -14), count: 8, seed: Double(k) * 0.7, size: 2.5) }
            if c.rarity >= 3 {
                // Sparkles that blink around the legendary and above.
                for s in 0..<6 {
                    let a = t * 2 + Double(s) * 1.05 + Double(k)
                    let sx = r.midX + CGFloat(cos(a)) * (cell * 0.62), sy = r.midY + CGFloat(sin(a)) * (cell * 0.62)
                    ctx.setFillColor(col.withAlphaComponent(CGFloat(0.4 + 0.6 * abs(sin(a * 1.7)))).cgColor)
                    ctx.fill(CGRect(x: sx - 2, y: sy - 2, width: 4, height: 4))
                }
            }
            text(c.name, at: CGPoint(x: r.midX, y: r.maxY + 6), size: 11, color: col, weight: .bold, align: .center)
            text("\(RpgCosmetics.rarityName[min(c.rarity, 5)]) · \(c.slot.title)", at: CGPoint(x: r.midX, y: r.maxY + 22), size: 10, color: Self.dim, weight: .semibold, align: .center)
            text(pull.isNew ? "NEW!" : "중복", at: CGPoint(x: r.midX, y: r.maxY + 36), size: 11, color: pull.isNew ? Self.gold : NSColor(white: 0.55, alpha: 1), weight: .heavy, align: .center)
        }
        let news = pulls.filter(\.isNew).count
        text("새 외관 \(news)개 · 중복 \(pulls.count - news)개 (중복은 환급되지 않아요)", at: CGPoint(x: area.midX, y: area.maxY - 4), size: 12, color: Self.dim, weight: .semibold, align: .center)
    }

    /// Rays of rainbow light turning slowly behind a 초월 card.
    private func drawPrismRays(_ ctx: CGContext, around r: CGRect, seed: Double) {
        let t = world.time, n = 14
        let reach = Double(max(r.width, r.height)) * 0.95
        ctx.saveGState()
        ctx.setAlpha(0.3)
        for i in 0..<n {
            let a = t * 0.45 + seed + Double(i) * 2 * .pi / Double(n), w = i % 2 == 0 ? 0.13 : 0.07
            let len = reach * (i % 2 == 0 ? 1 : 0.78)
            ctx.setFillColor(RpgArt.prismInk(Double(i) / Double(n) - t * 0.3, .soft))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: r.midX, y: r.midY))
            ctx.addLine(to: CGPoint(x: Double(r.midX) + cos(a - w) * len, y: Double(r.midY) + sin(a - w) * len))
            ctx.addLine(to: CGPoint(x: Double(r.midX) + cos(a + w) * len, y: Double(r.midY) + sin(a + w) * len))
            ctx.closePath()
            ctx.fillPath()
        }
        ctx.restoreGState()
    }
}

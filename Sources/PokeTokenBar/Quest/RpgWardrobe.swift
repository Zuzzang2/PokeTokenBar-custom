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

    /// A small icon for a cosmetic: a tile in its set's colours with the slot's name.
    func drawCosmeticIcon(_ ctx: CGContext, _ c: RpgCosmetic, in r: CGRect, owned: Bool = true, worn: Bool = false) {
        let theme = RpgCosmetics.theme(c.theme)
        let main = theme.map { NSColor(red: CGFloat($0.main.r) / 255, green: CGFloat($0.main.g) / 255, blue: CGFloat($0.main.b) / 255, alpha: 1) } ?? NSColor(white: 0.45, alpha: 1)
        let trim = theme.map { NSColor(red: CGFloat($0.trim.r) / 255, green: CGFloat($0.trim.g) / 255, blue: CGFloat($0.trim.b) / 255, alpha: 1) } ?? .white
        ctx.setFillColor(main.cgColor)
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 4, dy: 4), cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(trim.withAlphaComponent(0.9).cgColor)
        ctx.fill(CGRect(x: r.minX + 8, y: r.minY + 8, width: r.width - 16, height: 4))
        text(c.slot.title, at: CGPoint(x: r.midX, y: r.midY - 6), size: 11, color: .white, weight: .heavy, align: .center)
        if !owned { ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor); ctx.fill(r.insetBy(dx: 4, dy: 4)) }
        if worn { text("착용", at: CGPoint(x: r.maxX - 6, y: r.minY + 6), size: 9, color: Self.gold, weight: .heavy, align: .right) }
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
            let odds = zip(RpgCosmetics.rarityName, RpgCosmetics.gachaOdds).map { "\($0) \($1)%" }.joined(separator: "  ·  ")
            text(odds, at: CGPoint(x: area.minX + 8, y: area.minY + 40), size: 12, color: Self.dim, weight: .semibold)
            text("\(RpgCosmetics.pity)번 안에 영웅 이상이 안 나오면 다음 뽑기는 영웅 이상 보장", at: CGPoint(x: area.minX + 8, y: area.minY + 62), size: 12, color: Self.dim, weight: .semibold)
            text("지금까지 \(p.gachaPity)회 연속 · 중복은 가격의 1/3 환급", at: CGPoint(x: area.minX + 8, y: area.minY + 84), size: 12, color: Self.gold, weight: .semibold)
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
            ctx.setStrokeColor((idx == selection ? Self.gold : RpgArt.rarityColors[min(c.rarity, 4)].withAlphaComponent(0.7)).cgColor)
            ctx.setLineWidth(idx == selection ? 3 : 1.5)
            ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.strokePath()
        }
        if list.isEmpty { text(tab == 0 ? "가진 외관이 없어요 (상점·뽑기·드랍으로 얻어요)" : "", at: CGPoint(x: area.minX + 8, y: area.minY + 20), size: 12, color: Self.dim) }
        if let sel {
            text(sel.name, at: CGPoint(x: card.midX, y: card.minY + 168), size: 15, color: RpgArt.rarityColors[min(sel.rarity, 4)], weight: .bold, align: .center)
            text("\(RpgCosmetics.rarityName[min(sel.rarity, 4)]) · \(sel.slot.title)", at: CGPoint(x: card.midX, y: card.minY + 190), size: 11, color: Self.dim, weight: .semibold, align: .center)
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

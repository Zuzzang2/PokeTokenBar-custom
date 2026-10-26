import AppKit
import CoreGraphics

// SPIKE: 메이플 스타일 창. 가방 (탭 + 아이템 격자 + 비교 툴팁), 장비창 (캐릭터 + 장비 칸 + 상세 능력치), 스킬창 (직업 단계 탭 +
// 아이콘 + 레벨 점 + 상세). Drawing and keys live here; `RpgView` routes to these from `drawPanel` and `handlePanelKey`.

enum RpgEquipSlot: Int, CaseIterable {
    case weapon, armor, ring, amulet, helmet, boots

    var title: String { ["무기", "갑옷", "반지", "목걸이", "투구", "신발"][rawValue] }
    /// Two columns around the character, top to bottom.
    static let left: [RpgEquipSlot] = [.weapon, .ring, .amulet]
    static let right: [RpgEquipSlot] = [.helmet, .armor, .boots]

    func id(_ p: RpgPlayer) -> String? {
        switch self {
        case .weapon: return p.weapon
        case .armor: return p.armor
        case .ring: return p.ring
        case .amulet: return p.amulet
        case .helmet: return p.helmet
        case .boots: return p.boots
        }
    }
}

extension RpgView {
    static let bagTabs = ["장비", "소비", "기타"]
    static let bagColumns = 6
    static let skillTabs = ["기본", "2차", "3차", "4차", "능력치"]

    // MARK: bag

    func bagTab(_ item: RpgItem) -> Int {
        switch item.kind {
        case .weapon, .armor, .ring, .amulet, .helmet, .boots: return 0
        case .potionHP, .potionMP, .scroll, .buff: return 1
        default: return 2
        }
    }

    func bagList(_ p: RpgPlayer) -> [String] {
        sortedInventory(p).filter { RpgItems.item($0).map(bagTab) == tab }
    }

    func equippedItem(like item: RpgItem, _ p: RpgPlayer) -> RpgItem? {
        switch item.kind {
        case .weapon: return p.weaponItem
        case .armor: return p.armorItem
        case .ring: return p.ringItem
        case .amulet: return p.amuletItem
        case .helmet: return p.helmetItem
        case .boots: return p.bootsItem
        default: return nil
        }
    }

    /// Stat lines of an item, each with the change against what is worn in that slot (green up, red down).
    func statLines(_ item: RpgItem, _ p: RpgPlayer, compare: Bool) -> [(String, NSColor)] {
        let green = NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1), red = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1)
        let worn = compare ? equippedItem(like: item, p) : nil
        let wornPlus = worn.map { p.plus[$0.id] ?? 0 } ?? 0
        func line(_ label: String, _ value: Double, _ other: Double?, pct: Bool = false) -> (String, NSColor)? {
            guard value != 0 || (other ?? 0) != 0 else { return nil }
            let f: (Double) -> String = { pct ? "\(Int(($0 * 100).rounded()))%" : "\(Int($0.rounded()))" }
            var s = "\(label)  +\(f(value))"
            var color = NSColor.white
            if let other, worn != nil, worn?.id != item.id {
                let d = value - other
                if abs(d) > 1e-9 { s += "  (\(d > 0 ? "▲" : "▼")\(f(abs(d))))"; color = d > 0 ? green : red }
            }
            return (s, color)
        }
        let plus = p.plus[item.id] ?? 0
        var rows: [(String, NSColor)?] = [
            line("공격력", RpgItems.boosted(item.attack, plus: plus), worn.map { RpgItems.boosted($0.attack, plus: wornPlus) }),
            line("방어력", RpgItems.boosted(item.defense, plus: plus), worn.map { RpgItems.boosted($0.defense, plus: wornPlus) }),
            line("HP", Double(item.bonusHP), worn.map { Double($0.bonusHP) }),
            line("MP", Double(item.bonusMP), worn.map { Double($0.bonusMP) }),
            line("치명타", item.bonusCrit, worn.map(\.bonusCrit), pct: true),
            line("공격력 %", item.bonusAttack, worn.map(\.bonusAttack), pct: true),
            line("이동속도", item.bonusSpeed, worn.map(\.bonusSpeed), pct: true),
        ]
        if item.heal > 0 { rows.append((item.kind == .potionMP ? "MP +\(item.heal) 회복" : "HP +\(item.heal) 회복", .white)) }
        return rows.compactMap { $0 }
    }

    func drawSlot(_ ctx: CGContext, _ r: CGRect, item: RpgItem?, count: Int? = nil, plus: Int = 0, selected: Bool, dimmed: Bool = false) {
        ctx.setFillColor(NSColor(white: 0.1, alpha: 0.85).cgColor)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
        let border = selected ? Self.gold : (item.map { RpgArt.rarityColors[$0.rarity].withAlphaComponent(0.7) } ?? NSColor(white: 0.3, alpha: 1))
        ctx.setStrokeColor(border.cgColor)
        ctx.setLineWidth(selected ? 3 : 1.5)
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.strokePath()
        guard let item, let icon = RpgArt.icon(item) else { return }
        ctx.interpolationQuality = .none
        if dimmed { ctx.setAlpha(0.45) }
        KartArt.draw(icon, in: ctx, rect: r.insetBy(dx: 5, dy: 5))
        ctx.setAlpha(1)
        if let count, count > 1 { text("\(count)", at: CGPoint(x: r.maxX - 4, y: r.maxY - 15), size: 11, align: .right, mono: true) }
        if plus > 0 { text("+\(plus)", at: CGPoint(x: r.minX + 4, y: r.minY + 2), size: 10, color: Self.gold, mono: true) }
    }

    /// The right-hand detail card for an item: icon, name, kind, stats with comparison, description.
    func drawItemCard(_ ctx: CGContext, _ item: RpgItem?, _ p: RpgPlayer, in r: CGRect, compare: Bool = true, extra: String? = nil) {
        box(ctx, r, alpha: 0.5)
        guard let item else {
            text("아이템을 고르세요", at: CGPoint(x: r.midX, y: r.minY + 20), size: 13, color: Self.dim, align: .center)
            return
        }
        drawSlot(ctx, CGRect(x: r.minX + 10, y: r.minY + 10, width: 52, height: 52), item: item, selected: false)
        let plus = p.plus[item.id] ?? 0
        text((plus > 0 ? "+\(plus) " : "") + item.name, at: CGPoint(x: r.minX + 72, y: r.minY + 12), size: 15, color: RpgArt.rarityColors[item.rarity], weight: .bold)
        let kind: String
        switch item.kind {
        case .weapon(let c): kind = "\(c.name) 무기"
        case .armor: kind = "갑옷"
        case .ring: kind = "반지"
        case .amulet: kind = "목걸이"
        case .helmet: kind = "투구"
        case .boots: kind = "신발"
        case .potionHP, .potionMP: kind = "물약"
        case .scroll: kind = "주문서"
        case .book: kind = "스킬북"
        case .stone: kind = "강화석"
        case .material: kind = "제작 재료"
        case .buff: kind = "강화 아이템"
        }
        text("\(RpgItems.rarityName[min(item.rarity, 4)]) · \(kind)" + (item.element != .base && item.isEquipment ? " · \(item.element.effectName)" : ""),
             at: CGPoint(x: r.minX + 72, y: r.minY + 34), size: 11, color: Self.dim, weight: .semibold)
        var y = r.minY + 76
        for (s, color) in statLines(item, p, compare: compare) {
            text(s, at: CGPoint(x: r.minX + 14, y: y), size: 13, color: color, weight: .bold)
            y += 20
        }
        var notes: [String] = []
        switch item.kind {
        case .scroll: notes.append("마을로 즉시 귀환")
        case .stone: notes.append("대장간에서 장비 강화에 사용")
        case .book(let id): if let s = RpgSkills.def(id) { notes.append("\(s.cls.name) · Lv\(s.minLevel)+ · \(s.name): \(s.desc)") }
        case .material: notes.append("대장간에서 제작에 사용")
        case .buff(let id): if let b = RpgBuffs.def(id) { notes.append(b.desc) }
        default: break
        }
        if let extra { notes.append(extra) }
        for n in notes {
            text(n, at: CGPoint(x: r.minX + 14, y: y + 2), size: 11, color: Self.dim, weight: .semibold)
            y += 18
        }
        text("판매가 \(item.sellPrice) G", at: CGPoint(x: r.maxX - 12, y: r.maxY - 22), size: 11, color: Self.gold, align: .right, mono: true)
    }

    func drawBag(_ ctx: CGContext, _ p: RpgPlayer) {
        let area = frame(ctx, title: "가방", hint: "방향키 이동   Tab 탭 전환   Enter 장착 · 사용   \(bindings.label(.inventory))/Esc 닫기", tabs: Self.bagTabs)
        text("\(p.gold) G", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 15, color: Self.gold, align: .right, mono: true)
        let ids = bagList(p)
        selection = min(selection, max(0, ids.count - 1))
        let cols = Self.bagColumns, cell: CGFloat = 52, gap: CGFloat = 6
        let gridW = CGFloat(cols) * (cell + gap) - gap
        let rowsVisible = max(1, Int((area.height + gap) / (cell + gap)))
        let firstRow = max(0, min(selection / cols - rowsVisible / 2, max(0, (ids.count - 1) / cols - rowsVisible + 1)))
        let slotsShown = rowsVisible * cols
        for k in 0..<slotsShown {
            let idx = firstRow * cols + k
            let r = CGRect(x: area.minX + CGFloat(k % cols) * (cell + gap), y: area.minY + CGFloat(k / cols) * (cell + gap), width: cell, height: cell)
            if idx < ids.count, let item = RpgItems.item(ids[idx]) {
                let eq = ids[idx] == p.weapon || ids[idx] == p.armor || ids[idx] == p.ring || ids[idx] == p.amulet || ids[idx] == p.helmet || ids[idx] == p.boots
                drawSlot(ctx, r, item: item, count: p.inventory[ids[idx]], plus: p.plus[ids[idx]] ?? 0, selected: idx == selection, dimmed: eq)
            } else {
                drawSlot(ctx, r, item: nil, selected: idx == selection)
            }
        }
        if ids.isEmpty { text("이 탭에는 아이템이 없어요", at: CGPoint(x: area.minX + gridW / 2, y: area.minY + 24), size: 12, color: Self.dim, align: .center) }
        let card = CGRect(x: area.minX + gridW + 14, y: area.minY, width: area.width - gridW - 14, height: area.height)
        let item = ids.indices.contains(selection) ? RpgItems.item(ids[selection]) : nil
        drawItemCard(ctx, item, p, in: card)
    }

    // MARK: equipment

    func playerSprite(_ p: RpgPlayer) -> CGImage? {
        let tint = RpgArt.classTint(p.cls, weapon: p.weaponItem).merging(RpgJobs.tint(p.cls, p.job)) { weapon, _ in weapon }
        return RpgArt.sprite(p.cls.rawValue, tint: tint)
    }

    /// The incoming monster attack used for the "damage taken" readout: the normal monster closest to the player's level.
    func typicalMonsterAttack(_ level: Int) -> Double {
        let normal = RpgMonsters.all.filter { $0.behavior != .boss }
        return Double(normal.min { abs($0.level - level) < abs($1.level - level) }?.attack ?? 10)
    }

    func drawEquipment(_ ctx: CGContext, _ p: RpgPlayer) {
        let area = frame(ctx, title: "장비창", hint: "방향키 선택   Enter 해제   \(bindings.label(.equipment))/Esc 닫기")
        let cell: CGFloat = 56
        let leftX = area.minX + 6, rightX = area.minX + 6 + cell + 118
        let top = area.minY + 8, step = cell + 22
        var rects: [RpgEquipSlot: CGRect] = [:]
        for (k, s) in RpgEquipSlot.left.enumerated() { rects[s] = CGRect(x: leftX, y: top + CGFloat(k) * step, width: cell, height: cell) }
        for (k, s) in RpgEquipSlot.right.enumerated() { rects[s] = CGRect(x: rightX, y: top + CGFloat(k) * step, width: cell, height: cell) }
        selection = min(max(selection, 0), RpgEquipSlot.allCases.count - 1)
        for s in RpgEquipSlot.allCases {
            guard let r = rects[s] else { continue }
            let item = s.id(p).flatMap(RpgItems.item)
            drawSlot(ctx, r, item: item, plus: s.id(p).flatMap { p.plus[$0] } ?? 0, selected: s.rawValue == selection)
            text(s.title, at: CGPoint(x: r.midX, y: r.maxY + 2), size: 10, color: Self.dim, weight: .semibold, align: .center)
        }
        // The character between the two columns.
        let dollRect = CGRect(x: leftX + cell + 8, y: top, width: 102, height: 3 * step - 20)
        box(ctx, dollRect, alpha: 0.35)
        if let img = playerSprite(p) {
            ctx.interpolationQuality = .none
            let h: CGFloat = 96, w = h * CGFloat(img.width) / CGFloat(img.height)
            KartArt.draw(img, in: ctx, rect: CGRect(x: dollRect.midX - w / 2, y: dollRect.minY + 40, width: w, height: h))
        }
        text(p.name, at: CGPoint(x: dollRect.midX, y: dollRect.minY + 8), size: 13, weight: .bold, align: .center)
        text("\(p.title) Lv\(p.level)", at: CGPoint(x: dollRect.midX, y: dollRect.minY + 24), size: 11, color: Self.gold, weight: .bold, align: .center)
        text("공격 \(Int(p.attack(at: world.time)))", at: CGPoint(x: dollRect.midX, y: dollRect.maxY - 36), size: 11, align: .center)
        text("방어 \(Int(p.defense))", at: CGPoint(x: dollRect.midX, y: dollRect.maxY - 20), size: 11, align: .center)

        // Stat sheet.
        let sx = rightX + cell + 18, sw = area.maxX - sx
        let atk = p.attack(at: world.time)
        let hit = RpgCombat.readout(attack: atk)
        let crit = p.critChance(at: world.time)
        let interval = p.attackInterval(at: world.time)
        let taken = 1 - RpgCombat.mitigation(typicalMonsterAttack(p.level), defense: p.defense)
        let rows: [(String, String)] = [
            ("HP", "\(Int(p.hp)) / \(Int(p.maxHP))"), ("MP", "\(Int(p.mp)) / \(Int(p.maxMP))"),
            ("공격력", "\(Int(hit.min)) ~ \(Int(hit.max))"),
            ("치명타", "\(Int((crit * 100).rounded()))%  (최대 \(Int(hit.crit)))"),
            ("공격 속도", String(format: "초당 %.1f회", 1 / interval)),
            ("방어력", "\(Int(p.defense))  (받는 피해 -\(Int(((1 - taken) * 100).rounded()))%)"),
            ("이동 속도", "\(Int(p.speed(at: world.time)))"),
            ("속성", p.element == .base ? "없음" : p.element.effectName),
            ("힘 / 민첩", "\(p.stats[0]) / \(p.stats[1])"), ("체력 / 지력", "\(p.stats[2]) / \(p.stats[3])"),
            ("남은 포인트", "SP \(p.sp) · AP \(p.ap)"),
        ]
        for (k, row) in rows.enumerated() {
            text(row.0, at: CGPoint(x: sx, y: area.minY + 8 + CGFloat(k) * 22), size: 12, color: Self.dim, weight: .semibold)
            text(row.1, at: CGPoint(x: sx + sw, y: area.minY + 8 + CGFloat(k) * 22), size: 12, align: .right, mono: true)
        }
        // Selected slot detail.
        let sel = RpgEquipSlot(rawValue: selection) ?? .weapon
        let card = CGRect(x: area.minX, y: area.minY + 3 * step + 8, width: area.width, height: area.maxY - (area.minY + 3 * step + 8))
        if card.height > 40 {
            let item = sel.id(p).flatMap(RpgItems.item)
            box(ctx, card, alpha: 0.5)
            if let item {
                text((p.plus[item.id] ?? 0) > 0 ? "+\(p.plus[item.id]!) \(item.name)" : item.name, at: CGPoint(x: card.minX + 12, y: card.minY + 8), size: 14, color: RpgArt.rarityColors[item.rarity], weight: .bold)
                text(statLines(item, p, compare: false).map(\.0).joined(separator: "   ") + (item.element != .base ? "   \(item.element.effectName)" : ""),
                     at: CGPoint(x: card.minX + 12, y: card.minY + 30), size: 12, weight: .bold)
            } else {
                text("\(sel.title) 칸이 비어 있어요", at: CGPoint(x: card.minX + 12, y: card.minY + 8), size: 13, color: Self.dim)
            }
        }
    }

    // MARK: skills

    /// The skills shown on a tab: 0 is the class's own, 1-3 the 2차/3차/4차 job's (empty until reached).
    func skillRows(_ p: RpgPlayer, tab t: Int) -> [RpgSkillDef] {
        if t == 0 { return p.cls.skills }
        guard t <= 3, p.job != 0, p.tier >= t else { return [] }
        return RpgJobs.def(p.cls, p.job, tier: t)?.skills.compactMap(RpgSkills.def) ?? []
    }

    func drawSkills(_ ctx: CGContext, _ p: RpgPlayer) {
        let area = frame(ctx, title: tab == 4 ? "능력치  (AP \(p.ap))" : "스킬  (SP \(p.sp))",
                         hint: tab == 4 ? "↑↓ 선택   Enter +1   Delete 초기화(\(RpgStats.resetCost(level: p.level))G)   ←→ 탭   \(bindings.label(.skills))/Esc 닫기"
                                        : "↑↓ 선택   Enter 스킬 레벨업   슬롯 키(\(bindings.label(.slot(0)))…\(bindings.label(.slot(7))))로 배치   Delete 슬롯에서 빼기   ←→ 탭",
                         tabs: Self.skillTabs)
        if tab == 4 { drawStats(ctx, p, area); return }
        let rows = skillRows(p, tab: tab)
        if rows.isEmpty {
            let need = tab == 1 ? "Lv\(RpgJobs.advanceLevel)에 전직관에서" : "Lv\(RpgTiers.levels[tab] ?? 0)에 전직관에서 \(tab + 1)차 전직을 하면"
            text(p.job == 0 && tab > 1 ? "먼저 2차 전직을 하세요" : "\(need) 열려요", at: CGPoint(x: area.midX, y: area.minY + 40), size: 14, color: Self.dim, align: .center)
            return
        }
        selection = min(selection, rows.count - 1)
        let detailH: CGFloat = 78
        let listRect = CGRect(x: area.minX, y: area.minY, width: area.width, height: area.height - detailH - 6)
        list(ctx, count: rows.count, in: listRect, rowH: 54) { i, r in
            let s = rows[i]
            let lv = p.skills[s.id]
            drawSkillIcon(ctx, s, in: CGRect(x: r.minX + 6, y: r.minY + 4, width: 40, height: 40), learned: lv != nil)
            let slot = p.slots.firstIndex(of: s.id).map { "  [\(bindings.label(.slot($0)))]" } ?? ""
            text(s.name + slot, at: CGPoint(x: r.minX + 56, y: r.minY + 6), size: 14, color: lv != nil ? (s.isUltimate ? RpgArt.rarityColors[3] : .white) : NSColor(white: 0.5, alpha: 1), weight: .bold)
            // Level pips.
            for k in 0..<s.maxLevel {
                ctx.setFillColor((k < (lv ?? 0) ? Self.gold : NSColor(white: 0.25, alpha: 1)).cgColor)
                ctx.fill(CGRect(x: r.minX + 56 + CGFloat(k) * 9, y: r.minY + 28, width: 7, height: 5))
            }
            let state = lv.map { "Lv\($0)/\(s.maxLevel)" } ?? (s.price > 0 ? "마법서점 \(s.price)G" : (s.isUltimate ? "보스 드랍" : "드랍으로 습득"))
            text(state, at: CGPoint(x: r.maxX - 12, y: r.minY + 6), size: 12, color: lv != nil ? Self.gold : Self.dim, align: .right, mono: true)
            text("Lv\(s.minLevel)+ · MP \(s.mp) · 쿨 \(Int(s.cooldown))초", at: CGPoint(x: r.maxX - 12, y: r.minY + 26), size: 10, color: Self.dim, align: .right)
        }
        // Detail card of the selected skill.
        let s = rows[selection]
        let lv = p.skills[s.id] ?? 1
        let card = CGRect(x: area.minX, y: area.maxY - detailH, width: area.width, height: detailH)
        box(ctx, card, alpha: 0.5)
        text(s.desc, at: CGPoint(x: card.minX + 12, y: card.minY + 8), size: 12, weight: .bold)
        if s.power > 0 {
            let now = Int(RpgSkills.damage(s, level: lv) * 100), next = Int(RpgSkills.damage(s, level: min(s.maxLevel, lv + 1)) * 100)
            let atk = p.attack(at: world.time) * RpgStats.skillFactor(p.stats)
            let perHit = Int(atk * RpgSkills.damage(s, level: lv))
            text("위력 \(now)%" + (lv < s.maxLevel && p.skills[s.id] != nil ? "  →  다음 레벨 \(next)%" : "") + "    한 번에 약 \(perHit) 피해", at: CGPoint(x: card.minX + 12, y: card.minY + 30), size: 12, color: Self.gold, weight: .bold)
        } else {
            text("피해를 주지 않는 보조 스킬이에요", at: CGPoint(x: card.minX + 12, y: card.minY + 30), size: 12, color: Self.dim)
        }
        if let fx = s.fx { text(Self.fxSummary(fx), at: CGPoint(x: card.minX + 12, y: card.minY + 52), size: 11, color: Self.dim, weight: .semibold) }
    }

    static func fxSummary(_ fx: RpgSkillFX) -> String {
        switch fx.shape {
        case .shot: return "투사체 \(fx.count)발" + (fx.big ? " · 관통" : "")
        case .zone: return "\(fx.count)회 폭발 · 반경 \(Int(fx.radius))"
        case .rain: return "\(fx.count)개 낙하 · 반경 \(Int(fx.radius))"
        case .chain: return "가까운 적 \(fx.count)명을 차례로 타격"
        case .line: return "전방 일직선 \(fx.count)연타"
        case .buff: return "\(Int(fx.seconds))초" + (fx.heal > 0 ? " · HP \(Int(fx.heal * 100))% 회복" : "")
        case .trap: return "지뢰 \(fx.count)개"
        case .turret: return "터렛 \(fx.count)대 · \(Int(fx.seconds))초"
        }
    }

    func drawStats(_ ctx: CGContext, _ p: RpgPlayer, _ area: CGRect) {
        list(ctx, count: RpgStats.names.count, in: CGRect(x: area.minX, y: area.minY, width: area.width, height: 4 * 60), rowH: 60) { i, r in
            text("\(RpgStats.names[i])  \(p.stats[i])", at: CGPoint(x: r.minX + 12, y: r.minY + 6), size: 16, color: p.ap > 0 ? Self.gold : .white, weight: .bold)
            text(RpgStats.blurbs[i], at: CGPoint(x: r.minX + 12, y: r.minY + 32), size: 11, color: Self.dim, weight: .semibold)
        }
        let hit = RpgCombat.readout(attack: p.attack(at: world.time))
        text("공격 \(Int(hit.min))~\(Int(hit.max))  ·  방어 \(Int(p.defense))  ·  HP \(Int(p.maxHP))  ·  MP \(Int(p.maxMP))  ·  치명타 \(Int(p.critChance(at: world.time) * 100))%",
             at: CGPoint(x: area.minX + 12, y: area.minY + 4 * 60 + 12), size: 13, weight: .bold)
    }

    // MARK: skill icons

    enum Glyph { case shot, burst, rain, chain, line, buff, heal, trap, turret, summon, slash }

    static func glyph(_ s: RpgSkillDef) -> Glyph {
        if let fx = s.fx {
            switch fx.shape {
            case .shot: return .shot
            case .zone: return .burst
            case .rain: return .rain
            case .chain: return .chain
            case .line: return .line
            case .buff: return fx.heal > 0 && fx.flags.isEmpty ? .heal : .buff
            case .trap: return .trap
            case .turret: return .turret
            }
        }
        let t = s.name + s.desc
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if has(["덫", "지뢰"]) { return .trap }
        if has(["회복", "치유", "치료", "생명"]) && s.power == 0 { return .heal }
        if s.power == 0 { return .buff }
        if has(["소환", "해골", "맹수", "정령", "용"]) { return .summon }
        if has(["번개", "전격", "연쇄", "체인", "차례"]) { return .chain }
        if has(["운석", "메테오", "낙하", "폭풍", "비"]) { return .rain }
        if has(["화살", "탄", "사격", "저격", "로켓", "포", "구슬", "볼트"]) { return .shot }
        if has(["일직선", "쓸", "지진", "균열", "전방"]) { return .line }
        if has(["베", "참", "검", "일격", "연타", "돌진"]) { return .slash }
        return .burst
    }

    static func element(_ s: RpgSkillDef) -> RpgElement {
        if let e = s.fx?.element { return e }
        let t = s.name + s.desc
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if has(["불", "화염", "지옥", "용암", "화룡", "태양"]) { return .fire }
        if has(["얼음", "서리", "빙", "눈보라", "냉기"]) { return .ice }
        if has(["번개", "전격", "벼락"]) { return .thunder }
        if has(["독"]) { return .poison }
        if has(["신성", "성", "빛", "축복", "치유", "천"]) { return .holy }
        if has(["바람", "질풍", "회오리", "폭풍"]) { return .wind }
        if has(["우주", "별", "차원", "죽음", "저주", "악마", "대악마", "암흑"]) { return .cosmic }
        switch s.cls {
        case .warrior: return .fire
        case .archer: return .wind
        case .mage: return .ice
        case .rogue: return .cosmic
        case .cleric: return .holy
        case .monk: return .thunder
        case .summoner: return .cosmic
        case .mechanic: return .base
        }
    }

    nonisolated(unsafe) static var skillIconCache: [String: CGImage] = [:]

    static func skillIcon(_ s: RpgSkillDef) -> CGImage? {
        if let img = skillIconCache[s.id] { return img }
        guard let c = KartArt.context(width: 32, height: 32) else { return nil }
        let e = RpgArt.elem(element(s))
        let outline = NSColor(red: 0.11, green: 0.09, blue: 0.15, alpha: 1).cgColor
        // Rounded background in the element's colours.
        let bg = CGPath(roundedRect: CGRect(x: 1, y: 1, width: 30, height: 30), cornerWidth: 6, cornerHeight: 6, transform: nil)
        c.addPath(bg); c.setFillColor(e.edge); c.fillPath()
        let inner = CGPath(roundedRect: CGRect(x: 3, y: 3, width: 26, height: 26), cornerWidth: 5, cornerHeight: 5, transform: nil)
        c.addPath(inner); c.setFillColor(e.mid.copy(alpha: 0.55) ?? e.mid); c.fillPath()
        c.addPath(bg); c.setStrokeColor(outline); c.setLineWidth(2); c.strokePath()
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        func stroke(_ pts: [CGPoint], width: CGFloat = 3, color: CGColor? = nil) {
            c.setStrokeColor(outline); c.setLineWidth(width + 2); c.setLineCap(.round); c.setLineJoin(.round)
            c.addLines(between: pts); c.strokePath()
            c.setStrokeColor(color ?? white); c.setLineWidth(width)
            c.addLines(between: pts); c.strokePath()
        }
        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: CGColor? = nil) {
            c.setFillColor(outline); c.fillEllipse(in: CGRect(x: x - r - 1, y: y - r - 1, width: 2 * r + 2, height: 2 * r + 2))
            c.setFillColor(color ?? white); c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        switch glyph(s) {
        case .shot:
            stroke([CGPoint(x: 7, y: 8), CGPoint(x: 24, y: 24)])
            stroke([CGPoint(x: 16, y: 24), CGPoint(x: 24, y: 24), CGPoint(x: 24, y: 16)])
        case .burst:
            for k in 0..<8 {
                let a = Double(k) * .pi / 4
                stroke([CGPoint(x: 16 + cos(a) * 5, y: 16 + sin(a) * 5), CGPoint(x: 16 + cos(a) * 11, y: 16 + sin(a) * 11)], width: 2.5)
            }
            dot(16, 16, 4, e.core)
        case .rain:
            for (x, y) in [(9.0, 22.0), (16.0, 16.0), (23.0, 22.0)] {
                stroke([CGPoint(x: x + 5, y: y + 6), CGPoint(x: x, y: y)], width: 2.5)
                dot(x, y - 1, 3, e.core)
            }
        case .chain:
            stroke([CGPoint(x: 18, y: 26), CGPoint(x: 11, y: 16), CGPoint(x: 20, y: 16), CGPoint(x: 13, y: 6)], width: 3, color: e.core)
        case .line:
            stroke([CGPoint(x: 6, y: 16), CGPoint(x: 26, y: 16)], width: 6, color: e.core)
            stroke([CGPoint(x: 6, y: 16), CGPoint(x: 26, y: 16)], width: 2)
        case .buff:
            let shield: [CGPoint] = [CGPoint(x: 16, y: 6), CGPoint(x: 25, y: 10), CGPoint(x: 24, y: 19), CGPoint(x: 16, y: 26), CGPoint(x: 8, y: 19), CGPoint(x: 7, y: 10), CGPoint(x: 16, y: 6)]
            stroke(shield, width: 3)
            stroke([CGPoint(x: 16, y: 11), CGPoint(x: 16, y: 20)], width: 2.5, color: e.core)
        case .heal:
            stroke([CGPoint(x: 16, y: 7), CGPoint(x: 16, y: 25)], width: 5)
            stroke([CGPoint(x: 7, y: 16), CGPoint(x: 25, y: 16)], width: 5)
        case .trap:
            for k in 0..<6 {
                let a = Double(k) * .pi / 3
                stroke([CGPoint(x: 16 + cos(a) * 4, y: 16 + sin(a) * 4), CGPoint(x: 16 + cos(a) * 10, y: 16 + sin(a) * 10)], width: 3)
            }
            dot(16, 16, 5)
        case .turret:
            dot(14, 12, 6)
            stroke([CGPoint(x: 16, y: 18), CGPoint(x: 25, y: 24)], width: 4)
            stroke([CGPoint(x: 8, y: 6), CGPoint(x: 21, y: 6)], width: 3)
        case .summon:
            dot(16, 16, 8, e.core)
            stroke([CGPoint(x: 11, y: 16), CGPoint(x: 21, y: 16)], width: 2.5, color: e.edge)
            stroke([CGPoint(x: 16, y: 11), CGPoint(x: 16, y: 21)], width: 2.5, color: e.edge)
            dot(7, 25, 2); dot(25, 25, 2); dot(16, 5, 2)
        case .slash:
            stroke([CGPoint(x: 7, y: 25), CGPoint(x: 25, y: 7)], width: 5)
            stroke([CGPoint(x: 12, y: 25), CGPoint(x: 25, y: 12)], width: 2.5, color: e.core)
        }
        let img = c.makeImage()
        if let img { skillIconCache[s.id] = img }
        return img
    }

    func drawSkillIcon(_ ctx: CGContext, _ s: RpgSkillDef, in r: CGRect, learned: Bool = true) {
        guard let img = Self.skillIcon(s) else { return }
        ctx.interpolationQuality = .none
        if !learned { ctx.setAlpha(0.4) }
        KartArt.draw(img, in: ctx, rect: r)
        ctx.setAlpha(1)
    }

    // MARK: keys

    /// Keys for the grid-like windows. Returns true when the key was used.
    func handleWindowKey(_ code: UInt16, repeatKey: Bool, _ p: RpgPlayer) -> Bool {
        switch panel {
        case .inventory:
            let ids = bagList(p)
            let cols = Self.bagColumns
            switch code {
            case 123: selection = max(0, selection - 1)
            case 124: selection = min(max(0, ids.count - 1), selection + 1)
            case 126: selection = selection >= cols ? selection - cols : selection
            case 125: selection = selection + cols < ids.count ? selection + cols : selection
            case 48, 30: if !repeatKey { tab = (tab + 1) % Self.bagTabs.count; selection = 0 }
            case 33: if !repeatKey { tab = (tab + Self.bagTabs.count - 1) % Self.bagTabs.count; selection = 0 }
            case 36: if !repeatKey, ids.indices.contains(selection) { act(.equip(ids[selection])) }
            default: return false
            }
            return true
        case .equipment:
            let leftCol = RpgEquipSlot.left, rightCol = RpgEquipSlot.right
            let cur = RpgEquipSlot(rawValue: selection) ?? .weapon
            let inLeft = leftCol.contains(cur)
            let col = inLeft ? leftCol : rightCol
            let row = col.firstIndex(of: cur) ?? 0
            switch code {
            case 126: selection = col[max(0, row - 1)].rawValue
            case 125: selection = col[min(col.count - 1, row + 1)].rawValue
            case 123, 124: selection = (inLeft ? rightCol : leftCol)[row].rawValue
            case 36: if !repeatKey { act(.unequip(selection)) }
            default: return false
            }
            return true
        case .skills:
            switch code {
            case 123: if !repeatKey { tab = (tab + Self.skillTabs.count - 1) % Self.skillTabs.count; selection = 0 }
            case 124, 48: if !repeatKey { tab = (tab + 1) % Self.skillTabs.count; selection = 0 }
            case 126: selection = max(0, selection - 1)
            case 125: selection = min(max(0, (tab == 4 ? RpgStats.names.count : skillRows(p, tab: tab).count) - 1), selection + 1)
            case 36:
                guard !repeatKey else { return true }
                if tab == 4 { act(.addStat(selection)); return true }
                let rows = skillRows(p, tab: tab)
                guard rows.indices.contains(selection) else { return true }
                let s = rows[selection]
                if p.skills[s.id] != nil { act(.levelSkill(s.id)) }
                else { world.toast(s.price > 0 ? "마법서점에서 스킬북을 살 수 있어요" : "몬스터가 떨어뜨리는 스킬북으로 배워요") }
            case 51:
                guard !repeatKey else { return true }
                if tab == 4 { act(.resetStats); return true }
                let rows = skillRows(p, tab: tab)
                if rows.indices.contains(selection), let slot = p.slots.firstIndex(of: rows[selection].id) { act(.assign(slot: slot, skill: nil)) }
            default:
                guard tab < 4, !repeatKey, let slot = bindings.actions(for: code).compactMap(\.slotIndex).first else { return false }
                let rows = skillRows(p, tab: tab)
                guard rows.indices.contains(selection) else { return true }
                let s = rows[selection]
                if p.skills[s.id] != nil { act(.assign(slot: slot, skill: s.id)); world.toast("\(s.name) → 슬롯 \(bindings.label(.slot(slot)))") }
                else { world.toast("아직 배우지 않은 스킬이에요") }
            }
            return true
        default:
            return false
        }
    }
}

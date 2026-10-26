import AppKit
import QuartzCore

// SPIKE: draws and drives `RpgWorld` for the local player. Low-res pixel frame (map, units, effects,
// cave darkness with torch light) scaled up with nearest-neighbour, then a crisp HUD: status, hotbar,
// toasts, damage numbers, and the inventory / shop panels, all keyboard driven.

@MainActor
final class RpgView: NSView {
    var onExit: (() -> Void)?
    var onSave: ((RpgSaveData) -> Void)?

    private enum Panel: Equatable { case none, inventory, shop(RpgShop) }

    private let world: RpgWorld
    private let localID: Int
    private var keys = Set<UInt16>()
    private var pressed = Set<UInt16>()
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var frameContext: CGContext?
    private var darkContext: CGContext?
    private var mapImages: [RpgMapID: CGImage] = [:]
    private var origin = CGPoint.zero
    private var scale: CGFloat = 3
    private var panel = Panel.none
    private var selection = 0
    private var shopSelling = false
    private var saveClock = 0.0

    init(frame: NSRect, world: RpgWorld, localID: Int) {
        self.world = world
        self.localID = localID
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    func stop() {
        link?.invalidate()
        link = nil
        saveNow()
    }

    func saveNow() {
        if let p = world.player(localID) { onSave?(RpgSaveStore.snapshot(p)) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, link == nil {
            let l = displayLink(target: self, selector: #selector(step(_:)))
            l.add(to: .main, forMode: .common)
            link = l
            lastTick = CACurrentMediaTime()
        } else if window == nil {
            stop()
        }
    }

    // MARK: input

    private func held(_ codes: UInt16...) -> Bool { codes.contains { keys.contains($0) } }
    private func tapped(_ codes: UInt16...) -> Bool { codes.contains { pressed.contains($0) } }

    override func keyDown(with event: NSEvent) {
        keys.insert(event.keyCode)
        if panel != .none {
            // Panel keys stay in the panel: closing with Esc or I must not also exit or reopen.
            handlePanelKey(event.keyCode, repeatKey: event.isARepeat)
            return
        }
        if !event.isARepeat { pressed.insert(event.keyCode) }
    }

    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    override func resignFirstResponder() -> Bool {
        keys.removeAll()
        return true
    }

    private func panelItems() -> [String] {
        guard let p = world.player(localID) else { return [] }
        switch panel {
        case .none: return []
        case .inventory: return sortedInventory(p)
        case .shop(let shop): return shopSelling ? sortedInventory(p) : shop.stock.map(\.id)
        }
    }

    private func sortedInventory(_ p: RpgPlayer) -> [String] {
        p.inventory.keys.sorted { a, b in
            let ia = RpgItems.item(a), ib = RpgItems.item(b)
            let ka = ia.map(kindOrder) ?? 9, kb = ib.map(kindOrder) ?? 9
            if ka != kb { return ka < kb }
            if (ia?.rarity ?? 0) != (ib?.rarity ?? 0) { return (ia?.rarity ?? 0) > (ib?.rarity ?? 0) }
            return a < b
        }
    }

    private func kindOrder(_ i: RpgItem) -> Int {
        switch i.kind {
        case .weapon: return 0
        case .armor: return 1
        case .potionHP: return 2
        case .potionMP: return 3
        case .scroll: return 4
        }
    }

    private func handlePanelKey(_ code: UInt16, repeatKey: Bool) {
        let items = panelItems()
        switch code {
        case 53, 34:   // Esc, I
            if !repeatKey { panel = .none; saveNow() }
        case 126, 13: selection = max(0, selection - 1)
        case 125, 1: selection = min(max(0, items.count - 1), selection + 1)
        case 48, 123, 124, 0, 2:
            if case .shop = panel, !repeatKey { shopSelling.toggle(); selection = 0 }
        case 36, 49, 38, 6:   // Enter, Space, J, Z
            guard !repeatKey, items.indices.contains(selection) else { return }
            let id = items[selection]
            switch panel {
            case .inventory: world.perform(.equip(id), for: localID)
            case .shop: world.perform(shopSelling ? .sell(id) : .buy(id), for: localID)
            case .none: break
            }
            selection = min(selection, max(0, panelItems().count - 1))
        default: break
        }
    }

    // MARK: loop

    @objc private func step(_ sender: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTick, 0), 1.0 / 30)
        lastTick = now
        var input = RpgInput()
        if panel == .none {
            input.move = CGVector(dx: (held(124, 2) ? 1 : 0) - (held(123, 0) ? 1 : 0), dy: (held(125, 1) ? 1 : 0) - (held(126, 13) ? 1 : 0))
            input.attack = held(38, 6)
            input.skill1 = tapped(40, 7)
            input.skill2 = tapped(37, 8)
            if tapped(18) { world.perform(.hpPotion, for: localID) }
            if tapped(19) { world.perform(.mpPotion, for: localID) }
            if tapped(20) { world.perform(.scroll, for: localID) }
            if tapped(3, 49) {
                if let shop = world.nearbyShop(for: localID) { panel = .shop(shop); selection = 0; shopSelling = false }
                else { world.perform(.interact, for: localID) }
            }
            if tapped(34, 48) { panel = .inventory; selection = 0 }
            if tapped(53) { saveNow(); onExit?() }
        }
        pressed.removeAll()
        world.step(dt, inputs: [localID: input])
        saveClock += dt
        if saveClock > 10 { saveClock = 0; saveNow() }
        needsDisplay = true
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let me = world.player(localID) else { return }
        scale = max(2, (bounds.height / 240).rounded())
        let vw = Int((bounds.width / scale).rounded(.up)), vh = Int((bounds.height / scale).rounded(.up))
        if frameContext?.width != vw || frameContext?.height != vh {
            frameContext = KartArt.context(width: vw, height: vh)
            darkContext = KartArt.context(width: vw, height: vh)
        }
        guard let f = frameContext else { return }
        let map = world.map(me.map)
        let size = map.pixelSize
        func center(_ v: CGFloat, view: Int, size: CGFloat) -> CGFloat {
            CGFloat(view) >= size ? size / 2 : min(max(v, CGFloat(view) / 2), size - CGFloat(view) / 2)
        }
        origin = CGPoint(x: (center(me.pos.x, view: vw, size: size.width) - CGFloat(vw) / 2).rounded(),
                         y: (center(me.pos.y - 6, view: vh, size: size.height) - CGFloat(vh) / 2).rounded())
        let t = world.time

        KartArt.fill(f, KartArt.rgb(20, 18, 26), 0, 0, CGFloat(vw), CGFloat(vh))
        f.saveGState()
        f.translateBy(x: -origin.x, y: -origin.y)
        if mapImages[me.map] == nil { mapImages[me.map] = RpgArt.renderMap(map) }
        if let img = mapImages[me.map] { KartArt.draw(img, in: f, rect: CGRect(origin: .zero, size: size)) }

        for portal in map.def.portals {
            let p = RpgMap.center(portal.at)
            if portal.hidden {
                let d = hypot(p.x - me.pos.x, p.y - me.pos.y)
                guard d < 56 else { continue }
                f.setAlpha(max(0.15, 1 - d / 56))
            }
            RpgArt.portal(f, at: CGPoint(x: p.x, y: p.y + 4), time: t, locked: me.level < portal.minLevel)
            f.setAlpha(1)
        }
        for torch in map.torches {
            let p = RpgMap.center(torch)
            let flick = Int(t * 10 + Double(torch.x)) % 3
            KartArt.fill(f, KartArt.rgb(255, 200, 60), p.x - 1, p.y - 7 - CGFloat(flick % 2), 3, 3)
            KartArt.fill(f, KartArt.rgb(255, 250, 200), p.x, p.y - 6, 1, 1)
        }
        for d in world.drops where d.map == me.map {
            if d.gold > 0 { RpgArt.coin(f, at: d.pos, time: t) }
            if let id = d.item, let item = RpgItems.item(id), let icon = RpgArt.icon(item) {
                let bob = CGFloat((sin(t * 4 + Double(d.id)) * 1.5).rounded())
                if item.rarity >= 2 {
                    let c = RpgArt.elem(item.element == .base ? .holy : item.element).mid
                    f.setFillColor(c.copy(alpha: 0.35) ?? c)
                    f.fillEllipse(in: CGRect(x: d.pos.x - 9, y: d.pos.y - 14 + bob, width: 18, height: 18))
                }
                KartArt.draw(icon, in: f, rect: CGRect(x: d.pos.x - 9, y: d.pos.y - 14 + bob, width: 18, height: 18))
            }
        }

        // Units sorted by feet so nearer ones overlap farther ones.
        enum Drawable { case player(RpgPlayer), mob(RpgMob), npc(RpgBuilding) }
        var items: [(y: CGFloat, d: Drawable)] = []
        for p in world.players where p.map == me.map { items.append((p.pos.y, .player(p))) }
        for m in world.mobs[me.map] ?? [] where !m.dead || t - m.diedAt < 0.4 { items.append((m.pos.y, .mob(m))) }
        if me.map == .town { for b in map.buildings { items.append((b.door.y, .npc(b))) } }
        for item in items.sorted(by: { $0.y < $1.y }) {
            switch item.d {
            case .player(let p): drawPlayer(p, in: f)
            case .mob(let m): drawMob(m, in: f)
            case .npc(let b): drawNPC(b, in: f)
            }
        }
        drawShots(f)
        drawEffects(f, map: me.map)
        f.restoreGState()

        if map.def.kind == .cave || map.def.kind == .boss { drawDarkness(f, map: map, me: me, vw: vw, vh: vh) }

        if let frame = f.makeImage() {
            ctx.interpolationQuality = .none
            let s = world.shake
            let jx = s > 0 ? CGFloat(Int.random(in: -1...1)) * CGFloat(s) * 2 : 0
            let jy = s > 0 ? CGFloat(Int.random(in: -1...1)) * CGFloat(s) * 2 : 0
            KartArt.draw(frame, in: ctx, rect: CGRect(x: jx, y: jy, width: CGFloat(vw) * scale, height: CGFloat(vh) * scale))
        }
        drawWorldText(me)
        drawHUD(ctx, me)
        switch panel {
        case .none: break
        case .inventory: drawInventory(ctx, me)
        case .shop(let shop): drawShop(ctx, me, shop)
        }
    }

    private func drawPlayer(_ p: RpgPlayer, in f: CGContext) {
        let tint = RpgArt.classTint(p.cls, weapon: p.weaponItem)
        guard let img = RpgArt.sprite(p.cls.rawValue, tint: tint) else { return }
        let bob: CGFloat = p.moving && Int(world.time * 8) % 2 == 0 ? 1 : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: p.pos.x - 6, y: p.pos.y - 2, width: 12, height: 4))
        if p.dead { f.setAlpha(0.35) } else if p.invulnerable > 0, Int(world.time * 20) % 2 == 0 { f.setAlpha(0.45) }
        KartArt.draw(img, in: f, rect: CGRect(x: (p.pos.x - 8).rounded(), y: (p.pos.y - 15 - bob).rounded(), width: 16, height: 16), flipX: !p.facingRight)
        f.setAlpha(1)
    }

    private static let mobSprite: [String: String] = [
        "slime": "slime", "blueslime": "blueslime", "brownshroom": "brownshroom", "poisonshroom": "mushroom", "wolf": "wolf",
        "bat": "bat", "cavebat": "cavebat", "skeleton": "skeleton", "skelarcher": "skelarcher", "golem": "golem",
        "goldslime": "goldslime", "slimeking": "slimeking",
    ]

    private func drawMob(_ m: RpgMob, in f: CGContext) {
        guard let key = Self.mobSprite[m.def.id], let img = RpgArt.sprite(key) else { return }
        let t = world.time
        let boss = m.def.behavior == .boss
        let w = CGFloat(img.width), h = CGFloat(img.height)
        var feet = m.pos
        var lift: CGFloat = 0
        if boss, m.airborne, let jt = m.jumpTarget {
            feet = jt
            lift = CGFloat(max(0, min(1, (m.phaseUntil - t) / 1.0))) * 90
        }
        let hop: CGFloat = (m.def.id.contains("slime") && !boss) ? CGFloat(abs(sin(t * 6 + Double(m.id))) * 2).rounded() : 0
        let fly: CGFloat = m.flies ? CGFloat(6 + sin(t * 8 + Double(m.id)) * 2).rounded() : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: feet.x - w * 0.35, y: feet.y - 2, width: w * 0.7, height: boss ? 8 : 4))
        if m.dead { f.setAlpha(CGFloat(max(0, 1 - (t - m.diedAt) / 0.4))) }
        if m.hurtFlash > 0 { f.setAlpha(0.5) }
        let flip = m.def.id == "wolf" ? m.facingRight : !m.facingRight
        let rect = CGRect(x: (feet.x - w / 2).rounded(), y: (feet.y - h + 1 - hop - fly - lift).rounded(), width: w, height: h)
        KartArt.draw(img, in: f, rect: rect, flipX: flip && !m.def.id.contains("slime") && !m.def.id.contains("bat"))
        f.setAlpha(1)
        if m.windup != nil { KartArt.fill(f, KartArt.rgb(255, 80, 80), feet.x - 1, rect.minY - 5, 2, 3) }
        if t < m.stunUntil {
            for k in 0..<3 {
                let a = t * 6 + Double(k) * 2.1
                KartArt.fill(f, KartArt.rgb(255, 240, 100), (feet.x + CGFloat(cos(a) * 6)).rounded(), (rect.minY - 2 + CGFloat(sin(a) * 2)).rounded(), 1, 1)
            }
        }
        if m.burnTicks > 0, Int(t * 10) % 2 == 0 { KartArt.fill(f, KartArt.rgb(255, 130, 40), feet.x - 3 + CGFloat(Int(t * 7) % 6), rect.minY + 4, 1, 2) }
        if t < m.slowUntil { KartArt.fill(f, KartArt.rgb(170, 238, 255), feet.x - 5, feet.y - 1, 10, 1) }
        if !m.dead, !boss, m.hp < Double(m.def.hp) {
            let bw: CGFloat = 14, x = (feet.x - bw / 2).rounded(), y = rect.minY - 4
            KartArt.fill(f, KartArt.rgb(20, 20, 24), x - 1, y - 1, bw + 2, 4)
            KartArt.fill(f, KartArt.rgb(240, 70, 70), x, y, (bw * CGFloat(max(0, m.hp) / Double(m.def.hp))).rounded(), 2)
        }
    }

    private func drawNPC(_ b: RpgBuilding, in f: CGContext) {
        let hair: CGColor = switch b.shop {
        case .weapon: KartArt.rgb(60, 60, 70)
        case .armor: KartArt.rgb(170, 60, 40)
        case .potion: KartArt.rgb(230, 200, 90)
        }
        guard let img = RpgArt.sprite("villager", tint: ["H": hair]) else { return }
        let p = b.door
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 2, width: 12, height: 4))
        let bob: CGFloat = Int(world.time * 2) % 2 == 0 ? 0 : 1
        KartArt.draw(img, in: f, rect: CGRect(x: p.x - 8, y: p.y - 15 - bob, width: 16, height: 16))
    }

    private func drawShots(_ f: CGContext) {
        guard let me = world.player(localID) else { return }
        for s in world.shots where s.map == me.map {
            let speed = max(1, hypot(s.vel.dx, s.vel.dy))
            let ux = Double(s.vel.dx / speed), uy = Double(s.vel.dy / speed)
            let e = RpgArt.elem(s.element)
            let x = Double(s.pos.x), y = Double(s.pos.y)
            switch s.kind {
            case .arrow, .bigArrow, .mobArrow:
                let len = s.kind == .bigArrow ? 12.0 : 7.0
                if s.kind != .mobArrow {
                    for k in 1...6 { RpgArt.dot(f, x - ux * (len + Double(k) * 1.6), y - uy * (len + Double(k) * 1.6), (k < 3 ? e.mid : e.edge).copy(alpha: 1 - Double(k) * 0.14) ?? e.mid) }
                }
                RpgArt.line(f, x - ux * len, y - uy * len, x, y, s.kind == .mobArrow ? KartArt.rgb(200, 190, 170) : KartArt.rgb(150, 100, 56))
                RpgArt.dot(f, x + ux, y + uy, s.kind == .mobArrow ? KartArt.rgb(230, 226, 210) : e.core, s.kind == .bigArrow ? 2 : 1)
                if s.kind == .bigArrow { RpgArt.disc(f, x, y, 3, e.mid.copy(alpha: 0.5) ?? e.mid) }
            case .orb:
                for k in 1...5 { RpgArt.dot(f, x - ux * Double(k) * 1.8, y - uy * Double(k) * 1.8, e.mid.copy(alpha: 1 - Double(k) * 0.18) ?? e.mid) }
                RpgArt.disc(f, x, y, 2.6, e.edge); RpgArt.disc(f, x, y, 1.6, e.mid); RpgArt.dot(f, x, y, e.core)
            case .slimeBall:
                RpgArt.disc(f, x, y, 3, KartArt.rgb(46, 140, 80)); RpgArt.disc(f, x - 0.5, y - 0.5, 2, KartArt.rgb(110, 220, 130))
                RpgArt.dot(f, x - 1, y - 1, KartArt.rgb(240, 255, 240))
            }
        }
    }

    private func drawEffects(_ f: CGContext, map: RpgMapID) {
        let t = world.time
        for e in world.fx where e.map == map {
            let progress = max(0, min(0.999, (t - e.start) / e.duration))
            let frame = Int(progress * 6)
            switch e.kind {
            case .slash(let angle, let radius): RpgArt.slash(f, at: e.pos, angle: angle, frame: frame, element: e.element, radius: radius)
            case .burst(let radius): RpgArt.burst(f, at: e.pos, frame: frame, element: e.element, radius: radius)
            case .ice(let radius): RpgArt.iceSpikes(f, at: e.pos, frame: frame, radius: radius)
            case .meteor(let radius): RpgArt.meteor(f, at: e.pos, frame: frame, radius: radius)
            case .chain(let points):
                let el = RpgArt.elem(e.element)
                for k in 0..<(points.count - 1) where frame < 5 {
                    RpgArt.bolt(f, from: points[k], to: points[k + 1], seed: UInt64(frame * 13 + k), el)
                    RpgArt.star(f, Double(points[k + 1].x), Double(points[k + 1].y), 2, el.edge, el.core)
                }
            case .spark(let crit): RpgArt.hitSpark(f, at: e.pos, frame: Int(progress * 4), crit: crit, element: e.element)
            case .levelUp: RpgArt.levelUp(f, at: e.pos, frame: Int(progress * 12) % 6)
            case .telegraph(let radius, _):
                let k = CGFloat(progress)
                f.setFillColor(KartArt.rgb(0, 0, 0, 0.15 + 0.35 * k))
                f.fillEllipse(in: CGRect(x: e.pos.x - radius * k, y: e.pos.y - radius * 0.5 * k, width: radius * 2 * k, height: radius * k))
                RpgArt.ring(f, Double(e.pos.x), Double(e.pos.y), radius, KartArt.rgb(255, 80, 80), squash: 0.5)
            }
        }
    }

    /// Caves are dark: a black veil with soft holes around the player, torches and blasts.
    private func drawDarkness(_ f: CGContext, map: RpgMap, me: RpgPlayer, vw: Int, vh: Int) {
        guard let d = darkContext else { return }
        d.setBlendMode(.normal)
        d.clear(CGRect(x: 0, y: 0, width: vw, height: vh))
        d.setFillColor(KartArt.rgb(8, 6, 14, map.def.kind == .boss ? 0.55 : 0.82))
        d.fill(CGRect(x: 0, y: 0, width: vw, height: vh))
        d.setBlendMode(.destinationOut)
        func light(_ p: CGPoint, _ r: CGFloat) {
            let c = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            for k in stride(from: 1.0, through: 0.35, by: -0.13) {
                d.setFillColor(KartArt.rgb(0, 0, 0, 0.22))
                d.fillEllipse(in: CGRect(x: c.x - r * k, y: c.y - r * k * 0.8, width: r * 2 * k, height: r * 1.6 * k))
            }
        }
        let flicker = CGFloat(sin(world.time * 9) * 2)
        light(CGPoint(x: me.pos.x, y: me.pos.y - 6), 62)
        for t in map.torches { light(RpgMap.center(t), 40 + flicker) }
        for e in world.fx where e.map == me.map { light(e.pos, 36) }
        for s in world.shots where s.map == me.map && s.fromPlayer { light(s.pos, 18) }
        for p in map.def.portals where !p.hidden { light(RpgMap.center(p.at), 26) }
        d.setBlendMode(.normal)
        if let veil = d.makeImage() { KartArt.draw(veil, in: f, rect: CGRect(x: 0, y: 0, width: vw, height: vh)) }
    }

    // MARK: HUD

    private func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) * scale, y: (p.y - origin.y) * scale) }

    private func text(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor = .white, weight: NSFont.Weight = .heavy,
                      align: NSTextAlignment = .left, mono: Bool = false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .shadow: shadow])
        let w = str.size().width
        let x = align == .center ? p.x - w / 2 : (align == .right ? p.x - w : p.x)
        str.draw(at: NSPoint(x: x, y: p.y))
    }

    private func panelRect(_ ctx: CGContext, _ rect: CGRect, alpha: CGFloat = 0.55) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
    }

    private func bar(_ ctx: CGContext, _ rect: CGRect, _ frac: Double, _ color: NSColor, label: String? = nil) {
        ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
        ctx.fill(rect)
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(max(0, min(1, frac))), height: rect.height))
        if let label { text(label, at: CGPoint(x: rect.midX, y: rect.minY - 2), size: 10, weight: .bold, align: .center, mono: true) }
    }

    private func drawWorldText(_ me: RpgPlayer) {
        let map = world.map(me.map)
        if me.map == .town {
            for b in map.buildings {
                let s = screen(CGPoint(x: b.door.x, y: b.door.y - 22))
                text(b.shop.title, at: CGPoint(x: s.x, y: s.y - 12), size: 12, color: NSColor(red: 1, green: 0.92, blue: 0.6, alpha: 1), weight: .bold, align: .center)
            }
        }
        for portal in map.def.portals where !portal.hidden || hypot(RpgMap.center(portal.at).x - me.pos.x, RpgMap.center(portal.at).y - me.pos.y) < 40 {
            let def = RpgMaps.def(portal.to)
            let s = screen(CGPoint(x: RpgMap.center(portal.at).x, y: RpgMap.center(portal.at).y - 20))
            let locked = me.level < portal.minLevel
            text("\(def.name) \(def.levelText)", at: CGPoint(x: s.x, y: s.y - 14), size: 11,
                 color: locked ? NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1) : NSColor(red: 0.7, green: 0.85, blue: 1, alpha: 1),
                 weight: .bold, align: .center)
        }
        for m in world.mobs[me.map] ?? [] where m.def.behavior == .boss && !m.dead { _ = m }
        for fl in world.floaters where fl.map == me.map {
            let s = screen(fl.pos)
            let a = CGFloat(min(1, fl.life / 0.3))
            let (color, size): (NSColor, CGFloat) = switch fl.style {
            case .damage: (.white, 13)
            case .crit: (NSColor(red: 1, green: 0.75, blue: 0.2, alpha: 1), 17)
            case .hurt: (NSColor(red: 1, green: 0.35, blue: 0.35, alpha: 1), 14)
            case .heal: (NSColor(red: 0.45, green: 1, blue: 0.5, alpha: 1), 13)
            case .gold: (NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), 12)
            case .xp: (NSColor(red: 0.7, green: 0.6, blue: 1, alpha: 1), 11)
            case .info: (.white, 12)
            }
            text(fl.text, at: s, size: size, color: color.withAlphaComponent(a), align: .center)
        }
    }

    private func drawHUD(_ ctx: CGContext, _ me: RpgPlayer) {
        // Status.
        let box = CGRect(x: 10, y: 10, width: 262, height: 96)
        panelRect(ctx, box)
        text("\(me.name)  ·  \(me.cls.name) Lv\(me.level)", at: CGPoint(x: 20, y: 14), size: 14)
        bar(ctx, CGRect(x: 20, y: 40, width: 240, height: 12), me.hp / me.maxHP, NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1),
            label: "\(Int(me.hp)) / \(Int(me.maxHP))")
        bar(ctx, CGRect(x: 20, y: 58, width: 240, height: 10), me.mp / me.maxMP, NSColor(red: 0.3, green: 0.55, blue: 1, alpha: 1),
            label: "\(Int(me.mp)) / \(Int(me.maxMP))")
        let need = RpgMaps.xpNeeded(me.level)
        bar(ctx, CGRect(x: 20, y: 74, width: 150, height: 6), me.level >= RpgMaps.maxLevel ? 1 : Double(me.xp) / Double(need),
            NSColor(red: 0.65, green: 0.5, blue: 1, alpha: 1))
        text("\(me.gold) G", at: CGPoint(x: 260, y: 80), size: 13, color: NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), align: .right, mono: true)
        text("XP \(me.xp)/\(need)", at: CGPoint(x: 20, y: 82), size: 9, color: NSColor(white: 0.8, alpha: 1), weight: .semibold, mono: true)

        // Map name.
        let def = world.map(me.map).def
        panelRect(ctx, CGRect(x: bounds.width - 190, y: 10, width: 180, height: 42))
        text(def.name, at: CGPoint(x: bounds.width - 100, y: 12), size: 15, align: .center)
        text(def.levelText, at: CGPoint(x: bounds.width - 100, y: 32), size: 10, color: NSColor(white: 0.8, alpha: 1), weight: .semibold, align: .center)

        // Boss bar.
        if let boss = (world.mobs[me.map] ?? []).first(where: { $0.def.behavior == .boss && !$0.dead }) {
            let w = min(520, bounds.width - 300)
            let r = CGRect(x: bounds.midX - w / 2, y: 64, width: w, height: 14)
            text(boss.def.name, at: CGPoint(x: bounds.midX, y: 44), size: 14, color: NSColor(red: 1, green: 0.6, blue: 0.5, alpha: 1), align: .center)
            bar(ctx, r, boss.hp / Double(boss.def.hp), NSColor(red: 0.85, green: 0.25, blue: 0.3, alpha: 1))
        }

        // Toasts.
        for (k, toast) in world.toasts.enumerated() {
            text(toast.text, at: CGPoint(x: bounds.midX, y: 92 + CGFloat(k) * 20), size: 14,
                 color: NSColor(red: 1, green: 0.95, blue: 0.75, alpha: 1), align: .center)
        }

        // Interaction hint.
        if let shop = world.nearbyShop(for: localID) {
            hint("F  \(shop.title) 들어가기")
        } else if let portal = world.nearbyPortal(for: localID) {
            let d = RpgMaps.def(portal.to)
            hint(me.level < portal.minLevel ? "Lv\(portal.minLevel) 이상만 들어갈 수 있어요" : "F  \(d.name)(으)로 이동")
        }

        drawHotbar(ctx, me)
        text("이동 WASD·방향키   공격 J   스킬 K L   물약 1 2   귀환 3   상호작용 F   가방 I   나가기 Esc",
             at: CGPoint(x: bounds.midX, y: bounds.height - 16), size: 10, color: NSColor(white: 1, alpha: 0.6), weight: .semibold, align: .center)

        if me.dead {
            panelRect(ctx, CGRect(x: bounds.midX - 160, y: bounds.midY - 40, width: 320, height: 64), alpha: 0.7)
            text("쓰러졌다…", at: CGPoint(x: bounds.midX, y: bounds.midY - 36), size: 22, align: .center)
            text("잠시 후 마을에서 부활합니다", at: CGPoint(x: bounds.midX, y: bounds.midY - 6), size: 13,
                 color: NSColor(white: 0.85, alpha: 1), align: .center)
        }
    }

    private func hint(_ s: String) {
        let me = world.player(localID)
        let p = screen(CGPoint(x: me?.pos.x ?? 0, y: (me?.pos.y ?? 0) + 6))
        text(s, at: CGPoint(x: p.x, y: p.y + 4), size: 13, color: NSColor(red: 1, green: 0.95, blue: 0.6, alpha: 1), align: .center)
    }

    private func drawHotbar(_ ctx: CGContext, _ me: RpgPlayer) {
        let size: CGFloat = 54, gap: CGFloat = 6
        struct Slot { let key: String; let title: String; let icon: CGImage?; let cooldown: Double; let total: Double; let count: Int? ; let dim: Bool }
        let potionCount = (me.inventory["hp0"] ?? 0) + (me.inventory["hp1"] ?? 0)
        let slots: [Slot] = [
            Slot(key: "J", title: "공격", icon: me.weaponItem.flatMap(RpgArt.icon), cooldown: me.attackTimer, total: me.attackInterval, count: nil, dim: false),
            Slot(key: "K", title: me.cls.skillNames[0], icon: nil, cooldown: me.skillTimers[0], total: me.cls.skillCooldown[0], count: nil,
                 dim: me.mp < Double(me.cls.skillCost[0])),
            Slot(key: "L", title: me.cls.skillNames[1], icon: nil, cooldown: me.skillTimers[1], total: me.cls.skillCooldown[1], count: nil,
                 dim: me.mp < Double(me.cls.skillCost[1])),
            Slot(key: "1", title: "HP", icon: RpgItems.item("hp0").flatMap(RpgArt.icon), cooldown: 0, total: 1, count: potionCount, dim: potionCount == 0),
            Slot(key: "2", title: "MP", icon: RpgItems.item("mp0").flatMap(RpgArt.icon), cooldown: 0, total: 1, count: me.inventory["mp0"] ?? 0,
                 dim: (me.inventory["mp0"] ?? 0) == 0),
            Slot(key: "3", title: "귀환", icon: RpgItems.item("scroll").flatMap(RpgArt.icon), cooldown: 0, total: 1, count: me.inventory["scroll"] ?? 0,
                 dim: (me.inventory["scroll"] ?? 0) == 0),
        ]
        let total = CGFloat(slots.count) * size + CGFloat(slots.count - 1) * gap
        let y = bounds.height - size - 34
        for (k, s) in slots.enumerated() {
            let x = bounds.midX - total / 2 + CGFloat(k) * (size + gap)
            let r = CGRect(x: x, y: y, width: size, height: size)
            panelRect(ctx, r, alpha: 0.65)
            if k == 1 || k == 2 {
                let el = RpgArt.elem(me.element)
                ctx.setFillColor(el.mid)
                ctx.fill(CGRect(x: x + 4, y: y + size - 7, width: size - 8, height: 3))
                text(s.title, at: CGPoint(x: x + size / 2, y: y + 20), size: 10, weight: .bold, align: .center)
                text("MP \(me.cls.skillCost[k - 1])", at: CGPoint(x: x + size / 2, y: y + 34), size: 9,
                     color: NSColor(red: 0.6, green: 0.75, blue: 1, alpha: 1), weight: .semibold, align: .center)
            } else if let icon = s.icon {
                ctx.interpolationQuality = .none
                KartArt.draw(icon, in: ctx, rect: CGRect(x: x + 9, y: y + 9, width: 36, height: 36))
            }
            text(s.key, at: CGPoint(x: x + 4, y: y + 2), size: 12)
            if let c = s.count { text("\(c)", at: CGPoint(x: x + size - 4, y: y + size - 18), size: 12, align: .right, mono: true) }
            if s.dim { ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor); ctx.fill(r) }
            if s.cooldown > 0 {
                let frac = CGFloat(s.cooldown / s.total)
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
                ctx.fill(CGRect(x: x, y: y + size * (1 - frac), width: size, height: size * frac))
                if s.total > 1 { text(String(format: "%.0f", s.cooldown.rounded(.up)), at: CGPoint(x: x + size / 2, y: y + 16), size: 18, align: .center) }
            }
        }
    }

    // MARK: panels

    private func itemLine(_ item: RpgItem) -> String {
        var parts: [String] = []
        if item.attack > 0 { parts.append("공격력 +\(item.attack)") }
        if item.defense > 0 { parts.append("방어력 +\(item.defense)") }
        if item.heal > 0 { parts.append(item.kind == .potionMP ? "MP +\(item.heal)" : "HP +\(item.heal)") }
        if item.kind == .scroll { parts.append("마을로 즉시 귀환") }
        if item.element != .base { parts.append(item.element.effectName) }
        if case .weapon(let cls) = item.kind { parts.append("\(cls.name) 전용") }
        return parts.joined(separator: " · ")
    }

    private func drawList(_ ctx: CGContext, _ ids: [String], in rect: CGRect, price: (RpgItem) -> String?, owned: (String) -> Int?, me: RpgPlayer) {
        let rowH: CGFloat = 46
        let visible = max(1, Int((rect.height - 10) / rowH))
        let first = max(0, min(selection - visible / 2, ids.count - visible))
        for (row, id) in ids.enumerated().dropFirst(first).prefix(visible) {
            guard let item = RpgItems.item(id) else { continue }
            let y = rect.minY + 6 + CGFloat(row - first) * rowH
            let r = CGRect(x: rect.minX + 6, y: y, width: rect.width - 12, height: rowH - 4)
            if row == selection {
                ctx.setFillColor(NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.18).cgColor)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil))
                ctx.fillPath()
            }
            if let icon = RpgArt.icon(item) {
                ctx.interpolationQuality = .none
                KartArt.draw(icon, in: ctx, rect: CGRect(x: r.minX + 4, y: r.minY + 3, width: 36, height: 36))
            }
            let equipped = id == me.weapon || id == me.armor
            text(item.name + (equipped ? "  [장착 중]" : ""), at: CGPoint(x: r.minX + 48, y: r.minY + 4), size: 13,
                 color: RpgArt.rarityColors[item.rarity], weight: .bold)
            text(itemLine(item), at: CGPoint(x: r.minX + 48, y: r.minY + 22), size: 10, color: NSColor(white: 0.78, alpha: 1), weight: .semibold)
            if let p = price(item) { text(p, at: CGPoint(x: r.maxX - 8, y: r.minY + 4), size: 13, color: NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), align: .right, mono: true) }
            if let c = owned(id) { text("×\(c)", at: CGPoint(x: r.maxX - 8, y: r.minY + 22), size: 11, align: .right, mono: true) }
        }
        if ids.isEmpty { text("비어 있어요", at: CGPoint(x: rect.midX, y: rect.minY + 20), size: 13, color: NSColor(white: 0.7, alpha: 1), align: .center) }
    }

    private func drawInventory(_ ctx: CGContext, _ me: RpgPlayer) {
        let w = min(640, bounds.width - 40), h = min(480, bounds.height - 120)
        let r = CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2 - 20, width: w, height: h)
        panelRect(ctx, r, alpha: 0.85)
        text("가방", at: CGPoint(x: r.minX + 16, y: r.minY + 10), size: 18)
        text("↑↓ 선택   Enter 장착/사용   Esc 닫기", at: CGPoint(x: r.maxX - 16, y: r.minY + 14), size: 11,
             color: NSColor(white: 0.75, alpha: 1), weight: .semibold, align: .right)
        let listRect = CGRect(x: r.minX + 8, y: r.minY + 40, width: w * 0.62, height: h - 48)
        drawList(ctx, panelItems(), in: listRect, price: { _ in nil }, owned: { me.inventory[$0] }, me: me)
        // Character sheet.
        let sx = r.minX + w * 0.64 + 10, sy = r.minY + 46
        let lines: [(String, String)] = [
            ("직업", me.cls.name), ("레벨", "\(me.level)"), ("HP", "\(Int(me.hp)) / \(Int(me.maxHP))"), ("MP", "\(Int(me.mp)) / \(Int(me.maxMP))"),
            ("공격력", "\(Int(me.attack))"), ("방어력", "\(Int(me.defense))"),
            ("속성", me.element == .base ? "없음" : me.element.effectName), ("무기", me.weaponItem?.name ?? "-"),
            ("갑옷", me.armorItem?.name ?? "-"), ("골드", "\(me.gold) G"),
        ]
        for (k, line) in lines.enumerated() {
            text(line.0, at: CGPoint(x: sx, y: sy + CGFloat(k) * 24), size: 12, color: NSColor(white: 0.7, alpha: 1), weight: .semibold)
            text(line.1, at: CGPoint(x: r.maxX - 16, y: sy + CGFloat(k) * 24), size: 13, align: .right)
        }
    }

    private func drawShop(_ ctx: CGContext, _ me: RpgPlayer, _ shop: RpgShop) {
        let w = min(640, bounds.width - 40), h = min(480, bounds.height - 120)
        let r = CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2 - 20, width: w, height: h)
        panelRect(ctx, r, alpha: 0.88)
        text(shop.title, at: CGPoint(x: r.minX + 16, y: r.minY + 10), size: 18)
        let tabs = ["사기", "팔기"]
        for (k, tab) in tabs.enumerated() {
            let active = (k == 1) == shopSelling
            text(tab, at: CGPoint(x: r.minX + 120 + CGFloat(k) * 60, y: r.minY + 13), size: 14,
                 color: active ? NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : NSColor(white: 0.55, alpha: 1))
        }
        text("\(me.gold) G", at: CGPoint(x: r.maxX - 16, y: r.minY + 12), size: 15, color: NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), align: .right, mono: true)
        let listRect = CGRect(x: r.minX + 8, y: r.minY + 40, width: w - 16, height: h - 70)
        if shopSelling {
            drawList(ctx, panelItems(), in: listRect, price: { "+\($0.sellPrice) G" }, owned: { me.inventory[$0] }, me: me)
        } else {
            drawList(ctx, panelItems(), in: listRect, price: { "\($0.price) G" }, owned: { me.inventory[$0] }, me: me)
        }
        text("↑↓ 선택   ←→ / Tab 사기·팔기   Enter 거래   Esc 나가기", at: CGPoint(x: r.midX, y: r.maxY - 24), size: 11,
             color: NSColor(white: 0.75, alpha: 1), weight: .semibold, align: .center)
    }
}

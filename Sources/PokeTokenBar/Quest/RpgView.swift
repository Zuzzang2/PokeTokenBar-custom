import AppKit
import QuartzCore

// SPIKE: draws and drives `RpgWorld` for the local player. Low-res pixel frame (map, units, effects,
// darkness with torch light) scaled up with nearest-neighbour, then a crisp HUD: status, buffs, quest
// tracker, an eight-slot skill bar, toasts, damage numbers and the keyboard-driven windows (bag, shops,
// forge, quest board, skills, key settings, 차원문). Arrow keys move; every other key is rebindable.

@MainActor
final class RpgView: NSView, NSTextFieldDelegate {
    var onExit: (() -> Void)?
    var onSave: ((RpgSaveData) -> Void)?
    weak var driver: RpgDriver?
    private var chatField: NSTextField?

    enum Panel: Equatable { case none, inventory, shop(RpgShop), smith, board, skills, keys, waypoint, quests, party, job, codex, trade, equipment }

    let world: RpgWorld
    let localID: Int
    var bindings = RpgKeyBindings.load()
    private var keys = Set<UInt16>()
    private var pressed = Set<UInt16>()
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var frameContext: CGContext?
    private var darkContext: CGContext?
    private var mapImages: [RpgMapID: CGImage] = [:]
    private var origin = CGPoint.zero
    private var scale: CGFloat = 3
    var panel = Panel.none
    private static let codexMonsters = RpgMonsters.all.sorted { $0.level < $1.level }
    private var showMinimap = UserDefaults.standard.object(forKey: "rpgMinimap") as? Bool ?? true
    var selection = 0
    var tab = 0
    private var waitingKey = false
    private var saveClock = 0.0
    private var fallenAt: CFTimeInterval?

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

    // MARK: actions and chat

    func act(_ action: RpgAction) {
        if let driver { driver.send(action) } else { world.perform(action, for: localID) }
    }

    /// Return opens a text field (a real one, so Korean input composes properly); Return sends, Esc cancels.
    private func openChat() {
        guard chatField == nil else { return }
        let field = NSTextField(frame: NSRect(x: 16, y: bounds.height - 150, width: min(460, bounds.width - 32), height: 26))
        field.placeholderString = "채팅 입력 후 Enter (Esc 취소)"
        field.font = .systemFont(ofSize: 14, weight: .semibold)
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.delegate = self
        field.autoresizingMask = [.maxXMargin, .minYMargin]
        addSubview(field)
        window?.makeFirstResponder(field)
        chatField = field
        keys.removeAll()
    }

    private func closeChat() {
        chatField?.removeFromSuperview()
        chatField = nil
        window?.makeFirstResponder(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            let text = chatField?.stringValue ?? ""
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                if let driver { driver.chat(text) } else { world.say(localID, text) }
            }
            closeChat()
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            closeChat()
            return true
        }
        return false
    }

    // MARK: input

    private func held(_ codes: UInt16...) -> Bool { codes.contains { keys.contains($0) } }
    private func tapped(_ a: RpgKeyAction) -> Bool { pressed.contains(bindings.code(a)) }

    override func keyDown(with event: NSEvent) {
        let code = event.keyCode
        if panel != .none {
            handlePanelKey(code, repeatKey: event.isARepeat)
            return
        }
        keys.insert(code)
        if !event.isARepeat { pressed.insert(code) }
    }

    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    override func resignFirstResponder() -> Bool {
        keys.removeAll()
        return true
    }

    func open(_ p: Panel) {
        panel = p
        selection = 0
        tab = 0
        waitingKey = false
        keys.removeAll()
    }

    func close() {
        panel = .none
        waitingKey = false
        saveNow()
    }

    var me: RpgPlayer? { world.player(localID) }

    private func panelCount() -> Int {
        guard let p = me else { return 0 }
        switch panel {
        case .none: return 0
        case .inventory: return bagList(p).count
        case .equipment: return RpgEquipSlot.allCases.count
        case .shop(let s): return tab == 0 ? stock(s, p).count : sortedInventory(p).count
        case .smith: return tab == 0 ? 2 : RpgRecipes.all.count
        case .job: return me?.job == 0 ? 2 : 1
        case .board: return tab == 0 ? world.boardOffers(for: localID).count : p.quests.count
        case .skills: return tab == 4 ? RpgStats.names.count : skillRows(p, tab: tab).count
        case .keys: return RpgKeyAction.allCases.count
        case .waypoint: return tab == 0 ? waypoints(p).count : RpgRegions.all.count
        case .quests: return p.quests.count
        case .codex: return tab == 0 ? Self.codexMonsters.count : RpgAchievements.all.count
        case .trade: return world.tradeView(for: localID) != nil ? tradeBag(p).count : tradeRows(p).count
        case .party: return tab == 0 ? partyRows(p).count : inviteCandidates(p).count
        }
    }

    private func stock(_ s: RpgShop, _ p: RpgPlayer) -> [RpgItem] {
        s == .skill ? s.stock.filter { if case .book(let id) = $0.kind { return RpgSkills.def(id)?.cls == p.cls }; return false } : s.stock
    }

    private func waypoints(_ p: RpgPlayer) -> [RpgMapID] { RpgMaps.waypoints.filter { p.visited.contains($0) } }

    /// Party tab rows: a pending invite first (-1), then the members (me included).
    private func partyRows(_ p: RpgPlayer) -> [Int] {
        let members = p.partyID == nil ? [p.id] : world.players.filter { $0.partyID == p.partyID }.map(\.id)
        return (p.inviteFrom != nil ? [-1] : []) + members
    }

    private func inviteCandidates(_ p: RpgPlayer) -> [RpgPlayer] {
        world.players.filter { $0.id != p.id && ($0.partyID == nil || $0.partyID != p.partyID) }
    }

    private func handlePanelKey(_ code: UInt16, repeatKey: Bool) {
        guard let p = me else { return }
        if waitingKey {
            if code == 53 { waitingKey = false; return }
            guard !RpgKeyBindings.reserved.contains(code) else { return }
            let action = RpgKeyAction.allCases[selection]
            bindings.bind(action, to: code)
            bindings.save()
            waitingKey = false
            world.toast("\(action.title) → \(RpgKeyBindings.name(code))")
            return
        }
        // The key that opened a window also closes it.
        let toggles: [(Panel, RpgKeyAction)] = [(.inventory, .inventory), (.equipment, .equipment), (.skills, .skills), (.keys, .keys), (.quests, .quests), (.party, .party), (.codex, .codex), (.trade, .trade)]
        if !repeatKey, toggles.contains(where: { $0.0 == panel && bindings.code($0.1) == code }) { close(); return }
        if handleWindowKey(code, repeatKey: repeatKey, p) { return }
        if panel == .skills, tab == 0, !repeatKey, let slot = bindings.actions(for: code).compactMap(\.slotIndex).first {
            let skill = p.skillList[min(selection, p.skillList.count - 1)]
            if p.skills[skill.id] != nil {
                act(.assign(slot: slot, skill: skill.id))
                world.toast("\(skill.name) → 슬롯 \(bindings.label(.slot(slot)))")
            } else {
                world.toast("아직 배우지 않은 스킬이에요")
            }
            return
        }
        if panel == .trade, handleTradeKey(code, repeatKey: repeatKey, p) { return }
        let count = panelCount()
        switch code {
        case 53: if !repeatKey { close() }
        case 126: selection = max(0, selection - 1)
        case 125: selection = min(max(0, count - 1), selection + 1)
        case 123, 124, 48:
            if !repeatKey { tab = tab == 0 ? 1 : 0; selection = 0 }
        case 36:
            guard !repeatKey else { return }
            confirm(p)
        case 51:
            guard !repeatKey else { return }
            switch panel {
            case .trade:
                let rows = tradeRows(p)
                if rows.indices.contains(selection), rows[selection] == -1 { act(.tradeDecline) }
            case .party where tab == 0:
                let rows = partyRows(p)
                if rows.indices.contains(selection) {
                    if rows[selection] == -1 { act(.declineInvite) } else { act(.leaveParty) }
                }
            case .board where tab == 1, .quests:
                if p.quests.indices.contains(selection) { act(.abandonQuest(p.quests[selection].id)); world.toast("의뢰 포기") }
            case .skills where tab == 1:
                act(.resetStats)
            case .skills:
                let skill = p.skillList[min(selection, p.skillList.count - 1)]
                if let slot = p.slots.firstIndex(of: skill.id) { act(.assign(slot: slot, skill: nil)) }
            case .keys:
                bindings = .defaults
                bindings.save()
                world.toast("키 설정을 기본값으로 되돌렸어요")
            default: break
            }
        default: break
        }
        selection = min(selection, max(0, panelCount() - 1))
    }

    private func confirm(_ p: RpgPlayer) {
        switch panel {
        case .inventory:
            let ids = sortedInventory(p)
            if ids.indices.contains(selection) { act(.equip(ids[selection])) }
        case .equipment:
            break
        case .shop(let s):
            if tab == 0 {
                let items = stock(s, p)
                if items.indices.contains(selection) { act(.buy(items[selection].id)) }
            } else {
                let ids = sortedInventory(p)
                if ids.indices.contains(selection) { act(.sell(ids[selection])) }
            }
        case .smith:
            if tab == 0 { act(.enhance(weapon: selection == 0)) }
            else if RpgRecipes.all.indices.contains(selection) { act(.craft(RpgRecipes.all[selection].id)) }
        case .job:
            act(p.job == 0 ? .advance(selection + 1) : .promote)
        case .board:
            if tab == 0 {
                let offers = world.boardOffers(for: localID)
                if offers.indices.contains(selection) { act(.acceptQuest(offers[selection].id)) }
            } else if p.quests.indices.contains(selection) {
                if p.quests[selection].done { act(.claimQuest(p.quests[selection].id)) }
                else { world.toast("아직 다 못 했어요 (\(p.quests[selection].progress)/\(p.quests[selection].count))") }
            }
        case .skills where tab == 1:
            act(.addStat(selection))
        case .skills:
            let skill = p.skillList[min(selection, p.skillList.count - 1)]
            if p.skills[skill.id] != nil { act(.levelSkill(skill.id)) }
            else { world.toast(skill.price > 0 ? "마법서점에서 스킬북을 살 수 있어요" : "몬스터가 떨어뜨리는 스킬북으로 배워요") }
        case .keys:
            waitingKey = true
        case .waypoint where tab == 1:
            if RpgRegions.all.indices.contains(selection) { act(.warp(RpgRegions.all[selection].entry)); close() }
        case .waypoint:
            let list = waypoints(p)
            if list.indices.contains(selection) { act(.warp(list[selection])); close() }
        case .party:
            if tab == 0 {
                let rows = partyRows(p)
                guard rows.indices.contains(selection) else { return }
                if rows[selection] == -1 { act(.acceptInvite) }
                else if rows[selection] != localID {
                    if p.map == .town { act(.warpToMember(rows[selection])); close() } else { world.toast("파티원 곁으로는 마을에서 이동할 수 있어요", to: nil) }
                }
            } else {
                let list = inviteCandidates(p)
                if list.indices.contains(selection) { act(.invite(list[selection].id)) }
            }
        case .trade:
            // An open trade handles its own keys (`handleTradeKey`); here: pick someone, or answer a request.
            let rows = tradeRows(p)
            guard world.tradeView(for: localID) == nil, rows.indices.contains(selection) else { return }
            if rows[selection] == -1 { act(.tradeAccept) } else { act(.tradeRequest(rows[selection])) }
        case .quests, .codex, .none:
            break
        }
    }

    // MARK: loop

    @objc private func step(_ sender: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastTick, 0), 1.0 / 30)
        lastTick = now
        var input = RpgInput()
        if panel == .none {
            input.move = CGVector(dx: (held(124) ? 1 : 0) - (held(123) ? 1 : 0), dy: (held(125) ? 1 : 0) - (held(126) ? 1 : 0))
            input.attack = keys.contains(bindings.code(.attack))
            for s in 0..<RpgWorld.slotCount where tapped(.slot(s)) { input.slots.insert(s) }
            if tapped(.hpPotion) { act(.hpPotion) }
            if tapped(.mpPotion) { act(.mpPotion) }
            if tapped(.scroll) { act(.scroll) }
            if tapped(.interact) {
                if let place = world.nearbyPlace(for: localID) {
                    switch place {
                    case .shop(let s): open(.shop(s))
                    case .smith: open(.smith)
                    case .board: open(.board)
                    case .jobMaster: open(.job)
                    }
                } else if let portal = world.nearbyPortal(for: localID), portal.waypoint {
                    open(.waypoint)
                } else {
                    act(.interact)
                }
            }
            if tapped(.inventory) { open(.inventory) }
            if tapped(.equipment) { open(.equipment) }
            if tapped(.skills) { open(.skills) }
            if tapped(.quests) { open(.quests) }
            if tapped(.codex) { open(.codex) }
            if tapped(.trade) { open(.trade) }
            if tapped(.keys) { open(.keys) }
            if tapped(.minimap) { showMinimap.toggle(); UserDefaults.standard.set(showMinimap, forKey: "rpgMinimap") }
            if tapped(.party) { open(.party) }
            if pressed.contains(53) { saveNow(); onExit?() }
            if pressed.contains(36) { openChat() }
        }
        pressed.removeAll()
        if let d = driver, d.isClient {
            // Client: walk locally right away, tell the host, and let snapshots fill in the rest.
            world.predict(localID, input: input, dt: dt)
            if let me {
                input.pos = me.pos
                input.facing = me.facing
            }
            for slot in input.slots { d.send(.cast(slot)) }
            input.slots = []
            d.sendInput(input)
            world.mirrorTick(dt, localID: localID)
        } else {
            var all = driver?.remoteInputs() ?? [:]
            all[localID] = input
            world.step(dt, inputs: all)
        }
        if me?.fallen == true {
            if fallenAt == nil { fallenAt = now; saveNow() } else if let at = fallenAt, now - at > 6 { fallenAt = nil; onExit?(); return }
        }
        saveClock += dt
        if saveClock > 10 { saveClock = 0; saveNow() }
        needsDisplay = true
    }

    // MARK: world drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let me else { return }
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
            RpgArt.portal(f, at: CGPoint(x: p.x, y: p.y + 4), time: t, locked: me.level < portal.minLevel, waypoint: portal.waypoint)
            f.setAlpha(1)
        }
        for torch in map.torches {
            let p = RpgMap.center(torch)
            let flick = Int(t * 10 + Double(torch.x)) % 3
            KartArt.fill(f, KartArt.rgb(255, 200, 60), p.x - 1, p.y - 7 - CGFloat(flick % 2), 3, 3)
            KartArt.fill(f, KartArt.rgb(255, 250, 200), p.x, p.y - 6, 1, 1)
        }
        for trap in world.traps where trap.map == me.map { trap.turret == true ? RpgArt.turret(f, at: trap.pos, time: t) : RpgArt.trap(f, at: trap.pos, time: t) }
        for g in world.graves where g.map == me.map { RpgArt.grave(f, at: CGPoint(x: g.x, y: g.y)) }
        for d in world.drops where d.map == me.map {
            let reserved = d.owner != nil && d.owner != localID && t - d.at < 30
            if reserved { f.setAlpha(0.35) }
            defer { f.setAlpha(1) }
            if d.gold > 0 { RpgArt.coin(f, at: d.pos, time: t) }
            if let id = d.item, let item = RpgItems.item(id), let icon = RpgArt.icon(item) {
                let bob = CGFloat((sin(t * 4 + Double(d.id)) * 1.5).rounded())
                if item.rarity >= 3 {
                    // A light column so epic and mythic drops are easy to spot from afar.
                    let beam = item.rarity == 4 ? KartArt.rgb(255, 90, 140) : KartArt.rgb(255, 215, 90)
                    let pulse = 0.5 + 0.5 * CGFloat(sin(t * 3 + Double(d.id)))
                    for k in 0..<12 {
                        f.setFillColor(beam.copy(alpha: (0.34 - CGFloat(k) * 0.026) * (0.6 + 0.4 * pulse)) ?? beam)
                        f.fill(CGRect(x: d.pos.x - 2, y: d.pos.y - 16 - CGFloat(k) * 4, width: 4, height: 4))
                    }
                }
                if item.rarity >= 2 {
                    let c = item.rarity == 4 ? KartArt.rgb(255, 90, 140) : RpgArt.elem(item.element == .base ? .holy : item.element).mid
                    f.setFillColor(c.copy(alpha: 0.35) ?? c)
                    f.fillEllipse(in: CGRect(x: d.pos.x - 9, y: d.pos.y - 14 + bob, width: 18, height: 18))
                }
                KartArt.draw(icon, in: f, rect: CGRect(x: d.pos.x - 9, y: d.pos.y - 14 + bob, width: 18, height: 18))
            }
        }

        enum Drawable { case player(RpgPlayer), mob(RpgMob), npc(RpgBuilding), pet(RpgPetState) }
        var items: [(y: CGFloat, d: Drawable)] = []
        for p in world.players where p.map == me.map { items.append((p.pos.y, .player(p))) }
        for m in world.mobs[me.map] ?? [] where !m.dead || t - m.diedAt < 0.4 { items.append((m.pos.y, .mob(m))) }
        for pet in world.pets.values where pet.map == me.map { items.append((pet.pos.y, .pet(pet))) }
        if me.map == .town { for b in map.buildings where b.place != .board { items.append((b.door.y, .npc(b))) } }
        for item in items.sorted(by: { $0.y < $1.y }) {
            switch item.d {
            case .player(let p): drawPlayer(p, in: f)
            case .mob(let m): drawMob(m, in: f)
            case .npc(let b): drawNPC(b, in: f)
            case .pet(let pet): drawPet(pet, in: f)
            }
        }
        drawShots(f, map: me.map)
        drawEffects(f, map: me.map)
        f.restoreGState()

        if map.darkness > 0 { drawDarkness(f, map: map, me: me, vw: vw, vh: vh) }

        if let frame = f.makeImage() {
            ctx.interpolationQuality = .none
            let s = world.shake
            let jx = s > 0 ? CGFloat(Int.random(in: -1...1)) * CGFloat(s) * 2 : 0
            let jy = s > 0 ? CGFloat(Int.random(in: -1...1)) * CGFloat(s) * 2 : 0
            KartArt.draw(frame, in: ctx, rect: CGRect(x: jx, y: jy, width: CGFloat(vw) * scale, height: CGFloat(vh) * scale))
        }
        drawWorldText(me)
        drawHUD(ctx, me)
        drawMinimap(ctx, me)
        drawPanel(ctx, me)
    }

    private func drawPlayer(_ p: RpgPlayer, in f: CGContext) {
        let t = world.time
        let tint = RpgArt.classTint(p.cls, weapon: p.weaponItem).merging(RpgJobs.tint(p.cls, p.job)) { weapon, _ in weapon }
        guard let img = RpgArt.sprite(p.cls.rawValue, tint: tint) else { return }
        let bob: CGFloat = p.moving && Int(t * 8) % 2 == 0 ? 1 : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: p.pos.x - 6, y: p.pos.y - 2, width: 12, height: 4))
        if t < p.rageUntil { RpgArt.aura(f, at: p.pos, time: t, color: KartArt.rgb(255, 90, 60)) }
        if t < p.ironUntil { RpgArt.aura(f, at: p.pos, time: t + 1, color: KartArt.rgb(210, 220, 235)) }
        if t < p.focusUntil { RpgArt.aura(f, at: p.pos, time: t + 2, color: KartArt.rgb(140, 240, 160)) }
        if t < p.shieldUntil {
            f.setStrokeColor(KartArt.rgb(140, 190, 255, 0.8))
            f.strokeEllipse(in: CGRect(x: p.pos.x - 10, y: p.pos.y - 20, width: 20, height: 22))
        }
        if p.dead { f.setAlpha(0.35) } else if t < p.stealthUntil { f.setAlpha(p.id == localID ? 0.5 : 0.25) }
        else if p.invulnerable > 0, Int(t * 20) % 2 == 0 { f.setAlpha(0.45) }
        KartArt.draw(img, in: f, rect: CGRect(x: (p.pos.x - 8).rounded(), y: (p.pos.y - 15 - bob).rounded(), width: 16, height: 16), flipX: !p.facingRight)
        f.setAlpha(1)
        // Glint on a highly enhanced weapon.
        if let w = p.weaponItem, (p.plus[w.id] ?? 0) >= 7, Int(t * 6) % 4 == 0 {
            KartArt.fill(f, KartArt.rgb(255, 255, 255), p.pos.x + (p.facingRight ? 5 : -6), p.pos.y - 14, 1, 1)
        }
    }

    // MARK: pets

    private struct PetArt { var frames: [(image: CGImage, delay: Double)] = [] }
    private var petArt: [String: PetArt] = [:]

    /// The pet's current animation frame; the GIF loads in the background and shrinks to ~15 world pixels.
    private func petFrame(_ pet: RpgPetState) -> CGImage? {
        let key = "\(pet.info.speciesID)-\(pet.info.shiny)"
        guard let art = petArt[key] else {
            petArt[key] = PetArt()
            let id = pet.info.speciesID, shiny = pet.info.shiny
            Task { @MainActor [weak self] in
                var frames = await SpriteLoader.animationFrames(speciesID: id, shiny: shiny).map { ($0.image, $0.delay) }
                if frames.isEmpty, let data = await SpriteStore.shared.data(speciesID: id, animated: false, shiny: shiny),
                   let still = NSImage(data: data) { frames = [(still, 1)] }
                let small = frames.compactMap { f in KartArt.rider(from: f.0, height: 15).map { ($0, max(0.05, f.1)) } }
                self?.petArt[key] = PetArt(frames: small.map { (image: $0.0, delay: $0.1) })
            }
            return nil
        }
        guard !art.frames.isEmpty else { return nil }
        var t = world.time.truncatingRemainder(dividingBy: max(0.1, art.frames.reduce(0) { $0 + $1.delay }))
        for f in art.frames { if t < f.delay { return f.image }; t -= f.delay }
        return art.frames.last?.image
    }

    private func drawPet(_ pet: RpgPetState, in f: CGContext) {
        guard let img = petFrame(pet) else { return }
        let bob: CGFloat = pet.moving && Int(world.time * 10) % 2 == 0 ? 1 : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.25))
        f.fillEllipse(in: CGRect(x: pet.pos.x - 5, y: pet.pos.y - 2, width: 10, height: 3))
        let w = CGFloat(img.width), h = CGFloat(img.height)
        KartArt.draw(img, in: f, rect: CGRect(x: (pet.pos.x - w / 2).rounded(), y: (pet.pos.y - h - bob).rounded(), width: w, height: h),
                     flipX: pet.facingRight)
    }

    private func drawMob(_ m: RpgMob, in f: CGContext) {
        guard let img = RpgArt.sprite(m.def.sprite) else { return }
        let t = world.time
        let boss = m.def.behavior == .boss
        let w = CGFloat(img.width), h = CGFloat(img.height)
        var feet = m.pos
        var lift: CGFloat = 0
        if boss, m.airborne, let jt = m.jumpTarget {
            feet = jt
            lift = CGFloat(max(0, min(1, (m.phaseUntil - t) / 1.0))) * 90
        }
        let slime = m.def.sprite.contains("slime")
        let hop: CGFloat = (slime && !boss) ? CGFloat(abs(sin(t * 6 + Double(m.id))) * 2).rounded() : 0
        let fly: CGFloat = m.flies ? CGFloat(6 + sin(t * 8 + Double(m.id)) * 2).rounded() : 0
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: feet.x - w * 0.35, y: feet.y - 2, width: w * 0.7, height: boss ? 8 : 4))
        if m.elite, !m.dead {
            f.setFillColor(KartArt.rgb(255, 215, 80, 0.30 + 0.12 * CGFloat(sin(t * 5))))
            f.fillEllipse(in: CGRect(x: feet.x - w * 0.6, y: feet.y - h * 0.9, width: w * 1.2, height: h))
        }
        if m.dead { f.setAlpha(CGFloat(max(0, 1 - (t - m.diedAt) / 0.4))) }
        if m.hurtFlash > 0 { f.setAlpha(0.5) }
        let symmetric = slime || m.def.sprite.contains("bat")
        let flip = m.def.sprite.contains("wolf") || m.def.sprite == "scorpion" ? m.facingRight : !m.facingRight
        let rect = CGRect(x: (feet.x - w / 2).rounded(), y: (feet.y - h + 1 - hop - fly - lift).rounded(), width: w, height: h)
        KartArt.draw(img, in: f, rect: rect, flipX: flip && !symmetric)
        f.setAlpha(1)
        if m.elite, !m.dead {
            for k in 0..<3 {
                let a = t * 3 + Double(k) * 2.1
                KartArt.fill(f, KartArt.rgb(255, 245, 160), (feet.x + CGFloat(cos(a) * w * 0.5)).rounded(), (rect.minY + h * 0.5 + CGFloat(sin(a * 1.3) * h * 0.4)).rounded(), 1, 1)
            }
        }
        if m.windup != nil { KartArt.fill(f, KartArt.rgb(255, 80, 80), feet.x - 1, rect.minY - 5, 2, 3) }
        if t < m.stunUntil {
            for k in 0..<3 {
                let a = t * 6 + Double(k) * 2.1
                KartArt.fill(f, KartArt.rgb(255, 240, 100), (feet.x + CGFloat(cos(a) * 6)).rounded(), (rect.minY - 2 + CGFloat(sin(a) * 2)).rounded(), 1, 1)
            }
        }
        if m.dotTicks > 0, Int(t * 10) % 2 == 0 {
            let c = m.dotElement == .poison ? KartArt.rgb(150, 230, 80) : KartArt.rgb(255, 130, 40)
            KartArt.fill(f, c, feet.x - 3 + CGFloat(Int(t * 7) % 6), rect.minY + 4, 1, 2)
        }
        if t < m.slowUntil { KartArt.fill(f, KartArt.rgb(170, 238, 255), feet.x - 5, feet.y - 1, 10, 1) }
        if !m.dead, !boss, m.hp < Double(m.def.hp) * m.hpScale {
            let bw: CGFloat = 14, x = (feet.x - bw / 2).rounded(), y = rect.minY - 4
            KartArt.fill(f, KartArt.rgb(20, 20, 24), x - 1, y - 1, bw + 2, 4)
            KartArt.fill(f, KartArt.rgb(240, 70, 70), x, y, (bw * CGFloat(max(0, m.hp) / (Double(m.def.hp) * m.hpScale))).rounded(), 2)
        }
    }

    private func drawNPC(_ b: RpgBuilding, in f: CGContext) {
        let hair: CGColor = switch b.place {
        case .shop(.weapon): KartArt.rgb(60, 60, 70)
        case .shop(.armor): KartArt.rgb(170, 60, 40)
        case .shop(.potion): KartArt.rgb(230, 200, 90)
        case .shop(.skill): KartArt.rgb(150, 100, 220)
        case .jobMaster: KartArt.rgb(240, 200, 70)
        default: KartArt.rgb(90, 70, 50)
        }
        guard let img = RpgArt.sprite("villager", tint: ["H": hair]) else { return }
        let p = b.door
        f.setFillColor(KartArt.rgb(0, 0, 0, 0.28))
        f.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 2, width: 12, height: 4))
        let bob: CGFloat = Int(world.time * 2) % 2 == 0 ? 0 : 1
        KartArt.draw(img, in: f, rect: CGRect(x: p.x - 8, y: p.y - 15 - bob, width: 16, height: 16))
    }

    private func drawShots(_ f: CGContext, map: RpgMapID) {
        for s in world.shots where s.map == map {
            let speed = max(1, hypot(s.vel.dx, s.vel.dy))
            let ux = Double(s.vel.dx / speed), uy = Double(s.vel.dy / speed)
            let e = RpgArt.elem(s.element)
            let x = Double(s.pos.x), y = Double(s.pos.y)
            switch s.kind {
            case .arrow, .bigArrow, .mobArrow, .poisonArrow:
                let len = s.kind == .bigArrow ? 12.0 : 7.0
                if s.kind != .mobArrow {
                    for k in 1...6 { RpgArt.dot(f, x - ux * (len + Double(k) * 1.6), y - uy * (len + Double(k) * 1.6), (k < 3 ? e.mid : e.edge).copy(alpha: 1 - Double(k) * 0.14) ?? e.mid) }
                }
                RpgArt.line(f, x - ux * len, y - uy * len, x, y, s.kind == .mobArrow ? KartArt.rgb(200, 190, 170) : KartArt.rgb(150, 100, 56))
                RpgArt.dot(f, x + ux, y + uy, s.kind == .mobArrow ? KartArt.rgb(230, 226, 210) : e.core, s.kind == .bigArrow ? 2 : 1)
                if s.kind == .bigArrow { RpgArt.disc(f, x, y, 3, e.mid.copy(alpha: 0.5) ?? e.mid) }
            case .orb, .bossOrb:
                let r = s.kind == .bossOrb ? 3.4 : 2.6
                for k in 1...5 { RpgArt.dot(f, x - ux * Double(k) * 1.8, y - uy * Double(k) * 1.8, e.mid.copy(alpha: 1 - Double(k) * 0.18) ?? e.mid) }
                RpgArt.disc(f, x, y, r, e.edge); RpgArt.disc(f, x, y, r * 0.6, e.mid); RpgArt.dot(f, x, y, e.core)
            case .slimeBall:
                RpgArt.disc(f, x, y, 3, KartArt.rgb(46, 140, 80)); RpgArt.disc(f, x - 0.5, y - 0.5, 2, KartArt.rgb(110, 220, 130))
                RpgArt.dot(f, x - 1, y - 1, KartArt.rgb(240, 255, 240))
            }
        }
    }

    private func drawEffects(_ f: CGContext, map: RpgMapID) {
        let t = world.time
        for e in world.fx where e.map == map && t >= e.start {
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
            case .strike:
                let el = RpgArt.elem(.thunder)
                if frame < 4 { RpgArt.bolt(f, from: CGPoint(x: e.pos.x + 4, y: e.pos.y - 70), to: e.pos, seed: UInt64(frame * 7 + Int(e.pos.x)), el) }
                RpgArt.burst(f, at: e.pos, frame: frame, element: .thunder, radius: 22)
            case .rain(let radius): RpgArt.arrowRain(f, at: e.pos, frame: Int(progress * 30) % 6, radius: radius, seed: UInt64(Int(progress * 30)))
            case .spark(let crit): RpgArt.hitSpark(f, at: e.pos, frame: Int(progress * 4), crit: crit, element: e.element)
            case .levelUp: RpgArt.levelUp(f, at: e.pos, frame: Int(progress * 12) % 6, element: e.element)
            case .telegraph(let radius):
                let k = CGFloat(progress)
                f.setFillColor(KartArt.rgb(0, 0, 0, 0.15 + 0.35 * k))
                f.fillEllipse(in: CGRect(x: e.pos.x - radius * k, y: e.pos.y - radius * 0.5 * k, width: radius * 2 * k, height: radius * k))
                RpgArt.ring(f, Double(e.pos.x), Double(e.pos.y), radius, KartArt.rgb(255, 80, 80), squash: 0.5)
            }
        }
    }

    /// Dark places: a veil with soft holes around the player, torches, blasts and portals.
    private func drawDarkness(_ f: CGContext, map: RpgMap, me: RpgPlayer, vw: Int, vh: Int) {
        guard let d = darkContext else { return }
        d.setBlendMode(.normal)
        d.clear(CGRect(x: 0, y: 0, width: vw, height: vh))
        d.setFillColor(KartArt.rgb(8, 6, 14, CGFloat(map.darkness)))
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
        for s in world.shots where s.map == me.map { light(s.pos, s.fromPlayer ? 18 : 12) }
        for p in map.def.portals where !p.hidden { light(RpgMap.center(p.at), 26) }
        if map.def.kind == .volcano {
            for y in 0..<map.height { for x in 0..<map.width where map.at(x, y) == .lava && (x + y) % 3 == 0 { light(RpgMap.center(RpgTile(x: x, y: y)), 22) } }
        }
        d.setBlendMode(.normal)
        if let veil = d.makeImage() { KartArt.draw(veil, in: f, rect: CGRect(x: 0, y: 0, width: vw, height: vh)) }
    }

    // MARK: HUD

    private func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) * scale, y: (p.y - origin.y) * scale) }

    func text(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor = .white, weight: NSFont.Weight = .heavy,
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

    func box(_ ctx: CGContext, _ rect: CGRect, alpha: CGFloat = 0.55) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
    }

    func bar(_ ctx: CGContext, _ rect: CGRect, _ frac: Double, _ color: NSColor, label: String? = nil) {
        ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
        ctx.fill(rect)
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(max(0, min(1, frac))), height: rect.height))
        if let label { text(label, at: CGPoint(x: rect.midX, y: rect.minY - 2), size: 10, weight: .bold, align: .center, mono: true) }
    }

    static let gold = NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
    static let dim = NSColor(white: 0.75, alpha: 1)

    private func drawWorldText(_ me: RpgPlayer) {
        let map = world.map(me.map)
        if me.map == .town {
            for b in map.buildings {
                let s = screen(CGPoint(x: b.door.x, y: b.door.y - (b.place == .board ? 34 : 22)))
                text(b.place.title, at: CGPoint(x: s.x, y: s.y - 12), size: 12, color: NSColor(red: 1, green: 0.92, blue: 0.6, alpha: 1), weight: .bold, align: .center)
            }
        }
        for m in world.mobs[me.map] ?? [] where m.elite && !m.dead {
            let s = screen(CGPoint(x: m.pos.x, y: m.pos.y - 24))
            text("★ 황금 \(m.def.name)", at: CGPoint(x: s.x, y: s.y - 12), size: 11, color: NSColor(red: 1, green: 0.88, blue: 0.35, alpha: 1), weight: .bold, align: .center)
        }
        for portal in map.def.portals where !portal.hidden || hypot(RpgMap.center(portal.at).x - me.pos.x, RpgMap.center(portal.at).y - me.pos.y) < 40 {
            let s = screen(CGPoint(x: RpgMap.center(portal.at).x, y: RpgMap.center(portal.at).y - 20))
            let locked = me.level < portal.minLevel
            let label = portal.waypoint ? "차원문" : "\(RpgMaps.def(portal.to).name) \(RpgMaps.def(portal.to).levelText)"
            text(label, at: CGPoint(x: s.x, y: s.y - 14), size: 11,
                 color: locked ? NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1) : (portal.waypoint ? Self.gold : NSColor(red: 0.7, green: 0.85, blue: 1, alpha: 1)),
                 weight: .bold, align: .center)
        }
        // Tombstones of fallen hardcore heroes: level and name, and how they fell when you stand close.
        for g in world.graves where g.map == me.map {
            let s = screen(CGPoint(x: g.x, y: g.y - 20))
            text("☠ Lv\(g.level) \(g.name)", at: CGPoint(x: s.x, y: s.y - 14), size: 10, color: NSColor(white: 0.85, alpha: 0.9), weight: .bold, align: .center)
            if hypot(CGFloat(g.x) - me.pos.x, CGFloat(g.y) - me.pos.y) < 36 {
                let day = Date(timeIntervalSince1970: g.date).formatted(.dateTime.month().day())
                text("\(g.cls.name) · \(g.cause)에게 쓰러짐 · \(day)", at: CGPoint(x: s.x, y: s.y - 28), size: 10,
                     color: NSColor(red: 1, green: 0.8, blue: 0.6, alpha: 1), weight: .semibold, align: .center)
            }
        }
        // Other players: name tags; everyone: chat bubbles.
        for p in world.players where p.map == me.map {
            let head = screen(CGPoint(x: p.pos.x, y: p.pos.y - 18))
            var top = head.y
            if p.id != localID {
                top -= 18
                text("Lv\(p.level) \(p.name)", at: CGPoint(x: head.x, y: top), size: 11,
                     color: NSColor(red: 0.6, green: 0.85, blue: 1, alpha: 1), weight: .bold, align: .center)
            }
            if let b = p.bubble, world.time < p.bubbleUntil {
                let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                let str = NSAttributedString(string: b, attributes: [.font: font, .foregroundColor: NSColor.black])
                let w = min(260, str.size().width + 16), h = str.size().height + 8
                let r = CGRect(x: head.x - w / 2, y: top - h - 6, width: w, height: h)
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 7, cornerHeight: 7, transform: nil))
                    ctx.fillPath()
                    ctx.move(to: CGPoint(x: head.x - 5, y: r.maxY)); ctx.addLine(to: CGPoint(x: head.x + 5, y: r.maxY))
                    ctx.addLine(to: CGPoint(x: head.x, y: r.maxY + 6)); ctx.fillPath()
                }
                str.draw(with: CGRect(x: r.minX + 8, y: r.minY + 4, width: w - 16, height: h - 6), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            }
        }
        for fl in world.floaters where fl.map == me.map {
            let s = screen(fl.pos)
            let a = CGFloat(min(1, fl.life / 0.3))
            let (color, size): (NSColor, CGFloat) = switch fl.style {
            case .damage: (.white, 13)
            case .crit: (NSColor(red: 1, green: 0.75, blue: 0.2, alpha: 1), 17)
            case .hurt: (NSColor(red: 1, green: 0.35, blue: 0.35, alpha: 1), 14)
            case .heal: (NSColor(red: 0.45, green: 1, blue: 0.5, alpha: 1), 13)
            case .gold: (Self.gold, 12)
            case .xp: (NSColor(red: 0.7, green: 0.6, blue: 1, alpha: 1), 11)
            case .poison: (NSColor(red: 0.6, green: 0.95, blue: 0.3, alpha: 1), 12)
            case .info: (.white, 12)
            }
            text(fl.text, at: s, size: size, color: color.withAlphaComponent(a), align: .center)
        }
    }

    /// The whole map shrunk into the top-right corner with dots for players, monsters, portals (M toggles it).
    private func drawMinimap(_ ctx: CGContext, _ me: RpgPlayer) {
        guard showMinimap, let img = mapImages[me.map] else { return }
        let map = world.map(me.map)
        let size = map.pixelSize
        let scale = min(190 / size.width, 150 / size.height)
        let mw = size.width * scale, mh = size.height * scale
        let top = 58 + (me.quests.isEmpty ? 0 : 14 + CGFloat(me.quests.count) * 18) + 10
        let rect = CGRect(x: bounds.width - 10 - mw, y: top, width: mw, height: mh)
        box(ctx, rect.insetBy(dx: -3, dy: -3), alpha: 0.6)
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.interpolationQuality = .none
        ctx.setAlpha(0.8)
        KartArt.draw(img, in: ctx, rect: rect)
        ctx.setAlpha(1)
        func dot(_ p: CGPoint, _ color: NSColor, _ r: CGFloat) {
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.minX + p.x * scale - r, y: rect.minY + p.y * scale - r, width: r * 2, height: r * 2))
        }
        for portal in map.def.portals where !portal.hidden { dot(RpgMap.center(portal.at), NSColor(red: 0.4, green: 0.9, blue: 1, alpha: 1), 2.5) }
        if map.darkness == 0 {
            for m in world.mobs[me.map] ?? [] where !m.dead {
                if m.def.behavior == .boss { dot(m.pos, NSColor(red: 0.85, green: 0.3, blue: 1, alpha: 1), 3.5) }
                else if m.elite { dot(m.pos, NSColor(red: 1, green: 0.85, blue: 0.25, alpha: 1), 2.5) }
                else { dot(m.pos, NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1), 1.4) }
            }
        }
        for p in world.players where p.map == me.map && p.id != me.id {
            dot(p.pos, p.partyID != nil && p.partyID == me.partyID ? NSColor(red: 0.4, green: 1, blue: 0.5, alpha: 1) : NSColor(red: 0.6, green: 0.8, blue: 1, alpha: 1), 2.5)
        }
        dot(me.pos, .white, 3)
        ctx.restoreGState()
    }

    private func drawHUD(_ ctx: CGContext, _ me: RpgPlayer) {
        let t = world.time
        box(ctx, CGRect(x: 10, y: 10, width: 262, height: 96))
        text("\(me.name)  ·  \(me.title) Lv\(me.level)", at: CGPoint(x: 20, y: 14), size: 14)
        if me.hardcore { text("하드코어", at: CGPoint(x: 262, y: 16), size: 11, color: NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1), align: .right) }
        bar(ctx, CGRect(x: 20, y: 40, width: 240, height: 12), me.hp / me.maxHP, NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1),
            label: "\(Int(me.hp)) / \(Int(me.maxHP))")
        bar(ctx, CGRect(x: 20, y: 58, width: 240, height: 10), me.mp / me.maxMP, NSColor(red: 0.3, green: 0.55, blue: 1, alpha: 1),
            label: "\(Int(me.mp)) / \(Int(me.maxMP))")
        let need = RpgMaps.xpNeeded(me.level)
        bar(ctx, CGRect(x: 20, y: 74, width: 150, height: 6), me.level >= RpgMaps.maxLevel ? 1 : Double(me.xp) / Double(need), NSColor(red: 0.65, green: 0.5, blue: 1, alpha: 1))
        text("\(me.gold) G", at: CGPoint(x: 260, y: 80), size: 13, color: Self.gold, align: .right, mono: true)
        text("XP \(me.xp)/\(need)" + (me.sp > 0 ? "   SP \(me.sp)" : "") + (me.ap > 0 ? "   AP \(me.ap)" : ""), at: CGPoint(x: 20, y: 82), size: 9,
             color: me.sp > 0 || me.ap > 0 ? NSColor(red: 0.6, green: 1, blue: 0.6, alpha: 1) : Self.dim, weight: .semibold, mono: true)

        // Buffs.
        var buffs: [(String, Double, NSColor)] = []
        if t < me.rageUntil { buffs.append(("분노", me.rageUntil - t, NSColor(red: 1, green: 0.45, blue: 0.35, alpha: 1))) }
        if t < me.ironUntil { buffs.append(("철벽", me.ironUntil - t, NSColor(white: 0.9, alpha: 1))) }
        if t < me.focusUntil { buffs.append(("집중", me.focusUntil - t, NSColor(red: 0.55, green: 1, blue: 0.6, alpha: 1))) }
        if t < me.shieldUntil { buffs.append(("실드", me.shieldUntil - t, NSColor(red: 0.55, green: 0.75, blue: 1, alpha: 1))) }
        if t < me.cycloneUntil { buffs.append(("회오리", me.cycloneUntil - t, NSColor(red: 0.9, green: 0.9, blue: 0.5, alpha: 1))) }

        for b in RpgBuffs.all where me.buffActive(b.id, t) {
            buffs.append((b.name, me.buffUntil[b.id]! - t, NSColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)))
        }
        for (k, b) in buffs.enumerated() {
            text("\(b.0) \(Int(b.1.rounded(.up)))s", at: CGPoint(x: 14 + CGFloat(k) * 66, y: 110), size: 11, color: b.2, weight: .bold)
        }

        // Map name and quest tracker.
        let def = world.map(me.map).def
        box(ctx, CGRect(x: bounds.width - 200, y: 10, width: 190, height: 42))
        text(me.map == .tower ? "\(def.name) \(world.towerFloor)층" : def.name, at: CGPoint(x: bounds.width - 105, y: 12), size: 15, align: .center)
        text(def.levelText, at: CGPoint(x: bounds.width - 105, y: 32), size: 10, color: Self.dim, weight: .semibold, align: .center)
        if !me.quests.isEmpty {
            box(ctx, CGRect(x: bounds.width - 200, y: 58, width: 190, height: 14 + CGFloat(me.quests.count) * 18))
            for (k, q) in me.quests.enumerated() {
                let name = RpgMonsters.def(q.monster).name
                text(q.done ? "✓ \(name) 완료" : "\(name) \(q.progress)/\(q.count)", at: CGPoint(x: bounds.width - 190, y: 64 + CGFloat(k) * 18), size: 11,
                     color: q.done ? NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1) : .white, weight: .bold)
            }
        }

        if let boss = (world.mobs[me.map] ?? []).first(where: { $0.def.behavior == .boss && !$0.dead }) {
            let w = min(520, bounds.width - 520)
            let r = CGRect(x: bounds.midX - w / 2, y: 34, width: w, height: 14)
            text("\(boss.def.name)  Lv\(boss.def.level)" + (boss.hpScale > 1 ? "  · 레이드 \(Int((boss.hpScale - 1) / 0.9 + 1.5))인" : ""), at: CGPoint(x: bounds.midX, y: 12), size: 14, color: NSColor(red: 1, green: 0.6, blue: 0.5, alpha: 1), align: .center)
            bar(ctx, r, boss.hp / (Double(boss.def.hp) * boss.hpScale), NSColor(red: 0.85, green: 0.25, blue: 0.3, alpha: 1), label: "\(Int(max(0, boss.hp)))")
            if boss.engagedAt > 0 {
                let left = RpgWorld.berserkAfter - (world.time - boss.engagedAt)
                text(left > 0 ? String(format: "광폭화까지 %d:%02d", Int(left) / 60, Int(left) % 60) : "광폭화! 공격력 3배", at: CGPoint(x: bounds.midX, y: 50), size: 12,
                     color: left > 60 ? Self.dim : NSColor(red: 1, green: 0.35, blue: 0.3, alpha: 1), weight: .bold, align: .center, mono: true)
            }
        }

        if me.combo >= 2, me.comboUntil > world.time {
            let bonus = Int(RpgWorld.comboBonus(me.combo) * 100)
            let color = me.combo >= 50 ? NSColor(red: 1, green: 0.35, blue: 0.9, alpha: 1)
                : me.combo >= 25 ? NSColor(red: 1, green: 0.4, blue: 0.3, alpha: 1)
                : me.combo >= 10 ? NSColor(red: 1, green: 0.7, blue: 0.2, alpha: 1) : NSColor(red: 1, green: 0.95, blue: 0.6, alpha: 1)
            text("COMBO ×\(me.combo)" + (bonus > 0 ? "   XP·골드 +\(bonus)%" : ""), at: CGPoint(x: bounds.midX, y: 62), size: 22, color: color, align: .center, mono: true)
            bar(ctx, CGRect(x: bounds.midX - 60, y: 88, width: 120, height: 3), (me.comboUntil - world.time) / RpgWorld.comboWindow, color)
        }

        for (k, toast) in world.toasts.filter({ $0.to == nil || $0.to == localID }).suffix(4).enumerated() {
            text(toast.text, at: CGPoint(x: bounds.midX, y: 92 + CGFloat(k) * 20), size: 14, color: NSColor(red: 1, green: 0.95, blue: 0.75, alpha: 1), align: .center)
        }

        if panel == .none {
            let interact = bindings.label(.interact)
            if let place = world.nearbyPlace(for: localID) {
                hint("\(interact)  \(place.title) 이용하기")
            } else if let portal = world.nearbyPortal(for: localID) {
                if portal.waypoint { hint("\(interact)  차원문 열기") }
                else { hint(me.level < portal.minLevel ? "Lv\(portal.minLevel) 이상만 들어갈 수 있어요" : "\(interact)  \(RpgMaps.def(portal.to).name)(으)로 이동") }
            }
        }

        // Party frames.
        if me.partyID != nil {
            let mates = world.players.filter { $0.partyID == me.partyID && $0.id != localID }
            for (k, m) in mates.enumerated() {
                let y = 150 + CGFloat(k) * 34
                box(ctx, CGRect(x: 10, y: y, width: 190, height: 30), alpha: 0.45)
                text("\(m.name) Lv\(m.level)", at: CGPoint(x: 18, y: y + 2), size: 11, color: m.dead ? NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1) : .white, weight: .bold)
                if m.map != me.map {
                    text(RpgMaps.def(m.map).name, at: CGPoint(x: 194, y: y + 3), size: 9, color: Self.dim, weight: .semibold, align: .right)
                }
                bar(ctx, CGRect(x: 18, y: y + 19, width: 174, height: 5), m.hp / max(1, m.maxHP), NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1))
            }
        }

        // Online status and chat log.
        if let d = driver {
            let n = d.onlineCount
            text(n > 1 ? "● 온라인 \(n)명 · \(d.statusLabel)" : "● 혼자 · 같은 Wi-Fi 동료를 찾는 중", at: CGPoint(x: 14, y: 128), size: 11,
                 color: n > 1 ? NSColor(red: 0.5, green: 1, blue: 0.6, alpha: 1) : Self.dim, weight: .bold)
        }
        let recent = world.chatLog.filter { world.time - $0.at < 30 && ($0.party == nil || $0.party == me.partyID) }.suffix(6)
        for (k, line) in recent.enumerated() {
            let y = bounds.height - 160 - CGFloat(recent.count - k) * 18
            text((line.party != nil ? "[파티] " : "") + "\(line.name): \(line.text)", at: CGPoint(x: 16, y: y), size: 12,
                 color: line.party != nil ? NSColor(red: 0.55, green: 1, blue: 0.65, alpha: 1) : NSColor(white: 1, alpha: 0.9), weight: .semibold)
        }
        if chatField == nil, panel == .none {
            text("Enter 채팅", at: CGPoint(x: 16, y: bounds.height - 150), size: 10, color: NSColor(white: 1, alpha: 0.4), weight: .semibold)
        }

        drawHotbar(ctx, me)
        let b = bindings
        text("이동 방향키   공격 \(b.label(.attack))   상호작용 \(b.label(.interact))   가방 \(b.label(.inventory))   스킬 \(b.label(.skills))   의뢰 \(b.label(.quests))   파티 \(b.label(.party))   키설정 \(b.label(.keys))   미니맵 \(b.label(.minimap))   도감 \(b.label(.codex))   거래 \(b.label(.trade))   나가기 Esc",
             at: CGPoint(x: bounds.midX, y: bounds.height - 16), size: 10, color: NSColor(white: 1, alpha: 0.6), weight: .semibold, align: .center)

        if me.fallen {
            box(ctx, CGRect(x: bounds.midX - 220, y: bounds.midY - 60, width: 440, height: 96), alpha: 0.85)
            text("☠ 영원히 잠들었습니다", at: CGPoint(x: bounds.midX, y: bounds.midY - 54), size: 26, color: NSColor(red: 1, green: 0.45, blue: 0.45, alpha: 1), align: .center)
            text("하드코어 Lv\(me.level) \(me.name) — 이 자리에 묘비가 남았어요", at: CGPoint(x: bounds.midX, y: bounds.midY - 16), size: 13, color: Self.dim, align: .center)
            text("잠시 후 타이틀로 돌아갑니다", at: CGPoint(x: bounds.midX, y: bounds.midY + 6), size: 11, color: Self.dim, weight: .semibold, align: .center)
        } else if me.dead {
            box(ctx, CGRect(x: bounds.midX - 160, y: bounds.midY - 40, width: 320, height: 64), alpha: 0.7)
            text("쓰러졌다…", at: CGPoint(x: bounds.midX, y: bounds.midY - 36), size: 22, align: .center)
            text("잠시 후 마을에서 부활합니다", at: CGPoint(x: bounds.midX, y: bounds.midY - 6), size: 13, color: Self.dim, align: .center)
        }
    }

    private func hint(_ s: String) {
        guard let me else { return }
        let p = screen(CGPoint(x: me.pos.x, y: me.pos.y + 6))
        text(s, at: CGPoint(x: p.x, y: p.y + 4), size: 13, color: NSColor(red: 1, green: 0.95, blue: 0.6, alpha: 1), align: .center)
    }

    private func drawHotbar(_ ctx: CGContext, _ me: RpgPlayer) {
        let size: CGFloat = 50, gap: CGFloat = 5
        let total = CGFloat(11) * size + CGFloat(10) * gap + 12
        let y = bounds.height - size - 32
        var x = bounds.midX - total / 2
        for s in 0..<RpgWorld.slotCount {
            let r = CGRect(x: x, y: y, width: size, height: size)
            box(ctx, r, alpha: 0.65)
            if let id = me.slots[s], let def = RpgSkills.def(id) {
                let lv = me.skills[id] ?? 1
                ctx.setFillColor(RpgArt.elem(def.cls == .mage && id == "m_blast" ? me.element : .base).mid)
                ctx.fill(CGRect(x: x + 4, y: y + size - 6, width: size - 8, height: 2))
                drawSkillIcon(ctx, def, in: CGRect(x: x + 9, y: y + 8, width: 32, height: 32))
                text("Lv\(lv)", at: CGPoint(x: x + size - 4, y: y + size - 13), size: 9, color: Self.dim, weight: .bold, align: .right)
                if me.mp < Double(def.mp) { ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor); ctx.fill(r) }
                let cd = me.cooldowns[id] ?? 0
                if cd > 0 {
                    let frac = CGFloat(cd / def.cooldown)
                    ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
                    ctx.fill(CGRect(x: x, y: y + size * (1 - frac), width: size, height: size * frac))
                    text(String(format: "%.0f", cd.rounded(.up)), at: CGPoint(x: x + size / 2, y: y + 14), size: 17, align: .center)
                }
            }
            text(bindings.label(.slot(s)), at: CGPoint(x: x + 3, y: y + 1), size: 10, color: Self.gold)
            x += size + gap
        }
        x += 12
        let consumables: [(RpgKeyAction, String, Int)] = [
            (.hpPotion, "hp0", ["hp0", "hp1", "hp2", "hp3", "hp4", "hp5"].reduce(0) { $0 + (me.inventory[$1] ?? 0) }),
            (.mpPotion, "mp0", ["mp0", "mp1", "mp2", "mp3"].reduce(0) { $0 + (me.inventory[$1] ?? 0) }),
            (.scroll, "scroll", me.inventory["scroll"] ?? 0),
        ]
        for (action, icon, count) in consumables {
            let r = CGRect(x: x, y: y, width: size, height: size)
            box(ctx, r, alpha: 0.65)
            if let item = RpgItems.item(icon), let img = RpgArt.icon(item) {
                ctx.interpolationQuality = .none
                KartArt.draw(img, in: ctx, rect: CGRect(x: x + 8, y: y + 8, width: 34, height: 34))
            }
            text(bindings.label(action), at: CGPoint(x: x + 3, y: y + 1), size: 10, color: Self.gold)
            text("\(count)", at: CGPoint(x: x + size - 4, y: y + size - 17), size: 12, align: .right, mono: true)
            if count == 0 { ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor); ctx.fill(r) }
            x += size + gap
        }
    }

    // MARK: windows

    func sortedInventory(_ p: RpgPlayer) -> [String] {
        func order(_ i: RpgItem) -> Int {
            switch i.kind {
            case .weapon: return 0
            case .armor: return 1
            case .ring: return 2
            case .amulet: return 3
            case .helmet: return 4
            case .boots: return 5
            case .book: return 6
            case .stone: return 7
            case .buff: return 8
            case .potionHP: return 9
            case .potionMP: return 10
            case .scroll: return 11
            case .material: return 12
            }
        }
        return p.inventory.keys.sorted { a, b in
            let ia = RpgItems.item(a), ib = RpgItems.item(b)
            let ka = ia.map(order) ?? 9, kb = ib.map(order) ?? 9
            if ka != kb { return ka < kb }
            if (ia?.rarity ?? 0) != (ib?.rarity ?? 0) { return (ia?.rarity ?? 0) > (ib?.rarity ?? 0) }
            return a < b
        }
    }

    func itemLine(_ item: RpgItem, _ p: RpgPlayer) -> String {
        var parts: [String] = []
        let plus = p.plus[item.id] ?? 0
        if item.attack > 0 { parts.append("공격력 +\(Int(RpgItems.boosted(item.attack, plus: plus)))") }
        if item.defense > 0 { parts.append("방어력 +\(Int(RpgItems.boosted(item.defense, plus: plus)))") }
        if item.heal > 0 { parts.append(item.kind == .potionMP ? "MP +\(item.heal)" : "HP +\(item.heal)") }
        switch item.kind {
        case .scroll: parts.append("마을로 즉시 귀환")
        case .stone: parts.append("대장간에서 장비 강화에 사용")
        case .book(let id):
            if let s = RpgSkills.def(id) { parts.append("\(s.cls.name) · Lv\(s.minLevel)+ · \(s.desc)") }
        case .weapon(let cls): parts.append("\(cls.name) 전용")
        case .material: parts.append("제작 재료 (대장간)")
        case .buff(let id): if let b = RpgBuffs.def(id) { parts.append(b.desc) }
        default: break
        }
        if item.bonusHP > 0 { parts.append("HP +\(item.bonusHP)") }
        if item.bonusMP > 0 { parts.append("MP +\(item.bonusMP)") }
        if item.bonusCrit > 0 { parts.append("치명 +\(Int((item.bonusCrit * 100).rounded()))%") }
        if item.bonusAttack > 0 { parts.append("공격 +\(Int((item.bonusAttack * 100).rounded()))%") }
        if item.bonusSpeed > 0 { parts.append("이동속도 +\(Int((item.bonusSpeed * 100).rounded()))%") }
        if item.element != .base, item.isEquipment { parts.append(item.element.effectName) }
        return parts.joined(separator: " · ")
    }

    func frame(_ ctx: CGContext, title: String, hint: String, tabs: [String] = []) -> CGRect {
        let w = min(680, bounds.width - 40), h = min(500, bounds.height - 110)
        let r = CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2 - 20, width: w, height: h)
        box(ctx, r, alpha: 0.88)
        text(title, at: CGPoint(x: r.minX + 16, y: r.minY + 10), size: 18)
        for (k, tabTitle) in tabs.enumerated() {
            text(tabTitle, at: CGPoint(x: r.minX + 160 + CGFloat(k) * 90, y: r.minY + 13), size: 14,
                 color: k == tab ? Self.gold : NSColor(white: 0.5, alpha: 1))
        }
        text(hint, at: CGPoint(x: r.midX, y: r.maxY - 24), size: 11, color: Self.dim, weight: .semibold, align: .center)
        return CGRect(x: r.minX + 8, y: r.minY + 42, width: r.width - 16, height: r.height - 74)
    }

    /// A scrolling list of rows; `row` draws one row's content into its rect.
    func list(_ ctx: CGContext, count: Int, in rect: CGRect, rowH: CGFloat = 46, row: (Int, CGRect) -> Void) {
        let visible = max(1, Int(rect.height / rowH))
        let first = max(0, min(selection - visible / 2, count - visible))
        for i in first..<min(count, first + visible) {
            let r = CGRect(x: rect.minX, y: rect.minY + CGFloat(i - first) * rowH, width: rect.width, height: rowH - 4)
            if i == selection {
                ctx.setFillColor(NSColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.18).cgColor)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil))
                ctx.fillPath()
            }
            row(i, r)
        }
        if count == 0 { text("비어 있어요", at: CGPoint(x: rect.midX, y: rect.minY + 20), size: 13, color: Self.dim, align: .center) }
    }

    func itemRow(_ ctx: CGContext, _ id: String, _ r: CGRect, _ p: RpgPlayer, right: String?, color: NSColor = RpgView.gold) {
        guard let item = RpgItems.item(id) else { return }
        if let icon = RpgArt.icon(item) {
            ctx.interpolationQuality = .none
            KartArt.draw(icon, in: ctx, rect: CGRect(x: r.minX + 4, y: r.minY + 3, width: 36, height: 36))
        }
        let plus = p.plus[id] ?? 0
        let equipped = id == p.weapon || id == p.armor || id == p.ring || id == p.amulet || id == p.helmet || id == p.boots
        text((plus > 0 ? "+\(plus) " : "") + item.name + (equipped ? "  [장착 중]" : ""), at: CGPoint(x: r.minX + 48, y: r.minY + 4), size: 13,
             color: RpgArt.rarityColors[item.rarity], weight: .bold)
        text(itemLine(item, p), at: CGPoint(x: r.minX + 48, y: r.minY + 22), size: 10, color: Self.dim, weight: .semibold)
        if let right { text(right, at: CGPoint(x: r.maxX - 8, y: r.minY + 4), size: 13, color: color, align: .right, mono: true) }
        if let c = p.inventory[id] { text("×\(c)", at: CGPoint(x: r.maxX - 8, y: r.minY + 22), size: 11, align: .right, mono: true) }
    }

    private func drawPanel(_ ctx: CGContext, _ p: RpgPlayer) {
        switch panel {
        case .none:
            return
        case .inventory:
            drawBag(ctx, p)
        case .equipment:
            drawEquipment(ctx, p)
        case .shop(let s):
            let area = frame(ctx, title: s.title, hint: "↑↓ 선택   ←→ 사기·팔기   Enter 거래   Esc 나가기", tabs: ["사기", "팔기"])
            text("\(p.gold) G", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 15, color: Self.gold, align: .right, mono: true)
            if tab == 0 {
                let items = stock(s, p)
                list(ctx, count: items.count, in: area) { i, r in
                    let it = items[i]
                    itemRow(ctx, it.id, r, p, right: "\(it.price) G", color: p.gold >= it.price ? Self.gold : NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
                }
            } else {
                let ids = sortedInventory(p)
                list(ctx, count: ids.count, in: area) { i, r in itemRow(ctx, ids[i], r, p, right: "+\(RpgItems.item(ids[i])?.sellPrice ?? 0) G") }
            }
        case .trade:
            drawTrade(ctx, p)
        case .codex:
            let area = frame(ctx, title: "도감 · 업적", hint: "↑↓ 선택   ←→ 탭   \(bindings.label(.codex))/Esc 닫기", tabs: ["몬스터 도감", "업적"])
            let green = NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1)
            if tab == 0 {
                let met = Self.codexMonsters.filter { (p.kills[$0.id] ?? 0) > 0 }.count
                text("발견 \(met) / \(Self.codexMonsters.count)", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 13, color: Self.gold, align: .right)
                list(ctx, count: Self.codexMonsters.count, in: area, rowH: 44) { i, r in
                    let def = Self.codexMonsters[i]
                    let n = p.kills[def.id] ?? 0
                    if let img = RpgArt.sprite(def.sprite) {
                        ctx.interpolationQuality = .none
                        ctx.setAlpha(n > 0 ? 1 : 0.25)
                        let h: CGFloat = 32
                        KartArt.draw(img, in: ctx, rect: CGRect(x: r.minX + 6, y: r.minY + 4, width: h * CGFloat(img.width) / CGFloat(img.height), height: h))
                        ctx.setAlpha(1)
                    }
                    text(n > 0 ? "\(def.name)  Lv\(def.level)" + (def.behavior == .boss ? "  [보스]" : "") : "???", at: CGPoint(x: r.minX + 56, y: r.minY + 4),
                         size: 14, color: n > 0 ? .white : Self.dim, weight: .bold)
                    text(n > 0 ? "처치 \(n)마리 · HP \(def.hp) · 경험치 \(def.xp)" : "아직 만나지 못했어요", at: CGPoint(x: r.minX + 56, y: r.minY + 24), size: 10,
                         color: Self.dim, weight: .semibold)
                }
            } else {
                text("달성 \(p.achievements.count) / \(RpgAchievements.all.count)", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 13, color: Self.gold, align: .right)
                list(ctx, count: RpgAchievements.all.count, in: area, rowH: 50) { i, r in
                    let a = RpgAchievements.all[i]
                    let have = p.achievements.contains(a.id)
                    let value = min(a.goal, RpgAchievements.value(a.metric, p))
                    text(a.name + (have ? "  ✓ 달성" : ""), at: CGPoint(x: r.minX + 12, y: r.minY + 4), size: 14, color: have ? green : .white, weight: .bold)
                    text("\(a.desc)  ·  보상 \(a.gold)G · 강화석 \(a.stones)개", at: CGPoint(x: r.minX + 12, y: r.minY + 25), size: 10, color: Self.dim, weight: .semibold)
                    bar(ctx, CGRect(x: r.maxX - 150, y: r.minY + 12, width: 140, height: 8), Double(value) / Double(a.goal), have ? green : Self.gold,
                        label: "\(value)/\(a.goal)")
                }
            }
        case .job where p.job != 0:
            let next = p.tier + 1
            let nextDef = RpgJobs.def(p.cls, p.job, tier: next)
            let area = frame(ctx, title: "전직관 — \(p.title)", hint: nextDef != nil ? "Enter 전직   Esc 나가기" : "Esc 나가기")
            if let o = nextDef, let need = RpgTiers.levels[next], let cost = RpgTiers.gold[next] {
                let ready = p.level >= need && p.gold >= cost
                text("\(next + 1)차 전직: \(o.name)", at: CGPoint(x: area.minX + 8, y: area.minY - 30), size: 14, color: Self.gold)
                list(ctx, count: 1, in: area, rowH: 150) { _, r in
                    text(o.name, at: CGPoint(x: r.minX + 16, y: r.minY + 8), size: 20, color: ready ? Self.gold : .white, weight: .bold)
                    text(o.blurb, at: CGPoint(x: r.minX + 16, y: r.minY + 38), size: 12, color: Self.dim, weight: .semibold)
                    text("조건: Lv\(need) (현재 \(p.level))  ·  \(cost) G (보유 \(p.gold))", at: CGPoint(x: r.minX + 16, y: r.minY + 62), size: 13,
                         color: ready ? NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1) : NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1), weight: .bold)
                    let bonus = [("HP", o.hp), ("MP", o.mp), ("공격", o.attack), ("방어", o.defense)].filter { $0.1 != 1 }
                        .map { "\($0.0) \($0.1 > 1 ? "+" : "")\(Int(($0.1 - 1) * 100))%" }.joined(separator: "  ")
                    text("현재 직업 대비 총 보정  " + bonus + "  치명 +\(Int(o.crit * 100))%", at: CGPoint(x: r.minX + 16, y: r.minY + 86), size: 12, weight: .bold)
                    let levels = RpgTiers.skillLevels[next] ?? []
                    let names = o.skills.compactMap(RpgSkills.def).enumerated().map { "\($1.name) (Lv\(levels[$0]))" }
                    text("스킬: " + names.joined(separator: "  ·  "), at: CGPoint(x: r.minX + 16, y: r.minY + 110), size: 12)
                }
            } else {
                text("최고 단계에 도달했어요", at: CGPoint(x: area.midX, y: area.minY + 40), size: 16, color: Self.gold, align: .center)
            }
        case .job:
            let area = frame(ctx, title: "전직관 — 2차 전직", hint: p.job == 0 && p.level >= RpgJobs.advanceLevel
                             ? "↑↓ 선택   Enter 전직 (한 번 고르면 바꿀 수 없어요)   Esc 나가기" : "Esc 나가기")
            let options = RpgJobs.options(for: p.cls)
            let status = p.job != 0 ? "이미 \(p.title)(으)로 전직했어요" : (p.level >= RpgJobs.advanceLevel ? "전직할 직업을 고르세요" : "Lv\(RpgJobs.advanceLevel)이 되면 전직할 수 있어요 (현재 Lv\(p.level))")
            text(status, at: CGPoint(x: area.minX + 8, y: area.minY - 30), size: 13, color: Self.gold)
            list(ctx, count: options.count, in: area, rowH: 120) { i, r in
                let o = options[i]
                text(o.name, at: CGPoint(x: r.minX + 16, y: r.minY + 8), size: 18, color: p.job == o.job ? Self.gold : .white, weight: .bold)
                text(o.blurb, at: CGPoint(x: r.minX + 16, y: r.minY + 36), size: 12, color: Self.dim, weight: .semibold)
                let bonus = [("HP", o.hp), ("MP", o.mp), ("공격", o.attack), ("방어", o.defense)].filter { $0.1 != 1 }
                    .map { "\($0.0) \($0.1 > 1 ? "+" : "")\(Int(($0.1 - 1) * 100))%" }.joined(separator: "  ")
                text(bonus + (o.crit > 0 ? "  치명 +\(Int(o.crit * 100))%" : "") + (o.interval != 1 ? "  공속 \(o.interval < 1 ? "+" : "-")\(Int(abs(1 - o.interval) * 100))%" : ""),
                     at: CGPoint(x: r.minX + 16, y: r.minY + 58), size: 12, color: .white, weight: .bold)
                let names = o.skills.compactMap(RpgSkills.def).enumerated().map { "\($1.name) (Lv\($0 == 0 ? RpgJobs.advanceLevel : RpgJobs.secondSkillLevel))" }
                text("스킬: " + names.joined(separator: "  ·  "), at: CGPoint(x: r.minX + 16, y: r.minY + 80), size: 12, color: .white)
            }
        case .smith where tab == 1:
            let area = frame(ctx, title: "대장간 — 제작", hint: "↑↓ 선택   ←→ 탭   Enter 제작   Esc 나가기", tabs: ["강화", "제작"])
            text("\(p.gold) G", at: CGPoint(x: area.maxX - 8, y: area.minY - 30), size: 15, color: Self.gold, align: .right, mono: true)
            list(ctx, count: RpgRecipes.all.count, in: area, rowH: 54) { i, r in
                let rec = RpgRecipes.all[i]
                let can = p.gold >= rec.gold && rec.materials.allSatisfy { (p.inventory[$0.key] ?? 0) >= $0.value }
                itemRow(ctx, rec.output, r, p, right: "\(rec.gold) G", color: p.gold >= rec.gold ? Self.gold : NSColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
                let needs = rec.materials.sorted { $0.key < $1.key }.map { "\(RpgItems.item($0.key)?.name ?? $0.key) \(p.inventory[$0.key] ?? 0)/\($0.value)" }.joined(separator: "  ")
                text((rec.count > 1 ? "×\(rec.count)  " : "") + needs, at: CGPoint(x: r.minX + 48, y: r.minY + 36), size: 10,
                     color: can ? NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1) : Self.dim, weight: .semibold)
            }
        case .smith:
            let area = frame(ctx, title: "대장간 — 장비 강화", hint: "↑↓ 선택   ←→ 탭   Enter 강화   Esc 나가기", tabs: ["강화", "제작"])
            let rows: [String?] = [p.weapon, p.armor]
            list(ctx, count: 2, in: area, rowH: 90) { i, r in
                guard let id = rows[i], let item = RpgItems.item(id) else {
                    text("장착한 갑옷이 없어요", at: CGPoint(x: r.minX + 16, y: r.minY + 10), size: 13, color: Self.dim)
                    return
                }
                itemRow(ctx, id, r, p, right: nil)
                let plus = p.plus[id] ?? 0
                if plus >= RpgItems.maxPlus {
                    text("최대 강화 완료", at: CGPoint(x: r.minX + 48, y: r.minY + 46), size: 12, color: Self.gold)
                } else {
                    let cost = RpgItems.enhanceCost(item, plus: plus)
                    let chance = Int(RpgItems.enhanceChance(plus) * 100)
                    text("+\(plus) → +\(plus + 1)   성공 \(chance)%   \(cost.gold) G · 강화석 \(cost.stones)개 (보유 \(p.inventory["stone"] ?? 0))",
                         at: CGPoint(x: r.minX + 48, y: r.minY + 46), size: 12, color: .white, weight: .bold)
                    text(plus >= 7 ? "실패하면 단계가 1 떨어져요" : "실패해도 단계는 유지돼요", at: CGPoint(x: r.minX + 48, y: r.minY + 64), size: 10,
                         color: plus >= 7 ? NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1) : Self.dim, weight: .semibold)
                }
            }
        case .board:
            let area = frame(ctx, title: "의뢰소", hint: "↑↓ 선택   ←→ 탭   Enter 수락·보상 받기   Delete 포기   Esc 나가기", tabs: ["새 의뢰", "진행 중 \(p.quests.count)/3"])
            let quests = tab == 0 ? world.boardOffers(for: localID) : p.quests
            list(ctx, count: quests.count, in: area, rowH: 58) { i, r in questRow(ctx, quests[i], r, active: tab == 1) }
        case .quests:
            let area = frame(ctx, title: "의뢰 목록", hint: "완료한 의뢰는 마을 의뢰소에서 보상을 받아요   Delete 포기   \(bindings.label(.quests))/Esc 닫기")
            list(ctx, count: p.quests.count, in: area, rowH: 58) { i, r in questRow(ctx, p.quests[i], r, active: true) }
        case .skills:
            drawSkills(ctx, p)
        case .keys:
            let area = frame(ctx, title: "키 설정", hint: waitingKey ? "바꿀 키를 누르세요 (Esc 취소)" : "↑↓ 선택   Enter 키 바꾸기   Delete 기본값으로   \(bindings.label(.keys))/Esc 닫기")
            let actions = RpgKeyAction.allCases
            list(ctx, count: actions.count, in: area, rowH: 26) { i, r in
                text(actions[i].title, at: CGPoint(x: r.minX + 12, y: r.minY + 3), size: 13, weight: .bold)
                let label = (waitingKey && i == selection) ? "…" : bindings.label(actions[i])
                text(label, at: CGPoint(x: r.maxX - 12, y: r.minY + 3), size: 13, color: Self.gold, align: .right, mono: true)
            }
        case .party:
            let count = p.partyID == nil ? 1 : world.players.filter { $0.partyID == p.partyID }.count
            let area = frame(ctx, title: "파티 \(count)/8",
                             hint: tab == 0 ? "Enter 초대 수락 · 파티원 곁으로 이동(마을에서)   Delete 거절 · 파티 나가기   ←→ 탭   \(bindings.label(.party))/Esc 닫기"
                                            : "Enter 초대하기   ←→ 탭   파티 채팅은 /p 메시지   \(bindings.label(.party))/Esc 닫기",
                             tabs: ["내 파티", "초대하기"])
            if tab == 0 {
                let rows = partyRows(p)
                list(ctx, count: rows.count, in: area, rowH: 44) { i, r in
                    if rows[i] == -1 {
                        let from = p.inviteFrom.flatMap { world.player($0) }?.name ?? "누군가"
                        text("📨 \(from) 님의 파티 초대 — Enter 수락 · Delete 거절", at: CGPoint(x: r.minX + 12, y: r.minY + 12), size: 14, color: Self.gold)
                        return
                    }
                    guard let m = world.player(rows[i]) else { return }
                    memberRow(ctx, m, r, me: m.id == localID)
                }
            } else {
                let list = inviteCandidates(p)
                self.list(ctx, count: list.count, in: area, rowH: 44) { i, r in memberRow(ctx, list[i], r, me: false) }
                if list.isEmpty {
                    text("같은 세계에 초대할 동료가 없어요", at: CGPoint(x: area.midX, y: area.minY + 20), size: 13, color: Self.dim, align: .center)
                }
            }
        case .waypoint where tab == 1:
            let area = frame(ctx, title: "차원문", hint: "새로운 대륙으로 떠나요 (레벨 필요)   ↑↓ 선택   Enter 이동   ←→ 탭   Esc 닫기", tabs: ["가 본 지역", "대륙"])
            let regions = RpgRegions.all
            self.list(ctx, count: regions.count, in: area, rowH: 54) { i, r in
                let region = regions[i]
                let ok = p.level >= region.minLevel
                text(region.name, at: CGPoint(x: r.minX + 12, y: r.minY + 6), size: 15, color: ok ? .white : NSColor(white: 0.5, alpha: 1), weight: .bold)
                text("Lv\(region.minLevel)+", at: CGPoint(x: r.maxX - 12, y: r.minY + 6), size: 12, color: ok ? Self.gold : NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1), align: .right)
                text(region.blurb, at: CGPoint(x: r.minX + 12, y: r.minY + 30), size: 11, color: Self.dim, weight: .semibold)
            }
        case .waypoint:
            let area = frame(ctx, title: "차원문", hint: "가 본 지역으로 바로 이동해요   ↑↓ 선택   Enter 이동   ←→ 탭   Esc 닫기", tabs: ["가 본 지역", "대륙"])
            let list = waypoints(p)
            self.list(ctx, count: list.count, in: area, rowH: 36) { i, r in
                let def = RpgMaps.def(list[i])
                text(def.name, at: CGPoint(x: r.minX + 12, y: r.minY + 6), size: 14, weight: .bold)
                text(def.levelText, at: CGPoint(x: r.maxX - 12, y: r.minY + 6), size: 12, color: Self.dim, align: .right)
            }
        }
    }

    // MARK: trade

    /// Players to trade with (same map), headed by a pending request (-1) if there is one.
    private func tradeRows(_ p: RpgPlayer) -> [Int] {
        (p.tradeFrom != nil ? [-1] : []) + world.players.filter { $0.id != p.id && $0.map == p.map }.map(\.id)
    }

    /// Bag items that may be offered (not enhanced ids).
    private func tradeBag(_ p: RpgPlayer) -> [String] { sortedInventory(p).filter { RpgTrades.tradable($0, p) } }

    /// Keys of an open trade: ↑↓ item, Enter +1, Delete -1, ←→ gold, Tab confirm, C cancel. Returns false when there is no trade.
    private func handleTradeKey(_ code: UInt16, repeatKey: Bool, _ p: RpgPlayer) -> Bool {
        guard let view = world.tradeView(for: localID) else { return false }
        let bag = tradeBag(p)
        let chosen = bag.indices.contains(selection) ? bag[selection] : nil
        switch code {
        case 126: selection = max(0, selection - 1)
        case 125: selection = min(max(0, bag.count - 1), selection + 1)
        case 36:
            if let item = chosen { act(.tradeOffer(item: item, count: (view.mine.items[item] ?? 0) + 1)) }
        case 51:
            if let item = chosen { act(.tradeOffer(item: item, count: (view.mine.items[item] ?? 0) - 1)) }
        case 123, 124:
            let step = NSEvent.modifierFlags.contains(.shift) ? 1000 : 100
            act(.tradeGold(view.mine.gold + (code == 124 ? step : -step)))
        case 48:
            if !repeatKey { act(.tradeConfirm(!view.mine.ok)) }
        case 8:
            if !repeatKey { act(.tradeCancel) }
        case 53:
            if !repeatKey { close() }
        default:
            break
        }
        return true
    }

    private func drawTrade(_ ctx: CGContext, _ p: RpgPlayer) {
        let green = NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1)
        guard let v = world.tradeView(for: localID) else {
            let rows = tradeRows(p)
            let area = frame(ctx, title: "거래", hint: "↑↓ 선택   Enter 거래 요청 · 수락   Delete 거절   \(bindings.label(.trade))/Esc 닫기")
            list(ctx, count: rows.count, in: area, rowH: 44) { i, r in
                if rows[i] == -1 {
                    let from = p.tradeFrom.flatMap { world.player($0) }?.name ?? "누군가"
                    text("\(from) 님의 거래 요청 — Enter 수락 · Delete 거절", at: CGPoint(x: r.minX + 12, y: r.minY + 12), size: 14, color: Self.gold)
                } else if let m = world.player(rows[i]) {
                    memberRow(ctx, m, r, me: false)
                }
            }
            if rows.isEmpty {
                text("같은 맵에 거래할 동료가 없어요 (가까이 가야 해요)", at: CGPoint(x: area.midX, y: area.minY + 20), size: 13, color: Self.dim, align: .center)
            }
            return
        }
        let area = frame(ctx, title: "\(v.partnerName) 님과 거래",
                         hint: "↑↓ 아이템   Enter +1   Delete -1   ←→ 골드 ±100 (Shift ±1000)   Tab 확정   C 취소   Esc 닫기")
        func column(_ offer: RpgTradeOffer, _ title: String, x: CGFloat) {
            text(title + (offer.ok ? "  ✓ 확정" : ""), at: CGPoint(x: x + 8, y: area.minY), size: 14, color: offer.ok ? green : Self.gold)
            text("골드 \(offer.gold) G", at: CGPoint(x: x + 8, y: area.minY + 22), size: 13)
            for (k, e) in offer.items.sorted(by: { $0.key < $1.key }).enumerated() {
                text("\(RpgItems.item(e.key)?.name ?? e.key) ×\(e.value)", at: CGPoint(x: x + 8, y: area.minY + 44 + CGFloat(k) * 16), size: 11, weight: .semibold)
            }
        }
        column(v.mine, "내 제안", x: area.minX)
        column(v.theirs, "상대 제안", x: area.minX + area.width / 2)
        let bag = tradeBag(p)
        let bagRect = CGRect(x: area.minX, y: area.minY + 180, width: area.width, height: max(40, area.height - 180))
        list(ctx, count: bag.count, in: bagRect, rowH: 46) { i, r in
            let n = v.mine.items[bag[i]] ?? 0
            itemRow(ctx, bag[i], r, p, right: n > 0 ? "제안 \(n)" : nil)
        }
    }

    private func memberRow(_ ctx: CGContext, _ m: RpgPlayer, _ r: CGRect, me: Bool) {
        if let img = RpgArt.sprite(m.cls.rawValue) {
            ctx.interpolationQuality = .none
            KartArt.draw(img, in: ctx, rect: CGRect(x: r.minX + 6, y: r.minY + 4, width: 34, height: 34))
        }
        text("\(m.name)\(me ? " (나)" : "")  ·  \(m.title) Lv\(m.level)", at: CGPoint(x: r.minX + 50, y: r.minY + 4), size: 13, weight: .bold)
        bar(ctx, CGRect(x: r.minX + 50, y: r.minY + 24, width: 160, height: 7), m.hp / max(1, m.maxHP), NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1))
        text(m.dead ? "쓰러짐" : RpgMaps.def(m.map).name, at: CGPoint(x: r.maxX - 10, y: r.minY + 12), size: 12,
             color: m.dead ? NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1) : Self.dim, weight: .semibold, align: .right)
    }

    private func questRow(_ ctx: CGContext, _ q: RpgQuest, _ r: CGRect, active: Bool) {
        let def = RpgMonsters.def(q.monster)
        let boss = def.behavior == .boss
        if let img = RpgArt.sprite(def.sprite) {
            ctx.interpolationQuality = .none
            let h: CGFloat = boss ? 40 : 34
            KartArt.draw(img, in: ctx, rect: CGRect(x: r.minX + 6, y: r.minY + 6, width: h * CGFloat(img.width) / CGFloat(img.height), height: h))
        }
        let title = boss ? "[보스] \(def.name) 토벌" : "\(def.name) \(q.count)마리 처치"
        text(title + (active ? "  \(q.progress)/\(q.count)" : "") + (q.done ? "  완료!" : ""), at: CGPoint(x: r.minX + 56, y: r.minY + 6), size: 14,
             color: q.done ? NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1) : .white, weight: .bold)
        let book = q.book.flatMap(RpgItems.item).map { " · \($0.name)" } ?? ""
        text("보상: \(q.gold)G · 경험치 \(q.xp) · 강화석 \(q.stones)\(book)   (Lv\(def.level) 지역)", at: CGPoint(x: r.minX + 56, y: r.minY + 28), size: 10,
             color: Self.dim, weight: .semibold)
    }
}

extension RpgArt {
    /// A small stone tombstone with a cross, standing where a hardcore hero fell.
    static func grave(_ ctx: CGContext, at p: CGPoint) {
        let x = p.x.rounded(), y = p.y.rounded()
        KartArt.fill(ctx, rgb(0, 0, 0, 0.3), x - 6, y, 12, 3)
        KartArt.fill(ctx, outline, x - 5, y - 13, 10, 14)
        KartArt.fill(ctx, rgb(150, 150, 160), x - 4, y - 12, 8, 12)
        KartArt.fill(ctx, rgb(180, 180, 190), x - 4, y - 12, 2, 12)
        KartArt.fill(ctx, outline, x - 3, y - 14, 6, 1)
        KartArt.fill(ctx, rgb(90, 90, 100), x - 1, y - 10, 2, 7)
        KartArt.fill(ctx, rgb(90, 90, 100), x - 3, y - 8, 6, 2)
        KartArt.fill(ctx, rgb(110, 90, 70), x - 6, y, 12, 1)
    }
}

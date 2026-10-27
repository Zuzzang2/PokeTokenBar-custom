import CoreGraphics
import Foundation
@testable import PokeTokenBar

/// 외관 아이템 drawn on the hero (`RpgCosmeticArt`): every piece shows and differs from the rest of its slot, what is worn is
/// part of the frame cache key, it reaches other players, ghosts and stealth draw it, and dressed heroes stay cheap to draw.
func cosmeticArtChecks() {
    MainActor.assumeIsolated {
        let all = RpgCosmetics.all
        let classes: [RpgClass] = [.warrior, .mage, .mechanic]
        func hero(_ cls: RpgClass, _ worn: [String: String] = [:], id: Int = 3) -> RpgPlayer {
            var p = RpgSaveStore.newPlayer(name: "c", cls: cls, id: id)
            p.worn = worn
            return p
        }
        func pose(_ v: RpgHeroView, moving: Bool = false, action: RpgHeroPose.Action = .idle) -> RpgHeroPose {
            RpgHeroPose(action: action, view: v, flip: false, moving: moving, step: 1, t: 0.05, aim: v == .front ? .pi / 2 : v == .back ? -.pi / 2 : 0)
        }
        func bytes(_ img: CGImage?) -> Data? { img?.dataProvider?.data as Data? }
        /// Everything a piece can change: the three body frames and the finished picture (weapon, aura, steps) idle and walking.
        @MainActor func look(_ p: RpgPlayer) -> [Data?] {
            RpgHeroView.allCases.flatMap { v in
                [bytes(RpgArt.heroFrame(p, pose: pose(v), time: 1)), bytes(RpgArt.heroPreview(p, pose: pose(v), time: 1)),
                 bytes(RpgArt.heroPreview(p, pose: pose(v, moving: true), time: 1.1))]
            }
        }

        // Every piece shows on some class, and no two pieces of a slot look the same.
        var unseen: [String] = [], twins: [String] = []
        for slot in RpgCosmeticSlot.allCases {
            var seen: [[Data?]: String] = [:]
            for c in all where c.slot == slot {
                let looks = classes.map { look(hero($0, [slot.rawValue: c.id])) }
                if !zip(classes, looks).contains(where: { cls, l in l != look(hero(cls)) }) { unseen.append(c.id) }
                let flat = looks.flatMap { $0 }
                if let other = seen[flat] { twins.append("\(other)=\(c.id)") }
                seen[flat] = c.id
            }
        }
        check(unseen.isEmpty, "every one of the \(all.count) cosmetics changes how a hero looks (\(unseen.prefix(5)))")
        check(twins.isEmpty, "no two cosmetics of a slot draw the same (\(twins.prefix(5)))")

        // Every letter of every worn piece has a colour, on every class.
        var holes: [String] = []
        for cls in RpgClass.allCases {
            for c in all {
                let h = RpgArt.heroCosmeticHoles(hero(cls, [c.slot.rawValue: c.id]))
                if !h.isEmpty { holes.append("\(cls.rawValue)/\(c.id) \(String(h.sorted()))") }
            }
        }
        check(holes.isEmpty, "every cosmetic pixel has a colour for every class (\(holes.prefix(3)))")

        // The frame cache follows what is worn: putting a piece on repaints, taking it off brings the old frame back.
        var p = hero(.archer)
        let bare = bytes(RpgArt.heroFrame(p, pose: pose(.front), time: 1))
        p.worn = ["hat": "hat_coast"]
        let hatted = bytes(RpgArt.heroFrame(p, pose: pose(.front), time: 1))
        p.worn = ["hat": "hat_coast", "outfit": "outfit_frost"]
        let dressed = bytes(RpgArt.heroFrame(p, pose: pose(.front), time: 1))
        p.worn = [:]
        check(bare != hatted && hatted != dressed && bytes(RpgArt.heroFrame(p, pose: pose(.front), time: 1)) == bare, "changing what is worn repaints the cached frame")
        let skinned = { (skin: UInt8) in bytes(RpgArt.heroWeaponImage(RpgItems.item("sword3")!, cls: .warrior, angle: 0.5, skin: skin)) }
        check(skinned(0) != skinned(3) && skinned(3) != skinned(9) && skinned(0) == skinned(0), "weapon skins are cached apart from the plain weapon")

        // Worn wings win over the 4차 ones; a hat hides the class's own headgear and helmet.
        var winged = hero(.cleric)
        (winged.job, winged.tier, winged.helmet) = (1, 3, "helmet11")
        let jobWings = bytes(RpgArt.heroFrame(winged, pose: pose(.back), time: 1))
        winged.worn = ["wings": "wings_rift"]
        check(bytes(RpgArt.heroFrame(winged, pose: pose(.back), time: 1)) != jobWings, "worn wings replace the 4차 wings")
        var helmed = hero(.warrior, ["hat": "hat_jungle"])
        let hatOnly = RpgHeroView.allCases.map { bytes(RpgArt.heroFrame(helmed, pose: pose($0), time: 1)) }
        helmed.helmet = "helmet11"
        check(RpgHeroView.allCases.map { bytes(RpgArt.heroFrame(helmed, pose: pose($0), time: 1)) } == hatOnly, "a worn hat hides the helmet")

        // A full set reaches other players through the snapshot and draws the same there.
        let set = ["hat": "hat_chaos", "outfit": "outfit_chaos", "cape": "cape_chaos", "weaponSkin": "weaponSkin_chaos", "aura": "aura_chaos",
                   "wings": "wings_chaos", "steps": "steps_chaos", "hair": "hair_2", "face": "face_5"]
        var host = hero(.summoner, id: 1)
        host.wardrobe = Set(set.values)
        host.worn = set
        let world = RpgWorld(player: host)
        world.addPlayer(RpgSaveStore.newPlayer(name: "guest", cls: .monk, id: 2))
        world.step(0.1, inputs: [:])
        let mirror = RpgWorld(player: RpgSaveStore.newPlayer(name: "guest", cls: .monk, id: 2))
        mirror.isMirror = true
        mirror.apply(world.snapshot(), localID: 2)
        let seen = mirror.player(1)
        check(seen?.worn == set, "others see the whole set worn (\(seen?.worn ?? [:]))")
        if let seen, let mine = world.player(1) {
            let same = RpgHeroView.allCases.allSatisfy { v in
                bytes(RpgArt.heroPreview(seen, pose: pose(v), time: 2)) == bytes(RpgArt.heroPreview(mine, pose: pose(v), time: 2))
            }
            check(same, "a remote hero is drawn exactly as its owner sees it")
        }

        // Ghosts, stealth, afterimages and menus draw every piece without trouble.
        guard let ctx = KartArt.context(width: 64, height: 64) else { check(false, "a drawing context"); return }
        var drawn = 0
        for cls in RpgClass.allCases {
            var p = hero(cls)
            p.pos = CGPoint(x: 32, y: 50)
            p.worn = Dictionary(uniqueKeysWithValues: RpgCosmeticSlot.allCases.compactMap { s in all.last { $0.slot == s }.map { (s.rawValue, $0.id) } })
            for action in RpgHeroPose.Action.allCases {
                for v in RpgHeroView.allCases {
                    p.dead = action == .dead
                    RpgArt.drawHero(ctx, p, pose: pose(v, moving: action == .idle, action: action), time: 3, alpha: 0.25)
                    RpgArt.drawHero(ctx, p, pose: pose(v, action: action), time: 3, alpha: 0.4, extras: false)
                    drawn += 1
                }
            }
            p.dead = false
            if RpgArt.heroPreview(p, pose: RpgArt.heroShowcasePose(p, time: 4), time: 4) == nil { drawn = -1_000 }
        }
        check(drawn == RpgClass.allCases.count * RpgHeroPose.Action.allCases.count * 3, "dead, stealthed and afterimage heroes in full sets draw (\(drawn))")
        var ghost = hero(.rogue, ["wings": "wings_celestial", "aura": "aura_celestial"])
        ghost.dead = true
        let ghostFrame = bytes(RpgArt.heroFrame(ghost, pose: RpgArt.heroPose(ghost, time: 1), time: 1))
        ghost.worn = ["aura": "aura_celestial"]
        check(ghostFrame == bytes(RpgArt.heroFrame(ghost, pose: RpgArt.heroPose(ghost, time: 1), time: 1)), "ghosts leave their wings behind like the 4차 ones")

        // Steps leave marks behind a walking hero, and every piece has a wardrobe icon.
        let tracker = RpgHeroTracker()
        var walker = hero(.archer, ["steps": "steps_frost"])
        walker.moving = true
        walker.pos = CGPoint(x: 100, y: 150)
        var motion = tracker.update(walker, time: 0)
        for k in 1...30 { walker.pos.x += 3; motion = tracker.update(walker, time: Double(k) / 30) }
        check(motion.prints.count >= 3, "walking in worn steps leaves marks (\(motion.prints.count))")
        guard let ground = KartArt.context(width: 400, height: 300), let plain = KartArt.context(width: 400, height: 300) else { return }
        RpgArt.drawHeroGround(ground, walker, motion: motion, pose: RpgArt.heroPose(walker, time: 1), time: 1)
        var unworn = walker
        unworn.worn = [:]
        RpgArt.drawHeroGround(plain, unworn, motion: motion, pose: RpgArt.heroPose(unworn, time: 1), time: 1)
        check(bytes(ground.makeImage()) != bytes(plain.makeImage()), "the marks are drawn on the ground")
        let icons = all.filter { RpgArt.cosmeticIcon($0, on: hero(.monk)) == nil }.map(\.id)
        check(icons.isEmpty, "every cosmetic has a wardrobe icon (\(icons.prefix(3)))")
        check(RpgArt.heroHeight(hero(.rogue, ["hat": "hat_festival"])) > RpgArt.heroHeight(.rogue), "a tall hat raises the head height used for bubbles")

        // Dressed heroes stay cheap: a crowd in full sets, after its frames are cached, draws well inside a 60 fps frame.
        guard let screen = KartArt.context(width: 640, height: 360) else { return }
        var crowd: [RpgPlayer] = []
        for k in 0..<24 {
            let cls = RpgClass.allCases[k % RpgClass.allCases.count]
            var q = hero(cls, id: 10 + k)
            q.worn = Dictionary(uniqueKeysWithValues: RpgCosmeticSlot.allCases.compactMap { s in
                let pieces = all.filter { $0.slot == s }
                return pieces.isEmpty ? nil : (s.rawValue, pieces[(k * 7) % pieces.count].id)
            })
            q.pos = CGPoint(x: 30 + (k % 8) * 75, y: 60 + (k / 8) * 110)
            q.moving = k % 2 == 0
            crowd.append(q)
        }
        @MainActor func drawCrowd(_ frames: Int, start: Double) {
            for f in 0..<frames {
                let t = start + Double(f) / 60
                for q in crowd { RpgArt.drawHero(screen, q, pose: RpgArt.heroPose(q, time: t, speed: q.moving ? 60 : 0, walked: t * 60), time: t) }
            }
        }
        drawCrowd(120, start: 0)
        let begin = Date()
        drawCrowd(120, start: 0)
        let perHero = Date().timeIntervalSince(begin) / Double(120 * crowd.count) * 1000
        // About 0.02 ms here in a debug build; rebuilding frames every draw (a broken cache key) costs about 0.4 ms.
        check(perHero < 0.1, "a hero in a full set draws in \(String(format: "%.3f", perHero)) ms (budget 0.1 ms: 24 of them take 2.4 ms of a 16 ms frame)")
    }
}

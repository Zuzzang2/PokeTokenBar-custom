import AppKit
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
    prismArtChecks()
}

/// The prism (초월) set shimmers: its frames are cached per shimmer phase, only for heroes wearing it, and it stays inside the
/// frame budget.
func prismArtChecks() {
    MainActor.assumeIsolated {
        let set = ["hat": "hat_prism", "outfit": "outfit_prism", "cape": "cape_prism", "weaponSkin": "weaponSkin_prism", "aura": "aura_prism",
                   "wings": "wings_prism", "steps": "steps_prism"]
        let n = RpgArt.prismPhases, rate = RpgArt.prismRate
        func hero(_ cls: RpgClass, _ worn: [String: String], id: Int = 3) -> RpgPlayer {
            var p = RpgSaveStore.newPlayer(name: "p", cls: cls, id: id)
            p.worn = worn
            return p
        }
        func pose(_ v: RpgHeroView, moving: Bool = false) -> RpgHeroPose {
            RpgHeroPose(action: .idle, view: v, flip: false, moving: moving, step: 1, t: 0.05, aim: v == .front ? .pi / 2 : v == .back ? -.pi / 2 : 0)
        }
        func bytes(_ img: CGImage?) -> Data? { img?.dataProvider?.data as Data? }
        let seed = 3.0 * 0.37
        /// A time at which the hero of id 3 is in shimmer phase `k`, `loops` loops on.
        func at(_ k: Int, loops: Int = 4) -> Double { (Double(k) + 0.5) / rate - seed + Double(loops * n) / rate }

        // Every phase of every piece is a picture of its own (the phase pinned, so nothing else moves), and a phase comes back
        // the same each loop.
        var still: [String] = []
        for (slot, id) in set.sorted(by: { $0.key < $1.key }) {
            for cls in [RpgClass.warrior, .mage, .mechanic] {
                let p = hero(cls, [slot: id])
                // Steps show in a picture only as the puff kicked up behind a walker (from the side: from the front and back the
                // feet hide it); their trail is drawn on the ground.
                for v in RpgHeroView.allCases where slot != "steps" || v == .side {
                    let phases = (0..<n).map { bytes(RpgArt.heroPreview(p, pose: pose(v, moving: slot == "steps"), time: 1, phase: $0)) }
                    if Set(phases.compactMap { $0 }).count != n { still.append("\(id)/\(cls.rawValue)/\(v)") }
                }
            }
        }
        check(still.isEmpty, "every prism piece shimmers: \(n) different pictures a loop in every view (\(still.prefix(4)))")
        // 20 loops (30 s) on, the wing beat is back in step too.
        let full = hero(.warrior, set)
        let same = (0..<n).allSatisfy { k in bytes(RpgArt.heroFrame(full, pose: pose(.front, moving: true), time: at(k))) == bytes(RpgArt.heroFrame(full, pose: pose(.front, moving: true), time: at(k, loops: 24))) }
        check(same, "the shimmer loops: a phase draws the same frame every \(String(format: "%.1f", Double(n) / rate)) s")

        // The phase is part of the frame key for prism wearers only: within one wing beat the clock moves the shimmer on (a new
        // frame) for a prism hero, while anyone else gets the very same cached frame back and no frame is built for them.
        let walking = pose(.side, moving: true)
        // A wing beat (the other clock a frame key reads) starts at `beat`; 0.01 s and 0.32 s into it are 2-3 phases apart.
        let beat = Double(Int((at(0) + seed) * 2.2) + 1) / 2.2 - seed
        let t0 = beat + 0.01, t1 = beat + 0.32
        check(RpgArt.prismPhase(t0, seed: seed) != RpgArt.prismPhase(t1, seed: seed) && Int((t0 + seed) * 2.2) == Int((t1 + seed) * 2.2),
              "two moments in one wing beat but different shimmer phases")
        let others = hero(.archer, set.mapValues { $0.replacingOccurrences(of: "prism", with: "celestial") })
        _ = RpgArt.heroFrame(others, pose: walking, time: t0)
        let before = RpgArt.heroFrameCounts
        let a = RpgArt.heroFrame(others, pose: walking, time: t0), b = RpgArt.heroFrame(others, pose: walking, time: t1)
        check(a != nil && a === b && RpgArt.heroFrameCounts == before, "a hero in no prism piece keeps one cached frame through the shimmer (cache \(before) → \(RpgArt.heroFrameCounts))")
        let prismHero = hero(.archer, set)
        let c0 = RpgArt.heroFrameCounts
        let p0 = RpgArt.heroFrame(prismHero, pose: walking, time: t0), p1 = RpgArt.heroFrame(prismHero, pose: walking, time: t1)
        check(p0 != nil && bytes(p0) != bytes(p1) && RpgArt.heroFrameCounts.plain == c0.plain && RpgArt.heroFrameCounts.prism == c0.prism + 2,
              "a prism hero's frames move with the shimmer and go to the prism cache only (\(c0) → \(RpgArt.heroFrameCounts))")
        // Ghosts and the white flash keep still: a dead prism hero is one picture whatever the phase.
        var ghost = hero(.rogue, set)
        ghost.dead = true
        let ghosts = Set((0..<n).compactMap { bytes(RpgArt.heroFrame(ghost, pose: RpgArt.heroPose(ghost, time: at($0)), time: at($0))) })
        check(ghosts.count == 1, "a ghost in the prism set does not shimmer (\(ghosts.count) different frames over a loop)")
        var winged = ghost, wingless = ghost
        winged.worn = ["wings": "wings_prism", "aura": "aura_prism"]
        wingless.worn = ["aura": "aura_prism"]
        check(bytes(RpgArt.heroFrame(winged, pose: RpgArt.heroPose(winged, time: 1), time: 1)) == bytes(RpgArt.heroFrame(wingless, pose: RpgArt.heroPose(wingless, time: 1), time: 1)),
              "ghosts leave prism wings behind too")

        // Weapons and icons shimmer too; every other skin and icon ignores the phase.
        let sword = RpgItems.item("sword3")!
        let beams = Set((0..<n).compactMap { bytes(RpgArt.heroWeaponImage(sword, cls: .warrior, angle: 0.5, skin: RpgArt.HeroWear.prism, phase: $0)) })
        let plain = (0..<n).map { RpgArt.heroWeaponImage(sword, cls: .warrior, angle: 0.5, skin: 9, phase: $0) }
        check(beams.count == n && plain.allSatisfy { $0 === plain[0] }, "a prism weapon skin has a frame per phase (\(beams.count)); other skins one")
        let me = hero(.monk, [:])
        var iconsStill: [String] = []
        for c in RpgCosmetics.all where c.theme == "prism" || c.theme == "chaos" {
            let icons = (0..<n).map { RpgArt.cosmeticIcon(c, on: me, time: Double($0) / rate) }
            let moving = c.theme == "prism" ? Set(icons.compactMap { bytes($0) }).count == n : icons.allSatisfy { $0 != nil && $0 === icons[0] }
            if !moving { iconsStill.append(c.id) }
        }
        check(iconsStill.isEmpty, "prism icons shimmer in every phase, other icons stay one cached picture (\(iconsStill.prefix(4)))")
        // The 초월 colour of names and the banner steps round the wheel: labels are cached per colour, so a smooth hue would lay
        // out a new label every frame.
        let tints = Set((0..<3000).map { RpgView.ultraColor(Double($0) * 0.0137) })
        check(tints.count <= 24, "the 초월 label colour takes \(tints.count) values over 40 s, so its labels stay cached (≤ 24)")

        // Others see the shimmer in step with the owner: the phase comes from the shared clock and the hero's id.
        var host = hero(.summoner, set, id: 1)
        host.wardrobe = Set(set.values)
        let world = RpgWorld(player: host)
        world.addPlayer(RpgSaveStore.newPlayer(name: "guest", cls: .monk, id: 2))
        world.step(0.1, inputs: [:])
        let mirror = RpgWorld(player: RpgSaveStore.newPlayer(name: "guest", cls: .monk, id: 2))
        mirror.isMirror = true
        mirror.apply(world.snapshot(), localID: 2)
        if let seen = mirror.player(1), let mine = world.player(1) {
            let inStep = (0..<n).allSatisfy { k in
                let t = 2 + Double(k) / rate
                return RpgHeroView.allCases.allSatisfy { bytes(RpgArt.heroPreview(seen, pose: pose($0), time: t)) == bytes(RpgArt.heroPreview(mine, pose: pose($0), time: t)) }
            }
            check(seen.worn == set && inStep, "a remote prism hero shimmers exactly as its owner sees it")
        } else {
            check(false, "the prism hero reaches the mirror")
        }

        // A crowd all in the prism set: once a loop of frames is cached (built straight into pixel buffers), a prism hero draws
        // inside the same 0.1 ms budget as the others, and the prism cache stays under its ceiling.
        guard let screen = KartArt.context(width: 640, height: 360) else { return }
        var crowd: [RpgPlayer] = []
        for k in 0..<24 {
            var q = hero(RpgClass.allCases[k % RpgClass.allCases.count], set, id: 60 + k)
            q.pos = CGPoint(x: 30 + (k % 8) * 75, y: 60 + (k / 8) * 110)
            q.moving = k % 2 == 0
            crowd.append(q)
        }
        @MainActor func drawCrowd(_ frames: Int, start: Double) -> Double {
            let begin = Date()
            for f in 0..<frames {
                let t = start + Double(f) / 60
                for q in crowd { RpgArt.drawHero(screen, q, pose: RpgArt.heroPose(q, time: t, speed: q.moving ? 60 : 0, walked: t * 60), time: t) }
            }
            return Date().timeIntervalSince(begin) / Double(frames * crowd.count) * 1000
        }
        let cold = drawCrowd(180, start: 0)
        let built = RpgArt.heroFrameBuilds
        let warm = drawCrowd(120, start: 7.3)
        let cached = RpgArt.heroFrameCounts.prism
        // Count the builds as well: a cache that only misses now and then (a key that drifts) hides inside the time.
        let rebuilt = Double(RpgArt.heroFrameBuilds.prism - built.prism) / Double(120 * crowd.count)
        print(String(format: "info  prism crowd: %.3f ms a hero while its frames are first built, %.3f ms after (%.3f frames built a draw); %d prism frames cached (%d looks)",
                     cold, warm, rebuilt, cached, RpgClass.allCases.count))
        check(warm < 0.1, "a hero in the full prism set draws in \(String(format: "%.3f", warm)) ms once its shimmer is cached (budget 0.1 ms)")
        check(rebuilt < 0.05 && RpgArt.heroFrameBuilds.plain == built.plain, "once cached, prism heroes rarely build a frame (\(String(format: "%.3f", rebuilt)) a draw) and never one of anyone else's")
        check(cached <= RpgArt.prismFrameCeiling + 1, "the prism frame cache stays under its ceiling (\(cached) ≤ \(RpgArt.prismFrameCeiling))")
    }
}

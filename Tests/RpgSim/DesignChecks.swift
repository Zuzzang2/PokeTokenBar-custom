import CoreGraphics
import Foundation
@testable import PokeTokenBar

/// Hero art (`RpgCharacterArt`): every class has every frame at one size, weapons turn, the customization `look`
/// saves, clamps and survives old saves, and the animation state reaches mirrors through the snapshot.
func designChecks() {
    check(RpgLook.hair.count >= 8 && RpgLook.skin.count >= 4 && RpgLook.accent.count >= 6, "look offers 8+ hair colours, 4+ skin tones, 6+ accents")

    MainActor.assumeIsolated {
        // Frames: every class × action × view × walking or not, mirrored too, plain and fully geared (helmet, 4차 wings).
        var frames = 0, wrongSize = 0, missing = 0
        for cls in RpgClass.allCases {
            var geared = RpgSaveStore.newPlayer(name: "g", cls: cls, id: 7)
            (geared.armor, geared.helmet, geared.boots, geared.job, geared.tier) = ("armor11", "helmet11", "boots11", 1, 3)
            for p in [RpgSaveStore.newPlayer(name: "t", cls: cls, id: 3), geared] {
                for action in RpgHeroPose.Action.allCases {
                    for view in RpgHeroView.allCases {
                        for (moving, step) in [(false, 0), (true, 0), (true, 1), (true, 2), (true, 3)] {
                            let pose = RpgHeroPose(action: action, view: view, flip: step == 2, moving: moving, step: step, t: 0.05, aim: 0.3)
                            frames += 1
                            guard let img = RpgArt.heroFrame(p, pose: pose, time: 1) else { missing += 1; continue }
                            if img.width != RpgArt.heroSize || img.height != RpgArt.heroSize { wrongSize += 1 }
                        }
                    }
                }
            }
        }
        check(missing == 0 && wrongSize == 0, "all \(frames) hero frames exist at \(RpgArt.heroSize)×\(RpgArt.heroSize) (missing \(missing), wrong size \(wrongSize))")

        // The walk cycle and a swing really animate: neighbouring frames differ.
        let w = RpgSaveStore.newPlayer(name: "w", cls: .warrior, id: 3)
        let walk = (0..<4).compactMap { RpgArt.heroFrame(w, pose: RpgHeroPose(action: .idle, view: .side, flip: false, moving: true, step: $0, t: 0, aim: 0), time: 1)?.dataProvider?.data as Data? }
        check(walk.count == 4 && Set(walk).count >= 3, "the side walk cycle has distinct frames")
        let swing = [0.0, 0.06, 0.12].compactMap { t in
            RpgArt.heroPreview(w, pose: RpgHeroPose(action: .attack, view: .side, flip: false, moving: false, step: 0, t: t, aim: 0), time: 1)?.dataProvider?.data as Data?
        }
        check(swing.count == 3 && Set(swing).count == 3, "a sword swing moves the blade from frame to frame")
        let looks = [[0, 0, 0], [5, 3, 4]].compactMap { look -> Data? in
            let p = RpgSaveStore.newPlayer(name: "l", cls: .mage, id: 3, look: look)
            return RpgArt.heroFrame(p, pose: RpgHeroPose(action: .idle, view: .front, flip: false, moving: false, step: 0, t: 0, aim: 0), time: 1)?.dataProvider?.data as Data?
        }
        check(looks.count == 2 && looks[0] != looks[1], "hair, skin and accent change the drawn hero")

        // Every weapon turns to every angle step (bows also with the string drawn).
        var weaponFail = 0
        for item in RpgItems.all {
            guard case .weapon(let cls) = item.kind else { continue }
            for step in stride(from: 0, to: RpgArt.heroWeaponSteps, by: 4) {
                let angle = Double(step) / Double(RpgArt.heroWeaponSteps) * 2 * .pi
                if RpgArt.heroWeaponImage(item, cls: cls, angle: angle) == nil { weaponFail += 1 }
                if cls == .archer, RpgArt.heroWeaponImage(item, cls: cls, angle: angle, draw: 3) == nil { weaponFail += 1 }
            }
        }
        check(weaponFail == 0, "every weapon is drawable in the hand at every angle (\(weaponFail) failed)")
        let weaponHoles = RpgItems.all.compactMap { item -> String? in
            guard case .weapon(let cls) = item.kind else { return nil }
            let holes = RpgArt.heroWeaponHoles(item, cls: cls)
            return holes.isEmpty ? nil : "\(item.id) \(String(holes.sorted()))"
        }
        check(weaponHoles.isEmpty, "every held weapon letter has a colour (\(weaponHoles.prefix(3)))")
        var bodyHoles: [String] = []
        for cls in RpgClass.allCases {
            for job in 0...2 where job == 0 || RpgJobs.def(cls, job) != nil {
                var p = RpgSaveStore.newPlayer(name: "h", cls: cls, id: 3, look: [10, 4, 9])
                (p.armor, p.helmet, p.boots, p.job, p.tier) = ("armor11", "helmet11", "boots11", job, job == 0 ? 0 : 3)
                let holes = RpgArt.heroPaletteHoles(p)
                if !holes.isEmpty { bodyHoles.append("\(cls.rawValue)/\(job) \(String(holes.sorted()))") }
                p.armor = nil; p.helmet = nil; p.boots = nil
                let bare = RpgArt.heroPaletteHoles(p)
                if !bare.isEmpty { bodyHoles.append("\(cls.rawValue)/\(job) bare \(String(bare.sorted()))") }
            }
        }
        check(bodyHoles.isEmpty, "every body-part letter has a colour for every class, job and gear (\(bodyHoles.prefix(3)))")
        check(RpgClass.allCases.allSatisfy { RpgArt.heroHeight($0) >= 20 } && RpgArt.heroHeight(.mage) > RpgArt.heroHeight(.warrior),
              "hero heights cover hats (name tags and bubbles sit above them)")
    }

    // Poses come from shared fields, so they match on the host and on every mirror.
    var p = RpgSaveStore.newPlayer(name: "pose", cls: .rogue, id: 1)
    func pose(_ time: Double = 10, speed: Double = 0) -> RpgHeroPose { MainActor.assumeIsolated { RpgArt.heroPose(p, time: time, speed: speed, walked: 15) } }
    check(pose().action == .idle && !pose().moving, "standing still is idle")
    p.moving = true
    check(pose().moving && pose().step == 2, "walking drives the walk cycle from distance walked")
    p.facing = CGVector(dx: 0, dy: -1)
    check(pose().view == .back, "facing up shows the back")
    p.facing = CGVector(dx: 0, dy: 1)
    check(pose().view == .front, "facing down shows the front")
    p.facing = CGVector(dx: -1, dy: 0); p.facingRight = false
    check(pose().view == .side && pose().flip, "facing left mirrors the side view")
    p.attackAt = 9.9
    check(pose().action == .attack && abs(pose().t - 0.1) < 1e-9 && pose().moving, "an attack plays over the walk")
    p.castAt = 9.95
    check(pose().action == .cast, "a newer skill cast wins over the swing")
    check(pose(speed: 400).action == .dash, "dash speed shows the dash pose")
    p.hurtFlash = 0.15
    check(pose().action == .hurt, "a fresh hit flinches")
    p.dead = true
    check(pose().action == .dead && !pose().moving, "the fallen float as ghosts")

    // look: clamped on load, saved, and absent on old saves.
    check(RpgLook.clean(nil, cls: .archer) == RpgLook.defaults(.archer), "no look means the class default")
    check(RpgLook.clean([1], cls: .monk) == [1] + RpgLook.defaults(.monk).suffix(2), "a short look keeps its part and defaults the rest")
    let wild = RpgLook.clean([999, -5, 2, 7, 8], cls: .cleric)
    check(wild == [RpgLook.hair.count - 1, 0, 2], "out-of-range parts are clamped and extras dropped (\(wild))")
    let made = RpgSaveStore.newPlayer(name: "look", cls: .summoner, id: 1, look: [4, 3, 5])
    var save = RpgSaveStore.snapshot(made)
    check(save.look == [4, 3, 5], "the snapshot saves the look")
    let decoded = (try? JSONDecoder().decode(RpgSaveData.self, from: JSONEncoder().encode(save)))
    check(decoded.map { RpgSaveStore.player(from: $0, id: 1).look } == [4, 3, 5], "the look round-trips through the save JSON")
    save.look = [77, 77, -1]
    check(RpgSaveStore.player(from: save, id: 1).look == [RpgLook.hair.count - 1, RpgLook.skin.count - 1, 0], "a tampered look is clamped on load")
    RpgSaveStore.save(RpgSaveStore.snapshot(made), slot: 3)
    var onDisk: [Int]?
    if case .ok(let d) = RpgSaveStore.load(slot: 3) { onDisk = d.look }
    check(onDisk == [4, 3, 5], "the look survives a save file")
    RpgSaveStore.delete(slot: 3)
    var old = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(RpgSaveStore.snapshot(made)))) as? [String: Any] ?? [:]
    old.removeValue(forKey: "look")
    let oldData = (try? JSONSerialization.data(withJSONObject: old)).flatMap { try? JSONDecoder().decode(RpgSaveData.self, from: $0) }
    check(oldData != nil && oldData?.look == nil && oldData.map { RpgSaveStore.player(from: $0, id: 1).look } == RpgLook.defaults(.summoner),
          "an old save without a look loads with the class default")

    // Mirrors: look, gear and the swing reach other players through the snapshot; old snapshots still decode.
    var hostHero = RpgSaveStore.newPlayer(name: "host", cls: .warrior, id: 1, look: [2, 1, 3])
    (hostHero.armor, hostHero.helmet, hostHero.boots, hostHero.ring) = ("armor7", "helmet6", "boots5", "ring6")
    let host = RpgWorld(player: hostHero)
    host.addPlayer(RpgSaveStore.newPlayer(name: "guest", cls: .mage, id: 2))
    host.step(0.1, inputs: [1: RpgInput(move: .zero, attack: true)])
    let snap = host.snapshot()
    let mirror = RpgWorld(player: RpgSaveStore.newPlayer(name: "guest", cls: .mage, id: 2))
    mirror.isMirror = true
    mirror.apply(snap, localID: 2)
    let seen = mirror.player(1)
    check(seen?.look == [2, 1, 3] && seen?.armor == "armor7" && seen?.helmet == "helmet6" && seen?.boots == "boots5" && seen?.ring == "ring6",
          "others see your look and gear")
    let seenPose = seen.map { s in MainActor.assumeIsolated { RpgArt.heroPose(s, time: mirror.time) } }
    check(seenPose?.action == .attack, "others see your swing")
    var bare = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(snap))) as? [String: Any] ?? [:]
    if var players = bare["players"] as? [[String: Any]] {
        for k in players.indices { for key in ["look", "armor", "helmet", "boots", "ring", "amulet", "attackAgo", "castAgo", "hurt"] { players[k].removeValue(forKey: key) } }
        bare["players"] = players
    }
    let oldSnap = (try? JSONSerialization.data(withJSONObject: bare)).flatMap { try? JSONDecoder().decode(RpgSnapshot.self, from: $0) }
    check(oldSnap != nil, "a snapshot from an older build still decodes")
    if let oldSnap {
        mirror.apply(oldSnap, localID: 2)
        check(mirror.player(1)?.look == RpgLook.defaults(.warrior), "an older peer's hero shows the class default look")
    }
}

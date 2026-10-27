import CoreGraphics
import Foundation
@testable import PokeTokenBar

/// Skill effects (RpgSkillFX.swift, RpgSkillLooks.swift): every skill and basic attack has its own look; casts stamp what
/// they make and the look — not the generic fallback — draws it; stamps survive the wire and older peers ignore them;
/// unstamped effects still draw; a party spamming skills stays inside the frame budget.
func fxChecks() {
    let skills = RpgSkills.all + RpgJobs.skills + RpgTiers.skills
    let styles = skills.map(\.id) + RpgClass.allCases.map { "basic:" + $0.rawValue }
    check(skills.count == 160 && Set(skills.map(\.id)).count == 160, "160 distinct skills to give looks to (\(skills.count))")

    MainActor.assumeIsolated {
        let missing = styles.filter { RpgArt.looks[$0] == nil }
        check(missing.isEmpty, "every skill and basic attack has a registered look (missing: \(missing))")
        var shared: [String] = []
        for cls in RpgClass.allCases {
            var seen: [Int: String] = [:]
            for s in styles where s == "basic:" + cls.rawValue || RpgSkills.def(s)?.cls == cls {
                guard let key = RpgArt.looks[s]?.pal.key else { continue }
                if let other = seen[key] { shared.append("\(other)/\(s)") } else { seen[key] = s }
            }
        }
        check(shared.isEmpty, "no two looks of one class share a palette (\(shared))")
    }

    // Cast everything once: what each cast makes carries its own style and its look draws it.
    var made: [String: Int] = [:], unstamped: Set<String> = [], fellBack: Set<String> = [], noArt: Set<String> = []
    var cost: [(String, Double)] = []
    MainActor.assumeIsolated {
        let probe = KartArt.context(width: 64, height: 64)!
        for s in styles {
            let w = fxWorld(s)
            fxCast(w, s)
            var worst = 0.0
            for frame in 0..<150 {
                if frame % 3 == 0 {
                    for e in w.fx {
                        guard let st = e.stamp else { unstamped.insert("\(s): \(e.kind)"); continue }
                        guard st.style == s else { continue }
                        made[s, default: 0] += 1
                        if !RpgArt.drawStyled(probe, e, time: w.time) { fellBack.insert("\(s): \(e.kind)") }
                    }
                    for shot in w.shots where shot.stamp?.style == s {
                        made[s, default: 0] += 1
                        if RpgArt.looks[s]?.shot == nil { noArt.insert("\(s) shot") }
                    }
                    for t in w.traps where t.stamp?.style == s {
                        made[s, default: 0] += 1
                        if RpgArt.looks[s]?.trap == nil { noArt.insert("\(s) trap") }
                    }
                    worst = max(worst, fxDrawTime(w))
                }
                w.step(1.0 / 60, inputs: [:])
            }
            cost.append((s, worst))
        }
    }
    let silent = styles.filter { made[$0, default: 0] == 0 }
    check(silent.isEmpty, "every skill and basic attack makes something stamped with its style (none from: \(silent))")
    check(unstamped.isEmpty, "nothing a cast makes goes unstamped (\(unstamped.sorted().prefix(6)))")
    check(fellBack.isEmpty, "every stamped effect is drawn by its skill's look, none falls back to the generic one (\(fellBack.sorted().prefix(8)))")
    check(noArt.isEmpty, "stamped shots and traps have their skill's art (\(noArt.sorted()))")
    let slowest = cost.sorted { $0.1 > $1.1 }.prefix(8).map { "\($0.0) \(String(format: "%.2f", $0.1 * 1000))ms" }
    print("info  slowest single casts to draw (worst frame, debug build): \(slowest.joined(separator: ", "))")

    // Template skills take their blast from the weapon when they have no element of their own (ice → .ice, thunder and
    // holy → .strike): every kind a template can make is drawn by its look.
    MainActor.assumeIsolated {
        let probe = KartArt.context(width: 64, height: 64)!
        var missed: [String] = []
        for s in skills {
            guard let t = s.fx else { continue }
            let kinds: [RpgFX.Kind] = switch t.shape {
            case .zone, .line: [.burst(radius: 20), .ice(radius: 20), .strike]
            case .rain: [.telegraph(radius: 30), .meteor(radius: 30)]
            case .chain: [.slash(angle: 1, radius: 16)]
            case .buff: [.levelUp]
            case .shot, .trap, .turret: []
            }
            for k in kinds {
                let e = RpgFX(kind: k, map: .field, pos: CGPoint(x: 30, y: 30), element: .base, start: 0, duration: 0.5, stamp: RpgFXStamp(s.id, dir: 0, from: .zero))
                if !RpgArt.drawStyled(probe, e, time: 0.2) { missed.append("\(s.id): \(k)") }
            }
        }
        check(missed.isEmpty, "every effect kind a template skill can make is drawn by its look (\(missed.prefix(6)))")

        // At a map's corner effects reach negative coordinates (a vine seeded by its x crashed there once):
        // every look draws every kind of effect, its shots and its traps at the origin.
        let kinds: [RpgFX.Kind] = [.slash(angle: 2, radius: 12), .burst(radius: 30), .ice(radius: 30), .meteor(radius: 30), .rain(radius: 30), .telegraph(radius: 30),
                                   .strike, .levelUp, .spark(crit: true), .chain([CGPoint(x: 0, y: 0), CGPoint(x: -40, y: -10)])]
        var drawn = 0
        for s in styles {
            for k in kinds {
                for t in [0.05, 0.5, 0.95] {
                    let e = RpgFX(kind: k, map: .field, pos: .zero, element: .fire, start: 0, duration: 1, stamp: RpgFXStamp(s, dir: 3, from: CGPoint(x: -20, y: -20)))
                    RpgArt.drawEffects(probe, [e], map: .field, time: t, ground: true)
                    RpgArt.drawEffects(probe, [e], map: .field, time: t)
                    drawn += 1
                }
            }
            RpgArt.drawShots(probe, [RpgShot(pos: .zero, vel: CGVector(dx: -200, dy: 50), map: .field, fromPlayer: true, ownerID: 1, damage: 1, element: .ice, kind: .bigArrow, life: 1,
                                             stamp: RpgFXStamp(s, dir: 3, from: CGPoint(x: -20, y: -20)))], map: .field, time: 3)
            RpgArt.drawTrap(probe, RpgTrap(map: .field, pos: .zero, ownerID: 1, damage: 1, expires: 9, armedAt: 0, turret: true, nextShot: 0, stamp: RpgFXStamp(s, dir: 3, from: .zero)), time: 1)
        }
        check(drawn == styles.count * kinds.count * 3, "every look draws every kind of effect, shot and trap at a map corner without crashing (\(drawn))")
    }

    // A kill during a skill can set off a level-up or an achievement: that is the kill's effect, drawn plain.
    do {
        let w = fxWorld("w_whirl", level: 1, dummyHP: 1)
        fxCast(w, "w_whirl")
        for _ in 0..<5 { w.step(1.0 / 60, inputs: [:]) }
        let levelUps = w.fx.filter { if case .levelUp = $0.kind { true } else { false } }
        check((w.player(1)?.level ?? 1) > 1 && !levelUps.isEmpty && levelUps.allSatisfy { $0.stamp == nil },
              "a level-up set off by a skill's kill is not drawn as that skill (\(levelUps.map { $0.stamp?.style ?? "plain" }))")
        check(w.fx.contains { $0.stamp?.style == "w_whirl" }, "…while the skill's own effects keep its style")
    }
    do {
        let w = fxWorld("c_heal")
        fxCast(w, "c_heal")
        check(w.fx.contains { $0.stamp?.style == "c_heal" && $0.stamp?.heal == true }, "heals are marked as the heal part of their skill")
        let q = fxWorld("w_quake")
        fxCast(q, "w_quake")
        for _ in 0..<30 { q.step(1.0 / 60, inputs: [:]) }
        let seqs = Set(q.fx.compactMap { $0.stamp?.style == "w_quake" && !$0.kind.isSpark ? $0.stamp?.seq : nil })
        check(seqs.count == 7, "delayed hits keep their order in the cast (seqs \(seqs.sorted()))")
        let f = fxWorld("j_frenzy")
        fxCast(f, "j_frenzy")
        for _ in 0..<20 { f.step(1.0 / 60, inputs: [:]) }
        check(f.fx.contains { if case .slash = $0.kind { $0.stamp?.style == "j_frenzy" } else { false } }, "광기's cyclone is drawn as 광기, not 회오리검")
    }

    // The wire: stamps round-trip, older peers ignore them, an older host's effects arrive unstamped.
    do {
        let stamp = RpgFXStamp("w_whirl", dir: 1.23456, from: CGPoint(x: 10.4, y: 20.6))
        check(stamp.dir == 1.23 && stamp.from == CGPoint(x: 10, y: 21), "stamps are rounded for the wire")
        var healing = stamp
        healing.heal = true
        healing.seq = 3
        let e = RpgFX(kind: .burst(radius: 30), map: .field, pos: .zero, element: .fire, start: 1, duration: 0.4, stamp: healing)
        let shot = RpgShot(pos: .zero, vel: CGVector(dx: 1, dy: 0), map: .field, fromPlayer: true, ownerID: 1, damage: 1, element: .base, kind: .arrow, life: 1, stamp: stamp)
        let trap = RpgTrap(map: .field, pos: .zero, ownerID: 1, damage: 1, expires: 9, armedAt: 0, turret: true, nextShot: 0, stamp: stamp)
        let snap = RpgSnapshot(time: 1, players: [], mobs: [], shots: [shot], fx: [e], floaters: [], drops: [], traps: [trap], toasts: [], chat: [], shake: 0)
        let data = try! JSONEncoder().encode(RpgNetMessage.snapshot(snap))
        if case .snapshot(let back)? = try? JSONDecoder().decode(RpgNetMessage.self, from: data) {
            check(back.fx.first?.stamp == healing && back.shots.first?.stamp == stamp && back.traps.first?.stamp == stamp, "stamps survive a snapshot round trip")
        } else {
            check(false, "a stamped snapshot decodes")
        }
        struct OldFX: Decodable { let kind: RpgFX.Kind, map: RpgMapID, pos: CGPoint, element: RpgElement, start: Double, duration: Double }
        struct OldShot: Decodable { let pos: CGPoint, vel: CGVector, map: RpgMapID, kind: RpgShot.Kind, life: Double }
        struct OldTrap: Decodable { let map: RpgMapID, pos: CGPoint, expires: Double, turret: Bool? }
        struct OldSnapshot: Decodable { let time: Double, fx: [OldFX], shots: [OldShot], traps: [OldTrap] }
        check((try? JSONDecoder().decode(OldSnapshot.self, from: JSONEncoder().encode(snap)))?.fx.count == 1, "an older peer reads a stamped snapshot")
        let plain = RpgFX(kind: .burst(radius: 30), map: .field, pos: .zero, element: .fire, start: 1, duration: 0.4)
        let plainJSON = String(data: try! JSONEncoder().encode(plain), encoding: .utf8) ?? ""
        check(!plainJSON.contains("stamp") && (try? JSONDecoder().decode(RpgFX.self, from: Data(plainJSON.utf8)))?.stamp == nil,
              "an unstamped effect costs no bytes and an older host's effects arrive unstamped")
    }

    // Unstamped effects (monsters, pets, an older host) and unknown styles (a newer host) draw the generic look.
    MainActor.assumeIsolated {
        let kinds: [RpgFX.Kind] = [.slash(angle: 0, radius: 11), .burst(radius: 20), .ice(radius: 20), .meteor(radius: 20), .chain([CGPoint(x: 20, y: 40), CGPoint(x: 70, y: 40)]),
                                   .spark(crit: true), .levelUp, .telegraph(radius: 20), .rain(radius: 20), .strike]
        var blank: [String] = []
        for k in kinds {
            for style in [nil, "zz_from_a_newer_build"] as [String?] {
                let ctx = KartArt.context(width: 100, height: 100)!
                let e = RpgFX(kind: k, map: .field, pos: CGPoint(x: 50, y: 70), element: .fire, start: 0, duration: 1, stamp: style.map { RpgFXStamp($0, dir: 0, from: .zero) })
                RpgArt.drawEffects(ctx, [e], map: .field, time: 0.3)
                if !fxInked(ctx) { blank.append("\(k) \(style ?? "unstamped")") }
            }
        }
        let shotKinds: [RpgShot.Kind] = [.arrow, .orb, .bigArrow, .mobArrow, .slimeBall, .bossOrb, .poisonArrow]
        for k in shotKinds {
            let ctx = KartArt.context(width: 100, height: 100)!
            RpgArt.drawShots(ctx, [RpgShot(pos: CGPoint(x: 50, y: 50), vel: CGVector(dx: 100, dy: 0), map: .field, fromPlayer: true, ownerID: 1, damage: 1, element: .ice, kind: k, life: 1)], map: .field, time: 0)
            if !fxInked(ctx) { blank.append("shot \(k)") }
        }
        check(blank.isEmpty, "unstamped and unknown-style effects and shots still draw (blank: \(blank))")
    }

    // Four heroes spamming every skill they have, attacking all the while.
    MainActor.assumeIsolated {
        let w = fxWorld("t3_ma1a", allSkills: true)
        for (k, cls) in [RpgClass.cleric, .summoner, .mechanic].enumerated() {
            var p = RpgSaveStore.newPlayer(name: "fx\(k)", cls: cls, id: k + 2)
            p.level = 90; p.job = k % 2 + 1; p.tier = 3; p.mp = 1e6
            p.map = .field; p.pos = w.player(1)!.pos; p.facing = CGVector(dx: k % 2 == 0 ? 1 : -1, dy: 0)
            for s in p.skillList { p.skills[s.id] = 5 }
            p.slots = Array(p.skillList.suffix(8).map { Optional($0.id) })
            w.addPlayer(p)
        }
        var times: [Double] = [], peakFX = 0, peakShots = 0
        var inputs: [Int: RpgInput] = [:]
        for id in 1...4 { var i = RpgInput(); i.attack = true; i.slots = Set(0..<8); inputs[id] = i }
        for frame in 0..<360 {
            w.step(1.0 / 60, inputs: inputs)
            peakFX = max(peakFX, w.fx.count); peakShots = max(peakShots, w.shots.count)
            if frame % 2 == 0 { times.append(fxDrawTime(w)) }
        }
        let avg = times.reduce(0, +) / Double(max(1, times.count)), worst = times.max() ?? 0
        print("info  party of four spamming skills: up to \(peakFX) effects and \(peakShots) shots; effects draw \(String(format: "%.2f", avg * 1000))ms a frame on average, \(String(format: "%.2f", worst * 1000))ms at worst (debug build)")
        check(avg < 0.008, "a party spamming skills draws its effects inside the frame budget (avg \(String(format: "%.2f", avg * 1000))ms < 8ms, debug build)")
        let snapBytes = fxSnapshotBytes(w)
        print("info  that party's busiest snapshot: \(snapBytes.stamped) bytes compressed with stamps, \(snapBytes.plain) without")
        check(Double(snapBytes.stamped) < Double(snapBytes.plain) * 1.35 + 200, "stamps add little to a snapshot (\(snapBytes.stamped) vs \(snapBytes.plain) bytes)")
    }
}

/// A field with a level-`level` hero ready to cast `style` (job and tier set for 2차·3차·4차 skills), facing right, and
/// training dummies frozen in front of and around it.
func fxWorld(_ style: String, level: Int = 90, dummyHP: Double = 1e9, allSkills: Bool = false) -> RpgWorld {
    let basic = style.hasPrefix("basic:")
    let cls = basic ? RpgClass(rawValue: String(style.dropFirst(6)))! : RpgSkills.def(style)!.cls
    var p = RpgSaveStore.newPlayer(name: "fx", cls: cls, id: 1)
    p.level = level
    if level == 1 { p.xp = RpgMaps.xpNeeded(1) - 1 }
    if style.hasPrefix("j_") { p.job = RpgJobs.all.first { $0.skills.contains(style) }?.job ?? 1 }
    if style.hasPrefix("t2_") || style.hasPrefix("t3_") { p.job = Int(String(Array(style)[5])) ?? 1 }
    p.tier = p.job > 0 ? 3 : 0
    if !basic { p.skills[style] = 5; p.slots[0] = style }
    if allSkills {
        for s in p.skillList { p.skills[s.id] = 5 }
        p.slots = Array(p.skillList.suffix(8).map { Optional($0.id) })
    }
    p.mp = 1e6
    p.map = .field
    p.pos = fxOpenSpot
    p.facing = CGVector(dx: 1, dy: 0)
    p.facingRight = true
    let w = RpgWorld(player: p)
    w.step(1.0 / 60, inputs: [:])
    let snap = w.snapshot()
    let spots: [(Double, Double)] = [(21, 1), (48, -14), (62, 14), (100, 0), (30, 30), (-34, 10), (130, -12)]
    let dummies = spots.enumerated().map { k, s in
        RpgMobPub(id: 900 + k, def: "golem", map: .field, x: Double(p.pos.x) + s.0, y: Double(p.pos.y) + s.1, hp: dummyHP, dead: false, diedAgo: 99,
                  airborne: false, jx: nil, jy: nil, phaseLeft: 0, hurt: false, stunLeft: 999, slowLeft: 0, dot: nil, windup: false, facingRight: false, summoned: false)
    }
    w.apply(RpgSnapshot(time: snap.time, players: snap.players, mobs: dummies, shots: [], fx: [], floaters: [], drops: [], traps: [], toasts: [], chat: [], shake: 0), localID: 1)
    return w
}

func fxCast(_ w: RpgWorld, _ style: String) {
    var input = RpgInput()
    if style.hasPrefix("basic:") { input.attack = true } else { input.slots = [0] }
    w.step(1.0 / 60, inputs: [1: input])
}

/// The most open stand on the field (room to see a whole effect).
let fxOpenSpot: CGPoint = {
    let m = RpgMap(RpgMaps.def(.field))
    var best = CGPoint(x: m.pixelSize.width / 2, y: m.pixelSize.height / 2), bestScore = -1
    for ty in 4..<(m.height - 4) {
        for tx in 4..<(m.width - 8) {
            var score = 0
            for dy in -4...3 { for dx in -4...8 where m.canStand(RpgMap.center(RpgTile(x: tx + dx, y: ty + dy))) { score += 1 } }
            if score > bestScore { bestScore = score; best = RpgMap.center(RpgTile(x: tx, y: ty)) }
        }
    }
    return best
}()

/// Seconds to draw every effect, shot and trap of player 1's map into a frame-sized bitmap (ground marks included).
@MainActor func fxDrawTime(_ w: RpgWorld) -> Double {
    guard let me = w.player(1) else { return 0 }
    if fxFrame == nil { fxFrame = KartArt.context(width: 400, height: 260) }
    guard let f = fxFrame else { return 0 }
    f.clear(CGRect(x: 0, y: 0, width: 400, height: 260))
    f.saveGState()
    f.translateBy(x: 200 - me.pos.x, y: 150 - me.pos.y)
    let t0 = CFAbsoluteTimeGetCurrent()
    for t in w.traps where t.map == me.map { RpgArt.drawTrap(f, t, time: w.time) }
    RpgArt.drawEffects(f, w.fx, map: me.map, time: w.time, ground: true)
    RpgArt.drawShots(f, w.shots, map: me.map, time: w.time)
    RpgArt.drawEffects(f, w.fx, map: me.map, time: w.time)
    let dt = CFAbsoluteTimeGetCurrent() - t0
    f.restoreGState()
    return dt
}

@MainActor var fxFrame: CGContext?

/// Whether anything was drawn into the bitmap.
func fxInked(_ ctx: CGContext) -> Bool {
    guard let data = ctx.data else { return false }
    let n = ctx.bytesPerRow * ctx.height
    let bytes = data.bindMemory(to: UInt8.self, capacity: n)
    for i in stride(from: 3, to: n, by: 4) where bytes[i] > 0 { return true }
    return false
}

/// LZFSE-compressed size of the world's snapshot as sent, and the same with every stamp removed.
func fxSnapshotBytes(_ w: RpgWorld) -> (stamped: Int, plain: Int) {
    let s = w.snapshot()
    func packed(_ snap: RpgSnapshot) -> Int {
        let raw = (try? JSONEncoder().encode(RpgNetMessage.snapshot(snap))) ?? Data()
        return ((try? (raw as NSData).compressed(using: .lzfse)) as Data?)?.count ?? raw.count
    }
    let plain = RpgSnapshot(time: s.time, players: s.players, mobs: s.mobs, shots: s.shots.map { var x = $0; x.stamp = nil; return x },
                            fx: s.fx.map { RpgFX(kind: $0.kind, map: $0.map, pos: $0.pos, element: $0.element, start: $0.start, duration: $0.duration) },
                            floaters: s.floaters, drops: s.drops, traps: s.traps.map { var x = $0; x.stamp = nil; return x }, toasts: s.toasts, chat: s.chat,
                            shake: s.shake, graves: s.graves, pets: s.pets, towerFloor: s.towerFloor)
    return (packed(s), packed(plain))
}

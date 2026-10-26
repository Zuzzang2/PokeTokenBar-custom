import Foundation
@testable import PokeTokenBar

// Plain assertions: any failure prints and exits non-zero.
var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "ok   " : "FAIL ", what)
    if !ok { failures += 1 }
}

func world(level: Int = 1, cls: RpgClass = .warrior) -> RpgWorld {
    var p = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
    p.level = level
    return RpgWorld(player: p)
}


// MARK: hunting helpers
/// A world with the player standing at the field's entrance (player 2 joins so the field's monsters spawn).
func fieldWorld(level: Int, cls: RpgClass = .warrior) -> (RpgWorld, Int) {
    let w = world(level: level, cls: cls)
    var p = RpgSaveStore.newPlayer(name: "hunter", cls: cls, id: 2)
    p.level = level
    p.map = .field
    p.pos = RpgMap.center(RpgMaps.def(.field).portals.first!.arrive)
    w.addPlayer(p)
    return (w, 2)
}

/// Walks toward the nearest living monster and attacks for `seconds`; returns the highest combo seen.
@discardableResult
func hunt(_ w: RpgWorld, id: Int, seconds: Double) -> Int {
    var t = 0.0, best = 0
    while t < seconds {
        guard let me = w.player(id) else { break }
        let target = (w.mobs[me.map] ?? []).filter { !$0.dead }
            .min { hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < hypot($1.pos.x - me.pos.x, $1.pos.y - me.pos.y) }
        var input = RpgInput()
        if let target {
            let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
            // Report positions like a remote player so the walk cannot snag on scenery: hop up to 80px per step.
            let hop = min(d, 80)
            input.pos = CGPoint(x: me.pos.x + dx / d * (d > 80 ? hop : max(0, d - 10)), y: me.pos.y + dy / d * (d > 80 ? hop : max(0, d - 10)))
            input.facing = CGVector(dx: dx / d, dy: dy / d)
            input.attack = true
        }
        w.step(1.0 / 30, inputs: [id: input])
        best = max(best, w.player(id)?.combo ?? 0)
        t += 1.0 / 30
    }
    return best
}

func idle(_ w: RpgWorld, seconds: Double) {
    var t = 0.0
    while t < seconds { w.step(1.0 / 30, inputs: [:]); t += 1.0 / 30 }
}

// MARK: basics
let basic = world()
basic.step(0.05, inputs: [:])
check(basic.player(1)?.level == 1, "world steps")

let advanced = world(level: 20)
advanced.perform(.advance(1), for: 1)
check(advanced.player(1)?.job == 1 && advanced.player(1)?.skills["j_bash"] != nil, "advance at Lv20 teaches the first job skill")
advanced.perform(.advance(2), for: 1)
check(advanced.player(1)?.job == 1, "a job cannot be changed")
let early = world(level: 19)
early.perform(.advance(1), for: 1)
check(early.player(1)?.job == 0, "no advancement below Lv20")


// MARK: combo
do {
    let (w, id) = fieldWorld(level: 30)
    let best = hunt(w, id: id, seconds: 40)
    check(best >= 3, "combo builds while killing (best \(best))")
    idle(w, seconds: RpgWorld.comboWindow + 1)
    check(w.player(id)?.combo == 0, "combo resets after the window")
    check(RpgWorld.comboBonus(9) == 0 && RpgWorld.comboBonus(10) == 0.05 && RpgWorld.comboBonus(500) == 0.5, "combo bonus steps by 5% per 10 and caps at 50%")
}

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")

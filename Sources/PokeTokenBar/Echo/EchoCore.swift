import Foundation

// SPIKE: time-loop puzzle simulation for the 메아리 mini game. Pure and deterministic: `step` returns a new
// world and never touches AppKit, so every level's solution can be replayed in tests.
//
// Rewinding turns the run you just played into an echo that replays it frame for frame. Echoes press
// plates and are one-way platforms (walk through them, land on their heads); doors open only while every
// plate of their group is held. World units: 30 per tile, 32x18 tiles.

struct EchoRect: Equatable {
    var x: Double, y: Double, w: Double, h: Double

    func overlaps(_ o: EchoRect) -> Bool {
        x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y
    }
}

struct EchoFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var facing: Int
}

enum EchoEnd: String, Codable { case dead, rewind, timeout, won }

struct EchoRecording: Codable, Equatable {
    var frames: [EchoFrame]
    var end: EchoEnd
}

struct EchoInput: Equatable {
    var left = false, right = false, jump = false
    static let none = EchoInput()
}

struct EchoLevel {
    struct Plate { let group: Character; let rect: EchoRect }
    struct Door { let group: Character; let tx: Int; let ty: Int; let rect: EchoRect }

    let name: String
    let title: String
    let hint: String
    /// Frames per loop.
    let limit: Int
    let maxEchoes: Int
    let cells: [[Character]]
    let plates: [Plate]
    let doors: [Door]
    let spikes: [EchoRect]
    let spawn: EchoFrame
    let exit: EchoRect
}

struct EchoPlayer: Equatable {
    var x: Double, y: Double
    var vx = 0.0, vy = 0.0
    var facing = 1
    var ground = true
    /// Echo index stood on last frame, -1 for none.
    var ride = -1
    var coyote = 0, buffer = 0
    var held = false, cut = false
}

enum EchoStatus: Equatable { case play, dead, won, timeout }
enum EchoCause: Equatable { case spike, crush }

struct EchoWorld {
    let level: EchoLevel
    let echoes: [EchoRecording]
    var frame = 0
    var player: EchoPlayer
    var status = EchoStatus.play
    var cause: EchoCause?
    var pressed: Set<Int> = []
    var open: [Character: Bool] = [:]
    var jumped = false
    var landed = false
}

enum EchoCore {
    static let tile = 30.0
    static let cols = 32
    static let rows = 18
    static let fps = 60.0
    static let dt = 1.0 / 60

    enum P {
        static let w = 18.0, h = 26.0
        static let speed = 210.0, accel = 2600.0, airAccel = 1700.0
        static let gravity = 1800.0, jump = 560.0, maxFall = 840.0
        static let coyote = 6, buffer = 7
        static let cut = 0.45
    }

    /// Plate group -> the door group it opens.
    static let plateToDoor: [Character: Character] = ["1": "a", "2": "b", "3": "c"]

    enum ParseError: Error, Equatable {
        case rows(String, Int)
        case cols(String, row: Int, count: Int)
        case missing(String, Character)
    }

    struct LevelDef {
        let name: String
        let title: String
        let hint: String
        let seconds: Double
        let echoes: Int
        let map: [String]
    }

    static func parse(_ def: LevelDef) throws -> EchoLevel {
        guard def.map.count == rows else { throw ParseError.rows(def.name, def.map.count) }
        var cells: [[Character]] = []
        var plates: [EchoLevel.Plate] = [], doors: [EchoLevel.Door] = [], spikes: [EchoRect] = []
        var spawn: EchoFrame?, exit: EchoRect?
        for (ty, row) in def.map.enumerated() {
            let chars = Array(row)
            guard chars.count == cols else { throw ParseError.cols(def.name, row: ty, count: chars.count) }
            for (tx, ch) in chars.enumerated() {
                let x = Double(tx) * tile, y = Double(ty) * tile
                switch ch {
                case "S": spawn = EchoFrame(x: x + (tile - P.w) / 2, y: y + tile - P.h, facing: 1)
                case "E": exit = EchoRect(x: x + 4, y: y - tile, w: tile - 8, h: tile * 2)
                case "^": spikes.append(EchoRect(x: x + 4, y: y + 14, w: tile - 8, h: tile - 14))
                case "1", "2", "3": plates.append(.init(group: ch, rect: EchoRect(x: x + 3, y: y + tile - 6, w: tile - 6, h: 6)))
                case "a", "b", "c": doors.append(.init(group: ch, tx: tx, ty: ty, rect: EchoRect(x: x, y: y, w: tile, h: tile)))
                default: break
                }
            }
            cells.append(chars)
        }
        guard let spawn else { throw ParseError.missing(def.name, "S") }
        guard let exit else { throw ParseError.missing(def.name, "E") }
        return EchoLevel(name: def.name, title: def.title, hint: def.hint, limit: Int((def.seconds * fps).rounded()),
                         maxEchoes: def.echoes, cells: cells, plates: plates, doors: doors, spikes: spikes,
                         spawn: spawn, exit: exit)
    }

    static func isWall(_ level: EchoLevel, _ tx: Int, _ ty: Int) -> Bool {
        tx < 0 || ty < 0 || tx >= cols || ty >= rows || level.cells[ty][tx] == "#"
    }

    static func box(_ x: Double, _ y: Double) -> EchoRect { EchoRect(x: x, y: y, w: P.w, h: P.h) }

    static func makeWorld(_ level: EchoLevel, echoes: [EchoRecording]) -> EchoWorld {
        let s = level.spawn
        return EchoWorld(level: level, echoes: echoes, player: EchoPlayer(x: s.x, y: s.y),
                         open: doorsOpen(level, pressed: []))
    }

    /// Echo positions at frame `f`. A loop cut short by a rewind leaves its echo standing at its last
    /// spot; an echo that died is gone after its death frame.
    static func ghosts(_ echoes: [EchoRecording], at f: Int) -> [EchoFrame?] {
        echoes.map { rec in
            if f < rec.frames.count { return rec.frames[f] }
            return rec.end == .dead ? nil : rec.frames.last
        }
    }

    static func platesPressed(_ level: EchoLevel, bodies: [EchoFrame?]) -> Set<Int> {
        Set(level.plates.indices.filter { i in
            bodies.contains { b in b.map { box($0.x, $0.y).overlaps(level.plates[i].rect) } ?? false }
        })
    }

    /// A door group opens only while every plate of its group is pressed.
    static func doorsOpen(_ level: EchoLevel, pressed: Set<Int>) -> [Character: Bool] {
        var open: [Character: Bool] = [:]
        for (plate, door) in plateToDoor {
            let group = level.plates.indices.filter { level.plates[$0].group == plate }
            open[door] = !group.isEmpty && group.allSatisfy(pressed.contains)
        }
        return open
    }

    private struct Solid { let rect: EchoRect; let ghost: Int }

    /// Walls and closed doors around `b`, plus any extra rects (echo heads).
    private static func solids(_ level: EchoLevel, open: [Character: Bool], extra: [Solid] = [], around b: EchoRect) -> [Solid] {
        var out: [Solid] = []
        let tx0 = Int((b.x / tile).rounded(.down)) - 1, tx1 = Int(((b.x + b.w) / tile).rounded(.down)) + 1
        let ty0 = Int((b.y / tile).rounded(.down)) - 1, ty1 = Int(((b.y + b.h) / tile).rounded(.down)) + 1
        for ty in ty0...ty1 {
            for tx in tx0...tx1 where isWall(level, tx, ty) {
                out.append(Solid(rect: EchoRect(x: Double(tx) * tile, y: Double(ty) * tile, w: tile, h: tile), ghost: -1))
            }
        }
        for d in level.doors where open[d.group] != true { out.append(Solid(rect: d.rect, ghost: -1)) }
        return out + extra
    }

    private static func moveX(_ p: EchoPlayer, _ dx: Double, _ rects: [Solid]) -> (x: Double, hit: Bool) {
        guard dx != 0 else { return (p.x, false) }
        let x = rects.reduce(p.x + dx) { nx, s in
            guard box(nx, p.y).overlaps(s.rect) else { return nx }
            return dx > 0 ? s.rect.x - P.w : s.rect.x + s.rect.w
        }
        return (x, x != p.x + dx)
    }

    private static func moveY(_ p: EchoPlayer, _ dy: Double, _ rects: [Solid]) -> (y: Double, hit: Int, ride: Int) {
        // hit: 0 none, 1 landed, -1 bumped head
        rects.reduce((y: p.y + dy, hit: 0, ride: -1)) { acc, s in
            guard box(p.x, acc.y).overlaps(s.rect) else { return acc }
            return dy > 0 ? (s.rect.y - P.h, 1, s.ghost) : (s.rect.y + s.rect.h, -1, -1)
        }
    }

    /// Push the player out of anything that moved into it (a closing door).
    private static func pushOut(_ p: EchoPlayer, _ rects: [Solid]) -> EchoPlayer {
        rects.reduce(p) { cur, s in
            let b = box(cur.x, cur.y), r = s.rect
            guard b.overlaps(r) else { return cur }
            let opts: [(d: Double, x: Double, y: Double)] = [
                (b.y + b.h - r.y, cur.x, r.y - P.h), (r.y + r.h - b.y, cur.x, r.y + r.h),
                (b.x + b.w - r.x, r.x - P.w, cur.y), (r.x + r.w - b.x, r.x + r.w, cur.y),
            ]
            let best = opts.min { $0.d < $1.d }!
            var next = cur
            next.x = best.x
            next.y = best.y
            return next
        }
    }

    /// `peers` are live teammates (co-op) where this machine last saw them: they press plates and can be
    /// stood on like echoes, but nobody is carried by them (their motion arrives over the network).
    static func step(_ world: EchoWorld, _ input: EchoInput, peers: [EchoFrame] = []) -> EchoWorld {
        guard world.status == .play else { return world }
        let level = world.level
        let f = world.frame + 1
        let prevG = ghosts(world.echoes, at: world.frame)
        let curG = ghosts(world.echoes, at: f)
        let prev = world.player

        let pressed = platesPressed(level, bodies: [EchoFrame(x: prev.x, y: prev.y, facing: prev.facing)] + curG + peers)
        let open = doorsOpen(level, pressed: pressed)
        let terrain = { (b: EchoRect) in solids(level, open: open, around: b) }

        // Ride: carried by the echo we stood on last frame.
        var p = prev
        if prev.ride >= 0, let a = prevG[prev.ride], let b = curG[prev.ride] {
            if b.x != a.x { p.x = moveX(p, b.x - a.x, terrain(box(p.x, p.y))).x }
            if b.y != a.y { p.y = moveY(p, b.y - a.y, terrain(box(p.x, p.y))).y }
        }
        p = pushOut(p, terrain(box(p.x, p.y)))

        let dir = (input.right ? 1 : 0) - (input.left ? 1 : 0)
        let accel = (p.ground ? P.accel : P.airAccel) * dt
        let target = Double(dir) * P.speed
        let vx = p.vx < target ? min(target, p.vx + accel) : max(target, p.vx - accel)
        var buffer = input.jump && !p.held ? P.buffer : max(0, p.buffer - 1)
        var coyote = p.ground ? P.coyote : max(0, p.coyote - 1)
        var vy = p.vy
        var cut = p.cut
        var jumped = false
        if buffer > 0, coyote > 0 {
            vy = -P.jump; buffer = 0; coyote = 0; cut = false; jumped = true
        }
        if !input.jump, vy < 0, !cut { vy *= P.cut; cut = true }
        vy = min(vy + P.gravity * dt, P.maxFall)

        let mx = moveX(p, vx * dt, terrain(box(p.x, p.y)))
        p.x = mx.x
        // Echoes are one-way platforms: only a player falling from above their heads lands on them.
        let feet = p.y + P.h
        let heads: [Solid] = vy > 0 ? curG.enumerated().compactMap { i, g in
            guard let g, feet <= g.y + 0.01 else { return nil }
            return Solid(rect: box(g.x, g.y), ghost: i)
        } + peers.compactMap { g in feet <= g.y + 0.01 ? Solid(rect: box(g.x, g.y), ghost: -1) : nil } : []
        let my = moveY(p, vy * dt, solids(level, open: open, extra: heads, around: box(p.x, p.y)))
        let ground = my.hit == 1
        p.y = my.y
        p.vx = mx.hit ? 0 : vx
        p.vy = my.hit != 0 ? 0 : vy
        p.ground = ground
        p.ride = ground ? my.ride : -1
        p.coyote = coyote
        p.buffer = buffer
        p.cut = cut
        p.held = input.jump
        if dir != 0 { p.facing = dir }

        let b = box(p.x, p.y)
        let crushed = terrain(b).contains { b.overlaps($0.rect) }
        let spiked = level.spikes.contains { b.overlaps($0) } || p.y > Double(rows) * tile
        var next = world
        next.frame = f
        next.player = p
        next.pressed = pressed
        next.open = open
        next.jumped = jumped
        next.landed = ground && !prev.ground
        if crushed || spiked {
            next.status = .dead
            next.cause = crushed ? .crush : .spike
        } else if b.overlaps(level.exit) {
            next.status = .won
        } else if f >= level.limit {
            next.status = .timeout
        }
        return next
    }

    static func snapshot(_ p: EchoPlayer) -> EchoFrame { EchoFrame(x: p.x, y: p.y, facing: p.facing) }

    /// Plays one loop to the end with a scripted input source; returns the recording and the final world.
    static func simulate(_ level: EchoLevel, echoes: [EchoRecording], input: (Int) -> EchoInput) -> (world: EchoWorld, rec: EchoRecording) {
        var w = makeWorld(level, echoes: echoes)
        var frames = [snapshot(w.player)]
        while w.status == .play {
            w = step(w, input(w.frame))
            frames.append(snapshot(w.player))
        }
        let end: EchoEnd = switch w.status {
        case .dead: .dead
        case .won: .won
        default: .timeout
        }
        return (w, EchoRecording(frames: frames, end: end))
    }

    /// Adds a finished loop as an echo. A full budget keeps every existing echo (nothing is dropped
    /// silently) and reports `false` so the caller can tell the player to erase one first.
    static func commit(_ rec: EchoRecording, to echoes: [EchoRecording], max: Int) -> (echoes: [EchoRecording], added: Bool) {
        guard max > 0, echoes.count < max else { return (echoes, false) }
        return (echoes + [rec], true)
    }
}

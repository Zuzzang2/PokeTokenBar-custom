import Foundation

// SPIKE: plaza motion, ticked every frame by `PlazaSession`. Pure so it can be tested.
// - Own trainer: moves at a constant speed while keys are held (no key-repeat stutter).
// - Remote trainers: network updates only move the target; the drawn position eases toward it.
// - Followers trail one step behind and catch up a little slower than their trainer.
// - Walking frames advance with distance walked, so steps match the ground covered.

enum PlazaMotion {
    static let walkSpeed = 110.0          // points per second
    static let remoteCatchUp = 14.0       // higher = tighter tracking of the network position
    static let followerCatchUp = 7.0
    static let snapDistance = 120.0       // farther than this is a teleport (rejoin), not a walk
    static let stepLength = 10.0          // points per walking frame

    /// Advances the local player by `dt` seconds with the held direction keys.
    static func walk(_ p: PlazaPlayer, held: Set<PlazaFacing>, dt: Double) -> PlazaPlayer {
        var next = p
        var vx = 0.0, vy = 0.0
        if held.contains(.left) { vx -= 1 }
        if held.contains(.right) { vx += 1 }
        if held.contains(.up) { vy -= 1 }
        if held.contains(.down) { vy += 1 }
        let length = hypot(vx, vy)
        if length > 0 {
            let d = walkSpeed * dt / length
            // Try each axis on its own so an obstacle on one axis still lets you slide on the other.
            if PlazaSession.isWalkable(x: next.x + vx * d, y: next.y) { next.x += vx * d }
            if PlazaSession.isWalkable(x: next.x, y: next.y + vy * d) { next.y += vy * d }
            next.facing = vx != 0 ? (vx < 0 ? .left : .right) : (vy < 0 ? .up : .down)
        }
        let moved = hypot(next.x - p.shownX, next.y - p.shownY)
        next.shownX = next.x
        next.shownY = next.y
        next.walked += moved
        next.moving = moved > 0.01
        return trail(next, dt: dt)
    }

    /// Eases a remote player's drawn position toward the last network position.
    static func follow(_ p: PlazaPlayer, dt: Double) -> PlazaPlayer {
        var next = p
        let dx = p.x - p.shownX, dy = p.y - p.shownY
        let distance = hypot(dx, dy)
        if distance > snapDistance {
            next.shownX = p.x
            next.shownY = p.y
            next.followerX = p.x - offset(p.facing).width
            next.followerY = p.y - offset(p.facing).height
            next.moving = false
            return next
        }
        let k = 1 - exp(-remoteCatchUp * dt)
        let mx = dx * k, my = dy * k
        next.shownX += mx
        next.shownY += my
        let moved = hypot(mx, my)
        next.moving = distance > 0.6
        if next.moving { next.facing = abs(dx) >= abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .up : .down) }
        next.walked += moved
        return trail(next, dt: dt)
    }

    /// Where the follower settles relative to the trainer: one step behind the facing direction.
    static func offset(_ facing: PlazaFacing) -> CGSize {
        switch facing {
        case .down: CGSize(width: -22, height: 10)    // diagonal so it peeks out from behind
        case .up: CGSize(width: 22, height: -8)
        case .left: CGSize(width: -28, height: 0)
        case .right: CGSize(width: 28, height: 0)
        }
    }

    private static func trail(_ p: PlazaPlayer, dt: Double) -> PlazaPlayer {
        var next = p
        let target = CGPoint(x: p.shownX - offset(p.facing).width, y: p.shownY - offset(p.facing).height)
        let k = 1 - exp(-followerCatchUp * dt)
        next.followerX += (target.x - p.followerX) * k
        next.followerY += (target.y - p.followerY) * k
        return next
    }
}

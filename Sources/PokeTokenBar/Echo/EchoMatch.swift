import Foundation

// SPIKE: the host's rules for a 메아리 run, solo or co-op. Pure value type; the game view feeds it events
// and broadcasts what it decides.
//
// Everyone plays the same loop at once. A loop ends when anyone rewinds, the host's clock runs out, or
// nobody is still running. Each player's run then becomes their echo (each player has their own budget),
// and a level is cleared when every player reaches the exit in the same loop.

/// One player's finished loop, with who it belongs to so every machine draws the right Pokémon.
struct EchoOwned: Codable, Sendable, Equatable {
    let owner: String
    let speciesID: Int?
    let isShiny: Bool
    let rec: EchoRecording
}

struct EchoMatch: Equatable {
    /// Players still connected, by ID.
    private(set) var active: Set<String>
    private(set) var level: Int
    private(set) var loop = 0
    private(set) var echoes: [EchoOwned] = []
    private(set) var exited: Set<String> = []
    /// Players whose run is over this loop (died or reached the exit).
    private(set) var done: Set<String> = []
    private(set) var collecting = false
    private var received: [String: EchoOwned] = [:]
    /// Loops played across the whole run, for the ending.
    private(set) var totalLoops = 0

    /// `priorLoops` carries a solo run's loop count over from earlier sessions.
    init(players: [String], level: Int, priorLoops: Int = 0) {
        active = Set(players)
        self.level = level
        totalLoops = priorLoops
    }

    /// Where a solo run resumes after clearing `level`: the next one, or the start once the last is done.
    static func nextStart(afterClearing level: Int, levelCount: Int) -> Int {
        level + 1 < levelCount ? level + 1 : 0
    }

    var isCleared: Bool { !active.isEmpty && active.isSubset(of: exited) }
    /// Every player's run is over without a clear: the loop should end.
    var allDone: Bool { !active.isEmpty && active.isSubset(of: done) && !isCleared }
    var hasEveryRecording: Bool { active.isSubset(of: Set(received.keys)) }

    func echoCount(of owner: String) -> Int { echoes.filter { $0.owner == owner }.count }

    mutating func playerExited(_ id: String) {
        guard !collecting, active.contains(id) else { return }
        exited.insert(id)
        done.insert(id)
    }

    mutating func playerDied(_ id: String) {
        guard !collecting, active.contains(id) else { return }
        done.insert(id)
    }

    mutating func playerLeft(_ id: String) {
        active.remove(id)
        received[id] = nil
    }

    /// Stop the loop and wait for everyone's recording.
    mutating func beginCollecting() {
        collecting = true
        received = [:]
    }

    mutating func receive(_ owned: EchoOwned) {
        guard collecting, active.contains(owned.owner) else { return }
        received[owned.owner] = owned
    }

    /// Adds every received run as an echo within its owner's budget and starts the next loop.
    /// Returns the owners whose budget was already full (their run was not kept).
    @discardableResult
    mutating func startNextLoop(maxPerPlayer: Int) -> [String] {
        var full: [String] = []
        for id in received.keys.sorted() {
            guard let owned = received[id] else { continue }
            if echoCount(of: id) < maxPerPlayer {
                echoes.append(owned)
            } else if maxPerPlayer > 0 {
                full.append(id)
            }
        }
        resetLoop()
        return full
    }

    /// Drops `owner`'s most recent echo and restarts the loop without keeping the current runs.
    mutating func erase(lastOf owner: String) {
        if let i = echoes.lastIndex(where: { $0.owner == owner }) { echoes.remove(at: i) }
        resetLoop()
    }

    mutating func advanceLevel() {
        level += 1
        echoes = []
        resetLoop()
    }

    private mutating func resetLoop() {
        loop += 1
        totalLoops += 1
        exited = []
        done = []
        collecting = false
        received = [:]
    }
}

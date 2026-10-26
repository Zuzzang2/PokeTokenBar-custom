import Foundation

// SPIKE: remembers the run that last cleared each 메아리 level on this Mac, so the next attempt plays
// alongside a faint "지난번의 나". Positions are rounded to whole world units to keep the defaults small.

@MainActor
struct EchoMemory {
    let defaults: UserDefaults

    private func key(_ level: String) -> String { "echoLastWin.\(level)" }

    func lastWin(level: String) -> [EchoFrame]? {
        guard let data = defaults.data(forKey: key(level)),
              let rows = try? JSONDecoder().decode([[Int]].self, from: data), !rows.isEmpty else { return nil }
        return rows.compactMap { $0.count == 3 ? EchoFrame(x: Double($0[0]), y: Double($0[1]), facing: $0[2]) : nil }
    }

    func remember(level: String, frames: [EchoFrame]) {
        let rows = frames.map { [Int($0.x.rounded()), Int($0.y.rounded()), $0.facing] }
        guard let data = try? JSONEncoder().encode(rows) else { return }
        defaults.set(data, forKey: key(level))
    }
}

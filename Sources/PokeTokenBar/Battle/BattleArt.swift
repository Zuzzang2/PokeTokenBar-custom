import AppKit

// SPIKE: generated art for the plaza and battle (assets/battle). The app bundle carries it under
// Resources/battle (build-app.sh); a raw `swift run` reads it from the checkout instead.
// Every caller has a drawn fallback, so missing art degrades to the old look rather than failing.

enum PlazaFacing: String, Codable, Sendable { case down, up, left, right }

@MainActor
enum BattleArt {
    private static var cache: [String: NSImage] = [:]

    private static var directories: [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("battle")) }
        // Dev fallback: <repo>/assets/battle relative to this source file.
        dirs.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../assets/battle").standardized)
        return dirs
    }

    static func image(_ name: String) -> NSImage? {
        if let hit = cache[name] { return hit }
        for dir in directories {
            if let image = NSImage(contentsOf: dir.appendingPathComponent("\(name).png")) {
                cache[name] = image
                return image
            }
        }
        return nil
    }

    static var plaza: NSImage? { image("plaza") }
    static var battleField: NSImage? { image("battle_field") }

    static let trainerDesigns = ["t1", "t2"]

    /// Stable design per player so everyone sees the same look for the same person.
    static func design(for id: String) -> String {
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let available = trainerDesigns.filter { image("trainers/\($0)_down0") != nil }
        return available.isEmpty ? "t1" : available[sum % available.count]
    }

    /// Walking frame; `left` reuses the mirrored right-facing art (`mirrored` = true).
    static func trainerFrame(design: String, facing: PlazaFacing, step: Int) -> (image: NSImage, mirrored: Bool)? {
        let dir = facing == .left ? "right" : facing.rawValue
        guard let image = image("trainers/\(design)_\(dir)\(step % 2)") else { return nil }
        return (image, facing == .left)
    }
}

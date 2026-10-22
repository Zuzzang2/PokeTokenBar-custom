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

    /// `trainers/local/` holds team-profile characters that stay out of git (third-party characters,
    /// public repo); a design whose frames are missing is simply not offered.
    static let trainerDesigns = ["t1", "t2", "pig", "lupin", "bunny", "dino", "bear", "green"]

    static let trainerDesignNames = [
        "t1": "모자 소년", "t2": "밀짚모자 소녀", "pig": "부리부리", "lupin": "루팡",
        "bunny": "리본 토끼", "dino": "메카 공룡", "bear": "분홍 곰", "green": "초록 점토",
    ]

    /// The player's chosen design; peers on older builds (no choice sent) or unknown designs get a
    /// stable pick from their ID so everyone still sees the same look for the same person.
    static func design(for profile: PlazaProfile) -> String {
        let available = trainerDesigns.filter { trainerFrame(design: $0, facing: .down, step: 0) != nil }
        if let chosen = profile.trainerDesign, available.contains(chosen) { return chosen }
        let sum = profile.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return available.isEmpty ? "t1" : available[sum % available.count]
    }

    /// Walking frame; `left` reuses the mirrored right-facing art (`mirrored` = true).
    static func trainerFrame(design: String, facing: PlazaFacing, step: Int) -> (image: NSImage, mirrored: Bool)? {
        let dir = facing == .left ? "right" : facing.rawValue
        let name = "\(design)_\(dir)\(step % 2)"
        guard let image = image("trainers/\(name)") ?? image("trainers/local/\(name)") else { return nil }
        return (image, facing == .left)
    }
}

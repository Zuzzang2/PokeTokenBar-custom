import AppKit

// SPIKE: standalone kart window opened from the status item menu. The player's kart carries the
// Pokémon being raised; the three CPU karts carry Pokémon from the dex (fallbacks when it is thin).

@MainActor
final class KartWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    private static let fallbackRiders: [(id: Int, name: String)] = [
        (25, "피카츄"), (133, "이브이"), (4, "파이리"), (7, "꼬부기"), (1, "이상해씨"), (39, "푸린"),
    ]

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let entrants = Self.entrants(companion: companion)
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let size = NSSize(width: min(1080, screen.width * 0.9), height: min(720, screen.height * 0.85))
        let view = KartGameView(frame: NSRect(origin: .zero, size: size), track: .standard, entrants: entrants)
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "포켓몬 카트 (테스트)"
        window.contentView = view
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                               queue: .main) { [weak self, weak view] _ in
            MainActor.assumeIsolated {
                view?.stop()
                if let token = self?.closeObserver { NotificationCenter.default.removeObserver(token) }
                self?.closeObserver = nil
                self?.window = nil
            }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.activate()

        for (i, e) in entrants.enumerated() {
            guard let id = e.speciesID else { continue }
            if let img = SpriteLoader.cachedImage(speciesID: id, shiny: e.isShiny) {
                view.setRider(img, at: i)
            } else {
                Task { [weak view] in
                    if let img = await SpriteLoader.image(speciesID: id, shiny: e.isShiny) { view?.setRider(img, at: i) }
                }
            }
        }
    }

    /// The raising Pokémon first, then up to three dex Pokémon whose sprites are already cached.
    private static func entrants(companion: CompanionStore) -> [KartEntrant] {
        let candidates = BattleMonBuilder.candidates(companion: companion)
        var out: [KartEntrant] = []
        if let mine = candidates.first(where: \.isRaising) {
            out.append(KartEntrant(name: mine.name, speciesID: mine.speciesID, isShiny: mine.isShiny, isPlayer: true,
                                   level: mine.profile?.level ?? 1))
        } else {
            out.append(KartEntrant(name: "나", speciesID: nil, isShiny: false, isPlayer: true, level: 1))
        }
        var used = Set(out.compactMap(\.speciesID))
        for c in candidates.filter({ !$0.isRaising }).shuffled() where out.count < 4 {
            guard !used.contains(c.speciesID), SpriteLoader.cachedImage(speciesID: c.speciesID, shiny: c.isShiny) != nil
            else { continue }
            used.insert(c.speciesID)
            out.append(KartEntrant(name: c.name, speciesID: c.speciesID, isShiny: c.isShiny, isPlayer: false,
                                   level: c.profile?.level ?? 50))
        }
        for f in fallbackRiders.shuffled() where out.count < 4 && !used.contains(f.id) {
            used.insert(f.id)
            out.append(KartEntrant(name: f.name, speciesID: f.id, isShiny: false, isPlayer: false, level: 50))
        }
        return out
    }
}

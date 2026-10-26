import AppKit
import SwiftUI

// SPIKE: standalone kart window opened from the status item menu. It opens on the lobby (pick a rider,
// see who is nearby); a race swaps the window's content to the game view and Esc swaps it back.

@MainActor
final class KartWindowController {
    static let pickKey = "kartPokemon"

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var session: KartSession?
    private var lobbyView: NSView?
    private var game: KartGameView?
    private var candidates: [BattleCandidate] = []

    private static let fallbackRiders: [(id: Int, name: String)] = [
        (25, "피카츄"), (133, "이브이"), (4, "파이리"), (7, "꼬부기"), (1, "이상해씨"), (39, "푸린"),
    ]

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        candidates = BattleMonBuilder.candidates(companion: companion)
        let picked = UserDefaults.standard.string(forKey: Self.pickKey)
        let pick = candidates.first { $0.id == picked } ?? candidates.first
        let me = KartPlayerInfo(id: UUID().uuidString, trainer: Self.trainerName(), speciesID: pick?.speciesID,
                                isShiny: pick?.isShiny ?? false, level: pick?.profile?.level ?? 1,
                                pokemonName: pick?.name ?? "?", inRace: false, build: KartSession.myBuild)
        if let pick { UserDefaults.standard.set(pick.id, forKey: Self.pickKey) }
        let session = KartSession(me: me)
        session.onStart = { [weak self] in self?.beginRace($0) }
        session.onState = { [weak self] raceID, karts in self?.game?.receive(raceID: raceID, karts: karts) }
        session.onFinished = { [weak self] raceID, id, time in self?.game?.receiveFinished(raceID: raceID, id: id, time: time) }
        session.onPeerLeft = { [weak self] id in self?.game?.markLeft(id) }
        self.session = session

        let lobby = NSHostingView(rootView: KartLobbyView(
            session: session, candidates: candidates,
            onSolo: { [weak self] in self?.startSolo() },
            onHostStart: { [weak self] fill in self?.hostStart(fillCPU: fill) }))
        lobbyView = lobby

        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let size = NSSize(width: min(1080, screen.width * 0.9), height: min(720, screen.height * 0.85))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "포켓몬 카트 (테스트)"
        window.contentView = lobby
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.teardown() }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func teardown() {
        game?.stop()
        game = nil
        session?.stop()
        session = nil
        lobbyView = nil
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        window = nil
    }

    private static func trainerName() -> String {
        let fullName = NSFullUserName()
        let fallback = fullName.isEmpty ? (Host.current().localizedName ?? "") : fullName
        return BattleMonBuilder.trainerName(nickname: UserDefaults.standard.string(forKey: "battleNickname") ?? "",
                                            fallback: fallback)
    }

    // MARK: races

    /// Host: everyone waiting races; with `fillCPU` the grid is topped up to four karts.
    private func hostStart(fillCPU: Bool) {
        guard let session else { return }
        let count = fillCPU ? max(0, 4 - session.waiting.count) : 0
        let taken = Set(session.waiting.compactMap(\.speciesID))
        let cpus = cpuRiders(count: count, avoiding: taken).enumerated().map { n, rider in
            KartRosterEntry(id: "cpu-\(n)-\(UUID().uuidString.prefix(8))", trainer: "CPU", pokemonName: rider.name,
                            speciesID: rider.speciesID, isShiny: rider.isShiny, level: rider.level, isCPU: true,
                            skill: Double.random(in: 0.86...0.95))
        }
        session.startRace(cpus: cpus)
    }

    private func beginRace(_ start: KartRaceStart) {
        guard let session else { return }
        let iHost = start.hostID == session.me.id
        let specs = start.roster.map { e in
            KartRacerSpec(id: e.id, trainer: e.trainer, pokemonName: e.pokemonName, speciesID: e.speciesID,
                          isShiny: e.isShiny, level: e.level, isCPU: e.isCPU,
                          role: e.id == session.me.id ? .local : (e.isCPU && iHost ? .ai : .remote), skill: e.skill)
        }
        present(specs: specs, raceID: start.raceID, online: true)
    }

    private func startSolo() {
        guard let session else { return }
        let me = session.me
        let taken: Set<Int> = me.speciesID.map { [$0] } ?? []
        var specs = cpuRiders(count: 3, avoiding: taken).enumerated().map { n, rider in
            KartRacerSpec(id: "cpu-\(n)", trainer: "CPU", pokemonName: rider.name, speciesID: rider.speciesID,
                          isShiny: rider.isShiny, level: rider.level, isCPU: true, role: .ai,
                          skill: [0.95, 0.92, 0.89][n % 3])
        }
        specs.append(KartRacerSpec(id: me.id, trainer: me.trainer, pokemonName: me.pokemonName, speciesID: me.speciesID,
                                   isShiny: me.isShiny, level: me.level, isCPU: false, role: .local, skill: 1))
        present(specs: specs, raceID: nil, online: false)
    }

    private func present(specs: [KartRacerSpec], raceID: String?, online: Bool) {
        guard let window, let session else { return }
        game?.stop()
        let view = KartGameView(frame: window.contentView?.bounds ?? .zero, track: .standard, specs: specs,
                                raceID: raceID, session: online ? session : nil)
        view.onExit = { [weak self] in self?.backToLobby() }
        game = view
        window.contentView = view
        window.makeFirstResponder(view)
        session.update { $0.inRace = true }
        for (i, s) in specs.enumerated() {
            guard let id = s.speciesID else { continue }
            if let img = SpriteLoader.cachedImage(speciesID: id, shiny: s.isShiny) {
                view.setRider(img, at: i)
            } else {
                Task { [weak view] in
                    if let img = await SpriteLoader.image(speciesID: id, shiny: s.isShiny) { view?.setRider(img, at: i) }
                }
            }
        }
    }

    private func backToLobby() {
        game?.stop()
        game = nil
        if let lobbyView { window?.contentView = lobbyView }
        session?.update { $0.inRace = false }
    }

    private struct Rider { let speciesID: Int; let name: String; let isShiny: Bool; let level: Int }

    /// CPU riders: dex Pokémon whose sprites are cached here, then well-known fallbacks.
    private func cpuRiders(count: Int, avoiding taken: Set<Int>) -> [Rider] {
        var used = taken
        var out: [Rider] = []
        for c in candidates.filter({ !$0.isRaising }).shuffled() where out.count < count {
            guard !used.contains(c.speciesID), SpriteLoader.cachedImage(speciesID: c.speciesID, shiny: c.isShiny) != nil
            else { continue }
            used.insert(c.speciesID)
            out.append(Rider(speciesID: c.speciesID, name: c.name, isShiny: c.isShiny, level: c.profile?.level ?? 50))
        }
        for f in Self.fallbackRiders.shuffled() where out.count < count && !used.contains(f.id) {
            used.insert(f.id)
            out.append(Rider(speciesID: f.id, name: f.name, isShiny: false, level: 50))
        }
        return out
    }
}

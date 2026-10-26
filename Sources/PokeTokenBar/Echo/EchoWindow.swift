import AppKit
import SwiftUI

// SPIKE: the 메아리 window, opened from the status item menu. It opens on the lobby (pick a Pokémon, see
// who is nearby); starting swaps the content to the game view and Esc swaps it back.

@MainActor
final class EchoWindowController {
    static let pickKey = "echoPokemon"
    static let progressKey = "echoLevel"
    /// Solo loops and echoes so far in the current run, so a run spread over sessions ends with its full count.
    static let loopsKey = "echoRunLoops"
    static let echoesKey = "echoRunEchoes"

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var session: EchoSession?
    private var lobbyView: NSView?
    private var game: EchoGameView?
    private var candidates: [BattleCandidate] = []

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        candidates = BattleMonBuilder.candidates(companion: companion)
        let picked = UserDefaults.standard.string(forKey: Self.pickKey)
        let pick = candidates.first { $0.id == picked } ?? candidates.first
        if let pick { UserDefaults.standard.set(pick.id, forKey: Self.pickKey) }
        let me = EchoPlayerInfo(id: UUID().uuidString, trainer: Self.trainerName(), speciesID: pick?.speciesID ?? 25,
                                isShiny: pick?.isShiny ?? false, pokemonName: pick?.name ?? "피카츄", inGame: false)
        let session = EchoSession(me: me)
        session.onMessage = { [weak self] message in self?.receive(message) }
        session.onPeerLeft = { [weak self] id in self?.game?.markLeft(id) }
        self.session = session

        let lobby = NSHostingView(rootView: EchoLobbyView(
            session: session, candidates: candidates,
            onSolo: { [weak self] in self?.startSolo() },
            onHostStart: { [weak session] in session?.startGame() }))
        lobbyView = lobby

        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let size = NSSize(width: min(1000, screen.width * 0.9), height: min(600, screen.height * 0.85))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "메아리 (테스트)"
        window.contentView = lobby
        window.contentMinSize = NSSize(width: 640, height: 400)
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

    /// Solo picks up where this machine left off; co-op always starts from the first puzzle that uses echoes.
    private static var savedLevel: Int {
        min(max(0, UserDefaults.standard.integer(forKey: progressKey)), EchoLevels.all.count - 1)
    }

    // MARK: games

    private func receive(_ message: EchoMessage) {
        if case .start(let start) = message {
            present(roster: start.roster, hostID: start.hostID, gameID: start.gameID, level: 1, online: true)
            return
        }
        game?.handle(message)
    }

    private func startSolo() {
        guard let session else { return }
        let me = session.me
        let entry = EchoRosterEntry(id: me.id, trainer: me.trainer, pokemonName: me.pokemonName, speciesID: me.speciesID,
                                    isShiny: me.isShiny)
        present(roster: [entry], hostID: me.id, gameID: UUID().uuidString, level: Self.savedLevel, online: false)
    }

    private func present(roster: [EchoRosterEntry], hostID: String, gameID: String, level: Int, online: Bool) {
        guard let window, let session else { return }
        game?.stop()
        let send: (EchoMessage) -> Void
        if online {
            send = { [weak session] in session?.send($0) }
        } else {
            send = { [weak self] message in
                Self.recordSoloProgress(message)
                self?.game?.handle(message)
            }
        }
        let sendState: (EchoMessage) -> Void = online ? { [weak session] in session?.sendState($0) } : { _ in }
        let defaults = UserDefaults.standard
        let prior = online ? (0, 0) : (defaults.integer(forKey: Self.loopsKey), defaults.integer(forKey: Self.echoesKey))
        let view = EchoGameView(frame: window.contentView?.bounds ?? .zero, roster: roster, meID: session.me.id,
                                hostID: hostID, gameID: gameID, startLevel: level, prior: prior,
                                memory: EchoMemory(defaults: .standard), send: send,
                                sendState: sendState)
        view.onExit = { [weak self] in self?.backToLobby() }
        game = view
        window.contentView = view
        window.makeFirstResponder(view)
        session.update { $0.inGame = true }
        for e in roster {
            guard let id = e.speciesID else { continue }
            if let img = SpriteLoader.cachedImage(speciesID: id, shiny: e.isShiny) {
                view.setSprite(img, for: e.id)
            } else {
                Task { [weak view] in
                    if let img = await SpriteLoader.image(speciesID: id, shiny: e.isShiny) { view?.setSprite(img, for: e.id) }
                }
            }
        }
        view.begin()
    }

    private static func recordSoloProgress(_ message: EchoMessage) {
        let defaults = UserDefaults.standard
        switch message {
        case let .cleared(_, level, loops, echoes):
            defaults.set(EchoMatch.nextStart(afterClearing: level, levelCount: EchoLevels.all.count), forKey: progressKey)
            defaults.set(loops, forKey: loopsKey)
            defaults.set(echoes, forKey: echoesKey)
        case .finished:
            // The run is over; the next solo game is a fresh run from the first level.
            for key in [progressKey, loopsKey, echoesKey] { defaults.removeObject(forKey: key) }
        default:
            break
        }
    }

    private func backToLobby() {
        game?.stop()
        game = nil
        if let lobbyView { window?.contentView = lobbyView }
        session?.update { $0.inGame = false }
    }
}

// MARK: - lobby

@MainActor
struct EchoLobbyView: View {
    let session: EchoSession
    let candidates: [BattleCandidate]
    let onSolo: () -> Void
    let onHostStart: () -> Void

    @AppStorage(EchoWindowController.pickKey) private var pickedID = "active"
    @AppStorage(EchoWindowController.progressKey) private var progress = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            picker.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            lobby.frame(width: 320).frame(maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 400)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("메아리").font(.largeTitle.bold())
            Text("되감으면 방금의 내가 메아리가 되어 그대로 다시 움직여요. 메아리로 발판을 누르고, 계단을 쌓고, 신전까지 가세요.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("함께할 포켓몬").font(.headline).padding(.top, 4)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(candidates) { c in
                        Button { choose(c) } label: { tile(c) }.buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
        }
        .padding(16)
    }

    private func tile(_ c: BattleCandidate) -> some View {
        let selected = c.id == pickedID
        return VStack(spacing: 2) {
            KartSpriteThumb(speciesID: c.speciesID, shiny: c.isShiny).frame(width: 64, height: 64)
            Text(c.name).font(.caption.bold()).lineLimit(1)
            Text(c.isRaising ? "키우는 중" : "도감").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
    }

    private func choose(_ c: BattleCandidate) {
        pickedID = c.id
        session.update {
            $0.speciesID = c.speciesID
            $0.isShiny = c.isShiny
            $0.pokemonName = c.name
        }
    }

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("같이 하기").font(.title2.bold())
                Spacer()
                Text("\(session.everyone.count)/\(EchoSession.capacity)").foregroundStyle(.secondary)
            }
            Text("같은 Wi-Fi에서 메아리 창을 연 사람끼리 자동으로 모여요. 모두가 신전에 닿아야 클리어예요.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: 6) { ForEach(session.everyone, id: \.id) { row($0) } }
            }
            if !session.notice.isEmpty { Text(session.notice).font(.caption).foregroundStyle(.secondary) }
            Divider()
            if session.isHost {
                Button(action: onHostStart) {
                    Text("같이 시작 (\(session.waiting.count)명)").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(session.waiting.count < 2)
            } else {
                let host = session.everyone.first { $0.id == session.hostID }?.trainer ?? "방장"
                Text("방장 \(host) 님이 시작하면 같이 출발해요.")
                    .font(.callout).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 6)
            }
            Button(action: onSolo) {
                Text(progress > 0 ? "혼자 하기 (\(progress + 1)단계부터)" : "혼자 하기").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func row(_ p: EchoPlayerInfo) -> some View {
        HStack(spacing: 10) {
            KartSpriteThumb(speciesID: p.speciesID, shiny: p.isShiny).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(p.trainer).font(.callout.bold()).lineLimit(1)
                    if p.id == session.me.id { badge("나", .blue) }
                    if p.id == session.hostID { badge("방장", .orange) }
                }
                Text(p.pokemonName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if p.inGame { badge("게임 중", .green) }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundStyle(color)
    }
}

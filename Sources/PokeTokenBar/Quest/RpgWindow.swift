import AppKit
import SwiftUI

// SPIKE: standalone window for 픽셀 모험, opened from the status item menu. Opens on a title screen
// (continue the saved character or make a new one), then swaps in `RpgView`. Also the multiplayer
// driver: it hosts the world (simulating remote players from their inputs and broadcasting snapshots) or
// mirrors a nearby host's world, and switches between the two as players come and go.

@MainActor
protocol RpgDriver: AnyObject {
    var isClient: Bool { get }
    var onlineCount: Int { get }
    var statusLabel: String { get }
    func send(_ action: RpgAction)
    func sendInput(_ input: RpgInput)
    func chat(_ text: String)
    func remoteInputs() -> [Int: RpgInput]
}

@MainActor
final class RpgWindowController: RpgDriver {
    private enum Mode: Equatable { case host, joining(String), client(String) }

    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var titleView: NSView?
    private var game: RpgView?
    private var world: RpgWorld?
    private var localID = 1
    private let state = RpgTitleState()

    private var session: RpgSession?
    private var mode = Mode.host
    private var hostPeers: [String: Int] = [:]
    private var inputs: [Int: RpgInput] = [:]
    private var netTimer: Timer?
    private var tick = 0
    private var lastInputSent = 0.0
    private var pendingSave: RpgSaveData?

    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        state.reload()
        let title = NSHostingView(rootView: RpgTitleView(state: state,
            onContinue: { [weak self] in self?.continueGame() },
            onNew: { [weak self] name, cls, hardcore in self?.newGame(name: name, cls: cls, hardcore: hardcore) }))
        titleView = title
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let size = NSSize(width: min(1080, screen.width * 0.9), height: min(720, screen.height * 0.85))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "픽셀 모험 (테스트)"
        window.contentView = title
        window.contentMinSize = NSSize(width: 720, height: 480)
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
        world = nil
        stopNetwork()
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        window = nil
    }

    private func stopNetwork() {
        netTimer?.invalidate()
        netTimer = nil
        session?.stop()
        session = nil
        hostPeers = [:]
        inputs = [:]
        mode = .host
    }

    private func continueGame() {
        guard case .ok(let data) = RpgSaveStore.load(), data.fallen != true else { return }
        startHosting(RpgSaveStore.player(from: data, id: 1))
    }

    private func newGame(name: String, cls: RpgClass, hardcore: Bool) {
        if case .tampered = RpgSaveStore.load() { RpgSaveStore.quarantine() }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let player = RpgSaveStore.newPlayer(name: trimmed.isEmpty ? "모험가" : String(trimmed.prefix(10)), cls: cls, id: 1, hardcore: hardcore)
        RpgSaveStore.save(RpgSaveStore.snapshot(player))
        startHosting(player)
    }

    // MARK: worlds

    /// Everyone starts by hosting their own world; meeting another host may make us yield to it.
    private func startHosting(_ player: RpgPlayer, announce: Bool = true) {
        let w = RpgWorld(player: player)
        attachGraves(w)
        if announce { w.toast("\(player.name)의 모험 시작! 같은 Wi-Fi에서 켠 동료와 자동으로 만나요") }
        world = w
        localID = player.id
        mode = .host
        hostPeers = [:]
        inputs = [:]
        present(w)
        if session == nil {
            let s = RpgSession(name: player.name)
            s.onMessage = { [weak self] message, from in self?.receive(message, from: from) }
            s.onPeerLeft = { [weak self] key in self?.peerLeft(key) }
            s.onPeersChanged = { [weak self] in self?.reconcile() }
            session = s
        }
        session?.setHosting(true)
        if netTimer == nil {
            netTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.netTick() }
            }
        }
        reconcile()
    }

    private func present(_ w: RpgWorld) {
        guard let window else { return }
        game?.stop()
        let view = RpgView(frame: window.contentView?.bounds ?? .zero, world: w, localID: localID)
        view.driver = self
        view.onSave = { RpgSaveStore.save($0) }
        view.onExit = { [weak self] in self?.backToTitle() }
        game = view
        window.contentView = view
        window.makeFirstResponder(view)
    }

    private func backToTitle() {
        game?.stop()
        game = nil
        world = nil
        stopNetwork()
        state.reload()
        if let titleView { window?.contentView = titleView }
    }

    /// Graves live on disk on every Mac: load them into a world and write back whenever one appears.
    private func attachGraves(_ w: RpgWorld) {
        w.addGraves(RpgGraveStore.load())
        w.onGraves = { [weak w] in
            guard let w else { return }
            let merged = Dictionary((RpgGraveStore.load() + w.graves).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            RpgGraveStore.save(Array(merged.values))
        }
    }

    private var myState: RpgSaveData? { world?.player(localID).map(RpgSaveStore.snapshot) }

    /// Decide who hosts: the smallest key among hosts. Hosts with a bigger key yield; clients whose host
    /// vanished follow the new one, or start hosting when nobody else is.
    private func reconcile() {
        guard let session, world != nil else { return }
        let elected = session.electedHost
        switch mode {
        case .host:
            if let e = elected, e != session.key { yield(to: e) }
        case .joining(let h), .client(let h):
            if let e = elected, e != h, e != session.key {
                join(e)
            } else if elected == nil, session.peers[h] == nil {
                // Host gone and nobody hosting: the smallest remaining key takes over.
                if session.peers.keys.allSatisfy({ session.key < $0 }), let me = world?.player(localID) {
                    world?.toast("방장이 나가서 이 세계를 이어받았어요", to: nil)
                    var p = me
                    p.dead = false
                    startHosting(p, announce: false)
                }
            }
        }
    }

    private func yield(to host: String) {
        game?.saveNow()
        session?.setHosting(false)
        join(host)
    }

    private func join(_ host: String) {
        guard let save = myState ?? pendingSave else { return }
        pendingSave = save
        mode = .joining(host)
        hostPeers = [:]
        session?.send(.join(peer: session?.key ?? "", save: save), to: host, reliable: true)
        world?.toast("근처 동료의 세계에 들어가는 중…", to: nil)
    }

    private func peerLeft(_ key: String) {
        if mode == .host, let id = hostPeers.removeValue(forKey: key) {
            world?.removePlayer(id)
            inputs.removeValue(forKey: id)
        }
        reconcile()
    }

    // MARK: messages

    private func receive(_ message: RpgNetMessage, from: String) {
        guard let session else { return }
        switch message {
        case .hello:
            break
        case .join(let peer, let save):
            guard mode == .host, let w = world else { return }
            let id = hostPeers[peer] ?? w.nextPlayerID
            hostPeers[peer] = id
            w.addPlayer(RpgSaveStore.player(from: save, id: id))
            session.send(.welcome(peer: peer, id: id), to: peer, reliable: true)
        case .welcome(let peer, let id):
            guard peer == session.key, case .joining(let host) = mode, host == from, let save = pendingSave else { return }
            var p = RpgSaveStore.player(from: save, id: id)
            p.dead = false
            let w = RpgWorld(player: p)
            w.isMirror = true
            attachGraves(w)
            session.send(.graves(peer: session.key, list: RpgGraveStore.load()), to: host, reliable: true)
            world = w
            localID = id
            mode = .client(host)
            present(w)
            w.toast("\(session.peers[host]?.name ?? "동료")님의 세계에 들어왔어요", to: nil)
        case .input(let peer, let input):
            if mode == .host, let id = hostPeers[peer] { inputs[id] = input }
        case .action(let peer, let action):
            if mode == .host, let id = hostPeers[peer] { world?.perform(action, for: id) }
        case .chat(let peer, let text):
            if mode == .host, let id = hostPeers[peer] { world?.say(id, text) }
        case .graves(_, let list):
            if mode == .host { world?.addGraves(list) }
        case .snapshot(let snap):
            if case .client(let host) = mode, host == from { world?.apply(snap, localID: localID) }
        case .privateState(let peer, let s):
            if peer == session.key, case .client(let host) = mode, host == from {
                world?.applyPrivate(s, localID: localID)
                pendingSave = s.save
            }
        }
    }

    private func netTick() {
        guard let session, let w = world, mode == .host, !hostPeers.isEmpty else { return }
        tick += 1
        session.broadcast(.snapshot(w.snapshot()), reliable: false)
        if tick % 5 == 0 {
            for (peer, id) in hostPeers {
                if let s = w.privateState(for: id) { session.send(.privateState(peer: peer, state: s), to: peer, reliable: true) }
            }
        }
    }

    // MARK: RpgDriver

    var isClient: Bool { if case .host = mode { return false } else { return true } }
    var onlineCount: Int { (session?.connectedCount ?? 0) + 1 }
    var statusLabel: String {
        switch mode {
        case .host: return hostPeers.isEmpty ? "혼자" : "방장"
        case .joining: return "접속 중…"
        case .client: return "참가 중"
        }
    }

    func send(_ action: RpgAction) {
        switch mode {
        case .host: world?.perform(action, for: localID)
        case .client(let host): session?.send(.action(peer: session?.key ?? "", action: action), to: host, reliable: true)
        case .joining: break
        }
    }

    func sendInput(_ input: RpgInput) {
        guard case .client(let host) = mode, let session, let w = world, w.time - lastInputSent >= 1.0 / 30 || w.time < lastInputSent else { return }
        lastInputSent = w.time
        session.send(.input(peer: session.key, input: input), to: host, reliable: false)
    }

    func chat(_ text: String) {
        switch mode {
        case .host: world?.say(localID, text)
        case .client(let host): session?.send(.chat(peer: session?.key ?? "", text: text), to: host, reliable: true)
        case .joining: break
        }
    }

    func remoteInputs() -> [Int: RpgInput] {
        let current = inputs
        // Held keys persist; a remote input only replaces them when the next packet arrives.
        return current
    }
}

@MainActor
@Observable
final class RpgTitleState {
    var save: RpgSaveData?
    var tampered = false

    func reload() {
        switch RpgSaveStore.load() {
        case .none: save = nil; tampered = false
        case .ok(let s): save = s; tampered = false
        case .tampered: save = nil; tampered = true
        }
    }
}

struct RpgTitleView: View {
    let state: RpgTitleState
    let onContinue: () -> Void
    let onNew: (String, RpgClass, Bool) -> Void

    @State private var name = ""
    @State private var cls = RpgClass.warrior
    @State private var confirmNew = false
    @State private var hardcore = false

    var body: some View {
        VStack(spacing: 18) {
            Text("픽셀 모험").font(.system(size: 40, weight: .heavy))
            Text("마을에서 장비를 사고, 포탈을 넘어 사냥터로. 같은 Wi-Fi의 동료와 자동으로 같은 세계에서 만나요.")
                .foregroundStyle(.secondary)
            if let s = state.save, s.fallen == true {
                GroupBox {
                    HStack(spacing: 14) {
                        RpgSpriteImage(key: s.cls.rawValue).frame(width: 64, height: 64).opacity(0.4).grayscale(1)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("☠ \(s.name) · \(s.cls.name) Lv\(s.level)").font(.title3.bold())
                            Text("하드코어 · \(RpgMaps.def(s.map).name)에서 영원히 잠들었습니다 · 플레이 \(Int(s.playTime / 60))분")
                                .foregroundStyle(.secondary)
                            Text("그 자리에 묘비가 남아 있어요. 새 모험을 시작하세요.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
                .frame(maxWidth: 560)
            } else if let s = state.save {
                GroupBox {
                    HStack(spacing: 14) {
                        RpgSpriteImage(key: s.cls.rawValue).frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(s.name) · \(s.cls.name) Lv\(s.level)").font(.title3.bold())
                            Text("\(RpgMaps.def(s.map).name) · \(s.gold) G · 플레이 \(Int(s.playTime / 60))분")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("이어하기", action: onContinue)
                            .controlSize(.large).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                    .padding(6)
                }
                .frame(maxWidth: 560)
            }
            if state.tampered {
                Text("저장 파일이 변조되어 불러올 수 없어요. 새로 시작하면 기존 파일은 따로 보관돼요.")
                    .font(.callout).foregroundStyle(.red)
            }
            GroupBox("새 모험") {
                VStack(spacing: 12) {
                    HStack {
                        Text("이름")
                        TextField("모험가", text: $name).textFieldStyle(.roundedBorder).frame(width: 200)
                    }
                    HStack(spacing: 12) {
                        ForEach(RpgClass.allCases, id: \.self) { c in
                            Button { cls = c } label: {
                                VStack(spacing: 6) {
                                    RpgSpriteImage(key: c.rawValue).frame(width: 72, height: 72)
                                    Text(c.name).font(.headline)
                                    Text(c.blurb).font(.caption).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center).frame(height: 44)
                                }
                                .padding(10)
                                .frame(width: 170)
                                .background(RoundedRectangle(cornerRadius: 10).fill(cls == c ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cls == c ? Color.accentColor : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle(isOn: $hardcore) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("하드코어 — 죽으면 끝").font(.headline).foregroundStyle(hardcore ? .red : .primary)
                            Text("받는 피해 1.5배, 경험치·드랍 1.3배. 쓰러지면 그 자리에 묘비가 남고 캐릭터는 사라져요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: 520, alignment: .leading)
                    Button(state.save == nil || state.save?.fallen == true ? "모험 시작" : "새로 시작 (기존 캐릭터 삭제)") {
                        if state.save == nil || state.save?.fallen == true { onNew(name, cls, hardcore) } else { confirmNew = true }
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
                .padding(6)
            }
            .frame(maxWidth: 580)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("기존 캐릭터를 지우고 새로 시작할까요?", isPresented: $confirmNew) {
            Button("새로 시작", role: .destructive) { onNew(name, cls, hardcore) }
            Button("취소", role: .cancel) {}
        }
    }
}

/// A class sprite scaled up crisply for SwiftUI.
struct RpgSpriteImage: View {
    let key: String

    var body: some View {
        if let cg = RpgArt.sprite(key) {
            Image(decorative: cg, scale: 1).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

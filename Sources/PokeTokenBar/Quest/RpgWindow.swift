import AppKit
import SwiftUI

// SPIKE: standalone window for 픽셀 모험, opened from the status item menu. Opens on a title screen
// (continue the saved character or make a new one), then swaps in `RpgView`. Saves every few seconds,
// on Esc and when the window closes.

@MainActor
final class RpgWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var titleView: NSView?
    private var game: RpgView?
    private let state = RpgTitleState()

    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        state.reload()
        let title = NSHostingView(rootView: RpgTitleView(state: state,
            onContinue: { [weak self] in self?.continueGame() },
            onNew: { [weak self] name, cls in self?.newGame(name: name, cls: cls) }))
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
            MainActor.assumeIsolated {
                self?.game?.stop()
                self?.game = nil
                if let token = self?.closeObserver { NotificationCenter.default.removeObserver(token) }
                self?.closeObserver = nil
                self?.window = nil
            }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func continueGame() {
        guard case .ok(let data) = RpgSaveStore.load() else { return }
        start(RpgSaveStore.player(from: data, id: 1))
    }

    private func newGame(name: String, cls: RpgClass) {
        if case .tampered = RpgSaveStore.load() { RpgSaveStore.quarantine() }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let player = RpgSaveStore.newPlayer(name: trimmed.isEmpty ? "모험가" : String(trimmed.prefix(10)), cls: cls, id: 1)
        RpgSaveStore.save(RpgSaveStore.snapshot(player))
        start(player)
    }

    private func start(_ player: RpgPlayer) {
        guard let window else { return }
        game?.stop()
        let world = RpgWorld(player: player)
        world.toast("\(player.name)의 모험 시작! 오른쪽 포탈로 초원에 가 보세요")
        let view = RpgView(frame: window.contentView?.bounds ?? .zero, world: world, localID: player.id)
        view.onSave = { RpgSaveStore.save($0) }
        view.onExit = { [weak self] in self?.backToTitle() }
        game = view
        window.contentView = view
        window.makeFirstResponder(view)
    }

    private func backToTitle() {
        game?.stop()
        game = nil
        state.reload()
        if let titleView { window?.contentView = titleView }
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
    let onNew: (String, RpgClass) -> Void

    @State private var name = ""
    @State private var cls = RpgClass.warrior
    @State private var confirmNew = false

    var body: some View {
        VStack(spacing: 18) {
            Text("픽셀 모험").font(.system(size: 40, weight: .heavy))
            Text("마을에서 장비를 사고, 포탈을 넘어 사냥터로. 동굴 끝엔 슬라임 킹이 기다려요.")
                .foregroundStyle(.secondary)
            if let s = state.save {
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
                    Button(state.save == nil ? "모험 시작" : "새로 시작 (기존 캐릭터 삭제)") {
                        if state.save == nil { onNew(name, cls) } else { confirmNew = true }
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
            Button("새로 시작", role: .destructive) { onNew(name, cls) }
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

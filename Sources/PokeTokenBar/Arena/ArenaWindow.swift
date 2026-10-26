import AppKit
import SwiftUI

// SPIKE: standalone arena window opened from the status item menu. Opens on a setup screen (pick a
// champion and the team size), builds every champion's battle data, then swaps in `ArenaView`.

@MainActor
final class ArenaWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var setupView: NSView?
    private var arena: ArenaView?
    private var lastMatch: (blue: [ArenaEntry], red: [ArenaEntry])?
    private let state = ArenaSetupState()

    private static let fallbackIDs = [25, 4, 7, 1, 133, 39, 52, 54, 58, 63, 66, 74, 92, 104, 116, 129]

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let candidates = BattleMonBuilder.candidates(companion: companion)
        let setup = NSHostingView(rootView: ArenaSetupView(state: state, candidates: candidates) { [weak self] pick, size in
            self?.start(pick: pick, teamSize: size, candidates: candidates)
        })
        setupView = setup
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let size = NSSize(width: min(1120, screen.width * 0.9), height: min(740, screen.height * 0.85))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "포켓몬 아레나 (테스트)"
        window.contentView = setup
        window.contentMinSize = NSSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.arena?.stop()
                self?.arena = nil
                if let token = self?.closeObserver { NotificationCenter.default.removeObserver(token) }
                self?.closeObserver = nil
                self?.window = nil
            }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private static func trainerName() -> String {
        let fullName = NSFullUserName()
        let fallback = fullName.isEmpty ? (Host.current().localizedName ?? "") : fullName
        return BattleMonBuilder.trainerName(nickname: UserDefaults.standard.string(forKey: "battleNickname") ?? "",
                                            fallback: fallback)
    }

    /// Builds my champion plus `2 × teamSize − 1` CPU champions from the dex (fallbacks when it is thin).
    private func start(pick: BattleCandidate, teamSize: Int, candidates: [BattleCandidate]) {
        guard !state.loading else { return }
        state.loading = true
        state.error = nil
        Task { @MainActor in
            defer { state.loading = false }
            guard let mine = try? await BattleMonBuilder.build(pick, trainer: Self.trainerName()) else {
                state.error = "포켓몬 정보를 불러오지 못했어요. 네트워크를 확인해 주세요."
                return
            }
            var pool = candidates.filter { $0.speciesID != pick.speciesID && $0.speciesID < 9000 }.shuffled()
            pool += Self.fallbackIDs.shuffled().map {
                BattleCandidate(id: "fallback-\($0)", speciesID: $0, name: "#\($0)", isShiny: false, profile: nil, nature: nil, isRaising: false)
            }
            var cpus: [BattleMon] = []
            var used: Set<Int> = [pick.speciesID]
            for c in pool where cpus.count < teamSize * 2 - 1 {
                guard !used.contains(c.speciesID), let mon = try? await BattleMonBuilder.build(c, trainer: "CPU") else { continue }
                used.insert(c.speciesID)
                cpus.append(mon)
            }
            guard cpus.count == teamSize * 2 - 1 else {
                state.error = "상대 포켓몬을 준비하지 못했어요. 네트워크를 확인해 주세요."
                return
            }
            let blue = [ArenaEntry(mon: mine, trainer: Self.trainerName(), isPlayer: true)]
                + cpus.prefix(teamSize - 1).map { ArenaEntry(mon: $0, trainer: "CPU", isPlayer: false) }
            let red = cpus.suffix(teamSize).map { ArenaEntry(mon: $0, trainer: "CPU", isPlayer: false) }
            lastMatch = (blue, Array(red))
            present(blue: blue, red: Array(red))
        }
    }

    private func present(blue: [ArenaEntry], red: [ArenaEntry]) {
        guard let window else { return }
        arena?.stop()
        let sim = ArenaSim(blue: blue, red: red)
        let view = ArenaView(frame: window.contentView?.bounds ?? .zero, sim: sim)
        view.onExit = { [weak self] in self?.backToSetup() }
        view.onRestart = { [weak self] in
            guard let self, let m = self.lastMatch else { return }
            self.present(blue: m.blue, red: m.red)
        }
        arena = view
        window.contentView = view
        window.makeFirstResponder(view)
        for u in sim.units where u.kind == .champion {
            guard let id = u.speciesID else { continue }
            let unitID = u.id, shiny = u.isShiny
            if let img = SpriteLoader.cachedImage(speciesID: id, shiny: shiny) {
                view.setSprite(img, for: unitID)
            } else {
                Task { [weak view] in
                    if let img = await SpriteLoader.image(speciesID: id, shiny: shiny) { view?.setSprite(img, for: unitID) }
                }
            }
        }
    }

    private func backToSetup() {
        arena?.stop()
        arena = nil
        if let setupView { window?.contentView = setupView }
    }
}

@MainActor
@Observable
final class ArenaSetupState {
    var loading = false
    var error: String?
}

struct ArenaSetupView: View {
    let state: ArenaSetupState
    let candidates: [BattleCandidate]
    let onStart: (BattleCandidate, Int) -> Void

    @AppStorage("arenaPokemon") private var pickedID = "active"
    @AppStorage("arenaTeamSize") private var teamSize = 2

    private var picked: BattleCandidate? { candidates.first { $0.id == pickedID } ?? candidates.first }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("포켓몬 아레나").font(.largeTitle.bold())
                Text("내 포켓몬으로 라인을 밀어 상대 본진 크리스탈을 부수면 승리!").foregroundStyle(.secondary)
                Text("출전할 포켓몬").font(.headline)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(candidates) { c in
                            Button { pickedID = c.id } label: { tile(c) }.buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("대전 방식").font(.title2.bold())
                Picker("", selection: $teamSize) {
                    Text("1 : 1").tag(1)
                    Text("2 : 2").tag(2)
                    Text("3 : 3").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("우리 팀 빈자리와 상대 팀은 CPU 포켓몬이 맡아요.").font(.caption).foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("조작").font(.headline)
                    Group {
                        Text("클릭 — 이동 / 적 클릭 시 공격")
                        Text("Q — 스킬샷 (1번 기술)")
                        Text("W — 범위 폭발 (2번 기술)")
                        Text("E — 돌진 (3번 기술)")
                        Text("R — 궁극기: 주변 폭발 + 보호막 (4번 기술, Lv3)")
                        Text("S 정지 · B 귀환 · Esc 나가기")
                    }
                    .font(.callout)
                }
                Text("기술 위력과 타입 상성이 그대로 데미지에 들어가요.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let error = state.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Button {
                    if let picked { onStart(picked, teamSize) }
                } label: {
                    Group {
                        if state.loading { ProgressView().controlSize(.small) } else { Text("시작하기") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(state.loading || picked == nil)
            }
            .padding(16)
            .frame(width: 320)
            .frame(maxHeight: .infinity)
        }
    }

    private func tile(_ c: BattleCandidate) -> some View {
        let selected = c.id == picked?.id
        return VStack(spacing: 2) {
            KartSpriteThumb(speciesID: c.speciesID, shiny: c.isShiny)
                .frame(width: 64, height: 64)
            Text(c.name).font(.caption.bold()).lineLimit(1)
            Text(c.isRaising ? "키우는 중" : "도감").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
    }
}

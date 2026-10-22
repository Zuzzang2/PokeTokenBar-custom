import AppKit
import SwiftUI

// SPIKE: standalone plaza/battle window opened from the status item menu.

@MainActor
final class BattleWindowController {
    private var window: NSWindow?
    private var session: PlazaSession?

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let host = NSHostingController(rootView: BattleRootView(companion: companion) { [weak self] in self?.session = $0 })
        let window = NSWindow(contentViewController: host)
        window.title = "포켓몬 대결 (테스트)"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 432, height: 640))
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.session?.stop()
                self?.session = nil
                self?.window = nil
            }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

private struct BattleRootView: View {
    let companion: CompanionStore
    let onSession: (PlazaSession) -> Void
    @State private var session: PlazaSession?
    @State private var candidates: [BattleCandidate] = []
    @State private var selected: [String] = []      // party order = tap order
    @State private var preparing = false
    @State private var error: String?
    @AppStorage("battleTrainerDesign") private var trainerDesign = "t1"
    @AppStorage("battleNickname") private var nickname = ""

    private var defaultName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? (Host.current().localizedName ?? "") : fullName
    }

    var body: some View {
        Group {
            if let session {
                PlazaRootView(plaza: session)
            } else if preparing {
                ProgressView("파티 준비 중…")
            } else {
                partyPicker
            }
        }
        .frame(width: 432, height: 640)
        .onAppear {
            let owned = BattleMonBuilder.candidates(companion: companion)
            candidates = owned.isEmpty ? BattleMonBuilder.randomCandidates() : owned
        }
    }

    private var partyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("트레이너").font(.headline)
            HStack {
                Text("닉네임").font(.callout)
                TextField(BattleMonBuilder.trainerName(nickname: "", fallback: defaultName), text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: nickname) {
                        if nickname.count > BattleMonBuilder.maxNicknameLength {
                            nickname = String(nickname.prefix(BattleMonBuilder.maxNicknameLength))
                        }
                    }
                Text("\(nickname.count)/\(BattleMonBuilder.maxNicknameLength)").font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                ForEach(BattleArt.trainerDesigns, id: \.self) { design in
                    Button { trainerDesign = design } label: {
                        VStack(spacing: 2) {
                            if let frame = BattleArt.trainerFrame(design: design, facing: .down, step: 0) {
                                Image(nsImage: frame.image).interpolation(.high).resizable().frame(width: 45, height: 48)
                            }
                            Text(BattleArt.trainerDesignNames[design] ?? design).font(.caption)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(trainerDesign == design ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(trainerDesign == design ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            Text("파티 선택 (\(selected.count)/\(BattleMonBuilder.maxParty))").font(.headline)
            Text("누른 순서대로 파티에 들어가요. 첫 번째가 선봉이에요. 모두 Lv.50으로 맞춰 싸웁니다.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text("준비 실패: \(error)").foregroundStyle(.red).font(.caption) }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(candidates) { c in
                        let order = selected.firstIndex(of: c.id)
                        Button { toggle(c.id) } label: {
                            HStack {
                                SpriteThumb(speciesID: c.speciesID, shiny: c.isShiny).frame(width: 40, height: 40)
                                Text(c.name + (c.isShiny ? " ✦" : "") + (c.isRaising ? " (키우는 중)" : ""))
                                Spacer()
                                if let order { Text("\(order + 1)").bold().foregroundStyle(.tint) }
                            }
                            .padding(4)
                            .contentShape(Rectangle())
                            .background(order != nil ? Color.accentColor.opacity(0.15) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button("이 파티로 광장 입장") { Task { await enterLobby() } }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected = selected.filter { $0 != id } }
        else if selected.count < BattleMonBuilder.maxParty { selected = selected + [id] }
    }

    private func enterLobby() async {
        preparing = true
        defer { preparing = false }
        do {
            let trainer = BattleMonBuilder.trainerName(nickname: nickname, fallback: defaultName)
            let picks = selected.compactMap { id in candidates.first { $0.id == id } }
            var team: [BattleMon] = []
            for pick in picks { team.append(try await BattleMonBuilder.build(pick, trainer: trainer)) }
            let s = PlazaSession(team: team, trainerDesign: trainerDesign)
            onSession(s)
            session = s
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SpriteThumb: View {
    let speciesID: Int
    let shiny: Bool
    @State private var sprite: NSImage?

    var body: some View {
        Group {
            if let sprite { Image(nsImage: sprite).interpolation(.none).resizable().scaledToFit() }
            else { Color.clear }
        }
        .task(id: speciesID) {
            if let data = await SpriteStore.shared.data(speciesID: speciesID, animated: false, shiny: shiny) {
                sprite = NSImage(data: data)
            }
        }
    }
}

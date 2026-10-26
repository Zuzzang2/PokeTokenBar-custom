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
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        // The plaza needs room for the field plus the roster panel: big, but never past the screen.
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        window.setContentSize(NSSize(width: min(1280, screen.width * 0.92), height: min(960, screen.height * 0.9)))
        window.contentMinSize = NSSize(width: 432, height: 640)
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
    @State private var query = ""
    @State private var preparing = false
    @State private var error: String?
    @State private var savedParties: [SavedParty] = SavedPartyStore.load()
    @State private var partyName = ""
    @State private var partyNote = ""
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
        .frame(minWidth: 432, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(BattleArt.trainerDesigns.filter { BattleArt.trainerFrame(design: $0, facing: .down, step: 0) != nil },
                        id: \.self) { design in
                    Button { trainerDesign = design } label: {
                        VStack(spacing: 2) {
                            if let frame = BattleArt.trainerFrame(design: design, facing: .down, step: 0) {
                                Image(nsImage: frame.image).interpolation(.high).resizable().scaledToFit().frame(height: 40)
                            }
                            Text(BattleArt.trainerDesignNames[design] ?? design).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(trainerDesign == design ? Color.blue.opacity(0.22) : Color.secondary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8)   // fixed color: accentColor greys out in inactive windows
                            .stroke(trainerDesign == design ? Color.blue : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            Text("파티 선택 (\(selected.count)/\(BattleMonBuilder.maxParty))").font(.headline)
            Text("누른 순서대로 파티에 들어가요. 첫 번째가 선봉이에요. 모두 Lv.50으로 맞춰 싸웁니다.")
                .font(.caption).foregroundStyle(.secondary)
            savedPartiesSection
            if let error { Text("준비 실패: \(error)").foregroundStyle(.red).font(.caption) }
            TextField("이름이나 번호로 찾기", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(SpeciesRoster.filter(candidates, query: query)) { c in
                        let order = selected.firstIndex(of: c.id)
                        Button { toggle(c.id) } label: {
                            HStack {
                                SpriteThumb(speciesID: c.speciesID, shiny: c.isShiny).frame(width: 40, height: 40)
                                Text(c.name + (c.isShiny ? " ✦" : "") + (c.isRaising ? " (키우는 중)" : ""))
                                if c.id.hasPrefix("free-") {
                                    Text("#\(c.speciesID)").font(.caption).foregroundStyle(.secondary)
                                }
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

    /// Favourite combinations: save the current party under a name, load or delete it later.
    private var savedPartiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(SavedPartyStore.defaultName(in: savedParties), text: $partyName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: partyName) {
                        if partyName.count > SavedPartyStore.maxNameLength {
                            partyName = String(partyName.prefix(SavedPartyStore.maxNameLength))
                        }
                    }
                Button("현재 조합 저장") { saveCurrentParty() }
                    .disabled(selected.isEmpty)
            }
            if savedParties.isEmpty {
                Text("마음에 드는 조합을 저장해 두면 다음에 한 번에 불러올 수 있어요. (최대 \(SavedPartyStore.maxSaved)개)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(savedParties) { party in
                    HStack(spacing: 6) {
                        Button { load(party) } label: {
                            HStack(spacing: 4) {
                                Text(party.name).font(.callout.bold())
                                ForEach(Array(party.members.enumerated()), id: \.offset) { _, m in
                                    SpriteThumb(speciesID: m.speciesID, shiny: m.shiny).frame(width: 26, height: 26)
                                }
                                Spacer(minLength: 0)
                                Text("불러오기").font(.caption).foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { delete(party) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("이 조합 삭제")
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                }
            }
            if !partyNote.isEmpty { Text(partyNote).font(.caption).foregroundStyle(.orange) }
        }
    }

    private func saveCurrentParty() {
        let members = selected.compactMap { id in candidates.first { $0.id == id } }
            .map { SavedParty.Member(id: $0.id, speciesID: $0.speciesID, name: $0.name, shiny: $0.isShiny) }
        guard !members.isEmpty else { return }
        let trimmed = partyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? SavedPartyStore.defaultName(in: savedParties) : trimmed
        savedParties = SavedPartyStore.adding(SavedParty(name: name, members: members), to: savedParties)
        SavedPartyStore.save(savedParties)
        partyName = ""
        partyNote = ""
    }

    private func load(_ party: SavedParty) {
        let result = SavedPartyStore.resolve(party, candidates: candidates, limit: BattleMonBuilder.maxParty)
        selected = result.ids
        partyNote = result.missing > 0 ? "\(result.missing)마리는 더 이상 없어서 빠졌어요." : ""
    }

    private func delete(_ party: SavedParty) {
        savedParties = savedParties.filter { $0.id != party.id }
        SavedPartyStore.save(savedParties)
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
            // Unlock-only picks (무쇠깨비, free pick) are not part of the trainer's real collection.
            let shared = SecretMonster.ownedOnly(candidates)
                .map { CollectionEntry(speciesID: $0.speciesID, name: $0.name, shiny: $0.isShiny) }
            let s = PlazaSession(team: team, collection: shared, trainerDesign: trainerDesign)
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

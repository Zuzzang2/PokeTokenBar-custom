import AppKit
import SwiftUI

// SPIKE: the kart lobby screen. Pick the Pokémon that rides your kart, see who else is waiting nearby,
// and (host only) start the race. Practice runs solo against CPUs without touching the lobby.

struct KartLobbyView: View {
    let session: KartSession
    let candidates: [BattleCandidate]
    let onSolo: () -> Void
    let onHostStart: (_ fillCPU: Bool) -> Void

    @AppStorage("battleNickname") private var nickname = ""
    @AppStorage("kartFillCPU") private var fillCPU = true
    @AppStorage(KartWindowController.pickKey) private var pickedID = "active"

    private var defaultName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? (Host.current().localizedName ?? "") : fullName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            picker
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            lobby
                .frame(width: 340)
                .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    // MARK: my kart

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("포켓몬 카트").font(.largeTitle.bold())
            HStack {
                Text("닉네임").font(.callout)
                TextField(BattleMonBuilder.trainerName(nickname: "", fallback: defaultName), text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: nickname) {
                        if nickname.count > BattleMonBuilder.maxNicknameLength {
                            nickname = String(nickname.prefix(BattleMonBuilder.maxNicknameLength))
                        }
                        let name = BattleMonBuilder.trainerName(nickname: nickname, fallback: defaultName)
                        session.update { $0.trainer = name }
                    }
            }
            Text("카트에 태울 포켓몬").font(.headline)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(candidates) { c in
                        Button { choose(c) } label: { tile(c) }
                            .buttonStyle(.plain)
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
            KartSpriteThumb(speciesID: c.speciesID, shiny: c.isShiny)
                .frame(width: 64, height: 64)
            Text(c.name).font(.caption.bold()).lineLimit(1)
            Text(c.isRaising ? "키우는 중 · Lv.\(c.profile?.level ?? 1)" : "Lv.\(c.profile?.level ?? 50)")
                .font(.caption2).foregroundStyle(.secondary)
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
            $0.level = c.profile?.level ?? (c.isRaising ? 1 : 50)
            $0.pokemonName = c.name
        }
    }

    // MARK: lobby

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("대기방").font(.title2.bold())
                Spacer()
                Text("\(session.everyone.count)/\(KartSession.capacity)").foregroundStyle(.secondary)
            }
            Text("같은 Wi-Fi에서 카트 창을 연 사람끼리 자동으로 모여요.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(session.everyone, id: \.id) { p in row(p) }
                }
            }
            if !session.notice.isEmpty {
                Text(session.notice).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if session.isHost {
                Toggle("빈자리를 CPU로 채우기 (4대까지)", isOn: $fillCPU)
                Button {
                    onHostStart(fillCPU)
                } label: {
                    Text(startLabel).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                let host = session.everyone.first { $0.id == session.hostID }?.trainer ?? "방장"
                Text("방장 \(host) 님이 시작하면 같이 출발해요.")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            }
            Button(action: onSolo) {
                Text("혼자 연습하기 (CPU 3대)").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(16)
    }

    private var startLabel: String {
        let humans = session.waiting.count
        let cpus = fillCPU ? max(0, 4 - humans) : 0
        return cpus > 0 ? "레이스 시작 (\(humans)명 + CPU \(cpus))" : "레이스 시작 (\(humans)명)"
    }

    private func row(_ p: KartPlayerInfo) -> some View {
        HStack(spacing: 10) {
            KartSpriteThumb(speciesID: p.speciesID, shiny: p.isShiny)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(p.trainer).font(.callout.bold()).lineLimit(1)
                    if p.id == session.me.id { badge("나", .blue) }
                    if p.id == session.hostID { badge("방장", .orange) }
                }
                Text("\(p.pokemonName) · Lv.\(p.level)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if p.inRace { badge("레이스 중", .green) }
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

/// A Pokémon sprite from the cache, fetched once if this machine has never shown that species.
struct KartSpriteThumb: View {
    let speciesID: Int?
    let shiny: Bool
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark.circle").font(.title2).foregroundStyle(.tertiary)
            }
        }
        .task(id: speciesID) {
            guard let id = speciesID else { image = nil; return }
            if let cached = SpriteLoader.cachedImage(speciesID: id, shiny: shiny) { image = cached; return }
            image = await SpriteLoader.image(speciesID: id, shiny: shiny)
        }
    }
}

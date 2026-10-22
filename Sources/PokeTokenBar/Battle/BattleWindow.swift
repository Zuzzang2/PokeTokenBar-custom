import AppKit
import SwiftUI

// SPIKE: standalone battle window opened from the status item menu.

@MainActor
final class BattleWindowController {
    private var window: NSWindow?
    private var session: BattleSession?

    func show(companion: CompanionStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let host = NSHostingController(rootView: BattleRootView(companion: companion) { [weak self] in self?.session = $0 })
        let window = NSWindow(contentViewController: host)
        window.title = "포켓몬 대결 (테스트)"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 560))
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
    let onSession: (BattleSession) -> Void
    @State private var session: BattleSession?
    @State private var candidates: [BattleCandidate] = []
    @State private var selected: [String] = []      // party order = tap order
    @State private var preparing = false
    @State private var error: String?

    var body: some View {
        Group {
            if let session {
                BattleSessionView(session: session)
            } else if preparing {
                ProgressView("파티 준비 중…")
            } else {
                partyPicker
            }
        }
        .frame(width: 420, height: 600)
        .onAppear {
            let owned = BattleMonBuilder.candidates(companion: companion)
            candidates = owned.isEmpty ? BattleMonBuilder.randomCandidates() : owned
        }
    }

    private var partyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Button("이 파티로 대결 로비 입장") { Task { await enterLobby() } }
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
            let fullName = NSFullUserName()
            let trainer = fullName.isEmpty ? (Host.current().localizedName ?? "트레이너") : fullName
            let picks = selected.compactMap { id in candidates.first { $0.id == id } }
            var team: [BattleMon] = []
            for pick in picks { team.append(try await BattleMonBuilder.build(pick, trainer: trainer)) }
            let s = BattleSession(me: team)
            onSession(s)
            session = s
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct BattleSessionView: View {
    let session: BattleSession

    var body: some View {
        VStack(spacing: 12) {
            switch session.phase {
            case .lobby, .connecting: lobby
            case .battling, .finished, .disconnected: battle
            }
        }
        .padding(16)
    }

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내 파티").font(.headline)
            HStack {
                ForEach(Array(session.me.enumerated()), id: \.offset) { _, mon in
                    SpriteThumb(speciesID: mon.speciesID, shiny: mon.isShiny).frame(width: 48, height: 48)
                }
            }
            if let inviter = session.pendingInviter {
                GroupBox {
                    VStack(alignment: .leading) {
                        Text("\(inviter.displayName)이(가) 대결을 신청했어요!").bold()
                        HStack {
                            Button("수락") { session.answerInvite(true) }.keyboardShortcut(.defaultAction)
                            Button("거절") { session.answerInvite(false) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(session.status).foregroundStyle(.secondary).font(.caption)
            Text("근처 트레이너").font(.headline)
            if session.nearby.isEmpty {
                Text("아직 아무도 없어요. 상대도 이 창에서 로비에 들어와야 보여요.").foregroundStyle(.secondary)
            }
            ForEach(session.nearby, id: \.self) { peer in
                HStack {
                    Text(peer.displayName).lineLimit(1)
                    Spacer()
                    Button("대결 신청") { session.invite(peer) }.disabled(session.phase != .lobby)
                }
            }
            Spacer()
        }
    }

    private var battle: some View {
        VStack(spacing: 10) {
            if let theirs = session.theirTeam, let mine = session.myTeam, let state = session.state {
                let me = session.myIndex, them = session.theirIndex
                MonCard(mon: theirs[state.active[them]], hp: state.activeHP(them), flipped: true,
                        remaining: state.hp[them].map { $0 > 0 })
                MonCard(mon: mine[state.active[me]], hp: state.activeHP(me), flipped: false,
                        remaining: state.hp[me].map { $0 > 0 })
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(state.log.enumerated()), id: \.offset) { i, line in
                                Text(line).font(.callout).id(i)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: state.log.count) { proxy.scrollTo(state.log.count - 1) }
                }
                if session.phase == .battling {
                    if session.mustReplace {
                        Text("다음 포켓몬을 고르세요").bold()
                        switchRow(mine: mine, state: state, me: me) { session.replace(with: $0) }
                    } else if !state.awaitingReplacement {
                        LazyVGrid(columns: [GridItem(), GridItem()]) {
                            ForEach(Array(mine[state.active[me]].moves.enumerated()), id: \.offset) { i, move in
                                Button { session.act(.move(i)) } label: {
                                    VStack {
                                        Text(move.name).bold()
                                        Text("\(move.type) · 위력 \(move.power)").font(.caption2)
                                    }.frame(maxWidth: .infinity)
                                }
                                .tint(BadgeTint.type(PokemonType(apiName: move.type)).color)
                                .buttonStyle(.borderedProminent)
                                .disabled(session.waitingForOpponent)
                            }
                        }
                        if mine.count > 1 {
                            Text("교체").font(.caption).foregroundStyle(.secondary)
                            switchRow(mine: mine, state: state, me: me) { session.act(.switchTo($0)) }
                                .disabled(session.waitingForOpponent)
                        }
                    }
                    if session.waitingForOpponent { Text("상대의 선택을 기다리는 중…").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if !session.status.isEmpty { Text(session.status).font(.title2).bold() }
        }
    }

    private func switchRow(mine: [BattleMon], state: BattleState, me: Int, pick: @escaping (Int) -> Void) -> some View {
        HStack {
            ForEach(Array(mine.enumerated()), id: \.offset) { slot, mon in
                Button { pick(slot) } label: {
                    VStack(spacing: 0) {
                        SpriteThumb(speciesID: mon.speciesID, shiny: mon.isShiny).frame(width: 36, height: 36)
                        Text("\(state.hp[me][slot])").font(.caption2.monospacedDigit())
                    }
                }
                .disabled(!state.canSwitch(me, to: slot))
                .opacity(state.hp[me][slot] == 0 ? 0.3 : 1)
            }
        }
    }
}

private struct SpriteThumb: View {
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

private struct MonCard: View {
    let mon: BattleMon
    let hp: Int
    let flipped: Bool
    let remaining: [Bool]

    var body: some View {
        HStack {
            if flipped { info; Spacer() }
            SpriteThumb(speciesID: mon.speciesID, shiny: mon.isShiny)
                .frame(width: 80, height: 80)
                .scaleEffect(x: flipped ? 1 : -1)
            if !flipped { Spacer(); info }
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(mon.name)\(mon.isShiny ? " ✦" : "") Lv.50").bold()
            HStack(spacing: 3) {
                Text(mon.trainer).font(.caption).foregroundStyle(.secondary)
                ForEach(Array(remaining.enumerated()), id: \.offset) { _, alive in
                    Circle().fill(alive ? Color.red : Color.gray.opacity(0.4)).frame(width: 7, height: 7)
                }
            }
            ProgressView(value: Double(hp), total: Double(mon.maxHP))
                .tint(Double(hp) / Double(mon.maxHP) > 0.5 ? .green : Double(hp) / Double(mon.maxHP) > 0.2 ? .yellow : .red)
                .frame(width: 160)
            Text("\(hp) / \(mon.maxHP)").font(.caption.monospacedDigit())
        }
    }
}

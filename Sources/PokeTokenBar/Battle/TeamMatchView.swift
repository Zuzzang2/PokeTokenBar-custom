import SwiftUI

// SPIKE: the 2:2 team battle screen. Foes on top, our team below (we are the bottom-left card),
// a caption line that replays the last step, then the move / target / switch controls.

struct TeamMatchView: View {
    let match: TeamBattleMatch
    let onLeave: () -> Void
    @State private var shownHP: [[Int]] = []
    @State private var shownActive = [0, 0, 0, 0]
    @State private var caption = ""
    @State private var isPlaying = false
    @State private var pendingMove: Int?

    var body: some View {
        VStack(spacing: 10) {
            if let state = match.state, let mine = match.myTeam, !shownHP.isEmpty {
                let me = match.myIndex
                HStack(alignment: .top, spacing: 12) {
                    ForEach(TeamBattleState.foes(of: me), id: \.self) { foe in
                        card(foe, state: state, isFoe: true)
                    }
                }
                Text(caption.isEmpty ? " " : caption)
                    .font(.callout).frame(maxWidth: .infinity, minHeight: 36)
                    .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                HStack(alignment: .top, spacing: 12) {
                    ForEach([me, TeamBattleState.partner(of: me)], id: \.self) { ally in
                        card(ally, state: state, isFoe: false)
                    }
                }
                if match.phase == .battling && !isPlaying { controls(state: state, mine: mine, me: me) }
            } else if match.state != nil {
                ProgressView()
            } else {
                ProgressView("참가자와 연결 중…")
            }
            if !match.status.isEmpty && !isPlaying { Text(match.status).font(.title2).bold() }
            if match.isOver && !isPlaying {
                Button("광장으로 돌아가기", action: onLeave).buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
        }
        .task(id: match.state?.step) { await replay() }
    }

    // MARK: - Cards

    private func card(_ trainer: Int, state: TeamBattleState, isFoe: Bool) -> some View {
        let team = match.teams[trainer] ?? []
        let slot = shownActive[trainer]
        let mon = team.indices.contains(slot) ? team[slot] : nil
        let hp = shownHP[trainer].indices.contains(slot) ? shownHP[trainer][slot] : 0
        let out = state.isOut(trainer) && !isPlaying
        let targetable = isFoe && pendingMove != nil && state.canTarget(trainer)
        return VStack(spacing: 4) {
            if let mon {
                SpriteThumb(speciesID: mon.speciesID, shiny: mon.isShiny).frame(width: 72, height: 72)
                    .opacity(hp == 0 ? 0.25 : 1)
                Text(mon.name).font(.callout.bold()).lineLimit(1)
                ProgressView(value: Double(hp), total: Double(max(1, mon.maxHP)))
                    .tint(hp * 2 > mon.maxHP ? .green : hp * 5 > mon.maxHP ? .yellow : .red)
                Text("\(hp)/\(mon.maxHP)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(trainer == match.myIndex ? "\(match.trainerName(trainer)) (나)" : match.trainerName(trainer))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if out { Text("전원 쓰러짐").font(.caption2.bold()).foregroundStyle(.red) }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor, lineWidth: targetable ? 3 : 0))
        .opacity(out ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard targetable, let move = pendingMove else { return }
            pendingMove = nil
            match.act(.move(move, target: trainer))
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private func controls(state: TeamBattleState, mine: [BattleMon], me: Int) -> some View {
        if match.mustReplace {
            Text("다음 포켓몬을 고르세요").bold()
            switchRow(mine: mine, state: state, me: me) { match.replace(with: $0) }
        } else if match.iAmOut {
            waiting("파트너의 승부를 지켜보는 중…")
        } else if match.hasActed || state.awaitingReplacement {
            waiting(waitingText())
        } else if pendingMove != nil {
            HStack {
                Text("공격할 상대를 눌러 고르세요").bold()
                Button("취소") { pendingMove = nil }
            }
        } else {
            let moves = mine[state.active[me]].moves
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                ForEach(Array(moves.enumerated()), id: \.offset) { i, move in
                    Button { choose(move: i, state: state, me: me) } label: {
                        VStack {
                            Text(move.name).bold()
                            Text("\(move.type) · 위력 \(move.power)").font(.caption2)
                        }.frame(maxWidth: .infinity)
                    }
                    .tint(BadgeTint.type(PokemonType(apiName: move.type)).color)
                    .buttonStyle(.borderedProminent)
                }
            }
            if mine.count > 1 {
                Text("교체").font(.caption).foregroundStyle(.secondary)
                switchRow(mine: mine, state: state, me: me) { match.act(.switchTo($0)) }
            }
        }
    }

    /// One living foe is attacked straight away; with two, the player taps the target card.
    private func choose(move: Int, state: TeamBattleState, me: Int) {
        let targets = TeamBattleState.foes(of: me).filter { state.canTarget($0) }
        if targets.count == 1, let only = targets.first {
            match.act(.move(move, target: only))
        } else {
            pendingMove = move
        }
    }

    private func waiting(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func waitingText() -> String {
        let names = match.waitingFor.map { match.trainerName($0) }
        return names.isEmpty ? "진행 중…" : "\(names.joined(separator: "·"))의 선택을 기다리는 중…"
    }

    private func switchRow(mine: [BattleMon], state: TeamBattleState, me: Int,
                           pick: @escaping (Int) -> Void) -> some View {
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

    // MARK: - Replay

    /// Plays the step's events in order so bars and sprites change with the captions, then settles
    /// on the real state (a newer step cancels this task; the next one settles instead).
    private func replay() async {
        guard let state = match.state else { return }
        if shownHP.isEmpty { shownHP = state.hp; shownActive = [0, 0, 0, 0] }
        isPlaying = true
        defer { if !Task.isCancelled { isPlaying = false } }
        for event in state.events {
            if Task.isCancelled { return }
            switch event {
            case .message(let text):
                caption = text
                try? await Task.sleep(for: .milliseconds(700))
            case .switchIn(let trainer, let slot):
                shownActive[trainer] = slot
                try? await Task.sleep(for: .milliseconds(250))
            case .attack:
                try? await Task.sleep(for: .milliseconds(200))
            case .damage(let trainer, let hp, _, _):
                let slot = shownActive[trainer]
                if shownHP[trainer].indices.contains(slot) { shownHP[trainer][slot] = hp }
                try? await Task.sleep(for: .milliseconds(450))
            case .miss, .faint:
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        if Task.isCancelled { return }
        shownHP = state.hp
        shownActive = state.active
        pendingMove = nil
    }
}

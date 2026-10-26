import SwiftUI

// SPIKE: the 2:2 team battle screen. `TeamBattleSceneView` draws and replays the fight; below it
// come the move / target / switch controls.

struct TeamMatchView: View {
    let match: TeamBattleMatch
    var result: MatchResult?
    let onLeave: () -> Void
    @State private var isPlaying = false
    @State private var pendingMove: Int?

    var body: some View {
        VStack(spacing: 10) {
            if let state = match.state, let mine = match.myTeam, match.teams.allSatisfy({ $0 != nil }) {
                let me = match.myIndex
                let targets = pendingMove == nil ? [] : TeamBattleState.foes(of: me).filter { state.canTarget($0) }
                TeamBattleSceneView(me: me, state: state, teams: match.teams.compactMap { $0 },
                                    names: (0..<4).map { match.trainerName($0) }, targetable: Set(targets),
                                    onTarget: { target in
                                        guard let move = pendingMove else { return }
                                        pendingMove = nil
                                        match.act(.move(move, target: target))
                                    }, isPlaying: $isPlaying)
                if match.phase == .battling && !isPlaying { controls(state: state, mine: mine, me: me) }
            } else if match.state != nil {
                ProgressView()
            } else {
                ProgressView("참가자와 연결 중…")
            }
            if !match.status.isEmpty && !isPlaying { Text(match.status).font(.title2).bold() }
            if match.isOver && !isPlaying {
                if let result { MatchResultCard(result: result) }
                Button("광장으로 돌아가기", action: onLeave).buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
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
                Text("장면에서 공격할 상대를 눌러 고르세요").bold()
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
}

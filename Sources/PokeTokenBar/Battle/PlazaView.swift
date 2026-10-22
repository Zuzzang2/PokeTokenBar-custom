import AppKit
import SwiftUI

// SPIKE: the plaza screen. Each trainer walks around as their lead Pokémon; click someone to
// challenge them, chat at the bottom. A match takes over the window until it ends.

struct PlazaRootView: View {
    let plaza: PlazaSession

    var body: some View {
        if let match = plaza.match {
            MatchView(match: match, opponentName: plaza.players[match.opponentID]?.profile.trainer) {
                plaza.leaveMatch()
            }
            .padding(16)
        } else {
            PlazaView(plaza: plaza)
        }
    }
}

private struct PlazaView: View {
    let plaza: PlazaSession
    @State private var selected: String?
    @State private var draft = ""
    @FocusState private var fieldAreaFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            header
            ZStack(alignment: .topLeading) {
                PlazaGround()
                    .onTapGesture { selected = nil; fieldAreaFocused = true }   // walking needs key focus
                ForEach(plaza.everyone) { player in
                    Avatar(player: player, isMe: player.id == plaza.me.id, isSelected: selected == player.id)
                        .position(x: player.x, y: player.y)
                        .animation(player.id == plaza.me.id ? nil : .linear(duration: 0.12), value: player.x)
                        .animation(player.id == plaza.me.id ? nil : .linear(duration: 0.12), value: player.y)
                        .onTapGesture {
                            if player.id != plaza.me.id { selected = selected == player.id ? nil : player.id }
                            fieldAreaFocused = true
                        }
                }
                if let id = selected, let player = plaza.players[id] {
                    challengeCard(player).position(x: min(310, max(90, player.x)), y: max(60, player.y - 70))
                }
            }
            .frame(width: PlazaSession.size.width, height: PlazaSession.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .focusable()
            .focusEffectDisabled()
            .focused($fieldAreaFocused)
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
                let step = 7.0
                switch press.key {
                case .upArrow: plaza.walk(dx: 0, dy: -step)
                case .downArrow: plaza.walk(dx: 0, dy: step)
                case .leftArrow: plaza.walk(dx: -step, dy: 0)
                default: plaza.walk(dx: step, dy: 0)
                }
                return .handled
            }
            .onAppear { fieldAreaFocused = true }

            if let id = plaza.incomingChallenge, let player = plaza.players[id] {
                incomingBanner(player)
            }
            chatPanel
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            Text("광장").font(.headline)
            Text("\(plaza.everyone.count)/\(PlazaSession.capacity)명").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("방향키로 이동 · 상대를 눌러 대결 신청").font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: PlazaSession.size.width)
    }

    private func challengeCard(_ player: PlazaPlayer) -> some View {
        VStack(spacing: 6) {
            Text(player.profile.trainer).font(.callout.bold())
            Text("대표 포켓몬: \(player.profile.leadName)").font(.caption)
            if player.busy {
                Text("대결 중").font(.caption.bold()).foregroundStyle(.orange)
            } else if plaza.outgoingChallenge == player.id {
                Text("응답을 기다리는 중…").font(.caption)
            } else {
                Button("대결 신청") { plaza.challenge(player.id); selected = nil }
                    .buttonStyle(.borderedProminent)
                    .disabled(plaza.outgoingChallenge != nil)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
        .shadow(radius: 4)
    }

    private func incomingBanner(_ player: PlazaPlayer) -> some View {
        HStack {
            Text("\(KoreanParticle.subject.attach(to: player.profile.trainer)) 대결을 신청했어요!").bold()
            Spacer()
            Button("수락") { plaza.answerChallenge(true) }.buttonStyle(.borderedProminent)
            Button("거절") { plaza.answerChallenge(false) }
        }
        .padding(10)
        .frame(width: PlazaSession.size.width)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.18)))
    }

    private var chatPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !plaza.notice.isEmpty { Text(plaza.notice).font(.caption).foregroundStyle(.secondary) }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(plaza.chat) { line in
                            (Text(line.name).bold().foregroundColor(line.name == "광장" ? .secondary : .accentColor)
                             + Text("  " + line.text))
                                .font(.callout)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: plaza.chat.count) { if let last = plaza.chat.last { proxy.scrollTo(last.id) } }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            HStack {
                TextField("메시지 입력 후 Enter", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        plaza.say(draft)
                        draft = ""
                        fieldAreaFocused = true   // back to walking after sending
                    }
                Button("보내기") { plaza.say(draft); draft = "" }.disabled(draft.isEmpty)
            }
        }
        .frame(width: PlazaSession.size.width)
    }
}

/// One trainer on the plaza: lead Pokémon sprite, name tag, chat bubble, busy badge.
private struct Avatar: View {
    let player: PlazaPlayer
    let isMe: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 1) {
            if let bubble = player.bubble {
                Text(bubble)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .frame(maxWidth: 130)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    .foregroundStyle(.black)
                    .shadow(radius: 1)
            } else if player.busy {
                Text("대결 중").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange))
            }
            SpriteView(speciesID: player.profile.speciesID, size: 52, animated: true, shiny: player.profile.shiny)
                .scaleEffect(x: player.facingLeft ? 1 : -1)
                .background(Ellipse().fill(Color.black.opacity(0.18)).frame(width: 40, height: 10).offset(y: 24))
            Text(player.profile.trainer)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(isMe ? Color.blue.opacity(0.85) : Color.black.opacity(0.55)))
                .overlay(Capsule().stroke(isSelected ? Color.yellow : .clear, lineWidth: 2))
        }
        .fixedSize()
        .contentShape(Rectangle())
    }
}

/// Drawn town square: paving, grass border, fountain, trees and benches.
private struct PlazaGround: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.52, green: 0.76, blue: 0.42)))
            let square = CGRect(x: 18, y: 50, width: w - 36, height: h - 64)
            ctx.fill(Path(roundedRect: square, cornerRadius: 14), with: .color(Color(red: 0.86, green: 0.82, blue: 0.72)))
            // Paving tiles
            var tiles = Path()
            stride(from: square.minX, through: square.maxX, by: 24).forEach {
                tiles.move(to: CGPoint(x: $0, y: square.minY)); tiles.addLine(to: CGPoint(x: $0, y: square.maxY))
            }
            stride(from: square.minY, through: square.maxY, by: 24).forEach {
                tiles.move(to: CGPoint(x: square.minX, y: $0)); tiles.addLine(to: CGPoint(x: square.maxX, y: $0))
            }
            ctx.stroke(tiles, with: .color(Color.black.opacity(0.06)), lineWidth: 1)
            // Fountain
            let c = CGPoint(x: w / 2, y: h / 2 + 18)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 46, y: c.y - 24, width: 92, height: 48)),
                     with: .color(Color(red: 0.62, green: 0.62, blue: 0.66)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 38, y: c.y - 18, width: 76, height: 36)),
                     with: .color(Color(red: 0.45, green: 0.72, blue: 0.92)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 16, width: 16, height: 20)),
                     with: .color(Color.white.opacity(0.85)))
            // Trees along the top edge
            for x in stride(from: 30.0, through: w - 30, by: 52) {
                ctx.fill(Path(CGRect(x: x - 3, y: 30, width: 6, height: 14)), with: .color(Color(red: 0.45, green: 0.3, blue: 0.18)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 16, y: 4, width: 32, height: 32)),
                         with: .color(Color(red: 0.25, green: 0.55, blue: 0.3)))
            }
            // Benches
            for x in [70.0, w - 110] {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: h - 40, width: 40, height: 10), cornerRadius: 2),
                         with: .color(Color(red: 0.6, green: 0.4, blue: 0.22)))
            }
        }
    }
}

/// Battle screen for a plaza match.
struct MatchView: View {
    let match: BattleMatch
    let opponentName: String?
    let onLeave: () -> Void
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 10) {
            if let theirs = match.theirTeam, let mine = match.myTeam, let state = match.state {
                let me = match.myIndex
                let teams = me == 0 ? [mine, theirs] : [theirs, mine]
                BattleSceneView(session: match, state: state, teams: teams, isPlaying: $isPlaying)
                if match.phase == .battling && !isPlaying {
                    if match.mustReplace {
                        Text("다음 포켓몬을 고르세요").bold()
                        switchRow(mine: mine, state: state, me: me) { match.replace(with: $0) }
                    } else if !state.awaitingReplacement {
                        LazyVGrid(columns: [GridItem(), GridItem()]) {
                            ForEach(Array(mine[state.active[me]].moves.enumerated()), id: \.offset) { i, move in
                                Button { match.act(.move(i)) } label: {
                                    VStack {
                                        Text(move.name).bold()
                                        Text("\(move.type) · 위력 \(move.power)").font(.caption2)
                                    }.frame(maxWidth: .infinity)
                                }
                                .tint(BadgeTint.type(PokemonType(apiName: move.type)).color)
                                .buttonStyle(.borderedProminent)
                                .disabled(match.waitingForOpponent)
                            }
                        }
                        if mine.count > 1 {
                            Text("교체").font(.caption).foregroundStyle(.secondary)
                            switchRow(mine: mine, state: state, me: me) { match.act(.switchTo($0)) }
                                .disabled(match.waitingForOpponent)
                        }
                    }
                    if match.waitingForOpponent { Text("상대의 선택을 기다리는 중…").font(.caption).foregroundStyle(.secondary) }
                }
            } else {
                ProgressView("\(opponentName ?? "상대")와 연결 중…")
            }
            if !match.status.isEmpty && !isPlaying { Text(match.status).font(.title2).bold() }
            if match.isOver && !isPlaying {
                Button("광장으로 돌아가기", action: onLeave).buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
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

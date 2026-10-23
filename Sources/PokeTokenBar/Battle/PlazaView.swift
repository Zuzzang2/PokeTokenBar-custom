import AppKit
import SwiftUI

// SPIKE: the plaza screen. Each trainer walks around with their lead Pokémon following behind;
// click someone to challenge them, chat at the bottom. A match takes over the window until it ends.

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

/// The town is bigger than the window: a fixed zoom, and a camera that follows the local player.
enum PlazaLayout {
    static let zoom: CGFloat = 1.3

    /// Top-left of the visible world rect (world points) centred on `center`, clamped to the map.
    static func camera(center: CGPoint, viewport: CGSize) -> CGPoint {
        let map = PlazaMap.size
        func axis(_ c: CGFloat, _ view: CGFloat, _ world: CGFloat) -> CGFloat {
            view >= world ? 0 : min(max(0, c - view / 2), world - view)
        }
        return CGPoint(x: axis(center.x, viewport.width, map.width), y: axis(center.y, viewport.height, map.height))
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
            GeometryReader { geo in
                viewport(size: geo.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .focusable()
            .focusEffectDisabled()
            .focused($fieldAreaFocused)
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow], phases: [.down, .repeat, .up]) { press in
                let direction: PlazaFacing = switch press.key {
                case .upArrow: .up
                case .downArrow: .down
                case .leftArrow: .left
                default: .right
                }
                plaza.setKey(direction, pressed: press.phase != .up)   // held keys; the ticker moves
                return .handled
            }
            .onChange(of: fieldAreaFocused) { if !fieldAreaFocused { plaza.releaseAllKeys() } }
            .onAppear { fieldAreaFocused = true }

            if let id = plaza.incomingChallenge, let player = plaza.players[id] {
                incomingBanner(player)
            }
            chatPanel.frame(height: 150)
        }
        .padding(16)
    }

    /// The visible part of the town: world drawn at `PlazaLayout.zoom`, shifted by the camera.
    private func viewport(size: CGSize) -> some View {
        let k = PlazaLayout.zoom
        let cam = PlazaLayout.camera(center: CGPoint(x: plaza.me.shownX, y: plaza.me.shownY),
                                     viewport: CGSize(width: size.width / k, height: size.height / k))
        return world
            .frame(width: PlazaMap.size.width, height: PlazaMap.size.height)
            .scaleEffect(k, anchor: .topLeading)
            .offset(x: -cam.x * k, y: -cam.y * k)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var world: some View {
            ZStack(alignment: .topLeading) {
                PlazaBackdrop()
                    .onTapGesture { selected = nil; fieldAreaFocused = true }   // walking needs key focus
                ForEach(plaza.everyone.sorted { $0.followerY < $1.followerY }) { player in
                    Follower(player: player)
                        .position(x: player.followerX, y: player.followerY - Avatar.feet)
                        .zIndex(player.followerY)
                }
                ForEach(plaza.everyone) { player in
                    Avatar(player: player, isMe: player.id == plaza.me.id, isSelected: selected == player.id)
                        .position(x: player.shownX, y: player.shownY - Avatar.feet)   // x/y are the feet
                        .zIndex(player.shownY + 0.5)      // nearer = drawn on top, followers included
                        .onTapGesture {
                            if player.id != plaza.me.id { selected = selected == player.id ? nil : player.id }
                            fieldAreaFocused = true
                        }
                }
                if let id = selected, let player = plaza.players[id] {
                    challengeCard(player).position(x: min(PlazaMap.size.width - 90, max(90, player.shownX)),
                                                   y: max(55, player.shownY - Avatar.feet - 85))
                        .zIndex(10_000)
                }
            }
    }

    private var header: some View {
        HStack {
            Text("광장").font(.headline)
            Text("\(plaza.everyone.count)/\(PlazaSession.capacity)명").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("방향키로 이동 · 상대를 눌러 대결 신청").font(.caption).foregroundStyle(.secondary)
        }
        .overlay(alignment: .bottomLeading) {
            if ProcessInfo.processInfo.environment["PTB_PLAZA_DEBUG"] == "1" {   // SPIKE: QA readout
                Text("pos " + plaza.everyone.map { "\(Int($0.x)),\(Int($0.y))/\(Int($0.shownX)),\(Int($0.shownY))" }
                    .joined(separator: " | "))
                    .font(.caption2.monospacedDigit()).offset(y: 12)
            }
        }
        .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
    }
}

/// One trainer on the plaza: walking trainer sprite, name tag, chat bubble and busy badge,
/// centered on the player's drawn position. The lead Pokémon is a separate `Follower`.
private struct Avatar: View {
    /// Distance from the view's center down to the trainer's feet; positions and collisions use the feet.
    static let feet: CGFloat = 38
    let player: PlazaPlayer
    let isMe: Bool
    let isSelected: Bool

    var body: some View {
        trainer
            .frame(width: 90, height: 90)
            .overlay(alignment: .bottom) { nameTag.offset(y: 14) }
            .overlay(alignment: .top) { topBadge.offset(y: -26) }
            .contentShape(Rectangle().inset(by: 22))      // just the trainer, so neighbours don't steal clicks
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("트레이너 \(player.profile.trainer) 위치 \(Int(player.shownX)),\(Int(player.shownY))")
    }

    @ViewBuilder
    private var trainer: some View {
        let design = BattleArt.design(for: player.profile)
        if let frame = BattleArt.trainerFrame(design: design, facing: player.facing, step: player.walkFrame) {
            Image(nsImage: frame.image).interpolation(.high).resizable()
                .frame(width: frame.image.size.width * 0.75, height: frame.image.size.height * 0.75)
                .scaleEffect(x: frame.mirrored ? -1 : 1)
                .background(Ellipse().fill(Color.black.opacity(0.22)).frame(width: 30, height: 8).offset(y: 23))
                .offset(y: 14)
        } else {
            SpriteView(speciesID: player.profile.speciesID, size: 52, animated: true, shiny: player.profile.shiny)
        }
    }

    private var nameTag: some View {
        Text(player.profile.trainer)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(isMe ? Color.blue.opacity(0.85) : Color.black.opacity(0.6)))
            .overlay(Capsule().stroke(isSelected ? Color.yellow : .clear, lineWidth: 2))
            .fixedSize()
    }

    @ViewBuilder
    private var topBadge: some View {
        if let bubble = player.bubble {
            Text(bubble)
                .font(.system(size: 11))
                .lineLimit(2)
                .frame(maxWidth: 140)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.25)))
                .foregroundStyle(.black)
                .fixedSize()
        } else if player.busy {
            Text("대결 중").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.orange))
        }
    }
}

/// The lead Pokémon trailing its trainer; positioned by `PlazaMotion`, drawn at feet level.
private struct Follower: View {
    let player: PlazaPlayer

    var body: some View {
        SpriteView(speciesID: player.profile.speciesID, size: 34, animated: true, shiny: player.profile.shiny)
            .scaleEffect(x: player.facing == .left ? 1 : -1)
            .offset(y: 26)
            .allowsHitTesting(false)
    }
}

/// Town map art, or a drawn square when the art is unavailable.
private struct PlazaBackdrop: View {
    var body: some View {
        if let art = BattleArt.town {
            Image(nsImage: art).resizable().interpolation(.high)
        } else {
            PlazaGround()
        }
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

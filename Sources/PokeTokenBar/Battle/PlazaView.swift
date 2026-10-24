import AppKit
import SwiftUI

// SPIKE: the plaza screen. Each trainer walks around with their lead Pokémon following behind;
// click someone to challenge them, chat at the bottom. A match takes over the window until it ends.

struct PlazaRootView: View {
    let plaza: PlazaSession

    var body: some View {
        if let teamMatch = plaza.teamMatch {
            TeamMatchView(match: teamMatch, result: plaza.lastResult) { plaza.leaveTeamMatch() }
                .padding(16)
        } else if let match = plaza.match {
            MatchView(match: match, opponentName: plaza.players[match.opponentID]?.profile.trainer,
                      result: plaza.lastResult, onRematch: { plaza.rematch(match.opponentID) }) {
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
    static let zoom: CGFloat = 1.5

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
    @State private var showStats = false
    @FocusState private var fieldAreaFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            header
            HStack(spacing: 8) {
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
            roster
            }

            if let id = plaza.incomingChallenge, let player = plaza.players[id] {
                incomingBanner(player)
            }
            teamBanner
            chatPanel.frame(height: 150)
        }
        .padding(16)
        .sheet(isPresented: $showStats) { StatsSheet(stats: plaza.stats) { showStats = false } }
        .sheet(isPresented: Binding(get: { plaza.viewedCollection != nil },
                                    set: { if !$0 { plaza.closeCollection() } })) {
            if let viewed = plaza.viewedCollection {
                CollectionSheet(viewed: viewed) { plaza.closeCollection() }
            }
        }
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
            .overlay {
                RightClickCatcher { point in
                    selected = nil
                    fieldAreaFocused = true
                    plaza.walk(to: CGPoint(x: point.x / k + cam.x, y: point.y / k + cam.y))
                }
            }
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
                            if plaza.teamDraft != nil {
                                plaza.draftPick(player.id)   // choosing opponents for a 2:2 team battle
                            } else if player.id != plaza.me.id {
                                selected = selected == player.id ? nil : player.id
                            }
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
            Text("방향키·우클릭으로 이동 · 상대를 눌러 대결·2:2 팀 대결·컬렉션 보기").font(.caption).foregroundStyle(.secondary)
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
            Text("인기도 ♥ \(player.profile.popularity ?? 0)").font(.caption).foregroundStyle(.pink)
            if player.profile.popularity != nil {
                Button(plaza.canVoteToday ? "인기도 올리기 ♥" : "오늘은 이미 올렸어요") { plaza.raisePopularity(of: player.id) }
                    .controlSize(.small)
                    .disabled(!plaza.canVoteToday)
            } else {
                Text("인기도 올리기: 상대 앱을 업데이트해야 해요").font(.caption2).foregroundStyle(.secondary)
            }
            if player.profile.sharesCollection == true {
                Button("컬렉션 보기") { plaza.requestCollection(player.id); selected = nil }
                    .controlSize(.small)
            } else {
                Text("컬렉션 보기: 상대 앱을 업데이트해야 해요").font(.caption2).foregroundStyle(.secondary)
            }
            if player.busy {
                Text("대결 중").font(.caption.bold()).foregroundStyle(.orange)
            } else if plaza.outgoingChallenge == player.id {
                Text("응답을 기다리는 중…").font(.caption)
            } else {
                Button("대결하기") { plaza.challenge(player.id); selected = nil }
                    .buttonStyle(.borderedProminent)
                    .disabled(plaza.outgoingChallenge != nil)
                if plaza.canJoinTeam(player) {
                    Button("2대2 하기") { plaza.beginTeamDraft(partner: player.id); selected = nil }
                        .controlSize(.small)
                        .disabled(plaza.outgoingChallenge != nil || plaza.pendingTeam != nil)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
        .shadow(radius: 4)
    }

    // MARK: Roster — always-visible buttons for everyone in the plaza

    private var roster: some View {
        let others = plaza.everyone.filter { $0.id != plaza.me.id }
            .sorted { ($0.profile.rating ?? Elo.start) > ($1.profile.rating ?? Elo.start) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("광장 사람들").font(.headline)
            HStack {
                Text("\(plaza.stats.tier.label) \(plaza.stats.rating)").font(.callout.bold())
                Spacer(minLength: 0)
                Button("내 전적") { showStats = true }.controlSize(.small)
            }
            Text("내 인기도 ♥ \(plaza.me.profile.popularity ?? 0)").font(.caption).foregroundStyle(.pink)
            Text("내 빌드 \(PlazaSession.myBuild ?? "알 수 없음")").font(.caption2).foregroundStyle(.secondary)
            if others.isEmpty {
                Text("아직 다른 트레이너가 없어요.").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(others) { rosterRow($0) }
                }
            }
        }
        .padding(10)
        .frame(width: 236)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
    }

    private func rosterRow(_ player: PlazaPlayer) -> some View {
        let id = player.id
        let teamBusy = plaza.pendingTeam != nil || plaza.teamMatch != nil
        let canTeam = plaza.canJoinTeam(player) && !teamBusy && plaza.outgoingChallenge == nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(player.profile.trainer).font(.callout.bold()).lineLimit(1)
                Text(player.profile.rating.map { "\(RankTier.tier(for: $0).emoji)\($0)" } ?? "").font(.caption)
                Text("♥ \(player.profile.popularity ?? 0)").font(.caption).foregroundStyle(.pink)
                if let record = plaza.stats.opponents[player.profile.pid ?? "name:\(player.profile.trainer)"] {
                    Text("\(record.wins)승 \(record.losses)패").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if player.busy { Text("대결 중").font(.caption2.bold()).foregroundStyle(.orange) }
            }
            if let draft = plaza.teamDraft {
                Button(id == draft.partner ? "내 파트너" : "상대로 선택 (\(draft.foes.count)/2)") {
                    plaza.draftPick(id)
                    fieldAreaFocused = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(id == draft.partner || !plaza.canJoinTeam(player))
            } else {
                HStack(spacing: 6) {
                    Button("대결하기") { plaza.challenge(id); fieldAreaFocused = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(player.busy || plaza.outgoingChallenge != nil || teamBusy)
                    Button("2대2 하기") { plaza.beginTeamDraft(partner: id); fieldAreaFocused = true }
                        .disabled(!canTeam)
                        .help(player.profile.teamBattle == true ? "이 사람과 한 팀이 돼서 2:2 대결" : "상대 앱을 업데이트해야 해요")
                }
                HStack(spacing: 6) {
                    Button(plaza.canVoteToday ? "인기도 올리기 ♥" : "오늘은 올렸어요") {
                        plaza.raisePopularity(of: id)
                        fieldAreaFocused = true
                    }
                    .tint(.pink)
                    .disabled(!plaza.canVoteToday || player.profile.popularity == nil)
                    .help(player.profile.popularity == nil ? "상대 앱을 업데이트해야 해요" : "하루에 한 번, 한 명에게 올릴 수 있어요")
                    Button("컬렉션") { plaza.requestCollection(id) }
                        .disabled(player.profile.sharesCollection != true)
                }
            }
            if player.profile.teamBattle != true || player.profile.popularity == nil {
                Text("상대 앱이 오래돼 일부 버튼이 꺼져 있어요").font(.caption2).foregroundStyle(.secondary)
            }
            Text(buildNote(player)).font(.caption2)
                .foregroundStyle(player.profile.appBuild == PlazaSession.myBuild ? Color.secondary : Color.orange)
        }
        .controlSize(.small)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.12)))
    }

    private func buildNote(_ player: PlazaPlayer) -> String {
        guard let build = player.profile.appBuild else { return "빌드: 구버전 (업데이트 필요)" }
        return build == PlazaSession.myBuild ? "빌드 \(build) · 같은 버전" : "빌드 \(build) · 내 빌드와 달라요"
    }

    private func trainerName(_ id: String) -> String { plaza.players[id]?.profile.trainer ?? "?" }

    /// The 2:2 team battle flow: choosing opponents, answering an invitation, waiting for everyone.
    @ViewBuilder private var teamBanner: some View {
        if let draft = plaza.teamDraft {
            teamRow {
                Text("\(KoreanParticle.object.attach(to: trainerName(draft.partner))) 파트너로 · 상대 2명을 눌러 고르세요 (\(draft.foes.count)/2)").bold()
                Spacer()
                Button("취소") { plaza.cancelTeamDraft() }
            }
        } else if let pending = plaza.pendingTeam {
            let r = pending.roster
            let sides = "\(r.names[0])·\(r.names[1]) vs \(r.names[2])·\(r.names[3])"
            teamRow {
                if pending.isHost {
                    Text("2:2 팀 대결 응답을 기다리는 중 (\(pending.accepted.count)/3) · \(sides)")
                    Spacer()
                    Button("취소") { plaza.cancelPendingTeam() }
                } else if !pending.answered {
                    Text("\(KoreanParticle.subject.attach(to: r.names[0])) 2:2 팀 대결을 신청했어요! \(sides)").bold()
                    Spacer()
                    Button("수락") { plaza.answerTeamInvite(true) }.buttonStyle(.borderedProminent)
                    Button("거절") { plaza.answerTeamInvite(false) }
                } else {
                    Text("다른 참가자를 기다리는 중… \(sides)")
                    Spacer()
                    Button("취소") { plaza.cancelPendingTeam() }
                }
            }
        }
    }

    private func teamRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(content: content)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.18)))
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
            HStack(spacing: 6) {
                ForEach(["👍", "👏", "😂", "🔥", "GG"], id: \.self) { emote in
                    Button(emote) { plaza.say(emote); fieldAreaFocused = true }.controlSize(.small)
                }
                Spacer(minLength: 0)
            }
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
/// Catches right-clicks (and control-clicks) over the field and reports the point in view coordinates,
/// top-left origin. Every other event falls through to the SwiftUI views underneath.
private struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: (CGPoint) -> Void

    final class CatcherView: NSView {
        var onRightClick: ((CGPoint) -> Void)?
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let rightClick = event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            return rightClick ? self : nil
        }
        override func rightMouseDown(with event: NSEvent) { report(event) }
        override func mouseDown(with event: NSEvent) { report(event) }   // control-click
        private func report(_ event: NSEvent) {
            onRightClick?(convert(event.locationInWindow, from: nil))
        }
    }

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) { view.onRightClick = onRightClick }
}

/// What the match just changed: rating, tier, streak and the record against this opponent.
struct MatchResultCard: View {
    let result: MatchResult

    var body: some View {
        VStack(spacing: 4) {
            Text(result.rated ? "랭크 \(result.delta >= 0 ? "+" : "")\(result.delta)  →  \(result.ratingAfter)"
                              : "랭크 점수는 그대로예요 (오늘 같은 상대와 \(BattleStats.ratedPerOpponentPerDay)판을 넘었어요)")
                .font(.headline)
                .foregroundStyle(result.rated ? (result.delta >= 0 ? Color.green : Color.red) : Color.secondary)
            Text(result.tier.label).font(.callout)
            if result.tierChanged {
                Text(result.delta >= 0 ? "🎉 \(result.tier.name)(으)로 승급했어요!" : "\(result.tier.name)(으)로 내려갔어요")
                    .font(.callout.bold()).foregroundStyle(.orange)
            }
            if let record = result.record {
                Text("\(record.name) 상대 전적 \(record.wins)승 \(record.losses)패").font(.caption)
                    .foregroundStyle(.secondary)
            } else if !result.versus.isEmpty {
                Text("vs \(result.versus.joined(separator: "·")) (2:2)").font(.caption).foregroundStyle(.secondary)
            }
            if result.won && result.streak >= 2 {
                Text("🔥 \(result.streak)연승 중!").font(.callout.bold()).foregroundStyle(.orange)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }
}

/// This trainer's ladder book: tier progress, record, streaks and the rivals met most often.
private struct StatsSheet: View {
    let stats: BattleStats
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("내 전적").font(.headline)
                Spacer()
                Button("닫기", action: onClose).keyboardShortcut(.cancelAction)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.tier.label)  \(stats.rating)").font(.title2.bold())
                if let next = RankTier.pointsToNext(from: stats.rating) {
                    Text("다음 티어까지 \(next)점").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("최고 티어예요!").font(.caption).foregroundStyle(.secondary)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow { Text("1:1"); Text("\(stats.wins)승 \(stats.losses)패") }
                GridRow { Text("2:2 팀"); Text("\(stats.teamWins)승 \(stats.teamLosses)패") }
                GridRow { Text("연승"); Text("현재 \(stats.streak) · 최고 \(stats.bestStreak)") }
                GridRow { Text("최고 점수"); Text("\(stats.peak)") }
            }
            .font(.callout)
            Divider()
            Text("자주 만난 상대").font(.subheadline.bold())
            if stats.rivals.isEmpty {
                Text("아직 대결한 상대가 없어요.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(stats.rivals.prefix(20).enumerated()), id: \.offset) { _, rival in
                            HStack {
                                Text(rival.record.name).lineLimit(1)
                                Spacer()
                                Text("\(rival.record.wins)승 \(rival.record.losses)패").monospacedDigit()
                                    .foregroundStyle(rival.record.wins >= rival.record.losses ? Color.green : Color.red)
                            }
                            .font(.callout)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 380, height: 420)
    }
}

/// Another trainer's shared collection: sprite, name and a shiny mark per owned Pokémon.
private struct CollectionSheet: View {
    let viewed: ViewedCollection
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(viewed.trainer)의 컬렉션").font(.headline)
                if let entries = viewed.entries {
                    Text("\(entries.count)마리 · 이로치 \(entries.filter(\.shiny).count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("닫기", action: onClose).keyboardShortcut(.cancelAction)
            }
            if let entries = viewed.entries {
                if entries.isEmpty {
                    Text("공유된 포켓몬이 없어요.").foregroundStyle(.secondary).frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                                VStack(spacing: 2) {
                                    SpriteView(speciesID: entry.speciesID, size: 56, shiny: entry.shiny)
                                    Text(entry.shiny ? "\(entry.name) ✦" : entry.name)
                                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                            }
                        }
                    }
                }
            } else if viewed.timedOut {
                Text("응답이 없어요. 상대가 광장을 나갔거나 이 기능이 없는 버전일 수 있어요.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxHeight: .infinity)
            } else {
                ProgressView("불러오는 중…").frame(maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(width: 460, height: 420)
    }
}

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

    private var tagText: String {
        var text = player.profile.trainer
        if let rating = player.profile.rating { text = "\(RankTier.tier(for: rating).emoji) " + text }
        if let likes = player.profile.popularity, likes > 0 { text += " ♥\(likes)" }
        return text
    }

    private var nameTag: some View {
        Text(tagText)
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
        SpriteView(speciesID: player.profile.speciesID, size: 48, animated: true, shiny: player.profile.shiny)
            .scaleEffect(x: player.facing == .left ? 1 : -1)
            .offset(y: 19)   // keeps the feet where the 34pt sprite stood
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
    var result: MatchResult?
    var onRematch: (() -> Void)?
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
                if let result { MatchResultCard(result: result) }
                HStack {
                    if match.phase == .finished, let onRematch {
                        Button("재대결 신청", action: onRematch).buttonStyle(.borderedProminent)
                    }
                    Button("광장으로 돌아가기", action: onLeave)
                }
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

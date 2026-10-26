import SwiftUI

// SPIKE: Gen V-style scene for the 2:2 team battle, same look as `BattleSceneView` (field art, animated
// sprites, thrown balls, per-type move effects, hit flashes, HP drain) with two Pokémon per side.
// Near side = my team (me left, partner right), far side = the two foes. It replays
// `TeamBattleState.events` and owns the caption box; foes can be tapped to pick a move's target.

struct TeamBattleSceneView: View {
    let me: Int
    let state: TeamBattleState
    let teams: [[BattleMon]]
    let names: [String]                      // trainer names by index
    /// Foes the player may tap right now (empty unless a move waits for its target).
    let targetable: Set<Int>
    let onTarget: (Int) -> Void
    @Binding var isPlaying: Bool

    @State private var shownHP: [[Int]] = []
    @State private var shownActive = [0, 0, 0, 0]
    @State private var present = [false, false, false, false]
    @State private var lunging = [false, false, false, false]
    @State private var hitBlink = [false, false, false, false]
    @State private var whiteOut = [false, false, false, false]
    @State private var ball: [CGPoint?] = [nil, nil, nil, nil]
    @State private var ballSpin = [0.0, 0.0, 0.0, 0.0]
    @State private var shake: CGFloat = 0
    @State private var effects: [BattleEffect] = []
    @State private var flash: Color = .clear
    @State private var text = ""
    @State private var playedStep = 0

    // Scene layout on the 400×260 field: foes on the far platform, my team on the near one.
    private func isNear(_ t: Int) -> Bool { TeamBattleState.team(of: t) == TeamBattleState.team(of: me) }
    private func feet(_ t: Int) -> CGPoint {
        if isNear(t) { return t == me ? CGPoint(x: 92, y: 246) : CGPoint(x: 208, y: 238) }
        return t == TeamBattleState.foes(of: me)[0] ? CGPoint(x: 246, y: 152) : CGPoint(x: 346, y: 168)
    }
    private func body(_ t: Int) -> CGPoint {
        let f = feet(t)
        return CGPoint(x: f.x, y: f.y - (isNear(t) ? 45 : 28))
    }
    /// Info boxes sit in the two free corners: foes top-left, my team bottom-right.
    private func boxCenter(_ t: Int) -> CGPoint {
        if isNear(t) { return CGPoint(x: 330, y: t == me ? 194 : 238) }
        return CGPoint(x: 72, y: t == TeamBattleState.foes(of: me)[0] ? 26 : 72)
    }
    private var order: [Int] { (0..<4).sorted { feet($0).y < feet($1).y } }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let k = max(1, min(geo.size.width / 400, 3))
                ZStack {
                    BattleBackdrop()
                    ForEach(order, id: \.self) { t in
                        sprite(t)
                            .position(x: feet(t).x, y: feet(t).y - 80)
                    }
                    ForEach(0..<4, id: \.self) { t in
                        if let p = ball[t] {
                            CaptureBall(size: isNear(t) ? 22 : 16).rotationEffect(.degrees(ballSpin[t])).position(p)
                        }
                    }
                    BattleEffectLayer(effects: effects)
                    flash.allowsHitTesting(false)
                    ForEach(0..<4, id: \.self) { t in
                        if teams[t].indices.contains(shownActive[t]) {
                            infoBox(t).position(boxCenter(t))
                        }
                    }
                    ForEach(Array(targetable), id: \.self) { t in
                        RoundedRectangle(cornerRadius: 8).stroke(Color.yellow, lineWidth: 3)
                            .frame(width: 96, height: 104)
                            .contentShape(Rectangle())
                            .position(x: feet(t).x, y: feet(t).y - 44)
                            .onTapGesture { onTarget(t) }
                    }
                }
                .frame(width: 400, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .offset(x: shake)
                .scaleEffect(k, anchor: .topLeading)
                .frame(width: 400 * k, height: 260 * k, alignment: .topLeading)
            }
            .aspectRatio(400.0 / 260.0, contentMode: .fit)
            .frame(maxWidth: 880)

            textBox
        }
        .task(id: state.step) { await play() }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func sprite(_ t: Int) -> some View {
        if teams[t].indices.contains(shownActive[t]) {
            let mon = teams[t][shownActive[t]]
            let near = isNear(t)
            let toward: CGSize = near ? CGSize(width: 22, height: -14) : CGSize(width: -22, height: 14)
            BattleSprite(speciesID: mon.speciesID, shiny: mon.isShiny, back: near,
                         scale: near ? 1.7 : 1.3, maxSide: near ? 120 : 88)
                .id("\(t)-\(shownActive[t])")
                .brightness(whiteOut[t] ? 1 : 0)
                .opacity(present[t] ? (hitBlink[t] ? 0.15 : 1) : 0)
                .scaleEffect(present[t] ? 1 : 0.05, anchor: .bottom)
                .offset(present[t] ? (lunging[t] ? toward : .zero) : CGSize(width: 0, height: 10))
                .allowsHitTesting(false)
        }
    }

    private func infoBox(_ t: Int) -> some View {
        let slot = shownActive[t]
        let mon = teams[t][slot]
        let hp = shownHP.indices.contains(t) && shownHP[t].indices.contains(slot) ? shownHP[t][slot] : mon.maxHP
        let alive = shownHP.indices.contains(t) ? shownHP[t].map { $0 > 0 } : []
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(mon.name + (mon.isShiny ? " ✦" : "")).font(.system(size: 11, weight: .bold)).lineLimit(1)
                Spacer(minLength: 2)
                ForEach(Array(alive.enumerated()), id: \.offset) { _, up in
                    Circle().fill(up ? Color.red : Color.gray.opacity(0.5)).frame(width: 5, height: 5)
                }
            }
            HStack(spacing: 3) {
                Text("HP").font(.system(size: 8, weight: .heavy)).foregroundStyle(.orange)
                HPBar(fraction: Double(hp) / Double(max(1, mon.maxHP)))
            }
            HStack(spacing: 3) {
                Text(t == me ? "\(names[t]) (나)" : names[t]).font(.system(size: 9)).lineLimit(1)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 2)
                if isNear(t) { Text("\(hp)/\(mon.maxHP)").font(.system(size: 9, weight: .semibold).monospacedDigit()) }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7).padding(.vertical, 4)
        .frame(width: 136)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .opacity(state.isOut(t) && !isPlaying ? 0.45 : 1)
    }

    private var textBox: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.16, green: 0.2, blue: 0.3)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.95, green: 0.55, blue: 0.25), lineWidth: 3))
            .frame(width: 400)
    }

    // MARK: - Playback

    private func syncToState() {
        shownHP = state.hp
        shownActive = state.active
        present = (0..<4).map { !state.isOut($0) && state.activeHP($0) > 0 }
        playedStep = state.step
        if let last = state.log.last { text = last }
    }

    private func play() async {
        if shownHP.isEmpty {
            // First appearance: empty field so the intro send-outs animate in.
            shownHP = state.hp
            shownActive = state.active
            present = [false, false, false, false]
        }
        guard state.step != playedStep else { return }
        isPlaying = true
        defer { isPlaying = false }
        for event in state.events {
            guard !Task.isCancelled else { return }
            switch event {
            case .message(let line):
                await type(line)
                await pause(0.55)
            case .switchIn(let t, let slot):
                await sendOut(t, slot: slot)
            case .attack(let from, let to, let type, let physical):
                await attack(from: from, to: to, type: type, physical: physical)
            case .damage(let t, let hp, let critical, let effectiveness):
                if effectiveness > 1 || critical {
                    flash = (critical ? Color.yellow : Color.white).opacity(0.55)
                    withAnimation(.easeOut(duration: 0.3)) { flash = .clear }
                }
                let amplitude: CGFloat = effectiveness > 1 ? 9 : critical ? 6 : 0
                for i in 0..<6 {
                    hitBlink[t] = i % 2 == 0
                    if amplitude > 0 { withAnimation(.linear(duration: 0.04)) { shake = i % 2 == 0 ? amplitude : -amplitude } }
                    await pause(0.07)
                }
                hitBlink[t] = false
                shake = 0
                withAnimation(.linear(duration: 0.6)) { shownHP[t][shownActive[t]] = hp }
                await pause(0.65)
            case .miss:
                await pause(0.1)
            case .faint(let t):
                withAnimation(.easeIn(duration: 0.4)) { present[t] = false }
                await pause(0.45)
            }
        }
        syncToState()
    }

    private func addEffect(_ kind: BattleEffect.Kind, from: CGPoint, to: CGPoint) {
        let effect = BattleEffect(kind: kind, from: from, to: to)
        effects = effects.filter { Date().timeIntervalSince($0.start) < $0.duration } + [effect]
    }

    /// Recall the current Pokémon (if any), throw a ball in an arc, open it, grow the new one out of a white silhouette.
    private func sendOut(_ t: Int, slot: Int) async {
        if present[t] {
            withAnimation(.easeIn(duration: 0.15)) { whiteOut[t] = true }
            await pause(0.15)
            withAnimation(.easeIn(duration: 0.25)) { present[t] = false }
            await pause(0.3)
        }
        shownActive[t] = slot
        whiteOut[t] = true
        let land = CGPoint(x: feet(t).x, y: feet(t).y - 30)
        let startPoint = isNear(t) ? CGPoint(x: -20, y: 250) : CGPoint(x: 430, y: 60)
        let apex = CGPoint(x: (startPoint.x + land.x) / 2, y: min(startPoint.y, land.y) - 70)
        ball[t] = startPoint
        ballSpin[t] = 0
        withAnimation(.easeOut(duration: 0.25)) { ball[t] = apex; ballSpin[t] = 360 }
        await pause(0.25)
        withAnimation(.easeIn(duration: 0.22)) { ball[t] = land; ballSpin[t] = 720 }
        await pause(0.24)
        ball[t] = nil
        addEffect(.ballOpen, from: land, to: land)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { present[t] = true }
        await pause(0.25)
        withAnimation(.easeOut(duration: 0.3)) { whiteOut[t] = false }
        await pause(0.35)
    }

    private func attack(from: Int, to: Int, type: String, physical: Bool) async {
        if physical {
            withAnimation(.easeOut(duration: 0.12)) { lunging[from] = true }
            await pause(0.12)
            addEffect(.move(type: type, physical: true), from: body(from), to: body(to))
            addEffect(.impact(strong: false), from: body(to), to: body(to))
            withAnimation(.easeIn(duration: 0.18)) { lunging[from] = false }
            await pause(0.4)
        } else {
            withAnimation(.easeOut(duration: 0.1)) { lunging[from] = true }
            await pause(0.1)
            withAnimation(.easeIn(duration: 0.12)) { lunging[from] = false }
            addEffect(.move(type: type, physical: false), from: body(from), to: body(to))
            await pause(0.7)
        }
    }

    private func type(_ line: String) async {
        text = ""
        for ch in line {
            guard !Task.isCancelled else { return }
            text.append(ch)
            await pause(0.022)
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

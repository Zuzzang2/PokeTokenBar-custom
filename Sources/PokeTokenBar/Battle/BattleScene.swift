import AppKit
import SwiftUI

// SPIKE: Gen V-style battle scene. Field art is generated (assets/battle, drawn fallback); sprites are
// PokéAPI's animated Black/White GIFs, back view for the player's side. The scene replays
// `BattleState.events` step by step: thrown balls, per-type move effects, hit flashes, HP drain.

struct BattleSceneView: View {
    let session: BattleMatch
    let state: BattleState
    let teams: [[BattleMon]]
    @Binding var isPlaying: Bool

    @State private var shownHP: [[Int]] = []
    @State private var shownActive = [0, 0]
    @State private var present = [false, false]     // sprite sent in and standing
    @State private var lunging = [false, false]
    @State private var hitBlink = [false, false]
    @State private var shake: CGFloat = 0
    @State private var whiteOut = [false, false]    // silhouette while leaving/entering a ball
    @State private var ball: [CGPoint?] = [nil, nil]
    @State private var ballSpin = [0.0, 0.0]
    @State private var effects: [BattleEffect] = []
    @State private var flash: Color = .clear
    @State private var text = ""
    @State private var playedStep = 0

    private var me: Int { session.myIndex }
    private var them: Int { session.theirIndex }

    // Scene layout, matched to the platforms in battle_field.png (scene is 400×260).
    private static let farFeet = CGPoint(x: 298, y: 156)
    private static let nearFeet = CGPoint(x: 139, y: 238)
    private func feet(_ side: Int) -> CGPoint { side == me ? Self.nearFeet : Self.farFeet }
    private func body(_ side: Int) -> CGPoint {
        let f = feet(side)
        return CGPoint(x: f.x, y: f.y - (side == me ? 55 : 32))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                BattleBackdrop()
                // Sprite frames are 160 tall and bottom-aligned, so center = feet - 80.
                sprite(side: them, back: false)
                    .position(x: Self.farFeet.x, y: Self.farFeet.y - 80)
                sprite(side: me, back: true)         // cut by the scene edge like the games
                    .position(x: Self.nearFeet.x, y: Self.nearFeet.y - 80)
                ForEach(0..<2, id: \.self) { side in
                    if let p = ball[side] {
                        CaptureBall(size: side == me ? 24 : 18).rotationEffect(.degrees(ballSpin[side])).position(p)
                    }
                }
                BattleEffectLayer(effects: effects)
                flash.allowsHitTesting(false)
                infoBox(side: them, showNumbers: false)
                    .position(x: 110, y: 40)
                infoBox(side: me, showNumbers: true)
                    .position(x: 300, y: 222)
            }
            .frame(width: 400, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .offset(x: shake)

            textBox
        }
        .task(id: state.step) { await play() }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func sprite(side: Int, back: Bool) -> some View {
        let mon = teams[side][shownActive[side]]
        let towardFoe: CGSize = back ? CGSize(width: 26, height: -16) : CGSize(width: -26, height: 16)
        BattleSprite(speciesID: mon.speciesID, shiny: mon.isShiny, back: back,
                     scale: back ? 2 : 1.6, maxSide: back ? 150 : 110)
            .id("\(side)-\(shownActive[side])")
            .brightness(whiteOut[side] ? 1 : 0)
            .opacity(present[side] ? (hitBlink[side] ? 0.15 : 1) : 0)
            .scaleEffect(present[side] ? 1 : 0.05, anchor: .bottom)
            .offset(present[side] ? (lunging[side] ? towardFoe : .zero) : CGSize(width: 0, height: 10))
    }

    private func infoBox(side: Int, showNumbers: Bool) -> some View {
        let mon = teams[side][shownActive[side]]
        let hp = shownHP.indices.contains(side) ? shownHP[side][shownActive[side]] : mon.maxHP
        let alive = shownHP.indices.contains(side) ? shownHP[side].map { $0 > 0 } : []
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(mon.name + (mon.isShiny ? " ✦" : "")).font(.system(size: 13, weight: .bold))
                Spacer(minLength: 4)
                Text("Lv50").font(.system(size: 11, weight: .semibold))
            }
            HStack(spacing: 4) {
                Text("HP").font(.system(size: 9, weight: .heavy)).foregroundStyle(.orange)
                HPBar(fraction: Double(hp) / Double(max(1, mon.maxHP)))
            }
            HStack(spacing: 3) {
                ForEach(Array(alive.enumerated()), id: \.offset) { _, up in
                    Circle().fill(up ? Color.red : Color.gray.opacity(0.5)).frame(width: 6, height: 6)
                }
                Spacer()
                if showNumbers {
                    Text("\(hp)/\(mon.maxHP)").font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(width: 180)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5), lineWidth: 1))
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
        present = (0..<2).map { state.activeHP($0) > 0 }
        playedStep = state.step
        if let last = state.log.last { text = last }
    }

    private func play() async {
        if shownHP.isEmpty {
            // First appearance: start from an empty field so the intro send-outs animate in.
            shownHP = state.hp
            shownActive = state.active
            present = [false, false]
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
            case .switchIn(let side, let slot):
                await sendOut(side: side, slot: slot)
            case .attack(let side, let type, let physical):
                await attack(side: side, type: type, physical: physical)
            case .damage(let side, let hp, let critical, let effectiveness):
                if effectiveness > 1 || critical {
                    flash = (critical ? Color.yellow : Color.white).opacity(0.55)
                    withAnimation(.easeOut(duration: 0.3)) { flash = .clear }
                }
                let amplitude: CGFloat = effectiveness > 1 ? 9 : critical ? 6 : 0
                for i in 0..<6 {
                    hitBlink[side] = i % 2 == 0
                    if amplitude > 0 { withAnimation(.linear(duration: 0.04)) { shake = i % 2 == 0 ? amplitude : -amplitude } }
                    await pause(0.07)
                }
                hitBlink[side] = false
                shake = 0
                withAnimation(.linear(duration: 0.6)) { shownHP[side][shownActive[side]] = hp }
                await pause(0.65)
            case .miss:
                await pause(0.1)
            case .faint(let side):
                withAnimation(.easeIn(duration: 0.4)) { present[side] = false }
                await pause(0.45)
            }
        }
        syncToState()
    }

    private func addEffect(_ kind: BattleEffect.Kind, from: CGPoint, to: CGPoint) {
        let effect = BattleEffect(kind: kind, from: from, to: to)
        effects = effects.filter { Date().timeIntervalSince($0.start) < $0.duration } + [effect]
    }

    /// Recall the current Pokémon (if any), throw a ball in an arc, open it, and grow the new
    /// Pokémon out of a white silhouette.
    private func sendOut(side: Int, slot: Int) async {
        if present[side] {
            withAnimation(.easeIn(duration: 0.15)) { whiteOut[side] = true }
            await pause(0.15)
            withAnimation(.easeIn(duration: 0.25)) { present[side] = false }
            await pause(0.3)
        }
        shownActive[side] = slot
        whiteOut[side] = true
        let land = CGPoint(x: feet(side).x, y: feet(side).y - 30)
        let startPoint = side == me ? CGPoint(x: -20, y: 250) : CGPoint(x: 430, y: 60)
        let apex = CGPoint(x: (startPoint.x + land.x) / 2, y: min(startPoint.y, land.y) - 70)
        ball[side] = startPoint
        ballSpin[side] = 0
        withAnimation(.easeOut(duration: 0.25)) { ball[side] = apex; ballSpin[side] = 360 }
        await pause(0.25)
        withAnimation(.easeIn(duration: 0.22)) { ball[side] = land; ballSpin[side] = 720 }
        await pause(0.24)
        ball[side] = nil
        addEffect(.ballOpen, from: land, to: land)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { present[side] = true }
        await pause(0.25)
        withAnimation(.easeOut(duration: 0.3)) { whiteOut[side] = false }
        await pause(0.35)
    }

    private func attack(side: Int, type: String, physical: Bool) async {
        let foe = 1 - side
        if physical {
            withAnimation(.easeOut(duration: 0.12)) { lunging[side] = true }
            await pause(0.12)
            addEffect(.move(type: type, physical: true), from: body(side), to: body(foe))
            addEffect(.impact(strong: false), from: body(foe), to: body(foe))
            withAnimation(.easeIn(duration: 0.18)) { lunging[side] = false }
            await pause(0.4)
        } else {
            withAnimation(.easeOut(duration: 0.1)) { lunging[side] = true }
            await pause(0.1)
            withAnimation(.easeIn(duration: 0.12)) { lunging[side] = false }
            addEffect(.move(type: type, physical: false), from: body(side), to: body(foe))
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

/// HP bar that animates its width; green → yellow → red like the games.
private struct HPBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.5))
                Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 6)
    }

    private var color: Color {
        fraction > 0.5 ? Color(red: 0.3, green: 0.85, blue: 0.4)
            : fraction > 0.2 ? Color(red: 0.98, green: 0.8, blue: 0.2) : Color(red: 0.95, green: 0.3, blue: 0.25)
    }
}

/// Generated field art, or the drawn field when the art is unavailable.
private struct BattleBackdrop: View {
    var body: some View {
        if let art = BattleArt.battleField {
            Image(nsImage: art).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                .frame(width: 400, height: 260).clipped()
        } else {
            BattleBackground()
        }
    }
}

/// Drawn field: sky, distant hills, grass and two elliptical platforms.
private struct BattleBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.55, green: 0.80, blue: 0.95),
                                                             Color(red: 0.86, green: 0.95, blue: 0.93)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.5)))
            // Distant hills
            for (x, r, shade) in [(0.15, 0.32, 0.62), (0.55, 0.38, 0.58), (0.92, 0.30, 0.64)] {
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - w * r, y: h * 0.34, width: w * r * 2, height: h * 0.32)),
                         with: .color(Color(red: 0.42, green: shade, blue: 0.48)))
            }
            // Grass field
            ctx.fill(Path(CGRect(x: 0, y: h * 0.48, width: w, height: h * 0.52)),
                     with: .linearGradient(Gradient(colors: [Color(red: 0.62, green: 0.84, blue: 0.45),
                                                             Color(red: 0.42, green: 0.70, blue: 0.32)]),
                                           startPoint: CGPoint(x: 0, y: h * 0.48), endPoint: CGPoint(x: 0, y: h)))
            // Grass stripes for depth
            for i in 0..<5 {
                let y = h * (0.56 + Double(i) * 0.09)
                ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: 2)), with: .color(.white.opacity(0.10)))
            }
            platform(ctx, center: CGPoint(x: 300, y: 128), size: CGSize(width: 170, height: 40))
            platform(ctx, center: CGPoint(x: 118, y: 226), size: CGSize(width: 230, height: 52))
        }
    }

    private func platform(_ ctx: GraphicsContext, center: CGPoint, size: CGSize) {
        let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                          width: size.width, height: size.height)
        ctx.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 4)), with: .color(Color(red: 0.25, green: 0.45, blue: 0.2).opacity(0.6)))
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [Color(red: 0.86, green: 0.93, blue: 0.62), Color(red: 0.6, green: 0.78, blue: 0.4)]),
            center: center, startRadius: 0, endRadius: size.width / 2))
        ctx.stroke(Path(ellipseIn: rect), with: .color(Color(red: 0.4, green: 0.6, blue: 0.3)), lineWidth: 2)
    }
}

/// Plays a Black/White animated GIF at native pixel size × `scale`, feet anchored at the bottom.
private struct BattleSprite: View {
    let speciesID: Int
    let shiny: Bool
    let back: Bool
    let scale: CGFloat
    /// Large GIF canvases (legendaries) would overflow the scene at `scale`; cap the longer side.
    let maxSide: CGFloat
    @State private var frames: [(image: NSImage, delay: TimeInterval)] = []
    @State private var index = 0
    @State private var mirrored = false

    var body: some View {
        Group {
            if frames.isEmpty {
                Color.clear.frame(width: 80, height: 80)
            } else {
                let image = frames[index % frames.count].image
                let k = min(scale, maxSide / max(1, max(image.size.width, image.size.height)))
                Image(nsImage: image).interpolation(.none).resizable()
                    .frame(width: image.size.width * k, height: image.size.height * k)
                    .scaleEffect(x: mirrored ? -1 : 1)
            }
        }
        .frame(width: 180, height: 160, alignment: .bottom)
        .task(id: "\(speciesID)-\(shiny)-\(back)") {
            index = 0
            let loaded = back ? await BattleSpriteSource.backFrames(speciesID: speciesID, shiny: shiny) : []
            if !loaded.isEmpty {
                frames = loaded; mirrored = false
            } else {
                frames = await SpriteLoader.animationFrames(speciesID: speciesID, shiny: shiny)
                mirrored = back   // no back art: mirror the front so it faces the foe
            }
            if frames.isEmpty, let data = await SpriteStore.shared.data(speciesID: speciesID, animated: false, shiny: shiny),
               let image = NSImage(data: data) {
                frames = [(image, 1)]
            }
            while !Task.isCancelled, frames.count > 1 {
                try? await Task.sleep(for: .seconds(max(0.03, frames[index % frames.count].delay)))
                index += 1
            }
        }
    }
}

@MainActor
enum BattleSpriteSource {
    private static let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/back"

    /// Animated back sprite, cached next to the app's other sprites.
    static func backFrames(speciesID: Int, shiny: Bool) async -> [(image: NSImage, delay: TimeInterval)] {
        let file = SpriteStore.shared.directory.appendingPathComponent("back-\(speciesID)-\(shiny ? "sh" : "")a.gif")
        if let data = try? Data(contentsOf: file) { return GIFDecoder.frames(from: data) }
        guard let url = URL(string: "\(base)/\(shiny ? "shiny/" : "")\(speciesID).gif"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        try? data.write(to: file, options: .atomic)
        return GIFDecoder.frames(from: data)
    }
}

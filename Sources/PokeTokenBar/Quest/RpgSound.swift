import AVFoundation
import Foundation

// SPIKE: 효과음. Every sound is synthesised at start-up (tones, noise bursts, little arpeggios), so the game needs no audio files.
// `RpgView` feeds it what happened this frame (new damage numbers, level-ups, pickups); it plays through a small pool of players.

@MainActor
final class RpgSound {
    enum Cue { case hit, crit, hurt, heal, gold, levelUp, cast, potion, pickup, boss }

    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var next = 0
    private var lastPlayed: [Cue: Double] = [:]
    var enabled = UserDefaults.standard.object(forKey: "rpgSound") as? Bool ?? true
    private static let rate = 44_100.0

    init() {
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.rate, channels: 1)!
        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        engine.mainMixerNode.outputVolume = 0.5
        do { try engine.start() } catch { return }
        self.engine = engine
        buffers = [
            .hit: Self.make(format, [.noise(0.05, vol: 0.5), .tone(160, 0.06, wave: .square, vol: 0.25, slide: -60)]),
            .crit: Self.make(format, [.tone(520, 0.05, wave: .square, vol: 0.35, slide: 200), .noise(0.07, vol: 0.5), .tone(900, 0.09, wave: .sine, vol: 0.3, slide: -300)]),
            .hurt: Self.make(format, [.tone(140, 0.14, wave: .saw, vol: 0.45, slide: -90), .noise(0.06, vol: 0.3)]),
            .heal: Self.make(format, [.tone(660, 0.08, wave: .sine, vol: 0.3), .tone(880, 0.12, wave: .sine, vol: 0.3)]),
            .gold: Self.make(format, [.tone(1318, 0.05, wave: .square, vol: 0.2), .tone(1760, 0.12, wave: .square, vol: 0.2)]),
            .levelUp: Self.make(format, [.tone(523, 0.1, wave: .square, vol: 0.28), .tone(659, 0.1, wave: .square, vol: 0.28), .tone(784, 0.1, wave: .square, vol: 0.28), .tone(1047, 0.3, wave: .square, vol: 0.3)]),
            .cast: Self.make(format, [.noise(0.1, vol: 0.2), .tone(300, 0.12, wave: .sine, vol: 0.3, slide: 500)]),
            .potion: Self.make(format, [.tone(500, 0.05, wave: .sine, vol: 0.3, slide: 300), .tone(700, 0.08, wave: .sine, vol: 0.3, slide: 300)]),
            .pickup: Self.make(format, [.tone(880, 0.04, wave: .square, vol: 0.18), .tone(1175, 0.07, wave: .square, vol: 0.18)]),
            .boss: Self.make(format, [.tone(90, 0.25, wave: .saw, vol: 0.5, slide: -30), .tone(70, 0.35, wave: .saw, vol: 0.5, slide: -20)]),
        ]
    }

    func play(_ cue: Cue, now: Double) {
        guard enabled, let engine, engine.isRunning, let buffer = buffers[cue] else { return }
        // The same cue at most 14 times a second so a pack of hits is a rattle, not a wall of noise.
        if let last = lastPlayed[cue], now - last < 0.07 { return }
        lastPlayed[cue] = now
        let node = players[next % players.count]
        next += 1
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    func toggle() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "rpgSound")
    }

    // MARK: synthesis

    private enum Part {
        enum Wave { case sine, square, saw }
        case tone(Double, Double, wave: Wave, vol: Float, slide: Double = 0)
        case noise(Double, vol: Float)
    }

    private static func make(_ format: AVAudioFormat, _ parts: [Part]) -> AVAudioPCMBuffer {
        var samples: [Float] = []
        for part in parts {
            switch part {
            case .tone(let freq, let dur, let wave, let vol, let slide):
                let n = Int(dur * rate)
                var phase = 0.0
                for i in 0..<n {
                    let t = Double(i) / Double(n)
                    let f = freq + slide * t
                    phase += f / rate
                    let frac = phase - floor(phase)
                    let raw: Double
                    switch wave {
                    case .sine: raw = sin(2 * .pi * phase)
                    case .square: raw = frac < 0.5 ? 1 : -1
                    case .saw: raw = 2 * frac - 1
                    }
                    let env = min(1, t * 20) * pow(1 - t, 1.5)
                    samples.append(Float(raw * env) * vol)
                }
            case .noise(let dur, let vol):
                let n = Int(dur * rate)
                for i in 0..<n {
                    let t = Double(i) / Double(n)
                    samples.append(Float.random(in: -1...1) * Float(pow(1 - t, 2)) * vol)
                }
            }
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, samples.count)))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, s) in samples.enumerated() { buffer.floatChannelData![0][i] = s }
        return buffer
    }
}

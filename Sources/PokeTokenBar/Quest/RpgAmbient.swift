import AppKit
import CoreGraphics

// SPIKE: 분위기. A day-night tint from the real clock on outdoor maps, plus drifting particles that fit the place
// (leaves and fireflies in the forest, snowfall, desert dust, volcano embers, cave motes, rain in the swamp).
// Drawn in the low-resolution frame, after the world and before the darkness of caves.

extension RpgView {
    /// 0 = full day, 1 = deep night, from the local clock.
    static func nightAmount(hour: Double) -> Double {
        switch hour {
        case 7..<18: return 0
        case 18..<21: return (hour - 18) / 3 * 0.8
        case 21..<24: return 0.8 + (hour - 21) / 3 * 0.2
        case 0..<4: return 1
        case 4..<7: return 1 - (hour - 4) / 3
        default: return 0
        }
    }

    func drawAmbient(_ f: CGContext, map: RpgMap, vw: Int, vh: Int) {
        let t = world.time
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
        let outdoor: Bool
        switch map.def.kind {
        case .field, .forest, .desert, .snow, .volcano, .town, .pond: outdoor = true
        default: outdoor = false
        }
        let night = outdoor && map.def.kind != .volcano ? Self.nightAmount(hour: hour) : 0
        if night > 0 {
            f.setFillColor(CGColor(red: 0.03, green: 0.06, blue: 0.2, alpha: CGFloat(night * 0.42)))
            f.fill(CGRect(x: 0, y: 0, width: vw, height: vh))
        } else if outdoor, hour >= 17, hour < 18 {
            f.setFillColor(CGColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.08))
            f.fill(CGRect(x: 0, y: 0, width: vw, height: vh))
        }

        // Particles: deterministic from the index and time, so no state to keep.
        func h(_ i: Int, _ salt: Double) -> Double { let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453; return v - floor(v) }
        func wrap(_ v: Double, _ m: Double) -> CGFloat { CGFloat(v - floor(v / m) * m) }
        let W = Double(vw), H = Double(vh)
        func dot(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ hgt: CGFloat, _ c: CGColor) { f.setFillColor(c); f.fill(CGRect(x: x, y: y, width: w, height: hgt)) }
        let kind = map.def.kind
        if map.def.id == .swamp {
            for i in 0..<70 {
                let x = wrap(h(i, 1) * W + t * 20, W), y = wrap(h(i, 2) * H + t * 130, H)
                dot(x, y, 1, 4, CGColor(red: 0.6, green: 0.75, blue: 1, alpha: 0.45))
            }
        } else if kind == .snow {
            for i in 0..<70 {
                let x = wrap(h(i, 1) * W + sin(t * 0.8 + Double(i)) * 8, W), y = wrap(h(i, 2) * H + t * (14 + h(i, 3) * 14), H)
                dot(x, y, 1.5, 1.5, CGColor(red: 1, green: 1, blue: 1, alpha: 0.8))
            }
        } else if kind == .desert {
            for i in 0..<30 {
                let x = wrap(h(i, 1) * W + t * (60 + h(i, 3) * 40), W), y = wrap(h(i, 2) * H + sin(t + Double(i)) * 4, H)
                dot(x, y, 6, 1, CGColor(red: 0.9, green: 0.78, blue: 0.5, alpha: 0.35))
            }
        } else if kind == .volcano {
            for i in 0..<40 {
                let x = wrap(h(i, 1) * W + sin(t + Double(i)) * 6, W), y = wrap(h(i, 2) * H - t * (16 + h(i, 3) * 20), H)
                let a = CGFloat(0.4 + 0.5 * h(i, 4))
                dot(x, y, 1.5, 1.5, CGColor(red: 1, green: CGFloat(0.4 + 0.4 * h(i, 5)), blue: 0.1, alpha: a))
            }
        } else if kind == .forest || kind == .field {
            if night > 0.5 {
                for i in 0..<26 {
                    let x = wrap(h(i, 1) * W + sin(t * 0.5 + Double(i) * 2) * 14, W), y = wrap(h(i, 2) * H + cos(t * 0.4 + Double(i)) * 10, H)
                    let blink = CGFloat(max(0, sin(t * 2 + Double(i) * 1.7)))
                    dot(x, y, 2, 2, CGColor(red: 0.85, green: 1, blue: 0.4, alpha: 0.2 + 0.7 * blink))
                }
            } else {
                for i in 0..<(kind == .forest ? 28 : 18) {
                    let x = wrap(h(i, 1) * W + t * 10 + sin(t + Double(i)) * 6, W), y = wrap(h(i, 2) * H + t * (10 + h(i, 3) * 8), H)
                    let c = kind == .forest ? CGColor(red: 0.45, green: 0.7, blue: 0.3, alpha: 0.7) : CGColor(red: 1, green: 0.9, blue: 0.95, alpha: 0.7)
                    dot(x, y, 2, 1, c)
                }
            }
        } else if kind == .cave || kind == .castle || kind == .boss {
            for i in 0..<22 {
                let x = wrap(h(i, 1) * W + sin(t * 0.3 + Double(i)) * 10, W), y = wrap(h(i, 2) * H - t * 3, H)
                dot(x, y, 1, 1, CGColor(red: 0.7, green: 0.65, blue: 0.9, alpha: 0.25))
            }
        }
    }
}

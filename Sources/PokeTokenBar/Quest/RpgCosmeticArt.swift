import AppKit
import CoreGraphics

// SPIKE: 외관 아이템 on the hero (`RpgCosmetics` is the catalog, `RpgCharacterArt` the paper doll they dress). Themed pieces are
// letter grids in role letters that take their set's colours; each worn layer (hat, outfit, cape, wings) maps them to its own
// private letters, so pieces of different sets share one frame:
//   # main · = main shade · + main light · ~ trim · - trim shade · * trim light · ^ glow · : glow light · & deep main
// Every other letter keeps its hero-palette meaning (K outline, X white, H/h/I hair, S/s skin, o eye, x blush, Q accent…).
// Hats, hairstyles, faces, outfits, capes and wings are baked into the cached body frames (the frame key carries `HeroWear`),
// weapon skins into the cached weapon turns; auras and steps are drawn each frame from small cached images.

// MARK: - what is worn

extension RpgArt {
    /// The wardrobe pieces a hero wears as small codes (set index + 1, or hair / face style + 1; 0 = nothing): cheap to build
    /// and hash every frame for the frame cache key.
    struct HeroWear: Hashable, Sendable {
        var hat: UInt8 = 0, outfit: UInt8 = 0, cape: UInt8 = 0, weapon: UInt8 = 0, aura: UInt8 = 0
        var wings: UInt8 = 0, steps: UInt8 = 0, hair: UInt8 = 0, face: UInt8 = 0
    }

    private static let wearCodes: [String: (slot: RpgCosmeticSlot, code: UInt8)] = {
        var codes: [String: (slot: RpgCosmeticSlot, code: UInt8)] = [:]
        for c in RpgCosmetics.all {
            let index = c.slot == .hair || c.slot == .face ? c.style : RpgCosmetics.themes.firstIndex { $0.key == c.theme } ?? -1
            if (0..<255).contains(index) { codes[c.id] = (c.slot, UInt8(index + 1)) }
        }
        return codes
    }()

    static func heroWear(_ worn: [String: String]) -> HeroWear {
        var w = HeroWear()
        for id in worn.values {
            guard let e = wearCodes[id] else { continue }
            switch e.slot {
            case .hat: w.hat = e.code
            case .outfit: w.outfit = e.code
            case .cape: w.cape = e.code
            case .weaponSkin: w.weapon = e.code
            case .aura: w.aura = e.code
            case .wings: w.wings = e.code
            case .steps: w.steps = e.code
            case .hair: w.hair = e.code
            case .face: w.face = e.code
            }
        }
        return w
    }
}

// MARK: - colours and letters

extension RpgArt {
    /// Role letters of cosmetic grids, in the order of `cosColors`.
    private static let cosRoles: [Character] = ["#", "=", "+", "~", "-", "*", "^", ":", "&"]
    private static let cosRoleIndex: [Character: Int] = Dictionary(uniqueKeysWithValues: cosRoles.enumerated().map { ($1, $0) })

    /// Each set's colours by role.
    private static let cosColors: [[CGColor]] = RpgCosmetics.themes.map { t in
        let main = col(t.main), trim = col(t.trim), glow = col(t.glow)
        return [main, scaled(main, 0.7), scaled(main, 1.3), trim, scaled(trim, 0.72), scaled(trim, 1.35), glow, scaled(glow, 1.5), scaled(main, 0.45)]
    }

    /// Private letters of each worn layer (0 hat, 1 outfit, 2 cape, 3 wings), by role.
    private static let cosLetters: [[Character]] = (0..<4).map { layer in
        (0..<cosRoles.count).map { Character(Unicode.Scalar(UInt32(0xE000 + layer * 16 + $0)) ?? "?") }
    }

    /// A part in role letters turned into a layer's private letters.
    private static func cosTranslate(_ p: HeroPart, _ layer: Int) -> HeroPart {
        let letters = cosLetters[layer]
        return HeroPart(x: p.x, y: p.y, g: p.g.map { row in String(row.map { ch in cosRoleIndex[ch].map { letters[$0] } ?? ch }) })
    }

    private static func luminance(_ c: CGColor) -> CGFloat {
        guard let k = c.components, k.count >= 3 else { return 0 }
        return 0.2126 * k[0] + 0.7152 * k[1] + 0.0722 * k[2]
    }

    /// The worn sets' colours under their layers' letters, plus an outfit's sleeves, trousers and boots.
    static func cosPalette(_ c: inout [Character: CGColor], _ w: HeroWear) {
        for (layer, code) in [(0, w.hat), (1, w.outfit), (2, w.cape), (3, w.wings)] where code > 0 && Int(code) <= cosColors.count {
            for (r, color) in cosColors[Int(code) - 1].enumerated() { c[cosLetters[layer][r]] = color }
        }
        guard w.outfit > 0, Int(w.outfit) <= cosColors.count else { return }
        let o = cosColors[Int(w.outfit) - 1]
        c["1"] = o[0]; c["2"] = o[1]
        c["5"] = scaled(o[0], 0.62); c["6"] = scaled(o[0], 0.45)
        // Pale sets get boots in their trim; the rest in a dark of their main colour.
        let boots = luminance(o[0]) > 0.72 ? o[3] : scaled(o[0], 0.5)
        c["B"] = boots; c["b"] = scaled(boots, 0.7)
    }

    /// A part mirrored left to right about the frame's centre line.
    private static func cosMirrored(_ p: HeroPart) -> HeroPart {
        let w = p.g.map(\.count).max() ?? 0
        return HeroPart(x: heroSize - p.x - w, y: p.y, g: p.g.map { String($0.padding(toLength: w, withPad: ".", startingAt: 0).reversed()) })
    }
}

// MARK: - hats

extension RpgArt {
    /// One hat per set, per view (side, front, back), and the frame row above which hair under it is hidden (0: it sits on the hair).
    private struct HatArt {
        let views: [HeroPart]
        let cover: [Int]
    }

    private static func hat(_ side: HeroPart, _ front: HeroPart, _ back: HeroPart? = nil, cover: [Int]) -> HatArt {
        HatArt(views: [side, front, back ?? front], cover: cover)
    }

    // All hat grids are 20 wide at x 6: the head (x 10-21) is columns 4-15, its eyes at rows 12-14.
    private static let hatArt: [HatArt] = [
        // classic: straw hat with a band.
        hat(part(4, ["......KKKKKKKK......", ".....K~-~~~-~~K.....", ".....K~~~-~~~-K.....", ".....K########K.....", "KKKKKK========KKKKKK",
                     "K-~~-~~~-~~~-~~~-~-K", ".KKKKKKKKKKKKKKKKKK."], x: 6),
            part(4, ["......KKKKKKKK......", ".....K~~-~~~-~K.....", ".....K~-~~~-~~K.....", ".....K########K.....", "..KKKK========KKKK..",
                     ".K~~~~~~~~~~~~~~~~K.", "K-~~-~~~-~~~-~~~-~-K", ".KKKKKKKKKKKKKKKKKK."], x: 6),
            cover: [10, 11, 11]),
        // festival: striped party hat, worn at a tilt, with a pompom and a frilled band.
        hat(part(0, ["...........KK.......", "..........K::K......", "..........K:^K......", ".........K#KK.......", "........K#~#K.......",
                     ".......K~#~#K.......", "......K#~#~#~K......", ".....K*^*^*^*^K.....", "......KKKKKKKK......"], x: 6),
            part(0, ["...........KK.......", "..........K::K......", "..........K:^K......", ".........K#KK.......", "........K#~#K.......",
                     ".......K~#~#K.......", "......K#~#~#~K......", ".....K*^*^*^*^K.....", "......KKKKKKKK......"], x: 6),
            cover: [0, 0, 0]),
        // coast: pirate tricorn with a skull.
        hat(part(2, [".....KKKKKKKKK......", "....K++#######K.....", "KK..K#########K.....", "K~K.K##########K....", "K#~KK##########K....",
                     ".K#~~K#########KK...", "..K#~~~~~~~~~~~~~KK.", "...KK=~~~~~~~~~~~~#K", ".....KK=========KKK.", ".......KKKKKKKKK...."], x: 6),
            part(2, [".....KKKKKKKKKK.....", "....K++########K....", "KK..K####XX####K..KK", "K~K.K###XooX###K.K~K", "K#~KK####XX####KK~#K",
                     ".K#~~K##X##X##K~~#K.", ".K##~~~~~~~~~~~~##K.", "..KK##=~~~~~~=##KK..", "....KKK======KKK....", "......KKK~~KKK......"], x: 6),
            part(2, [".....KKKKKKKKKK.....", "....K##########K....", "KK..K##########K..KK", "K~K.K##########K.K~K", "K#~KK##########KK~#K",
                     ".K#~~K########K~~#K.", ".K##~~~~~~~~~~~~##K.", "..KK##=~~~~~~=##KK..", "....KKK======KKK....", "......KKKKKKKK......"], x: 6),
            cover: [9, 9, 9]),
        // jungle: explorer's pith helmet, a tall dome with a vent on top.
        hat(part(1, ["..........KK........", ".........K##K.......", ".....KKKK~**KKK.....", "....K~~~~~**~~~K....", "...K~~~~~~~*~~~~K...",
                     "...K~~~~~~~~~~~~K...", "...K-~~~~~~~~~~-K...", "..KK############KK..", ".K-~~~~~~~~~~~~~~-K.", "K--KKKKKKKKKKKKKK--K",
                     ".KK..............KK."], x: 6),
            part(1, [".........KK.........", "........K##K........", "......KK~**~KK......", ".....K~**~~~~~K.....", "....K~**~~~~~~-K....",
                     "....K~*~~~~~~~-K....", "....K~~~~~~~~--K....", "...KK##########KK...", "..K-~~~~~~~~~~~~-K..", "..KK------------KK..",
                     "....KKKKKKKKKKKK...."], x: 6),
            cover: [10, 11, 11]),
        // mushroom: spotted mushroom cap with gills.
        hat(part(1, [".......KKKKKK.......", ".....KK##~~##KK.....", "....K###~~~####K....", "...K#~~#####~~##K...", "..K##~~#####~~###K..",
                     "..K######~~######K..", ".K##~~###~~###~~##K.", ".K=#~~########~~#=K.", ".KK==============KK.", "..K-~-~-~-~-~-~-~K..",
                     "...KKKKKKKKKKKKKK..."], x: 6),
            part(1, [".......KKKKKK.......", ".....KK##~~##KK.....", "....K###~~~####K....", "...K#~~#####~~##K...", "..K##~~#####~~###K..",
                     "..K######~~######K..", ".K##~~###~~###~~##K.", ".K=#~~########~~#=K.", ".KK==============KK.", "..K-~-~-~-~-~-~-~K..",
                     "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [11, 11, 11]),
        // ancient: scholar's square cap with a tassel.
        hat(part(3, ["....................", "..KKKKKKKKKKKKKKKK..", ".K-~~~~~~~~~~~~~~-K.", "..KK^KKKKKKKKKKKKK..", "...K^K#########K....",
                     "...K:K##########K...", "....KK##########K...", "....K=#########=K...", "....KKKKKKKKKKKKK..."], x: 6),
            part(3, ["........KKKK........", ".....KKK~~~~KKK.....", "..KKK~~~~*~~~~~KKK..", ".K-~~~~~~~~~~~~~~-K.", "..KKK--~~~~~~--KKK^K",
                     ".....K########K..K^K", "....K##########K.K:K", "....K=########=K..K.", "....KKKKKKKKKKKK...."], x: 6),
            cosMirrored(part(3, ["........KKKK........", ".....KKK~~~~KKK.....", "..KKK~~~~*~~~~~KKK..", ".K-~~~~~~~~~~~~~~-K.", "..KKK--~~~~~~--KKK^K",
                              ".....K########K..K^K", "....K##########K.K:K", "....K=########=K..K.", "....KKKKKKKKKKKK...."], x: 6)),
            cover: [11, 11, 11]),
        // crystal: miner's helmet with a bright lamp.
        hat(part(3, ["......KKKKKK........", "....KK#+++##KK......", "...K#++#######KKK...", "...K++#######K:XK...", "...K+########K^^K...",
                     "...K#########~KKK...", "..KK~~~~~~~~~~~~KK..", ".K-~~~~~~~~~~~~~~~K.", "..KKKKKKKKKKKKKKKK.."], x: 6),
            part(3, [".......KKKKKK.......", ".....KK#+++##KK.....", "....K#++KKKK##=K....", "....K++#K:XK##=K....", "....K+##K^^K##=K....",
                     "....K###~KK~##=K....", "...KK~~~~~~~~~~KK...", "..K-~~~~~~~~~~~~-K..", "...KKKKKKKKKKKKKK..."], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K=#######++K....", "....K=########+K....", "....K##########K....",
                     "....K=#########K....", "...KK~~~~~~~~~~KK...", "..K-~~~~~~~~~~~~-K..", "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [11, 11, 11]),
        // factory: work cap with goggles.
        hat(part(4, ["......KKKKKK........", "....KK~~~~~~KK......", "...K~**~~~~~~-K.....", "...K~*~~~~~~~~-KKKK.", "...KKKKKKKKKKKK~~~-K",
                     "...K#########K:^^KK.", "...KKKKKKKKKKK^^^K..", "..............KKK..."], x: 6),
            part(4, [".......KKKKKK.......", ".....KK~~~~~~KK.....", "....K~**~~~~~~-K....", "....K~*~~~~~~~-K....", "...KKKKKKKKKKKKKK...",
                     "..K#K:^^K##K:^^K#K..", "..K#K^^^KKKK^^^K#K..", "...KKKKKK..KKKKKK..."], x: 6),
            part(4, [".......KKKKKK.......", ".....KK~~~~~~KK.....", "....K-~~~~~~**~K....", "....K-~~~~~~~*~K....", "...KKKKKKKKKKKKKK...",
                     "...K############K...", "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [9, 9, 9]),
        // skyisle: knight's helm with little wings.
        hat(part(2, ["......KKKKKK........", "....KK++#~###KK.....", "KK.K++###~####=K....", "K#KK+####~#####K....", "K##K#####~#####K....",
                     ".K#~K##########K....", ".K##K~~~~~~~~~~KK...", "..KKK~-~-~-~-~^~~K..", ".....KKKKKKKKKKKK..."], x: 6),
            part(2, [".......KKKKKK.......", "KK...KK++#~#=KK...KK", "K#K.K++###~###=K.K#K", "K##KK+####~####KK##K", ".K#~K#####~####K~#K.",
                     ".K##K##########K##K.", "..K#KK~~~~~~~~KK#K..", "...KK~-~-^^-~-~KK...", ".....KKKKKKKKKK....."], x: 6),
            part(2, [".......KKKKKK.......", "KK...KK=#~#++KK...KK", "K#K.K=###~###++K.K#K", "K##KK####~####+KK##K", ".K#~K####~#####K~#K.",
                     ".K##K##########K##K.", "..K#KK~~~~~~~~KK#K..", "...KK~-~-~~-~-~KK...", ".....KKKKKKKKKK....."], x: 6),
            cover: [10, 10, 10]),
        // undersea: sea god's crown of coral points and pearls.
        hat(part(1, [".........KK.........", "....K...K:^K...K....", "...K:K..K^^K..K:K...", "...K#K.K####K.K#K...", "...K##K######K##K...",
                     "...K############K...", "...K~#~#~##~#~#~K...", "....KKKKKKKKKKKK...."], x: 6),
            part(1, [".........KK.........", "....K...K:^K...K....", "...K:K..K^^K..K:K...", "...K#K.K####K.K#K...", "...K##K######K##K...",
                     "...K############K...", "...K~#~#~##~#~#~K...", "....KKKKKKKKKKKK...."], x: 6),
            cover: [0, 0, 0]),
        // haunted: ghost's hood with a ragged hem.
        hat(part(3, ["......KKKKKK........", "....KK######KK......", "...K#+#######KK.....", "..K#+#########=K....", "..K#+##########=K...",
                     "..K############=K...", "..K#########KKK~K...", "..K#######KK~~~K....", "..K######K~~KK......", "..K#####~K..........",
                     "..K#####~K..........", "..K#####~K..........", "..K####=~K..........", "..K=###=K...........", ".K=#=#=#K...........",
                     ".K#K=K=#K...........", "..K.K.KK............"], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K##+#######K....", "...K#+##########K...", "...K#+##########K...",
                     "..K##############K..", "..K###KKKKKKKK###K..", "..K##K~~~~~~~~K##K..", "..K##K~......~K##K..", "..K##K........K##K..",
                     "..K##K........K##K..", "..K##K........K##K..", "..K#=K........K=#K..", "...K=#K......K#=K...", "..K=#=#K....K#=#=K..",
                     "..K#K=#K....K#=K#K..", "...K.KK......KK.K..."], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K#######+##K....", "...K#########+##K...", "...K##########+#K...",
                     "..K##############K..", "..K##############K..", "..K##############K..", "..K##############K..", "..K##############K..",
                     "..K=############=K..", "..K=############=K..", "..K==##########==K..", "...K=##########=K...", "..K=#=#=####=#=#=K..",
                     "..K#K=#K=##=K#=K#K..", "...K.KK.KKKK.KK.K..."], x: 6),
            cover: [12, 12, 12]),
        // underworld: demon horns.
        hat(part(0, ["..KK............KK..", ".K~K............K~K.", ".K~#K..........K#~K.", ".K##K..........K##K.", "..K#=K........K=#K..",
                     "..K&#=K......K=#&K..", "...K&#=KK..KK=#&K...", "....KK&&K..K&&KK....", "......KK....KK......"], x: 6),
            part(0, ["..KK............KK..", ".K~K............K~K.", ".K~#K..........K#~K.", ".K##K..........K##K.", "..K#=K........K=#K..",
                     "..K&#=K......K=#&K..", "...K&#=KK..KK=#&K...", "....KK&&K..K&&KK....", "......KK....KK......"], x: 6),
            cover: [0, 0, 0]),
        // frost: fur hat with ear flaps.
        hat(part(3, ["......KKKKKK........", "....KK######KK......", "...K#+########K.....", "...K++########=K....", "..KK~-~~~-~~~-~~KK..",
                     ".K~~~~-~~~~-~~~~~~K.", ".K~-~~~~-~~~~-~~~-K.", ".K~~~~~~~~~~~~KKKK..", ".K~~~-~~K...........", ".K-~~~~~K...........",
                     ".K~~-~~~K...........", ".K~~~~~-K...........", "..KKKKKK............"], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K#+#######=K....", "....K++#######=K....", "...KK~-~~~-~~-~~KK..",
                     "..K~~~~-~~~~-~~~~K..", "..K~-~~~~-~~~~-~~K..", "..K~~~KKKKKKKK~~~K..", "..K~~K........K~~K..", "..K-~K........K~-K..",
                     "..K~~K........K~~K..", "..K~-K........K-~K..", "...KK..........KK..."], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K=#######+#K....", "....K=########+K....", "...KK~-~~~-~~-~~KK..",
                     "..K~~~~-~~~~-~~~~K..", "..K~-~~~~-~~~~-~~K..", "..K~~~~~~~~~~~~~~K..", "..K~-~~~~-~~~~-~~K..", "..K~~~~~~~~~~~~~~K..",
                     "..K~~-~~~~~~~-~~~K..", "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [11, 11, 11]),
        // celestial: floating halo over a winged circlet.
        hat(part(0, ["......:^^^^^^:......", ".....^........^.....", "......:^^^^^^:......", "....................", "....................",
                     "....................", "..KK............KK..", ".K++K..........K++K.", ".K#+#KKKKKKKKKK#+#K.", "..K##~~~~^^~~~~##K..",
                     "...KKKKKKKKKKKKKK..."], x: 6),
            part(0, ["......:^^^^^^:......", ".....^........^.....", "......:^^^^^^:......", "....................", "....................",
                     "....................", "..KK............KK..", ".K++K..........K++K.", ".K#+#KKKKKKKKKK#+#K.", "..K##~~~~^^~~~~##K..",
                     "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [0, 0, 0]),
        // rift: starry cowl with a veil over the lower face.
        hat(part(3, ["......KKKKKK........", "....KK######KK......", "...K##^######KK.....", "..K#####:#####=K....", "..K#^##########=K...",
                     "..K############=K...", "..K#########KKK^K...", "..K#######KK~~~K....", "..K######K~~KK......", "..K#####~K..........",
                     "..K#####~K..........", "..K#####~K..........", "..K####=~KK~~~~K....", "..K=###=K-~-~-~K....", ".K=#=#=#K~-~-~K.....",
                     ".K#K=K=#KK-~-K......", "..K.K.KK..KKK......."], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K##^######:K....", "...K#####:######K...", "...K#^##########K...",
                     "..K######KK######K..", "..K#####K^^K#####K..", "..K##KKKKKKKKKK##K..", "..K##K~......~K##K..", "..K##K........K##K..",
                     "..K##K........K##K..", "..K##K........K##K..", "..K##K~~~~~~~~K##K..", "..K#=K-~-~-~-~K=#K..", "...K=K~-~-~-~-K=K...",
                     "....KK-~-~-~-~KK....", "......KK~-~-KK......", "........KKKK........"], x: 6),
            part(3, [".......KKKKKK.......", ".....KK######KK.....", "....K###^######K....", "...K#####:######K...", "...K#^##########K...",
                     "..K##########^###K..", "..K##############K..", "..K####:#########K..", "..K##############K..", "..K#########^####K..",
                     "..K##############K..", "..K=#############K..", "..K=############=K..", "...K=##########=K...", "....KK========KK....",
                     "......KKKKKKKK......"], x: 6),
            cover: [12, 12, 12]),
        // chaos: jagged black crown with glowing gems.
        hat(part(0, [".........KK.........", "...K....K+#K....K...", "..K+K..K++##K..K#K..", "..K+#KK+#:^##KK##K..", "..K+##K+#^^##K###K..",
                     "..K+############=K..", "..K~#~#~#^^#~#~#~K..", "...KKKKKKKKKKKKKK..."], x: 6),
            part(0, [".........KK.........", "...K....K+#K....K...", "..K+K..K++##K..K#K..", "..K+#KK+#:^##KK##K..", "..K+##K+#^^##K###K..",
                     "..K+############=K..", "..K~#~#~#^^#~#~#~K..", "...KKKKKKKKKKKKKK..."], x: 6),
            cover: [0, 0, 0]),
    ]

    private static let cosHats: [[HeroPart]] = hatArt.map { $0.views.map { cosTranslate($0, 0) } }

    /// The worn hat in the hat layer's letters, and the row above which the hair under it is hidden.
    static func cosHat(_ code: UInt8, view: Int) -> (part: HeroPart, cover: Int)? {
        let i = Int(code) - 1
        guard cosHats.indices.contains(i) else { return nil }
        return (cosHats[i][view], hatArt[i].cover[view])
    }

    /// The highest pixel row a worn hat or hairstyle reaches (nil when neither is worn), for chat bubbles over the head.
    static func cosHeadTop(_ w: HeroWear) -> Int? {
        let parts = (0..<3).compactMap { cosHat(w.hat, view: $0)?.part } + (0..<3).compactMap { cosHair(w.hair, view: $0) }
        return parts.compactMap { p in p.g.firstIndex { $0.contains { $0 != "." } }.map { p.y + $0 } }.min()
    }
}

// MARK: - hair

extension RpgArt {
    /// Hairstyles (side, front, back) in the hero's hair colours, replacing the class hair; 20 wide at x 6 like the hats.
    private static let hairArt: [[HeroPart]] = [
        // short bob: rounded, straight-cut bangs, curled in at the jaw.
        [part(5, ["......KKKKKK........", "....KKHHHHHHKK......", "...KHHHHIIHHHHK.....", "...KHHHIHHHHHHHK....", "...KHHIHHHHHHHHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHHHHHHHhhhhK...", "...KHHHHHK..........", "...KHHHHHK..........", "...KHHHHHK..........",
                  "...KhHHHHK..........", "....KhhhK...........", ".....KKK............"], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHIIHHHHK....", "...KHHHHIHHHHHHHK...", "...KHHHIHHHHHHHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHhhhhhhhhhhHK...", "...KHK........KHK...", "...KHK........KHK...", "...KHK........KHK...",
                  "...KhHK......KHhK...", "....KhHK....KHhK....", ".....KK......KK....."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHHIIHHK....", "...KHHHHHHHHIHHHK...", "...KHHHHHHHHHIHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KhHHHHHHHHHHhK...",
                  "...KhhHHHHHHHHhhK...", "....KhhhhhhhhhhK....", ".....KKKKKKKKKK....."], x: 6)],
        // ponytail: pulled back, a tail tied high at the back.
        [part(5, ["......KKKKKK........", "....KKHHHHHHKK......", "...KHHHHIIHHHHK.....", "..KKHHHIHHHHHHHK....", ".KQKHHIHHHHHHHHHK...",
                  "KHHKHHHHHHHHHHHhK...", "KhHKHHHHHHHhhK......", "KhHKHHHHHK..........", ".KhHKHHHHK..........", ".KhHKhhhK...........",
                  "..KhK.KK............", "..KhHK..............", "...KhK..............", "....K..............."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHIIHHHK....", "...KHHHHHHHHIHHHKK..", "...KHHHHHHHHHHHHKQK.",
                  "...KHHHHHHHHHHHHKHHK", "...KHhHHhhhhHHhHKhHK", "...KHK...hh...KHKhHK", "...KHK........KHKhHK", "....K..........KKhHK",
                  "................KhHK", "................KhHK", "...............KhHK.", "...............KhK..", "................K..."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHKKHHHHK....", "...KHHHHKQQKHHHHK...", "...KHHHHKHhKHHHHK...",
                  "...KHHHKHHhhKHHHK...", "...KHHHKHHhhKHHHK...", "...KHHHKHIhhKHHHK...", "...KhHHKHHhhKHHhK...", "...KhhHKHHhhKHhhK...",
                  "....KhhKHHhhKhhK....", ".....KKKHHhhKKK.....", ".......KHHhhK.......", "........KHhK........", ".........KK........."], x: 6)],
        // twin tails: a tail tied at each side.
        [part(5, ["......KKKKKK........", "....KKHHHHHHKK......", "...KHHHHIIHHHHK.....", "..KKHHHIHHHHHHHK....", ".KQKHHKQQKHHHHHHK...",
                  "KHHKHKHHHHKHHHHHK...", "KHhKHKHhHKHHhhhhK...", "KhHKHKhHhK..........", "KhHKHKHhHK..........", ".KhHKKhHhK..........",
                  ".KHhK.KhHK..........", ".KhHK.KHhK..........", "..KhHKKhHK..........", "..KhhK.KhK..........", "...KK...K..........."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHIIHHHK....", "..KKKHHHHHHHIHHHKKK.", ".KHQKHHHHHHHHHHHKQHK",
                  "KHHKHHHHHHHHHHHHKHHK", "KHHKHhHHHhhHHHhHKHHK", "KHhKhK...hh...KhKhHK", "KhHKK..........KKhHK", ".KhHK..........KHhK.",
                  ".KhHK..........KHhK.", ".KHhK..........KhHK.", "..KhHK........KHhK..", "..KhhK........KhhK..", "...KK..........KK..."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHHIIHHK....", "..KKKHHHHHHHHIHHKKK.", ".KHQKHHHHHHHHHHHKQHK",
                  "KHHKHHHHHHHHHHHHKHHK", "KHhKHHHHHHHHHHHHKhHK", "KHhKHHHHHHHHHHHHKhHK", "KhHKhHHHHHHHHHHhKhHK", ".KhHKhhHHHHHHhhKHhK.",
                  ".KhHKKhhhhhhhhKKHhK.", ".KHhK.KKKKKKKK.KhHK.", "..KhHK........KHhK..", "..KhhK........KhhK..", "...KK..........KK..."], x: 6)],
        // long: falls past the shoulders.
        [part(5, ["......KKKKKK........", "....KKHHHHHHKK......", "...KHHHHIIHHHHK.....", "..KHHHHIHHHHHHHK....", "..KHHHIHHHHHHHHHK...",
                  "..KHHHHHHHHHHHHHK...", "..KHHHHHHHHHhSSK....", "..KHHHHHHK..........", "..KHHHHHHK..........", "..KHHHHHHK..........",
                  "..KHHHHHK...........", "..KhHHHHK...........", "..KhHHHHK...........", "..KhhHHHK...........", "..KhhhHK............",
                  "...KhhhK............", "....KKK............."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHIIHHHHK....", "...KHHHHIHHHHHHHK...", "..KHHHHIHHHHHHHHHK..",
                  "..KHHHHHHHHHHHHHHK..", "..KHHhHHHhhHHHhHHK..", "..KHHK...hh...KHHK..", "..KHHK........KHHK..", "..KHHK........KHHK..",
                  "..KHhK........KhHK..", "..KHhHK......KHhHK..", "..KHhHK......KHhHK..", "..KhHhK......KhHhK..", "..KhhhK......KhhhK..",
                  "..KhhK........KhhK..", "...KK..........KK..."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHHIIHHK....", "...KHHHHHHHHIHHHK...", "..KHHHHHHHHHHIHHHK..",
                  "..KHHHHHHHHHHHHHHK..", "..KHHHHHHHHHHHHHHK..", "..KHHHHHHHHHHHHHHK..", "..KHHHHHHHHHHHHHHK..", "..KHHHHHHHHHHHHHHK..",
                  "..KHhHHHHHHHHHHhHK..", "..KHhHHHHHHHHHHhHK..", "..KHhHHHHHHHHHHhHK..", "..KhhHHHHHHHHHHhhK..", "..KhhhHHHHHHHHhhhK..",
                  "...KhhhhhhhhhhhhK...", "....KKKKKKKKKKKK...."], x: 6)],
        // mohawk: a tall crest, the sides shaved.
        [part(0, ["...........K........", "........K.KIK.......", "......K.KIKHHK......", "....K.KIKHHHHK......", "...KIKHHHHHHHHK.....",
                  "...KHHHHHHHHHHHK....", "...KhHHHHHHHHHhK....", "....KhhhhhhhhhK.....", ".....KKKKKKKKK......", "....ss.........s...."], x: 6),
         part(0, [".........KK.........", "........KIIK........", "........KHIK........", ".......KHHIHK.......", ".......KHHIHK.......",
                  ".......KHHHHK.......", ".......KHhHHK.......", ".......KhHHhK.......", "........KhhK........", "......ss.KK.ss......",
                  ".....ss......ss....."], x: 6),
         part(0, [".........KK.........", "........KIIK........", "........KHIK........", ".......KHHIHK.......", ".......KHHHHK.......",
                  ".......KHHHHK.......", ".......KHhHHK.......", ".......KhHHhK.......", "........KhhK........", "......s.KhhK.s......",
                  ".....ss.KhhK.ss.....", ".....s..KhhK..s.....", ".....s..KhhK..s.....", "........KhhK........", "........KhhK........",
                  ".........KK........."], x: 6)],
        // slicked back: combed back off the forehead.
        [part(5, [".....KKKKKK.........", "...KKHHIHHHKK.......", "..KHHIHHIHHHHK......", "..KHIHHIHHHHHHK.....", "..KHHHHHHHHHHHHK....",
                  "..KHHHHHHHHhhK......", "...KHHHHHHK.........", "...KHHHHHK..........", "...KhHHHK...........", "....KKKK............"], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHIHHIHKK.....", "....KHHIHHIHHHHK....", "...KHHIHHIHHHHHHK...", "...KHHHHHHHHHHHHK...",
                  "...KHhhhhhhhhhhHK...", "...KhK........KhK...", "....K..........K...."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHIHHIHKK.....", "....KHHIHHIHHIHK....", "...KHHIHHIHHIHHHK...", "...KHHIHHIHHIHHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KhHHHHHHHHHHhK...", "....KhhhhhhhhhhK....", ".....KKKKKKKKKK....."], x: 6)],
        // braid: one plait over the shoulder, tied with the accent colour.
        [part(5, ["......KKKKKK........", "....KKHHHHHHKK......", "...KHHHHIIHHHHK.....", "...KHHHIHHHHHHHK....", "...KHHIHHHHHHHHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHHHHHHHhhhhK...", "...KHHHHHK..........", "...KHHHHHK..........", "...KhHHHK...........",
                  "..KHhKKK............", "..KhHK..............", "..KHhK..............", "..KhHK..............", "..KQQK..............",
                  "..KhHK..............", "...KK..............."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHIIHHHHHHK....", "...KHHIHHHHHHHHHK...", "...KHHHHHHHHHHHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHhhhHHHhhhHK...", "..KHHK...hh...KHK...", "..KHHK........KHK...", "..KHhK........KhK...",
                  "..KhHK.........K....", "..KHhK..............", "..KhHK..............", "..KHhK..............", "..KhHK..............",
                  "..KQQK..............", "..KhHK..............", "...KK..............."], x: 6),
         part(5, [".......KKKKKK.......", ".....KKHHHHHHKK.....", "....KHHHHHHIIHHK....", "...KHHHHHHHHIHHHK...", "...KHHHHHHHHHIHHK...",
                  "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KHHHHHHHHHHHHK...", "...KhHHHHHHHHHHhK...", "...KhhHHKHhKHHhhK...",
                  "....KhhKhHHhKhhK....", ".....KKKHhhHKKK.....", ".......KhHHhK.......", ".......KHhhHK.......", ".......KhHHhK.......",
                  ".......KQQQQK.......", "........KhhK........", ".........KK........."], x: 6)],
        // curly: a big round mop of curls.
        [part(3, [".....KK.KK.KK.......", "...KKHHKHHKHHKK.....", "..KHHIHHHIHHHIHK....", ".KHHIHHhHHHhHHHHK...", "KHhHHHHHIHHHHIHhHK..",
                  "KHHHIHHHHHHHHHHHHK..", "KHhHHHHhHHHIHHhHHHK.", "KHHHIHHHHHHHHHHhhK..", "KHhHHhHHhHHhhSSK....", "KhHHHhHHHK..........",
                  "KHhHHHhHHK..........", ".KhHHhHHK...........", ".KHhhHhK............", "..KKKKK............."], x: 6),
         part(3, ["......KK.KK.KK......", "....KKHHKHHKHHKK....", "...KHHIHHHIHHHIHK...", "..KHHIHHhHHHhHHHHK..", ".KHhHHHHHIHHHHIHhHK.",
                  ".KHHHIHHHHHHHHHHHHK.", "KHhHHHHhHHHIHHhHHhHK", "KHHHIHHHHHHHHHHHHHHK", "KHhHHhHHhhHHhhHHhHhK", "KhHHK....hh....KHHhK",
                  "KHhHK..........KHhHK", ".KhHHK........KHHhK.", ".KHhhK........KhhHK.", "..KKK..........KKK.."], x: 6),
         part(3, ["......KK.KK.KK......", "....KKHHKHHKHHKK....", "...KHHIHHHIHHHIHK...", "..KHHIHHhHHHhHHHHK..", ".KHhHHHHHIHHHHIHhHK.",
                  ".KHHHIHHHHHHHHHHHHK.", "KHhHHHHhHHHIHHhHHhHK", "KHHHIHHHHHHHHHHHHHHK", "KHhHHhHHhHHHhHHhHHhK", "KhHHHHhHHHhHHHHhHHhK",
                  "KHhHHhHHHhHHHhHHHhHK", ".KhHHHhHHHHhHHHhHhK.", ".KHhhHHhhHHhhHHhhHK.", "..KKKhhKKhhKKhhKKK..", ".....KK..KK..KK....."], x: 6)],
    ]

    /// A worn hairstyle for a view.
    static func cosHair(_ code: UInt8, view: Int) -> HeroPart? {
        let i = Int(code) - 1
        return hairArt.indices.contains(i) ? hairArt[i][view] : nil
    }
}

// MARK: - faces

extension RpgArt {
    /// Eyes and mouths over the base face, side (x 14-21) and front (x 12-19), rows from 12; `.` keeps the face below.
    private static let faceArt: [[HeroPart?]] = [
        // wink, tongue out.
        [part(12, ["SSSoSSS.", "SSoSoSS.", "SSSSSSS.", "........", ".....o.."], x: 14),
         part(12, ["SooSSSoS", "SwoSSoSo", "SiiSSSSS", "........", "...oo...", "...x...."], x: 12), nil],
        // sleepy: heavy lids.
        [part(12, ["SSSSSSS.", "SSooSSS.", "SSioSSS.", "........", ".....o.."], x: 14),
         part(12, ["SSSSSSSS", "SooSSooS", "SioSSioS", "........", "....o..."], x: 12), nil],
        // sparkling: shining eyes.
        [part(12, ["SSwoSSS.", "SSooSSS.", "SSowSSS.", "....x...", ".....o.."], x: 14),
         part(12, ["SwoSSwoS", "SooSSooS", "SowSSowS", "x......x", "...oo..."], x: 12), nil],
        // blank: dot eyes, flat mouth.
        [part(12, ["SSSSSSS.", "SSSoSSS.", "SSSSSSS.", "........", ".....o.."], x: 14),
         part(12, ["SSSSSSSS", "SSoSSoSS", "SSSSSSSS", "........", "...oo..."], x: 12), nil],
        // happy squint: ^ ^ and a smile.
        [part(12, ["SSSoSSS.", "SSoSoSS.", "SSSSSSS.", "....xx..", ".....o.."], x: 14),
         part(12, ["SoSSSSoS", "oSoSSoSo", "SSSSSSSS", "xx....xx", "..o..o..", "...oo..."], x: 12), nil],
        // fierce: slanted brows, narrowed eyes, a frown.
        [part(12, ["SooSSSS.", "SSSoSSS.", "SSioSSS.", "........", ".....o.."], x: 14),
         part(12, ["ooSSSSoo", "SooSSooS", "SioSSoiS", "........", "...oo...", "..o..o.."], x: 12), nil],
    ]

    /// A worn face's eyes and mouth for a view (none from the back).
    static func cosFace(_ code: UInt8, view: Int) -> HeroPart? {
        let i = Int(code) - 1
        return faceArt.indices.contains(i) ? faceArt[i][view] : nil
    }
}

// MARK: - hems and patterns (outfits and capes)

extension RpgArt {
    fileprivate enum CosHem { case none, trim, zigzag, scallop, leaves, shards, hazard, waves, rags, flames, fur, feathers, spikes }
    fileprivate enum CosPattern { case none, dots, confetti, scales, stars, stripes, runes, wisps, veins }

    private static func isRole(_ c: Character) -> Bool { cosRoleIndex[c] != nil }

    /// Rows as character arrays padded to one width.
    private static func cells(_ g: RpgGrid) -> [[Character]] {
        let w = g.map(\.count).max() ?? 0
        return g.map { Array($0) + Array(repeating: ".", count: w - $0.count) }
    }

    private static func grid(_ c: [[Character]]) -> RpgGrid {
        var rows = c.map { String($0) }
        while let last = rows.last, !last.contains(where: { $0 != "." }) { rows.removeLast() }
        return rows
    }

    /// Recolours the main-colour pixels of a role grid in a repeating pattern (grid coordinates, so it rides along with the part).
    fileprivate static func patterned(_ c: inout [[Character]], _ p: CosPattern) {
        guard p != .none else { return }
        for y in c.indices {
            for x in c[y].indices where c[y][x] == "#" {
                let mark: Character? = switch p {
                case .none: nil
                case .dots: x % 3 == 1 && y % 3 == 1 ? "~" : nil
                case .confetti: (x * 5 + y * 3) % 7 == 0 ? (y % 2 == 0 ? "~" : "^") : nil
                case .scales: y % 2 == 1 && (x + y / 2) % 2 == 0 ? "=" : nil
                case .stars: (x * 7 + y * 5) % 13 == 0 ? "^" : (x * 7 + y * 5) % 13 == 6 ? ":" : nil
                case .stripes: x % 3 == 0 ? "=" : nil
                case .runes: (x + y) % 4 == 0 && y % 2 == 1 ? "^" : nil
                case .wisps: (x * 3 + y * 7) % 11 == 0 ? ":" : nil
                case .veins: (x + y) % 3 == 0 ? "=" : nil
                }
                if let mark { c[y][x] = mark }
            }
        }
    }

    /// Inside pixels next to the outline become trim (gold-edged capes).
    fileprivate static func edged(_ c: inout [[Character]]) {
        let src = c
        for y in src.indices {
            for x in src[y].indices where isRole(src[y][x]) {
                let near = [(0, 1), (0, -1), (1, 0), (-1, 0)].contains { d in
                    let ny = y + d.1, nx = x + d.0
                    return ny >= 0 && ny < src.count && nx >= 0 && nx < src[ny].count && src[ny][nx] == "K"
                }
                if near { c[y][x] = "~" }
            }
        }
    }

    /// Reshapes the bottom edge of an outlined part: bumps, rags, flames, spikes and the like hang from its last outlined row.
    fileprivate static func hemmed(_ c: inout [[Character]], _ hem: CosHem) {
        guard hem != .none, let b = c.lastIndex(where: { $0.contains("K") }), b > 0 else { return }
        let f = b - 1
        // Columns where the bottom outline closes a filled column.
        let cols = c[b].indices.filter { x in c[b][x] == "K" && x < c[f].count && isRole(c[f][x]) }
        guard !cols.isEmpty else { return }
        while c.count < b + 4 { c.append(Array(repeating: ".", count: c[0].count)) }
        func set(_ x: Int, _ y: Int, _ ch: Character) { if y < c.count, x >= 0, x < c[y].count { c[y][x] = ch } }
        func outline(_ x: Int, _ y: Int) { if y < c.count, x >= 0, x < c[y].count, c[y][x] == "." { c[y][x] = "K" } }
        /// A tooth of `len` pixels hanging below column x, outlined.
        func tooth(_ x: Int, _ len: Int, _ fill: Character, tip: Character? = nil) {
            for k in 0..<len { set(x, b + k, k == len - 1 ? (tip ?? fill) : fill); outline(x - 1, b + k + 1); outline(x + 1, b + k + 1) }
            set(x, b + len, "K")
        }
        switch hem {
        case .none: break
        case .trim:
            for x in cols { set(x, f, "~") }
        case .zigzag:
            for x in cols { set(x, f, "~") }
            for (i, x) in cols.enumerated() where i % 2 == 0 { tooth(x, 1, "~") }
        case .scallop:
            for x in cols { set(x, f, "~") }
            for (i, x) in cols.enumerated() where i % 3 == 1 { tooth(x, 1, "~"); set(x - 1, b, "~"); set(x + 1, b, "~"); set(x - 1, b + 1, "K"); set(x + 1, b + 1, "K"); set(x - 2, b, "K"); set(x + 2, b, "K") }
        case .leaves:
            for (i, x) in cols.enumerated() where i % 3 == 1 { tooth(x, 2, "#", tip: "="); set(x - 1, b, "#"); set(x + 1, b, "#") }
        case .shards:
            for (i, x) in cols.enumerated() where i % 3 == 1 { tooth(x, 2, "~", tip: "^") }
        case .hazard:
            for x in cols { set(x, f, (x + f) % 4 < 2 ? "~" : "&"); if f > 0, isRole(c[f - 1][x]) { set(x, f - 1, (x + f - 1) % 4 < 2 ? "~" : "&") } }
        case .waves:
            for x in cols { set(x, f, "~") }
            for (i, x) in cols.enumerated() where i % 4 == 1 || i % 4 == 2 { tooth(x, 1, "~") }
        case .rags:
            for (i, x) in cols.enumerated() {
                switch i % 5 {
                case 1: tooth(x, 2, "=")
                case 3: tooth(x, 1, "=")
                case 4: set(x, f, "K")
                default: break
                }
            }
        case .flames:
            for x in cols { set(x, f, "~") }
            for (i, x) in cols.enumerated() where i % 3 == 0 { tooth(x, 2, "~", tip: "^") }
        case .fur:
            for x in cols { set(x, f, x % 3 == 0 ? "-" : "~") }
            for (i, x) in cols.enumerated() where i % 2 == 0 { tooth(x, 1, "~") }
        case .feathers:
            for (i, x) in cols.enumerated() where i % 2 == 0 { tooth(x, i % 4 == 0 ? 2 : 1, "#", tip: "~") }
        case .spikes:
            for (i, x) in cols.enumerated() where i % 3 == 1 { tooth(x, 2, "#", tip: "~") }
        }
    }
}

// MARK: - outfits

extension RpgArt {
    /// Each class's torso letters an outfit recolours, by role: cloth to the main colour, gold and straps to the trim, belts deep.
    private static let outfitLetters: [RpgClass: [Character: Character]] = [
        .warrior: ["M": "#", "N": "+", "m": "=", "R": "~", "r": "-", "L": "&", "l": "&", "Y": "^"],
        .archer: ["G": "#", "N": "+", "g": "=", "Q": "~", "q": "-", "L": "&", "l": "&", "Y": "^"],
        .mage: ["P": "#", "N": "+", "p": "=", "Y": "~", "Q": "&", "q": "&"],
        .rogue: ["Z": "#", "N": "+", "z": "=", "L": "~", "l": "-", "R": "^", "X": ":", "n": "&"],
        .cleric: ["W": "#", "V": "=", "Q": "~", "Y": "-"],
        .monk: ["F": "#", "f": "+", "N": "=", "Q": "~", "q": "-"],
        .summoner: ["E": "#", "e": "=", "A": "~", "a": "-", "N": "*", "O": "^", "Q": "&", "q": "&", "Y": "~"],
        .mechanic: ["F": "#", "f": "+", "N": "=", "Z": "~", "z": "-", "Q": "~", "q": "-", "L": "&", "l": "&", "X": ":"],
    ]

    // Outfit pieces over the torso (x 8; side, front, back). Torsos start at row 18: side columns 5-10, front and back 4-11.
    private static let noPart = part(0, [])
    private static let fCollar = [part(19, [".....~~~~~......"]), part(19, ["....~~~..~~~...."]), part(19, ["....~~~~~~~~...."])]
    private static let fSash = [part(19, ["..........~.....", ".........~~.....", "........~~......", ".......~~......."]),
                                part(19, ["....~~..........", ".....~~.........", "......~~........", ".......~~.......", "........~~......"]),
                                part(19, ["..........~~....", ".........~~.....", "........~~......", ".......~~.......", "......~~........"])]
    private static let fRuff = [part(18, [".....KKKKKK.....", "....K~*~*~*K....", ".....K~K~K~K....", "......K.K.K....."]),
                                part(18, ["..KKKKKKKKKKKK..", ".K~*~*~*~*~*~*K.", "..K~K~K~~K~K~K..", "...K.K.KK.K.K..."]),
                                part(18, ["..KKKKKKKKKKKK..", ".K~*~*~*~*~*~*K.", "..K~K~K~~K~K~K..", "...K.K.KK.K.K..."])]
    private static let fJabot = [part(19, ["..........XK....", "..........XXK...", "..........XK....", ".........~......"]),
                                 part(19, ["......KXXK......", ".....~.XX.~.....", "......KXXK......", ".....~.XX.~....."]), noPart]
    private static let fTails = [part(22, ["...K#K..........", "..K##K..........", "..K#=K..........", "..K#=K..........", "...KK..........."]),
                                 part(22, ["..K#K......K#K..", "..K#K......K#K..", "..K=K......K=K..", "...K........K..."]),
                                 part(22, ["...K###KK###K...", "...K###KK###K...", "...K#=#KK#=#K...", "...K#=K..K=#K...", "....KK....KK...."])]
    private static let fPockets = [part(20, [".......-~~......", ".......--~......"]), part(20, ["....-~~..~~-....", "....--~..~--...."]), noPart]
    private static let fStraps = [part(19, [".......~~.......", ".......~~.......", "......~~~~......", "......~~~~......"]),
                                  part(19, ["....~~....~~....", "....~~....~~....", "....~~~^^~~~....", "....~~~~~~~~...."]),
                                  part(19, ["....~~....~~....", ".....~~..~~.....", "......~~~~......"])]
    private static let fStole = [part(19, ["..........~.....", "..........~.....", "..........~.....", "..........~.....", "..........~....."]),
                                 part(19, [".....~....~.....", ".....~....~.....", ".....~....~.....", ".....~....~.....", ".....~....~....."]), noPart]
    private static let fPlates = [part(16, [".....KKKKK......", "....K+##~K......", "....K###~K......", "....K~~~~K......", ".....KKKK......."]),
                                  part(17, [".KKKK......KKKK.", "K+##~K....K~##+K", "K###~K....K~###K", "K~~~~K....K~~~~K", ".KKKK......KKKK."]),
                                  part(17, [".KKKK......KKKK.", "K+##~K....K~##+K", "K###~K....K~###K", "K~~~~K....K~~~~K", ".KKKK......KKKK."])]
    private static let fCrest = [noPart, part(20, [".......~~.......", "......~^^~......", ".......~~......."]), noPart]
    private static let fShells = [part(16, [".....KKKKK......", "....K~#~#K......", "....K#~#~K......", "....K~#~#K......", ".....KKKK......."]),
                                  part(17, [".KKKK......KKKK.", "K~#~#K....K#~#~K", "K#~#~K....K~#~#K", "K~#~#K....K#~#~K", ".KKKK......KKKK."]),
                                  part(17, [".KKKK......KKKK.", "K~#~#K....K#~#~K", "K#~#~K....K~#~#K", "K~#~#K....K#~#~K", ".KKKK......KKKK."])]
    private static let fPearls = [noPart, part(19, ["....:.:..:.:....", ".....:.::.:....."]), noPart]
    private static let fSpikes = [part(14, [".....K..........", ".....K#K........", "....K#=K........", "....K#=#KK......", "....K#=##K......", "....K~~~~K......", ".....KKKK......."]),
                                  part(15, ["..K..........K..", ".K#K........K#K.", "KK#=KK....KK=#KK", "K#=#~K....K~#=#K", "K~~~~K....K~~~~K", ".KKKK......KKKK."]),
                                  part(15, ["..K..........K..", ".K#K........K#K.", "KK#=KK....KK=#KK", "K#=#~K....K~#=#K", "K~~~~K....K~~~~K", ".KKKK......KKKK."])]
    private static let fShards = [part(14, [".....K..........", "....K^K.........", "....K:^K........", "....K^:^K.......", "....K~^~~K......", "....K~~~~K......", ".....KKKK......."]),
                                  part(15, ["..K..........K..", ".K^K........K^K.", ".K:^K......K^:K.", "K~^~~K....K~~^~K", "K~~~~K....K~~~~K", ".KKKK......KKKK."]),
                                  part(15, ["..K..........K..", ".K^K........K^K.", ".K^:K......K:^K.", "K~^~~K....K~~^~K", "K~~~~K....K~~~~K", ".KKKK......KKKK."])]
    private static let fFur = [part(18, [".....KKKKKK.....", "....K~~-~~~K....", "....K~-~~~-K....", ".....KK.KKK....."]),
                               part(18, ["..KKKKKKKKKKKK..", ".K~~-~~~~~~-~~K.", ".K~-~~~-~~~~-~K.", "..KK.KKKKKK.KK.."]),
                               part(18, ["..KKKKKKKKKKKK..", ".K~~-~~~~~~-~~K.", ".K~-~~~~-~~~-~K.", "..KK.KKKKKK.KK.."])]
    private static let fHighCollar = [part(16, ["....K...........", "...K~K..........", "...K~~KKKKKK....", "...K~~~~~~~K...."]),
                                      part(16, ["...K........K...", "..K~K......K~K..", "..K~~KKKKKK~~K..", "..K~~~~~~~~~~K.."]),
                                      part(16, ["...KKKKKKKKKK...", "..K~~~~~~~~~~K..", "..K~~~~~~~~~~K..", "..K~~~~~~~~~~K.."])]
    private static let fGem = [part(19, ["..........KK....", "..........^:K...", "..........KK...."]),
                               part(19, ["......KKKK......", ".....K^::^K.....", "......K^^K......", ".......KK......."]), noPart]

    private struct OutfitStyle {
        var pattern: CosPattern = .none
        var hem: CosHem = .none
        var parts: [[HeroPart]] = []
    }

    /// One outfit per set, in set order.
    private static let outfitStyles: [OutfitStyle] = [
        OutfitStyle(parts: [fSash, fCollar]),                                   // classic: traveller's vest and satchel strap
        OutfitStyle(pattern: .confetti, hem: .scallop, parts: [fRuff]),         // festival: confetti and a ruff
        OutfitStyle(hem: .trim, parts: [fJabot, fTails]),                       // coast: captain's coat
        OutfitStyle(parts: [fPockets, fCollar]),                                // jungle: explorer's shirt
        OutfitStyle(pattern: .dots, hem: .scallop, parts: [fCollar]),           // mushroom: spotted, petal hem
        OutfitStyle(hem: .trim, parts: [fStole, fTails]),                       // ancient: scholar's robe and stole
        OutfitStyle(pattern: .stars, parts: [fShards]),                         // crystal: shards on the shoulders
        OutfitStyle(hem: .hazard, parts: [fStraps]),                            // factory: work overalls
        OutfitStyle(hem: .trim, parts: [fPlates, fCrest]),                      // skyisle: knight's plate
        OutfitStyle(pattern: .scales, parts: [fShells, fPearls]),               // undersea: scales, shells, pearls
        OutfitStyle(pattern: .wisps, hem: .rags),                               // haunted: tattered shroud
        OutfitStyle(hem: .flames, parts: [fSpikes]),                            // underworld: spiked, flame hem
        OutfitStyle(hem: .fur, parts: [fFur]),                                  // frost: fur collar and hem
        OutfitStyle(hem: .trim, parts: [fHighCollar, fSash]),                   // celestial: gold-trimmed vestment
        OutfitStyle(pattern: .stars, parts: [fGem]),                            // rift: starfield and a gem
        OutfitStyle(pattern: .runes, hem: .spikes, parts: [fHighCollar, fGem]), // chaos: glowing runes
    ]

    private static var outfitCache: [Int: [HeroPart]] = [:]

    /// The parts an outfit draws in place of a class's torso and armour pieces (outfit layer letters).
    static func cosOutfit(_ cls: RpgClass, code: UInt8, view: Int) -> [HeroPart] {
        let t = Int(code) - 1
        guard outfitStyles.indices.contains(t), let art = heroClasses[cls], let cindex = RpgClass.allCases.firstIndex(of: cls) else { return [] }
        let key = (cindex * 64 + t) * 4 + view
        if let hit = outfitCache[key] { return hit }
        let style = outfitStyles[t]
        let torso = art.torso[view]
        let map = outfitLetters[cls] ?? [:]
        var c = cells(torso.g.map { String($0.map { map[$0] ?? $0 }) })
        patterned(&c, style.pattern)
        hemmed(&c, style.hem)
        let parts = [cosTranslate(HeroPart(x: torso.x, y: torso.y, g: grid(c)), 1)] + style.parts.map { cosTranslate($0[view], 1) }
        outfitCache[key] = parts
        return parts
    }
}

// MARK: - capes

extension RpgArt {
    private struct CapeStyle {
        var hem: CosHem = .none
        var edge = false
        var pattern: CosPattern = .none
        /// A small picture on the back, centred.
        var emblem: RpgGrid = []
        /// The clasp at the throat, seen from the front (four letters).
        var clasp = "K~~K"
    }

    /// One cape per set, in set order.
    private static let capeStyles: [CapeStyle] = [
        CapeStyle(),                                                                                        // classic: plain travelling cloak
        CapeStyle(hem: .zigzag, pattern: .confetti, clasp: "K^^K"),                                      // festival
        CapeStyle(hem: .trim, edge: true, emblem: [".XX.", "XooX", ".XX.", "X..X"], clasp: "~KK~"),      // coast: skull and crossbones
        CapeStyle(hem: .leaves, pattern: .veins, emblem: ["..~", ".~.", "~.."], clasp: "K#~K"),           // jungle: leaf cloak
        CapeStyle(hem: .scallop, pattern: .dots, clasp: "K~~K"),                                          // mushroom
        CapeStyle(hem: .trim, edge: true, emblem: [".~~.", "~^^~", ".~~."], clasp: "K^^K"),               // ancient: the eye
        CapeStyle(hem: .shards, emblem: [".^.", "^:^", ".^."], clasp: "K^:K"),                            // crystal
        CapeStyle(hem: .hazard, emblem: ["~.~", ".&.", "~.~"], clasp: "K~~K"),                            // factory: hazard stripes, gear
        CapeStyle(hem: .trim, edge: true, emblem: ["~..~", "~~~~", ".~~."], clasp: "~^^~"),               // skyisle: wings
        CapeStyle(hem: .waves, pattern: .scales, clasp: "K::K"),                                          // undersea
        CapeStyle(hem: .rags, pattern: .wisps, clasp: "K::K"),                                            // haunted
        CapeStyle(hem: .flames, emblem: ["~..~", ".~~.", "~^^~"], clasp: "K^^K"),                         // underworld
        CapeStyle(hem: .fur, emblem: ["X.X", ".X.", "X.X"], clasp: "~--~"),                               // frost: snowflake
        CapeStyle(hem: .feathers, edge: true, emblem: ["..:..", ".:^:.", "..:.."], clasp: "~^^~"),        // celestial: star
        CapeStyle(edge: true, pattern: .stars, clasp: "K^^K"),                                            // rift: starfield
        CapeStyle(hem: .spikes, pattern: .runes, emblem: ["^.^", ".^.", "^.^"], clasp: "K^^K"),           // chaos: sigil
    ]

    private static var capeCache: [Int: HeroPart] = [:]

    /// A worn cape for a view and cloth frame: the class cape's shape and sway in the set's colours (cape layer letters).
    static func cosCape(_ code: UInt8, view: Int, flap: Int) -> HeroPart? {
        let t = Int(code) - 1
        guard capeStyles.indices.contains(t), let views = backParts[.cape], views.indices.contains(view), !views[view].isEmpty else { return nil }
        let frame = min(flap, views[view].count - 1)
        let key = (t * 4 + view) * 4 + frame
        if let hit = capeCache[key] { return hit }
        let base = views[view][frame]
        let style = capeStyles[t]
        var c = cells(base.g.map { String($0.map { $0 == "Q" ? "#" : $0 == "q" ? "=" : $0 }) })
        patterned(&c, style.pattern)
        if style.edge, view == 2 { edged(&c) }
        hemmed(&c, style.hem)
        if view == 2, !style.emblem.isEmpty {
            // Centred on the back between the shoulder blades (frame x 15.5, row 21).
            let w = style.emblem[0].count, x0 = 16 - w / 2 - base.x, y0 = 3
            for (dy, row) in style.emblem.enumerated() {
                for (dx, ch) in row.enumerated() where ch != "." {
                    let y = y0 + dy, x = x0 + dx
                    if y < c.count, x < c[y].count, isRole(c[y][x]) { c[y][x] = ch }
                }
            }
        }
        let part = cosTranslate(HeroPart(x: base.x, y: base.y, g: grid(c)), 2)
        capeCache[key] = part
        return part
    }

    /// What shows of a worn cape from the front: its collar either side of the chin and the clasp at the throat (cape layer letters).
    static func cosCapeClasp(_ code: UInt8) -> HeroPart? {
        let t = Int(code) - 1
        guard capeStyles.indices.contains(t) else { return nil }
        return cosTranslate(HeroPart(x: 12, y: 18, g: ["##....##", "#=" + capeStyles[t].clasp + "=#"]), 2)
    }
}

// MARK: - wings

extension RpgArt {
    /// Cosmetic wings by set (only the late sets have them): the left wing raised and lowered, 13 wide, its root at the
    /// bottom right where it meets the shoulder blade.
    private static let wingArt: [String: [RpgGrid]] = [
        // knight's wings: swept-back blades with a gold leading edge.
        "skyisle": [["KK...........", "K~KK.........", ".K~+KK.......", ".K~++#KK.....", "..K~+###KK...", "..K~+#####KK.", "...K~+######K",
                     "..K~K~+####=K", "..K~+K~+##=K.", ".K~+=KK~+=K..", ".K~=K..KKK...", "..KK........."],
                    [".............", ".............", "KKK..........", "K~+KKK.......", ".K~++#KKK....", "..K~+####KKK.", "..KK~+######K",
                     ".K~+K~+####=K", ".K~++K~+##=K.", "K~+=KK~+=KK..", "K~=K.KKKK....", "KKK.........."]],
        // angel: a big rounded wing of white feathers, scalloped below.
        "celestial": [["...KKK.......", ".KK+++KK.....", "K+++####KK...", "K++######=K..", ".K+#######=K.", ".K+##=##=##=K", "..K+=#=#==#=K",
                       "..K+K=K==K=K.", ".K+K.K=K=KK..", ".K+KK.KKK....", "..KK.........", "............."],
                      [".............", ".............", "...KKK.......", ".KK+++KKK....", "K+++#####KK..", "K++#######=K.", ".K+##=##=##=K",
                       ".K+#=#=#==#=K", "..K+=K=K==KK.", "..K+KK=K=K...", ".K+K.KKKK....", ".KK.........."]],
        // fins: pale ribs fanning from the root through sea-green webbing.
        "undersea": [["K............", "K~K..........", "K#~K..K......", ".K#~KK~K.....", ".K##~#~#K....", "..K#~##~#K...", "..K##~#~##KK.",
                      "...K#~##~#~~K", "...K##~#~~~~K", "....K#~~~=KK.", "....K~~KKK...", ".....KK......"],
                     [".............", ".............", "KK...........", "K~KK..K......", ".K#~KK~K.....", ".K##~#~#KK...", "..K#~##~##KK.",
                      "..K##~#~##~~K", "...K#~#~~~~~K", "...K#~~~=KKK.", "....K~~KK....", ".....KK......"]],
        // ghostly tatters drifting loose.
        "haunted": [["..K..........", ".K:K.........", ".K~#K...K....", "K~##K..K:K...", "K~###K.K#~K..", ".K~###K~##=K.", ".K~####~##==K",
                     "..K~##=###=:K", "..K.K#=K#=K.K", "...K.K=KK=K..", "......K..K...", "............."],
                    [".............", ".............", "..K..........", ".K:K....K....", "K~##K..K:K...", "K~###KK~#=K..", ".K~####~##=KK",
                     ".K~###=###=:K", "..K.K#=K#=K.K", "...K.K=KK=K..", "......K..K...", "............."]],
        // bat wings: a bone along the top, claw at the wrist, scalloped skin between the fingers.
        "underworld": [["..K..........", ".K~K.........", ".K~#KK.......", "K~&##~KK.....", "K~&###~~KK...", ".K~&####~~KK.", ".K~K&####~=~K",
                        "..K.K&###~==K", "....KK&##~=K.", "......KK&=K..", "........KK...", "............."],
                       [".............", ".............", ".............", "KK...........", "K~KKK........", "K~&##KKK.....", ".K~&###~~KKK.",
                        ".K~&#####~~=K", "..K~K&###~==K", "..KK.KK&#~=K.", "......KK&=K..", "........KK..."]],
        // ice: separate sharp crystal shards.
        "frost": [["K............", "K~K..........", "K:~K.........", ".K:~K..K.....", ".K~#~KK~K....", "..K~##K:~K...", "..K~###K~#K..",
                   "...K~###~##KK", "..K^K~##~##=K", ".K^K.K~#~#=K.", "K^K...K~~=K..", "KK.....KKK..."],
                  [".............", ".............", "KK...........", "K:KK.........", ".K:~~KK..K...", "..K~###KK~K..", "..K~####K~#K.",
                   "...K~###~##KK", "..K^K~##~##=K", ".K^K.K~#~#=K.", "K^K...K~~=K..", "KK.....KKK..."]],
        // rift: broken shards hanging apart, edged in light.
        "rift": [["K............", "K^K..........", ".K~K.K.......", "..K.K^K......", ".K~K.K~K.....", "K^#~K.K#K....", ".K~#~K.K#~K..",
                  "..K~#~K~##~K.", "...K~#K.K~#^K", "....K~K..K~K.", ".....K....K..", "............."],
                 [".............", ".............", "K.K..........", "K^KK^K.......", ".K~KK~K......", ".K~#K.K#~K...", "..K~#~K~#~K..",
                  "...K~#~K~##~K", "....K~#K.K~^K", ".....K~K..K~K", "......K....K.", "............."]],
        // chaos: jagged black thorns rimmed in pink.
        "chaos": [["K............", "KK........K..", "K~K......K~K.", ".K~K....K~#K.", ".K#~K..K~##K.", "..K#~KK~###KK", "..K##~~####~K",
                   ".K~K###K###~K", "K~K.K#K.K#~K.", "KK...K...KK..", ".............", "............."],
                  [".............", ".............", "KK...........", "K~KK......KK.", ".K#~KK...K~K.", "..K##~K.K~#KK", "..K###~~###~K",
                   ".K~K###K###~K", "K~K.K#K.K#~K.", "KK...K...KK..", ".............", "............."]],
    ]

    private static var wingCache: [Int: HeroPart] = [:]

    /// Worn wings for a view and flap (0 raised, 1 lowered): a pair behind the body, one wing from the side (wings layer letters).
    static func cosWings(_ code: UInt8, view: Int, flap: Int) -> HeroPart? {
        let t = Int(code) - 1
        guard RpgCosmetics.themes.indices.contains(t), let art = wingArt[RpgCosmetics.themes[t].key] else { return nil }
        let key = (t * 4 + view) * 2 + flap
        if let hit = wingCache[key] { return hit }
        let half = cells(art[flap & 1])
        let w = half.first?.count ?? 0, n = heroSize
        // The left wing's root sits at the shoulder blade (x 12, row 17), the right wing is its mirror; from the side the one
        // wing roots two pixels further forward, behind the back.
        let top = 8
        var rows = Array(repeating: Array(repeating: Character("."), count: n), count: half.count)
        for (y, row) in half.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                let lx = (view == 0 ? 14 : 12) - (w - 1) + x
                if lx >= 0, lx < n { rows[y][lx] = ch }
                if view != 0 { let rx = n - 1 - lx; if rx >= 0, rx < n { rows[y][rx] = ch } }
            }
        }
        let part = cosTranslate(HeroPart(x: 0, y: top, g: grid(rows)), 3)
        wingCache[key] = part
        return part
    }
}

// MARK: - weapon skins

extension RpgArt {
    /// Which role colours a weapon skin paints the held art's blade, blade edge, guard and handle with, by set.
    private static let skinRoles: [(blade: Int, edge: Int, guard: Int, handle: Int)] = [
        (5, 3, 0, 8), (2, 0, 3, 1), (5, 3, 0, 8), (2, 0, 3, 8), (3, 4, 0, 1), (5, 3, 0, 8), (5, 3, 0, 8), (2, 0, 3, 8),
        (0, 6, 3, 4), (3, 0, 1, 8), (3, 6, 0, 8), (3, 0, 8, 8), (3, 0, 1, 8), (5, 3, 0, 4), (3, 2, 0, 8), (3, 0, 8, 8),
    ]

    private enum SkinMark { case none, stripes, dots, edge, checker }

    /// The pattern a skin lays over the blade (template coordinates, so it turns with the weapon) and its role colour, by set:
    /// candy and hazard stripes, spots, a glowing edge, facets.
    private static let skinMarks: [(mark: SkinMark, role: Int)] = [
        (.none, 0), (.stripes, 3), (.edge, 6), (.dots, 6), (.dots, 0), (.dots, 7), (.checker, 2), (.stripes, 8),
        (.edge, 3), (.checker, 1), (.dots, 7), (.stripes, 6), (.dots, 7), (.edge, 7), (.dots, 6), (.checker, 3),
    ]

    /// A weapon's held colours under a skin (stats stay the weapon's own); `y` is the pattern colour of `cosSkinLetter`.
    static func cosWeaponColors(_ base: [Character: CGColor], skin: UInt8) -> [Character: CGColor] {
        let t = Int(skin) - 1
        guard cosColors.indices.contains(t), skinRoles.indices.contains(t), skinMarks.indices.contains(t) else { return base }
        let c = cosColors[t], r = skinRoles[t]
        var out = base
        out["B"] = c[r.blade]; out["b"] = scaled(c[r.blade], 0.72); out["E"] = c[r.edge]
        out["G"] = c[r.guard]; out["H"] = c[r.handle]
        out["J"] = c[7]; out["O"] = c[6]; out["@"] = c[6]; out["%"] = c[7]
        out["L"] = c[r.handle]; out["A"] = c[r.blade]
        out["y"] = c[skinMarks[t].role]
        return out
    }

    /// A held-weapon template letter at (x, y) under a skin's pattern.
    static func cosSkinLetter(_ skin: UInt8, _ ch: Character, x: Int, y: Int) -> Character {
        let t = Int(skin) - 1
        guard skinMarks.indices.contains(t), ch == "B" || ch == "E" else { return ch }
        let on = switch skinMarks[t].mark {
        case .none: false
        case .stripes: x % 3 == 0
        case .dots: ch == "B" && (x + y) % 3 == 0
        case .edge: ch == "E"
        case .checker: (x + y) % 2 == 0
        }
        return on ? "y" : ch
    }

    /// The glow a skinned weapon wears around its silhouette.
    static func cosGlow(_ code: UInt8) -> CGColor? {
        let t = Int(code) - 1
        return cosColors.indices.contains(t) ? cosColors[t][6] : nil
    }
}

// MARK: - auras and steps

extension RpgArt {
    /// Each set's little shape for aura motes, weapon-skin sparks and footsteps, in role letters.
    private static let motes: [RpgGrid] = [
        [".~.", "~*~", ".~."],                         // classic: soft sparkle
        ["~.", ".^"],                                  // festival: confetti
        [":~", "~-"],                                  // coast: doubloon
        [".^", "#="],                                  // jungle: leaf
        ["#~#", ".~."],                                // mushroom: tiny mushroom
        ["^^^", "^.^", "^^^"],                         // ancient: rune
        [".^.", "^:^", "^:^", ".^."],                  // crystal: shard
        ["~^~", "^&^", "~^~"],                         // factory: gear
        ["..:", ".:.", "^.."],                         // skyisle: feather
        [".:.", ":.:", ".:."],                         // undersea: bubble
        [".^", "^:", "^."],                            // haunted: wisp
        [":", "^"],                                    // underworld: ember
        [":.:", ".^.", ":.:"],                         // frost: snowflake
        ["..:..", "..:..", "::^::", "..:..", "..:.."], // celestial: star
        ["^&", "&^"],                                  // rift: void shard
        ["~.~", "~^~", ".~."],                         // chaos: heart
    ]

    private static var moteCache: [Int: CGImage] = [:]

    /// A set's mote as a small image.
    private static func cosMote(_ code: UInt8) -> CGImage? {
        let t = Int(code) - 1
        guard motes.indices.contains(t), cosColors.indices.contains(t) else { return nil }
        if let hit = moteCache[t] { return hit }
        let g = motes[t], colors = cosColors[t]
        guard let ctx = KartArt.context(width: g.map(\.count).max() ?? 1, height: g.count) else { return nil }
        for (y, row) in g.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let r = cosRoleIndex[ch] else { continue }
                KartArt.fill(ctx, colors[r], CGFloat(x), CGFloat(y), 1, 1)
            }
        }
        let img = ctx.makeImage()
        moteCache[t] = img
        return img
    }

    /// Draws a set's mote centred at (x, y), faded to `alpha` (callers draw at full opacity: a stealthed hero fades as one layer).
    static func cosDrawMote(_ c: CGContext, _ code: UInt8, _ x: Double, _ y: Double, alpha: CGFloat = 1) {
        guard alpha > 0.02, let img = cosMote(code) else { return }
        if alpha < 1 { c.saveGState(); c.setAlpha(alpha) }
        KartArt.draw(img, in: c, rect: CGRect(x: (x - Double(img.width) / 2).rounded(), y: (y - Double(img.height) / 2).rounded(), width: Double(img.width), height: Double(img.height)))
        if alpha < 1 { c.restoreGState() }
    }

    private enum RingStyle { case solid, dotted, dashed, double, spiky, wavy }
    private static let ringStyles: [RingStyle] = [.solid, .dotted, .wavy, .dashed, .dotted, .double, .spiky, .dashed,
                                                  .double, .wavy, .dotted, .spiky, .solid, .double, .dashed, .spiky]
    private static let auraFrames = 8
    private static var ringCache: [Int: CGImage] = [:]

    /// A set's aura ring around the feet (one of `auraFrames` turning frames), drawn centred on the image.
    private static func cosAuraRing(_ code: UInt8, frame: Int) -> CGImage? {
        let t = Int(code) - 1
        guard cosColors.indices.contains(t) else { return nil }
        let f = ((frame % auraFrames) + auraFrames) % auraFrames
        let key = t * auraFrames + f
        if let hit = ringCache[key] { return hit }
        let w = 29, h = 13, cx = 14.0, cy = 6.0, rx = 12.0, ry = 4.6
        guard let ctx = KartArt.context(width: w, height: h) else { return nil }
        let colors = cosColors[t], glow = colors[6], core = colors[7], trim = colors[3]
        let phase = Double(f) / Double(auraFrames) * 2 * .pi
        let steps = 96
        for i in 0..<steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let x = cx + cos(a) * rx, y = cy + sin(a) * ry
            let k = (a + phase).truncatingRemainder(dividingBy: 2 * .pi)
            var color: CGColor? = glow.copy(alpha: 0.75)
            switch ringStyles[t] {
            case .solid: break
            case .dotted: color = i % 4 == 0 ? (i % 8 == 0 ? core : trim) : nil
            case .dashed: color = Int(k / (2 * .pi) * 12) % 2 == 0 ? glow.copy(alpha: 0.8) : nil
            case .double:
                if i % 2 == 0 { KartArt.fill(ctx, trim.copy(alpha: 0.6) ?? trim, CGFloat((cx + cos(a) * (rx - 3)).rounded()), CGFloat((cy + sin(a) * (ry - 1.4)).rounded()), 1, 1) }
            case .spiky:
                if Int(k / (2 * .pi) * 16) % 2 == 0, sin(a) > -0.2 { KartArt.fill(ctx, trim.copy(alpha: 0.85) ?? trim, CGFloat(x.rounded()), CGFloat(y.rounded() - 1), 1, 1) }
            case .wavy:
                // Foam crests riding round the ring.
                if Int(k / (2 * .pi) * 48) % 4 == 0 { KartArt.fill(ctx, core, CGFloat(x.rounded()), CGFloat(y.rounded() - 1), 1, 1) }
            }
            if let color { KartArt.fill(ctx, color, CGFloat(x.rounded()), CGFloat(y.rounded()), 1, 1) }
        }
        // A bright travelling spark on every ring.
        KartArt.fill(ctx, core, CGFloat((cx + cos(phase) * rx).rounded()), CGFloat((cy + sin(phase) * ry).rounded()), 1, 1)
        let img = ctx.makeImage()
        ringCache[key] = img
        return img
    }

    /// An aura behind (`front` false) or in front of the hero: the ground ring and the half of the orbiting motes on that side.
    static func cosDrawAura(_ c: CGContext, _ code: UInt8, ax: Double, ay: Double, time: Double, seed: Double, front: Bool) {
        if !front, let ring = cosAuraRing(code, frame: Int(time * 10 + seed * 7)) {
            KartArt.draw(ring, in: c, rect: CGRect(x: ax - 14, y: ay - 6, width: Double(ring.width), height: Double(ring.height)))
        }
        let n = 4
        for k in 0..<n {
            let a = time * 1.7 + Double(k) * 2 * .pi / Double(n) + seed
            guard (sin(a) >= 0) == front else { continue }
            let rise = (time * 0.5 + Double(k) * 0.29 + seed).truncatingRemainder(dividingBy: 1)
            let x = ax + cos(a) * 11, y = ay - 3 - rise * 16 + sin(a) * 3
            cosDrawMote(c, code, x, y, alpha: CGFloat(0.95 * (1 - rise * rise)))
        }
    }
}

extension RpgArt {
    /// Footsteps: the set's mote left at each step, fading over `stepLife` seconds (light sets drift up as they go).
    static let stepLife = 1.2
    private static let risingSteps: Set<String> = ["undersea", "haunted", "underworld", "celestial"]

    static func cosDrawSteps(_ c: CGContext, _ code: UInt8, _ prints: [(pos: CGPoint, at: Double, side: Int)], time: Double, alpha: CGFloat) {
        let t = Int(code) - 1
        let rises = RpgCosmetics.themes.indices.contains(t) && risingSteps.contains(RpgCosmetics.themes[t].key)
        for p in prints {
            let age = (time - p.at) / stepLife
            guard age >= 0, age < 1 else { continue }
            let x = Double(p.pos.x) + Double(p.side) * 2, y = Double(p.pos.y) + 1 - (rises ? age * 6 : 0)
            cosDrawMote(c, code, x, y, alpha: alpha * CGFloat(1 - age * age))
        }
    }

    /// While walking, a puff of the set's mote kicked up at the trailing foot (shows in menus too, where nobody moves).
    static func cosDrawKick(_ c: CGContext, _ code: UInt8, ax: Double, ay: Double, pose: RpgHeroPose, time: Double) {
        guard pose.moving else { return }
        let phase = (time * 4).truncatingRemainder(dividingBy: 1)
        let back: Double = pose.view == .side ? (pose.flip ? 1 : -1) : 0
        let side: Double = pose.step % 2 == 0 ? -2 : 2
        cosDrawMote(c, code, ax + back * (3 + phase * 3) + (pose.view == .side ? 0 : side), ay - 1 - phase * 3, alpha: CGFloat(1 - phase))
    }
}

// MARK: - wardrobe icons

extension RpgArt {
    private struct IconKey: Hashable {
        let id: String
        let cls: RpgClass
        let look: [Int]
    }

    private static var iconCache: [IconKey: CGImage] = [:]

    /// A cosmetic on the viewer's own hero (class and look), cropped to where the piece is: wardrobe tiles.
    static func cosmeticIcon(_ c: RpgCosmetic, on p: RpgPlayer) -> CGImage? {
        let key = IconKey(id: c.id, cls: p.cls, look: p.look)
        if let hit = iconCache[key] { return hit }
        if iconCache.count > 600 { iconCache.removeAll(keepingCapacity: true) }
        var q = p
        q.worn = [c.slot.rawValue: c.id]
        (q.dead, q.job, q.tier, q.helmet, q.dash, q.hurtFlash, q.attackAt, q.castAt) = (false, 0, 0, nil, nil, 0, -100, -100)
        let w = heroWear(q.worn)
        let icon: CGImage?
        switch c.slot {
        case .weaponSkin:
            icon = q.weaponItem.flatMap { heroWeaponImage($0, cls: q.cls, angle: -0.8, skin: w.weapon) }.flatMap(trimmed)
        case .steps, .aura:
            // Marks or the ring with motes over it, drawn on their own.
            guard let ctx = KartArt.context(width: 29, height: 24) else { return nil }
            if c.slot == .aura {
                if let ring = cosAuraRing(w.aura, frame: 0) { KartArt.draw(ring, in: ctx, rect: CGRect(x: 0, y: 11, width: ring.width, height: ring.height)) }
                for (x, y) in [(6.0, 9.0), (15.0, 4.0), (23.0, 10.0)] { cosDrawMote(ctx, w.aura, x, y) }
            } else {
                // A trail of left and right steps going up the tile, the newest brightest.
                for k in 0..<4 { cosDrawMote(ctx, w.steps, 5 + Double(k) * 6.5, 20 - Double(k) * 5 + Double(k % 2) * 3, alpha: CGFloat(0.45 + 0.18 * Double(k))) }
            }
            icon = ctx.makeImage().flatMap(trimmed)
        default:
            let back = c.slot == .cape || c.slot == .wings
            let pose = RpgHeroPose(action: .idle, view: back ? .back : .front, flip: false, moving: false, step: 0, t: 0, aim: back ? -.pi / 2 : .pi / 2)
            // Picture rectangles in the 48-pixel preview, whose 32-pixel frame starts at (8, 13).
            let crop: CGRect = switch c.slot {
            case .hat: CGRect(x: 12, y: 12, width: 24, height: 21)
            case .hair: CGRect(x: 11, y: 14, width: 26, height: 24)
            case .face: CGRect(x: 16, y: 20, width: 16, height: 13)
            case .outfit: CGRect(x: 14, y: 27, width: 20, height: 18)
            case .cape: CGRect(x: 14, y: 23, width: 20, height: 20)
            default: CGRect(x: 8, y: 19, width: 32, height: 19)
            }
            icon = heroPreview(q, pose: pose, time: 0.35).flatMap { $0.cropping(to: crop) }
        }
        if let icon { iconCache[key] = icon }
        return icon
    }

    /// An image of ours (RGBA, alpha last) cut down to its opaque pixels.
    private static func trimmed(_ img: CGImage) -> CGImage? {
        guard img.bitsPerPixel == 32, let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return img }
        var lo = (x: img.width, y: img.height), hi = (x: -1, y: -1)
        for y in 0..<img.height {
            for x in 0..<img.width where bytes[y * img.bytesPerRow + x * 4 + 3] > 0 {
                lo = (min(lo.x, x), min(lo.y, y)); hi = (max(hi.x, x), max(hi.y, y))
            }
        }
        guard hi.x >= lo.x else { return img }
        return img.cropping(to: CGRect(x: lo.x, y: lo.y, width: hi.x - lo.x + 1, height: hi.y - lo.y + 1))
    }
}

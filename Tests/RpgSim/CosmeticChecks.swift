import Foundation
@testable import PokeTokenBar

/// 외관 아이템: catalog, saves, the 의상실 shop, the gacha and its pity rule, drops.
func cosmeticChecks() {
    let all = RpgCosmetics.all
    check(all.count >= 100, "the catalog has \(all.count) cosmetics (>= 100)")
    check(Set(all.map(\.id)).count == all.count, "cosmetic ids are unique")
    check(all.allSatisfy { $0.id.hasPrefix($0.slot.rawValue + "_") && (0...4).contains($0.rarity) && $0.price > 0 }, "ids carry their slot; rarity 0-4; prices positive")
    check(RpgCosmeticSlot.allCases.allSatisfy { s in all.contains { $0.slot == s } }, "every slot has cosmetics")
    check(RpgCosmetics.themes.count == 16 && Set(RpgCosmetics.themes.map(\.key)).count == 16, "16 themed sets")
    check(RpgRegions.all.allSatisfy { r in RpgCosmetics.theme(r.id) != nil }, "every continent has a matching cosmetic set")

    // Saved data is untrusted.
    let cleaned = RpgCosmetics.clean(wardrobe: ["hat_coast", "bogus", "cape_coast"], worn: ["hat": "hat_coast", "cape": "hat_coast", "outfit": "outfit_coast", "wings": "nope"])
    check(cleaned.0 == ["hat_coast", "cape_coast"] && cleaned.1 == ["hat": "hat_coast"], "unknown ids, wrong-slot and unowned pieces are dropped: \(cleaned)")
    check(RpgCosmetics.clean(wardrobe: Array(repeating: "hat_coast", count: 1000), worn: nil).0.count == 1, "duplicates collapse")

    // The 의상실.
    let town = RpgMap(RpgMaps.def(.town))
    guard let shop = town.buildings.first(where: { $0.place == .wardrobe }) else { check(false, "the town has a 의상실"); return }
    var p = RpgSaveStore.newPlayer(name: "t", cls: .mage, id: 1)
    p.gold = 100_000
    p.pos = shop.door
    let w = RpgWorld(player: p)
    check(w.nearbyPlace(for: 1) == .wardrobe, "standing at the door is the 의상실")
    w.perform(.buyCosmetic("hat_classic"), for: 1)
    let bought = w.player(1)!
    check(bought.wardrobe.contains("hat_classic") && bought.gold == 100_000 - RpgCosmetics.def("hat_classic")!.price, "buying costs the price")
    w.perform(.buyCosmetic("hat_classic"), for: 1)
    check(w.player(1)!.gold == bought.gold, "no second purchase of an owned piece")
    w.perform(.buyCosmetic("aura_crystal"), for: 1)
    check(!w.player(1)!.wardrobe.contains("aura_crystal"), "gacha-only pieces are not for sale")
    w.perform(.wear("hat_classic"), for: 1)
    w.perform(.wear("cape_classic"), for: 1)
    check(w.player(1)!.worn == ["hat": "hat_classic"], "wearing needs ownership: \(w.player(1)!.worn)")
    w.perform(.unwear("hat"), for: 1)
    check(w.player(1)!.worn.isEmpty, "taking off clears the slot")
    // Away from the shop nothing sells.
    var far = RpgSaveStore.newPlayer(name: "far", cls: .mage, id: 1)
    far.gold = 100_000
    let w2 = RpgWorld(player: far)
    w2.perform(.buyCosmetic("hat_classic"), for: 1)
    w2.perform(.gacha(1), for: 1)
    check(w2.player(1)!.wardrobe.isEmpty && w2.player(1)!.gold == 100_000, "the shop and gacha work only at the 의상실")

    // Gacha.
    var counts = [0, 0, 0, 0, 0]
    for roll in 0..<100 { counts[RpgCosmetics.gachaRarity(roll: roll, pityCount: 0)] += 1 }
    check(counts == [55, 30, 12, 3, 0], "gacha odds over 100 rolls: \(counts)")
    check((0..<100).allSatisfy { RpgCosmetics.gachaRarity(roll: $0, pityCount: RpgCosmetics.pity - 1) >= 2 }, "the pity pull is 영웅 or better")
    let before = w.player(1)!.gold
    w.perform(.gacha(10), for: 1)
    let pulled = w.player(1)!
    check(before - pulled.gold == RpgCosmetics.gachaTenCost && pulled.wardrobe.count > bought.wardrobe.count - 1, "ten pulls cost \(RpgCosmetics.gachaTenCost) and add pieces (\(pulled.wardrobe.count))")
    var rich = RpgSaveStore.newPlayer(name: "rich", cls: .mage, id: 1)
    rich.gold = 10_000_000
    rich.pos = shop.door
    let w3 = RpgWorld(player: rich)
    for _ in 0..<30 { w3.perform(.gacha(10), for: 1) }
    let big = w3.player(1)!
    check(big.wardrobe.count > 40 && big.wardrobe.allSatisfy { RpgCosmetics.def($0) != nil } && big.gachaPity <= RpgCosmetics.pity, "300 pulls fill the wardrobe with real pieces (\(big.wardrobe.count)), pity within bounds")
    check(big.gold > 10_000_000 - 30 * RpgCosmetics.gachaTenCost, "duplicates paid gold back")

    // Drops: only continent monsters, bosses far more often.
    if let region = RpgRegions.all.first, let boss = region.monsters.first(where: { $0.behavior == .boss }), let normal = region.monsters.first(where: { $0.behavior != .boss }) {
        let b = RpgCosmetics.dropChance(boss), n = RpgCosmetics.dropChance(normal)
        check(b != nil && n != nil && b!.chance > n!.chance * 100 && b!.theme == region.id, "region bosses drop their set far more often than its monsters")
    }
    check(RpgCosmetics.dropChance(RpgMonsters.def("slime")) == nil, "main-game monsters drop no cosmetics")
    check(RpgCosmetics.newPiece(theme: "coast", owned: [], roll: 7).map { RpgCosmetics.def($0)?.theme == "coast" } == true, "a drop is a piece of its set")
    check(RpgCosmetics.newPiece(theme: "coast", owned: Set(all.filter { $0.theme == "coast" }.map(\.id)), roll: 1) == nil, "a complete set drops nothing")

    // Save and look sync.
    let saved = RpgSaveStore.snapshot(pulled)
    let back = RpgSaveStore.player(from: saved, id: 1)
    check(back.wardrobe == pulled.wardrobe && back.gachaPity == pulled.gachaPity, "the wardrobe survives a save")
    var forged = saved
    forged.wardrobe = ["hat_chaos", "zzz"]
    forged.worn = ["hat": "hat_chaos", "outfit": "hat_chaos"]
    forged.pity = 999
    let fp = RpgSaveStore.player(from: forged, id: 1)
    check(fp.worn == ["hat": "hat_chaos"] && fp.wardrobe == ["hat_chaos"] && fp.gachaPity == RpgCosmetics.pity, "a hand-edited save is cleaned and pity clamped")
    check(RpgSaveStore.player(from: { var o = saved; o.wardrobe = nil; o.worn = nil; o.pity = nil; return o }(), id: 1).wardrobe.isEmpty, "an old save has an empty wardrobe")
}

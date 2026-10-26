import Foundation
@testable import PokeTokenBar

/// Checks every region in `RpgRegions.all`: a region is only done when all of these pass for it.
func regionChecks() {
    let allMapIDs = Set(RpgMaps.all.map(\.id))
    check(allMapIDs.count == RpgMaps.all.count, "map ids are unique across all regions")
    let seeds = RpgMaps.all.map(\.seed)
    check(Set(seeds).count == seeds.count, "map seeds are unique across all regions")
    let monsterIDs = RpgMonsters.all.map(\.id)
    check(Set(monsterIDs).count == monsterIDs.count, "monster ids are unique (\(monsterIDs.count) monsters)")
    let itemIDs = RpgItems.all.map(\.id)
    check(Set(itemIDs).count == itemIDs.count, "item ids are unique (\(itemIDs.count) items)")
    check(Set(RpgRecipes.all.map(\.id)).count == RpgRecipes.all.count, "recipe ids are unique")
    for region in RpgRegions.all {
        let tag = region.id
        let ids = Set(region.maps.map(\.id))
        check(ids.contains(region.entry) && region.maps.count >= 8, "\(tag): entry map exists and the region has \(region.maps.count) maps (>= 8)")
        check(region.maps.filter { RpgMaps.def($0.id).kind == .boss }.count >= 1, "\(tag): has a boss room")
        check(region.maps.allSatisfy { $0.portals.allSatisfy { allMapIDs.contains($0.to) } }, "\(tag): every portal leads to a real map")
        // Inside the region everything is reachable from the entry, and the entry leads back to the town.
        var seen: Set<RpgMapID> = [region.entry], frontier = [region.entry]
        while let id = frontier.popLast() {
            for p in RpgMaps.def(id).portals where !p.waypoint && ids.contains(p.to) && seen.insert(p.to).inserted { frontier.append(p.to) }
        }
        check(seen == ids, "\(tag): every map is reachable from the entry (\(seen.count)/\(ids.count))")
        check(RpgMaps.def(region.entry).portals.contains { $0.to == .town }, "\(tag): the entry map has a door back to the town")
        let walkable = region.maps.allSatisfy { def in
            let m = RpgMap(def)
            return def.portals.allSatisfy { m.canStand(RpgMap.center($0.at)) } && m.canStand(RpgMap.center(region.entryTile)) || def.id != region.entry
        }
        check(walkable, "\(tag): portal and entry tiles are walkable")
        for def in region.maps {
            let m = RpgMap(def)
            for p in def.portals where !p.waypoint {
                if !RpgMap(RpgMaps.def(p.to)).canStand(RpgMap.center(p.arrive)) { check(false, "\(tag): \(def.id.rawValue) → \(p.to.rawValue) arrival tile is blocked") }
            }
            if def.kind != .boss, def.kind != .town { check(m.spawnTiles.count >= 40, "\(tag): \(def.id.rawValue) has room for monsters (\(m.spawnTiles.count) spawn tiles)") }
            check(def.monsters.allSatisfy { sp in RpgMonsters.all.contains(where: { $0.id == sp.monster }) }, "\(tag): \(def.id.rawValue) spawns only real monsters")
        }
        check(region.monsters.count >= 8, "\(tag): has \(region.monsters.count) monsters of its own (>= 8)")
        check(region.monsters.allSatisfy { RpgDropsValid.ok($0) }, "\(tag): every monster drop is a real item")
        check(region.monsters.allSatisfy { m in MainActor.assumeIsolated { RpgArt.sprite(m.sprite) != nil } }, "\(tag): every monster has a sprite")
        check(region.items.allSatisfy { i in MainActor.assumeIsolated { RpgArt.icon(i) != nil } }, "\(tag): every item has an icon")
        check(region.items.count >= 6, "\(tag): has \(region.items.count) items of its own (>= 6)")
        check(region.recipes.allSatisfy { r in RpgItems.item(r.output) != nil && r.materials.keys.allSatisfy { RpgItems.item($0) != nil } }, "\(tag): recipes use real items")
        // Spawned monsters sit in the region's level band, and bosses in the room that matches.
        let lo = region.maps.compactMap { RpgMaps.def($0.id).levelText.split { !$0.isNumber }.compactMap { Int($0) }.first }.min() ?? 1
        check(lo >= 1 && region.minLevel <= lo + 3, "\(tag): minLevel \(region.minLevel) fits the lowest map level \(lo)")
    }
}

enum RpgDropsValid {
    static func ok(_ m: RpgMonsterDef) -> Bool { m.drops.allSatisfy { RpgItems.item($0.item) != nil } }
}

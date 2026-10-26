import XCTest
@testable import PokeTokenBar

final class RpgMapTests: XCTestCase {
    func testEveryMapIDHasADefinition() {
        for id in RpgMapID.allCases { XCTAssertEqual(RpgMaps.all.filter { $0.id == id }.count, 1, "\(id)") }
        XCTAssertEqual(Set(RpgMaps.all.map(\.seed)).count, RpgMaps.all.count, "seeds must be unique")
    }

    func testPortalsAreValid() {
        for map in RpgMaps.all {
            for p in map.portals {
                XCTAssertTrue(RpgMaps.all.contains { $0.id == p.to }, "\(map.id) -> \(p.to)")
                XCTAssertTrue((0..<map.width).contains(p.at.x) && (0..<map.height).contains(p.at.y), "\(map.id) portal out of bounds")
                let dest = RpgMaps.def(p.to)
                XCTAssertTrue((0..<dest.width).contains(p.arrive.x) && (0..<dest.height).contains(p.arrive.y), "\(map.id) arrival out of bounds")
            }
        }
    }

    func testEveryMapIsReachableFromTown() {
        var seen: Set<RpgMapID> = [.town]
        var queue: [RpgMapID] = [.town]
        while let id = queue.popLast() {
            for p in RpgMaps.def(id).portals where !p.waypoint && seen.insert(p.to).inserted { queue.append(p.to) }
        }
        XCTAssertEqual(seen, Set(RpgMapID.allCases))
    }

    func testSpawnMonstersExist() {
        let ids = Set(RpgMonsters.all.map(\.id))
        for map in RpgMaps.all { for s in map.monsters { XCTAssertTrue(ids.contains(s.monster), "\(map.id): \(s.monster)") } }
        for m in RpgMonsters.all { XCTAssertNotNil(RpgArt.specs[m.sprite], "sprite \(m.sprite)") }
    }

    func testLevelBandsAreContinuous() {
        let levels = RpgMaps.all.flatMap(\.monsters).map { RpgMonsters.def($0.monster).level }
        for lv in 1...50 {
            XCTAssertTrue(levels.contains { abs($0 - lv) <= 3 }, "no hunting ground near Lv\(lv)")
        }
    }
}

import XCTest
@testable import PokeTokenBar

final class RpgBossRespawnTests: XCTestCase {
    // Bosses used to stay down for 90 seconds; they now come back as fast as ordinary monsters.
    func testBossesRespawnLikeOrdinaryMonsters() {
        XCTAssertEqual(RpgWorld.respawnDelay(for: .boss), RpgWorld.respawnDelay)
        XCTAssertEqual(RpgWorld.respawnDelay(for: .aggressive), RpgWorld.respawnDelay)
        XCTAssertEqual(RpgWorld.respawnDelay(for: .coward), 30, "the golden slime keeps its long wait")
    }
}

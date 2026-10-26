import XCTest
@testable import PokeTokenBar

final class RpgJobTests: XCTestCase {
    private func world(level: Int, cls: RpgClass = .warrior) -> RpgWorld {
        var p = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
        p.level = level
        return RpgWorld(player: p)
    }

    func testJobSurvivesSaveRoundTrip() {
        var p = RpgSaveStore.newPlayer(name: "t", cls: .mage, id: 1)
        p.level = 25
        p.job = 2
        let back = RpgSaveStore.player(from: RpgSaveStore.snapshot(p), id: 1)
        XCTAssertEqual(back.job, 2)
    }

    func testAdvanceNeedsLevel20AndPicksOneJob() {
        let early = world(level: RpgJobs.advanceLevel - 1)
        early.perform(.advance(1), for: 1)
        XCTAssertEqual(early.player(1)?.job, 0)

        let ready = world(level: RpgJobs.advanceLevel)
        ready.perform(.advance(1), for: 1)
        XCTAssertEqual(ready.player(1)?.job, 1)
        XCTAssertNotNil(ready.player(1)?.skills["j_bash"])
        ready.perform(.advance(2), for: 1)
        XCTAssertEqual(ready.player(1)?.job, 1, "a job cannot be changed once chosen")
    }

    func testEveryJobSkillExistsAndBelongsToItsClass() {
        for job in RpgJobs.all {
            XCTAssertEqual(job.skills.count, 2)
            for id in job.skills { XCTAssertEqual(RpgSkills.def(id)?.cls, job.cls, id) }
        }
    }

    func testPetInfoIsClampedFromTheNetwork() {
        let wild = RpgPetInfo(speciesID: -5, shiny: false, name: String(repeating: "가", count: 40), power: 99_999, element: .base).sanitized
        XCTAssertEqual(wild.speciesID, 1)
        XCTAssertEqual(wild.name.count, 12)
        XCTAssertEqual(wild.power, 400)
    }
}

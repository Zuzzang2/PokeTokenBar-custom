import XCTest
@testable import PokeTokenBar

// SPIKE: trainer design choice in the plaza.
@MainActor
final class PlazaTrainerSpikeTests: XCTestCase {
    private func profile(_ design: String?) -> PlazaProfile {
        PlazaProfile(id: "abc", trainer: "t", speciesID: 1, shiny: false, leadName: "x", trainerDesign: design)
    }

    func testChosenDesignIsUsed() {
        XCTAssertEqual(BattleArt.design(for: profile("t2")), "t2")
        XCTAssertEqual(BattleArt.design(for: profile("t1")), "t1")
    }

    func testMissingOrUnknownDesignFallsBackToAnAvailableOne() {
        XCTAssertTrue(BattleArt.trainerDesigns.contains(BattleArt.design(for: profile(nil))))
        XCTAssertTrue(BattleArt.trainerDesigns.contains(BattleArt.design(for: profile("nope"))))
    }

    /// Peers on the previous build send presence without `trainerDesign`; it must still decode.
    func testPresenceFromOlderBuildDecodes() throws {
        let old = #"{"id":"abc","trainer":"t","speciesID":1,"shiny":false,"leadName":"x"}"#
        let decoded = try JSONDecoder().decode(PlazaProfile.self, from: Data(old.utf8))
        XCTAssertNil(decoded.trainerDesign)
    }
}

// SPIKE: custom nickname rules.
final class PlazaNicknameSpikeTests: XCTestCase {
    func testNicknameIsTrimmedAndUsed() {
        XCTAssertEqual(BattleMonBuilder.trainerName(nickname: "  지우  ", fallback: "김한결"), "지우")
    }

    func testBlankNicknameFallsBack() {
        XCTAssertEqual(BattleMonBuilder.trainerName(nickname: "   ", fallback: "김한결"), "김한결")
        XCTAssertEqual(BattleMonBuilder.trainerName(nickname: "", fallback: ""), "트레이너")
    }

    /// MCPeerID traps on display names over 63 UTF-8 bytes; Korean is 3 bytes per syllable.
    func testLongNamesAreCutToTwelveCharactersAndFitPeerIDLimit() {
        let name = BattleMonBuilder.trainerName(nickname: String(repeating: "가", count: 30), fallback: "x")
        XCTAssertEqual(name.count, 12)
        XCTAssertLessThanOrEqual(name.utf8.count, 63)
        let fallback = BattleMonBuilder.trainerName(nickname: "", fallback: String(repeating: "나", count: 40))
        XCTAssertLessThanOrEqual(fallback.utf8.count, 63)
    }
}

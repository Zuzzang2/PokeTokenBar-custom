import XCTest
@testable import PokeTokenBar

// MARK: 보관함 (알 구매 시 내보낸 개체 보존 + 꺼내서 맞바꾸기)

private struct BoxNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class BoxTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func mon(_ id: Int, used: Int) -> String {
        "{\"baseID\":\(id),\"pathIDs\":[\(id)],\"stageIndex\":0,\"usedAtStage\":\(used),"
            + "\"rarity\":\"common\",\"totalForms\":3}"
    }

    private func store(active: String?, box: [String]? = nil) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("box-\(UUID().uuidString).json")
        var json = "{\"installBaselineSet\":true,\"usedSinceInstall\":5000000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"active\":\(active ?? "null"),\"dex\":[]"
        if let box { json += ",\"box\":[\(box.joined(separator: ","))]" }
        json += "}"
        try? json.data(using: .utf8)!.write(to: url)
        return CompanionStore(provider: BoxNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 7))
    }

    func testLegacySaveWithoutBoxDecodesEmptyBox() {
        let s = store(active: mon(10, used: 1))
        XCTAssertTrue(s.state.box.isEmpty)
        XCTAssertTrue(s.hasActive)
    }

    func testBuyEggMovesActiveToBoxWithGrowth() {
        let s = store(active: mon(10, used: 200_000_000))
        XCTAssertTrue(s.buyFreshEgg())
        XCTAssertTrue(s.isEgg)
        XCTAssertEqual(s.state.box.count, 1)
        XCTAssertEqual(s.state.box.first?.baseID, 10)
        XCTAssertEqual(s.state.box.first?.usedAtStage, 200_000_000, "성장 진행도 보존")
        XCTAssertTrue(s.state.dex.last?.isReleased ?? false, "도감 기록은 기존처럼 남는다")
    }

    func testCannotTakeOutWhileEgg() {
        let s = store(active: nil, box: [mon(20, used: 1)])
        XCTAssertFalse(s.canTakeFromBox, "알 상태에서 꺼내면 산 알이 사라진다")
        XCTAssertFalse(s.takeFromBox(at: 0))
        XCTAssertEqual(s.state.box.count, 1)
    }

    func testTakeOutSwapsWithActive() {
        let s = store(active: mon(10, used: 111), box: [mon(20, used: 222)])
        XCTAssertTrue(s.takeFromBox(at: 0))
        XCTAssertEqual(s.state.active?.baseID, 20)
        XCTAssertEqual(s.state.active?.usedAtStage, 222, "꺼낸 개체는 성장 이어서")
        XCTAssertEqual(s.state.box.map(\.baseID), [10], "현재 개체는 보관함으로")
        XCTAssertEqual(s.state.box.first?.usedAtStage, 111)
    }

    func testTakeOutRejectsBadIndex() {
        let s = store(active: mon(10, used: 1), box: [mon(20, used: 1)])
        XCTAssertFalse(s.takeFromBox(at: 5))
        XCTAssertEqual(s.state.active?.baseID, 10)
    }

    func testBoxPersistsAcrossReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("box-\(UUID().uuidString).json")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":5000000000,\"lastDate\":\"d\",\"active\":\(mon(10, used: 7))}"
        try json.data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: BoxNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 7))
        XCTAssertTrue(s.buyFreshEgg())
        let reloaded = CompanionStore(provider: BoxNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 7))
        XCTAssertEqual(reloaded.state.box.map(\.baseID), [10])
    }
}

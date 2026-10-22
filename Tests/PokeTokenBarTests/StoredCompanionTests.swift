import XCTest
@testable import PokeTokenBar

// MARK: 보관함 — 알을 사도 놓아주지 않고 보관, 컬렉션에서 다시 내 포켓몬으로

private struct StorageNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

@MainActor
final class StoredCompanionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// 2단계째(stageIndex 1) 진행 중인 이로치 활성 + 졸업분 1개(`grad`) + 추가 기록.
    private static let activeJSON = "{\"baseID\":10,\"pathIDs\":[10,11],\"plannedPathIDs\":[10,11,12],"
        + "\"stageIndex\":1,\"usedAtStage\":123456789,\"rarity\":\"common\",\"totalForms\":3,"
        + "\"isShiny\":true,\"nature\":\"bold\"}"
    private static let graduatedJSON = "{\"id\":\"grad\",\"baseID\":1,\"finalID\":3,\"chainOrder\":[1,2,3],\"rarity\":\"common\"}"
    /// 보관 상태를 함께 가진 보관 기록.
    private static let storedJSON = "{\"id\":\"box1\",\"baseID\":20,\"finalID\":21,\"chainOrder\":[20,21],"
        + "\"rarity\":\"rare\",\"caughtAt\":700000000,\"releasedAt\":700000000,"
        + "\"storedMon\":{\"baseID\":20,\"pathIDs\":[20,21],\"plannedPathIDs\":[20,21,22],\"stageIndex\":1,"
        + "\"usedAtStage\":777,\"rarity\":\"rare\",\"totalForms\":3,\"nature\":\"calm\"}}"
    /// 이 기능 이전에 놓아준 기록 — 보관 상태가 없다.
    private static let legacyReleasedJSON = "{\"id\":\"old\",\"baseID\":30,\"finalID\":31,\"chainOrder\":[30,31],"
        + "\"rarity\":\"uncommon\",\"caughtAt\":700000000,\"releasedAt\":700000000,\"isShiny\":true,\"nature\":\"timid\"}"

    private func fileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("stored-\(UUID().uuidString).json")
    }

    private func write(active: Bool = true, extraDex: [String] = [], to url: URL) {
        let dex = ([Self.graduatedJSON] + extraDex).joined(separator: ",")
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":10000000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"active\":\(active ? Self.activeJSON : "null"),\"dex\":[\(dex)],"
            + "\"collectedFinals\":[\"1:3\"]}"
        try? json.data(using: .utf8)!.write(to: url)
    }

    private func open(_ url: URL, defaults: UserDefaults? = nil) -> CompanionStore {
        CompanionStore(provider: StorageNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 3),
                       defaults: defaults ?? UserDefaults(suiteName: "stored-\(UUID().uuidString)")!)
    }

    private func store(active: Bool = true, extraDex: [String] = []) -> CompanionStore {
        let url = fileURL()
        write(active: active, extraDex: extraDex, to: url)
        return open(url)
    }

    /// [핵심] 알 구매는 놓아주기가 아니라 보관이다 — 진화 단계·단계 진행·진화 계획·개체 속성이 그대로 남는다.
    func testBuyingAnEggStoresTheFullGrowthState() throws {
        let s = store()
        XCTAssertTrue(s.buyFreshEgg())
        XCTAssertNil(s.state.active)
        let entry = try XCTUnwrap(s.state.dex.last)
        XCTAssertTrue(s.isStored(entry), "졸업분이 아니라 보관 기록")
        XCTAssertEqual(entry.chainOrder, [10, 11], "도감 칸은 도달한 형태만")
        let mon = try XCTUnwrap(entry.storedMon, "보관 상태가 함께 저장된다")
        XCTAssertEqual(mon.pathIDs, [10, 11])
        XCTAssertEqual(mon.plannedPathIDs, [10, 11, 12], "분기 계획까지 보존")
        XCTAssertEqual(mon.stageIndex, 1)
        XCTAssertEqual(mon.usedAtStage, 123_456_789, "단계 진행이 사라지지 않는다")
        XCTAssertTrue(mon.isShiny)
        XCTAssertEqual(mon.nature, .bold)
    }

    /// [핵심] 보관한 개체를 고르면 지금 포켓몬과 자리를 바꾼다. 기록 수·도감 종·지갑·확률 가중은 그대로.
    func testRaisingStoredSwapsWithTheCurrentPokemon() throws {
        let s = store(extraDex: [Self.storedJSON])
        let entriesBefore = s.dexEntries.count
        let speciesBefore = Set(s.dexSpecies.map(\.id))
        XCTAssertTrue(s.canRaiseStored)

        XCTAssertTrue(s.raiseStored("box1"))

        let active = try XCTUnwrap(s.state.active)
        XCTAssertEqual(active.baseID, 20)
        XCTAssertEqual(active.pathIDs, [20, 21])
        XCTAssertEqual(active.plannedPathIDs, [20, 21, 22])
        XCTAssertEqual(active.stageIndex, 1)
        XCTAssertEqual(active.usedAtStage, 777, "보관된 진행에서 이어 키운다")
        XCTAssertEqual(active.nature, .calm)
        XCTAssertFalse(s.state.dex.contains { $0.id == "box1" }, "데려온 기록은 보관함에서 빠진다")

        let outgoing = try XCTUnwrap(s.state.dex.first { $0.storedMon?.baseID == 10 })
        XCTAssertTrue(s.isStored(outgoing), "원래 포켓몬은 보관함으로")
        XCTAssertEqual(outgoing.storedMon?.usedAtStage, 123_456_789)
        XCTAssertEqual(outgoing.caughtAt, now)

        XCTAssertEqual(s.dexEntries.count, entriesBefore, "교체일 뿐 — 기록 수는 그대로")
        XCTAssertEqual(Set(s.dexSpecies.map(\.id)), speciesBefore, "도감 종 구성 불변")
        XCTAssertEqual(s.state.spentTokens, 0, "교체는 무료")
        XCTAssertEqual(s.state.collectedFinals, ["1:3"], "보관은 졸업이 아니다")
    }

    /// 다시 바꾸면 원래 개체가 같은 상태로 돌아온다 — 교체를 반복해도 진행이 새지 않는다.
    func testSwappingBackRestoresTheOriginal() throws {
        let s = store(extraDex: [Self.storedJSON])
        XCTAssertTrue(s.raiseStored("box1"))
        let outgoingID = try XCTUnwrap(s.state.dex.first { $0.storedMon?.baseID == 10 }?.id)
        XCTAssertTrue(s.raiseStored(outgoingID))
        let active = try XCTUnwrap(s.state.active)
        XCTAssertEqual(active.baseID, 10)
        XCTAssertEqual(active.stageIndex, 1)
        XCTAssertEqual(active.usedAtStage, 123_456_789)
        XCTAssertEqual(s.state.dex.first { $0.storedMon?.baseID == 20 }?.storedMon?.usedAtStage, 777)
    }

    /// 알을 품는 동안엔 교체할 수 없다 — 알과 활성은 공존하지 않아 교체하면 산 알이 사라진다.
    func testCannotRaiseWhileIncubatingAnEgg() {
        let s = store(active: false, extraDex: [Self.storedJSON])
        XCTAssertFalse(s.canRaiseStored)
        XCTAssertFalse(s.raiseStored("box1"))
        XCTAssertNil(s.state.active, "no-op")
        XCTAssertTrue(s.state.dex.contains { $0.id == "box1" }, "보관 기록 유지")
    }

    /// 졸업분은 다시 키울 수 없다 — 최종체를 끝낸 기록이라 곧바로 재졸업해 같은 개체가 둘 생긴다.
    func testGraduatedEntryCannotBeRaised() throws {
        let s = store()
        let graduated = try XCTUnwrap(s.state.dex.first { $0.id == "grad" })
        XCTAssertFalse(s.isStored(graduated))
        XCTAssertFalse(s.raiseStored("grad"))
        XCTAssertEqual(s.state.active?.baseID, 10, "활성 유지")
    }

    /// 지금 키우는 개체의 합성 항목은 보관 기록이 아니다(버튼이 뜨지 않는다).
    func testActiveEntryIsNotStored() throws {
        let s = store()
        let activeEntry = try XCTUnwrap(s.dexEntriesSorted.first)
        XCTAssertTrue(s.isActiveDexEntry(activeEntry))
        XCTAssertFalse(s.isStored(activeEntry))
    }

    /// 이 기능 이전에 놓아준 기록도 데려올 수 있다 — 보관 상태가 없어 도달한 형태에서 단계 진행 0으로.
    func testLegacyReleasedEntryReturnsAtItsReachedStage() throws {
        let s = store(extraDex: [Self.legacyReleasedJSON])
        XCTAssertTrue(s.raiseStored("old"))
        let active = try XCTUnwrap(s.state.active)
        XCTAssertEqual(active.baseID, 30)
        XCTAssertEqual(active.pathIDs, [30, 31])
        XCTAssertEqual(active.stageIndex, 1, "도달한 형태 그대로")
        XCTAssertEqual(active.usedAtStage, 0, "단계 진행은 기록되지 않았다")
        XCTAssertEqual(active.rarity, .uncommon)
        XCTAssertTrue(active.isShiny)
        XCTAssertEqual(active.nature, .timid)
        XCTAssertNotNil(active.profile, "기록의 프로필(레벨·개체값)을 이어받는다")
    }

    /// 손상된 보관 상태 하나가 개체 기록을 날리지 않는다 — 구버전 기록처럼 도달한 형태로 되살린다.
    func testCorruptStoredStateKeepsTheEntry() throws {
        let corrupt = "{\"id\":\"bad\",\"baseID\":40,\"finalID\":41,\"chainOrder\":[40,41],\"rarity\":\"common\","
            + "\"releasedAt\":700000000,\"storedMon\":{\"baseID\":40,\"pathIDs\":[],\"stageIndex\":0,"
            + "\"usedAtStage\":5,\"rarity\":\"common\",\"totalForms\":2}}"
        let s = store(extraDex: [corrupt])
        let entry = try XCTUnwrap(s.state.dex.first { $0.id == "bad" }, "기록은 남는다")
        XCTAssertNil(entry.storedMon)
        XCTAssertTrue(s.raiseStored("bad"))
        XCTAssertEqual(s.state.active?.pathIDs, [40, 41])
    }

    /// 보관 상태는 디스크에 남아 재시작 뒤에도 그대로 데려올 수 있다.
    func testStoredStateSurvivesRelaunch() throws {
        let url = fileURL()
        write(to: url)
        XCTAssertTrue(open(url).buyFreshEgg())

        let relaunched = open(url)
        let entry = try XCTUnwrap(relaunched.state.dex.first { $0.storedMon?.baseID == 10 })
        XCTAssertEqual(entry.storedMon?.usedAtStage, 123_456_789)
        XCTAssertEqual(entry.storedMon?.plannedPathIDs, [10, 11, 12])
    }

    /// 보관 상태도 활성과 같은 신뢰경계 정규화를 거친다 — 다시 데려오는 순간 활성이 되기 때문.
    func testSanitizeNormalizesStoredState() {
        var mon = MonState(baseID: 1, pathIDs: [1, 2, 2], stageIndex: 1, usedAtStage: -5,
                           rarity: .common, totalForms: 99)
        mon.stageIndex = 9
        var state = CompanionState()
        state.dex = [DexEntry(id: "x", baseID: 1, finalID: 2, chainOrder: [1, 2], rarity: .common,
                              caughtAt: nil, releasedAt: now, storedMon: mon)]
        let stored = SaveTransfer.sanitized(state).dex[0].storedMon
        XCTAssertEqual(stored?.usedAtStage, 0)
        XCTAssertEqual(stored?.totalForms, 12)
        XCTAssertEqual(stored?.pathIDs, [1, 2])
        XCTAssertEqual(stored?.stageIndex, 1)
    }

    /// 난이도를 바꿔도 보관한 개체의 단계 진행률은 유지된다(활성과 같은 환산).
    func testGrowthDifficultyRescalesStoredProgress() throws {
        let s = store()
        XCTAssertTrue(s.buyFreshEgg())
        s.setGrowthDifficulty(2.0)
        let stored = try XCTUnwrap(s.state.dex.last?.storedMon)
        // common·3형태·stageIndex 1 의 기본 임계 250M → 2배 난이도에서 500M. 49.4% 진행은 그대로.
        XCTAssertEqual(Double(stored.usedAtStage), 246_913_578, accuracy: 1)
    }
}

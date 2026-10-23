import XCTest
@testable import PokeTokenBar

final class SelfUpdaterTests: XCTestCase {
    private let remote = "b5dfb12060ebcc0882fba4e9d2bad8adea2bf5ff"

    func testSameCommitIsUpToDate() {
        XCTAssertTrue(SelfUpdater.isUpToDate(build: "b5dfb12", remote: remote))
    }

    func testOlderCommitIsNotUpToDate() {
        XCTAssertFalse(SelfUpdater.isUpToDate(build: "25c7fee", remote: remote))
    }

    /// A build with uncommitted changes differs from main even when the commit matches.
    func testLocalChangesAreNeverUpToDate() {
        XCTAssertFalse(SelfUpdater.isUpToDate(build: "b5dfb12+local", remote: remote))
    }

    func testUnknownBuildAlwaysUpdates() {
        XCTAssertFalse(SelfUpdater.isUpToDate(build: "unknown", remote: remote))
        XCTAssertFalse(SelfUpdater.isUpToDate(build: "b5d", remote: remote))
    }
}

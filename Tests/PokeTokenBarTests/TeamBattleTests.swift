import XCTest
@testable import PokeTokenBar

// SPIKE: 2:2 team battle — pure engine rules and four-peer sync under shuffled message delivery.
@MainActor
final class TeamBattleTests: XCTestCase {
    private func mon(_ trainer: String, hp: Int = 100, atk: Int = 100, spe: Int = 50, power: Int = 60) -> BattleMon {
        BattleMon(trainer: trainer, name: "\(trainer)몬", speciesID: 1, isShiny: false, types: ["normal"],
                  stats: ["hp": hp, "attack": atk, "defense": 80, "special-attack": atk, "special-defense": 80, "speed": spe],
                  moves: [BattleMove(name: "tackle", type: "normal", power: power, accuracy: nil, isPhysical: true, priority: 0)])
    }

    func testFasterAttackerKnocksOutBeforeTheSlowOneActs() {
        let teams = [[mon("A", atk: 200, spe: 200, power: 200)], [mon("B")], [mon("C", hp: 1, spe: 5)], [mon("D")]]
        let state = TeamBattleEngine.resolve(
            TeamBattleEngine.initialState(teams), teams: teams,
            actions: [.move(0, target: 2), .move(0, target: 3), .move(0, target: 0), .move(0, target: 1)], seed: 5)
        XCTAssertEqual(state.hp[2][0], 0)
        XCTAssertFalse(state.log.contains { $0.contains("C몬의 tackle") })
    }

    func testAttackOnDownedFoeRetargetsToTheLivingOne() {
        let teams = [[mon("A", atk: 200, spe: 200, power: 200)], [mon("B", atk: 1, spe: 100, power: 1)],
                     [mon("C", hp: 1)], [mon("D", hp: 500)]]
        var state = TeamBattleEngine.initialState(teams)
        state.hp[2][0] = 0
        state.hp[2] = [0]
        let next = TeamBattleEngine.resolve(
            state, teams: teams, actions: [.move(0, target: 2), .move(0, target: 2), nil, .move(0, target: 0)], seed: 9)
        XCTAssertLessThan(next.hp[3][0], 500, "target C is out, so D takes the hit")
    }

    func testTeamLosesOnlyWhenBothTrainersAreOut() {
        let teams = [[mon("A")], [mon("B")], [mon("C")], [mon("D")]]
        var state = TeamBattleEngine.initialState(teams)
        state.hp[2] = [0]
        XCTAssertNil(TeamBattleEngine.winningTeam(state))
        state.hp[3] = [0]
        XCTAssertEqual(TeamBattleEngine.winningTeam(state), 0)
    }

    func testFourPeersStayInSyncWhenMessagesArriveOutOfOrder() {
        for game in 0..<20 {
            let teams = (0..<4).map { t in
                (0..<(1 + (game + t) % 3)).map { mon("T\(t)", hp: 80 + (game + $0) % 40, atk: 60 + (game * 7 + t) % 50,
                                                      spe: 40 + (game * 5 + t * 19 + $0) % 90) }
            }
            var matches: [TeamBattleMatch] = []
            var queue: [(to: Int, from: Int, msg: TeamBattleMessage)] = []
            for i in 0..<4 {
                matches.append(TeamBattleMatch(me: teams[i], roster: ["a", "b", "c", "d"], myIndex: i) { msg, to in
                    queue.append((to, i, msg))
                })
            }
            func pump() {
                while !queue.isEmpty {
                    let item = queue.remove(at: Int.random(in: 0..<queue.count))
                    matches[item.to].receive(item.msg, from: item.from)
                }
            }
            pump()
            for _ in 0..<500 where !matches.allSatisfy(\.isOver) {
                for (i, m) in matches.enumerated() {
                    guard let state = m.state, !m.isOver else { continue }
                    if m.mustReplace {
                        if let slot = (0..<teams[i].count).first(where: { state.hp[i][$0] > 0 }) { m.replace(with: slot) }
                    } else if !m.iAmOut, !m.hasActed, !state.awaitingReplacement {
                        m.act(.move(0, target: TeamBattleState.foes(of: i)[Int.random(in: 0..<2)]))
                    }
                    if Bool.random() { pump() }
                }
                pump()
            }
            XCTAssertTrue(matches.allSatisfy { $0.phase == .finished }, "game \(game) finished")
            XCTAssertTrue(matches.dropFirst().allSatisfy { $0.state == matches[0].state }, "game \(game) in sync")
        }
    }
}

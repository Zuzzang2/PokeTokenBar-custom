import Foundation
@testable import PokeTokenBar

func storyChecks() {
    let steps = RpgStory.steps
    check(steps.count >= 30, "the story has \(steps.count) chapters")
    check(steps.allSatisfy { step in
        switch step.goal {
        case .kill(let id, _): return RpgMonsters.all.contains { $0.id == id }
        case .visit(let m): return RpgMaps.all.contains { $0.id == m }
        default: return true
        }
    }, "every story goal names a real monster or map")
    check(zip(steps, steps.dropFirst()).allSatisfy { $0.level <= $1.level }, "story rewards rise along the chain")
    check(steps.allSatisfy { s in RpgStory.prizeItem(s, .warrior).map { RpgItems.item($0) != nil } ?? true }, "story prizes are real items")

    var p = RpgSaveStore.newPlayer(name: "t", cls: .mage, id: 1)
    p.gold = 0
    let w = RpgWorld(player: p)
    w.perform(.claimStory, for: 1)
    check(w.player(1)!.story == 0, "chapter 1 cannot be claimed before its goal")
    p.kills["slime"] = 10
    let w2 = RpgWorld(player: p)
    w2.perform(.claimStory, for: 1)
    let after = w2.player(1)!
    check(after.story == 1 && after.gold >= steps[0].gold, "claiming pays the reward and advances (story \(after.story), gold \(after.gold))")
    w2.perform(.claimStory, for: 1)
    check(w2.player(1)!.story == 1, "chapter 2 needs its own goal")
    let saved = RpgSaveStore.snapshot(after)
    check(RpgSaveStore.player(from: saved, id: 1).story == 1, "story progress survives a save")
    var forged = saved
    forged.story = 9999
    check(RpgSaveStore.player(from: forged, id: 1).story == steps.count, "a forged story index is clamped")
}

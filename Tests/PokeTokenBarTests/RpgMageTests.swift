import XCTest
@testable import PokeTokenBar

// Mage balance: MP only came back after 5 quiet seconds, so a mage paid for every spell in potions and had
// no gold left for skill books; and it took over twice the damage of a warrior on half the HP.
final class RpgMageTests: XCTestCase {
    /// A mage standing at the field's entrance with an empty MP bar and no out-of-combat regen.
    private func fieldMage() -> RpgWorld {
        let w = RpgWorld(player: RpgSaveStore.newPlayer(name: "t", cls: .warrior, id: 1))
        var p = RpgSaveStore.newPlayer(name: "mage", cls: .mage, id: 2)
        p.level = 5
        p.map = .field
        p.pos = RpgMap.center(RpgMaps.def(.field).portals.first!.arrive)
        p.mp = 0
        p.lastHurt = .greatestFiniteMagnitude
        w.addPlayer(p)
        return w
    }

    /// Walks to the nearest monster and attacks it for `seconds` (positions reported like a remote player).
    private func fight(_ w: RpgWorld, seconds: Double) {
        var t = 0.0
        while t < seconds {
            guard let me = w.player(2) else { return }
            var input = RpgInput()
            if let target = (w.mobs[me.map] ?? []).filter({ !$0.dead })
                .min(by: { hypot($0.pos.x - me.pos.x, $0.pos.y - me.pos.y) < hypot($1.pos.x - me.pos.x, $1.pos.y - me.pos.y) }) {
                let dx = target.pos.x - me.pos.x, dy = target.pos.y - me.pos.y, d = max(1, hypot(dx, dy))
                let go = d > 80 ? 80 : max(0, d - 30)
                input.pos = CGPoint(x: me.pos.x + dx / d * go, y: me.pos.y + dy / d * go)
                input.facing = CGVector(dx: dx / d, dy: dy / d)
                input.attack = true
            }
            w.step(1.0 / 30, inputs: [2: input])
            t += 1.0 / 30
        }
    }

    func testMageOrbHitsRestoreMana() {
        let w = fieldMage()
        fight(w, seconds: 4)
        XCTAssertGreaterThan(w.player(2)?.mp ?? 0, 0, "basic orb hits feed the MP bar even mid-fight")
    }

    /// Clerics and summoners also fire orbs; only the mage's feed MP.
    func testOtherClassesDoNotGainManaFromBasicAttacks() {
        for cls in RpgClass.allCases where cls != .mage {
            let w = RpgWorld(player: RpgSaveStore.newPlayer(name: "t", cls: .warrior, id: 1))
            var p = RpgSaveStore.newPlayer(name: "other", cls: cls, id: 2)
            p.level = 5
            p.map = .field
            p.pos = RpgMap.center(RpgMaps.def(.field).portals.first!.arrive)
            p.mp = 0
            p.lastHurt = .greatestFiniteMagnitude
            w.addPlayer(p)
            fight(w, seconds: 4)
            XCTAssertEqual(w.player(2)?.mp ?? -1, 0, accuracy: 0.001, cls.rawValue)
        }
    }

    /// Hits of `attack` a fresh character of `cls` at `level` takes to fall (the `hurtPlayer` formula, no gear).
    private func hitsToFall(_ cls: RpgClass, level: Int, attack: Double) -> Double {
        var p = RpgSaveStore.newPlayer(name: "t", cls: cls, id: 1)
        p.level = level
        p.armor = nil
        return p.maxHP / max(1, attack - p.defense * 0.5)
    }

    func testMageTakesLessDamageButStaysTheSoftestClass() {
        XCTAssertEqual(RpgClass.mage.defensePerLevel, 1.6, accuracy: 0.001)
        // A Lv10 mage against a wolf (attack 18) and a Lv30 mage against a Lv30-band hitter.
        for (level, attack) in [(10, 18.0), (30, 90.0)] {
            let mage = hitsToFall(.mage, level: level, attack: attack)
            XCTAssertLessThan(mage, hitsToFall(.archer, level: level, attack: attack), "Lv\(level): mage still falls first")
            XCTAssertLessThan(mage, hitsToFall(.warrior, level: level, attack: attack), "Lv\(level)")
        }
    }
    /// Cooldowns before the mage pass; every mage spell now comes back in half the time.
    func testMageSpellCooldownsAreHalved() {
        let before: [String: Double] = ["m_blast": 4, "m_chain": 6, "m_blink": 6, "m_shield": 25, "m_blizzard": 12, "m_pillar": 8,
                                        "m_heal": 14, "m_ult": 45, "j_inferno": 8, "j_firestorm": 20, "j_frost": 7, "j_glacier": 18]
        for (id, old) in before {
            let cd = RpgSkills.def(id)?.cooldown ?? .infinity
            XCTAssertEqual(cd, old / 2, accuracy: 0.001, id)
        }
    }
    /// The basic orb was the weakest basic attack (slow, short, single target); it now hits harder and reaches further.
    func testMageOrbIsFasterLongerAndStronger() throws {
        let w = fieldMage()
        var input = RpgInput()
        input.attack = true
        input.facing = CGVector(dx: 1, dy: 0)
        w.step(1.0 / 30, inputs: [2: input])
        let orb = try XCTUnwrap(w.shots.first { $0.fromPlayer && $0.kind == .orb })
        let speed = hypot(orb.vel.dx, orb.vel.dy)
        XCTAssertGreaterThanOrEqual(speed, 220)
        XCTAssertGreaterThanOrEqual(orb.life * speed + speed / 30, 165, "range")
        let mage = try XCTUnwrap(w.player(2))
        XCTAssertEqual(orb.damage, mage.attack(at: 0) * 1.3, accuracy: 0.01)
    }

    func testManaShieldBookIsEarlierAndCheaper() throws {
        let shield = try XCTUnwrap(RpgSkills.def("m_shield"))
        XCTAssertEqual(shield.minLevel, 10)
        XCTAssertEqual(shield.price, 900)
        XCTAssertEqual(RpgItems.item("book_m_shield")?.price, 900, "the shop sells it at the new price")
    }
    func testMageManaPoolIsDoubled() {
        var p = RpgSaveStore.newPlayer(name: "t", cls: .mage, id: 1)
        XCTAssertEqual(p.maxMP, 140, accuracy: 0.001)
        p.level = 10
        XCTAssertEqual(p.maxMP, 284, accuracy: 0.001, "was 142 at Lv10")
    }
}

import Foundation
@testable import PokeTokenBar

/// Checks for the Lv60-100 content (maps, monsters, bosses, gear tiers). Extended by the content work.
func contentChecks() {
    check(RpgMaps.maxLevel >= 60, "max level is \(RpgMaps.maxLevel)")
}

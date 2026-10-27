import Foundation

// SPIKE: rebindable keys for 픽셀 모험. Arrow keys always move and Esc / Return / Delete always drive
// menus; everything else (attack, the eight skill slots, potions, windows) maps to a key the player
// picks. Stored in UserDefaults so the layout survives restarts.

enum RpgKeyAction: String, Codable, CaseIterable, Sendable {
    case attack, interact
    case slot0, slot1, slot2, slot3, slot4, slot5, slot6, slot7
    case hpPotion, mpPotion, scroll, inventory, skills, quests, keys, minimap, party, codex, trade, equipment, sound, wardrobe

    var title: String {
        switch self {
        case .attack: return "기본 공격"
        case .interact: return "상호작용 · 포탈"
        case .hpPotion: return "HP 물약"
        case .mpPotion: return "MP 물약"
        case .scroll: return "귀환 주문서"
        case .inventory: return "가방"
        case .equipment: return "장비창"
        case .wardrobe: return "옷장 (외관)"
        case .sound: return "효과음 켜기/끄기"
        case .skills: return "스킬창"
        case .quests: return "의뢰 목록"
        case .keys: return "키 설정"
        case .minimap: return "미니맵 켜기/끄기"
        case .codex: return "도감 · 업적"
        case .trade: return "거래"
        case .party: return "파티"
        default: return "스킬 슬롯 \((slotIndex ?? 0) + 1)"
        }
    }

    var slotIndex: Int? {
        switch self {
        case .slot0: return 0
        case .slot1: return 1
        case .slot2: return 2
        case .slot3: return 3
        case .slot4: return 4
        case .slot5: return 5
        case .slot6: return 6
        case .slot7: return 7
        default: return nil
        }
    }

    static func slot(_ i: Int) -> RpgKeyAction { [.slot0, .slot1, .slot2, .slot3, .slot4, .slot5, .slot6, .slot7][i] }
}

struct RpgKeyBindings: Codable, Sendable {
    private static let storeKey = "rpgKeyBindings"
    /// Movement and menu keys that can never be rebound: arrows, Esc, Return, Delete.
    static let reserved: Set<UInt16> = [123, 124, 125, 126, 53, 36, 51]

    var codes: [RpgKeyAction: UInt16]

    static let defaults = RpgKeyBindings(codes: [
        .attack: 6, .interact: 49,                                            // Z, Space
        .slot0: 12, .slot1: 13, .slot2: 14, .slot3: 15,                       // Q W E R
        .slot4: 0, .slot5: 1, .slot6: 2, .slot7: 3,                           // A S D F
        .hpPotion: 18, .mpPotion: 19, .scroll: 20,                            // 1 2 3
        .inventory: 34, .skills: 40, .quests: 37, .keys: 31, .minimap: 46, .party: 35, .codex: 11, .trade: 17, .equipment: 8, .sound: 45, .wardrobe: 9,       // I K L O P
    ])

    static func load() -> RpgKeyBindings {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              var saved = try? JSONDecoder().decode(RpgKeyBindings.self, from: data) else { return defaults }
        for a in RpgKeyAction.allCases where saved.codes[a] == nil { saved.codes[a] = defaults.codes[a] }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.storeKey) }
    }

    func code(_ a: RpgKeyAction) -> UInt16 { codes[a] ?? Self.defaults.codes[a] ?? 0 }
    func actions(for code: UInt16) -> [RpgKeyAction] { codes.filter { $0.value == code }.map(\.key) }

    /// Binds `code` to `action`; whatever held that key before takes the action's old key.
    mutating func bind(_ action: RpgKeyAction, to code: UInt16) {
        let old = self.code(action)
        for (a, c) in codes where c == code && a != action { codes[a] = old }
        codes[action] = code
    }

    func label(_ a: RpgKeyAction) -> String { Self.name(code(a)) }

    static func name(_ code: UInt16) -> String {
        let table: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
            15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-",
            28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        ]
        return table[code] ?? "#\(code)"
    }
}

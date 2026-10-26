import Foundation

/// Digimon lines bundled with the app. PokéAPI has no Digimon, so ids live in a reserved 9000s band
/// (Pokémon use 1...649, forms use 10000+) and data/sprites come from this file and the app bundle.
enum DigimonCatalog {
    struct Entry {
        let id: Int
        let names: [String: String]     // PokéAPI-style language code → name
        let types: [String]
        let stats: [Int]                // hp, atk, def, spa, spd, spe
        let ability: String
        let moves: [(name: String, level: Int)]
    }

    static let agumonLine: [Int] = [9001, 9002, 9003, 9004, 9005]
    /// Shiny Koromon branches off to this line instead of Agumon's; normal ones never take it.
    static let blackAgumonLine: [Int] = [9006, 9007, 9008]
    /// Gallantmon Crimson Mode: shiny-only alternative to Gallantmon at the end of the high-res Guilmon line.
    static let crimsonID = 9146
    static let crimsonLineBase = 9141
    static let shinyOnlyIDs: Set<Int> = Set(blackAgumonLine + [crimsonID])
    /// Granted on the graduation that completes both of these finals. Not in `baseIDs`, so never hatched.
    static let omegamonID = 9021
    static let omegamonRequirements: Set<String> = ["9001:9005", "9011:9015"]
    static let gabumonLine: [Int] = [9011, 9012, 9013, 9014, 9015]
    /// Five-stage lines generated from `lineSpecs`: Guilmon 9031, Veemon 9041, Piyomon 9051,
    /// Patamon 9061, Tentomon 9071, Gomamon 9081, Tailmon 9111, Renamon 9121, Lopmon 9131, Guilmon (hi-res) 9141.
    static let extraLines: [[Int]] = lineSpecs.map { spec in (0..<5).map { spec.base + $0 } }
    static let baseIDs: [Int] = [agumonLine[0], gabumonLine[0]] + extraLines.map { $0[0] }
    /// Same as `PokeAPIClient`'s capture-rate threshold for `.rare`.
    static let captureRate = 45

    private static let handWritten: [Entry] = [
        Entry(id: 9001, names: ["ko": "코로몬", "en": "Koromon", "ja": "コロモン"], types: ["normal"],
              stats: [50, 40, 35, 40, 35, 45], ability: "run-away",
              moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
        Entry(id: 9002, names: ["ko": "아구몬", "en": "Agumon", "ja": "アグモン"], types: ["fire"],
              stats: [65, 70, 55, 60, 50, 70], ability: "blaze",
              moves: [("scratch", 1), ("ember", 1), ("fire-fang", 14), ("flame-burst", 22)]),
        Entry(id: 9003, names: ["ko": "그레이몬", "en": "Greymon", "ja": "グレイモン"], types: ["fire", "dragon"],
              stats: [90, 100, 85, 85, 70, 70], ability: "blaze",
              moves: [("ember", 1), ("headbutt", 1), ("flamethrower", 24), ("dragon-claw", 32)]),
        Entry(id: 9004, names: ["ko": "메탈그레이몬", "en": "MetalGreymon", "ja": "メタルグレイモン"], types: ["fire", "steel"],
              stats: [95, 120, 105, 95, 80, 75], ability: "blaze",
              moves: [("flamethrower", 1), ("metal-claw", 1), ("flash-cannon", 30), ("fire-blast", 40)]),
        Entry(id: 9005, names: ["ko": "워그레이몬", "en": "WarGreymon", "ja": "ウォーグレイモン"], types: ["fire", "dragon"],
              stats: [100, 135, 115, 90, 90, 90], ability: "blaze",
              moves: [("dragon-claw", 1), ("flare-blitz", 1), ("dragon-dance", 34), ("outrage", 46)]),

        Entry(id: 9006, names: ["ko": "블랙아구몬", "en": "BlackAgumon", "ja": "ブラックアグモン"], types: ["dark"],
              stats: [65, 72, 55, 60, 50, 70], ability: "blaze",
              moves: [("scratch", 1), ("ember", 1), ("bite", 14), ("shadow-claw", 22)]),
        Entry(id: 9007, names: ["ko": "블랙그레이몬", "en": "BlackGreymon", "ja": "ブラックグレイモン"], types: ["dark", "dragon"],
              stats: [90, 105, 85, 85, 70, 70], ability: "blaze",
              moves: [("ember", 1), ("headbutt", 1), ("dark-pulse", 24), ("dragon-claw", 32)]),
        Entry(id: 9008, names: ["ko": "스컬그레이몬", "en": "SkullGreymon", "ja": "スカルグレイモン"], types: ["dark", "ghost"],
              stats: [100, 130, 70, 100, 60, 80], ability: "blaze",
              moves: [("shadow-claw", 1), ("crunch", 1), ("hex", 30), ("hyper-beam", 42)]),
        Entry(id: 9021, names: ["ko": "오메가몬", "en": "Omegamon", "ja": "オメガモン"], types: ["dragon", "steel"],
              stats: [140, 155, 130, 140, 120, 115], ability: "blaze",
              moves: [("dragon-claw", 1), ("sacred-sword", 1), ("flash-cannon", 30), ("fire-blast", 40),
                      ("dragon-pulse", 45), ("hyper-beam", 50)]),

        Entry(id: 9146, names: ["ko": "듀크몬 크림슨 모드", "en": "Gallantmon Crimson Mode", "ja": "デュークモン クリムゾンモード"],
              types: ["fire", "steel"], stats: [100, 135, 108, 105, 92, 95], ability: "blaze",
              moves: [("flare-blitz", 1), ("iron-head", 1), ("flash-cannon", 34), ("fire-blast", 46)]),

        // Not a Digimon: the unlock-gated `SecretMonster`, kept here to reuse bundled data and sprites.
        Entry(id: 9101, names: ["ko": "무쇠깨비", "en": "Musoekkaebi", "ja": "ムセッケビ"], types: ["steel", "dark"],
              stats: [255, 255, 255, 255, 255, 255], ability: "huge-power",
              moves: []),

        Entry(id: 9011, names: ["ko": "뿔몬", "en": "Tsunomon", "ja": "ツノモン"], types: ["normal"],
              stats: [50, 38, 40, 38, 38, 42], ability: "run-away",
              moves: [("tackle", 1), ("leer", 5), ("powder-snow", 10)]),
        Entry(id: 9012, names: ["ko": "파피몬", "en": "Gabumon", "ja": "ガブモン"], types: ["ice"],
              stats: [65, 62, 58, 58, 55, 65], ability: "snow-cloak",
              moves: [("bite", 1), ("powder-snow", 1), ("ice-fang", 14), ("ice-shard", 22)]),
        Entry(id: 9013, names: ["ko": "가루몬", "en": "Garurumon", "ja": "ガルルモン"], types: ["ice"],
              stats: [90, 95, 80, 80, 80, 100], ability: "snow-cloak",
              moves: [("ice-fang", 1), ("bite", 1), ("ice-beam", 24), ("crunch", 32)]),
        Entry(id: 9014, names: ["ko": "워가루몬", "en": "WereGarurumon", "ja": "ワーガルルモン"], types: ["ice", "fighting"],
              stats: [95, 115, 90, 90, 90, 100], ability: "snow-cloak",
              moves: [("ice-punch", 1), ("close-combat", 1), ("avalanche", 30), ("blizzard", 40)]),
        Entry(id: 9015, names: ["ko": "메탈가루몬", "en": "MetalGarurumon", "ja": "メタルガルルモン"], types: ["ice", "steel"],
              stats: [100, 120, 110, 105, 95, 105], ability: "snow-cloak",
              moves: [("ice-beam", 1), ("metal-claw", 1), ("flash-cannon", 34), ("blizzard", 46)]),
    ]

    private static let entries: [Int: Entry] = Dictionary(
        uniqueKeysWithValues: (handWritten + lineSpecs.flatMap(lineEntries)).map { ($0.id, $0) })

    // MARK: Digimon skills

    /// A Digimon's own attack. Power and accuracy come from the stage tier and the slot, not from
    /// per-move numbers, so every line scales the same way.
    private struct Skill {
        let name: String
        let type: String
        let physical: Bool
        init(_ name: String, _ type: String, _ physical: Bool) {
            self.name = name
            self.type = type
            self.physical = physical
        }
    }

    /// Four skills per species, weakest to signature.
    private static let skills: [Int: [Skill]] = [
        9001: [Skill("몸통박치기", "normal", true), Skill("점프 어택", "normal", true), Skill("버블 블로우", "water", false), Skill("코로 브레스", "fire", false)],
        9002: [Skill("빅 클로", "normal", true), Skill("헤드 어택", "normal", true), Skill("화염 발톱", "fire", true), Skill("페퍼 브레스", "fire", false)],
        9003: [Skill("꼬리 후리기", "normal", true), Skill("뿔 박치기", "normal", true), Skill("메가 플레임", "fire", false), Skill("대폭염", "fire", false)],
        9004: [Skill("메탈 클로", "steel", true), Skill("트라이던트 암", "steel", true), Skill("기가 미사일", "fire", false), Skill("기가 디스트로이어", "steel", false)],
        9005: [Skill("드라몬 킬러", "dragon", true), Skill("브레이브 실드", "steel", true), Skill("용기의 일격", "fighting", true), Skill("가이아 포스", "fire", false)],
        9006: [Skill("다크 클로", "dark", true), Skill("칠흑 발톱", "dark", true), Skill("어둠의 숨결", "dark", false), Skill("암흑 불꽃", "dark", false)],
        9007: [Skill("그림자 뿔", "dark", true), Skill("흑룡 꼬리", "dragon", true), Skill("블랙 메가 플레임", "dark", false), Skill("칠흑 대폭염", "dark", false)],
        9008: [Skill("뼈 휘두르기", "ghost", true), Skill("어둠의 포효", "dark", false), Skill("해골 미사일", "ghost", false), Skill("파멸 포격", "dark", false)],
        9011: [Skill("몸통박치기", "normal", true), Skill("뿔 박치기", "normal", true), Skill("뿔 돌진", "normal", true), Skill("작은 눈보라", "ice", false)],
        9012: [Skill("송곳니 물기", "normal", true), Skill("프티 파이어", "fire", false), Skill("푸른 발톱", "ice", true), Skill("블루 블래스터", "ice", false)],
        9013: [Skill("거친 송곳니", "normal", true), Skill("프로즌 클로", "ice", true), Skill("서리 숨결", "ice", false), Skill("폭풍 송곳니", "ice", false)],
        9014: [Skill("늑대 발톱", "fighting", true), Skill("월광 킥", "fighting", true), Skill("아이스 클로", "ice", true), Skill("월광의 포효", "ice", false)],
        9015: [Skill("메탈 클로", "steel", true), Skill("아이스 미사일", "ice", false), Skill("코큐토스 브레스", "ice", false), Skill("메탈 울프 레이저", "steel", false)],
        9021: [Skill("그레이 소드", "steel", true), Skill("가루 캐논", "ice", false), Skill("트랜센던트 소드", "fighting", true), Skill("슈프림 캐논", "fire", false)],
        9031: [Skill("몸통박치기", "normal", true), Skill("구르기", "normal", true), Skill("불꽃 거품", "fire", false), Skill("꼬마 불꽃", "fire", false)],
        9032: [Skill("록 브레이커", "normal", true), Skill("파이어볼", "fire", false), Skill("불타는 발톱", "fire", true), Skill("파이로 스피어", "fire", false)],
        9033: [Skill("꼬리 휘두르기", "normal", true), Skill("화염 클로", "fire", true), Skill("파이로 블래스터", "fire", false), Skill("인페르노 브레스", "fire", false)],
        9034: [Skill("강철 발톱", "steel", true), Skill("가슴 캐논", "fire", false), Skill("용 파괴포", "dragon", false), Skill("아토믹 블래스터", "fire", false)],
        9035: [Skill("로얄 창격", "steel", true), Skill("성스러운 방패", "steel", true), Skill("크림슨 라이트", "fire", false), Skill("파이널 엘리시온", "steel", false)],
        9041: [Skill("몸통박치기", "normal", true), Skill("구르기", "normal", true), Skill("거품 공격", "water", false), Skill("번뜩 박치기", "normal", true)],
        9042: [Skill("브이 헤드버트", "normal", true), Skill("브이 펀치", "fighting", true), Skill("드래곤 점프", "dragon", true), Skill("브이 블래스트", "dragon", false)],
        9043: [Skill("엑스 너클", "fighting", true), Skill("슬래시 킥", "fighting", true), Skill("엑스 레이저", "dragon", false), Skill("엑스 인페르노", "dragon", false)],
        9044: [Skill("더블 건", "steel", false), Skill("데저트 캐논", "steel", false), Skill("용 날개 베기", "dragon", true), Skill("패일 파이널", "dragon", false)],
        9045: [Skill("임페리얼 클로", "dragon", true), Skill("용 날개 돌풍", "flying", false), Skill("포지티브 레이", "dragon", false), Skill("메가 크러시", "steel", false)],
        9051: [Skill("몸통박치기", "normal", true), Skill("쪼기", "flying", true), Skill("뾰족 거품", "water", false), Skill("꼬마 불꽃", "fire", false)],
        9052: [Skill("쪼기", "flying", true), Skill("날개 치기", "flying", true), Skill("매직 파이어", "fire", false), Skill("스피닝 니들", "flying", false)],
        9053: [Skill("날갯짓", "flying", true), Skill("화염 깃털", "fire", false), Skill("메테오 윙", "fire", false), Skill("불새 급강하", "flying", true)],
        9054: [Skill("송곳 부리", "flying", true), Skill("불꽃 날개", "fire", false), Skill("섀도 윙", "dark", false), Skill("가루다 폭풍", "flying", false)],
        9055: [Skill("불사조 급습", "flying", true), Skill("성스러운 불꽃", "fire", false), Skill("별빛 폭발", "fire", false), Skill("불사조 대화염", "fire", false)],
        9061: [Skill("몸통박치기", "normal", true), Skill("뛰어오르기", "normal", true), Skill("거품 공격", "water", false), Skill("꼬마 바람", "flying", false)],
        9062: [Skill("몸통박치기", "normal", true), Skill("에어 샷", "normal", false), Skill("날개 박치기", "flying", true), Skill("부머 버블", "normal", false)],
        9063: [Skill("성스러운 주먹", "fighting", true), Skill("헤븐즈 너클", "fighting", true), Skill("홀리 빔", "psychic", false), Skill("천벌", "psychic", false)],
        9064: [Skill("성검 슬래시", "steel", true), Skill("천사의 날개", "flying", false), Skill("게이트 오브 데스티니", "psychic", false), Skill("성검 일섬", "steel", true)],
        9065: [Skill("빛의 화살", "psychic", false), Skill("천상의 날개", "flying", false), Skill("세븐 헤븐즈", "psychic", false), Skill("최후의 심판", "psychic", false)],
        9071: [Skill("몸통박치기", "normal", true), Skill("끈끈이 거품", "bug", false), Skill("꿈틀 박치기", "normal", true), Skill("작은 번개", "electric", false)],
        9072: [Skill("텐타 박치기", "bug", true), Skill("가시 침", "bug", true), Skill("슈퍼 쇼크", "electric", false), Skill("스파크 썬더", "electric", false)],
        9073: [Skill("집게 공격", "bug", true), Skill("뿔 찌르기", "bug", true), Skill("일렉트로 쇼크", "electric", false), Skill("호른 썬더", "electric", false)],
        9074: [Skill("뿔 충격", "bug", true), Skill("번개 뿔", "electric", true), Skill("호른 버스터", "bug", true), Skill("메가 블래스터", "electric", false)],
        9075: [Skill("장수풍뎅이 돌진", "bug", true), Skill("헤라클 호른", "bug", true), Skill("천둥 번개", "electric", false), Skill("기가 블래스터", "electric", false)],
        9081: [Skill("몸통박치기", "normal", true), Skill("구르기", "normal", true), Skill("거품 공격", "water", false), Skill("물풍선", "water", false)],
        9082: [Skill("고마 박치기", "normal", true), Skill("물보라", "water", false), Skill("마블 샷", "water", false), Skill("파도 돌진", "water", true)],
        9083: [Skill("뿔 찌르기", "normal", true), Skill("얼음 작살", "ice", true), Skill("하푼 토네이도", "water", true), Skill("하푼 블리자드", "ice", false)],
        9084: [Skill("망치 휘두르기", "fighting", true), Skill("바다 해머", "water", true), Skill("벽력 해머", "electric", true), Skill("바다의 노여움", "water", false)],
        9101: [Skill("도깨비 방망이", "steel", true), Skill("도깨비불", "fire", false),
               Skill("씨름 메치기", "fighting", true), Skill("금 나와라 뚝딱", "ghost", false)],
        9111: [Skill("몸통박치기", "normal", true), Skill("냥냥 박치기", "normal", true), Skill("거품 공격", "water", false), Skill("꼬마 반짝", "psychic", false)],
        9112: [Skill("몸통박치기", "normal", true), Skill("플롯 돌진", "normal", true), Skill("신비한 빛", "psychic", false), Skill("스피닝 테일", "normal", true)],
        9113: [Skill("네코 펀치", "normal", true), Skill("네코 킥", "fighting", true), Skill("캣츠 아이 최면", "psychic", false), Skill("라이트닝 포", "electric", false)],
        9114: [Skill("천사의 일격", "flying", true), Skill("천사의 날개", "flying", false), Skill("헤븐즈 차밍", "psychic", false), Skill("천상의 화살", "psychic", false)],
        9115: [Skill("성스러운 창", "psychic", true), Skill("오파니 방패", "steel", true), Skill("프로미넌스 빔", "psychic", false), Skill("성스러운 심판", "psychic", false)],
        9121: [Skill("몸통박치기", "normal", true), Skill("꼬마 불꽃", "fire", false), Skill("꼬리 흔들기", "normal", true), Skill("쪼끔 바람", "flying", false)],
        9122: [Skill("발톱 할퀴기", "normal", true), Skill("나선 킥", "fighting", true), Skill("환영의 장막", "psychic", false), Skill("다이아몬드 스톰", "rock", false)],
        9123: [Skill("꼬리 후리기", "normal", true), Skill("여우불 돌진", "fire", true), Skill("용염 윤무", "fire", false), Skill("구미호 화염진", "fire", false)],
        9124: [Skill("붓 후리기", "psychic", true), Skill("부적 결계", "psychic", false), Skill("천지개벽 부적", "ghost", false), Skill("오행 봉인술", "psychic", false)],
        9125: [Skill("금강장 일격", "fighting", true), Skill("무녀의 기도", "psychic", false), Skill("수호의 파문", "fire", false), Skill("아메시스트 만다라", "psychic", false)],
        9131: [Skill("몸통박치기", "normal", true), Skill("초코 박치기", "normal", true), Skill("거품 공격", "water", false), Skill("꼬마 번개", "electric", false)],
        9132: [Skill("귀 후려치기", "normal", true), Skill("뿔 박치기", "normal", true), Skill("미니 토네이도", "flying", false), Skill("블레이징 아이스", "ice", false)],
        9133: [Skill("쌍권 연타", "fighting", true), Skill("철선 후리기", "steel", true), Skill("파이널 킥", "fighting", true), Skill("용권 선풍", "flying", true)],
        9134: [Skill("도끼날 손", "steel", true), Skill("귀 칼날", "steel", true), Skill("천공 참격", "flying", true), Skill("골드 크러시", "steel", true)],
        9135: [Skill("날개 치기", "flying", true), Skill("귀 번개", "electric", false), Skill("성스러운 폭풍", "psychic", false), Skill("신성한 천둥", "electric", false)],
        9141: [Skill("몸통박치기", "normal", true), Skill("기기 박치기", "normal", true), Skill("거품 공격", "water", false), Skill("꼬마 불꽃", "fire", false)],
        9142: [Skill("빅 클로", "normal", true), Skill("록 브레이커", "normal", true), Skill("화염 발톱", "fire", true), Skill("파이로 스피어", "fire", false)],
        9143: [Skill("꼬리 후리기", "normal", true), Skill("화염 클로", "fire", true), Skill("파이로 블래스터", "fire", false), Skill("인페르노 블래스트", "fire", false)],
        9144: [Skill("강철 발톱", "steel", true), Skill("아토믹 블래스터", "fire", false), Skill("용 파괴포", "dragon", false), Skill("건틀릿 크러시", "steel", true)],
        9145: [Skill("로얄 창격", "steel", true), Skill("이지스 방패 돌진", "steel", true), Skill("크림슨 라이트", "fire", false), Skill("파이널 엘리시온", "steel", false)],
        9146: [Skill("글로리 랜스", "steel", true), Skill("그라니 플레임", "fire", true), Skill("크림슨 베일", "fire", false), Skill("얼티밋 라이트", "steel", false)],
        9085: [Skill("꼬리 휘두르기", "normal", true), Skill("해일", "water", false), Skill("심해 레이저", "water", false), Skill("해룡의 포효", "dragon", false)],
    ]

    /// Power by stage tier (baby … ultimate, then Omegamon) and slot.
    private static let powerTiers: [[Int]] = [
        [25, 30, 35, 40], [40, 55, 70, 80], [55, 70, 85, 95],
        [65, 80, 95, 110], [80, 95, 110, 125], [95, 110, 125, 140]]
    private static let slotAccuracy = [100, 100, 95, 90]
    /// Shiny-only branch members and Omegamon sit at other tiers than their id suggests.
    private static let tierOverrides: [Int: Int] = [9006: 1, 9007: 2, 9008: 3, 9021: 5, 9101: 5, 9146: 4]

    private static func tier(of id: Int) -> Int {
        tierOverrides[id] ?? max(0, min(4, id - ((id / 10) * 10 + 1)))
    }

    /// Battle moves for a Digimon, or nil for anything else (Pokémon use PokéAPI data).
    static func battleMoves(speciesID id: Int) -> [BattleMove]? {
        guard let list = skills[id] else { return nil }
        let powers = powerTiers[tier(of: id)]
        return list.enumerated().map { i, skill in
            BattleMove(name: skill.name, type: skill.type, power: powers[i], accuracy: slotAccuracy[i],
                       isPhysical: skill.physical, priority: 0)
        }
    }

    static func contains(_ id: Int) -> Bool { entries[id] != nil }

    private struct Stage {
        let ko: String, en: String, ja: String
        let types: [String]
        let moves: [(name: String, level: Int)]
    }
    private struct LineSpec {
        let base: Int
        let ability: String
        let stages: [Stage]
    }
    /// Shared stage curve: baby, child, adult, perfect, ultimate (hp, atk, def, spa, spd, spe).
    private static let stageStats: [[Int]] = [
        [50, 38, 38, 38, 38, 42], [65, 65, 55, 60, 52, 66], [90, 95, 82, 82, 72, 80],
        [95, 115, 95, 92, 85, 88], [100, 130, 110, 100, 92, 95]]

    private static func lineEntries(_ spec: LineSpec) -> [Entry] {
        spec.stages.enumerated().map { i, st in
            Entry(id: spec.base + i, names: ["ko": st.ko, "en": st.en, "ja": st.ja], types: st.types,
                  stats: stageStats[i], ability: i == 0 ? "run-away" : spec.ability, moves: st.moves)
        }
    }

    private static let lineSpecs: [LineSpec] = [
        LineSpec(base: 9031, ability: "blaze", stages: [
            Stage(ko: "지기몬", en: "Gigimon", ja: "ジジモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
            Stage(ko: "길몬", en: "Guilmon", ja: "ギルモン", types: ["fire"], moves: [("scratch", 1), ("ember", 1), ("fire-fang", 14), ("flame-burst", 22)]),
            Stage(ko: "그라우몬", en: "Growlmon", ja: "グラウモン", types: ["fire"], moves: [("ember", 1), ("headbutt", 1), ("flamethrower", 24), ("dragon-claw", 32)]),
            Stage(ko: "워그라우몬", en: "WarGrowlmon", ja: "メガログラウモン", types: ["fire", "dragon"], moves: [("flamethrower", 1), ("dragon-claw", 1), ("flash-cannon", 30), ("fire-blast", 40)]),
            Stage(ko: "듀크몬", en: "Gallantmon", ja: "デュークモン", types: ["fire", "steel"], moves: [("flare-blitz", 1), ("dragon-claw", 1), ("flash-cannon", 34), ("fire-blast", 46)])]),
        LineSpec(base: 9041, ability: "justified", stages: [
            Stage(ko: "치보몬", en: "Chibomon", ja: "チビモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("headbutt", 10)]),
            Stage(ko: "브이몬", en: "Veemon", ja: "ブイモン", types: ["dragon"], moves: [("tackle", 1), ("headbutt", 1), ("dragon-breath", 14), ("brick-break", 22)]),
            Stage(ko: "엑스브이몬", en: "ExVeemon", ja: "エクスブイモン", types: ["dragon", "fighting"], moves: [("headbutt", 1), ("dragon-claw", 1), ("brick-break", 24), ("dragon-pulse", 32)]),
            Stage(ko: "패일드라몬", en: "Paildramon", ja: "パイルドラモン", types: ["dragon", "steel"], moves: [("dragon-claw", 1), ("flash-cannon", 1), ("hyper-beam", 30), ("dragon-pulse", 40)]),
            Stage(ko: "임페리얼드라몬", en: "Imperialdramon", ja: "インペリアルドラモン", types: ["dragon", "steel"], moves: [("dragon-pulse", 1), ("flash-cannon", 1), ("hyper-beam", 34), ("outrage", 46)])]),
        LineSpec(base: 9051, ability: "keen-eye", stages: [
            Stage(ko: "요코몬", en: "Yokomon", ja: "ピョコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("peck", 10)]),
            Stage(ko: "피요몬", en: "Biyomon", ja: "ピヨモン", types: ["flying"], moves: [("peck", 1), ("gust", 1), ("wing-attack", 14), ("air-slash", 22)]),
            Stage(ko: "버드라몬", en: "Birdramon", ja: "バードラモン", types: ["fire", "flying"], moves: [("ember", 1), ("wing-attack", 1), ("flamethrower", 24), ("aerial-ace", 32)]),
            Stage(ko: "가루다몬", en: "Garudamon", ja: "ガルダモン", types: ["fire", "flying"], moves: [("flamethrower", 1), ("air-slash", 1), ("fire-blast", 30), ("hurricane", 40)]),
            Stage(ko: "피닉스몬", en: "Phoenixmon", ja: "ホウオウモン", types: ["fire", "flying"], moves: [("fire-blast", 1), ("brave-bird", 1), ("hurricane", 34), ("sky-attack", 46)])]),
        LineSpec(base: 9061, ability: "serene-grace", stages: [
            Stage(ko: "토코몬", en: "Tokomon", ja: "トコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("gust", 10)]),
            Stage(ko: "파닥몬", en: "Patamon", ja: "パタモン", types: ["normal", "flying"], moves: [("tackle", 1), ("gust", 1), ("headbutt", 14), ("air-slash", 22)]),
            Stage(ko: "엔젤몬", en: "Angemon", ja: "エンジェモン", types: ["flying", "psychic"], moves: [("confusion", 1), ("wing-attack", 1), ("psychic", 24), ("aerial-ace", 32)]),
            Stage(ko: "매그나엔젤몬", en: "MagnaAngemon", ja: "ホーリーエンジェモン", types: ["flying", "psychic"], moves: [("psychic", 1), ("sacred-sword", 1), ("air-slash", 30), ("hyper-beam", 40)]),
            Stage(ko: "세라피몬", en: "Seraphimon", ja: "セラフィモン", types: ["flying", "psychic"], moves: [("psychic", 1), ("hyper-beam", 1), ("air-slash", 34), ("sacred-sword", 46)])]),
        LineSpec(base: 9071, ability: "static", stages: [
            Stage(ko: "모티몬", en: "Motimon", ja: "モチモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("bug-bite", 10)]),
            Stage(ko: "텐타몬", en: "Tentomon", ja: "テントモン", types: ["bug", "electric"], moves: [("thunder-shock", 1), ("bug-bite", 1), ("spark", 14), ("bug-buzz", 22)]),
            Stage(ko: "카부테리몬", en: "Kabuterimon", ja: "カブテリモン", types: ["bug", "electric"], moves: [("thunder-shock", 1), ("bug-bite", 1), ("thunderbolt", 24), ("x-scissor", 32)]),
            Stage(ko: "메가카부테리몬", en: "MegaKabuterimon", ja: "アトラーカブテリモン", types: ["bug", "electric"], moves: [("thunderbolt", 1), ("x-scissor", 1), ("megahorn", 30), ("thunder", 40)]),
            Stage(ko: "헤라클카부테리몬", en: "HerculesKabuterimon", ja: "ヘラクルカブテリモン", types: ["bug", "electric"], moves: [("thunder", 1), ("megahorn", 1), ("bug-buzz", 34), ("hyper-beam", 46)])]),
        LineSpec(base: 9081, ability: "torrent", stages: [
            Stage(ko: "푸카몬", en: "Pukamon", ja: "プカモン", types: ["water"], moves: [("tackle", 1), ("growl", 5), ("water-gun", 10)]),
            Stage(ko: "고마몬", en: "Gomamon", ja: "ゴマモン", types: ["water"], moves: [("tackle", 1), ("water-gun", 1), ("aqua-jet", 14), ("bubble-beam", 22)]),
            Stage(ko: "이가몬", en: "Ikkakumon", ja: "イッカクモン", types: ["water", "ice"], moves: [("water-gun", 1), ("horn-attack", 1), ("ice-beam", 24), ("horn-drill", 32)]),
            Stage(ko: "주드몬", en: "Zudomon", ja: "ズドモン", types: ["water", "fighting"], moves: [("hammer-arm", 1), ("waterfall", 1), ("surf", 30), ("close-combat", 40)]),
            Stage(ko: "플레시오몬", en: "Plesiomon", ja: "プレシオモン", types: ["water", "dragon"], moves: [("hydro-pump", 1), ("dragon-pulse", 1), ("surf", 34), ("hyper-beam", 46)])]),
        LineSpec(base: 9111, ability: "cute-charm", stages: [
            Stage(ko: "야옹몬", en: "Nyaromon", ja: "ニャロモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("charm", 10)]),
            Stage(ko: "플롯트몬", en: "Salamon", ja: "プロットモン", types: ["normal"], moves: [("tackle", 1), ("charm", 1), ("bite", 14), ("play-rough", 22)]),
            Stage(ko: "가트몬", en: "Tailmon", ja: "テイルモン", types: ["normal"], moves: [("scratch", 1), ("mach-punch", 1), ("hypnosis", 24), ("thunderbolt", 32)]),
            Stage(ko: "엔젤우몬", en: "Angewomon", ja: "エンジェウーモン", types: ["flying", "psychic"], moves: [("aerial-ace", 1), ("psychic", 1), ("air-slash", 30), ("hyper-beam", 40)]),
            Stage(ko: "오파니몬", en: "Ophanimon", ja: "オファニモン", types: ["psychic", "steel"], moves: [("psychic", 1), ("flash-cannon", 1), ("hyper-beam", 34), ("sacred-sword", 46)])]),
        LineSpec(base: 9121, ability: "magic-guard", stages: [
            Stage(ko: "포코몬", en: "Viximon", ja: "ポコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
            Stage(ko: "레나몬", en: "Renamon", ja: "レナモン", types: ["fighting"], moves: [("scratch", 1), ("double-kick", 1), ("confusion", 14), ("power-gem", 22)]),
            Stage(ko: "구미호몬", en: "Kyubimon", ja: "キュウビモン", types: ["fire"], moves: [("ember", 1), ("fire-fang", 1), ("flamethrower", 24), ("fire-blast", 32)]),
            Stage(ko: "도사몬", en: "Taomon", ja: "タオモン", types: ["psychic", "ghost"], moves: [("confusion", 1), ("shadow-ball", 1), ("psychic", 30), ("hex", 40)]),
            Stage(ko: "샤크라몬", en: "Sakuyamon", ja: "サクヤモン", types: ["psychic", "fighting"], moves: [("psychic", 1), ("close-combat", 1), ("fire-blast", 34), ("psyshock", 46)])]),
        LineSpec(base: 9131, ability: "technician", stages: [
            Stage(ko: "초코몬", en: "Chocomon", ja: "チョコモン", types: ["normal"], moves: [("tackle", 1), ("growl", 5), ("headbutt", 10)]),
            Stage(ko: "로프몬", en: "Lopmon", ja: "ロップモン", types: ["normal"], moves: [("tackle", 1), ("headbutt", 1), ("gust", 14), ("icy-wind", 22)]),
            Stage(ko: "토리에몬", en: "Turuiemon", ja: "トゥルイエモン", types: ["fighting"], moves: [("double-kick", 1), ("metal-claw", 1), ("brick-break", 24), ("high-jump-kick", 32)]),
            Stage(ko: "안티라몬", en: "Antylamon", ja: "アンティラモン", types: ["steel", "fighting"], moves: [("metal-claw", 1), ("x-scissor", 1), ("close-combat", 30), ("iron-head", 40)]),
            Stage(ko: "케루비몬", en: "Cherubimon", ja: "ケルビモン", types: ["electric", "psychic"], moves: [("thunderbolt", 1), ("psychic", 1), ("hurricane", 34), ("thunder", 46)])]),
        LineSpec(base: 9141, ability: "blaze", stages: [
            Stage(ko: "기기몬", en: "Gigimon", ja: "ギギモン", types: ["fire"], moves: [("tackle", 1), ("growl", 5), ("ember", 10)]),
            Stage(ko: "길몬", en: "Guilmon", ja: "ギルモン", types: ["fire"], moves: [("scratch", 1), ("ember", 1), ("fire-fang", 14), ("flame-burst", 22)]),
            Stage(ko: "그라우몬", en: "Growlmon", ja: "グラウモン", types: ["fire", "dragon"], moves: [("ember", 1), ("headbutt", 1), ("flamethrower", 24), ("dragon-claw", 32)]),
            Stage(ko: "메가로그라우몬", en: "WarGrowlmon", ja: "メガログラウモン", types: ["fire", "steel"], moves: [("flamethrower", 1), ("metal-claw", 1), ("flash-cannon", 30), ("fire-blast", 40)]),
            Stage(ko: "듀크몬", en: "Gallantmon", ja: "デュークモン", types: ["steel", "dragon"], moves: [("flare-blitz", 1), ("dragon-claw", 1), ("flash-cannon", 34), ("fire-blast", 46)])]),
    ]

    private static func chain(_ ids: [Int]) -> EvoNode {
        let tail = ids.dropFirst()
        return EvoNode(speciesID: ids[0], children: tail.isEmpty ? [] : [chain(Array(tail))])
    }

    private static func names(_ ids: [Int]) -> [Int: [String: String]] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, entries[$0]!.names) })
    }

    static func line(baseSpeciesID: Int) -> EvoLine? {
        if baseSpeciesID == omegamonID {
            return EvoLine(baseID: omegamonID, tree: EvoNode(speciesID: omegamonID, children: []),
                           rarity: .legendary, names: names([omegamonID]))
        }
        if baseSpeciesID == agumonLine[0] {
            let tree = EvoNode(speciesID: baseSpeciesID,
                               children: [chain(agumonLine).children[0], chain(blackAgumonLine)])
            return EvoLine(baseID: baseSpeciesID, tree: tree, rarity: .rare,
                           names: names(agumonLine + blackAgumonLine))
        }
        if baseSpeciesID == crimsonLineBase, let ids = extraLines.first(where: { $0.first == baseSpeciesID }) {
            // Warrior stage forks into Gallantmon (normal) or Crimson Mode (shiny only).
            let war = EvoNode(speciesID: ids[3], children: [EvoNode(speciesID: ids[4], children: []),
                                                            EvoNode(speciesID: crimsonID, children: [])])
            let tree = EvoNode(speciesID: ids[0], children: [EvoNode(speciesID: ids[1], children: [
                EvoNode(speciesID: ids[2], children: [war])])])
            return EvoLine(baseID: baseSpeciesID, tree: tree, rarity: .rare, names: names(ids + [crimsonID]))
        }
        guard let ids = ([gabumonLine] + extraLines).first(where: { $0.first == baseSpeciesID }) else { return nil }
        return EvoLine(baseID: baseSpeciesID, tree: chain(ids), rarity: .rare, names: names(ids))
    }

    /// Of `children`, the ones this individual may evolve into: shiny takes the shiny-only branch,
    /// normal never does. Nodes without a shiny-only child (every Pokémon) keep all children.
    static func eligibleChildren(_ children: [EvoNode], shiny: Bool) -> [EvoNode] {
        let eligible = children.filter { shinyOnlyIDs.contains($0.speciesID) == shiny }
        return eligible.isEmpty ? children : eligible
    }

    /// Profile move list: the Digimon's own skills at spread-out levels.
    private static func skillOptions(_ e: Entry) -> [PokemonMoveOption] {
        guard let list = skills[e.id] else {
            return e.moves.map {
                PokemonMoveOption(name: $0.name, learnMethods: [PokemonMoveLearnMethod(method: "level-up", level: $0.level)])
            }
        }
        return zip(list, [1, 10, 20, 30]).map { skill, level in
            PokemonMoveOption(name: skill.name, learnMethods: [PokemonMoveLearnMethod(method: "level-up", level: level)])
        }
    }

    static func details(speciesID: Int) -> PokemonDetails? {
        guard let e = entries[speciesID] else { return nil }
        let keys = PokemonStatCalculator.order
        return PokemonDetails(
            speciesID: e.id, name: e.names["en"] ?? "", height: 10, weight: 300,
            baseExperience: 100, genderRate: -1, types: e.types,
            baseStats: Dictionary(uniqueKeysWithValues: zip(keys, e.stats).map { ($0, $1) }),
            abilities: [PokemonAbilityOption(name: e.ability, slot: 1, isHidden: false)],
            moves: skillOptions(e))
    }
}

/// Serves Digimon from `DigimonCatalog` and delegates everything else (Pokémon) to PokéAPI.
struct DigimonAwareProvider: PokeProviding, PokemonDetailProviding {
    let inner: any PokeProviding

    func line(baseSpeciesID: Int) async throws -> EvoLine {
        if let local = DigimonCatalog.line(baseSpeciesID: baseSpeciesID) { return local }
        return try await inner.line(baseSpeciesID: baseSpeciesID)
    }

    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        try await inner.baseSpeciesIndex() + DigimonCatalog.baseIDs.map {
            BaseSpecies(id: $0, captureRate: DigimonCatalog.captureRate)
        }
    }

    func baseSpecies(id: Int) async throws -> BaseSpecies? {
        if DigimonCatalog.baseIDs.contains(id) { return BaseSpecies(id: id, captureRate: DigimonCatalog.captureRate) }
        return try await inner.baseSpecies(id: id)
    }

    func pokemonDetails(speciesID: Int) async throws -> PokemonDetails {
        if let local = DigimonCatalog.details(speciesID: speciesID) { return local }
        guard let detail = inner as? any PokemonDetailProviding else { throw URLError(.unsupportedURL) }
        return try await detail.pokemonDetails(speciesID: speciesID)
    }
}

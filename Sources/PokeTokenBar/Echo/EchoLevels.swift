import Foundation

// SPIKE: 메아리 level maps, 32x18 tiles.
// # wall  S spawn  E exit  ^ spikes  1-3 plates  a-c doors (plate 1 -> door a; every plate of a group must be held)

enum EchoLevels {
    private static let wall = "################################"
    private static let open = "#..............................#"
    private static func rep(_ row: String, _ n: Int) -> [String] { Array(repeating: row, count: n) }

    static let title = EchoCore.LevelDef(
        name: "title", title: "메아리", hint: "", seconds: 20, echoes: 0,
        map: [wall] + rep(open, 14) + ["#.S.........................E..#", wall, wall])

    static let defs: [EchoCore.LevelDef] = [
        .init(name: "wake", title: "1. 깨어남", hint: "숲 끝의 신전까지 가 보자.", seconds: 12, echoes: 0,
              map: [wall] + rep(open, 13) + [
                  "#.............###..............#",
                  "#.S.....##....###.........E....#",
                  "####################^^^#########",
                  wall,
              ]),
        .init(name: "echo", title: "2. 메아리", hint: "발판은 밟고 있는 동안만 문을 연다.   R 되감기", seconds: 8, echoes: 1,
              map: [wall] + rep("#...................#..........#", 12) + rep("#...................a..........#", 2) + [
                  "#.S...1.............a.......E..#",
                  wall, wall,
              ]),
        .init(name: "stair", title: "3. 계단", hint: "혼자서는 닿지 않는다.", seconds: 8, echoes: 1,
              map: [wall] + rep(open, 12) + rep("#...............###............#", 2) + [
                  "#.S.............###.........E..#",
                  wall, wall,
              ]),
        .init(name: "relay", title: "4. 릴레이", hint: "문 두 개, 발판 두 개.", seconds: 9, echoes: 2,
              map: [wall] + rep("#...........#...........#......#", 12) + rep("#...........a...........b......#", 2) + [
                  "#.S.1.......a....2......b...E..#",
                  wall, wall,
              ]),
        .init(name: "tower", title: "5. 탑", hint: "더 높이.", seconds: 9, echoes: 2,
              map: [wall] + rep(open, 11) + rep("#.................###..........#", 3) + [
                  "#.S...............###......E...#",
                  wall, wall,
              ]),
        .init(name: "sacrifice", title: "6. 남는 쪽", hint: "구덩이 바닥에도 발판이 있다.", seconds: 10, echoes: 2,
              map: [wall] + rep("#.............#................#", 8) + rep("#.............a.......###......#", 2) + [
                  "#.S...........a.......###...E..#",
              ] + rep("#######.########################", 3) + [
                  "#######1########################",
                  wall, wall,
              ]),
        .init(name: "chorus", title: "7. 합창", hint: "발판 셋. 그리고 걸어 나갈 하나.", seconds: 10, echoes: 3,
              map: [wall] + rep("#...................#..........#", 11) + [
                  "#...........1.......#..........#",
              ] + rep("#..........###......a..........#", 2) + [
                  "#.S..1....1###......a.......E..#",
                  wall, wall,
              ]),
    ]

    /// Parsed once; the maps are static and covered by tests, so a parse failure is a programming error.
    static let titleRoom: EchoLevel = try! EchoCore.parse(title)
    static let all: [EchoLevel] = defs.map { try! EchoCore.parse($0) }
}

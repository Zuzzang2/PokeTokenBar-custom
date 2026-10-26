// ECHO levels. 32x18 tiles.
// # wall  S spawn  E exit  ^ spikes  1-3 plates  a-c doors (plate 1 -> door a; every plate of a group must be held)
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.EchoLevels = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const WALL = '################################';
  const OPEN = '#..............................#';
  const rep = (row, n) => Array.from({ length: n }, () => row);

  const TITLE = Object.freeze({
    name: 'title', title: 'ECHO', time: 20, echoes: 0,
    map: [
      WALL, ...rep(OPEN, 13),
      '#..............................#',
      '#.S.........................E..#',
      WALL, WALL,
    ],
  });

  const LEVELS = Object.freeze([
    {
      name: 'wake', title: '01  깨어남', time: 12, echoes: 0,
      hint: '←→ / A D 이동      SPACE 점프',
      map: [
        WALL, ...rep(OPEN, 13),
        '#.............###..............#',
        '#.S.....##....###.........E....#',
        '####################^^^#########',
        WALL,
      ],
    },
    {
      name: 'echo', title: '02  메아리', time: 8, echoes: 1,
      hint: '발판은 밟고 있을 때만 문을 연다.   [R] 되감기 — 방금의 너는 메아리가 되어 똑같이 반복한다.',
      map: [
        WALL,
        ...rep('#...................#..........#', 12),
        ...rep('#...................a..........#', 2),
        '#.S...1.............a.......E..#',
        WALL, WALL,
      ],
    },
    {
      name: 'stair', title: '03  계단', time: 8, echoes: 1,
      hint: '너무 높다. 과거의 너는 지나쳐 갈 수도 있고, 머리를 밟고 설 수도 있다.',
      map: [
        WALL, ...rep(OPEN, 12),
        ...rep('#...............###............#', 2),
        '#.S.............###.........E..#',
        WALL, WALL,
      ],
    },
    {
      name: 'relay', title: '04  릴레이', time: 9, echoes: 2,
      hint: '한 명이 문을 잡고, 다른 한 명이 다음 문을 잡는다.',
      map: [
        WALL,
        ...rep('#...........#...........#......#', 12),
        ...rep('#...........a...........b......#', 2),
        '#.S.1.......a....2......b...E..#',
        WALL, WALL,
      ],
    },
    {
      name: 'tower', title: '05  탑', time: 9, echoes: 2,
      hint: '어깨 위에 어깨를.',
      map: [
        WALL, ...rep(OPEN, 11),
        ...rep('#.................###..........#', 3),
        '#.S...............###......E...#',
        WALL, WALL,
      ],
    },
    {
      name: 'sacrifice', title: '06  남는 사람', time: 10, echoes: 2,
      hint: '누군가는 저 구덩이에 남아야 한다.   [BACKSPACE] 마지막 메아리 지우기',
      map: [
        WALL,
        ...rep('#.............#................#', 8),
        ...rep('#.............a.......###......#', 2),
        '#.S...........a.......###...E..#',
        ...rep('#######.########################', 3),
        '#######1########################',
        WALL, WALL,
      ],
    },
    {
      name: 'chorus', title: '07  합창', time: 10, echoes: 3,
      hint: '세 개의 발판. 세 명의 너. 그리고 마지막으로 걸어 나갈 너.',
      map: [
        WALL,
        ...rep('#...................#..........#', 11),
        '#...........1.......#..........#',
        ...rep('#..........###......a..........#', 2),
        '#.S..1....1###......a.......E..#',
        WALL, WALL,
      ],
    },
  ]);

  return Object.freeze({ TITLE, LEVELS });
});

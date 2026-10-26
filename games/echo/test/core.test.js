const test = require('node:test');
const assert = require('node:assert/strict');
const Core = require('../core.js');
const { TITLE, LEVELS } = require('../levels.js');
const { script, playLoops } = require('./script.js');

const level = (name) => Core.parseLevel(LEVELS.find((l) => l.name === name));

// One proven input script per loop. The last loop of each entry must reach the exit.
const SOLUTIONS = {
  wake: [[[45, 'r'], [15, 'rj'], [55, 'r'], [15, 'rj'], [46, 'r'], [15, 'rj'], [100, 'r']]],
  echo: [[[34, 'r']], [[300, 'r']]],
  stair: [[[200, 'r']], [[100, 'r'], [15, 'rj'], [10, 'r'], [20, 'rj'], [200, 'r']]],
  relay: [[[18, 'r']], [[130, 'r']], [[400, 'r']]],
  tower: [
    [[200, 'r']],
    [[100, 'r'], [15, 'rj'], [200, 'r']],
    [[100, 'r'], [20, 'rj'], [25, 'r'], [20, 'rj'], [25, 'r'], [20, 'rj'], [200, 'r']],
  ],
  sacrifice: [
    [[300, 'r']],
    [[30, 'r'], [15, 'rj'], [300, 'r']],
    [[30, 'r'], [15, 'rj'], [120, 'r'], [15, 'rj'], [10, 'r'], [20, 'rj'], [200, 'r']],
  ],
  chorus: [
    [[28, 'r']],
    [[30, 'r'], [15, 'rj'], [200, 'r']],
    [[30, 'r'], [15, 'rj'], [30, 'r'], [15, 'rj'], [10, 'r'], [20, 'rj'], [13, 'r']],
    [[30, 'r'], [15, 'rj'], [30, 'r'], [15, 'rj'], [10, 'r'], [20, 'rj'], [300, 'r']],
  ],
};

test('every level parses to a 32x18 grid with spawn and exit', () => {
  [TITLE, ...LEVELS].forEach((def) => {
    const lvl = Core.parseLevel(def);
    assert.equal(lvl.cells.length, Core.ROWS);
    assert.ok(lvl.spawn && lvl.exit, def.name);
  });
});

test('parseLevel rejects a malformed row', () => {
  const bad = { ...TITLE, map: [...TITLE.map.slice(0, 17), '###'] };
  assert.throws(() => Core.parseLevel(bad), /row 17 has 3 cols/);
});

test('every level has a solution within its echo budget', () => {
  LEVELS.forEach((def) => {
    const loops = SOLUTIONS[def.name];
    assert.ok(loops, `missing solution for ${def.name}`);
    assert.ok(loops.length - 1 <= def.echoes, `${def.name} needs more echoes than allowed`);
    const { last } = playLoops(Core.parseLevel(def), loops);
    assert.equal(last.status, 'won', def.name);
  });
});

test('a lone jump cannot clear a three-tile wall (stair needs an echo)', () => {
  const { last } = playLoops(level('stair'), [SOLUTIONS.stair[1]]);
  assert.equal(last.status, 'timeout');
});

test('one echo is not enough for the tower', () => {
  const { last } = playLoops(level('tower'), [SOLUTIONS.tower[0], SOLUTIONS.tower[2]]);
  assert.equal(last.status, 'timeout');
});

test('a door stays shut once its plate is released', () => {
  const { last } = playLoops(level('echo'), [SOLUTIONS.echo[1]]);
  assert.equal(last.status, 'timeout');
  assert.equal(last.open.a, false);
});

test('chorus door needs every plate of the group held at once', () => {
  const twoOfThree = [SOLUTIONS.chorus[0], SOLUTIONS.chorus[1], SOLUTIONS.chorus[3]];
  const { last } = playLoops(level('chorus'), twoOfThree);
  assert.notEqual(last.status, 'won');
});

test('standing on a moving echo carries the player', () => {
  const lvl = Core.parseLevel(TITLE);
  const gx = lvl.spawn.x + 40;
  const frames = Array.from({ length: 400 }, (_, i) => ({ x: i < 120 ? gx : gx + 2 * (i - 120), y: lvl.spawn.y, f: 1 }));
  const { rec } = Core.simulate(lvl, [{ frames, end: 'timeout' }], script([[5, 'r'], [10, 'rj'], [8, 'j']]));
  assert.equal(rec.frames[119].y, lvl.spawn.y - Core.P.h);
  assert.equal(rec.frames[200].x - rec.frames[119].x, frames[200].x - frames[119].x);
});

test('an echo moving into a boxed-in player passes through instead of crushing', () => {
  const lvl = Core.parseLevel({
    name: 'closet', time: 5, echoes: 1,
    map: [
      ...Array.from({ length: 15 }, () => '################################'),
      '#####S#.E#######################',
      '################################',
      '################################',
    ],
  });
  const away = { x: lvl.spawn.x - 30, y: lvl.spawn.y, f: 1 };
  const frames = [away, away, away, { x: lvl.spawn.x + 6, y: lvl.spawn.y, f: 1 }];
  const { world } = Core.simulate(lvl, [{ frames, end: 'rewind' }], () => ({ l: false, r: false, j: false }));
  assert.equal(world.status, 'timeout');
});

test('falling into spikes kills', () => {
  const { last } = playLoops(level('wake'), [[[50, 'r'], [20, 'rj'], [60, 'r'], [20, 'rj'], [100, 'r']]]);
  assert.equal(last.status, 'dead');
  assert.equal(last.cause, 'spike');
});

test('step is pure: the input world is never mutated', () => {
  const w0 = Core.createWorld(level('wake'), []);
  const before = JSON.stringify(w0.player);
  const w1 = Core.step(w0, { l: false, r: true, j: true });
  assert.equal(JSON.stringify(w0.player), before);
  assert.notEqual(w1.player.x, w0.player.x);
  assert.ok(Object.isFrozen(w1));
});

test('an echo cut short by a rewind keeps standing where it stopped', () => {
  const lvl = level('chorus');
  const early = Core.simulate(lvl, [], script([[28, 'r']])).rec;
  const cut = Object.freeze({ frames: early.frames.slice(0, 40), end: 'rewind' });
  const [held] = Core.ghostsAt([cut], 300);
  assert.deepEqual(held, cut.frames[39]);
});

test('an echo that died is gone after its death frame', () => {
  const rec = Object.freeze({ frames: [{ x: 1, y: 2, f: 1 }], end: 'dead' });
  assert.deepEqual(Core.ghostsAt([rec], 5), [null]);
});

test('chorus is solvable when the plate-holders rewind early', () => {
  const lvl = level('chorus');
  const echoes = SOLUTIONS.chorus.slice(0, 3).reduce((acc, segs) => {
    const { rec } = Core.simulate(lvl, acc, script(segs));
    const len = segs.reduce((s, [n]) => s + n, 0) + 5;
    return [...acc, Object.freeze({ frames: rec.frames.slice(0, len), end: 'rewind' })];
  }, []);
  const { world } = Core.simulate(lvl, echoes, script(SOLUTIONS.chorus[3]));
  assert.equal(world.status, 'won');
});

// Regression: an echo parked on a plate used to wall off the corridor when the player waited at spawn
// and set off after the echo had walked away (scripts that moved in lockstep never hit this branch).
test('a player who waits before moving walks through a standing echo', () => {
  const lvl = level('echo');
  const { rec } = Core.simulate(lvl, [], script([[34, 'r']]));
  const { world } = Core.simulate(lvl, [rec], script([[90, ''], [300, 'r']]));
  assert.equal(world.status, 'won');
});

test('jumping up through an echo from below still lands on top of it', () => {
  const lvl = Core.parseLevel(TITLE);
  const g = { x: lvl.spawn.x, y: lvl.spawn.y - 40, f: 1 };
  const frames = Array.from({ length: 300 }, (_, i) => (i < 5 ? { x: 400, y: lvl.spawn.y, f: 1 } : g));
  const { rec } = Core.simulate(lvl, [{ frames, end: 'timeout' }], script([[10, ''], [20, 'j']]));
  assert.equal(rec.frames[100].y, g.y - Core.P.h);
});

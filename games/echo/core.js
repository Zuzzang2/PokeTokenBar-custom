// ECHO core simulation: pure, deterministic, renderer-agnostic.
// step(world, input) returns a new world; nothing here touches Phaser or the DOM.
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.EchoCore = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const TILE = 30;
  const COLS = 32;
  const ROWS = 18;
  const FPS = 60;
  const DT = 1 / FPS;
  const P = Object.freeze({
    w: 18, h: 26, speed: 210, accel: 2600, airAccel: 1700,
    gravity: 1800, jump: 560, maxFall: 840, coyote: 6, buffer: 7, cut: 0.45,
  });

  const PLATE_TO_DOOR = Object.freeze({ 1: 'a', 2: 'b', 3: 'c' });

  function parseLevel(def) {
    if (def.map.length !== ROWS) throw new Error(`${def.name}: ${def.map.length} rows, expected ${ROWS}`);
    const cells = [];
    const plates = [];
    const doors = [];
    const spikes = [];
    let spawn = null;
    let exit = null;
    def.map.forEach((row, ty) => {
      if (row.length !== COLS) throw new Error(`${def.name}: row ${ty} has ${row.length} cols`);
      [...row].forEach((ch, tx) => {
        const x = tx * TILE;
        const y = ty * TILE;
        if (ch === 'S') spawn = { x: x + (TILE - P.w) / 2, y: y + TILE - P.h };
        else if (ch === 'E') exit = { tx, ty, x: x + 4, y: y - TILE, w: TILE - 8, h: TILE * 2 };
        else if (ch === '^') spikes.push({ tx, ty, x: x + 4, y: y + 14, w: TILE - 8, h: TILE - 14 });
        else if ('123'.includes(ch)) plates.push({ tx, ty, group: ch, x: x + 3, y: y + TILE - 6, w: TILE - 6, h: 6 });
        else if ('abc'.includes(ch)) doors.push({ tx, ty, group: ch, x, y, w: TILE, h: TILE });
      });
      cells.push(row);
    });
    if (!spawn) throw new Error(`${def.name}: missing spawn S`);
    if (!exit) throw new Error(`${def.name}: missing exit E`);
    return Object.freeze({
      name: def.name, title: def.title, hint: def.hint || '',
      limit: Math.round(def.time * FPS), maxEchoes: def.echoes,
      cells, plates, doors, spikes, spawn, exit,
    });
  }

  const overlap = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
  const boxOf = (o) => ({ x: o.x, y: o.y, w: P.w, h: P.h });
  const isWall = (lvl, tx, ty) => tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS || lvl.cells[ty][tx] === '#';

  function spawnPlayer(lvl) {
    return Object.freeze({
      x: lvl.spawn.x, y: lvl.spawn.y, vx: 0, vy: 0, facing: 1,
      ground: true, ride: -1, coyote: 0, buffer: 0, held: false, cut: false,
    });
  }

  function createWorld(lvl, echoes) {
    return Object.freeze({
      lvl, echoes, frame: 0, player: spawnPlayer(lvl), status: 'play', cause: null,
      solid: echoes.map(() => false), open: doorsOpen(lvl, new Set()), pressed: new Set(),
    });
  }

  // Echo i at frame f. A loop cut short by a rewind leaves its echo standing at the last spot;
  // an echo that died is gone after its death frame.
  function ghostsAt(echoes, f) {
    return echoes.map((rec) => {
      if (f < rec.frames.length) return rec.frames[f];
      return rec.end === 'dead' ? null : rec.frames[rec.frames.length - 1];
    });
  }

  function platesPressed(lvl, bodies) {
    const pressed = new Set();
    lvl.plates.forEach((pl, i) => {
      if (bodies.some((b) => b && overlap(boxOf(b), pl))) pressed.add(i);
    });
    return pressed;
  }

  // A door group opens only while every plate of its group is pressed.
  function doorsOpen(lvl, pressed) {
    const open = {};
    Object.entries(PLATE_TO_DOOR).forEach(([plate, door]) => {
      const group = lvl.plates.map((pl, i) => [pl, i]).filter(([pl]) => pl.group === plate);
      open[door] = group.length > 0 && group.every(([, i]) => pressed.has(i));
    });
    return open;
  }

  function solids(lvl, open, ghostRects, box) {
    const rects = [];
    const tx0 = Math.floor(box.x / TILE) - 1;
    const tx1 = Math.floor((box.x + box.w) / TILE) + 1;
    const ty0 = Math.floor(box.y / TILE) - 1;
    const ty1 = Math.floor((box.y + box.h) / TILE) + 1;
    for (let ty = ty0; ty <= ty1; ty += 1) {
      for (let tx = tx0; tx <= tx1; tx += 1) {
        if (isWall(lvl, tx, ty)) rects.push({ x: tx * TILE, y: ty * TILE, w: TILE, h: TILE, ghost: -1 });
      }
    }
    lvl.doors.forEach((d) => { if (!open[d.group]) rects.push({ ...d, ghost: -1 }); });
    return rects.concat(ghostRects);
  }

  function moveX(p, dx, rects) {
    if (dx === 0) return { x: p.x, hit: false };
    const x = rects.reduce((nx, r) => {
      const b = { x: nx, y: p.y, w: P.w, h: P.h };
      if (!overlap(b, r)) return nx;
      return dx > 0 ? r.x - P.w : r.x + r.w;
    }, p.x + dx);
    return { x, hit: x !== p.x + dx };
  }

  function moveY(p, dy, rects) {
    return rects.reduce((acc, r) => {
      const b = { x: p.x, y: acc.y, w: P.w, h: P.h };
      if (!overlap(b, r)) return acc;
      return dy > 0 ? { y: r.y - P.h, hit: 'down', ride: r.ghost } : { y: r.y + r.h, hit: 'up', ride: -1 };
    }, { y: p.y + dy, hit: null, ride: -1 });
  }

  // Push the player out of anything that moved into it (an echo, a closing door).
  function pushOut(p, rects) {
    return rects.reduce((cur, r) => {
      const b = boxOf(cur);
      if (!overlap(b, r)) return cur;
      const opts = [
        { d: b.y + b.h - r.y, x: cur.x, y: r.y - P.h },
        { d: r.y + r.h - b.y, x: cur.x, y: r.y + r.h },
        { d: b.x + b.w - r.x, x: r.x - P.w, y: cur.y },
        { d: r.x + r.w - b.x, x: r.x + r.w, y: cur.y },
      ];
      const best = opts.reduce((m, o) => (o.d < m.d ? o : m));
      return { ...cur, x: best.x, y: best.y };
    }, p);
  }

  function step(world, input) {
    if (world.status !== 'play') return world;
    const { lvl, echoes } = world;
    const f = world.frame + 1;
    const prevG = ghostsAt(echoes, world.frame);
    const curG = ghostsAt(echoes, f);
    const prevP = world.player;

    const solid = echoes.map((_, i) => world.solid[i]
      || (curG[i] !== null && !overlap(boxOf(prevP), boxOf(curG[i]))));
    const ghostRects = curG
      .map((g, i) => (g && solid[i] ? { x: g.x, y: g.y, w: P.w, h: P.h, ghost: i } : null))
      .filter(Boolean);

    const pressed = platesPressed(lvl, [prevP, ...curG]);
    const open = doorsOpen(lvl, pressed);

    // Ride: carried by the echo we stood on last frame.
    const ridden = prevP.ride >= 0 && prevG[prevP.ride] && curG[prevP.ride] ? prevP.ride : -1;
    const others = (box) => solids(lvl, open, ghostRects.filter((r) => r.ghost !== ridden), box);
    let p = { ...prevP };
    if (ridden >= 0) {
      const dx = curG[ridden].x - prevG[ridden].x;
      const dy = curG[ridden].y - prevG[ridden].y;
      if (dx) p = { ...p, x: moveX(p, dx, others(boxOf(p))).x };
      if (dy) p = { ...p, y: moveY(p, dy, others(boxOf(p))).y };
    }
    p = pushOut(p, solids(lvl, open, ghostRects, boxOf(p)));

    const dir = (input.r ? 1 : 0) - (input.l ? 1 : 0);
    const accel = (p.ground ? P.accel : P.airAccel) * DT;
    const target = dir * P.speed;
    const vx = p.vx < target ? Math.min(target, p.vx + accel) : Math.max(target, p.vx - accel);
    const pressedJump = input.j && !p.held;
    let buffer = pressedJump ? P.buffer : Math.max(0, p.buffer - 1);
    let coyote = p.ground ? P.coyote : Math.max(0, p.coyote - 1);
    let vy = p.vy;
    let cut = p.cut;
    let jumped = false;
    if (buffer > 0 && coyote > 0) {
      vy = -P.jump; buffer = 0; coyote = 0; cut = false; jumped = true;
    }
    if (!input.j && vy < 0 && !cut) { vy *= P.cut; cut = true; }
    vy = Math.min(vy + P.gravity * DT, P.maxFall);

    const mx = moveX(p, vx * DT, solids(lvl, open, ghostRects, boxOf(p)));
    p = { ...p, x: mx.x };
    const my = moveY(p, vy * DT, solids(lvl, open, ghostRects, boxOf(p)));
    const ground = my.hit === 'down';
    p = {
      ...p, y: my.y, vx: mx.hit ? 0 : vx, vy: my.hit ? 0 : vy,
      ground, ride: ground ? my.ride : -1, coyote, buffer, cut,
      held: !!input.j, facing: dir || p.facing,
    };

    const box = boxOf(p);
    const crushed = solids(lvl, open, ghostRects, box).some((r) => overlap(box, r));
    const spiked = lvl.spikes.some((s) => overlap(box, s)) || p.y > ROWS * TILE;
    const won = overlap(box, lvl.exit);
    const status = crushed || spiked ? 'dead' : won ? 'won' : f >= lvl.limit ? 'timeout' : 'play';
    const cause = crushed ? 'paradox' : spiked ? 'spike' : null;
    const player = Object.freeze(p);
    return Object.freeze({
      ...world, frame: f, player, solid, pressed, open, status, cause, jumped,
      landed: ground && !prevP.ground,
    });
  }

  const snapshot = (p) => Object.freeze({ x: p.x, y: p.y, f: p.facing });

  // Run a whole loop with a scripted input source; returns the finished recording + final world.
  function simulate(lvl, echoes, inputAt) {
    let w = createWorld(lvl, echoes);
    const frames = [snapshot(w.player)];
    while (w.status === 'play') {
      w = step(w, inputAt(w.frame));
      frames.push(snapshot(w.player));
    }
    return { world: w, rec: Object.freeze({ frames, end: w.status }) };
  }

  return Object.freeze({
    TILE, COLS, ROWS, FPS, DT, P, PLATE_TO_DOOR,
    parseLevel, createWorld, step, ghostsAt, snapshot, simulate, overlap, boxOf, isWall,
    platesPressed, doorsOpen,
  });
});

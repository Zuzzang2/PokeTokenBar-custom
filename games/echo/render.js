// ECHO drawing helpers. All art is procedural: no image assets.
(function (root) {
  'use strict';

  const { TILE, COLS, ROWS, P, isWall } = root.EchoCore;
  const W = COLS * TILE;
  const H = ROWS * TILE;

  const COLOR = Object.freeze({
    bg: 0x05060f, grid: 0x11163a, wall: 0x0b0e22, wallInner: 0x13183a, edge: 0x4d5bff,
    player: 0x5ff7ff, spike: 0xff3864, plate: 0x3a3f6b, plateLit: 0xffd166,
    door: 0xff4fd8, exit: 0x7dffb2, ink: 0x05060f,
  });
  const ECHO_COLORS = [0xff4fd8, 0xb46bff, 0xffb84f, 0x7dff8a, 0xff6b6b, 0x6bb8ff];
  const echoColor = (i) => ECHO_COLORS[i % ECHO_COLORS.length];

  // Deterministic pseudo-random so the starfield is the same every frame.
  const rand = (seed) => { const x = Math.sin(seed * 9301 + 49297) * 233280; return x - Math.floor(x); };

  function drawStatic(g, lvl) {
    g.clear();
    g.fillStyle(COLOR.bg, 1).fillRect(0, 0, W, H);
    for (let i = 0; i < 90; i += 1) {
      g.fillStyle(0x8fa0ff, 0.08 + rand(i) * 0.25).fillRect(rand(i + 1) * W, rand(i + 2) * H, 1.5, 1.5);
    }
    g.lineStyle(1, COLOR.grid, 0.55);
    for (let x = 0; x <= W; x += TILE) g.lineBetween(x, 0, x, H);
    for (let y = 0; y <= H; y += TILE) g.lineBetween(0, y, W, y);

    for (let ty = 0; ty < ROWS; ty += 1) {
      for (let tx = 0; tx < COLS; tx += 1) {
        if (!isWall(lvl, tx, ty)) continue;
        const x = tx * TILE;
        const y = ty * TILE;
        g.fillStyle(COLOR.wall, 1).fillRect(x, y, TILE, TILE);
        if ((tx + ty) % 2 === 0) g.fillStyle(COLOR.wallInner, 1).fillRect(x + 13, y + 13, 4, 4);
        const open = (dx, dy) => !isWall(lvl, tx + dx, ty + dy);
        if (open(0, -1)) { g.fillStyle(COLOR.edge, 1).fillRect(x, y, TILE, 2); g.fillStyle(COLOR.edge, 0.18).fillRect(x, y + 2, TILE, 6); }
        if (open(0, 1)) g.fillStyle(COLOR.edge, 0.45).fillRect(x, y + TILE - 1, TILE, 1);
        if (open(-1, 0)) g.fillStyle(COLOR.edge, 0.6).fillRect(x, y, 1, TILE);
        if (open(1, 0)) g.fillStyle(COLOR.edge, 0.6).fillRect(x + TILE - 1, y, 1, TILE);
      }
    }
    lvl.spikes.forEach((s) => {
      const x = s.tx * TILE;
      const y = s.ty * TILE;
      g.fillStyle(COLOR.spike, 0.12).fillRect(x, y + 10, TILE, TILE - 10);
      for (let k = 0; k < 3; k += 1) {
        g.fillStyle(COLOR.spike, 1).fillTriangle(x + k * 10, y + TILE, x + k * 10 + 5, y + 12, x + k * 10 + 10, y + TILE);
      }
    });
  }

  function drawDynamic(g, glow, lvl, view, t) {
    lvl.plates.forEach((pl, i) => {
      const lit = view.pressed.has(i);
      g.fillStyle(lit ? COLOR.plateLit : COLOR.plate, 1).fillRect(pl.x, pl.y + (lit ? 3 : 0), pl.w, lit ? 3 : 6);
      g.fillStyle(lit ? COLOR.plateLit : 0x8088c0, lit ? 1 : 0.6).fillRect(pl.x + pl.w / 2 - 3, pl.y + (lit ? 1 : -2), 6, 2);
      if (lit) glow.fillStyle(COLOR.plateLit, 0.18).fillRect(pl.x - 6, pl.y - 14, pl.w + 12, 20);
    });

    lvl.doors.forEach((d) => {
      if (view.open[d.group]) {
        g.lineStyle(1, COLOR.door, 0.25).strokeRect(d.x + 6, d.y + 1, TILE - 12, TILE - 2);
        return;
      }
      g.fillStyle(COLOR.door, 0.22).fillRect(d.x + 4, d.y, TILE - 8, TILE);
      for (let k = 0; k < 3; k += 1) {
        const yy = d.y + ((k * 10 + t * 30) % TILE);
        g.fillStyle(COLOR.door, 0.9).fillRect(d.x + 4, yy, TILE - 8, 2);
      }
      g.fillStyle(COLOR.door, 1).fillRect(d.x + 4, d.y, 2, TILE).fillRect(d.x + TILE - 6, d.y, 2, TILE);
      glow.fillStyle(COLOR.door, 0.08).fillRect(d.x - 2, d.y, TILE + 4, TILE);
    });

    const ex = lvl.exit;
    glow.fillStyle(COLOR.exit, 0.1 + 0.05 * Math.sin(t * 3)).fillRect(ex.x - 8, ex.y - 6, ex.w + 16, ex.h + 6);
    g.lineStyle(2, COLOR.exit, 1).strokeRect(ex.x, ex.y, ex.w, ex.h);
    for (let k = 0; k < 4; k += 1) {
      const p = (t * 0.6 + k / 4) % 1;
      g.fillStyle(COLOR.exit, 0.7 * (1 - p)).fillRect(ex.x + 3, ex.y + ex.h - 4 - p * (ex.h - 8), ex.w - 6, 2);
    }
  }

  function drawBody(g, glow, b, color, alpha) {
    const { x, y } = b;
    glow.fillStyle(color, 0.14 * alpha).fillRect(x - 5, y - 5, P.w + 10, P.h + 10);
    g.fillStyle(color, alpha).fillRect(x, y + 2, P.w, P.h - 2).fillRect(x + 2, y, P.w - 4, 2);
    g.fillStyle(COLOR.ink, alpha).fillRect(x + (b.f > 0 ? 11 : 3), y + 7, 4, 5);
    g.fillStyle(COLOR.ink, 0.35 * alpha).fillRect(x + 2, y + P.h - 5, P.w - 4, 2);
  }

  function drawTrail(g, frames, f, color, alpha) {
    for (let k = 1; k <= 7; k += 1) {
      const fr = frames[f - k * 3];
      if (!fr) break;
      g.fillStyle(color, alpha * (0.22 - k * 0.028)).fillRect(fr.x + 3, fr.y + 3, P.w - 6, P.h - 6);
    }
  }

  // An echo: replaying, holding its last spot after a rewind, or dissolving after its death.
  function drawEcho(g, glow, rec, i, f, alphaScale) {
    const color = echoColor(i);
    const last = rec.frames.length - 1;
    if (f <= last || rec.end !== 'dead') {
      const fr = rec.frames[Math.min(f, last)];
      if (f <= last) drawTrail(g, rec.frames, f, color, alphaScale);
      drawBody(g, glow, fr, color, 0.62 * alphaScale);
      g.fillStyle(color, 0.9 * alphaScale).fillRect(fr.x + P.w / 2 - 1, fr.y - 7, 2, 3);
      return;
    }
    const fade = 1 - (f - last) / 30;
    if (fade <= 0) return;
    const fr = rec.frames[last];
    const tint = COLOR.spike;
    for (let k = 0; k < 8; k += 1) {
      const lift = (1 - fade) * (12 + rand(i * 31 + k) * 30);
      g.fillStyle(tint, fade * 0.8).fillRect(fr.x + rand(k + i) * P.w, fr.y + rand(k * 7 + i) * P.h - lift, 3, 3);
    }
  }

  function drawParticles(g, particles) {
    particles.forEach((p) => g.fillStyle(p.color, Math.max(0, p.life / p.max)).fillRect(p.x, p.y, p.size, p.size));
  }

  function drawHud(g, view) {
    g.fillStyle(0xffffff, 0.06).fillRect(0, 0, W, 4);
    g.fillStyle(view.rewinding ? COLOR.door : COLOR.player, 0.9).fillRect(0, 0, W * view.progress, 4);
    for (let i = 0; i < view.maxEchoes; i += 1) {
      const x = W - 24 - (view.maxEchoes - 1 - i) * 18;
      const used = i < view.echoCount;
      g.fillStyle(used ? echoColor(i) : 0xffffff, used ? 0.95 : 0.15).fillRect(x, 14, 10, 14);
    }
  }

  root.EchoRender = Object.freeze({
    W, H, COLOR, echoColor, drawStatic, drawDynamic, drawBody, drawTrail, drawEcho, drawParticles, drawHud,
  });
})(typeof self !== 'undefined' ? self : this);

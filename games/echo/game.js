// ECHO main scene: title -> play <-> rewind -> clear montage -> ... -> ending.
(function () {
  'use strict';

  const Core = window.EchoCore;
  const R = window.EchoRender;
  const Sound = window.EchoAudio;
  const { TITLE, LEVELS } = window.EchoLevels;
  const { DT, P } = Core;
  const { W, H, COLOR } = R;

  const SAVE_KEY = 'echo-save-v1';
  const FONT = '"Noto Sans KR", "Apple SD Gothic Neo", system-ui, sans-serif';
  const MONO = '"Silkscreen", "Noto Sans KR", monospace';
  const NO_INPUT = Object.freeze({ l: false, r: false, j: false });

  const freshSave = () => ({ level: 0, loops: 0, echoes: 0, visits: 0, titleGhosts: [] });
  function loadSave() {
    try { return { ...freshSave(), ...JSON.parse(localStorage.getItem(SAVE_KEY) || '{}') }; } catch (e) { return freshSave(); }
  }
  function writeSave(save) {
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* storage unavailable: play on without saving */ }
  }
  const pack = (frames) => frames.map((fr) => [Math.round(fr.x), Math.round(fr.y), fr.f]);
  const unpack = (rows) => ({ frames: rows.map(([x, y, f]) => ({ x, y, f })), end: 'title' });

  class EchoScene extends Phaser.Scene {
    constructor() { super('echo'); }

    create() {
      this.back = this.add.graphics();
      this.g = this.add.graphics();
      this.glow = this.add.graphics();
      this.glow.setBlendMode(Phaser.BlendModes.ADD);
      this.fx = this.add.graphics();

      this.tTitle = this.text(18, 14, '', 15, MONO, '#9aa6ff');
      this.tEcho = this.text(W - 18, 32, '', 11, FONT, '#7f88c9').setOrigin(1, 0);
      this.tHint = this.text(W / 2, H - 12, '', 14, FONT, '#aab3ff').setOrigin(0.5, 1);
      this.tGhosts = ['#ff4fd8', '#b46bff', '#5ff7ff'].map((c) => this.text(W / 2, H / 2 - 50, '', 72, MONO, c).setOrigin(0.5));
      this.tBig = this.text(W / 2, H / 2 - 50, '', 72, MONO, '#ffffff').setOrigin(0.5);
      this.tSub = this.text(W / 2, H / 2 + 14, '', 18, FONT, '#cfd6ff').setOrigin(0.5);
      this.tLabels = [0, 1, 2].map(() => this.text(0, 0, '', 11, FONT, '#ff9be9').setOrigin(0.5, 1));
      this.endTexts = [];

      this.keys = this.input.keyboard.addKeys('LEFT,RIGHT,UP,A,D,W,SPACE');
      this.input.keyboard.addCapture('SPACE,UP,DOWN,LEFT,RIGHT,BACKSPACE');
      this.input.keyboard.on('keydown', () => Sound.unlock());
      this.input.keyboard.on('keydown-R', () => this.onRewindKey());
      this.input.keyboard.on('keydown-BACKSPACE', () => this.onErase());
      this.input.keyboard.on('keydown-ESC', () => this.onReset());
      this.input.keyboard.on('keydown-M', () => Sound.toggleMute());
      this.input.on('pointerdown', () => Sound.unlock());
      this.touch = window.EchoTouch || NO_INPUT;
      window.EchoActions = { rewind: () => this.onRewindKey() };
      window.__echo = this; // hook for the automated browser playthrough

      this.setupFilters();

      this.save = loadSave();
      this.particles = [];
      this.acc = 0;
      this.t = 0;
      this.startTitle();
    }

    // Bloom (threshold -> blur -> add) and a slight CRT barrel. WebGL only; canvas falls back to flat.
    setupFilters() {
      try {
        const cam = this.cameras.main;
        const bloom = cam.filters.internal.addParallelFilters();
        bloom.top.addThreshold(0.3, 1);
        bloom.top.addBlur(1, 2, 2, 1.6);
        bloom.blend.blendMode = Phaser.BlendModes.ADD;
        bloom.blend.amount = 1;
        this.barrel = cam.filters.external.addBarrel(1.03);
      } catch (e) {
        this.barrel = null;
      }
    }

    text(x, y, s, size, family, color) {
      const t = this.add.text(x, y, s, { fontFamily: family, fontSize: `${size}px`, color });
      if (t.setResolution) t.setResolution(2);
      return t;
    }

    readInput() {
      const k = this.keys;
      const tc = this.touch;
      return {
        l: k.LEFT.isDown || k.A.isDown || !!tc.l,
        r: k.RIGHT.isDown || k.D.isDown || !!tc.r,
        j: k.SPACE.isDown || k.UP.isDown || k.W.isDown || !!tc.j,
      };
    }

    // ---------- flow ----------

    startTitle() {
      this.mode = 'title';
      this.lvl = Core.parseLevel(TITLE);
      this.echoes = [];
      this.titleGhosts = this.save.titleGhosts.map(unpack);
      this.save = { ...this.save, visits: this.save.visits + 1 };
      writeSave(this.save);
      R.drawStatic(this.back, this.lvl);
      this.beginLoop();
      const returning = this.titleGhosts.length > 0;
      this.tTitle.setText('');
      this.tBig.setText('ECHO').setY(H / 2 - 120);
      this.tSub.setText(returning
        ? '다시 왔구나. 지난번의 너는 아직 여기 있다.'
        : '지나간 너는 사라지지 않는다.').setY(H / 2 - 50).setAlpha(1);
      this.tHint.setText('오른쪽 빛으로 걸어가면 시작      ←→ 이동   SPACE 점프   M 음소거');
      this.tEcho.setText('');
    }

    startLevel(idx, echoes) {
      this.mode = 'play';
      this.levelIdx = idx;
      this.def = LEVELS[idx];
      this.lvl = Core.parseLevel(this.def);
      this.echoes = echoes || [];
      R.drawStatic(this.back, this.lvl);
      this.tTitle.setText(this.def.title);
      this.tHint.setText(this.def.hint);
      this.tBig.setText('').setY(H / 2 - 50);
      this.tSub.setText('').setY(H / 2 + 14);
      this.tLabels.forEach((t) => t.setText(''));
      this.beginLoop();
      this.banner(this.def.title.replace(/^\d+\s+/, ''), 1.4);
    }

    beginLoop() {
      if (this.mode !== 'title') this.mode = 'play';
      this.world = Core.createWorld(this.lvl, this.echoes);
      this.frames = [Core.snapshot(this.world.player)];
      Sound.setVoices(this.echoes.length + (this.mode === 'title' ? this.titleGhosts.length : 0));
      this.updateEchoText();
    }

    updateEchoText() {
      if (this.mode === 'title') return;
      const max = this.lvl.maxEchoes;
      this.tEcho.setText(max === 0 ? 'R 다시 시작' : `메아리 ${this.echoes.length}/${max}    R 되감기  ·  BACKSPACE 지우기  ·  ESC 전부 지우기`);
    }

    banner(msg, seconds) {
      this.tweens.killTweensOf(this.tSub);
      this.tSub.setText(msg).setAlpha(1);
      this.tweens.add({ targets: this.tSub, alpha: 0, delay: seconds * 1000, duration: 600 });
    }

    // Close the current loop: it becomes an echo (if the level allows) and time runs backwards.
    rewind(end, commit) {
      const rec = Object.freeze({ frames: this.frames, end });
      const max = this.lvl.maxEchoes;
      if (commit && max > 0) {
        this.echoes = [...this.echoes, rec].slice(-max);
        Sound.play('echo');
      }
      this.save = { ...this.save, loops: this.save.loops + 1 };
      writeSave(this.save);
      Sound.play('rewind');
      this.rewFrames = this.frames;
      this.rf = this.frames.length - 1;
      this.rewSpeed = Math.max(4, this.rf / 40);
      this.mode = 'rewind';
      this.updateEchoText();
    }

    onRewindKey() {
      if (this.mode === 'play') this.rewind('rewind', true);
      else if (this.mode === 'ending' && this.endT > this.endDone) {
        this.save = { ...this.save, level: 0, echoes: 0 };
        writeSave(this.save);
        this.clearEnding();
        this.startTitle();
      }
    }

    onErase() {
      if (this.mode !== 'play' || this.echoes.length === 0) return;
      this.echoes = this.echoes.slice(0, -1);
      Sound.play('erase');
      this.rewind('rewind', false);
    }

    onReset() {
      if (this.mode !== 'play') return;
      this.echoes = [];
      this.rewind('rewind', false);
    }

    onWin() {
      Sound.play('win');
      this.cameras.main.flash(250, 125, 255, 178);
      this.burst(this.world.player, COLOR.exit, 40);
      if (this.mode === 'title') {
        const titleGhosts = [...this.save.titleGhosts, pack(this.frames)].slice(-3);
        this.save = { ...this.save, titleGhosts };
        writeSave(this.save);
        this.tSub.setY(H / 2 + 14);
        this.startLevel(this.save.level < LEVELS.length ? this.save.level : 0);
        return;
      }
      this.montage = [...this.echoes, Object.freeze({ frames: this.frames, end: 'won' })];
      this.montageLen = Math.max(...this.montage.map((r) => r.frames.length));
      this.mf = 0;
      this.mode = 'clear';
      this.save = { ...this.save, level: this.levelIdx + 1, echoes: this.save.echoes + this.echoes.length };
      writeSave(this.save);
      Sound.setVoices(this.montage.length);
      this.tweens.killTweensOf(this.tSub);
      this.tBig.setText('LOOP CLOSED');
      this.tSub.setAlpha(1).setText(this.echoes.length === 0
        ? '혼자서.'
        : `${this.echoes.length}명의 지나간 너와 함께.`);
    }

    finishClear() {
      this.tBig.setText('');
      this.tSub.setText('');
      const next = this.levelIdx + 1;
      if (next < LEVELS.length) this.startLevel(next);
      else this.startEnding();
    }

    // ---------- loop ----------

    update(time, delta) {
      this.t += delta / 1000;
      this.acc = Math.min(this.acc + delta / 1000, 0.25);
      while (this.acc >= DT) {
        this.acc -= DT;
        this.tick();
      }
      document.body.classList.toggle('rewinding', this.mode === 'rewind');
      if (this.barrel) this.barrel.amount = this.mode === 'rewind' ? 1.1 + 0.04 * Math.sin(this.t * 30) : 1.03;
      this.draw();
    }

    tick() {
      this.particles = this.particles
        .map((p) => ({ ...p, x: p.x + p.vx * DT, y: p.y + p.vy * DT, vy: p.vy + p.g * DT, life: p.life - DT }))
        .filter((p) => p.life > 0);

      if (this.mode === 'play' || this.mode === 'title') this.tickPlay();
      else if (this.mode === 'dying') {
        this.wait -= 1;
        if (this.wait <= 0) this.rewind('dead', true);
      } else if (this.mode === 'rewind') {
        this.rf = Math.max(0, this.rf - this.rewSpeed);
        if (this.rf === 0) this.beginLoop();
      } else if (this.mode === 'clear') {
        this.mf += 2;
        if (this.mf > this.montageLen + 50) this.finishClear();
      } else if (this.mode === 'ending') {
        this.tickEnding();
      }
    }

    tickPlay() {
      const prev = this.world;
      const w = Core.step(prev, this.readInput());
      this.world = w;
      this.frames.push(Core.snapshot(w.player));
      if (w.jumped) Sound.play('jump');
      if (w.landed) { Sound.play('land'); this.dust(w.player); }
      if (w.pressed.size > prev.pressed.size) Sound.play('plate');
      Object.keys(w.open).forEach((k) => {
        if (w.open[k] && !prev.open[k]) Sound.play('door');
        if (!w.open[k] && prev.open[k]) Sound.play('doorShut');
      });

      if (w.status === 'won') this.onWin();
      else if (w.status === 'dead') this.onDeath(w);
      else if (w.status === 'timeout') {
        if (this.mode === 'title') this.beginLoop();
        else this.rewind('timeout', true);
      }
    }

    onDeath(w) {
      const crush = w.cause === 'crush';
      Sound.play(crush ? 'crush' : 'death');
      this.cameras.main.shake(crush ? 450 : 200, crush ? 0.014 : 0.006);
      if (crush) {
        this.cameras.main.flash(180, 255, 79, 216);
        this.banner('닫히는 문에 끼였다', 1.6);
      }
      this.burst(w.player, crush ? COLOR.door : COLOR.spike, 34);
      this.mode = 'dying';
      this.wait = 40;
    }

    // ---------- particles ----------

    burst(b, color, n) {
      const spawned = Array.from({ length: n }, (_, i) => {
        const a = (i / n) * Math.PI * 2 + Math.random() * 0.4;
        const sp = 80 + Math.random() * 220;
        return {
          x: b.x + P.w / 2, y: b.y + P.h / 2, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60,
          g: 500, life: 0.6 + Math.random() * 0.5, max: 1.1, size: 2 + Math.random() * 3, color,
        };
      });
      this.particles = [...this.particles, ...spawned];
    }

    dust(b) {
      const spawned = Array.from({ length: 6 }, (_, i) => ({
        x: b.x + P.w / 2, y: b.y + P.h - 2, vx: (i - 2.5) * 30, vy: -20 - Math.random() * 30,
        g: 120, life: 0.3, max: 0.3, size: 2, color: COLOR.player,
      }));
      this.particles = [...this.particles, ...spawned];
    }

    // ---------- drawing ----------

    draw() {
      const { g, glow, fx } = this;
      g.clear(); glow.clear(); fx.clear();
      if (this.mode === 'ending') { this.drawEnding(); return; }

      const f = this.viewFrame();
      const bodies = Core.ghostsAt(this.echoes, Math.floor(f));
      const playerFrame = this.viewPlayer(f);
      const pressed = this.mode === 'play' || this.mode === 'title' || this.mode === 'dying'
        ? this.world.pressed : Core.platesPressed(this.lvl, [playerFrame, ...bodies]);
      const open = Core.doorsOpen(this.lvl, pressed);
      R.drawDynamic(g, glow, this.lvl, { pressed, open }, this.t);

      const echoes = this.mode === 'clear' ? this.montage : this.echoes;
      echoes.forEach((rec, i) => R.drawEcho(g, glow, rec, i, Math.floor(f), this.mode === 'clear' ? 1 : 0.9));
      if (this.mode === 'title') this.drawTitleGhosts(g, glow);
      this.tGhosts.forEach((t, i) => {
        const on = this.mode === 'title';
        const lag = Math.sin(this.t * 1.3 - i * 0.5);
        t.setText(on ? this.tBig.text : '').setPosition(W / 2 + lag * (10 + i * 10), this.tBig.y).setAlpha(on ? 0.35 - i * 0.08 : 0);
      });

      if (playerFrame && this.mode !== 'clear') {
        const source = this.mode === 'rewind' ? this.rewFrames : this.frames;
        const color = this.mode === 'rewind' ? 0xffffff : COLOR.player;
        R.drawTrail(g, source, Math.floor(f), color, 1);
        if (this.mode !== 'dying') R.drawBody(g, glow, playerFrame, color, 1);
      }

      R.drawParticles(fx, this.particles);
      if (this.mode !== 'title') {
        R.drawHud(fx, {
          progress: Math.min(1, f / this.lvl.limit), rewinding: this.mode === 'rewind',
          maxEchoes: this.lvl.maxEchoes, echoCount: this.echoes.length,
        });
      }
      if (this.mode === 'rewind') this.drawRewindLines(fx);
    }

    viewFrame() {
      if (this.mode === 'rewind') return this.rf;
      if (this.mode === 'clear') return this.mf;
      return this.world.frame;
    }

    viewPlayer(f) {
      if (this.mode === 'rewind') return this.rewFrames[Math.floor(f)];
      return this.world.player;
    }

    drawTitleGhosts(g, glow) {
      this.titleGhosts.forEach((rec, i) => {
        const fr = rec.frames[this.world.frame % rec.frames.length];
        R.drawTrail(g, rec.frames, this.world.frame % rec.frames.length, R.echoColor(i), 0.8);
        R.drawBody(g, glow, fr, R.echoColor(i), 0.5);
        this.tLabels[i].setText(i === this.titleGhosts.length - 1 ? '지난번의 너' : '그 전의 너')
          .setPosition(fr.x + P.w / 2, fr.y - 8).setAlpha(0.8);
      });
    }

    drawRewindLines(fx) {
      for (let k = 0; k < 6; k += 1) {
        const y = (this.t * 900 + k * 97) % H;
        fx.fillStyle(0xffffff, 0.05).fillRect(0, y, W, 2 + (k % 3));
      }
      fx.fillStyle(COLOR.door, 0.9).fillRect(W / 2 - 22, 40, 10, 22).fillRect(W / 2 - 6, 40, 10, 22);
      fx.fillStyle(COLOR.door, 0.9).fillTriangle(W / 2 + 10, 51, W / 2 + 26, 40, W / 2 + 26, 62);
      fx.fillTriangle(W / 2 + 26, 51, W / 2 + 42, 40, W / 2 + 42, 62);
    }

    // ---------- ending ----------

    startEnding() {
      this.mode = 'ending';
      this.endT = 0;
      this.back.clear();
      this.back.fillStyle(COLOR.bg, 1).fillRect(0, 0, W, H);
      [this.tTitle, this.tEcho, this.tHint, this.tBig, this.tSub].forEach((t) => t.setText(''));
      const loops = this.save.loops;
      const echoes = this.save.echoes;
      this.starCount = Math.max(1, echoes);
      this.starsShown = 0;
      const lines = [
        [1.0, `너는 ${loops}번 시간을 되감았다.`],
        [4.0, `${echoes}명의 네가 발판 위에 서 있었고, 구덩이에 남았고, 누군가의 계단이 되었다.`],
        [8.0, '그들 중 누구도 출구에 닿지 못했다.'],
        [11.0, '그리고 그들 모두가 너를 여기까지 데려왔다.'],
      ];
      this.endTexts = lines.map(([at, s], i) => {
        const t = this.text(W / 2, 120 + i * 44, s, 20, FONT, '#e6e9ff').setOrigin(0.5).setAlpha(0);
        this.tweens.add({ targets: t, alpha: 1, delay: at * 1000, duration: 1400 });
        return t;
      });
      const title = this.text(W / 2, H - 120, 'ECHO', 56, MONO, '#ffffff').setOrigin(0.5).setAlpha(0);
      const coda = this.text(W / 2, H - 70, '지나간 시도는 실패가 아니다. 발판이다.        R 처음부터', 15, FONT, '#9aa6ff').setOrigin(0.5).setAlpha(0);
      this.endDone = 15.5;
      this.tweens.add({ targets: [title, coda], alpha: 1, delay: this.endDone * 1000, duration: 2000 });
      this.endTexts = [...this.endTexts, title, coda];
      Sound.setVoices(0);
    }

    tickEnding() {
      this.endT += DT;
      const due = this.endT < 4 ? 0 : Math.min(this.starCount, Math.floor((this.endT - 4) / 0.22));
      if (due > this.starsShown) {
        Sound.play('star', this.starsShown);
        this.starsShown = due;
        Sound.setVoices(Math.min(6, due));
      }
    }

    drawEnding() {
      const { g, glow } = this;
      for (let i = 0; i < this.starsShown; i += 1) {
        const x = 60 + ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1 * (W - 120);
        const y = 300 + ((Math.sin(i * 78.233) * 12345.678) % 1 + 1) % 1 * 110;
        const tw = 0.6 + 0.4 * Math.sin(this.t * 2 + i);
        const c = R.echoColor(i);
        glow.fillStyle(c, 0.18 * tw).fillCircle(x, y, 10);
        g.fillStyle(c, tw).fillRect(x - 2, y - 2, 4, 4);
      }
    }

    clearEnding() {
      this.endTexts.forEach((t) => t.destroy());
      this.endTexts = [];
    }
  }

  function boot() {
    new Phaser.Game({
      type: Phaser.AUTO,
      parent: 'game',
      width: W,
      height: H,
      backgroundColor: '#05060f',
      scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
      scene: [EchoScene],
    });
  }

  // Fonts load lazily, so request them explicitly before any Phaser text is rasterized.
  const fontsReady = document.fonts && document.fonts.load
    ? Promise.all(['72px "Silkscreen"', '16px "Noto Sans KR"'].map((f) => document.fonts.load(f)))
    : Promise.resolve();
  Promise.race([fontsReady, new Promise((r) => setTimeout(r, 2500))]).catch(() => {}).then(boot);
})();

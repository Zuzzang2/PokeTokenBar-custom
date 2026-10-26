// ECHO audio: every sound is synthesized. Each echo on screen adds one polyrhythmic voice to the music.
(function (root) {
  'use strict';

  const SCALE = [0, 3, 5, 7, 10, 12, 15];
  const PROGRESSION = [0, -4, 3, -2];
  const PERIODS = [3, 5, 7, 4, 6, 9];
  const STEP = 0.15;
  const hz = (semi) => 110 * Math.pow(2, semi / 12);

  function createAudio() {
    let ctx = null;
    let master = null;
    let muted = false;
    let voices = 0;
    let step = 0;
    let nextTime = 0;

    function tone(freq, dur, opts = {}) {
      if (!ctx) return;
      const { type = 'square', vol = 0.12, slide = null, at = ctx.currentTime, attack = 0.005 } = opts;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, at);
      if (slide) osc.frequency.exponentialRampToValueAtTime(slide, at + dur);
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(vol, at + attack);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + dur);
      osc.connect(gain).connect(master);
      osc.start(at);
      osc.stop(at + dur + 0.05);
    }

    function noise(dur, vol) {
      if (!ctx) return;
      const len = Math.floor(ctx.sampleRate * dur);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < len; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
      const src = ctx.createBufferSource();
      const gain = ctx.createGain();
      gain.gain.value = vol;
      src.buffer = buf;
      src.connect(gain).connect(master);
      src.start();
    }

    function scheduleStep(s, at) {
      const root = PROGRESSION[Math.floor(s / 16) % PROGRESSION.length];
      if (s % 16 === 0) {
        tone(hz(root - 12), STEP * 16, { type: 'triangle', vol: 0.07, at, attack: 0.4 });
        tone(hz(root + 7 - 12), STEP * 16, { type: 'sine', vol: 0.035, at, attack: 0.6 });
      }
      if (s % 8 === 4) tone(hz(root + 24), 0.05, { type: 'square', vol: 0.012, at });
      for (let k = 0; k < voices; k += 1) {
        const period = PERIODS[k % PERIODS.length];
        if (s % period !== 0) continue;
        const idx = (Math.floor(s / period) + k * 2) % SCALE.length;
        const octave = 12 * (1 + (k % 3));
        tone(hz(root + SCALE[idx] + octave), 0.35, {
          type: k % 2 ? 'triangle' : 'sine', vol: 0.045 / (1 + k * 0.15), at,
        });
      }
    }

    function tick() {
      if (!ctx || muted) return;
      while (nextTime < ctx.currentTime + 0.12) {
        scheduleStep(step, nextTime);
        step += 1;
        nextTime += STEP;
      }
    }

    const sounds = {
      jump: () => tone(380, 0.12, { slide: 620, vol: 0.06 }),
      land: () => tone(140, 0.06, { type: 'triangle', vol: 0.08 }),
      plate: () => tone(660, 0.08, { type: 'triangle', vol: 0.1 }),
      door: () => { tone(220, 0.25, { slide: 440, vol: 0.06, type: 'sawtooth' }); },
      doorShut: () => tone(300, 0.2, { slide: 120, vol: 0.06, type: 'sawtooth' }),
      death: () => { noise(0.35, 0.25); tone(200, 0.4, { slide: 40, vol: 0.12, type: 'sawtooth' }); },
      crush: () => { noise(0.6, 0.3); tone(90, 0.6, { slide: 1200, vol: 0.1, type: 'sawtooth' }); },
      rewind: () => tone(1200, 0.55, { slide: 90, vol: 0.07, type: 'sawtooth' }),
      echo: () => [0, 4, 7].forEach((s, i) => tone(hz(s + 24), 0.5, { type: 'sine', vol: 0.06, at: ctx.currentTime + i * 0.06 })),
      erase: () => tone(500, 0.2, { slide: 200, vol: 0.06, type: 'triangle' }),
      win: () => [0, 3, 7, 10, 12, 15, 19].forEach((s, i) => tone(hz(s + 12), 0.9, { type: 'triangle', vol: 0.07, at: ctx.currentTime + i * 0.07 })),
      star: (i) => tone(hz(SCALE[i % SCALE.length] + 24 + 12 * (Math.floor(i / SCALE.length) % 2)), 1.2, { type: 'sine', vol: 0.05 }),
    };

    return Object.freeze({
      unlock() {
        if (!ctx) {
          const Ctor = root.AudioContext || root.webkitAudioContext;
          if (!Ctor) return;
          ctx = new Ctor();
          const comp = ctx.createDynamicsCompressor();
          master = ctx.createGain();
          master.gain.value = 0.55;
          master.connect(comp).connect(ctx.destination);
          nextTime = ctx.currentTime + 0.05;
          setInterval(tick, 30);
        }
        if (ctx.state === 'suspended') ctx.resume();
      },
      play(name, arg) { if (ctx && !muted && sounds[name]) sounds[name](arg); },
      setVoices(n) { voices = n; },
      toggleMute() {
        muted = !muted;
        if (ctx) master.gain.value = muted ? 0 : 0.55;
        if (!muted && ctx) nextTime = ctx.currentTime + 0.05;
        return muted;
      },
    });
  }

  root.EchoAudio = createAudio();
})(typeof self !== 'undefined' ? self : this);

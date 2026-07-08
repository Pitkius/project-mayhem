/* Procedūriniai garso efektai — Web Audio API, be išorinių failų */
window.MgAudio = (() => {
  let ctx = null;
  let master = null;
  let ambient = null;
  let ambientDrug = null;
  let unlocked = false;

  const PROFILES = {
    thc:      { base: 220, wave: 'sine',   detune: 4 },
    alcohol:  { base: 140, wave: 'triangle', detune: 8 },
    vape:     { base: 480, wave: 'sine',   detune: 12 },
    weed:     { base: 180, wave: 'sine',   detune: 6 },
    heroin:   { base: 95,  wave: 'sawtooth', detune: 3 },
    meth:     { base: 620, wave: 'square', detune: 18 },
    pills:    { base: 320, wave: 'triangle', detune: 5 },
    mushroom: { base: 260, wave: 'sine',   detune: 9 },
    cocaine:  { base: 400, wave: 'sine',   detune: 2 },
    amp:      { base: 280, wave: 'square', detune: 14 },
    default:  { base: 200, wave: 'sine',   detune: 5 },
  };

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.42;
    master.connect(ctx.destination);
    return ctx;
  }

  function unlock() {
    const c = ensure();
    if (!c || unlocked) return;
    if (c.state === 'suspended') c.resume();
    unlocked = true;
  }

  function tone(freq, dur, type, gain, when) {
    const c = ensure();
    if (!c) return;
    const t0 = when || c.currentTime;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g);
    g.connect(master);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  function noise(dur, gain, filterFreq) {
    const c = ensure();
    if (!c) return;
    const t0 = c.currentTime;
    const len = Math.floor(c.sampleRate * dur);
    const buf = c.createBuffer(1, len, c.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i += 1) data[i] = (Math.random() * 2 - 1) * 0.85;
    const src = c.createBufferSource();
    src.buffer = buf;
    const g = c.createGain();
    const filt = c.createBiquadFilter();
    filt.type = 'bandpass';
    filt.frequency.value = filterFreq || 1200;
    filt.Q.value = 0.7;
    g.gain.setValueAtTime(gain, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(filt);
    filt.connect(g);
    g.connect(master);
    src.start(t0);
    src.stop(t0 + dur);
  }

  const SFX = {
    open() {
      unlock();
      tone(180, 0.18, 'sine', 0.12);
      tone(360, 0.22, 'sine', 0.08, ensure().currentTime + 0.06);
    },
    close() {
      tone(280, 0.12, 'sine', 0.06);
      tone(140, 0.2, 'sine', 0.05, ensure().currentTime + 0.04);
    },
    success() {
      unlock();
      const t = ensure().currentTime;
      [523, 659, 784].forEach((f, i) => tone(f, 0.28, 'sine', 0.1 - i * 0.02, t + i * 0.07));
    },
    fail() {
      unlock();
      const t = ensure().currentTime;
      tone(180, 0.35, 'sawtooth', 0.12, t);
      tone(120, 0.4, 'sawtooth', 0.08, t + 0.1);
    },
    click() {
      unlock();
      tone(800 + Math.random() * 200, 0.04, 'square', 0.04);
    },
    tap() {
      unlock();
      tone(420, 0.06, 'triangle', 0.07);
      noise(0.04, 0.03, 900);
    },
    pour() {
      unlock();
      noise(0.35, 0.06, 600 + Math.random() * 400);
    },
    press() {
      unlock();
      tone(90, 0.14, 'square', 0.1);
      noise(0.08, 0.05, 400);
    },
    steam() {
      unlock();
      noise(0.5, 0.04, 1800 + Math.random() * 600);
    },
    bubble() {
      unlock();
      tone(300 + Math.random() * 120, 0.12, 'sine', 0.05);
    },
    seal() {
      unlock();
      noise(0.15, 0.08, 2200);
      tone(1200, 0.08, 'sine', 0.04);
    },
    drop() {
      unlock();
      tone(520, 0.08, 'sine', 0.06);
      tone(260, 0.12, 'sine', 0.04, ensure().currentTime + 0.05);
    },
    gauge_tick() {
      unlock();
      tone(640, 0.02, 'sine', 0.02);
    },
    synth() {
      unlock();
      const t = ensure().currentTime;
      tone(440, 0.15, 'sine', 0.05, t);
      tone(554, 0.15, 'sine', 0.04, t + 0.08);
    },
    scrape() {
      unlock();
      noise(0.12, 0.05, 2500);
    },
    whoosh() {
      unlock();
      noise(0.2, 0.04, 800);
    },
  };

  function play(name, opts) {
    const fn = SFX[name];
    if (typeof fn === 'function') fn(opts);
  }

  function stopAmbient() {
    if (!ambient) return;
    try {
      const t = ctx ? ctx.currentTime : 0;
      ambient.gain.gain.cancelScheduledValues(t);
      ambient.gain.gain.setValueAtTime(ambient.gain.gain.value, t);
      ambient.gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.4);
      ambient.osc.stop(t + 0.45);
      ambient.noise.stop(t + 0.45);
    } catch (_) { /* ignore */ }
    ambient = null;
    ambientDrug = null;
  }

  function ambientFor(drug) {
    const c = ensure();
    if (!c) return;
    unlock();
    const key = String(drug || 'default').toLowerCase();
    if (ambientDrug === key) return;
    stopAmbient();
    const p = PROFILES[key] || PROFILES.default;
    const t0 = c.currentTime;
    const osc = c.createOscillator();
    const noiseSrc = c.createBufferSource();
    const len = Math.floor(c.sampleRate * 2);
    const buf = c.createBuffer(1, len, c.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i += 1) d[i] = (Math.random() * 2 - 1) * 0.35;
    noiseSrc.buffer = buf;
    noiseSrc.loop = true;
    const ng = c.createGain();
    const og = c.createGain();
    const mix = c.createGain();
    const filt = c.createBiquadFilter();
    filt.type = 'lowpass';
    filt.frequency.value = p.base * 2.2;
    osc.type = p.wave;
    osc.frequency.setValueAtTime(p.base, t0);
    osc.detune.setValueAtTime(p.detune * 10, t0);
    og.gain.value = 0.018;
    ng.gain.value = 0.012;
    mix.gain.value = 0.55;
    osc.connect(og);
    noiseSrc.connect(filt);
    filt.connect(ng);
    og.connect(mix);
    ng.connect(mix);
    mix.connect(master);
    osc.start(t0);
    noiseSrc.start(t0);
    ambient = { osc, noise: noiseSrc, gain: mix };
    ambientDrug = key;
  }

  document.addEventListener('keydown', unlock, { once: true });
  document.addEventListener('pointerdown', unlock, { once: true });

  return { play, ambientFor, stopAmbient, unlock, SFX };
})();

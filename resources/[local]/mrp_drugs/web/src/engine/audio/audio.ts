import type { DrugTheme } from '@/config/drugThemes';

// Lightweight WebAudio SFX engine. Uses synthesized tones + filtered noise so
// the workstation has an audio identity without shipping large audio assets.
// All nodes are tracked and torn down on stop() to avoid leaks / overlap.
//
// PLACEHOLDER NOTE: These are synthesized sounds. Real .webm/.ogg SFX can be
// dropped into web/src/assets/audio/ later and wired via loadSample().

type SfxName =
  | 'click'
  | 'place'
  | 'pour'
  | 'valve'
  | 'seal'
  | 'warn'
  | 'success'
  | 'fail'
  | 'tick';

class AudioEngine {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private ambient: {
    nodes: OscillatorNode[];
    gains: GainNode[];
    lfos: OscillatorNode[];
    noise?: AudioBufferSourceNode;
  } | null = null;
  private enabled = true;
  private volume = 0.5;

  private ensure(): AudioContext | null {
    if (!this.enabled) return null;
    if (!this.ctx) {
      try {
        const Ctor =
          window.AudioContext ||
          (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        this.ctx = new Ctor();
        this.master = this.ctx.createGain();
        this.master.gain.value = this.volume;
        this.master.connect(this.ctx.destination);
      } catch {
        this.enabled = false;
        return null;
      }
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
    return this.ctx;
  }

  setVolume(v: number) {
    this.volume = Math.max(0, Math.min(1, v));
    if (this.master) this.master.gain.value = this.volume;
  }

  setEnabled(on: boolean) {
    this.enabled = on;
    if (!on) this.stopAll();
  }

  private tone(freq: number, dur: number, type: OscillatorType, gain: number, slideTo?: number) {
    const ctx = this.ensure();
    if (!ctx || !this.master) return;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, ctx.currentTime + dur);
    g.gain.setValueAtTime(0.0001, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(gain, ctx.currentTime + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + dur);
    osc.connect(g);
    g.connect(this.master);
    osc.start();
    osc.stop(ctx.currentTime + dur + 0.02);
  }

  private noise(dur: number, gain: number, freq: number) {
    const ctx = this.ensure();
    if (!ctx || !this.master) return;
    const buf = ctx.createBuffer(1, ctx.sampleRate * dur, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
    const src = ctx.createBufferSource();
    src.buffer = buf;
    const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.value = gain;
    src.connect(bp);
    bp.connect(g);
    g.connect(this.master);
    src.start();
  }

  play(name: SfxName) {
    switch (name) {
      case 'click':
        return this.tone(520, 0.05, 'square', 0.12);
      case 'tick':
        return this.tone(880, 0.03, 'sine', 0.08);
      case 'place':
        return this.tone(180, 0.12, 'sine', 0.18, 90);
      case 'pour':
        return this.noise(0.35, 0.06, 620);
      case 'valve':
        return this.tone(300, 0.18, 'sawtooth', 0.1, 140);
      case 'seal':
        return this.noise(0.25, 0.1, 1200);
      case 'warn':
        this.tone(440, 0.12, 'square', 0.14);
        return;
      case 'success':
        this.tone(523, 0.12, 'sine', 0.16);
        setTimeout(() => this.tone(659, 0.12, 'sine', 0.16), 90);
        setTimeout(() => this.tone(784, 0.2, 'sine', 0.18), 180);
        return;
      case 'fail':
        this.tone(220, 0.25, 'sawtooth', 0.16, 110);
        return;
    }
  }

  startAmbient(kind: DrugTheme['ambient'] = 'hum') {
    const ctx = this.ensure();
    if (!ctx || !this.master || this.ambient) return;

    const nodes: OscillatorNode[] = [];
    const gains: GainNode[] = [];
    const lfos: OscillatorNode[] = [];

    const addTone = (freq: number, vol: number, type: OscillatorType, lfoHz = 0.25, lfoDepth = 0.012) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      osc.type = type;
      osc.frequency.value = freq;
      gain.gain.value = vol;
      lfo.frequency.value = lfoHz;
      lfoGain.gain.value = lfoDepth;
      lfo.connect(lfoGain);
      lfoGain.connect(gain.gain);
      osc.connect(gain);
      gain.connect(this.master!);
      osc.start();
      lfo.start();
      nodes.push(osc);
      gains.push(gain);
      lfos.push(lfo);
    };

    switch (kind) {
      case 'bubble':
        addTone(88, 0.028, 'sine', 0.18, 0.01);
        addTone(176, 0.012, 'triangle', 0.35, 0.006);
        break;
      case 'organic':
        addTone(52, 0.03, 'sine', 0.12, 0.008);
        addTone(104, 0.01, 'triangle', 0.22, 0.004);
        break;
      case 'drip':
        addTone(70, 0.032, 'sine', 0.08, 0.018);
        break;
      case 'static':
        addTone(120, 0.008, 'sawtooth', 1.2, 0.004);
        break;
      case 'fan':
        addTone(95, 0.022, 'sine', 0.45, 0.008);
        addTone(190, 0.006, 'triangle', 0.9, 0.003);
        break;
      case 'crackle':
        addTone(58, 0.025, 'square', 0.5, 0.02);
        addTone(116, 0.01, 'sawtooth', 0.7, 0.01);
        break;
      case 'hum':
      default:
        addTone(62, 0.035, 'sine', 0.25, 0.015);
        break;
    }

    let noise: AudioBufferSourceNode | undefined;
    if (kind === 'static' || kind === 'fan') {
      const buf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
      const data = buf.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * 0.15;
      noise = ctx.createBufferSource();
      noise.buffer = buf;
      noise.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = kind === 'fan' ? 420 : 900;
      const g = ctx.createGain();
      g.gain.value = kind === 'fan' ? 0.012 : 0.006;
      noise.connect(bp);
      bp.connect(g);
      g.connect(this.master);
      noise.start();
    }

    this.ambient = { nodes, gains, lfos, noise };
  }

  stopAmbient() {
    if (!this.ambient) return;
    try {
      this.ambient.nodes.forEach((n) => n.stop());
      this.ambient.lfos.forEach((n) => n.stop());
      this.ambient.noise?.stop();
    } catch {
      /* ignore */
    }
    this.ambient = null;
  }

  stopAll() {
    this.stopAmbient();
  }

  dispose() {
    this.stopAll();
    if (this.ctx) {
      void this.ctx.close();
      this.ctx = null;
      this.master = null;
    }
  }
}

export const Audio = new AudioEngine();

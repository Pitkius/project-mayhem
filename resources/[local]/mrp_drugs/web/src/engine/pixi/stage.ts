import { Application, Container } from 'pixi.js';

// Fixed design resolution. Every interactive point / object is authored in
// these coordinates and the whole world is uniformly scaled + letterboxed to
// the actual canvas size. This keeps hit targets aligned across 1080p, 1440p,
// 4K, 1366x768 and ultrawide (the brief's responsive requirement).
export const DESIGN_W = 1280;
export const DESIGN_H = 720;

export class PixiStage {
  app: Application | null = null;
  /** World container: author content here in DESIGN_W x DESIGN_H space. */
  world = new Container();
  private ro: ResizeObserver | null = null;
  private host: HTMLElement | null = null;
  private tickFns = new Set<(dtMs: number) => void>();
  private destroyed = false;

  async init(host: HTMLElement) {
    this.host = host;
    const app = new Application();
    await app.init({
      antialias: true,
      backgroundAlpha: 0,
      resolution: Math.min(window.devicePixelRatio || 1, 2),
      autoDensity: true,
      powerPreference: 'high-performance',
      resizeTo: host,
    });
    if (this.destroyed) {
      app.destroy(true, { children: true, texture: true });
      return;
    }
    this.app = app;
    host.appendChild(app.canvas);
    app.stage.addChild(this.world);

    this.layout();
    this.ro = new ResizeObserver(() => this.layout());
    this.ro.observe(host);

    app.ticker.add((ticker) => {
      const dt = ticker.deltaMS;
      this.tickFns.forEach((fn) => fn(dt));
    });
  }

  private layout() {
    if (!this.app || !this.host) return;
    const w = this.host.clientWidth || DESIGN_W;
    const h = this.host.clientHeight || DESIGN_H;
    const scale = Math.min(w / DESIGN_W, h / DESIGN_H);
    this.world.scale.set(scale);
    this.world.position.set((w - DESIGN_W * scale) / 2, (h - DESIGN_H * scale) / 2);
  }

  onTick(fn: (dtMs: number) => void): () => void {
    this.tickFns.add(fn);
    return () => this.tickFns.delete(fn);
  }

  /** Remove everything authored in the world without tearing down the app. */
  clearWorld() {
    this.world.removeChildren().forEach((c) => c.destroy({ children: true }));
    this.tickFns.clear();
  }

  destroy() {
    this.destroyed = true;
    this.tickFns.clear();
    if (this.ro) {
      this.ro.disconnect();
      this.ro = null;
    }
    if (this.app) {
      this.app.destroy(true, { children: true, texture: true, textureSource: true });
      this.app = null;
    }
    this.host = null;
  }
}

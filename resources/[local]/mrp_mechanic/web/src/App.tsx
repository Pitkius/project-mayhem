import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import gsap from 'gsap';
import type {
  BodyModCategory, BodyVariant, InstallState, OpenWorkshopPayload,
  PerformanceCategory, PerformancePart, StatKey, WorkshopSection,
} from './types';
import { SECTIONS } from './types';
import { fetchNui, itemImageUrl } from './nui';
import { mergeStatKeys, statsForPart } from './stats';
import './styles.css';

const PERF_ICONS: Record<string, string> = {
  engine: '⚙', brakes: '🛑', transmission: '⚡', suspension: '🔩', armor: '🛡', turbo: '💨',
};

function colorForIndex(i: number) {
  const h = (i * 2.27) % 360;
  const s = i < 20 ? 8 : i < 40 ? 15 : 55 + (i % 30);
  const l = i < 10 ? 92 : i < 20 ? 18 : 35 + (i % 25);
  return `hsl(${h}, ${s}%, ${l}%)`;
}

function installState(_cat: PerformanceCategory, part: PerformancePart): InstallState {
  if (part.installed) return 'installed';
  if (part.idx === -1) return 'install';
  if (!part.itemName) return 'incompatible';
  if ((part.inventoryCount || 0) < 1) return 'missing';
  return 'install';
}

function installLabel(s: InstallState) {
  if (s === 'installed') return 'Sumontuota';
  if (s === 'missing') return 'Nėra inventoriuje';
  if (s === 'incompatible') return 'Netinka';
  return 'Montuoti';
}

function fadeIn(el: Element | null | undefined, vars: gsap.TweenVars = {}) {
  if (!el) return;
  gsap.fromTo(el, { opacity: 0 }, { opacity: 1, duration: 0.3, ease: 'power2.out', ...vars });
}

function slideIn(el: Element | null | undefined, from: gsap.TweenVars, vars: gsap.TweenVars = {}) {
  if (!el) return;
  gsap.fromTo(el, from, { duration: 0.35, ease: 'power2.out', ...vars });
}

function StatBar({ label, current, next }: { label: string; current: number; next: number }) {
  const nextRef = useRef<HTMLDivElement>(null);
  const delta = next - current;
  useLayoutEffect(() => {
    const bar = nextRef.current;
    if (!bar) return;
    gsap.fromTo(bar, { width: '0%' }, { width: `${next}%`, duration: 0.45, ease: 'power2.out' });
  }, [next]);
  return (
    <div className="stat-row">
      <div className="stat-row__head">
        <span>{label}</span>
        <span className={`stat-delta ${delta >= 0 ? 'up' : 'down'}`}>{delta >= 0 ? '+' : ''}{delta}</span>
      </div>
      <div className="stat-bar">
        <div className="stat-bar__current" style={{ width: `${current}%` }} />
        <div className="stat-bar__next" ref={nextRef} style={{ width: `${next}%` }} />
      </div>
      <div className="stat-values">
        <span>Dabar: <strong>{current}</strong></span>
        <span>Po: <strong>{next}</strong></span>
      </div>
    </div>
  );
}

export default function App() {
  const [open, setOpen] = useState(false);
  const [payload, setPayload] = useState<OpenWorkshopPayload | null>(null);
  const [section, setSection] = useState<WorkshopSection>('performance');
  const [perfCatId, setPerfCatId] = useState<string | null>(null);
  const [perfPartIdx, setPerfPartIdx] = useState<number | null>(null);
  const [paintType, setPaintType] = useState(0);
  const [bodyCat, setBodyCat] = useState<BodyModCategory | null>(null);
  const [bodyVariants, setBodyVariants] = useState<BodyVariant[]>([]);

  const rootRef = useRef<HTMLDivElement>(null);
  const leftRef = useRef<HTMLElement>(null);
  const contentRef = useRef<HTMLElement>(null);
  const dragging = useRef(false);
  const lastMouse = useRef({ x: 0, y: 0 });

  const categories = payload?.categories ?? [];
  const perfCat = categories.find((c) => c.id === perfCatId) ?? categories[0] ?? null;
  const perfPart = perfCat?.parts.find((p) => p.idx === perfPartIdx) ?? null;
  const statKeys = useMemo(() => mergeStatKeys(categories), [categories]);

  const reset = useCallback(() => {
    setOpen(false);
    setPayload(null);
    setSection('performance');
    setPerfCatId(null);
    setPerfPartIdx(null);
    setBodyCat(null);
    setBodyVariants([]);
  }, []);

  const close = useCallback(() => {
    const root = rootRef.current;
    const finish = () => reset();
    if (root) gsap.to(root, { opacity: 0, duration: 0.22, onComplete: finish });
    else finish();
    fetchNui('wsClose');
  }, [reset]);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const msg = e.data as { action?: string } & Partial<OpenWorkshopPayload> & {
        modType?: number; label?: string; variants?: BodyVariant[]; on?: boolean;
      };
      if (msg.action === 'openWorkshop') {
        setPayload(msg as OpenWorkshopPayload);
        setPerfCatId(msg.categories?.[0]?.id ?? null);
        setPerfPartIdx(null);
        setSection('performance');
        setOpen(true);
        return;
      }
      if (msg.action === 'closeWorkshop') { reset(); return; }
      if (msg.action === 'bodyVariants') {
        setBodyVariants(msg.variants ?? []);
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [reset]);

  useLayoutEffect(() => {
    if (!open) return;
    fadeIn(rootRef.current, { duration: 0.35 });
    slideIn(leftRef.current, { x: -28, opacity: 0 }, { x: 0, opacity: 1, duration: 0.4 });
  }, [open]);

  useLayoutEffect(() => {
    if (!open) return;
    slideIn(contentRef.current, { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.28 });
  }, [open, section, perfCatId, bodyCat]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape' && open) close(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, close]);

  const selectSection = (s: WorkshopSection) => {
    setSection(s);
    setBodyCat(null);
    setBodyVariants([]);
    setPerfPartIdx(null);
    const sec = SECTIONS.find((x) => x.id === s);
    fetchNui('wsSelectCam', { section: sec?.cam ?? 'body' });
  };

  const selectPerfCat = (cat: PerformanceCategory) => {
    setPerfCatId(cat.id);
    setPerfPartIdx(null);
    fetchNui('wsSelectCam', { modType: cat.modType });
  };

  const selectBodyCat = (cat: BodyModCategory) => {
    setBodyCat(cat);
    setBodyVariants([]);
    fetchNui('wsSelectCam', { modType: cat.id });
    if (cat.count > 0) fetchNui('wsRequestVariants', { modType: cat.id, label: cat.label });
  };

  const onMouseDown = (e: React.MouseEvent) => {
    if ((e.target as HTMLElement).closest('.ui-panel')) return;
    dragging.current = true;
    lastMouse.current = { x: e.clientX, y: e.clientY };
  };
  const onMouseMove = (e: React.MouseEvent) => {
    if (!dragging.current) return;
    const dx = e.clientX - lastMouse.current.x;
    const dy = e.clientY - lastMouse.current.y;
    lastMouse.current = { x: e.clientX, y: e.clientY };
    fetchNui('wsCameraOrbit', { deltaX: dx, deltaY: dy });
  };
  const onWheel = (e: React.WheelEvent) => {
    if ((e.target as HTMLElement).closest('.ui-panel')) return;
    e.preventDefault();
    fetchNui('wsCameraZoom', { delta: e.deltaY > 0 ? 1 : -1 });
  };

  if (!open || !payload) return null;

  const previewStats = perfCat && perfPart ? statsForPart(perfCat, perfPart) : perfCat?.currentStats ?? {};
  const currentStats = perfCat?.currentStats ?? {};
  const installBtn = perfPart ? installState(perfCat!, perfPart) : 'missing';
  const activePaint = payload.paintTypes.find((p) => p.paintType === paintType) ?? payload.paintTypes[0];

  return (
    <div className="ws-root" ref={rootRef} onMouseDown={onMouseDown} onMouseMove={onMouseMove}
      onMouseUp={() => { dragging.current = false; }} onMouseLeave={() => { dragging.current = false; }}
      onWheel={onWheel}>
      <div className="ws-vignette" aria-hidden="true" />

      <aside className="ui-panel ui-panel--left" ref={leftRef}>
        <header className="ws-header">
          <div>
            <p className="ws-kicker">Los Santos Customs</p>
            <h1>{payload.vehicle.model}</h1>
            <p className="ws-plate">{payload.vehicle.plate}</p>
          </div>
          <button type="button" className="btn-icon" onClick={close}>✕</button>
        </header>

        <nav className="section-nav">
          {SECTIONS.map((s) => (
            <button key={s.id} type="button"
              className={`section-btn ${section === s.id ? 'active' : ''}`}
              onClick={() => selectSection(s.id)}>
              <span className="section-btn__icon">{s.icon}</span>
              <span>{s.label}</span>
            </button>
          ))}
        </nav>

        {section === 'performance' && (
          <nav className="sub-nav">
            <p className="panel-label">Performance dalys</p>
            {categories.map((cat) => (
              <button key={cat.id} type="button"
                className={`sub-btn ${perfCat?.id === cat.id ? 'active' : ''}`}
                onClick={() => selectPerfCat(cat)}>
                <span>{PERF_ICONS[cat.id] ?? '🔧'}</span>
                <span className="sub-btn__text">{cat.label}</span>
                <span className={`cat-dot ${cat.hasInventory ? 'has-item' : ''}`} />
              </button>
            ))}
          </nav>
        )}

        {section === 'body' && (
          <nav className="sub-nav">
            <p className="panel-label">Kėbulo kategorijos</p>
            {payload.bodyMods.filter((b) => b.count > 0).map((b) => (
              <button key={b.id} type="button"
                className={`sub-btn ${bodyCat?.id === b.id ? 'active' : ''}`}
                onClick={() => selectBodyCat(b)}>
                <span className="sub-btn__text">{b.label}</span>
                <span className="sub-meta">{b.count}</span>
              </button>
            ))}
          </nav>
        )}

        <div className="cam-hint">
          <span>Pelė: sukti · Ratukas: zoom</span>
          <button type="button" className="btn-ghost-sm" onClick={() => fetchNui('wsCameraReset')}>Atstatyti kamerą</button>
        </div>
      </aside>

      <section className="ui-panel ui-panel--center" ref={contentRef}>
        {section === 'performance' && perfCat && (
          <>
            <h2>{perfCat.label}</h2>
            <p className="panel-sub">Pasirink detalę — performance montavimui reikia itemo</p>
            <div className="parts-grid">
              {perfCat.parts.map((part) => (
                <button key={`${perfCat.id}-${part.idx}`} type="button"
                  className={`part-card ${perfPartIdx === part.idx ? 'active' : ''} ${part.installed ? 'installed' : ''}`}
                  onClick={() => setPerfPartIdx(part.idx)}>
                  <img src={itemImageUrl(part.image)} alt="" />
                  <span className="part-card__label">{part.label}</span>
                  {part.itemName && part.inventoryCount >= 0 && <span className="part-card__qty">x{part.inventoryCount}</span>}
                  {part.installed && <span className="part-badge">Sumontuota</span>}
                </button>
              ))}
            </div>
          </>
        )}

        {section === 'paint' && (
          <>
            <h2>Dažymas</h2>
            <p className="panel-sub">{activePaint?.txt ?? 'Pasirink spalvą'}</p>
            <div className="pills">
              {payload.paintTypes.map((pt) => (
                <button key={pt.paintType} type="button"
                  className={`pill ${paintType === pt.paintType ? 'active' : ''}`}
                  onClick={() => setPaintType(pt.paintType)}>{pt.label}</button>
              ))}
            </div>
            <div className="color-grid">
              {Array.from({ length: 160 }, (_, i) => (
                <button key={i} type="button" className="swatch" style={{ background: colorForIndex(i) }}
                  title={`Indeksas ${i}`}
                  onClick={() => fetchNui('wsApplyPaint', { paintType, colorIndex: i })}>
                  <span>{i}</span>
                </button>
              ))}
            </div>
          </>
        )}

        {section === 'tint' && (
          <>
            <h2>Langų tamsinimas</h2>
            <p className="panel-sub">Peržiūra iškart ant transporto</p>
            <div className="tint-list">
              {payload.windowTints.map((t) => (
                <button key={t.idx} type="button" className="tint-row"
                  onClick={() => fetchNui('wsApplyTint', { idx: t.idx })}>
                  <span>{t.label}</span>
                  <span className="sub-meta">ID {t.idx}</span>
                </button>
              ))}
            </div>
          </>
        )}

        {section === 'body' && bodyCat && (
          <>
            <h2>{bodyCat.label}</h2>
            <p className="panel-sub">Pasirink variantą — peržiūra iškart</p>
            <div className="variant-grid">
              <button type="button" className="variant-btn variant-btn--stock"
                onClick={() => fetchNui('wsInstallBody', { modType: bodyCat.id, idx: -1, label: bodyCat.label })}>
                Gamyklinis
              </button>
              {bodyVariants.map((v) => (
                <button key={v.idx} type="button" className="variant-btn"
                  onClick={() => fetchNui('wsInstallBody', { modType: bodyCat.id, idx: v.idx, label: bodyCat.label })}>
                  {v.label}
                </button>
              ))}
            </div>
          </>
        )}

        {section === 'body' && !bodyCat && (
          <div className="empty-state">
            <p>Pasirink kėbulo kategoriją iš kairės</p>
          </div>
        )}
      </section>

      {section === 'performance' && perfCat && perfPart && (
        <aside className="ui-panel ui-panel--right">
          <img className="detail-img" src={itemImageUrl(perfPart.image)} alt="" />
          <h3>{perfPart.label}</h3>
          <p className="detail-meta">
            {perfPart.itemName ? `Inventoriuje: ${Math.max(0, perfPart.inventoryCount)} / 1` : 'Gamyklinis'}
          </p>
          <div className="stats-block">
            {statKeys.filter((k) => perfCat.statKeys.includes(k)).map((k: StatKey) => (
              <StatBar key={k} label={payload.statLabels[k] ?? k}
                current={currentStats[k] ?? 38} next={previewStats[k] ?? currentStats[k] ?? 38} />
            ))}
          </div>
          <button type="button" className={`btn-install ${installBtn}`} disabled={installBtn !== 'install'}
            onClick={() => fetchNui('wsInstallPerf', {
              modType: perfCat.modType, idx: perfPart.idx, itemName: perfPart.itemName,
              isToggle: perfCat.isToggle, label: perfPart.label,
            })}>
            {installLabel(installBtn)}
          </button>
        </aside>
      )}

      <footer className="ws-footer">
        <button type="button" className="btn-ghost" onClick={() => fetchNui('wsRepair')}>Remontas</button>
        <button type="button" className="btn-save" onClick={() => fetchNui('wsSave')}>Išsaugoti klientui</button>
      </footer>
    </div>
  );
}

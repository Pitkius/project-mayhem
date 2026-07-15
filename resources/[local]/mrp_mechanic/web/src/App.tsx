import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import gsap from 'gsap';
import type {
  BodyModCategory, BodyVariant, InstallState, OpenWorkshopPayload,
  PaintState, PaintTarget, PerformanceCategory, PerformancePart, StatKey, WheelTypeCategory, WorkshopSection,
} from './types';
import { SECTIONS } from './types';
import { fetchNui, itemImageUrl } from './nui';
import { mergeStatKeys, statsForPart } from './stats';
import { colorForIndex, colorNameForIndex } from './vehicleColors';
import './styles.css';

const PERF_ICONS: Record<string, string> = {
  engine: 'fa-gear',
  brakes: 'fa-compact-disc',
  transmission: 'fa-gears',
  suspension: 'fa-arrows-up-down',
  armor: 'fa-shield-halved',
  turbo: 'fa-fan',
};

const DEFAULT_PAINT: PaintState = { paintType: 0, primary: 0, secondary: 0, pearlescent: 0 };

const PAINT_TARGETS: { id: PaintTarget; label: string; hint: string }[] = [
  { id: 'primary', label: 'Pagrindinė', hint: 'Kėbulo pagrindinė spalva' },
  { id: 'secondary', label: 'Antrinė', hint: 'Antrinė / accent spalva' },
  { id: 'pearl', label: 'Atspalvis', hint: 'Perlamutrinis atspalvis (perl)' },
];

function swatchStyle(index: number, paintType: number, isPearl = false): CSSProperties {
  const hex = colorForIndex(index);
  if (isPearl) {
    return {
      background: `linear-gradient(160deg, ${hex} 0%, #ffffffaa 40%, ${hex} 100%)`,
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.25)',
    };
  }
  if (paintType === 3) {
    return { background: hex, filter: 'saturate(0.82) brightness(0.94)' };
  }
  if (paintType === 5) {
    return {
      background: `linear-gradient(135deg, #f5f5f5 0%, ${hex} 35%, #ffffff 55%, ${hex} 75%, #c0c0c0 100%)`,
    };
  }
  if (paintType === 1 || paintType === 4) {
    return {
      background: `linear-gradient(145deg, ${hex} 0%, #ffffff55 45%, ${hex} 100%)`,
    };
  }
  if (paintType === 2) {
    return {
      background: `linear-gradient(160deg, ${hex} 0%, #ffffff88 50%, ${hex} 100%)`,
    };
  }
  return { background: hex };
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
  const [paintState, setPaintState] = useState<PaintState>(DEFAULT_PAINT);
  const [paintTarget, setPaintTarget] = useState<PaintTarget>('primary');
  const [bodyCat, setBodyCat] = useState<BodyModCategory | null>(null);
  const [bodyVariants, setBodyVariants] = useState<BodyVariant[]>([]);
  const [wheelTypeCat, setWheelTypeCat] = useState<WheelTypeCategory | null>(null);
  const [wheelModSlot, setWheelModSlot] = useState<23 | 24>(23);
  const [wheelVariants, setWheelVariants] = useState<BodyVariant[]>([]);

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
    setWheelTypeCat(null);
    setWheelModSlot(23);
    setWheelVariants([]);
    setPaintState(DEFAULT_PAINT);
    setPaintTarget('primary');
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
        modType?: number; label?: string; variants?: BodyVariant[]; on?: boolean; wheelType?: number;
      };
      if (msg.action === 'openWorkshop') {
        const p = msg as OpenWorkshopPayload;
        const ps = p.paintState ?? DEFAULT_PAINT;
        setPayload(p);
        setPaintState(ps);
        setPaintTarget('primary');
        setPerfCatId(msg.categories?.[0]?.id ?? null);
        setPerfPartIdx(null);
        setSection('performance');
        setOpen(true);
        return;
      }
      if (msg.action === 'closeWorkshop') { reset(); return; }
      if (msg.action === 'bodyVariants') {
        if (msg.wheelType != null) setWheelVariants(msg.variants ?? []);
        else setBodyVariants(msg.variants ?? []);
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
  }, [open, section, perfCatId, bodyCat, wheelTypeCat]);

  const camKeysRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) {
        close();
        return;
      }
      const k = e.key.toLowerCase();
      if (!open || !['w', 'a', 's', 'd'].includes(k)) return;
      e.preventDefault();
      camKeysRef.current.add(k);
    };
    const onKeyUp = (e: KeyboardEvent) => {
      camKeysRef.current.delete(e.key.toLowerCase());
    };
    const onBlur = () => camKeysRef.current.clear();

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
      camKeysRef.current.clear();
    };
  }, [open, close]);

  useEffect(() => {
    if (!open) return;
    const tick = () => {
      const keys = camKeysRef.current;
      if (!keys.size) return;
      let angleDelta = 0;
      let distDelta = 0;
      if (keys.has('a')) angleDelta -= 0.85;
      if (keys.has('d')) angleDelta += 0.85;
      if (keys.has('w')) distDelta -= 0.05;
      if (keys.has('s')) distDelta += 0.05;
      if (angleDelta || distDelta) fetchNui('wsCameraKeys', { angleDelta, distDelta });
    };
    const id = window.setInterval(tick, 16);
    return () => window.clearInterval(id);
  }, [open]);

  const selectSection = (s: WorkshopSection) => {
    setSection(s);
    setBodyCat(null);
    setBodyVariants([]);
    setWheelTypeCat(null);
    setWheelModSlot(23);
    setWheelVariants([]);
    setPerfPartIdx(null);
    const sec = SECTIONS.find((x) => x.id === s);
    fetchNui('wsSelectCam', { section: s === 'wheels' ? 'wheels' : (sec?.cam ?? 'body') });
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

  const loadWheelVariants = (wt: WheelTypeCategory, modType: 23 | 24) => {
    const slotLabel = modType === 24 ? 'Galinės ratlankės' : 'Priekinės ratlankės';
    fetchNui('wsRequestVariants', { modType, wheelType: wt.id, label: `${wt.label} — ${slotLabel}` });
  };

  const selectWheelType = (wt: WheelTypeCategory) => {
    setWheelTypeCat(wt);
    setWheelModSlot(23);
    setWheelVariants([]);
    fetchNui('wsPreviewWheelType', { wheelType: wt.id });
    fetchNui('wsSelectCam', { section: 'wheels' });
    loadWheelVariants(wt, 23);
  };

  const selectWheelSlot = (modType: 23 | 24) => {
    if (!wheelTypeCat) return;
    setWheelModSlot(modType);
    setWheelVariants([]);
    fetchNui('wsSelectCam', { modType });
    loadWheelVariants(wheelTypeCat, modType);
  };

  const installWheel = (idx: number) => {
    if (!wheelTypeCat) return;
    const slotLabel = wheelModSlot === 24 ? 'Galinės ratlankės' : 'Priekinės ratlankės';
    fetchNui('wsInstallBody', {
      modType: wheelModSlot,
      wheelType: wheelTypeCat.id,
      idx,
      label: `${wheelTypeCat.label} — ${slotLabel}`,
    });
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

  const applyPaint = useCallback((patch: Partial<PaintState>) => {
    setPaintState((prev) => {
      const next = { ...prev, ...patch };
      fetchNui('wsApplyPaint', next);
      return next;
    });
  }, []);

  if (!open || !payload) return null;

  const previewStats = perfCat && perfPart ? statsForPart(perfCat, perfPart) : perfCat?.currentStats ?? {};
  const currentStats = perfCat?.currentStats ?? {};
  const installBtn = perfPart ? installState(perfCat!, perfPart) : 'missing';
  const activePaint = payload.paintTypes.find((p) => p.paintType === paintState.paintType) ?? payload.paintTypes[0];
  const activeTargetMeta = PAINT_TARGETS.find((t) => t.id === paintTarget) ?? PAINT_TARGETS[0];
  const activeColorIndex = paintTarget === 'primary'
    ? paintState.primary
    : paintTarget === 'secondary'
      ? paintState.secondary
      : paintState.pearlescent;

  return (
    <div className="ws-root" ref={rootRef} onMouseDown={onMouseDown} onMouseMove={onMouseMove}
      onMouseUp={() => { dragging.current = false; }} onMouseLeave={() => { dragging.current = false; }}
      onWheel={onWheel}>
      <aside className="ui-panel ui-panel--left" ref={leftRef}>
        <header className="ws-header">
          <div>
            <p className="ws-kicker">Los Santos Customs</p>
            <h1>{payload.vehicle.model}</h1>
            <p className="ws-plate">{payload.vehicle.plate}</p>
          </div>
          <button type="button" className="btn-icon" onClick={close} aria-label="Uždaryti">
            <i className="fas fa-xmark" aria-hidden="true" />
          </button>
        </header>

        <nav className="section-nav">
          {SECTIONS.map((s) => (
            <button key={s.id} type="button"
              className={`section-btn ${section === s.id ? 'active' : ''}`}
              onClick={() => selectSection(s.id)}>
              <span className="section-btn__icon"><i className={`fas ${s.icon}`} aria-hidden="true" /></span>
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
                <span className="sub-btn__icon"><i className={`fas ${PERF_ICONS[cat.id] ?? 'fa-wrench'}`} aria-hidden="true" /></span>
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

        {section === 'wheels' && (
          <nav className="sub-nav">
            <p className="panel-label">Ratlankių tipai</p>
            {(payload.wheelTypes ?? []).map((wt) => (
              <button key={wt.id} type="button"
                className={`sub-btn ${wheelTypeCat?.id === wt.id ? 'active' : ''}`}
                onClick={() => selectWheelType(wt)}>
                <span className="sub-btn__text">{wt.label}</span>
                <span className="sub-meta">{wt.count}{wt.rearCount ? `+${wt.rearCount}` : ''}</span>
                {payload.installedWheelType === wt.id && <span className="cat-dot has-item" />}
              </button>
            ))}
          </nav>
        )}

        <div className="cam-hint">
          <span>WASD: sukti / priartinti · Pelė: kampas · Ratukas: zoom</span>
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
            <p className="panel-sub">{activePaint?.txt ?? 'Pasirink dažų tipą ir spalvas'}</p>

            <p className="panel-label">Dažų tipas</p>
            <div className="pills">
              {payload.paintTypes.map((pt) => (
                <button key={pt.paintType} type="button"
                  className={`pill ${paintState.paintType === pt.paintType ? 'active' : ''}`}
                  onClick={() => applyPaint({ paintType: pt.paintType })}>{pt.label}</button>
              ))}
            </div>

            <p className="panel-label">Ką dažai</p>
            <div className="paint-targets">
              {PAINT_TARGETS.map((t) => (
                <button key={t.id} type="button"
                  className={`paint-target ${paintTarget === t.id ? 'active' : ''}`}
                  onClick={() => setPaintTarget(t.id)}>
                  <span className="paint-target__swatch" style={swatchStyle(
                    t.id === 'primary' ? paintState.primary : t.id === 'secondary' ? paintState.secondary : paintState.pearlescent,
                    paintState.paintType,
                    t.id === 'pearl',
                  )} />
                  <span className="paint-target__label">{t.label}</span>
                  <span className="paint-target__idx">
                    {t.id === 'primary' ? paintState.primary : t.id === 'secondary' ? paintState.secondary : paintState.pearlescent}
                  </span>
                </button>
              ))}
            </div>

            <p className="panel-sub paint-target-hint">{activeTargetMeta.hint}</p>

            <div className="paint-actions">
              <button type="button" className="btn-ghost-sm"
                onClick={() => applyPaint({ secondary: paintState.primary })}>
                Antrinė = pagrindinė
              </button>
              <button type="button" className="btn-ghost-sm"
                onClick={() => applyPaint({ pearlescent: paintState.primary })}>
                Atspalvis = pagrindinė
              </button>
            </div>

            <div className="color-grid">
              {Array.from({ length: 160 }, (_, i) => (
                <button key={i} type="button"
                  className={`swatch ${activeColorIndex === i ? 'active' : ''}`}
                  style={swatchStyle(i, paintState.paintType, paintTarget === 'pearl')}
                  title={`${colorNameForIndex(i)} (${i})`}
                  onClick={() => {
                    if (paintTarget === 'primary') applyPaint({ primary: i });
                    else if (paintTarget === 'secondary') applyPaint({ secondary: i });
                    else applyPaint({ pearlescent: i });
                  }}>
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

        {section === 'wheels' && wheelTypeCat && (
          <>
            <h2>{wheelTypeCat.label}</h2>
            <p className="panel-sub">Pasirink ratlankių variantą — peržiūra iškart</p>
            {payload.isBike && (wheelTypeCat.rearCount ?? 0) > 0 && (
              <>
                <p className="panel-label">Ratų ašis</p>
                <div className="pills">
                  <button type="button"
                    className={`pill ${wheelModSlot === 23 ? 'active' : ''}`}
                    onClick={() => selectWheelSlot(23)}>
                    Priekinės ({wheelTypeCat.count})
                  </button>
                  <button type="button"
                    className={`pill ${wheelModSlot === 24 ? 'active' : ''}`}
                    onClick={() => selectWheelSlot(24)}>
                    Galinės ({wheelTypeCat.rearCount})
                  </button>
                </div>
              </>
            )}
            <div className="variant-grid">
              <button type="button" className="variant-btn variant-btn--stock"
                onClick={() => installWheel(-1)}>
                Gamyklinis
              </button>
              {wheelVariants.map((v) => (
                <button key={v.idx} type="button" className="variant-btn"
                  onClick={() => installWheel(v.idx)}>
                  {v.label}
                </button>
              ))}
            </div>
          </>
        )}

        {section === 'wheels' && !wheelTypeCat && (
          <div className="empty-state">
            <p>Pasirink ratlankių tipą iš kairės</p>
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

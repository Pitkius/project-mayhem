import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import gsap from 'gsap';
import type { InstallState, OpenPerformancePayload, PerformanceCategory, PerformancePart, StatKey } from './types';
import { fetchNui, itemImageUrl } from './nui';
import { mergeStatKeys, statsForPart } from './stats';
import './styles.css';

const CATEGORY_ICONS: Record<string, string> = {
  engine: '⚙',
  brakes: '🛑',
  transmission: '⚡',
  suspension: '🔩',
  armor: '🛡',
  turbo: '💨',
};

function installState(_cat: PerformanceCategory, part: PerformancePart): InstallState {
  if (part.installed) return 'installed';
  if (part.idx === -1) return 'install';
  if (!part.itemName) return 'incompatible';
  if ((part.inventoryCount || 0) < 1) return 'missing';
  return 'install';
}

function installLabel(state: InstallState): string {
  switch (state) {
    case 'installed': return 'Sumontuota';
    case 'missing': return 'Nėra inventoriuje';
    case 'incompatible': return 'Netinka';
    default: return 'Montuoti';
  }
}

function StatBar({ label, current, next }: { label: string; current: number; next: number }) {
  const barRef = useRef<HTMLDivElement>(null);
  const delta = next - current;

  useEffect(() => {
    if (!barRef.current) return;
    gsap.fromTo(barRef.current.querySelector('.stat-bar__next'), { width: '0%' }, { width: `${next}%`, duration: 0.45, ease: 'power2.out' });
  }, [next]);

  return (
    <div className="stat-row" ref={barRef}>
      <div className="stat-row__head">
        <span>{label}</span>
        <span className={`stat-delta ${delta >= 0 ? 'up' : 'down'}`}>{delta >= 0 ? '+' : ''}{delta}</span>
      </div>
      <div className="stat-bar">
        <div className="stat-bar__current" style={{ width: `${current}%` }} />
        <div className="stat-bar__next" style={{ width: `${next}%` }} />
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
  const [payload, setPayload] = useState<OpenPerformancePayload | null>(null);
  const [selectedCatId, setSelectedCatId] = useState<string | null>(null);
  const [selectedPartIdx, setSelectedPartIdx] = useState<number | null>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const dragging = useRef(false);
  const lastMouse = useRef({ x: 0, y: 0 });

  const categories = payload?.categories ?? [];
  const selectedCat = categories.find((c) => c.id === selectedCatId) ?? categories[0] ?? null;
  const selectedPart = selectedCat?.parts.find((p) => p.idx === selectedPartIdx) ?? null;

  const statKeys = useMemo(() => mergeStatKeys(categories), [categories]);

  const close = useCallback(() => {
    gsap.to(rootRef.current, { opacity: 0, duration: 0.22, onComplete: () => {
      setOpen(false);
      setPayload(null);
      setSelectedCatId(null);
      setSelectedPartIdx(null);
    }});
    fetchNui('perfClose');
  }, []);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const msg = e.data as { action?: string } & Partial<OpenPerformancePayload>;
      if (msg.action === 'openPerformanceUI') {
        setPayload(msg as OpenPerformancePayload);
        setSelectedCatId(msg.categories?.[0]?.id ?? null);
        setSelectedPartIdx(null);
        setOpen(true);
        requestAnimationFrame(() => {
          gsap.fromTo(rootRef.current, { opacity: 0 }, { opacity: 1, duration: 0.35, ease: 'power2.out' });
          gsap.fromTo(panelRef.current, { x: -28, opacity: 0 }, { x: 0, opacity: 1, duration: 0.4, ease: 'power2.out' });
        });
        return;
      }
      if (msg.action === 'closePerformanceUI') {
        setOpen(false);
        setPayload(null);
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, close]);

  const selectCategory = (cat: PerformanceCategory) => {
    setSelectedCatId(cat.id);
    setSelectedPartIdx(null);
    fetchNui('perfSelectCategory', { modType: cat.modType });
    gsap.fromTo('.parts-panel', { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.28 });
  };

  const selectPart = (part: PerformancePart) => {
    setSelectedPartIdx(part.idx);
    gsap.fromTo('.detail-panel', { opacity: 0, x: 12 }, { opacity: 1, x: 0, duration: 0.3 });
  };

  const onInstall = () => {
    if (!selectedCat || !selectedPart) return;
    const state = installState(selectedCat, selectedPart);
    if (state !== 'install') return;
    fetchNui('perfInstallPart', {
      modType: selectedCat.modType,
      idx: selectedPart.idx,
      itemName: selectedPart.itemName,
      isToggle: selectedCat.isToggle === true,
      label: selectedPart.label,
    });
  };

  const onSave = () => fetchNui('perfSave');

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
    fetchNui('perfCameraOrbit', { deltaX: dx, deltaY: dy });
  };

  const onMouseUp = () => { dragging.current = false; };

  const onWheel = (e: React.WheelEvent) => {
    if ((e.target as HTMLElement).closest('.ui-panel')) return;
    e.preventDefault();
    fetchNui('perfCameraZoom', { delta: e.deltaY > 0 ? 1 : -1 });
  };

  if (!open || !payload) return null;

  const previewStats = selectedCat && selectedPart
    ? statsForPart(selectedCat, selectedPart)
    : selectedCat?.currentStats ?? {};

  const currentStats = selectedCat?.currentStats ?? {};
  const installBtnState = selectedPart ? installState(selectedCat!, selectedPart) : 'missing';

  return (
    <div
      className="perf-root"
      ref={rootRef}
      onMouseDown={onMouseDown}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseUp}
      onWheel={onWheel}
    >
      <div className="perf-vignette" aria-hidden="true" />

      <aside className="ui-panel ui-panel--left" ref={panelRef}>
        <header className="perf-header">
          <div>
            <p className="perf-kicker">Performance montavimas</p>
            <h1>{payload.vehicle.model}</h1>
            <p className="perf-plate">{payload.vehicle.plate}</p>
          </div>
          <button type="button" className="btn-icon" onClick={close} aria-label="Uždaryti">✕</button>
        </header>

        <p className="panel-label">Kategorijos</p>
        <nav className="cat-list">
          {categories.map((cat) => {
            const lvl = cat.installedLevel < 0 ? 0 : cat.installedLevel + 1;
            return (
              <button
                key={cat.id}
                type="button"
                className={`cat-item ${selectedCat?.id === cat.id ? 'active' : ''}`}
                onClick={() => selectCategory(cat)}
              >
                <span className="cat-item__icon">{CATEGORY_ICONS[cat.id] ?? '🔧'}</span>
                <span className="cat-item__body">
                  <span className="cat-item__title">{cat.label}</span>
                  <span className="cat-item__meta">Lygis {cat.isToggle ? (cat.installedLevel >= 0 ? 'ON' : 'OFF') : lvl}</span>
                </span>
                <span className={`cat-dot ${cat.hasInventory ? 'has-item' : ''}`} title={cat.hasInventory ? 'Yra detalių' : 'Nėra detalių'} />
              </button>
            );
          })}
        </nav>

        <div className="cam-hint">
          <span>Pelė: sukti · Ratukas: zoom</span>
          <button type="button" className="btn-ghost-sm" onClick={() => fetchNui('perfCameraReset')}>Atstatyti kamerą</button>
        </div>
      </aside>

      {selectedCat && (
        <section className="ui-panel ui-panel--center parts-panel">
          <h2>{selectedCat.label}</h2>
          <p className="panel-sub">Pasirink detalę montavimui</p>
          <div className="parts-grid">
            {selectedCat.parts.map((part) => (
              <button
                key={`${selectedCat.id}-${part.idx}`}
                type="button"
                className={`part-card ${selectedPartIdx === part.idx ? 'active' : ''} ${part.installed ? 'installed' : ''}`}
                onClick={() => selectPart(part)}
              >
                <img src={itemImageUrl(part.image)} alt="" loading="lazy" />
                <span className="part-card__label">{part.label}</span>
                {part.itemName && part.inventoryCount >= 0 && (
                  <span className="part-card__qty">x{part.inventoryCount}</span>
                )}
                {part.installed && <span className="part-badge">Sumontuota</span>}
              </button>
            ))}
          </div>
        </section>
      )}

      {selectedCat && selectedPart && (
        <aside className="ui-panel ui-panel--right detail-panel">
          <img className="detail-img" src={itemImageUrl(selectedPart.image)} alt="" />
          <h3>{selectedPart.label}</h3>
          <p className="detail-meta">
            {selectedPart.itemName
              ? `Inventoriuje: ${Math.max(0, selectedPart.inventoryCount)} / 1`
              : 'Gamyklinis variantas'}
          </p>

          <div className="stats-block">
            {statKeys.filter((k) => selectedCat.statKeys.includes(k)).map((k: StatKey) => (
              <StatBar
                key={k}
                label={payload.statLabels[k] ?? k}
                current={currentStats[k] ?? 38}
                next={previewStats[k] ?? currentStats[k] ?? 38}
              />
            ))}
          </div>

          <button
            type="button"
            className={`btn-install ${installBtnState}`}
            disabled={installBtnState !== 'install'}
            onClick={onInstall}
          >
            {installLabel(installBtnState)}
          </button>
        </aside>
      )}

      <footer className="perf-footer">
        <button type="button" className="btn-save" onClick={onSave}>Išsaugoti klientui</button>
      </footer>
    </div>
  );
}

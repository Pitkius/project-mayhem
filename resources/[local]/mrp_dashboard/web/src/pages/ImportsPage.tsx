import { useMemo, useState } from 'react';
import type { DashboardData, ImportClass } from '@/types/dashboard';
import { Button, Card, ProgressBar, formatNumber } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

const CLASS_META: Record<
  ImportClass,
  { label: string; blurb: string; tone: string }
> = {
  A: {
    label: 'A',
    blurb: 'Greitos, prieinamos CR — šiek tiek virš paprastų mašinų',
    tone: 'class-a',
  },
  S: {
    label: 'S',
    blurb: 'Stiprios ir greitos — solidus importo lygis',
    tone: 'class-s',
  },
  X: {
    label: 'X',
    blurb: 'Greičiausios ir brangiausios — top tier',
    tone: 'class-x',
  },
};

const CATS: { id: ImportClass | 'all'; label: string }[] = [
  { id: 'all', label: 'VISOS' },
  { id: 'A', label: 'A KLASĖ' },
  { id: 'S', label: 'S KLASĖ' },
  { id: 'X', label: 'X KLASĖ' },
];

export function ImportsPage({
  data,
  notify,
  embedded = false,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
  embedded?: boolean;
}) {
  const [cat, setCat] = useState<ImportClass | 'all'>('all');
  const [q, setQ] = useState('');
  const [sort, setSort] = useState<'price' | 'name' | 'class'>('class');

  const list = useMemo(() => {
    let items = [...data.imports];
    if (cat !== 'all') items = items.filter((v) => v.class === cat);
    if (q.trim()) {
      const s = q.toLowerCase();
      items = items.filter((v) => v.name.toLowerCase().includes(s));
    }
    const rank = { A: 0, S: 1, X: 2 } as const;
    items.sort((a, b) => {
      if (sort === 'name') return a.name.localeCompare(b.name);
      if (sort === 'price') return a.price - b.price;
      const byClass = rank[a.class] - rank[b.class];
      return byClass !== 0 ? byClass : a.price - b.price;
    });
    return items;
  }, [data.imports, cat, q, sort]);

  return (
    <div>
      {!embedded ? (
        <div className="page-title">
          <div>
            <h1>Importų salonas</h1>
            <p>Trys klasės: A (prieinama) · S (stipri) · X (top / brangiausia).</p>
          </div>
        </div>
      ) : null}

      <div className="grid grid-3" style={{ marginBottom: 14 }}>
        {(['A', 'S', 'X'] as ImportClass[]).map((cls) => (
          <button
            key={cls}
            type="button"
            className={`card import-class-card ${CLASS_META[cls].tone}${
              cat === cls ? ' active' : ''
            }`}
            onClick={() => setCat(cls)}
          >
            <div className={`class-badge ${CLASS_META[cls].tone}`}>{cls}</div>
            <p className="muted" style={{ marginTop: 8 }}>
              {CLASS_META[cls].blurb}
            </p>
          </button>
        ))}
      </div>

      <div className="search-row">
        <input
          placeholder="Ieškoti..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as 'price' | 'name' | 'class')}
        >
          <option value="class">Klasė</option>
          <option value="price">Kaina</option>
          <option value="name">Pavadinimas</option>
        </select>
      </div>
      <div className="chips">
        {CATS.map((c) => (
          <button
            key={c.id}
            type="button"
            className={`chip${cat === c.id ? ' active' : ''}`}
            onClick={() => setCat(c.id)}
          >
            {c.label}
          </button>
        ))}
      </div>
      <div className="grid grid-3">
        {list.map((v) => (
          <Card key={v.id}>
            <div className="row" style={{ marginBottom: 8 }}>
              <strong>{v.name}</strong>
              <span className={`class-badge ${CLASS_META[v.class].tone}`}>
                {v.class}
              </span>
            </div>
            <div className="import-preview">
              <img src={v.image} alt={v.name} loading="lazy" />
            </div>
            {v.limitedEndsIn ? (
              <span className="tag" style={{ marginBottom: 8 }}>
                LIMITED · {v.limitedEndsIn}
              </span>
            ) : null}
            <div className="stack">
              <div>
                <div className="stat-line">
                  <span>TOP SPEED</span>
                  <span>{v.topSpeed}</span>
                </div>
                <ProgressBar value={v.topSpeed} />
              </div>
              <div>
                <div className="stat-line">
                  <span>ACCELERATION</span>
                  <span>{v.acceleration}</span>
                </div>
                <ProgressBar value={v.acceleration} />
              </div>
              <div>
                <div className="stat-line">
                  <span>HANDLING</span>
                  <span>{v.handling}</span>
                </div>
                <ProgressBar value={v.handling} />
              </div>
              <div className="muted">SEATS · {v.seats}</div>
              <div className="value" style={{ fontSize: 18, color: 'var(--accent-soft)' }}>
                {formatNumber(v.price)} CR
              </div>
              <div className="row">
                <Button
                  variant="ghost"
                  onClick={() => notify('PREVIEW', `${v.name} (${v.class}) preview.`, '🚗')}
                >
                  PREVIEW
                </Button>
                <Button
                  onClick={async () => {
                    await nuiCallback('purchaseImport', { id: v.id, class: v.class });
                    notify('PIRKIMAS', `${v.name} · klasė ${v.class} (stub).`, '🛒');
                  }}
                >
                  PURCHASE
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

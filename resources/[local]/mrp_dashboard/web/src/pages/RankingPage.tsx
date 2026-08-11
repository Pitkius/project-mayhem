import { useMemo, useState } from 'react';
import type { DashboardData, LeaderboardEntry, RankingCategory } from '@/types/dashboard';
import { Card } from '@/components/ui';
import { CharacterFigure, PageHero } from '@/components/PageHero';

const TABS: { id: RankingCategory; label: string }[] = [
  { id: 'playtime', label: 'PLAYTIME' },
  { id: 'money', label: 'MONEY' },
  { id: 'missions', label: 'MISSIONS' },
  { id: 'rppass', label: 'RP PASS' },
  { id: 'events', label: 'EVENTS' },
];

function displayName(name: string) {
  return name.replace(/\s*\(tu\)\s*$/i, '').trim();
}

export function RankingPage({ data }: { data: DashboardData }) {
  const [tab, setTab] = useState<RankingCategory>('playtime');
  const rows = data.rankings[tab] || [];

  const { top, self } = useMemo(() => {
    const top10 = rows.filter((r) => r.rank <= 10).slice(0, 10);
    const me = rows.find((r) => r.isSelf) || null;
    return { top: top10, self: me as LeaderboardEntry | null };
  }, [rows]);

  return (
    <div className="page-shell">
      <PageHero
        theme="ranking"
        title="Reitingas"
        subtitle="Top 10 iš serverio DB. Dešinėje — tavo pozicija ir crew veikėjas."
        figureLabel={data.player.characterName}
        avatarUrl={data.player.avatarUrl}
        avatarFallback={data.player.characterName
          .split(' ')
          .map((p) => p[0])
          .join('')
          .slice(0, 2)
          .toUpperCase()}
      />

      <div className="chips">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            className={`chip${tab === t.id ? ' active' : ''}`}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="page-body page-body-fill">
        <div className="grid grid-rank">
          <Card title="TOP 10">
            <table className="table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>ŽAIDĖJAS</th>
                  <th>REZULTATAS</th>
                </tr>
              </thead>
              <tbody>
                {top.length === 0 ? (
                  <tr>
                    <td colSpan={3} className="muted">
                      Kol kas nėra duomenų.
                    </td>
                  </tr>
                ) : (
                  top.map((r) => (
                    <tr key={`${r.rank}-${r.name}`} className={r.isSelf ? 'self' : ''}>
                      <td>{r.rank}</td>
                      <td>
                        {displayName(r.name)}
                        {r.isSelf ? ' (tu)' : ''}
                      </td>
                      <td>{r.value}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </Card>

          <aside className="rank-side">
            <Card title="TAVO POZICIJA">
              {self ? (
                <div className="rank-self-card">
                  <div className="rank-num">#{self.rank}</div>
                  <div style={{ marginTop: 10 }}>
                    <strong>{displayName(self.name)}</strong>
                    <p className="muted" style={{ marginTop: 4 }}>
                      {self.value}
                    </p>
                  </div>
                </div>
              ) : (
                <p className="muted">Tavo pozicija bus matoma prisijungus žaidime.</p>
              )}
            </Card>
            <Card title="CREW">
              {data.player.avatarUrl ? (
                <div className="page-hero-character theme-ranking" style={{ width: '100%' }}>
                  <div className="page-hero-character-frame">
                    <img src={data.player.avatarUrl} alt="" draggable={false} />
                  </div>
                  <span className="char-figure-label">{data.player.characterName}</span>
                </div>
              ) : (
                <CharacterFigure theme="ranking" label={data.player.characterName} />
              )}
            </Card>
          </aside>
        </div>
      </div>
    </div>
  );
}

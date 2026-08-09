import { useState } from 'react';
import type { DashboardData, RankingCategory } from '@/types/dashboard';
import { Card } from '@/components/ui';

const TABS: { id: RankingCategory; label: string }[] = [
  { id: 'playtime', label: 'PLAYTIME' },
  { id: 'money', label: 'MONEY' },
  { id: 'missions', label: 'MISSIONS' },
  { id: 'rppass', label: 'RP PASS' },
  { id: 'events', label: 'EVENTS' },
];

export function RankingPage({ data }: { data: DashboardData }) {
  const [tab, setTab] = useState<RankingCategory>('playtime');
  const rows = data.rankings[tab] || [];

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Reitingas</h1>
          <p>Leaderboard pagal kategorijas.</p>
        </div>
      </div>
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
      <Card>
        <table className="table">
          <thead>
            <tr>
              <th>#</th>
              <th>ŽAIDĖJAS</th>
              <th>REIKŠMĖ</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={`${r.rank}-${r.name}`} className={r.isSelf ? 'self' : ''}>
                <td>{r.rank}</td>
                <td>{r.name}{r.isSelf ? ' (tu)' : ''}</td>
                <td>{r.value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

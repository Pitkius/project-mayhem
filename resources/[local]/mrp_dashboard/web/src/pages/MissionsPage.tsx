import { useMemo, useState } from 'react';
import type { DashboardData, MissionPeriod } from '@/types/dashboard';
import { Button, Card, ProgressBar, formatNumber } from '@/components/ui';
import { nuiCallback } from '@/services/nui';
import { PageHero } from '@/components/PageHero';

const TABS: { id: MissionPeriod; label: string }[] = [
  { id: 'daily', label: 'DIENINĖS' },
  { id: 'weekly', label: 'SAVAITINĖS' },
  { id: 'monthly', label: 'MĖNESINĖS' },
];

export function MissionsPage({
  data,
  onPatch,
  notify,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const [tab, setTab] = useState<MissionPeriod>('daily');
  const list = useMemo(
    () => data.missions.filter((m) => m.period === tab),
    [data.missions, tab],
  );

  return (
    <div className="page-shell">
      <PageHero
        theme="missions"
        title="Misijos"
        subtitle="Kasdienės, savaitinės ir mėnesinės užduotys — progress + rewardai."
        figureLabel="QUEST"
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
      <div className="page-body">
        <div className="mission-card-grid">
          {list.length === 0 ? (
            <Card>
              <p className="muted">Šioje kategorijoje misijų kol kas nėra.</p>
            </Card>
          ) : (
            list.map((m) => (
              <Card key={m.id}>
                <div className="row" style={{ marginBottom: 8 }}>
                  <strong>{m.title}</strong>
                  <span className="muted" style={{ textTransform: 'uppercase' }}>
                    {m.status}
                  </span>
                </div>
                <div className="stat-line">
                  <span>
                    {formatNumber(m.progress)} / {formatNumber(m.goal)} {m.unit}
                  </span>
                </div>
                <ProgressBar value={m.progress} max={m.goal} />
                <div className="row" style={{ marginTop: 12 }}>
                  <div className="muted">
                    REWARD · {m.rewardXp} XP · ${formatNumber(m.rewardMoney)}
                  </div>
                  <Button
                    disabled={m.status !== 'completed'}
                    onClick={async () => {
                      await nuiCallback('claimMission', { id: m.id });
                      onPatch({
                        missions: data.missions.map((x) =>
                          x.id === m.id ? { ...x, status: 'claimed' } : x,
                        ),
                      });
                      notify('MISIJA', `Gavai ${m.rewardXp} XP.`, '🎯');
                    }}
                  >
                    CLAIM
                  </Button>
                </div>
              </Card>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

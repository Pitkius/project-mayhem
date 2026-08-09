import { useMemo, useState } from 'react';
import type { DashboardData } from '@/types/dashboard';
import { Button, Card } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function RewardsPage({
  data,
  onPatch,
  notify,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const [filter, setFilter] = useState<'all' | 'unclaimed' | 'claimed'>('unclaimed');
  const list = useMemo(() => {
    if (filter === 'all') return data.rewards;
    if (filter === 'claimed') return data.rewards.filter((r) => r.claimed);
    return data.rewards.filter((r) => !r.claimed);
  }, [data.rewards, filter]);

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Apdovanojimai</h1>
          <p>Inbox iš RP Pass, daily, misijų ir eventų.</p>
        </div>
        <Button
          onClick={async () => {
            await nuiCallback('claimAllRewards');
            onPatch({
              rewards: data.rewards.map((r) => ({ ...r, claimed: true })),
            });
            notify('CLAIM ALL', 'Visi neatsiimti rewardai pasiimti.', '✨');
          }}
        >
          CLAIM ALL
        </Button>
      </div>
      <div className="chips">
        {(
          [
            ['unclaimed', 'NEATSIIMTI'],
            ['claimed', 'ATSIIMTI'],
            ['all', 'VISI'],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={`chip${filter === id ? ' active' : ''}`}
            onClick={() => setFilter(id)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="grid grid-2">
        {list.map((r) => (
          <Card key={r.id}>
            <div className="value" style={{ fontSize: 18 }}>
              {r.title}
            </div>
            <span className={`rarity-pill rarity-${r.rarity}`}>{r.rarity.toUpperCase()}</span>
            <p className="muted" style={{ margin: '8px 0 12px' }}>
              SOURCE · {r.source}
            </p>
            <Button
              disabled={r.claimed}
              onClick={async () => {
                await nuiCallback('claimReward', { id: r.id });
                onPatch({
                  rewards: data.rewards.map((x) =>
                    x.id === r.id ? { ...x, claimed: true } : x,
                  ),
                });
                notify('REWARD', r.title, '🎁');
              }}
            >
              {r.claimed ? 'CLAIMED' : 'CLAIM'}
            </Button>
          </Card>
        ))}
      </div>
    </div>
  );
}

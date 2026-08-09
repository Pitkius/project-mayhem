import { useMemo } from 'react';
import type { DashboardData } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function RpPassPage({
  data,
  onPatch,
  notify,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const pass = data.rpPass;
  const visibleLevels = useMemo(() => {
    const start = Math.max(1, pass.level - 5);
    const end = Math.min(pass.maxLevel, start + 14);
    const levels: number[] = [];
    for (let i = start; i <= end; i++) levels.push(i);
    return levels;
  }, [pass.level, pass.maxLevel]);

  const claim = async (level: number, track: 'free' | 'premium') => {
    await nuiCallback('claimRpPass', { level, track });
    const rewards = pass.rewards.map((r) =>
      r.level === level && r.track === track ? { ...r, claimed: true } : r,
    );
    onPatch({ rpPass: { ...pass, rewards } });
    notify('APDOVANOJIMAS', `RP Pass ${track} LVL ${level} pasiimtas.`, '🎁');
  };

  const claimAll = async () => {
    await nuiCallback('claimAllRpPass');
    const rewards = pass.rewards.map((r) => {
      if (r.locked) return r;
      if (r.track === 'premium' && !pass.premium) return r;
      if (r.level > pass.level) return r;
      return { ...r, claimed: true };
    });
    onPatch({ rpPass: { ...pass, rewards } });
    notify('CLAIM ALL', 'Visi galimi RP Pass rewardai pasiimti.', '✨');
  };

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>RP Pass</h1>
          <p>
            Level {pass.level} / {pass.maxLevel} · {pass.xp} / {pass.xpRequired} XP
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button variant="ghost" onClick={claimAll}>
            CLAIM ALL
          </Button>
          <Button
            variant="outline"
            onClick={async () => {
              await nuiCallback('buyPremium');
              onPatch({ rpPass: { ...pass, premium: true } });
              notify('PREMIUM', 'RP Pass Premium aktyvuotas (stub).', '💎');
            }}
            disabled={pass.premium}
          >
            {pass.premium ? 'PREMIUM ON' : 'BUY PREMIUM'}
          </Button>
        </div>
      </div>

      <Card>
        <div className="stat-line">
          <span>XP</span>
          <span>
            {pass.xp} / {pass.xpRequired}
          </span>
        </div>
        <ProgressBar value={pass.xp} max={pass.xpRequired} />
      </Card>

      <div style={{ marginTop: 14 }} className="stack">
        <Card title="FREE TRACK">
          <div className="track-wrap">
            <div className="track">
              {visibleLevels
                .filter((lvl) => lvl % 5 === 0)
                .map((lvl) => {
                  const r = pass.rewards.find((x) => x.level === lvl && x.track === 'free');
                  if (!r) return null;
                  return (
                    <div
                      key={`f-${lvl}`}
                      className={`track-node${lvl === pass.level ? ' current' : ''}${
                        r.claimed ? ' claimed' : ''
                      }${r.locked ? ' locked' : ''}`}
                    >
                      <strong>LVL {lvl}</strong>
                      <span className="muted">{r.label}</span>
                      <span className={`rarity-pill rarity-${r.rarity}`}>
                        {r.rarity}
                      </span>
                      <Button
                        variant="primary"
                        disabled={r.locked || r.claimed || lvl > pass.level}
                        onClick={() => claim(lvl, 'free')}
                      >
                        {r.claimed ? 'TAKEN' : 'CLAIM'}
                      </Button>
                    </div>
                  );
                })}
            </div>
          </div>
        </Card>

        <Card title="PREMIUM TRACK">
          <div className="track-wrap">
            <div className="track">
              {visibleLevels.map((lvl) => {
                const r = pass.rewards.find((x) => x.level === lvl && x.track === 'premium');
                if (!r) return null;
                const premiumLocked = !pass.premium;
                return (
                  <div
                    key={`p-${lvl}`}
                    className={`track-node${lvl === pass.level ? ' current' : ''}${
                      r.claimed ? ' claimed' : ''
                    }${r.locked || premiumLocked ? ' locked' : ''}`}
                  >
                    <strong>LVL {lvl}</strong>
                    <span className="muted">{r.label}</span>
                    <span className={`rarity-pill rarity-${r.rarity}`}>
                      {r.rarity}
                    </span>
                    <Button
                      variant="primary"
                      disabled={
                        premiumLocked || r.locked || r.claimed || lvl > pass.level
                      }
                      onClick={() => claim(lvl, 'premium')}
                    >
                      {premiumLocked ? 'LOCKED' : r.claimed ? 'TAKEN' : 'CLAIM'}
                    </Button>
                  </div>
                );
              })}
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}

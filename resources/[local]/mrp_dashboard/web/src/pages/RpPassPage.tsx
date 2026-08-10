import { useMemo } from 'react';
import type { DashboardData, RpPassReward } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

function RewardCard({
  reward,
  currentLevel,
  premiumLocked,
  onClaim,
}: {
  reward: RpPassReward;
  currentLevel: number;
  premiumLocked?: boolean;
  onClaim: () => void;
}) {
  const locked = reward.locked || !!premiumLocked || reward.level > currentLevel;
  return (
    <div
      className={`track-node${reward.level === currentLevel ? ' current' : ''}${
        reward.claimed ? ' claimed' : ''
      }${locked ? ' locked' : ''}`}
    >
      <strong>LVL {reward.level}</strong>
      <div className="pass-reward-icon" aria-hidden>
        {reward.icon}
      </div>
      <span className="pass-reward-name">{reward.label}</span>
      <span className="pass-reward-qty">×{reward.amount}</span>
      <span className={`rarity-pill rarity-${reward.rarity}`}>{reward.rarity}</span>
      <Button
        variant="primary"
        disabled={locked || reward.claimed}
        onClick={onClaim}
      >
        {premiumLocked ? 'LOCKED' : reward.claimed ? 'TAKEN' : 'CLAIM'}
      </Button>
    </div>
  );
}

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
    const reward = pass.rewards.find((r) => r.level === level && r.track === track);
    await nuiCallback('claimRpPass', {
      level,
      track,
      itemName: reward?.itemName,
      amount: reward?.amount,
    });
    const rewards = pass.rewards.map((r) =>
      r.level === level && r.track === track ? { ...r, claimed: true } : r,
    );
    onPatch({ rpPass: { ...pass, rewards } });
    notify(
      'APDOVANOJIMAS',
      `${reward?.icon ?? '🎁'} ${reward?.label ?? 'Item'} ×${reward?.amount ?? 1}`,
      reward?.icon ?? '🎁',
    );
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
    notify('CLAIM ALL', 'Visi galimi RP Pass itemai pasiimti.', '✨');
  };

  const freeVisible = visibleLevels.filter((lvl) => lvl === 1 || lvl % 5 === 0);

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>RP Pass</h1>
          <p>
            Level {pass.level} / {pass.maxLevel} · Free: 1 / 5 / 10… · Premium: kiekvienas lygis
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
        <Card title="FREE TRACK · itemai kas 5 lygius (+ LVL 1)">
          <div className="track-wrap">
            <div className="track">
              {freeVisible.map((lvl) => {
                const r = pass.rewards.find((x) => x.level === lvl && x.track === 'free');
                if (!r) return null;
                return (
                  <RewardCard
                    key={`f-${lvl}`}
                    reward={r}
                    currentLevel={pass.level}
                    onClaim={() => void claim(lvl, 'free')}
                  />
                );
              })}
            </div>
          </div>
        </Card>

        <Card title="PREMIUM TRACK · itemas kiekviename lygyje">
          <div className="track-wrap">
            <div className="track">
              {visibleLevels.map((lvl) => {
                const r = pass.rewards.find((x) => x.level === lvl && x.track === 'premium');
                if (!r) return null;
                return (
                  <RewardCard
                    key={`p-${lvl}`}
                    reward={r}
                    currentLevel={pass.level}
                    premiumLocked={!pass.premium}
                    onClaim={() => void claim(lvl, 'premium')}
                  />
                );
              })}
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}

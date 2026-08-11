import { useEffect, useMemo, useRef } from 'react';
import type { DashboardData, ItemRarity, RpPassReward } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback } from '@/services/nui';
import { PageHero } from '@/components/PageHero';

function emptySlot(
  level: number,
  track: 'free' | 'premium',
  currentLevel: number,
): RpPassReward {
  return {
    level,
    track,
    label: '—',
    itemName: '',
    amount: 0,
    icon: '',
    rarity: 'common' as ItemRarity,
    claimed: false,
    locked: level > currentLevel,
    empty: true,
  };
}

/** Resolve reward for a level; missing entries become empty placeholders so the grid stays 1–max. */
function resolveReward(
  rewards: RpPassReward[],
  level: number,
  track: 'free' | 'premium',
  currentLevel: number,
): RpPassReward {
  const found = rewards.find((r) => r.level === level && r.track === track);
  if (found) return found;
  return emptySlot(level, track, currentLevel);
}

function RewardCard({
  reward,
  currentLevel,
  premiumLocked,
  nodeRef,
  onClaim,
}: {
  reward: RpPassReward;
  currentLevel: number;
  premiumLocked?: boolean;
  nodeRef?: (el: HTMLDivElement | null) => void;
  onClaim: () => void;
}) {
  const isEmpty = !!reward.empty || !reward.itemName;
  const locked = isEmpty || reward.locked || !!premiumLocked || reward.level > currentLevel;
  return (
    <div
      ref={nodeRef}
      className={`track-node${reward.level === currentLevel ? ' current' : ''}${
        reward.claimed ? ' claimed' : ''
      }${locked ? ' locked' : ''}${isEmpty ? ' empty' : ''}`}
    >
      <strong>LVL {reward.level}</strong>
      <div className="pass-reward-icon" aria-hidden>
        {isEmpty ? '·' : reward.icon}
      </div>
      <span className="pass-reward-name">{isEmpty ? 'Tuščia' : reward.label}</span>
      {!isEmpty ? <span className="pass-reward-qty">×{reward.amount}</span> : (
        <span className="pass-reward-qty pass-reward-qty--empty">—</span>
      )}
      {!isEmpty ? (
        <span className={`rarity-pill rarity-${reward.rarity}`}>{reward.rarity}</span>
      ) : (
        <span className="rarity-pill rarity-common">empty</span>
      )}
      <Button
        variant="primary"
        disabled={isEmpty || locked || reward.claimed}
        onClick={onClaim}
      >
        {isEmpty ? '—' : premiumLocked ? 'LOCKED' : reward.claimed ? 'TAKEN' : 'CLAIM'}
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
  const maxLevel = Math.max(1, pass.maxLevel || 100);
  const allLevels = useMemo(() => {
    const levels: number[] = [];
    for (let i = 1; i <= maxLevel; i++) levels.push(i);
    return levels;
  }, [maxLevel]);

  const currentNodeRef = useRef<HTMLDivElement | null>(null);
  const freeWrapRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const node = currentNodeRef.current;
    const wrap = freeWrapRef.current;
    if (!node || !wrap) return;
    const left = node.offsetLeft - wrap.clientWidth / 2 + node.clientWidth / 2;
    wrap.scrollTo({ left: Math.max(0, left), behavior: 'smooth' });
  }, [pass.level, maxLevel]);

  const claim = async (level: number, track: 'free' | 'premium') => {
    const reward = resolveReward(pass.rewards, level, track, pass.level);
    if (reward.empty || !reward.itemName) return;
    await nuiCallback('claimRpPass', {
      level,
      track,
      itemName: reward.itemName,
      amount: reward.amount,
    });
    const rewards = pass.rewards.map((r) =>
      r.level === level && r.track === track ? { ...r, claimed: true } : r,
    );
    onPatch({ rpPass: { ...pass, rewards } });
    notify(
      'APDOVANOJIMAS',
      `${reward.icon} ${reward.label} ×${reward.amount}`,
      reward.icon,
    );
  };

  const claimAll = async () => {
    await nuiCallback('claimAllRpPass');
    const rewards = pass.rewards.map((r) => {
      if (r.empty || !r.itemName) return r;
      if (r.locked) return r;
      if (r.track === 'premium' && !pass.premium) return r;
      if (r.level > pass.level) return r;
      return { ...r, claimed: true };
    });
    onPatch({ rpPass: { ...pass, rewards } });
    notify('CLAIM ALL', 'Visi galimi RP Pass itemai pasiimti.', '✨');
  };

  return (
    <div className="page-shell">
      <PageHero
        theme="pass"
        title="RP Pass"
        subtitle={`Level ${pass.level} / ${maxLevel} · Free + Premium · 1–${maxLevel}`}
        figureLabel="PASS"
        actions={
          <>
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
          </>
        }
      />

      <div className="page-body">
        <Card>
          <div className="stat-line">
            <span>XP</span>
            <span>
              {pass.xp} / {pass.xpRequired}
            </span>
          </div>
          <ProgressBar value={pass.xp} max={pass.xpRequired} />
        </Card>

        <div className="stack">
          <Card title={`FREE TRACK · lygiai 1–${maxLevel}`}>
            <div className="track-wrap" ref={freeWrapRef}>
              <div className="track">
                {allLevels.map((lvl) => {
                  const r = resolveReward(pass.rewards, lvl, 'free', pass.level);
                  return (
                    <RewardCard
                      key={`f-${lvl}`}
                      reward={r}
                      currentLevel={pass.level}
                      nodeRef={lvl === pass.level ? (el) => { currentNodeRef.current = el; } : undefined}
                      onClaim={() => void claim(lvl, 'free')}
                    />
                  );
                })}
              </div>
            </div>
          </Card>

          <Card title={`PREMIUM TRACK · lygiai 1–${maxLevel}`}>
            <div className="track-wrap">
              <div className="track">
                {allLevels.map((lvl) => {
                  const r = resolveReward(pass.rewards, lvl, 'premium', pass.level);
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
    </div>
  );
}

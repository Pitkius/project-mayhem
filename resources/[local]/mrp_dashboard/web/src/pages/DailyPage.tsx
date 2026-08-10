import { useMemo, useState } from 'react';
import type { CrateDef, DashboardData, ItemRarity } from '@/types/dashboard';
import { RARITY_LABEL } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback, isDevPreview } from '@/services/nui';
import type { CrateSpinPayload } from '@/components/LootSpinOverlay';

function crateImg(def: CrateDef) {
  if (isDevPreview()) return `/assets/crates/${def.image}`;
  return `nui://mrp_dashboard/html/assets/crates/${def.image}`;
}

export function DailyPage({
  data,
  onPatch,
  notify,
  onDevSpin,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
  onDevSpin?: (payload: CrateSpinPayload) => void;
}) {
  const d = data.daily;
  const crates = d.crates ?? [];
  const [selectedId, setSelectedId] = useState(d.crateItem || crates[0]?.id || 'dienos_deze');
  const selected = useMemo(
    () => crates.find((c) => c.id === selectedId) || crates[0],
    [crates, selectedId],
  );
  const readyByTime = d.playedMinutes >= d.requiredMinutes;
  const canClaim = d.canClaim && readyByTime && !d.claimedToday;

  const claimCrate = async () => {
    if (!canClaim) return;
    await nuiCallback('claimDailyCrate', {
      day: d.day,
      item: d.crateItem,
    });
    onPatch({
      daily: {
        ...d,
        claimedToday: true,
        canClaim: false,
        days: d.days.map((x) => (x.current ? { ...x, claimed: true } : x)),
      },
    });
    notify('DIENOS DĖŽĖ', `${d.crateLabel} įdėta į inventorių. Naudok ją — prasuks loot.`, '📦');
  };

  const previewSpin = () => {
    if (!selected || !onDevSpin) return;
    const pool = selected.lootPool;
    const winner = pool[Math.floor(Math.random() * pool.length)];
    const reelLen = 48;
    const winnerIndex = 40;
    const reel = Array.from({ length: reelLen }, (_, i) => {
      const src = i === winnerIndex ? winner : pool[Math.floor(Math.random() * pool.length)];
      return {
        kind: (src.itemName === 'xp' ? 'xp' : 'item') as 'xp' | 'item',
        item: src.itemName === 'xp' ? undefined : src.itemName,
        amount: src.amount,
        rarity: src.rarity,
        label: src.name,
        icon: src.icon || '🎁',
        iconUrl: src.iconUrl,
      };
    });
    onDevSpin({
      token: 'dev',
      crateId: selected.id,
      crateLabel: selected.label,
      crateIcon: selected.icon,
      crateIconUrl: crateImg(selected),
      accent: selected.accent,
      reel,
      winnerIndex,
      winner: reel[winnerIndex],
    });
  };

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Dėžės</h1>
          <p>
            DAY {d.day}/{d.maxDays} · Streak {d.streak} · Atidarymas inventoriuje su CSGO spin
          </p>
        </div>
      </div>

      <div className="crate-catalog">
        {crates.map((c) => (
          <button
            key={c.id}
            type="button"
            className={`crate-card${selected?.id === c.id ? ' active' : ''}`}
            style={{ ['--crate-accent' as string]: c.accent }}
            onClick={() => setSelectedId(c.id)}
          >
            <img src={crateImg(c)} alt="" className="crate-card-img" draggable={false} />
            <strong>{c.label}</strong>
            <span className="muted">{c.description}</span>
          </button>
        ))}
      </div>

      {selected ? (
        <div className="grid grid-2" style={{ marginTop: 14 }}>
          <Card title={selected.label.toUpperCase()}>
            <div className="crate-stage">
              <img
                src={crateImg(selected)}
                alt=""
                className="crate-hero-img"
                draggable={false}
              />
              <p className="muted" style={{ textAlign: 'center' }}>
                Itemas <code>{selected.id}</code> · naudok inventoriuje → spin → loot su ikonomis
              </p>

              {selected.id === d.crateItem ? (
                <>
                  <div style={{ marginTop: 8 }}>
                    <div className="stat-line">
                      <span>Playtime šiandien</span>
                      <span>
                        {Math.floor(d.playedMinutes / 60)}h {d.playedMinutes % 60}m /{' '}
                        {Math.floor(d.requiredMinutes / 60)}h
                      </span>
                    </div>
                    <ProgressBar value={d.playedMinutes} max={d.requiredMinutes} />
                  </div>
                  <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center', gap: 8 }}>
                    <Button disabled={!canClaim} onClick={() => void claimCrate()}>
                      {d.claimedToday
                        ? 'JAU PASIIMTA'
                        : !readyByTime
                          ? 'REIKIA PLAYTIME'
                          : 'PASIIMTI DIENOS DĖŽĘ'}
                    </Button>
                  </div>
                </>
              ) : (
                <p className="muted" style={{ textAlign: 'center' }}>
                  Šią dėžę gauni iš eventų / RP Pass / savaitės rewardų.
                </p>
              )}

              {isDevPreview() ? (
                <div style={{ display: 'flex', justifyContent: 'center', marginTop: 10 }}>
                  <Button variant="outline" onClick={previewSpin}>
                    DEV: TEST SPIN
                  </Button>
                </div>
              ) : null}
            </div>
          </Card>

          <Card title="KAS GALI IŠKRISTI">
            <p className="muted" style={{ marginBottom: 10 }}>
              Atidarius — CSGO ratas su itemų ikonomis. Vienas dropas.
            </p>
            <div className="stack">
              {selected.lootPool.map((item) => (
                <div key={item.id} className="row loot-preview-row">
                  <span className="loot-preview-left">
                    {item.iconUrl ? (
                      <img src={item.iconUrl} alt="" className="loot-preview-icon" />
                    ) : (
                      <span>{item.icon ?? '🎁'}</span>
                    )}
                    <span>
                      {item.name}
                      <span className="muted"> ×{item.amount}</span>
                    </span>
                  </span>
                  <span className={`rarity-pill rarity-${item.rarity}`}>
                    {RARITY_LABEL[item.rarity]}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      ) : null}

      <div style={{ marginTop: 14 }} className="day-grid">
        {d.days.map((day) => (
          <div
            key={day.day}
            className={`day-card${day.current ? ' current' : ''}${day.claimed ? ' claimed' : ''}`}
          >
            <strong>DAY {day.day}</strong>
            <div className="muted" style={{ marginTop: 6 }}>
              {day.label}
            </div>
            {day.rarityHint ? (
              <span
                className={`rarity-pill rarity-${day.rarityHint}`}
                style={{ marginTop: 8, display: 'inline-flex' }}
              >
                {RARITY_LABEL[day.rarityHint as ItemRarity]}
              </span>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}

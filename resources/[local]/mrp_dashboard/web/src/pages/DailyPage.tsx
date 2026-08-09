import type { DashboardData, ItemRarity } from '@/types/dashboard';
import { RARITY_LABEL } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function DailyPage({
  data,
  onPatch,
  notify,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const d = data.daily;
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
    notify(
      'DIENOS DĖŽĖ',
      `${d.crateLabel} įdėta į inventorių. Atidaryk ją ten.`,
      '📦',
    );
  };

  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Dienos dėžė</h1>
          <p>
            DAY {d.day} / {d.maxDays} · Streak {d.streak} · Pasiimi itemą, atidarai inventoriuje
          </p>
        </div>
      </div>

      <div className="grid grid-2">
        <Card title="DIENOS DĖŽĖ">
          <div className="crate-stage">
            <div className="crate-box">
              <div className="crate-lid" />
              <div className="crate-body">📦</div>
            </div>
            <div className="value" style={{ textAlign: 'center', fontSize: 20 }}>
              {d.crateLabel}
            </div>
            <p className="muted" style={{ textAlign: 'center' }}>
              Itemas <code>{d.crateItem}</code> · atidaromas per inventorių · random loot iš
              lentelės (be ginklų)
            </p>

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

            <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center' }}>
              <Button disabled={!canClaim} onClick={() => void claimCrate()}>
                {d.claimedToday
                  ? 'JAU PASIIMTA'
                  : !readyByTime
                    ? 'REIKIA PLAYTIME'
                    : 'PASIIMTI Į INVENTORIŲ'}
              </Button>
            </div>
          </div>
        </Card>

        <Card title="KAS GALI IŠKRISTI">
          <p className="muted" style={{ marginBottom: 10 }}>
            Atidarius dėžę inventoriuje — random vienas iš šių (serverio lentelė).
          </p>
          <div className="stack">
            {d.lootPool.map((item) => (
              <div key={item.id} className="row loot-preview-row">
                <span>
                  {item.icon ?? '🎁'} {item.name}
                  <span className="muted"> ×{item.amount}</span>
                </span>
                <span className={`rarity-pill rarity-${item.rarity}`}>
                  {RARITY_LABEL[item.rarity]}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div style={{ marginTop: 14 }} className="day-grid">
        {d.days.map((day) => (
          <div
            key={day.day}
            className={`day-card${day.current ? ' current' : ''}${
              day.claimed ? ' claimed' : ''
            }`}
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

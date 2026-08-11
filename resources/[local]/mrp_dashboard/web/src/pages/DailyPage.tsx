import { useMemo, useState } from 'react';
import type { CrateDef, DashboardData, ItemRarity } from '@/types/dashboard';
import { RARITY_LABEL } from '@/types/dashboard';
import { Button, Card, ProgressBar } from '@/components/ui';
import { nuiCallback, isDevPreview } from '@/services/nui';
import type { CrateSpinPayload } from '@/components/LootSpinOverlay';
import { PageHero } from '@/components/PageHero';

function crateImg(def: CrateDef) {
  if (isDevPreview()) return `/assets/crates/${def.image}`;
  return `nui://mrp_dashboard/html/assets/crates/${def.image}`;
}

function fmtMin(m: number) {
  const h = Math.floor(m / 60);
  const min = m % 60;
  if (h <= 0) return `${min} min`;
  return `${h}h ${min}m`;
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
  const weekly = d.weekly;
  const req = d.requirements;
  // DIENINIS: only free daily + weekly crates (shop crates stay under Premium)
  const crates = useMemo(
    () => (d.crates ?? []).filter((c) => c.kind === 'daily' || c.kind === 'weekly'),
    [d.crates],
  );
  const [selectedId, setSelectedId] = useState(d.crateItem || crates[0]?.id || 'dienos_deze');
  const selected = useMemo(
    () => crates.find((c) => c.id === selectedId) || crates[0],
    [crates, selectedId],
  );

  const dailyPlayOk = req?.dailyPlay ?? d.playedMinutes >= d.requiredMinutes;
  const dailyMissionOk =
    req?.dailyMission ?? (d.missionsCompleted ?? 0) >= (d.requiredMissions ?? 0);
  const canClaimDaily = d.canClaim && !d.claimedToday;

  const weeklyPlayOk = req?.weeklyPlay ?? (weekly ? weekly.playedMinutes >= weekly.requiredMinutes : false);
  const weeklyMissionOk =
    req?.weeklyMission ??
    weekly?.missionDone ??
    (weekly ? (weekly.missionsCompleted ?? 0) >= (weekly.requiredMissions ?? 0) : false);
  const canClaimWeekly = Boolean(weekly?.canClaim && !weekly?.claimed);

  const claimDaily = async () => {
    if (!canClaimDaily) return;
    await nuiCallback('claimDailyCrate', { item: d.crateItem });
    onPatch({
      daily: {
        ...d,
        claimedToday: true,
        canClaim: false,
        days: d.days.map((x) => (x.current ? { ...x, claimed: true } : x)),
      },
    });
    notify('DIENOS DĖŽĖ', 'Dėžė įdėta į inventorių — naudok ją, kad prasuktum loot.', '📦');
  };

  const claimWeekly = async () => {
    if (!weekly || !canClaimWeekly) return;
    await nuiCallback('claimWeeklyCrate', { item: weekly.crateItem });
    onPatch({
      daily: {
        ...d,
        weekly: { ...weekly, claimed: true, canClaim: false },
      },
    });
    notify('SAVAITĖS DĖŽĖ', 'Savaitės dėžė įdėta į inventorių — atidaryk inventoriuje.', '🏆');
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

  const isDaily = selected?.id === d.crateItem;
  const isWeekly = selected?.id === weekly?.crateItem;
  const isShopCrate = selected && !isDaily && !isWeekly;

  const dailyReqM = d.requiredMissions ?? 3;
  const dailyDoneM = d.missionsCompleted ?? 0;
  const weeklyReqM = weekly?.requiredMissions ?? 12;
  const weeklyDoneM = weekly?.missionsCompleted ?? 0;

  return (
    <div className="page-shell">
      <PageHero
        theme="crates"
        title="Dėžės"
        subtitle={`DAY ${d.day}/${d.maxDays} · Streak ${d.streak} · Dieninė = playtime + ${dailyReqM} mis. · Savaitinė = playtime + ${weeklyReqM} mis.`}
        figureLabel={data.player.characterName}
        avatarUrl={data.player.avatarUrl}
      />

      <div className="page-body">
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
          <div className="grid grid-2">
            <Card title={selected.label.toUpperCase()}>
              <div className="crate-stage">
                <img
                  src={crateImg(selected)}
                  alt=""
                  className="crate-hero-img"
                  draggable={false}
                />
                <p className="muted" style={{ textAlign: 'center' }}>
                  {isDaily
                    ? `Nemokama dienos dėžė: surink ${fmtMin(d.requiredMinutes)} playtime ir užbaik ${dailyReqM} misijas šiandien.`
                    : isWeekly
                      ? `Nemokama savaitės dėžė: surink ${fmtMin(weekly?.requiredMinutes ?? 0)} playtime ir užbaik ${weeklyReqM} misijas šią savaitę.`
                      : 'Perkama Premium parduotuvėje už kreditus. Atidaryk inventoriuje — CSGO spin.'}
                </p>

                {isDaily ? (
                  <>
                    <div style={{ marginTop: 8 }} className="stack">
                      <div className="stat-line">
                        <span>{dailyPlayOk ? '✓' : '○'} Playtime šiandien</span>
                        <span>
                          {fmtMin(d.playedMinutes)} / {fmtMin(d.requiredMinutes)}
                        </span>
                      </div>
                      <ProgressBar value={d.playedMinutes} max={d.requiredMinutes} />
                      <div className="stat-line" style={{ marginTop: 8 }}>
                        <span>{dailyMissionOk ? '✓' : '○'} Misijos šiandien</span>
                        <span>
                          {dailyDoneM} / {dailyReqM}
                        </span>
                      </div>
                      <ProgressBar value={dailyDoneM} max={dailyReqM} />
                      {!dailyPlayOk || !dailyMissionOk ? (
                        <p className="muted" style={{ marginTop: 8, fontSize: 12 }}>
                          {!dailyPlayOk && !dailyMissionOk
                            ? 'Užrakinta: trūksta playtime ir misijų.'
                            : !dailyPlayOk
                              ? 'Užrakinta: trūksta playtime.'
                              : 'Užrakinta: trūksta misijų (trucking / gaujos / darbai).'}
                        </p>
                      ) : null}
                    </div>
                    <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center', gap: 8 }}>
                      <Button disabled={!canClaimDaily} onClick={() => void claimDaily()}>
                        {d.claimedToday
                          ? 'JAU PASIIMTA'
                          : !dailyPlayOk
                            ? 'REIKIA PLAYTIME'
                            : !dailyMissionOk
                              ? `REIKIA MISIJŲ (${dailyDoneM}/${dailyReqM})`
                              : 'PASIIMTI DIENOS DĖŽĘ'}
                      </Button>
                    </div>
                  </>
                ) : null}

                {isWeekly && weekly ? (
                  <>
                    <div style={{ marginTop: 8 }} className="stack">
                      <div className="stat-line">
                        <span>{weeklyPlayOk ? '✓' : '○'} Playtime šią savaitę</span>
                        <span>
                          {fmtMin(weekly.playedMinutes)} / {fmtMin(weekly.requiredMinutes)}
                        </span>
                      </div>
                      <ProgressBar value={weekly.playedMinutes} max={weekly.requiredMinutes} />
                      <div className="stat-line" style={{ marginTop: 8 }}>
                        <span>{weeklyMissionOk ? '✓' : '○'} Misijos šią savaitę</span>
                        <span>
                          {weeklyDoneM} / {weeklyReqM}
                        </span>
                      </div>
                      <ProgressBar value={weeklyDoneM} max={weeklyReqM} />
                      {!weeklyPlayOk || !weeklyMissionOk ? (
                        <p className="muted" style={{ marginTop: 8, fontSize: 12 }}>
                          {!weeklyPlayOk && !weeklyMissionOk
                            ? 'Užrakinta: trūksta savaitės playtime ir misijų.'
                            : !weeklyPlayOk
                              ? 'Užrakinta: trūksta savaitės playtime.'
                              : 'Užrakinta: trūksta misijų (trucking / gaujos / darbai).'}
                        </p>
                      ) : null}
                    </div>
                    <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center', gap: 8 }}>
                      <Button disabled={!canClaimWeekly} onClick={() => void claimWeekly()}>
                        {weekly.claimed
                          ? 'JAU PASIIMTA'
                          : !weeklyPlayOk
                            ? 'REIKIA PLAYTIME'
                            : !weeklyMissionOk
                              ? `REIKIA MISIJŲ (${weeklyDoneM}/${weeklyReqM})`
                              : 'PASIIMTI SAVAITĖS DĖŽĘ'}
                      </Button>
                    </div>
                  </>
                ) : null}

                {isShopCrate ? (
                  <p className="muted" style={{ textAlign: 'center', marginTop: 8 }}>
                    Kaina: {selected.priceCredits ?? '—'} kreditų · Premium → Dėžės
                  </p>
                ) : null}

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
                Atidarius inventoriuje — ratas su garsu, vienas dropas.
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

        <div className="day-grid">
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
    </div>
  );
}

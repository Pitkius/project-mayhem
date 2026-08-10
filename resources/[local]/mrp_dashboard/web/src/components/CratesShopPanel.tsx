import { useMemo, useState } from 'react';
import type { CrateDef, DashboardData } from '@/types/dashboard';
import { RARITY_LABEL } from '@/types/dashboard';
import { Button, Card, formatNumber } from '@/components/ui';
import { isDevPreview, nuiCallback } from '@/services/nui';
import type { CrateSpinPayload } from '@/components/LootSpinOverlay';

function crateImg(def: CrateDef) {
  if (isDevPreview()) return `/assets/crates/${def.image}`;
  return `nui://mrp_dashboard/html/assets/crates/${def.image}`;
}

export function CratesShopPanel({
  data,
  notify,
  onDevSpin,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
  onDevSpin?: (payload: CrateSpinPayload) => void;
}) {
  const crates = data.daily.crates ?? [];
  const shopCrates = crates.filter((c) => c.kind !== 'daily' && c.kind !== 'weekly');
  const [selectedId, setSelectedId] = useState(shopCrates[0]?.id || crates[0]?.id || '');
  const selected = useMemo(
    () => crates.find((c) => c.id === selectedId) || shopCrates[0] || crates[0],
    [crates, shopCrates, selectedId],
  );

  const buyCrate = async (crate: CrateDef) => {
    if (!crate.priceCredits) {
      notify('DĖŽĖ', 'Šią dėžę gauni iš dieninio / eventų.', crate.icon);
      return;
    }
    await nuiCallback('purchaseCrate', { id: crate.id, price: crate.priceCredits });
    notify('PIRKIMAS', `${crate.label} · −${formatNumber(crate.priceCredits)} CR (jei užteko balanso).`, crate.icon);
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
    <div className="premium-panel">
      <div className="crate-catalog">
        {shopCrates.map((c) => (
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
            {c.priceCredits ? (
              <span className="crate-price">{formatNumber(c.priceCredits)} CR</span>
            ) : (
              <span className="crate-price free">FREE</span>
            )}
          </button>
        ))}
      </div>

      {selected ? (
        <div className="grid grid-2" style={{ marginTop: 16 }}>
          <Card title={selected.label.toUpperCase()}>
            <div className="crate-stage">
              <img src={crateImg(selected)} alt="" className="crate-hero-img" draggable={false} />
              <p className="muted" style={{ textAlign: 'center' }}>
                Atidaryk inventoriuje — CSGO spin su itemų ikonomis.
              </p>
              <div style={{ display: 'flex', justifyContent: 'center', gap: 8, flexWrap: 'wrap' }}>
                {selected.priceCredits ? (
                  <Button onClick={() => void buyCrate(selected)}>
                    PIRKTI · {formatNumber(selected.priceCredits)} CR
                  </Button>
                ) : (
                  <Button variant="ghost" onClick={() => notify('INFO', 'Pasiimk per Dieninį tabą.', '📦')}>
                    PER DIENINĮ
                  </Button>
                )}
                {isDevPreview() ? (
                  <Button variant="outline" onClick={previewSpin}>
                    DEV SPIN
                  </Button>
                ) : null}
              </div>
            </div>
          </Card>
          <Card title="LOOT LENTELĖ">
            <div className="stack">
              {selected.lootPool.map((item) => (
                <div key={item.id} className="row loot-preview-row">
                  <span className="loot-preview-left">
                    <span>{item.icon ?? '🎁'}</span>
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
    </div>
  );
}

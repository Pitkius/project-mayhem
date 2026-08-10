import { useState } from 'react';
import type { DashboardData } from '@/types/dashboard';
import { Button, formatNumber } from '@/components/ui';
import { nuiCallback } from '@/services/nui';
import { ImportsPage } from '@/pages/ImportsPage';
import { VipPage } from '@/pages/VipPage';
import { CratesShopPanel } from '@/components/CratesShopPanel';
import type { CrateSpinPayload } from '@/components/LootSpinOverlay';
import { PageHero } from '@/components/PageHero';

type PremiumTab = 'imports' | 'crates' | 'vip';

const TABS: { id: PremiumTab; label: string }[] = [
  { id: 'imports', label: 'IMPORTAI' },
  { id: 'crates', label: 'DĖŽĖS' },
  { id: 'vip', label: 'VIP' },
];

export function PremiumShopPage({
  data,
  notify,
  onDevSpin,
  initialTab = 'imports',
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
  onDevSpin?: (payload: CrateSpinPayload) => void;
  initialTab?: PremiumTab;
}) {
  const [tab, setTab] = useState<PremiumTab>(initialTab);

  return (
    <div className="page-shell premium-shop">
      <PageHero
        theme="premium"
        title="Premium parduotuvė"
        subtitle={`Importai · Dėžės · VIP — 1€ = 1 CR · balansas ${formatNumber(data.player.credits)} CR`}
        figureLabel="SHOP"
        actions={
          <Button
            variant="outline"
            onClick={async () => {
              await nuiCallback('openTebexStore');
              notify('TEBEX', '1€ = 1 kreditas. Nuoroda į store išsiųsta chate.', '💳');
            }}
          >
            PIRKTI KREDITUS
          </Button>
        }
      />

      <div className="premium-tabs" role="tablist">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            aria-selected={tab === t.id}
            className={`premium-tab${tab === t.id ? ' active' : ''}`}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="page-body premium-tab-panel anim-fade-up" key={tab}>
        {tab === 'imports' ? <ImportsPage data={data} notify={notify} embedded /> : null}
        {tab === 'crates' ? (
          <CratesShopPanel data={data} notify={notify} onDevSpin={onDevSpin} />
        ) : null}
        {tab === 'vip' ? <VipPage data={data} notify={notify} embedded /> : null}
      </div>
    </div>
  );
}

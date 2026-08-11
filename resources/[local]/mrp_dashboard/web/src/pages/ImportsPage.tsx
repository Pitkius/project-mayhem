import type { DashboardData } from '@/types/dashboard';
import { Button } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function ImportsPage({
  embedded = false,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
  embedded?: boolean;
}) {
  const openSalon = async () => {
    await nuiCallback('openImportDealership');
  };

  return (
    <div className="premium-panel import-salon-gate">
      {!embedded ? (
        <div className="page-title">
          <div>
            <h1>Importų salonas</h1>
            <p>Prabangūs / REH automobiliai (shop = luxury).</p>
          </div>
        </div>
      ) : null}

      <div className="card" style={{ maxWidth: 520, padding: 24 }}>
        <h2 style={{ marginTop: 0, marginBottom: 8 }}>Importų salonas</h2>
        <p className="muted" style={{ marginBottom: 18 }}>
          Atidaro pilną importų katalogą su 3D peržiūra (Simion showroom).
          Pirkimas banku / cash — ne CR stub.
        </p>
        <Button onClick={() => void openSalon()}>Atidaryti Importų saloną</Button>
      </div>
    </div>
  );
}

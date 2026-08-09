import type { DashboardData } from '@/types/dashboard';
import { Button, Card, formatNumber } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function VipPage({
  data,
  notify,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  return (
    <div>
      <div className="page-title">
        <div>
          <h1>VIP</h1>
          <p>Premium narystės planai.</p>
        </div>
      </div>
      <Card title="TAVO VIP">
        <div className="value">{data.player.vip}</div>
        <p className="muted" style={{ marginTop: 6 }}>
          {data.player.vipDays} dienų liko
        </p>
      </Card>
      <div style={{ marginTop: 14 }} className="grid grid-3">
        {data.vipPlans.map((plan) => (
          <Card key={plan.id} title={plan.name}>
            <div className="value" style={{ fontSize: 22 }}>
              {formatNumber(plan.price)} CR
            </div>
            <p className="muted" style={{ margin: '8px 0 12px' }}>
              {plan.days} dienų
            </p>
            <ul className="stack" style={{ listStyle: 'none', marginBottom: 14 }}>
              {plan.perks.map((p) => (
                <li key={p} className="muted">
                  · {p}
                </li>
              ))}
            </ul>
            <Button
              onClick={async () => {
                await nuiCallback('buyPremium', { plan: plan.id });
                notify('VIP', `${plan.name} planas (stub).`, '💎');
              }}
            >
              PIRKTI
            </Button>
          </Card>
        ))}
      </div>
    </div>
  );
}

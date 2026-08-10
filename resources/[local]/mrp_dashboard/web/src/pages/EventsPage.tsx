import type { DashboardData } from '@/types/dashboard';
import { Button, Card } from '@/components/ui';
import { nuiCallback } from '@/services/nui';
import { PageHero } from '@/components/PageHero';

export function EventsPage({
  data,
  notify,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  return (
    <div className="page-shell">
      <PageHero
        theme="events"
        title="Renginiai"
        subtitle="Aktyvūs ir artėjantys serverio eventai — prisijunk ir laimėk."
        figureLabel="EVENT"
      />
      <div className="page-body">
        <div className="event-card-grid">
          {data.events.map((e) => (
            <Card key={e.id} title={e.title}>
              <p className="muted">{e.description}</p>
              <div className="home-stat-grid" style={{ margin: '14px 0' }}>
                <div className="home-stat-chip">
                  <span>STARTS IN</span>
                  <strong>{e.startsIn}</strong>
                </div>
                <div className="home-stat-chip">
                  <span>PRIZE</span>
                  <strong>{e.prize}</strong>
                </div>
                <div className="home-stat-chip" style={{ gridColumn: '1 / -1' }}>
                  <span>PLAYERS</span>
                  <strong>{e.participants}</strong>
                </div>
              </div>
              <Button
                onClick={async () => {
                  await nuiCallback('joinEvent', { id: e.id });
                  notify('EVENT', `Prisijungei prie ${e.title} (stub).`, '🏁');
                }}
              >
                JOIN
              </Button>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}

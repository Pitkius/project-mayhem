import type { DashboardData } from '@/types/dashboard';
import { Button, Card } from '@/components/ui';
import { nuiCallback } from '@/services/nui';

export function EventsPage({
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
          <h1>Renginiai</h1>
          <p>Aktyvūs ir artėjantys serverio eventai.</p>
        </div>
      </div>
      <div className="grid grid-2">
        {data.events.map((e) => (
          <Card key={e.id} title={e.title}>
            <p className="muted">{e.description}</p>
            <div className="row" style={{ margin: '12px 0' }}>
              <div>
                <div className="muted">Starts in</div>
                <strong>{e.startsIn}</strong>
              </div>
              <div>
                <div className="muted">Prize</div>
                <strong>{e.prize}</strong>
              </div>
              <div>
                <div className="muted">Players</div>
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
  );
}

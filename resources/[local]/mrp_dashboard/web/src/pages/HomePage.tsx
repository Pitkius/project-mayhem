import type { DashboardData, PageId } from '@/types/dashboard';
import { Card, ProgressBar, Button, formatNumber } from '@/components/ui';

export function HomePage({
  data,
  onNavigate,
}: {
  data: DashboardData;
  onNavigate: (id: PageId) => void;
}) {
  const { player, server, news } = data;
  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Pagrindinis</h1>
          <p>Sveikas, {player.characterName}. Čia tavo Mayhem apžvalga.</p>
        </div>
      </div>
      <div className="grid grid-home">
        <Card title="ŽAIDĖJAS">
          <div className="stack">
            <div className="value" style={{ fontSize: 20 }}>
              {player.characterName}
            </div>
            <div className="muted">Steam: {player.steamName}</div>
            <div className="muted">ID #{player.id}</div>
            <div className="muted">Darbas: {player.job}</div>
            <div className="muted">
              VIP: {player.vip === 'NONE' ? 'Nėra' : `${player.vip} · ${player.vipDays} d.`}
            </div>
            <div className="muted">
              Playtime: {player.playtimeHours}h {player.playtimeMinutes}m
            </div>
            <div className="muted">Nuo: {player.memberSince}</div>
          </div>
        </Card>

        <Card title="VALIUTA">
          <div className="currency-grid">
            <div className="card currency-tile credits" style={{ padding: 12 }}>
              <h3>CREDITS</h3>
              <div className="value">{formatNumber(player.credits)} CR</div>
            </div>
            <div className="card currency-tile cash" style={{ padding: 12 }}>
              <h3>CASH</h3>
              <div className="value">${formatNumber(player.cash)}</div>
            </div>
            <div className="card currency-tile bank" style={{ padding: 12 }}>
              <h3>BANK</h3>
              <div className="value">${formatNumber(player.bank)}</div>
            </div>
          </div>
        </Card>

        <Card title="SERVERIO STATUSAS">
          <div className="stack">
            <div>
              <span className="status-dot" />
              <strong>{server.online ? 'ONLINE' : 'OFFLINE'}</strong>
            </div>
            <div>
              <div className="stat-line">
                <span>Žaidėjai</span>
                <span>
                  {server.players} / {server.maxPlayers}
                </span>
              </div>
              <ProgressBar value={server.players} max={server.maxPlayers} />
            </div>
            <div className="muted">Policija: {server.police}</div>
            <div className="muted">EMS: {server.ems}</div>
            <div className="muted">Uptime: {server.uptime}</div>
          </div>
        </Card>
      </div>

      <div style={{ marginTop: 14 }} className="grid grid-2">
        <Card title="NAUJIENOS">
          <div className="news-list">
            {news.map((n) => (
              <div key={n.id} className="news-item">
                <div>
                  <span className="tag">{n.tag}</span>
                  <strong style={{ display: 'block' }}>{n.title}</strong>
                  <p className="muted">{n.body}</p>
                </div>
                <Button variant="ghost" onClick={() => onNavigate('imports')}>
                  ŽIŪRĖTI
                </Button>
              </div>
            ))}
          </div>
        </Card>
        <Card title="GREITOS NUORODOS">
          <div className="stack">
            <Button variant="ghost" onClick={() => onNavigate('rppass')}>
              RP Pass · LVL {data.rpPass.level}
            </Button>
            <Button variant="ghost" onClick={() => onNavigate('daily')}>
              Dieninis · Day {data.daily.day}/{data.daily.maxDays}
            </Button>
            <Button variant="ghost" onClick={() => onNavigate('imports')}>
              Importai
            </Button>
            <Button variant="ghost" onClick={() => onNavigate('vip')}>
              VIP Shop
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
}

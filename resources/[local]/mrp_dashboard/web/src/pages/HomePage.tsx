import { Banknote, Coins, Landmark } from 'lucide-react';
import type { DashboardData, PageId } from '@/types/dashboard';
import { Card, ProgressBar, Button, formatNumber } from '@/components/ui';
import { PageHero } from '@/components/PageHero';

export function HomePage({
  data,
  onNavigate,
}: {
  data: DashboardData;
  onNavigate: (id: PageId) => void;
}) {
  const { player, server, news } = data;
  const initials = player.characterName
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="page-shell">
      <PageHero
        theme="home"
        title="Pagrindinis"
        subtitle={`Sveikas, ${player.characterName}. Čia tavo Mayhem apžvalga — statusas, valiuta ir greitos nuorodos.`}
        figureLabel="CREW"
        avatarUrl={player.avatarUrl}
        avatarFallback={initials}
        actions={
          <>
            <Button variant="ghost" onClick={() => onNavigate('daily')}>
              Dėžės
            </Button>
            <Button variant="outline" onClick={() => onNavigate('ranking')}>
              Reitingas
            </Button>
          </>
        }
      />

      <div className="page-body">
        <div className="grid grid-home">
          <Card title="ŽAIDĖJAS">
            <div className="value" style={{ fontSize: 22, marginBottom: 12 }}>
              {player.characterName}
            </div>
            <div className="home-stat-grid">
              <div className="home-stat-chip">
                <span>STEAM</span>
                <strong>{player.steamName}</strong>
              </div>
              <div className="home-stat-chip">
                <span>ID</span>
                <strong>#{player.id}</strong>
              </div>
              <div className="home-stat-chip">
                <span>DARBAS</span>
                <strong>{player.job}</strong>
              </div>
              <div className="home-stat-chip">
                <span>VIP</span>
                <strong>
                  {player.vip === 'NONE' ? 'Nėra' : `${player.vip} · ${player.vipDays}d`}
                </strong>
              </div>
              <div className="home-stat-chip">
                <span>PLAYTIME</span>
                <strong>
                  {player.playtimeHours}h {player.playtimeMinutes}m
                </strong>
              </div>
              <div className="home-stat-chip">
                <span>NARYS NUO</span>
                <strong>{player.memberSince}</strong>
              </div>
            </div>
          </Card>

          <Card title="VALIUTA">
            <div className="currency-grid">
              <div className="card currency-tile credits" style={{ padding: 14 }}>
                <div className="currency-tile-head">
                  <span className="currency-icon" aria-hidden>
                    <Coins size={18} strokeWidth={2.25} />
                  </span>
                  <h3>CREDITS</h3>
                </div>
                <div className="value">{formatNumber(player.credits)} CR</div>
              </div>
              <div className="card currency-tile cash" style={{ padding: 14 }}>
                <div className="currency-tile-head">
                  <span className="currency-icon" aria-hidden>
                    <Banknote size={18} strokeWidth={2.25} />
                  </span>
                  <h3>CASH</h3>
                </div>
                <div className="value">${formatNumber(player.cash)}</div>
              </div>
              <div className="card currency-tile bank" style={{ padding: 14 }}>
                <div className="currency-tile-head">
                  <span className="currency-icon" aria-hidden>
                    <Landmark size={18} strokeWidth={2.25} />
                  </span>
                  <h3>BANK</h3>
                </div>
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
              <div className="home-stat-grid">
                <div className="home-stat-chip">
                  <span>POLICIJA</span>
                  <strong>{server.police}</strong>
                </div>
                <div className="home-stat-chip">
                  <span>EMS</span>
                  <strong>{server.ems}</strong>
                </div>
                <div className="home-stat-chip" style={{ gridColumn: '1 / -1' }}>
                  <span>UPTIME</span>
                  <strong>{server.uptime}</strong>
                </div>
              </div>
            </div>
          </Card>
        </div>

        <div className="grid grid-2">
          <Card title="NAUJIENOS">
            <div className="news-list">
              {news.map((n) => (
                <div key={n.id} className="news-item">
                  <div>
                    <span className="tag">{n.tag}</span>
                    <strong style={{ display: 'block' }}>{n.title}</strong>
                    <p className="muted">{n.body}</p>
                  </div>
                  <Button variant="ghost" onClick={() => onNavigate('premium')}>
                    ŽIŪRĖTI
                  </Button>
                </div>
              ))}
            </div>
          </Card>
          <Card title="GREITOS NUORODOS">
            <div className="quick-links">
              <Button variant="ghost" onClick={() => onNavigate('rppass')}>
                RP Pass · LVL {data.rpPass.level}
              </Button>
              <Button variant="ghost" onClick={() => onNavigate('daily')}>
                Dieninis · Day {data.daily.day}/{data.daily.maxDays}
              </Button>
              <Button variant="ghost" onClick={() => onNavigate('premium')}>
                Premium shop
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}

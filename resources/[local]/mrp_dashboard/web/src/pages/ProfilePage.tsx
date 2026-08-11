import type { DashboardData } from '@/types/dashboard';
import { Card } from '@/components/ui';
import { PageHero } from '@/components/PageHero';

export function ProfilePage({ data }: { data: DashboardData }) {
  const p = data.player;
  const initials = p.characterName
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="page-shell">
      <PageHero
        theme="profile"
        title="Profilis"
        subtitle="Charakterio informacija, playtime ir achievements."
        figureLabel={p.characterName}
        avatarUrl={p.avatarUrl}
        avatarFallback={initials}
      />
      <div className="page-body">
        <div className="grid grid-2">
          <Card title="INFORMACIJA">
            <div className="home-stat-grid">
              <div className="home-stat-chip">
                <span>VARDAS</span>
                <strong>{p.characterName}</strong>
              </div>
              <div className="home-stat-chip">
                <span>STEAM</span>
                <strong>{p.steamName}</strong>
              </div>
              <div className="home-stat-chip">
                <span>ID</span>
                <strong>#{p.id}</strong>
              </div>
              <div className="home-stat-chip">
                <span>DARBAS</span>
                <strong>{p.job}</strong>
              </div>
              <div className="home-stat-chip">
                <span>PLAYTIME</span>
                <strong>
                  {p.playtimeHours}h {p.playtimeMinutes}m
                </strong>
              </div>
              <div className="home-stat-chip">
                <span>NARYS NUO</span>
                <strong>{p.memberSince}</strong>
              </div>
              <div className="home-stat-chip">
                <span>RP PASS</span>
                <strong>LVL {data.rpPass.level}</strong>
              </div>
              <div className="home-stat-chip">
                <span>VIP</span>
                <strong>
                  {p.vip} ({p.vipDays} d.)
                </strong>
              </div>
            </div>
          </Card>
          <Card title="ACHIEVEMENTS">
            <div className="grid grid-2">
              {data.achievements.map((a) => (
                <div
                  key={a.id}
                  className="card"
                  style={{ opacity: a.unlocked ? 1 : 0.45, padding: 12 }}
                >
                  <strong>{a.title}</strong>
                  <p className="muted" style={{ marginTop: 6 }}>
                    {a.description}
                  </p>
                  <p className="tag" style={{ marginTop: 8 }}>
                    {a.unlocked ? 'UNLOCKED' : 'LOCKED'}
                  </p>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}

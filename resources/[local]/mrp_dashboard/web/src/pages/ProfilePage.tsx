import type { DashboardData } from '@/types/dashboard';
import { Card } from '@/components/ui';

export function ProfilePage({ data }: { data: DashboardData }) {
  const p = data.player;
  return (
    <div>
      <div className="page-title">
        <div>
          <h1>Profilis</h1>
          <p>Charakterio informacija ir achievements.</p>
        </div>
      </div>
      <div className="grid grid-2">
        <Card title="INFORMACIJA">
          <div className="stack">
            <div className="profile-identity">
              <div className={`avatar profile-avatar${p.avatarUrl ? ' has-photo' : ''}`}>
                {p.avatarUrl ? (
                  <img src={p.avatarUrl} alt="" draggable={false} />
                ) : (
                  p.characterName
                    .split(' ')
                    .map((part) => part[0])
                    .join('')
                    .slice(0, 2)
                    .toUpperCase()
                )}
              </div>
              <div>
                <strong>{p.characterName}</strong>
              </div>
            </div>
            <div className="muted">Steam: {p.steamName}</div>
            <div className="muted">ID: #{p.id}</div>
            <div className="muted">
              Playtime: {p.playtimeHours}h {p.playtimeMinutes}m
            </div>
            <div className="muted">Pirmą kartą: {p.memberSince}</div>
            <div className="muted">RP Pass: LVL {data.rpPass.level}</div>
            <div className="muted">
              VIP: {p.vip} ({p.vipDays} d.)
            </div>
            <div className="muted">Darbas: {p.job}</div>
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
  );
}

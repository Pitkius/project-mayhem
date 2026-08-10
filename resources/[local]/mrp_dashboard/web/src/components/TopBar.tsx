import { X, CircleDollarSign } from 'lucide-react';
import type { PlayerData } from '@/types/dashboard';
import { formatNumber } from '@/components/ui';

export function TopBar({ player, onClose }: { player: PlayerData; onClose: () => void }) {
  const initials = player.characterName
    .split(' ')
    .map((p) => p[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  return (
    <header className="topbar">
      <div className="topbar-player">
        <div className={`avatar${player.avatarUrl ? ' has-photo' : ''}`}>
          {player.avatarUrl ? (
            <img src={player.avatarUrl} alt="" draggable={false} />
          ) : (
            initials
          )}
        </div>
        <div className="topbar-meta">
          <strong>
            {player.characterName}
            {player.vip !== 'NONE' ? <span className="vip-badge">{player.vip}</span> : null}
          </strong>
          <span>
            ID #{player.id} · {player.job}
          </span>
        </div>
      </div>
      <div className="topbar-actions">
        <div className="credits-pill">
          <span className="credits-pill-icon" aria-hidden>
            <CircleDollarSign size={18} strokeWidth={2.35} />
          </span>
          {formatNumber(player.credits)} CR
        </div>
        <button type="button" className="icon-btn" onClick={onClose} title="Uždaryti">
          <X size={18} />
        </button>
      </div>
    </header>
  );
}

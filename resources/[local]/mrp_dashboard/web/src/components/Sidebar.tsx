import type { NavId, PageId } from '@/types/dashboard';
import {
  Home,
  Map,
  Ticket,
  Target,
  CalendarDays,
  Sparkles,
  Gift,
  PartyPopper,
  Trophy,
  User,
  Settings,
} from 'lucide-react';
import mayhemMark from '@/assets/brand/mayhem_mark.png';

const ITEMS: { id: NavId; label: string; icon: typeof Home }[] = [
  { id: 'home', label: 'PAGRINDINIS', icon: Home },
  { id: 'map', label: 'ŽEMĖLAPIS', icon: Map },
  { id: 'rppass', label: 'RP PASS', icon: Ticket },
  { id: 'missions', label: 'MISIJOS', icon: Target },
  { id: 'daily', label: 'DIENINIS', icon: CalendarDays },
  { id: 'premium', label: 'PREMIUM', icon: Sparkles },
  { id: 'rewards', label: 'APDOVANOJIMAI', icon: Gift },
  { id: 'events', label: 'RENGINIAI', icon: PartyPopper },
  { id: 'ranking', label: 'REITINGAS', icon: Trophy },
  { id: 'profile', label: 'PROFILIS', icon: User },
  { id: 'settings', label: 'NUSTATYMAI', icon: Settings },
];

export function Sidebar({
  active,
  onNavigate,
}: {
  active: PageId;
  onNavigate: (id: NavId) => void;
}) {
  const premiumActive = active === 'premium' || active === 'imports' || active === 'vip';

  return (
    <aside className="sidebar">
      <div className="brand">
        <div className="brand-mark">
          <img src={mayhemMark} alt="Mayhem" width={40} height={40} />
        </div>
        <div className="brand-text">
          <strong>MAYHEM</strong>
          <span>Roleplay Dashboard</span>
        </div>
      </div>
      <nav className="nav-list">
        {ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = item.id === 'premium' ? premiumActive : active === item.id;
          return (
            <button
              key={item.id}
              type="button"
              className={`nav-item${isActive ? ' active' : ''}`}
              onClick={() => onNavigate(item.id)}
            >
              <Icon />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="sidebar-foot">discord.gg/mayhem · v1.0</div>
    </aside>
  );
}

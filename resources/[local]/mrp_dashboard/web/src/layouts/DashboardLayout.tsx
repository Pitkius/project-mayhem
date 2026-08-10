import type { DashboardData, NavId, PageId } from '@/types/dashboard';
import { Sidebar } from '@/components/Sidebar';
import { TopBar } from '@/components/TopBar';
import { HomePage } from '@/pages/HomePage';
import { RpPassPage } from '@/pages/RpPassPage';
import { MissionsPage } from '@/pages/MissionsPage';
import { DailyPage } from '@/pages/DailyPage';
import { PremiumShopPage } from '@/pages/PremiumShopPage';
import { RewardsPage } from '@/pages/RewardsPage';
import { EventsPage } from '@/pages/EventsPage';
import { RankingPage } from '@/pages/RankingPage';
import { ProfilePage } from '@/pages/ProfilePage';
import type { CrateSpinPayload } from '@/components/LootSpinOverlay';

export function DashboardLayout({
  page,
  data,
  onNavigate,
  onClose,
  onPatch,
  notify,
  onDevSpin,
}: {
  page: PageId;
  data: DashboardData;
  onNavigate: (id: NavId) => void;
  onClose: () => void;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
  onDevSpin?: (payload: CrateSpinPayload) => void;
}) {
  const showPremium = page === 'premium' || page === 'imports' || page === 'vip';

  return (
    <div className="dashboard-shell">
      <div className="shell-atmosphere" aria-hidden />
      <Sidebar active={page} onNavigate={onNavigate} />
      <TopBar player={data.player} onClose={onClose} />
      <main className="content" key={page}>
        {page === 'home' && <HomePage data={data} onNavigate={onNavigate} />}
        {page === 'rppass' && <RpPassPage data={data} onPatch={onPatch} notify={notify} />}
        {page === 'missions' && <MissionsPage data={data} onPatch={onPatch} notify={notify} />}
        {page === 'daily' && (
          <DailyPage data={data} onPatch={onPatch} notify={notify} onDevSpin={onDevSpin} />
        )}
        {showPremium && (
          <PremiumShopPage
            key={`premium-${page}`}
            data={data}
            notify={notify}
            onDevSpin={onDevSpin}
            initialTab={page === 'vip' ? 'vip' : 'imports'}
          />
        )}
        {page === 'rewards' && <RewardsPage data={data} onPatch={onPatch} notify={notify} />}
        {page === 'events' && <EventsPage data={data} notify={notify} />}
        {page === 'ranking' && <RankingPage data={data} />}
        {page === 'profile' && <ProfilePage data={data} />}
      </main>
    </div>
  );
}

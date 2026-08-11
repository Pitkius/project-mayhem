import { useCallback, useEffect, useState } from 'react';
import { DashboardLayout } from '@/layouts/DashboardLayout';
import { NotificationStack } from '@/components/NotificationStack';
import { LootSpinOverlay, type CrateSpinPayload } from '@/components/LootSpinOverlay';
import { mockDashboard } from '@/mock/data';
import { closeDashboard, isDevPreview, nuiCallback, onNuiMessage } from '@/services/nui';
import type { DashboardData, NavId, NotificationItem, PageId } from '@/types/dashboard';
import '@/styles/global.css';

export default function App() {
  const [open, setOpen] = useState(isDevPreview());
  const [page, setPage] = useState<PageId>('home');
  const [data, setData] = useState<DashboardData>(mockDashboard);
  const [toasts, setToasts] = useState<NotificationItem[]>([]);
  const [crateSpin, setCrateSpin] = useState<CrateSpinPayload | null>(null);

  const notify = useCallback((title: string, description: string, icon = 'ℹ️') => {
    if (!data.settings.notifications && title !== 'NUSTATYMAI') return;
    const id = `${Date.now()}-${Math.random()}`;
    setToasts((prev) =>
      [
        {
          id,
          icon,
          title,
          description,
          timestamp: new Date().toLocaleTimeString('lt-LT'),
        },
        ...prev,
      ].slice(0, 4),
    );
    window.setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4500);
  }, [data.settings.notifications]);

  const handleClose = useCallback(async () => {
    if (crateSpin) return;
    setOpen(false);
    setPage('home');
    await closeDashboard();
  }, [crateSpin]);

  const handleNavigate = useCallback(
    async (id: NavId) => {
      // ESC sidebar Map → native GTA pause map (not custom MapPage NUI)
      if (id === 'map') {
        if (isDevPreview()) {
          notify('ŽEMĖLAPIS', 'Žaidime atsidarys native GTA map.', '🗺️');
          return;
        }
        await nuiCallback('openNativeMap');
        return;
      }
      setPage(id);
    },
    [notify],
  );

  useEffect(() => {
    void nuiCallback('ready');
    return onNuiMessage((msg) => {
      if (msg.action === 'open') {
        setOpen(true);
        setPage('home');
      }
      if (msg.action === 'close') {
        setOpen(false);
      }
      if (msg.action === 'openCrateSpin' && msg.payload) {
        setCrateSpin(msg.payload as CrateSpinPayload);
      }
      if (msg.action === 'setData' && msg.payload) {
        const incoming = msg.payload as Partial<DashboardData>;
        setData((prev) => ({
          ...prev,
          ...incoming,
          player: incoming.player
            ? { ...prev.player, ...incoming.player }
            : prev.player,
          daily: incoming.daily
            ? {
                ...prev.daily,
                ...incoming.daily,
                weekly: incoming.daily.weekly
                  ? { ...prev.daily.weekly, ...incoming.daily.weekly } as typeof prev.daily.weekly
                  : prev.daily.weekly,
                requirements: incoming.daily.requirements ?? prev.daily.requirements,
              }
            : prev.daily,
          missions: incoming.missions ?? prev.missions,
          rankings: incoming.rankings
            ? { ...prev.rankings, ...incoming.rankings }
            : prev.rankings,
          server: incoming.server
            ? { ...prev.server, ...incoming.server }
            : prev.server,
          settings: incoming.settings
            ? { ...prev.settings, ...incoming.settings }
            : prev.settings,
        }));
      }
      if (msg.action === 'notify' && msg.payload) {
        notify(msg.payload.title, msg.payload.description, msg.payload.icon);
      }
    });
  }, [notify]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open && !crateSpin) {
        e.preventDefault();
        void handleClose();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, handleClose, crateSpin]);

  return (
    <div
      className={`app-root${open || crateSpin || isDevPreview() ? ' is-open' : ''}${
        isDevPreview() ? ' dev-preview' : ''
      }`}
    >
      {open ? (
        <DashboardLayout
          page={page}
          data={data}
          onNavigate={(id) => void handleNavigate(id)}
          onClose={() => void handleClose()}
          onPatch={(patch) => setData((prev) => ({ ...prev, ...patch }))}
          notify={notify}
          onDevSpin={setCrateSpin}
        />
      ) : null}
      {crateSpin ? (
        <LootSpinOverlay payload={crateSpin} onDone={() => setCrateSpin(null)} />
      ) : null}
      <NotificationStack
        items={toasts}
        onDismiss={(id) => setToasts((prev) => prev.filter((t) => t.id !== id))}
      />
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import { DashboardLayout } from '@/layouts/DashboardLayout';
import { NotificationStack } from '@/components/NotificationStack';
import { mockDashboard } from '@/mock/data';
import { closeDashboard, isDevPreview, nuiCallback, onNuiMessage } from '@/services/nui';
import type { DashboardData, NavId, NotificationItem, PageId } from '@/types/dashboard';
import '@/styles/global.css';

export default function App() {
  const [open, setOpen] = useState(isDevPreview());
  const [page, setPage] = useState<PageId>('home');
  const [data, setData] = useState<DashboardData>(mockDashboard);
  const [toasts, setToasts] = useState<NotificationItem[]>([]);

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
    setOpen(false);
    setPage('home');
    await closeDashboard();
  }, []);

  const handleNavigate = useCallback(
    async (id: NavId) => {
      if (id === 'map') {
        if (isDevPreview()) {
          notify('ŽEMĖLAPIS', 'Žaidime atsidarys native GTA map.', '🗺️');
          return;
        }
        await nuiCallback('openNativeMap');
        setOpen(false);
        return;
      }
      if (id === 'settings') {
        if (isDevPreview()) {
          notify('NUSTATYMAI', 'Žaidime atsidarys native GTA settings.', '⚙️');
          return;
        }
        await nuiCallback('openNativeSettings');
        setOpen(false);
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
      if (msg.action === 'setData' && msg.payload) {
        setData((prev) => ({ ...prev, ...(msg.payload as Partial<DashboardData>) }));
      }
      if (msg.action === 'notify' && msg.payload) {
        notify(msg.payload.title, msg.payload.description, msg.payload.icon);
      }
    });
  }, [notify]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) {
        e.preventDefault();
        void handleClose();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, handleClose]);

  if (!open) {
    return (
      <div className={`app-root${isDevPreview() ? ' dev-preview' : ''}`}>
        <NotificationStack
          items={toasts}
          onDismiss={(id) => setToasts((prev) => prev.filter((t) => t.id !== id))}
        />
      </div>
    );
  }

  return (
    <div className={`app-root${isDevPreview() ? ' dev-preview' : ''}`}>
      <DashboardLayout
        page={page}
        data={data}
        onNavigate={(id) => void handleNavigate(id)}
        onClose={() => void handleClose()}
        onPatch={(patch) => setData((prev) => ({ ...prev, ...patch }))}
        notify={notify}
      />
      <NotificationStack
        items={toasts}
        onDismiss={(id) => setToasts((prev) => prev.filter((t) => t.id !== id))}
      />
    </div>
  );
}

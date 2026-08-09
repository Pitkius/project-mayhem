import type { NotificationItem } from '@/types/dashboard';
import { X } from 'lucide-react';

export function NotificationStack({
  items,
  onDismiss,
}: {
  items: NotificationItem[];
  onDismiss: (id: string) => void;
}) {
  if (!items.length) return null;
  return (
    <div className="toasts">
      {items.map((n) => (
        <div key={n.id} className="toast">
          <div className="toast-head">
            <strong>
              {n.icon} {n.title}
            </strong>
            <button type="button" className="icon-btn" onClick={() => onDismiss(n.id)}>
              <X size={14} />
            </button>
          </div>
          <p>{n.description}</p>
          <p style={{ marginTop: 4, fontSize: 11 }}>{n.timestamp}</p>
        </div>
      ))}
    </div>
  );
}

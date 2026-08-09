export function getResourceName(): string {
  const w = window as unknown as { GetParentResourceName?: () => string };
  if (typeof w.GetParentResourceName === 'function') {
    return w.GetParentResourceName();
  }
  return 'mrp_dashboard';
}

/** Browser Vite preview / non-FiveM CEF */
export function isDevPreview(): boolean {
  if (import.meta.env.DEV) return true;
  if (new URLSearchParams(window.location.search).has('dev')) return true;
  return typeof (window as unknown as { invokeNative?: unknown }).invokeNative === 'undefined';
}

export async function nuiCallback<T = unknown>(
  event: string,
  data: Record<string, unknown> = {},
): Promise<T | null> {
  if (isDevPreview()) {
    console.info('[mrp_dashboard] stub callback', event, data);
    return { ok: true, stub: true } as T;
  }
  try {
    const res = await fetch(`https://${getResourceName()}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return (await res.json()) as T;
  } catch (err) {
    console.error('[mrp_dashboard] NUI callback failed', event, err);
    return null;
  }
}

export function closeDashboard() {
  return nuiCallback('close');
}

export type NuiMessage =
  | { action: 'open'; payload?: unknown }
  | { action: 'close' }
  | { action: 'setData'; payload: unknown }
  | { action: 'notify'; payload: { icon?: string; title: string; description: string } };

export function onNuiMessage(handler: (msg: NuiMessage) => void): () => void {
  const listener = (event: MessageEvent) => {
    const data = event.data as NuiMessage | undefined;
    if (!data || typeof data !== 'object' || !('action' in data)) return;
    handler(data);
  };
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

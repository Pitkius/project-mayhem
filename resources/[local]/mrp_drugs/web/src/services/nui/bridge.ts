import {
  PARENT_SOURCE,
  WEB_SOURCE,
  type ParentMessage,
  type QualityTier,
  type WebMessage,
} from '@/types/protocol';

type Handler = (msg: ParentMessage) => void;

const handlers = new Set<Handler>();

function onWindowMessage(ev: MessageEvent) {
  const msg = ev.data as ParentMessage | undefined;
  if (!msg || (msg as { source?: string }).source !== PARENT_SOURCE) return;
  handlers.forEach((h) => {
    try {
      h(msg);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[mrp_drugs_web] handler error', err);
    }
  });
}

let installed = false;

/** Subscribe to parent messages. Returns an unsubscribe function. */
export function onParentMessage(handler: Handler): () => void {
  if (!installed) {
    window.addEventListener('message', onWindowMessage);
    installed = true;
  }
  handlers.add(handler);
  return () => handlers.delete(handler);
}

function postToParent(msg: WebMessage) {
  // Post to the hosting NUI frame. Fall back to window for dev preview.
  const target = window.parent && window.parent !== window ? window.parent : window;
  target.postMessage(msg, '*');
}

export function sendResult(payload: {
  success: boolean;
  score: number;
  quality: QualityTier;
  mistakes: number;
}) {
  postToParent({ source: WEB_SOURCE, action: 'result', data: payload });
}

export function sendCancel() {
  postToParent({ source: WEB_SOURCE, action: 'cancel' });
}

export function sendReady() {
  postToParent({ source: WEB_SOURCE, action: 'ready' });
}

// Centralized input helpers with guaranteed cleanup. Stations subscribe and get
// back a disposer; App calls all disposers on teardown so no listeners leak
// between sessions (a common NUI focus / double-fire bug source).

export type Disposer = () => void;

/** Tracks a "hold" gesture from SPACE key or primary pointer button. */
export function createHold(onChange?: (held: boolean) => void) {
  let held = false;
  const set = (v: boolean) => {
    if (v === held) return;
    held = v;
    onChange?.(held);
  };
  const kd = (e: KeyboardEvent) => {
    if (e.code === 'Space') {
      e.preventDefault();
      set(true);
    }
  };
  const ku = (e: KeyboardEvent) => {
    if (e.code === 'Space') set(false);
  };
  const pd = () => set(true);
  const pu = () => set(false);
  window.addEventListener('keydown', kd);
  window.addEventListener('keyup', ku);
  window.addEventListener('pointerdown', pd);
  window.addEventListener('pointerup', pu);
  window.addEventListener('blur', pu);
  const dispose: Disposer = () => {
    window.removeEventListener('keydown', kd);
    window.removeEventListener('keyup', ku);
    window.removeEventListener('pointerdown', pd);
    window.removeEventListener('pointerup', pu);
    window.removeEventListener('blur', pu);
  };
  return {
    isHeld: () => held,
    dispose,
  };
}

/** Escape key handler (used for cancel confirmation flow). */
export function onEscape(cb: () => void): Disposer {
  const kd = (e: KeyboardEvent) => {
    if (e.code === 'Escape') {
      e.preventDefault();
      cb();
    }
  };
  window.addEventListener('keydown', kd);
  return () => window.removeEventListener('keydown', kd);
}

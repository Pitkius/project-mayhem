import { useEffect, useRef, useState } from 'react';
import type { ItemRarity } from '@/types/dashboard';
import { RARITY_LABEL } from '@/types/dashboard';
import { nuiCallback } from '@/services/nui';

export type CrateSpinEntry = {
  kind: 'item' | 'xp';
  item?: string;
  amount: number;
  rarity: ItemRarity;
  label: string;
  icon: string;
  iconUrl?: string | null;
};

export type CrateSpinPayload = {
  token: string;
  crateId: string;
  crateLabel: string;
  crateIcon: string;
  crateIconUrl?: string | null;
  accent?: string;
  reel: CrateSpinEntry[];
  winnerIndex: number;
  winner: CrateSpinEntry;
};

const CELL_W = 120;
const CELL_GAP = 10;
const STEP = CELL_W + CELL_GAP;

function Cell({ entry, highlight }: { entry: CrateSpinEntry; highlight?: boolean }) {
  return (
    <div className={`loot-cell rarity-${entry.rarity}${highlight ? ' win' : ''}`}>
      <div className="loot-icon-wrap">
        {entry.iconUrl ? (
          <img className="loot-img" src={entry.iconUrl} alt="" draggable={false} />
        ) : (
          <span className="loot-icon">{entry.icon}</span>
        )}
      </div>
      <span className="loot-name">{entry.label}</span>
      <span className="loot-qty">×{entry.amount}</span>
      <span className={`rarity-pill rarity-${entry.rarity}`}>{RARITY_LABEL[entry.rarity]}</span>
    </div>
  );
}

export function LootSpinOverlay({
  payload,
  onDone,
}: {
  payload: CrateSpinPayload;
  onDone: () => void;
}) {
  const [phase, setPhase] = useState<'spin' | 'result'>('spin');
  const [spinning, setSpinning] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const reelRef = useRef<HTMLDivElement>(null);
  const finished = useRef(false);

  useEffect(() => {
    const wrap = wrapRef.current;
    const reel = reelRef.current;
    if (!wrap || !reel) return;

    const wrapW = wrap.clientWidth;
    const target = -(payload.winnerIndex * STEP + CELL_W / 2 - wrapW / 2);
    reel.style.setProperty('--reel-offset', `${target}px`);

    const start = window.setTimeout(() => setSpinning(true), 60);
    const doneTimer = window.setTimeout(() => setPhase('result'), 3600);
    return () => {
      window.clearTimeout(start);
      window.clearTimeout(doneTimer);
    };
  }, [payload.winnerIndex]);

  const finish = async () => {
    if (finished.current) return;
    finished.current = true;
    await nuiCallback('crateSpinDone', { token: payload.token });
    onDone();
  };

  useEffect(() => {
    if (phase !== 'result') return;
    const auto = window.setTimeout(() => {
      void finish();
    }, 2500);
    return () => window.clearTimeout(auto);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  return (
    <div
      className="crate-spin-overlay"
      style={{ ['--crate-accent' as string]: payload.accent || '#a78bfa' }}
    >
      <div className="crate-spin-panel">
        <div className="crate-spin-head">
          {payload.crateIconUrl ? (
            <img src={payload.crateIconUrl} alt="" className="crate-spin-crateimg" draggable={false} />
          ) : (
            <span className="crate-spin-emoji">{payload.crateIcon}</span>
          )}
          <div>
            <strong>{payload.crateLabel}</strong>
            <p className="muted">Sukasi kaip CSGO case…</p>
          </div>
        </div>

        {phase === 'spin' ? (
          <div className="loot-reel-wrap crate-spin-reel" ref={wrapRef}>
            <div className="loot-reel-pointer" />
            <div ref={reelRef} className={`loot-reel${spinning ? ' spinning' : ''}`}>
              {payload.reel.map((entry, i) => (
                <Cell key={`${entry.label}-${i}`} entry={entry} />
              ))}
            </div>
          </div>
        ) : (
          <div className="loot-result">
            <Cell entry={payload.winner} highlight />
            <div className="value" style={{ fontSize: 18 }}>
              {payload.winner.icon} {payload.winner.label} ×{payload.winner.amount}
            </div>
            <button type="button" className="btn btn-primary" onClick={() => void finish()}>
              ATSIIMTI
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

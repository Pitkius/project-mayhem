import { QUALITY_COLOR, QUALITY_LABEL } from '@/config/quality';
import { useMachine } from '@/stores/machine';

// Minimal HUD. Per the brief, textual UI takes a small part of the screen and
// never covers the Pixi workstation scene.
export function Hud() {
  const ui = useMachine((s) => s.ui);
  const stage = useMachine((s) => s.stage);
  const score = useMachine((s) => s.score);
  const payload = useMachine((s) => s.payload);

  if (ui !== 'PLAYING' && ui !== 'INTRO' && ui !== 'READY') return null;

  return (
    <div className="hud">
      <div className="hud-top">
        <div className="hud-title">
          <span className="hud-tier">{payload?.level ? `${payload.level} lygis` : 'Gamyba'}</span>
          <h2>{stage.title || payload?.label || 'THC'}</h2>
        </div>
        <div className="hud-step">
          {stage.index}/{stage.total}
        </div>
      </div>
      <div className="hud-bar">
        <div
          className="hud-bar-fill"
          style={{ width: `${stage.total ? (stage.index / stage.total) * 100 : 0}%` }}
        />
      </div>
      {stage.hint ? <p className="hud-hint">{stage.hint}</p> : null}
      {score > 0 ? (
        <div className="hud-quality">
          Kokybė:{' '}
          <b style={{ color: colorHex(score) }}>{QUALITY_LABEL[qtier(score)]}</b>
        </div>
      ) : null}
      <p className="hud-footer">
        <kbd>SPACE</kbd> / pelė · <kbd>ESC</kbd> atšaukti
      </p>
    </div>
  );
}

function qtier(score: number) {
  if (score >= 85) return 'excellent' as const;
  if (score >= 65) return 'good' as const;
  if (score >= 40) return 'medium' as const;
  return 'poor' as const;
}
function colorHex(score: number) {
  return `#${QUALITY_COLOR[qtier(score)].toString(16).padStart(6, '0')}`;
}

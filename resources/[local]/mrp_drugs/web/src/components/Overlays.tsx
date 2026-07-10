import { QUALITY_COLOR, QUALITY_LABEL } from '@/config/quality';
import { useMachine } from '@/stores/machine';

interface Props {
  onCancelConfirm: () => void;
  onCancelDismiss: () => void;
  onDone: () => void;
}

// Full-state overlays: LOADING, SUCCESS/FAILED result, cancel confirmation,
// and ERROR. These are simple UI cards (allowed CSS usage).
export function Overlays({ onCancelConfirm, onCancelDismiss, onDone }: Props) {
  const ui = useMachine((s) => s.ui);
  const quality = useMachine((s) => s.quality);
  const score = useMachine((s) => s.score);
  const errorMessage = useMachine((s) => s.errorMessage);
  const cancelable = useMachine((s) => s.payload?.cancelable ?? true);

  if (ui === 'LOADING') {
    return (
      <div className="overlay">
        <div className="card">
          <div className="spinner" />
          <p>Ruošiama darbo stotis…</p>
        </div>
      </div>
    );
  }

  if (ui === 'CANCEL_CONFIRMATION') {
    return (
      <div className="overlay">
        <div className="card">
          {cancelable ? (
            <>
              <h3>Nutraukti procesą?</h3>
              <p className="muted">Dalis medžiagų gali būti prarasta.</p>
              <div className="row">
                <button className="btn danger" onClick={onCancelConfirm}>
                  Taip, nutraukti
                </button>
                <button className="btn" onClick={onCancelDismiss}>
                  Tęsti
                </button>
              </div>
            </>
          ) : (
            <>
              <h3>Negalima nutraukti</h3>
              <p className="muted">Šio proceso atšaukti negalima — užbaik etapą.</p>
              <div className="row">
                <button className="btn" onClick={onCancelDismiss}>
                  Grįžti
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    );
  }

  if (ui === 'SUCCESS' || ui === 'PARTIAL_SUCCESS') {
    const color = quality ? `#${QUALITY_COLOR[quality].toString(16).padStart(6, '0')}` : '#84cc16';
    return (
      <div className="overlay">
        <div className="card success">
          <h3>Pagaminta</h3>
          <div className="quality-badge" style={{ borderColor: color, color }}>
            {quality ? QUALITY_LABEL[quality] : '—'}
          </div>
          <p className="muted">Rezultatas: {score}/100</p>
        </div>
      </div>
    );
  }

  if (ui === 'FAILED') {
    return (
      <div className="overlay">
        <div className="card fail">
          <h3>Nepavyko</h3>
          <p className="muted">Procesas nutrūko — patikrink rezultatą inventoriuje.</p>
        </div>
      </div>
    );
  }

  if (ui === 'ERROR') {
    return (
      <div className="overlay">
        <div className="card fail">
          <h3>Klaida</h3>
          <p className="muted">{errorMessage || 'Įvyko klaida.'}</p>
          <div className="row">
            <button className="btn" onClick={onDone}>
              Uždaryti
            </button>
          </div>
        </div>
      </div>
    );
  }

  return null;
}

import { useCallback, useEffect, useRef } from 'react';
import { PixiStage } from '@/engine/pixi/stage';
import { onEscape } from '@/engine/input/input';
import { Audio } from '@/engine/audio/audio';
import { onParentMessage, sendReady, sendResult } from '@/services/nui/bridge';
import { getStation } from '@/minigames/registry';
import type { StationController } from '@/minigames/types';
import type { StationPayload } from '@/types/protocol';
import { useMachine } from '@/stores/machine';
import { qualityFromScore } from '@/config/quality';
import { themeFor } from '@/config/drugThemes';
import { Hud } from '@/components/Hud';
import { Overlays } from '@/components/Overlays';

export function App() {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const stageRef = useRef<PixiStage | null>(null);
  const stationRef = useRef<StationController | null>(null);
  const closeTimer = useRef<number | null>(null);

  const teardown = useCallback(() => {
    if (closeTimer.current) {
      window.clearTimeout(closeTimer.current);
      closeTimer.current = null;
    }
    stationRef.current?.destroy();
    stationRef.current = null;
    stageRef.current?.destroy();
    stageRef.current = null;
    Audio.stopAll();
    useMachine.getState().reset();
  }, []);

  const finishAndClose = useCallback(() => {
    teardown();
  }, [teardown]);

  // Start a station session for the given payload.
  const startSession = useCallback(
    async (payload: StationPayload) => {
      // Clean any previous session first (never allow two at once).
      stationRef.current?.destroy();
      stationRef.current = null;
      stageRef.current?.destroy();
      stageRef.current = null;

      const factory = getStation(payload.drug);
      if (!factory) {
        useMachine.getState().setError(`Nepalaikoma stotis: ${payload.drug}`);
        return;
      }

      useMachine.getState().startSession(payload); // -> LOADING

      const drugTheme = themeFor(payload.drug);
      document.documentElement.style.setProperty(
        '--drug-accent',
        `#${drugTheme.accent.toString(16).padStart(6, '0')}`,
      );

      const host = hostRef.current;
      if (!host) {
        useMachine.getState().setError('Nėra scenos konteinerio.');
        return;
      }

      const stage = new PixiStage();
      stageRef.current = stage;
      try {
        await stage.init(host);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('[App] pixi init failed', err);
        useMachine.getState().setError('Nepavyko paleisti scenos.');
        return;
      }
      // Session may have been closed while awaiting init.
      if (stageRef.current !== stage) {
        stage.destroy();
        return;
      }

      sendReady();
      useMachine.getState().setUi('PLAYING');

      stationRef.current = factory(stage, payload, {
        onStage: (info) => {
          const st = useMachine.getState();
          if (st.ui === 'PLAYING') st.setStage(info);
        },
        onScore: (score) => useMachine.getState().setScore(score),
        onFinish: (result) => {
          const quality = result.success ? qualityFromScore(result.score) : 'poor';
          useMachine.getState().setOutcome({ score: result.score, quality, mistakes: result.mistakes });
          useMachine.getState().setUi(result.success ? 'SUCCESS' : 'FAILED');
          // Report to parent (relayed to Lua scheduleResult / finishCraft).
          sendResult({
            success: result.success,
            score: result.score,
            quality,
            mistakes: result.mistakes,
          });
          // Auto-close after showing the outcome briefly.
          closeTimer.current = window.setTimeout(finishAndClose, result.success ? 1600 : 1400);
        },
      });
    },
    [finishAndClose],
  );

  // Parent message subscription.
  useEffect(() => {
    const off = onParentMessage((msg) => {
      if (msg.action === 'startStation') {
        void startSession(msg.data);
      } else if (msg.action === 'close') {
        teardown();
      }
    });
    // Tell the parent bridge the listener is installed so any payload posted
    // before mount (race on iframe load) gets re-delivered.
    sendReady();
    return off;
  }, [startSession, teardown]);

  // ESC -> cancel confirmation (pause), or dismiss it.
  useEffect(() => {
    const off = onEscape(() => {
      const st = useMachine.getState();
      if (st.ui === 'PLAYING') {
        st.setUi('CANCEL_CONFIRMATION');
      } else if (st.ui === 'CANCEL_CONFIRMATION') {
        st.setUi('PLAYING');
      }
    });
    return off;
  }, []);

  // Safety: tear down on unload (resource restart).
  useEffect(() => () => teardown(), [teardown]);

  const ui = useMachine((s) => s.ui);
  const visible = ui !== 'CLOSED';

  return (
    <div className={`stage-root${visible ? ' visible' : ''}`}>
      <div ref={hostRef} className="pixi-host" />
      <Hud />
      <Overlays
        onCancelConfirm={() => {
          stationRef.current?.cancel();
        }}
        onCancelDismiss={() => useMachine.getState().setUi('PLAYING')}
        onDone={finishAndClose}
      />
    </div>
  );
}

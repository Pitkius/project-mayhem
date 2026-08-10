import type { DashboardData, SettingsState } from '@/types/dashboard';
import { Button, Card } from '@/components/ui';
import { PageHero } from '@/components/PageHero';
import { nuiCallback } from '@/services/nui';

function ToggleRow({
  label,
  description,
  on,
  onToggle,
}: {
  label: string;
  description: string;
  on: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="row settings-row">
      <div>
        <strong>{label}</strong>
        <p className="muted">{description}</p>
      </div>
      <button
        type="button"
        className={`toggle${on ? ' on' : ''}`}
        aria-pressed={on}
        onClick={onToggle}
      />
    </div>
  );
}

export function SettingsPage({
  data,
  onPatch,
  notify,
}: {
  data: DashboardData;
  onPatch: (patch: Partial<DashboardData>) => void;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const s = data.settings;

  const patchSettings = async (partial: Partial<SettingsState>, toast?: string) => {
    const next = { ...s, ...partial };
    onPatch({ settings: next });
    await nuiCallback('updateSettings', { ...partial });
    if (toast) notify('NUSTATYMAI', toast, '⚙️');
  };

  return (
    <div className="page-shell">
      <PageHero
        theme="profile"
        title="Nustatymai"
        subtitle="HUD, pranešimai, garsas ir kalba — lokalūs stub’ai (NUI callback)."
        figureLabel="CFG"
        actions={
          <Button
            variant="outline"
            onClick={async () => {
              await nuiCallback('openNativeSettings');
              notify('GTA', 'Atidaromas native GTA settings meniu.', '⚙️');
            }}
          >
            GTA SETTINGS
          </Button>
        }
      />

      <div className="page-body">
        <div className="grid grid-2">
          <Card title="HUD">
            <div className="stack">
              <ToggleRow
                label="HUD įjungtas"
                description="Rodyti gameplay HUD (mrp_hud)."
                on={s.hudEnabled}
                onToggle={() =>
                  void patchSettings(
                    { hudEnabled: !s.hudEnabled },
                    s.hudEnabled ? 'HUD išjungtas (stub).' : 'HUD įjungtas (stub).',
                  )
                }
              />
              <div className="field">
                <label htmlFor="hud-opacity">HUD opacity · {s.hudOpacity}%</label>
                <input
                  id="hud-opacity"
                  type="range"
                  min={20}
                  max={100}
                  value={s.hudOpacity}
                  onChange={(e) =>
                    void patchSettings({ hudOpacity: Number(e.target.value) })
                  }
                />
              </div>
              <div className="field">
                <label htmlFor="hud-scale">HUD scale · {s.hudScale}%</label>
                <input
                  id="hud-scale"
                  type="range"
                  min={70}
                  max={130}
                  value={s.hudScale}
                  onChange={(e) =>
                    void patchSettings({ hudScale: Number(e.target.value) })
                  }
                />
              </div>
            </div>
          </Card>

          <Card title="BENDRA">
            <div className="stack">
              <ToggleRow
                label="Pranešimai"
                description="Dashboard toast pranešimai."
                on={s.notifications}
                onToggle={() =>
                  void patchSettings(
                    { notifications: !s.notifications },
                    s.notifications ? 'Pranešimai išjungti.' : 'Pranešimai įjungti.',
                  )
                }
              />
              <ToggleRow
                label="Garsas"
                description="UI / crate spin garsai."
                on={s.sound}
                onToggle={() =>
                  void patchSettings(
                    { sound: !s.sound },
                    s.sound ? 'Garsas išjungtas (stub).' : 'Garsas įjungtas (stub).',
                  )
                }
              />
              <ToggleRow
                label="FPS skaitiklis"
                description="Rodyti FPS overlay."
                on={s.fpsCounter}
                onToggle={() => void patchSettings({ fpsCounter: !s.fpsCounter })}
              />
              <ToggleRow
                label="Cinematic mode"
                description="Slėpti dalį HUD cinematic filmavimui."
                on={s.cinematic}
                onToggle={() => void patchSettings({ cinematic: !s.cinematic })}
              />
            </div>
          </Card>

          <Card title="KALBA">
            <div className="chips" style={{ marginBottom: 0 }}>
              {(
                [
                  ['lt', 'LIETUVIŲ'],
                  ['en', 'ENGLISH'],
                ] as const
              ).map(([id, label]) => (
                <button
                  key={id}
                  type="button"
                  className={`chip${s.language === id ? ' active' : ''}`}
                  onClick={() =>
                    void patchSettings(
                      { language: id },
                      id === 'lt' ? 'Kalba: lietuvių (stub).' : 'Language: English (stub).',
                    )
                  }
                >
                  {label}
                </button>
              ))}
            </div>
            <p className="muted" style={{ marginTop: 12 }}>
              UI tekstai šiuo metu LT; EN perjungimas — stub vėlesnei lokalizacijai.
            </p>
          </Card>

          <Card title="KEYBINDS">
            <div className="stack">
              <div className="stat-line">
                <span>Dashboard</span>
                <strong>ESC / F10</strong>
              </div>
              <div className="stat-line">
                <span>Žemėlapis (native)</span>
                <strong>per sidebar</strong>
              </div>
              <p className="muted">
                Keybind redagavimas vėliau per FiveM key mapping — dabar tik informacija.
              </p>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}

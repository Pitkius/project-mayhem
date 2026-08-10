import { useState } from 'react';
import type { DashboardData } from '@/types/dashboard';
import { Button, Card } from '@/components/ui';
import { PageHero } from '@/components/PageHero';
import { isDevPreview, nuiCallback } from '@/services/nui';

const FILTERS = [
  { id: 'all', label: 'VISI' },
  { id: 'police', label: 'POLICIJA' },
  { id: 'ems', label: 'EMS' },
  { id: 'shops', label: 'PARDUOTUVĖS' },
  { id: 'jobs', label: 'DARBAI' },
  { id: 'events', label: 'EVENTAI' },
] as const;

type FilterId = (typeof FILTERS)[number]['id'];

const MARKERS: { id: string; label: string; filter: FilterId; x: number; y: number }[] = [
  { id: 'mrpd', label: 'MRPD', filter: 'police', x: 42, y: 58 },
  { id: 'sandy', label: 'Sandy PD', filter: 'police', x: 68, y: 38 },
  { id: 'pillbox', label: 'Pillbox', filter: 'ems', x: 48, y: 52 },
  { id: '247', label: '24/7', filter: 'shops', x: 55, y: 45 },
  { id: 'mech', label: 'Mechanikai', filter: 'jobs', x: 35, y: 62 },
  { id: 'race', label: 'Lenktynės', filter: 'events', x: 72, y: 55 },
];

export function MapPage({
  data,
  notify,
}: {
  data: DashboardData;
  notify: (title: string, description: string, icon?: string) => void;
}) {
  const [filter, setFilter] = useState<FilterId>('all');
  const visible = MARKERS.filter((m) => filter === 'all' || m.filter === filter);

  const openNative = async () => {
    if (isDevPreview()) {
      notify('ŽEMĖLAPIS', 'Žaidime atsidarys native GTA map.', '🗺️');
      return;
    }
    await nuiCallback('openNativeMap');
  };

  return (
    <div className="page-shell">
      <PageHero
        theme="home"
        title="Žemėlapis"
        subtitle="Placeholder žemėlapis su filtrais. Pilnas GTA map — mygtuku apačioje."
        figureLabel="MAP"
        actions={
          <Button variant="outline" onClick={() => void openNative()}>
            ATIDARYTI GTA MAP
          </Button>
        }
      />

      <div className="chips">
        {FILTERS.map((f) => (
          <button
            key={f.id}
            type="button"
            className={`chip${filter === f.id ? ' active' : ''}`}
            onClick={() => setFilter(f.id)}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="page-body">
        <Card title="LOS SANTOS · OVERVIEW">
          <div className="map-canvas" aria-label="Žemėlapio placeholder">
            <div className="map-grid" />
            <div
              className="player-dot"
              style={{ left: '48%', top: '54%' }}
              title={data.player.characterName}
            />
            {visible.map((m) => (
              <div
                key={m.id}
                className="map-marker"
                style={{ left: `${m.x}%`, top: `${m.y}%` }}
              >
                {m.label}
              </div>
            ))}
          </div>
          <p className="muted" style={{ marginTop: 12 }}>
            Rodykla = tu · filtrai keičia markerius · vėliau galima prijungti custom blipus.
          </p>
        </Card>
      </div>
    </div>
  );
}

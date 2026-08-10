import { useId, type ReactNode } from 'react';

export type FigureTheme =
  | 'home'
  | 'pass'
  | 'missions'
  | 'crates'
  | 'premium'
  | 'rewards'
  | 'events'
  | 'ranking'
  | 'profile';

const ACCENT: Record<FigureTheme, string> = {
  home: '#a78bfa',
  pass: '#c4b5fd',
  missions: '#38bdf8',
  crates: '#fbbf24',
  premium: '#f472b6',
  rewards: '#4ade80',
  events: '#fb7185',
  ranking: '#67e8f9',
  profile: '#a78bfa',
};

/** Stylized crew silhouette — fills empty side space on pages */
export function CharacterFigure({
  theme = 'home',
  className = '',
  label,
}: {
  theme?: FigureTheme;
  className?: string;
  label?: string;
}) {
  const uid = useId().replace(/:/g, '');
  const accent = ACCENT[theme];
  const cg = `cg-${theme}-${uid}`;
  const glow = `glow-${theme}-${uid}`;
  return (
    <div className={`char-figure theme-${theme} ${className}`.trim()} aria-hidden>
      <svg viewBox="0 0 220 280" className="char-figure-svg" fill="none">
        <defs>
          <linearGradient id={cg} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor={accent} stopOpacity="0.55" />
            <stop offset="100%" stopColor={accent} stopOpacity="0.12" />
          </linearGradient>
          <radialGradient id={glow} cx="50%" cy="30%" r="55%">
            <stop offset="0%" stopColor={accent} stopOpacity="0.35" />
            <stop offset="100%" stopColor={accent} stopOpacity="0" />
          </radialGradient>
        </defs>
        <ellipse cx="110" cy="248" rx="68" ry="14" fill={accent} opacity="0.18" />
        <circle cx="110" cy="110" r="90" fill={`url(#${glow})`} />
        <path
          d="M70 250c8-42 18-78 40-98 22 20 32 56 40 98H70Z"
          fill={`url(#${cg})`}
          stroke={accent}
          strokeOpacity="0.45"
          strokeWidth="1.5"
        />
        <path
          d="M78 168c10-28 22-44 32-50 10 6 22 22 32 50l-8 42H86l-8-42Z"
          fill={accent}
          fillOpacity="0.22"
          stroke={accent}
          strokeOpacity="0.5"
          strokeWidth="1.2"
        />
        <circle cx="110" cy="88" r="28" fill={`url(#${cg})`} stroke={accent} strokeOpacity="0.55" />
        <path
          d="M82 90c2-28 18-42 28-42s26 14 28 42c-8-10-18-14-28-14s-20 4-28 14Z"
          fill={accent}
          fillOpacity="0.4"
        />
        <path
          d="M78 170c-18 10-28 28-32 48"
          stroke={accent}
          strokeOpacity="0.55"
          strokeWidth="10"
          strokeLinecap="round"
        />
        <path
          d="M142 170c18 10 28 28 32 48"
          stroke={accent}
          strokeOpacity="0.55"
          strokeWidth="10"
          strokeLinecap="round"
        />
        <circle cx="100" cy="90" r="2.5" fill="#f8fafc" opacity="0.7" />
        <circle cx="120" cy="90" r="2.5" fill="#f8fafc" opacity="0.7" />
        {theme === 'crates' || theme === 'rewards' ? (
          <rect x="148" y="188" width="36" height="28" rx="4" fill={accent} fillOpacity="0.45" stroke={accent} />
        ) : null}
        {theme === 'ranking' ? (
          <path d="M150 200l10-22 10 22h-20Zm6-8h8v18h-8v-18Z" fill={accent} fillOpacity="0.7" />
        ) : null}
        {theme === 'missions' || theme === 'events' ? (
          <path d="M158 196l18-8-4 20-14-12Z" fill={accent} fillOpacity="0.65" />
        ) : null}
        {theme === 'pass' || theme === 'premium' ? (
          <path d="M156 192l8-14 8 14-8 4-8-4Z" fill={accent} fillOpacity="0.75" />
        ) : null}
      </svg>
      {label ? <span className="char-figure-label">{label}</span> : null}
    </div>
  );
}

export function PageHero({
  title,
  subtitle,
  theme = 'home',
  figureLabel,
  actions,
  avatarUrl,
  avatarFallback,
}: {
  title: string;
  subtitle?: string;
  theme?: FigureTheme;
  figureLabel?: string;
  actions?: ReactNode;
  avatarUrl?: string;
  avatarFallback?: string;
}) {
  return (
    <header className={`page-hero theme-${theme}`}>
      <div className="page-hero-copy">
        <div className="page-hero-text">
          <h1>{title}</h1>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        {actions ? <div className="page-hero-actions">{actions}</div> : null}
      </div>
      <div className="page-hero-art">
        {avatarUrl || avatarFallback ? (
          <div className={`avatar page-hero-avatar${avatarUrl ? ' has-photo' : ''}`}>
            {avatarUrl ? (
              <img src={avatarUrl} alt="" draggable={false} />
            ) : (
              avatarFallback
            )}
          </div>
        ) : null}
        <CharacterFigure theme={theme} label={figureLabel} />
      </div>
    </header>
  );
}

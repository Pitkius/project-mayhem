/* Realistiškos SVG ikonos — jokio emoji, vieningas 3D stilius */
window.DrugIcons = (() => {
  let _uid = 0;
  const gid = () => `di${++_uid}`;

  function wrap(cls, vb, body, w = 64, h = 64) {
    return `<svg class="di ${cls}" viewBox="${vb}" width="${w}" height="${h}" aria-hidden="true" focusable="false">${body}</svg>`;
  }

  function grad(id, c1, c2, y2 = 1) {
    return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="${y2}"><stop offset="0%" stop-color="${c1}"/><stop offset="100%" stop-color="${c2}"/></linearGradient></defs>`;
  }

  function shine() {
    return `<ellipse cx="22" cy="18" rx="10" ry="6" fill="rgba(255,255,255,0.22)" transform="rotate(-18 22 18)"/>`;
  }

  const icons = {
    growPot(fillPct = 0) {
      const g = gid();
      const fill = Math.max(0, Math.min(100, fillPct));
      return wrap('di-pot', '0 0 64 64',
        `${grad(g, '#8b5a2b', '#4a2f12')}
        <path d="M14 28 Q32 18 50 28 L48 54 Q32 62 16 54 Z" fill="url(#${g})" stroke="#2d1a0a" stroke-width="1.2"/>
        <rect x="20" y="22" width="24" height="4" rx="2" fill="#6b4423"/>
        <clipPath id="${g}c"><path d="M16 30 L48 30 L46 52 Q32 58 18 52 Z"/></clipPath>
        <rect x="16" y="${54 - fill * 0.24}" width="32" height="${fill * 0.24}" fill="#3d2817" clip-path="url(#${g}c)" opacity="0.9"/>
        ${shine()}`);
    },

    wateringCan(fillPct = 0, spoutOpen = false) {
      const g = gid();
      const fill = Math.max(0, Math.min(100, fillPct));
      return wrap('di-can', '0 0 64 64',
        `${grad(g, '#5a9e3a', '#2d5a18')}
        <path d="M18 26 L42 26 L44 48 Q32 56 20 48 Z" fill="url(#${g})" stroke="#1a3a0c" stroke-width="1"/>
        <path d="M42 30 L54 22 L56 28 L44 34 Z" fill="#4a8a2e" stroke="#1a3a0c" stroke-width="0.8"/>
        <rect x="24" y="18" width="12" height="8" rx="3" fill="#3d6b22"/>
        <rect x="22" y="${46 - fill * 0.2}" width="20" height="${fill * 0.2}" fill="#1e4a10" opacity="0.75"/>
        ${spoutOpen ? '<path d="M54 24 Q58 30 54 34" stroke="#7dd3fc" stroke-width="2" fill="none"/>' : ''}
        ${shine()}`);
    },

    scale() {
      const g = gid();
      return wrap('di-scale', '0 0 64 64',
        `${grad(g, '#1e293b', '#0f172a')}
        <rect x="10" y="38" width="44" height="14" rx="3" fill="url(#${g})" stroke="#334155" stroke-width="1"/>
        <rect x="14" y="14" width="36" height="22" rx="4" fill="#0f172a" stroke="#475569" stroke-width="1.2"/>
        <rect x="18" y="18" width="28" height="14" rx="2" fill="#22c55e" opacity="0.85"/>
        <text x="32" y="28" text-anchor="middle" fill="#ecfdf5" font-size="8" font-family="monospace" font-weight="700">0.00</text>
        <circle cx="32" cy="45" r="4" fill="#64748b"/>`);
    },

    scissors() {
      const g = gid();
      return wrap('di-scissors', '0 0 64 64',
        `${grad(g, '#cbd5e1', '#64748b')}
        <circle cx="20" cy="44" r="7" fill="none" stroke="url(#${g})" stroke-width="3"/>
        <circle cx="44" cy="44" r="7" fill="none" stroke="url(#${g})" stroke-width="3"/>
        <path d="M24 40 L48 14" stroke="url(#${g})" stroke-width="3" stroke-linecap="round"/>
        <path d="M40 40 L16 14" stroke="url(#${g})" stroke-width="3" stroke-linecap="round"/>`);
    },

    gloves() {
      const g = gid();
      return wrap('di-gloves', '0 0 64 64',
        `${grad(g, '#f8fafc', '#94a3b8')}
        <path d="M16 36 Q16 20 28 18 L28 10 Q32 6 36 10 L36 18 Q48 20 48 36 L48 52 Q32 58 16 52 Z" fill="url(#${g})" stroke="#64748b" stroke-width="1"/>
        <path d="M22 28 L22 20 M28 26 L28 16 M34 26 L34 16 M40 28 L40 20" stroke="#cbd5e1" stroke-width="2" stroke-linecap="round"/>`);
    },

    cannabisLeaf() {
      const g = gid();
      return wrap('di-leaf', '0 0 64 64',
        `${grad(g, '#4ade80', '#15803d')}
        <path d="M32 8 Q20 20 18 34 Q16 48 32 58 Q48 48 46 34 Q44 20 32 8 Z" fill="url(#${g})" stroke="#14532d" stroke-width="1"/>
        <path d="M32 12 L32 54" stroke="#166534" stroke-width="1.5"/>
        <path d="M32 22 Q22 24 16 28 M32 30 Q42 32 48 28 M32 38 Q24 40 18 44 M32 44 Q40 46 46 42" stroke="#22c55e" stroke-width="1.2" fill="none"/>`);
    },

    soilBag(open = false) {
      const g = gid();
      return wrap('di-bag', '0 0 64 64',
        `${grad(g, '#57534e', '#292524')}
        <path d="M18 18 Q32 10 46 18 L50 50 Q32 58 14 50 Z" fill="url(#${g})" stroke="#44403c" stroke-width="1.2"/>
        <ellipse cx="32" cy="38" rx="14" ry="9" fill="#78350f" opacity="${open ? 1 : 0.85}"/>
        ${open ? '<path d="M18 20 L28 30 M46 20 L36 30" stroke="#fbbf24" stroke-width="2"/>' : '<line x1="16" y1="18" x2="48" y2="18" stroke="#d6d3d1" stroke-width="2" stroke-dasharray="4 3"/>'}`);
    },

    seedPacket() {
      const g = gid();
      return wrap('di-seed', '0 0 64 64',
        `${grad(g, '#166534', '#052e16')}
        <rect x="18" y="12" width="28" height="40" rx="4" fill="url(#${g})" stroke="#4ade80" stroke-width="1"/>
        <circle cx="32" cy="30" r="6" fill="#22c55e"/>
        <path d="M32 24 Q36 18 38 14" stroke="#86efac" stroke-width="1.5" fill="none"/>`);
    },

    waterBottle() {
      const g = gid();
      return wrap('di-bottle', '0 0 64 64',
        `${grad(g, '#38bdf8', '#0369a1')}
        <rect x="26" y="10" width="12" height="6" rx="2" fill="#64748b"/>
        <path d="M22 16 L42 16 L40 54 Q32 58 24 54 Z" fill="rgba(56,189,248,0.35)" stroke="#0ea5e9" stroke-width="1.5"/>
        <rect x="24" y="28" width="16" height="20" fill="url(#${g})" opacity="0.7" rx="2"/>
        ${shine()}`);
    },

    waterDrop() {
      const g = gid();
      return wrap('di-drop', '0 0 64 64',
        `${grad(g, '#7dd3fc', '#0284c7')}
        <path d="M32 10 Q46 30 32 50 Q18 30 32 10 Z" fill="url(#${g})" stroke="#38bdf8" stroke-width="1"/>
        <ellipse cx="26" cy="22" rx="4" ry="6" fill="rgba(255,255,255,0.35)"/>`);
    },

    soilMound() {
      const g = gid();
      return wrap('di-mound', '0 0 64 64',
        `${grad(g, '#92400e', '#451a03')}
        <ellipse cx="32" cy="50" rx="22" ry="7" fill="#292524"/>
        <path d="M10 50 Q18 26 32 24 Q46 26 54 50" fill="url(#${g})" stroke="#78350f" stroke-width="1"/>`);
    },

    thcVial() {
      const g = gid();
      return wrap('di-thc', '0 0 64 64',
        `${grad(g, '#a78bfa', '#5b21b6')}
        <rect x="28" y="8" width="8" height="6" rx="2" fill="#c4b5fd"/>
        <path d="M24 14 L40 14 L38 52 Q32 56 26 52 Z" fill="rgba(167,139,250,0.5)" stroke="#7c3aed" stroke-width="1.5"/>
        <rect x="26" y="28" width="12" height="18" fill="url(#${g})" opacity="0.9" rx="2"/>
        ${shine()}`);
    },

    cartridge() {
      const g = gid();
      return wrap('di-cart', '0 0 64 64',
        `${grad(g, '#e2e8f0', '#64748b')}
        <rect x="22" y="14" width="20" height="36" rx="6" fill="url(#${g})" stroke="#475569" stroke-width="1.2"/>
        <rect x="26" y="8" width="12" height="8" rx="3" fill="#94a3b8"/>
        <rect x="26" y="24" width="12" height="20" fill="#a78bfa" opacity="0.7" rx="2"/>`);
    },

    moonshineJar() {
      const g = gid();
      return wrap('di-jar', '0 0 64 64',
        `${grad(g, '#fbbf24', '#b45309')}
        <path d="M20 20 L44 20 L42 52 Q32 58 22 52 Z" fill="rgba(251,191,36,0.25)" stroke="#d97706" stroke-width="1.5"/>
        <rect x="18" y="14" width="28" height="8" rx="3" fill="#78716c"/>
        <rect x="24" y="30" width="16" height="16" fill="url(#${g})" opacity="0.85" rx="2"/>
        ${shine()}`);
    },

    still() {
      const g = gid();
      return wrap('di-still', '0 0 64 64',
        `${grad(g, '#94a3b8', '#475569')}
        <rect x="26" y="36" width="12" height="18" rx="2" fill="url(#${g})"/>
        <path d="M20 36 L44 36 L40 20 Q32 12 24 20 Z" fill="rgba(148,163,184,0.4)" stroke="#64748b" stroke-width="1.2"/>
        <path d="M40 24 Q52 20 54 12" stroke="#cbd5e1" stroke-width="3" fill="none" stroke-linecap="round"/>
        <circle cx="54" cy="10" r="4" fill="rgba(251,191,36,0.5)"/>`);
    },

    vapeDevice() {
      const g = gid();
      return wrap('di-vape', '0 0 64 64',
        `${grad(g, '#1e293b', '#0f172a')}
        <rect x="28" y="10" width="8" height="44" rx="4" fill="url(#${g})" stroke="#334155" stroke-width="1"/>
        <rect x="26" y="44" width="12" height="8" rx="3" fill="#67e8f9" opacity="0.6"/>
        <ellipse cx="32" cy="8" rx="5" ry="3" fill="#94a3b8"/>`);
    },

    syringe() {
      const g = gid();
      return wrap('di-syringe', '0 0 64 64',
        `${grad(g, '#f1f5f9', '#94a3b8')}
        <rect x="28" y="8" width="8" height="36" rx="2" fill="url(#${g})" stroke="#64748b" stroke-width="1"/>
        <path d="M32 44 L32 56" stroke="#64748b" stroke-width="2"/>
        <path d="M28 56 L36 56" stroke="#64748b" stroke-width="2"/>
        <rect x="30" y="20" width="4" height="16" fill="#f87171" opacity="0.7"/>`);
    },

    methCrystal() {
      const g = gid();
      return wrap('di-meth', '0 0 64 64',
        `${grad(g, '#67e8f9', '#0891b2')}
        <path d="M32 8 L48 28 L40 56 L24 56 L16 28 Z" fill="url(#${g})" stroke="#22d3ee" stroke-width="1" opacity="0.9"/>
        <path d="M32 8 L40 56 M16 28 L48 28" stroke="rgba(255,255,255,0.25)" stroke-width="0.8"/>
        <ellipse cx="28" cy="22" rx="6" ry="10" fill="rgba(255,255,255,0.2)"/>`);
    },

    pill() {
      const g = gid();
      return wrap('di-pill', '0 0 64 64',
        `${grad(g, '#fb923c', '#ea580c')}
        <ellipse cx="32" cy="32" rx="20" ry="12" fill="url(#${g})" stroke="#c2410c" stroke-width="1"/>
        <line x1="32" y1="20" x2="32" y2="44" stroke="rgba(255,255,255,0.35)" stroke-width="2"/>`);
    },

    pillPress() {
      const g = gid();
      return wrap('di-press', '0 0 64 64',
        `${grad(g, '#71717a', '#27272a')}
        <rect x="14" y="36" width="36" height="16" rx="3" fill="url(#${g})"/>
        <rect x="22" y="12" width="20" height="28" rx="4" fill="#52525b" stroke="#a1a1aa" stroke-width="1"/>
        <rect x="26" y="8" width="12" height="8" rx="2" fill="#a1a1aa"/>`);
    },

    mushroom() {
      const g = gid();
      return wrap('di-mushroom', '0 0 64 64',
        `${grad(g, '#c084fc', '#7e22ce')}
        <ellipse cx="32" cy="28" rx="22" ry="14" fill="url(#${g})" stroke="#6b21a8" stroke-width="1"/>
        <rect x="26" y="28" width="12" height="22" rx="4" fill="#fef3c7" stroke="#d6d3d1" stroke-width="1"/>
        <circle cx="22" cy="24" r="3" fill="rgba(255,255,255,0.25)"/>
        <circle cx="36" cy="20" r="2" fill="rgba(255,255,255,0.2)"/>`);
    },

    cocaineBrick() {
      const g = gid();
      return wrap('di-brick', '0 0 64 64',
        `${grad(g, '#f8fafc', '#cbd5e1')}
        <rect x="12" y="20" width="40" height="28" rx="3" fill="url(#${g})" stroke="#94a3b8" stroke-width="1.2"/>
        <line x1="12" y1="30" x2="52" y2="30" stroke="#e2e8f0" stroke-width="1"/>
        <line x1="12" y1="38" x2="52" y2="38" stroke="#e2e8f0" stroke-width="1"/>
        <text x="32" y="36" text-anchor="middle" fill="#64748b" font-size="7" font-weight="700">PURE</text>`);
    },

    cocaLeaf() {
      const g = gid();
      return wrap('di-coca', '0 0 64 64',
        `${grad(g, '#4ade80', '#166534')}
        <path d="M32 6 Q14 18 12 32 Q10 46 32 58 Q54 46 52 32 Q50 18 32 6 Z" fill="url(#${g})" stroke="#14532d" stroke-width="1"/>
        <path d="M32 10 L32 54 M20 22 L44 22 M16 34 L48 34 M20 46 L44 46" stroke="#22c55e" stroke-width="1" fill="none"/>`);
    },

    beaker() {
      const g = gid();
      return wrap('di-beaker', '0 0 64 64',
        `${grad(g, '#38bdf8', '#0284c7')}
        <path d="M22 12 L42 12 L46 52 Q32 58 18 52 Z" fill="rgba(56,189,248,0.2)" stroke="#0ea5e9" stroke-width="1.5"/>
        <rect x="22" y="30" width="20" height="18" fill="url(#${g})" opacity="0.75" rx="1"/>
        ${shine()}`);
    },

    bag() {
      const g = gid();
      return wrap('di-zipbag', '0 0 64 64',
        `${grad(g, 'rgba(255,255,255,0.15)', 'rgba(255,255,255,0.05)')}
        <rect x="14" y="18" width="36" height="36" rx="4" fill="url(#${g})" stroke="rgba(255,255,255,0.45)" stroke-width="1.5"/>
        <line x1="14" y1="26" x2="50" y2="26" stroke="rgba(255,255,255,0.35)" stroke-width="2"/>
        <rect x="20" y="32" width="24" height="16" rx="2" fill="rgba(167,139,250,0.35)"/>`);
    },

    foil() {
      return wrap('di-foil', '0 0 64 64',
        `<rect x="10" y="24" width="44" height="20" rx="2" fill="url(#silver)" stroke="#94a3b8" stroke-width="1"/>
        <defs><linearGradient id="silver" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f8fafc"/><stop offset="50%" stop-color="#cbd5e1"/><stop offset="100%" stop-color="#e2e8f0"/></linearGradient></defs>
        <path d="M14 28 Q32 22 50 28" stroke="rgba(255,255,255,0.5)" stroke-width="1" fill="none"/>`);
    },

    hammer() {
      const g = gid();
      return wrap('di-hammer', '0 0 64 64',
        `${grad(g, '#94a3b8', '#475569')}
        <rect x="10" y="16" width="28" height="14" rx="3" fill="url(#${g})"/>
        <rect x="34" y="22" width="8" height="32" rx="2" fill="#78350f" transform="rotate(25 38 38)"/>`);
    },

    check() {
      return wrap('di-check', '0 0 64 64',
        `<circle cx="32" cy="32" r="24" fill="rgba(74,222,128,0.15)" stroke="#4ade80" stroke-width="2"/>
        <path d="M18 32 L28 42 L46 22" stroke="#4ade80" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`);
    },

    target() {
      return wrap('di-target', '0 0 64 64',
        `<circle cx="32" cy="32" r="22" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="2"/>
        <circle cx="32" cy="32" r="12" fill="none" stroke="rgba(255,255,255,0.35)" stroke-width="2"/>
        <circle cx="32" cy="32" r="4" fill="#f87171"/>`);
    },
  };

  const drugMap = {
    thc: 'thcVial', alcohol: 'moonshineJar', vape: 'vapeDevice', weed: 'cannabisLeaf',
    heroin: 'syringe', meth: 'methCrystal', pills: 'pill', mushroom: 'mushroom',
    cocaine: 'cocaineBrick', amp: 'pill', default: 'beaker',
  };

  function render(name, size = 64) {
    const fn = icons[name];
    if (!fn) return icons.beaker();
    const raw = typeof fn === 'function' ? fn() : fn;
    return raw.replace(/width="\d+"/, `width="${size}"`).replace(/height="\d+"/, `height="${size}"`);
  }

  function drug(drugKey, size = 52) {
    const key = drugMap[String(drugKey || 'default').toLowerCase()] || drugMap.default;
    return render(key, size);
  }

  return { ...icons, render, drug };
})();

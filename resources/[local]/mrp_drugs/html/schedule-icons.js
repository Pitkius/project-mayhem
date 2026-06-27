/* Custom SVG ikonos — augalų mini-žaidimai (be emoji) */
const SchIcons = (() => {
  let uid = 0;
  const nextId = (prefix) => `${prefix}_${++uid}`;

  const wrap = (cls, inner, w = 64, h = 64) =>
    `<svg class="sch-svg ${cls || ""}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">${inner}</svg>`;

  return {
    /** Juodas auginimo vazonas (grow_pot) */
    growPot(fillPct = 0, label) {
      const soilH = Math.max(0, Math.min(46, (fillPct / 100) * 46));
      const soilY = 50 - soilH;
      const gPot = nextId("gp");
      const gSoil = nextId("gs");
      const gRim = nextId("gr");
      return wrap(
        "sch-icon-grow-pot",
        `<defs>
          <linearGradient id="${gPot}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#52525b"/>
            <stop offset="45%" stop-color="#27272a"/>
            <stop offset="100%" stop-color="#09090b"/>
          </linearGradient>
          <linearGradient id="${gRim}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#71717a"/>
            <stop offset="100%" stop-color="#3f3f46"/>
          </linearGradient>
          <linearGradient id="${gSoil}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#92400e"/>
            <stop offset="100%" stop-color="#451a03"/>
          </linearGradient>
        </defs>
        <ellipse cx="32" cy="56" rx="22" ry="5" fill="#000" opacity="0.35"/>
        <rect x="11" y="14" width="42" height="9" rx="3" fill="url(#${gRim})" stroke="#a1a1aa" stroke-width="0.8"/>
        <path d="M14 22 L50 22 L46 54 Q32 60 18 54 Z" fill="url(#${gPot})" stroke="#52525b" stroke-width="1.2"/>
        <rect x="18" y="${soilY}" width="28" height="${soilH}" rx="2" fill="url(#${gSoil})"/>
        <path d="M14 22 L50 22" stroke="#71717a" stroke-width="0.6" opacity="0.6"/>`
      );
    },

    pot(fillPct = 0) {
      return this.growPot(fillPct);
    },

    soilBag(open = false) {
      const tear = open
        ? `<path d="M18 14 L26 20 M46 14 L38 20 M32 12 L32 22" stroke="#fbbf24" stroke-width="2" stroke-linecap="round"/>`
        : `<line x1="16" y1="16" x2="48" y2="16" stroke="#fde68a" stroke-width="2.5" stroke-dasharray="4 3"/>`;
      const gBag = nextId("bag");
      const gSoil = nextId("soil");
      return wrap(
        "sch-icon-bag",
        `<defs>
          <linearGradient id="${gBag}" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3f3f46"/><stop offset="100%" stop-color="#18181b"/></linearGradient>
          <linearGradient id="${gSoil}" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#92400e"/><stop offset="100%" stop-color="#451a03"/></linearGradient>
        </defs>
        <path d="M22 16 Q32 8 42 16 L46 52 Q32 60 18 52 Z" fill="url(#${gBag})" stroke="#71717a" stroke-width="1.5"/>
        <ellipse cx="32" cy="38" rx="14" ry="10" fill="url(#${gSoil})" opacity="${open ? 1 : 0.85}"/>
        ${tear}
        <text x="32" y="58" text-anchor="middle" fill="#a1a1aa" font-size="7" font-family="system-ui">SUBSTRATAS</text>`
      );
    },

    /** Lapų kirpimo žirklės (trimming_scissors) */
    trimScissors() {
      const gBlade = nextId("tb");
      return wrap(
        "sch-icon-trim-scissors",
        `<defs>
          <linearGradient id="${gBlade}" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#f4f4f5"/>
            <stop offset="100%" stop-color="#a1a1aa"/>
          </linearGradient>
        </defs>
        <path d="M18 46 C10 46 8 38 12 32 C16 26 22 24 26 28 L34 36" fill="none" stroke="#ea580c" stroke-width="4" stroke-linecap="round"/>
        <path d="M46 46 C54 46 56 38 52 32 C48 26 42 24 38 28 L30 36" fill="none" stroke="#ea580c" stroke-width="4" stroke-linecap="round"/>
        <path d="M26 28 L38 16 L42 20 L30 32 Z" fill="url(#${gBlade})" stroke="#71717a" stroke-width="0.8"/>
        <path d="M38 28 L26 16 L22 20 L34 32 Z" fill="url(#${gBlade})" stroke="#71717a" stroke-width="0.8"/>
        <circle cx="32" cy="36" r="3" fill="#52525b"/>
        <path d="M34 36 L48 48" stroke="url(#${gBlade})" stroke-width="2.5" stroke-linecap="round"/>
        <path d="M30 36 L16 48" stroke="url(#${gBlade})" stroke-width="2.5" stroke-linecap="round"/>`
      );
    },

    scissors() {
      return this.trimScissors();
    },

    /** Apsauginės pirštinės */
    gloves() {
      const gGlove = nextId("gl");
      return wrap(
        "sch-icon-gloves",
        `<defs>
          <linearGradient id="${gGlove}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#3f3f46"/>
            <stop offset="100%" stop-color="#18181b"/>
          </linearGradient>
        </defs>
        <path d="M10 30 Q10 14 20 12 L24 12 Q28 12 28 16 L28 34 Q28 44 20 46 L16 46 Q10 44 10 36 Z" fill="url(#${gGlove})" stroke="#71717a" stroke-width="1.2"/>
        <path d="M28 20 L34 16 Q42 14 46 22 L46 38 Q46 46 38 48 L32 48 Q28 48 28 44 Z" fill="url(#${gGlove})" stroke="#71717a" stroke-width="1.2"/>
        <path d="M14 18 L14 26" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>
        <path d="M18 16 L18 24" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>
        <path d="M22 16 L22 24" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>
        <path d="M34 18 L34 26" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>
        <path d="M38 20 L38 28" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>
        <path d="M42 22 L42 30" stroke="#52525b" stroke-width="2" stroke-linecap="round"/>`
      );
    },

    /** Skaitmeninės svarstyklės */
    digitalScale() {
      const gScale = nextId("sc");
      return wrap(
        "sch-icon-scale",
        `<defs>
          <linearGradient id="${gScale}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#e4e4e7"/>
            <stop offset="100%" stop-color="#71717a"/>
          </linearGradient>
        </defs>
        <rect x="10" y="28" width="44" height="26" rx="4" fill="url(#${gScale})" stroke="#52525b" stroke-width="1.2"/>
        <rect x="14" y="32" width="36" height="12" rx="2" fill="#052e16" stroke="#166534" stroke-width="0.8"/>
        <text x="32" y="41" text-anchor="middle" fill="#4ade80" font-size="7" font-family="monospace" font-weight="700">0.00g</text>
        <rect x="26" y="20" width="12" height="10" rx="2" fill="#a1a1aa"/>
        <ellipse cx="32" cy="58" rx="18" ry="3" fill="#000" opacity="0.25"/>`
      );
    },

    /** Kanapių lapas derliui */
    cannabisLeaf() {
      const gLeaf = nextId("lf");
      return wrap(
        "sch-icon-leaf",
        `<defs>
          <linearGradient id="${gLeaf}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#4ade80"/>
            <stop offset="100%" stop-color="#15803d"/>
          </linearGradient>
        </defs>
        <path d="M32 54 L32 30" stroke="#166534" stroke-width="2.2" stroke-linecap="round"/>
        <path d="M32 44 Q14 40 10 28 Q22 32 32 38" fill="url(#${gLeaf})" stroke="#22c55e" stroke-width="0.8"/>
        <path d="M32 42 Q50 38 54 26 Q42 30 32 36" fill="url(#${gLeaf})" stroke="#22c55e" stroke-width="0.8"/>
        <path d="M32 36 Q18 30 16 20 Q26 26 32 32" fill="url(#${gLeaf})" stroke="#22c55e" stroke-width="0.8"/>
        <path d="M32 34 Q46 28 48 18 Q38 24 32 30" fill="url(#${gLeaf})" stroke="#22c55e" stroke-width="0.8"/>
        <path d="M32 40 Q24 36 22 30 Q28 34 32 38" fill="#166534" opacity="0.5"/>
        <path d="M32 40 Q40 36 42 30 Q36 34 32 38" fill="#166534" opacity="0.5"/>`
      );
    },

    seedPacket() {
      return wrap(
        "sch-icon-seed",
        `<rect x="18" y="12" width="28" height="40" rx="4" fill="#14532d" stroke="#4ade80" stroke-width="1.2"/>
        <circle cx="32" cy="30" r="6" fill="#22c55e"/>
        <path d="M32 24 Q36 20 38 16" stroke="#86efac" stroke-width="1.5" fill="none"/>
        <circle cx="38" cy="16" r="2" fill="#bbf7d0"/>
        <text x="32" y="48" text-anchor="middle" fill="#86efac" font-size="6" font-family="system-ui">SEEDS</text>`
      );
    },

    wateringCan(fillPct = 0, spoutOpen = false) {
      const waterH = Math.max(0, Math.min(22, fillPct * 0.22));
      const gCan = nextId("cn");
      return wrap(
        "sch-icon-can",
        `<defs><linearGradient id="${gCan}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#65a30d"/><stop offset="100%" stop-color="#365314"/></linearGradient></defs>
        <path d="M12 24 Q12 14 22 14 L38 14 Q48 14 48 24 L46 50 Q32 56 18 50 Z" fill="url(#${gCan})" stroke="#a3e635" stroke-width="1.2"/>
        <rect x="20" y="${38 - waterH}" width="20" height="${waterH}" fill="#38bdf8" opacity="0.75" rx="2"/>
        <path d="M48 28 L58 24 L58 32 Z" fill="#4d7c0f" stroke="#bef264" stroke-width="1"/>
        <path d="M58 28 L${spoutOpen ? 66 : 62} 30" stroke="#bef264" stroke-width="2" stroke-linecap="round"/>
        <path d="M26 14 Q26 8 32 6 Q38 8 38 14" fill="none" stroke="#d9f99d" stroke-width="2"/>`
      );
    },

    waterBottle() {
      return wrap(
        "sch-icon-bottle",
        `<rect x="24" y="10" width="16" height="6" rx="2" fill="#64748b"/>
        <path d="M22 16 L42 16 L40 54 Q32 58 24 54 Z" fill="rgba(56,189,248,0.35)" stroke="#38bdf8" stroke-width="1.5"/>
        <rect x="24" y="28" width="16" height="22" fill="#0ea5e9" opacity="0.65" rx="2"/>
        <ellipse cx="32" cy="30" rx="6" ry="2" fill="#bae6fd" opacity="0.5"/>`
      );
    },

    sprout() {
      return this.cannabisLeaf();
    },

    waterDrop() {
      return wrap(
        "sch-icon-drop",
        `<path d="M32 10 Q44 28 32 48 Q20 28 32 10 Z" fill="#38bdf8" stroke="#7dd3fc" stroke-width="1.2"/>
        <ellipse cx="28" cy="26" rx="4" ry="6" fill="#e0f2fe" opacity="0.45"/>`
      );
    },

    soilMound() {
      return wrap(
        "sch-icon-mound",
        `<ellipse cx="32" cy="48" rx="22" ry="8" fill="#451a03"/>
        <path d="M12 48 Q20 28 32 26 Q44 28 52 48" fill="#92400e" stroke="#78350f" stroke-width="1"/>
        <circle cx="24" cy="38" r="2" fill="#a16207" opacity="0.6"/>
        <circle cx="38" cy="36" r="1.5" fill="#a16207" opacity="0.5"/>`
      );
    },
  };
})();

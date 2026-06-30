/* Mini-žaidimų ikonos — PNG nuotraukos (ne piešiamas SVG) */
const SchIcons = (() => {
  const ICON_BASE = 'icons';

  function pngImg(file, className = 'sch-png-icon') {
    return `<img class="${className}" src="${ICON_BASE}/${file}.png" alt="" draggable="false" loading="eager"/>`;
  }

  function fillBar(pct, cls) {
    const fill = Math.max(0, Math.min(100, Number(pct) || 0));
    return `<div class="${cls}" style="--fill:${fill}%"><span></span></div>`;
  }

  return {
    /** Augimo vazonas (grow_pot) */
    growPot(fillPct = 0) {
      return `<div class="sch-png-stack sch-png-pot">
        ${pngImg('grow_pot', 'sch-png-pot__img')}
        ${fillBar(fillPct, 'sch-png-pot__fill')}
      </div>`;
    },

    pot(fillPct = 0) {
      return this.growPot(fillPct);
    },

    /** Skaitmeninės svarstyklės (drug_scale) */
    digitalScale() {
      return pngImg('drug_scale', 'sch-png-scale');
    },

    /** Laistytuvas (watering_can) */
    wateringCan(fillPct = 0, spoutOpen = false) {
      const openCls = spoutOpen ? ' sch-png-can--open' : '';
      return `<div class="sch-png-stack sch-png-can${openCls}">
        ${pngImg('watering_can', 'sch-png-can__img')}
        ${fillBar(fillPct, 'sch-png-can__fill')}
      </div>`;
    },

    /* --- Kiti įrankiai kol kas lieka SVG (vėliau galima perkelti į PNG) --- */

    soilBag(open = false) {
      const tear = open
        ? `<path d="M18 14 L26 20 M46 14 L38 20 M32 12 L32 22" stroke="#fbbf24" stroke-width="2" stroke-linecap="round"/>`
        : `<line x1="16" y1="16" x2="48" y2="16" stroke="#fde68a" stroke-width="2.5" stroke-dasharray="4 3"/>`;
      let uid = `bag_${Date.now()}`;
      return `<svg class="sch-svg sch-icon-bag" viewBox="0 0 64 64" width="64" height="64" aria-hidden="true">
        <defs>
          <linearGradient id="${uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#3f3f46"/><stop offset="100%" stop-color="#18181b"/></linearGradient>
        </defs>
        <path d="M22 16 Q32 8 42 16 L46 52 Q32 60 18 52 Z" fill="url(#${uid})" stroke="#71717a" stroke-width="1.5"/>
        <ellipse cx="32" cy="38" rx="14" ry="10" fill="#92400e" opacity="${open ? 1 : 0.85}"/>
        ${tear}
      </svg>`;
    },

    trimScissors() {
      return pngImg('trimming_scissors', 'sch-png-scissors');
    },

    scissors() {
      return this.trimScissors();
    },

    gloves() {
      return pngImg('gloves_item', 'sch-png-gloves');
    },

    cannabisLeaf() {
      return pngImg('weed_leaf', 'sch-png-leaf');
    },

    seedPacket() {
      return `<svg class="sch-svg sch-icon-seed" viewBox="0 0 64 64" width="64" height="64" aria-hidden="true">
        <rect x="18" y="12" width="28" height="40" rx="4" fill="#14532d" stroke="#4ade80" stroke-width="1.2"/>
        <circle cx="32" cy="30" r="6" fill="#22c55e"/>
        <path d="M32 24 Q36 20 38 16" stroke="#86efac" stroke-width="1.5" fill="none"/>
      </svg>`;
    },

    waterBottle() {
      return `<svg class="sch-svg sch-icon-bottle" viewBox="0 0 64 64" width="64" height="64" aria-hidden="true">
        <rect x="24" y="10" width="16" height="6" rx="2" fill="#64748b"/>
        <path d="M22 16 L42 16 L40 54 Q32 58 24 54 Z" fill="rgba(56,189,248,0.35)" stroke="#38bdf8" stroke-width="1.5"/>
        <rect x="24" y="28" width="16" height="22" fill="#0ea5e9" opacity="0.65" rx="2"/>
      </svg>`;
    },

    sprout() {
      return this.cannabisLeaf();
    },

    waterDrop() {
      return `<svg class="sch-svg sch-icon-drop" viewBox="0 0 64 64" width="64" height="64" aria-hidden="true">
        <path d="M32 10 Q44 28 32 48 Q20 28 32 10 Z" fill="#38bdf8" stroke="#7dd3fc" stroke-width="1.2"/>
      </svg>`;
    },

    soilMound() {
      return `<svg class="sch-svg sch-icon-mound" viewBox="0 0 64 64" width="64" height="64" aria-hidden="true">
        <ellipse cx="32" cy="48" rx="22" ry="8" fill="#451a03"/>
        <path d="M12 48 Q20 28 32 26 Q44 28 52 48" fill="#92400e" stroke="#78350f" stroke-width="1"/>
      </svg>`;
    },
  };
})();

const hudRoot = document.getElementById("hudRoot");
const hudBars = document.getElementById("hudBars");
const hudRings = document.getElementById("hudRings");
const hudTiles = document.getElementById("hudTiles");
const hudFrame = document.getElementById("hudFrame");
const hudBlCluster = document.getElementById("hudBlCluster");
const rows = {
  health: document.getElementById("row-health"),
  armor: document.getElementById("row-armor"),
  stamina: document.getElementById("row-stamina"),
  hunger: document.getElementById("row-hunger"),
  thirst: document.getElementById("row-thirst"),
  voice: document.getElementById("row-voice"),
};
const ringWraps = {
  health: document.getElementById("ring-wrap-health"),
  armor: document.getElementById("ring-wrap-armor"),
  stamina: document.getElementById("ring-wrap-stamina"),
  hunger: document.getElementById("ring-wrap-hunger"),
  thirst: document.getElementById("ring-wrap-thirst"),
  voice: document.getElementById("ring-wrap-voice"),
};
const ringTexts = {
  health: document.getElementById("ring-pct-health"),
  armor: document.getElementById("ring-pct-armor"),
  stamina: document.getElementById("ring-pct-stamina"),
  hunger: document.getElementById("ring-pct-hunger"),
  thirst: document.getElementById("ring-pct-thirst"),
  voice: document.getElementById("ring-pct-voice"),
};
const carHud = document.getElementById("carhud");
const speedText = document.getElementById("speed");
const fuelText = document.getElementById("fuel");
const seatbeltText = document.getElementById("seatbelt");
const body = document.body;
const hudMenu = document.getElementById("hudMenu");

const MAIN_STATS = ["health", "armor", "stamina", "hunger", "thirst", "voice"];
const RING_R = 15;
const RING_LEN = 2 * Math.PI * RING_R;

const menu = {
  preset: document.getElementById("menuPreset"),
  style: document.getElementById("menuStyle"),
  color: document.getElementById("menuColor"),
  alpha: document.getElementById("menuAlpha"),
  scale: document.getElementById("menuScale"),
  scaleVal: document.getElementById("menuScaleVal"),
  alphaVal: document.getElementById("menuAlphaVal"),
  health: document.getElementById("optHealth"),
  armor: document.getElementById("optArmor"),
  stamina: document.getElementById("optStamina"),
  hunger: document.getElementById("optHunger"),
  thirst: document.getElementById("optThirst"),
  voice: document.getElementById("optVoice"),
  speed: document.getElementById("optSpeed"),
  fuel: document.getElementById("optFuel"),
  seatbelt: document.getElementById("optSeatbelt"),
  compact: document.getElementById("optCompact"),
  anim: document.getElementById("optAnim"),
  btnApplyPreset: document.getElementById("btnApplyPreset"),
  btnSavePreset: document.getElementById("btnSavePreset"),
  btnResetDefaults: document.getElementById("btnResetDefaults"),
  btnCloseMenu: document.getElementById("btnCloseMenu"),
  btnExport: document.getElementById("btnExport"),
  btnImport: document.getElementById("btnImport"),
  importArea: document.getElementById("hmImportArea"),
  savedBadge: document.getElementById("hmSavedBadge"),
  pvStats: document.getElementById("hmPvStats"),
  pvVoice: document.getElementById("hmPvVoice"),
  pvCar: document.getElementById("hmPvCar"),
  pvWeapon: document.getElementById("hmPvWeapon"),
  pvClock: document.getElementById("hmPvClock"),
  preview: document.getElementById("hmPreview"),
  hudBg: document.getElementById("optHudBg"),
  dynamic: document.getElementById("optDynamic"),
  colPrimary: document.getElementById("hmColPrimary"),
  colSecondary: document.getElementById("hmColSecondary"),
  colAccent: document.getElementById("hmColAccent"),
  colText: document.getElementById("hmColText"),
  swatches: document.getElementById("hmSwatches"),
  tabs: document.getElementById("hmTabs"),
};

const SERVER_PLACEHOLDER = "fivemprojektas";

const THEME_PALETTE = {
  violet: { primary: "#a78bfa", secondary: "#5b21b6", accent: "#e879f9", text: "#f8fafc" },
  cyan: { primary: "#22d3ee", secondary: "#0e7490", accent: "#67e8f9", text: "#f0fdfa" },
  red: { primary: "#f87171", secondary: "#991b1b", accent: "#fb7185", text: "#fff1f2" },
  green: { primary: "#86efac", secondary: "#166534", accent: "#bbf7d0", text: "#f0fdf4" },
  amber: { primary: "#fbbf24", secondary: "#b45309", accent: "#fde68a", text: "#fffbeb" },
};

const PREVIEW_ICONS = {
  health: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.53L12 21.35z"/></svg>',
  armor: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"/></svg>',
  stamina: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M13 2L3 14h8l-1 8 10-12h-8l1-8z"/></svg>',
  hunger: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4z"/></svg>',
  thirst: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 22c4.97 0 9-4.03 9-9 0-4.97-4.5-10-9-13-4.5 3-9 8.03-9 13 0 4.97 4.03 9 9 9z"/></svg>',
  voice: '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.49 6-3.31 6-6.72h-1.7z"/></svg>',
};

const PREVIEW_SAMPLE = {
  health: 85,
  armor: 22,
  stamina: 74,
  hunger: 90,
  thirst: 87,
  voice: 62,
};

const PREVIEW_COLORS = {
  health: "#f43f5e",
  armor: "#a78bfa",
  hunger: "#fb923c",
  thirst: "#38bdf8",
  stamina: "#e879f9",
  voice: "#c4b5fd",
};

const DEFAULT_MENU_STATE = {
  style: "dots",
  color: "violet",
  alpha: 0.58,
  scale: 1,
  compact: false,
  anim: true,
  show: {
    health: true,
    armor: true,
    stamina: false,
    hunger: true,
    thirst: true,
    voice: true,
    speed: false,
    fuel: false,
    seatbelt: false,
  },
};

const bars = {
  health: document.getElementById("health"),
  armor: document.getElementById("armor"),
  stamina: document.getElementById("stamina"),
  hunger: document.getElementById("hunger"),
  thirst: document.getElementById("thirst"),
  voice: document.getElementById("voice"),
};

const ringProgress = {};
MAIN_STATS.forEach((k) => {
  ringProgress[k] = document.getElementById(`ring-progress-${k}`);
});

const tileWraps = {
  health: document.getElementById("tile-wrap-health"),
  armor: document.getElementById("tile-wrap-armor"),
  stamina: document.getElementById("tile-wrap-stamina"),
  hunger: document.getElementById("tile-wrap-hunger"),
  thirst: document.getElementById("tile-wrap-thirst"),
  voice: document.getElementById("tile-wrap-voice"),
};
const hfWraps = {
  health: document.getElementById("hf-wrap-health"),
  armor: document.getElementById("hf-wrap-armor"),
  stamina: document.getElementById("hf-wrap-stamina"),
  hunger: document.getElementById("hf-wrap-hunger"),
  thirst: document.getElementById("hf-wrap-thirst"),
  voice: document.getElementById("hf-wrap-voice"),
};
const hfFills = {};
const hfVals = {};
MAIN_STATS.forEach((k) => {
  hfFills[k] = document.getElementById(`hf-fill-${k}`);
  hfVals[k] = document.getElementById(`hf-val-${k}`);
});
const tileFills = {};
const tileTexts = {};
MAIN_STATS.forEach((k) => {
  tileFills[k] = document.getElementById(`tile-fill-${k}`);
  tileTexts[k] = document.getElementById(`tile-pct-${k}`);
});

const carSpeedDigits = document.getElementById("carSpeedDigits");
const carGear = document.getElementById("carGear");
const carRpmArc = document.getElementById("carRpmArc");
const carFuelArc = document.getElementById("carFuelArc");
const chStatTurnL = document.getElementById("chStatTurnL");
const chStatTurnR = document.getElementById("chStatTurnR");
const chStatBelt = document.getElementById("chStatBelt");
const chStatHandbrake = document.getElementById("chStatHandbrake");
const chStatLock = document.getElementById("chStatLock");
const chStatLights = document.getElementById("chStatLights");
const carhudClassic = document.getElementById("carhudClassic");
const vehiclePanel = document.getElementById("vehiclePanel");
const vehicleListMenu = document.getElementById("vehicleListMenu");
const vlmHeader = document.getElementById("vlmHeader");
const vlmSub = document.getElementById("vlmSub");
const vlmRows = document.getElementById("vlmRows");
const vpClock = document.getElementById("vpClock");
const vpWeather = document.getElementById("vpWeather");
const vpStreet = document.getElementById("vpStreet");
const vpWaypoint = document.getElementById("vpWaypoint");
const vpFuelHFill = document.getElementById("vpFuelHFill");
const vpMotorHFill = document.getElementById("vpMotorHFill");
const vpFuelPct = document.getElementById("vpFuelPct");
const vpMotorPct = document.getElementById("vpMotorPct");
const vpVehicleName = document.getElementById("vpVehicleName");
const vpVehicleImage = document.getElementById("vpVehicleImage");

function setChStat(el, mode) {
  if (!el) return;
  el.classList.remove("state-on", "state-off", "state-warn", "state-blink");
  if (mode) el.classList.add(mode);
}

function setVehicleSchemaImage() {
  if (!vpVehicleImage) return;
  vpVehicleImage.src = "assets/vehicles/car-schema-topdown.svg";
  vpVehicleImage.classList.add("vp-schema-loaded");
}
const vpPlateLine = document.getElementById("vpPlateLine");
const vpHazardToggle = document.getElementById("vpHazardToggle");
const vpBtnClose = document.getElementById("vpBtnClose");

const CAR_RPM_ARC_LEN = (270 / 360) * 2 * Math.PI * 50;
const CAR_FUEL_ARC_LEN = (270 / 360) * 2 * Math.PI * 58;

(function initRings() {
  MAIN_STATS.forEach((k) => {
    const el = ringProgress[k];
    if (!el) return;
    el.style.strokeDasharray = String(RING_LEN);
    el.style.strokeDashoffset = String(RING_LEN);
  });
})();

(function initCarArcs() {
  if (carRpmArc) {
    carRpmArc.style.strokeDasharray = `${CAR_RPM_ARC_LEN} 400`;
    carRpmArc.style.strokeDashoffset = String(CAR_RPM_ARC_LEN);
  }
  if (carFuelArc) {
    carFuelArc.style.strokeDasharray = `${CAR_FUEL_ARC_LEN} 400`;
    carFuelArc.style.strokeDashoffset = String(CAR_FUEL_ARC_LEN);
  }
})();

let currentSettings = {
  style: "dots",
  color: "violet",
  alpha: 0.58,
  scale: 1,
  compact: false,
  anim: true,
  show: {
    health: true,
    armor: true,
    stamina: false,
    hunger: true,
    thirst: true,
    voice: true,
    speed: false,
    fuel: false,
    seatbelt: false,
  },
};
let menuPresets = {};
let savedBadgeTimer = null;

function resourceName() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "fivempro_hud";
}

function nuiPost(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

function mainStatsVisible() {
  const s = currentSettings.show || {};
  return MAIN_STATS.some((k) => s[k] === true);
}

function setBar(name, value, opts) {
  const o = opts || {};
  const clamped = Math.max(0, Math.min(100, Number(value) || 0));
  if (bars[name]) bars[name].style.width = `${clamped}%`;
  const ring = ringProgress[name];
  if (ring) {
    ring.style.strokeDashoffset = String(RING_LEN * (1 - clamped / 100));
  }
  const pctEl = ringTexts[name];
  if (pctEl) {
    pctEl.textContent = String(Math.round(clamped));
  }
  const tf = tileFills[name];
  if (tf) tf.style.height = `${clamped}%`;
  const tt = tileTexts[name];
  if (tt) tt.textContent = String(Math.round(clamped));
  const hf = hfFills[name];
  if (hf) hf.style.height = `${clamped}%`;
  const hv = hfVals[name];
  if (hv) {
    if (name === "voice" && o.voiceTalking) {
      hv.textContent = "Kalba";
    } else if (name === "voice") {
      hv.textContent = clamped >= 80 ? "Tol." : clamped >= 55 ? "Vid." : "Art.";
    } else {
      hv.textContent = String(Math.round(clamped));
    }
  }
  if (hfWraps[name]) {
    hfWraps[name].classList.toggle("is-talking", name === "voice" && !!o.voiceTalking);
  }
}

function applyVisualStyle(style) {
  const allowed = ["line", "square", "dots", "tiles", "frame"];
  const normalized = allowed.includes(style) ? style : "dots";
  body.classList.remove("shape-line", "shape-square", "shape-dots", "shape-tiles", "shape-frame");
  body.classList.add(`shape-${normalized}`);

  const isRings = normalized === "dots";
  const isTiles = normalized === "tiles";
  const isFrame = normalized === "frame";
  const useBars = normalized === "line" || normalized === "square";
  hudBars.classList.toggle("hidden", !useBars);
  hudRings.classList.toggle("hidden", !isRings);
  if (hudTiles) hudTiles.classList.toggle("hidden", !isTiles);
  if (hudFrame) hudFrame.classList.toggle("hidden", !isFrame);
  if (hudBlCluster) hudBlCluster.classList.toggle("hf-shell-active", isFrame);
}

function syncRows() {
  const s = currentSettings.show || {};
  MAIN_STATS.forEach((k) => {
    const on = s[k] === true;
    if (rows[k]) rows[k].classList.toggle("hidden", !on);
    if (ringWraps[k]) ringWraps[k].classList.toggle("hidden", !on);
    if (tileWraps[k]) tileWraps[k].classList.toggle("hidden", !on);
    if (hfWraps[k]) hfWraps[k].classList.toggle("hidden", !on);
  });
}

function updateHudVisibility(gameShowHud) {
  const show = !!gameShowHud && mainStatsVisible();
  hudRoot.style.display = show ? "flex" : "none";
}

function applyThemeData(data) {
  if (!data) return;
  currentSettings.style = data.style || currentSettings.style;
  currentSettings.alpha = Number(data.alpha || currentSettings.alpha);
  currentSettings.color = data.color || currentSettings.color;
  if (data.show) currentSettings.show = { ...currentSettings.show, ...data.show };
  if (data.scale != null) currentSettings.scale = Number(data.scale) || 1;
  if (data.compact != null) currentSettings.compact = data.compact === true;
  if (data.anim != null) currentSettings.anim = data.anim !== false;
  if (data.fillColor) {
    document.documentElement.style.setProperty("--accent-fill", data.fillColor);
  }
  if (data.glowColor) {
    document.documentElement.style.setProperty("--accent-glow", data.glowColor);
  }
  if (data.tileColors && typeof data.tileColors === "object") {
    const tc = data.tileColors;
    if (tc.health) document.documentElement.style.setProperty("--tile-health", tc.health);
    if (tc.armor) document.documentElement.style.setProperty("--tile-armor", tc.armor);
    if (tc.hunger) document.documentElement.style.setProperty("--tile-hunger", tc.hunger);
    if (tc.thirst) document.documentElement.style.setProperty("--tile-thirst", tc.thirst);
    if (tc.stamina) document.documentElement.style.setProperty("--tile-stamina", tc.stamina);
    if (tc.voice) document.documentElement.style.setProperty("--tile-voice", tc.voice);
  }
  if (data.vehicleUiAccent) {
    document.documentElement.style.setProperty("--vehicle-accent", data.vehicleUiAccent);
  }
  document.documentElement.style.setProperty("--panel-alpha", String(currentSettings.alpha || 0.55));
  document.documentElement.style.setProperty("--hud-scale", String(currentSettings.scale || 1));
  body.classList.toggle("hud-compact", currentSettings.compact === true);
  body.classList.toggle("no-hud-anim", currentSettings.anim === false);
  applyVisualStyle(currentSettings.style);
}

function updateMenuLabels() {
  if (menu.alphaVal && menu.alpha) {
    menu.alphaVal.textContent = `${Math.round(Number(menu.alpha.value) * 100)}%`;
  }
  if (menu.scaleVal && menu.scale) {
    menu.scaleVal.textContent = `${Math.round(Number(menu.scale.value) * 100)}%`;
  }
}

function syncSwitchLabels() {
  document.querySelectorAll(".hm-el").forEach((el) => {
    const input = el.querySelector('input[type="checkbox"]');
    if (input) el.classList.toggle("is-on", input.checked);
  });
}

function activePreviewStats(show) {
  const s = show || {};
  return MAIN_STATS.filter((k) => s[k] === true);
}

function updatePreviewClock() {
  if (!menu.pvClock) return;
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  const mo = String(now.getMonth() + 1).padStart(2, "0");
  const yr = now.getFullYear();
  menu.pvClock.textContent = `${hh}:${mm} · ${dd}.${mo}.${yr}`;
}

function updateThemeColorPicks(colorKey) {
  const pal = THEME_PALETTE[colorKey] || THEME_PALETTE.violet;
  if (menu.colPrimary) menu.colPrimary.style.background = pal.primary;
  if (menu.colSecondary) menu.colSecondary.style.background = pal.secondary;
  if (menu.colAccent) menu.colAccent.style.background = pal.accent;
  if (menu.colText) menu.colText.style.background = pal.text;
}

function renderPreviewBarRows(keys) {
  keys.forEach((k) => {
    const pct = PREVIEW_SAMPLE[k] || 50;
    const row = document.createElement("div");
    row.className = "hm-pv-bar-row";
    row.innerHTML = `<span class="hm-pv-bar-ico">${PREVIEW_ICONS[k] || ""}</span><div class="hm-pv-bar-track"><div class="hm-pv-bar-fill" style="width:${pct}%;background:${PREVIEW_COLORS[k] || "#a78bfa"};box-shadow:0 0 8px ${PREVIEW_COLORS[k] || "#a78bfa"}55"></div></div>`;
    menu.pvStats.appendChild(row);
  });
}

function renderPreviewStats(_style, show) {
  if (!menu.pvStats) return;
  const keys = activePreviewStats(show);
  menu.pvStats.innerHTML = "";
  if (!keys.length) {
    menu.pvStats.innerHTML = '<span class="hm-pv-empty">Nėra aktyvių elementų</span>';
    return;
  }
  renderPreviewBarRows(keys);
}

function renderMenuPreview() {
  const state = getMenuState();
  renderPreviewStats(state.style, state.show);
  updatePreviewClock();
  updateThemeColorPicks(state.color);
  if (menu.preview) {
    menu.preview.classList.toggle("hm-pv-dim-bg", menu.hudBg ? !menu.hudBg.checked : false);
  }
  if (menu.pvVoice) menu.pvVoice.classList.toggle("hidden", !state.show.voice);
  const showCar = state.show.speed || state.show.fuel || state.show.seatbelt;
  if (menu.pvCar) menu.pvCar.classList.toggle("hidden", !showCar);
  document.querySelectorAll(".hm-pv-server-logo").forEach((el) => {
    el.textContent = SERVER_PLACEHOLDER;
  });
  if (menu.swatches) {
    menu.swatches.querySelectorAll(".hm-swatch").forEach((sw) => {
      sw.classList.toggle("is-active", sw.getAttribute("data-c") === state.color);
    });
  }
  syncSwitchLabels();
  updateMenuLabels();
}

function applyMenuLive() {
  const payload = getMenuState();
  currentSettings = {
    ...currentSettings,
    style: payload.style,
    color: payload.color,
    alpha: payload.alpha,
    scale: payload.scale,
    compact: payload.compact,
    anim: payload.anim,
    show: { ...currentSettings.show, ...payload.show },
  };
  syncRows();
  applyThemeData({
    style: currentSettings.style,
    alpha: currentSettings.alpha,
    color: currentSettings.color,
    show: currentSettings.show,
    fillColor: document.documentElement.style.getPropertyValue("--accent-fill") || undefined,
    glowColor: document.documentElement.style.getPropertyValue("--accent-glow") || undefined,
  });
  document.documentElement.style.setProperty("--hud-scale", String(currentSettings.scale || 1));
  body.classList.toggle("hud-compact", currentSettings.compact === true);
  body.classList.toggle("no-hud-anim", currentSettings.anim === false);
  renderMenuPreview();
}

function flashSavedBadge() {
  if (!menu.savedBadge) return;
  menu.savedBadge.classList.remove("hidden");
  if (savedBadgeTimer) clearTimeout(savedBadgeTimer);
  savedBadgeTimer = setTimeout(() => menu.savedBadge.classList.add("hidden"), 2200);
}

function highlightTabPanel(tab) {
  document.querySelectorAll(".hm-tab").forEach((t) => {
    t.classList.toggle("is-active", t.getAttribute("data-tab") === tab);
  });
  const map = { hud: null, colors: "colors", notif: "other", minimap: "layout", other: "export" };
  document.querySelectorAll(".hm-panel").forEach((p) => {
    const key = p.getAttribute("data-panel");
    p.classList.toggle("is-highlight", map[tab] === key);
  });
}

function getMenuState() {
  return {
    preset: Number(menu.preset.value || 1),
    style: menu.style.value,
    color: menu.color.value,
    alpha: Number(menu.alpha.value || 0.55),
    scale: Number(menu.scale ? menu.scale.value : 1) || 1,
    compact: menu.compact ? menu.compact.checked : false,
    anim: menu.anim ? menu.anim.checked !== false : true,
    show: {
      health: menu.health.checked,
      armor: menu.armor.checked,
      stamina: menu.stamina.checked,
      hunger: menu.hunger.checked,
      thirst: menu.thirst.checked,
      voice: menu.voice ? menu.voice.checked : true,
      speed: menu.speed.checked,
      fuel: menu.fuel.checked,
      seatbelt: menu.seatbelt.checked,
    },
  };
}

function fillMenuFromPreset(idx) {
  const p = menuPresets[idx] || currentSettings;
  if (!p) return;
  menu.preset.value = String(idx);
  menu.style.value = p.style || "dots";
  menu.color.value = p.color || "violet";
  menu.alpha.value = String(p.alpha || 0.55);
  if (menu.scale) menu.scale.value = String(p.scale != null ? p.scale : 1);
  if (menu.compact) menu.compact.checked = p.compact === true;
  if (menu.anim) menu.anim.checked = p.anim !== false;
  const show = p.show || {};
  menu.health.checked = show.health !== false;
  menu.armor.checked = show.armor === true;
  menu.stamina.checked = show.stamina === true;
  menu.hunger.checked = show.hunger !== false;
  menu.thirst.checked = show.thirst !== false;
  if (menu.voice) menu.voice.checked = show.voice !== false;
  menu.speed.checked = show.speed === true;
  menu.fuel.checked = show.fuel === true;
  menu.seatbelt.checked = show.seatbelt === true;
  renderMenuPreview();
}

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data) return;

  if (data.action === "theme") {
    applyThemeData(data);
    if (typeof data.preset === "number") {
      body.classList.remove("preset-1", "preset-2", "preset-3");
      body.classList.add(`preset-${data.preset}`);
    }
    syncRows();
    return;
  }

  if (data.action === "openMenu") {
    menuPresets = data.presets || {};
    const active = Number(data.activePreset || 1);
    fillMenuFromPreset(active);
    hudMenu.classList.remove("hidden");
    body.classList.add("hud-menu-open");
    highlightTabPanel("hud");
    applyMenuLive();
    return;
  }

  if (data.action === "closeMenu") {
    hudMenu.classList.add("hidden");
    body.classList.remove("hud-menu-open");
    return;
  }

  if (data.action === "vehicleList") {
    if (!vehicleListMenu) return;
    if (!data.open) {
      vehicleListMenu.classList.add("hidden");
      return;
    }
    vehicleListMenu.classList.remove("hidden");
    if (vlmHeader) vlmHeader.textContent = data.title || "—";
    if (vlmSub) vlmSub.textContent = data.subtitle || "";
    if (vlmRows) {
      vlmRows.innerHTML = "";
      (data.rows || []).forEach((row) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "vlm-row";
        btn.textContent = row.label || "";
        btn.addEventListener("click", () => {
          if (row.id === "close") {
            nuiPost("vehicleList:action", { action: "close" });
            return;
          }
          nuiPost("vehicleList:action", {
            action: row.id,
            doorIndex: row.doorIndex,
            label: row.label,
          });
        });
        vlmRows.appendChild(btn);
      });
    }
    return;
  }

  if (data.action === "vehiclePanel") {
    if (!vehiclePanel) return;
    if (!data.open) {
      vehiclePanel.classList.add("hidden");
      return;
    }
    vehiclePanel.classList.remove("hidden");
    if (vpClock && data.timeStr) vpClock.textContent = data.timeStr;
    if (vpWeather && data.weather) vpWeather.textContent = String(data.weather).toUpperCase();
    if (vpStreet) vpStreet.textContent = data.street || "—";
    if (vpWaypoint) {
      const m = data.waypointM;
      vpWaypoint.textContent = m != null && m !== "" ? `${m} m` : "—";
    }
    const fuelN = Math.max(0, Math.min(100, Number(data.fuel) || 0));
    if (vpFuelHFill) vpFuelHFill.style.width = `${fuelN}%`;
    if (vpFuelPct) vpFuelPct.textContent = `${Math.round(fuelN)}%`;
    const motorN = Math.max(0, Math.min(100, Number(data.motorPct) != null ? data.motorPct : 100));
    if (vpMotorHFill) vpMotorHFill.style.width = `${motorN}%`;
    if (vpMotorPct) vpMotorPct.textContent = `${Math.round(motorN)}%`;
    const bodyN = Math.max(0, Math.min(100, Number(data.bodyPct) != null ? data.bodyPct : 100));
    const vpBodyHFill = document.getElementById("vpBodyHFill");
    const vpBodyPct = document.getElementById("vpBodyPct");
    if (vpBodyHFill) vpBodyHFill.style.width = `${bodyN}%`;
    if (vpBodyPct) vpBodyPct.textContent = `${Math.round(bodyN)}%`;
    const vpMileage = document.getElementById("vpMileage");
    if (vpMileage) {
      const km = Number(data.mileageKm);
      vpMileage.textContent = Number.isFinite(km) ? `${Math.round(km)} km` : "—";
    }
    const vpVehicleClass = document.getElementById("vpVehicleClass");
    if (vpVehicleClass) vpVehicleClass.textContent = data.vehicleClassLabel || "—";
    if (vpVehicleName) vpVehicleName.textContent = data.vehicleName || "—";
    if (vpPlateLine) vpPlateLine.textContent = data.plate || "—";
    setVehicleSchemaImage();
    const vpLockStatus = document.getElementById("vpLockStatus");
    const vpEngineStatus = document.getElementById("vpEngineStatus");
    if (vpLockStatus) {
      vpLockStatus.textContent = data.locked ? "Užrakinta" : "Atrakinta";
      vpLockStatus.classList.toggle("is-on", !!data.locked);
    }
    if (vpEngineStatus) {
      vpEngineStatus.textContent = data.engineOn ? "Veikia" : "Išjungtas";
      vpEngineStatus.classList.toggle("is-on", !!data.engineOn);
    }
    if (data.hasKeys === false) {
      document.querySelectorAll(".vp-ios-q, .vp-ctrl, .vp-spot.vp-door").forEach((el) => {
        el.classList.add("vp-disabled");
        el.setAttribute("disabled", "disabled");
      });
    } else {
      document.querySelectorAll(".vp-ios-q, .vp-ctrl, .vp-spot.vp-door").forEach((el) => {
        el.classList.remove("vp-disabled");
        el.removeAttribute("disabled");
      });
    }
    if (vpHazardToggle) {
      vpHazardToggle.classList.toggle("on", !!data.hazard);
      vpHazardToggle.setAttribute("aria-pressed", data.hazard ? "true" : "false");
    }
    document.querySelectorAll(".vp-ios-q, .vp-ctrl").forEach((btn) => {
      const act = btn.getAttribute("data-act");
      btn.classList.remove("on");
      if (act === "lock" && data.locked) btn.classList.add("on");
      if (act === "lights" && data.headlightsOn) btn.classList.add("on");
      if (act === "interior" && data.interiorLight) btn.classList.add("on");
      if (act === "engine" && data.engineOn) btn.classList.add("on");
    });
    if (Array.isArray(data.doors)) {
      data.doors.forEach((d) => {
        const el = document.querySelector(`.vp-spot.vp-door[data-door="${d.idx}"]`);
        if (!el) return;
        el.classList.toggle("state-open", !!d.open);
      });
    }
    return;
  }

  if (data.action !== "update") return;

  if (data.settings) {
    currentSettings = {
      ...currentSettings,
      ...data.settings,
      show: { ...currentSettings.show, ...(data.settings.show || {}) },
    };
    syncRows();
    applyVisualStyle(currentSettings.style);
  }

  updateHudVisibility(data.show);

  const voiceOpts = { voiceTalking: !!data.voiceTalking };
  setBar("health", data.health);
  setBar("armor", data.armor);
  setBar("stamina", data.stamina);
  setBar("hunger", data.hunger);
  setBar("thirst", data.thirst);
  setBar("voice", data.voice, voiceOpts);

  const showCarHud = !!data.inVehicle && !!data.show;
  carHud.classList.toggle("hidden", !showCarHud);
  if (carhudClassic) carhudClassic.classList.add("hidden");

  const sp = Math.max(0, Math.min(999, Number(data.speed) || 0));
  const fuelN = Math.max(0, Math.min(100, Number(data.fuel) || 0));
  const eh = Number(data.engineHealth);
  const motorPctHud = Number.isFinite(eh) ? Math.max(0, Math.min(100, Math.round(eh / 10))) : 0;

  if (speedText) speedText.textContent = String(sp);
  if (fuelText) fuelText.textContent = `${Math.round(fuelN)}%`;
  if (seatbeltText) seatbeltText.textContent = data.seatbelt ? "Įj." : "Išj.";

  if (carSpeedDigits) {
    carSpeedDigits.textContent = String(sp);
  }
  if (carGear && data.gear) {
    carGear.textContent = String(data.gear);
  }
  const carFuelPctLbl = document.getElementById("carFuelPctLbl");
  const carMotorPctLbl = document.getElementById("carMotorPctLbl");
  if (carFuelPctLbl) carFuelPctLbl.textContent = `${Math.round(fuelN)}%`;
  if (carMotorPctLbl) carMotorPctLbl.textContent = `${motorPctHud}%`;
  if (carRpmArc) {
    const rpm = Math.max(0, Math.min(100, Number(data.rpm) || 0));
    carRpmArc.style.strokeDashoffset = String(CAR_RPM_ARC_LEN * (1 - rpm / 100));
  }
  if (carFuelArc) {
    carFuelArc.style.strokeDashoffset = String(CAR_FUEL_ARC_LEN * (1 - fuelN / 100));
  }

  const beltOn = !!data.seatbelt;
  setChStat(chStatBelt, beltOn ? "state-on" : "state-warn");
  setChStat(chStatHandbrake, data.handbrake ? "state-on" : "state-off");
  setChStat(chStatLock, data.doorsLocked ? "state-on" : "state-off");
  setChStat(chStatLights, data.lightsOn ? "state-on" : "state-off");
  const ind = Number(data.indicators) || 0;
  setChStat(chStatTurnL, ind === 1 || ind === 3 ? "state-blink" : "state-off");
  setChStat(chStatTurnR, ind === 2 || ind === 3 ? "state-blink" : "state-off");

  const statFuel = document.getElementById("carStatFuel");
  const statEngine = document.getElementById("carStatEngine");
  if (statFuel) statFuel.classList.toggle("state-warn", fuelN < 18);
  if (statEngine) statEngine.classList.toggle("state-warn", motorPctHud < 40);
});

function bindMenuInput(el, eventName, handler) {
  if (!el) return;
  el.addEventListener(eventName, handler);
}

[
  menu.style,
  menu.color,
  menu.alpha,
  menu.scale,
  menu.health,
  menu.armor,
  menu.stamina,
  menu.hunger,
  menu.thirst,
  menu.voice,
  menu.speed,
  menu.fuel,
  menu.seatbelt,
  menu.compact,
  menu.anim,
  menu.hudBg,
  menu.dynamic,
].forEach((el) => {
  bindMenuInput(el, "input", () => applyMenuLive());
  bindMenuInput(el, "change", () => applyMenuLive());
});

menu.preset.addEventListener("change", () => {
  fillMenuFromPreset(Number(menu.preset.value || 1));
  applyMenuLive();
});

if (menu.btnApplyPreset) {
  menu.btnApplyPreset.addEventListener("click", () => {
    nuiPost("hud:applyPreset", { preset: Number(menu.preset.value || 1) }).then(() => {
      const p = menuPresets[Number(menu.preset.value || 1)];
      if (p) fillMenuFromPreset(Number(menu.preset.value || 1));
      applyMenuLive();
    });
  });
}

if (menu.btnResetDefaults) {
  menu.btnResetDefaults.addEventListener("click", () => {
    const idx = Number(menu.preset.value || 1);
    menuPresets[idx] = { ...DEFAULT_MENU_STATE, preset: idx };
    fillMenuFromPreset(idx);
    applyMenuLive();
  });
}

menu.btnSavePreset.addEventListener("click", () => {
  const payload = getMenuState();
  menuPresets[payload.preset] = payload;
  applyMenuLive();
  nuiPost("hud:savePreset", payload).then(() => flashSavedBadge());
});

menu.btnCloseMenu.addEventListener("click", () => {
  nuiPost("hud:close", {});
});

if (menu.tabs) {
  menu.tabs.addEventListener("click", (e) => {
    const btn = e.target.closest(".hm-tab");
    if (!btn) return;
    highlightTabPanel(btn.getAttribute("data-tab") || "hud");
  });
}

if (menu.swatches) {
  menu.swatches.addEventListener("click", (e) => {
    const sw = e.target.closest(".hm-swatch");
    if (!sw || !menu.color) return;
    menu.color.value = sw.getAttribute("data-c") || "violet";
    applyMenuLive();
  });
}

if (menu.btnExport) {
  menu.btnExport.addEventListener("click", () => {
    const json = JSON.stringify(getMenuState(), null, 2);
    if (menu.importArea) {
      menu.importArea.classList.remove("hidden");
      menu.importArea.value = json;
      menu.importArea.focus();
      menu.importArea.select();
    }
  });
}

if (menu.btnImport) {
  menu.btnImport.addEventListener("click", () => {
    if (menu.importArea) menu.importArea.classList.toggle("hidden");
    if (!menu.importArea || menu.importArea.classList.contains("hidden")) return;
    try {
      const data = JSON.parse(menu.importArea.value || "{}");
      const idx = Number(menu.preset.value || 1);
      menuPresets[idx] = { ...DEFAULT_MENU_STATE, ...data, preset: idx };
      fillMenuFromPreset(idx);
      applyMenuLive();
      flashSavedBadge();
    } catch (err) {
      /* neteisingas JSON */
    }
  });
}

if (vpBtnClose) {
  vpBtnClose.addEventListener("click", () => {
    nuiPost("vehiclePanel:action", { action: "close" });
  });
}

document.querySelectorAll(".vp-ios-q, .vp-ctrl").forEach((btn) => {
  btn.addEventListener("click", () => {
    if (btn.classList.contains("vp-disabled")) return;
    const act = btn.getAttribute("data-act");
    if (!act || act === "hood" || act === "trunk" || act === "doorFlip") return;
    nuiPost("vehiclePanel:action", { action: act });
  });
});

document.querySelectorAll(".vp-spot.vp-door").forEach((btn) => {
  btn.addEventListener("click", () => {
    if (btn.classList.contains("vp-disabled")) return;
    const d = btn.getAttribute("data-door");
    if (d == null || d === "") return;
    nuiPost("vehiclePanel:action", { action: "door", doorIndex: Number(d) });
  });
});

if (vpHazardToggle) {
  vpHazardToggle.addEventListener("click", () => {
    nuiPost("vehiclePanel:action", { action: "hazard" });
  });
}

document.querySelector(".vlm-backdrop")?.addEventListener("click", () => {
  nuiPost("vehicleList:action", { action: "close" });
});

window.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  if (!hudMenu.classList.contains("hidden")) {
    e.preventDefault();
    nuiPost("hud:close", {});
    return;
  }
  if (vehiclePanel && !vehiclePanel.classList.contains("hidden")) {
    e.preventDefault();
    nuiPost("vehiclePanel:action", { action: "close" });
    return;
  }
  if (vehicleListMenu && !vehicleListMenu.classList.contains("hidden")) {
    e.preventDefault();
    nuiPost("vehicleList:action", { action: "close" });
  }
});

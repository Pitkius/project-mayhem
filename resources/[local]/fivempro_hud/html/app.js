const hudRoot = document.getElementById("hudRoot");
const hudBars = document.getElementById("hudBars");
const hudRings = document.getElementById("hudRings");
const hudTiles = document.getElementById("hudTiles");
const hudFrame = document.getElementById("hudFrame");
const hudBlCluster = document.getElementById("hudBlCluster");
const hudBrCluster = document.getElementById("hudBrCluster");
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
  preview: document.getElementById("hmPreview"),
  previewStage: document.getElementById("hmPvHudStage"),
  hudBg: document.getElementById("optHudBg"),
  dynamic: document.getElementById("optDynamic"),
  colPrimary: document.getElementById("hmColPrimary"),
  colSecondary: document.getElementById("hmColSecondary"),
  colAccent: document.getElementById("hmColAccent"),
  colText: document.getElementById("hmColText"),
  swatches: document.getElementById("hmSwatches"),
  tabs: document.getElementById("hmTabs"),
};


const THEME_PALETTE = {
  violet: { primary: "#a78bfa", secondary: "#5b21b6", accent: "#e879f9", text: "#f8fafc" },
  cyan: { primary: "#22d3ee", secondary: "#0e7490", accent: "#67e8f9", text: "#f0fdfa" },
  red: { primary: "#f87171", secondary: "#991b1b", accent: "#fb7185", text: "#fff1f2" },
  green: { primary: "#86efac", secondary: "#166534", accent: "#bbf7d0", text: "#f0fdf4" },
  amber: { primary: "#fbbf24", secondary: "#b45309", accent: "#fde68a", text: "#fffbeb" },
};

const COLOR_THEMES = {
  cyan: { fill: "#22d3ee", glow: "rgba(34,211,238,0.5)" },
  violet: { fill: "#a78bfa", glow: "rgba(167,139,250,0.5)" },
  red: { fill: "#f87171", glow: "rgba(248,113,113,0.5)" },
  green: { fill: "#4ade80", glow: "rgba(74,222,128,0.5)" },
  amber: { fill: "#fbbf24", glow: "rgba(251,191,36,0.5)" },
};

const TILE_COLORS = {
  violet: { health: "#f43f5e", armor: "#a78bfa", hunger: "#fb923c", thirst: "#38bdf8", stamina: "#e879f9", voice: "#c4b5fd" },
  cyan: { health: "#fb7185", armor: "#22d3ee", hunger: "#fdba74", thirst: "#67e8f9", stamina: "#a5f3fc", voice: "#a5f3fc" },
  red: { health: "#fca5a5", armor: "#c084fc", hunger: "#fdba74", thirst: "#7dd3fc", stamina: "#f9a8d4", voice: "#e9d5ff" },
  green: { health: "#f87171", armor: "#86efac", hunger: "#fcd34d", thirst: "#6ee7b7", stamina: "#bbf7d0", voice: "#d9f99d" },
  amber: { health: "#ef4444", armor: "#d8b4fe", hunger: "#fbbf24", thirst: "#38bdf8", stamina: "#fbcfe8", voice: "#fde68a" },
};

const PREVIEW_HUD_SCALE = 0.72;

let previewClustersHome = null;
let previewClustersMounted = false;

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
  if (body.classList.contains("hud-menu-open")) {
    const show = getMenuShowSettings();
    if (hudRoot) hudRoot.style.display = MAIN_STATS.some((k) => show[k]) ? "flex" : "none";
    return;
  }
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

function rememberPreviewClustersHome() {
  if (previewClustersHome || !hudBlCluster || !hudBlCluster.parentNode) return;
  previewClustersHome = {
    parent: hudBlCluster.parentNode,
    before: hudBlCluster,
  };
}

function mountPreviewClusters() {
  if (previewClustersMounted || !menu.previewStage || !hudBlCluster || !hudBrCluster) return;
  rememberPreviewClustersHome();
  menu.previewStage.appendChild(hudBlCluster);
  menu.previewStage.appendChild(hudBrCluster);
  if (menu.preview) menu.preview.classList.add("hm-pv-live");
  previewClustersMounted = true;
}

function unmountPreviewClusters() {
  if (!previewClustersMounted || !previewClustersHome) return;
  const { parent, before } = previewClustersHome;
  if (before && before.parentNode === parent) {
    parent.insertBefore(hudBlCluster, before);
    parent.insertBefore(hudBrCluster, before);
  } else {
    parent.appendChild(hudBlCluster);
    parent.appendChild(hudBrCluster);
  }
  if (menu.preview) menu.preview.classList.remove("hm-pv-live");
  previewClustersMounted = false;
}

function getMenuShowSettings() {
  return getMenuState().show || currentSettings.show || {};
}

function syncPreviewVisibility(state) {
  if (!body.classList.contains("hud-menu-open")) return;
  const show = state?.show || getMenuShowSettings();
  MAIN_STATS.forEach((k) => {
    const on = show[k] === true;
    if (rows[k]) rows[k].classList.toggle("hidden", !on);
    if (ringWraps[k]) ringWraps[k].classList.toggle("hidden", !on);
    if (tileWraps[k]) tileWraps[k].classList.toggle("hidden", !on);
    if (hfWraps[k]) hfWraps[k].classList.toggle("hidden", !on);
  });
  if (hudRoot) {
    hudRoot.style.display = MAIN_STATS.some((k) => show[k]) ? "flex" : "none";
  }
}

function updateThemeColorPicks(colorKey) {
  const pal = THEME_PALETTE[colorKey] || THEME_PALETTE.violet;
  if (menu.colPrimary) menu.colPrimary.style.background = pal.primary;
  if (menu.colSecondary) menu.colSecondary.style.background = pal.secondary;
  if (menu.colAccent) menu.colAccent.style.background = pal.accent;
  if (menu.colText) menu.colText.style.background = pal.text;
}

function normalizePresets(raw) {
  if (!raw || typeof raw !== "object") return {};
  if (Array.isArray(raw)) {
    const out = {};
    raw.forEach((p, i) => {
      if (p) out[i + 1] = p;
    });
    return out;
  }
  return raw;
}

function getPreset(idx) {
  const n = Number(idx) || 1;
  if (!menuPresets || typeof menuPresets !== "object") return null;
  return menuPresets[n] || menuPresets[String(n)] || (Array.isArray(menuPresets) ? menuPresets[n - 1] : null);
}

function buildThemePayload(state) {
  const colorKey = state.color || "violet";
  const colors = COLOR_THEMES[colorKey] || COLOR_THEMES.violet;
  const tiles = TILE_COLORS[colorKey] || TILE_COLORS.violet;
  return {
    style: state.style,
    alpha: state.alpha,
    color: colorKey,
    scale: state.scale,
    compact: state.compact,
    anim: state.anim,
    show: state.show,
    fillColor: colors.fill,
    glowColor: colors.glow,
    tileColors: tiles,
  };
}

function renderMenuPreview() {
  const state = getMenuState();
  updateThemeColorPicks(state.color);
  if (menu.preview) {
    const liveView = menu.hudBg ? menu.hudBg.checked !== false : true;
    menu.preview.classList.toggle("hm-pv-live-view", liveView);
    menu.preview.classList.toggle("hm-pv-static-bg", !liveView);
    menu.preview.style.setProperty("--panel-alpha", String(state.alpha || 0.55));
    menu.preview.style.setProperty("--pv-hud-scale", String(state.scale || 1));
    menu.preview.style.setProperty("--pv-hud-base-scale", String(PREVIEW_HUD_SCALE));
  }
  syncPreviewVisibility(state);
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
  applyThemeData(buildThemePayload(currentSettings));
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
  const p = getPreset(idx) || currentSettings;
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

const HUD_MENU_CLOSE_MS = 380;

function openHudMenuUi() {
  hudMenu.classList.remove("hidden", "is-closing");
  void hudMenu.offsetWidth;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      hudMenu.classList.add("is-open");
    });
  });
}

function closeHudMenuUi() {
  hudMenu.classList.remove("is-open");
  hudMenu.classList.add("is-closing");
  window.setTimeout(() => {
    unmountPreviewClusters();
    hudMenu.classList.add("hidden");
    hudMenu.classList.remove("is-closing");
    body.classList.remove("hud-menu-open");
  }, HUD_MENU_CLOSE_MS);
}

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data) return;

  if (data.action === "theme") {
    if (typeof data.preset === "number") {
      body.classList.remove("preset-1", "preset-2", "preset-3");
      body.classList.add(`preset-${data.preset}`);
    }
    if (!body.classList.contains("hud-menu-open")) {
      applyThemeData(data);
      syncRows();
    }
    return;
  }

  if (data.action === "openMenu") {
    menuPresets = normalizePresets(data.presets || {});
    const active = Number(data.activePreset || 1);
    fillMenuFromPreset(active);
    openHudMenuUi();
    body.classList.add("hud-menu-open");
    mountPreviewClusters();
    highlightTabPanel("hud");
    applyMenuLive();
    return;
  }

  if (data.action === "closeMenu") {
    closeHudMenuUi();
    return;
  }

  if (data.action === "inventoryFocus") {
    body.classList.toggle("inventory-open", data.active === true);
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

  if (data.settings && !body.classList.contains("hud-menu-open")) {
    currentSettings = {
      ...currentSettings,
      ...data.settings,
      show: { ...currentSettings.show, ...(data.settings.show || {}) },
    };
    syncRows();
    applyVisualStyle(currentSettings.style);
  }

  updateHudVisibility(data.show);

  const menuShow = body.classList.contains("hud-menu-open") ? getMenuShowSettings() : null;
  const effectiveShow = menuShow || currentSettings.show || {};

  const voiceOpts = { voiceTalking: !!data.voiceTalking };
  setBar("health", data.health);
  setBar("armor", data.armor);
  setBar("stamina", data.stamina);
  setBar("hunger", data.hunger);
  setBar("thirst", data.thirst);
  setBar("voice", data.voice, voiceOpts);

  if (body.classList.contains("hud-menu-open")) {
    syncPreviewVisibility({ show: effectiveShow });
  }

  const wantsCarHud = !!(effectiveShow.speed || effectiveShow.fuel || effectiveShow.seatbelt);
  const showCarHud = !!data.inVehicle && !!data.show && wantsCarHud;
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
  const idx = Number(menu.preset.value || 1);
  fillMenuFromPreset(idx);
  applyMenuLive();
  nuiPost("hud:applyPreset", { preset: idx, silent: true });
});

if (menu.btnApplyPreset) {
  menu.btnApplyPreset.addEventListener("click", () => {
    const idx = Number(menu.preset.value || 1);
    nuiPost("hud:applyPreset", { preset: idx }).then(() => {
      fillMenuFromPreset(idx);
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

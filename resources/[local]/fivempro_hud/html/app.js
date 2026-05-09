const hudRoot = document.getElementById("hudRoot");
const hudBars = document.getElementById("hudBars");
const hudRings = document.getElementById("hudRings");
const rows = {
  health: document.getElementById("row-health"),
  armor: document.getElementById("row-armor"),
  stamina: document.getElementById("row-stamina"),
  hunger: document.getElementById("row-hunger"),
  thirst: document.getElementById("row-thirst"),
};
const ringWraps = {
  health: document.getElementById("ring-wrap-health"),
  armor: document.getElementById("ring-wrap-armor"),
  stamina: document.getElementById("ring-wrap-stamina"),
  hunger: document.getElementById("ring-wrap-hunger"),
  thirst: document.getElementById("ring-wrap-thirst"),
};
const ringTexts = {
  health: document.getElementById("ring-pct-health"),
  armor: document.getElementById("ring-pct-armor"),
  stamina: document.getElementById("ring-pct-stamina"),
  hunger: document.getElementById("ring-pct-hunger"),
  thirst: document.getElementById("ring-pct-thirst"),
};
const carHud = document.getElementById("carhud");
const speedText = document.getElementById("speed");
const fuelText = document.getElementById("fuel");
const seatbeltText = document.getElementById("seatbelt");
const body = document.body;
const hudMenu = document.getElementById("hudMenu");

const MAIN_STATS = ["health", "armor", "stamina", "hunger", "thirst"];
const RING_R = 15;
const RING_LEN = 2 * Math.PI * RING_R;

const menu = {
  preset: document.getElementById("menuPreset"),
  style: document.getElementById("menuStyle"),
  color: document.getElementById("menuColor"),
  alpha: document.getElementById("menuAlpha"),
  health: document.getElementById("optHealth"),
  armor: document.getElementById("optArmor"),
  stamina: document.getElementById("optStamina"),
  hunger: document.getElementById("optHunger"),
  thirst: document.getElementById("optThirst"),
  speed: document.getElementById("optSpeed"),
  fuel: document.getElementById("optFuel"),
  seatbelt: document.getElementById("optSeatbelt"),
  btnApplyPreset: document.getElementById("btnApplyPreset"),
  btnSavePreset: document.getElementById("btnSavePreset"),
  btnCloseMenu: document.getElementById("btnCloseMenu"),
};

const bars = {
  health: document.getElementById("health"),
  armor: document.getElementById("armor"),
  stamina: document.getElementById("stamina"),
  hunger: document.getElementById("hunger"),
  thirst: document.getElementById("thirst"),
};

const ringProgress = {};
MAIN_STATS.forEach((k) => {
  ringProgress[k] = document.getElementById(`ring-progress-${k}`);
});

(function initRings() {
  MAIN_STATS.forEach((k) => {
    const el = ringProgress[k];
    if (!el) return;
    el.style.strokeDasharray = String(RING_LEN);
    el.style.strokeDashoffset = String(RING_LEN);
  });
})();

let currentSettings = {
  style: "dots",
  color: "violet",
  alpha: 0.55,
  show: {
    health: true,
    armor: false,
    stamina: false,
    hunger: true,
    thirst: true,
    speed: false,
    fuel: false,
    seatbelt: false,
  },
};
let menuPresets = {};

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

function setBar(name, value) {
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
}

function applyVisualStyle(style) {
  const normalized = style || "dots";
  body.classList.remove("shape-line", "shape-square", "shape-dots");
  body.classList.add(`shape-${normalized}`);

  const isRings = normalized === "dots";
  hudBars.classList.toggle("hidden", isRings);
  hudRings.classList.toggle("hidden", !isRings);
}

function syncRows() {
  const s = currentSettings.show || {};
  MAIN_STATS.forEach((k) => {
    const on = s[k] === true;
    if (rows[k]) rows[k].classList.toggle("hidden", !on);
    if (ringWraps[k]) ringWraps[k].classList.toggle("hidden", !on);
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
  if (data.fillColor) {
    document.documentElement.style.setProperty("--accent-fill", data.fillColor);
  }
  if (data.glowColor) {
    document.documentElement.style.setProperty("--accent-glow", data.glowColor);
  }
  document.documentElement.style.setProperty("--panel-alpha", String(currentSettings.alpha || 0.55));
  applyVisualStyle(currentSettings.style);
}

function getMenuState() {
  return {
    preset: Number(menu.preset.value || 1),
    style: menu.style.value,
    color: menu.color.value,
    alpha: Number(menu.alpha.value || 0.55),
    show: {
      health: menu.health.checked,
      armor: menu.armor.checked,
      stamina: menu.stamina.checked,
      hunger: menu.hunger.checked,
      thirst: menu.thirst.checked,
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
  const show = p.show || {};
  menu.health.checked = show.health !== false;
  menu.armor.checked = show.armor === true;
  menu.stamina.checked = show.stamina === true;
  menu.hunger.checked = show.hunger !== false;
  menu.thirst.checked = show.thirst !== false;
  menu.speed.checked = show.speed === true;
  menu.fuel.checked = show.fuel === true;
  menu.seatbelt.checked = show.seatbelt === true;
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
    return;
  }

  if (data.action === "closeMenu") {
    hudMenu.classList.add("hidden");
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

  setBar("health", data.health);
  setBar("armor", data.armor);
  setBar("stamina", data.stamina);
  setBar("hunger", data.hunger);
  setBar("thirst", data.thirst);

  const showCarHud =
    !!data.inVehicle &&
    !!data.show &&
    (currentSettings.show.speed || currentSettings.show.fuel || currentSettings.show.seatbelt);
  carHud.classList.toggle("hidden", !showCarHud);
  speedText.parentElement.classList.toggle("hidden", !currentSettings.show.speed);
  fuelText.parentElement.classList.toggle("hidden", !currentSettings.show.fuel);
  seatbeltText.parentElement.classList.toggle("hidden", !currentSettings.show.seatbelt);
  speedText.textContent = `${data.speed ?? 0}`;
  fuelText.textContent = `${data.fuel ?? 0}%`;
  seatbeltText.textContent = data.seatbelt ? "ON" : "OFF";
});

menu.preset.addEventListener("change", () => {
  fillMenuFromPreset(Number(menu.preset.value || 1));
});

menu.btnApplyPreset.addEventListener("click", () => {
  nuiPost("hud:applyPreset", { preset: Number(menu.preset.value || 1) }).then(() => {
    const p = menuPresets[Number(menu.preset.value || 1)];
    if (p) {
      currentSettings = { ...currentSettings, ...p, show: { ...currentSettings.show, ...(p.show || {}) } };
      syncRows();
      applyVisualStyle(currentSettings.style);
    }
  });
});

menu.btnSavePreset.addEventListener("click", () => {
  const payload = getMenuState();
  menuPresets[payload.preset] = payload;
  currentSettings = { ...currentSettings, ...payload, show: { ...currentSettings.show, ...payload.show } };
  syncRows();
  applyVisualStyle(currentSettings.style);
  nuiPost("hud:savePreset", payload);
});

menu.btnCloseMenu.addEventListener("click", () => {
  nuiPost("hud:close", {});
});

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !hudMenu.classList.contains("hidden")) {
    e.preventDefault();
    nuiPost("hud:close", {});
  }
});

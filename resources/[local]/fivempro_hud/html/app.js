const hudRoot = document.getElementById("hudRoot");
const hudBars = document.getElementById("hudBars");
const hudRings = document.getElementById("hudRings");
const hudTiles = document.getElementById("hudTiles");
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

const tileWraps = {
  health: document.getElementById("tile-wrap-health"),
  armor: document.getElementById("tile-wrap-armor"),
  stamina: document.getElementById("tile-wrap-stamina"),
  hunger: document.getElementById("tile-wrap-hunger"),
  thirst: document.getElementById("tile-wrap-thirst"),
};
const tileFills = {};
const tileTexts = {};
MAIN_STATS.forEach((k) => {
  tileFills[k] = document.getElementById(`tile-fill-${k}`);
  tileTexts[k] = document.getElementById(`tile-pct-${k}`);
});

const carSpeedDigits = document.getElementById("carSpeedDigits");
const carRpmArc = document.getElementById("carRpmArc");
const carFuelTrack = document.getElementById("carFuelTrack");
const carFuelFill = document.getElementById("carFuelFill");
const carIconBelt = document.getElementById("carIconBelt");
const carhudClassic = document.getElementById("carhudClassic");
const vehiclePanel = document.getElementById("vehiclePanel");
const vpClock = document.getElementById("vpClock");
const vpWeather = document.getElementById("vpWeather");
const vpStreet = document.getElementById("vpStreet");
const vpWaypoint = document.getElementById("vpWaypoint");
const vpEngineTemp = document.getElementById("vpEngineTemp");
const vpFuelFill = document.getElementById("vpFuelFill");
const vpHazardToggle = document.getElementById("vpHazardToggle");
const vpBtnClose = document.getElementById("vpBtnClose");

const CAR_RPM_ARC_LEN = 245;

(function initRings() {
  MAIN_STATS.forEach((k) => {
    const el = ringProgress[k];
    if (!el) return;
    el.style.strokeDasharray = String(RING_LEN);
    el.style.strokeDashoffset = String(RING_LEN);
  });
})();

(function initCarRpm() {
  if (!carRpmArc) return;
  carRpmArc.style.strokeDasharray = `${CAR_RPM_ARC_LEN} 400`;
  carRpmArc.style.strokeDashoffset = String(CAR_RPM_ARC_LEN);
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
  const tf = tileFills[name];
  if (tf) tf.style.height = `${clamped}%`;
  const tt = tileTexts[name];
  if (tt) tt.textContent = String(Math.round(clamped));
}

function applyVisualStyle(style) {
  const allowed = ["line", "square", "dots", "tiles"];
  const normalized = allowed.includes(style) ? style : "dots";
  body.classList.remove("shape-line", "shape-square", "shape-dots", "shape-tiles");
  body.classList.add(`shape-${normalized}`);

  const isRings = normalized === "dots";
  const isTiles = normalized === "tiles";
  const useBars = normalized === "line" || normalized === "square";
  hudBars.classList.toggle("hidden", !useBars);
  hudRings.classList.toggle("hidden", !isRings);
  if (hudTiles) hudTiles.classList.toggle("hidden", !isTiles);
}

function syncRows() {
  const s = currentSettings.show || {};
  MAIN_STATS.forEach((k) => {
    const on = s[k] === true;
    if (rows[k]) rows[k].classList.toggle("hidden", !on);
    if (ringWraps[k]) ringWraps[k].classList.toggle("hidden", !on);
    if (tileWraps[k]) tileWraps[k].classList.toggle("hidden", !on);
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
  if (data.tileColors && typeof data.tileColors === "object") {
    const tc = data.tileColors;
    if (tc.health) document.documentElement.style.setProperty("--tile-health", tc.health);
    if (tc.armor) document.documentElement.style.setProperty("--tile-armor", tc.armor);
    if (tc.hunger) document.documentElement.style.setProperty("--tile-hunger", tc.hunger);
    if (tc.thirst) document.documentElement.style.setProperty("--tile-thirst", tc.thirst);
    if (tc.stamina) document.documentElement.style.setProperty("--tile-stamina", tc.stamina);
  }
  if (data.vehicleUiAccent) {
    document.documentElement.style.setProperty("--vehicle-accent", data.vehicleUiAccent);
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

  if (data.action === "vehiclePanel") {
    if (!vehiclePanel) return;
    if (!data.open) {
      vehiclePanel.classList.add("hidden");
      return;
    }
    vehiclePanel.classList.remove("hidden");
    if (vpClock && data.timeStr) vpClock.textContent = data.timeStr;
    if (vpWeather && data.weather) vpWeather.textContent = `ORAS ${data.weather}`;
    if (vpStreet) vpStreet.textContent = data.street || "—";
    if (vpWaypoint) {
      const m = data.waypointM;
      vpWaypoint.textContent = m != null && m !== "" ? `${m} m` : "—";
    }
    if (vpEngineTemp) vpEngineTemp.textContent = data.engineTemp != null ? `${data.engineTemp}°` : "—";
    if (vpFuelFill) vpFuelFill.style.height = `${Math.max(0, Math.min(100, Number(data.fuel) || 0))}%`;
    if (vpHazardToggle) {
      vpHazardToggle.classList.toggle("on", !!data.hazard);
      vpHazardToggle.setAttribute("aria-pressed", data.hazard ? "true" : "false");
    }
    document.querySelectorAll(".vp-act").forEach((btn) => {
      const act = btn.getAttribute("data-act");
      btn.classList.remove("vp-act-on");
      if (act === "engine" && data.engineOn) btn.classList.add("vp-act-on");
      if (act === "lights" && data.headlightsOn) btn.classList.add("vp-act-on");
      if (act === "interior" && data.interiorLight) btn.classList.add("vp-act-on");
      if (act === "lock" && data.locked) btn.classList.add("vp-act-on");
    });
    if (Array.isArray(data.doors)) {
      data.doors.forEach((d) => {
        const el = document.querySelector(`.vp-door[data-door="${d.idx}"]`);
        if (!el) return;
        el.classList.toggle("state-open", !!d.open);
        el.classList.toggle("state-unlocked", !data.locked);
        el.textContent = d.open ? "▢" : data.locked ? "●" : "○";
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
  if (carhudClassic) carhudClassic.classList.add("hidden");
  if (speedText && speedText.parentElement) {
    speedText.parentElement.classList.toggle("hidden", !currentSettings.show.speed);
  }
  if (fuelText && fuelText.parentElement) {
    fuelText.parentElement.classList.toggle("hidden", !currentSettings.show.fuel);
  }
  if (seatbeltText && seatbeltText.parentElement) {
    seatbeltText.parentElement.classList.toggle("hidden", !currentSettings.show.seatbelt);
  }
  if (speedText) speedText.textContent = `${data.speed ?? 0}`;
  if (fuelText) fuelText.textContent = `${data.fuel ?? 0}%`;
  if (seatbeltText) seatbeltText.textContent = data.seatbelt ? "ON" : "OFF";

  if (carSpeedDigits) {
    const sp = Math.max(0, Math.min(999, Number(data.speed) || 0));
    carSpeedDigits.textContent = String(sp).padStart(3, "0");
  }
  if (carRpmArc) {
    const rpm = Math.max(0, Math.min(100, Number(data.rpm) || 0));
    carRpmArc.style.strokeDashoffset = String(CAR_RPM_ARC_LEN * (1 - rpm / 100));
  }
  if (carFuelTrack) carFuelTrack.classList.toggle("hidden", !currentSettings.show.fuel);
  if (carFuelFill) {
    const fl = Math.max(0, Math.min(100, Number(data.fuel) || 0));
    carFuelFill.style.height = `${fl}%`;
  }
  if (carIconBelt) {
    carIconBelt.classList.toggle("belt-off", !data.seatbelt);
    carIconBelt.classList.toggle("hidden", !currentSettings.show.seatbelt);
  }
  const engIco = document.getElementById("carIconEngine");
  if (engIco) engIco.classList.toggle("hidden", !showCarHud);
  const carGaugeWrap = document.querySelector(".car-gauge-wrap");
  if (carGaugeWrap) carGaugeWrap.classList.toggle("hidden", !currentSettings.show.speed);
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

if (vpBtnClose) {
  vpBtnClose.addEventListener("click", () => {
    nuiPost("vehiclePanel:action", { action: "close" });
  });
}

document.querySelectorAll(".vp-act").forEach((btn) => {
  btn.addEventListener("click", () => {
    const act = btn.getAttribute("data-act");
    if (act) nuiPost("vehiclePanel:action", { action: act });
  });
});

document.querySelectorAll(".vp-door").forEach((btn) => {
  btn.addEventListener("click", () => {
    const d = btn.getAttribute("data-door");
    nuiPost("vehiclePanel:action", { action: "door", doorIndex: Number(d) });
  });
});

if (vpHazardToggle) {
  vpHazardToggle.addEventListener("click", () => {
    nuiPost("vehiclePanel:action", { action: "hazard" });
  });
}

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
  }
});

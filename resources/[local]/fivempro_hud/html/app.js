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
const carFuelArc = document.getElementById("carFuelArc");
const carMotorFill = document.getElementById("carMotorFill");
const carMotorPct = document.getElementById("carMotorPct");
const carMvMotor = document.getElementById("carMvMotor");
const carFuelMiniFill = document.getElementById("carFuelMiniFill");
const carFuelMiniPct = document.getElementById("carFuelMiniPct");
const carMvFuelMini = document.getElementById("carMvFuelMini");
const carIcoEngine = document.getElementById("carIcoEngine");
const carIcoDoors = document.getElementById("carIcoDoors");
const carIcoLights = document.getElementById("carIcoLights");
const carIcoBelt = document.getElementById("carIcoBelt");
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

function setVehiclePreviewImage(modelSpawn) {
  if (!vpVehicleImage) return;
  const safe = String(modelSpawn || "default")
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "");
  const name = safe || "default";
  const fallbacks = [
    `assets/vehicles/${name}.png`,
    "assets/vehicles/default.png",
    "assets/vehicles/default.svg",
  ];
  let step = 0;
  vpVehicleImage.onerror = () => {
    step += 1;
    if (step < fallbacks.length) {
      vpVehicleImage.src = fallbacks[step];
      return;
    }
    vpVehicleImage.onerror = null;
  };
  vpVehicleImage.src = fallbacks[0];
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
  style: "tiles",
  color: "violet",
  alpha: 0.55,
  show: {
    health: true,
    armor: true,
    stamina: true,
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
    if (vpFuelPct) vpFuelPct.textContent = String(Math.round(fuelN));
    const motorN = Math.max(0, Math.min(100, Number(data.motorPct) != null ? data.motorPct : 100));
    if (vpMotorHFill) vpMotorHFill.style.width = `${motorN}%`;
    if (vpMotorPct) vpMotorPct.textContent = String(Math.round(motorN));
    if (vpVehicleName) vpVehicleName.textContent = data.vehicleName || "—";
    if (vpPlateLine) vpPlateLine.textContent = data.plate || "—";
    setVehiclePreviewImage(data.modelSpawn);
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
      document.querySelectorAll(".vp-ios-q, .vp-ios-power, .vp-door, .vp-win").forEach((el) => {
        el.classList.add("vp-disabled");
        el.setAttribute("disabled", "disabled");
      });
    } else {
      document.querySelectorAll(".vp-ios-q, .vp-ios-power, .vp-door, .vp-win").forEach((el) => {
        el.classList.remove("vp-disabled");
        el.removeAttribute("disabled");
      });
    }
    if (vpHazardToggle) {
      vpHazardToggle.classList.toggle("on", !!data.hazard);
      vpHazardToggle.setAttribute("aria-pressed", data.hazard ? "true" : "false");
    }
    document.querySelectorAll(".vp-ios-q").forEach((btn) => {
      const act = btn.getAttribute("data-act");
      btn.classList.remove("on");
      if (act === "lock" && data.locked) btn.classList.add("on");
      if (act === "lights" && data.headlightsOn) btn.classList.add("on");
      if (act === "interior" && data.interiorLight) btn.classList.add("on");
    });
    document.querySelectorAll(".vp-ios-power").forEach((btn) => {
      btn.classList.toggle("on", !!data.engineOn);
    });
    if (Array.isArray(data.doors)) {
      data.doors.forEach((d) => {
        const el = document.querySelector(`.vp-door[data-door="${d.idx}"]`);
        if (!el) return;
        el.classList.toggle("state-open", !!d.open);
        el.classList.toggle("state-unlocked", !data.locked);
        const labels = ["Vair.", "Keleiv.", "G. kairė", "G. dešinė", "Kapotas", "Bagažinė"];
        let lab = labels[d.idx] || "Durys";
        el.textContent = d.open ? `${lab} ●` : lab;
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

  const showCarHud = !!data.inVehicle && !!data.show;
  carHud.classList.toggle("hidden", !showCarHud);
  if (carhudClassic) carhudClassic.classList.add("hidden");

  const sp = Math.max(0, Math.min(999, Number(data.speed) || 0));
  const fuelN = Math.max(0, Math.min(100, Number(data.fuel) || 0));
  const eh = Number(data.engineHealth);
  const motorPctHud = Number.isFinite(eh) ? Math.max(0, Math.min(100, Math.round(eh / 10))) : 0;

  if (speedText) speedText.textContent = String(sp);
  if (fuelText) fuelText.textContent = `${Math.round(fuelN)}%`;
  if (seatbeltText) seatbeltText.textContent = data.seatbelt ? "ON" : "OFF";

  if (carSpeedDigits) {
    carSpeedDigits.textContent = String(sp);
  }
  const carFuelPctLbl = document.getElementById("carFuelPctLbl");
  const carMotorPctLbl = document.getElementById("carMotorPctLbl");
  if (carFuelPctLbl) carFuelPctLbl.textContent = `${Math.round(fuelN)}%`;
  if (carMotorPctLbl) carMotorPctLbl.textContent = `${motorPctHud}%`;
  if (carMotorPct) carMotorPct.textContent = String(motorPctHud);
  if (carFuelMiniPct) carFuelMiniPct.textContent = String(Math.round(fuelN));
  if (carRpmArc) {
    const rpm = Math.max(0, Math.min(100, Number(data.rpm) || 0));
    carRpmArc.style.strokeDashoffset = String(CAR_RPM_ARC_LEN * (1 - rpm / 100));
  }
  if (carFuelArc) {
    carFuelArc.style.strokeDashoffset = String(CAR_FUEL_ARC_LEN * (1 - fuelN / 100));
  }
  if (carMotorFill) carMotorFill.style.height = `${motorPctHud}%`;
  if (carMvMotor) {
    carMvMotor.classList.toggle("state-warn", motorPctHud < 40);
  }

  if (carFuelMiniFill) carFuelMiniFill.style.height = `${fuelN}%`;
  if (carMvFuelMini) {
    carMvFuelMini.classList.toggle("state-warn", fuelN < 18);
  }

  const statFuel = document.getElementById("carStatFuel");
  const statEngine = document.getElementById("carStatEngine");
  if (statFuel) statFuel.classList.toggle("state-warn", fuelN < 18);
  if (statEngine) statEngine.classList.toggle("state-warn", motorPctHud < 40);

  const engineEl = carIcoEngine || document.getElementById("carIcoEngine");
  const doorsEl = carIcoDoors || document.getElementById("carIcoDoors");
  const lightsEl = carIcoLights || document.getElementById("carIcoLights");
  const beltEl = carIcoBelt || document.getElementById("carIcoBelt");

  if (engineEl) {
    engineEl.classList.toggle("state-on", !!data.engineOn);
    engineEl.classList.toggle("state-off", !data.engineOn);
    engineEl.classList.toggle("state-warn", motorPctHud < 40);
  }
  if (doorsEl) {
    doorsEl.classList.toggle("state-on", !!data.doorsLocked);
    doorsEl.classList.toggle("state-off", !data.doorsLocked);
  }
  if (lightsEl) {
    lightsEl.classList.toggle("state-on", !!data.lightsOn);
    lightsEl.classList.toggle("state-off", !data.lightsOn);
  }
  if (beltEl) {
    beltEl.classList.toggle("state-on", !!data.seatbelt);
    beltEl.classList.toggle("state-off", !data.seatbelt);
    beltEl.classList.toggle("state-warn", !data.seatbelt);
  }
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

document.querySelectorAll(".vp-ios-q, .vp-ios-power").forEach((btn) => {
  btn.addEventListener("click", () => {
    const act = btn.getAttribute("data-act");
    if (!act) return;
    if (act === "doorFlip") {
      nuiPost("vehiclePanel:action", { action: "door", doorIndex: 0 });
      return;
    }
    nuiPost("vehiclePanel:action", { action: act });
  });
});

document.querySelectorAll(".vp-door").forEach((btn) => {
  btn.addEventListener("click", () => {
    const d = btn.getAttribute("data-door");
    nuiPost("vehiclePanel:action", { action: "door", doorIndex: Number(d) });
  });
});

document.querySelectorAll(".vp-win").forEach((btn) => {
  btn.addEventListener("click", () => {
    const w = btn.getAttribute("data-window");
    nuiPost("vehiclePanel:action", { action: "window", windowIndex: Number(w) });
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

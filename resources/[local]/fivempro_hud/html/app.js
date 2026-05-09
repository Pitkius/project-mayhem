const hud = document.getElementById("hud");
const rows = {
  health: document.getElementById("row-health"),
  armor: document.getElementById("row-armor"),
  stamina: document.getElementById("row-stamina"),
  hunger: document.getElementById("row-hunger"),
  thirst: document.getElementById("row-thirst"),
};
const carHud = document.getElementById("carhud");
const speedText = document.getElementById("speed");
const fuelText = document.getElementById("fuel");
const seatbeltText = document.getElementById("seatbelt");
const body = document.body;
const hudMenu = document.getElementById("hudMenu");

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

let currentSettings = {
  style: "square",
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

function setBar(name, value) {
  const clamped = Math.max(0, Math.min(100, Number(value) || 0));
  bars[name].style.width = `${clamped}%`;
}

function applyVisualStyle(style) {
  body.classList.remove("shape-line", "shape-square", "shape-dots");
  body.classList.add(`shape-${style || "square"}`);
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

function syncRows() {
  rows.health.classList.toggle("hidden", !currentSettings.show.health);
  rows.armor.classList.toggle("hidden", !currentSettings.show.armor);
  rows.stamina.classList.toggle("hidden", !currentSettings.show.stamina);
  rows.hunger.classList.toggle("hidden", !currentSettings.show.hunger);
  rows.thirst.classList.toggle("hidden", !currentSettings.show.thirst);
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
  menu.style.value = p.style || "square";
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
    currentSettings = { ...currentSettings, ...data.settings, show: { ...currentSettings.show, ...(data.settings.show || {}) } };
    syncRows();
  }
  hud.style.display = data.show ? "flex" : "none";

  setBar("health", data.health);
  setBar("armor", data.armor);
  setBar("stamina", data.stamina);
  setBar("hunger", data.hunger);
  setBar("thirst", data.thirst);

  const showCarHud = !!data.inVehicle && !!data.show && (currentSettings.show.speed || currentSettings.show.fuel || currentSettings.show.seatbelt);
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
    }
  });
});

menu.btnSavePreset.addEventListener("click", () => {
  const payload = getMenuState();
  menuPresets[payload.preset] = payload;
  currentSettings = { ...currentSettings, ...payload, show: { ...currentSettings.show, ...payload.show } };
  syncRows();
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

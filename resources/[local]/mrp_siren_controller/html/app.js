const root = document.getElementById("scRoot");
const panel = document.getElementById("scPanel");
const vehicleName = document.getElementById("scVehicleName");
const codeStatus = document.getElementById("scCodeStatus");
const toneStatus = document.getElementById("scToneStatus");

const CODE_LABELS = {
  off: "Išjungta",
  lights: "Kodas 1",
  sound: "Kodas 2",
  full: "Kodas 3",
};

const TONE_LABELS = {
  off: "—",
  wail: "Vilkimas",
  yelp: "Ūkavimas",
  priority: "Prioritetas",
};

let state = {
  code: "off",
  tone: "wail",
  muted: false,
  vehicleLabel: "—",
  jobType: "police",
};

function nuiPost(endpoint, data) {
  return fetch(`https://mrp_siren_controller/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  });
}

function applyUi() {
  document.querySelectorAll(".sc-code").forEach((btn) => {
    const code = btn.getAttribute("data-code");
    btn.classList.toggle("is-active", state.code === code);
  });

  const badgeClass = {
    off: "sc-vi-off",
    lights: "sc-vi-code1",
    sound: "sc-vi-code2",
    full: "sc-vi-code3",
  };
  codeStatus.textContent = CODE_LABELS[state.code] || "Išjungta";
  codeStatus.className = `sc-vi-badge ${badgeClass[state.code] || "sc-vi-off"}`;

  const hasSound = state.code === "sound" || state.code === "full";
  document.querySelectorAll(".sc-tone").forEach((btn) => {
    const tone = btn.getAttribute("data-tone");
    const selected = state.tone === tone;
    btn.classList.toggle("is-active", selected && !state.muted);
    btn.classList.toggle("is-pending", selected && !hasSound && !state.muted);
    btn.classList.toggle("is-dimmed", state.muted);
  });

  toneStatus.textContent = state.muted
    ? "Pritildyta"
    : hasSound
      ? (TONE_LABELS[state.tone] || "—")
      : (TONE_LABELS[state.tone] ? `${TONE_LABELS[state.tone]} (paruošta)` : "—");

  document.getElementById("btnMute")?.classList.toggle("is-active", state.muted);
  if (vehicleName) vehicleName.textContent = state.vehicleLabel || "—";

  const lightsOn = state.code === "lights" || state.code === "full";
  const soundOn = state.code === "sound" || state.code === "full";

  const setLight = (id, on, kind) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.classList.remove("is-on-red", "is-on-blue", "is-on-bar");
    if (on) el.classList.add(kind);
  };

  setLight("lightFl", lightsOn, "is-on-red");
  setLight("lightFr", lightsOn, "is-on-blue");
  setLight("lightRl", lightsOn, "is-on-red");
  setLight("lightRr", lightsOn, "is-on-blue");
  setLight("lightBar", lightsOn, "is-on-bar");

  document.getElementById("stageS1")?.classList.toggle("is-on", state.code === "lights");
  document.getElementById("stageS2")?.classList.toggle("is-on", state.code === "sound");
  document.getElementById("stageS3")?.classList.toggle("is-on", state.code === "full");
}

function openPanel(data) {
  state = { ...state, ...data };
  root.classList.remove("hidden");
  applyUi();
}

function closePanel() {
  root.classList.add("hidden");
}

document.getElementById("scClose")?.addEventListener("click", () => nuiPost("close"));
document.getElementById("scBackdrop")?.addEventListener("click", () => nuiPost("close"));

document.querySelectorAll(".sc-code").forEach((btn) => {
  btn.addEventListener("click", () => {
    const code = btn.getAttribute("data-code");
    nuiPost("setCode", { code });
  });
});

document.querySelectorAll(".sc-tone").forEach((btn) => {
  btn.addEventListener("click", () => {
    const tone = btn.getAttribute("data-tone");
    if (!tone) return;
    state.tone = tone;
    applyUi();
    nuiPost("setTone", { tone });
  });
});

const manualBtn = document.getElementById("btnManual");
if (manualBtn) {
  const startManual = () => {
    manualBtn.classList.add("is-held");
    nuiPost("manual", { held: true });
  };
  const endManual = () => {
    manualBtn.classList.remove("is-held");
    nuiPost("manual", { held: false });
  };
  manualBtn.addEventListener("mousedown", startManual);
  manualBtn.addEventListener("mouseup", endManual);
  manualBtn.addEventListener("mouseleave", endManual);
  manualBtn.addEventListener("touchstart", (e) => { e.preventDefault(); startManual(); });
  manualBtn.addEventListener("touchend", endManual);
}

document.getElementById("btnAirhorn")?.addEventListener("click", () => nuiPost("airhorn"));
document.getElementById("btnMute")?.addEventListener("click", () => nuiPost("toggleMute"));

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data) return;
  if (data.action === "open") {
    openPanel(data);
    return;
  }
  if (data.action === "close") {
    closePanel();
    return;
  }
  if (data.action === "sync") {
    state = { ...state, ...data };
    applyUi();
  }
});

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !root.classList.contains("hidden")) {
    e.preventDefault();
    nuiPost("close");
  }
});

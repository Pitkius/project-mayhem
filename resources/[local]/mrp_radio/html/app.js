const app = document.getElementById("radio-app");
const lcdFreq = document.getElementById("lcdFreq");
const lcdFaction = document.getElementById("lcdFaction");
const lcdStatus = document.getElementById("lcdStatus");
const statusLed = document.getElementById("statusLed");
const radioLcd = document.getElementById("radioLcd");
const btnPower = document.getElementById("btnPower");
const btnMute = document.getElementById("btnMute");
const btnUp = document.getElementById("btnUp");
const btnDown = document.getElementById("btnDown");
const btn1 = document.getElementById("btn1");
const btn2 = document.getElementById("btn2");
const modalFreq = document.getElementById("modal-freq");
const inputFreq = document.getElementById("inputFreq");
const inputAlias = document.getElementById("inputAlias");
const freqHint = document.getElementById("freqHint");

const FREQ_STEP = 0.01;
const MIN_FREQ = 1.0;
const MAX_FREQ = 999.99;

let state = {
  freq: null,
  label: null,
  sub: null,
  alias: "",
  connected: false,
  soundOn: true,
};

function nui(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
}

function parseFreq(raw) {
  if (raw == null || raw === "") return null;
  const n = parseFloat(String(raw).replace(",", "."));
  if (Number.isNaN(n)) return null;
  return Math.round(n * 100) / 100;
}

function formatLcdFreq(n) {
  if (n == null || Number.isNaN(n)) return "--.--";
  const rounded = Math.round(n * 100) / 100;
  const whole = Math.floor(rounded);
  const frac = Math.round((rounded - whole) * 100);
  if (whole >= 100) return `${whole}.${String(frac).padStart(2, "0")}`;
  return `${String(whole).padStart(2, "0")}.${String(frac).padStart(2, "0")}`;
}

function factionClass(label) {
  if (!label) return "";
  const l = label.toLowerCase();
  if (l.includes("polic")) return "faction-pd";
  if (l.includes("medik") || l.includes("ems")) return "faction-ems";
  if (l.includes("mechan")) return "faction-mech";
  if (l.includes("vieš")) return "faction-pub";
  return "";
}

function refreshUi() {
  lcdFreq.textContent = formatLcdFreq(state.freq);

  lcdFaction.className = "lcd-faction";
  if (state.label) {
    lcdFaction.textContent = state.label.toUpperCase();
    const fc = factionClass(state.label);
    if (fc) lcdFaction.classList.add(fc);
  } else {
    lcdFaction.textContent = "—";
  }

  if (state.connected) {
    app.classList.add("is-connected");
    radioLcd.classList.add("is-live");
    btn1.classList.add("is-active");
    statusLed.classList.add("on");
    lcdStatus.textContent = "PRISIJUNGTA · TX/RX";
  } else {
    app.classList.remove("is-connected");
    radioLcd.classList.remove("is-live");
    btn1.classList.remove("is-active");
    statusLed.classList.remove("on");
    if (state.freq != null) {
      lcdStatus.textContent = state.sub ? "PASIRUOŠĘS" : "PASIRINKTA";
    } else {
      lcdStatus.textContent = "ĮVESK DAŽNĮ";
    }
  }

  btnMute.classList.toggle("is-muted", !state.soundOn);
}

function changeFreq(delta) {
  const base = state.freq != null ? state.freq : MIN_FREQ;
  let next = Math.round((base + delta) * 100) / 100;
  next = Math.max(MIN_FREQ, Math.min(MAX_FREQ, next));
  if (!state.alias) {
    openFreqModal(next);
    freqHint.textContent = "Įrašyk šaukinį ir patvirtink.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("validateFreq", { freq: next, alias: state.alias });
}

function openFreqModal(preset) {
  inputFreq.value = preset != null ? preset : state.freq != null ? state.freq : "";
  inputAlias.value = state.alias || "";
  freqHint.textContent = "";
  freqHint.className = "modal__hint";
  modalFreq.classList.remove("hidden");
  inputFreq.focus();
}

function toggleConnect() {
  if (state.connected) {
    nui("disconnect");
    state.connected = false;
    refreshUi();
    return;
  }
  if (state.freq == null) {
    openFreqModal();
    return;
  }
  if (!state.alias) {
    openFreqModal(state.freq);
    freqHint.textContent = "Pirmiausia įrašyk šaukinį.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("connect", { freq: state.freq, alias: state.alias });
}

btnPower.addEventListener("click", () => nui("close"));
btnMute.addEventListener("click", () => nui("toggleSound"));
btnUp.addEventListener("click", () => changeFreq(FREQ_STEP));
btnDown.addEventListener("click", () => changeFreq(-FREQ_STEP));
btn1.addEventListener("click", () => toggleConnect());
btn2.addEventListener("click", () => openFreqModal());

document.getElementById("btnFreqCancel").addEventListener("click", () => modalFreq.classList.add("hidden"));

document.getElementById("btnFreqOk").addEventListener("click", () => {
  const v = parseFreq(inputFreq.value);
  const alias = (inputAlias.value || "").trim();
  if (v == null || v < MIN_FREQ) {
    freqHint.textContent = "Įveskite dažnį (pvz. 19.81).";
    freqHint.className = "modal__hint err";
    return;
  }
  if (!alias) {
    freqHint.textContent = "Įrašyk savo šaukinį racijoje.";
    freqHint.className = "modal__hint err";
    return;
  }
  state.alias = alias;
  nui("validateFreq", { freq: v, alias });
});

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    if (!modalFreq.classList.contains("hidden")) modalFreq.classList.add("hidden");
    else nui("close");
  }
});

window.addEventListener("message", (event) => {
  const msg = event.data || {};
  if (msg.action === "state") {
    const d = msg.data || {};
    if (d.freq != null) state.freq = parseFreq(d.freq);
    if (d.label !== undefined) state.label = d.label;
    if (d.sub !== undefined) state.sub = d.sub;
    if (d.alias != null) state.alias = d.alias;
    state.connected = !!d.connected;
    state.soundOn = d.soundOn !== false;
    app.classList.remove("hidden");
    refreshUi();
  }
  if (msg.action === "close") {
    app.classList.add("hidden");
    modalFreq.classList.add("hidden");
  }
  if (msg.action === "freqResult") {
    const d = msg.data || {};
    if (d.ok) {
      state.freq = parseFreq(d.freq);
      state.label = d.label;
      state.sub = d.lock || d.sub || "";
      if (d.alias) state.alias = d.alias;
      freqHint.textContent = d.label
        ? `${formatLcdFreq(d.freq)} MHz · ${d.label}`
        : `${formatLcdFreq(d.freq)} MHz`;
      freqHint.className = "modal__hint ok";
      setTimeout(() => modalFreq.classList.add("hidden"), 450);
    } else {
      freqHint.textContent = d.message || "Negalima.";
      freqHint.className = "modal__hint err";
    }
    refreshUi();
  }
});

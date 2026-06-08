const app = document.getElementById("radio-app");
const lcdFreq = document.getElementById("lcdFreq");
const lcdMeta = document.getElementById("lcdMeta");
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

/** LCD formatas kaip MEINMACHT — pvz. 01.00, 12.00, 88.00 */
function formatLcdFreq(n) {
  if (n == null || Number.isNaN(n)) return "--.--";
  const whole = Math.floor(n);
  const frac = Math.round((n - whole) * 100);
  if (whole >= 100) return `${whole}.${String(frac).padStart(2, "0")}`;
  return `${String(whole).padStart(2, "0")}.${String(frac).padStart(2, "0")}`;
}

function refreshUi() {
  lcdFreq.textContent = formatLcdFreq(state.freq);

  if (state.connected) {
    app.classList.add("is-connected");
    btn1.classList.add("is-active");
    const parts = [];
    if (state.label) parts.push(state.label.toUpperCase());
    parts.push("PRISIJUNGTA");
    lcdMeta.textContent = parts.join(" · ");
  } else {
    app.classList.remove("is-connected");
    btn1.classList.remove("is-active");
    if (state.freq != null && state.label) {
      lcdMeta.textContent = state.label.toUpperCase();
    } else if (state.freq != null) {
      lcdMeta.textContent = "PASIRUOŠĘS";
    } else {
      lcdMeta.textContent = "ĮVESK DAŽNĮ";
    }
  }

  btnMute.classList.toggle("is-muted", !state.soundOn);
}

function changeFreq(delta) {
  const base = state.freq != null ? state.freq : 0;
  const next = Math.max(1, Math.min(999, base + delta));
  if (!state.alias) {
    openFreqModal(next);
    freqHint.textContent = "Įrašyk vardą ir patvirtink.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("validateFreq", { freq: next, alias: state.alias });
}

function openFreqModal(preset) {
  inputFreq.value = preset != null ? preset : (state.freq != null ? state.freq : "");
  inputAlias.value = state.alias || "";
  freqHint.textContent = "";
  freqHint.className = "modal__hint";
  modalFreq.classList.remove("hidden");
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
    freqHint.textContent = "Pirmiausia įrašyk vardą.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("connect", { freq: state.freq, alias: state.alias });
}

btnPower.addEventListener("click", () => nui("close"));
btnMute.addEventListener("click", () => nui("toggleSound"));
btnUp.addEventListener("click", () => changeFreq(1));
btnDown.addEventListener("click", () => changeFreq(-1));
btn1.addEventListener("click", () => toggleConnect());
btn2.addEventListener("click", () => openFreqModal());

document.getElementById("btnFreqCancel").addEventListener("click", () => modalFreq.classList.add("hidden"));

document.getElementById("btnFreqOk").addEventListener("click", () => {
  const v = parseInt(inputFreq.value, 10);
  const alias = (inputAlias.value || "").trim();
  if (!v || v < 1) {
    freqHint.textContent = "Įveskite dažnį.";
    freqHint.className = "modal__hint err";
    return;
  }
  if (!alias) {
    freqHint.textContent = "Įrašyk savo vardą racijoje.";
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
    if (d.freq != null) state.freq = d.freq;
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
      state.freq = d.freq;
      state.label = d.label;
      state.sub = d.lock || d.sub || "";
      if (d.alias) state.alias = d.alias;
      freqHint.textContent = d.label ? `${d.freq} — ${d.label}` : `Dažnis ${d.freq}`;
      freqHint.className = "modal__hint ok";
      setTimeout(() => modalFreq.classList.add("hidden"), 450);
    } else {
      freqHint.textContent = d.message || "Negalima.";
      freqHint.className = "modal__hint err";
    }
    refreshUi();
  }
});

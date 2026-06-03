const app = document.getElementById("radio-app");
const screenFreq = document.getElementById("screenFreq");
const screenLabel = document.getElementById("screenLabel");
const screenSub = document.getElementById("screenSub");
const screenAlias = document.getElementById("screenAlias");
const screenBatt = document.getElementById("screenBatt");
const btnConnect = document.getElementById("btnConnect");
const btnFreq = document.getElementById("btnFreq");
const btnSound = document.getElementById("btnSound");
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

function padFreq(n) {
  if (n == null || Number.isNaN(n)) return "--";
  return String(n).padStart(2, "0");
}

function refreshUi() {
  screenFreq.textContent = state.freq != null ? padFreq(state.freq) : "--";
  screenLabel.textContent = state.label || "RACIJA";
  screenSub.textContent = state.sub || (state.freq != null ? "Pasiruošęs" : "Įveskite dažnį");
  screenAlias.textContent = state.alias ? `Vardas: ${state.alias}` : "";

  if (state.connected) {
    btnConnect.classList.add("connected");
    screenSub.textContent = state.sub || "PRISIJUNGTA";
  } else {
    btnConnect.classList.remove("connected");
    if (state.freq != null && !state.sub) screenSub.textContent = "Pasiruošęs";
  }

  screenBatt.textContent = state.soundOn ? "SND" : "MUT";
}

document.getElementById("btnClose").addEventListener("click", () => nui("close"));

btnFreq.addEventListener("click", () => {
  inputFreq.value = state.freq != null ? state.freq : "";
  inputAlias.value = state.alias || "";
  freqHint.textContent = "";
  freqHint.className = "modal__hint";
  modalFreq.classList.remove("hidden");
});

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

btnSound.addEventListener("click", () => nui("toggleSound"));

btnConnect.addEventListener("click", () => {
  if (state.connected) {
    nui("disconnect");
  } else {
    if (state.freq == null) {
      modalFreq.classList.remove("hidden");
      return;
    }
    if (!state.alias) {
      modalFreq.classList.remove("hidden");
      freqHint.textContent = "Pirmiausia įrašyk vardą ir dažnį.";
      freqHint.className = "modal__hint err";
      return;
    }
    nui("connect", { freq: state.freq, alias: state.alias });
  }
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
      setTimeout(() => modalFreq.classList.add("hidden"), 500);
    } else {
      freqHint.textContent = d.message || "Negalima.";
      freqHint.className = "modal__hint err";
    }
    refreshUi();
  }
});

function tickClock() {
  const d = new Date();
  document.getElementById("screenTime").textContent =
    `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
tickClock();
setInterval(tickClock, 10000);

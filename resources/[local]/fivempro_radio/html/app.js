const app = document.getElementById("radio-app");
const screenFreq = document.getElementById("screenFreq");
const screenLabel = document.getElementById("screenLabel");
const screenSub = document.getElementById("screenSub");
const screenLock = document.getElementById("screenLock");
const screenTime = document.getElementById("screenTime");
const btnConnect = document.getElementById("btnConnect");
const btnFreq = document.getElementById("btnFreq");
const btnSound = document.getElementById("btnSound");
const modalFreq = document.getElementById("modal-freq");
const modalSettings = document.getElementById("modal-settings");
const inputFreq = document.getElementById("inputFreq");
const freqHint = document.getElementById("freqHint");

let state = {
  freq: null,
  label: null,
  lock: null,
  connected: false,
  soundOn: true,
  settings: {},
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
  screenLabel.textContent = state.label || "Nenustatytas dažnis";
  screenSub.textContent = state.lock || (state.freq != null ? "Pasiruošęs prisijungimui" : "Įveskite dažnį");
  screenLock.classList.toggle("hidden", !state.lock);

  if (state.connected) {
    btnConnect.textContent = "Prisijungta";
    btnConnect.classList.add("connected");
  } else {
    btnConnect.textContent = "Prisijungti";
    btnConnect.classList.remove("connected");
  }

  btnSound.textContent = state.soundOn ? "Garsas ON" : "Garsas OFF";
  btnSound.classList.toggle("muted", !state.soundOn);
}

function applySettings(s) {
  if (!s) return;
  document.getElementById("setBeepStart").checked = !!s.beepStart;
  document.getElementById("setBeepEnd").checked = !!s.beepEnd;
  document.getElementById("setChannelChange").checked = !!s.channelChange;
  document.getElementById("setConnect").checked = !!s.connect;
  document.getElementById("setDisconnect").checked = !!s.disconnect;
  document.getElementById("setCompactOverlay").checked = !!s.compactOverlay;
  document.getElementById("setMemberDisplay").value = s.memberDisplay || "callsign_name";
}

function tickClock() {
  const d = new Date();
  screenTime.textContent = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

document.getElementById("btnClose").addEventListener("click", () => nui("close"));
btnFreq.addEventListener("click", () => {
  inputFreq.value = state.freq != null ? state.freq : "";
  freqHint.textContent = "";
  freqHint.className = "modal__hint";
  modalFreq.classList.remove("hidden");
});
document.getElementById("btnFreqCancel").addEventListener("click", () => modalFreq.classList.add("hidden"));
document.getElementById("btnFreqOk").addEventListener("click", () => {
  const v = parseInt(inputFreq.value, 10);
  if (!v || v < 1) {
    freqHint.textContent = "Įveskite teisingą dažnį.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("validateFreq", { freq: v });
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
    nui("connect", { freq: state.freq });
  }
});
document.getElementById("btnSettings").addEventListener("click", () => {
  applySettings(state.settings);
  modalSettings.classList.remove("hidden");
});
document.getElementById("btnSettingsSave").addEventListener("click", () => {
  const payload = {
    beepStart: document.getElementById("setBeepStart").checked,
    beepEnd: document.getElementById("setBeepEnd").checked,
    channelChange: document.getElementById("setChannelChange").checked,
    connect: document.getElementById("setConnect").checked,
    disconnect: document.getElementById("setDisconnect").checked,
    compactOverlay: document.getElementById("setCompactOverlay").checked,
    memberDisplay: document.getElementById("setMemberDisplay").value,
  };
  nui("saveSettings", payload);
  modalSettings.classList.add("hidden");
});

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    if (!modalFreq.classList.contains("hidden")) modalFreq.classList.add("hidden");
    else if (!modalSettings.classList.contains("hidden")) modalSettings.classList.add("hidden");
    else nui("close");
  }
});

window.addEventListener("message", (event) => {
  const msg = event.data || {};
  if (msg.action === "state") {
    const d = msg.data || {};
    state.freq = d.freq != null ? d.freq : state.freq;
    state.label = d.label != null ? d.label : state.label;
    state.lock = d.lock != null ? d.lock : state.lock;
    state.connected = !!d.connected;
    state.soundOn = d.soundOn !== false;
    state.settings = d.settings || state.settings;
    app.classList.remove("hidden");
    refreshUi();
  }
  if (msg.action === "close") {
    app.classList.add("hidden");
    modalFreq.classList.add("hidden");
    modalSettings.classList.add("hidden");
  }
  if (msg.action === "freqResult") {
    const d = msg.data || {};
    if (d.ok) {
      state.freq = d.freq;
      state.label = d.label;
      state.lock = d.lock;
      freqHint.textContent = d.label ? `Dažnis ${d.freq} — ${d.label}` : `Dažnis ${d.freq}`;
      freqHint.className = "modal__hint ok";
      setTimeout(() => modalFreq.classList.add("hidden"), 600);
    } else {
      freqHint.textContent = d.message || "Negalima.";
      freqHint.className = "modal__hint err";
    }
    refreshUi();
  }
});

setInterval(tickClock, 15000);
tickClock();

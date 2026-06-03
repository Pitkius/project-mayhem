const app = document.getElementById("radio-app");
const screenFreq = document.getElementById("screenFreq");
const screenLabel = document.getElementById("screenLabel");
const screenSub = document.getElementById("screenSub");
const screenAlias = document.getElementById("screenAlias");
const screenBatt = document.getElementById("screenBatt");
const screenLock = document.getElementById("screenLock");
const screenBadge = document.getElementById("screenBadge");
const screenConn = document.getElementById("screenConn");
const signalBars = document.getElementById("signalBars");
const labelConnect = document.getElementById("labelConnect");
const labelSound = document.getElementById("labelSound");
const btnConnect = document.getElementById("btnConnect");
const btnFreq = document.getElementById("btnFreq");
const btnSound = document.getElementById("btnSound");
const btnChPrev = document.getElementById("btnChPrev");
const btnChNext = document.getElementById("btnChNext");
const modalFreq = document.getElementById("modal-freq");
const inputFreq = document.getElementById("inputFreq");
const inputAlias = document.getElementById("inputAlias");
const freqHint = document.getElementById("freqHint");
const waveCanvas = document.getElementById("waveCanvas");

let state = {
  freq: null,
  label: null,
  sub: null,
  alias: "",
  connected: false,
  soundOn: true,
};

let waveAnim = null;

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

function inferBadge(label, sub) {
  const t = `${label || ""} ${sub || ""}`.toUpperCase();
  if (t.includes("PD") || t.includes("POLIC")) return "PD";
  if (t.includes("EMS") || t.includes("MED")) return "EMS";
  if (t.includes("MECH")) return "MECH";
  return "";
}

function setSignalBars(connected, locked) {
  const spans = signalBars.querySelectorAll("span");
  const level = connected ? (locked ? 3 : 4) : 0;
  spans.forEach((el, i) => {
    el.classList.toggle("on", i < level);
  });
}

function refreshUi() {
  screenFreq.textContent = state.freq != null ? padFreq(state.freq) : "--";
  screenLabel.textContent = (state.label || "RACIJA").toUpperCase();
  screenAlias.textContent = state.alias ? state.alias : "";

  const locked = !!(state.sub && /užkoduot|Užkoduot/i.test(state.sub));
  screenLock.classList.toggle("visible", locked);

  const badge = inferBadge(state.label, state.sub);
  if (badge) {
    screenBadge.textContent = badge;
    screenBadge.classList.remove("hidden");
  } else {
    screenBadge.classList.add("hidden");
  }

  if (state.connected) {
    app.classList.add("is-connected");
    btnConnect.classList.add("is-connected");
    labelConnect.textContent = "ATJUNGTI";
    screenConn.textContent = "PRISIJUNGTA";
    screenConn.classList.add("on");
    screenSub.textContent = state.sub || "Kanalas aktyvus";
    startWave();
  } else {
    app.classList.remove("is-connected");
    btnConnect.classList.remove("is-connected");
    labelConnect.textContent = "PRISIJUNGTI";
    screenConn.textContent = "NEPRISIJUNGTA";
    screenConn.classList.remove("on");
    screenSub.textContent = state.sub || (state.freq != null ? "Pasiruošęs" : "Įveskite dažnį");
    stopWave();
  }

  setSignalBars(state.connected, locked);
  labelSound.textContent = state.soundOn ? "ĮJ." : "IŠJ.";
  labelSound.classList.toggle("on", state.soundOn);
  screenBatt.textContent = state.soundOn ? "78%" : "62%";
}

function changeFreq(delta) {
  const base = state.freq != null ? state.freq : 0;
  const next = Math.max(1, Math.min(999, base + delta));
  if (!state.alias) {
    modalFreq.classList.remove("hidden");
    inputFreq.value = next;
    freqHint.textContent = "Įrašyk vardą ir patvirtink.";
    freqHint.className = "modal__hint err";
    return;
  }
  nui("validateFreq", { freq: next, alias: state.alias });
}

function startWave() {
  if (waveAnim) return;
  const ctx = waveCanvas.getContext("2d");
  let t = 0;
  function draw() {
    const w = waveCanvas.width;
    const h = waveCanvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = "rgba(167, 139, 250, 0.85)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let x = 0; x < w; x++) {
      const y = h / 2 + Math.sin((x + t) * 0.08) * 10 + Math.sin((x + t) * 0.03) * 6;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    t += state.connected ? 4 : 1;
    waveAnim = requestAnimationFrame(draw);
  }
  draw();
}

function stopWave() {
  if (waveAnim) {
    cancelAnimationFrame(waveAnim);
    waveAnim = null;
  }
  const ctx = waveCanvas.getContext("2d");
  ctx.clearRect(0, 0, waveCanvas.width, waveCanvas.height);
}

document.getElementById("btnClose").addEventListener("click", () => nui("close"));

btnFreq.addEventListener("click", () => {
  inputFreq.value = state.freq != null ? state.freq : "";
  inputAlias.value = state.alias || "";
  freqHint.textContent = "";
  freqHint.className = "modal__hint";
  modalFreq.classList.remove("hidden");
});

btnChPrev.addEventListener("click", () => changeFreq(-1));
btnChNext.addEventListener("click", () => changeFreq(1));

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
    state.connected = false;
    refreshUi();
    return;
  }
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
    stopWave();
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
setInterval(tickClock, 15000);

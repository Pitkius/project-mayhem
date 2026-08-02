const app = document.getElementById("app");
const productList = document.getElementById("productList");
const emptyPick = document.getElementById("emptyPick");
const detailPanel = document.getElementById("detailPanel");
const btnCraft = document.getElementById("btnCraft");
const btnBuyParts = document.getElementById("btnBuyParts");
const weedDryQuantity = document.getElementById("weedDryQuantity");
const weedDryAmount = document.getElementById("weedDryAmount");
const weedDryAvailable = document.getElementById("weedDryAvailable");
const weedDryTimePreview = document.getElementById("weedDryTimePreview");
const mgSkill = document.getElementById("mgSkill");
const mgAdvanced = document.getElementById("mgAdvanced");
const craftProgress = document.getElementById("craftProgress");
const craftProgressPhase = document.getElementById("craftProgressPhase");
const craftProgressLabel = document.getElementById("craftProgressLabel");
const craftProgressBar = document.getElementById("craftProgressBar");
const craftProgressTime = document.getElementById("craftProgressTime");

// PAKAVIMAS: 3D informacinis HUD (kairėje). Tekstas rodomas, bet neima paspaudimų.
const weed3dHud = document.createElement("section");
weed3dHud.id = "weed3dHud";
weed3dHud.className = "weed3d-hud hidden";
weed3dHud.innerHTML = `
  <div class="weed3d-head">
    <div>
      <span class="weed3d-kicker">3D WORKSTATION</span>
      <h2 id="weed3dTitle">Žolė</h2>
    </div>
    <span id="weed3dStage" class="weed3d-stage">1/1</span>
  </div>
  <p id="weed3dHint" class="weed3d-hint"></p>
  <div id="weed3dMetrics" class="weed3d-metrics"></div>
  <div class="weed3d-footer">
    <span id="weed3dScore">Kokybė: 0</span>
    <span id="weed3dMistakes">Klaidos: 0</span>
  </div>`;
document.body.appendChild(weed3dHud);

const weed3dTitle = document.getElementById("weed3dTitle");
const weed3dStage = document.getElementById("weed3dStage");
const weed3dHint = document.getElementById("weed3dHint");
const weed3dMetrics = document.getElementById("weed3dMetrics");
const weed3dScore = document.getElementById("weed3dScore");
const weed3dMistakes = document.getElementById("weed3dMistakes");

// PAKAVIMAS: nematomi paspaudimo taškai virš maišelio/gabaliuko ekrane.
// pointer-events: none (CSS) — paspaudimai eina per GTA Lua, ne per šiuos mygtukus.
const weedPackCursor = document.createElement("div");
weedPackCursor.id = "weedPackCursor";
weedPackCursor.className = "weed-pack-cursor hidden";
weedPackCursor.innerHTML = `
  <button type="button" class="weed-pack-target weed-pack-bag hidden" data-target="bag">
    <span>Maišelis</span>
  </button>
  <button type="button" class="weed-pack-target weed-pack-bud hidden" data-target="bud">
    <span>Žolė</span>
  </button>`;
document.body.appendChild(weedPackCursor);
const weedPackBag = weedPackCursor.querySelector('[data-target="bag"]');
const weedPackBud = weedPackCursor.querySelector('[data-target="bud"]');
let weedPackActive = false;
let weedPackTargets = { bag: null, bud: null };
let weedPackClickLocked = false;

async function sendWeedPackClick(target) {
  if (!weedPackActive || !target || weedPackClickLocked) return;
  weedPackClickLocked = true;
  try {
    await post("weedPackClick", { target });
  } catch (_) {
    // A failed NUI request must not permanently block later pack clicks.
  } finally {
    weedPackClickLocked = false;
  }
}

function weedPackHitRadius() {
  // PAKAVIMAS: paspaudimo spindulys px. 0.18 = 18% ekrano. Didesnis = lengviau pataikyti NUI režime.
  return Math.max(110, Math.min(window.innerWidth, window.innerHeight) * 0.18);
}

function findWeedPackTargetAt(clientX, clientY) {
  let best = null;
  let bestDist = Infinity;
  for (const name of ["bag", "bud"]) {
    const target = weedPackTargets[name];
    if (!target || target.active !== true || target.visible === false) continue;
    const px = (Number(target.x) || 0.5) * window.innerWidth;
    const py = (Number(target.y) || 0.5) * window.innerHeight;
    const dist = Math.hypot(clientX - px, clientY - py);
    if (dist <= weedPackHitRadius() && dist < bestDist) {
      best = name;
      bestDist = dist;
    }
  }
  return best;
}

function handleWeedPackButton(event) {
  if (!weedPackActive || (event.button !== undefined && event.button !== 0)) return;
  const target = event.currentTarget?.dataset?.target
    || findWeedPackTargetAt(event.clientX, event.clientY);
  const state = weedPackTargets[target];
  if (!target || !state || state.active !== true || state.visible === false) return;
  event.preventDefault();
  event.stopPropagation();
  sendWeedPackClick(target);
}

function handleWeedPackOverlay(event) {
  if (!weedPackActive || (event.button !== undefined && event.button !== 0)) return;
  const target = findWeedPackTargetAt(event.clientX, event.clientY);
  if (!target) return;
  event.preventDefault();
  event.stopPropagation();
  sendWeedPackClick(target);
}

weedPackCursor.addEventListener("pointerdown", handleWeedPackOverlay);
weedPackBag.addEventListener("pointerdown", handleWeedPackButton);
weedPackBud.addEventListener("pointerdown", handleWeedPackButton);

let state = { products: [], selectedId: null, isWeaponMode: false };

function weedDryDurationSeconds(amount, drying) {
  amount = Math.max(0, Math.floor(Number(amount) || 0));
  const secondsPerPlant = Math.max(1, Number(drying?.secondsPerPlant) || 10);
  const every = Math.max(1, Number(drying?.discountEvery) || 25);
  const discountPercent = Math.max(0, Number(drying?.discountPercent) || 2);
  const discount = Math.floor(amount / every) * discountPercent;
  return Math.max(1, Math.floor(amount * secondsPerPlant * Math.max(0.1, 1 - discount / 100)));
}

function selectedProduct() {
  return state.products.find((product) => product.id === state.selectedId);
}

function selectedDryAmount(product = selectedProduct()) {
  if (!product?.drying) return null;
  return Math.floor(Number(weedDryAmount?.value) || 0);
}

function updateWeedDryDetail(product = selectedProduct()) {
  const drying = product?.drying;
  if (!weedDryQuantity) return;
  weedDryQuantity.classList.toggle("hidden", !drying);
  if (!drying) return;

  const minimum = Number(drying.minimumAmount) || 10;
  const maximum = Number(drying.maximumAmount) || 500;
  const available = Math.max(0, Number(drying.availableAmount) || 0);
  weedDryAmount.min = "1";
  weedDryAmount.max = String(maximum);

  const amount = selectedDryAmount(product);
  const valid = amount >= minimum && amount <= maximum && amount <= available;
  weedDryAvailable.textContent = `Turite: ${available} · Min.: ${minimum}`;
  const durationText = valid
    ? formatCraftTime(weedDryDurationSeconds(amount, drying) * 1000)
    : null;
  weedDryTimePreview.textContent = durationText
    ? `Džiovinimo laikas: ${durationText}`
    : (available < minimum
      ? `Trūksta lapų: minimali partija yra ${minimum}.`
      : amount < minimum
        ? `Minimalus džiovinimo kiekis yra ${minimum}.`
        : amount > maximum
          ? `Didžiausias džiovinimo kiekis yra ${maximum}.`
          : amount > available
            ? `Trūksta lapų: turite ${available}.`
            : `Įveskite kiekį nuo ${minimum} iki ${Math.min(maximum, available)}.`);
  document.getElementById("prodTime").textContent = durationText || "Pasirinkite kiekį";

  const ingredient = product.ingredients?.[0];
  const row = document.querySelector("#ingredientList li");
  if (ingredient && row) {
    row.className = valid ? "ok" : "bad";
    const value = row.querySelector("span:last-child");
    if (value) value.textContent = `${available}/${amount > 0 ? amount : minimum}`;
  }
  btnCraft.disabled = !valid;
}

function updateWeed3dHud(data, reset = false) {
  const d = data || {};
  if (reset && weed3dMetrics) weed3dMetrics.innerHTML = "";
  if (d.title !== undefined && weed3dTitle) weed3dTitle.textContent = d.title;
  if (d.stage !== undefined && weed3dStage) weed3dStage.textContent = d.stage;
  if (d.hint !== undefined && weed3dHint) weed3dHint.textContent = d.hint;
  if (d.score !== undefined && weed3dScore) weed3dScore.textContent = `Kokybė: ${Math.round(Number(d.score) || 0)}`;
  if (d.mistakes !== undefined && weed3dMistakes) weed3dMistakes.textContent = `Klaidos: ${Number(d.mistakes) || 0}`;
  if (!weed3dMetrics) return;

  const rows = [];
  if (d.temperature !== undefined) rows.push(["Temperatūra", `${Number(d.temperature).toFixed(1)}°C`]);
  if (d.airflow !== undefined) rows.push(["Oro srautas", `${Math.round(Number(d.airflow))}%`]);
  if (d.weight !== undefined) rows.push(["Svoris", `${Number(d.weight).toFixed(2)} g`]);
  if (d.target !== undefined) rows.push(["Tikslas", String(d.target)]);
  if (d.remaining !== undefined) rows.push(["Liko", `${Math.ceil(Number(d.remaining) / 1000)} s`]);
  if (d.seal !== undefined) rows.push(["Slėgis", `${Math.round(Number(d.seal) * 100)}%`]);
  if (d.packed !== undefined) rows.push(["Supakuota", `${Number(d.packed) || 0}/${Number(d.targetCount) || 5}`]);
  // PAKAVIMAS: targetCount numatytas 5 — turi sutapti su session.packTarget Lua faile.
  if (rows.length > 0) {
    weed3dMetrics.replaceChildren(...rows.map(([label, value]) => {
      const row = document.createElement("span");
      const strong = document.createElement("b");
      row.textContent = `${label} `;
      strong.textContent = value;
      row.appendChild(strong);
      return row;
    }));
  }
}

function positionWeedPackTarget(button, target) {
  // PAKAVIMAS: x/y (0–1) iš Lua → mygtuko pozicija %. 0.04–0.96 riboja nuo kraštų.
  const data = target || {};
  const visible = data.visible !== false && data.active === true;
  button.classList.toggle("hidden", !visible);
  button.classList.toggle("active", visible);
  if (!visible) return;
  const x = Math.min(0.96, Math.max(0.04, Number(data.x) || 0.5));
  const y = Math.min(0.94, Math.max(0.06, Number(data.y) || 0.5));
  button.style.left = `${x * 100}%`;
  button.style.top = `${y * 100}%`;
}

function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
}

function formatCraftTime(ms) {
  const sec = Math.max(0, Math.ceil((ms || 0) / 1000));
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  if (m > 0) return `${m}:${String(s).padStart(2, "0")}`;
  return `${s} sek.`;
}

function showCraftProgress(data) {
  if (!craftProgress) return;
  const d = data || {};
  const phaseIndex = d.phaseIndex || 1;
  const phaseCount = d.phaseCount || 1;
  if (craftProgressPhase) {
    craftProgressPhase.textContent =
      phaseCount > 1 ? `Etapas ${phaseIndex}/${phaseCount}` : "Gamyba";
  }
  if (craftProgressLabel) craftProgressLabel.textContent = d.label || "Gaminama…";
  if (craftProgressBar) craftProgressBar.style.width = "0%";
  const totalMs = d.totalMs || d.durationMs || 0;
  if (craftProgressTime) {
    craftProgressTime.textContent = `Liko: ${formatCraftTime(totalMs)}`;
  }
  craftProgress.classList.remove("hidden");
}

function updateCraftProgress(data) {
  if (!craftProgress || craftProgress.classList.contains("hidden")) return;
  const d = data || {};
  if (craftProgressBar && typeof d.overallPct === "number") {
    craftProgressBar.style.width = `${Math.min(100, Math.max(0, d.overallPct))}%`;
  }
  if (craftProgressTime && typeof d.totalRemainingMs === "number") {
    craftProgressTime.textContent = `Liko: ${formatCraftTime(d.totalRemainingMs)}`;
  }
}

function hideCraftProgress() {
  if (!craftProgress) return;
  craftProgress.classList.add("hidden");
  if (craftProgressBar) craftProgressBar.style.width = "0%";
}

function canCraftProduct(p) {
  if (!p || !p.ingredients) return false;
  if (p.drying) {
    const amount = selectedDryAmount(p);
    return amount >= (Number(p.drying.minimumAmount) || 10)
      && amount <= (Number(p.drying.maximumAmount) || 500)
      && amount <= (Number(p.drying.availableAmount) || 0);
  }
  return p.ingredients.every((i) => i.missing <= 0);
}

function renderList() {
  productList.innerHTML = "";
  state.products.forEach((p) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "prod-item" + (state.selectedId === p.id ? " active" : "");
    const stage = p.stageLabel ? `${p.stageLabel} · ` : "";
    btn.innerHTML = `<strong>${p.label}</strong><small>${stage}${p.levelLabel || ""} · ${p.risk || ""}</small>`;
    btn.onclick = () => {
      state.selectedId = p.id;
      renderList();
      renderDetail(p);
    };
    productList.appendChild(btn);
  });
}

function renderDetail(p) {
  if (!p) {
    emptyPick.classList.remove("hidden");
    detailPanel.classList.add("hidden");
    return;
  }
  emptyPick.classList.add("hidden");
  detailPanel.classList.remove("hidden");
  document.getElementById("prodTitle").textContent = p.label;
  document.getElementById("prodLevel").textContent = (p.stageLabel ? `${p.stageLabel} · ` : "") + (p.levelLabel || `Lygis ${p.level}`);
  document.getElementById("prodRisk").textContent = `Rizika: ${p.risk || "—"}`;
  const sec = p.craftTimeSec || 0;
  let timeText = sec >= 90 ? `~${Math.ceil(sec / 60)} min (${sec} sek.)` : `${sec} sek.`;
  if (state.isWeaponMode) {
    timeText += p.usesPrinter ? " · 3D spausdintuvas" : " · rankinis surinkimas";
  }
  document.getElementById("prodTime").textContent = timeText;
  btnCraft.textContent = p.drying ? "PRADĖTI DŽIOVINIMĄ" : "GAMINTI";
  const rewardSection = document.getElementById("rewardSection");
  if (rewardSection) {
    rewardSection.classList.toggle("hidden", state.isWeaponMode || !(p.sellBase > 0));
  }
  if (!state.isWeaponMode && p.sellBase > 0) {
    document.getElementById("prodReward").textContent = `$${p.sellBase}`;
  }
  const ul = document.getElementById("ingredientList");
  ul.innerHTML = "";
  (p.ingredients || []).forEach((i) => {
    const li = document.createElement("li");
    li.className = i.missing <= 0 ? "ok" : "bad";
    li.innerHTML = `<span>${i.label}</span><span>${i.have}/${i.need}</span>`;
    ul.appendChild(li);
  });
  updateWeedDryDetail(p);
  btnCraft.disabled = !canCraftProduct(p);
}

if (weedDryAmount) {
  weedDryAmount.addEventListener("input", () => updateWeedDryDetail());
}

window.addEventListener("message", (e) => {
  const msg = e.data || {};
  if (msg.action === "open") {
    const d = msg.data || {};
    state.products = d.products || [];
    state.selectedId = state.products[0] ? state.products[0].id : null;
    const headTitle = document.getElementById("headTitle");
    state.isWeaponMode = !!(d.station && d.station.mode === "weapon");
    if (headTitle) {
      headTitle.innerHTML = state.isWeaponMode
        ? 'GINKLŲ <span>DIRBTUVĖ</span>'
        : 'NELEGALI <span>GAMYBA</span>';
    }
    if (btnBuyParts) {
      btnBuyParts.classList.toggle("hidden", !state.isWeaponMode);
    }
    const rewardSection = document.getElementById("rewardSection");
    if (rewardSection) rewardSection.classList.toggle("hidden", state.isWeaponMode);
    document.getElementById("stationLabel").textContent = d.station
      ? `${d.station.label} · ${d.station.level} lygis`
      : "Stotis";
    app.classList.remove("hidden");
    renderList();
    if (state.selectedId) {
      renderDetail(state.products.find((x) => x.id === state.selectedId));
    }
  }
  if (msg.action === "close") {
    if (cancelSkillGame) cancelSkillGame(false);
    if (cancelAdvancedGame) cancelAdvancedGame(false);
    weed3dHud.classList.add("hidden");
    weedPackActive = false;
    weedPackCursor.classList.add("hidden");
    app.classList.add("hidden");
    mgSkill.classList.add("hidden");
    mgAdvanced.classList.add("hidden");
    const mgSchedule = document.getElementById("mgSchedule");
    if (mgSchedule) mgSchedule.classList.add("hidden");
    if (window.MrpWebStation) MrpWebStation.close();
  }
  if (msg.action === "weed3dOpen") {
    updateWeed3dHud(msg.data, true);
    weed3dHud.classList.remove("hidden");
  }
  if (msg.action === "weed3dUpdate") {
    updateWeed3dHud(msg.data);
  }
  if (msg.action === "weed3dClose") {
    weed3dHud.classList.add("hidden");
    if (weed3dMetrics) weed3dMetrics.innerHTML = "";
  }
  if (msg.action === "weedPackOpen") {
    // PAKAVIMAS: įjungia overlay (dabar dažniausiai iškart uždaromas iš Lua).
    weedPackActive = true;
    weedPackClickLocked = false;
    weedPackTargets = { bag: null, bud: null };
    weedPackCursor.classList.remove("hidden");
  }
  if (msg.action === "weedPackTargets") {
    // PAKAVIMAS: Lua siunčia bag/bud ekrano koordinates (x, y 0–1) ir active būseną.
    const data = msg.data || {};
    weedPackTargets = {
      bag: data.bag || null,
      bud: data.bud || null,
    };
    positionWeedPackTarget(weedPackBag, data.bag);
    positionWeedPackTarget(weedPackBud, data.bud);
  }
  if (msg.action === "weedPackClose") {
    weedPackActive = false;
    weedPackClickLocked = false;
    weedPackTargets = { bag: null, bud: null };
    weedPackCursor.classList.add("hidden");
    weedPackBag.classList.add("hidden");
    weedPackBud.classList.add("hidden");
  }
  if (msg.action === "craftProgress") {
    showCraftProgress(msg.data);
  }
  if (msg.action === "craftProgressUpdate") {
    updateCraftProgress(msg.data);
  }
  if (msg.action === "craftProgressHide") {
    hideCraftProgress();
  }
  if (msg.action === "minigameSkill") {
    runSkillGame();
  }
  if (msg.action === "minigameAdvanced") {
    runAdvancedGame(msg.data && msg.data.rounds ? msg.data.rounds : 3);
  }
  if (msg.action === "minigameSchedule") {
    /* schedule.js */
  }
  if (msg.action === "ampQuizShow") {
    showAmpQuiz(msg.data || {});
  }
  if (msg.action === "ampQuizHide") {
    hideAmpQuiz();
  }
});

document.getElementById("btnClose").onclick = () => post("close");
if (btnBuyParts) {
  btnBuyParts.onclick = () => post("buyParts");
}
btnCraft.onclick = () => {
  if (!state.selectedId) return;
  const product = selectedProduct();
  post("craft", {
    productId: state.selectedId,
    amount: product?.drying ? selectedDryAmount(product) : undefined,
  });
};

let cancelSkillGame = null;
let cancelAdvancedGame = null;

function runSkillGame() {
  if (cancelSkillGame) cancelSkillGame(false);
  mgSkill.classList.remove("hidden");
  const zone = document.getElementById("mgZone");
  const needle = document.getElementById("mgNeedle");
  const zoneLeft = 15 + Math.random() * 55;
  zone.style.left = `${zoneLeft}%`;
  let pos = 0;
  let dir = 1.4;
  let done = false;
  const iv = setInterval(() => {
    pos += dir;
    if (pos >= 100) dir = -1.4;
    if (pos <= 0) dir = 1.4;
    needle.style.left = `${pos}%`;
  }, 16);
  const finish = (success) => {
    if (done) return;
    done = true;
    clearInterval(iv);
    window.removeEventListener("keydown", onKey);
    mgSkill.classList.add("hidden");
    cancelSkillGame = null;
    post("skillResult", { success: !!success });
  };
  const onKey = (ev) => {
    if (done || ev.code !== "Space") return;
    const zl = zoneLeft;
    const zh = zl + 28;
    finish(pos >= zl && pos <= zh);
  };
  cancelSkillGame = finish;
  window.addEventListener("keydown", onKey);
}

function runAdvancedGame(rounds) {
  if (cancelAdvancedGame) cancelAdvancedGame(false);
  mgAdvanced.classList.remove("hidden");
  const seqEl = document.getElementById("mgSeq");
  const keys = ["W", "A", "S", "D"];
  const seq = [];
  for (let i = 0; i < rounds; i++) seq.push(keys[Math.floor(Math.random() * keys.length)]);
  let idx = 0;
  seqEl.textContent = seq.join(" → ");
  document.getElementById("mgAdvLabel").textContent = `Įvesk seką (${idx + 1}/${rounds})`;

  const buttons = mgAdvanced.querySelectorAll(".mg-keys button");
  let done = false;
  const finish = (success) => {
    if (done) return;
    done = true;
    buttons.forEach((button) => { button.onclick = null; });
    mgAdvanced.classList.add("hidden");
    cancelAdvancedGame = null;
    post("advancedResult", { success: !!success });
  };
  cancelAdvancedGame = finish;
  buttons.forEach((b) => {
    b.classList.remove("hit");
    b.onclick = () => {
      if (b.dataset.key !== seq[idx]) {
        return finish(false);
      }
      b.classList.add("hit");
      idx += 1;
      if (idx >= seq.length) {
        return finish(true);
      }
      document.getElementById("mgAdvLabel").textContent = `Įvesk seką (${idx + 1}/${rounds})`;
    };
  });
}

document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  if (weedPackActive) {
    e.preventDefault();
    post("weedPackCancel");
    return;
  }
  if (cancelSkillGame && !mgSkill.classList.contains("hidden")) {
    cancelSkillGame(false);
  }
  if (cancelAdvancedGame && !mgAdvanced.classList.contains("hidden")) {
    cancelAdvancedGame(false);
  }
});

const ampQuiz = document.getElementById("ampQuiz");
const ampQuizStep = document.getElementById("ampQuizStep");
const ampQuizQuestion = document.getElementById("ampQuizQuestion");
const ampQuizOptions = document.getElementById("ampQuizOptions");

function hideAmpQuiz() {
  if (ampQuiz) ampQuiz.classList.add("hidden");
  if (ampQuizOptions) ampQuizOptions.innerHTML = "";
}

function showAmpQuiz(data) {
  if (!ampQuiz) return;
  const d = data || {};
  if (ampQuizStep) {
    ampQuizStep.textContent = `Klausimas ${d.index || 1}/${d.total || 3}`;
  }
  if (ampQuizQuestion) ampQuizQuestion.textContent = d.question || "—";
  if (ampQuizOptions) {
    ampQuizOptions.innerHTML = "";
    (d.options || []).forEach((opt, i) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = opt;
      btn.onclick = () => post("ampQuizAnswer", { choice: i + 1 });
      ampQuizOptions.appendChild(btn);
    });
  }
  ampQuiz.classList.remove("hidden");
}

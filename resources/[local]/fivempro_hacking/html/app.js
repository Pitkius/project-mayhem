const tablet = document.getElementById("tablet");
const hackPanel = document.getElementById("hack");
const hackGrid = document.getElementById("hackGrid");
const hackTimer = document.getElementById("hackTimer");
let tabletData = null;
let hackState = null;
let hackInterval = null;

function res() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "fivempro_hacking";
}

function post(endpoint, data) {
  return fetch(`https://${res()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === "openTablet") {
    tabletData = d.data;
    tablet.classList.remove("hidden");
    hackPanel.classList.add("hidden");
    renderTablet();
    if (d.flashTab) setTab("storage");
  }
  if (d.action === "close") {
    tablet.classList.add("hidden");
    hackPanel.classList.add("hidden");
    document.getElementById("physical")?.classList.add("hidden");
    stopHackTimer();
  }
  if (d.action === "tabletRefresh" && d.data) {
    if (tabletData) {
      tabletData.installed_os = d.data.installed_os;
      tabletData.exploits = d.data.exploits;
    }
    renderTablet();
  }
  if (d.action === "hackOpen") {
    tablet.classList.add("hidden");
    document.getElementById("physical")?.classList.add("hidden");
    hackPanel.classList.remove("hidden");
    startHack(d.profile, d.tierId);
  }
  if (d.action === "hackClose") {
    hackPanel.classList.add("hidden");
    stopHackTimer();
  }
});

document.getElementById("btnClose").onclick = () => post("close", {});
document.getElementById("hackCancel").onclick = () => post("hackCancel", {});

document.querySelectorAll(".tab").forEach((t) => {
  t.onclick = () => setTab(t.dataset.tab);
});

function setTab(id) {
  document.querySelectorAll(".tab").forEach((x) => x.classList.toggle("active", x.dataset.tab === id));
  document.querySelectorAll(".tab-panel").forEach((p) => p.classList.add("hidden"));
  const el = document.getElementById("tab-" + id);
  if (el) el.classList.remove("hidden");
}

function renderTablet() {
  if (!tabletData) return;
  const os = tabletData.installed_os;
  const osLabel = os && tabletData.osCatalog[os] ? tabletData.osCatalog[os].label : "—";
  document.getElementById("sysInfo").innerHTML =
    "<div><strong>" +
    tabletData.tabletLabel +
    "</strong></div>" +
    '<div class="muted">OS: ' +
    osLabel +
    "</div>" +
    "<div>Storage: " +
    (tabletData.exploits || []).length +
    (os ? 1 : 0) +
    " / " +
    tabletData.storage +
    "</div>" +
    '<div class="muted">Exploit slots: ' +
    (tabletData.exploits || []).length +
    " / " +
    tabletData.exploitSlots +
    "</div>";
  document.getElementById("storageInfo").innerHTML =
    '<div class="muted">Idiek flashdrive su payload (black market).</div>';
  const exEl = document.getElementById("exploitList");
  exEl.innerHTML = "";
  (tabletData.exploits || []).forEach((id) => {
    const c = tabletData.exploitCatalog[id];
    const div = document.createElement("div");
    div.className = "card";
    div.innerHTML =
      "<strong>" + (c ? c.label : id) + '</strong><div class="muted">' + (c ? c.desc : "") + "</div>";
    exEl.appendChild(div);
  });
  const tierEl = document.getElementById("tierList");
  tierEl.innerHTML = "";
  Object.keys(tabletData.robberyTiers || {}).forEach((k) => {
    const t = tabletData.robberyTiers[k];
    const flow = (tabletData.robberyFlows && tabletData.robberyFlows[k]) || [];
    const locN = (tabletData.robberyLocCounts && tabletData.robberyLocCounts[k]) || 0;
    const div = document.createElement("div");
    div.className = "card";
    div.innerHTML =
      "<strong>" +
      t.label +
      '</strong><div class="muted">Min OS: ' +
      t.minOs +
      " • " +
      t.minTablet +
      "</div>" +
      (flow.length ? '<div class="muted">Fazės: ' + flow.join(" → ") + "</div>" : "") +
      (locN ? '<div class="muted">' + locN + " vietų — qb-target zona</div>" : "");
    tierEl.appendChild(div);
  });
}

document.getElementById("btnInstall").onclick = () => {
  const slot = Number(document.getElementById("driveSlot").value);
  post("installDrive", { slot });
};

function stopHackTimer() {
  if (hackInterval) clearInterval(hackInterval);
  hackInterval = null;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function flashSequence(sequence) {
  for (const idx of sequence) {
    const cell = hackGrid.querySelector('[data-idx="' + idx + '"]');
    if (cell) cell.classList.add("active");
    await sleep(380);
    if (cell) cell.classList.remove("active");
    await sleep(180);
  }
}

async function startHack(profile, tierId) {
  stopHackTimer();
  const steps = profile.steps || 5;
  const gridN = profile.grid || 4;
  const totalMs = profile.timeMs || 12000;
  const cells = gridN * gridN;
  const sequence = [];
  while (sequence.length < steps) {
    const n = Math.floor(Math.random() * cells);
    if (sequence.length === 0 || sequence[sequence.length - 1] !== n) sequence.push(n);
  }
  hackGrid.style.gridTemplateColumns = "repeat(" + gridN + ", 1fr)";
  hackGrid.innerHTML = "";
  for (let i = 0; i < cells; i++) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "hack-cell";
    b.dataset.idx = String(i);
    b.disabled = true;
    b.onclick = () => onCell(i);
    hackGrid.appendChild(b);
  }
  document.getElementById("hackHint").textContent = "Stebėk seką…";
  await flashSequence(sequence);
  document.getElementById("hackHint").textContent = "Pakartok seką";
  hackState = { sequence, idx: 0, tierId, failed: false, deadline: Date.now() + totalMs };
  document.querySelectorAll(".hack-cell").forEach((c) => {
    c.disabled = false;
  });
  hackInterval = setInterval(() => {
    if (!hackState) return;
    const left = Math.max(0, hackState.deadline - Date.now()) / 1000;
    hackTimer.textContent = left.toFixed(1) + "s";
    if (left <= 0) finishHack(false);
  }, 50);
}

function onCell(i) {
  if (!hackState || hackState.failed) return;
  const expected = hackState.sequence[hackState.idx];
  const cell = hackGrid.querySelector('[data-idx="' + i + '"]');
  if (i !== expected) {
    if (cell) cell.classList.add("fail");
    return finishHack(false);
  }
  if (cell) cell.classList.add("done");
  hackState.idx++;
  if (hackState.idx >= hackState.sequence.length) return finishHack(true);
}

function finishHack(success) {
  if (!hackState) return;
  const tierId = hackState.tierId;
  hackState = null;
  stopHackTimer();
  post("hackResult", { success, tierId });
}

/* --- Physical minigames (drill, card, thermite, loot, chain) --- */
const physicalPanel = document.getElementById("physical");
const physicalTitle = document.getElementById("physicalTitle");
const physicalHint = document.getElementById("physicalHint");
const physicalTiming = document.getElementById("physicalTiming");
const physicalSequence = document.getElementById("physicalSequence");
const physicalHold = document.getElementById("physicalHold");
const physicalMash = document.getElementById("physicalMash");
const mgZone = document.getElementById("mgZone");
const mgNeedle = document.getElementById("mgNeedle");
const mgRound = document.getElementById("mgRound");
const mgRounds = document.getElementById("mgRounds");
const mgSeq = document.getElementById("mgSeq");
const mgHoldZone = document.getElementById("mgHoldZone");
const mgHoldFill = document.getElementById("mgHoldFill");
const mgMashFill = document.getElementById("mgMashFill");
const mgMashCount = document.getElementById("mgMashCount");
const mgMashTarget = document.getElementById("mgMashTarget");

let physicalState = null;
let physicalRaf = null;
let physicalTimer = null;

const ARROWS = ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"];
const ARROW_LABELS = { ArrowUp: "↑", ArrowDown: "↓", ArrowLeft: "←", ArrowRight: "→" };

function hidePhysicalPanels() {
  [physicalTiming, physicalSequence, physicalHold, physicalMash].forEach((el) => el.classList.add("hidden"));
}

function stopPhysicalLoop() {
  if (physicalRaf) cancelAnimationFrame(physicalRaf);
  physicalRaf = null;
  if (physicalTimer) clearInterval(physicalTimer);
  physicalTimer = null;
  window.removeEventListener("keydown", onPhysicalKey);
  window.removeEventListener("keyup", onPhysicalKeyUp);
}

function finishPhysical(success) {
  if (!physicalState) return;
  const mode = physicalState.mode;
  stopPhysicalLoop();
  physicalState = null;
  physicalPanel.classList.add("hidden");
  post("physicalResult", { success, mode });
}

function onPhysicalKeyUp(e) {
  if (!physicalState || physicalState.mode !== "hold") return;
  if (e.code === "Space") physicalState.holding = false;
}

function onPhysicalKey(e) {
  if (!physicalState) return;
  if (e.code === "Escape") {
    e.preventDefault();
    stopPhysicalLoop();
    physicalState = null;
    physicalPanel.classList.add("hidden");
    post("physicalCancel", {});
    return;
  }

  if (physicalState.mode === "timing" && e.code === "Space") {
    e.preventDefault();
    const n = physicalState.needlePos;
    const z0 = physicalState.zoneStart;
    const z1 = z0 + physicalState.zoneWidth;
    if (n < z0 || n > z1) return finishPhysical(false);
    physicalState.round += 1;
    mgRound.textContent = String(physicalState.round);
    if (physicalState.round > physicalState.totalRounds) return finishPhysical(true);
    physicalState.zoneStart = 0.08 + Math.random() * (0.84 - physicalState.zoneWidth);
    mgZone.style.left = physicalState.zoneStart * 100 + "%";
    physicalState.speed = 0.012 + Math.random() * 0.014;
  }

  if (physicalState.mode === "sequence" && ARROWS.includes(e.code)) {
    e.preventDefault();
    if (e.code !== physicalState.sequence[physicalState.step]) return finishPhysical(false);
    physicalState.step += 1;
    mgSeq.textContent = physicalState.sequence.slice(physicalState.step).map((k) => ARROW_LABELS[k]).join(" ");
    if (physicalState.step >= physicalState.sequence.length) finishPhysical(true);
  }

  if (physicalState.mode === "hold" && e.code === "Space") {
    e.preventDefault();
    physicalState.holding = true;
  }

  if (physicalState.mode === "mash" && e.code === "Space") {
    e.preventDefault();
    const now = Date.now();
    if (now - (physicalState.lastMash || 0) < 120) return;
    physicalState.lastMash = now;
    physicalState.count += 1;
    mgMashCount.textContent = String(physicalState.count);
    mgMashFill.style.width = Math.min(100, (physicalState.count / physicalState.target) * 100) + "%";
    if (physicalState.count >= physicalState.target) finishPhysical(true);
  }
}

function startTiming(data) {
  hidePhysicalPanels();
  physicalTiming.classList.remove("hidden");
  const totalRounds = data.rounds || 3;
  mgRounds.textContent = String(totalRounds);
  mgRound.textContent = "1";
  const zoneWidth = 0.12 + Math.random() * 0.1;
  const zoneStart = 0.1 + Math.random() * (0.82 - zoneWidth);
  mgZone.style.width = zoneWidth * 100 + "%";
  mgZone.style.left = zoneStart * 100 + "%";
  physicalState = {
    mode: "timing",
    needlePos: 0,
    dir: 1,
    speed: 0.014,
    zoneStart,
    zoneWidth,
    round: 1,
    totalRounds,
  };
  const tick = () => {
    if (!physicalState || physicalState.mode !== "timing") return;
    physicalState.needlePos += physicalState.dir * physicalState.speed;
    if (physicalState.needlePos >= 1) {
      physicalState.needlePos = 1;
      physicalState.dir = -1;
    }
    if (physicalState.needlePos <= 0) {
      physicalState.needlePos = 0;
      physicalState.dir = 1;
    }
    mgNeedle.style.left = "calc(" + physicalState.needlePos * 100 + "% - 2px)";
    physicalRaf = requestAnimationFrame(tick);
  };
  physicalRaf = requestAnimationFrame(tick);
  window.addEventListener("keydown", onPhysicalKey);
}

function startSequence(data) {
  hidePhysicalPanels();
  physicalSequence.classList.remove("hidden");
  const len = data.length || 4;
  const sequence = [];
  for (let i = 0; i < len; i++) sequence.push(ARROWS[Math.floor(Math.random() * ARROWS.length)]);
  mgSeq.textContent = sequence.map((k) => ARROW_LABELS[k]).join(" ");
  physicalState = { mode: "sequence", sequence, step: 0 };
  window.addEventListener("keydown", onPhysicalKey);
}

function startHold(data) {
  hidePhysicalPanels();
  physicalHold.classList.remove("hidden");
  const holdMs = data.holdMs || 2500;
  const zoneStart = 0.15 + Math.random() * 0.55;
  mgHoldZone.style.width = "22%";
  mgHoldZone.style.left = zoneStart * 100 + "%";
  mgHoldFill.style.width = "0%";
  physicalState = { mode: "hold", holding: false, progress: 0, holdMs, zoneStart };
  physicalTimer = setInterval(() => {
    if (!physicalState || physicalState.mode !== "hold") return;
    if (physicalState.holding) {
      physicalState.progress += 50;
      const pct = Math.min(100, (physicalState.progress / physicalState.holdMs) * 100);
      mgHoldFill.style.width = pct + "%";
      if (physicalState.progress >= physicalState.holdMs) finishPhysical(true);
    }
  }, 50);
  window.addEventListener("keydown", onPhysicalKey);
  window.addEventListener("keyup", onPhysicalKeyUp);
}

function startMash(data) {
  hidePhysicalPanels();
  physicalMash.classList.remove("hidden");
  const target = data.target || 18;
  const timeMs = data.timeMs || 9000;
  mgMashTarget.textContent = String(target);
  mgMashCount.textContent = "0";
  mgMashFill.style.width = "0%";
  physicalState = { mode: "mash", target, count: 0, lastMash: 0 };
  physicalTimer = setInterval(() => {
    if (!physicalState || physicalState.mode !== "mash") return;
    physicalState.deadline = physicalState.deadline || Date.now() + timeMs;
    if (Date.now() > physicalState.deadline) finishPhysical(false);
  }, 200);
  window.addEventListener("keydown", onPhysicalKey);
}

function openPhysical(d) {
  tablet.classList.add("hidden");
  hackPanel.classList.add("hidden");
  physicalPanel.classList.remove("hidden");
  physicalTitle.textContent = d.label || "Veiksmas";
  physicalHint.textContent = d.label || "";
  if (d.mode === "timing") startTiming(d.data || {});
  else if (d.mode === "sequence") startSequence(d.data || {});
  else if (d.mode === "hold") startHold(d.data || {});
  else if (d.mode === "mash") startMash(d.data || {});
}

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === "physicalOpen") openPhysical(d);
});

document.getElementById("physicalCancel").onclick = () => {
  stopPhysicalLoop();
  physicalState = null;
  physicalPanel.classList.add("hidden");
  post("physicalCancel", {});
};

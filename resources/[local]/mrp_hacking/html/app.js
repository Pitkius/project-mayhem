const tablet = document.getElementById("tablet");
const hackPanel = document.getElementById("hack");
const hackGrid = document.getElementById("hackGrid");
const hackWire = document.getElementById("hackWire");
const hackWireSvg = document.getElementById("hackWireSvg");
const hackWireNodes = document.getElementById("hackWireNodes");
const hackTrace = document.getElementById("hackTrace");
const hackTraceCanvas = document.getElementById("hackTraceCanvas");
const hackTimer = document.getElementById("hackTimer");
let tabletData = null;
let hackState = null;
let hackInterval = null;
let hackGameInterval = null;
let onTraceKey = null;

function res() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "mrp_hacking";
}

function post(endpoint, data) {
  return fetch(`https://${res()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

window.HackPost = post;

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === "openTablet") {
    tabletData = d.data;
    tablet.classList.remove("hidden");
    hackPanel.classList.add("hidden");
    if (window.TabletUI) {
      TabletUI.open(d.data, { flashTab: d.flashTab, driveSlot: d.driveSlot });
    }
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
      if (d.data.flashDrives) tabletData.flashDrives = d.data.flashDrives;
    }
    if (window.TabletUI) TabletUI.refresh(tabletData);
  }
  if (d.action === "tabletMapRefresh" && tabletData) {
    if (d.robberyMapSites) tabletData.robberyMapSites = d.robberyMapSites;
    if (d.discoveredRobberyLocs) tabletData.discoveredRobberyLocs = d.discoveredRobberyLocs;
    if (window.TabletUI) TabletUI.refresh(tabletData);
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

function stopHackTimer() {
  if (hackInterval) clearInterval(hackInterval);
  hackInterval = null;
  if (hackGameInterval) clearInterval(hackGameInterval);
  hackGameInterval = null;
  if (onTraceKey) {
    window.removeEventListener("keydown", onTraceKey);
    onTraceKey = null;
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function buildHackSequence(steps, cells) {
  const sequence = [];
  while (sequence.length < steps) {
    const n = Math.floor(Math.random() * cells);
    if (sequence.length === 0 || sequence[sequence.length - 1] !== n) sequence.push(n);
  }
  return sequence;
}

async function flashSequence(sequence, flashMs) {
  const onMs = flashMs || 380;
  const offMs = Math.max(120, Math.floor(onMs * 0.45));
  for (const idx of sequence) {
    const cell = hackGrid.querySelector('[data-idx="' + idx + '"]');
    if (cell) cell.classList.add("active");
    await sleep(onMs);
    if (cell) cell.classList.remove("active");
    await sleep(offMs);
  }
}

async function flashPairs(pairs, flashMs) {
  const onMs = flashMs || 340;
  for (const pair of pairs) {
    const cells = pair.map((idx) => hackGrid.querySelector('[data-idx="' + idx + '"]')).filter(Boolean);
    cells.forEach((c) => c.classList.add("active"));
    await sleep(onMs);
    cells.forEach((c) => c.classList.remove("active"));
    await sleep(200);
  }
}

function buildWireNodes(count) {
  const nodes = [];
  const cx = 50;
  const cy = 50;
  const r = 36;
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2 - Math.PI / 2;
    nodes.push({ id: i, x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r });
  }
  return nodes;
}

function wirePos(node) {
  return { x: node.x, y: node.y };
}

function drawWirePath(nodes, path, activeClass) {
  if (!hackWireSvg) return;
  hackWireSvg.innerHTML = "";
  for (let i = 0; i < path.length - 1; i++) {
    const a = nodes[path[i]];
    const b = nodes[path[i + 1]];
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
    line.setAttribute("x1", a.x);
    line.setAttribute("y1", a.y);
    line.setAttribute("x2", b.x);
    line.setAttribute("y2", b.y);
    line.setAttribute("class", activeClass || "wire-line");
    hackWireSvg.appendChild(line);
  }
}

function buildWireDom(nodes) {
  if (!hackWireNodes) return;
  hackWireNodes.innerHTML = "";
  nodes.forEach((n) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "hack-wire-node";
    btn.dataset.idx = String(n.id);
    btn.style.left = n.x + "%";
    btn.style.top = n.y + "%";
    btn.textContent = String(n.id + 1);
    btn.disabled = true;
    btn.onclick = () => onWireNode(n.id);
    hackWireNodes.appendChild(btn);
  });
}

function onWireNode(id) {
  if (!hackState || hackState.mode !== "wire" || hackState.failed) return;
  const expected = hackState.path[hackState.idx];
  const btn = hackWireNodes?.querySelector('[data-idx="' + id + '"]');
  if (id !== expected) {
    if (btn) btn.classList.add("fail");
    return finishHack(false);
  }
  if (btn) btn.classList.add("done");
  hackState.idx++;
  if (hackState.idx >= hackState.path.length) return finishHack(true);
}

async function flashWirePath(nodes, path, flashMs) {
  for (let i = 0; i < path.length; i++) {
    const id = path[i];
    const btn = hackWireNodes?.querySelector('[data-idx="' + id + '"]');
    if (btn) btn.classList.add("active");
    if (i > 0) drawWirePath(nodes, path.slice(0, i + 1), "wire-line flash");
    await sleep(flashMs || 450);
    if (btn) btn.classList.remove("active");
    await sleep(120);
  }
  drawWirePath(nodes, path, "wire-line");
}

async function startWireHack(profile, tierId) {
  const steps = profile.steps || 5;
  const totalMs = profile.timeMs || 14000;
  const flashMs = profile.flashMs || 420;
  const hintEl = document.getElementById("hackHint");
  const nodes = buildWireNodes(Math.max(steps + 2, 6));
  const path = [];
  while (path.length < steps) {
    const n = Math.floor(Math.random() * nodes.length);
    if (path.length === 0 || path[path.length - 1] !== n) path.push(n);
  }
  buildWireDom(nodes);
  hintEl.textContent = "Stebėk circuit kelią…";
  await flashWirePath(nodes, path, flashMs);
  hintEl.textContent = "Jungk mazgus ta pačia tvarka";
  hackState = {
    mode: "wire",
    path,
    idx: 0,
    tierId,
    failed: false,
    deadline: Date.now() + totalMs,
  };
  hackWireNodes?.querySelectorAll(".hack-wire-node").forEach((b) => {
    b.disabled = false;
  });
  beginHackInput(hackState, totalMs);
}

function buildTracePath(steps) {
  const pts = [];
  const w = 360;
  const h = 220;
  let x = 30;
  let y = h / 2;
  for (let i = 0; i < steps * 8; i++) {
    x += (w - 60) / (steps * 8);
    y = h / 2 + Math.sin(i * 0.55) * (38 + Math.random() * 22);
    pts.push({ x, y });
  }
  return pts;
}

function drawTracePath(ctx, pts, progress, width) {
  if (!ctx || !pts.length) return;
  ctx.clearRect(0, 0, 360, 220);
  ctx.strokeStyle = "rgba(34, 211, 238, 0.18)";
  ctx.lineWidth = 18 + (width || 0.1) * 80;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.stroke();
  ctx.strokeStyle = "rgba(34, 211, 238, 0.35)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.stroke();
  ctx.strokeStyle = "rgba(34, 197, 94, 0.9)";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  const end = Math.min(pts.length - 1, Math.floor(progress * (pts.length - 1)));
  for (let i = 1; i <= end; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.stroke();
}

function startTraceHack(profile, tierId) {
  const steps = profile.steps || 5;
  const totalMs = profile.timeMs || 16000;
  const speed = profile.traceSpeed || 0.004;
  const width = profile.traceWidth || 0.1;
  const hintEl = document.getElementById("hackHint");
  const ctx = hackTraceCanvas?.getContext("2d");
  const path = buildTracePath(steps);
  hintEl.textContent = "Sek signalą — A/D koreguok, laikykis linijos";
  hackState = {
    mode: "trace",
    path,
    progress: 0,
    offset: 0,
    speed,
    width,
    tierId,
    failed: false,
    deadline: Date.now() + totalMs,
  };
  drawTracePath(ctx, path, 0, width);
  beginHackInput(hackState, totalMs);
  onTraceKey = (e) => {
    if (!hackState || hackState.mode !== "trace") return;
    if (e.code === "KeyA" || e.code === "ArrowLeft") {
      e.preventDefault();
      hackState.offset -= 0.014;
    }
    if (e.code === "KeyD" || e.code === "ArrowRight") {
      e.preventDefault();
      hackState.offset += 0.014;
    }
    hackState.offset = Math.max(-0.28, Math.min(0.28, hackState.offset));
  };
  window.addEventListener("keydown", onTraceKey);
  hackGameInterval = setInterval(() => {
    if (!hackState || hackState.mode !== "trace") return;
    hackState.progress = Math.min(1, hackState.progress + hackState.speed);
    hackState.offset += (Math.random() - 0.5) * 0.006;
    drawTracePath(ctx, hackState.path, hackState.progress, hackState.width);
    const idx = Math.min(hackState.path.length - 1, Math.floor(hackState.progress * (hackState.path.length - 1)));
    const target = hackState.path[idx];
    const dot = document.getElementById("hackTraceDot");
    if (target && dot) {
      dot.style.left = target.x + hackState.offset * 42 + "px";
      dot.style.top = target.y + "px";
    }
    if (Math.abs(hackState.offset) > hackState.width) return finishHack(false);
    if (hackState.progress >= 1) finishHack(true);
  }, 40);
}

function buildHackGrid(gridN) {
  const cells = gridN * gridN;
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
  return cells;
}

function beginHackInput(hackState, totalMs) {
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

async function startHack(profile, tierId) {
  stopHackTimer();
  const mode = profile.mode || "sequence";
  const steps = profile.steps || 5;
  const gridN = profile.grid || 4;
  const totalMs = profile.timeMs || 12000;
  const flashMs = profile.flashMs || 380;
  const hintEl = document.getElementById("hackHint");

  if (mode === "wire") {
    hackGrid?.classList.add("hidden");
    hackWire?.classList.remove("hidden");
    hackTrace?.classList.add("hidden");
    return startWireHack(profile, tierId);
  }
  if (mode === "trace") {
    hackGrid?.classList.add("hidden");
    hackWire?.classList.add("hidden");
    hackTrace?.classList.remove("hidden");
    return startTraceHack(profile, tierId);
  }
  hackGrid?.classList.remove("hidden");
  hackWire?.classList.add("hidden");
  hackTrace?.classList.add("hidden");

  const cells = buildHackGrid(gridN);
  const sequence = buildHackSequence(steps, cells);

  if (mode === "reverse") {
    hintEl.textContent = "Stebėk seką (atbuline tvarka)…";
    await flashSequence(sequence, flashMs);
    hintEl.textContent = "Spausk langelius ATGALINE tvarka";
    hackState = {
      mode,
      sequence: sequence.slice().reverse(),
      idx: 0,
      tierId,
      failed: false,
      deadline: Date.now() + totalMs,
    };
    beginHackInput(hackState, totalMs);
    return;
  }

  if (mode === "pairs") {
    const pairs = [];
    const seqCopy = sequence.slice();
    while (seqCopy.length >= 2) {
      pairs.push([seqCopy.shift(), seqCopy.shift()]);
    }
    if (seqCopy.length) pairs.push([seqCopy[0], seqCopy[0]]);
    hintEl.textContent = "Stebėk poras…";
    await flashPairs(pairs, flashMs);
    hintEl.textContent = "Spausk poras ta pačia tvarka";
    hackState = {
      mode,
      pairs,
      pairIdx: 0,
      pairStep: 0,
      tierId,
      failed: false,
      deadline: Date.now() + totalMs,
    };
    beginHackInput(hackState, totalMs);
    return;
  }

  if (mode === "code") {
    const code = sequence.map((i) => (i % 10) + 1);
    hintEl.textContent = "Kodas: " + code.join(" - ");
    await sleep(1400 + code.length * 320);
    hintEl.textContent = "Įvesk skaičius ta tvarka (langeliai 1–" + Math.min(10, cells) + ")";
    hackState = {
      mode,
      code,
      idx: 0,
      tierId,
      failed: false,
      deadline: Date.now() + totalMs,
    };
    beginHackInput(hackState, totalMs);
    return;
  }

  hintEl.textContent = "Stebėk seką…";
  await flashSequence(sequence, flashMs);
  hintEl.textContent = "Pakartok seką";
  hackState = {
    mode: "sequence",
    sequence,
    idx: 0,
    tierId,
    failed: false,
    deadline: Date.now() + totalMs,
  };
  beginHackInput(hackState, totalMs);
}

function onCell(i) {
  if (!hackState || hackState.failed) return;
  const cell = hackGrid.querySelector('[data-idx="' + i + '"]');

  if (hackState.mode === "pairs") {
    const pair = hackState.pairs[hackState.pairIdx];
    if (!pair) return finishHack(true);
    const expected = pair[hackState.pairStep];
    if (i !== expected) {
      if (cell) cell.classList.add("fail");
      return finishHack(false);
    }
    if (cell) cell.classList.add("done");
    hackState.pairStep++;
    if (hackState.pairStep >= pair.length) {
      hackState.pairIdx++;
      hackState.pairStep = 0;
    }
    if (hackState.pairIdx >= hackState.pairs.length) return finishHack(true);
    return;
  }

  if (hackState.mode === "code") {
    const digit = (i % 10) + 1;
    const expected = hackState.code[hackState.idx];
    if (digit !== expected) {
      if (cell) cell.classList.add("fail");
      return finishHack(false);
    }
    if (cell) cell.classList.add("done");
    hackState.idx++;
    if (hackState.idx >= hackState.code.length) return finishHack(true);
    return;
  }

  const expected = hackState.sequence[hackState.idx];
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
const physicalDrill = document.getElementById("physicalDrill");
const drillStageDots = document.getElementById("drillStageDots");
const drillGreenZone = document.getElementById("drillGreenZone");
const drillNeedle = document.getElementById("drillNeedle");
const drillTempVal = document.getElementById("drillTempVal");
const drillPressVal = document.getElementById("drillPressVal");
const drillHealthVal = document.getElementById("drillHealthVal");
const drillDepthVal = document.getElementById("drillDepthVal");
const drillTempBar = document.getElementById("drillTempBar");
const drillPressBar = document.getElementById("drillPressBar");
const drillHealthBar = document.getElementById("drillHealthBar");
const drillDepthBarPro = document.getElementById("drillDepthBarPro");
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
  [physicalTiming, physicalSequence, physicalHold, physicalMash, physicalDrill].forEach((el) => el?.classList.add("hidden"));
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
  physicalPanel.classList.remove("physical-drill-fs");
  physicalPanel.classList.add("hidden");
  post("physicalResult", { success, mode });
}

function onPhysicalKeyUp(e) {
  if (!physicalState) return;
  if (physicalState.mode === "hold" && e.code === "Space") physicalState.holding = false;
  if (physicalState.mode === "drill" && physicalState.keys) {
    if (e.code === "KeyW") physicalState.keys.w = false;
    if (e.code === "KeyS") physicalState.keys.s = false;
    if (e.code === "KeyA") physicalState.keys.a = false;
    if (e.code === "KeyD") physicalState.keys.d = false;
  }
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

  if (physicalState.mode === "drill") {
    if (e.code === "KeyW" || e.code === "KeyS" || e.code === "KeyA" || e.code === "KeyD") {
      e.preventDefault();
      if (e.code === "KeyW") physicalState.keys.w = true;
      if (e.code === "KeyS") physicalState.keys.s = true;
      if (e.code === "KeyA") physicalState.keys.a = true;
      if (e.code === "KeyD") physicalState.keys.d = true;
    }
  }
}

function renderDrillStageDots(stage, total) {
  if (!drillStageDots) return;
  drillStageDots.innerHTML = "";
  for (let i = 0; i < total; i++) {
    const dot = document.createElement("span");
    dot.className = "drill-dot" + (i < stage ? " done" : i === stage ? " active" : "");
    drillStageDots.appendChild(dot);
  }
}

function updateDrillUI(st) {
  if (!st) return;
  const temp = Math.round(st.temp);
  const press = Math.round(st.pressure);
  const health = Math.round(st.health);
  const depth = Math.round(st.depth);
  if (drillTempVal) drillTempVal.textContent = temp + "°C";
  if (drillPressVal) drillPressVal.textContent = press + "%";
  if (drillHealthVal) drillHealthVal.textContent = health + "%";
  if (drillDepthVal) drillDepthVal.textContent = depth + "%";
  if (drillTempBar) {
    drillTempBar.style.width = temp + "%";
    drillTempBar.parentElement?.classList.toggle("warn", temp > 75);
    drillTempBar.parentElement?.classList.toggle("danger", temp > 90);
  }
  if (drillPressBar) drillPressBar.style.width = press + "%";
  if (drillHealthBar) drillHealthBar.style.width = health + "%";
  if (drillDepthBarPro) drillDepthBarPro.style.width = depth + "%";
  if (drillNeedle) drillNeedle.style.left = st.align * 100 + "%";
  if (drillGreenZone) {
    drillGreenZone.style.width = st.greenW * 100 + "%";
    drillGreenZone.style.left = (st.greenCenter - st.greenW / 2) * 100 + "%";
  }
}

function startDrill(data) {
  hidePhysicalPanels();
  physicalPanel.classList.add("physical-drill-fs");
  physicalTitle.textContent = "GRĄŽIMAS";
  physicalHint.textContent = "";
  physicalDrill.classList.remove("hidden");
  const stages = data.stages || 5;
  const target = data.depthTarget || 100;
  const greenW = 0.16 + Math.random() * 0.06;
  const greenCenter = 0.25 + Math.random() * 0.5;
  renderDrillStageDots(0, stages);
  physicalState = {
    mode: "drill",
    depth: 0,
    temp: 28,
    pressure: 48,
    health: 100,
    power: 48,
    align: 0.5,
    greenCenter,
    greenW,
    keys: { w: false, s: false, a: false, d: false },
    stage: 0,
    stages,
    target,
    deadline: Date.now() + (data.timeMs || 55000),
  };
  updateDrillUI(physicalState);
  physicalTimer = setInterval(() => {
    if (!physicalState || physicalState.mode !== "drill") return;
    const st = physicalState;
    if (Date.now() > st.deadline) return finishPhysical(false);
    const drilling = st.keys.w;
    if (st.keys.w) st.power = Math.min(100, st.power + 1.6);
    if (st.keys.s) {
      st.power = Math.max(0, st.power - 2.4);
      st.temp = Math.max(18, st.temp - 1.05);
    }
    if (!st.keys.w && !st.keys.s) st.power = Math.max(35, st.power - 0.35);
    if (st.keys.a) st.align = Math.max(0.02, st.align - 0.032);
    if (st.keys.d) st.align = Math.min(0.98, st.align + 0.032);
    if (drilling) st.align += (Math.random() - 0.5) * 0.004;
    st.pressure = Math.max(0, Math.min(100, st.pressure + (st.power - 50) * 0.035));
    const inGreen = Math.abs(st.align - st.greenCenter) <= st.greenW / 2;
    const goodPress = st.pressure >= 36 && st.pressure <= 74;
    if (drilling && inGreen && goodPress) {
      st.depth = Math.min(st.target, st.depth + 0.42 + st.power * 0.0035);
      st.temp = Math.max(18, st.temp - 0.55);
    } else if (drilling) {
      st.temp = Math.min(100, st.temp + (inGreen ? 0.35 : 0.85));
      if (!inGreen) st.health = Math.max(0, st.health - 0.45);
    } else {
      st.temp = Math.max(18, st.temp - 0.65);
    }
    if (drilling && st.power > 82) st.temp = Math.min(100, st.temp + 0.35);
    if (st.temp > 90) st.health = Math.max(0, st.health - 0.28);
    if (st.temp >= 100 || st.health <= 0) return finishPhysical(false);
    const stageSize = st.target / st.stages;
    if (st.depth >= stageSize * (st.stage + 1) && st.stage < st.stages - 1) {
      st.stage += 1;
      st.greenCenter = 0.2 + Math.random() * 0.6;
      st.greenW = 0.14 + Math.random() * 0.05;
      renderDrillStageDots(st.stage, st.stages);
    }
    updateDrillUI(st);
    if (st.depth >= st.target) finishPhysical(true);
  }, 50);
  window.addEventListener("keydown", onPhysicalKey);
  window.addEventListener("keyup", onPhysicalKeyUp);
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
  if (d.mode === "drill") {
    startDrill(d.data || {});
    return;
  }
  physicalPanel.classList.remove("physical-drill-fs");
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
  physicalPanel.classList.remove("physical-drill-fs");
  physicalPanel.classList.add("hidden");
  post("physicalCancel", {});
};

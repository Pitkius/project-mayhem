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
    const div = document.createElement("div");
    div.className = "card";
    div.innerHTML =
      "<strong>" + t.label + '</strong><div class="muted">Min OS: ' + t.minOs + " • " + t.minTablet + "</div>";
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

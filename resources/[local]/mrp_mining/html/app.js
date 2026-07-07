const root = document.getElementById("mining-root");
const miningPanel = document.getElementById("mining-panel");
const sellPanel = document.getElementById("sell-panel");
const marker = document.getElementById("mining-marker");
const zone = document.getElementById("mining-zone");
const hitsEl = document.getElementById("mining-hits");
const neededEl = document.getElementById("mining-needed");
const timeEl = document.getElementById("mining-time");

let miningState = null;
let rafId = null;
let lastTs = 0;

function post(name, data) {
  return fetch(`https://mrp_mining/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  });
}

function zoneBounds() {
  const zl = parseFloat(zone.style.left) || 40;
  const zw = parseFloat(zone.style.width) || 18;
  return { start: zl, end: zl + zw };
}

function markerPos() {
  return parseFloat(marker.style.left) || 0;
}

function inZone() {
  const m = markerPos();
  const b = zoneBounds();
  return m >= b.start && m <= b.end;
}

function tick(ts) {
  if (!miningState) return;
  const dt = lastTs ? (ts - lastTs) / 1000 : 0;
  lastTs = ts;

  miningState.pos += miningState.dir * miningState.speed * dt * 100;
  if (miningState.pos >= 100) {
    miningState.pos = 100;
    miningState.dir = -1;
  } else if (miningState.pos <= 0) {
    miningState.pos = 0;
    miningState.dir = 1;
  }

  marker.style.left = `${miningState.pos}%`;

  miningState.timeLeft -= dt;
  timeEl.textContent = Math.max(0, Math.ceil(miningState.timeLeft));
  if (miningState.timeLeft <= 0) {
    endMining(false);
    return;
  }

  rafId = requestAnimationFrame(tick);
}

function tryHit() {
  if (!miningState) return;
  if (inZone()) {
    miningState.hits += 1;
    hitsEl.textContent = miningState.hits;
    zone.style.width = `${Math.max(12, 18 - miningState.hits)}%`;
    if (miningState.hits >= miningState.needed) {
      endMining(true);
    }
  } else {
    miningState.misses = (miningState.misses || 0) + 1;
    if (miningState.misses >= 3) endMining(false);
  }
}

function endMining(success) {
  if (!miningState) return;
  cancelAnimationFrame(rafId);
  rafId = null;
  miningPanel.classList.add(success ? "success" : "fail");
  const payload = { success };
  miningState = null;
  setTimeout(() => {
    root.classList.remove("active");
    root.classList.add("hidden");
    miningPanel.classList.remove("success", "fail");
    post("miningResult", payload);
  }, success ? 400 : 600);
}

function startMining(data) {
  miningState = {
    hits: 0,
    needed: data.hits || 5,
    timeLeft: data.time || 12,
    speed: data.speed || 0.85,
    pos: 0,
    dir: 1,
    misses: 0,
  };
  neededEl.textContent = miningState.needed;
  hitsEl.textContent = "0";
  timeEl.textContent = miningState.timeLeft;
  zone.style.left = `${30 + Math.random() * 40}%`;
  zone.style.width = "18%";
  marker.style.left = "0%";
  miningPanel.classList.remove("hidden", "success", "fail");
  sellPanel.classList.add("hidden");
  root.classList.remove("hidden");
  root.classList.add("active");
  lastTs = 0;
  rafId = requestAnimationFrame(tick);
}

function renderSellList(items) {
  const list = document.getElementById("sell-list");
  list.innerHTML = "";
  if (!items.length) {
    list.innerHTML = '<div class="sell-row"><div class="sell-row-info"><div class="sell-row-name">Neturi ką parduoti</div><div class="sell-row-meta">Iškask rūdų karjere</div></div></div>';
    document.getElementById("sell-total").textContent = "$0";
    return;
  }
  let total = 0;
  items.forEach((row) => {
    total += row.total || 0;
    const el = document.createElement("div");
    el.className = "sell-row";
    el.innerHTML = `
      <div class="sell-row-info">
        <div class="sell-row-name">${row.label}</div>
        <div class="sell-row-meta">${row.count} vnt. × $${row.price} = $${row.total}</div>
      </div>
      <button type="button" class="sell-row-btn" data-item="${row.item}" ${row.count < 1 ? "disabled" : ""}>Parduoti</button>
    `;
    list.appendChild(el);
  });
  document.getElementById("sell-total").textContent = `$${total}`;
  list.querySelectorAll(".sell-row-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      post("sellItem", { item: btn.dataset.item });
    });
  });
}

function openSell(data) {
  miningPanel.classList.add("hidden");
  sellPanel.classList.remove("hidden");
  root.classList.remove("hidden");
  root.classList.add("active");
  renderSellList(data.items || []);
}

function closeAll() {
  cancelAnimationFrame(rafId);
  miningState = null;
  root.classList.add("hidden");
  root.classList.remove("active");
  post("closeUi");
}

document.getElementById("mining-close").addEventListener("click", () => {
  if (miningState) endMining(false);
  else closeAll();
});
document.getElementById("sell-close").addEventListener("click", closeAll);
document.getElementById("sell-all-btn").addEventListener("click", () => post("sellAll"));

document.addEventListener("keydown", (e) => {
  if (e.code === "Space" && miningState) {
    e.preventDefault();
    tryHit();
  }
  if (e.code === "Escape") {
    if (miningState) endMining(false);
    else closeAll();
  }
});

document.addEventListener("mousedown", (e) => {
  if (e.button === 0 && miningState) tryHit();
});

window.addEventListener("message", (ev) => {
  const d = ev.data;
  if (!d || !d.action) return;
  if (d.action === "startMining") startMining(d);
  if (d.action === "openSell") openSell(d);
  if (d.action === "close") closeAll();
  if (d.action === "sellRefresh") renderSellList(d.items || []);
});

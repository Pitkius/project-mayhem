const app = document.getElementById("app");
const productList = document.getElementById("productList");
const emptyPick = document.getElementById("emptyPick");
const detailPanel = document.getElementById("detailPanel");
const btnCraft = document.getElementById("btnCraft");
const mgSkill = document.getElementById("mgSkill");
const mgAdvanced = document.getElementById("mgAdvanced");

let state = { products: [], selectedId: null, isWeaponMode: false };

function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
}

function canCraftProduct(p) {
  if (!p || !p.ingredients) return false;
  return p.ingredients.every((i) => i.missing <= 0);
}

function renderList() {
  productList.innerHTML = "";
  state.products.forEach((p) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "prod-item" + (state.selectedId === p.id ? " active" : "");
    btn.innerHTML = `<strong>${p.label}</strong><small>${p.levelLabel || ""} · ${p.risk || ""}</small>`;
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
  document.getElementById("prodLevel").textContent = p.levelLabel || `Lygis ${p.level}`;
  document.getElementById("prodRisk").textContent = `Rizika: ${p.risk || "—"}`;
  document.getElementById("prodTime").textContent = `${p.craftTimeSec || 0} sek.`;
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
  btnCraft.disabled = !canCraftProduct(p);
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
    app.classList.add("hidden");
    mgSkill.classList.add("hidden");
    mgAdvanced.classList.add("hidden");
  }
  if (msg.action === "minigameSkill") {
    runSkillGame();
  }
  if (msg.action === "minigameAdvanced") {
    runAdvancedGame(msg.data && msg.data.rounds ? msg.data.rounds : 3);
  }
});

document.getElementById("btnClose").onclick = () => post("close");
btnCraft.onclick = () => {
  if (!state.selectedId) return;
  post("craft", { productId: state.selectedId });
};

function runSkillGame() {
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
  const onKey = (ev) => {
    if (done || ev.code !== "Space") return;
    done = true;
    clearInterval(iv);
    window.removeEventListener("keydown", onKey);
    mgSkill.classList.add("hidden");
    const zl = zoneLeft;
    const zh = zl + 28;
    const success = pos >= zl && pos <= zh;
    post("skillResult", { success });
  };
  window.addEventListener("keydown", onKey);
}

function runAdvancedGame(rounds) {
  mgAdvanced.classList.remove("hidden");
  const seqEl = document.getElementById("mgSeq");
  const keys = ["W", "A", "S", "D"];
  const seq = [];
  for (let i = 0; i < rounds; i++) seq.push(keys[Math.floor(Math.random() * keys.length)]);
  let idx = 0;
  seqEl.textContent = seq.join(" → ");
  document.getElementById("mgAdvLabel").textContent = `Įvesk seką (${idx + 1}/${rounds})`;

  const buttons = mgAdvanced.querySelectorAll(".mg-keys button");
  buttons.forEach((b) => {
    b.classList.remove("hit");
    b.onclick = () => {
      if (b.dataset.key !== seq[idx]) {
        mgAdvanced.classList.add("hidden");
        return post("advancedResult", { success: false });
      }
      b.classList.add("hit");
      idx += 1;
      if (idx >= seq.length) {
        mgAdvanced.classList.add("hidden");
        return post("advancedResult", { success: true });
      }
      document.getElementById("mgAdvLabel").textContent = `Įvesk seką (${idx + 1}/${rounds})`;
    };
  });
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !mgSkill.classList.contains("hidden")) {
    mgSkill.classList.add("hidden");
    post("skillResult", { success: false });
  }
});

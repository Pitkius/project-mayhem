const app = document.getElementById("app");
const contractList = document.getElementById("contractList");
const exchangeList = document.getElementById("exchangeList");
const contractDetail = document.getElementById("contractDetail");
const btnAccept = document.getElementById("btnAccept");
const registerOverlay = document.getElementById("registerOverlay");

let state = { data: null, selected: null };

function resourceName() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "fivempro_trucking";
}

function nui(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json());
}

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

function fmtMoney(n) {
  return "$" + Number(n || 0).toLocaleString("lt-LT");
}

function stars(n) {
  n = Math.max(1, Math.min(5, Number(n) || 1));
  return "★".repeat(n) + "☆".repeat(5 - n);
}

function normCoord(x, y, map) {
  const minX = map.minX ?? -4000;
  const maxX = map.maxX ?? 4500;
  const minY = map.minY ?? -4000;
  const maxY = map.maxY ?? 6625;
  return {
    px: ((x - minX) / (maxX - minX)) * 100,
    py: (1 - (y - minY) / (maxY - minY)) * 100,
  };
}

function renderRouteMap(contract) {
  const el = document.getElementById("routeMap");
  if (!contract || !el) {
    if (el) el.innerHTML = "";
    return;
  }
  const map = state.data?.map || {};
  const a = normCoord(contract.pickup.x, contract.pickup.y, map);
  const b = normCoord(contract.delivery.x, contract.delivery.y, map);
  el.innerHTML = `
    <svg viewBox="0 0 100 100" preserveAspectRatio="none">
      <defs>
        <linearGradient id="routeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#a78bfa"/>
          <stop offset="100%" stop-color="#fb923c"/>
        </linearGradient>
      </defs>
      <line x1="${a.px}" y1="${a.py}" x2="${b.px}" y2="${b.py}" stroke="url(#routeGrad)" stroke-width="1.2" stroke-linecap="round"/>
      <circle cx="${a.px}" cy="${a.py}" r="2.2" fill="#fff" stroke="#0f0e14" stroke-width="0.4"/>
      <circle cx="${b.px}" cy="${b.py}" r="2.4" fill="#a78bfa" stroke="#fff" stroke-width="0.35"/>
    </svg>`;
}

function renderContractItem(c, selected) {
  const illegal = c.illegal ? '<span class="tag tag-illegal">NELEGALU</span>' : "";
  return `
    <div class="contract-item${selected ? " selected" : ""}" data-id="${esc(c.id)}">
      <div>
        <div><strong>${esc(c.cargoLabel)}</strong> ${illegal}</div>
        <div class="meta">${esc(c.pickupLabel)} → ${esc(c.deliveryLabel)}</div>
        <div class="meta">${esc(c.distanceKm)} km · ${esc(c.timeLimitMin)} min · <span class="risk-${esc(c.risk)}">${esc(c.risk)}</span></div>
      </div>
      <div class="pay">${fmtMoney(c.pay)}</div>
    </div>`;
}

function selectContract(c) {
  state.selected = c;
  btnAccept.disabled = !c;
  if (!c) {
    contractDetail.classList.add("empty");
    contractDetail.textContent = "Pasirinkite kontraktą";
    renderRouteMap(null);
    return;
  }
  contractDetail.classList.remove("empty");
  contractDetail.innerHTML = `
    <div class="detail-row"><span>Krovinys</span><strong>${esc(c.cargoLabel)}</strong></div>
    <div class="detail-row"><span>Iš</span><span>${esc(c.pickupLabel)}</span></div>
    <div class="detail-row"><span>Į</span><span>${esc(c.deliveryLabel)}</span></div>
    <div class="detail-row"><span>Atstumas</span><span>${esc(c.distanceKm)} km</span></div>
    <div class="detail-row"><span>Laikas</span><span>${esc(c.timeLimitMin)} min</span></div>
    <div class="detail-row"><span>Rizika</span><span class="risk-${esc(c.risk)}">${esc(c.risk)}</span></div>
    <div class="detail-row"><span>Atlygis</span><strong>${fmtMoney(c.pay)}</strong></div>`;
  renderRouteMap(c);
  document.querySelectorAll(".contract-item").forEach((el) => {
    el.classList.toggle("selected", el.dataset.id === c.id);
  });
}

function bindContractClicks(root) {
  root.querySelectorAll(".contract-item").forEach((el) => {
    el.addEventListener("click", () => {
      const id = el.dataset.id;
      const c = (state.data?.contracts || []).find((x) => x.id === id);
      selectContract(c || null);
    });
  });
}

function renderProfile() {
  const d = state.data;
  if (!d) return;
  const p = d.profile || {};
  document.getElementById("profileName").textContent = d.playerName || "Vairuotojas";
  document.getElementById("profileRank").textContent = `Level ${p.level || 1} Driver`;
  const next = p.xpNext || 400;
  const cur = p.xp || 0;
  const prev = (d.profile && d.profile.level > 1) ? 0 : 0;
  const pct = next ? Math.min(100, ((cur - prev) / (next - prev)) * 100) : 100;
  document.getElementById("xpFill").style.width = `${Math.max(0, pct)}%`;
  document.getElementById("xpLabel").textContent = `XP: ${cur.toLocaleString("lt-LT")} / ${next ? next.toLocaleString("lt-LT") : "MAX"}`;
  document.getElementById("repStars").textContent = stars(p.stars);
  const pill = document.getElementById("companyPill");
  if (d.company) {
    pill.classList.remove("hidden");
    pill.textContent = d.company.name;
    document.getElementById("companyBalance").classList.remove("hidden");
    document.getElementById("companyBalance").textContent = fmtMoney(d.company.balance);
  } else {
    pill.classList.add("hidden");
    document.getElementById("companyBalance").classList.add("hidden");
  }
  const isReg = p.registered === true || p.registered === 1 || p.registered === "1";
  registerOverlay.classList.toggle("hidden", isReg);
  if (isReg) setRegisterStatus("");
}

function renderContracts() {
  const list = state.data?.contracts || [];
  contractList.innerHTML = list.map((c) => renderContractItem(c, state.selected?.id === c.id)).join("");
  exchangeList.innerHTML = list.map((c) => renderContractItem(c, false)).join("");
  bindContractClicks(contractList);
  bindContractClicks(exchangeList);
  if (state.selected) selectContract(state.selected);
  else selectContract(list[0] || null);
}

function renderFleet() {
  const grid = document.getElementById("fleetGrid");
  const fleet = state.data?.fleet || [];
  const shop = state.data?.fleetShop || [];
  if (!grid) return;
  let html = fleet.map((v) => `
    <div class="fleet-card">
      <h4>${esc(v.label || v.model)}</h4>
      <div class="meta">${esc(v.plate)} · ${esc(v.status)}</div>
      <div class="meta">Būklė ${esc(v.condition_pct)}%</div>
      <div class="bar"><span style="width:${esc(v.condition_pct)}%"></span></div>
      <div class="meta">Kuras ${esc(v.fuel_pct)}%</div>
      <div class="bar"><span style="width:${esc(v.fuel_pct)}%"></span></div>
    </div>`).join("");
  if (state.data?.company?.isOwner) {
    html += shop.map((s) => `
      <div class="fleet-card">
        <h4>Pirkti: ${esc(s.model)}</h4>
        <div class="meta">${fmtMoney(s.price)}</div>
        <button type="button" class="btn-secondary buy-fleet" data-model="${esc(s.model)}">Pirkti</button>
      </div>`).join("");
  }
  grid.innerHTML = html || '<div class="stat-card">Transporto parkas tuščias.</div>';
  grid.querySelectorAll(".buy-fleet").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const res = await nui("trucking:buyFleet", { model: btn.dataset.model });
      if (res?.ok && res.dashboard) { state.data = res.dashboard; renderAll(); }
    });
  });
}

function renderCompany() {
  const el = document.getElementById("companyPanel");
  const d = state.data;
  const p = d?.profile || {};
  if (!el) return;
  if (d?.company) {
    el.innerHTML = `
      <div class="company-card">
        <h3>${esc(d.company.name)}</h3>
        <p>Balansas: <strong>${fmtMoney(d.company.balance)}</strong></p>
        <p>Pristatymai: ${esc(d.company.total_deliveries)} · Pajamos: ${fmtMoney(d.company.total_revenue)}</p>
        <p>Darbuotojai: ${(d.members || []).length}</p>
      </div>`;
    return;
  }
  if ((p.level || 1) < (d?.companyMinLevel || 5)) {
    el.innerHTML = `<div class="company-card">Įmonę galima įkurti nuo ${d?.companyMinLevel || 5} lygio.</div>`;
    return;
  }
  el.innerHTML = `
    <div class="company-card">
      <h3>Įkurti transporto įmonę</h3>
      <p>Kaina: ${fmtMoney(d?.companyCreateCost || 50000)}</p>
      <div class="company-form">
        <input id="companyNameInput" placeholder="Pvz. Baltic Logistics" maxlength="48" />
        <button type="button" class="btn-secondary" id="btnCreateCompany">Įkurti</button>
      </div>
    </div>`;
  document.getElementById("btnCreateCompany")?.addEventListener("click", async () => {
    const name = document.getElementById("companyNameInput")?.value || "";
    const res = await nui("trucking:createCompany", { name });
    if (res?.ok && res.dashboard) { state.data = res.dashboard; renderAll(); }
  });
}

function renderStats() {
  const p = state.data?.profile || {};
  document.getElementById("statsPanel").innerHTML = `
    <div class="stat-card"><div>Lygis</div><strong>Level ${esc(p.level)}</strong></div>
    <div class="stat-card"><div>XP</div><strong>${esc(p.xp)}</strong></div>
    <div class="stat-card"><div>Reputacija</div><strong>${stars(p.stars)}</strong></div>
    <div class="stat-card"><div>Pristatymai</div><strong>${esc(p.total_deliveries)}</strong></div>
    <div class="stat-card"><div>Uždirbta</div><strong>${fmtMoney(p.total_earned)}</strong></div>
    <div class="stat-card"><div>Licencijos</div><strong>${p.licenses?.heavy_truck ? "Heavy Truck ✓" : "—"}</strong></div>`;
}

function renderLeaderboard() {
  const rows = state.data?.leaderboard || [];
  document.getElementById("leaderboardPanel").innerHTML = rows.length
    ? rows.map((r, i) => `
      <div class="lb-row">
        <strong>#${i + 1} ${esc(r.name)}</strong>
        <div class="meta">${fmtMoney(r.total_revenue)} · ${esc(r.total_deliveries)} kroviniai · ${esc(r.members)} darbuotojai</div>
      </div>`).join("")
    : '<div class="stat-card">Dar nėra įmonių statistikos.</div>';
}

function renderAll() {
  renderProfile();
  renderContracts();
  renderFleet();
  renderCompany();
  renderStats();
  renderLeaderboard();
  const now = new Date();
  document.getElementById("clock").textContent = now.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
}

function setTab(tab) {
  document.querySelectorAll(".nav-btn").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));
  document.querySelectorAll(".tab").forEach((p) => p.classList.toggle("active", p.dataset.panel === tab));
  const titles = {
    market: ["KONTRAKTŲ RINKA", "Pasirinkite kitą krovinio pristatymą"],
    exchange: ["KROVINIŲ BIRŽA", "CargoNet aktyvūs kontraktai"],
    fleet: ["TRANSPORTO PARKAS", "Jūsų sunkvežimiai"],
    company: ["ĮMONĖS VALDYMAS", "Logistikos kompanija"],
    stats: ["VAIRUOTOJO STATISTIKA", "Progresija ir pasiekimai"],
    leaderboard: ["TOP LOGISTICS", "Geriausios serverio įmonės"],
  };
  const t = titles[tab] || titles.market;
  document.getElementById("pageTitle").textContent = t[0];
  document.getElementById("pageSub").textContent = t[1];
}

document.querySelectorAll(".nav-btn").forEach((btn) => {
  btn.addEventListener("click", () => setTab(btn.dataset.tab));
});

document.getElementById("btnClose").addEventListener("click", () => nui("trucking:close"));
function setRegisterStatus(msg, type) {
  const el = document.getElementById("registerStatus");
  if (!el) return;
  if (!msg) {
    el.classList.add("hidden");
    el.textContent = "";
    return;
  }
  el.textContent = msg;
  el.className = "register-status " + (type || "");
}

document.getElementById("btnRegister").addEventListener("click", async () => {
  const btn = document.getElementById("btnRegister");
  btn.disabled = true;
  setRegisterStatus("Registruojama…", "");
  const res = await nui("trucking:register");
  btn.disabled = false;
  if (res?.ok && res.dashboard) {
    state.data = res.dashboard;
    renderAll();
    setRegisterStatus("");
    return;
  }
  setRegisterStatus(res?.reason || "Registracija nepavyko. Bandyk dar kartą.", "err");
});
btnAccept.addEventListener("click", async () => {
  if (!state.selected) return;
  await nui("trucking:acceptContract", { contractId: state.selected.id });
});

window.addEventListener("message", (event) => {
  const msg = event.data;
  if (!msg) return;
  if (msg.action === "open") {
    state.data = msg.data;
    state.selected = null;
    app.classList.remove("hidden");
    renderAll();
    setTab(msg.mode === "phone" ? "exchange" : "market");
  }
  if (msg.action === "close") {
    app.classList.add("hidden");
  }
});

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") nui("trucking:close");
});

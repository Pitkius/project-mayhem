const app = document.getElementById("app");
const contractList = document.getElementById("contractList");
const exchangeList = document.getElementById("exchangeList");
const contractDetail = document.getElementById("contractDetail");
const btnAccept = document.getElementById("btnAccept");
const registerOverlay = document.getElementById("registerOverlay");

let state = { data: null, selected: null };
let routeRequestId = 0;

function showToast(msg, type) {
  const el = document.getElementById("toast");
  if (!el) return;
  if (!msg) {
    el.classList.add("hidden");
    el.textContent = "";
    return;
  }
  el.textContent = msg;
  el.className = "toast " + (type || "");
  el.classList.remove("hidden");
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => showToast(""), 4200);
}

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
  const rangeX = maxX - minX || 1;
  const rangeY = maxY - minY || 1;
  return {
    px: Math.max(2, Math.min(98, ((Number(x) - minX) / rangeX) * 100)),
    py: Math.max(2, Math.min(98, (1 - (Number(y) - minY) / rangeY) * 100)),
  };
}

function mapImageUrl(map) {
  const raw = String(map?.imageFile || "asset/gtav_satellite_2048.png").trim();
  const res = resourceName();
  let p = raw.replace(/^\/+/, "");
  if (!p.startsWith("html/")) p = `html/${p}`;
  return `nui://${res}/${p}`;
}

function drawRouteSvg(contract, pathPoints, map) {
  const el = document.getElementById("routeMap");
  if (!el || !contract) return;
  const bg = mapImageUrl(map);
  const a = normCoord(contract.pickup.x, contract.pickup.y, map);
  const b = normCoord(contract.delivery.x, contract.delivery.y, map);
  const uid = `rg${Date.now() % 100000}`;
  const pts = (pathPoints && pathPoints.length > 1 ? pathPoints : [a, b])
    .map((p) => (p.px != null ? p : normCoord(p.x, p.y, map)));
  const pathD = pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.px.toFixed(2)} ${p.py.toFixed(2)}`).join(" ");
  el.innerHTML = `
    <div class="route-map-bg" style="background-image:url('${bg}')"></div>
    <div class="route-map-vignette"></div>
    <svg class="route-map-svg" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <defs>
        <linearGradient id="${uid}" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#a78bfa"/>
          <stop offset="100%" stop-color="#fb923c"/>
        </linearGradient>
      </defs>
      <path d="${pathD}" fill="none" stroke="url(#${uid})" stroke-width="0.55" stroke-linecap="round" stroke-linejoin="round" opacity="0.92"/>
      <circle cx="${a.px}" cy="${a.py}" r="1.8" fill="#fff" stroke="#0f0e14" stroke-width="0.35"/>
      <circle cx="${b.px}" cy="${b.py}" r="2" fill="#a78bfa" stroke="#fff" stroke-width="0.3"/>
    </svg>`;
}

async function renderRouteMap(contract) {
  const el = document.getElementById("routeMap");
  if (!el) return;
  if (!contract) {
    el.innerHTML = '<div class="route-map-empty">Pasirinkite kontraktą</div>';
    return;
  }
  const map = state.data?.map || {};
  const reqId = ++routeRequestId;
  drawRouteSvg(contract, null, map);
  try {
    const res = await nui("trucking:getRoutePath", {
      from: contract.pickup,
      to: contract.delivery,
    });
    if (reqId !== routeRequestId) return;
    if (res?.ok && Array.isArray(res.points) && res.points.length > 1) {
      drawRouteSvg(contract, res.points, map);
    }
    if (res?.ok && res.distanceKm > 0 && state.selected?.id === contract.id) {
      contract.distanceKm = res.distanceKm;
      contract.roadDistanceKm = res.distanceKm;
      updateSelectedDistanceUi(contract);
    }
  } catch (e) {
    /* atsarginė tiesi linija */
  }
}

function updateSelectedDistanceUi(c) {
  const distEl = document.querySelector("#contractDetail .detail-distance");
  if (distEl) {
    distEl.innerHTML = `<span>${esc(c.distanceKm)} km <small class="road-tag">keliu</small></span>`;
  }
  const titleDist = document.querySelector(`[data-id="${CSS.escape(c.id)}"] .meta`);
  if (titleDist && c.distanceKm) {
    const parts = titleDist.textContent.split("·");
    if (parts.length >= 2) {
      titleDist.textContent = `${esc(c.distanceKm)} km · ${parts.slice(1).join("·").trim()}`;
    }
  }
}

function missionDetailRows(c, startLabel) {
  const trailer = c.trailerModel ? ` + priekaba` : "";
  const truckLine = c.truckLabel
    ? `<div class="detail-row"><span>Transportas</span><strong>${esc(c.truckLabel)}${trailer}</strong></div>`
    : "";
  const boxesLine = c.boxesRequired
    ? `<div class="detail-row"><span>Kiekis</span><span>${esc(c.boxesRequired)} dėž.</span></div>`
    : "";
  return `
    <div class="detail-row"><span>Krovinys</span><strong>${esc(c.cargoLabel)}</strong></div>
    ${boxesLine}
    ${truckLine}
    <div class="detail-row"><span>Pradžia</span><span>${esc(startLabel)}</span></div>
    <div class="detail-row"><span>Iš</span><span>${esc(c.pickupLabel)}</span></div>
    <div class="detail-row"><span>Į</span><span>${esc(c.deliveryLabel)}</span></div>
    <div class="detail-row detail-distance"><span>Atstumas</span><span>${esc(c.distanceKm)} km <small class="road-tag">keliu</small></span></div>
    <div class="detail-row"><span>Laikas</span><span>${esc(c.timeLimitMin)} min</span></div>
    <div class="detail-row"><span>Rizika</span><span class="risk-${esc(c.risk)}">${esc(c.risk)}</span></div>
    <div class="detail-row"><span>Atlygis</span><strong>${fmtMoney(c.pay)}</strong></div>`;
}

function applyQuoteToContract(quote) {
  if (!quote?.id) return;
  const list = state.data?.contracts || [];
  const c = list.find((x) => x.id === quote.id);
  if (!c) return;
  c.distanceKm = quote.distanceKm;
  c.roadDistanceKm = quote.distanceKm;
  c.timeLimitMin = quote.timeLimitMin;
  c.pay = quote.pay;
  if (state.selected?.id === c.id) {
    contractDetail.classList.remove("empty");
    const startLabel = state.data?.startHubLabel || c.pickupLabel;
    contractDetail.innerHTML = missionDetailRows(c, startLabel);
    renderRouteMap(c);
  }
}

async function refreshRoadQuotes() {
  const list = state.data?.contracts || [];
  if (!list.length) return;
  try {
    const local = await nui("trucking:quoteContracts", {
      contracts: list.map((c) => ({ id: c.id, pickup: c.pickup, delivery: c.delivery })),
    });
    if (!local?.ok || !Array.isArray(local.quotes) || !local.quotes.length) return;
    const server = await nui("trucking:applyRoadQuotes", { quotes: local.quotes });
    if (!server?.ok || !Array.isArray(server.quotes)) return;
    server.quotes.forEach(applyQuoteToContract);
    renderContractsListOnly();
    if (state.selected) {
      const refreshed = list.find((x) => x.id === state.selected.id);
      if (refreshed) selectContract(refreshed);
    }
  } catch (e) {}
}

function renderContractsListOnly() {
  const list = state.data?.contracts || [];
  const exchange = exchangeContracts(list);
  const emptyMsg =
    '<div class="contract-empty">Šiuo metu kontraktų nėra — palaukite atnaujinimo arba pakelkite lygį.</div>';
  contractList.innerHTML = list.length
    ? list.map((c) => renderContractItem(c, state.selected?.id === c.id)).join("")
    : emptyMsg;
  exchangeList.innerHTML = exchange.length
    ? exchange.map((c) => renderContractItem(c, false)).join("")
    : emptyMsg;
  bindContractClicks(contractList);
  bindContractClicks(exchangeList);
}

function renderContractItem(c, selected) {
  const illegal = c.illegal ? '<span class="tag tag-illegal">NELEGALU</span>' : "";
  return `
    <div class="contract-item${selected ? " selected" : ""}" data-id="${esc(c.id)}">
      <div>
        <div><strong>${esc(c.cargoLabel)}</strong> ${illegal}</div>
        <div class="meta">${esc(c.pickupLabel)} → ${esc(c.deliveryLabel)}</div>
        <div class="meta">${esc(c.distanceKm)} km · ${esc(c.boxesRequired || "?")} dėž. · ${esc(c.truckLabel || "transportas")} · <span class="risk-${esc(c.risk)}">${esc(c.risk)}</span></div>
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
  const startLabel = state.data?.startHubLabel || c.pickupLabel;
  contractDetail.innerHTML = missionDetailRows(c, startLabel);
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
  document.getElementById("profileRank").textContent = `${p.level || 1} lygio vairuotojas`;
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
  const isReg =
    p.registered === true ||
    p.registered === 1 ||
    p.registered === "1" ||
    Number(p.total_deliveries) > 0;
  registerOverlay.classList.toggle("hidden", isReg);
  if (isReg) setRegisterStatus("");
}

function exchangeContracts(list) {
  const premium = (list || []).filter((c) => c.category && c.category !== "standard");
  return premium.length ? premium : (list || []);
}

function renderContracts() {
  const list = state.data?.contracts || [];
  const exchange = exchangeContracts(list);
  const emptyMsg =
    '<div class="contract-empty">Šiuo metu kontraktų nėra — palaukite atnaujinimo arba pakelkite lygį.</div>';
  contractList.innerHTML = list.length
    ? list.map((c) => renderContractItem(c, state.selected?.id === c.id)).join("")
    : emptyMsg;
  exchangeList.innerHTML = exchange.length
    ? exchange.map((c) => renderContractItem(c, false)).join("")
    : emptyMsg;
  bindContractClicks(contractList);
  bindContractClicks(exchangeList);
  if (state.selected) selectContract(state.selected);
  else selectContract(list[0] || null);
  refreshRoadQuotes();
}

function renderFleet() {
  const grid = document.getElementById("fleetGrid");
  const fleet = state.data?.fleet || [];
  const shop = state.data?.fleetShop || [];
  if (!grid) return;
  if (!state.data?.company) {
    grid.innerHTML = '<div class="stat-card">Transporto parkas prieinamas tik įkūrus įmonę. Skiltyje „Įmonės valdymas“ paspausk „Įkurk savo įmonę“.</div>';
    return;
  }
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
      if (res?.ok && res.dashboard) {
        state.data = res.dashboard;
        renderAll();
        showToast("Transportas nupirktas.", "ok");
      } else {
        showToast(res?.reason || "Pirkimas nepavyko.", "err");
      }
    });
  });
}

function renderCompany() {
  const el = document.getElementById("companyPanel");
  const d = state.data;
  const p = d?.profile || {};
  const minLvl = d?.companyMinLevel || 5;
  if (!el) return;
  if (d?.company) {
    const members = (d.members || []).map((m) => `
      <div class="member-row">
        <span>${esc(m.role === "owner" ? "Savininkas" : "Vairuotojas")}</span>
        <span class="meta">${esc(m.citizenid)}</span>
      </div>`).join("");
    el.innerHTML = `
      <div class="company-card">
        <h3>${esc(d.company.name)}</h3>
        <p>Balansas: <strong>${fmtMoney(d.company.balance)}</strong></p>
        <p>Pristatymai: ${esc(d.company.total_deliveries)} · Pajamos: ${fmtMoney(d.company.total_revenue)}</p>
        <p>Darbuotojai: ${(d.members || []).length}</p>
        <div class="member-list">${members || '<p class="meta">Dar nėra papildomų darbuotojų.</p>'}</div>
      </div>`;
    return;
  }
  if ((p.level || 1) < minLvl) {
    el.innerHTML = `
      <div class="company-card company-empty">
        <h3>Įkurk savo įmonę</h3>
        <p>Įmonę galima įkurti nuo <strong>${minLvl} lygio</strong>. Dabar tavo lygis: ${esc(p.level || 1)}.</p>
      </div>`;
    return;
  }
  el.innerHTML = `
    <div class="company-card company-empty">
      <h3>Įkurk savo įmonę</h3>
      <p>Įkūrimo kaina: <strong>${fmtMoney(d?.companyCreateCost || 50000)}</strong></p>
      <div class="company-form">
        <input id="companyNameInput" placeholder="Pvz. Baltic Logistics" maxlength="48" />
        <button type="button" class="btn-secondary" id="btnCreateCompany">Įkurti įmonę</button>
      </div>
    </div>`;
  document.getElementById("btnCreateCompany")?.addEventListener("click", async () => {
    const name = document.getElementById("companyNameInput")?.value || "";
    const res = await nui("trucking:createCompany", { name });
    if (res?.ok && res.dashboard) {
      state.data = res.dashboard;
      renderAll();
      showToast("Įmonė sėkmingai įkurta.", "ok");
    } else {
      showToast(res?.reason || "Įmonės įkūrimas nepavyko.", "err");
    }
  });
}

function renderStats() {
  const p = state.data?.profile || {};
  const hist = state.data?.deliveryHistory || [];
  document.getElementById("statsPanel").innerHTML = `
    <div class="stat-card"><div>Lygis</div><strong>${esc(p.level)} lygis</strong></div>
    <div class="stat-card"><div>XP</div><strong>${esc(p.xp)}</strong></div>
    <div class="stat-card"><div>Reputacija</div><strong>${stars(p.stars)}</strong></div>
    <div class="stat-card"><div>Pristatymai</div><strong>${esc(p.total_deliveries)}</strong></div>
    <div class="stat-card"><div>Uždirbta</div><strong>${fmtMoney(p.total_earned)}</strong></div>
    <div class="stat-card"><div>Licencijos</div><strong>${p.licenses?.heavy_truck ? "Sunkiojo transporto ✓" : "—"}</strong></div>`;
  const histEl = document.getElementById("deliveryHistoryPanel");
  if (!histEl) return;
  histEl.innerHTML = hist.length
    ? `<h3 class="history-title">Paskutiniai pristatymai</h3>
      <div class="history-table">
        ${hist.map((h) => `
          <div class="history-row">
            <div><strong>${esc(h.cargoLabel)}</strong></div>
            <div class="meta">${esc(h.pickupLabel)} → ${esc(h.deliveryLabel)}</div>
            <div class="meta">${fmtMoney(h.pay)} · būklė ${esc(h.condition_pct)}% · ${h.on_time ? "laiku" : "vėluota"}</div>
          </div>`).join("")}
      </div>`
    : '<div class="stat-card">Dar nėra pristatymų istorijos — priimk pirmą kontraktą.</div>';
}

function renderLeaderboard() {
  const companies = state.data?.leaderboard || [];
  const drivers = state.data?.driverLeaderboard || [];
  const parts = [];
  parts.push('<h3 class="history-title">Top įmonės</h3>');
  parts.push(companies.length
    ? companies.map((r, i) => `
      <div class="lb-row">
        <strong>#${i + 1} ${esc(r.name)}</strong>
        <div class="meta">${fmtMoney(r.total_revenue)} · ${esc(r.total_deliveries)} kroviniai · ${esc(r.members)} darbuotojai</div>
      </div>`).join("")
    : '<div class="stat-card">Dar nėra įmonių reitingo.</div>');
  parts.push('<h3 class="history-title">Top vairuotojai</h3>');
  parts.push(drivers.length
    ? drivers.map((r, i) => {
      const name = `${r.firstname || ""} ${r.lastname || ""}`.trim() || r.citizenid;
      return `
      <div class="lb-row">
        <strong>#${i + 1} ${esc(name)}</strong>
        <div class="meta">${esc(r.total_deliveries)} pristatymų · ${fmtMoney(r.total_earned)} · ${esc(r.level)} lygis</div>
      </div>`;
    }).join("")
    : '<div class="stat-card">Dar nėra vairuotojų reitingo.</div>');
  document.getElementById("leaderboardPanel").innerHTML = parts.join("");
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
  document.querySelectorAll(".tab").forEach((p) => {
    p.classList.toggle("active", p.dataset.panel === tab);
    p.classList.remove("hidden");
  });
  const startHub = state.data?.startHubLabel || "Logistikos centras";
  const titles = {
    market: ["KONTRAKTŲ RINKA", `Paėmimas: ${startHub} · pasirinkite krovinį`],
    exchange: ["KROVINIŲ BIRŽA", "Specialūs ir aktyvūs kroviniai"],
    fleet: ["TRANSPORTO PARKAS", "Jūsų sunkvežimiai ir pirkimas"],
    company: ["ĮMONĖS VALDYMAS", state.data?.company ? "Kompanijos valdymas" : "Įkurk savo įmonę"],
    stats: ["VAIRUOTOJO STATISTIKA", "Progresija, licencijos ir istorija"],
    leaderboard: ["LENTELĖS", "Geriausios įmonės ir vairuotojai"],
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
  btnAccept.disabled = true;
  let roadDistanceKm = state.selected.roadDistanceKm || state.selected.distanceKm;
  try {
    const route = await nui("trucking:getRoutePath", {
      from: state.selected.pickup,
      to: state.selected.delivery,
    });
    if (route?.ok && route.distanceKm > 0) roadDistanceKm = route.distanceKm;
  } catch (e) {}
  const res = await nui("trucking:acceptContract", {
    contractId: state.selected.id,
    roadDistanceKm,
  });
  btnAccept.disabled = false;
  if (!res?.ok) showToast(res?.reason || "Kontrakto priimti nepavyko.", "err");
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

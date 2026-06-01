const tablet = document.getElementById("tablet");
const gangTitle = document.getElementById("gangTitle");
const gangMeta = document.getElementById("gangMeta");
const gangPanelEmpty = document.getElementById("gangPanelEmpty");
const gangPanelContent = document.getElementById("gangPanelContent");
const gangName = document.getElementById("gangName");
const gangType = document.getElementById("gangType");
const primaryColor = document.getElementById("primaryColor");
const secondaryColor = document.getElementById("secondaryColor");
const colorWarn = document.getElementById("colorWarn");
const primarySwatches = document.getElementById("primarySwatches");
const secondarySwatches = document.getElementById("secondarySwatches");

const tabPanels = {
  register: document.getElementById("tabPanelRegister"),
  gang: document.getElementById("tabPanelGang"),
  map: document.getElementById("tabPanelMap"),
  missions: document.getElementById("tabPanelMissions"),
  top: document.getElementById("tabPanelTop"),
  wars: document.getElementById("tabPanelWars"),
};
const missionTurfSelect = document.getElementById("missionTurfSelect");
const missionTypeSelect = document.getElementById("missionTypeSelect");
const claimThresholdLbl = document.getElementById("claimThresholdLbl");
const tabMissions = document.getElementById("tabMissions");

let lastState = null;
let tabletDocked = false;
let tabletDragBound = false;
const tabletBezel = document.querySelector(".tablet-bezel");
/** @type {'register' | 'gang' | 'map' | 'missions' | 'top' | 'wars'} */
let activeTab = "register";

function resourceName() {
  try {
    if (typeof GetParentResourceName === "function") return GetParentResourceName();
  } catch (e) {}
  return "fivempro_gangs";
}

function post(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  })
    .then((r) => r.json())
    .catch(() => null);
}

window.GangMapPost = post;

function safe(s) {
  const d = document.createElement("div");
  d.textContent = s == null ? "" : String(s);
  return d.innerHTML;
}

function destroyTurfMap() {
  if (window.GangMap) GangMap.destroy();
}

function scheduleRenderMap(state) {
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      if (!lastState || activeTab !== "map") return;
      const root = document.getElementById("gangsLeafletMap");
      if (!root || root.clientHeight < 48) {
        setTimeout(() => scheduleRenderMap(state), 100);
        return;
      }
      if (window.GangMap) GangMap.open(state || lastState);
    });
  });
}

function hexKey(hex) {
  return String(hex || "").trim().toUpperCase();
}

function syncSwatchSelection(selectEl, containerEl) {
  if (!containerEl) return;
  const cur = hexKey(selectEl.value);
  containerEl.querySelectorAll(".color-swatch").forEach((b) => {
    b.classList.toggle("active", hexKey(b.dataset.hex) === cur);
  });
}

function renderColorSwatches(selectEl, containerEl, palette, usage) {
  if (!containerEl || !selectEl) return;
  containerEl.innerHTML = "";
  const opts = palette || [];
  opts.forEach((hex) => {
    const used = Number((usage || {})[String(hex).toUpperCase()] || 0);
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "color-swatch";
    if (used > 0) btn.classList.add("is-used");
    btn.style.backgroundColor = hex;
    btn.dataset.hex = hex;
    btn.title = used > 0 ? `${hex} — jau naudojama` : String(hex);
    btn.addEventListener("click", () => {
      selectEl.value = hex;
      syncSwatchSelection(selectEl, containerEl);
      selectEl.dispatchEvent(new Event("change", { bubbles: true }));
    });
    containerEl.appendChild(btn);
  });

  const valid = opts.some((h) => hexKey(h) === hexKey(selectEl.value));
  if (!valid && opts.length) selectEl.value = opts[0];
  syncSwatchSelection(selectEl, containerEl);
}

function renderPalette(palette, usage) {
  primaryColor.innerHTML = "";
  secondaryColor.innerHTML = "";
  (palette || []).forEach((hex) => {
    const used = Number((usage || {})[String(hex).toUpperCase()] || 0);
    const txt = used > 0 ? `${hex} (used ${used})` : hex;
    const o1 = document.createElement("option");
    o1.value = hex;
    o1.textContent = txt;
    primaryColor.appendChild(o1);
    const o2 = document.createElement("option");
    o2.value = hex;
    o2.textContent = txt;
    secondaryColor.appendChild(o2);
  });
  renderColorSwatches(primaryColor, primarySwatches, palette, usage);
  renderColorSwatches(secondaryColor, secondarySwatches, palette, usage);
}

function mergeTabletMap(res) {
  if (!res || !res.ok) return res;
  if (!res.tabletMap && lastState && lastState.tabletMap) res.tabletMap = lastState.tabletMap;
  if (!res.gangColors && lastState && lastState.gangColors) res.gangColors = lastState.gangColors;
  return res;
}

function renderMissionsTab(state) {
  if (!missionTurfSelect || !missionTypeSelect) return;
  missionTurfSelect.innerHTML = "";
  const optAny = document.createElement("option");
  optAny.value = "";
  optAny.textContent = "— dabartinė zona / nereikia —";
  missionTurfSelect.appendChild(optAny);
  (state.turfs || []).forEach((t) => {
    const o = document.createElement("option");
    o.value = t.turf_id;
    const inf = Number(t.influence ?? t.progress ?? 0);
    o.textContent = `#${t.cell_num || t.turf_id} · ${t.district || t.turf_label || t.turf_id} (${inf}%)`;
    missionTurfSelect.appendChild(o);
  });
  missionTypeSelect.innerHTML = "";
  (state.missions || []).forEach((m) => {
    const o = document.createElement("option");
    o.value = m.id;
    const rep = Number(m.reputationReward || m.progress || 0);
    o.textContent = `${m.label} (Rep +${rep})`;
    missionTypeSelect.appendChild(o);
  });
  if (claimThresholdLbl) claimThresholdLbl.textContent = String(state.claimThreshold || 100);
  const stats = document.getElementById("gangMissionStats");
  if (stats && state.gang) {
    stats.textContent = `Rep: ${state.gang.reputation || 0} · Tipas: ${state.gang.gang_type || "—"}`;
  }
  if (tabMissions) tabMissions.style.display = state.hasGang ? "" : "none";
  document.querySelectorAll('.tab-btn[data-tab="top"], .tab-btn[data-tab="wars"]').forEach((btn) => {
    btn.style.display = state.hasGang ? "" : "none";
  });
}

function renderTopAndWarsTabs(state) {
  const topFull = document.getElementById("topGangsListFull");
  if (topFull) {
    topFull.innerHTML = (state.topGangs || [])
      .map(
        (g, i) =>
          `<li class="top-gang-row">
            <span class="top-rank">#${i + 1}</span>
            <span class="top-color-swatch" style="background:linear-gradient(135deg, ${g.color_hex || "#64748b"}, ${g.secondary_color_hex || g.color_hex || "#64748b"})"></span>
            <span class="top-color-code">${safe((g.color_hex || "#64748B").toUpperCase())}</span>
            <span class="top-meta">${g.turf_count || 0} turf · ${Number(g.reputation || 0).toLocaleString()} rep</span>
          </li>`,
      )
      .join("") || "<li class='muted'>Duomenų nėra</li>";
  }

  const warsFull = document.getElementById("activeWarsListFull");
  if (warsFull) {
    warsFull.innerHTML = (state.activeWars || [])
      .map(
        (w) =>
          `<li class="war-row">
            <span class="war-dot" style="background:${w.color_hex || "#f87171"}"></span>
            <strong>Turf #${safe(w.turfId || w.cell_num || "—")}</strong>
            <span>${safe(w.label)} · ${safe(w.influence)}%</span>
            <em>${safe(w.timeLabel || "Aktyvus")}</em>
          </li>`,
      )
      .join("") || "<li class='muted'>Šiuo metu ramu</li>";
  }

  const actsFull = document.getElementById("recentActsListFull");
  if (actsFull) {
    actsFull.innerHTML = (state.recentActivities || [])
      .map(
        (a) =>
          `<li><span class="act-dot" style="background:${a.colorHex || "#a78bfa"}"></span> ${safe(a.gangName || "—")} · ${safe(a.label || a.turfId)} <em>+$${a.profit}</em></li>`,
      )
      .join("") || "<li class='muted'>Veiklų nėra</li>";
  }
}

function updateGangTabContent(state) {
  const memberListEl = document.getElementById("gangMemberList");
  if (state.hasGang) {
    gangPanelEmpty.classList.add("hidden");
    gangPanelContent.classList.remove("hidden");
    gangTitle.textContent = `${state.gang.name} (${state.gang.gang_type})`;
    gangMeta.textContent = `Rep: ${state.gang.reputation || 0} · ${state.gang.color_hex || "-"} / ${state.gang.secondary_color_hex || "-"}`;
    const rows = state.members || [];
    memberListEl.innerHTML = rows.length
      ? rows
          .map(
            (m) =>
              `<div class="gang-member-row"><span>${safe(m.name || "Narys")}</span><span>${safe(m.citizenid || "-")}</span><strong>R${safe(m.rank || 0)}</strong></div>`,
          )
          .join("")
      : `<div class="gang-member-row"><span>Narių nėra</span><span>-</span><strong>-</strong></div>`;
  } else {
    gangPanelContent.classList.add("hidden");
    gangPanelEmpty.classList.remove("hidden");
    memberListEl.innerHTML = "";
  }
}

function activateTab(tab) {
  if (tab === "gang" && !lastState?.hasGang) tab = "register";
  if ((tab === "missions" || tab === "top" || tab === "wars") && !lastState?.hasGang) tab = "register";
  activeTab = tab;

  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });

  Object.entries(tabPanels).forEach(([k, el]) => {
    if (el) el.classList.toggle("hidden", k !== tab);
  });

  const warsPopover = document.getElementById("warsPopover");
  if (warsPopover) warsPopover.classList.add("hidden");

  if (tab === "map") {
    scheduleRenderMap(lastState);
  } else {
    destroyTurfMap();
  }
}

document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => activateTab(btn.dataset.tab));
});

function render(state) {
  lastState = state;
  tablet.classList.remove("hidden");
  if (!gangType || !primaryColor) {
    console.error("[fivempro_gangs] Trūksta UI elementų");
    return;
  }

  gangType.innerHTML = "";
  Object.entries(state.gangTypes || {}).forEach(([k, v]) => {
    const o = document.createElement("option");
    o.value = k;
    o.textContent = `${v}`;
    gangType.appendChild(o);
  });
  renderPalette(state.palette || [], state.colorUsage || {});
  updateGangTabContent(state);
  renderMissionsTab(state);
  renderTopAndWarsTabs(state);

  if (window.GangMap && activeTab === "map") {
    GangMap.renderPanels(state);
  }

  if (activeTab === "gang" && !state.hasGang) activeTab = "register";
  if (activeTab === "missions" && !state.hasGang) activeTab = "register";

  activateTab(activeTab);
}

function refreshWarn() {
  if (!lastState) return;
  const usage = lastState.colorUsage || {};
  const used = Number(usage[String(primaryColor.value || "").toUpperCase()] || 0) > 0;
  colorWarn.classList.toggle("hidden", !used);
  colorWarn.textContent = used ? `Spalva ${primaryColor.value} jau naudojama — vis tiek gali rinktis.` : "";
}
primaryColor.addEventListener("change", refreshWarn);

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;
  if (d.action === "open") {
    const payload = d.payload || {};
    if (payload.keepTab && activeTab) {
      /* paliekame esamą skiltį */
    } else if (payload.initialTab) {
      activeTab = payload.initialTab;
    } else {
      activeTab = payload.hasGang ? "gang" : "register";
    }
    setTabletDocked(false, true);
    try {
      render(payload);
    } catch (err) {
      console.error("[fivempro_gangs] render klaida:", err);
      tablet.classList.remove("hidden");
      activateTab("register");
    }
  }
  if (d.action === "dock") {
    setTabletDocked(true, true);
  }
  if (d.action === "undock") {
    setTabletDocked(false, true);
  }
  if (d.action === "close") {
    destroyTurfMap();
    tablet.classList.add("hidden");
    activeTab = "register";
  }
});

function setTabletDocked(docked, skipPost) {
  tabletDocked = !!docked;
  tablet.classList.toggle("is-docked", tabletDocked);
  const btn = document.getElementById("btnDock");
  if (btn) btn.textContent = tabletDocked ? "Visas" : "Kampas";
  if (!skipPost) post("gangs:setDocked", { docked: tabletDocked });
  if (!tabletDocked && tabletBezel) {
    tabletBezel.style.left = "";
    tabletBezel.style.top = "";
    tabletBezel.style.right = "";
    tabletBezel.style.bottom = "";
  }
  if (activeTab === "map" && window.GangMap) {
    requestAnimationFrame(() => GangMap.invalidate());
  }
}

function bindTabletDrag() {
  if (tabletDragBound) return;
  tabletDragBound = true;
  const head = document.querySelector(".tablet-head");
  if (!head || !tabletBezel) return;
  let drag = false;
  let sx = 0;
  let sy = 0;
  let sl = 0;
  let st = 0;
  head.addEventListener("mousedown", (e) => {
    if (!tabletDocked || e.target.closest("button")) return;
    drag = true;
    const r = tabletBezel.getBoundingClientRect();
    sx = e.clientX;
    sy = e.clientY;
    sl = r.left;
    st = r.top;
    e.preventDefault();
  });
  window.addEventListener("mouseup", () => {
    drag = false;
  });
  window.addEventListener("mousemove", (e) => {
    if (!drag || !tabletDocked) return;
    tabletBezel.style.left = `${sl + e.clientX - sx}px`;
    tabletBezel.style.top = `${st + e.clientY - sy}px`;
    tabletBezel.style.right = "auto";
    tabletBezel.style.bottom = "auto";
  });
}

const btnDockGang = document.getElementById("btnDock");
if (btnDockGang) {
  btnDockGang.onclick = () => setTabletDocked(!tabletDocked);
}
bindTabletDrag();

document.getElementById("btnClose").onclick = () => post("gangs:close", {});
document.getElementById("btnRefresh").onclick = () =>
  post("gangs:refresh", {}).then((res) => {
    mergeTabletMap(res);
    if (res && res.ok) render(res);
  });

document.getElementById("btnCreate").onclick = () => {
  const payload = {
    name: gangName.value.trim(),
    gangType: gangType.value,
    colorHex: primaryColor.value,
    secondaryColorHex: secondaryColor.value,
  };
  post("gangs:createGang", payload).then(() =>
    post("gangs:refresh", {}).then((res) => {
      mergeTabletMap(res);
      if (res && res.ok) {
        activeTab = "gang";
        render(res);
      }
    }),
  );
};

document.getElementById("zoomIn").onclick = () => window.GangMap && GangMap.zoomIn();
document.getElementById("zoomOut").onclick = () => window.GangMap && GangMap.zoomOut();
document.getElementById("tabletHomeBtn").onclick = () => window.GangMap && GangMap.resetView();
document.getElementById("btnFitTurfs")?.addEventListener("click", () => window.GangMap && GangMap.fitAllTurfs());
document.getElementById("btnMapReset")?.addEventListener("click", () => window.GangMap && GangMap.resetView());

const warsBanner = document.getElementById("warsBanner");
const warsPopover = document.getElementById("warsPopover");
if (warsBanner && warsPopover) {
  warsBanner.addEventListener("click", (e) => {
    e.stopPropagation();
    const opening = warsPopover.classList.contains("hidden");
    if (opening) {
      warsPopover.classList.remove("hidden");
      warsBanner.setAttribute("aria-expanded", "true");
      if (lastState && window.GangMap) GangMap.renderWarsPopover(lastState);
    } else {
      warsPopover.classList.add("hidden");
      warsBanner.setAttribute("aria-expanded", "false");
    }
  });
  document.addEventListener("click", () => {
    warsPopover.classList.add("hidden");
    warsBanner.setAttribute("aria-expanded", "false");
  });
  warsPopover.addEventListener("click", (e) => e.stopPropagation());
}

const btnTurfRoute = document.getElementById("btnTurfRoute");
if (btnTurfRoute) {
  btnTurfRoute.onclick = () => {
    const t = window.GangMap && GangMap.getSelectedTurf();
    if (!t) return;
    post("gangs:setWaypoint", { turfId: t.turf_id }).then(() => setTabletDocked(true));
  };
}

document.getElementById("btnInviteMember").onclick = () => {
  post("gangs:inviteMember", { targetId: Number(document.getElementById("memberTargetId").value) || 0 }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};
document.getElementById("btnSetRank").onclick = () => {
  post("gangs:setMemberRank", {
    citizenid: document.getElementById("memberCitizenId").value.trim(),
    rank: Number(document.getElementById("memberRank").value) || 0,
  }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};
document.getElementById("btnKickMember").onclick = () => {
  post("gangs:kickMember", { citizenid: document.getElementById("memberCitizenId").value.trim() }).then(() => {
    post("gangs:refresh", {}).then((res) => res && res.ok && render(mergeTabletMap(res)));
  });
};

const btnStartMission = document.getElementById("btnStartMission");
if (btnStartMission) {
  btnStartMission.onclick = () => {
    const turfId = missionTurfSelect?.value;
    const missionType = missionTypeSelect?.value;
    if (!turfId || !missionType) return;
    post("gangs:startMission", { turfId, missionType });
  };
}

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !tablet.classList.contains("hidden")) {
    e.preventDefault();
    post("gangs:close", {});
  }
});

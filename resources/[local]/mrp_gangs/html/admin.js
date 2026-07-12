(function () {
  const root = document.getElementById("gangAdmin");
  if (!root) return;

  const els = {
    search: document.getElementById("gaSearch"),
    list: document.getElementById("gaList"),
    listMeta: document.getElementById("gaListMeta"),
    detail: document.getElementById("gaDetail"),
    toast: document.getElementById("gaToast"),
    tabs: root.querySelectorAll(".ga-tab"),
  };

  let state = { gangs: [], turfs: [], maxWarnings: 5 };
  let tab = "gangs";
  let selectedGangId = null;
  let selectedTurfId = null;

  function resourceName() {
    try {
      if (typeof GetParentResourceName === "function") return GetParentResourceName();
    } catch (e) {}
    return "mrp_gangs";
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

  function safe(s) {
    const d = document.createElement("div");
    d.textContent = s == null ? "" : String(s);
    return d.innerHTML;
  }

  let toastTimer = null;
  function toast(msg, type) {
    if (!els.toast) return;
    els.toast.textContent = msg;
    els.toast.className = "ga-toast show " + (type || "");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => els.toast.classList.remove("show"), 2800);
  }

  function maxWarnings() {
    return Number(state.maxWarnings) || 5;
  }

  function warnMeterHtml(count, max) {
    max = max || maxWarnings();
    count = Math.max(0, Math.min(max, Number(count) || 0));
    let html = "";
    for (let i = 1; i <= max; i += 1) {
      const filled = i <= count;
      const danger = count >= max && filled;
      html += `<span class="ga-warn-slot${filled ? " filled" : ""}${danger ? " danger" : ""}" title="${i}/${max}"></span>`;
    }
    return html;
  }

  function formatWhen(iso) {
    if (!iso) return "—";
    try {
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return String(iso);
      return d.toLocaleString("lt-LT", { dateStyle: "short", timeStyle: "short" });
    } catch (e) {
      return String(iso);
    }
  }

  function warnHistoryHtml(items) {
    const list = items || [];
    if (!list.length) return `<p class="ga-warn-item"><em>Įspėjimų istorijos nėra.</em></p>`;
    return list
      .map(
        (w) =>
          `<div class="ga-warn-item"><strong>${safe(w.reason || "Įspėjimas")}</strong><em>${safe(w.admin_name || "Admin")} · ${safe(formatWhen(w.created_at))}</em></div>`,
      )
      .join("");
  }

  function gangById(id) {
    return (state.gangs || []).find((g) => Number(g.id) === Number(id));
  }

  function turfById(id) {
    return (state.turfs || []).find((t) => String(t.turf_id) === String(id));
  }

  function filterGangs() {
    const q = (els.search?.value || "").trim().toLowerCase();
    return (state.gangs || []).filter((g) => {
      if (!q) return true;
      const hay = `${g.id} ${g.name} ${g.gang_type}`.toLowerCase();
      return hay.includes(q);
    });
  }

  function filterTurfs() {
    const q = (els.search?.value || "").trim().toLowerCase();
    return (state.turfs || []).filter((t) => {
      if (!q) return true;
      const hay = `${t.turf_id} ${t.turf_label || ""} ${t.owner_name || ""} ${t.district || ""}`.toLowerCase();
      return hay.includes(q);
    });
  }

  function renderList() {
    if (!els.list) return;
    const items = tab === "gangs" ? filterGangs() : filterTurfs();
    if (els.listMeta) {
      els.listMeta.textContent = tab === "gangs"
        ? `${items.length} gaujos`
        : `${items.length} teritorijos`;
    }
    if (!items.length) {
      els.list.innerHTML = `<div class="ga-empty-detail" style="padding:24px"><strong>Nerasta</strong>Pabandyk kitą paiešką.</div>`;
      return;
    }
    if (tab === "gangs") {
      els.list.innerHTML = items
        .map((g) => {
          const active = Number(selectedGangId) === Number(g.id);
          const hex = g.color_hex || "#888";
          return `<button type="button" class="ga-list-item${active ? " active" : ""}" data-gang-id="${g.id}">
            <div class="ga-list-item-title">
              <span class="ga-swatch" style="background:${safe(hex)}"></span>
              ${safe(g.name)}
            </div>
            <div class="ga-list-item-sub">#${g.id} · ${safe(g.gang_type)} · Rep ${g.reputation ?? 0} · ⚠ ${g.warnings ?? 0}/${maxWarnings()} · ${g.member_count ?? 0} nariai</div>
          </button>`;
        })
        .join("");
      els.list.querySelectorAll("[data-gang-id]").forEach((btn) => {
        btn.onclick = () => {
          selectedGangId = Number(btn.dataset.gangId);
          renderList();
          renderDetail();
        };
      });
    } else {
      els.list.innerHTML = items
        .map((t) => {
          const active = String(selectedTurfId) === String(t.turf_id);
          const owner = t.owner_name || "Laisva";
          return `<button type="button" class="ga-list-item${active ? " active" : ""}" data-turf-id="${safe(t.turf_id)}">
            <div class="ga-list-item-title">${safe(t.turf_label || t.turf_id)}</div>
            <div class="ga-list-item-sub">${safe(owner)} · ${t.progress ?? 0}% · ${safe(t.district || "")}</div>
          </button>`;
        })
        .join("");
      els.list.querySelectorAll("[data-turf-id]").forEach((btn) => {
        btn.onclick = () => {
          selectedTurfId = btn.dataset.turfId;
          renderList();
          renderDetail();
        };
      });
    }
  }

  function renderGangDetail(g) {
    const delName = `DELETE-${g.id}`;
    const wCount = Number(g.warnings) || 0;
    const wMax = maxWarnings();
    const wStatClass = wCount >= wMax ? " is-danger" : wCount > 0 ? " is-warn" : "";
    els.detail.innerHTML = `
      <div class="ga-detail-card">
        <h2><span class="ga-swatch" style="width:14px;height:14px;background:${safe(g.color_hex || "#888")}"></span> ${safe(g.name)} <span class="ga-id">#${g.id}</span></h2>
        <span class="ga-type-pill">${safe(g.gang_type)}</span>
        <div class="ga-stat-row">
          <div class="ga-stat"><span>Reputacija</span><strong id="gaStatRep">${g.reputation ?? 0}</strong></div>
          <div class="ga-stat"><span>Nariai</span><strong>${g.member_count ?? 0}</strong></div>
          <div class="ga-stat${wStatClass}"><span>Įspėjimai</span><strong>${wCount}/${wMax}</strong></div>
        </div>
        <div class="ga-warn-box">
          <h3>⚠ Įspėjimų sistema (${wCount}/${wMax})</h3>
          <div class="ga-warn-meter" aria-label="Įspėjimai">${warnMeterHtml(wCount, wMax)}</div>
          <div class="ga-form-grid">
            <label>Priežastis
              <textarea id="gaWarnReason" rows="2" maxlength="255" placeholder="Pvz. per dažni turf karai…"></textarea>
            </label>
          </div>
          <div class="ga-actions">
            <button type="button" class="ga-btn ga-btn-warn" id="gaIssueWarn"${wCount >= wMax ? " disabled" : ""}>Duoti įspėjimą</button>
            <button type="button" class="ga-btn ga-btn-ghost" id="gaClearWarns"${wCount === 0 ? " disabled" : ""}>Nunulinti įspėjimus</button>
          </div>
          <div class="ga-warn-history">
            <h4>Paskutiniai įspėjimai</h4>
            ${warnHistoryHtml(g.recent_warnings)}
          </div>
        </div>
        <div class="ga-form-grid">
          <label>Reputacija
            <input type="number" id="gaRep" value="${Number(g.reputation) || 0}" min="0" step="1" />
          </label>
        </div>
        <div class="ga-actions">
          <button type="button" class="ga-btn ga-btn-primary" id="gaSaveGang">Išsaugoti</button>
        </div>
        <div class="ga-delete-box">
          <h3>Pavojinga zona</h3>
          <p>Visam laikui ištrina gaują, narius ir atlaisvina jos turfus. Įrašyk <code>${delName}</code> patvirtinimui.</p>
          <input type="text" id="gaDeleteConfirm" placeholder="${delName}" autocomplete="off" />
          <button type="button" class="ga-btn ga-btn-danger" id="gaDeleteGang">Ištrinti gaują</button>
        </div>
      </div>`;

    document.getElementById("gaIssueWarn")?.addEventListener("click", () => {
      const reason = (document.getElementById("gaWarnReason")?.value || "").trim();
      post("gangs:adminIssueWarning", { gangId: g.id, reason }).then((res) => {
        if (res && res.ok) {
          toast("Įspėjimas suteiktas.", "ok");
          mergeState(res);
          selectedGangId = g.id;
          renderAll();
        } else toast((res && res.message) || "Nepavyko duoti įspėjimo.", "err");
      });
    });

    document.getElementById("gaClearWarns")?.addEventListener("click", () => {
      post("gangs:adminClearWarnings", { gangId: g.id }).then((res) => {
        if (res && res.ok) {
          toast("Įspėjimai nunulinti.", "ok");
          mergeState(res);
          selectedGangId = g.id;
          renderAll();
        } else toast((res && res.message) || "Klaida.", "err");
      });
    });

    document.getElementById("gaSaveGang").onclick = () => {
      const reputation = Number(document.getElementById("gaRep").value) || 0;
      post("gangs:adminSaveGang", { gangId: g.id, reputation }).then((res) => {
        if (res && res.ok) {
          toast("Gauja atnaujinta.", "ok");
          mergeState(res);
          renderAll();
        } else toast((res && res.message) || "Klaida.", "err");
      });
    };

    document.getElementById("gaDeleteGang").onclick = () => {
      const v = (document.getElementById("gaDeleteConfirm").value || "").trim();
      if (v !== delName) {
        toast("Neteisingas patvirtinimas.", "err");
        return;
      }
      post("gangs:adminDeleteGang", { gangId: g.id }).then((res) => {
        if (res && res.ok) {
          toast("Gauja ištrinta.", "ok");
          selectedGangId = null;
          mergeState(res);
          renderAll();
        } else toast((res && res.message) || "Klaida.", "err");
      });
    };
  }

  function renderTurfDetail(t) {
    const gangOpts = ['<option value="0">— Laisva —</option>']
      .concat(
        (state.gangs || []).map(
          (g) =>
            `<option value="${g.id}"${Number(t.owner_gang_id) === Number(g.id) ? " selected" : ""}>#${g.id} ${safe(g.name)}</option>`,
        ),
      )
      .join("");
    const prog = Math.max(0, Math.min(100, Number(t.progress) || 0));

    els.detail.innerHTML = `
      <div class="ga-detail-card">
        <h2>${safe(t.turf_label || t.turf_id)} <span class="ga-id">${safe(t.turf_id)}</span></h2>
        <span class="ga-type-pill">${safe(t.district || "Teritorija")}</span>
        <div class="ga-stat-row">
          <div class="ga-stat"><span>Savininkas</span><strong style="font-size:14px">${safe(t.owner_name || "Laisva")}</strong></div>
          <div class="ga-stat"><span>Progresas</span><strong id="gaProgLbl">${prog}%</strong></div>
        </div>
        <div class="ga-form-grid">
          <label>Savininko gauja
            <select id="gaTurfOwner">${gangOpts}</select>
          </label>
          <label class="ga-range-wrap">Užėmimo progresas
            <input type="range" id="gaTurfProg" min="0" max="100" value="${prog}" />
            <span class="ga-range-val" id="gaTurfProgVal">${prog}%</span>
          </label>
        </div>
        <div class="ga-actions">
          <button type="button" class="ga-btn ga-btn-primary" id="gaSaveTurf">Išsaugoti</button>
          <button type="button" class="ga-btn ga-btn-ghost" id="gaResetTurf">Atstatyti turf</button>
        </div>
      </div>`;

    const range = document.getElementById("gaTurfProg");
    const lbl = document.getElementById("gaTurfProgVal");
    range.oninput = () => {
      lbl.textContent = range.value + "%";
    };

    document.getElementById("gaSaveTurf").onclick = () => {
      post("gangs:adminSaveTurf", {
        turfId: t.turf_id,
        progress: Number(range.value) || 0,
        ownerGangId: Number(document.getElementById("gaTurfOwner").value) || 0,
      }).then((res) => {
        if (res && res.ok) {
          toast("Turf atnaujintas.", "ok");
          mergeState(res);
          renderAll();
        } else toast((res && res.message) || "Klaida.", "err");
      });
    };

    document.getElementById("gaResetTurf").onclick = () => {
      post("gangs:adminResetTurf", { turfId: t.turf_id }).then((res) => {
        if (res && res.ok) {
          toast("Turf atstatytas.", "ok");
          mergeState(res);
          renderAll();
        } else toast((res && res.message) || "Klaida.", "err");
      });
    };
  }

  function renderDetail() {
    if (!els.detail) return;
    if (tab === "gangs") {
      const g = gangById(selectedGangId);
      if (!g) {
        els.detail.innerHTML = `<div class="ga-empty-detail"><strong>Pasirink gaują</strong>Spausk ant gaujos sąraše kairėje, kad redaguotum reputaciją ar ištrintum.</div>`;
        return;
      }
      renderGangDetail(g);
      return;
    }
    const t = turfById(selectedTurfId);
    if (!t) {
      els.detail.innerHTML = `<div class="ga-empty-detail"><strong>Pasirink teritoriją</strong>Valdyk savininką, progresą arba atstatyk turf.</div>`;
      return;
    }
    renderTurfDetail(t);
  }

  function mergeState(res) {
    if (!res) return;
    if (res.gangs) state.gangs = res.gangs;
    if (res.turfs) state.turfs = res.turfs;
    if (res.maxWarnings != null) state.maxWarnings = res.maxWarnings;
  }

  function renderAll() {
    renderList();
    renderDetail();
  }

  function setTab(next) {
    tab = next;
    els.tabs.forEach((b) => b.classList.toggle("active", b.dataset.gaTab === tab));
    if (tab === "gangs") {
      if (!gangById(selectedGangId)) selectedGangId = state.gangs[0] ? state.gangs[0].id : null;
    } else if (!turfById(selectedTurfId)) {
      selectedTurfId = state.turfs[0] ? state.turfs[0].turf_id : null;
    }
    if (els.search) {
      els.search.placeholder = tab === "gangs" ? "Ieškoti gaujos…" : "Ieškoti turf…";
      els.search.value = "";
    }
    renderAll();
  }

  function openAdmin(payload) {
    state = {
      gangs: payload.gangs || [],
      turfs: payload.turfs || [],
      maxWarnings: payload.maxWarnings || 5,
    };
    selectedGangId = state.gangs[0] ? state.gangs[0].id : null;
    selectedTurfId = state.turfs[0] ? state.turfs[0].turf_id : null;
    tab = "gangs";
    setTab("gangs");
    root.classList.remove("hidden");
    root.setAttribute("aria-hidden", "false");
  }

  function closeAdmin() {
    root.classList.add("hidden");
    root.setAttribute("aria-hidden", "true");
    post("gangs:adminClose", {});
  }

  els.tabs.forEach((btn) => {
    btn.onclick = () => setTab(btn.dataset.gaTab);
  });

  if (els.search) {
    els.search.oninput = () => renderList();
  }

  document.getElementById("gaBtnRefresh")?.addEventListener("click", () => {
    post("gangs:adminRefresh", {}).then((res) => {
      if (res && res.ok) {
        mergeState(res);
        renderAll();
        toast("Duomenys atnaujinti.", "ok");
      } else toast("Nepavyko atnaujinti.", "err");
    });
  });

  document.getElementById("gaBtnClose")?.addEventListener("click", closeAdmin);

  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !root.classList.contains("hidden")) {
      e.preventDefault();
      e.stopPropagation();
      closeAdmin();
    }
  });

  window.addEventListener("message", (e) => {
    const d = e.data;
    if (!d || !d.action) return;
    if (d.action === "adminOpen") openAdmin(d.payload || {});
    if (d.action === "adminClose") {
      root.classList.add("hidden");
      root.setAttribute("aria-hidden", "true");
    }
  });
})();

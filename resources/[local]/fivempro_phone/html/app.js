const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fivempro_phone";

const SCREENS = ["lockScreen", "accountSetup", "homeScreen", "appStoreScreen", "appScreen"];
const APP_TEMPLATE = {
  emergency: "renderEmergencyApp",
  calls: "renderCallsApp",
  messages: "renderMessagesApp",
  contacts: "renderContactsApp",
  ads: "renderAdsApp",
  insta: "renderSocialApp",
  bank: "renderBankApp",
  settings: "renderSettingsApp",
  camera: "renderCameraApp",
  notes: "renderNotesApp",
  shop: "renderShopApp",
  weather: "renderWeatherApp",
  radio: "renderRadioApp",
  cargonet: "renderCargoNetApp",
};
const DOCK_APPS = ["calls", "messages", "contacts", "settings"];
const APPS_PER_PAGE = 16;

const state = {
  me: { number: "000000", name: "Žaidėjas" },
  account: { hasAccount: false, username: "" },
  appStore: { availableApps: [] },
  contacts: [],
  messagePreview: [],
  ads: [],
  posts: [],
  money: { cash: 0, bank: 0 },
  activeCallId: null,
  activeConvNumber: "",
  unlocked: false,
  homePage: 0,
  lockNotifs: [],
};

let lockDragY = 0;

function nui(event, data = {}) {
  return fetch(`https://${resourceName}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  }).then((r) => r.json());
}

function esc(str) {
  return String(str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function iconAssetName(icon) {
  const raw = String(icon || "").trim();
  if (!raw || /[\u{1F300}-\u{1FAFF}]/u.test(raw)) return "appstore";
  return raw.replace(/\.svg$/i, "");
}

function iconUrl(icon) {
  const name = iconAssetName(icon);
  return `assets/icons/${name}.svg`;
}

function iconHtml(icon, className = "app-icon-wrap") {
  const name = iconAssetName(icon);
  return `<span class="${className}"><img src="${iconUrl(name)}" alt="" loading="lazy" onerror="this.src='assets/icons/appstore.svg'" /></span>`;
}

function setLockUiState(locked) {
  const dev = document.querySelector(".device");
  if (!dev) return;
  dev.classList.toggle("screen-locked", !!locked);
  dev.classList.toggle("screen-unlocked", !locked);
}

function showScreen(id) {
  SCREENS.forEach((s) => document.getElementById(s).classList.add("hidden"));
  const el = document.getElementById(id);
  if (el) el.classList.remove("hidden");
}

function tickClock() {
  const now = new Date();
  const t = now.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
  const d = now.toLocaleDateString("lt-LT", { weekday: "long", month: "long", day: "numeric" });
  ["statusTime", "lockTime"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.textContent = t;
  });
  const ld = document.getElementById("lockDate");
  if (ld) ld.textContent = d.charAt(0).toUpperCase() + d.slice(1);
}

function applyWallpaper() {
  const wp = localStorage.getItem("fivempro_phone_wp") || "default";
  const el = document.getElementById("deviceWallpaper");
  if (!el) return;
  const presets = {
    default: "radial-gradient(120% 80% at 20% 0%, rgba(88,86,214,.45), transparent 55%), radial-gradient(90% 70% at 90% 20%, rgba(10,132,255,.35), transparent 50%), linear-gradient(165deg,#0c0c12,#12121c,#08080e)",
    midnight: "linear-gradient(160deg,#050508,#0f0f18 50%,#1a1030)",
    sunset: "linear-gradient(165deg,#1a0a12,#3d1a28 45%,#5c2d14)",
  };
  el.style.background = presets[wp] || presets.default;
}

function renderLockNotifs() {
  const box = document.getElementById("lockNotifs");
  if (!box) return;
  const rows = state.lockNotifs.slice(0, 4);
  box.innerHTML = rows.length
    ? rows.map((n) => `<div class="lock-notif"><b>${esc(n.title)}</b><div>${esc(n.body)}</div>`).join("")
    : "";
}

function pushLockNotif(title, body) {
  state.lockNotifs.unshift({ title, body, at: Date.now() });
  state.lockNotifs = state.lockNotifs.slice(0, 8);
  renderLockNotifs();
}

function unlockPhone() {
  state.unlocked = true;
  setLockUiState(false);
  openHome();
}

function bindLockSwipe() {
  const zone = document.getElementById("lockUnlockZone");
  const bar = document.getElementById("lockBar");
  if (!zone || zone.dataset.bound) return;
  zone.dataset.bound = "1";
  let startY = 0;
  let dragging = false;

  const applyDrag = () => {
    if (bar) bar.style.transform = `translateY(${lockDragY}px)`;
    zone.style.opacity = String(Math.min(1, 0.55 + Math.abs(lockDragY) / 120));
  };

  const onEnd = () => {
    if (!dragging) return;
    dragging = false;
    if (lockDragY < -56) unlockPhone();
    lockDragY = 0;
    if (bar) bar.style.transform = "";
    zone.style.opacity = "";
  };

  const onStart = (clientY) => {
    if (state.unlocked) return;
    dragging = true;
    startY = clientY;
    lockDragY = 0;
  };

  zone.addEventListener("mousedown", (e) => {
    e.preventDefault();
    onStart(e.clientY);
  });
  window.addEventListener("mousemove", (e) => {
    if (!dragging) return;
    lockDragY = e.clientY - startY;
    if (lockDragY > 0) lockDragY = 0;
    applyDrag();
  });
  window.addEventListener("mouseup", onEnd);

  zone.addEventListener("touchstart", (e) => {
    onStart(e.touches[0].clientY);
  }, { passive: true });
  zone.addEventListener("touchmove", (e) => {
    if (!dragging) return;
    lockDragY = e.touches[0].clientY - startY;
    if (lockDragY > 0) lockDragY = 0;
    applyDrag();
  }, { passive: true });
  zone.addEventListener("touchend", onEnd);
}

function installedApps() {
  return (state.appStore.availableApps || []).filter((a) => a.installed || a.default);
}

function storeApps() {
  return (state.appStore.availableApps || []).filter((a) => a.default !== true);
}

function renderHomeApps() {
  const pagesEl = document.getElementById("homePages");
  const dotsEl = document.getElementById("pageDots");
  const dockEl = document.getElementById("dockBar");
  if (!pagesEl || !dockEl) return;

  const all = installedApps().filter((a) => !DOCK_APPS.includes(a.id));
  const pageCount = Math.max(1, Math.ceil(all.length / APPS_PER_PAGE));
  if (state.homePage >= pageCount) state.homePage = 0;

  pagesEl.innerHTML = "";
  for (let p = 0; p < pageCount; p += 1) {
    const page = document.createElement("div");
    page.className = "home-page";
    all.slice(p * APPS_PER_PAGE, (p + 1) * APPS_PER_PAGE).forEach((app) => {
      page.appendChild(makeAppTile(app));
    });
    pagesEl.appendChild(page);
  }
  pagesEl.style.transform = `translateX(-${state.homePage * 100}%)`;

  if (dotsEl) {
    dotsEl.innerHTML = Array.from({ length: pageCount }, (_, i) =>
      `<button type="button" class="page-dot${i === state.homePage ? " active" : ""}" data-page="${i}"></button>`,
    ).join("");
    dotsEl.querySelectorAll(".page-dot").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.homePage = Number(btn.dataset.page) || 0;
        renderHomeApps();
      });
    });
  }

  dockEl.innerHTML = "";
  DOCK_APPS.forEach((id) => {
    const app = installedApps().find((a) => a.id === id);
    if (app) dockEl.appendChild(makeAppTile(app));
  });

  bindHomeSwipe(pagesEl, pageCount);
}

function makeAppTile(app) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "app-tile";
  btn.innerHTML = `${iconHtml(app.icon)}<span class="app-label">${esc(app.label)}</span>`;
  btn.addEventListener("click", () => openApp(app.id));
  return btn;
}

function bindHomeSwipe(pagesEl, pageCount) {
  if (pagesEl.dataset.swipeBound || pageCount < 2) return;
  pagesEl.dataset.swipeBound = "1";
  let sx = 0;
  pagesEl.addEventListener("touchstart", (e) => {
    sx = e.touches[0].clientX;
  }, { passive: true });
  pagesEl.addEventListener("touchend", (e) => {
    const dx = e.changedTouches[0].clientX - sx;
    if (Math.abs(dx) < 48) return;
    if (dx < 0 && state.homePage < pageCount - 1) state.homePage += 1;
    if (dx > 0 && state.homePage > 0) state.homePage -= 1;
    renderHomeApps();
  }, { passive: true });
}

function openHome() {
  if (!state.account?.hasAccount) {
    showScreen("accountSetup");
    setLockUiState(false);
    return;
  }
  if (!state.unlocked) {
    setLockUiState(true);
    showScreen("lockScreen");
    renderLockNotifs();
    return;
  }
  setLockUiState(false);
  showScreen("homeScreen");
  renderHomeApps();
}

function setCallUiActive(active) {
  document.querySelector(".device")?.classList.toggle("phone-call-active", !!active);
}

function hideCallOverlay() {
  const ov = document.getElementById("callOverlay");
  if (!ov) return;
  ov.classList.add("hidden");
  ov.setAttribute("aria-hidden", "true");
  setCallUiActive(false);
}

function showIncomingCallOverlay(payload = {}) {
  const ov = document.getElementById("callOverlay");
  if (!ov) return;
  const num = payload?.fromNumber || "Nežinomas nr.";
  const nm = (payload?.fromName || "").trim();
  document.getElementById("callOverlaySub").textContent = num;
  document.getElementById("callOverlayTitle").textContent = nm ? `Skambina · ${nm}` : "Įeinantis skambutis";
  ov.classList.remove("hidden");
  ov.setAttribute("aria-hidden", "false");
  setCallUiActive(true);
}

function syncPendingIncomingCall(payload) {
  const pending = payload?.pendingIncomingCall;
  if (pending && pending.id) {
    state.activeCallId = pending.id;
    showIncomingCallOverlay(pending);
    return;
  }
  if (!state.activeCallId) {
    hideCallOverlay();
  }
}

async function respondToCall(accept) {
  const id = state.activeCallId;
  hideCallOverlay();
  state.activeCallId = null;
  if (!id) {
    openHome();
    return;
  }
  await nui("respondCall", { callId: id, accept: !!accept });
  if (accept) {
    state.unlocked = true;
    openHome();
  } else {
    setLockUiState(true);
    showScreen("lockScreen");
  }
}

function hydrate(payload = {}) {
  state.me = payload.me || state.me;
  state.account = payload.account || state.account;
  state.appStore = payload.appStore || state.appStore;
  state.contacts = payload.contacts || [];
  state.messagePreview = payload.messagePreview || [];
  state.ads = payload.ads || [];
  state.posts = payload.posts || [];
  state.money = payload.money || state.money;
  const name = state.account.username || state.me.name || "Žaidėjas";
  const pn = document.getElementById("profileName");
  if (pn) pn.textContent = `Sveiki, ${name}`;
  applyWallpaper();
  syncPendingIncomingCall(payload);
  if (!state.activeCallId) openHome();
}

function renderAppStore() {
  const list = document.getElementById("storeList");
  const rows = storeApps();
  list.innerHTML = rows.length
    ? rows
        .map((app) => {
          const done = app.installed || app.default;
          const desc = app.description || "Papildoma programėlė";
          return `<div class="card store-row">
          ${iconHtml(app.icon, "store-app-icon")}
          <div class="store-row-info">
            <b>${esc(app.label)}</b>
            <div class="small muted">${esc(desc)}</div>
          </div>
          <button type="button" data-install-app="${esc(app.id)}" ${done ? "disabled" : ""}>${done ? "Įdiegta" : "Gauti"}</button>
        </div>`;
        })
        .join("")
    : `<div class="card muted">Visos papildomos programėlės jau įdiegtos.</div>`;
  list.querySelectorAll("[data-install-app]:not([disabled])").forEach((btn) => {
    btn.addEventListener("click", async () => {
      await nui("installApp", { appId: btn.dataset.installApp });
      hydrate(await nui("refresh"));
      showScreen("appStoreScreen");
      renderAppStore();
    });
  });
}

function openAppStore() {
  showScreen("appStoreScreen");
  renderAppStore();
}

async function openApp(appId) {
  if (appId === "appstore") {
    openAppStore();
    return;
  }
  showScreen("appScreen");
  document.getElementById("appTitle").textContent =
    installedApps().find((a) => a.id === appId)?.label || appId;
  const content = document.getElementById("appContent");
  const fn = APP_TEMPLATE[appId];
  if (!fn || typeof window[fn] !== "function") {
    content.innerHTML = `<div class="card">Programėlė ruošiama.</div>`;
    return;
  }
  window[fn](content);
}

window.renderEmergencyApp = (content) => {
  content.innerHTML = `<div class="card"><b>Skubus iškvietimas</b><div class="row"><button data-emerg="police">Policija</button><button data-emerg="ems">Greitoji</button></div><div class="row"><button data-emerg="taxi">Taksi</button><button data-emerg="mechanic">Mechanikas</button></div></div>`;
  content.querySelectorAll("[data-emerg]").forEach((btn) =>
    btn.addEventListener("click", () => nui("emergencyCall", { service: btn.dataset.emerg })),
  );
};

window.renderCallsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="callNumber" placeholder="Numeris" /><button id="btnCall">Skambinti</button></div><button id="btnHangup">Baigti</button><p class="muted small">Jūsų nr: ${esc(state.me.number)}</p></div>`;
  document.getElementById("btnCall").addEventListener("click", () =>
    nui("startCall", { number: (document.getElementById("callNumber").value || "").replace(/\D+/g, "") }),
  );
  document.getElementById("btnHangup").addEventListener("click", () =>
    state.activeCallId && nui("endCall", { callId: state.activeCallId }),
  );
};

window.renderMessagesApp = (content) => {
  const n = state.activeConvNumber || "";
  const rows = state.messagePreview.filter((m) => !n || String(m.from_number) === n || String(m.to_number) === n);
  content.innerHTML = `<div class="card"><div class="row"><input id="msgNumber" value="${esc(n)}" placeholder="Numeris" /><button id="btnLoadConv">Atidaryti</button></div><div id="conversationList">${rows.map((m) => `<div class="small">${esc(m.from_number)}: ${esc(m.body)}</div>`).join("")}</div><div class="row"><input id="msgBody" placeholder="Žinutė" /><button id="btnSendMsg">Siųsti</button></div></div>`;
  document.getElementById("btnLoadConv").addEventListener("click", () => {
    state.activeConvNumber = (document.getElementById("msgNumber").value || "").replace(/\D+/g, "");
    openApp("messages");
  });
  document.getElementById("btnSendMsg").addEventListener("click", async () => {
    const number = (document.getElementById("msgNumber").value || "").replace(/\D+/g, "");
    const body = document.getElementById("msgBody").value || "";
    if (!number || !body) return;
    await nui("sendMessage", { number, body });
    hydrate(await nui("refresh"));
    openApp("messages");
  });
};

window.renderContactsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="contactName" placeholder="Vardas" /><input id="contactNumber" placeholder="Nr" /></div><button id="btnSaveContact">Išsaugoti</button></div>${state.contacts.map((c) => `<div class="card">${esc(c.display_name)} (${esc(c.contact_number)})</div>`).join("")}`;
  document.getElementById("btnSaveContact").addEventListener("click", async () => {
    await nui("saveContact", {
      name: document.getElementById("contactName").value,
      number: document.getElementById("contactNumber").value,
    });
    hydrate(await nui("refresh"));
    openApp("contacts");
  });
};

window.renderAdsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="adBody" placeholder="Skelbimas" /><button id="btnPostAd">Kelti</button></div></div>${state.ads.map((a) => `<div class="card"><b>${esc(a.author_name)}</b><div>${esc(a.body)}</div></div>`).join("")}`;
  document.getElementById("btnPostAd").addEventListener("click", async () => {
    await nui("createAd", { body: document.getElementById("adBody").value });
    hydrate(await nui("refresh"));
    openApp("ads");
  });
};

window.renderSocialApp = (content) => {
  content.innerHTML = `<div class="card"><input id="postCaption" placeholder="Aprašymas" /><input id="postImageUrl" placeholder="Nuotraukos nuoroda" /><button id="btnPostInsta">Kelti</button></div>${state.posts.map((p) => `<div class="card"><b>${esc(p.author_name)}</b><div>${esc(p.caption)}</div><button data-like="${Number(p.id)}">Patinka ${Number(p.likes || 0)}</button></div>`).join("")}`;
  document.getElementById("btnPostInsta").addEventListener("click", async () => {
    await nui("createPost", {
      caption: document.getElementById("postCaption").value,
      imageUrl: document.getElementById("postImageUrl").value,
    });
    hydrate(await nui("refresh"));
    openApp("insta");
  });
  content.querySelectorAll("[data-like]").forEach((b) =>
    b.addEventListener("click", async () => {
      await nui("likePost", { postId: Number(b.dataset.like) });
      hydrate(await nui("refresh"));
      openApp("insta");
    }),
  );
};

window.renderBankApp = (content) => {
  const cash = Number(state.money.cash || 0);
  const bank = Number(state.money.bank || 0);
  content.innerHTML = `<div class="card"><b>Piniginė</b><p>Grynieji: $${cash.toLocaleString("lt-LT")}</p><p>Bankas: $${bank.toLocaleString("lt-LT")}</p><p class="muted small">Balansas sinchronizuojamas su QBCore.</p></div>`;
};

window.renderSettingsApp = (content) => {
  const wp = localStorage.getItem("fivempro_phone_wp") || "default";
  content.innerHTML = `
    <div class="card">
      <div class="settings-row"><span>Numeris</span><span>${esc(state.me.number)}</span></div>
      <div class="settings-row"><span>Paskyra</span><span>${esc(state.account.username || "—")}</span></div>
    </div>
    <div class="card">
      <label class="small muted">Fonas</label>
      <select id="wpSelect">
        <option value="default"${wp === "default" ? " selected" : ""}>Numatyta</option>
        <option value="midnight"${wp === "midnight" ? " selected" : ""}>Vidurnaktis</option>
        <option value="sunset"${wp === "sunset" ? " selected" : ""}>Saulėlydis</option>
      </select>
    </div>`;
  document.getElementById("wpSelect").addEventListener("change", (e) => {
    localStorage.setItem("fivempro_phone_wp", e.target.value);
    applyWallpaper();
  });
};

window.renderCameraApp = (content) => {
  content.innerHTML = `<div class="card"><p>Foto režimas. Uždaryti: <b>ESC</b> arba <b>Backspace</b>.</p><button id="btnCam" class="ios-btn primary">Atidaryti kamerą</button><button id="btnCamClose" class="ios-btn" type="button">Uždaryti kamerą</button></div>`;
  document.getElementById("btnCam").addEventListener("click", () => nui("openCamera", {}));
  document.getElementById("btnCamClose").addEventListener("click", () => nui("closeCamera", {}));
};

window.renderShopApp = (content) => {
  content.innerHTML = `<div class="card"><b>Marketplace</b><p class="muted small">Apsipirkite miesto NPC parduotuvėse.</p><button id="btnShopHint" class="ios-btn primary">Patikrinti parduotuves</button></div>`;
  document.getElementById("btnShopHint").addEventListener("click", () => nui("shopHint", {}));
};

window.renderWeatherApp = (content) => {
  content.innerHTML = `<div class="card"><b>Orai Los Santos</b><p id="weatherText" class="muted">Kraunama…</p></div>`;
  nui("getWeather", {}).then((res) => {
    const el = document.getElementById("weatherText");
    if (el) el.textContent = res?.label || "Giedra, ~24°C";
  });
};

window.renderRadioApp = (content) => {
  const stations = [
    { id: "pop", label: "Los Santos pop" },
    { id: "rock", label: "Roko stotis" },
    { id: "news", label: "Weazel naujienos" },
  ];
  content.innerHTML = `<div class="card"><b>Radijas</b><p class="muted small">Pasirinkite stotį.</p>${stations.map((s) => `<button type="button" class="ios-btn" data-radio="${s.id}" style="width:100%;margin-top:8px">${esc(s.label)}</button>`).join("")}</div>`;
  content.querySelectorAll("[data-radio]").forEach((btn) =>
    btn.addEventListener("click", () => nui("radioStation", { station: btn.dataset.radio })),
  );
};

window.renderCargoNetApp = (content) => {
  content.innerHTML = `<div class="card"><b>CargoNet</b><p class="muted small">Krovinių birža ir logistikos kontraktai.</p><button id="btnOpenCargoNet" class="ios-btn primary">Atidaryti TruckNet</button></div>`;
  document.getElementById("btnOpenCargoNet").addEventListener("click", () => nui("openCargoNet", {}));
};

window.renderNotesApp = (content) => {
  const notes = localStorage.getItem("fivempro_phone_notes") || "";
  content.innerHTML = `<div class="card"><textarea id="notesArea" rows="12" placeholder="Užrašai…">${esc(notes)}</textarea><button id="btnSaveNotes" class="ios-btn primary">Išsaugoti</button></div>`;
  document.getElementById("btnSaveNotes").addEventListener("click", () => {
    localStorage.setItem("fivempro_phone_notes", document.getElementById("notesArea").value);
  });
};

window.addEventListener("message", async (e) => {
  const { action, payload } = e.data || {};
  if (action === "open") {
    state.unlocked = false;
    setLockUiState(true);
    document.getElementById("phone").classList.remove("hidden");
    tickClock();
    showScreen("lockScreen");
    renderLockNotifs();
  } else if (action === "close") {
    hideCallOverlay();
    state.activeCallId = null;
    document.getElementById("phone").classList.add("hidden");
    state.unlocked = false;
    setLockUiState(true);
  } else if (action === "hydrate") {
    hydrate(payload || {});
  } else if (action === "newMessageNotify") {
    const from = payload?.fromNumber || "Nežinomas";
    pushLockNotif("Žinutė", from);
    hydrate(await nui("refresh"));
  } else if (action === "incomingCall") {
    state.activeCallId = payload?.id || null;
    pushLockNotif("Skambutis", payload?.fromNumber || "Nežinomas");
    showIncomingCallOverlay(payload || {});
  } else if (action === "callState") {
    const st = payload?.status || "";
    const cs = document.getElementById("callState");
    if (cs) cs.textContent = st;
    if (/(ended|rejected|busy|failed)/i.test(st)) {
      state.activeCallId = null;
      hideCallOverlay();
      if (!state.unlocked) showScreen("lockScreen");
      else openHome();
    } else if (payload?.id) {
      state.activeCallId = payload.id;
    }
  }
});

document.getElementById("homeBar").addEventListener("click", openHome);
document.getElementById("callReject").addEventListener("click", (e) => {
  e.preventDefault();
  e.stopPropagation();
  respondToCall(false);
});
document.getElementById("callAccept").addEventListener("click", (e) => {
  e.preventDefault();
  e.stopPropagation();
  respondToCall(true);
});
window.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  const phone = document.getElementById("phone");
  if (!phone || phone.classList.contains("hidden")) return;
  e.preventDefault();
  nui("close");
});
document.getElementById("openStore")?.addEventListener("click", openAppStore);
document.querySelectorAll("[data-back-home]").forEach((b) => b.addEventListener("click", openHome));
document.getElementById("btnCreateAccount").addEventListener("click", async () => {
  const res = await nui("createAccount", {
    username: document.getElementById("setupUsername").value,
    password: document.getElementById("setupPassword").value,
  });
  document.getElementById("setupState").textContent = res?.ok ? "Paskyra sukurta." : res?.message || "Klaida";
  hydrate(await nui("refresh"));
});

setInterval(tickClock, 15000);
tickClock();
bindLockSwipe();
applyWallpaper();
setLockUiState(true);

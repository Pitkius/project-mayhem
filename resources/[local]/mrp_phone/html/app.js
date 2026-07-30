function getResourceName() {
  return typeof GetParentResourceName === "function" ? GetParentResourceName() : "mrp_phone";
}

const SCREENS = ["lockScreen", "accountSetup", "homeScreen", "appStoreScreen", "appScreen"];
const APP_TEMPLATE = {
  calls: "renderCallsApp",
  messages: "renderMessagesApp",
  contacts: "renderContactsApp",
  ads: "renderAdsApp",
  gallery: "renderGalleryApp",
  carplay: "renderCarplayApp",
  insta: "renderSocialApp",
  bank: "renderBankApp",
  settings: "renderSettingsApp",
  camera: "renderCameraApp",
  notes: "renderNotesApp",
  weather: "renderWeatherApp",
};
const DOCK_APPS = ["calls", "messages", "contacts", "settings"];
const APPS_PER_PAGE = 16;

const state = {
  me: { number: "000000", name: "Žaidėjas", citizenid: "" },
  account: { hasAccount: false, username: "" },
  appStore: { availableApps: [] },
  contacts: [],
  messagePreview: [],
  messageThreads: [],
  ads: [],
  adCategories: [],
  adProfile: null,
  photos: [],
  notes: [],
  notesOldDays: 30,
  posts: [],
  money: { cash: 0, bank: 0 },
  activeCallId: null,
  activeConvNumber: "",
  contactEditId: null,
  adsFilter: "all",
  adsMineOnly: false,
  unlocked: false,
  homePage: 0,
  lockNotifs: [],
};

window.PhoneState = state;
window.PhoneNui = nui;
window.PhoneEsc = esc;
window.PhoneIconHtml = iconHtml;

function isPhoneTextInput(el) {
  if (!el) return false;
  const tag = el.tagName;
  if (tag === "TEXTAREA") return true;
  if (tag === "INPUT") {
    const type = (el.type || "text").toLowerCase();
    return !["button", "submit", "checkbox", "radio", "range", "file", "hidden"].includes(type);
  }
  return el.isContentEditable === true;
}

function phoneHasActiveTextInput() {
  const phone = document.getElementById("phone");
  const active = document.activeElement;
  if (!phone || !active || !phone.contains(active)) return false;
  return isPhoneTextInput(active);
}

function syncPhoneInputFocus() {
  nui("phoneInputFocus", { focused: phoneHasActiveTextInput() }).catch(() => {});
}

let lockDragY = 0;

function nui(event, data = {}) {
  return fetch(`https://${getResourceName()}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  }).then(async (r) => {
    const text = await r.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch (_) {
      return { ok: false, raw: text };
    }
  });
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
  const wp = localStorage.getItem("mrp_phone_wp") || "default";
  const el = document.getElementById("deviceWallpaper");
  if (!el) return;
  const presets = {
    default: "radial-gradient(120% 80% at 20% 0%, rgba(191,95,255,.42), transparent 55%), radial-gradient(90% 70% at 90% 20%, rgba(157,78,221,.28), transparent 50%), linear-gradient(165deg,#0c0c12,#12121c,#08080e)",
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

function stopCameraUi() {
  nui("cameraStopLive", {}).catch(() => {});
  document.getElementById("phone")?.classList.remove("camera-live-mode");
}

function openHome() {
  stopCameraUi();
  state.currentApp = null;
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
  state.messageThreads = payload.messageThreads || [];
  state.ads = payload.ads || [];
  state.adCategories = payload.adCategories || [];
  state.adProfile = payload.adProfile || null;
  state.photos = payload.photos || [];
  state.notes = Array.isArray(payload.notes) ? payload.notes : (Array.isArray(state.notes) ? state.notes : []);
  state.notesOldDays = Number(payload.notesOldDays) > 0 ? Number(payload.notesOldDays) : 30;
  state.posts = payload.posts || [];
  state.money = payload.money || state.money;
  const name = state.account.username || state.me.name || "Žaidėjas";
  const pn = document.getElementById("profileName");
  if (pn) pn.textContent = `Sveiki, ${name}`;
  applyWallpaper();
  syncPendingIncomingCall(payload);
  const onCamera = state.currentApp === "camera" || document.getElementById("cameraScreen")?.classList.contains("active");
  if (!state.activeCallId && !onCamera) openHome();
}

window.PhoneHydrate = hydrate;

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
  state.currentApp = appId;
  if (appId !== "camera") {
    stopCameraUi();
  }
  if (appId === "appstore") {
    openAppStore();
    return;
  }
  showScreen("appScreen");
  document.getElementById("appScreen")?.classList.toggle("app-fullscreen", appId === "ads" || appId === "bank");
  document.getElementById("appTitle").textContent =
    installedApps().find((a) => a.id === appId)?.label || appId;
  const content = document.getElementById("appContent");
  content.className = "scroll-body";
  const phoneApp = window.PhoneApps && window.PhoneApps[`render${appId.charAt(0).toUpperCase()}${appId.slice(1)}App`];
  if (phoneApp) {
    phoneApp(content);
    return;
  }
  const fn = APP_TEMPLATE[appId];
  if (!fn || typeof window[fn] !== "function") {
    content.innerHTML = `<div class="card">Programėlė ruošiama.</div>`;
    return;
  }
  const rendered = window[fn](content);
  if (rendered && typeof rendered.then === "function") await rendered;
}

window.PhoneOpenApp = openApp;

window.renderSocialApp = async (content) => {
  content.className = "scroll-body insta-body";
  const draft = window.PhoneState._lgDraft || { caption: "", photoId: null, preview: "" };
  window.PhoneState._lgDraft = draft;

  const posts = state.posts || [];
  const postsHtmlParts = [];
  if (!posts.length) {
    postsHtmlParts.push(`<div class="lg-empty muted">Dar nėra įrašų. Būk pirmas!</div>`);
  } else {
    for (const p of posts) {
      let media = "";
      if (p.image_url) {
        const src = window.PhoneResolveImageRef
          ? await window.PhoneResolveImageRef(p.image_url)
          : p.image_url;
        if (src) {
          media = `<div class="lg-post-media"><img src="${esc(src)}" alt="" loading="lazy" /></div>`;
        }
      }
      postsHtmlParts.push(`<article class="lg-post neon-card">
        <header class="lg-post-head"><strong>${esc(p.author_name)}</strong></header>
        ${media}
        <p class="lg-post-caption">${esc(p.caption || "")}</p>
        <footer class="lg-post-actions">
          <button type="button" class="lg-like-btn" data-like="${Number(p.id)}">♥ Patinka ${Number(p.likes || 0)}</button>
        </footer>
      </article>`);
    }
  }

  const previewHtml = draft.preview
    ? `<div class="lg-compose-preview" style="background-image:url('${esc(draft.preview)}')"></div>`
    : `<div class="lg-compose-preview empty">Nuotrauka nepasirinkta</div>`;

  content.innerHTML = `
    <div class="lg-app">
      <section class="lg-compose neon-card">
        <h3 class="lg-compose-title">Naujas įrašas</h3>
        <input id="postCaption" placeholder="Aprašymas" maxlength="260" value="${esc(draft.caption)}" />
        <div class="lg-compose-media">
          ${previewHtml}
          <div class="lg-compose-actions">
            <button type="button" class="neon-btn" id="btnLgPickPhoto">Iš galerijos</button>
            <button type="button" class="neon-btn" id="btnLgOpenCam">Kamera</button>
            ${draft.photoId ? `<button type="button" class="neon-btn danger" id="btnLgClearPhoto">Pašalinti</button>` : ""}
          </div>
        </div>
        <button type="button" id="btnPostInsta" class="neon-btn primary">Kelti</button>
        <p class="muted small" id="lgPostStatus"></p>
      </section>
      <div class="lg-feed">${postsHtmlParts.join("")}</div>
    </div>`;

  const captionEl = content.querySelector("#postCaption");
  captionEl?.addEventListener("input", () => {
    draft.caption = captionEl.value || "";
  });

  content.querySelector("#btnLgPickPhoto")?.addEventListener("click", () => {
    if (!window.PhoneShowPhotoPicker) return;
    window.PhoneShowPhotoPicker((id, preview) => {
      draft.photoId = id;
      draft.preview = preview;
      openApp("insta");
    });
  });
  content.querySelector("#btnLgOpenCam")?.addEventListener("click", () => openApp("camera"));
  content.querySelector("#btnLgClearPhoto")?.addEventListener("click", () => {
    draft.photoId = null;
    draft.preview = "";
    openApp("insta");
  });

  content.querySelector("#btnPostInsta")?.addEventListener("click", async () => {
    const status = content.querySelector("#lgPostStatus");
    const caption = captionEl?.value || "";
    if (!caption.trim() && !draft.photoId) {
      if (status) status.textContent = "Įrašyk aprašymą arba pasirink nuotrauką.";
      return;
    }
    const res = await nui("createPost", {
      caption,
      imageUrl: draft.photoId ? `gallery:${draft.photoId}` : "",
    });
    if (!res?.ok) {
      if (status) status.textContent = res?.message || "Nepavyko įkelti.";
      return;
    }
    draft.caption = "";
    draft.photoId = null;
    draft.preview = "";
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

window.renderSettingsApp = (content) => {
  const wp = localStorage.getItem("mrp_phone_wp") || "default";
  content.className = "scroll-body";
  content.innerHTML = `
    <div class="settings-app">
      <div class="neon-card settings-card">
        <div class="settings-row"><span>Numeris</span><b>${esc(state.me.number)}</b></div>
        <div class="settings-row"><span>Paskyra</span><b>${esc(state.account.username || "—")}</b></div>
        <div class="settings-row"><span>Vardas</span><b>${esc(state.me.name || "—")}</b></div>
      </div>
      <div class="neon-card settings-card">
        <label class="small muted">Fono tema</label>
        <div class="settings-wp-grid">
          ${["default", "midnight", "sunset"]
            .map(
              (id) =>
                `<button type="button" class="settings-wp-btn${wp === id ? " active" : ""}" data-wp="${id}">
                  <span class="settings-wp-swatch wp-${id}"></span>
                  <span>${id === "default" ? "Numatyta" : id === "midnight" ? "Vidurnaktis" : "Saulėlydis"}</span>
                </button>`,
            )
            .join("")}
        </div>
      </div>
      <div class="neon-card settings-card">
        <p class="muted small">Nuotraukos: ${Number((state.photos || []).length)} · Užrašai: ${Number((state.notes || []).length)}</p>
      </div>
    </div>`;
  content.querySelectorAll("[data-wp]").forEach((btn) => {
    btn.addEventListener("click", () => {
      localStorage.setItem("mrp_phone_wp", btn.dataset.wp);
      applyWallpaper();
      openApp("settings");
    });
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
    syncPhoneInputFocus();
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
    const labels = {
      ringing: "Skambinama…",
      connected: "Skambutis aktyvus",
      ended: "Skambutis baigtas",
      rejected: "Atmesta",
      busy: "Užimta",
      failed: "Nepavyko",
    };
    const cs = document.getElementById("callState");
    if (cs) cs.textContent = labels[st] || st;
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
  nui("close").catch(() => {});
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

const phoneRoot = document.getElementById("phone");
if (phoneRoot) {
  phoneRoot.addEventListener("focusin", (e) => {
    if (!isPhoneTextInput(e.target)) return;
    syncPhoneInputFocus();
  });
  phoneRoot.addEventListener("focusout", () => {
    setTimeout(syncPhoneInputFocus, 0);
  });
}

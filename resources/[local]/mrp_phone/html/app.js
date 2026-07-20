const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "mrp_phone";

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
  socialProfile: null,
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

function themeCssVar(name, fallback) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return v || fallback || "";
}

function themedWallpaperPresets() {
  const glow = themeCssVar("--phone-wall-glow", "rgba(124, 58, 237, 0.45)");
  const soft = themeCssVar("--primary-soft", "rgba(167, 139, 250, 0.28)");
  return {
    default: `radial-gradient(120% 80% at 20% 0%, ${glow}, transparent 55%), radial-gradient(90% 70% at 90% 20%, rgba(10, 132, 255, 0.35), transparent 50%), linear-gradient(165deg, #0c0c12 0%, #12121c 40%, #08080e 100%)`,
    midnight: "linear-gradient(160deg, #050508, #0f0f18 50%, #1a1030)",
    sunset: "linear-gradient(165deg, #1a0a12, #3d1a28 45%, #5c2d14)",
    violet: `radial-gradient(100% 80% at 50% 0%, ${soft}, transparent 60%), linear-gradient(165deg, #0a0612, #140a22, #080510)`,
  };
}

function applyWallpaper() {
  const wp = localStorage.getItem("mrp_phone_wp") || "default";
  const el = document.getElementById("deviceWallpaper");
  if (!el) return;
  const presets = themedWallpaperPresets();
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
  if (localStorage.getItem("mrp_phone_notifs") === "0") return;
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
  document.getElementById("appScreen")?.classList.remove("app-fullscreen", "app-insta-full");
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
  state.socialProfile = payload.socialProfile || null;
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

/** Aktyvūs App Store siuntimai: appId -> { started, duration, timer } */
const storeDownloads = {};

function storeDownloadPct(appId) {
  const d = storeDownloads[appId];
  if (!d) return 0;
  return Math.min(100, Math.floor(((Date.now() - d.started) / d.duration) * 100));
}

function clearStoreDownload(appId) {
  const d = storeDownloads[appId];
  if (d?.timer) clearInterval(d.timer);
  delete storeDownloads[appId];
}

async function finishStoreDownload(appId) {
  clearStoreDownload(appId);
  const res = await nui("installApp", { appId });
  hydrate(await nui("refresh"));
  showScreen("appStoreScreen");
  renderAppStore();
  if (res && res.ok === false && res.message) {
    /* silent — refresh already shows state */
  }
}

function startStoreDownloadTick(appId) {
  const d = storeDownloads[appId];
  if (!d) return;
  if (d.timer) clearInterval(d.timer);
  d.timer = setInterval(() => {
    if (!storeDownloads[appId]) return;
    const pct = storeDownloadPct(appId);
    const btn = document.querySelector(`[data-install-app="${String(appId).replace(/"/g, "")}"]`);
    if (btn) {
      btn.disabled = true;
      btn.classList.add("is-downloading");
      btn.innerHTML = `<span class="store-dl-ring" style="--p:${pct}"></span><span class="store-dl-label">${pct}%</span>`;
      const bar = btn.closest(".store-row")?.querySelector(".store-dl-bar > i");
      if (bar) bar.style.width = `${pct}%`;
    }
    if (pct >= 100) {
      clearInterval(storeDownloads[appId].timer);
      storeDownloads[appId].timer = null;
      finishStoreDownload(appId);
    }
  }, 120);
}

function renderAppStore() {
  const list = document.getElementById("storeList");
  const rows = storeApps();
  list.innerHTML = rows.length
    ? rows
        .map((app) => {
          const done = app.installed || app.default;
          const desc = app.description || "Papildoma programėlė";
          const dl = storeDownloads[app.id];
          const pct = dl ? storeDownloadPct(app.id) : 0;
          let action;
          if (done) {
            action = `<button type="button" disabled>Įdiegta</button>`;
          } else if (dl) {
            action = `<button type="button" class="is-downloading" data-install-app="${esc(app.id)}" disabled>
              <span class="store-dl-ring" style="--p:${pct}"></span>
              <span class="store-dl-label">${pct}%</span>
            </button>`;
          } else {
            action = `<button type="button" data-install-app="${esc(app.id)}">Gauti</button>`;
          }
          return `<div class="card store-row${dl ? " is-downloading" : ""}">
          ${iconHtml(app.icon, "store-app-icon")}
          <div class="store-row-info">
            <b>${esc(app.label)}</b>
            <div class="small muted">${esc(desc)}</div>
            ${dl ? `<div class="store-dl-bar"><i style="width:${pct}%"></i></div>` : ""}
          </div>
          ${action}
        </div>`;
        })
        .join("")
    : `<div class="card muted">Visos papildomos programėlės jau įdiegtos.</div>`;

  list.querySelectorAll("[data-install-app]:not([disabled])").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const appId = btn.dataset.installApp;
      if (!appId || storeDownloads[appId]) return;
      btn.disabled = true;
      btn.textContent = "…";
      const res = await nui("beginAppDownload", { appId });
      if (!res || !res.ok) {
        btn.disabled = false;
        btn.textContent = "Gauti";
        return;
      }
      const duration = Math.max(3000, Number(res.durationMs) || 8000);
      storeDownloads[appId] = { started: Date.now(), duration, timer: null };
      renderAppStore();
      startStoreDownloadTick(appId);
    });
  });

  Object.keys(storeDownloads).forEach((appId) => {
    if (!storeDownloads[appId].timer) startStoreDownloadTick(appId);
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
  const appScreen = document.getElementById("appScreen");
  appScreen?.classList.toggle("app-fullscreen", appId === "ads" || appId === "bank" || appId === "insta");
  appScreen?.classList.toggle("app-insta-full", appId === "insta");
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

const lgUi = { tab: "feed", draftPhotoId: null };

function phoneIco(name) {
  return window.PhoneIco ? window.PhoneIco(name) : "";
}

function parsePostImageRef(raw) {
  const img = String(raw || "").trim();
  if (!img) return { url: "", photoId: 0 };
  if (img.startsWith("p:")) {
    const photoId = Number(img.replace("p:", ""));
    return { url: "", photoId: Number.isFinite(photoId) ? photoId : 0 };
  }
  if (img.startsWith("http") || img.startsWith("data:")) return { url: img, photoId: 0 };
  return { url: img, photoId: 0 };
}

async function resolvePostImage(raw) {
  const ref = parsePostImageRef(raw);
  if (ref.url) return ref.url;
  if (!ref.photoId) return "";
  const res = await nui("getPhoto", { id: ref.photoId });
  if (res?.ok && res.photo?.image) {
    return window.PhoneNormalizeImageSrc
      ? window.PhoneNormalizeImageSrc(res.photo.image)
      : res.photo.image;
  }
  return "";
}

function lgInitials(name) {
  const parts = String(name || "?").trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

function hasSocialProfile() {
  return !!(state.socialProfile && state.socialProfile.username);
}

function renderSocialSetup(content) {
  content.className = "scroll-body insta-body";
  const prof = state.socialProfile;
  content.innerHTML = `
    <div class="lg-app">
      <div class="lg-header-bar"><span class="lg-brand">LifeGram</span></div>
      <section class="lg-compose neon-card" style="margin:12px 14px">
        <h3 class="lg-compose-title">${prof?.username ? "Redaguoti paskyrą" : "Sukurti LifeGram paskyrą"}</h3>
        <p class="muted small">Telefono paskyra neatstoja — reikia atskiros LifeGram paskyros.</p>
        <label class="small muted">Vartotojo vardas</label>
        <input id="lgUsername" placeholder="Pvz. Mantas123" maxlength="24" value="${esc(prof?.username || "")}" />
        <label class="small muted" style="display:block;margin-top:10px">Bio</label>
        <textarea id="lgBio" placeholder="Trumpas aprašymas…" rows="3" maxlength="200" style="width:100%;resize:vertical">${esc(prof?.bio || "")}</textarea>
        <button type="button" id="btnSaveSocial" class="neon-btn primary">Išsaugoti</button>
        <div class="muted small" id="lgSetupMsg" style="margin-top:8px"></div>
      </section>
    </div>`;

  content.querySelector("#btnSaveSocial")?.addEventListener("click", async () => {
    const msg = content.querySelector("#lgSetupMsg");
    const res = await nui("saveSocialProfile", {
      username: content.querySelector("#lgUsername")?.value,
      bio: content.querySelector("#lgBio")?.value,
    });
    if (!res?.ok) {
      if (msg) msg.textContent = res?.message || "Klaida";
      return;
    }
    hydrate(await nui("refresh"));
    lgUi.tab = "feed";
    openApp("insta");
  });
}

window.renderSocialApp = async (content) => {
  if (!hasSocialProfile()) {
    renderSocialSetup(content);
    return;
  }

  content.className = "scroll-body insta-body";
  const tab = lgUi.tab || "feed";
  const handle = state.socialProfile.username;
  const bio = state.socialProfile.bio || "";
  const myPosts = (state.posts || []).filter((p) => p.author_name === handle);

  const renderFeed = async () => {
    const posts = state.posts || [];
    if (!posts.length) return `<div class="lg-empty muted">Dar nėra įrašų. Būk pirmas!</div>`;
    const cards = await Promise.all(
      posts.map(async (p) => {
        const imgSrc = p.image_url ? await resolvePostImage(p.image_url) : "";
        const img = imgSrc
          ? `<div class="lg-post-media"><img src="${esc(imgSrc)}" alt="" loading="lazy" /></div>`
          : "";
        return `<article class="lg-post-card">
          <header class="lg-post-head">
            <div class="core-avatar sm">${esc(lgInitials(p.author_name))}</div>
            <strong>@${esc(p.author_name)}</strong>
          </header>
          ${img}
          <p class="lg-post-caption">${esc(p.caption || "")}</p>
          <footer class="lg-post-actions">
            <button type="button" class="lg-like-btn" data-like="${Number(p.id)}">${phoneIco("heart")} Patinka · ${Number(p.likes || 0)}</button>
          </footer>
        </article>`;
      }),
    );
    return `<div class="lg-feed">${cards.join("")}</div>`;
  };

  const renderCreate = () => {
    const photos = state.photos || [];
    const photoPick = photos.length
      ? `<div class="lg-photo-pick" id="lgPhotoPick">${photos
          .slice(0, 8)
          .map(
            (ph) =>
              `<button type="button" data-photo="${Number(ph.id)}" class="${lgUi.draftPhotoId === Number(ph.id) ? "selected" : ""}" style="background-image:url('')"></button>`,
          )
          .join("")}</div>`
      : `<p class="muted small">Nėra nuotraukų — naudokite Kamerą arba įklijuokite nuorodą.</p>`;

    return `<section class="lg-compose neon-card" style="margin:12px 14px">
      <h3 class="lg-compose-title">Naujas įrašas</h3>
      <textarea id="postCaption" placeholder="Ką norite pasakyti?" rows="3" style="width:100%;resize:vertical"></textarea>
      <label class="small muted" style="display:block;margin-top:10px">Nuotrauka iš galerijos</label>
      ${photoPick}
      <input id="postImageUrl" placeholder="Arba nuotraukos nuoroda (URL)" style="margin-top:10px" />
      <button type="button" id="btnPostInsta" class="neon-btn primary">Kelti įrašą</button>
    </section>`;
  };

  const renderProfile = () => {
    return `<div class="lg-profile-hero">
      <div class="core-avatar">${esc(lgInitials(handle))}</div>
      <b>@${esc(handle)}</b>
      <div class="muted small">${esc(bio || "Nėra bio")}</div>
      <div class="lg-post-stats"><span><b>${myPosts.length}</b> įrašai</span><span><b>${myPosts.reduce((s, p) => s + Number(p.likes || 0), 0)}</b> patinka</span></div>
    </div>
    <section class="lg-compose neon-card" style="margin:12px 14px">
      <h3 class="lg-compose-title">Redaguoti profilį</h3>
      <label class="small muted">Vartotojo vardas</label>
      <input id="lgEditUsername" maxlength="24" value="${esc(handle)}" />
      <label class="small muted" style="display:block;margin-top:10px">Bio</label>
      <textarea id="lgEditBio" rows="3" maxlength="200" style="width:100%;resize:vertical">${esc(bio)}</textarea>
      <button type="button" id="btnEditSocial" class="neon-btn primary">Išsaugoti</button>
      <div class="muted small" id="lgEditMsg" style="margin-top:8px"></div>
    </section>
    <div class="core-section-label" style="padding:0 14px">Mano įrašai</div>
    <div id="lgProfileFeed" class="lg-feed"><div class="muted small" style="padding:16px">${window.t ? window.t("common.loading") : "Kraunama…"}</div></div>`;
  };

  content.innerHTML = `
    <div class="lg-app">
      <div class="lg-header-bar"><span class="lg-brand">LifeGram</span></div>
      <div id="lgPanel"></div>
      <nav class="lg-tabbar">
        <button type="button" data-lg-tab="feed" class="${tab === "feed" ? "active" : ""}"><span class="ico">${phoneIco("home")}</span>Feed</button>
        <button type="button" data-lg-tab="search" class="${tab === "search" ? "active" : ""}"><span class="ico">${phoneIco("search")}</span>Paieška</button>
        <button type="button" data-lg-tab="create" class="${tab === "create" ? "active" : ""}"><span class="ico">${phoneIco("plus")}</span>Kurti</button>
        <button type="button" data-lg-tab="profile" class="${tab === "profile" ? "active" : ""}"><span class="ico">${phoneIco("user")}</span>Profilis</button>
      </nav>
    </div>`;

  const panel = content.querySelector("#lgPanel");

  if (tab === "feed") {
    panel.innerHTML = `<div class="muted small" style="padding:16px">${window.t ? window.t("common.loading") : "Kraunama…"}</div>`;
    panel.innerHTML = await renderFeed();
  } else if (tab === "create") {
    panel.innerHTML = renderCreate();
    const pick = content.querySelector("#lgPhotoPick");
    if (pick) {
      pick.querySelectorAll("[data-photo]").forEach((btn) => {
        nui("getPhoto", { id: Number(btn.dataset.photo) }).then((res) => {
          if (res?.ok && res.photo?.image) {
            const src = window.PhoneNormalizeImageSrc
              ? window.PhoneNormalizeImageSrc(res.photo.image)
              : res.photo.image;
            btn.style.backgroundImage = `url('${src}')`;
          }
        });
        btn.addEventListener("click", () => {
          lgUi.draftPhotoId = Number(btn.dataset.photo);
          pick.querySelectorAll("[data-photo]").forEach((b) => b.classList.toggle("selected", Number(b.dataset.photo) === lgUi.draftPhotoId));
        });
      });
    }
    content.querySelector("#btnPostInsta")?.addEventListener("click", async () => {
      const caption = content.querySelector("#postCaption")?.value || "";
      const urlField = content.querySelector("#postImageUrl")?.value || "";
      const imageUrl = lgUi.draftPhotoId ? `p:${lgUi.draftPhotoId}` : urlField;
      await nui("createPost", { caption, imageUrl });
      lgUi.draftPhotoId = null;
      hydrate(await nui("refresh"));
      lgUi.tab = "feed";
      openApp("insta");
    });
  } else if (tab === "profile") {
    panel.innerHTML = renderProfile();
    content.querySelector("#btnEditSocial")?.addEventListener("click", async () => {
      const msg = content.querySelector("#lgEditMsg");
      const res = await nui("saveSocialProfile", {
        username: content.querySelector("#lgEditUsername")?.value,
        bio: content.querySelector("#lgEditBio")?.value,
      });
      if (!res?.ok) {
        if (msg) msg.textContent = res?.message || "Klaida";
        return;
      }
      hydrate(await nui("refresh"));
      openApp("insta");
    });
    const feedEl = content.querySelector("#lgProfileFeed");
    if (feedEl) {
      if (!myPosts.length) {
        feedEl.innerHTML = `<div class="lg-empty muted">Dar neturite įrašų.</div>`;
      } else {
        const cards = await Promise.all(
          myPosts.map(async (p) => {
            const imgSrc = p.image_url ? await resolvePostImage(p.image_url) : "";
            const img = imgSrc ? `<div class="lg-post-media"><img src="${esc(imgSrc)}" alt="" loading="lazy" /></div>` : "";
            return `<article class="lg-post-card">${img}<p class="lg-post-caption">${esc(p.caption || "")}</p><div class="lg-post-stats">♥ ${Number(p.likes || 0)}</div></article>`;
          }),
        );
        feedEl.innerHTML = cards.join("");
      }
    }
  } else {
    panel.innerHTML = `<div class="core-app-panel">
      <div class="core-search-bar">${phoneIco("search")}<input type="search" id="lgSearch" placeholder="Ieškoti pagal autorių" /></div>
      <div id="lgSearchResults" class="core-list-stack"></div>
    </div>`;
    const renderSearch = (q) => {
      const query = String(q || "").toLowerCase();
      const authors = [...new Set((state.posts || []).map((p) => p.author_name))].filter((name) =>
        !query ? true : String(name).toLowerCase().includes(query),
      );
      const box = content.querySelector("#lgSearchResults");
      if (!authors.length) {
        box.innerHTML = `<div class="empty-state">Nieko nerasta</div>`;
        return;
      }
      box.innerHTML = authors
        .map(
          (name) => `<div class="core-list-item">
            <div class="core-avatar sm">${esc(lgInitials(name))}</div>
            <div class="core-list-body"><b>@${esc(name)}</b><div class="sub">${(state.posts || []).filter((p) => p.author_name === name).length} įrašai</div></div>
          </div>`,
        )
        .join("");
    };
    renderSearch("");
    content.querySelector("#lgSearch")?.addEventListener("input", (e) => renderSearch(e.target.value));
  }

  content.querySelectorAll("[data-lg-tab]").forEach((btn) => {
    btn.addEventListener("click", () => {
      lgUi.tab = btn.dataset.lgTab || "feed";
      openApp("insta");
    });
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
  content.className = "scroll-body core-app-body settings-app";
  const wp = localStorage.getItem("mrp_phone_wp") || "default";
  const soundsOn = localStorage.getItem("mrp_phone_sounds") !== "0";
  const notifsOn = localStorage.getItem("mrp_phone_notifs") !== "0";

  const wpPresets = [
    { id: "default", label: "Numatyta", bg: themedWallpaperPresets().default },
    { id: "violet", label: "Violetinė", bg: themedWallpaperPresets().violet },
    { id: "midnight", label: "Vidurnaktis", bg: themedWallpaperPresets().midnight },
    { id: "sunset", label: "Saulėlydis", bg: themedWallpaperPresets().sunset },
  ];

  content.innerHTML = `
    <div class="neon-card settings-group">
      <h3>Paskyra</h3>
      <div class="settings-row-modern"><span>Telefono numeris</span><span class="val">${esc(state.me.number)}</span></div>
      <div class="settings-row-modern"><span>Vartotojo vardas</span><span class="val">${esc(state.account.username || "—")}</span></div>
      <div class="settings-row-modern"><span>Vardas</span><span class="val">${esc(state.me.name || "—")}</span></div>
    </div>
    <div class="neon-card settings-group">
      <h3>Ekranas</h3>
      <div class="wp-grid" id="wpGrid">${wpPresets
        .map(
          (p) =>
            `<button type="button" class="wp-tile${wp === p.id ? " active" : ""}" data-wp="${p.id}" style="background:${p.bg}"><span>${esc(p.label)}</span></button>`,
        )
        .join("")}</div>
    </div>
    <div class="neon-card settings-group">
      <h3>Garsai ir pranešimai</h3>
      <div class="settings-row-modern">
        <span>Skambučių garsai</span>
        <button type="button" class="toggle-switch${soundsOn ? " on" : ""}" id="toggleSounds" aria-pressed="${soundsOn}"></button>
      </div>
      <div class="settings-row-modern">
        <span>Pranešimai užrakintame ekrane</span>
        <button type="button" class="toggle-switch${notifsOn ? " on" : ""}" id="toggleNotifs" aria-pressed="${notifsOn}"></button>
      </div>
    </div>
    <div class="neon-card settings-group">
      <h3>Apie</h3>
      <div class="settings-row-modern"><span>Telefono tema</span><span class="val">Sinchronizuojama su /hud</span></div>
    </div>`;

  content.querySelectorAll("[data-wp]").forEach((btn) => {
    btn.addEventListener("click", () => {
      localStorage.setItem("mrp_phone_wp", btn.dataset.wp);
      applyWallpaper();
      openApp("settings");
    });
  });

  const bindToggle = (id, key) => {
    content.querySelector(id)?.addEventListener("click", (e) => {
      const el = e.currentTarget;
      const on = !el.classList.contains("on");
      el.classList.toggle("on", on);
      el.setAttribute("aria-pressed", on ? "true" : "false");
      localStorage.setItem(key, on ? "1" : "0");
    });
  };
  bindToggle("#toggleSounds", "mrp_phone_sounds");
  bindToggle("#toggleNotifs", "mrp_phone_notifs");
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
window.addEventListener("mrpThemeChanged", applyWallpaper);
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

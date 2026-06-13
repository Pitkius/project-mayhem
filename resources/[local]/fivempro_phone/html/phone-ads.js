(function () {
  const SAVED_KEY = "fivempro_ads_saved";

  const adsUi = {
    tab: "feed",
    sort: "newest",
    search: "",
    category: "all",
    detailId: null,
    galleryIdx: 0,
    draftPhotoIds: [],
    priceMin: 0,
    priceMax: 100000,
    subView: null,
  };

  const CAT_ICONS = {
    vehicle: "car",
    property: "home",
    job: "briefcase",
    service: "wrench",
    electronics: "phone",
    clothes: "shirt",
    other: "box",
  };

  const ICONS = {
    bag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M6 8h12l-1 13H7L6 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 7h18s-3 0-3-7"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
    filter: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 6h16M7 12h10M10 18h4"/></svg>',
    heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z"/></svg>',
    heartFill: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1.8"><path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z"/></svg>',
    home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/></svg>',
    msg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M21 12a8 8 0 0 1-8 8H7l-4 3V12a8 8 0 0 1 8-8h4a8 8 0 0 1 8 8z"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="8" r="4"/><path d="M4 20c1.5-4 6-6 8-6s6.5 2 8 6"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>',
    car: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M5 11l1.5-4h11L19 11"/><path d="M5 11v6h2v-2h10v2h2v-6"/><circle cx="7.5" cy="15.5" r="1.5"/><circle cx="16.5" cy="15.5" r="1.5"/></svg>',
    briefcase: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>',
    wrench: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.5-2.5 2.5-2.5z"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/></svg>',
    shirt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M16 3l4 4-2 2v12H6V9L4 7l4-4 4 3 4-3z"/></svg>',
    box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 2 3 7v10l9 5 9-5V7z"/><path d="M3 7l9 5 9-5M12 12v10"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12l5 5L20 7"/></svg>',
    settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    bookmark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M6 4h12v16l-6-4-6 4z"/></svg>',
    star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 2l3 7h7l-5.5 4.5L18 21l-6-4-6 4 1.5-7.5L2 9h7z"/></svg>',
    logout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5M21 12H9"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z"/></svg>',
    call: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.3 1.8.6 2.6a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.5-1.2a2 2 0 0 1 2.1-.5c.8.3 1.7.5 2.6.6A2 2 0 0 1 22 16.9z"/></svg>',
  };

  const ico = (name) => ICONS[name] || "";

  function esc(s) {
    return window.PhoneEsc ? window.PhoneEsc(s) : String(s || "");
  }

  function digits(v) {
    return String(v || "").replace(/\D+/g, "");
  }

  function initials(name) {
    const p = String(name || "?").trim().split(/\s+/).filter(Boolean);
    if (!p.length) return "?";
    if (p.length === 1) return p[0].slice(0, 2).toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }

  function contactName(number) {
    const n = digits(number);
    const hit = (window.PhoneState?.contacts || []).find((c) => digits(c.contact_number) === n);
    return hit ? hit.display_name : n;
  }

  function categoryLabel(id) {
    const cats = window.PhoneState?.adCategories || [];
    const hit = cats.find((c) => c.id === id);
    return hit ? hit.label : id;
  }

  function fmtPrice(n) {
    const v = Number(n) || 0;
    if (v <= 0) return "Nemokamai";
    return `€${v.toLocaleString("lt-LT")}`;
  }

  function formatWhen(ts) {
    if (!ts) return "";
    const d = new Date(ts);
    if (Number.isNaN(d.getTime())) return String(ts);
    const now = new Date();
    const sameDay = d.toDateString() === now.toDateString();
    if (sameDay) return d.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
    return d.toLocaleDateString("lt-LT", { year: "numeric", month: "2-digit", day: "2-digit" });
  }

  function formatDateShort(ts) {
    if (!ts) return "";
    const d = new Date(ts);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString("lt-LT", { year: "numeric", month: "2-digit", day: "2-digit" });
  }

  function hasProfile() {
    return !!(window.PhoneState?.adProfile && window.PhoneState.adProfile.username);
  }

  function getSavedIds() {
    try {
      const raw = localStorage.getItem(SAVED_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch (_) {
      return [];
    }
  }

  function setSavedIds(ids) {
    localStorage.setItem(SAVED_KEY, JSON.stringify(ids));
  }

  function toggleSaved(id) {
    const ids = getSavedIds();
    const n = Number(id);
    const idx = ids.indexOf(n);
    if (idx >= 0) ids.splice(idx, 1);
    else ids.push(n);
    setSavedIds(ids);
    return ids.includes(n);
  }

  function isSaved(id) {
    return getSavedIds().includes(Number(id));
  }

  function parseAdImageRefs(ad) {
    const raw = ad?.image_urls || ad?.imageUrl || "";
    if (!raw) return { urls: [], photoIds: [] };
    if (raw.includes("p:")) {
      const photoIds = raw
        .split("|")
        .map((p) => Number(String(p).replace("p:", "")))
        .filter((n) => Number.isFinite(n) && n > 0);
      return { urls: [], photoIds };
    }
    if (raw.includes("||")) return { urls: raw.split("||").filter(Boolean), photoIds: [] };
    if (raw.startsWith("http") || raw.startsWith("data:")) return { urls: [raw], photoIds: [] };
    return { urls: [], photoIds: [] };
  }

  async function resolveAdThumb(ad) {
    const refs = parseAdImageRefs(ad);
    if (refs.urls[0]) return refs.urls[0];
    if (refs.photoIds[0]) {
      const res = await window.PhoneNui("getPhoto", { id: refs.photoIds[0] });
      if (res?.ok && res.photo?.image) {
        return window.PhoneNormalizeImageSrc
          ? window.PhoneNormalizeImageSrc(res.photo.image)
          : res.photo.image;
      }
    }
    return "";
  }

  async function resolveAdImages(ad) {
    const refs = parseAdImageRefs(ad);
    const out = [...refs.urls];
    for (const pid of refs.photoIds) {
      const res = await window.PhoneNui("getPhoto", { id: pid });
      if (res?.ok && res.photo?.image) {
        out.push(
          window.PhoneNormalizeImageSrc
            ? window.PhoneNormalizeImageSrc(res.photo.image)
            : res.photo.image,
        );
      }
    }
    return out;
  }

  function filterAds(list) {
    let ads = [...(list || [])];
    const q = adsUi.search.trim().toLowerCase();
    if (q) {
      ads = ads.filter(
        (a) =>
          String(a.title || "").toLowerCase().includes(q) ||
          String(a.body || "").toLowerCase().includes(q) ||
          String(a.author_name || "").toLowerCase().includes(q),
      );
    }
    if (adsUi.category && adsUi.category !== "all") {
      ads = ads.filter((a) => (a.category || "other") === adsUi.category);
    }
    const minP = Number(adsUi.priceMin) || 0;
    const maxP = Number(adsUi.priceMax) || 999999999;
    ads = ads.filter((a) => {
      const p = Number(a.price) || 0;
      return p >= minP && p <= maxP;
    });
    ads.sort((a, b) => {
      const pa = Number(a.price) || 0;
      const pb = Number(b.price) || 0;
      const da = new Date(a.created_at || 0).getTime();
      const db = new Date(b.created_at || 0).getTime();
      if (adsUi.sort === "cheapest") return pa - pb;
      if (adsUi.sort === "expensive") return pb - pa;
      if (adsUi.sort === "oldest") return da - db;
      return db - da;
    });
    return ads;
  }

  function showPhotoPicker(onPick) {
    const photos = window.PhoneState?.photos || [];
    if (!photos.length) {
      alert("Galerija tuščia. Nufotografuok telefono kamera.");
      return;
    }
    const overlay = document.createElement("div");
    overlay.className = "ads-picker-overlay";
    overlay.innerHTML = `
      <div class="ads-picker-head">
        <span>Pasirink nuotrauką</span>
        <button type="button" class="ads-back-btn" id="adsPickerClose">✕</button>
      </div>
      <div class="ads-picker-grid" id="adsPickerGrid"></div>`;
    document.body.appendChild(overlay);
    const grid = overlay.querySelector("#adsPickerGrid");
    photos.forEach((ph) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "ads-picker-item";
      btn.dataset.id = ph.id;
      grid.appendChild(btn);
      window.PhoneNui("getPhoto", { id: ph.id }).then((res) => {
        if (res?.ok && res.photo?.image) {
          const u = window.PhoneNormalizeImageSrc
            ? window.PhoneNormalizeImageSrc(res.photo.image)
            : res.photo.image;
          btn.style.backgroundImage = `url('${u}')`;
        }
      });
      btn.addEventListener("click", async () => {
        const res = await window.PhoneNui("getPhoto", { id: ph.id });
        if (res?.ok && res.photo?.image) {
          const img = window.PhoneNormalizeImageSrc
            ? window.PhoneNormalizeImageSrc(res.photo.image)
            : res.photo.image;
          onPick(ph.id, img);
        }
        overlay.remove();
      });
    });
    overlay.querySelector("#adsPickerClose").addEventListener("click", () => overlay.remove());
  }

  function bindFavButtons(host) {
    host.querySelectorAll("[data-fav]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const id = btn.dataset.fav;
        const saved = toggleSaved(id);
        btn.classList.toggle("active", saved);
        btn.innerHTML = saved ? ico("heartFill") : ico("heart");
      });
    });
  }

  function bindAdCards(host) {
    host.querySelectorAll("[data-ad]").forEach((el) => {
      el.addEventListener("click", () => {
        adsUi.detailId = Number(el.dataset.ad);
        adsUi.galleryIdx = 0;
        adsUi.tab = "detail";
        rerender();
      });
    });
  }

  let renderHost = null;

  function rerender() {
    if (renderHost) window.renderAdsApp(renderHost);
  }

  function navHtml(active) {
    return `<nav class="ads-nav">
      <button type="button" class="ads-nav-btn${active === "feed" ? " active" : ""}" data-tab="feed">${ico("home")}<span>Pagrindinis</span></button>
      <button type="button" class="ads-nav-btn${active === "search" ? " active" : ""}" data-tab="search">${ico("search")}<span>Paieška</span></button>
      <div class="ads-nav-fab-wrap">
        <button type="button" class="ads-nav-fab" data-tab="create">${ico("plus")}</button>
        <span>Pridėti</span>
      </div>
      <button type="button" class="ads-nav-btn${active === "messages" ? " active" : ""}" data-tab="messages">${ico("msg")}<span>Pranešimai</span></button>
      <button type="button" class="ads-nav-btn${active === "profile" ? " active" : ""}" data-tab="profile">${ico("user")}<span>Profilis</span></button>
    </nav>`;
  }

  function bindNav(host) {
    host.querySelectorAll("[data-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const t = btn.dataset.tab;
        if (t === "create" && !hasProfile()) {
          adsUi.tab = "setup";
        } else {
          adsUi.tab = t;
          adsUi.subView = null;
        }
        rerender();
      });
    });
  }

  async function renderFeedCards(host, ads) {
    if (!ads.length) {
      host.innerHTML = `<div class="ads-empty">Skelbimų nerasta.</div>`;
      return;
    }
    host.innerHTML = `<div class="ads-feed-list">${ads
      .map((a) => {
        const saved = isSaved(a.id);
        return `<article class="ads-feed-card" data-ad="${a.id}">
          <div class="ads-feed-thumb" data-thumb="${a.id}"></div>
          <div class="ads-feed-body">
            <div class="ads-feed-title">${esc(a.title || a.body)}</div>
            <div class="ads-feed-price">${esc(fmtPrice(a.price))}</div>
            <div class="ads-feed-meta">${esc(categoryLabel(a.category))} · ${esc(formatDateShort(a.created_at))}</div>
          </div>
          <button type="button" class="ads-fav-btn${saved ? " active" : ""}" data-fav="${a.id}">${saved ? ico("heartFill") : ico("heart")}</button>
        </article>`;
      })
      .join("")}</div>`;
    for (const a of ads) {
      const thumb = host.querySelector(`[data-thumb="${a.id}"]`);
      if (!thumb) continue;
      const url = await resolveAdThumb(a);
      if (url) thumb.style.backgroundImage = `url('${url}')`;
    }
    bindAdCards(host);
    bindFavButtons(host);
  }

  function renderFeed(host) {
    const cats = (window.PhoneState?.adCategories || []).filter((c) => c.id !== "all");
    const threads = window.PhoneState?.messageThreads || [];
    const badge = threads.length > 0 ? Math.min(threads.length, 9) : 0;

    host.innerHTML = `
      <div class="ads-top">
        <div class="ads-top-title">${ico("bag")} Skelbimai</div>
        <button type="button" class="ads-bell" data-tab="messages">
          ${ico("bell")}
          ${badge ? `<span class="ads-bell-badge">${badge}</span>` : ""}
        </button>
      </div>
      <div class="ads-search-wrap">
        <span class="ads-search-ico">${ico("search")}</span>
        <input type="search" id="adsFeedSearch" placeholder="Ieškoti skelbimų…" value="${esc(adsUi.search)}" />
        <button type="button" class="ads-search-filter" data-tab="search">${ico("filter")}</button>
      </div>
      <div class="ads-cat-scroll">
        <button type="button" class="ads-cat-chip${adsUi.category === "all" ? " active" : ""}" data-cat="all">Visi</button>
        ${cats.map((c) => `<button type="button" class="ads-cat-chip${adsUi.category === c.id ? " active" : ""}" data-cat="${esc(c.id)}">${esc(c.label)}</button>`).join("")}
      </div>
      <div class="ads-section-head">
        <b>Naujausi skelbimai</b>
        <button type="button" class="ads-link" data-tab="search">Žiūrėti visus</button>
      </div>
      <div id="adsFeedList"></div>`;

    const list = host.querySelector("#adsFeedList");
    const ads = filterAds(window.PhoneState?.ads || []);
    renderFeedCards(list, ads);

    host.querySelector("#adsFeedSearch")?.addEventListener("input", (e) => {
      adsUi.search = e.target.value;
      renderFeedCards(list, filterAds(window.PhoneState?.ads || []));
    });
    host.querySelectorAll("[data-cat]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.category = btn.dataset.cat;
        rerender();
      });
    });
    host.querySelectorAll("[data-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.tab = btn.dataset.tab;
        rerender();
      });
    });
  }

  async function renderDetail(host) {
    const ad = (window.PhoneState?.ads || []).find((a) => Number(a.id) === Number(adsUi.detailId));
    if (!ad) {
      host.innerHTML = `<div class="ads-empty">Skelbimas nerastas.</div>`;
      return;
    }
    const imgs = await resolveAdImages(ad);
    const hero = imgs[adsUi.galleryIdx] || imgs[0] || "";
    const saved = isSaved(ad.id);
    const myCid = window.PhoneState?.me?.citizenid;
    const phone = digits(ad.phone_number);

    host.innerHTML = `
      <div class="ads-detail-hero" style="background-image:url('${hero}')">
        <div class="ads-detail-hero-overlay">
          <button type="button" class="ads-back-btn" id="adBack">‹</button>
          <div style="display:flex;gap:8px">
            <button type="button" class="ads-icon-btn ads-fav-btn${saved ? " active" : ""}" id="adDetailFav">${saved ? ico("heartFill") : ico("heart")}</button>
          </div>
        </div>
        ${imgs.length > 1 ? `<div class="ads-detail-dots">${imgs.map((_, i) => `<span class="ads-detail-dot${i === adsUi.galleryIdx ? " active" : ""}"></span>`).join("")}</div>` : ""}
      </div>
      <div class="ads-detail-content">
        <h1 class="ads-detail-title">${esc(ad.title || ad.body)}</h1>
        <div class="ads-detail-price">${esc(fmtPrice(ad.price))}</div>
        <div class="ads-detail-stats">
          <span>${ico("calendar")} ${esc(formatDateShort(ad.created_at))}</span>
          <span>${ico("eye")} ${Math.floor(800 + Number(ad.id) * 37)}</span>
          <span>${ico("user")} ${esc(ad.author_name)}</span>
        </div>
        <div class="ads-block-title">Aprašymas</div>
        <p class="ads-detail-desc">${esc(ad.body)}</p>
        <div class="ads-block-title">Informacija</div>
        <div class="ads-info-table">
          <div class="ads-info-row"><span>Kategorija</span><span>${esc(categoryLabel(ad.category))}</span></div>
          <div class="ads-info-row"><span>Pardavėjas</span><span>${esc(ad.author_name)}</span></div>
          <div class="ads-info-row"><span>Telefonas</span><span>${esc(ad.phone_number)}</span></div>
          <div class="ads-info-row"><span>Kaina</span><span>${esc(fmtPrice(ad.price))}</span></div>
        </div>
        ${myCid && ad.citizenid === myCid ? `<button type="button" class="ads-btn-secondary ads-btn-danger" id="adDelDetail">Pašalinti skelbimą</button>` : ""}
      </div>
      <div class="ads-detail-footer">
        <button type="button" class="ads-btn-primary" id="adContact">Susisiekti su pardavėju</button>
        <button type="button" class="ads-btn-icon" id="adMsg" title="Rašyti žinutę">${ico("chat")}</button>
      </div>`;

    if (imgs.length > 1) {
      const heroEl = host.querySelector(".ads-detail-hero");
      heroEl?.addEventListener("click", (e) => {
        if (e.target.closest("button")) return;
        adsUi.galleryIdx = (adsUi.galleryIdx + 1) % imgs.length;
        rerender();
      });
    }

    host.querySelector("#adBack")?.addEventListener("click", () => {
      adsUi.tab = "feed";
      rerender();
    });
    host.querySelector("#adDetailFav")?.addEventListener("click", () => {
      const s = toggleSaved(ad.id);
      const btn = host.querySelector("#adDetailFav");
      btn.classList.toggle("active", s);
      btn.innerHTML = s ? ico("heartFill") : ico("heart");
    });
    host.querySelector("#adContact")?.addEventListener("click", () => {
      if (window.startCall && phone) window.startCall(phone);
    });
    host.querySelector("#adMsg")?.addEventListener("click", () => {
      if (window.openChat && phone) {
        window.openChat(phone);
      }
    });
    host.querySelector("#adDelDetail")?.addEventListener("click", async () => {
      if (!confirm("Pašalinti skelbimą?")) return;
      await window.PhoneNui("deleteAd", { adId: ad.id });
      await window.refreshState?.();
      adsUi.tab = "feed";
      rerender();
    });
  }

  function renderSearch(host) {
    const cats = (window.PhoneState?.adCategories || []).filter((c) => c.id !== "all");
    const count = filterAds(window.PhoneState?.ads || []).length;

    host.innerHTML = `
      <div class="ads-header-bar">
        <span class="ads-header-action muted"></span>
        <span class="ads-header-title">Paieška</span>
        <span class="ads-header-action muted"></span>
      </div>
      <div class="ads-search-wrap" style="margin-bottom:18px">
        <span class="ads-search-ico">${ico("search")}</span>
        <input type="search" id="adsSearchQ" placeholder="Ieškoti skelbimų…" value="${esc(adsUi.search)}" />
      </div>
      <div class="ads-cat-grid">
        ${cats
          .map((c) => {
            const iconName = CAT_ICONS[c.id] || "box";
            return `<button type="button" class="ads-cat-tile${adsUi.category === c.id ? " active" : ""}" data-cat="${esc(c.id)}">${ico(iconName)}<span>${esc(c.label)}</span></button>`;
          })
          .join("")}
      </div>
      <div class="ads-price-range">
        <div class="ads-block-title">Kaina</div>
        <div class="ads-price-inputs">
          <input type="number" id="adsPriceMin" min="0" placeholder="Nuo" value="${adsUi.priceMin || ""}" />
          <input type="number" id="adsPriceMax" min="0" placeholder="Iki" value="${adsUi.priceMax < 999999999 ? adsUi.priceMax : ""}" />
        </div>
        <input type="range" class="ads-range-slider" id="adsPriceRange" min="0" max="100000" step="1000" value="${Math.min(adsUi.priceMax, 100000)}" />
      </div>
      <div class="ads-block-title">Rūšiavimas</div>
      <div class="ads-sort-row">
        <button type="button" class="ads-sort-btn${adsUi.sort === "newest" ? " active" : ""}" data-sort="newest">${adsUi.sort === "newest" ? ico("check") : ""} Naujausi</button>
        <button type="button" class="ads-sort-btn${adsUi.sort === "cheapest" ? " active" : ""}" data-sort="cheapest">${adsUi.sort === "cheapest" ? ico("check") : ""} Pigiausi</button>
        <button type="button" class="ads-sort-btn${adsUi.sort === "expensive" ? " active" : ""}" data-sort="expensive">${adsUi.sort === "expensive" ? ico("check") : ""} Brangiausi</button>
      </div>
      <button type="button" class="ads-btn-primary" id="adsShowResults">Rodyti rezultatus (${count})</button>`;

    host.querySelector("#adsSearchQ")?.addEventListener("input", (e) => {
      adsUi.search = e.target.value;
    });
    host.querySelectorAll("[data-cat]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.category = btn.dataset.cat;
        rerender();
      });
    });
    host.querySelector("#adsPriceMin")?.addEventListener("input", (e) => {
      adsUi.priceMin = Number(e.target.value) || 0;
    });
    host.querySelector("#adsPriceMax")?.addEventListener("input", (e) => {
      adsUi.priceMax = Number(e.target.value) || 999999999;
    });
    host.querySelector("#adsPriceRange")?.addEventListener("input", (e) => {
      adsUi.priceMax = Number(e.target.value) || 100000;
      const maxInp = host.querySelector("#adsPriceMax");
      if (maxInp) maxInp.value = adsUi.priceMax;
    });
    host.querySelectorAll("[data-sort]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.sort = btn.dataset.sort;
        rerender();
      });
    });
    host.querySelector("#adsShowResults")?.addEventListener("click", () => {
      adsUi.tab = "feed";
      rerender();
    });
  }

  function renderCreate(host) {
    const cats = (window.PhoneState?.adCategories || []).filter((c) => c.id !== "all");
    const maxLen = 260;

    host.innerHTML = `
      <div class="ads-header-bar">
        <button type="button" class="ads-header-action muted" id="adCreateCancel">Atšaukti</button>
        <span class="ads-header-title">Pridėti skelbimą</span>
        <button type="button" class="ads-header-action" id="adCreateNext">Toliau</button>
      </div>
      <div class="ads-form-group">
        <label>Nuotraukos</label>
        <div class="ads-photo-grid" id="adPhotoGrid"></div>
        <button type="button" class="ads-btn-secondary" id="adAddPhotoGal">+ Galerija</button>
        <button type="button" class="ads-btn-secondary" id="adAddPhotoCam">+ Kamera</button>
      </div>
      <div class="ads-form-group">
        <label>Pavadinimas</label>
        <input type="text" id="adNewTitle" placeholder="Pvz. BMW M4 Competition" maxlength="48" />
      </div>
      <div class="ads-form-group">
        <label>Kategorija</label>
        <select id="adNewCat">${cats.map((c) => `<option value="${esc(c.id)}">${esc(c.label)}</option>`).join("")}</select>
      </div>
      <div class="ads-form-group">
        <label>Kaina (€)</label>
        <input type="number" id="adNewPrice" min="0" placeholder="0" />
      </div>
      <div class="ads-form-group">
        <label>Aprašymas</label>
        <textarea id="adNewBody" placeholder="Aprašykite prekę ar paslaugą…" maxlength="${maxLen}"></textarea>
        <div class="ads-char-count" id="adCharCount">0/${maxLen}</div>
      </div>
      <button type="button" class="ads-btn-primary" id="adPublish">Paskelbti skelbimą</button>
      <div class="ads-empty" id="adCreateMsg" style="padding-top:8px"></div>`;

    const grid = host.querySelector("#adPhotoGrid");
    const refreshPhotos = () => {
      grid.innerHTML =
        adsUi.draftPhotoIds
          .map(
            (entry, i) =>
              `<div class="ads-photo-slot" style="background-image:url('${entry.preview}')"><button type="button" class="ads-photo-del" data-rm="${i}">✕</button></div>`,
          )
          .join("") +
        (adsUi.draftPhotoIds.length < 5
          ? `<button type="button" class="ads-photo-slot add" id="adAddMore">+</button>`
          : "");
      grid.querySelector("#adAddMore")?.addEventListener("click", () => pickPhoto());
      grid.querySelectorAll("[data-rm]").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          adsUi.draftPhotoIds.splice(Number(btn.dataset.rm), 1);
          refreshPhotos();
        });
      });
    };

    const pickPhoto = () =>
      showPhotoPicker((id, preview) => {
        if (adsUi.draftPhotoIds.length < 5) adsUi.draftPhotoIds.push({ id, preview });
        refreshPhotos();
      });

    refreshPhotos();

    const bodyEl = host.querySelector("#adNewBody");
    const countEl = host.querySelector("#adCharCount");
    bodyEl?.addEventListener("input", () => {
      if (countEl) countEl.textContent = `${bodyEl.value.length}/${maxLen}`;
    });

    host.querySelector("#adAddPhotoGal")?.addEventListener("click", pickPhoto);
    host.querySelector("#adAddPhotoCam")?.addEventListener("click", () => window.PhoneOpenApp("camera"));
    host.querySelector("#adCreateCancel")?.addEventListener("click", () => {
      adsUi.tab = "feed";
      rerender();
    });
    host.querySelector("#adCreateNext")?.addEventListener("click", () => host.querySelector("#adPublish")?.click());
    host.querySelector("#adPublish")?.addEventListener("click", async () => {
      const msg = host.querySelector("#adCreateMsg");
      const title = host.querySelector("#adNewTitle")?.value?.trim();
      const body = host.querySelector("#adNewBody")?.value?.trim();
      if (!title || !body) {
        if (msg) msg.textContent = "Užpildykite pavadinimą ir aprašymą.";
        return;
      }
      const res = await window.PhoneNui("createAd", {
        title,
        category: host.querySelector("#adNewCat")?.value,
        price: host.querySelector("#adNewPrice")?.value,
        body,
        imagePhotoIds: adsUi.draftPhotoIds.map((e) => e.id),
      });
      if (!res?.ok) {
        if (msg) msg.textContent = res?.message || "Nepavyko paskelbti.";
        return;
      }
      adsUi.draftPhotoIds = [];
      await window.refreshState?.();
      adsUi.tab = "feed";
      rerender();
    });
  }

  function renderMessages(host) {
    const threads = window.PhoneState?.messageThreads || [];

    host.innerHTML = `
      <div class="ads-header-bar">
        <span class="ads-header-action muted"></span>
        <span class="ads-header-title">Pranešimai</span>
        <span class="ads-header-action muted"></span>
      </div>
      <div class="ads-msg-list" id="adsMsgList"></div>`;

    const list = host.querySelector("#adsMsgList");
    if (!threads.length) {
      list.innerHTML = `<div class="ads-empty">Žinučių dar nėra.</div>`;
      return;
    }
    list.innerHTML = threads
      .map((th) => {
        const num = digits(th.peer_number);
        const name = contactName(num);
        const unread = th.direction === "in" ? 1 : 0;
        return `<button type="button" class="ads-msg-item" data-peer="${esc(num)}">
          <div class="ads-msg-avatar">${esc(initials(name))}</div>
          <div class="ads-msg-body">
            <div class="ads-msg-name">${esc(name)}</div>
            <div class="ads-msg-preview">${th.direction === "out" ? "Jūs: " : ""}${esc(th.last_body)}</div>
          </div>
          <div>
            <div class="ads-msg-time">${esc(formatWhen(th.last_at))}</div>
            ${unread ? `<div class="ads-msg-badge">1</div>` : ""}
          </div>
        </button>`;
      })
      .join("");

    list.querySelectorAll("[data-peer]").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (window.openChat) window.openChat(btn.dataset.peer);
      });
    });
  }

  async function renderProfile(host) {
    const prof = window.PhoneState?.adProfile;
    const myCid = window.PhoneState?.me?.citizenid;
    const myAds = (window.PhoneState?.ads || []).filter((a) => a.citizenid === myCid);
    const savedCount = getSavedIds().length;
    const sub = adsUi.subView;

    if (sub === "myAds" || sub === "saved") {
      const ads =
        sub === "myAds"
          ? myAds
          : (window.PhoneState?.ads || []).filter((a) => isSaved(a.id));
      host.innerHTML = `
        <div class="ads-header-bar">
          <button type="button" class="ads-header-action muted" id="adSubBack">‹ Atgal</button>
          <span class="ads-header-title">${sub === "myAds" ? "Mano skelbimai" : "Išsaugoti skelbimai"}</span>
          <span class="ads-header-action muted"></span>
        </div>
        <div id="adSubList"></div>`;
      renderFeedCards(host.querySelector("#adSubList"), ads);
      host.querySelector("#adSubBack")?.addEventListener("click", () => {
        adsUi.subView = null;
        rerender();
      });
      return;
    }

    host.innerHTML = `
      <div class="ads-header-bar">
        <button type="button" class="ads-header-action muted" id="adProfSettings">${ico("settings")}</button>
        <span class="ads-header-title">Mano profilis</span>
        <span class="ads-header-action muted"></span>
      </div>
      <div class="ads-profile-hero">
        <div class="ads-profile-avatar" id="adProfAvatar"></div>
        <div class="ads-profile-name">${esc(prof?.username || "—")} <span class="ads-profile-verified">✓</span></div>
        <div class="ads-profile-since">Narys nuo ${esc(formatDateShort(prof?.created_at))}</div>
      </div>
      <div class="ads-profile-stats">
        <div class="ads-stat-box"><div class="ads-stat-num">${myAds.length}</div><div class="ads-stat-label">Skelbimai</div></div>
        <div class="ads-stat-box"><div class="ads-stat-num">${myAds.length}</div><div class="ads-stat-label">Aktyvūs</div></div>
        <div class="ads-stat-box"><div class="ads-stat-num">${savedCount}</div><div class="ads-stat-label">Išsaugoti</div></div>
      </div>
      <div class="ads-menu-list">
        <button type="button" class="ads-menu-item" data-sub="myAds">${ico("list")}<span>Mano skelbimai</span><span class="ads-menu-chevron">›</span></button>
        <button type="button" class="ads-menu-item" data-sub="saved">${ico("bookmark")}<span>Išsaugoti skelbimai</span><span class="ads-menu-chevron">›</span></button>
        <button type="button" class="ads-menu-item" data-tab="messages">${ico("msg")}<span>Mano pranešimai</span><span class="ads-menu-chevron">›</span></button>
        <button type="button" class="ads-menu-item" id="adEditProf">${ico("settings")}<span>Profilio nustatymai</span><span class="ads-menu-chevron">›</span></button>
        <button type="button" class="ads-menu-item" id="adReviews">${ico("star")}<span>Atsiliepimai</span><span class="ads-menu-chevron">›</span></button>
      </div>`;

    if (prof?.hasAvatar && myCid) {
      const res = await window.PhoneNui("getAdProfileAvatar", { citizenid: myCid });
      if (res?.avatar) {
        const u = res.avatar.startsWith("data:") ? res.avatar : `data:image/png;base64,${res.avatar}`;
        host.querySelector("#adProfAvatar").style.backgroundImage = `url('${u}')`;
      }
    } else {
      host.querySelector("#adProfAvatar").textContent = initials(prof?.username);
      host.querySelector("#adProfAvatar").style.display = "grid";
      host.querySelector("#adProfAvatar").style.placeItems = "center";
      host.querySelector("#adProfAvatar").style.fontSize = "28px";
      host.querySelector("#adProfAvatar").style.fontWeight = "800";
    }

    host.querySelectorAll("[data-sub]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.subView = btn.dataset.sub;
        rerender();
      });
    });
    host.querySelectorAll("[data-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        adsUi.tab = btn.dataset.tab;
        rerender();
      });
    });
    host.querySelector("#adProfSettings")?.addEventListener("click", () => {
      adsUi.tab = "setup";
      rerender();
    });
    host.querySelector("#adEditProf")?.addEventListener("click", () => {
      adsUi.tab = "setup";
      rerender();
    });
    host.querySelector("#adReviews")?.addEventListener("click", () => alert("Atsiliepimai — netrukus."));
  }

  function renderProfileSetup(host) {
    const prof = window.PhoneState?.adProfile;
    host.innerHTML = `
      <div class="ads-setup-card">
        <h3>${prof?.username ? "Redaguoti profilį" : "Sukurti profilį"}</h3>
        <p class="ads-empty" style="padding:0 0 12px">Prieš keliant skelbimus susikurk profilį.</p>
        <div class="ads-profile-avatar" id="adSetupAvatar" style="margin-bottom:14px"></div>
        <button type="button" class="ads-btn-secondary" id="adPickAvatarGal">Pasirinkti iš galerijos</button>
        <button type="button" class="ads-btn-secondary" id="adPickAvatarCam">Nufotografuoti</button>
        <div class="ads-form-group">
          <label>Vartotojo vardas</label>
          <input type="text" id="adProfUsername" placeholder="Pvz. Mantas123" maxlength="24" value="${esc(prof?.username || "")}" />
        </div>
        <div class="ads-form-group">
          <label>Aprašymas</label>
          <textarea id="adProfBio" rows="3" placeholder="Trumpas aprašymas…" maxlength="200">${esc(prof?.bio || "")}</textarea>
        </div>
        <button type="button" class="ads-btn-primary" id="adSaveProfile">Išsaugoti profilį</button>
        ${prof?.username ? `<button type="button" class="ads-btn-secondary" id="adSetupBack">Grįžti</button>` : ""}
      </div>`;

    let avatarData = "";
    const av = host.querySelector("#adSetupAvatar");
    if (prof?.hasAvatar) {
      window.PhoneNui("getAdProfileAvatar", { citizenid: window.PhoneState?.me?.citizenid }).then((res) => {
        if (res?.avatar) {
          const u = res.avatar.startsWith("data:") ? res.avatar : `data:image/png;base64,${res.avatar}`;
          av.style.backgroundImage = `url('${u}')`;
        }
      });
    } else {
      av.textContent = "?";
      av.style.display = "grid";
      av.style.placeItems = "center";
      av.style.fontSize = "28px";
    }

    host.querySelector("#adPickAvatarGal")?.addEventListener("click", () =>
      showPhotoPicker((_id, img) => {
        avatarData = img;
        av.style.backgroundImage = `url('${img}')`;
        av.textContent = "";
      }),
    );
    host.querySelector("#adPickAvatarCam")?.addEventListener("click", () => window.PhoneOpenApp("camera"));
    host.querySelector("#adSetupBack")?.addEventListener("click", () => {
      adsUi.tab = "profile";
      rerender();
    });
    host.querySelector("#adSaveProfile")?.addEventListener("click", async () => {
      const res = await window.PhoneNui("saveAdProfile", {
        username: host.querySelector("#adProfUsername")?.value,
        bio: host.querySelector("#adProfBio")?.value,
        avatarData,
      });
      if (!res?.ok) alert(res?.message || "Klaida");
      else {
        await window.refreshState?.();
        adsUi.tab = "profile";
        rerender();
      }
    });
  }

  window.renderAdsApp = function renderAdsApp(content) {
    renderHost = content;
    content.className = "scroll-body ads-portal-body";

    if (!hasProfile() && !["setup", "feed"].includes(adsUi.tab)) {
      adsUi.tab = "setup";
    }

    const showNav = !["detail", "setup"].includes(adsUi.tab);
    const screenCls = adsUi.tab === "detail" ? "ads-screen ads-screen-detail" : "ads-screen";

    content.innerHTML = `<div class="ads-app"><div class="${screenCls}" id="adsPanel"></div>${showNav ? navHtml(adsUi.tab) : ""}</div>`;
    const panel = content.querySelector("#adsPanel");

    if (adsUi.tab === "setup") renderProfileSetup(panel);
    else if (adsUi.tab === "detail") renderDetail(panel);
    else if (adsUi.tab === "search") renderSearch(panel);
    else if (adsUi.tab === "create") {
      if (!hasProfile()) renderProfileSetup(panel);
      else renderCreate(panel);
    } else if (adsUi.tab === "messages") renderMessages(panel);
    else if (adsUi.tab === "profile") renderProfile(panel);
    else renderFeed(panel);

    bindNav(content);
  };
})();

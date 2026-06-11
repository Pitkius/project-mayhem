(function () {
  const adsUi = { tab: "feed", sort: "newest", search: "", category: "all", detailId: null, draftPhotoIds: [] };

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
        const img = res.photo.image;
        return img.startsWith("data:") ? img : `data:image/png;base64,${img}`;
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
        const img = res.photo.image;
        out.push(img.startsWith("data:") ? img : `data:image/png;base64,${img}`);
      }
    }
    return out;
  }

  function categoryLabel(id) {
    const cats = window.PhoneState.adCategories || [];
    const c = cats.find((x) => x.id === id);
    return c ? c.label : id;
  }

  function formatWhen(ts) {
    if (!ts) return "";
    try {
      return new Date(ts).toLocaleDateString("lt-LT", { month: "short", day: "numeric" });
    } catch (_) {
      return "";
    }
  }

  function hasProfile() {
    return !!(window.PhoneState.adProfile && window.PhoneState.adProfile.username);
  }

  function filterAds(list) {
    let ads = [...list];
    const q = adsUi.search.trim().toLowerCase();
    if (q) {
      ads = ads.filter(
        (a) =>
          String(a.title || "").toLowerCase().includes(q) ||
          String(a.body || "").toLowerCase().includes(q),
      );
    }
    if (adsUi.category && adsUi.category !== "all") {
      ads = ads.filter((a) => (a.category || "other") === adsUi.category);
    }
    const sort = adsUi.sort;
    ads.sort((a, b) => {
      const pa = Number(a.price) || 0;
      const pb = Number(b.price) || 0;
      const da = new Date(a.created_at || 0).getTime();
      const db = new Date(b.created_at || 0).getTime();
      if (sort === "cheapest") return pa - pb;
      if (sort === "expensive") return pb - pa;
      if (sort === "oldest") return da - db;
      return db - da;
    });
    return ads;
  }

  async function pickPhotoFromGallery(onPick) {
    const photos = window.PhoneState.photos || [];
    if (!photos.length) {
      alert("Galerija tuščia. Nufotografuok telefono kamera.");
      return;
    }
    const id = photos[0].id;
    const res = await window.PhoneNui("getPhoto", { id });
    if (res?.ok && res.photo?.image) {
      const img = res.photo.image.startsWith("data:") ? res.photo.image : `data:image/png;base64,${res.photo.image}`;
      onPick(id, img);
    }
  }

  function renderProfileSetup(host) {
    host.innerHTML = `
      <div class="ads-profile-setup neon-card">
        <h3 style="text-align:center">Sukurti profilį</h3>
        <p class="muted small" style="text-align:center">Prieš keliant skelbimus susikurk profilį.</p>
        <div class="ads-avatar-preview" id="adAvatarPreview"></div>
        <button type="button" class="neon-btn" id="adPickAvatarGal" style="width:100%">Pasirinkti iš galerijos</button>
        <button type="button" class="neon-btn" id="adPickAvatarCam" style="width:100%">Nufotografuoti</button>
        <input id="adProfUsername" placeholder="Vartotojo vardas" maxlength="24" />
        <textarea id="adProfBio" rows="3" placeholder="Aprašymas" maxlength="200"></textarea>
        <button type="button" class="neon-btn primary" id="adSaveProfile">Išsaugoti profilį</button>
      </div>`;
    let avatarData = "";
    host.querySelector("#adPickAvatarGal").addEventListener("click", () =>
      pickPhotoFromGallery((_id, img) => {
        avatarData = img;
        host.querySelector("#adAvatarPreview").style.backgroundImage = `url('${img}')`;
      }),
    );
    host.querySelector("#adPickAvatarCam").addEventListener("click", () => {
      window.PhoneOpenApp("camera");
    });
    host.querySelector("#adSaveProfile").addEventListener("click", async () => {
      const res = await window.PhoneNui("saveAdProfile", {
        username: host.querySelector("#adProfUsername").value,
        bio: host.querySelector("#adProfBio").value,
        avatarData,
      });
      if (!res?.ok) alert(res?.message || "Klaida");
      else {
        await window.refreshState?.();
        window.PhoneOpenApp("ads");
      }
    });
  }

  async function renderFeed(host) {
    const ads = filterAds(window.PhoneState.ads || []);
    if (!ads.length) {
      host.innerHTML = `<div class="empty-state">Skelbimų nėra.</div>`;
      return;
    }
    host.innerHTML = ads
      .map((a) => {
        const price = Number(a.price) || 0;
        const priceTxt = price > 0 ? `$${price.toLocaleString("lt-LT")}` : "Nemokamai";
        return `<article class="neon-card ad-feed-card" data-ad="${a.id}">
          <div class="ad-feed-thumb" data-thumb-ad="${a.id}"></div>
          <div>
            <div class="ad-feed-price">${window.PhoneEsc(priceTxt)}</div>
            <b>${window.PhoneEsc(a.title || a.body)}</b>
            <p class="muted small" style="margin:4px 0">${window.PhoneEsc((a.body || "").slice(0, 80))}</p>
            <div class="muted small">${window.PhoneEsc(a.author_name)} · ${formatWhen(a.created_at)}</div>
          </div>
        </article>`;
      })
      .join("");
    for (const a of ads) {
      const thumb = host.querySelector(`[data-thumb-ad="${a.id}"]`);
      if (!thumb) continue;
      const url = await resolveAdThumb(a);
      if (url) thumb.style.backgroundImage = `url('${url}')`;
    }
    host.querySelectorAll("[data-ad]").forEach((el) =>
      el.addEventListener("click", () => {
        adsUi.detailId = Number(el.dataset.ad);
        adsUi.tab = "detail";
        window.PhoneOpenApp("ads");
      }),
    );
  }

  async function renderDetail(host) {
    const ad = (window.PhoneState.ads || []).find((a) => Number(a.id) === Number(adsUi.detailId));
    if (!ad) {
      host.innerHTML = `<div class="empty-state">Skelbimas nerastas.</div>`;
      return;
    }
    const imgs = await resolveAdImages(ad);
    const price = Number(ad.price) || 0;
    const priceTxt = price > 0 ? `$${price.toLocaleString("lt-LT")}` : "Nemokamai";
    const myCid = window.PhoneState.me?.citizenid;
    host.innerHTML = `
      <div class="neon-card" style="padding:12px;margin-bottom:10px">
        <button type="button" class="neon-btn" id="adBackFeed">← Atgal</button>
        <div class="ad-detail-gallery">${imgs.map((u) => `<img src="${u}" alt="" />`).join("") || '<div class="muted small">Be nuotraukų</div>'}</div>
        <h2 style="margin:10px 0 4px">${window.PhoneEsc(ad.title || ad.body)}</h2>
        <div class="ad-feed-price">${window.PhoneEsc(priceTxt)}</div>
        <p class="muted small">${window.PhoneEsc(categoryLabel(ad.category))} · ${formatWhen(ad.created_at)}</p>
        <p style="margin:10px 0">${window.PhoneEsc(ad.body)}</p>
        <p class="muted small">${window.PhoneEsc(ad.author_name)} · ${window.PhoneEsc(ad.phone_number)}</p>
        <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap">
          <button type="button" class="neon-btn" data-call="${window.PhoneEsc(String(ad.phone_number || "").replace(/\D/g, ""))}">Skambinti</button>
          <button type="button" class="neon-btn" data-msg="${window.PhoneEsc(String(ad.phone_number || "").replace(/\D/g, ""))}">Rašyti žinutę</button>
          ${myCid && ad.citizenid === myCid ? `<button type="button" class="neon-btn danger" id="adDelDetail">Šalinti</button>` : ""}
        </div>
      </div>`;
    host.querySelector("#adBackFeed").addEventListener("click", () => {
      adsUi.tab = "feed";
      window.PhoneOpenApp("ads");
    });
    host.querySelector("[data-call]")?.addEventListener("click", (e) => {
      if (window.startCall) window.startCall(e.currentTarget.dataset.call);
    });
    host.querySelector("[data-msg]")?.addEventListener("click", (e) => {
      if (window.openChat) window.openChat(e.currentTarget.dataset.msg);
    });
    host.querySelector("#adDelDetail")?.addEventListener("click", async () => {
      if (!confirm("Pašalinti skelbimą?")) return;
      await window.PhoneNui("deleteAd", { adId: ad.id });
      await window.refreshState?.();
      adsUi.tab = "feed";
      window.PhoneOpenApp("ads");
    });
  }

  function renderSearch(host) {
    const cats = (window.PhoneState.adCategories || []).filter((c) => c.id !== "all");
    host.innerHTML = `
      <div class="ads-search-row">
        <input type="search" id="adSearchQ" placeholder="Ieškoti…" value="${window.PhoneEsc(adsUi.search)}" />
        <select id="adSearchCat">
          <option value="all">Visos kategorijos</option>
          ${cats.map((c) => `<option value="${window.PhoneEsc(c.id)}"${adsUi.category === c.id ? " selected" : ""}>${window.PhoneEsc(c.label)}</option>`).join("")}
        </select>
      </div>
      <div class="ads-sort-chips">
        <button type="button" data-sort="newest" class="${adsUi.sort === "newest" ? "active" : ""}">Naujausi</button>
        <button type="button" data-sort="oldest" class="${adsUi.sort === "oldest" ? "active" : ""}">Seniausi</button>
        <button type="button" data-sort="cheapest" class="${adsUi.sort === "cheapest" ? "active" : ""}">Pigiausi</button>
        <button type="button" data-sort="expensive" class="${adsUi.sort === "expensive" ? "active" : ""}">Brangiausi</button>
      </div>
      <div id="adSearchResults"></div>`;
    const results = host.querySelector("#adSearchResults");
    const rerender = () => renderFeed(results);
    rerender();
    host.querySelector("#adSearchQ").addEventListener("input", (e) => {
      adsUi.search = e.target.value;
      rerender();
    });
    host.querySelector("#adSearchCat").addEventListener("change", (e) => {
      adsUi.category = e.target.value;
      rerender();
    });
    host.querySelectorAll("[data-sort]").forEach((btn) =>
      btn.addEventListener("click", () => {
        adsUi.sort = btn.dataset.sort;
        window.PhoneOpenApp("ads");
      }),
    );
  }

  function renderCreate(host) {
    const cats = (window.PhoneState.adCategories || []).filter((c) => c.id !== "all");
    host.innerHTML = `
      <div class="neon-card" style="padding:12px">
        <h3>Naujas skelbimas</h3>
        <input id="adNewTitle" placeholder="Pavadinimas" maxlength="48" style="width:100%;margin:8px 0;padding:10px;border-radius:12px;border:1px solid var(--glass-border);background:rgba(0,0,0,.35);color:#fff" />
        <select id="adNewCat" style="width:100%;margin-bottom:8px;padding:10px;border-radius:12px">${cats.map((c) => `<option value="${window.PhoneEsc(c.id)}">${window.PhoneEsc(c.label)}</option>`).join("")}</select>
        <input id="adNewPrice" type="number" min="0" placeholder="Kaina ($)" style="width:100%;margin-bottom:8px;padding:10px;border-radius:12px;border:1px solid var(--glass-border);background:rgba(0,0,0,.35);color:#fff" />
        <textarea id="adNewBody" rows="4" placeholder="Aprašymas" maxlength="260" style="width:100%;padding:10px;border-radius:12px;border:1px solid var(--glass-border);background:rgba(0,0,0,.35);color:#fff"></textarea>
        <div class="ad-image-pick-row" id="adImageRow" style="margin:10px 0"></div>
        <button type="button" class="neon-btn" id="adAddImgGal">+ Galerija</button>
        <button type="button" class="neon-btn" id="adAddImgCam" style="margin-left:6px">+ Kamera</button>
        <button type="button" class="neon-btn primary" style="width:100%;margin-top:12px" id="adPublishNew">Paskelbti</button>
      </div>`;
    const row = host.querySelector("#adImageRow");
    const refreshImgs = () => {
      row.innerHTML = adsUi.draftPhotoIds
        .map(
          (entry, i) =>
            `<img class="ad-image-thumb" src="${entry.preview || ""}" data-i="${i}" alt="" title="Pašalinti" />`,
        )
        .join("");
      row.querySelectorAll("img").forEach((img) =>
        img.addEventListener("click", () => {
          adsUi.draftPhotoIds.splice(Number(img.dataset.i), 1);
          refreshImgs();
        }),
      );
    };
    refreshImgs();
    host.querySelector("#adAddImgGal").addEventListener("click", () =>
      pickPhotoFromGallery((id, preview) => {
        if (adsUi.draftPhotoIds.length < 5) adsUi.draftPhotoIds.push({ id, preview });
        refreshImgs();
      }),
    );
    host.querySelector("#adAddImgCam").addEventListener("click", () => window.PhoneOpenApp("camera"));
    host.querySelector("#adPublishNew").addEventListener("click", async () => {
      const res = await window.PhoneNui("createAd", {
        title: host.querySelector("#adNewTitle").value,
        category: host.querySelector("#adNewCat").value,
        price: host.querySelector("#adNewPrice").value,
        body: host.querySelector("#adNewBody").value,
        imagePhotoIds: adsUi.draftPhotoIds.map((e) => e.id),
      });
      if (!res?.ok) alert(res?.message || "Klaida");
      else {
        adsUi.draftPhotoIds = [];
        await window.refreshState?.();
        adsUi.tab = "feed";
        window.PhoneOpenApp("ads");
      }
    });
  }

  function renderProfileTab(host) {
    const prof = window.PhoneState.adProfile;
    const myCid = window.PhoneState.me?.citizenid;
    const myAds = (window.PhoneState.ads || []).filter((a) => a.citizenid === myCid);
    host.innerHTML = `
      <div class="neon-card ads-profile-setup">
        <div class="ads-avatar-preview" id="adProfAv"></div>
        <h3 style="text-align:center">${window.PhoneEsc(prof?.username || "—")}</h3>
        <p class="muted small" style="text-align:center">${window.PhoneEsc(prof?.bio || "")}</p>
        <p class="small" style="text-align:center">${myAds.length} skelbimai · nuo ${formatWhen(prof?.created_at)}</p>
        <button type="button" class="neon-btn" id="adEditProf" style="width:100%">Redaguoti profilį</button>
      </div>
      <div style="margin-top:10px" id="adProfAds"></div>`;
    if (prof?.hasAvatar) {
      window.PhoneNui("getAdProfileAvatar", { citizenid: myCid }).then((res) => {
        if (res?.avatar) {
          const u = res.avatar.startsWith("data:") ? res.avatar : `data:image/png;base64,${res.avatar}`;
          host.querySelector("#adProfAv").style.backgroundImage = `url('${u}')`;
        }
      });
    }
    renderFeed(host.querySelector("#adProfAds"));
    host.querySelectorAll("[data-ad]").forEach((el) => {
      el.addEventListener("click", () => {
        adsUi.detailId = Number(el.dataset.ad);
        adsUi.tab = "detail";
        window.PhoneOpenApp("ads");
      });
    });
    host.querySelector("#adEditProf").addEventListener("click", () => {
      adsUi.tab = "setup";
      window.PhoneOpenApp("ads");
    });
  }

  function renderTabbar(content, active) {
    const bar = document.createElement("div");
    bar.className = "ads-tabbar";
    const tabs = [
      { id: "feed", label: "Pagrindinis", ico: "⌂" },
      { id: "search", label: "Paieška", ico: "⌕" },
      { id: "create", label: "Pridėti", ico: "＋" },
      { id: "notif", label: "Pranešimai", ico: "🔔" },
      { id: "profile", label: "Profilis", ico: "👤" },
    ];
    bar.innerHTML = tabs
      .map(
        (t) =>
          `<button type="button" class="${active === t.id ? "active" : ""}" data-tab="${t.id}"><span class="ico">${t.ico}</span>${t.label}</button>`,
      )
      .join("");
    content.appendChild(bar);
    bar.querySelectorAll("[data-tab]").forEach((btn) =>
      btn.addEventListener("click", () => {
        adsUi.tab = btn.dataset.tab;
        if (adsUi.tab === "notif") adsUi.tab = "feed";
        window.PhoneOpenApp("ads");
      }),
    );
  }

  window.renderAdsApp = function renderAdsApp(content) {
    content.className = "scroll-body ads-portal-body";
    if (!hasProfile() && adsUi.tab !== "setup") {
      adsUi.tab = "setup";
    }
    content.innerHTML = `<div class="ads-portal"><div class="ads-portal-panel" id="adsPortalPanel"></div></div>`;
    const panel = content.querySelector("#adsPortalPanel");

    if (adsUi.tab === "setup") {
      renderProfileSetup(panel);
    } else if (adsUi.tab === "detail") {
      renderDetail(panel);
    } else if (adsUi.tab === "search") {
      renderSearch(panel);
    } else if (adsUi.tab === "create") {
      if (!hasProfile()) renderProfileSetup(panel);
      else renderCreate(panel);
    } else if (adsUi.tab === "profile") {
      renderProfileTab(panel);
    } else {
      adsUi.tab = "feed";
      renderFeed(panel);
    }

    if (adsUi.tab !== "detail" && adsUi.tab !== "setup") {
      renderTabbar(content.querySelector(".ads-portal"), adsUi.tab);
    }
  };
})();

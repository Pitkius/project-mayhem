(function () {
  const camState = { live: false, front: false, zoom: 1, flash: false, view: "camera" };

  function photoCount() {
    return (window.PhoneState.photos || []).length;
  }

  function ensureFlashOverlay() {
    let el = document.getElementById("camFlashOverlay");
    if (!el) {
      el = document.createElement("div");
      el.id = "camFlashOverlay";
      el.className = "cam-flash-overlay";
      document.body.appendChild(el);
    }
    return el;
  }

  function setCameraLiveMode(on) {
    const phone = document.getElementById("phone");
    if (phone) phone.classList.toggle("camera-live-mode", !!on);
    camState.live = !!on;
  }

  const normalizeImageSrc = (raw) =>
    (window.PhoneNormalizeImageSrc ? window.PhoneNormalizeImageSrc(raw) : String(raw || ""));

  async function loadThumbUrl(photoId) {
    const res = await window.PhoneNui("getPhoto", { id: photoId });
    if (!res?.ok || !res.photo?.image) return "";
    return normalizeImageSrc(res.photo.image);
  }

  async function renderGalleryGrid(container) {
    const photos = window.PhoneState.photos || [];
    if (!photos.length) {
      container.innerHTML = `<div class="empty-state">Galerija tuščia. Nufotografuok ką nors!</div>`;
      return;
    }
    container.innerHTML = `<div class="cam-gallery-grid" id="camGalleryGrid"></div>`;
    const grid = container.querySelector("#camGalleryGrid");
    for (const p of photos) {
      const cell = document.createElement("div");
      cell.className = "cam-gallery-cell";
      const img = document.createElement("img");
      img.alt = "";
      img.loading = "lazy";
      grid.appendChild(cell);
      cell.appendChild(img);
      loadThumbUrl(p.id).then((url) => {
        if (url) img.src = url;
      });
      cell.addEventListener("click", async () => {
        const url = await loadThumbUrl(p.id);
        if (!url) return;

        container.replaceChildren();
        const card = document.createElement("div");
        card.className = "neon-card cam-gallery-detail";
        card.style.margin = "8px";
        card.style.padding = "10px";

        const img = document.createElement("img");
        img.alt = "";
        img.className = "cam-gallery-detail-img";
        img.src = url;

        const actions = document.createElement("div");
        actions.className = "cam-gallery-detail-actions";

        const backBtn = document.createElement("button");
        backBtn.type = "button";
        backBtn.className = "neon-btn";
        backBtn.id = "camBackGallery";
        backBtn.textContent = "← Atgal";

        const delBtn = document.createElement("button");
        delBtn.type = "button";
        delBtn.className = "neon-btn danger";
        delBtn.id = "camDelPhoto";
        delBtn.dataset.id = String(p.id);
        delBtn.textContent = "Šalinti";

        actions.append(backBtn, delBtn);
        card.append(img, actions);
        container.append(card);

        backBtn.addEventListener("click", () => renderGalleryGrid(container));
        delBtn.addEventListener("click", async () => {
          await window.PhoneNui("deletePhoto", { id: Number(p.id) });
          await window.refreshState?.();
          renderGalleryGrid(container);
        });
      });
    }
  }

  function bindCameraControls(content) {
    const vf = content.querySelector("#camViewfinder");
    const hint = content.querySelector("#camHint");
    const zoomLbl = content.querySelector("#camZoomLbl");
    const flashBtn = content.querySelector("#camFlashBtn");
    const shutter = content.querySelector("#camShutter");
    const flipBtn = content.querySelector("#camFlipBtn");
    const galleryBtn = content.querySelector("#camGalleryBtn");
    const counter = content.querySelector("#camCounter");
    const zoomSlider = content.querySelector("#camZoomSlider");

    const syncUi = () => {
      if (zoomLbl) zoomLbl.textContent = `${camState.zoom.toFixed(1)}×`;
      if (counter) counter.textContent = `${photoCount()}`;
      if (flashBtn) flashBtn.classList.toggle("on", camState.flash);
      if (vf) vf.classList.toggle("is-live", camState.live);
      if (hint) hint.style.opacity = camState.live ? "0" : "1";
      if (zoomSlider) zoomSlider.value = String(camState.zoom);
    };

    const startLive = async () => {
      await window.PhoneNui("cameraStartLive", {
        front: camState.front,
        zoom: camState.zoom,
        flash: camState.flash,
      });
      setCameraLiveMode(true);
      syncUi();
    };

    shutter?.addEventListener("click", async () => {
      if (!camState.live) await startLive();
      await window.PhoneNui("cameraCapture", {});
    });

    flipBtn?.addEventListener("click", async () => {
      const res = await window.PhoneNui("cameraFlip", {});
      camState.front = !!res?.front;
      syncUi();
    });

    flashBtn?.addEventListener("click", async () => {
      const res = await window.PhoneNui("cameraToggleFlash", {});
      camState.flash = !!res?.flash;
      syncUi();
    });

    zoomSlider?.addEventListener("input", async (e) => {
      camState.zoom = Number(e.target.value) || 1;
      await window.PhoneNui("cameraSetZoom", { zoom: camState.zoom });
      syncUi();
    });

    galleryBtn?.addEventListener("click", () => {
      window.PhoneOpenApp("gallery");
    });

    content.querySelector("#camOpenGalleryTab")?.addEventListener("click", () => {
      camState.view = "gallery";
      window.PhoneOpenApp("gallery");
    });

    syncUi();
    startLive();
  }

  window.renderCameraApp = function renderCameraApp(content) {
    content.className = "scroll-body camera-body";
    content.innerHTML = `
      <div class="cam-app">
        <div class="cam-viewfinder" id="camViewfinder">
          <div class="cam-top-bar">
            <button type="button" class="neon-btn icon-btn cam-flash" id="camFlashBtn" title="Blykstė">⚡</button>
            <span class="cam-zoom-pill" id="camZoomLbl">1.0×</span>
          </div>
          <div class="cam-viewfinder-hint" id="camHint">Gyvas vaizdas — fotografuok mygtuku apačioje</div>
        </div>
        <div style="padding:0 14px">
          <input type="range" class="cam-zoom-slider" id="camZoomSlider" min="0.55" max="2.5" step="0.05" value="1" />
        </div>
        <div class="cam-controls">
          <div class="cam-gallery-thumb" id="camGalleryBtn" title="Galerija"></div>
          <button type="button" class="cam-shutter" id="camShutter" aria-label="Fotografuoti"></button>
          <div class="cam-counter" id="camCounter">0</div>
        </div>
        <div style="display:flex;justify-content:center;padding-bottom:12px">
          <button type="button" class="neon-btn icon-btn" id="camFlipBtn" title="Keisti kamerą">⟳</button>
        </div>
      </div>`;
    bindCameraControls(content);
  };

  window.renderGalleryApp = function renderGalleryApp(content) {
    content.className = "scroll-body camera-body";
    setCameraLiveMode(false);
    window.PhoneNui("cameraStopLive", {});
    content.innerHTML = `
      <div style="padding:10px 12px 4px;display:flex;justify-content:space-between;align-items:center">
        <b>Galerija</b>
        <button type="button" class="neon-btn" id="camGoCamera">Kamera</button>
      </div>
      <div id="camGalleryHost"></div>`;
    content.querySelector("#camGoCamera").addEventListener("click", () => window.PhoneOpenApp("camera"));
    renderGalleryGrid(content.querySelector("#camGalleryHost"));
  };

  window.addEventListener("message", (e) => {
    const { action, payload } = e.data || {};
    if (action === "cameraMode") {
      setCameraLiveMode(!!payload?.active);
      if (payload) {
        camState.front = !!payload.front;
        camState.zoom = Number(payload.zoom) || camState.zoom;
        camState.flash = !!payload.flash;
      }
    }
    if (action === "cameraState" && payload) {
      camState.front = !!payload.front;
      camState.zoom = Number(payload.zoom) || camState.zoom;
      camState.flash = !!payload.flash;
    }
    if (action === "cameraFlash") {
      const el = ensureFlashOverlay();
      el.classList.add("on");
      setTimeout(() => el.classList.remove("on"), 120);
    }
    if (action === "photoSaved") {
      if (payload?.id && window.PhoneState) {
        const photos = window.PhoneState.photos || [];
        if (!photos.some((p) => Number(p.id) === Number(payload.id))) {
          photos.unshift({ id: payload.id, created_at: new Date().toISOString() });
          window.PhoneState.photos = photos;
        }
      }
      const gal = document.getElementById("camGalleryHost");
      if (gal) renderGalleryGrid(gal);
      const cnt = document.getElementById("camGalleryCount");
      if (cnt && payload?.count != null) cnt.textContent = String(payload.count);
    }
  });
})();

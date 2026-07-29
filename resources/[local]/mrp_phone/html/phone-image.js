(function () {
  function normalizeImageSrc(raw) {
    if (!raw) return "";
    let img = String(raw).trim();
    if (!img) return "";

    if (img.charAt(0) === "{") {
      try {
        const parsed = JSON.parse(img);
        if (parsed && typeof parsed.data === "string") img = parsed.data.trim();
      } catch (_) {}
    }

    if (img.startsWith("data:")) return img;
    if (img.startsWith("http://") || img.startsWith("https://")) return img;

    if (img.startsWith("/9j")) return `data:image/jpeg;base64,${img}`;
    if (img.startsWith("iVBORw0K")) return `data:image/png;base64,${img}`;
    if (img.startsWith("UklGR")) return `data:image/webp;base64,${img}`;

    return `data:image/jpeg;base64,${img}`;
  }

  function parseGalleryRef(raw) {
    const m = String(raw || "").match(/^gallery:(\d+)$/i);
    return m ? Number(m[1]) : null;
  }

  async function resolveImageRef(raw) {
    const galleryId = parseGalleryRef(raw);
    if (galleryId) {
      const res = await (window.PhoneNui ? window.PhoneNui("getPhoto", { id: galleryId }) : null);
      if (res?.ok && res.photo?.image) return normalizeImageSrc(res.photo.image);
      return "";
    }
    return normalizeImageSrc(raw);
  }

  /** Bendras galerijos pickeris (skelbimai, LifeGram, …) */
  function showPhotoPicker(onPick) {
    const photos = window.PhoneState?.photos || [];
    if (!photos.length) {
      alert("Galerija tuščia. Nufotografuok telefono kamera.");
      return;
    }
    document.querySelectorAll(".ads-picker-overlay").forEach((el) => el.remove());
    const overlay = document.createElement("div");
    overlay.className = "ads-picker-overlay";
    overlay.innerHTML = `
      <div class="ads-picker-head">
        <span>Pasirink nuotrauką</span>
        <button type="button" class="ads-back-btn" id="phonePickerClose">✕</button>
      </div>
      <div class="ads-picker-grid" id="phonePickerGrid"></div>`;
    const host = document.getElementById("phone") || document.body;
    host.appendChild(overlay);
    const grid = overlay.querySelector("#phonePickerGrid");
    photos.forEach((ph) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "ads-picker-item";
      btn.dataset.id = ph.id;
      grid.appendChild(btn);
      if (window.PhoneNui) {
        window.PhoneNui("getPhoto", { id: ph.id }).then((res) => {
          if (res?.ok && res.photo?.image) {
            btn.style.backgroundImage = `url('${normalizeImageSrc(res.photo.image)}')`;
          }
        });
      }
      btn.addEventListener("click", async () => {
        const res = await (window.PhoneNui ? window.PhoneNui("getPhoto", { id: ph.id }) : null);
        if (res?.ok && res.photo?.image) {
          onPick(ph.id, normalizeImageSrc(res.photo.image));
        }
        overlay.remove();
      });
    });
    overlay.querySelector("#phonePickerClose").addEventListener("click", () => overlay.remove());
  }

  const UI_ICONS = {
    call: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7.2 4.8c1.2 1.8 3 3.6 5.1 4.9l1.1-1.1c.4-.4 1-.4 1.4 0l.9.9c.4.4.4 1 0 1.4-1.1 1.1-2.5 1.8-4 1.8C7.6 12.7 4.5 9.9 3.6 6.3c0-1.4.6-2.7 1.6-3.7.4-.4 1-.4 1.4 0l.9.9c.4.4.3 1-.1 1.4L7.2 4.8z" fill="currentColor"/><path d="M14.5 13.2c1.5 1.1 3.1 1.9 4.9 2.3l1-1c.4-.4 1-.4 1.4 0l1.1 1.1c.4.4.4 1 0 1.4-1.2 1.2-2.8 1.9-4.4 1.9-4.2 0-8.2-2.9-9.8-6.9-.4-1.1-.6-2.3-.6-3.5 0-1.6.6-3.1 1.8-4.3.4-.4 1-.4 1.4 0l1.1 1.1c.4.4.4 1 0 1.4l-1 1c.4 1.8 1.2 3.4 2.3 4.9z" fill="currentColor" opacity=".35"/></svg>`,
    msg: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 5h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9l-4 3V7a2 2 0 0 1 2-2z" fill="currentColor"/></svg>`,
    edit: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 16.5V20h3.5L18 9.5 14.5 6 4 16.5z" fill="currentColor"/><path d="M15.2 5.3l2.5 2.5 1.4-1.4a1.2 1.2 0 0 0 0-1.7l-.8-.8a1.2 1.2 0 0 0-1.7 0l-1.4 1.4z" fill="currentColor"/></svg>`,
    del: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 7h10v12a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V7z" fill="currentColor"/><path d="M5 5h14v2H5V5zm4-2h6v2H9V3z" fill="currentColor"/></svg>`,
    flash: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M13 2 6 13h5l-1 9 8-12h-5l0-8z" fill="currentColor"/></svg>`,
    flip: `<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 7V4L2 9l5 5v-3h7a5 5 0 0 1 0 10h-2v2h2a7 7 0 1 0 0-14H7z" fill="currentColor"/></svg>`,
  };

  function uiIcon(name) {
    return UI_ICONS[name] || "";
  }

  window.PhoneNormalizeImageSrc = normalizeImageSrc;
  window.PhoneParseGalleryRef = parseGalleryRef;
  window.PhoneResolveImageRef = resolveImageRef;
  window.PhoneShowPhotoPicker = showPhotoPicker;
  window.PhoneUiIcon = uiIcon;
})();

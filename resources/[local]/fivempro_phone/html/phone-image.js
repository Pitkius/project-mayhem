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

    if (img.startsWith("/9j")) return `data:image/jpeg;base64,${img}`;
    if (img.startsWith("iVBORw0K")) return `data:image/png;base64,${img}`;
    if (img.startsWith("UklGR")) return `data:image/webp;base64,${img}`;

    return `data:image/jpeg;base64,${img}`;
  }

  window.PhoneNormalizeImageSrc = normalizeImageSrc;
})();

/* ═══════════════════════════════════════════════════════════════
   Dark Net UI logika — savarankiškas modulis (nekonfliktuoja su app.js)
   ═══════════════════════════════════════════════════════════════ */
(function () {
  "use strict";

  const RESOURCE = (function () {
    try { return window.GetParentResourceName ? GetParentResourceName() : "mrp_drugs"; }
    catch (e) { return "mrp_drugs"; }
  })();

  function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  const ICONS = {
    hemp_trim: "🌿",
    chemical_mix: "⚗️",
    meth_ingredient: "🧪",
    amp_precursor: "💊",
    amp_cold_meds: "💊",
    amp_solvent: "🧴",
    amp_reactor: "⚙️",
    amp_cooler: "❄️",
    amp_vent: "💨",
    default: "📦",
  };

  let root = null;
  let cart = {};      // { productId: amount }
  let products = [];
  let currentOrder = null;
  let meta = { isNight: false, nightStart: 20, nightEnd: 8, levelUnlocked: 1 };

  // ── DOM kūrimas ────────────────────────────────────────────────
  function build() {
    if (root) return;
    root = document.createElement("div");
    root.id = "dn-root";
    root.innerHTML = `
      <div class="dn-window">
        <div class="dn-head">
          <div class="dn-logo">◈</div>
          <div class="dn-title">
            <h1>Dark Net</h1>
            <p>Encrypted supply channel</p>
          </div>
          <div class="dn-head-right">
            <div class="dn-clock" id="dn-clock">—</div>
            <button class="dn-x" id="dn-close">✕</button>
          </div>
        </div>
        <div class="dn-body" id="dn-body"></div>
      </div>
      <div class="dn-pin-overlay" id="dn-pin-overlay">
        <div class="dn-pin-box">
          <h3>SIUNTOS PIN</h3>
          <p>Įvesk kodą iš žinutės</p>
          <input class="dn-pin-input" id="dn-pin-input" maxlength="8" inputmode="numeric" autocomplete="off" />
          <div class="dn-pin-actions">
            <button class="dn-pin-cancel" id="dn-pin-cancel">Atšaukti</button>
            <button class="dn-pin-ok" id="dn-pin-ok">Patvirtinti</button>
          </div>
        </div>
      </div>
    `;
    document.body.appendChild(root);

    root.querySelector("#dn-close").addEventListener("click", close);
    root.querySelector("#dn-pin-cancel").addEventListener("click", closePin);
    root.querySelector("#dn-pin-ok").addEventListener("click", submitPin);
    root.querySelector("#dn-pin-input").addEventListener("keydown", (e) => {
      if (e.key === "Enter") submitPin();
      if (e.key === "Escape") closePin();
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && root.classList.contains("dn-show") && !pinOpen()) close();
    });
  }

  // ── Atvaizdavimas ──────────────────────────────────────────────
  function clockLabel() {
    const el = root.querySelector("#dn-clock");
    if (meta.isNight) {
      el.className = "dn-clock dn-night";
      el.textContent = "🌙 NAKTIS · pristatymai aktyvūs";
    } else {
      el.className = "dn-clock dn-day";
      el.textContent = `☀ DIENA · pristatymai ${meta.nightStart}:00–${meta.nightEnd}:00`;
    }
  }

  function render() {
    const body = root.querySelector("#dn-body");
    body.innerHTML = `
      <div class="dn-market" id="dn-market"></div>
      <div class="dn-side" id="dn-side"></div>
    `;
    renderMarket();
    renderSide();
    clockLabel();
  }

  function renderMarket() {
    const m = root.querySelector("#dn-market");
    m.innerHTML = `<p class="dn-section-label">Prieinamos žaliavos</p>`;
    products.forEach((p) => {
      const icon = ICONS[p.item] || ICONS.default;
      const row = document.createElement("div");
      row.className = "dn-product" + (p.locked ? " dn-locked" : "");
      row.innerHTML = `
        <div class="dn-p-icon">${icon}</div>
        <div class="dn-p-main">
          <div class="dn-p-name">${p.label}</div>
          <div class="dn-p-meta">$${p.pricePerUnit}/vnt · L${p.level} · ${p.minAmount}–${p.maxAmount} vnt</div>
          ${p.locked ? `<div class="dn-p-lock">🔒 Reikia atrakinti L${p.level}</div>` : ``}
        </div>
        ${p.locked ? `` : `
        <div class="dn-qty">
          <button data-act="dec">−</button>
          <input type="text" id="qty-${p.id}" value="${p.defaultAmount}" />
          <button data-act="inc">+</button>
        </div>
        <button class="dn-add" data-add="${p.id}">Į krepšelį</button>`}
      `;
      if (!p.locked) {
        const input = row.querySelector(`#qty-${p.id}`);
        const clamp = (v) => Math.max(p.minAmount, Math.min(p.maxAmount, parseInt(v) || p.minAmount));
        row.querySelector('[data-act="dec"]').addEventListener("click", () => { input.value = clamp(parseInt(input.value) - 5); });
        row.querySelector('[data-act="inc"]').addEventListener("click", () => { input.value = clamp(parseInt(input.value) + 5); });
        input.addEventListener("change", () => { input.value = clamp(input.value); });
        row.querySelector(`[data-add="${p.id}"]`).addEventListener("click", () => {
          addToCart(p.id, clamp(input.value));
        });
      }
      m.appendChild(row);
    });
  }

  function productById(id) { return products.find((p) => p.id === id); }

  function addToCart(id, amount) {
    cart[id] = (cart[id] || 0) + amount;
    const p = productById(id);
    if (p) cart[id] = Math.min(p.maxAmount, cart[id]);
    renderSide();
  }

  function cartTotal() {
    let t = 0;
    Object.keys(cart).forEach((id) => {
      const p = productById(id);
      if (p) t += p.pricePerUnit * cart[id];
    });
    return t;
  }

  function renderSide() {
    const side = root.querySelector("#dn-side");
    if (currentOrder) return renderActiveOrder(side);

    const keys = Object.keys(cart);
    let rows = "";
    if (keys.length === 0) {
      rows = `<div class="dn-cart-empty">Krepšelis tuščias</div>`;
    } else {
      keys.forEach((id) => {
        const p = productById(id);
        if (!p) return;
        rows += `
          <div class="dn-cart-row">
            <span class="cr-name">${p.label}</span>
            <span class="cr-qty">×${cart[id]}</span>
            <span class="cr-price">$${p.pricePerUnit * cart[id]}</span>
            <span class="cr-del" data-del="${id}">✕</span>
          </div>`;
      });
    }
    side.innerHTML = `
      <p class="dn-section-label">Užsakymas</p>
      <div class="dn-cart-list">${rows}</div>
      <div class="dn-total"><span>Iš viso</span><strong>$${cartTotal()}</strong></div>
      <button class="dn-order-btn" id="dn-order" ${keys.length === 0 ? "disabled" : ""}>Pateikti užsakymą</button>
      <p class="dn-hint">Mokama nešvariais pinigais. Siunta paliekama naktį (${meta.nightStart}:00–${meta.nightEnd}:00) atsitiktinėje vietoje su PIN kodu.</p>
    `;
    side.querySelectorAll("[data-del]").forEach((el) => {
      el.addEventListener("click", () => { delete cart[el.getAttribute("data-del")]; renderSide(); });
    });
    const btn = side.querySelector("#dn-order");
    if (btn) btn.addEventListener("click", placeOrder);
  }

  function renderActiveOrder(side) {
    const o = currentOrder;
    let itemsTxt = (o.items || []).map((i) => `${i.amount}× ${labelForItem(i.item)}`).join("<br>");
    const isActive = o.status === "active";
    side.innerHTML = `
      <p class="dn-section-label">Aktyvus užsakymas</p>
      <div class="dn-active">
        <div class="dn-status-badge ${isActive ? "dn-status-active" : "dn-status-pending"}">
          ${isActive ? "SIUNTA PALIKTA" : "LAUKIAMA NAKTIES"}
        </div>
        <div class="dn-active-items">${itemsTxt}</div>
        ${isActive && o.pin ? `<div class="dn-pin">${o.pin}</div><div class="dn-active-items">Rask siuntą pažymėtoje zonoje ir įvesk PIN.</div>` : ``}
        ${!isActive ? `<div class="dn-active-items">Kai sutems, gausi žinutę su vieta ir PIN kodu.</div>` : ``}
        <div class="dn-total" style="justify-content:center;"><strong>$${o.total}</strong></div>
        <button class="dn-cancel" id="dn-cancel">Atšaukti užsakymą</button>
      </div>
      <p class="dn-hint">Vienu metu galimas tik vienas užsakymas. Pinigai už atšauktą ar neatsiimtą siuntą negrąžinami.</p>
    `;
    side.querySelector("#dn-cancel").addEventListener("click", cancelOrder);
  }

  function labelForItem(item) {
    const p = products.find((x) => x.item === item);
    return p ? p.label : item;
  }

  // ── Veiksmai ───────────────────────────────────────────────────
  function placeOrder() {
    const list = Object.keys(cart).map((id) => ({ id, amount: cart[id] }));
    if (list.length === 0) return;
    post("darknetPlaceOrder", { cart: list });
    cart = {};
  }

  function cancelOrder() { post("darknetCancelOrder", {}); }

  // ── PIN ────────────────────────────────────────────────────────
  let pinOrderId = null;
  function pinOpen() { return root.querySelector("#dn-pin-overlay").classList.contains("dn-show"); }
  let pinOnly = false;
  function openPin(orderId) {
    pinOrderId = orderId;
    const ov = root.querySelector("#dn-pin-overlay");
    const inp = root.querySelector("#dn-pin-input");
    inp.value = "";
    // Jei UI neatidarytas — rodom tik PIN modalą (be tuščio lango).
    pinOnly = !root.classList.contains("dn-show");
    if (pinOnly) root.querySelector(".dn-window").style.display = "none";
    ov.classList.add("dn-show");
    root.classList.add("dn-show");
    setTimeout(() => inp.focus(), 30);
  }
  function closePin() {
    root.querySelector("#dn-pin-overlay").classList.remove("dn-show");
    if (pinOnly) {
      root.classList.remove("dn-show");
      root.querySelector(".dn-window").style.display = "";
      pinOnly = false;
    }
    post("darknetPinCancel", {});
  }
  function submitPin() {
    const pin = (root.querySelector("#dn-pin-input").value || "").trim();
    if (!pin) return;
    root.querySelector("#dn-pin-overlay").classList.remove("dn-show");
    if (pinOnly) {
      root.classList.remove("dn-show");
      root.querySelector(".dn-window").style.display = "";
      pinOnly = false;
    }
    post("darknetPinSubmit", { orderId: pinOrderId, pin: pin });
  }

  // ── Atidarymas / uždarymas ─────────────────────────────────────
  function open(data) {
    build();
    root.querySelector(".dn-window").style.display = "";
    products = data.products || [];
    currentOrder = data.order || null;
    meta.isNight = !!data.isNight;
    meta.nightStart = data.nightStart != null ? data.nightStart : 20;
    meta.nightEnd = data.nightEnd != null ? data.nightEnd : 8;
    meta.levelUnlocked = data.levelUnlocked || 1;
    render();
    root.classList.add("dn-show");
  }
  function close() {
    if (!root) return;
    root.classList.remove("dn-show");
    root.querySelector("#dn-pin-overlay").classList.remove("dn-show");
    post("darknetClose", {});
  }

  // ── Žinučių tiltas iš kliento ──────────────────────────────────
  window.addEventListener("message", function (e) {
    const d = e.data || {};
    if (!d.action) return;
    if (d.action === "darknet:open") open(d.data || d);
    else if (d.action === "darknet:close") close();
    else if (d.action === "darknet:orderSync") {
      build();
      currentOrder = (d.data && d.data.order) || d.order || null;
      if (root.classList.contains("dn-show")) renderSide();
    }
    else if (d.action === "darknet:pin") {
      build();
      openPin((d.data && d.data.orderId) || d.orderId);
    }
    else if (d.action === "darknet:clock") {
      if (root) { meta.isNight = !!(d.data && d.data.isNight); if (root.classList.contains("dn-show")) clockLabel(); }
    }
  });
})();

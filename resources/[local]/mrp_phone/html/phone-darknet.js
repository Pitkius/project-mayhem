/* DarkNet apps hosted in mrp_phone shell */

window.renderDarknetMarketApp = function renderDarknetMarketApp(root) {
  root.innerHTML = `<div class="dn-app">
    <h3>DarkNet Market</h3>
    <p class="muted small">Nelegalios žaliavos · marked bills · naktiniai dead drop</p>
    <div id="dnMarketList" class="dn-card">Kraunama…</div>
    <button type="button" class="ios-btn primary" id="dnRefreshMarket">Atnaujinti</button>
  </div>`;
  const load = async () => {
    const res = await window.PhoneNui("darknetMarketState", {});
    const el = document.getElementById("dnMarketList");
    if (!el) return;
    if (!res?.ok) {
      el.textContent = res?.message || "Nepavyko gauti katalogo.";
      return;
    }
    const products = res.products || [];
    el.innerHTML = products
      .map(
        (p) => `<div class="dn-card">
        <strong>${window.PhoneEsc(p.label || p.id)}</strong>
        <div class="muted small">L${p.level} · $${p.pricePerUnit}/vnt ${p.locked ? "· UŽRAKINTA" : ""}</div>
        <button type="button" class="ios-btn" data-order="${window.PhoneEsc(p.id)}" ${p.locked ? "disabled" : ""}>Užsakyti ${p.defaultAmount || p.minAmount || 1}</button>
      </div>`
      )
      .join("") || "<div class='muted'>Tuščia</div>";
    el.querySelectorAll("[data-order]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = btn.getAttribute("data-order");
        const prod = products.find((x) => x.id === id);
        const amount = prod?.defaultAmount || prod?.minAmount || 1;
        const r = await window.PhoneNui("darknetPlaceOrder", {
          cart: [{ id, amount }],
        });
        alert(r?.ok ? (r.night ? "Siunta paruošta — zona pažymėta." : "Užsakymas priimtas. Lauk nakties.") : r?.reason || r?.message || "Klaida");
        load();
      });
    });
  };
  document.getElementById("dnRefreshMarket")?.addEventListener("click", load);
  load();
};

window.renderEncryptedMessagesApp = function renderEncryptedMessagesApp(root) {
  root.innerHTML = `<div class="dn-app">
    <h3>Encrypted Messages</h3>
    <p class="muted small">Šifruoti pokalbiai šiame DarkNet įrenginyje</p>
    <div id="dnEncList" class="dn-card">Kraunama…</div>
    <input id="dnEncPeer" placeholder="Gavėjo etiketė" maxlength="32" />
    <textarea id="dnEncBody" rows="3" placeholder="Žinutė" maxlength="320"></textarea>
    <button type="button" class="ios-btn primary" id="dnEncSend">Siųsti</button>
  </div>`;
  const load = async () => {
    const res = await window.PhoneNui("encryptedList", {});
    const el = document.getElementById("dnEncList");
    if (!el) return;
    const rows = res?.threads || [];
    el.innerHTML =
      rows
        .map((t) => `<div><strong>${window.PhoneEsc(t.peer_label)}</strong><div class="muted small">${window.PhoneEsc(t.last_body || "")}</div></div>`)
        .join("") || "<div class='muted'>Nėra gijų</div>";
  };
  document.getElementById("dnEncSend")?.addEventListener("click", async () => {
    await window.PhoneNui("encryptedSend", {
      peerLabel: document.getElementById("dnEncPeer")?.value,
      body: document.getElementById("dnEncBody")?.value,
    });
    load();
  });
  load();
};

window.renderDeadDropsApp = function renderDeadDropsApp(root) {
  root.innerHTML = `<div class="dn-app">
    <h3>Dead Drops</h3>
    <p class="muted small">Aktyvi zona + PIN atsiėmimui (be tikslaus GPS)</p>
    <div id="dnDropState" class="dn-card">Kraunama…</div>
    <input id="dnDropPin" placeholder="PIN" maxlength="4" inputmode="numeric" />
    <button type="button" class="ios-btn primary" id="dnDropCollect">Atsiimti</button>
  </div>`;
  const load = async () => {
    const res = await window.PhoneNui("darknetDropState", {});
    const el = document.getElementById("dnDropState");
    if (!el) return;
    if (!res?.ok || !res.order) {
      el.textContent = res?.message || "Nėra aktyvaus dead drop.";
      return;
    }
    el.innerHTML = `<div>Status: <strong>${window.PhoneEsc(res.order.status)}</strong></div>
      <div class="muted small">Paieškos zona ~${res.order.radius || 70}m (žemėlapyje)</div>`;
  };
  document.getElementById("dnDropCollect")?.addEventListener("click", async () => {
    const r = await window.PhoneNui("darknetCollect", {
      pin: document.getElementById("dnDropPin")?.value,
    });
    alert(r?.ok ? "Siunta atsiimta." : r?.reason || r?.message || "Nepavyko");
    load();
  });
  load();
};

window.renderMapsApp = function renderMapsApp(root) {
  root.innerHTML = `<div class="dn-app"><h3>Žemėlapis</h3><p class="muted">Netrukus — waypoint / zona.</p></div>`;
};

const root = document.getElementById("licenseRoot");
const cardEl = document.getElementById("licenseCard");
const fieldsEl = document.getElementById("cardFields");
const btnClose = document.getElementById("btnClose");

function post(name, data) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  });
}

function esc(s) {
  const d = document.createElement("div");
  d.textContent = s == null ? "" : String(s);
  return d.innerHTML;
}

function field(label, value) {
  return `<div class="field-row"><label>${esc(label)}</label><span>${esc(value)}</span></div>`;
}

function statusPill(status) {
  const ok = String(status).toLowerCase().includes("galioj");
  const cls = ok ? "ok" : "bad";
  return `<span class="status-pill ${cls}">${esc(status)}</span>`;
}

function renderCategories(categories) {
  if (!categories || !categories.length) {
    return field("Kategorijos", "—");
  }
  const badges = categories
    .map((c) => {
      const cls = c.active ? "cat-badge active" : "cat-badge inactive";
      return `<div class="${cls}"><span class="letter">${esc(c.letter)}</span><span>${esc(c.label)}</span></div>`;
    })
    .join("");
  return `<div class="field-row"><label>Kategorijos</label><div class="cat-grid">${badges}</div></div>`;
}

function renderCard(data) {
  document.getElementById("serverName").textContent = data.serverName || "MRP";
  document.getElementById("serverSubtitle").textContent = data.serverSubtitle || "Los Santos RP";
  document.getElementById("docTitle").textContent = data.title || "Dokumentas";
  document.getElementById("docLabel").textContent = data.type === "id_card" ? "Tapatybė" : "Licencija";
  document.getElementById("photoInitials").textContent = data.photoInitials || "?";
  document.getElementById("citizenId").textContent = data.citizenid || "—";

  cardEl.dataset.type = data.type || "id_card";

  let html = "";
  const name = `${data.firstname || ""} ${data.lastname || ""}`.trim();

  if (data.type === "id_card") {
    html += field("Vardas, pavardė", name || "—");
    html += field("Gimimo data", data.birthdate);
    html += field("Lytis", data.gender);
    html += field("Pilietybė", data.nationality);
    html += field("Išdavimo data", data.issued);
  } else if (data.type === "driving_license") {
    html += field("Vardas, pavardė", name || "—");
    html += renderCategories(data.categories);
    html += field("Galioja iki", data.validUntil);
    html += `<div class="field-row"><label>Statusas</label>${statusPill(data.status)}</div>`;
    html += field("Išdavimo data", data.issued);
  } else {
    html += field("Vardas, pavardė", name || "—");
    html += field("Licencijos tipas", data.licenseType);
    html += field(data.type === "fishing_license" ? "Leidžiama žvejoti" : "Leidžiama medžioti", data.allowed);
    html += field("Galioja iki", data.validUntil);
    html += `<div class="field-row"><label>Statusas</label>${statusPill(data.status)}</div>`;
  }

  fieldsEl.innerHTML = html;
}

function openCard(data) {
  renderCard(data);
  root.classList.remove("hidden");
  root.setAttribute("aria-hidden", "false");
}

function closeCard() {
  root.classList.add("hidden");
  root.setAttribute("aria-hidden", "true");
}

btnClose.addEventListener("click", () => post("close"));

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !root.classList.contains("hidden")) {
    post("close");
  }
});

window.addEventListener("message", (event) => {
  const msg = event.data;
  if (!msg || !msg.action) return;
  if (msg.action === "open" && msg.card) openCard(msg.card);
  if (msg.action === "close") closeCard();
});

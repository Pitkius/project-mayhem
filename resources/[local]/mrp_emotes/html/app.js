const RESOURCE =
  typeof GetParentResourceName === "function" ? GetParentResourceName() : "mrp_emotes";

const app = document.getElementById("app");
const emCats = document.getElementById("emCats");
const emGrid = document.getElementById("emGrid");
const emSearch = document.getElementById("emSearch");
const emEmpty = document.getElementById("emEmpty");
const emCount = document.getElementById("emCount");
const emClose = document.getElementById("emClose");
const emCancel = document.getElementById("emCancel");

const CLOSE_MS = 360;
const catLabels = {};

let categories = [];
let emotes = [];
let activeCat = "all";
let searchQuery = "";

function nui(name, data) {
  return fetch(`https://${RESOURCE}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

function openUi() {
  app.classList.remove("hidden", "is-closing");
  void app.offsetWidth;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => app.classList.add("is-open"));
  });
}

function closeUi() {
  app.classList.remove("is-open");
  app.classList.add("is-closing");
  window.setTimeout(() => {
    app.classList.add("hidden");
    app.classList.remove("is-closing");
  }, CLOSE_MS);
}

function filteredEmotes() {
  const q = searchQuery.trim().toLowerCase();
  return emotes.filter((e) => {
    const catOk = activeCat === "all" || e.cat === activeCat;
    if (!catOk) return false;
    if (!q) return true;
    return (e.label || "").toLowerCase().includes(q) || (e.cat || "").toLowerCase().includes(q);
  });
}

function renderCats() {
  emCats.innerHTML = "";
  categories.forEach((c) => {
    catLabels[c.id] = c.label;
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `em-cat${activeCat === c.id ? " is-active" : ""}`;
    btn.textContent = c.label;
    btn.addEventListener("click", () => {
      activeCat = c.id;
      renderCats();
      renderGrid();
    });
    emCats.appendChild(btn);
  });
}

function renderGrid() {
  const list = filteredEmotes();
  emGrid.innerHTML = "";
  emEmpty.classList.toggle("hidden", list.length > 0);
  emCount.textContent = `${emotes.length} animacijų · rodoma ${list.length}`;

  list.forEach((e, idx) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "em-card";
    btn.style.animationDelay = `${Math.min(idx * 0.018, 0.45)}s`;
    btn.innerHTML = `<strong>${escapeHtml(e.label || "Animacija")}</strong><span>${escapeHtml(catLabels[e.cat] || e.cat || "")}</span>`;
    btn.addEventListener("click", () => nui("emotes:play", { id: e.id }));
    emGrid.appendChild(btn);
  });
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

emSearch.addEventListener("input", () => {
  searchQuery = emSearch.value || "";
  renderGrid();
});

emClose.addEventListener("click", () => nui("emotes:close", {}));
emCancel.addEventListener("click", () => nui("emotes:cancel", {}));

document.addEventListener("keydown", (ev) => {
  if (ev.key === "Escape" && !app.classList.contains("hidden")) {
    nui("emotes:close", {});
  }
});

window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data) return;

  if (data.action === "open") {
    categories = data.categories || [];
    emotes = data.emotes || [];
    activeCat = "all";
    searchQuery = "";
    emSearch.value = "";
    renderCats();
    renderGrid();
    openUi();
    return;
  }

  if (data.action === "close") {
    closeUi();
  }
});

const root = document.getElementById("root");
const dlTitle = document.getElementById("dlTitle");
const dlSubtitle = document.getElementById("dlSubtitle");
const dlTabs = document.getElementById("dlTabs");
const dlList = document.getElementById("dlList");
const dlActions = document.getElementById("dlActions");
const dlHint = document.getElementById("dlHint");
const dlClose = document.getElementById("dlClose");

let state = {
  categories: [],
  items: [],
  activeCategory: null,
};

let applyLocked = false;

function applyItem(payload) {
  if (applyLocked) return;
  applyLocked = true;
  root.classList.add("dl-busy");
  post("dutyLockerApply", payload).finally(() => {
    setTimeout(() => {
      applyLocked = false;
      root.classList.remove("dl-busy");
    }, 300);
  });
}

function post(name, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
}

function renderTabs() {
  dlTabs.innerHTML = "";
  state.categories.forEach((cat) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dl-tab" + (cat.id === state.activeCategory ? " active" : "");
    btn.textContent = cat.label;
    btn.onclick = () => {
      state.activeCategory = cat.id;
      renderTabs();
      renderList();
    };
    dlTabs.appendChild(btn);
  });
}

function renderList() {
  dlList.innerHTML = "";
  const cat = state.activeCategory;
  const rows = state.items.filter((it) => it.category === cat);

  const removable = ["hat", "vest", "belt", "extra"].includes(cat);
  if (removable) {
    const rm = document.createElement("button");
    rm.type = "button";
    rm.className = "dl-item remove";
    rm.innerHTML = "<strong>Nuimti</strong><small>Pašalinti šios kategorijos dalį</small>";
    rm.onclick = () => applyItem({ id: `remove:${cat}` });
    dlList.appendChild(rm);
  }

  if (!rows.length) {
    const empty = document.createElement("li");
    empty.className = "dl-empty";
    empty.textContent = "Šioje kategorijoje nėra variantų.";
    dlList.appendChild(empty);
    return;
  }

  rows.forEach((item) => {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dl-item";
    btn.innerHTML = `<strong>${item.label || "Apranga"}</strong>${item.description ? `<small>${item.description}</small>` : ""}`;
    btn.onclick = () => applyItem({ id: item.id, category: item.category });
    li.appendChild(btn);
    dlList.appendChild(li);
  });
}

function renderActions(actions) {
  dlActions.innerHTML = "";
  (actions || []).forEach((act) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dl-action" + (act.danger ? " danger" : "");
    btn.textContent = act.label || act.id;
    btn.onclick = () => post("dutyLockerAction", { id: act.id });
    dlActions.appendChild(btn);
  });
}

function openUi(data) {
  state.categories = data.categories || [];
  state.items = data.items || [];
  state.activeCategory = state.categories[0]?.id || null;

  dlTitle.textContent = data.title || "Darbo apranga";
  dlSubtitle.textContent = data.subtitle || "";
  dlSubtitle.style.display = data.subtitle ? "block" : "none";
  dlHint.textContent = data.hint || "ESC — uždaryti";

  renderTabs();
  renderList();
  renderActions(data.actions);
  root.classList.remove("hidden");
}

function closeUi() {
  root.classList.add("hidden");
  state = { categories: [], items: [], activeCategory: null };
}

dlClose.addEventListener("click", () => post("dutyLockerClose"));

window.addEventListener("keydown", (ev) => {
  if (ev.key === "Escape") {
    ev.preventDefault();
    post("dutyLockerClose");
  }
});

window.addEventListener("message", (ev) => {
  const msg = ev.data || {};
  if (msg.action === "open") openUi(msg.data || {});
  if (msg.action === "close") closeUi();
});

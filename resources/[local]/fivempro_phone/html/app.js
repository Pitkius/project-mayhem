const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fivempro_phone";
const screens = ["accountSetup", "homeScreen", "appStoreScreen", "appScreen"];
const APP_TEMPLATE = {
  emergency: "renderEmergencyApp",
  calls: "renderCallsApp",
  messages: "renderMessagesApp",
  contacts: "renderContactsApp",
  ads: "renderAdsApp",
  insta: "renderSocialApp",
};
const state = {
  me: { number: "000000", name: "Player" },
  account: { hasAccount: false, username: "" },
  appStore: { availableApps: [] },
  contacts: [],
  messagePreview: [],
  ads: [],
  posts: [],
  activeCallId: null,
  activeConvNumber: "",
};

function nui(event, data = {}) {
  return fetch(`https://${resourceName}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  }).then((r) => r.json());
}

function esc(str) {
  return String(str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function showScreen(id) {
  screens.forEach((s) => document.getElementById(s).classList.add("hidden"));
  document.getElementById(id).classList.remove("hidden");
}

function openHome() {
  if (!state.account?.hasAccount) {
    showScreen("accountSetup");
  } else {
    showScreen("homeScreen");
    renderHomeApps();
  }
}

function hydrate(payload = {}) {
  state.me = payload.me || state.me;
  state.account = payload.account || state.account;
  state.appStore = payload.appStore || state.appStore;
  state.contacts = payload.contacts || [];
  state.messagePreview = payload.messagePreview || [];
  state.ads = payload.ads || [];
  state.posts = payload.posts || [];
  document.getElementById("meNumber").textContent = `Nr: ${state.me.number}`;
  document.getElementById("profileName").textContent = state.account.username || state.me.name || "Player";
  openHome();
}

function renderHomeApps() {
  const grid = document.getElementById("appGrid");
  const installed = (state.appStore.availableApps || []).filter((a) => a.installed || a.default);
  grid.innerHTML = installed
    .map((app) => `<button class="app-icon" data-open-app="${esc(app.id)}"><span class="app-emoji">${esc(app.icon)}</span><span class="app-label">${esc(app.label)}</span></button>`)
    .join("");
  grid.querySelectorAll("[data-open-app]").forEach((btn) => {
    btn.addEventListener("click", () => openApp(btn.dataset.openApp));
  });
}

function renderAppStore() {
  const list = document.getElementById("storeList");
  list.innerHTML = (state.appStore.availableApps || [])
    .map((app) => `<div class="card"><b>${esc(app.icon)} ${esc(app.label)}</b><div class="small">${esc(app.id)}</div><button data-install-app="${esc(app.id)}">${app.installed || app.default ? "Installed" : "Install"}</button></div>`)
    .join("");
  list.querySelectorAll("[data-install-app]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const appId = btn.dataset.installApp;
      await nui("installApp", { appId });
      const fresh = await nui("refresh");
      hydrate(fresh || {});
      showScreen("appStoreScreen");
      renderAppStore();
    });
  });
}

function openAppStore() {
  showScreen("appStoreScreen");
  renderAppStore();
}

function openApp(appId) {
  showScreen("appScreen");
  document.getElementById("appTitle").textContent = appId.toUpperCase();
  const content = document.getElementById("appContent");
  const fn = APP_TEMPLATE[appId];
  if (!fn || typeof window[fn] !== "function") {
    content.innerHTML = `<div class="card">Programėlė dar ruošiama.</div>`;
    return;
  }
  window[fn](content);
}

window.renderEmergencyApp = (content) => {
  content.innerHTML = `<div class="card"><b>Skubus iškvietimas</b><div class="row"><button data-emerg="police">Policija</button><button data-emerg="ems">EMS</button></div><div class="row"><button data-emerg="taxi">Taxi</button><button data-emerg="mechanic">Mechanic</button></div></div>`;
  content.querySelectorAll("[data-emerg]").forEach((btn) => btn.addEventListener("click", () => nui("emergencyCall", { service: btn.dataset.emerg })));
};

window.renderCallsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="callNumber" placeholder="Numeris" /><button id="btnCall">Skambinti</button></div><button id="btnHangup">Baigti skambutį</button></div>`;
  document.getElementById("btnCall").addEventListener("click", () => nui("startCall", { number: (document.getElementById("callNumber").value || "").replace(/\D+/g, "") }));
  document.getElementById("btnHangup").addEventListener("click", () => state.activeCallId && nui("endCall", { callId: state.activeCallId }));
};

window.renderMessagesApp = (content) => {
  const n = state.activeConvNumber || "";
  const rows = state.messagePreview.filter((m) => !n || String(m.from_number) === n || String(m.to_number) === n);
  content.innerHTML = `<div class="card"><div class="row"><input id="msgNumber" value="${esc(n)}" placeholder="Numeris" /><button id="btnLoadConv">Open</button></div><div id="conversationList">${rows.map((m) => `<div>${esc(m.from_number)}: ${esc(m.body)}</div>`).join("")}</div><div class="row"><input id="msgBody" placeholder="Žinutė" /><button id="btnSendMsg">Siųsti</button></div></div>`;
  document.getElementById("btnLoadConv").addEventListener("click", () => { state.activeConvNumber = (document.getElementById("msgNumber").value || "").replace(/\D+/g, ""); openApp("messages"); });
  document.getElementById("btnSendMsg").addEventListener("click", async () => {
    const number = (document.getElementById("msgNumber").value || "").replace(/\D+/g, "");
    const body = document.getElementById("msgBody").value || "";
    if (!number || !body) return;
    await nui("sendMessage", { number, body });
    hydrate(await nui("refresh"));
    openApp("messages");
  });
};

window.renderContactsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="contactName" placeholder="Vardas" /><input id="contactNumber" placeholder="Nr" /></div><button id="btnSaveContact">Išsaugoti</button></div>${state.contacts.map((c) => `<div class="card">${esc(c.display_name)} (${esc(c.contact_number)})</div>`).join("")}`;
  document.getElementById("btnSaveContact").addEventListener("click", async () => {
    await nui("saveContact", { name: document.getElementById("contactName").value, number: document.getElementById("contactNumber").value });
    hydrate(await nui("refresh"));
    openApp("contacts");
  });
};

window.renderAdsApp = (content) => {
  content.innerHTML = `<div class="card"><div class="row"><input id="adBody" placeholder="Skelbimas" /><button id="btnPostAd">Kelti</button></div></div>${state.ads.map((a) => `<div class="card"><b>${esc(a.author_name)}</b><div>${esc(a.body)}</div></div>`).join("")}`;
  document.getElementById("btnPostAd").addEventListener("click", async () => {
    await nui("createAd", { body: document.getElementById("adBody").value });
    hydrate(await nui("refresh"));
    openApp("ads");
  });
};

window.renderSocialApp = (content) => {
  content.innerHTML = `<div class="card"><input id="postCaption" placeholder="Caption" /><input id="postImageUrl" placeholder="Image URL" /><button id="btnPostInsta">Kelti</button></div>${state.posts.map((p) => `<div class="card"><b>${esc(p.author_name)}</b><div>${esc(p.caption)}</div><button data-like="${Number(p.id)}">Like ${Number(p.likes || 0)}</button></div>`).join("")}`;
  document.getElementById("btnPostInsta").addEventListener("click", async () => {
    await nui("createPost", { caption: document.getElementById("postCaption").value, imageUrl: document.getElementById("postImageUrl").value });
    hydrate(await nui("refresh"));
    openApp("insta");
  });
  content.querySelectorAll("[data-like]").forEach((b) => b.addEventListener("click", async () => {
    await nui("likePost", { postId: Number(b.dataset.like) });
    hydrate(await nui("refresh"));
    openApp("insta");
  }));
};

window.addEventListener("message", async (e) => {
  const { action, payload } = e.data || {};
  if (action === "open") {
    document.getElementById("phone").classList.remove("hidden");
    openHome();
  } else if (action === "close") {
    document.getElementById("phone").classList.add("hidden");
  } else if (action === "hydrate") {
    hydrate(payload || {});
  } else if (action === "newMessageNotify") {
    hydrate(await nui("refresh"));
  } else if (action === "incomingCall") {
    state.activeCallId = payload?.id || null;
    document.getElementById("callState").textContent = `Incoming: ${payload?.fromNumber || "Unknown"}`;
  } else if (action === "callState") {
    state.activeCallId = payload?.id || null;
    document.getElementById("callState").textContent = payload?.status || "";
  }
});

document.getElementById("btnClose").addEventListener("click", () => nui("close"));
document.getElementById("openStore").addEventListener("click", openAppStore);
document.querySelectorAll("[data-back-home]").forEach((b) => b.addEventListener("click", openHome));
document.getElementById("btnCreateAccount").addEventListener("click", async () => {
  const res = await nui("createAccount", {
    username: document.getElementById("setupUsername").value,
    password: document.getElementById("setupPassword").value,
  });
  document.getElementById("setupState").textContent = res?.ok ? "Paskyra sukurta." : (res?.message || "Klaida");
  hydrate(await nui("refresh"));
});

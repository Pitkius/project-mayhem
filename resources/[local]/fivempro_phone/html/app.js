const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fivempro_phone";

const state = {
  me: { number: "000000", name: "Player" },
  contacts: [],
  messagePreview: [],
  ads: [],
  posts: [],
  activeConvNumber: "",
  activeCallId: null,
};

const phone = document.getElementById("phone");
const callState = document.getElementById("callState");
const meNumber = document.getElementById("meNumber");
const incomingWrap = document.getElementById("incomingWrap");
const incomingText = document.getElementById("incomingText");

function nui(event, data = {}) {
  return fetch(`https://${resourceName}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  }).then((r) => r.json());
}

function esc(str) {
  return String(str || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function formatTime(ts) {
  if (!ts) return "";
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return String(ts);
  return d.toLocaleString();
}

function setTab(name) {
  document.querySelectorAll(".tab").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === name);
  });
  document.querySelectorAll(".panel").forEach((p) => p.classList.add("hidden"));
  const el = document.getElementById(`tab-${name}`);
  if (el) el.classList.remove("hidden");
}

function renderContacts() {
  const el = document.getElementById("contactsList");
  el.innerHTML = state.contacts
    .map((c) => `<div class="card"><b>${esc(c.display_name)}</b><div class="small">${esc(c.contact_number)}</div></div>`)
    .join("");
}

function renderAds() {
  const el = document.getElementById("adsList");
  el.innerHTML = state.ads
    .map((a) => `<div class="card"><b>${esc(a.author_name)}</b> <span class="small">(${esc(a.phone_number)})</span><div>${esc(a.body)}</div><div class="small">${esc(formatTime(a.created_at))}</div></div>`)
    .join("");
}

function renderPosts() {
  const el = document.getElementById("postsList");
  el.innerHTML = state.posts
    .map((p) => {
      const img = p.image_url ? `<div><img src="${esc(p.image_url)}" style="max-width:100%;border-radius:8px;" /></div>` : "";
      return `<div class="card">
        <b>${esc(p.author_name)}</b>
        <div>${esc(p.caption)}</div>
        ${img}
        <div class="row">
          <span class="small">❤ ${Number(p.likes || 0)}</span>
          <button data-like="${Number(p.id)}">Like</button>
        </div>
      </div>`;
    })
    .join("");
  el.querySelectorAll("button[data-like]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      await nui("likePost", { postId: Number(btn.dataset.like) });
      await refresh();
    });
  });
}

function renderMessagePreview() {
  const box = document.getElementById("conversation");
  const n = state.activeConvNumber;
  if (!n) {
    box.innerHTML = '<div class="small">Įvesk numerį ir spausk "Atidaryti pokalbį".</div>';
    return;
  }
  const filtered = state.messagePreview
    .filter((m) => String(m.from_number) === n || String(m.to_number) === n)
    .sort((a, b) => Number(a.id) - Number(b.id));
  box.innerHTML = filtered
    .map((m) => {
      const mine = String(m.from_number) === String(state.me.number);
      return `<div class="card">
        <div><b>${mine ? "Tu" : esc(m.from_number)}</b></div>
        <div>${esc(m.body)}</div>
        <div class="small">${esc(formatTime(m.created_at))}</div>
      </div>`;
    })
    .join("");
}

function hydrate(data) {
  state.me = data.me || state.me;
  state.contacts = data.contacts || [];
  state.messagePreview = data.messagePreview || [];
  state.ads = data.ads || [];
  state.posts = data.posts || [];
  meNumber.textContent = `Nr: ${state.me.number}`;
  renderContacts();
  renderAds();
  renderPosts();
  renderMessagePreview();
}

async function refresh() {
  const data = await nui("refresh");
  hydrate(data || {});
}

window.addEventListener("message", (e) => {
  const { action, payload } = e.data || {};
  if (action === "open") {
    phone.classList.remove("hidden");
    setTab("home");
  } else if (action === "close") {
    phone.classList.add("hidden");
  } else if (action === "hydrate") {
    hydrate(payload || {});
  } else if (action === "newMessageNotify") {
    refresh();
  } else if (action === "incomingCall") {
    incomingWrap.classList.remove("hidden");
    state.activeCallId = payload?.id || null;
    incomingText.textContent = `Gaunamas skambutis iš ${payload?.fromNumber || "Nežinomas"}`;
  } else if (action === "callState") {
    const st = payload?.status || "";
    if (st === "connected") {
      callState.textContent = "Skambutis sujungtas";
    } else if (st === "ringing") {
      callState.textContent = "Skambinama...";
    } else if (st === "rejected") {
      callState.textContent = "Skambutis atmestas";
      state.activeCallId = null;
      incomingWrap.classList.add("hidden");
    } else if (st === "ended") {
      callState.textContent = "Skambutis baigtas";
      state.activeCallId = null;
      incomingWrap.classList.add("hidden");
    }
  }
});

document.getElementById("btnClose").addEventListener("click", () => nui("close"));
document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => setTab(b.dataset.tab)));

document.getElementById("btnSaveContact").addEventListener("click", async () => {
  const name = document.getElementById("contactName").value;
  const number = document.getElementById("contactNumber").value;
  await nui("saveContact", { name, number });
  document.getElementById("contactName").value = "";
  document.getElementById("contactNumber").value = "";
  await refresh();
});

document.getElementById("btnLoadConv").addEventListener("click", async () => {
  state.activeConvNumber = document.getElementById("msgNumber").value.replace(/\D+/g, "");
  renderMessagePreview();
});

document.getElementById("btnSendMsg").addEventListener("click", async () => {
  const number = (document.getElementById("msgNumber").value || "").replace(/\D+/g, "");
  const body = document.getElementById("msgBody").value;
  if (!number || !body) return;
  await nui("sendMessage", { number, body });
  document.getElementById("msgBody").value = "";
  state.activeConvNumber = number;
  await refresh();
});

document.getElementById("btnPostAd").addEventListener("click", async () => {
  const body = document.getElementById("adBody").value;
  if (!body) return;
  await nui("createAd", { body });
  document.getElementById("adBody").value = "";
  await refresh();
});

document.getElementById("btnPostInsta").addEventListener("click", async () => {
  const caption = document.getElementById("postCaption").value;
  const imageUrl = document.getElementById("postImageUrl").value;
  await nui("createPost", { caption, imageUrl });
  document.getElementById("postCaption").value = "";
  document.getElementById("postImageUrl").value = "";
  await refresh();
});

document.getElementById("btnCall").addEventListener("click", async () => {
  const number = (document.getElementById("callNumber").value || "").replace(/\D+/g, "");
  if (!number) return;
  await nui("startCall", { number });
});

document.getElementById("btnHangup").addEventListener("click", async () => {
  if (!state.activeCallId) return;
  await nui("endCall", { callId: state.activeCallId });
});

document.getElementById("btnAcceptCall").addEventListener("click", async () => {
  if (!state.activeCallId) return;
  await nui("respondCall", { callId: state.activeCallId, accept: true });
  incomingWrap.classList.add("hidden");
});

document.getElementById("btnRejectCall").addEventListener("click", async () => {
  if (!state.activeCallId) return;
  await nui("respondCall", { callId: state.activeCallId, accept: false });
  incomingWrap.classList.add("hidden");
});

document.getElementById("btnEmergPolice").addEventListener("click", () => nui("emergencyCall", { service: "police" }));
document.getElementById("btnEmergEms").addEventListener("click", () => nui("emergencyCall", { service: "ems" }));
document.getElementById("btnEmergTaxi").addEventListener("click", () => nui("emergencyCall", { service: "taxi" }));

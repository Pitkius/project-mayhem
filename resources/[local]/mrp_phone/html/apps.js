/** Programėlių UI — modulinė struktūra lengvam plėtimui */
(function () {
  const digits = (v) => String(v || "").replace(/\D+/g, "");

  function initials(name) {
    const parts = String(name || "?").trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return "?";
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  function contactName(number) {
    const n = digits(number);
    const hit = (window.PhoneState?.contacts || []).find((c) => digits(c.contact_number) === n);
    return hit ? hit.display_name : n;
  }

  function sortContacts(list) {
    const serviceOrder = { police: 0, ems: 1, mechanic: 2, taxi: 3 };
    return [...(list || [])].sort((a, b) => {
      const sa = isSystemContact(a) ? (serviceOrder[a.service] ?? 9) : 100;
      const sb = isSystemContact(b) ? (serviceOrder[b.service] ?? 9) : 100;
      if (sa !== sb) return sa - sb;
      return String(a.display_name || "").localeCompare(String(b.display_name || ""), "lt", { sensitivity: "base" });
    });
  }

  function contactAvatar(c, small) {
    const cls = small ? "avatar sm" : "avatar";
    if (isSystemContact(c) && c.system_icon && window.PhoneIconHtml) {
      return `<div class="${cls} avatar-icon">${window.PhoneIconHtml(c.system_icon, "contact-icon-wrap")}</div>`;
    }
    return `<div class="${cls}">${window.PhoneEsc(initials(c.display_name))}</div>`;
  }

  function contactByNumber(number) {
    const n = digits(number);
    return (window.PhoneState?.contacts || []).find((c) => digits(c.contact_number) === n) || null;
  }

  function isSystemContact(c) {
    return !!(c && (c.is_system || c.system));
  }

  function formatWhen(ts) {
    if (!ts) return "";
    const d = new Date(ts);
    if (Number.isNaN(d.getTime())) return String(ts);
    const now = new Date();
    const sameDay = d.toDateString() === now.toDateString();
    if (sameDay) return d.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
    return d.toLocaleDateString("lt-LT", { month: "short", day: "numeric" });
  }

  function bindChipScrollIndicator(wrap) {
    if (!wrap) return;
    const row = wrap.querySelector(".scroll-chips");
    const rail = wrap.querySelector(".chip-scroll-rail");
    const thumb = wrap.querySelector(".chip-scroll-thumb");
    if (!row || !rail || !thumb) return;

    const update = () => {
      const maxScroll = row.scrollWidth - row.clientWidth;
      const railW = rail.clientWidth;
      if (maxScroll <= 4 || railW <= 0) {
        rail.classList.add("is-hidden");
        return;
      }
      rail.classList.remove("is-hidden");
      const ratio = row.clientWidth / row.scrollWidth;
      const thumbW = Math.max(28, Math.floor(railW * ratio));
      const travel = railW - thumbW;
      const pct = row.scrollLeft / maxScroll;
      thumb.style.width = `${thumbW}px`;
      thumb.style.transform = `translateX(${Math.round(pct * travel)}px)`;
    };

    row.addEventListener("scroll", update, { passive: true });
    if (typeof ResizeObserver !== "undefined") {
      const ro = new ResizeObserver(update);
      ro.observe(row);
    }
    requestAnimationFrame(update);
  }

  function categoryLabel(id) {
    const cats = window.PhoneState?.adCategories || [];
    const hit = cats.find((c) => c.id === id);
    return hit ? hit.label : id;
  }

  async function refreshState() {
    const data = await window.PhoneNui("refresh");
    if (window.PhoneHydrate) window.PhoneHydrate(data);
    return data;
  }

  function startCall(number) {
    return window.PhoneNui("startCall", { number: digits(number) });
  }

  function openChat(number) {
    window.PhoneState.activeConvNumber = digits(number);
    window.PhoneOpenApp("messages");
  }

  window.refreshState = refreshState;
  window.startCall = startCall;
  window.openChat = openChat;

  window.PhoneApps = {
    renderContactsApp(content) {
      const contacts = sortContacts(window.PhoneState.contacts);
      const editing = window.PhoneState.contactEditId || null;

      content.innerHTML = `
        <div class="app-toolbar">
          <input type="search" id="contactSearch" class="search-input" placeholder="${window.t("contacts.search")}" />
          <button type="button" class="ios-btn compact primary" id="btnToggleContactForm">${window.t("contacts.add")}</button>
        </div>
        <div id="contactForm" class="card form-card hidden">
          <input id="contactName" placeholder="${window.t("contacts.name")}" maxlength="60" />
          <input id="contactNumber" placeholder="${window.t("contacts.number")}" maxlength="20" />
          <div class="row">
            <button type="button" class="ios-btn primary" id="btnSaveContact">${window.t("contacts.save")}</button>
            <button type="button" class="ios-btn" id="btnCancelContact">${window.t("common.cancel")}</button>
          </div>
        </div>
        <div id="contactList" class="list-stack"></div>`;

      const listEl = content.querySelector("#contactList");
      const formEl = content.querySelector("#contactForm");
      const searchEl = content.querySelector("#contactSearch");

      const renderList = (filter) => {
        const q = String(filter || "").toLowerCase();
        const rows = contacts.filter((c) => {
          if (!q) return true;
          return (
            String(c.display_name || "").toLowerCase().includes(q) ||
            String(c.contact_number || "").includes(q)
          );
        });
        if (!rows.length) {
          listEl.innerHTML = `<div class="empty-state">${window.t("contacts.empty")}</div>`;
          return;
        }
        listEl.innerHTML = rows
          .map((c) => {
            const num = digits(c.contact_number);
            const isEdit = editing === Number(c.id);
            const system = isSystemContact(c);
            return `<div class="list-item contact-item${system ? " system-contact" : ""}" data-id="${Number(c.id)}">
              ${contactAvatar(c)}
              <div class="list-item-body">
                <b>${window.PhoneEsc(c.display_name)}</b>${system ? ` <span class="tag">Tarnyba</span>` : ""}
                <div class="muted small">${window.PhoneEsc(num)}</div>
                ${
                  isEdit
                    ? `<div class="inline-edit row">
                    <input class="edit-name" value="${window.PhoneEsc(c.display_name)}" maxlength="60" />
                    <input class="edit-number" value="${window.PhoneEsc(num)}" maxlength="20" />
                    <button type="button" class="mini-btn save-edit">${window.t("contacts.save")}</button>
                  </div>`
                    : ""
                }
              </div>
              <div class="list-item-actions">
                <button type="button" class="icon-btn call" title="${window.t("contacts.call")}" data-call="${window.PhoneEsc(num)}">📞</button>
                ${system ? "" : `<button type="button" class="icon-btn msg" title="${window.t("contacts.message")}" data-msg="${window.PhoneEsc(num)}">💬</button>
                <button type="button" class="icon-btn edit" title="${window.t("contacts.edit")}" data-edit="${Number(c.id)}">✎</button>
                <button type="button" class="icon-btn danger" title="${window.t("contacts.delete")}" data-del="${Number(c.id)}">✕</button>`}
              </div>
            </div>`;
          })
          .join("");

        listEl.querySelectorAll("[data-call]").forEach((btn) =>
          btn.addEventListener("click", () => startCall(btn.dataset.call)),
        );
        listEl.querySelectorAll("[data-msg]").forEach((btn) =>
          btn.addEventListener("click", () => openChat(btn.dataset.msg)),
        );
        listEl.querySelectorAll("[data-edit]").forEach((btn) =>
          btn.addEventListener("click", () => {
            window.PhoneState.contactEditId = Number(btn.dataset.edit);
            window.PhoneOpenApp("contacts");
          }),
        );
        listEl.querySelectorAll("[data-del]").forEach((btn) =>
          btn.addEventListener("click", async () => {
            if (!confirm(window.t("contacts.confirmDelete"))) return;
            await window.PhoneNui("deleteContact", { id: Number(btn.dataset.del) });
            await refreshState();
            window.PhoneOpenApp("contacts");
          }),
        );
        listEl.querySelectorAll(".save-edit").forEach((btn) =>
          btn.addEventListener("click", async () => {
            const row = btn.closest(".contact-item");
            const id = Number(row?.dataset.id);
            const name = row.querySelector(".edit-name")?.value || "";
            const number = row.querySelector(".edit-number")?.value || "";
            await window.PhoneNui("updateContact", { id, name, number });
            window.PhoneState.contactEditId = null;
            await refreshState();
            window.PhoneOpenApp("contacts");
          }),
        );
      };

      renderList("");
      searchEl.addEventListener("input", () => renderList(searchEl.value));

      content.querySelector("#btnToggleContactForm").addEventListener("click", () => {
        formEl.classList.toggle("hidden");
      });
      content.querySelector("#btnCancelContact").addEventListener("click", () => {
        formEl.classList.add("hidden");
      });
      content.querySelector("#btnSaveContact").addEventListener("click", async () => {
        const name = content.querySelector("#contactName").value;
        const number = content.querySelector("#contactNumber").value;
        const res = await window.PhoneNui("saveContact", { name, number });
        if (!res?.ok) return;
        content.querySelector("#contactName").value = "";
        content.querySelector("#contactNumber").value = "";
        formEl.classList.add("hidden");
        await refreshState();
        window.PhoneOpenApp("contacts");
      });
    },

    renderMessagesApp(content) {
      const threads = window.PhoneState.messageThreads || [];
      const active = digits(window.PhoneState.activeConvNumber);
      const view = active ? "chat" : "list";

      if (view === "list") {
        content.innerHTML = `
          <div class="app-toolbar">
            <input type="search" id="threadSearch" class="search-input" placeholder="${window.t("messages.search")}" />
            <button type="button" class="ios-btn compact primary" id="btnNewThread">${window.t("messages.new")}</button>
          </div>
          <div id="newThreadBox" class="card form-card hidden">
            <input id="newThreadNumber" placeholder="${window.t("messages.to")}" />
            <button type="button" class="ios-btn primary" id="btnOpenThread">${window.t("messages.open")}</button>
          </div>
          <div id="threadList" class="list-stack"></div>`;

        const listEl = content.querySelector("#threadList");
        const renderThreads = (filter) => {
          const q = String(filter || "").toLowerCase();
          const rows = threads.filter((th) => {
            const name = contactName(th.peer_number).toLowerCase();
            const num = digits(th.peer_number);
            if (!q) return true;
            return name.includes(q) || num.includes(q);
          });
          if (!rows.length) {
            listEl.innerHTML = `<div class="empty-state">${window.t("messages.empty")}</div>`;
            return;
          }
          listEl.innerHTML = rows
            .map((th) => {
              const num = digits(th.peer_number);
              const name = contactName(num);
              return `<button type="button" class="list-item thread-item" data-peer="${window.PhoneEsc(num)}">
                ${contactAvatar(contactByNumber(num) || { display_name: name }, false)}
                <div class="list-item-body">
                  <div class="thread-top"><b>${window.PhoneEsc(name)}</b><span class="muted small">${formatWhen(th.last_at)}</span></div>
                  <div class="muted small thread-preview">${th.direction === "out" ? "Jūs: " : ""}${window.PhoneEsc(th.last_body)}</div>
                </div>
              </button>`;
            })
            .join("");
          listEl.querySelectorAll(".thread-item").forEach((btn) =>
            btn.addEventListener("click", () => openChat(btn.dataset.peer)),
          );
        };
        renderThreads("");
        content.querySelector("#threadSearch").addEventListener("input", (e) => renderThreads(e.target.value));
        content.querySelector("#btnNewThread").addEventListener("click", () => {
          content.querySelector("#newThreadBox").classList.toggle("hidden");
        });
        content.querySelector("#btnOpenThread").addEventListener("click", () => {
          const num = digits(content.querySelector("#newThreadNumber").value);
          if (!num) return;
          openChat(num);
        });
        return;
      }

      content.innerHTML = `
        <div class="chat-header">
          <button type="button" class="nav-back chat-back" id="btnBackThreads">&lt;</button>
          <div>
            <b>${window.PhoneEsc(contactName(active))}</b>
            <div class="muted small">${window.PhoneEsc(active)}</div>
          </div>
          <button type="button" class="icon-btn call" id="btnChatCall" title="${window.t("contacts.call")}">📞</button>
        </div>
        <div id="chatMessages" class="chat-messages"><div class="muted small">${window.t("common.loading")}</div></div>
        <div class="chat-compose">
          <input id="msgBody" placeholder="${window.t("messages.placeholder")}" maxlength="320" />
          <button type="button" class="ios-btn primary compact" id="btnSendMsg">${window.t("messages.send")}</button>
        </div>`;

      content.querySelector("#btnBackThreads").addEventListener("click", () => {
        window.PhoneState.activeConvNumber = "";
        window.PhoneOpenApp("messages");
      });
      content.querySelector("#btnChatCall").addEventListener("click", () => startCall(active));

      const chatEl = content.querySelector("#chatMessages");
      const myNum = digits(window.PhoneState.me?.number);

      window.PhoneNui("getConversation", { number: active }).then((res) => {
        const msgs = res?.messages || [];
        if (!msgs.length) {
          chatEl.innerHTML = `<div class="empty-state">${window.t("messages.empty")}</div>`;
          return;
        }
        chatEl.innerHTML = msgs
          .map((m) => {
            const out = digits(m.from_number) === myNum;
            return `<div class="bubble-row ${out ? "out" : "in"}">
              <div class="bubble">${window.PhoneEsc(m.body)}</div>
              <div class="bubble-time muted small">${formatWhen(m.created_at)}</div>
            </div>`;
          })
          .join("");
        chatEl.scrollTop = chatEl.scrollHeight;
      });

      content.querySelector("#btnSendMsg").addEventListener("click", async () => {
        const body = content.querySelector("#msgBody").value || "";
        if (!body.trim()) return;
        await window.PhoneNui("sendMessage", { number: active, body });
        content.querySelector("#msgBody").value = "";
        await refreshState();
        window.PhoneOpenApp("messages");
      });
    },

    renderCallsApp(content) {
      const threads = (window.PhoneState.messageThreads || []).slice(0, 8);
      const contacts = sortContacts(window.PhoneState.contacts);
      const pad = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"];

      content.innerHTML = `
        <div class="card dial-card">
          <input id="callNumber" class="dial-input" placeholder="${window.t("calls.dial")}" inputmode="tel" />
          <div class="dial-pad">
            ${pad.map((k) => `<button type="button" class="pad-key" data-key="${k}">${k}</button>`).join("")}
          </div>
          <div class="row dial-actions">
            <button type="button" class="ios-btn primary" id="btnCall">${window.t("calls.call")}</button>
            <button type="button" class="ios-btn danger" id="btnHangup">${window.t("calls.hangup")}</button>
          </div>
          <p class="muted small">${window.t("calls.yourNumber")}: ${window.PhoneEsc(window.PhoneState.me?.number)}</p>
        </div>
        <div class="section-title">${window.t("calls.fromContacts")}</div>
        <div class="chip-row">${contacts
          .map(
            (c) =>
              `<button type="button" class="chip" data-num="${window.PhoneEsc(digits(c.contact_number))}">${window.PhoneEsc(c.display_name)}</button>`,
          )
          .join("")}</div>
        <div class="section-title">${window.t("calls.recent")}</div>
        <div class="list-stack">${threads
          .map((th) => {
            const num = digits(th.peer_number);
            return `<button type="button" class="list-item thread-item compact" data-num="${window.PhoneEsc(num)}">
              ${contactAvatar(contactByNumber(num) || { display_name: contactName(num) }, true)}
              <div class="list-item-body"><b>${window.PhoneEsc(contactName(num))}</b><div class="muted small">${window.PhoneEsc(num)}</div></div>
            </button>`;
          })
          .join("")}</div>`;

      const input = content.querySelector("#callNumber");
      content.querySelectorAll(".pad-key").forEach((btn) =>
        btn.addEventListener("click", () => {
          input.value = digits(input.value + btn.dataset.key);
        }),
      );
      content.querySelectorAll("[data-num]").forEach((btn) =>
        btn.addEventListener("click", () => {
          input.value = btn.dataset.num;
        }),
      );
      content.querySelector("#btnCall").addEventListener("click", () => startCall(input.value));
      content.querySelector("#btnHangup").addEventListener("click", () => {
        const id = window.PhoneState.activeCallId;
        if (id) window.PhoneNui("endCall", { callId: id });
      });
    },

  };
})();

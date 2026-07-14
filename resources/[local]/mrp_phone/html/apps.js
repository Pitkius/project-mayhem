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
    const cls = small ? "core-avatar sm" : "core-avatar";
    if (isSystemContact(c) && c.system_icon && window.PhoneIconHtml) {
      return `<div class="${cls} icon">${window.PhoneIconHtml(c.system_icon, "contact-icon-wrap")}</div>`;
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

  function ico(name) {
    return window.PhoneIco ? window.PhoneIco(name) : "";
  }

  const READ_KEY = "mrp_phone_read";

  function getReadMap() {
    try {
      return JSON.parse(localStorage.getItem(READ_KEY) || "{}");
    } catch (_) {
      return {};
    }
  }

  function markThreadRead(peer, lastAt) {
    const key = digits(peer);
    if (!key) return;
    const map = getReadMap();
    map[key] = lastAt || new Date().toISOString();
    localStorage.setItem(READ_KEY, JSON.stringify(map));
  }

  function isThreadUnread(th) {
    if (!th || th.direction !== "in") return false;
    const key = digits(th.peer_number);
    const readAt = getReadMap()[key];
    if (!readAt || !th.last_at) return true;
    return new Date(th.last_at) > new Date(readAt);
  }

  function groupLetter(name) {
    const ch = String(name || "#").trim().charAt(0).toUpperCase();
    if (/[A-ZĄČĘĖĮŠŲŪŽ]/.test(ch)) return ch;
    if (/[0-9]/.test(ch)) return "#";
    return "#";
  }

  const callsUi = { tab: "dial" };

  window.refreshState = refreshState;
  window.startCall = startCall;
  window.openChat = openChat;

  window.PhoneApps = {
    renderContactsApp(content) {
      content.className = "scroll-body core-app-body";
      const contacts = sortContacts(window.PhoneState.contacts);
      const editing = window.PhoneState.contactEditId || null;

      content.innerHTML = `
        <div class="core-app-panel">
          <div class="core-search-bar">
            ${ico("search")}
            <input type="search" id="contactSearch" placeholder="${window.t("contacts.search")}" />
            <button type="button" class="core-icon-btn primary" id="btnToggleContactForm" title="${window.t("contacts.add")}">${ico("plus")}</button>
          </div>
          <div id="contactForm" class="neon-card contacts-form-card hidden">
            <input id="contactName" placeholder="${window.t("contacts.name")}" maxlength="60" />
            <input id="contactNumber" placeholder="${window.t("contacts.number")}" maxlength="20" />
            <div class="row">
              <button type="button" class="ios-btn primary" id="btnSaveContact">${window.t("contacts.save")}</button>
              <button type="button" class="ios-btn" id="btnCancelContact">${window.t("common.cancel")}</button>
            </div>
          </div>
          <div class="contacts-layout">
            <div class="contacts-list-wrap" id="contactList"></div>
            <nav class="contacts-az" id="contactAz"></nav>
          </div>
        </div>`;

      const listEl = content.querySelector("#contactList");
      const azEl = content.querySelector("#contactAz");
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
          azEl.innerHTML = "";
          return;
        }

        const systems = rows.filter((c) => isSystemContact(c));
        const regular = rows.filter((c) => !isSystemContact(c));
        const groups = {};
        regular.forEach((c) => {
          const letter = groupLetter(c.display_name);
          if (!groups[letter]) groups[letter] = [];
          groups[letter].push(c);
        });
        const letters = Object.keys(groups).sort((a, b) => a.localeCompare(b, "lt"));

        const renderRow = (c) => {
          const num = digits(c.contact_number);
          const isEdit = editing === Number(c.id);
          const system = isSystemContact(c);
          return `<div class="core-list-item contact-item${system ? " system" : ""}" data-id="${Number(c.id)}">
            ${contactAvatar(c)}
            <div class="core-list-body">
              <b>${window.PhoneEsc(c.display_name)}${system ? ` <span class="tag">Tarnyba</span>` : ""}</b>
              <div class="sub">${window.PhoneEsc(num)}</div>
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
            <div class="core-list-actions">
              <button type="button" class="core-icon-btn" title="${window.t("contacts.call")}" data-call="${window.PhoneEsc(num)}">${ico("call")}</button>
              ${system ? "" : `<button type="button" class="core-icon-btn" title="${window.t("contacts.message")}" data-msg="${window.PhoneEsc(num)}">${ico("msg")}</button>
              <button type="button" class="core-icon-btn" title="${window.t("contacts.edit")}" data-edit="${Number(c.id)}">${ico("edit")}</button>
              <button type="button" class="core-icon-btn danger" title="${window.t("contacts.delete")}" data-del="${Number(c.id)}">${ico("trash")}</button>`}
            </div>
          </div>`;
        };

        let html = "";
        if (systems.length) {
          html += `<div class="core-section-label">Tarnybos</div><div class="core-list-stack">${systems.map(renderRow).join("")}</div>`;
        }
        letters.forEach((letter) => {
          html += `<div class="core-section-label" id="contact-section-${letter}">${letter}</div>`;
          html += `<div class="core-list-stack">${groups[letter].map(renderRow).join("")}</div>`;
        });
        listEl.innerHTML = html;

        azEl.innerHTML = letters
          .map((l) => `<button type="button" data-letter="${l}" title="${l}">${l}</button>`)
          .join("");
        azEl.querySelectorAll("button").forEach((btn) => {
          btn.addEventListener("click", () => {
            const target = listEl.querySelector(`#contact-section-${btn.dataset.letter}`);
            if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
          });
        });

        listEl.querySelectorAll("[data-call]").forEach((btn) =>
          btn.addEventListener("click", (e) => {
            e.stopPropagation();
            startCall(btn.dataset.call);
          }),
        );
        listEl.querySelectorAll("[data-msg]").forEach((btn) =>
          btn.addEventListener("click", (e) => {
            e.stopPropagation();
            openChat(btn.dataset.msg);
          }),
        );
        listEl.querySelectorAll("[data-edit]").forEach((btn) =>
          btn.addEventListener("click", (e) => {
            e.stopPropagation();
            window.PhoneState.contactEditId = Number(btn.dataset.edit);
            window.PhoneOpenApp("contacts");
          }),
        );
        listEl.querySelectorAll("[data-del]").forEach((btn) =>
          btn.addEventListener("click", async (e) => {
            e.stopPropagation();
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
        content.className = "scroll-body core-app-body";
        content.innerHTML = `
          <div class="core-app-panel">
            <div class="core-search-bar">
              ${ico("search")}
              <input type="search" id="threadSearch" placeholder="${window.t("messages.search")}" />
              <button type="button" class="core-icon-btn primary" id="btnNewThread" title="${window.t("messages.new")}">${ico("plus")}</button>
            </div>
            <div id="newThreadBox" class="neon-card contacts-form-card hidden">
              <input id="newThreadNumber" placeholder="${window.t("messages.to")}" />
              <button type="button" class="ios-btn primary" id="btnOpenThread">${window.t("messages.open")}</button>
            </div>
            <div id="threadList" class="core-list-stack"></div>
          </div>`;

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
              const unread = isThreadUnread(th);
              return `<button type="button" class="core-list-item thread-item" data-peer="${window.PhoneEsc(num)}">
                ${contactAvatar(contactByNumber(num) || { display_name: name }, false)}
                <div class="core-list-body">
                  <div class="thread-top"><b>${window.PhoneEsc(name)}</b><span class="muted small">${formatWhen(th.last_at)}</span></div>
                  <div class="sub">${th.direction === "out" ? "Jūs: " : ""}${window.PhoneEsc(th.last_body)}</div>
                </div>
                ${unread ? '<span class="core-badge">1</span>' : ""}
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

      content.className = "scroll-body core-app-body chat-app";
      content.innerHTML = `
        <div class="chat-header">
          <button type="button" class="core-icon-btn chat-back" id="btnBackThreads">${ico("back")}</button>
          <div class="core-list-body">
            <b>${window.PhoneEsc(contactName(active))}</b>
            <div class="sub">${window.PhoneEsc(active)}</div>
          </div>
          <button type="button" class="core-icon-btn" id="btnChatCall" title="${window.t("contacts.call")}">${ico("call")}</button>
        </div>
        <div id="chatMessages" class="chat-messages"><div class="muted small">${window.t("common.loading")}</div></div>
        <div class="chat-compose-modern">
          <input id="msgBody" placeholder="${window.t("messages.placeholder")}" maxlength="320" />
          <button type="button" class="core-icon-btn primary" id="btnSendMsg" title="${window.t("messages.send")}">${ico("send")}</button>
        </div>`;

      const thread = threads.find((th) => digits(th.peer_number) === active);
      if (thread) markThreadRead(active, thread.last_at);

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

      const sendMsg = async () => {
        const body = content.querySelector("#msgBody").value || "";
        if (!body.trim()) return;
        await window.PhoneNui("sendMessage", { number: active, body });
        content.querySelector("#msgBody").value = "";
        await refreshState();
        window.PhoneOpenApp("messages");
      };
      content.querySelector("#btnSendMsg").addEventListener("click", sendMsg);
      content.querySelector("#msgBody").addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          sendMsg();
        }
      });
    },

    renderCallsApp(content) {
      content.className = "scroll-body core-app-body";
      const threads = (window.PhoneState.messageThreads || []).slice(0, 12);
      const contacts = sortContacts(window.PhoneState.contacts);
      const pad = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"];
      const tab = callsUi.tab || "dial";

      const renderPanel = () => {
        const panel = content.querySelector("#callsPanel");
        if (!panel) return;

        if (tab === "dial") {
          panel.innerHTML = `
            <div class="calls-dial-display" id="callNumberDisplay">—</div>
            <input type="tel" id="callNumber" class="hidden" />
            <div class="calls-pad">
              ${pad.map((k) => `<button type="button" class="pad-key" data-key="${k}">${k}</button>`).join("")}
            </div>
            <div class="calls-action-row">
              <button type="button" class="calls-call-btn green" id="btnCall" title="${window.t("calls.call")}">${ico("call")}</button>
              <button type="button" class="calls-call-btn red" id="btnHangup" title="${window.t("calls.hangup")}">${ico("hangup")}</button>
            </div>
            <p class="muted small" style="text-align:center;padding:8px">${window.t("calls.yourNumber")}: ${window.PhoneEsc(window.PhoneState.me?.number)}</p>`;

          const input = panel.querySelector("#callNumber");
          const display = panel.querySelector("#callNumberDisplay");
          const syncDisplay = () => {
            display.textContent = digits(input.value) || "—";
          };
          panel.querySelectorAll(".pad-key").forEach((btn) =>
            btn.addEventListener("click", () => {
              input.value = digits(input.value + btn.dataset.key);
              syncDisplay();
            }),
          );
          panel.querySelector("#btnCall").addEventListener("click", () => startCall(input.value));
          panel.querySelector("#btnHangup").addEventListener("click", () => {
            const id = window.PhoneState.activeCallId;
            if (id) window.PhoneNui("endCall", { callId: id });
          });
          syncDisplay();
          return;
        }

        if (tab === "recent") {
          panel.innerHTML = threads.length
            ? `<div class="core-list-stack">${threads
                .map((th) => {
                  const num = digits(th.peer_number);
                  const name = contactName(num);
                  const missed = th.direction === "in";
                  return `<button type="button" class="core-list-item" data-num="${window.PhoneEsc(num)}">
                    ${contactAvatar(contactByNumber(num) || { display_name: name }, true)}
                    <div class="core-list-body">
                      <b>${window.PhoneEsc(name)}</b>
                      <div class="sub">${missed ? "Gautas · " : "Siųstas · "}${formatWhen(th.last_at)}</div>
                    </div>
                    <span class="core-icon-btn" style="pointer-events:none">${ico("call")}</span>
                  </button>`;
                })
                .join("")}</div>`
            : `<div class="empty-state">Nėra naujausių kontaktų</div>`;
          panel.querySelectorAll("[data-num]").forEach((btn) =>
            btn.addEventListener("click", () => startCall(btn.dataset.num)),
          );
          return;
        }

        panel.innerHTML = `
          <div class="core-search-bar" style="margin-bottom:12px">
            ${ico("search")}
            <input type="search" id="callsContactSearch" placeholder="Ieškoti kontakto" />
          </div>
          <div id="callsContactList" class="core-list-stack"></div>`;
        const listEl = panel.querySelector("#callsContactList");
        const searchEl = panel.querySelector("#callsContactSearch");
        const renderContacts = (filter) => {
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
              return `<button type="button" class="core-list-item${isSystemContact(c) ? " system" : ""}" data-num="${window.PhoneEsc(num)}">
                ${contactAvatar(c, true)}
                <div class="core-list-body"><b>${window.PhoneEsc(c.display_name)}</b><div class="sub">${window.PhoneEsc(num)}</div></div>
                ${ico("call")}
              </button>`;
            })
            .join("");
          listEl.querySelectorAll("[data-num]").forEach((btn) =>
            btn.addEventListener("click", () => startCall(btn.dataset.num)),
          );
        };
        renderContacts("");
        searchEl.addEventListener("input", () => renderContacts(searchEl.value));
      };

      content.innerHTML = `
        <div class="core-app-panel" id="callsPanel"></div>
        <nav class="calls-tabbar">
          <button type="button" data-tab="dial" class="${tab === "dial" ? "active" : ""}"><span class="ico">${ico("dial")}</span>Klaviatūra</button>
          <button type="button" data-tab="recent" class="${tab === "recent" ? "active" : ""}"><span class="ico">${ico("clock")}</span>Naujausi</button>
          <button type="button" data-tab="contacts" class="${tab === "contacts" ? "active" : ""}"><span class="ico">${ico("contacts")}</span>Kontaktai</button>
        </nav>`;

      renderPanel();
      content.querySelectorAll(".calls-tabbar [data-tab]").forEach((btn) => {
        btn.addEventListener("click", () => {
          callsUi.tab = btn.dataset.tab || "dial";
          window.PhoneOpenApp("calls");
        });
      });
    },

  };
})();

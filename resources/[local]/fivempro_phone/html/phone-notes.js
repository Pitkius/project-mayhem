(function () {
  const ui = {
    screen: "list",
    editingId: null,
    draft: { title: "", body: "" },
    status: "",
    statusError: false,
  };

  function esc(s) {
    return window.PhoneEsc ? window.PhoneEsc(s) : String(s || "");
  }

  function nui(action, data) {
    return window.PhoneNui ? window.PhoneNui(action, data) : Promise.resolve({ ok: false });
  }

  function t(key, fallback) {
    return window.t ? window.t(key, fallback) : fallback;
  }

  function notes() {
    const list = window.PhoneState?.notes;
    return Array.isArray(list) ? list : [];
  }

  function setNotes(list) {
    if (!window.PhoneState) return;
    window.PhoneState.notes = Array.isArray(list) ? list : [];
  }

  function preview(body) {
    const text = String(body || "").replace(/\s+/g, " ").trim();
    if (!text) return t("notes.emptyBody", "Tuščias užrašas");
    return text.length > 72 ? `${text.slice(0, 72)}…` : text;
  }

  function formatDate(iso) {
    if (!iso) return "";
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString("lt-LT", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
  }

  function renderList() {
    const items = notes();
    if (!items.length) {
      return `
        <div class="notes-empty neon-card">
          <p>${esc(t("notes.empty", "Dar neturite užrašų."))}</p>
          <button type="button" id="btnNewNote" class="ios-btn primary">${esc(t("notes.new", "Naujas užrašas"))}</button>
        </div>`;
    }
    return `
      <div class="notes-toolbar">
        <span class="muted small">${items.length} ${esc(t("notes.count", "užrašai"))}</span>
        <button type="button" id="btnNewNote" class="notes-new-btn">+ ${esc(t("notes.newShort", "Naujas"))}</button>
      </div>
      <div class="notes-list">${items
        .map(
          (n) => `<button type="button" class="notes-item" data-id="${n.id}">
            <strong>${esc(n.title || t("notes.untitled", "Be pavadinimo"))}</strong>
            <span class="notes-preview">${esc(preview(n.body))}</span>
            <span class="notes-date muted small">${esc(formatDate(n.updated_at || n.created_at))}</span>
          </button>`
        )
        .join("")}</div>`;
  }

  function renderEditor() {
    return `
      <div class="notes-editor neon-card">
        <label class="small muted" for="noteTitle">${esc(t("notes.titleLabel", "Pavadinimas"))}</label>
        <input id="noteTitle" type="text" maxlength="64" placeholder="${esc(t("notes.titlePh", "Užrašo pavadinimas"))}" value="${esc(ui.draft.title)}" />
        <label class="small muted" for="noteBody">${esc(t("notes.bodyLabel", "Užrašas"))}</label>
        <textarea id="noteBody" rows="10" placeholder="${esc(t("notes.bodyPh", "Rašykite čia…"))}">${esc(ui.draft.body)}</textarea>
        <p class="small ${ui.statusError ? "notes-status-err" : "muted"}" id="notesStatus">${esc(ui.status)}</p>
        <div class="notes-actions">
          <button type="button" id="btnBackNotes" class="ios-btn">${esc(t("notes.back", "Atgal"))}</button>
          ${ui.editingId ? `<button type="button" id="btnDeleteNote" class="ios-btn notes-del">${esc(t("notes.delete", "Ištrinti"))}</button>` : ""}
          <button type="button" id="btnSaveNote" class="ios-btn primary">${esc(t("notes.save", "Išsaugoti"))}</button>
        </div>
      </div>`;
  }

  function renderShell() {
    return `<div class="notes-app">
      <div class="notes-head">
        <h2>${esc(t("notes.appTitle", "Užrašai"))}</h2>
        <p class="muted small">${esc(t("notes.appHint", "Keli užrašai su pavadinimais"))}</p>
      </div>
      ${ui.screen === "list" ? renderList() : renderEditor()}
    </div>`;
  }

  function openEditor(note) {
    ui.screen = "edit";
    ui.editingId = note?.id || null;
    ui.draft = {
      title: note?.title || "",
      body: note?.body || "",
    };
    ui.status = "";
    ui.statusError = false;
    paint();
  }

  function openList() {
    ui.screen = "list";
    ui.editingId = null;
    ui.draft = { title: "", body: "" };
    ui.status = "";
    ui.statusError = false;
    paint();
  }

  function paint() {
    const root = document.getElementById("notesAppRoot");
    if (!root) return;
    root.innerHTML = renderShell();
    bindEvents();
  }

  async function saveNote() {
    const root = document.getElementById("notesAppRoot");
    const title = root?.querySelector("#noteTitle")?.value?.trim() || "";
    const body = root?.querySelector("#noteBody")?.value || "";
    ui.draft = { title, body };
    const btn = root?.querySelector("#btnSaveNote");
    if (!title) {
      ui.status = t("notes.needTitle", "Įveskite pavadinimą.");
      ui.statusError = true;
      paint();
      return;
    }
    if (!body.trim()) {
      ui.status = t("notes.needBody", "Įveskite užrašo tekstą.");
      ui.statusError = true;
      paint();
      return;
    }
    if (btn) btn.disabled = true;
    ui.status = t("notes.saving", "Saugoma…");
    ui.statusError = false;
    paint();
    try {
      const res = await nui("saveNotes", { id: ui.editingId, title, body });
      if (res?.ok) {
        const saved = res.note || { id: ui.editingId, title, body, updated_at: new Date().toISOString() };
        let list = notes().filter((n) => n.id !== saved.id);
        list.unshift({
          id: saved.id,
          title: saved.title || title,
          body: saved.body || body,
          updated_at: saved.updated_at || new Date().toISOString(),
        });
        setNotes(list);
        openList();
        return;
      }
      ui.status = res?.message || t("notes.error", "Nepavyko išsaugoti.");
      ui.statusError = true;
    } catch (_) {
      ui.status = t("notes.error", "Nepavyko išsaugoti.");
      ui.statusError = true;
    }
    paint();
  }

  async function deleteNote() {
    if (!ui.editingId) return;
    const root = document.getElementById("notesAppRoot");
    const btn = root?.querySelector("#btnDeleteNote");
    if (btn) btn.disabled = true;
    try {
      const res = await nui("deleteNote", { id: ui.editingId });
      if (res?.ok) {
        setNotes(notes().filter((n) => n.id !== ui.editingId));
        openList();
        return;
      }
      ui.status = res?.message || t("notes.error", "Nepavyko ištrinti.");
      ui.statusError = true;
    } catch (_) {
      ui.status = t("notes.error", "Nepavyko ištrinti.");
      ui.statusError = true;
    }
    paint();
  }

  function bindEvents() {
    document.getElementById("btnNewNote")?.addEventListener("click", () => openEditor(null));
    document.getElementById("btnBackNotes")?.addEventListener("click", openList);
    document.getElementById("btnSaveNote")?.addEventListener("click", saveNote);
    document.getElementById("btnDeleteNote")?.addEventListener("click", deleteNote);
    document.querySelectorAll(".notes-item").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = Number(btn.dataset.id);
        const note = notes().find((n) => n.id === id);
        if (note) openEditor(note);
      });
    });
  }

  window.PhoneNotes = {
    render(content) {
      openList();
      content.innerHTML = `<div id="notesAppRoot" class="scroll-body notes-body"></div>`;
      paint();
    },
  };

  window.renderNotesApp = (content) => {
    if (window.PhoneNotes) window.PhoneNotes.render(content);
  };
})();

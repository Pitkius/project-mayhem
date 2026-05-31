(function () {
  if (window.__fpLtKeyboardInit) return;
  window.__fpLtKeyboardInit = true;

  const ROWS = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="],
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"],
    ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"],
  ];

  const LT_LOWER = ["ą", "č", "ę", "ė", "į", "š", "ų", "ū", "ž"];
  const LT_UPPER = ["Ą", "Č", "Ę", "Ė", "Į", "Š", "Ų", "Ū", "Ž"];

  let activeInput = null;
  let shiftOn = false;
  let root = null;

  function insertAtCursor(el, text) {
    if (!el) return;
    const start = el.selectionStart ?? el.value.length;
    const end = el.selectionEnd ?? el.value.length;
    const before = el.value.slice(0, start);
    const after = el.value.slice(end);
    el.value = before + text + after;
    const pos = start + text.length;
    el.setSelectionRange(pos, pos);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function backspace(el) {
    if (!el) return;
    const start = el.selectionStart ?? 0;
    const end = el.selectionEnd ?? 0;
    if (start !== end) {
      el.value = el.value.slice(0, start) + el.value.slice(end);
      el.setSelectionRange(start, start);
    } else if (start > 0) {
      el.value = el.value.slice(0, start - 1) + el.value.slice(start);
      el.setSelectionRange(start - 1, start - 1);
    }
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function mapKey(key) {
    if (shiftOn && key.length === 1 && /[a-z]/.test(key)) return key.toUpperCase();
    return key;
  }

  function buildKeyboard() {
    root = document.createElement("div");
    root.id = "fp-lt-keyboard";

    const label = document.createElement("div");
    label.className = "fp-lt-label";
    label.textContent = "Lietuviška klaviatūra";
    root.appendChild(label);

    ROWS.forEach((row) => {
      const rowEl = document.createElement("div");
      rowEl.className = "fp-lt-row";
      row.forEach((key) => {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "fp-lt-key";
        btn.textContent = key;
        btn.addEventListener("mousedown", (e) => e.preventDefault());
        btn.addEventListener("click", () => insertAtCursor(activeInput, mapKey(key)));
        rowEl.appendChild(btn);
      });
      root.appendChild(rowEl);
    });

    const ltRow = document.createElement("div");
    ltRow.className = "fp-lt-row";
    LT_LOWER.forEach((ch, i) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "fp-lt-key fp-lt-special";
      btn.textContent = ch;
      btn.addEventListener("mousedown", (e) => e.preventDefault());
      btn.addEventListener("click", () => insertAtCursor(activeInput, shiftOn ? LT_UPPER[i] : ch));
      ltRow.appendChild(btn);
    });
    root.appendChild(ltRow);

    const bottom = document.createElement("div");
    bottom.className = "fp-lt-row";

    const shiftBtn = document.createElement("button");
    shiftBtn.type = "button";
    shiftBtn.className = "fp-lt-key fp-lt-wide";
    shiftBtn.textContent = "Shift";
    shiftBtn.addEventListener("mousedown", (e) => e.preventDefault());
    shiftBtn.addEventListener("click", () => {
      shiftOn = !shiftOn;
      shiftBtn.style.background = shiftOn ? "#a78bfa" : "";
      shiftBtn.style.color = shiftOn ? "#1c1533" : "";
      refreshRowLabels();
    });
    bottom.appendChild(shiftBtn);

    const spaceBtn = document.createElement("button");
    spaceBtn.type = "button";
    spaceBtn.className = "fp-lt-key fp-lt-space";
    spaceBtn.textContent = "Tarpas";
    spaceBtn.addEventListener("mousedown", (e) => e.preventDefault());
    spaceBtn.addEventListener("click", () => insertAtCursor(activeInput, " "));
    bottom.appendChild(spaceBtn);

    const bsBtn = document.createElement("button");
    bsBtn.type = "button";
    bsBtn.className = "fp-lt-key fp-lt-wide";
    bsBtn.textContent = "⌫";
    bsBtn.addEventListener("mousedown", (e) => e.preventDefault());
    bsBtn.addEventListener("click", () => backspace(activeInput));
    bottom.appendChild(bsBtn);

    const closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = "fp-lt-key fp-lt-wide";
    closeBtn.textContent = "✕";
    closeBtn.addEventListener("mousedown", (e) => e.preventDefault());
    closeBtn.addEventListener("click", hideKeyboard);
    bottom.appendChild(closeBtn);

    root.appendChild(bottom);
    document.body.appendChild(root);
  }

  function refreshRowLabels() {
    if (!root) return;
    const rows = root.querySelectorAll(".fp-lt-row");
    ROWS.forEach((row, ri) => {
      const rowEl = rows[ri + 1];
      if (!rowEl) return;
      const keys = rowEl.querySelectorAll(".fp-lt-key");
      row.forEach((key, ki) => {
        if (keys[ki]) keys[ki].textContent = shiftOn && /[a-z]/.test(key) ? key.toUpperCase() : key;
      });
    });
  }

  function isTextInput(el) {
    if (!el) return false;
    const tag = el.tagName;
    if (tag === "TEXTAREA") return true;
    if (tag !== "INPUT") return false;
    const type = (el.type || "text").toLowerCase();
    return ["text", "password", "search", "email", "tel", "url", "number"].includes(type);
  }

  function showKeyboard(el) {
    if (!root) buildKeyboard();
    activeInput = el;
    root.classList.add("is-open");
  }

  function hideKeyboard() {
    activeInput = null;
    if (root) root.classList.remove("is-open");
    shiftOn = false;
  }

  document.addEventListener(
    "focusin",
    (e) => {
      if (isTextInput(e.target)) showKeyboard(e.target);
    },
    true
  );

  document.addEventListener(
    "focusout",
    (e) => {
      setTimeout(() => {
        const focused = document.activeElement;
        if (!isTextInput(focused)) hideKeyboard();
      }, 120);
    },
    true
  );

  document.addEventListener("mousedown", (e) => {
    if (!root || !root.classList.contains("is-open")) return;
    if (root.contains(e.target)) return;
    if (isTextInput(e.target)) return;
    hideKeyboard();
  });
})();

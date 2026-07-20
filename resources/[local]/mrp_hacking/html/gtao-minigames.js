/**
 * GTA Online stiliaus minigame'ai bankams / seifams.
 * gtao_datacrack — klasikinis „Data Crack“ (žali blokai, kaip mhacking / GTAO).
 * gtao_drill — Fleeca gręžimas (esamas drill UI, alias).
 */
(function () {
  const CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  function post(name, data) {
    if (typeof fetch !== "undefined" && typeof GetParentResourceName === "function") {
      fetch(`https://${GetParentResourceName()}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data || {}),
      });
    }
  }

  let crackState = null;
  let crackRaf = null;
  let crackKeyHandler = null;

  function stopCrack() {
    if (crackRaf) cancelAnimationFrame(crackRaf);
    crackRaf = null;
    if (crackKeyHandler) {
      window.removeEventListener("keydown", crackKeyHandler);
      crackKeyHandler = null;
    }
    crackState = null;
  }

  function finishCrack(ok) {
    stopCrack();
    const panel = document.getElementById("gtaoCrack");
    if (panel) panel.classList.add("hidden");
    // hackState gali būti null — siunčiam tiesiai
    post("hackResult", { success: ok === true });
  }

  function randChar() {
    return CHARSET[Math.floor(Math.random() * CHARSET.length)];
  }

  function buildRows(count, len) {
    const rows = [];
    for (let i = 0; i < count; i++) {
      let s = "";
      for (let j = 0; j < len; j++) s += randChar();
      rows.push(s);
    }
    return rows;
  }

  function renderCrack() {
    const board = document.getElementById("gtaoCrackBoard");
    const targetEl = document.getElementById("gtaoCrackTarget");
    const livesEl = document.getElementById("gtaoCrackLives");
    const timerEl = document.getElementById("gtaoCrackTimer");
    if (!board || !crackState) return;
    targetEl.textContent = crackState.target;
    livesEl.textContent = String(crackState.lives);
    const left = Math.max(0, (crackState.deadline - Date.now()) / 1000);
    timerEl.textContent = left.toFixed(1) + "s";
    board.innerHTML = "";
    crackState.rows.forEach((row, idx) => {
      const div = document.createElement("div");
      div.className = "gtao-crack-row" + (idx === crackState.focus ? " is-focus" : "");
      const highlight = row.slice(0, crackState.matchLen);
      const rest = row.slice(crackState.matchLen);
      div.innerHTML =
        '<span class="gtao-crack-match">' +
        highlight +
        '</span><span class="gtao-crack-rest">' +
        rest +
        "</span>";
      board.appendChild(div);
    });
  }

  function tickCrack() {
    if (!crackState) return;
    if (Date.now() > crackState.deadline) {
      finishCrack(false);
      return;
    }
    crackState.rows = crackState.rows.map((row, idx) => {
      if (idx === crackState.focus) return row;
      if (Math.random() < 0.08) {
        const arr = row.split("");
        const i = Math.floor(Math.random() * arr.length);
        arr[i] = randChar();
        return arr.join("");
      }
      return row;
    });
    renderCrack();
    crackRaf = requestAnimationFrame(tickCrack);
  }

  function onCrackKey(e) {
    if (!crackState) return;
    if (e.code === "ArrowUp" || e.code === "KeyW") {
      e.preventDefault();
      crackState.focus = Math.max(0, crackState.focus - 1);
      crackState.matchLen = 0;
      renderCrack();
      return;
    }
    if (e.code === "ArrowDown" || e.code === "KeyS") {
      e.preventDefault();
      crackState.focus = Math.min(crackState.rows.length - 1, crackState.focus + 1);
      crackState.matchLen = 0;
      renderCrack();
      return;
    }
    if (e.code === "Escape") {
      e.preventDefault();
      finishCrack(false);
      return;
    }
    const ch = (e.key || "").toUpperCase();
    if (!CHARSET.includes(ch)) return;
    e.preventDefault();
    const row = crackState.rows[crackState.focus];
    const need = crackState.target[crackState.matchLen];
    if (ch === need && row[crackState.matchLen] === need) {
      crackState.matchLen += 1;
      if (crackState.matchLen >= crackState.target.length) {
        finishCrack(true);
        return;
      }
    } else {
      crackState.lives -= 1;
      crackState.matchLen = 0;
      if (crackState.lives <= 0) {
        finishCrack(false);
        return;
      }
    }
    renderCrack();
  }

  /**
   * GTA Online Data Crack: pasirink eilutę (W/S), spausk raides pagal TARGET.
   */
  window.startGtaoDatacrack = function startGtaoDatacrack(profile, tierId) {
    stopCrack();
    const hackPanel = document.getElementById("hack");
    const tablet = document.getElementById("tablet");
    const physical = document.getElementById("physical");
    tablet?.classList.add("hidden");
    physical?.classList.add("hidden");
    hackPanel?.classList.add("hidden");

    let panel = document.getElementById("gtaoCrack");
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "gtaoCrack";
      panel.className = "gtao-crack hidden";
      panel.innerHTML = `
        <div class="gtao-crack-frame">
          <header class="gtao-crack-head">
            <span>REMOTE ACCESS — DATA CRACK</span>
            <span id="gtaoCrackTimer">0.0s</span>
          </header>
          <p class="gtao-crack-hint">W/S — eilutė · spausk raides pagal TARGET · ESC — atšaukti</p>
          <div class="gtao-crack-meta">
            <div>TARGET <strong id="gtaoCrackTarget">----</strong></div>
            <div>LIVES <strong id="gtaoCrackLives">3</strong></div>
          </div>
          <div id="gtaoCrackBoard" class="gtao-crack-board"></div>
          <button type="button" id="gtaoCrackCancel" class="btn danger">Nutraukti</button>
        </div>`;
      document.body.appendChild(panel);
      panel.querySelector("#gtaoCrackCancel").onclick = () => finishCrack(false);
    }

    const rows = Math.max(4, Math.min(7, (profile && profile.steps) || 5));
    const len = Math.max(5, Math.min(8, (profile && profile.grid) || 6));
    const target = buildRows(1, len)[0];
    const pool = buildRows(rows, len);
    pool[Math.floor(Math.random() * rows)] = target;

    crackState = {
      tierId,
      rows: pool,
      target,
      focus: 0,
      matchLen: 0,
      lives: 3,
      deadline: Date.now() + ((profile && profile.timeMs) || 20000),
    };

    panel.classList.remove("hidden");
    crackKeyHandler = onCrackKey;
    window.addEventListener("keydown", crackKeyHandler);
    renderCrack();
    crackRaf = requestAnimationFrame(tickCrack);
  };
})();

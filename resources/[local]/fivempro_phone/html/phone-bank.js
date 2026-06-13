(function () {
  const bankUi = {
    tab: "home",
    screen: "home",
    data: null,
    hideBalance: false,
    transfer: { query: "", recipient: null, amount: "", purpose: "" },
    pending: null,
    success: null,
    amountAction: null,
    historyFilter: "all",
    lookupTimer: null,
  };

  const icon = (name, cls) => (window.BankIcon ? window.BankIcon(name, cls) : "");

  const TX_META = {
    transfer_out: { icon: "transferOut", income: false },
    transfer_in: { icon: "transferIn", income: true },
    deposit: { icon: "deposit", income: true },
    withdraw: { icon: "transferOut", income: false },
    payment: { icon: "payment", income: false },
    salary: { icon: "salary", income: true },
    fine: { icon: "fine", income: false },
    other: { icon: "other", income: false },
  };

  function esc(s) {
    return window.PhoneEsc ? window.PhoneEsc(s) : String(s || "");
  }

  function fmtMoney(n, signed) {
    const v = Math.round(Number(n) || 0);
    const abs = Math.abs(v).toLocaleString("lt-LT");
    if (signed && v > 0) return `+${abs} €`;
    if (signed && v < 0) return `−${abs} €`;
    return `${abs} €`;
  }

  function maskCard(last4) {
    const l = String(last4 || "0000").padStart(4, "0");
    return `•••• •••• •••• ${l}`;
  }

  function initials(name) {
    const p = String(name || "?").trim().split(/\s+/);
    return ((p[0]?.[0] || "") + (p[1]?.[0] || "")).toUpperCase() || "?";
  }

  function parseTxDate(iso) {
    if (!iso) return null;
    if (typeof iso === "number") {
      const d = new Date(iso);
      return Number.isNaN(d.getTime()) ? null : d;
    }
    const direct = new Date(iso);
    if (!Number.isNaN(direct.getTime())) return direct;
    const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/);
    if (!m) return null;
    return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0));
  }

  function txMeta(type, amount) {
    const m = TX_META[type] || TX_META.other;
    const amt = Number(amount) || 0;
    const income = amt > 0 || m.income;
    return { icon: m.icon, income, cls: income ? "income" : "expense" };
  }

  function formatTxDate(iso) {
    const d = parseTxDate(iso);
    if (!d) return String(iso || "");
    const now = new Date();
    const sameDay = (a, b) =>
      a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const time = d.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
    if (sameDay(d, now)) return `Šiandien ${time}`;
    if (sameDay(d, yesterday)) return `Vakar ${time}`;
    return d.toLocaleDateString("lt-LT", { month: "short", day: "numeric" }) + ` ${time}`;
  }

  function groupByDate(txs) {
    const groups = [];
    let cur = null;
    for (const tx of txs || []) {
      const d = parseTxDate(tx.created_at);
      let label = "Anksčiau";
      const now = new Date();
      const yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      const same = (a, b) =>
        a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
      if (d) {
        if (same(d, now)) label = "Šiandien";
        else if (same(d, yesterday)) label = "Vakar";
        else label = d.toLocaleDateString("lt-LT", { weekday: "long", month: "long", day: "numeric" });
      }
      if (!cur || cur.label !== label) {
        cur = { label, items: [] };
        groups.push(cur);
      }
      cur.items.push(tx);
    }
    return groups;
  }

  function renderTxItem(tx) {
    const meta = txMeta(tx.tx_type, tx.amount);
    const amt = Number(tx.amount) || 0;
    const cls = amt > 0 ? "pos" : amt < 0 ? "neg" : "neu";
    const status = tx.status === "completed" ? "įvykdyta" : esc(tx.status || "įvykdyta");
    return `<div class="bank-tx-item">
      <div class="bank-tx-icon ${meta.cls}">${icon(meta.icon)}</div>
      <div>
        <div class="bank-tx-title">${esc(tx.title || "Operacija")}</div>
        <div class="bank-tx-sub">${esc(formatTxDate(tx.created_at))} · ${status}</div>
      </div>
      <div class="bank-tx-amount ${cls}">${fmtMoney(amt, true)}</div>
    </div>`;
  }

  async function loadState() {
    const res = await window.PhoneNui("bankGetState", {});
    if (res?.ok) {
      bankUi.data = res;
      if (window.PhoneState) {
        window.PhoneState.money = { cash: res.cash, bank: res.bank };
      }
    }
    return res;
  }

  function navHtml(active) {
    const tabs = [
      { id: "home", icon: "home", label: "Pagrindinis" },
      { id: "transfer", icon: "transfer", label: "Pervedimai" },
      { id: "history", icon: "history", label: "Istorija" },
    ];
    return `<nav class="bank-nav">${tabs
      .map(
        (t) =>
          `<button type="button" class="bank-nav-btn${active === t.id ? " active" : ""}" data-bank-tab="${t.id}">
            ${icon(t.icon, "bank-nav-svg")}<span>${t.label}</span>
          </button>`
      )
      .join("")}</nav>`;
  }

  function bindNav(host) {
    host.querySelectorAll("[data-bank-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        bankUi.tab = btn.dataset.bankTab;
        bankUi.screen = bankUi.tab;
        if (bankUi.tab === "transfer") bankUi.transfer = { query: "", recipient: null, amount: "", purpose: "" };
        renderBank(host);
      });
    });
  }

  function renderHome(host) {
    const d = bankUi.data || {};
    const balHidden = bankUi.hideBalance;
    const bankStr = balHidden ? "••••••" : fmtMoney(d.bank);
    const cashStr = balHidden ? "••••••" : fmtMoney(d.cash);
    const txs = (d.transactions || []).slice(0, 6);

    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-screen-scroll">
        <div class="bank-brand-row">
          <div class="bank-brand">${esc(d.bankName || "BANKAS")}</div>
          <div class="bank-bell">${icon("bell")}</div>
        </div>
        <div class="bank-greeting">Sveiki, ${esc(d.holderName || "žaidėjas")}</div>

        <div class="bank-card-visual">
          <div class="bank-card-chip"></div>
          <div class="bank-card-number">${maskCard(d.cardLast4)}</div>
          <div class="bank-card-meta">
            <span>${esc(d.accountNumber || "")}</span>
            <span class="bank-card-visa">VISA</span>
          </div>
        </div>

        <div class="bank-balances">
          <div class="bank-balance-row">
            <div>
              <div class="bank-balance-label">Banko balansas</div>
              <div class="bank-balance-value bank">${bankStr}
                <button type="button" class="bank-hide-bal" id="bankToggleBal" title="Slėpti">${icon(balHidden ? "eye" : "eyeOff", "bank-eye-svg")}</button>
              </div>
            </div>
          </div>
          <div class="bank-balance-row">
            <div>
              <div class="bank-balance-label">Grynieji pinigai</div>
              <div class="bank-balance-value cash">${cashStr}</div>
            </div>
          </div>
        </div>

        <div class="bank-quick-grid">
          <button type="button" class="bank-quick-btn" data-bank-action="transfer">${icon("transfer", "bank-quick-svg")}<span>Pervesti</span></button>
          <button type="button" class="bank-quick-btn" data-bank-action="deposit">${icon("deposit", "bank-quick-svg")}<span>Įnešti</span></button>
          <button type="button" class="bank-quick-btn" data-bank-action="history">${icon("history", "bank-quick-svg")}<span>Istorija</span></button>
        </div>

        <div class="bank-section-head">
          <b>Paskutinės operacijos</b>
          <button type="button" class="bank-link" data-bank-action="history">Žiūrėti viską</button>
        </div>
        <div class="bank-tx-list">
          ${txs.length ? txs.map(renderTxItem).join("") : '<div class="bank-empty">Operacijų dar nėra. Atlikite pervedimą ar įnešimą.</div>'}
        </div>
      </div>
      ${navHtml("home")}
    </div>`;

    host.querySelector("#bankToggleBal")?.addEventListener("click", () => {
      bankUi.hideBalance = !bankUi.hideBalance;
      renderBank(host);
    });
    host.querySelectorAll("[data-bank-action]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const a = btn.dataset.bankAction;
        if (a === "history") {
          bankUi.tab = "history";
          bankUi.screen = "history";
        } else if (a === "transfer") {
          bankUi.tab = "transfer";
          bankUi.screen = "transfer";
          bankUi.transfer = { query: "", recipient: null, amount: "", purpose: "" };
        } else {
          bankUi.screen = a;
          bankUi.amountAction = a;
        }
        renderBank(host);
      });
    });
    bindNav(host);
  }

  function renderTransfer(host) {
    const t = bankUi.transfer;
    const chips = [20, 50, 100, 500, 1000];
    const found = t.recipient
      ? `<div class="bank-recipient-found">
          <div class="bank-recipient-avatar">${esc(initials(t.recipient.name))}</div>
          <div><b>${esc(t.recipient.name)}</b><small>ID: ${esc(t.recipient.citizenid)}</small></div>
          <span class="bank-found-badge">Rastas</span>
        </div>`
      : "";

    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-screen-scroll">
        <div class="bank-header">
          <button type="button" class="bank-header-back" data-bank-back="home">‹</button>
          <span class="bank-header-title">Pervesti pinigus</span>
          <span class="bank-header-spacer"></span>
        </div>

        <div class="bank-field">
          <label>Gavėjo ID arba sąskaita</label>
          <input type="text" id="bankRecipient" placeholder="CitizenID arba LT-0000-0000" value="${esc(t.query)}" autocomplete="off" />
        </div>
        ${found}

        <div class="bank-field">
          <label>Suma (€)</label>
          <input type="number" id="bankAmount" min="1" placeholder="0" value="${esc(t.amount)}" />
        </div>
        <div class="bank-chips">
          ${chips.map((c) => `<button type="button" class="bank-chip${String(t.amount) === String(c) ? " active" : ""}" data-bank-chip="${c}">€${c}</button>`).join("")}
        </div>

        <div class="bank-field">
          <label>Paskirtis (pasirenkama)</label>
          <textarea id="bankPurpose" placeholder="Pvz. už prekes">${esc(t.purpose)}</textarea>
        </div>

        <button type="button" class="bank-submit" id="bankReviewBtn">Peržiūrėti ir patvirtinti</button>
        <div class="bank-status-msg" id="bankTransferMsg"></div>
      </div>
      ${navHtml("transfer")}
    </div>`;

    const msg = host.querySelector("#bankTransferMsg");
    const lookup = async (q) => {
      t.query = q;
      if (q.length < 2) {
        t.recipient = null;
        renderBank(host);
        return;
      }
      const res = await window.PhoneNui("bankLookupRecipient", { query: q });
      if (res?.ok && res.recipient) {
        t.recipient = res.recipient;
        if (msg) msg.textContent = "";
      } else {
        t.recipient = null;
        if (msg && q.length >= 3) {
          msg.textContent = res?.message || "";
          msg.className = "bank-status-msg err";
        }
      }
      renderBank(host);
    };

    const recipInput = host.querySelector("#bankRecipient");
    recipInput?.addEventListener("input", (e) => {
      clearTimeout(bankUi.lookupTimer);
      bankUi.lookupTimer = setTimeout(() => lookup(e.target.value.trim()), 400);
    });

    host.querySelector("#bankAmount")?.addEventListener("input", (e) => {
      t.amount = e.target.value;
    });
    host.querySelector("#bankPurpose")?.addEventListener("input", (e) => {
      t.purpose = e.target.value;
    });
    host.querySelectorAll("[data-bank-chip]").forEach((btn) => {
      btn.addEventListener("click", () => {
        t.amount = btn.dataset.bankChip;
        renderBank(host);
      });
    });
    host.querySelector("#bankReviewBtn")?.addEventListener("click", () => {
      t.amount = host.querySelector("#bankAmount")?.value || t.amount;
      t.purpose = host.querySelector("#bankPurpose")?.value || t.purpose;
      t.query = host.querySelector("#bankRecipient")?.value?.trim() || t.query;
      if (!t.recipient) {
        if (msg) {
          msg.textContent = "Įveskite galiojantį gavėją.";
          msg.className = "bank-status-msg err";
        }
        return;
      }
      const amt = Math.floor(Number(t.amount) || 0);
      if (amt < 1) {
        if (msg) {
          msg.textContent = "Įveskite sumą.";
          msg.className = "bank-status-msg err";
        }
        return;
      }
      bankUi.pending = { type: "transfer", amount: amt, recipient: t.recipient, purpose: t.purpose };
      bankUi.screen = "confirm";
      renderBank(host);
    });
    host.querySelector("[data-bank-back]")?.addEventListener("click", () => {
      bankUi.screen = "home";
      bankUi.tab = "home";
      renderBank(host);
    });
    bindNav(host);
  }

  function renderConfirm(host) {
    const p = bankUi.pending || {};
    const amt = p.amount || 0;
    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-screen-scroll">
        <div class="bank-header">
          <button type="button" class="bank-header-back" data-bank-back="transfer">‹</button>
          <span class="bank-header-title">Patvirtinti</span>
          <span class="bank-header-spacer"></span>
        </div>
        <div class="bank-confirm-icon">${icon("transfer", "bank-confirm-svg")}</div>
        <div class="bank-confirm-title">Ar tikrai norite pervesti?</div>
        <p class="bank-confirm-sub">
          ${fmtMoney(amt)} žaidėjui <b>${esc(p.recipient?.name)}</b>
        </p>
        <div class="bank-confirm-card">
          <div class="bank-confirm-row"><span>Gavėjas</span><span>${esc(p.recipient?.name)}</span></div>
          <div class="bank-confirm-row"><span>ID</span><span>${esc(p.recipient?.citizenid)}</span></div>
          <div class="bank-confirm-row"><span>Suma</span><span>${fmtMoney(amt)}</span></div>
          <div class="bank-confirm-row"><span>Paskirtis</span><span>${esc(p.purpose || "—")}</span></div>
          <div class="bank-confirm-row"><span>Mokesčiai</span><span>€0</span></div>
          <div class="bank-confirm-row"><span>Iš viso</span><span class="bank-confirm-total">${fmtMoney(amt)}</span></div>
        </div>
        <p class="bank-confirm-note">${icon("shield", "bank-shield-svg")} Pervedimas bus atliktas akimirksniu.</p>
        <div class="bank-confirm-actions">
          <button type="button" class="bank-btn-secondary" id="bankCancelConfirm">Atšaukti</button>
          <button type="button" class="bank-btn-primary" id="bankDoConfirm">Patvirtinti</button>
        </div>
        <div class="bank-status-msg" id="bankConfirmMsg"></div>
      </div>
    </div>`;

    host.querySelector("#bankCancelConfirm")?.addEventListener("click", () => {
      bankUi.screen = "transfer";
      renderBank(host);
    });
    host.querySelector("[data-bank-back]")?.addEventListener("click", () => {
      bankUi.screen = "transfer";
      renderBank(host);
    });
    host.querySelector("#bankDoConfirm")?.addEventListener("click", async () => {
      const btn = host.querySelector("#bankDoConfirm");
      const msg = host.querySelector("#bankConfirmMsg");
      if (btn) btn.disabled = true;
      const res = await window.PhoneNui("bankTransfer", {
        recipient: p.recipient?.citizenid,
        amount: p.amount,
        purpose: p.purpose,
      });
      if (btn) btn.disabled = false;
      if (res?.ok) {
        bankUi.success = {
          title: "Pervedimas atliktas!",
          body: `Sėkmingai išsiuntėte ${fmtMoney(res.amount)} žaidėjui ${res.recipientName}.`,
          txId: res.txId,
        };
        bankUi.pending = null;
        bankUi.transfer = { query: "", recipient: null, amount: "", purpose: "" };
        await loadState();
        bankUi.screen = "success";
        renderBank(host);
      } else if (msg) {
        msg.textContent = res?.message || "Nepavyko pervesti.";
        msg.className = "bank-status-msg err";
      }
    });
  }

  function renderSuccess(host) {
    const s = bankUi.success || {};
    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-success bank-screen-scroll">
        <div class="bank-success-icon">${icon("check", "bank-success-svg")}</div>
        <h3>${esc(s.title || "Atlikta!")}</h3>
        <p>${esc(s.body || "")}</p>
        ${s.txId ? `<div class="bank-tx-id">#${esc(s.txId)} <button type="button" class="bank-copy-btn" id="bankCopyTx">Kopijuoti</button></div>` : ""}
        <button type="button" class="bank-submit" id="bankGoHome">Grįžti į pagrindinį</button>
        <button type="button" class="bank-btn-secondary bank-success-secondary" id="bankAgain">Atlikti dar vieną</button>
      </div>
    </div>`;
    host.querySelector("#bankGoHome")?.addEventListener("click", () => {
      bankUi.screen = "home";
      bankUi.tab = "home";
      bankUi.success = null;
      renderBank(host);
    });
    host.querySelector("#bankAgain")?.addEventListener("click", () => {
      bankUi.screen = "transfer";
      bankUi.tab = "transfer";
      bankUi.success = null;
      renderBank(host);
    });
    host.querySelector("#bankCopyTx")?.addEventListener("click", () => {
      if (s.txId && navigator.clipboard) navigator.clipboard.writeText(s.txId);
    });
  }

  function renderDepositScreen(host) {
    const chips = [100, 500, 1000, 5000];
    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-screen-scroll">
        <div class="bank-header">
          <button type="button" class="bank-header-back" data-bank-back="home">‹</button>
          <span class="bank-header-title">Įnešti pinigus</span>
          <span class="bank-header-spacer"></span>
        </div>
        <p class="bank-hint">Grynieji → bankas</p>
        <div class="bank-field">
          <label>Suma (€)</label>
          <input type="number" id="bankAmtInput" min="1" placeholder="0" />
        </div>
        <div class="bank-chips">
          ${chips.map((c) => `<button type="button" class="bank-chip" data-bank-chip="${c}">€${c}</button>`).join("")}
        </div>
        <button type="button" class="bank-submit" id="bankAmtSubmit">Įnešti</button>
        <div class="bank-status-msg" id="bankAmtMsg"></div>
      </div>
    </div>`;

    let amount = "";
    host.querySelector("#bankAmtInput")?.addEventListener("input", (e) => {
      amount = e.target.value;
    });
    host.querySelectorAll("[data-bank-chip]").forEach((btn) => {
      btn.addEventListener("click", () => {
        amount = btn.dataset.bankChip;
        const inp = host.querySelector("#bankAmtInput");
        if (inp) inp.value = amount;
      });
    });
    host.querySelector("[data-bank-back]")?.addEventListener("click", () => {
      bankUi.screen = "home";
      bankUi.tab = "home";
      renderBank(host);
    });
    host.querySelector("#bankAmtSubmit")?.addEventListener("click", async () => {
      const msg = host.querySelector("#bankAmtMsg");
      const inp = host.querySelector("#bankAmtInput");
      const val = Math.floor(Number(inp?.value || amount) || 0);
      if (val < 1) {
        if (msg) {
          msg.textContent = "Įveskite sumą.";
          msg.className = "bank-status-msg err";
        }
        return;
      }
      const res = await window.PhoneNui("bankDeposit", { amount: val });
      if (res?.ok) {
        await loadState();
        bankUi.success = {
          title: "Įnešta!",
          body: `${fmtMoney(val)} perkelta į banką.`,
        };
        bankUi.screen = "success";
        renderBank(host);
      } else if (msg) {
        msg.textContent = res?.message || "Operacija nepavyko.";
        msg.className = "bank-status-msg err";
      }
    });
  }

  async function renderHistory(host) {
    const filters = [
      { id: "all", label: "Visos" },
      { id: "transfer_out", label: "Pervedimai" },
      { id: "transfer_in", label: "Gautos" },
      { id: "deposit", label: "Įnešimai" },
      { id: "salary", label: "Algos" },
      { id: "payment", label: "Pirkimai" },
      { id: "fine", label: "Baudos" },
    ];

    host.innerHTML = `<div class="bank-app">
      <div class="bank-screen bank-screen-history">
        <div class="bank-header">
          <button type="button" class="bank-header-back" data-bank-back="home">‹</button>
          <span class="bank-header-title">Transakcijų istorija</span>
          <span class="bank-header-spacer"></span>
        </div>
        <div class="bank-filter-tabs bank-scroll-x">${filters
          .map(
            (f) =>
              `<button type="button" class="bank-filter-tab${bankUi.historyFilter === f.id ? " active" : ""}" data-bank-filter="${f.id}">${f.label}</button>`
          )
          .join("")}</div>
        <div class="bank-history-scroll bank-scroll-y">
          <div class="bank-history-loading">Kraunama…</div>
        </div>
      </div>
      ${navHtml("history")}
    </div>`;

    const scroll = host.querySelector(".bank-history-scroll");
    const res = await window.PhoneNui("bankGetHistory", { filter: bankUi.historyFilter });
    const txs = res?.ok ? res.transactions || [] : bankUi.data?.transactions || [];
    const groups = groupByDate(txs);

    if (scroll) {
      scroll.innerHTML = groups.length
        ? groups
            .map(
              (g) =>
                `<div class="bank-date-group">${esc(g.label)}</div>${g.items.map(renderTxItem).join("")}`
            )
            .join("")
        : `<div class="bank-empty">${res?.ok === false ? esc(res.message || "Nepavyko užkrauti istorijos.") : "Operacijų nerasta."}</div>`;
    }

    host.querySelectorAll("[data-bank-filter]").forEach((btn) => {
      btn.addEventListener("click", () => {
        bankUi.historyFilter = btn.dataset.bankFilter;
        renderBank(host);
      });
    });
    host.querySelector("[data-bank-back]")?.addEventListener("click", () => {
      bankUi.screen = "home";
      bankUi.tab = "home";
      renderBank(host);
    });
    bindNav(host);
  }

  function renderBank(host) {
    const screen = bankUi.screen;
    if (screen === "confirm") return renderConfirm(host);
    if (screen === "success") return renderSuccess(host);
    if (screen === "deposit") return renderDepositScreen(host);
    if (screen === "transfer" || bankUi.tab === "transfer") return renderTransfer(host);
    if (screen === "history" || bankUi.tab === "history") return renderHistory(host);
    return renderHome(host);
  }

  window.renderBankApp = async function renderBankApp(content) {
    content.className = "scroll-body bank-body";
    content.innerHTML = `<div class="bank-empty">Kraunama…</div>`;
    bankUi.tab = "home";
    bankUi.screen = "home";
    bankUi.pending = null;
    bankUi.success = null;
    bankUi.historyFilter = "all";
    await loadState();
    renderBank(content);
  };
})();

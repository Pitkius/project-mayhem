(function () {
    const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fivempro_bank";

    const NAV = [
        { id: "home", icon: "🏠", label: "Pagrindinis" },
        { id: "transfer", icon: "💸", label: "Pervesti" },
        { id: "deposit", icon: "🏦", label: "Įnešti" },
        { id: "withdraw", icon: "💵", label: "Išsiimti" },
        { id: "history", icon: "📋", label: "Istorija" },
        { id: "stats", icon: "📊", label: "Statistika" },
        { id: "settings", icon: "⚙️", label: "Nustatymai" },
    ];

    const TX_ICON = {
        transfer_out: "💸",
        transfer_in: "💰",
        deposit: "🏦",
        withdraw: "💵",
        payment: "🏪",
        salary: "💰",
        fine: "⚠️",
        other: "📄",
    };

    const FILTER_CHIPS = [
        { id: "all", label: "Visos" },
        { id: "transfer_out", label: "Pervedimai" },
        { id: "transfer_in", label: "Gavimai" },
        { id: "salary", label: "Algos" },
        { id: "payment", label: "Mokėjimai" },
        { id: "deposit", label: "Įnešimai" },
        { id: "withdraw", label: "Išėmimai" },
    ];

    const WITHDRAW_PRESETS = [50, 100, 250, 500, 1000];
    const DEPOSIT_PRESETS = [100, 250, 500];

    const state = {
        open: false,
        tab: "home",
        data: null,
        history: [],
        historyFilter: "all",
        historySearch: "",
        transfer: { query: "", recipient: null, amount: "", purpose: "" },
        settings: { sounds: true, hideBalance: false },
        numpad: { value: "", action: null },
        lookupTimer: null,
    };

    const $ = (sel) => document.querySelector(sel);

    function nui(event, data = {}) {
        return fetch(`https://${resourceName}/${event}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data),
        })
            .then((r) => r.json())
            .catch(() => ({ ok: false, message: "Ryšio klaida." }));
    }

    function esc(s) {
        return String(s ?? "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
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
        return `**** **** **** ${l}`;
    }

    function parseTxDate(iso) {
        if (!iso) return null;
        const direct = new Date(iso);
        if (!Number.isNaN(direct.getTime())) return direct;
        const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
        if (!m) return null;
        return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
    }

    function formatTxTime(iso) {
        const d = parseTxDate(iso);
        if (!d) return "";
        const now = new Date();
        const same = (a, b) =>
            a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        const yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);
        const time = d.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
        if (same(d, now)) return time;
        if (same(d, yesterday)) return `Vakar ${time}`;
        return d.toLocaleDateString("lt-LT", { month: "short", day: "numeric" }) + ` ${time}`;
    }

    function txIncome(tx) {
        const amt = Number(tx.amount) || 0;
        if (amt !== 0) return amt > 0;
        return ["transfer_in", "deposit", "salary"].includes(tx.tx_type);
    }

    function showToast(msg) {
        const el = $("#atmToast");
        el.textContent = msg;
        el.classList.remove("atm-hidden");
        clearTimeout(showToast._t);
        showToast._t = setTimeout(() => el.classList.add("atm-hidden"), 2400);
    }

    function updateClock() {
        const now = new Date();
        $("#atmClock").textContent = now.toLocaleTimeString("lt-LT", { hour: "2-digit", minute: "2-digit" });
        $("#atmDate").textContent = now.toLocaleDateString("lt-LT", {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
        });
    }

    async function loadState() {
        const res = await nui("bankGetState", {});
        if (res?.ok) {
            state.data = res;
            $("#atmBrand").textContent = res.bankName || "BANKNET";
            $("#atmHolder").textContent = res.holderName || "Klientas";
        }
        return res;
    }

    async function loadHistory(filter) {
        const res = await nui("bankGetHistory", { filter: filter || "all" });
        if (res?.ok) state.history = res.transactions || [];
        return res;
    }

    function renderNav() {
        const nav = $("#atmNav");
        nav.innerHTML = NAV.map(
            (t) =>
                `<button type="button" class="atm-nav-btn${state.tab === t.id ? " active" : ""}" data-tab="${t.id}">
                    <span class="atm-nav-icon">${t.icon}</span>${esc(t.label)}
                </button>`
        ).join("");
        nav.querySelectorAll("[data-tab]").forEach((btn) => {
            btn.addEventListener("click", () => switchTab(btn.dataset.tab));
        });
        $(".atm-help-btn")?.addEventListener("click", () => switchTab("help"));
    }

    function switchTab(tab) {
        state.tab = tab;
        if (tab === "transfer") state.transfer = { query: "", recipient: null, amount: "", purpose: "" };
        renderNav();
        renderContent();
    }

    function renderTxItem(tx) {
        const income = txIncome(tx);
        const amt = Number(tx.amount) || 0;
        const cls = amt > 0 ? "pos" : amt < 0 ? "neg" : income ? "pos" : "neg";
        const icon = TX_ICON[tx.tx_type] || TX_ICON.other;
        return `<div class="atm-tx-item">
            <div class="atm-tx-icon ${income ? "income" : "expense"}">${icon}</div>
            <div>
                <div class="atm-tx-title">${esc(tx.title || "Operacija")}</div>
                <div class="atm-tx-time">${esc(formatTxTime(tx.created_at))}</div>
            </div>
            <div class="atm-tx-amount ${cls}">${fmtMoney(amt, true)}</div>
        </div>`;
    }

    function renderHome() {
        const d = state.data || {};
        const hide = state.settings.hideBalance;
        const bankStr = hide ? "••••••" : fmtMoney(d.bank);
        const cashStr = hide ? "••••••" : fmtMoney(d.cash);
        const recent = (d.transactions || []).slice(0, 6);

        return `<div class="atm-home-grid">
            <div class="atm-home-left">
                <div class="atm-card">
                    <div class="atm-card-chip"></div>
                    <div class="atm-card-balances">
                        <div>
                            <div class="atm-card-label">Banko balansas</div>
                            <div class="atm-card-value" id="bankBalance">${bankStr}</div>
                        </div>
                        <div>
                            <div class="atm-card-label">Grynieji</div>
                            <div class="atm-card-value" id="cashBalance">${cashStr}</div>
                        </div>
                    </div>
                    <div class="atm-card-meta">
                        <div>
                            <div class="atm-card-label">Sąskaitos numeris</div>
                            <div class="atm-account-row">
                                <span>${esc(d.accountNumber || "LT-0000-0000")}</span>
                                <button type="button" class="atm-copy-btn" data-copy="${esc(d.accountNumber || "")}" title="Kopijuoti">⎘</button>
                            </div>
                        </div>
                        <div>
                            <div class="atm-card-label">Kortelės numeris</div>
                            <div class="atm-card-number">${maskCard(d.cardLast4)}</div>
                        </div>
                    </div>
                </div>
                <div class="atm-quick-actions">
                    <button type="button" class="atm-quick-btn" data-goto="transfer"><span class="icon">💸</span>Pervesti</button>
                    <button type="button" class="atm-quick-btn" data-goto="deposit"><span class="icon">🏦</span>Įnešti</button>
                    <button type="button" class="atm-quick-btn" data-goto="withdraw"><span class="icon">💵</span>Išsiimti</button>
                    <button type="button" class="atm-quick-btn" data-goto="history"><span class="icon">📋</span>Istorija</button>
                </div>
            </div>
            <div class="atm-recent">
                <div class="atm-recent-head">
                    <h3>Paskutinės operacijos</h3>
                    <button type="button" class="atm-link-btn" data-goto="history">Visos →</button>
                </div>
                <div class="atm-tx-list">
                    ${recent.length ? recent.map(renderTxItem).join("") : '<div class="atm-empty">Operacijų nėra</div>'}
                </div>
            </div>
        </div>`;
    }

    function renderWithdraw() {
        const d = state.data || {};
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Išėmimas</h2>
            <p class="atm-screen-sub">Pasirinkite sumą arba įveskite kitą</p>
            <div class="atm-cash-banner">Banko balansas: <strong>${fmtMoney(d.bank)}</strong></div>
            <div class="atm-amount-grid">
                ${WITHDRAW_PRESETS.map((a) => `<button type="button" class="atm-amount-btn" data-withdraw="${a}">${a} €</button>`).join("")}
                <button type="button" class="atm-amount-btn wide" data-numpad="withdraw">Kita suma</button>
            </div>
        </div>`;
    }

    function renderDeposit() {
        const d = state.data || {};
        const cash = Number(d.cash) || 0;
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Įnešimas</h2>
            <p class="atm-screen-sub">Perkelkite grynuosius į banko sąskaitą</p>
            <div class="atm-cash-banner">Turite grynais: <strong>${fmtMoney(cash)}</strong></div>
            <div class="atm-amount-grid">
                ${DEPOSIT_PRESETS.map((a) => `<button type="button" class="atm-amount-btn${cash >= a ? "" : ""}" data-deposit="${a}" ${cash < a ? "disabled style='opacity:0.4'" : ""}>${a} €</button>`).join("")}
                <button type="button" class="atm-amount-btn highlight" data-deposit-all="1" ${cash < 1 ? "disabled style='opacity:0.4'" : ""}>Viską</button>
                <button type="button" class="atm-amount-btn wide" data-numpad="deposit">Kita suma</button>
            </div>
        </div>`;
    }

    function renderTransfer() {
        const t = state.transfer;
        const preview = t.recipient
            ? `<div class="atm-recipient-preview">✓ ${esc(t.recipient.name)} · ${esc(t.recipient.accountNumber || t.recipient.citizenid)}</div>`
            : "";
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Pervedimas</h2>
            <p class="atm-screen-sub">Gavėjo ID arba sąskaitos numeris (LT-XXXX-XXXX)</p>
            <div class="atm-form">
                <div class="atm-field">
                    <label>Gavėjas</label>
                    <input type="text" id="transferQuery" placeholder="LTC-5821 arba LT-2048-5821" value="${esc(t.query)}" />
                </div>
                ${preview}
                <div class="atm-field">
                    <label>Suma (€)</label>
                    <input type="number" id="transferAmount" min="1" placeholder="500" value="${esc(t.amount)}" />
                </div>
                <div class="atm-field">
                    <label>Paskirtis (nebūtina)</label>
                    <input type="text" id="transferPurpose" placeholder="Automobilis" value="${esc(t.purpose)}" maxlength="80" />
                </div>
                <button type="button" class="atm-btn primary wide" id="transferSubmit">Pervesti</button>
            </div>
        </div>`;
    }

    function filterHistoryRows() {
        const q = state.historySearch.trim().toLowerCase();
        return (state.history || []).filter((tx) => {
            if (!q) return true;
            const hay = [tx.title, tx.counterparty, tx.purpose, tx.tx_type].join(" ").toLowerCase();
            return hay.includes(q);
        });
    }

    function renderHistory() {
        const rows = filterHistoryRows().slice(0, 20);
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Operacijų istorija</h2>
            <div class="atm-history-toolbar">
                <input type="search" class="atm-search" id="historySearch" placeholder="Ieškoti operacijų..." value="${esc(state.historySearch)}" />
                <div class="atm-filter-chips">
                    ${FILTER_CHIPS.map(
                        (c) =>
                            `<button type="button" class="atm-chip${state.historyFilter === c.id ? " active" : ""}" data-filter="${c.id}">${c.label}</button>`
                    ).join("")}
                </div>
            </div>
            <div class="atm-history-scroll">
                ${rows.length ? rows.map(renderTxItem).join("") : '<div class="atm-empty">Operacijų nerasta</div>'}
            </div>
        </div>`;
    }

    function computeStats() {
        const now = new Date();
        const weekAgo = new Date(now);
        weekAgo.setDate(weekAgo.getDate() - 7);
        let income = 0;
        let expense = 0;
        const expCats = {};
        const incCats = {};

        for (const tx of state.history || []) {
            const d = parseTxDate(tx.created_at);
            if (!d || d < weekAgo) continue;
            const amt = Number(tx.amount) || 0;
            const cat = tx.title || tx.tx_type || "Kita";
            if (amt > 0 || txIncome(tx)) {
                const v = amt > 0 ? amt : Math.abs(amt);
                income += v;
                incCats[cat] = (incCats[cat] || 0) + v;
            } else {
                expense += Math.abs(amt);
                expCats[cat] = (expCats[cat] || 0) + Math.abs(amt);
            }
        }

        const topExp = Object.entries(expCats).sort((a, b) => b[1] - a[1])[0];
        const topInc = Object.entries(incCats).sort((a, b) => b[1] - a[1])[0];

        return {
            income,
            expense,
            topExp: topExp ? topExp[0] : "—",
            topInc: topInc ? topInc[0] : "—",
            expList: Object.entries(expCats).sort((a, b) => b[1] - a[1]).slice(0, 5),
            incList: Object.entries(incCats).sort((a, b) => b[1] - a[1]).slice(0, 5),
        };
    }

    function renderStats() {
        const s = computeStats();
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Statistika</h2>
            <p class="atm-screen-sub">Šios savaitės apžvalga</p>
            <div class="atm-stats-grid">
                <div class="atm-stat-card expense">
                    <div class="atm-stat-label">Šios savaitės išlaidos</div>
                    <div class="atm-stat-value expense">${fmtMoney(s.expense)}</div>
                </div>
                <div class="atm-stat-card income">
                    <div class="atm-stat-label">Šios savaitės pajamos</div>
                    <div class="atm-stat-value income">${fmtMoney(s.income)}</div>
                </div>
            </div>
            <div class="atm-stats-cols">
                <div class="atm-stats-block">
                    <h4>Didžiausios išlaidos</h4>
                    ${s.expList.length ? s.expList.map(([n, v]) => `<div class="atm-stats-row"><span>${esc(n)}</span><span class="neg">${fmtMoney(-v, true)}</span></div>`).join("") : `<div class="atm-empty">Nėra duomenų</div>`}
                    <div class="atm-stats-row"><span><strong>Didžiausia kategorija</strong></span><span>${esc(s.topExp)}</span></div>
                </div>
                <div class="atm-stats-block">
                    <h4>Didžiausios pajamos</h4>
                    ${s.incList.length ? s.incList.map(([n, v]) => `<div class="atm-stats-row"><span>${esc(n)}</span><span class="pos">${fmtMoney(v, true)}</span></div>`).join("") : `<div class="atm-empty">Nėra duomenų</div>`}
                    <div class="atm-stats-row"><span><strong>Didžiausi šaltinis</strong></span><span>${esc(s.topInc)}</span></div>
                </div>
            </div>
        </div>`;
    }

    function renderSettings() {
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Nustatymai</h2>
            <div class="atm-settings-list">
                <div class="atm-setting-row">
                    <span>Slėpti balansą</span>
                    <button type="button" class="atm-toggle${state.settings.hideBalance ? " on" : ""}" id="toggleHideBal"></button>
                </div>
                <div class="atm-setting-row">
                    <span>Garsiniai pranešimai</span>
                    <button type="button" class="atm-toggle${state.settings.sounds ? " on" : ""}" id="toggleSounds"></button>
                </div>
            </div>
        </div>`;
    }

    function renderHelp() {
        return `<div class="atm-screen">
            <h2 class="atm-screen-title">Pagalba</h2>
            <div class="atm-help-card">
                <p><strong>BANKNET</strong> — saugus banko terminalas, susietas su telefono banko programėle.</p>
                <p>Pervedimams naudokite gavėjo <strong>citizen ID</strong> arba sąskaitą <strong>LT-XXXX-XXXX</strong>.</p>
                <p>Klausimams: <strong>1999</strong> · el. paštas: <strong>pagalba@banknet.lt</strong></p>
                <p>Uždaryti terminalą: <strong>Escape</strong> arba paspauskite už lango.</p>
            </div>
        </div>`;
    }

    function bindHomeEvents(host) {
        host.querySelectorAll("[data-goto]").forEach((btn) => {
            btn.addEventListener("click", () => switchTab(btn.dataset.goto));
        });
        host.querySelectorAll("[data-copy]").forEach((btn) => {
            btn.addEventListener("click", () => {
                const val = btn.dataset.copy;
                if (!val) return;
                nui("copyText", { text: val });
                showToast("Sąskaitos numeris nukopijuotas");
            });
        });
    }

    function bindWithdrawEvents(host) {
        host.querySelectorAll("[data-withdraw]").forEach((btn) => {
            btn.addEventListener("click", () => confirmWithdraw(Number(btn.dataset.withdraw)));
        });
        host.querySelector('[data-numpad="withdraw"]')?.addEventListener("click", () => openNumpad("withdraw"));
    }

    function bindDepositEvents(host) {
        host.querySelectorAll("[data-deposit]").forEach((btn) => {
            btn.addEventListener("click", () => confirmDeposit(Number(btn.dataset.deposit)));
        });
        host.querySelector("[data-deposit-all]")?.addEventListener("click", () => {
            const cash = Number(state.data?.cash) || 0;
            if (cash > 0) confirmDeposit(cash);
        });
        host.querySelector('[data-numpad="deposit"]')?.addEventListener("click", () => openNumpad("deposit"));
    }

    function bindTransferEvents(host) {
        const qInput = host.querySelector("#transferQuery");
        const scheduleLookup = () => {
            clearTimeout(state.lookupTimer);
            state.transfer.query = qInput.value;
            state.lookupTimer = setTimeout(async () => {
                const q = qInput.value.trim();
                if (q.length < 3) {
                    state.transfer.recipient = null;
                    renderContent();
                    return;
                }
                const res = await nui("bankLookupRecipient", { query: q });
                if (res?.ok && res.recipient) {
                    state.transfer.recipient = res.recipient;
                    renderContent();
                } else {
                    state.transfer.recipient = null;
                }
            }, 400);
        };
        qInput?.addEventListener("input", scheduleLookup);
        host.querySelector("#transferAmount")?.addEventListener("input", (e) => {
            state.transfer.amount = e.target.value;
        });
        host.querySelector("#transferPurpose")?.addEventListener("input", (e) => {
            state.transfer.purpose = e.target.value;
        });
        host.querySelector("#transferSubmit")?.addEventListener("click", submitTransfer);
    }

    function bindHistoryEvents(host) {
        host.querySelector("#historySearch")?.addEventListener("input", (e) => {
            state.historySearch = e.target.value;
            renderContent();
        });
        host.querySelectorAll("[data-filter]").forEach((btn) => {
            btn.addEventListener("click", async () => {
                state.historyFilter = btn.dataset.filter;
                await loadHistory(state.historyFilter);
                renderContent();
            });
        });
    }

    function bindSettingsEvents(host) {
        host.querySelector("#toggleHideBal")?.addEventListener("click", () => {
            state.settings.hideBalance = !state.settings.hideBalance;
            renderContent();
        });
        host.querySelector("#toggleSounds")?.addEventListener("click", () => {
            state.settings.sounds = !state.settings.sounds;
            renderContent();
        });
    }

    function renderContent() {
        const host = $("#atmContent");
        host.classList.remove("atm-fade");
        void host.offsetWidth;
        host.classList.add("atm-fade");

        let html = "";
        switch (state.tab) {
            case "home":
                html = renderHome();
                break;
            case "withdraw":
                html = renderWithdraw();
                break;
            case "deposit":
                html = renderDeposit();
                break;
            case "transfer":
                html = renderTransfer();
                break;
            case "history":
                html = renderHistory();
                break;
            case "stats":
                html = renderStats();
                break;
            case "settings":
                html = renderSettings();
                break;
            case "help":
                html = renderHelp();
                break;
            default:
                html = renderHome();
        }
        host.innerHTML = html;

        if (state.tab === "home") bindHomeEvents(host);
        if (state.tab === "withdraw") bindWithdrawEvents(host);
        if (state.tab === "deposit") bindDepositEvents(host);
        if (state.tab === "transfer") bindTransferEvents(host);
        if (state.tab === "history") bindHistoryEvents(host);
        if (state.tab === "settings") bindSettingsEvents(host);
    }

    function openNumpad(action) {
        state.numpad = { value: "", action };
        $("#numpadLabel").textContent = action === "withdraw" ? "Išėmimo suma" : "Įnešimo suma";
        $("#numpadDisplay").textContent = "0 €";
        buildNumpad();
        $("#numpadOverlay").classList.remove("atm-hidden");
    }

    function closeNumpad() {
        $("#numpadOverlay").classList.add("atm-hidden");
        state.numpad = { value: "", action: null };
    }

    function buildNumpad() {
        const keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "⌫"];
        const grid = $("#numpadGrid");
        grid.innerHTML = keys
            .map((k) => `<button type="button" class="atm-numpad-key" data-key="${k}">${k}</button>`)
            .join("");
        grid.querySelectorAll("[data-key]").forEach((btn) => {
            btn.addEventListener("click", () => numpadKey(btn.dataset.key));
        });
    }

    function numpadKey(key) {
        let v = state.numpad.value || "";
        if (key === "C") v = "";
        else if (key === "⌫") v = v.slice(0, -1);
        else if (v.length < 8) v += key;
        state.numpad.value = v;
        const num = Number(v) || 0;
        $("#numpadDisplay").textContent = `${num.toLocaleString("lt-LT")} €`;
    }

    function showConfirm(title, text, onOk) {
        $("#confirmTitle").textContent = title;
        $("#confirmText").textContent = text;
        $("#confirmOverlay").classList.remove("atm-hidden");
        const ok = () => {
            cleanup();
            onOk();
        };
        const cancel = () => cleanup();
        const cleanup = () => {
            $("#confirmOverlay").classList.add("atm-hidden");
            $("#confirmOk").removeEventListener("click", ok);
            $("#confirmCancel").removeEventListener("click", cancel);
        };
        $("#confirmOk").addEventListener("click", ok);
        $("#confirmCancel").addEventListener("click", cancel);
    }

    function showSuccess(title, text, thenTab) {
        $("#successTitle").textContent = title;
        $("#successText").textContent = text;
        $("#successOverlay").classList.remove("atm-hidden");
        const done = async () => {
            $("#successOverlay").classList.add("atm-hidden");
            $("#successOk").removeEventListener("click", done);
            await refreshBalances(true);
            if (thenTab) switchTab(thenTab);
        };
        $("#successOk").addEventListener("click", done);
    }

    function confirmWithdraw(amount) {
        amount = Math.floor(Number(amount) || 0);
        if (amount < 1) return showToast("Įveskite sumą.");
        showConfirm("Patvirtinimas", `Ar tikrai norite išsiimti ${fmtMoney(amount)}?`, () => doWithdraw(amount));
    }

    function confirmDeposit(amount) {
        amount = Math.floor(Number(amount) || 0);
        if (amount < 1) return showToast("Įveskite sumą.");
        showConfirm("Patvirtinimas", `Ar tikrai norite įnešti ${fmtMoney(amount)}?`, () => doDeposit(amount));
    }

    async function doWithdraw(amount) {
        const res = await nui("bankWithdraw", { amount });
        if (!res?.ok) return showToast(res?.message || "Nepavyko.");
        showSuccess("Sėkmingai!", `Sėkmingai išimta ${fmtMoney(amount)}`, "home");
    }

    async function doDeposit(amount) {
        const res = await nui("bankDeposit", { amount });
        if (!res?.ok) return showToast(res?.message || "Nepavyko.");
        showSuccess("Sėkmingai!", `Sėkmingai įnešta ${fmtMoney(amount)}`, "home");
    }

    async function submitTransfer() {
        const q = ($("#transferQuery")?.value || state.transfer.query || "").trim();
        const amount = Math.floor(Number($("#transferAmount")?.value || state.transfer.amount) || 0);
        const purpose = ($("#transferPurpose")?.value || state.transfer.purpose || "").trim();
        if (!q) return showToast("Įveskite gavėją.");
        if (amount < 1) return showToast("Įveskite sumą.");

        showConfirm("Patvirtinimas", `Pervesti ${fmtMoney(amount)} gavėjui?`, async () => {
            const res = await nui("bankTransfer", { recipient: q, amount, purpose });
            if (!res?.ok) return showToast(res?.message || "Nepavyko.");
            showSuccess("Pervedimas atliktas!", `${fmtMoney(amount)} → ${res.recipientName || "gavėjas"}`, "home");
        });
    }

    async function refreshBalances(pulse) {
        await loadState();
        await loadHistory("all");
        if (state.tab === "home" || pulse) {
            renderContent();
            if (pulse) {
                $("#bankBalance")?.classList.add("pulse");
                $("#cashBalance")?.classList.add("pulse");
                setTimeout(() => {
                    $("#bankBalance")?.classList.remove("pulse");
                    $("#cashBalance")?.classList.remove("pulse");
                }, 500);
            }
        }
    }

    async function openTerminal() {
        state.open = true;
        state.tab = "home";
        state.historyFilter = "all";
        state.historySearch = "";
        $("#app").classList.remove("atm-hidden", "atm-closing");
        $("#app").setAttribute("aria-hidden", "false");
        updateClock();
        renderNav();
        await loadState();
        await loadHistory("all");
        renderContent();
    }

    function closeTerminal() {
        if (!state.open) return;
        state.open = false;
        $("#app").classList.add("atm-closing");
        setTimeout(() => {
            $("#app").classList.add("atm-hidden");
            $("#app").classList.remove("atm-closing");
            $("#app").setAttribute("aria-hidden", "true");
        }, 260);
        nui("atmClose", {});
    }

    $("#numpadClose")?.addEventListener("click", closeNumpad);
    $("#numpadConfirm")?.addEventListener("click", () => {
        const amount = Math.floor(Number(state.numpad.value) || 0);
        const action = state.numpad.action;
        closeNumpad();
        if (action === "withdraw") confirmWithdraw(amount);
        else if (action === "deposit") confirmDeposit(amount);
    });

    $(".atm-backdrop")?.addEventListener("mousedown", closeTerminal);

    document.addEventListener("keydown", (e) => {
        if (!state.open) return;
        if (e.key === "Escape") {
            if (!$("#numpadOverlay").classList.contains("atm-hidden")) closeNumpad();
            else if (!$("#confirmOverlay").classList.contains("atm-hidden")) $("#confirmOverlay").classList.add("atm-hidden");
            else if (!$("#successOverlay").classList.contains("atm-hidden")) $("#successOverlay").classList.add("atm-hidden");
            else closeTerminal();
        }
    });

    window.addEventListener("message", (event) => {
        const msg = event.data;
        if (!msg || !msg.action) return;
        if (msg.action === "open") openTerminal();
        if (msg.action === "close") closeTerminal();
    });

    setInterval(() => {
        if (state.open) updateClock();
    }, 10000);
})();

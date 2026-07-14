import { fetchNotifyConfig, NOTIFY_CONFIG } from "./config.js";

const ROOT_ID = "fp-notify-root";
const DEFAULT_DURATION = 5000;

const LIMITS = {
    MAX_VISIBLE: 5,
    MAX_QUEUE: 40,
    DEDUP_MS: 2500,
    RATE_WINDOW_MS: 1000,
    RATE_MAX: 14,
    MAX_TITLE_LEN: 80,
    MAX_BODY_LEN: 220,
    DISMISS_MS: 280,
    REMOVE_MS: 300,
};

const VARIANT_META = {
    success: { title: "Sėkmingai", accent: "#34d399", accentSoft: "rgba(52, 211, 153, 0.18)", icon: "fas fa-check", priority: 2 },
    error: { title: "Klaida", accent: "#f87171", accentSoft: "rgba(248, 113, 113, 0.18)", icon: "fas fa-xmark", priority: 4 },
    warning: { title: "Įspėjimas", accent: "#fbbf24", accentSoft: "rgba(251, 191, 36, 0.18)", icon: "fas fa-triangle-exclamation", priority: 3 },
    primary: { title: "Informacija", accent: "#60a5fa", accentSoft: "rgba(96, 165, 250, 0.18)", icon: "fas fa-circle-info", priority: 1 },
    info: { title: "Informacija", accent: "#60a5fa", accentSoft: "rgba(96, 165, 250, 0.18)", icon: "fas fa-circle-info", priority: 1 },
    police: { title: "Iškvietimas", accent: "#a78bfa", accentSoft: "rgba(167, 139, 250, 0.2)", icon: "fas fa-bullhorn", priority: 3 },
    ambulance: { title: "Medikai", accent: "#f472b6", accentSoft: "rgba(244, 114, 182, 0.18)", icon: "fas fa-truck-medical", priority: 3 },
};

const LEGACY_ICON_MAP = {
    check_circle: "fas fa-check",
    notifications: "fas fa-circle-info",
    warning: "fas fa-triangle-exclamation",
    error: "fas fa-xmark",
    local_police: "fas fa-shield-halved",
};

let debugEnabled = false;
let nextId = 1;

const state = {
    visible: new Map(),
    queue: [],
    dedup: new Map(),
    rateHits: [],
    stats: { shown: 0, queued: 0, dropped: 0, merged: 0, dismissed: 0 },
    removeTimers: new Map(),
    debugEl: null,
};

function normalizeType(type) {
    const t = String(type || "primary").toLowerCase();
    if (t === "inform" || t === "information") return "info";
    if (t === "check") return "success";
    return VARIANT_META[t] ? t : "primary";
}

function normalizeIcon(icon) {
    if (!icon || typeof icon !== "string") return null;
    if (icon.includes("fa-")) return icon;
    return LEGACY_ICON_MAP[icon] || null;
}

function clampText(str, max) {
    const s = String(str ?? "").trim();
    if (s.length <= max) return s;
    return s.slice(0, max - 1) + "…";
}

function resolvePosition() {
    const p = NOTIFY_CONFIG?.NotificationStyling?.position;
    const allowed = new Set(["top-right", "top-left", "bottom-right", "bottom-left", "top", "bottom"]);
    return p && allowed.has(p) ? p : "top-right";
}

function parsePayload(data) {
    const type = normalizeType(data?.type);
    const meta = VARIANT_META[type] || VARIANT_META.primary;

    let title = meta.title;
    let body = "";

    if (data?.text && typeof data.text === "object") {
        title = String(data.text.text || data.text.title || meta.title);
        body = String(data.text.caption || data.text.message || data.text.description || "");
    } else {
        const raw = String(data?.text ?? "");
        const nl = raw.indexOf("\n");
        if (nl > 0) {
            title = raw.slice(0, nl).trim();
            body = raw.slice(nl + 1).trim();
        } else {
            body = raw.trim();
        }
    }

    if (data?.caption) body = String(data.caption).trim();
    title = clampText(title.trim() || meta.title, LIMITS.MAX_TITLE_LEN);
    body = clampText(body, LIMITS.MAX_BODY_LEN);

    const customIcon = normalizeIcon(data?.icon);
    const configIcon = normalizeIcon(NOTIFY_CONFIG?.VariantDefinitions?.[type]?.icon);

    return {
        type,
        title,
        body,
        duration: Math.max(1500, Math.min(15000, Number(data?.length) || DEFAULT_DURATION)),
        icon: customIcon || configIcon || meta.icon,
        meta,
        showProgress: NOTIFY_CONFIG?.NotificationStyling?.progress !== false,
        priority: meta.priority || 1,
        count: 1,
    };
}

function dedupKey(payload) {
    return `${payload.type}|${payload.title}|${payload.body}`;
}

function getRoot() {
    let root = document.getElementById(ROOT_ID);
    if (!root) {
        root = document.createElement("div");
        root.id = ROOT_ID;
        root.className = "fp-notify-root fp-notify-root--top-right";
        root.setAttribute("aria-live", "polite");
        document.body.appendChild(root);
    }
    return root;
}

function applyRootPosition(root) {
    root.className = `fp-notify-root fp-notify-root--${resolvePosition()}`;
}

function rateAllowed(payload) {
    const now = Date.now();
    state.rateHits = state.rateHits.filter((t) => now - t < LIMITS.RATE_WINDOW_MS);
    if (state.rateHits.length >= LIMITS.RATE_MAX) {
        if (payload.priority >= 3) {
            state.rateHits.push(now);
            return true;
        }
        state.stats.dropped++;
        return false;
    }
    state.rateHits.push(now);
    return true;
}

function findVisibleByKey(key) {
    for (const item of state.visible.values()) {
        if (item.dedupKey === key) return item;
    }
    return null;
}

function findQueuedByKey(key) {
    return state.queue.find((q) => q.dedupKey === key) || null;
}

function updateCountBadge(item) {
    let badge = item.el.querySelector(".fp-toast__count");
    if (item.payload.count <= 1) {
        if (badge) badge.remove();
        return;
    }
    if (!badge) {
        badge = document.createElement("span");
        badge.className = "fp-toast__count";
        item.el.querySelector(".fp-toast__content")?.appendChild(badge);
    }
    badge.textContent = `×${item.payload.count}`;
}

function restartProgress(item) {
    const progress = item.el.querySelector(".fp-toast__progress");
    if (!progress) return;
    const bar = progress.querySelector(".fp-toast__progress-bar");
    if (!bar) return;
    bar.style.animation = "none";
    void bar.offsetWidth;
    bar.style.animation = "";
    item.el.style.setProperty("--fp-duration", `${item.payload.duration}ms`);
}

function refreshTimer(item) {
    if (item.timer) clearTimeout(item.timer);
    restartProgress(item);
    item.timer = setTimeout(() => dismissToast(item.id), item.payload.duration);
}

function mergePayload(existing, incoming) {
    existing.count += 1;
    existing.duration = Math.max(existing.duration, incoming.duration);
    return existing;
}

function enqueue(data) {
    const payload = parsePayload(data);
    if (!payload.body && !payload.title) {
        state.stats.dropped++;
        return null;
    }

    if (!rateAllowed(payload)) return null;

    const key = dedupKey(payload);
    const now = Date.now();
    const dedupEntry = state.dedup.get(key);

    if (dedupEntry && now - dedupEntry.at < LIMITS.DEDUP_MS) {
        const visible = findVisibleByKey(key);
        if (visible) {
            mergePayload(visible.payload, payload);
            updateCountBadge(visible);
            refreshTimer(visible);
            dedupEntry.at = now;
            state.stats.merged++;
            return visible.id;
        }
        const queued = findQueuedByKey(key);
        if (queued) {
            mergePayload(queued.payload, payload);
            dedupEntry.at = now;
            state.stats.merged++;
            return queued.id;
        }
    }

    state.dedup.set(key, { at: now });

    const id = nextId++;
    const item = { id, payload: { ...payload }, dedupKey: key, el: null, timer: null, dismissing: false };

    if (state.visible.size >= LIMITS.MAX_VISIBLE) {
        if (state.queue.length >= LIMITS.MAX_QUEUE) {
            dropLowestFromQueue();
        }
        state.queue.push(item);
        state.stats.queued++;
        return id;
    }

    mountToast(item);
    return id;
}

function dropLowestFromQueue() {
    if (state.queue.length === 0) return;
    let idx = 0;
    let lowest = state.queue[0].payload.priority;
    for (let i = 1; i < state.queue.length; i++) {
        if (state.queue[i].payload.priority < lowest) {
            lowest = state.queue[i].payload.priority;
            idx = i;
        }
    }
    state.queue.splice(idx, 1);
    state.stats.dropped++;
}

function evictOldestVisible() {
    let oldest = null;
    for (const item of state.visible.values()) {
        if (!oldest || item.mountedAt < oldest.mountedAt) oldest = item;
    }
    if (oldest) dismissToast(oldest.id, true);
}

function drainQueue() {
    while (state.visible.size < LIMITS.MAX_VISIBLE && state.queue.length > 0) {
        const item = state.queue.shift();
        mountToast(item);
    }
}

function createToastEl(payload) {
    const { title, body, icon, meta, duration, showProgress, count } = payload;
    const el = document.createElement("article");
    el.className = `fp-toast fp-toast--${payload.type}`;
    el.style.setProperty("--fp-accent", meta.accent);
    el.style.setProperty("--fp-accent-soft", meta.accentSoft);
    el.style.setProperty("--fp-duration", `${duration}ms`);

    const iconWrap = document.createElement("div");
    iconWrap.className = "fp-toast__icon";
    iconWrap.setAttribute("aria-hidden", "true");
    const ico = document.createElement("i");
    ico.className = icon;
    iconWrap.appendChild(ico);

    const content = document.createElement("div");
    content.className = "fp-toast__content";

    const titleEl = document.createElement("h3");
    titleEl.className = "fp-toast__title";
    titleEl.textContent = title;
    content.appendChild(titleEl);

    if (body) {
        const bodyEl = document.createElement("p");
        bodyEl.className = "fp-toast__body";
        bodyEl.textContent = body;
        content.appendChild(bodyEl);
    }

    if (count > 1) {
        const badge = document.createElement("span");
        badge.className = "fp-toast__count";
        badge.textContent = `×${count}`;
        content.appendChild(badge);
    }

    const closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = "fp-toast__close";
    closeBtn.setAttribute("aria-label", "Uždaryti");
    closeBtn.innerHTML = '<i class="fas fa-xmark" aria-hidden="true"></i>';

    el.appendChild(iconWrap);
    el.appendChild(content);
    el.appendChild(closeBtn);

    if (showProgress) {
        const progress = document.createElement("div");
        progress.className = "fp-toast__progress";
        const bar = document.createElement("div");
        bar.className = "fp-toast__progress-bar";
        progress.appendChild(bar);
        el.appendChild(progress);
    }

    return el;
}

function mountToast(item) {
    const root = getRoot();
    applyRootPosition(root);

    if (state.visible.size >= LIMITS.MAX_VISIBLE) {
        evictOldestVisible();
    }

    const el = createToastEl(item.payload);
    item.el = el;
    item.mountedAt = Date.now();
    item.dismissing = false;

    const closeBtn = el.querySelector(".fp-toast__close");
    if (closeBtn) {
        closeBtn.addEventListener("click", (e) => {
            e.stopPropagation();
            dismissToast(item.id);
        }, { once: true });
    }

    root.appendChild(el);
    requestAnimationFrame(() => el.classList.add("fp-toast--in"));

    state.visible.set(item.id, item);
    state.stats.shown++;

    refreshTimer(item);
    updateDebugPanel();
}

function dismissToast(id, immediate) {
    const item = state.visible.get(id);
    if (!item || item.dismissing) return;
    item.dismissing = true;

    if (item.timer) {
        clearTimeout(item.timer);
        item.timer = null;
    }

    const existingRemove = state.removeTimers.get(id);
    if (existingRemove) clearTimeout(existingRemove);

    item.el.classList.remove("fp-toast--in");
    item.el.classList.add("fp-toast--out");

    const removeDelay = immediate ? 0 : LIMITS.REMOVE_MS;
    const removeTimer = setTimeout(() => {
        state.removeTimers.delete(id);
        if (item.el?.parentNode) item.el.remove();
        state.visible.delete(id);
        state.stats.dismissed++;
        drainQueue();
        updateDebugPanel();
    }, removeDelay);

    state.removeTimers.set(id, removeTimer);
}

function clearAllToasts() {
    for (const id of [...state.visible.keys()]) dismissToast(id, true);
    state.queue.length = 0;
    state.dedup.clear();
    state.rateHits.length = 0;
    updateDebugPanel();
}

function updateDebugPanel() {
    if (!debugEnabled) {
        if (state.debugEl) state.debugEl.remove();
        state.debugEl = null;
        return;
    }
    if (!state.debugEl) {
        state.debugEl = document.createElement("div");
        state.debugEl.className = "fp-notify-debug";
        document.body.appendChild(state.debugEl);
    }
    const timers = [...state.visible.values()].filter((v) => v.timer).length;
    state.debugEl.textContent =
        `Notify | matoma: ${state.visible.size}/${LIMITS.MAX_VISIBLE} | eilė: ${state.queue.length}/${LIMITS.MAX_QUEUE} ` +
        `| atmesta: ${state.stats.dropped} | sujungta: ${state.stats.merged} | timer: ${timers}`;
}

function onMessage(event) {
    const data = event.data;
    if (!data) return;

    if (data.action === "notify") {
        enqueue(data);
        return;
    }
    if (data.action === "notifyClear") {
        clearAllToasts();
        return;
    }
    if (data.action === "notifyDebug") {
        debugEnabled = !!data.enabled;
        updateDebugPanel();
    }
}

async function init() {
    await fetchNotifyConfig();
    const root = getRoot();
    applyRootPosition(root);
    window.addEventListener("message", onMessage);

    window.addEventListener("beforeunload", () => {
        for (const id of [...state.visible.keys()]) {
            const item = state.visible.get(id);
            if (item?.timer) clearTimeout(item.timer);
        }
        for (const t of state.removeTimers.values()) clearTimeout(t);
    });
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
} else {
    init();
}

export { enqueue as showToast, clearAllToasts };

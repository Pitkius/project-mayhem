import { fetchNotifyConfig, NOTIFY_CONFIG } from "./config.js";

const ROOT_ID = "fp-notify-root";
const MAX_VISIBLE = 6;
const DEFAULT_DURATION = 5000;

const VARIANT_META = {
    success: {
        title: "Sėkmingai",
        accent: "#34d399",
        accentSoft: "rgba(52, 211, 153, 0.18)",
        icon: "fas fa-check",
    },
    error: {
        title: "Klaida",
        accent: "#f87171",
        accentSoft: "rgba(248, 113, 113, 0.18)",
        icon: "fas fa-xmark",
    },
    warning: {
        title: "Įspėjimas",
        accent: "#fbbf24",
        accentSoft: "rgba(251, 191, 36, 0.18)",
        icon: "fas fa-triangle-exclamation",
    },
    primary: {
        title: "Informacija",
        accent: "#60a5fa",
        accentSoft: "rgba(96, 165, 250, 0.18)",
        icon: "fas fa-circle-info",
    },
    info: {
        title: "Informacija",
        accent: "#60a5fa",
        accentSoft: "rgba(96, 165, 250, 0.18)",
        icon: "fas fa-circle-info",
    },
    police: {
        title: "Iškvietimas",
        accent: "#a78bfa",
        accentSoft: "rgba(167, 139, 250, 0.2)",
        icon: "fas fa-bullhorn",
    },
    ambulance: {
        title: "Medikai",
        accent: "#f472b6",
        accentSoft: "rgba(244, 114, 182, 0.18)",
        icon: "fas fa-truck-medical",
    },
};

const LEGACY_ICON_MAP = {
    check_circle: "fas fa-check",
    notifications: "fas fa-circle-info",
    warning: "fas fa-triangle-exclamation",
    error: "fas fa-xmark",
    local_police: "fas fa-shield-halved",
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

function resolvePosition() {
    const p = NOTIFY_CONFIG?.NotificationStyling?.position;
    const allowed = new Set([
        "top-right",
        "top-left",
        "bottom-right",
        "bottom-left",
        "top",
        "bottom",
    ]);
    if (p && allowed.has(p)) return p;
    return "top-right";
}

function parsePayload(data) {
    const type = normalizeType(data.type);
    const meta = VARIANT_META[type] || VARIANT_META.primary;

    let title = meta.title;
    let body = "";

    if (data.text && typeof data.text === "object") {
        title = String(data.text.text || data.text.title || meta.title);
        body = String(data.text.caption || data.text.message || data.text.description || "");
    } else {
        const raw = String(data.text ?? "");
        const nl = raw.indexOf("\n");
        if (nl > 0) {
            title = raw.slice(0, nl).trim();
            body = raw.slice(nl + 1).trim();
        } else {
            body = raw.trim();
        }
    }

    if (data.caption) {
        body = String(data.caption).trim();
    }

    title = title.trim() || meta.title;

    const customIcon = normalizeIcon(data.icon);
    const configIcon = normalizeIcon(
        NOTIFY_CONFIG?.VariantDefinitions?.[type]?.icon
    );

    return {
        type,
        title,
        body,
        duration: Math.max(1500, Number(data.length) || DEFAULT_DURATION),
        icon: customIcon || configIcon || meta.icon,
        meta,
        showProgress: NOTIFY_CONFIG?.NotificationStyling?.progress !== false,
    };
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

const stack = [];

function dismissToast(id) {
    const idx = stack.findIndex((x) => x.id === id);
    if (idx === -1) return;
    const item = stack[idx];
    if (item.timer) clearTimeout(item.timer);

    item.el.classList.remove("fp-toast--in");
    item.el.classList.add("fp-toast--out");

    setTimeout(() => {
        item.el.remove();
        const i = stack.findIndex((x) => x.id === id);
        if (i !== -1) stack.splice(i, 1);
    }, 320);
}

function trimStack() {
    while (stack.length > MAX_VISIBLE) {
        dismissToast(stack[0].id);
    }
}

function createToastEl(payload) {
    const { title, body, icon, meta, duration, showProgress } = payload;
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

function showToast(data) {
    const payload = parsePayload(data);
    const root = getRoot();
    applyRootPosition(root);

    const id = `fp-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const el = createToastEl(payload);

    const closeBtn = el.querySelector(".fp-toast__close");
    if (closeBtn) {
        closeBtn.addEventListener("click", (e) => {
            e.stopPropagation();
            dismissToast(id);
        });
    }

    root.appendChild(el);
    requestAnimationFrame(() => el.classList.add("fp-toast--in"));

    const item = { id, el, timer: null };
    stack.push(item);
    trimStack();

    item.timer = setTimeout(() => dismissToast(id), payload.duration);
    return id;
}

function onMessage(event) {
    const data = event.data;
    if (!data || data.action !== "notify") return;
    showToast(data);
}

async function init() {
    await fetchNotifyConfig();
    const root = getRoot();
    applyRootPosition(root);
    window.addEventListener("message", onMessage);
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
} else {
    init();
}

export { showToast };

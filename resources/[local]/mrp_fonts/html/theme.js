(function (global) {
    "use strict";

    var DEFAULT_THEME = {
        primary: "#a78bfa",
        primaryHover: "#c4b5fd",
        primaryActive: "#7c3aed",
        primarySoft: "rgba(167, 139, 250, 0.18)",
        primaryBorder: "rgba(192, 132, 252, 0.35)",
        primaryGlow: "rgba(167, 139, 250, 0.52)",
        primaryText: "#ffffff",
        background: "rgba(4, 2, 10, 0.42)",
        surface: "rgba(18, 10, 32, 0.72)",
        surfaceActive: "rgba(88, 28, 135, 0.82)",
        text: "#f8f4ff",
        mutedText: "#c4b5fd",
    };

    var VAR_MAP = {
        primary: "--primary",
        primaryHover: "--primary-hover",
        primaryActive: "--primary-active",
        primarySoft: "--primary-soft",
        primaryBorder: "--primary-border",
        primaryGlow: "--primary-glow",
        primaryText: "--primary-text",
        background: "--background",
        surface: "--surface",
        surfaceActive: "--surface-active",
        text: "--text",
        mutedText: "--muted-text",
    };

    function hexToRgb(hex) {
        var h = String(hex || "").replace("#", "");
        if (h.length === 3) {
            h = h.split("").map(function (c) { return c + c; }).join("");
        }
        if (h.length !== 6) return null;
        var n = parseInt(h, 16);
        if (isNaN(n)) return null;
        return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
    }

    function withAlpha(color, alpha) {
        var rgb = hexToRgb(color);
        if (!rgb) return color;
        return "rgba(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ", " + alpha + ")";
    }

    function applyPlayerTheme(theme) {
        var t = Object.assign({}, DEFAULT_THEME, theme || {});
        var root = document.documentElement;
        var accent = t.primaryActive || t.primary;

        Object.keys(VAR_MAP).forEach(function (key) {
            if (t[key]) root.style.setProperty(VAR_MAP[key], t[key]);
        });

        root.style.setProperty("--accent-fill", t.primary);
        root.style.setProperty("--accent-soft", t.mutedText || t.primaryHover);
        root.style.setProperty("--accent-glow", t.primaryGlow);
        root.style.setProperty("--accent-highlight", t.primaryActive);
        root.style.setProperty("--ws-violet", accent);
        root.style.setProperty("--ws-violet-soft", withAlpha(accent, 0.28));
        root.style.setProperty("--ws-violet-border", t.primaryBorder || withAlpha(t.primaryHover || accent, 0.42));
        root.style.setProperty("--ws-panel-bg", withAlpha(accent, 0.38));
        root.style.setProperty("--ws-panel-bg-strong", withAlpha(accent, 0.48));
    }

    global.applyPlayerTheme = applyPlayerTheme;

    window.addEventListener("message", function (event) {
        var data = event.data;
        if (!data) return;
        if (data.action === "applyTheme" && data.theme) {
            applyPlayerTheme(data.theme);
        }
    });
})(typeof window !== "undefined" ? window : globalThis);

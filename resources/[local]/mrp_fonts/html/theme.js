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

    function applyPlayerTheme(theme) {
        var t = Object.assign({}, DEFAULT_THEME, theme || {});
        var root = document.documentElement;

        Object.keys(VAR_MAP).forEach(function (key) {
            if (t[key]) root.style.setProperty(VAR_MAP[key], t[key]);
        });

        root.style.setProperty("--accent-fill", t.primary);
        root.style.setProperty("--accent-soft", t.mutedText || t.primaryHover);
        root.style.setProperty("--accent-glow", t.primaryGlow);
        root.style.setProperty("--accent-highlight", t.primaryActive);
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

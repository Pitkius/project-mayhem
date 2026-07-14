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
        background: "rgba(124, 58, 237, 0.14)",
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
        if (!color) return null;
        if (String(color).indexOf("rgba(") === 0) return color;
        var rgb = hexToRgb(color);
        if (!rgb) return color;
        return "rgba(" + rgb.r + ", " + rgb.g + ", " + rgb.b + ", " + alpha + ")";
    }

    function mixHex(a, b, t) {
        var ar = hexToRgb(a);
        var br = hexToRgb(b);
        if (!ar || !br) return a || b;
        return "#" + [ar.r + (br.r - ar.r) * t, ar.g + (br.g - ar.g) * t, ar.b + (br.b - ar.b) * t]
            .map(function (c) {
                var n = Math.round(c);
                var h = n.toString(16);
                return h.length === 1 ? "0" + h : h;
            })
            .join("");
    }

    function darken(hex, t) {
        return mixHex(hex, "#000000", t);
    }

    function buildAccentGrad(active, primary, hover) {
        return "linear-gradient(135deg, " + active + ", " + primary + ")";
    }

    function buildBtnGrad(active, primary, hover) {
        return "linear-gradient(145deg, " + hover + ", " + primary + ")";
    }

    function buildCardGrad(active, primary, hover) {
        return "linear-gradient(135deg, " + darken(active, 0.35) + " 0%, " + active + " 45%, " + hover + " 100%)";
    }

    function surfaceTint(hex, alpha) {
        var rgb = hexToRgb(hex);
        if (!rgb) return DEFAULT_THEME.surface;
        return "rgba(" +
            Math.round(rgb.r * 0.07 + 8) + ", " +
            Math.round(rgb.g * 0.05 + 6) + ", " +
            Math.round(rgb.b * 0.12 + 10) + ", " +
            alpha + ")";
    }

    function applyResourceAliases(t) {
        var root = document.documentElement;
        var primary = t.primary;
        var hover = t.primaryHover || primary;
        var active = t.primaryActive || primary;
        var soft = t.primarySoft;
        var border = t.primaryBorder;
        var glow = t.primaryGlow;
        var muted = t.mutedText || hover;
        var surface = t.surface || surfaceTint(primary, 0.72);
        var accentGrad = buildAccentGrad(active, primary, hover);
        var btnGrad = buildBtnGrad(active, primary, hover);
        var cardGrad = buildCardGrad(active, primary, hover);

        var aliases = {
            "--accent-fill": primary,
            "--accent-soft": muted,
            "--accent-glow": glow,
            "--accent-highlight": active,
            "--accent-grad": accentGrad,
            "--btn-grad": btnGrad,
            "--card-grad": cardGrad,
            "--fp-accent": primary,
            "--fp-accent-soft": hover,
            "--fp-accent-dim": soft,
            "--fp-accent-glow": glow,
            "--fp-accent-deep": active,
            "--fp-primary": primary,
            "--fp-primary-soft": hover,
            "--fp-primary-deep": active,
            "--fp-primary-glow": glow,
            "--fp-primary-dim": soft,
            "--neon-purple": hover,
            "--neon-purple-soft": border,
            "--neon-purple-glow": glow,
            "--neon-purple-dim": active,
            "--bm-accent": primary,
            "--bm-accent-deep": active,
            "--sc-purple": primary,
            "--sc-purple-soft": hover,
            "--sc-purple-deep": active,
            "--sc-purple-glow": glow,
            "--purple-dim": active,
            "--mg-accent": primary,
            "--mg-accent-2": active,
            "--mg-glow": glow,
            "--mg-level": hover,
            "--vehicle-accent": active,
            "--glass-bg": surface,
            "--glass-border": border,
            "--glass-hover": soft,
            "--app-bg": surfaceTint(primary, 0.96),
            "--phone-scroll-thumb": "linear-gradient(180deg, " + withAlpha(hover, 0.95) + " 0%, " + withAlpha(active, 0.85) + " 100%)",
            "--cc-violet": primary,
            "--cc-violet-lit": hover,
            "--cc-violet-dim": soft,
            "--cc-border": border,
            "--cc-glass": surface,
            "--cc-glass-strong": withAlpha(active, 0.62),
            "--ho-violet-bright": hover,
            "--drug-accent": primary,
            "--ws-violet": active,
            "--ws-violet-soft": withAlpha(active, 0.28),
            "--ws-violet-border": border,
            "--ws-panel-bg": withAlpha(active, 0.38),
            "--ws-panel-bg-strong": withAlpha(active, 0.48),
            "--car-shell-border": border,
            "--car-shell-glow": withAlpha(primary, 0.12),
            "--car-fuel-stroke": hover,
            "--car-stat-on-color": hover,
            "--car-stat-on-bg": soft,
            "--car-stat-on-border": border,
            "--car-stat-on-glow": glow,
            "--panel-shadow": "0 24px 80px rgba(0, 0, 0, 0.55), 0 0 60px " + withAlpha(primary, 0.18),
        };

        Object.keys(aliases).forEach(function (key) {
            if (aliases[key]) root.style.setProperty(key, aliases[key]);
        });
    }

    function applyPlayerTheme(theme) {
        var t = Object.assign({}, DEFAULT_THEME, theme || {});
        var root = document.documentElement;

        Object.keys(VAR_MAP).forEach(function (key) {
            if (t[key]) root.style.setProperty(VAR_MAP[key], t[key]);
        });

        applyResourceAliases(t);
    }

    function resetPlayerTheme() {
        applyPlayerTheme(DEFAULT_THEME);
    }

    global.applyPlayerTheme = applyPlayerTheme;
    global.resetPlayerTheme = resetPlayerTheme;

    window.addEventListener("message", function (event) {
        var data = event.data;
        if (!data) return;
        if (data.action === "applyTheme" && data.theme) {
            applyPlayerTheme(data.theme);
        }
        if (data.action === "resetTheme") {
            resetPlayerTheme();
        }
    });
})(typeof window !== "undefined" ? window : globalThis);

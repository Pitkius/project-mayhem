--- Vieninga žaidėjo UI tema — šaltinis: HUD preset spalva (KVP per mrp_hud).
local cachedPlayerTheme = nil

local DEFAULT_PRIMARY = '#a78bfa'

local function clamp(n, a, b)
    return math.max(a, math.min(b, n))
end

local function hexToRgb(hex)
    if type(hex) ~= 'string' then return 167, 139, 250 end
    local r, g, b = hex:match('#(%x%x)(%x%x)(%x%x)')
    if not r then return 167, 139, 250 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function rgbToHex(r, g, b)
    return ('#%02x%02x%02x'):format(clamp(math.floor(r), 0, 255), clamp(math.floor(g), 0, 255), clamp(math.floor(b), 0, 255))
end

local function mixHex(a, b, t)
    local ar, ag, ab = hexToRgb(a)
    local br, bg, bb = hexToRgb(b)
    return rgbToHex(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
end

local function lighten(hex, t)
    return mixHex(hex, '#ffffff', t)
end

local function darken(hex, t)
    return mixHex(hex, '#000000', t)
end

local function hexAlpha(hex, alpha)
    local r, g, b = hexToRgb(hex)
    return ('rgba(%d,%d,%d,%.3f)'):format(r, g, b, alpha)
end

local function relativeLuminance(hex)
    local r, g, b = hexToRgb(hex)
    local function lin(c)
        c = c / 255
        if c <= 0.03928 then return c / 12.92 end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function contrastText(primary)
    return relativeLuminance(primary) > 0.58 and '#0f0720' or '#ffffff'
end

--- @param resolved table resolveHudColors() rezultatas
--- @param colorKey string
function BuildPlayerTheme(resolved, colorKey)
    resolved = resolved or {}
    local primary = resolved.fill or DEFAULT_PRIMARY
    local secondary = resolved.soft or lighten(primary, 0.12)
    local textColor = (resolved.customColors and resolved.customColors.text) or '#f8fafc'

    return {
        primary = primary,
        primaryHover = lighten(primary, 0.14),
        primaryActive = darken(primary, 0.18),
        primarySoft = hexAlpha(primary, 0.18),
        primaryBorder = hexAlpha(primary, 0.38),
        primaryGlow = resolved.glow or hexAlpha(primary, 0.52),
        primaryText = contrastText(primary),
        background = hexAlpha(primary, 0.14),
        surface = 'rgba(18, 10, 32, 0.72)',
        surfaceActive = hexAlpha(primary, 0.82),
        text = textColor,
        mutedText = secondary,
        colorKey = colorKey or 'violet',
    }
end

function SetPlayerTheme(theme)
    cachedPlayerTheme = theme
    TriggerEvent('mrp_hud:client:themeChanged', theme)
end

function GetPlayerTheme()
    return cachedPlayerTheme
end

exports('GetPlayerTheme', GetPlayerTheme)
exports('BuildPlayerTheme', BuildPlayerTheme)

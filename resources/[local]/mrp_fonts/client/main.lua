--- Vietinis Noto Sans LT (stream/NotoSansLT.gfx) — pause žemėlapio blipų legendai ir kitas žaidimo tekstas.
local FONT_FILE = 'NotoSansLT'
local FONT_FACE = 'NotoSansLT'

local fontId = nil
local fontReady = false
local blipSeq = 0

local function ensureFont()
    if fontReady then return true end
    RegisterFontFile(FONT_FILE)
    fontId = RegisterFontId(FONT_FACE)
    fontReady = fontId ~= nil and fontId ~= -1
    return fontReady
end

CreateThread(function()
    Wait(0)
    ensureFont()
end)

--- @param text string
--- @return string
local function formatNativeText(text)
    text = tostring(text or '')
    if text == '' then return text end
    if not fontReady then return text end
    return ('<font face="%s">%s</font>'):format(FONT_FACE, text)
end

--- Unikalus AddTextEntry + blip pavadinimas (vengia STRING lenkimo ir palengvina lietuviškas raides su GFX šriftu).
--- @param blip number
--- @param label string
local function setBlipName(blip, label)
    if not blip or blip == 0 then return end
    if not DoesBlipExist(blip) then return end

    blipSeq = blipSeq + 1
    Wait(0)
    local key = ('FMP_BL_%d'):format(blipSeq)
    AddTextEntry(key, formatNativeText(label))
    BeginTextCommandSetBlipName(key)
    EndTextCommandSetBlipName(blip)
end

--- Taikyti lietuvišką šriftą prieš BeginTextCommandDisplayText / DrawText.
local function applyTextFont()
    if fontReady and fontId then
        SetTextFont(fontId)
    end
end

local function textDisplayLen(s)
    s = tostring(s or '')
    if utf8 and utf8.len then
        return utf8.len(s) or #s
    end
    return #s
end

--- 3D tekstas su lietuviškomis raidėmis (ė, ū, š, …) — naudoti vietoj QBCore SetTextFont(4).
local function drawText3D(x, y, z, text, opts)
    text = tostring(text or '')
    local o = opts or {}
    local scale = o.scale or 0.35
    SetDrawOrigin(x + 0.0, y + 0.0, z + 0.0, 0)
    SetTextScale(scale, scale)
    if ensureFont() then
        SetTextFont(fontId)
    else
        SetTextFont(4)
    end
    SetTextProportional(1)
    SetTextColour(o.r or 255, o.g or 255, o.b or 255, o.a or 215)
    SetTextCentre(o.center ~= false)
    if o.outline ~= false then
        SetTextOutline()
    end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    if o.background ~= false then
        local factor = textDisplayLen(text) / 370
        DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, o.bgAlpha or 75)
    end
    ClearDrawOrigin()
end

exports('SetBlipName', setBlipName)
exports('FormatNativeText', formatNativeText)
exports('ApplyTextFont', applyTextFont)
exports('DrawText3D', drawText3D)
exports('IsNativeFontReady', function()
    return fontReady
end)

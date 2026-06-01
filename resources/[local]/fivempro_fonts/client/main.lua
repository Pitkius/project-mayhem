--- Vietinis Noto Sans LT (stream/NotoSansLT.gfx) — pause žemėlapio blipų legendai ir kitas žaidimo tekstas.
local FONT_FILE = 'NotoSansLT'
local FONT_FACE = 'NotoSansLT'

local fontId = nil
local fontReady = false
local blipSeq = 0

CreateThread(function()
    Wait(0)
    RegisterFontFile(FONT_FILE)
    fontId = RegisterFontId(FONT_FACE)
    fontReady = fontId ~= nil and fontId ~= -1
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

exports('SetBlipName', setBlipName)
exports('FormatNativeText', formatNativeText)
exports('ApplyTextFont', applyTextFont)
exports('IsNativeFontReady', function()
    return fontReady
end)

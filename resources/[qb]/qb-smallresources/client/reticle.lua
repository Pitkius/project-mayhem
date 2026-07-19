--- Tikras GTA 5 taikinukas (simple / complex pagal žaidimo HUD nustatymus).
--- Jokio custom piešimo — tik priverčiame ENEMY/FRIENDLY spalvas likti baltas,
--- kad taikinukas neraudonuotų / nepilkėtų ant žmogaus.

local function applyNativeReticleWhiteTint()
    --- HUD_COLOUR_ENEMY / FRIENDLY — GTA jomis tintina native reticle
    ReplaceHudColourWithRgba(119, 255, 255, 255, 255)
    ReplaceHudColourWithRgba(118, 255, 255, 255, 255)
end

CreateThread(function()
    if Config.AlwaysWhiteReticle == false then return end
    applyNativeReticleWhiteTint()
    while true do
        applyNativeReticleWhiteTint()
        Wait(5000)
    end
end)

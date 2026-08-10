--- Bendras NUI temos tiltas — įtraukite į bet kurį resource su NUI:
--- client_script '@mrp_hud/client/theme_nui_consumer.lua'

local function pushPlayerThemeToNui()
    local ok, theme = pcall(function()
        return exports['mrp_hud']:GetPlayerTheme()
    end)
    if ok and theme then
        SendNUIMessage({ action = 'applyTheme', theme = theme })
    end
end

RegisterNetEvent('mrp_hud:client:themeChanged', function(theme)
    if theme then
        SendNUIMessage({ action = 'applyTheme', theme = theme })
    else
        pushPlayerThemeToNui()
    end
end)

CreateThread(function()
    while GetResourceState('mrp_hud') ~= 'started' do
        Wait(200)
    end
    Wait(800)
    pushPlayerThemeToNui()
end)

--- Kviesti atidarant NUI (kartu su open žinute).
function PushPlayerThemeToNui()
    pushPlayerThemeToNui()
end

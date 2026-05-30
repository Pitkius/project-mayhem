--- Uždaryti loadscreen tik kai spawnfix / QBCore baigia krauti žaidėją
local closed = false

local function closeLoadscreen()
    if closed then return end
    closed = true
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
end

RegisterNetEvent('fivempro_loadscreen:client:close', closeLoadscreen)

-- Atsarginis uždarymas jei spawnfix neužsikrauna
CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while not closed and GetGameTimer() < deadline do
        if LocalPlayer.state.isLoggedIn then
            Wait(3000)
            closeLoadscreen()
            return
        end
        Wait(500)
    end
    if not closed then
        closeLoadscreen()
    end
end)

exports('CloseLoadscreen', closeLoadscreen)

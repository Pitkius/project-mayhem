local debugPed = nil

local function sandboxCfg()
    return Config.DebugSandboxVendor or {}
end

local function spawnDebugVendor()
    local cfg = sandboxCfg()
    if not cfg.enabled then return end
    if debugPed and DoesEntityExist(debugPed) then return end

    local c = cfg.coords or vector4(Config.Base.x, Config.Base.y, Config.Base.z, Config.Base.w)
    local hash = tonumber(cfg.pedModel) or `s_m_y_construct_02`

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    debugPed = CreatePed(0, hash, c.x, c.y, c.z, c.w, false, true)
    SetEntityAsMissionEntity(debugPed, true, true)
    SetBlockingOfNonTemporaryEvents(debugPed, true)
    FreezeEntityPosition(debugPed, true)
    SetEntityInvincible(debugPed, true)
    if cfg.scenario then
        TaskStartScenarioInPlace(debugPed, cfg.scenario, 0, true)
    end

    if GetResourceState('qb-target') ~= 'started' then return end

    exports['qb-target']:AddTargetEntity(debugPed, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mechanic:client:debugOpenSupplyShop',
                icon = 'fas fa-brush',
                label = 'Žaliavų test shop',
            },
            {
                type = 'client',
                event = 'fivempro_mechanic:client:debugOpenPickaxeShop',
                icon = 'fas fa-stream',
                label = 'Kirtiklių test shop',
            },
        },
        distance = 2.85,
    })
end

RegisterNetEvent('fivempro_mechanic:client:debugOpenSupplyShop', function()
    TriggerServerEvent('fivempro_mechanic:server:debugOpenSupplyShop')
end)

RegisterNetEvent('fivempro_mechanic:client:debugOpenPickaxeShop', function()
    TriggerServerEvent('fivempro_mechanic:server:debugOpenPickaxeShop')
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(350)
    end
    Wait(1200)
    spawnDebugVendor()
end)

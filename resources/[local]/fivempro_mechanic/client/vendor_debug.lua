local QBCore = exports['qb-core']:GetCoreObject()

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
                event = 'fivempro_mechanic:client:debugOpenSupplyMenu',
                icon = 'fas fa-brush',
                label = ('Žaliavų TEST rinkinys ($%s)'):format(tonumber(cfg.bundlePrice) or 1),
            },
            {
                type = 'client',
                event = 'fivempro_mechanic:client:debugOpenPickaxeMenu',
                icon = 'fas fa-stream',
                label = 'Kirtiklių parduotuvė (DEBUG)',
            },
        },
        distance = 2.85,
    })
end

RegisterNetEvent('fivempro_mechanic:client:debugOpenSupplyMenu', function()
    TriggerServerEvent('fivempro_mechanic:server:debugBuySupplyBundle')
end)

RegisterNetEvent('fivempro_mechanic:client:debugOpenPickaxeMenu', function()
    local tiers = Config.DebugPickaxeOffers or {}
    if not tiers[1] then
        return QBCore.Functions.Notify('Nėra kirtikių sąrašo.', 'error')
    end
    local menu = {
        {
            header = 'Šachtininko kioskėls (DEBUG)',
            txt = 'Kuo aukštensnis lygis, tuo brangiau. Laikinai testavimui.',
            isMenuHeader = true,
        },
    }

    for i, row in ipairs(tiers) do
        menu[#menu + 1] = {
            header = ('%s — $%s'):format(row.label or row.item, tonumber(row.price) or 0),
            txt = row.item or '',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_mechanic:server:debugBuyPickaxe', i)
                end,
            },
        }
    end

    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(350)
    end
    Wait(1200)
    spawnDebugVendor()
end)

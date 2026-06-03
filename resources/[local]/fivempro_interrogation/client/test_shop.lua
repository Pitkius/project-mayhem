local QBCore = exports['qb-core']:GetCoreObject()

local testShopPed = 0
local testShopBlip = nil

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function openTestShopMenu()
    if not Config.EnableTestShop or not Config.TestShop then return end
    local cfg = Config.TestShop
    local itemLabel = 'Spaudimo įranga'
    local price = tonumber(cfg.price) or 0
    local priceTxt = price > 0 and ('%s € (%s)'):format(price, cfg.payAccount or 'cash') or 'Nemokamai (test)'

    exports['qb-menu']:openMenu({
        { header = 'Gaujų įrangos testas', isMenuHeader = true },
        { header = itemLabel, txt = priceTxt },
        { header = 'Pirkti 1 vnt.', params = { event = 'fivempro_interrogation:client:buyTestKit' } },
        { header = 'Uždaryti', params = { isAction = true, event = function() exports['qb-menu']:closeMenu() end } },
    })
end

RegisterNetEvent('fivempro_interrogation:client:buyTestKit', function()
    TriggerServerEvent('fivempro_interrogation:server:buyTestKit')
end)

local function spawnTestShop()
    if not Config.EnableTestShop or not Config.TestShop then return end
    local cfg = Config.TestShop
    local model = joaat(cfg.model or 'g_m_y_lost_02')
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    if not HasModelLoaded(model) then return end

    local c = cfg.coords
    testShopPed = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(testShopPed, true)
    FreezeEntityPosition(testShopPed, true)
    SetBlockingOfNonTemporaryEvents(testShopPed, true)
    if cfg.scenario then
        TaskStartScenarioInPlace(testShopPed, cfg.scenario, 0, true)
    end

    if cfg.blip and cfg.blip.enabled then
        local bc = cfg.blip.coords or vector3(c.x, c.y, c.z)
        testShopBlip = AddBlipForCoord(bc.x, bc.y, bc.z)
        SetBlipSprite(testShopBlip, cfg.blip.sprite or 478)
        SetBlipColour(testShopBlip, cfg.blip.color or 27)
        SetBlipScale(testShopBlip, cfg.blip.scale or 0.75)
        SetBlipAsShortRange(testShopBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(cfg.blip.label or 'Test: gaujų įranga')
        EndTextCommandSetBlipName(testShopBlip)
    end

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(testShopPed, {
            options = {
                {
                    icon = 'fas fa-toolbox',
                    label = cfg.label or 'Pirkti spaudimo įrangą',
                    action = openTestShopMenu,
                },
            },
            distance = cfg.interactDist or 2.8,
        })
    end
    SetModelAsNoLongerNeeded(model)
end

CreateThread(function()
    Wait(1600)
    spawnTestShop()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if testShopPed ~= 0 and DoesEntityExist(testShopPed) then
        if GetResourceState('qb-target') == 'started' then
            exports['qb-target']:RemoveTargetEntity(testShopPed)
        end
        DeleteEntity(testShopPed)
        testShopPed = 0
    end
    if testShopBlip and DoesBlipExist(testShopBlip) then
        RemoveBlip(testShopBlip)
        testShopBlip = nil
    end
end)

local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}

local function removeZones()
    for name in pairs(zones) do
        pcall(function() exports['qb-target']:RemoveZone(name) end)
    end
    zones = {}
end

local function drillBox(locId, index)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:depositCanDrill', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        local mg = (Config.RobberyMinigames or {}).drill
        local anim = (Config.RobberyAnims or {}).drill
        local ok = true
        if mg then
            ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
                label = 'Deposit dėžutė',
                anim = anim,
                data = mg.data or {},
            })
        end
        if not ok then
            return QBCore.Functions.Notify('Gręžimas atšauktas.', 'error')
        end
        local ms = (Config.Robberies.Timings and Config.Robberies.Timings.deposit) or 14000
        QBCore.Functions.Progressbar('deposit_drill', 'Gręžiama deposit dėžutė…', ms, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@fleeca_bank@drilling',
            anim = 'drill_straight_idle',
            flags = 49,
        }, {}, {}, function()
            TriggerServerEvent('mrp_hacking:server:depositDrilled', locId, index)
        end, function()
            QBCore.Functions.Notify('Atšaukta.', 'error')
        end)
    end, locId, index)
end

local function registerDepositZones()
    removeZones()
    if GetResourceState('qb-target') ~= 'started' then return end
    for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
        for i, box in ipairs(list) do
            local zoneName = ('hack_deposit_%s_%d'):format(locId, i)
            zones[zoneName] = true
            exports['qb-target']:AddCircleZone(zoneName, box.coords, 0.55, {
                name = zoneName,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-box',
                        label = 'Gręžti deposit dėžutę (mažas grąžtas)',
                        canInteract = function()
                            return QBCore.Functions.HasItem(Config.SmallDrillItem or 'small_drill', 1)
                        end,
                        action = function()
                            drillBox(locId, i)
                        end,
                    },
                },
                distance = 1.6,
            })
        end
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1200)
    registerDepositZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeZones()
end)

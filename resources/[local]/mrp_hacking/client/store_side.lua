local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local busy = false

local function removeZones()
    for name in pairs(zones) do
        pcall(function() exports['qb-target']:RemoveZone(name) end)
    end
    zones = {}
end

local function sideCfg()
    return Config.Robberies.StoreSide or {}
end

local function runCashGrab(loc)
    if busy then return end
    QBCore.Functions.TriggerCallback('mrp_hacking:server:storeSideCan', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        busy = true
        local ms = (Config.Robberies.Timings and Config.Robberies.Timings.storeCashGrab) or 4500
        QBCore.Functions.Progressbar('store_cash_grab', 'Imami pinigai iš kasos…', ms, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@ornate_bank@grab_cash',
            anim = 'grab',
            flags = 49,
        }, {}, {}, function()
            busy = false
            TriggerServerEvent('mrp_hacking:server:storeSideLoot', loc.id, 'cash')
        end, function()
            busy = false
            QBCore.Functions.Notify('Atšaukta.', 'error')
        end)
    end, loc.id, 'cash')
end

local function runPerlas(loc)
    if busy then return end
    QBCore.Functions.TriggerCallback('mrp_hacking:server:storeSideCan', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        busy = true
        if not res.silent then
            TriggerServerEvent('mrp_hacking:server:storeSideAlert', loc.id, 'perlas')
        end
        local mg = sideCfg().perlasMinigame or { mode = 'sequence', label = 'Perlas', data = { length = 4 } }
        local ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
            label = mg.label or 'Perlas terminalas',
            anim = (Config.RobberyAnims or {}).crack,
            data = mg.data or {},
        })
        if not ok then
            busy = false
            return QBCore.Functions.Notify('Perlas įsilaužimas nepavyko.', 'error')
        end
        local ms = sideCfg().perlasProgressMs
            or (Config.Robberies.Timings and Config.Robberies.Timings.storePerlas)
            or 9000
        QBCore.Functions.Progressbar('store_perlas', 'Laužiamas Perlas terminalas…', ms, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@ornate_bank@hack',
            anim = 'hack_loop',
            flags = 49,
        }, {}, {}, function()
            busy = false
            TriggerServerEvent('mrp_hacking:server:storeSideLoot', loc.id, 'perlas')
        end, function()
            busy = false
            QBCore.Functions.Notify('Atšaukta.', 'error')
        end)
    end, loc.id, 'perlas')
end

local function runSafe(loc)
    if busy then return end
    QBCore.Functions.TriggerCallback('mrp_hacking:server:storeSideCan', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        if res.needAlert then
            QBCore.Functions.Notify('Be stealth hack seifo gręžimas iškviečia policiją.', 'error', 7000)
            TriggerServerEvent('mrp_hacking:server:storeSideAlert', loc.id, 'safe')
        end
        busy = true
        local mg = sideCfg().safeMinigame or (Config.RobberyMinigames or {}).drill
        local anim = (Config.RobberyAnims or {}).drill
        local ok = true
        if mg then
            ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode or 'drill', {
                label = mg.label or 'Parduotuvės seifas',
                anim = anim,
                data = mg.data or {},
            })
        end
        if not ok then
            busy = false
            return QBCore.Functions.Notify('Seifo gręžimas atšauktas.', 'error')
        end
        local ms = sideCfg().safeDrillMs
            or (Config.Robberies.Timings and Config.Robberies.Timings.storeSafe)
            or 120000
        QBCore.Functions.Progressbar('store_safe_drill', 'Gręžiamas seifas (apie 2 min)…', ms, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@heists@fleeca_bank@drilling',
            anim = 'drill_straight_idle',
            flags = 49,
        }, {
            model = 'prop_tool_drill',
            bone = 57005,
            coords = { x = 0.14, y = 0.0, z = -0.01 },
            rotation = { x = 90.0, y = -90.0, z = 180.0 },
        }, {}, function()
            busy = false
            TriggerServerEvent('mrp_hacking:server:storeSideLoot', loc.id, 'safe')
        end, function()
            busy = false
            QBCore.Functions.Notify('Atšaukta.', 'error')
        end)
    end, loc.id, 'safe')
end

local function registerStoreSideZones()
    removeZones()
    if GetResourceState('qb-target') ~= 'started' then return end
    for _, loc in ipairs((Config.Robberies.Locations and Config.Robberies.Locations.store) or {}) do
        if loc.cashRegister and loc.cashRegister.coords then
            local name = ('hack_store_cash_%s'):format(loc.id)
            zones[name] = true
            exports['qb-target']:AddCircleZone(name, loc.cashRegister.coords, loc.cashRegister.radius or 0.65, {
                name = name,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-cash-register',
                        label = 'Ištuštinti kasą',
                        canInteract = function()
                            return not busy
                        end,
                        action = function()
                            runCashGrab(loc)
                        end,
                    },
                },
                distance = 1.6,
            })
        end

        if loc.perlas and loc.perlas.coords then
            local name = ('hack_store_perlas_%s'):format(loc.id)
            zones[name] = true
            exports['qb-target']:AddCircleZone(name, loc.perlas.coords, loc.perlas.radius or 0.65, {
                name = name,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-ticket-alt',
                        label = 'Išlaužti Perlas terminalą',
                        canInteract = function()
                            return not busy
                        end,
                        action = function()
                            runPerlas(loc)
                        end,
                    },
                },
                distance = 1.6,
            })
        end

        if loc.safe and loc.safe.coords then
            local name = ('hack_store_safe_%s'):format(loc.id)
            zones[name] = true
            local drillItem = sideCfg().safeItem or Config.DrillItem or 'drill'
            exports['qb-target']:AddCircleZone(name, loc.safe.coords, loc.safe.radius or 0.9, {
                name = name,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-vault',
                        label = 'Gręžti seifą (2 min)',
                        canInteract = function()
                            return not busy and QBCore.Functions.HasItem(drillItem, 1)
                        end,
                        action = function()
                            runSafe(loc)
                        end,
                    },
                },
                distance = 1.8,
            })
        end
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1400)
    registerStoreSideZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeZones()
end)

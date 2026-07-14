local QBCore = exports['qb-core']:GetCoreObject()

local insideHouseId = nil
local sleeperPed = nil
local sleeperAwake = false
local drawerZones = {}

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function runMinigame(mode, label, length)
    if GetResourceState('mrp_hacking') == 'started' then
        local ok, result = pcall(function()
            return exports['mrp_hacking']:RunPhysicalMinigame(mode, {
                label = label,
                anim = {
                    dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                    name = 'machinic_loop_mechandplayer',
                    flags = 16,
                },
                data = { length = length },
            })
        end)
        if ok then return result == true end
    end
    return math.random(1, 100) <= 65
end

local function runLockpickAtDoor(house)
    local hasAdv = QBCore.Functions.HasItem(Config.Burglary.advancedLockpickItem)
    local hasBasic = QBCore.Functions.HasItem(Config.Burglary.lockpickItem)
    if not hasAdv and not hasBasic then
        return notify('Reikia visrakčio', 'error')
    end

    local advanced = hasAdv
    local mgCfg = Config.Burglary.lockpickMinigame
    local key = advanced and 'advancedlockpick' or 'lockpick'
    local mg = mgCfg[key] or mgCfg.lockpick

    local ok = runMinigame(mg.mode, mg.label, mg.length)
    if not ok then
        if math.random() < (Config.Burglary.failLockpickAlertChance or 0) then
            TriggerServerEvent('mrp_burglary:server:triggerAlarm', house.id, 'garsus durų laužymas')
        end
        return notify('Nepavyko atrakinti durų', 'error')
    end

    if math.random() < (Config.Burglary.policeAlertChance or 0) then
        TriggerServerEvent('mrp_burglary:server:triggerAlarm', house.id, 'įtartinas triukšmas')
    end

    TriggerServerEvent('mrp_burglary:server:beginSession', house.id, advanced)
end

local function clearInteriorState()
    insideHouseId = nil
    sleeperAwake = false
    if sleeperPed and DoesEntityExist(sleeperPed) then
        DeleteEntity(sleeperPed)
    end
    sleeperPed = nil
    for _, zoneName in ipairs(drawerZones) do
        pcall(function() exports['qb-target']:RemoveZone(zoneName) end)
    end
    drawerZones = {}
end

local function wakeSleeper(houseId)
    if sleeperAwake or not sleeperPed or not DoesEntityExist(sleeperPed) then return end
    sleeperAwake = true
    ClearPedTasks(sleeperPed)
    TaskCombatPed(sleeperPed, PlayerPedId(), 0, 16)
    if math.random() < (Config.Burglary.wakeAlertChance or 0.85) then
        TriggerServerEvent('mrp_burglary:server:triggerAlarm', houseId, 'savininkas pabudo')
    end
    notify('Savininkas pabudo!', 'error')
end

local function spawnSleeper(interior)
    local cfg = Config.Burglary.sleepingNpc or {}
    local pos = interior.sleeper
    if not pos then return end

    local model = joaat(cfg.model or 'a_m_y_bevhills_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    sleeperPed = CreatePed(0, model, pos.x, pos.y, pos.z - 1.0, pos.w, false, false)
    SetEntityInvincible(sleeperPed, false)
    SetBlockingOfNonTemporaryEvents(sleeperPed, true)
    if cfg.scenario then
        TaskStartScenarioInPlace(sleeperPed, cfg.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(model)
end

local function setupDrawerTargets(house)
    local interior = house.interior
    if not interior or not interior.drawers then return end

    for idx, coords in ipairs(interior.drawers) do
        local zoneName = ('mrp_burglary_drawer_%s_%d'):format(house.id, idx)
        drawerZones[#drawerZones + 1] = zoneName

        exports['qb-target']:AddBoxZone(zoneName, coords, 0.8, 0.8, {
            name = zoneName,
            heading = 0.0,
            debugPoly = false,
            minZ = coords.z - 0.5,
            maxZ = coords.z + 0.8,
        }, {
            options = {
                {
                    icon = 'fas fa-search',
                    label = 'Apieškoti stalčių',
                    action = function()
                        if insideHouseId ~= house.id then return end
                        wakeSleeper(house.id)

                        local mg = Config.Burglary.drawerMinigame or {}
                        local ok = runMinigame(mg.mode or 'sequence', mg.label or 'Stalčius', mg.length or 4)
                        if not ok then
                            notify('Nepavyko tyliai atidaryti', 'error')
                            return
                        end
                        TriggerServerEvent('mrp_burglary:server:searchDrawer', house.id, idx)
                    end,
                },
            },
            distance = 1.6,
        })
    end
end

local function exitHouse(house)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local door = house.door
    SetEntityCoords(ped, door.x, door.y, door.z, false, false, false, false)
    SetEntityHeading(ped, door.w)

    TriggerServerEvent('mrp_burglary:server:exitSession', house.id)
    clearInteriorState()

    Wait(300)
    DoScreenFadeIn(500)
    notify('Išėjai iš namo', 'success')
end

RegisterNetEvent('mrp_burglary:client:enterInterior', function(house)
    if not house or not house.interior then return end
    insideHouseId = house.id

    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local enter = house.interior.enter
    SetEntityCoords(ped, enter.x, enter.y, enter.z, false, false, false, false)
    SetEntityHeading(ped, enter.w)

    spawnSleeper(house.interior)
    setupDrawerTargets(house)

    exports['qb-target']:AddBoxZone(('mrp_burglary_exit_%s'):format(house.id), house.interior.exit, 1.2, 1.2, {
        name = ('mrp_burglary_exit_%s'):format(house.id),
        heading = 0.0,
        debugPoly = false,
        minZ = house.interior.exit.z - 1.0,
        maxZ = house.interior.exit.z + 1.5,
    }, {
        options = {
            {
                icon = 'fas fa-door-open',
                label = 'Išeiti',
                action = function()
                    exitHouse(house)
                end,
            },
        },
        distance = 2.0,
    })
    drawerZones[#drawerZones + 1] = ('mrp_burglary_exit_%s'):format(house.id)

    Wait(300)
    DoScreenFadeIn(500)
    notify(('Viduje: %s — tyliai apieškok stalčius'):format(house.label or ''), 'primary')
end)

RegisterNetEvent('mrp_burglary:client:drawerLooted', function(granted)
    if not granted or #granted == 0 then
        return notify('Tuščia', 'error')
    end
    local parts = {}
    for _, g in ipairs(granted) do
        if g.type == 'cash' then
            parts[#parts + 1] = ('$%d grynais'):format(g.amount or 0)
        elseif g.item == 'markedbills' then
            parts[#parts + 1] = ('nešvarūs pinigai ($%d)'):format(g.worth or 0)
        else
            parts[#parts + 1] = ('%dx %s'):format(g.count or 1, g.item or '?')
        end
    end
    notify(('Rasta: %s'):format(table.concat(parts, ', ')), 'success')
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end

    for _, house in ipairs((Config.Burglary and Config.Burglary.houses) or {}) do
        local door = house.door
        exports['qb-target']:AddBoxZone(('mrp_burglary_door_%s'):format(house.id), vector3(door.x, door.y, door.z), 1.2, 1.2, {
            name = ('mrp_burglary_door_%s'):format(house.id),
            heading = door.w,
            debugPoly = false,
            minZ = door.z - 1.0,
            maxZ = door.z + 1.5,
        }, {
            options = {
                {
                    icon = 'fas fa-house-lock',
                    label = ('Įsilaužti (%s)'):format((Config.Burglary.tiers[house.tier] or {}).label or house.tier),
                    action = function()
                        if insideHouseId then return end
                        QBCore.Functions.TriggerCallback('mrp_burglary:server:canStart', function(res)
                            if not res or not res.ok then
                                return notify((res and res.message) or 'Negalima', 'error')
                            end
                            runLockpickAtDoor(house)
                        end, house.id)
                    end,
                },
            },
            distance = 1.8,
        })
    end
end)

CreateThread(function()
    while true do
        if insideHouseId and sleeperPed and DoesEntityExist(sleeperPed) and not sleeperAwake then
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(sleeperPed))
            if dist < 2.2 and IsPedRunning(PlayerPedId()) then
                wakeSleeper(insideHouseId)
            end
            Wait(400)
        else
            Wait(1200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearInteriorState()
end)

local QBCore = exports['qb-core']:GetCoreObject()

local insideHouseId = nil
local sleeperPed = nil
local sleeperAwake = false
local drawerZones = {}
local propEntities = {} --- { tv = ent, safe = ent }
local sessionLayout = nil --- { hasTv, hasSafe }
local busy = false

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function progressWithAnim(name, label, duration, anim, onDone, onCancel)
    anim = anim or Config.Burglary.lockpickAnim or {}
    QBCore.Functions.Progressbar(name, label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = anim.dict,
        anim = anim.clip,
        flags = anim.flag or 49,
    }, {}, {}, function()
        if onDone then onDone() end
    end, function()
        if onCancel then onCancel() end
    end)
end

local function runMinigame(mode, label, length)
    if GetResourceState('mrp_hacking') ~= 'started' then
        return true --- progress bar jau buvo — be hacking praleidžiam skill
    end
    local ok, result = pcall(function()
        return exports['mrp_hacking']:RunPhysicalMinigame(mode, {
            label = label,
            anim = {
                dict = (Config.Burglary.lockpickAnim or {}).dict or 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                name = (Config.Burglary.lockpickAnim or {}).clip or 'machinic_loop_mechandplayer',
                flags = 16,
            },
            data = { length = length },
        })
    end)
    return ok and result == true
end

local function isSleeperAlive()
    if not sleeperPed or not DoesEntityExist(sleeperPed) then return false end
    if IsPedDeadOrDying(sleeperPed, true) then return false end
    return GetEntityHealth(sleeperPed) > 0
end

local function wakeSleeper(houseId, reason)
    if sleeperAwake or not isSleeperAlive() then return end
    sleeperAwake = true
    ClearPedTasks(sleeperPed)
    SetPedFleeAttributes(sleeperPed, 0, false)
    SetPedCombatAttributes(sleeperPed, 46, true)
    TaskCombatPed(sleeperPed, PlayerPedId(), 0, 16)
    if math.random() < (Config.Burglary.wakeAlertChance or 0.85) then
        TriggerServerEvent('mrp_burglary:server:triggerAlarm', houseId, reason or 'savininkas pabudo')
    end
    notify('Savininkas pabudo ir kviečia policiją!', 'error')
end

local function clearProps()
    for _, ent in pairs(propEntities) do
        if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    propEntities = {}
end

local function clearInteriorState()
    insideHouseId = nil
    sleeperAwake = false
    sessionLayout = nil
    if sleeperPed and DoesEntityExist(sleeperPed) then
        DeleteEntity(sleeperPed)
    end
    sleeperPed = nil
    clearProps()
    for _, zoneName in ipairs(drawerZones) do
        pcall(function() exports['qb-target']:RemoveZone(zoneName) end)
    end
    drawerZones = {}
end

local function spawnProp(modelName, pos)
    if not pos then return nil end
    local model = joaat(modelName)
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return nil end
    local obj = CreateObject(model, pos.x, pos.y, pos.z - 0.95, false, false, false)
    SetEntityHeading(obj, pos.w or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function setupPropTargets(house)
    local propsCfg = Config.Burglary.props or {}

    if sessionLayout and sessionLayout.hasTv and house.interior.tv then
        local tvCfg = propsCfg.tv or {}
        local ent = spawnProp(tvCfg.model or 'prop_tv_flat_01', house.interior.tv)
        if ent then
            propEntities.tv = ent
            local zoneName = ('mrp_burglary_tv_%s'):format(house.id)
            drawerZones[#drawerZones + 1] = zoneName
            exports['qb-target']:AddTargetEntity(ent, {
                options = {
                    {
                        icon = 'fas fa-tv',
                        label = 'Nuimti televizorių',
                        canInteract = function()
                            return insideHouseId == house.id and not busy and propEntities.tv ~= nil
                        end,
                        action = function()
                            if busy then return end
                            busy = true
                            progressWithAnim(
                                'burg_take_tv',
                                tvCfg.takeLabel or 'Nuimamas televizorius…',
                                tvCfg.takeDuration or 12000,
                                tvCfg.anim or Config.Burglary.lockpickAnim,
                                function()
                                    busy = false
                                    TriggerServerEvent('mrp_burglary:server:takeTv', house.id)
                                end,
                                function()
                                    busy = false
                                    notify('Atšaukta', 'error')
                                end
                            )
                        end,
                    },
                },
                distance = 2.0,
            })
        end
    end

    if sessionLayout and sessionLayout.hasSafe and house.interior.safe then
        local safeCfg = propsCfg.safe or {}
        local ent = spawnProp(safeCfg.model or 'prop_ld_int_safe_01', house.interior.safe)
        if ent then
            propEntities.safe = ent
            exports['qb-target']:AddTargetEntity(ent, {
                options = {
                    {
                        icon = 'fas fa-vault',
                        label = 'Gręžti seifą',
                        canInteract = function()
                            return insideHouseId == house.id and not busy and propEntities.safe ~= nil
                                and QBCore.Functions.HasItem(Config.Burglary.drillItem or 'drill', 1)
                        end,
                        action = function()
                            if busy then return end
                            if not QBCore.Functions.HasItem(Config.Burglary.drillItem or 'drill', 1) then
                                return notify('Reikia grąžto', 'error')
                            end
                            busy = true
                            --- Gyvas NPC — pabunda / puola / PD
                            if isSleeperAlive() then
                                wakeSleeper(house.id, 'seifo gręžimas')
                            end
                            local drillAnim = {
                                dict = 'anim@heists@fleeca_bank@drilling',
                                clip = 'drill_straight_idle',
                                flag = 49,
                            }
                            progressWithAnim(
                                'burg_drill_safe',
                                safeCfg.drillLabel or 'Gręžiamas seifas…',
                                safeCfg.drillDuration or 18000,
                                drillAnim,
                                function()
                                    busy = false
                                    TriggerServerEvent('mrp_burglary:server:drillSafe', house.id)
                                end,
                                function()
                                    busy = false
                                    notify('Gręžimas atšauktas', 'error')
                                end
                            )
                        end,
                    },
                },
                distance = 1.8,
            })
        end
    end
end

local function runLockpickAtDoor(house)
    if busy then return end
    local hasAdv = QBCore.Functions.HasItem(Config.Burglary.advancedLockpickItem)
    local hasBasic = QBCore.Functions.HasItem(Config.Burglary.lockpickItem)
    if not hasAdv and not hasBasic then
        return notify('Reikia visrakčio', 'error')
    end

    local advanced = hasAdv
    local key = advanced and 'advancedlockpick' or 'lockpick'
    local prog = (Config.Burglary.lockpickProgress or {})[key] or { duration = 14000, label = 'Laužiate spyną…' }
    local mgCfg = Config.Burglary.lockpickMinigame or {}
    local mg = mgCfg[key] or mgCfg.lockpick

    busy = true
    progressWithAnim(
        'burg_door_lockpick',
        prog.label,
        prog.duration or 14000,
        Config.Burglary.lockpickAnim,
        function()
            local skillOk = true
            if mg then
                skillOk = runMinigame(mg.mode or 'sequence', mg.label or 'Spyna', mg.length or 5)
            end
            busy = false
            if not skillOk then
                if math.random() < (Config.Burglary.failLockpickAlertChance or 0) then
                    TriggerServerEvent('mrp_burglary:server:triggerAlarm', house.id, 'garsus durų laužymas')
                end
                return notify('Nepavyko atrakinti durų', 'error')
            end
            if math.random() < (Config.Burglary.policeAlertChance or 0) then
                TriggerServerEvent('mrp_burglary:server:triggerAlarm', house.id, 'įtartinas triukšmas')
            end
            TriggerServerEvent('mrp_burglary:server:beginSession', house.id, advanced)
        end,
        function()
            busy = false
            notify('Įsilaužimas atšauktas', 'error')
        end
    )
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
                    canInteract = function()
                        return insideHouseId == house.id and not busy
                    end,
                    action = function()
                        if insideHouseId ~= house.id or busy then return end
                        wakeSleeper(house.id, 'stalčių paieška')
                        busy = true
                        local dProg = Config.Burglary.drawerProgress or {}
                        progressWithAnim(
                            'burg_drawer',
                            dProg.label or 'Apieškomi stalčiai…',
                            dProg.duration or 6500,
                            Config.Burglary.lockpickAnim,
                            function()
                                local mg = Config.Burglary.drawerMinigame or {}
                                local ok = runMinigame(mg.mode or 'sequence', mg.label or 'Stalčius', mg.length or 5)
                                busy = false
                                if not ok then
                                    notify('Nepavyko tyliai atidaryti', 'error')
                                    return
                                end
                                TriggerServerEvent('mrp_burglary:server:searchDrawer', house.id, idx)
                            end,
                            function()
                                busy = false
                                notify('Atšaukta', 'error')
                            end
                        )
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

RegisterNetEvent('mrp_burglary:client:enterInterior', function(house, layout)
    if not house or not house.interior then return end
    insideHouseId = house.id
    sessionLayout = layout or {}
    sleeperAwake = false

    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local enter = house.interior.enter
    SetEntityCoords(ped, enter.x, enter.y, enter.z, false, false, false, false)
    SetEntityHeading(ped, enter.w)

    spawnSleeper(house.interior)
    setupDrawerTargets(house)
    setupPropTargets(house)

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
    local tip = 'Viduje: tyliai apieškok. '
    if sessionLayout.hasTv then tip = tip .. 'Yra TV. ' end
    if sessionLayout.hasSafe then tip = tip .. 'Yra seifas (reikia grąžto).' end
    notify(tip, 'primary')
end)

RegisterNetEvent('mrp_burglary:client:tvTaken', function()
    if propEntities.tv and DoesEntityExist(propEntities.tv) then
        DeleteEntity(propEntities.tv)
    end
    propEntities.tv = nil
    notify('Televizorius paimtas — parduok pas vogtų daiktų pirklį.', 'success')
end)

RegisterNetEvent('mrp_burglary:client:safeOpened', function(granted)
    if propEntities.safe and DoesEntityExist(propEntities.safe) then
        --- paliekam prop, bet disable target by clearing ref after loot once — server tracks
    end
    if not granted or #granted == 0 then
        return notify('Seifas tuščias…', 'error')
    end
    local parts = {}
    for _, g in ipairs(granted) do
        if g.type == 'cash' then
            parts[#parts + 1] = ('$%d'):format(g.amount or 0)
        elseif g.item == 'markedbills' then
            parts[#parts + 1] = ('nešvarūs $%d'):format(g.worth or g.count or 0)
        else
            parts[#parts + 1] = ('%dx %s'):format(g.count or 1, g.item or '?')
        end
    end
    notify(('Seife: %s'):format(table.concat(parts, ', ')), 'success')
end)

RegisterNetEvent('mrp_burglary:client:safeEmpty', function()
    notify('Seifas tuščias.', 'error')
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
                    canInteract = function()
                        return not insideHouseId and not busy
                    end,
                    action = function()
                        if insideHouseId or busy then return end
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

    --- Fence NPC
    local fence = Config.Burglary.fence
    if fence and fence.enabled and fence.coords then
        local model = joaat(fence.pedModel or 'g_m_y_mexgoon_02')
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        local c = fence.coords
        local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        if fence.scenario then
            TaskStartScenarioInPlace(ped, fence.scenario, 0, true)
        end
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-dollar-sign',
                    label = fence.label or 'Parduoti vogtus daiktus',
                    action = function()
                        TriggerServerEvent('mrp_burglary:server:sellStolen')
                    end,
                },
            },
            distance = 2.2,
        })
    end
end)

CreateThread(function()
    while true do
        if insideHouseId and isSleeperAlive() and not sleeperAwake then
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(sleeperPed))
            if dist < 2.2 and IsPedRunning(PlayerPedId()) then
                wakeSleeper(insideHouseId, 'bėgiojimas')
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

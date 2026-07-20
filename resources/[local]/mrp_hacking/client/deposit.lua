local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local vaultOpen = {} --- [locId] = true
local drilled = {} --- [boxKey] = true
local pileProps = {} --- [boxKey] = entity
local pileZones = {} --- [boxKey] = zoneName
local claiming = false
local pendingClaim = nil --- { key, allowed }

local function depositCfg()
    return Config.Robberies.Deposit or {}
end

local function boxKey(locId, index)
    return ('%s:%d'):format(tostring(locId), tonumber(index) or 0)
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function removeZones()
    for name in pairs(zones) do
        pcall(function() exports['qb-target']:RemoveZone(name) end)
    end
    zones = {}
end

local function removePile(key)
    if pileZones[key] then
        pcall(function() exports['qb-target']:RemoveZone(pileZones[key]) end)
        pileZones[key] = nil
    end
    local ent = pileProps[key]
    if ent and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
    pileProps[key] = nil
end

local function clearAllPiles()
    for key in pairs(pileProps) do
        removePile(key)
    end
end

local function spawnPile(key, pile)
    if not pile or not pile.coords then return end
    if pileProps[key] and DoesEntityExist(pileProps[key]) then return end
    removePile(key)

    local cfg = depositCfg()
    local modelName = cfg.pileProp or 'bkr_prop_bkr_cashpile_01'
    local hash = loadModel(modelName)
    if not hash then hash = loadModel('prop_money_bag_01') end
    if not hash then return end

    local c = pile.coords
    local ent = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    if not ent or ent == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    SetEntityHeading(ent, pile.heading or 0.0)
    PlaceObjectOnGroundProperly(ent)
    FreezeEntityPosition(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    SetModelAsNoLongerNeeded(hash)
    pileProps[key] = ent

    if GetResourceState('qb-target') ~= 'started' then return end
    local zoneName = ('hack_deposit_pile_%s'):format(key:gsub(':', '_'))
    pileZones[key] = zoneName
    local pos = GetEntityCoords(ent)
    exports['qb-target']:AddCircleZone(zoneName, pos, 0.7, {
        name = zoneName,
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-money-bill-wave',
                label = 'Surinkti pinigų kalną',
                canInteract = function()
                    return not claiming
                end,
                action = function()
                    claimPile(pile.locId, pile.index, key)
                end,
            },
        },
        distance = 1.8,
    })
end

function claimPile(locId, index, key)
    if claiming then return end
    claiming = true
    pendingClaim = { key = key, allowed = nil }
    TriggerServerEvent('mrp_hacking:server:depositStartClaim', locId, index)

    local t = GetGameTimer() + 2000
    while pendingClaim and pendingClaim.allowed == nil and GetGameTimer() < t do
        Wait(0)
    end

    local allowed = pendingClaim and pendingClaim.allowed
    pendingClaim = nil

    if not allowed then
        claiming = false
        if allowed == nil then
            QBCore.Functions.Notify('Nepavyko pradėti rinkimo.', 'error')
        end
        return
    end

    local ms = tonumber(depositCfg().grabMs) or 4500
    SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
    QBCore.Functions.Progressbar('deposit_grab_pile', 'Renkami pinigai…', ms, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'anim@heists@ornate_bank@grab_cash',
        anim = 'grab',
        flags = 49,
    }, {}, {}, function()
        claiming = false
        TriggerServerEvent('mrp_hacking:server:depositClaimPile', locId, index)
    end, function()
        claiming = false
        TriggerServerEvent('mrp_hacking:server:depositCancelClaim', locId, index)
        QBCore.Functions.Notify('Atšaukta.', 'error')
    end)
end

local function drillBox(locId, index)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:depositCanDrill', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
        local mg = (Config.RobberyMinigames or {}).drill
        --- Deposit: sequence vietoj native drill (patikimiau)
        local mode = 'sequence'
        local data = { length = 4 }
        if mg and mg.mode and mg.mode ~= 'native_drill' and mg.mode ~= 'gtao_drill' and mg.mode ~= 'drill' then
            mode = mg.mode
            data = mg.data or data
        end
        local anim = (Config.RobberyAnims or {}).drill
        local ok = exports['mrp_hacking']:RunPhysicalMinigame(mode, {
            label = 'Deposit dėžutė — užraktas',
            anim = anim,
            data = data,
        })
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
        }, {
            model = 'prop_tool_drill',
            bone = 57005,
            coords = { x = 0.14, y = 0.0, z = -0.01 },
            rotation = { x = 90.0, y = -90.0, z = 180.0 },
        }, {}, function()
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
            local key = boxKey(locId, i)
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
                            if not vaultOpen[tostring(locId)] then return false end
                            if drilled[key] then return false end
                            if pileProps[key] then return false end
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

local function applyState(locId, open, drilledMap, pilesMap)
    locId = tostring(locId or '')
    vaultOpen[locId] = open == true
    if drilledMap then
        for k, v in pairs(drilledMap) do
            if v then drilled[k] = true end
        end
    end
    if pilesMap then
        for k, pile in pairs(pilesMap) do
            if pile and not drilled[k] then drilled[k] = true end
            if pile then spawnPile(k, pile) end
        end
    end
end

RegisterNetEvent('mrp_hacking:client:depositVaultState', function(locId, open, drilledMap, pilesMap)
    applyState(locId, open, drilledMap, pilesMap)
    if open then
        QBCore.Functions.Notify('Žali markeriai virš dėžučių = galima gręžti. Po gręžimo — surink pinigų kalną.', 'primary', 9000)
    end
end)

RegisterNetEvent('mrp_hacking:client:depositBoxDrilled', function(locId, index, key, pile)
    drilled[key] = true
    if pile then spawnPile(key, pile) end
end)

RegisterNetEvent('mrp_hacking:client:depositPileClaimed', function(locId, index, key)
    removePile(key)
end)

RegisterNetEvent('mrp_hacking:client:depositClaimAllowed', function(key)
    if pendingClaim and pendingClaim.key == key then
        pendingClaim.allowed = true
    end
end)

RegisterNetEvent('mrp_hacking:client:depositClaimDenied', function(key, msg)
    if pendingClaim and pendingClaim.key == key then
        pendingClaim.allowed = false
    end
    if msg then QBCore.Functions.Notify(msg, 'error') end
end)

--- Markeriai ant gręžiamų dėžučių + pinigų kalnų
CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local cfg = depositCfg()
        local mk = cfg.marker or {}
        local pmk = cfg.pileMarker or {}

        for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
            if vaultOpen[tostring(locId)] then
                for i, box in ipairs(list) do
                    local key = boxKey(locId, i)
                    local c = box.coords
                    if #(p - c) < 35.0 then
                        sleep = 0
                        if not drilled[key] and not pileProps[key] then
                            local col = mk.color or { r = 50, g = 220, b = 90, a = 200 }
                            DrawMarker(
                                mk.type or 20,
                                c.x, c.y, c.z + (mk.zOffset or 0.55),
                                0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                                mk.scale or 0.28, mk.scale or 0.28, mk.scale or 0.28,
                                col.r or 50, col.g or 220, col.b or 90, col.a or 200,
                                mk.bob ~= false, true, 2, false, nil, nil, false
                            )
                        elseif pileProps[key] and DoesEntityExist(pileProps[key]) then
                            local pc = GetEntityCoords(pileProps[key])
                            local col = pmk.color or { r = 255, g = 200, b = 40, a = 220 }
                            DrawMarker(
                                pmk.type or 2,
                                pc.x, pc.y, pc.z + (pmk.zOffset or 0.85),
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                pmk.scale or 0.22, pmk.scale or 0.22, pmk.scale or 0.22,
                                col.r or 255, col.g or 200, col.b or 40, col.a or 220,
                                true, true, 2, false, nil, nil, false
                            )
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

--- Sync kai priartėji prie banko
CreateThread(function()
    local lastNear = {}
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
            local first = list[1]
            if first then
                local near = #(p - first.coords) < 60.0
                local id = tostring(locId)
                if near and not lastNear[id] then
                    lastNear[id] = true
                    QBCore.Functions.TriggerCallback('mrp_hacking:server:depositGetState', function(res)
                        if res then
                            applyState(id, res.open, res.drilled, res.piles)
                        end
                    end, id)
                elseif not near then
                    lastNear[id] = nil
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1200)
    registerDepositZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeZones()
    clearAllPiles()
end)

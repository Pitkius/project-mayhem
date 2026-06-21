--- Lost MC Gabz interjeras + įėjimas (stream turi būti įkeltas prieš entity set'us).

local CLUBHOUSE_COORDS = vector3(994.4787, -122.9949, 73.11467)
local GARAGE_COORDS = vector3(972.16, -118.05, 74.35)
local ENTRANCE_OUTSIDE = vector4(981.5164, -102.9560, 74.8505, 250.7)
local INTERIOR_SPAWN = vector4(995.15, -120.85, 74.05, 70.0)
local EXIT_INSIDE = vector4(993.85, -123.55, 74.05, 250.0)
local LOST_CENTER = vector3(987.0, -115.0, 74.5)
local CLUBHOUSE_INTERIOR_TYPE = 'bkr_biker_dlc_int_02'
local REAPPLY_RADIUS = 140.0

local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'
local GABZ_IPLS = { 'gabz_biker_milo_', 'lost_garage_milo_' }

local INTERIOR_PROBES = {
    CLUBHOUSE_COORDS,
    vector3(989.5, -118.0, 73.1),
    vector3(998.0, -127.0, 73.1),
    vector3(1000.5, -115.5, 73.1),
    vector3(981.52, -102.96, 74.85),
    GARAGE_COORDS,
}

local LOST_DOOR_MODEL = `lost_mc_door_01`
local LOST_DOOR_SPOTS = {
    vector3(981.52, -102.96, 74.85),
    vector3(981.40, -103.05, 74.85),
}

local applied = false
local vanillaRemoved = false
local teleporting = false
local targetsReady = false

local function requestCollision(coords)
    if not coords then return end
    for dz = -2.0, 3.0, 1.0 do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z + dz)
    end
end

local function requestCollisionList(list)
    for _, coords in ipairs(list or {}) do
        requestCollision(coords)
    end
end

local function getInteriorId(coords, interiorType)
    if not coords then return 0 end
    if interiorType and interiorType ~= '' then
        local typed = GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
        if typed and typed ~= 0 then return typed end
    end
    return GetInteriorAtCoords(coords.x, coords.y, coords.z)
end

local function enableProp(interiorId, prop, color)
    EnableInteriorProp(interiorId, prop)
    if color then
        SetInteriorPropColor(interiorId, prop, color)
    end
end

local function setupClubhouse(interiorId)
    if not interiorId or interiorId == 0 then return false end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)

    enableProp(interiorId, 'walls_02', 8)
    enableProp(interiorId, 'Furnishings_02', 8)
    enableProp(interiorId, 'decorative_02')
    enableProp(interiorId, 'mural_03')
    enableProp(interiorId, 'lower_walls_default', 8)
    enableProp(interiorId, 'mod_booth')
    enableProp(interiorId, 'gun_locker')
    enableProp(interiorId, 'cash_small')
    enableProp(interiorId, 'id_small')
    enableProp(interiorId, 'weed_small')

    RefreshInterior(interiorId)
    return true
end

local function setupGarage(interiorId)
    if not interiorId or interiorId == 0 then return end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    RefreshInterior(interiorId)
end

local function openLostMcDoorProps()
    for _, spot in ipairs(LOST_DOOR_SPOTS) do
        requestCollision(spot)
        local obj = GetClosestObjectOfType(spot.x, spot.y, spot.z, 2.5, LOST_DOOR_MODEL, false, false, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, false)
            SetEntityCollision(obj, true, true)
        end
        pcall(function()
            SetStateOfClosestDoorOfType(LOST_DOOR_MODEL, spot.x, spot.y, spot.z, false, 0.0, false)
        end)
    end
end

local function removeVanillaPlacementOnce()
    if vanillaRemoved then return end
    RemoveIpl(VANILLA_BIKER_IPL)
    vanillaRemoved = true
end

local function applyLostMcInterior()
    for _, ipl in ipairs(GABZ_IPLS) do
        RequestIpl(ipl)
    end

    requestCollisionList(INTERIOR_PROBES)

    local clubhouseId = 0
    for _, probe in ipairs(INTERIOR_PROBES) do
        clubhouseId = getInteriorId(probe, CLUBHOUSE_INTERIOR_TYPE)
        if clubhouseId ~= 0 and IsValidInterior(clubhouseId) then
            break
        end
    end

    if clubhouseId == 0 or not IsValidInterior(clubhouseId) then
        return false
    end

    if not IsInteriorReady(clubhouseId) then
        LoadInterior(clubhouseId)
    end

    setupClubhouse(clubhouseId)
    removeVanillaPlacementOnce()

    local garageId = getInteriorId(GARAGE_COORDS, CLUBHOUSE_INTERIOR_TYPE)
    if garageId ~= 0 and garageId ~= clubhouseId then
        setupGarage(garageId)
    end

    openLostMcDoorProps()
    applied = true
    return true
end

local function prepareInteriorAt(x, y, z)
    for _ = 1, 30 do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    applyLostMcInterior()
    local interiorId = getInteriorId(vector3(x, y, z), CLUBHOUSE_INTERIOR_TYPE)
    if interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

local function fadeTeleport(coords, heading)
    if teleporting then return end
    teleporting = true

    applyLostMcInterior()

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    if heading then
        SetEntityHeading(ped, heading)
    end

    prepareInteriorAt(coords.x, coords.y, coords.z)
    openLostMcDoorProps()

    Wait(350)
    DoScreenFadeIn(400)
    teleporting = false
end

local function enterClubhouse()
    fadeTeleport(vector3(INTERIOR_SPAWN.x, INTERIOR_SPAWN.y, INTERIOR_SPAWN.z), INTERIOR_SPAWN.w)
end

local function exitClubhouse()
    fadeTeleport(vector3(ENTRANCE_OUTSIDE.x, ENTRANCE_OUTSIDE.y, ENTRANCE_OUTSIDE.z), ENTRANCE_OUTSIDE.w)
end

local function setupTargets()
    if targetsReady or GetResourceState('qb-target') ~= 'started' then return end

    local out = ENTRANCE_OUTSIDE
    exports['qb-target']:AddBoxZone('gabz_lost_enter', vector3(out.x, out.y, out.z), 2.0, 2.0, {
        name = 'gabz_lost_enter',
        heading = out.w,
        minZ = out.z - 1.2,
        maxZ = out.z + 1.4,
        debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-door-open',
                label = 'Įeiti į klubą',
                action = enterClubhouse,
            },
        },
        distance = 2.5,
    })

    local inside = EXIT_INSIDE
    exports['qb-target']:AddBoxZone('gabz_lost_exit', vector3(inside.x, inside.y, inside.z), 2.0, 2.0, {
        name = 'gabz_lost_exit',
        heading = inside.w,
        minZ = inside.z - 1.0,
        maxZ = inside.z + 1.2,
        debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-door-closed',
                label = 'Išeiti laukan',
                action = exitClubhouse,
            },
        },
        distance = 2.5,
    })

    targetsReady = true
end

local function playerInsideClubhouse(coords)
    return coords.x > 978.0 and coords.x < 1006.0
        and coords.y > -135.0 and coords.y < -104.0
        and coords.z > 71.0 and coords.z < 78.0
end

local function keepLostMcFloor()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if not playerInsideClubhouse(coords) then return end

    if coords.z < 72.75 then
        SetEntityCoordsNoOffset(ped, CLUBHOUSE_COORDS.x, CLUBHOUSE_COORDS.y, 74.12, false, false, false)
        prepareInteriorAt(CLUBHOUSE_COORDS.x, CLUBHOUSE_COORDS.y, CLUBHOUSE_COORDS.z)
    end
end

CreateThread(function()
    Wait(2000)
    local ok = false
    for _ = 1, 80 do
        if applyLostMcInterior() then
            ok = true
            print('^5[cfx-gabz-lost]^7 Lost MC interjeras užkrautas.')
            break
        end
        Wait(500)
    end
    if not ok then
        print('^1[cfx-gabz-lost]^7 Interjeras neužsikrovė — naudok qb-target prie durų arba /restart cfx-gabz-lost')
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    setupTargets()
end)

CreateThread(function()
    while true do
        local sleep = 4000
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            if #(coords - LOST_CENTER) < REAPPLY_RADIUS then
                sleep = 1500
                requestCollisionList(INTERIOR_PROBES)
                openLostMcDoorProps()
                keepLostMcFloor()

                local interiorId = getInteriorId(CLUBHOUSE_COORDS, CLUBHOUSE_INTERIOR_TYPE)
                if not applied or interiorId == 0 or not IsValidInterior(interiorId) then
                    applied = false
                    if applyLostMcInterior() then
                        print('^5[cfx-gabz-lost]^7 Lost MC interjeras pakartotas (artumas).')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    applied = false
    vanillaRemoved = false
    targetsReady = false
    CreateThread(function()
        Wait(2500)
        applyLostMcInterior()
        setupTargets()
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GetResourceState('qb-target') == 'started' then
        pcall(function() exports['qb-target']:RemoveZone('gabz_lost_enter') end)
        pcall(function() exports['qb-target']:RemoveZone('gabz_lost_exit') end)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(4000)
        applied = false
        applyLostMcInterior()
        setupTargets()
    end)
end)

exports('ReloadLostMc', function()
    applied = false
    applyLostMcInterior()
    openLostMcDoorProps()
end)

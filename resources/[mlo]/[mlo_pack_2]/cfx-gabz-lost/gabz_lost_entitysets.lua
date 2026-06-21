local CLUBHOUSE_COORDS = vector3(994.4787, -122.9949, 73.11467)
local GARAGE_COORDS = vector3(972.16, -118.05, 74.35)
local ENTRANCE_COORDS = vector3(981.5164, -102.9560, 74.8505)
local LOST_CENTER = vector3(987.0, -115.0, 74.5)
local CLUBHOUSE_INTERIOR_TYPE = 'bkr_biker_dlc_int_02'

local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'
local GABZ_IPLS = { 'gabz_biker_milo_', 'lost_garage_milo_' }

local INTERIOR_PROBES = {
    CLUBHOUSE_COORDS,
    vector3(989.5, -118.0, 73.1),
    vector3(998.0, -127.0, 73.1),
    vector3(1000.5, -115.5, 73.1),
    ENTRANCE_COORDS,
    GARAGE_COORDS,
}

local LOST_DOORS = {
    { model = `lost_mc_door_01`, coords = vector3(981.52, -102.96, 74.85), heading = 70.7 },
    { model = `lost_mc_door_01`, coords = vector3(981.40, -103.05, 74.85), heading = 250.0 },
}

local lostReady = false
local lastLostLoadAt = 0

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

local function waitInteriorAt(coords, interiorType, attempts)
    attempts = attempts or 250
    for _ = 1, attempts do
        requestCollision(coords)
        local id = getInteriorId(coords, interiorType)
        if id ~= 0 and IsValidInterior(id) then
            if IsInteriorReady(id) then
                return id
            end
            LoadInterior(id)
        end
        Wait(50)
    end
    return getInteriorId(coords, interiorType)
end

local function unlockDoor(door)
    if not door or not door.model or not door.coords then return end
    pcall(function()
        SetStateOfClosestDoorOfType(
            door.model,
            door.coords.x,
            door.coords.y,
            door.coords.z,
            false,
            door.heading or 0.0,
            false
        )
    end)
end

local function unlockLostDoors()
    for _, door in ipairs(LOST_DOORS) do
        unlockDoor(door)
    end
end

local function enableProp(interiorId, prop, color)
    EnableInteriorProp(interiorId, prop)
    if color then
        SetInteriorPropColor(interiorId, prop, color)
    end
end

local function setupClubhouse(interiorId)
    if not interiorId or interiorId == 0 then return end
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
end

local function setupGarage(interiorId)
    if not interiorId or interiorId == 0 then return end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    RefreshInterior(interiorId)
end

local function waitForMapdata()
    local deadline = GetGameTimer() + 20000
    while GetResourceState('cfx-gabz-mapdata') ~= 'started' and GetGameTimer() < deadline do
        Wait(200)
    end
end

local function loadLostMc(force)
    local now = GetGameTimer()
    if not force and lostReady and (now - lastLostLoadAt) < 4000 then
        return
    end

    waitForMapdata()

    for _, ipl in ipairs(GABZ_IPLS) do
        RequestIpl(ipl)
    end
    RemoveIpl(VANILLA_BIKER_IPL)

    requestCollisionList(INTERIOR_PROBES)
    Wait(350)

    local clubhouseId = 0
    for _, probe in ipairs(INTERIOR_PROBES) do
        clubhouseId = waitInteriorAt(probe, CLUBHOUSE_INTERIOR_TYPE, 80)
        if clubhouseId ~= 0 then break end
    end

    if clubhouseId == 0 then
        print('^1[cfx-gabz-lost]^7 Clubhouse interjeras neužsikrovė — patikrink mapdata / stream.')
        lostReady = false
        return
    end

    setupClubhouse(clubhouseId)
    PinInteriorInMemory(clubhouseId)

    local garageId = waitInteriorAt(GARAGE_COORDS, CLUBHOUSE_INTERIOR_TYPE, 80)
    if garageId ~= 0 and garageId ~= clubhouseId then
        setupGarage(garageId)
        PinInteriorInMemory(garageId)
    end

    unlockLostDoors()
    lostReady = true
    lastLostLoadAt = now
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
    end

    local interiorId = getInteriorId(CLUBHOUSE_COORDS, CLUBHOUSE_INTERIOR_TYPE)
    if interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        if not IsInteriorReady(interiorId) then
            LoadInterior(interiorId)
        end
    end
end

CreateThread(function()
    Wait(2500)
    loadLostMc(true)
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local near = #(coords - LOST_CENTER) < 140.0

        if near then
            loadLostMc(false)
            requestCollisionList(INTERIOR_PROBES)
            keepLostMcFloor()
            Wait(900)
        else
            Wait(2200)
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        loadLostMc(true)
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(4000)
        loadLostMc(true)
    end)
end)

exports('ReloadLostMc', function()
    lostReady = false
    loadLostMc(true)
end)

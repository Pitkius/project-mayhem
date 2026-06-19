local BURNT_FARM_IPLS = {
    'farm_burnt',
    'farm_burnt_props',
    'farm_burnt_lod',
    'farm_burnt_props2',
}

local VANILLA_FARM_EXTERIOR_IPLS = {
    'farm',
    'farm_lod',
    'farm_props',
    'des_farmhouse',
}

local VANILLA_FARM_INTERIOR_IPLS = {
    'farmint',
    'farmint_cap',
}

local ONEIL_CENTER = vec3(2435.61, 4975.78, 46.57)
local ONEIL_INTERIOR_PROBE = vec3(2453.229, 4965.452, 45.572)
local ONEIL_DOOR_PROBE = vec3(2452.2986, 4969.7222, 46.5716)

--- Druglabs MLO IPL (O'Neil zona) — turi būti išjungti, kad veiktų vanilla sodyba
local ONEIL_DRUGLAB_IPLS = {
    'brown_amfsted2_milo_',
    'brown_amfsted4_milo_',
}

--- O'Neil sodybos durys — keli modeliai + tikslios koordinatės
local ONEIL_DOORS = {
    {
        coords = vec3(2452.2986, 4969.7222, 46.5716),
        heading = 308.7976,
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1`, `prop_farmhouse_door2` },
    },
    {
        coords = vec3(2435.78, 4975.82, 46.81),
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1` },
    },
    {
        coords = vec3(2441.50, 4981.85, 46.81),
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1` },
    },
}

local ONEIL_BLOCK_ENTITY_SETS = {
    'brown_amfsted', 'amfsted', 'methlab', 'drug', 'lab', 'brown_methlab',
}

local SIMEON_CENTER = vec3(-47.59, -1115.42, 26.43)
local SIMEON_INTERIOR_PROBE = vec3(-38.62, -1099.01, 27.31)
local SIMEON_STYLE_PROPS = { 'csr_beforeMission', 'csr_inMission', 'csr_afterMissionA', 'csr_afterMissionB' }
local SIMEON_SHUTTER_PROPS = { 'shutter_open', 'shutter_closed' }

local SIMEON_DOORS = {
    { model = `v_ilev_csr_door_l`, coords = vec3(-32.64, -1108.55, 26.57) },
    { model = `v_ilev_csr_door_r`, coords = vec3(-31.72, -1108.55, 26.57) },
    { model = `prop_com_gar_door_01`, coords = vec3(-40.18, -1094.71, 27.26) },
    { model = `prop_com_gar_door_01`, coords = vec3(-37.86, -1094.71, 27.26) },
}

--- Gabz Lost MC — įėjimas (vartai / durys) + clubhouse interjeras
local LOST_MC_CENTER = vec3(981.6895, -102.8003, 74.8478)
local LOST_MC_ENTRANCE = vec3(981.6895, -102.8003, 74.8478)
local LOST_MC_CLUB_PROBE = vec3(994.4787, -122.9949, 73.11467)
local LOST_MC_GARAGE_PROBE = vec3(972.16, -118.05, 74.35)
local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'

local LOST_MC_DOORS = {
    {
        coords = vec3(982.1292, -103.1277, 74.8483),
        heading = 49.5662,
        models = { `lost_mc_door_01`, `lost_mc_gate`, `v_ilev_lostdoor`, `prop_lrggate_01_l` },
        radius = 5.0,
    },
    {
        coords = vec3(982.6339, -104.7095, 74.8488),
        models = { `lost_mc_door_01`, `v_ilev_lostdoor` },
        radius = 4.5,
    },
}

local function removeIpls(list)
    for _, ipl in ipairs(list) do
        RemoveIpl(ipl)
    end
end

local function requestIpls(list)
    for _, ipl in ipairs(list) do
        RequestIpl(ipl)
    end
end

local function requestCollision(coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + 3500
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        if #(GetEntityCoords(ped) - coords) < 120.0
            and HasCollisionLoadedAroundEntity(ped) then
            break
        end
        Wait(0)
    end
end

local function waitInteriorAt(coords, attempts, interiorType)
    attempts = attempts or 250
    for _ = 1, attempts do
        requestCollision(coords)
        local id = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if (not id or id == 0) and interiorType then
            id = GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
        end
        if id and id ~= 0 and IsValidInterior(id) then
            if IsInteriorReady(id) then
                return id
            end
            LoadInterior(id)
        end
        Wait(50)
    end
    local fallback = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if fallback and fallback ~= 0 then return fallback end
    if interiorType then
        return GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
    end
    return 0
end

local function pinInteriorAt(coords, interiorType)
    local interiorId = waitInteriorAt(coords, 120, interiorType)
    if not interiorId or interiorId == 0 then return 0 end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    RefreshInterior(interiorId)
    return interiorId
end

local function getSimeonInteriorId()
    local id = GetInteriorAtCoords(SIMEON_INTERIOR_PROBE.x, SIMEON_INTERIOR_PROBE.y, SIMEON_INTERIOR_PROBE.z)
    if id and id ~= 0 then return id end
    return GetInteriorAtCoordsWithType(SIMEON_INTERIOR_PROBE.x, SIMEON_INTERIOR_PROBE.y, SIMEON_INTERIOR_PROBE.z, 'v_carshowroom')
end

local function disableInteriorEntitySet(interiorId, name)
    if not interiorId or interiorId == 0 or not name or name == '' then return end
    pcall(function()
        if IsInteriorEntitySetActive(interiorId, name) then
            DeactivateInteriorEntitySet(interiorId, name)
        end
    end)
    pcall(function()
        DisableInteriorProp(interiorId, name)
    end)
end

local function enableInteriorEntitySet(interiorId, name)
    if not interiorId or interiorId == 0 or not name or name == '' then return end
    pcall(function()
        EnableInteriorProp(interiorId, name)
    end)
    pcall(function()
        if not IsInteriorEntitySetActive(interiorId, name) then
            ActivateInteriorEntitySet(interiorId, name)
        end
    end)
end

local function enableInteriorProp(interiorId, prop, color)
    if not interiorId or interiorId == 0 then return end
    EnableInteriorProp(interiorId, prop)
    if color then
        SetInteriorPropColor(interiorId, prop, color)
    end
end

local function unlockLegacyDoor(model, coords, heading)
    if not model or not coords then return end
    pcall(function()
        SetStateOfClosestDoorOfType(model, coords.x, coords.y, coords.z, false, heading or 0.0, false)
    end)
end

local function unlockDoorEntry(door, prefix, index)
    local c = door.coords
    local radius = door.radius or 4.0
    local models = door.models or (door.model and { door.model } or {})
    local heading = door.heading or 0.0

    requestCollision(c)

    for _, model in ipairs(models) do
        unlockLegacyDoor(model, c, heading)
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, model, false, false, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, false)
            SetEntityCanBeDamaged(obj, false)
            SetEntityCollision(obj, true, true)
            if door.heading then
                SetEntityHeading(obj, door.heading)
            end
        end
    end

    local primaryModel = models[1]
    if not primaryModel then return end

    local dh = joaat(('%s_%s'):format(prefix, index))
    local ok, reg = pcall(function()
        return IsDoorRegisteredWithSystem(dh)
    end)
    if not ok or not reg then
        AddDoorToSystem(dh, primaryModel, c.x, c.y, c.z, false, false, false)
    end
    DoorSystemSetDoorState(dh, 0, false, false)
    pcall(function() DoorSystemSetAutomaticDistance(dh, 40.0, false, false) end)
    pcall(function() DoorSystemSetAutomaticRate(dh, 1.0, false, false) end)
    pcall(function() DoorSystemSetOpenRatio(dh, 0.0, false, false) end)
    pcall(function() DoorSystemSetHoldOpen(dh, false) end)
end

local function unlockDoorList(doors, prefix)
    for i, door in ipairs(doors) do
        unlockDoorEntry(door, prefix, i)
    end
end

local function unlockSimeonDoors()
    unlockDoorList(SIMEON_DOORS, 'simeon_csr')
end

local function unlockOneilDoors()
    unlockDoorList(ONEIL_DOORS, 'oneil_farm')
end

local function unlockLostMcDoors()
    unlockDoorList(LOST_MC_DOORS, 'lost_mc')
end

local function suppressOneilMloInterior()
    local probes = {
        ONEIL_INTERIOR_PROBE,
        ONEIL_DOOR_PROBE,
        vec3(2452.28, 4969.70, 46.57),
    }
    for _, coords in ipairs(probes) do
        local interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if interiorId and interiorId ~= 0 then
            for _, setName in ipairs(ONEIL_BLOCK_ENTITY_SETS) do
                disableInteriorEntitySet(interiorId, setName)
            end
            RefreshInterior(interiorId)
        end
    end
end

local function loadSimeonShowroom()
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')

    local interiorId = getSimeonInteriorId()
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)

        for _, prop in ipairs(SIMEON_STYLE_PROPS) do
            disableInteriorEntitySet(interiorId, prop)
        end
        for _, prop in ipairs(SIMEON_SHUTTER_PROPS) do
            disableInteriorEntitySet(interiorId, prop)
        end

        enableInteriorEntitySet(interiorId, 'csr_beforeMission')
        enableInteriorEntitySet(interiorId, 'shutter_open')
        RefreshInterior(interiorId)
    end

    pinInteriorAt(SIMEON_CENTER)
    unlockSimeonDoors()
end

local function loadOneilFarmhouse()
    removeIpls(BURNT_FARM_IPLS)
    removeIpls(ONEIL_DRUGLAB_IPLS)
    requestIpls(VANILLA_FARM_EXTERIOR_IPLS)
    requestIpls(VANILLA_FARM_INTERIOR_IPLS)

    requestCollision(ONEIL_DOOR_PROBE)
    pinInteriorAt(ONEIL_INTERIOR_PROBE, 'farmhouse')
    pinInteriorAt(ONEIL_DOOR_PROBE, 'farmhouse')
    suppressOneilMloInterior()
    unlockOneilDoors()
end

local lostMcReloadCooldown = 0

local function isLostMcInteriorReady()
    local clubhouseId = GetInteriorAtCoords(LOST_MC_CLUB_PROBE.x, LOST_MC_CLUB_PROBE.y, LOST_MC_CLUB_PROBE.z)
    if clubhouseId == 0 then
        clubhouseId = GetInteriorAtCoords(LOST_MC_ENTRANCE.x, LOST_MC_ENTRANCE.y, LOST_MC_ENTRANCE.z)
    end
    return clubhouseId ~= 0 and IsValidInterior(clubhouseId) and IsInteriorReady(clubhouseId)
end

local function ensureLostMcInterior()
    RemoveIpl(VANILLA_BIKER_IPL)

    if isLostMcInteriorReady() then
        pinInteriorAt(LOST_MC_CLUB_PROBE)
        pinInteriorAt(LOST_MC_ENTRANCE)
        pinInteriorAt(LOST_MC_GARAGE_PROBE)
        return
    end

    local now = GetGameTimer()
    if now < lostMcReloadCooldown then return end
    lostMcReloadCooldown = now + 8000

    if GetResourceState('cfx-gabz-lost') == 'started' then
        pcall(function()
            exports['cfx-gabz-lost']:ReloadLostMc()
        end)
        return
    end

    RequestIpl('gabz_biker_milo_')
    RequestIpl('lost_garage_milo_')
    requestCollision(LOST_MC_ENTRANCE)
    requestCollision(LOST_MC_CLUB_PROBE)
    pinInteriorAt(LOST_MC_CLUB_PROBE)
    pinInteriorAt(LOST_MC_ENTRANCE)
    pinInteriorAt(LOST_MC_GARAGE_PROBE)
end

local function loadLostMcClubhouse()
    RemoveIpl(VANILLA_BIKER_IPL)
    ensureLostMcInterior()
    unlockLostMcDoors()
end

local function applyMapFixes()
    loadSimeonShowroom()
    loadOneilFarmhouse()
    loadLostMcClubhouse()
end

exports('ReloadSimeonShowroom', loadSimeonShowroom)
exports('ReloadOneilFarmhouse', loadOneilFarmhouse)
exports('ReloadLostMc', loadLostMcClubhouse)
exports('ApplyMapFixes', applyMapFixes)

CreateThread(function()
    Wait(2500)
    applyMapFixes()
end)

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local nearOneil = #(p - ONEIL_CENTER) < 90.0 or #(p - ONEIL_DOOR_PROBE) < 45.0
        local nearSimeon = #(p - SIMEON_CENTER) < 120.0
        local nearLost = #(p - LOST_MC_CENTER) < 110.0

        if nearOneil then
            loadOneilFarmhouse()
            unlockOneilDoors()
            Wait(2000)
        elseif nearLost then
            loadLostMcClubhouse()
            Wait(2000)
        elseif nearSimeon then
            loadSimeonShowroom()
            unlockSimeonDoors()
            Wait(1200)
        else
            Wait(3500)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName()
        or resourceName == 'druglabs'
        or resourceName == 'cfx-gabz-lost'
        or resourceName == 'fivempro_dealership' then
        Wait(800)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    applyMapFixes()
end)

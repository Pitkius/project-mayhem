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

local ONEIL_CENTER = vec3(2435.81, 4975.95, 46.57)
local ONEIL_INTERIOR_PROBE = vec3(2453.229, 4965.452, 45.572)
local ONEIL_DOOR_PROBE = vec3(2452.2986, 4969.7222, 46.5716)

--- Druglabs MLO IPL — stream failai gali likti, bet IPL taip pat nuimame
local ONEIL_DRUGLAB_IPLS = {
    'brown_amfsted_milo_',
    'brown_amfsted2_milo_',
    'brown_amfsted3_milo_',
    'brown_amfsted4_milo_',
}

local ONEIL_BLOCK_MODELS = {
    `brown_amfsted_shell`,
}

local ONEIL_DOORS = {
    {
        coords = vec3(2452.2986, 4969.7222, 46.5716),
        heading = 308.7976,
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1`, `prop_farmhouse_door2` },
        radius = 5.0,
    },
    {
        coords = vec3(2435.8105, 4975.9517, 46.5714),
        heading = 224.2388,
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1`, `prop_farmhouse_door2` },
        radius = 5.0,
    },
    {
        coords = vec3(2441.50, 4981.85, 46.81),
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1` },
        radius = 4.5,
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

local LOST_MC_CENTER = vec3(981.3867, -102.3285, 74.3489)
local LOST_MC_ENTRANCE = vec3(981.3867, -102.3285, 74.3489)
local LOST_MC_CLUB_PROBE = vec3(994.4787, -122.9949, 73.11467)
local LOST_MC_GARAGE_PROBE = vec3(972.16, -118.05, 74.35)
local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'

local LOST_MC_DOORS = {
    {
        coords = vec3(981.3867, -102.3285, 74.3489),
        heading = 34.8568,
        models = { `lost_mc_door_01`, `lost_mc_gate`, `v_ilev_lostdoor`, `prop_lrggate_01_l` },
        radius = 6.0,
    },
    {
        coords = vec3(982.6339, -104.7095, 74.8488),
        heading = 30.8738,
        models = { `lost_mc_door_01`, `v_ilev_lostdoor` },
        radius = 5.0,
    },
}

local LOST_MC_VANILLA_DOOR_MODELS = {
    `v_ilev_lostdoor`,
    `prop_lrggate_01_l`,
}

local LOST_MC_GABZ_DOOR_MODELS = {
    `lost_mc_door_01`,
    `lost_mc_gate`,
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

local function hasNearbyModel(coords, radius, models)
    for _, model in ipairs(models) do
        if GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, model, false, false, false) ~= 0 then
            return true
        end
    end
    return false
end

local function hideDuplicateObjects(center, radius, vanillaModels, customModels)
    if not hasNearbyModel(center, radius, customModels) then return end

    local pool = GetGamePool('CObject')
    for _, entity in ipairs(pool) do
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            local isVanilla = false
            for _, vanilla in ipairs(vanillaModels) do
                if model == vanilla then
                    isVanilla = true
                    break
                end
            end
            if isVanilla and #(GetEntityCoords(entity) - center) <= radius then
                SetEntityVisible(entity, false, false)
                SetEntityCollision(entity, false, false)
                FreezeEntityPosition(entity, true)
            end
        end
    end
end

local function stripBlockingModels(center, radius, models)
    local pool = GetGamePool('CObject')
    for _, entity in ipairs(pool) do
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            for _, block in ipairs(models) do
                if model == block and #(GetEntityCoords(entity) - center) <= radius then
                    SetEntityVisible(entity, false, false)
                    SetEntityCollision(entity, false, false)
                    FreezeEntityPosition(entity, true)
                end
            end
        end
    end
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
    local radius = door.radius or 5.0
    local models = door.models or (door.model and { door.model } or {})

    requestCollision(c)

    local bestObj, bestModel, bestDist = 0, nil, radius + 1.0
    for _, model in ipairs(models) do
        unlockLegacyDoor(model, c, door.heading)
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, model, false, false, false)
        if obj and obj ~= 0 then
            local dist = #(GetEntityCoords(obj) - c)
            if dist < bestDist then
                bestDist = dist
                bestObj = obj
                bestModel = model
            end
        end
    end

    if bestObj == 0 or not bestModel then return end

    local oc = GetEntityCoords(bestObj)
    local oh = door.heading or GetEntityHeading(bestObj)

    FreezeEntityPosition(bestObj, false)
    SetEntityCanBeDamaged(bestObj, false)
    SetEntityCollision(bestObj, true, true)
    SetEntityHeading(bestObj, oh)

    local dh = joaat(('%s_%s'):format(prefix, index))
    pcall(function()
        if IsDoorRegisteredWithSystem(dh) then
            RemoveDoorFromSystem(dh)
        end
    end)
    AddDoorToSystem(dh, bestModel, oc.x, oc.y, oc.z, false, false, false)
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
        ONEIL_CENTER,
        vec3(2435.81, 4975.95, 46.57),
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
    pinInteriorAt(ONEIL_CENTER, 'farmhouse')
    suppressOneilMloInterior()
    stripBlockingModels(ONEIL_CENTER, 55.0, ONEIL_BLOCK_MODELS)
    unlockOneilDoors()
end

local function setupLostClubhouse(interiorId)
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    enableInteriorProp(interiorId, 'walls_02', 8)
    enableInteriorProp(interiorId, 'Furnishings_02', 8)
    enableInteriorProp(interiorId, 'decorative_02')
    enableInteriorProp(interiorId, 'mural_03')
    enableInteriorProp(interiorId, 'lower_walls_default', 8)
    enableInteriorProp(interiorId, 'mod_booth')
    enableInteriorProp(interiorId, 'gun_locker')
    enableInteriorProp(interiorId, 'cash_small')
    enableInteriorProp(interiorId, 'id_small')
    enableInteriorProp(interiorId, 'weed_small')
    RefreshInterior(interiorId)
end

local function isLostMcInteriorReady()
    local clubhouseId = GetInteriorAtCoords(LOST_MC_CLUB_PROBE.x, LOST_MC_CLUB_PROBE.y, LOST_MC_CLUB_PROBE.z)
    if clubhouseId == 0 then
        clubhouseId = GetInteriorAtCoords(LOST_MC_ENTRANCE.x, LOST_MC_ENTRANCE.y, LOST_MC_ENTRANCE.z)
    end
    return clubhouseId ~= 0 and IsValidInterior(clubhouseId) and IsInteriorReady(clubhouseId)
end

local function loadLostMcClubhouse()
    RemoveIpl(VANILLA_BIKER_IPL)
    RequestIpl('gabz_biker_milo_')
    RequestIpl('lost_garage_milo_')

    requestCollision(LOST_MC_ENTRANCE)
    requestCollision(LOST_MC_CLUB_PROBE)

    local clubhouseId = waitInteriorAt(LOST_MC_CLUB_PROBE, 200)
    if clubhouseId == 0 then
        clubhouseId = waitInteriorAt(LOST_MC_ENTRANCE, 120)
    end

    if clubhouseId ~= 0 then
        setupLostClubhouse(clubhouseId)
    elseif GetResourceState('cfx-gabz-lost') == 'started' then
        pcall(function()
            exports['cfx-gabz-lost']:ReloadLostMc()
        end)
        clubhouseId = waitInteriorAt(LOST_MC_CLUB_PROBE, 120)
        if clubhouseId ~= 0 then
            setupLostClubhouse(clubhouseId)
        end
    end

    pinInteriorAt(LOST_MC_ENTRANCE)
    pinInteriorAt(LOST_MC_GARAGE_PROBE)

    hideDuplicateObjects(LOST_MC_ENTRANCE, 18.0, LOST_MC_VANILLA_DOOR_MODELS, LOST_MC_GABZ_DOOR_MODELS)
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
        local nearOneil = #(p - ONEIL_CENTER) < 95.0 or #(p - ONEIL_DOOR_PROBE) < 50.0
        local nearSimeon = #(p - SIMEON_CENTER) < 120.0
        local nearLost = #(p - LOST_MC_CENTER) < 120.0

        if nearOneil then
            removeIpls(ONEIL_DRUGLAB_IPLS)
            removeIpls(BURNT_FARM_IPLS)
            loadOneilFarmhouse()
            Wait(1500)
        elseif nearLost then
            RemoveIpl(VANILLA_BIKER_IPL)
            loadLostMcClubhouse()
            Wait(1500)
        elseif nearSimeon then
            loadSimeonShowroom()
            unlockSimeonDoors()
            Wait(1200)
        else
            Wait(3500)
        end
    end
end)

--- Vanilla biker IPL žaidimas vėl užkrauna šalia Lost MC — nuimame nuolat
CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        if #(p - LOST_MC_CENTER) < 150.0 then
            RemoveIpl(VANILLA_BIKER_IPL)
            hideDuplicateObjects(LOST_MC_ENTRANCE, 20.0, LOST_MC_VANILLA_DOOR_MODELS, LOST_MC_GABZ_DOOR_MODELS)
            Wait(750)
        else
            Wait(2500)
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

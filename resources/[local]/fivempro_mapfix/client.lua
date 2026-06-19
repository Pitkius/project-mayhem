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

local ONEIL_CENTER = vec3(2435.7107, 4975.8750, 46.5714)
local ONEIL_INTERIOR_PROBE = vec3(2453.229, 4965.452, 45.572)
local ONEIL_DOOR_PROBE = vec3(2452.2986, 4969.7222, 46.5716)

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
        radius = 6.0,
    },
    {
        coords = vec3(2435.7107, 4975.8750, 46.5714),
        heading = 231.8669,
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1`, `prop_farmhouse_door2` },
        radius = 6.0,
    },
    {
        coords = vec3(2441.50, 4981.85, 46.81),
        models = { `prop_ld_farm_door01`, `prop_farmhouse_door1` },
        radius = 5.0,
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

local LOST_MC_CENTER = vec3(981.5164, -102.9560, 74.8505)
local LOST_MC_ENTRANCE = vec3(981.5164, -102.9560, 74.8505)
local LOST_MC_CLUB_PROBE = vec3(994.4787, -122.9949, 73.11467)
local LOST_MC_GARAGE_PROBE = vec3(972.16, -118.05, 74.35)
local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'

local LOST_MC_DOORS = {
    {
        coords = vec3(981.5164, -102.9560, 74.8505),
        heading = 70.7127,
        models = { `lost_mc_door_01`, `lost_mc_gate`, `v_ilev_lostdoor`, `prop_lrggate_01_l` },
        radius = 8.0,
    },
    {
        coords = vec3(982.6339, -104.7095, 74.8488),
        heading = 30.8738,
        models = { `lost_mc_door_01`, `v_ilev_lostdoor`, `lost_mc_gate` },
        radius = 6.0,
    },
}

local LOST_MC_STREAM_POINTS = {
    LOST_MC_ENTRANCE,
    LOST_MC_CLUB_PROBE,
    LOST_MC_GARAGE_PROBE,
    vec3(994.4787, -122.9949, 73.11467),
}

local ONEIL_STREAM_POINTS = {
    ONEIL_CENTER,
    ONEIL_DOOR_PROBE,
    ONEIL_INTERIOR_PROBE,
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
end

local function forceStreamAt(coords, radius)
    radius = radius or 70.0
    requestCollision(coords)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)

    if NewLoadSceneStartSphere then
        NewLoadSceneStartSphere(coords.x, coords.y, coords.z, radius, 0)
        local deadline = GetGameTimer() + 7000
        while GetGameTimer() < deadline do
            requestCollision(coords)
            if IsNewLoadSceneLoaded and IsNewLoadSceneLoaded() then
                break
            end
            Wait(0)
        end
        if NewLoadSceneStop then
            NewLoadSceneStop()
        end
    else
        local deadline = GetGameTimer() + 2000
        while GetGameTimer() < deadline do
            requestCollision(coords)
            Wait(0)
        end
    end
end

local function forceStreamPoints(points, radius)
    for _, coords in ipairs(points) do
        forceStreamAt(coords, radius)
    end
end

local function waitInteriorAt(coords, attempts, interiorType)
    attempts = attempts or 300
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

local function pinInteriorAt(coords, interiorType, attempts)
    local interiorId = waitInteriorAt(coords, attempts or 200, interiorType)
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

local function registerDoorSystem(prefix, index, model, coords, heading)
    if not model or not coords then return end
    local dh = joaat(('%s_%s'):format(prefix, index))
    pcall(function()
        if IsDoorRegisteredWithSystem(dh) then
            RemoveDoorFromSystem(dh)
        end
    end)
    AddDoorToSystem(dh, model, coords.x, coords.y, coords.z, false, false, false)
    DoorSystemSetDoorState(dh, 0, false, false)
    pcall(function() DoorSystemSetAutomaticDistance(dh, 50.0, false, false) end)
    pcall(function() DoorSystemSetAutomaticRate(dh, 1.0, false, false) end)
    pcall(function() DoorSystemSetOpenRatio(dh, 0.0, false, false) end)
    pcall(function() DoorSystemSetHoldOpen(dh, false) end)
    if heading then
        unlockLegacyDoor(model, coords, heading)
    end
end

local function unlockDoorEntry(door, prefix, index)
    local c = door.coords
    local radius = door.radius or 6.0
    local models = door.models or (door.model and { door.model } or {})
    local heading = door.heading

    requestCollision(c)

    local used = {}
    for _, model in ipairs(models) do
        unlockLegacyDoor(model, c, heading)
        registerDoorSystem(prefix, ('%s_m%s'):format(index, model), model, c, heading)
    end

    local pool = GetGamePool('CObject')
    for _, entity in ipairs(pool) do
        if not used[entity] and DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            for _, wanted in ipairs(models) do
                if model == wanted and #(GetEntityCoords(entity) - c) <= radius then
                    used[entity] = true
                    local oc = GetEntityCoords(entity)
                    FreezeEntityPosition(entity, false)
                    SetEntityCanBeDamaged(entity, false)
                    SetEntityCollision(entity, true, true)
                    registerDoorSystem(prefix, ('%s_p%s'):format(index, entity), model, oc, heading or GetEntityHeading(entity))
                end
            end
        end
    end
end

local function unlockDoorList(doors, prefix)
    for i, door in ipairs(doors) do
        unlockDoorEntry(door, prefix, i)
    end
end

local function stripBlockingModels(center, radius, models)
    local pool = GetGamePool('CObject')
    for _, entity in ipairs(pool) do
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            for _, block in ipairs(models) do
                if model == block and #(GetEntityCoords(entity) - center) <= radius then
                    SetEntityCollision(entity, false, false)
                    FreezeEntityPosition(entity, true)
                end
            end
        end
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
    for _, coords in ipairs(ONEIL_STREAM_POINTS) do
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

    forceStreamPoints(ONEIL_STREAM_POINTS, 80.0)

    pinInteriorAt(ONEIL_INTERIOR_PROBE, 'farmhouse', 300)
    pinInteriorAt(ONEIL_DOOR_PROBE, 'farmhouse', 200)
    pinInteriorAt(ONEIL_CENTER, 'farmhouse', 200)
    suppressOneilMloInterior()
    stripBlockingModels(ONEIL_CENTER, 60.0, ONEIL_BLOCK_MODELS)
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

local function purgeVanillaBikerIpl()
    RemoveIpl(VANILLA_BIKER_IPL)
end

local function loadLostMcClubhouse()
    purgeVanillaBikerIpl()
    Wait(100)

    RequestIpl('gabz_biker_milo_')
    RequestIpl('lost_garage_milo_')
    Wait(800)

    forceStreamPoints(LOST_MC_STREAM_POINTS, 90.0)
    purgeVanillaBikerIpl()

    local clubhouseId = waitInteriorAt(LOST_MC_CLUB_PROBE, 400)
    if clubhouseId == 0 then
        clubhouseId = waitInteriorAt(LOST_MC_ENTRANCE, 250)
    end

    if clubhouseId ~= 0 then
        setupLostClubhouse(clubhouseId)
    else
        print('^1[fivempro_mapfix]^7 Lost MC interjeras neužsikrovė — patikrink cfx-gabz-lost / mapdata.')
    end

    pinInteriorAt(LOST_MC_ENTRANCE, nil, 200)
    pinInteriorAt(LOST_MC_GARAGE_PROBE, nil, 150)
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
    if GetResourceState('druglabs') == 'started' then
        print('^1[fivempro_mapfix]^7 druglabs paleistas — O\'Neil sodyba gali turėti dvigubą koliziją. Naudok: stop druglabs')
    end
    while GetResourceState('cfx-gabz-lost') ~= 'started' do
        Wait(200)
    end
    Wait(1500)
    applyMapFixes()
end)

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local nearOneil = #(p - ONEIL_CENTER) < 100.0 or #(p - ONEIL_DOOR_PROBE) < 55.0
        local nearSimeon = #(p - SIMEON_CENTER) < 120.0
        local nearLost = #(p - LOST_MC_CENTER) < 130.0

        if nearOneil then
            removeIpls(ONEIL_DRUGLAB_IPLS)
            removeIpls(BURNT_FARM_IPLS)
            loadOneilFarmhouse()
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

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        if #(p - LOST_MC_CENTER) < 160.0 then
            purgeVanillaBikerIpl()
            Wait(500)
        else
            Wait(2500)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName()
        or resourceName == 'druglabs'
        or resourceName == 'cfx-gabz-lost'
        or resourceName == 'cfx-gabz-mapdata'
        or resourceName == 'fivempro_dealership' then
        Wait(1000)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(4000)
    applyMapFixes()
end)

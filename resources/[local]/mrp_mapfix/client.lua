--- O'Neil sodyba + Simeon showroom. Lost MC valdo `cfx-gabz-lost` (vengti dvigubo IPL).

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

local ONEIL_DOOR_PROBE = vec3(2452.2986, 4969.7222, 46.5716)
local ONEIL_INTERIOR_PROBE = vec3(2453.229, 4965.452, 45.572)
local ONEIL_CENTER = vec3(2435.7107, 4975.8750, 46.5714)
local ONEIL_INTERIOR_TYPE = 'farmhouse'

local ONEIL_DRUGLAB_IPLS = {
    'brown_amfsted_milo_',
    'brown_amfsted2_milo_',
    'brown_amfsted3_milo_',
    'brown_amfsted4_milo_',
}

local ONEIL_DRUGLAB_MODELS = {
    `brown_amfsted_shell`,
    `brown_amfsted_col`,
}

local ONEIL_DOORS = {
    { model = `prop_farmhouse_door1`, coords = vec3(2452.2986, 4969.7222, 46.5716), heading = 308.7976 },
    { model = `prop_farmhouse_door1`, coords = vec3(2452.55, 4970.03, 46.81), heading = 315.0 },
    { model = `prop_farmhouse_door1`, coords = vec3(2435.7107, 4975.8750, 46.5714), heading = 231.8669 },
    { model = `prop_ld_farm_door01`, coords = vec3(2435.29, 4975.52, 46.81), heading = 225.0 },
    { model = `prop_ld_farm_door01`, coords = vec3(2448.44, 4971.86, 46.81), heading = 135.0 },
    { model = `prop_gate_farm_03`, coords = vec3(2438.45, 4976.85, 46.81), heading = 225.0 },
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

local simeonPinnedId = nil
local lastSimeonFullReload = 0
local SIMEON_FULL_RELOAD_COOLDOWN_MS = 15000

--- Vape dangoraižis (sc1_29_motel · Davis)
local VAPE_SKYSCRAPER_ENTRANCE = vec4(370.0215, -1795.8375, 29.2295, 316.4124)
local VAPE_SKYSCRAPER_CENTER = vec3(370.0215, -1795.8375, 29.2295)
local VAPE_SKYSCRAPER_INTERIOR_TYPES = {
    'sc1_29_motel_shell_milo_',
    'sc1_29_shop_shell_milo_',
}

--- hid_weed_lab (Davis) — dekoratyvūs MLO vazonai prie džiovinimo stoties
local WEED_LAB_POT_CENTER = vec3(1144.5345, -1659.7990, 36.6147)
local WEED_LAB_POT_RADIUS = 10.0
local WEED_LAB_POT_MODELS = {
    `bkr_prop_weed_bucket_01a`,
    `bkr_prop_weed_med_01a`,
    `bkr_prop_weed_lrg_01a`,
    `prop_weed_02`,
    `prop_weed_01`,
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

local function waitInteriorAt(coords, interiorType, attempts)
    attempts = attempts or 200
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
    if interiorType then
        return GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
    end
    return GetInteriorAtCoords(coords.x, coords.y, coords.z)
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
    pcall(function()
        DoorSystemSetDoorState(door.model, 0, false, false)
    end)
end

local function unlockDoorList(doors)
    for _, door in ipairs(doors) do
        unlockDoor(door)
    end
end

local function hideOneilDruglabShells()
    for _, model in ipairs(ONEIL_DRUGLAB_MODELS) do
        pcall(function()
            CreateModelHide(ONEIL_CENTER.x, ONEIL_CENTER.y, ONEIL_CENTER.z, 80.0, model, true)
            CreateModelHide(ONEIL_DOOR_PROBE.x, ONEIL_DOOR_PROBE.y, ONEIL_DOOR_PROBE.z, 45.0, model, true)
        end)
    end
end

local function pinInteriorAt(coords, interiorType)
    if not coords then return false end
    requestCollision(coords)
    local interiorId = nil
    if interiorType and interiorType ~= '' then
        interiorId = GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
    end
    if not interiorId or interiorId == 0 then
        interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    end
    if interiorId and interiorId ~= 0 and IsValidInterior(interiorId) then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
        return true
    end
    return false
end

local function vapeSkyscraperProbes()
    local e = VAPE_SKYSCRAPER_ENTRANCE
    local h = math.rad(e.w or 0.0)
    return {
        vec3(e.x, e.y, e.z),
        vec3(e.x - math.sin(h) * 3.5, e.y + math.cos(h) * 3.5, e.z),
        vec3(e.x - math.sin(h) * 7.0, e.y + math.cos(h) * 7.0, e.z),
        vec3(356.20, -1800.96, 28.85),
    }
end

local function hideWeedLabDecorPots()
    local c = WEED_LAB_POT_CENTER
    for _, model in ipairs(WEED_LAB_POT_MODELS) do
        pcall(function()
            CreateModelHide(c.x, c.y, c.z, WEED_LAB_POT_RADIUS, model, true)
        end)
    end
end

local function purgeWeedLabDecorPots()
    local c = WEED_LAB_POT_CENTER
    local radiusSq = WEED_LAB_POT_RADIUS * WEED_LAB_POT_RADIUS
    for _, entity in ipairs(GetGamePool('CObject')) do
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            local model = GetEntityModel(entity)
            local isPotModel = false
            for _, potModel in ipairs(WEED_LAB_POT_MODELS) do
                if model == potModel then
                    isPotModel = true
                    break
                end
            end
            if isPotModel then
                local coords = GetEntityCoords(entity)
                local dx = coords.x - c.x
                local dy = coords.y - c.y
                local dz = coords.z - c.z
                if (dx * dx + dy * dy + dz * dz) <= radiusSq then
                    SetEntityAsMissionEntity(entity, true, true)
                    DeleteEntity(entity)
                end
            end
        end
    end
end

local function loadWeedLabInterior()
    requestCollision(WEED_LAB_POT_CENTER)
    hideWeedLabDecorPots()
    purgeWeedLabDecorPots()
end

local function loadVapeSkyscraper()
    for _, probe in ipairs(vapeSkyscraperProbes()) do
        requestCollision(probe)
    end

    for _, probe in ipairs(vapeSkyscraperProbes()) do
        for _, interiorType in ipairs(VAPE_SKYSCRAPER_INTERIOR_TYPES) do
            pinInteriorAt(probe, interiorType)
        end
        pinInteriorAt(probe, nil)
    end

    local interiorId = waitInteriorAt(VAPE_SKYSCRAPER_CENTER, VAPE_SKYSCRAPER_INTERIOR_TYPES[1], 120)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

local function getSimeonInteriorId()
    local id = GetInteriorAtCoords(SIMEON_INTERIOR_PROBE.x, SIMEON_INTERIOR_PROBE.y, SIMEON_INTERIOR_PROBE.z)
    if id and id ~= 0 then return id end
    return GetInteriorAtCoordsWithType(SIMEON_INTERIOR_PROBE.x, SIMEON_INTERIOR_PROBE.y, SIMEON_INTERIOR_PROBE.z, 'v_carshowroom')
end

local function isSimeonInteriorReady()
    local id = simeonPinnedId or getSimeonInteriorId()
    return id and id ~= 0 and IsValidInterior(id) and IsInteriorReady(id)
end

local function requestSimeonCollision()
    requestCollision(SIMEON_CENTER)
    requestCollision(SIMEON_INTERIOR_PROBE)
    requestCollision(vec3(-47.25, -1094.42, 26.42))
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

local function applySimeonInteriorState(interiorId)
    if not interiorId or interiorId == 0 then return end
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

--- Lengvas užtikrinimas (be entity set reset) — naudoti autosalone ir arti zonos.
local function ensureSimeonShowroom()
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')
    requestSimeonCollision()

    local interiorId = getSimeonInteriorId()
    if interiorId and interiorId ~= 0 and IsValidInterior(interiorId) then
        PinInteriorInMemory(interiorId)
        if not IsInteriorReady(interiorId) then
            LoadInterior(interiorId)
        end
        simeonPinnedId = interiorId
    end

    unlockDoorList(SIMEON_DOORS)
    return isSimeonInteriorReady()
end

local function loadSimeonShowroom(force)
    local now = GetGameTimer()
    if not force and isSimeonInteriorReady() and (now - lastSimeonFullReload) < SIMEON_FULL_RELOAD_COOLDOWN_MS then
        return ensureSimeonShowroom()
    end

    lastSimeonFullReload = now
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')
    requestSimeonCollision()

    local interiorId = getSimeonInteriorId()
    if not interiorId or interiorId == 0 then
        interiorId = waitInteriorAt(SIMEON_INTERIOR_PROBE, 'v_carshowroom', 80)
    end
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        applySimeonInteriorState(interiorId)
        simeonPinnedId = interiorId
    end

    unlockDoorList(SIMEON_DOORS)
    return isSimeonInteriorReady()
end

local function loadOneilFarmhouse()
    removeIpls(BURNT_FARM_IPLS)
    removeIpls(ONEIL_DRUGLAB_IPLS)
    hideOneilDruglabShells()
    requestIpls(VANILLA_FARM_EXTERIOR_IPLS)
    requestIpls(VANILLA_FARM_INTERIOR_IPLS)

    local probes = {
        ONEIL_CENTER,
        ONEIL_DOOR_PROBE,
        ONEIL_INTERIOR_PROBE,
        vec3(2452.55, 4970.03, 46.81),
        vec3(2448.44, 4971.86, 46.81),
        vec3(2453.5, 4966.0, 45.57),
    }
    for _, coords in ipairs(probes) do
        for dz = -1.0, 2.5, 0.5 do
            RequestCollisionAtCoord(coords.x, coords.y, coords.z + dz)
        end
    end

    local interiorId = waitInteriorAt(ONEIL_INTERIOR_PROBE, ONEIL_INTERIOR_TYPE, 300)
    if (not interiorId or interiorId == 0) then
        interiorId = waitInteriorAt(ONEIL_DOOR_PROBE, ONEIL_INTERIOR_TYPE, 120)
    end
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end

    unlockDoorList(ONEIL_DOORS)
end

local function applyMapFixes()
    loadSimeonShowroom()
    loadOneilFarmhouse()
    loadVapeSkyscraper()
    loadWeedLabInterior()
end

exports('ReloadSimeonShowroom', function()
    return loadSimeonShowroom(true)
end)
exports('EnsureSimeonShowroom', ensureSimeonShowroom)
exports('IsSimeonShowroomReady', isSimeonInteriorReady)
exports('ReloadOneilFarmhouse', loadOneilFarmhouse)
exports('ReloadVapeSkyscraper', loadVapeSkyscraper)
exports('ReloadWeedLabInterior', loadWeedLabInterior)
exports('ReloadLostMc', function()
    if GetResourceState('cfx-gabz-lost') == 'started' then
        pcall(function()
            exports['cfx-gabz-lost']:ReloadLostMc()
        end)
    end
end)
exports('ApplyMapFixes', applyMapFixes)

CreateThread(function()
    if GetResourceState('druglabs') == 'started' then
        print('^1[mrp_mapfix]^7 druglabs paleistas — O\'Neil gali turėti dvigubą koliziją. Naudok: stop druglabs')
    end
    Wait(3000)
    applyMapFixes()
end)

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local nearOneil = #(p - ONEIL_CENTER) < 100.0 or #(p - ONEIL_DOOR_PROBE) < 55.0
        local nearSimeon = #(p - SIMEON_CENTER) < 120.0
        local nearVapeSkyscraper = #(p - VAPE_SKYSCRAPER_CENTER) < 120.0
        local nearWeedLab = #(p - WEED_LAB_POT_CENTER) < 80.0

        if nearOneil then
            removeIpls(ONEIL_DRUGLAB_IPLS)
            removeIpls(BURNT_FARM_IPLS)
            loadOneilFarmhouse()
            Wait(2500)
        elseif nearSimeon then
            if not isSimeonInteriorReady() then
                loadSimeonShowroom(false)
            else
                ensureSimeonShowroom()
            end
            Wait(4000)
        elseif nearVapeSkyscraper then
            loadVapeSkyscraper()
            Wait(2000)
        elseif nearWeedLab then
            loadWeedLabInterior()
            Wait(2500)
        else
            Wait(3500)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName()
        or resourceName == 'druglabs'
        or resourceName == 'mrp_dealership'
        or resourceName == 'sc1_29_motel'
        or resourceName == 'cfx-gabz-lost'
        or resourceName == 'cfx-gabz-mapdata'
        or resourceName == 'hid_weed_lab' then
        Wait(1000)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(4000)
    applyMapFixes()
end)

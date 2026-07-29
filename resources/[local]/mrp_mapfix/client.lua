--- O'Neil sodyba + Simeon showroom + Madrazo (La Fuente Blanca) durys.
--- Lost MC valdo `cfx-gabz-lost` (vengti dvigubo IPL).

-- Burnt story-mission shell + interior cap (blocks doors when left active).
local BLOCKING_FARM_IPLS = {
    'farm_burnt',
    'farm_burnt_props',
    'farm_burnt_lod',
    'farm_burnt_props2',
    'farmint_cap', -- MUST stay removed; requesting it seals the farmhouse
}

local VANILLA_FARM_EXTERIOR_IPLS = {
    'farm',
    'farm_lod',
    'farm_props',
    'des_farmhouse',
}

-- Intact interior only (matches bob74_ipl). Do NOT request farmint_cap here.
local VANILLA_FARM_INTERIOR_IPLS = {
    'farmint',
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

--- Martin Madrazo / La Fuente Blanca ranch (vanilla — durys užrakintos default)
local MADRAZO_CENTER = vec3(1395.0, 1142.0, 114.5)
local MADRAZO_INTERIOR_PROBE = vec3(1399.5, 1148.5, 114.3)
local MADRAZO_DOORS = {
    -- Pagrindinis įėjimas (dvigubos)
    { model = `v_ilev_ra_door4l`, coords = vec3(1395.920, 1142.904, 114.700) },
    { model = `v_ilev_ra_door4r`, coords = vec3(1395.919, 1140.704, 114.790) },
    -- Stiklinės šoninės
    { model = `v_ilev_ra_door1_l`, coords = vec3(1399.85, 1128.18, 114.48) },
    { model = `v_ilev_ra_door1_r`, coords = vec3(1401.05, 1128.18, 114.48) },
    -- Stiklinės priekinės / kiemo
    { model = `v_ilev_ra_door1_l`, coords = vec3(1390.20, 1131.55, 114.48) },
    { model = `v_ilev_ra_door1_r`, coords = vec3(1390.20, 1132.85, 114.48) },
    -- Extra dažni Madrazo/LFB propai (jei yra mapoje)
    { model = `v_ilev_ra_door2`, coords = vec3(1408.15, 1144.10, 114.48) },
    { model = `v_ilev_ra_door2`, coords = vec3(1408.15, 1165.50, 114.48) },
    { model = `v_ilev_ra_doors2`, coords = vec3(1390.50, 1163.40, 114.48) },
    { model = `prop_ld_garaged_01`, coords = vec3(1412.55, 1118.80, 114.80) },
    { model = `prop_facgate_07`, coords = vec3(1356.80, 1147.20, 113.80) },
    { model = `prop_gate_cult_01_l`, coords = vec3(1480.50, 1129.80, 114.50) },
    { model = `prop_gate_cult_01_r`, coords = vec3(1487.50, 1129.80, 114.50) },
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

local madrazoDoorSysIds = {}

local function unlockDoor(door)
    if not door or not door.model or not door.coords then return end
    local c = door.coords
    pcall(function()
        SetStateOfClosestDoorOfType(
            door.model,
            c.x, c.y, c.z,
            false,
            door.heading or 0.0,
            false
        )
    end)
    -- Door system (MP-safe): unique id per model+coords
    pcall(function()
        local key = ('%s_%.2f_%.2f_%.2f'):format(door.model, c.x, c.y, c.z)
        local sysId = madrazoDoorSysIds[key]
        if not sysId then
            sysId = joaat(key)
            madrazoDoorSysIds[key] = sysId
            if not IsDoorRegisteredWithSystem(sysId) then
                AddDoorToSystem(sysId, door.model, c.x, c.y, c.z, false, false, false)
            end
        end
        DoorSystemSetDoorState(sysId, 0, false, false) -- 0 = unlocked / free
        DoorSystemSetOpenRatio(sysId, 0.0, false, false)
    end)
    -- Unfreeze physical door prop (vanilla Madrazo often frozen shut)
    pcall(function()
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.5, door.model, false, false, false)
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            FreezeEntityPosition(obj, false)
        end
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

local oneilPinnedId = nil
local lastOneilFullReload = 0
local ONEIL_FULL_RELOAD_COOLDOWN_MS = 45000

local madrazoPinnedId = nil
local lastMadrazoFullReload = 0
local MADRAZO_FULL_RELOAD_COOLDOWN_MS = 45000

local function requestIplIfNeeded(ipl)
    if not IsIplActive(ipl) then
        RequestIpl(ipl)
    end
end

local function removeIplIfActive(ipl)
    if IsIplActive(ipl) then
        RemoveIpl(ipl)
    end
end

local function isOneilInteriorReady()
    local id = GetInteriorAtCoords(ONEIL_INTERIOR_PROBE.x, ONEIL_INTERIOR_PROBE.y, ONEIL_INTERIOR_PROBE.z)
    if not id or id == 0 then
        id = GetInteriorAtCoordsWithType(
            ONEIL_INTERIOR_PROBE.x, ONEIL_INTERIOR_PROBE.y, ONEIL_INTERIOR_PROBE.z,
            ONEIL_INTERIOR_TYPE
        )
    end
    if not id or id == 0 then
        id = GetInteriorAtCoords(ONEIL_DOOR_PROBE.x, ONEIL_DOOR_PROBE.y, ONEIL_DOOR_PROBE.z)
    end
    return id and id ~= 0 and IsValidInterior(id) and IsInteriorReady(id)
end

--- Soft keep-alive: no RefreshInterior (flashina jei kartojama)
local function ensureOneilFarmhouse()
    for _, ipl in ipairs(BLOCKING_FARM_IPLS) do removeIplIfActive(ipl) end
    for _, ipl in ipairs(ONEIL_DRUGLAB_IPLS) do removeIplIfActive(ipl) end
    hideOneilDruglabShells()
    for _, ipl in ipairs(VANILLA_FARM_EXTERIOR_IPLS) do requestIplIfNeeded(ipl) end
    for _, ipl in ipairs(VANILLA_FARM_INTERIOR_IPLS) do requestIplIfNeeded(ipl) end
    removeIplIfActive('farmint_cap')

    local id = GetInteriorAtCoords(ONEIL_INTERIOR_PROBE.x, ONEIL_INTERIOR_PROBE.y, ONEIL_INTERIOR_PROBE.z)
    if not id or id == 0 then
        id = GetInteriorAtCoordsWithType(
            ONEIL_INTERIOR_PROBE.x, ONEIL_INTERIOR_PROBE.y, ONEIL_INTERIOR_PROBE.z,
            ONEIL_INTERIOR_TYPE
        )
    end
    if id and id ~= 0 and IsValidInterior(id) then
        PinInteriorInMemory(id)
        if not IsInteriorReady(id) then
            LoadInterior(id)
        end
        oneilPinnedId = id
    end

    unlockDoorList(ONEIL_DOORS)
    return isOneilInteriorReady()
end

local function isMadrazoInteriorReady()
    local id = GetInteriorAtCoords(MADRAZO_INTERIOR_PROBE.x, MADRAZO_INTERIOR_PROBE.y, MADRAZO_INTERIOR_PROBE.z)
    if not id or id == 0 then
        id = GetInteriorAtCoords(MADRAZO_CENTER.x, MADRAZO_CENTER.y, MADRAZO_CENTER.z)
    end
    return id and id ~= 0 and IsValidInterior(id) and IsInteriorReady(id)
end

local function ensureMadrazoRanch()
    local id = GetInteriorAtCoords(MADRAZO_INTERIOR_PROBE.x, MADRAZO_INTERIOR_PROBE.y, MADRAZO_INTERIOR_PROBE.z)
    if not id or id == 0 then
        id = GetInteriorAtCoords(MADRAZO_CENTER.x, MADRAZO_CENTER.y, MADRAZO_CENTER.z)
    end
    if id and id ~= 0 and IsValidInterior(id) then
        PinInteriorInMemory(id)
        if not IsInteriorReady(id) then
            LoadInterior(id)
        end
        madrazoPinnedId = id
    end
    unlockDoorList(MADRAZO_DOORS)
    return isMadrazoInteriorReady()
end

local function loadOneilFarmhouse(force)
    local now = GetGameTimer()
    if not force and isOneilInteriorReady() and (now - lastOneilFullReload) < ONEIL_FULL_RELOAD_COOLDOWN_MS then
        return ensureOneilFarmhouse()
    end

    lastOneilFullReload = now
    removeIpls(BLOCKING_FARM_IPLS)
    removeIpls(ONEIL_DRUGLAB_IPLS)
    hideOneilDruglabShells()
    requestIpls(VANILLA_FARM_EXTERIOR_IPLS)
    requestIpls(VANILLA_FARM_INTERIOR_IPLS)
    RemoveIpl('farmint_cap')

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

    local interiorId = waitInteriorAt(ONEIL_INTERIOR_PROBE, ONEIL_INTERIOR_TYPE, 120)
    if (not interiorId or interiorId == 0) then
        interiorId = waitInteriorAt(ONEIL_DOOR_PROBE, ONEIL_INTERIOR_TYPE, 60)
    end
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        -- Refresh only on forced/full load (causes flicker if repeated)
        RefreshInterior(interiorId)
        oneilPinnedId = interiorId
    end

    unlockDoorList(ONEIL_DOORS)
    return isOneilInteriorReady()
end

local function loadMadrazoRanch(force)
    local now = GetGameTimer()
    if not force and isMadrazoInteriorReady() and (now - lastMadrazoFullReload) < MADRAZO_FULL_RELOAD_COOLDOWN_MS then
        return ensureMadrazoRanch()
    end

    lastMadrazoFullReload = now
    requestCollision(MADRAZO_CENTER)
    requestCollision(MADRAZO_INTERIOR_PROBE)
    for _, door in ipairs(MADRAZO_DOORS) do
        RequestCollisionAtCoord(door.coords.x, door.coords.y, door.coords.z)
    end

    local interiorId = waitInteriorAt(MADRAZO_INTERIOR_PROBE, nil, 40)
    if (not interiorId or interiorId == 0) then
        interiorId = waitInteriorAt(MADRAZO_CENTER, nil, 20)
    end
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
        madrazoPinnedId = interiorId
    end

    unlockDoorList(MADRAZO_DOORS)
    return isMadrazoInteriorReady()
end

local function applyMapFixes()
    loadSimeonShowroom(true)
    loadOneilFarmhouse(true)
    loadVapeSkyscraper()
    loadMadrazoRanch(true)
end

exports('ReloadSimeonShowroom', function()
    return loadSimeonShowroom(true)
end)
exports('EnsureSimeonShowroom', ensureSimeonShowroom)
exports('IsSimeonShowroomReady', isSimeonInteriorReady)
exports('ReloadOneilFarmhouse', function()
    return loadOneilFarmhouse(true)
end)
exports('EnsureOneilFarmhouse', ensureOneilFarmhouse)
exports('ReloadMadrazoRanch', function()
    return loadMadrazoRanch(true)
end)
exports('EnsureMadrazoRanch', ensureMadrazoRanch)
exports('ReloadVapeSkyscraper', loadVapeSkyscraper)
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
        print('^2[mrp_mapfix]^7 druglabs active (O\'Neil archived — La Mesa/Port OK)')
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
        local nearMadrazo = #(p - MADRAZO_CENTER) < 120.0

        if nearOneil then
            -- Soft maintain only — full RefreshInterior caused interior flash every few seconds
            if not isOneilInteriorReady() then
                loadOneilFarmhouse(true)
            else
                ensureOneilFarmhouse()
            end
            Wait(4000)
        elseif nearMadrazo then
            if not isMadrazoInteriorReady() then
                loadMadrazoRanch(true)
            else
                ensureMadrazoRanch()
            end
            Wait(3000)
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
        else
            Wait(3500)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName()
        or resourceName == 'druglabs'
        or resourceName == 'bob74_ipl'
        or resourceName == 'mrp_dealership'
        or resourceName == 'sc1_29_motel'
        or resourceName == 'cfx-gabz-lost'
        or resourceName == 'cfx-gabz-mapdata' then
        Wait(1000)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(4000)
    applyMapFixes()
end)

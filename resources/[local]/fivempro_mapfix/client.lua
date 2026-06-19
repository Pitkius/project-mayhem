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

--- O'Neil sodybos durys (vanilla prop_ld_farm_door01)
local ONEIL_DOORS = {
    { model = `prop_ld_farm_door01`, coords = vec3(2435.78, 4975.82, 46.81) },
    { model = `prop_ld_farm_door01`, coords = vec3(2441.50, 4981.85, 46.81) },
    { model = `prop_ld_farm_door01`, coords = vec3(2452.70, 4969.31, 46.57) },
}

local SIMEON_CENTER = vec3(-47.59, -1115.42, 26.43)
local SIMEON_INTERIOR_PROBE = vec3(-38.62, -1099.01, 27.31)
local SIMEON_STYLE_PROPS = { 'csr_beforeMission', 'csr_inMission', 'csr_afterMissionA', 'csr_afterMissionB' }
local SIMEON_SHUTTER_PROPS = { 'shutter_open', 'shutter_closed' }

--- Simiono / Premium Deluxe Motorsport durys ir garažo vartai
local SIMEON_DOORS = {
    { model = `v_ilev_csr_door_l`, coords = vec3(-32.64, -1108.55, 26.57) },
    { model = `v_ilev_csr_door_r`, coords = vec3(-31.72, -1108.55, 26.57) },
    { model = `prop_com_gar_door_01`, coords = vec3(-40.18, -1094.71, 27.26) },
    { model = `prop_com_gar_door_01`, coords = vec3(-37.86, -1094.71, 27.26) },
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

local function pinInteriorAt(coords)
    local interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
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

local function unlockDoorList(doors, prefix)
    for i, door in ipairs(doors) do
        local c = door.coords
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 3.0, door.model, false, false, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, false)
            SetEntityCanBeDamaged(obj, false)
            SetEntityCollision(obj, true, true)
        end

        local dh = joaat(('%s_%s'):format(prefix, i))
        local ok, reg = pcall(function()
            return IsDoorRegisteredWithSystem(dh)
        end)
        if not ok or not reg then
            AddDoorToSystem(dh, door.model, c.x, c.y, c.z, false, false, false)
        end
        DoorSystemSetDoorState(dh, 0, false, false)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 30.0, false, false) end)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, false, false) end)
    end
end

local function unlockSimeonDoors()
    unlockDoorList(SIMEON_DOORS, 'simeon_csr')
end

local function unlockOneilDoors()
    unlockDoorList(ONEIL_DOORS, 'oneil_farm')
end

local function suppressOneilMloInterior()
    local interiorId = GetInteriorAtCoords(ONEIL_INTERIOR_PROBE.x, ONEIL_INTERIOR_PROBE.y, ONEIL_INTERIOR_PROBE.z)
    if not interiorId or interiorId == 0 then return end

    local sets = { 'brown_amfsted', 'amfsted', 'methlab', 'drug', 'lab' }
    for _, setName in ipairs(sets) do
        disableInteriorEntitySet(interiorId, setName)
    end
    RefreshInterior(interiorId)
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

--- O'Neil sodyba — tik vanilla farm (druglabs build4 išjungtas / išarchyvuotas).
local function loadOneilFarmhouse()
    removeIpls(BURNT_FARM_IPLS)
    requestIpls(VANILLA_FARM_EXTERIOR_IPLS)
    requestIpls(VANILLA_FARM_INTERIOR_IPLS)
    pinInteriorAt(ONEIL_INTERIOR_PROBE)
    suppressOneilMloInterior()
    unlockOneilDoors()
end

local function loadLostMcFallback()
    if GetResourceState('cfx-gabz-lost') ~= 'started' then return end
    pcall(function()
        exports['cfx-gabz-lost']:ReloadLostMc()
    end)
end

local function applyMapFixes()
    loadSimeonShowroom()
    loadOneilFarmhouse()
    loadLostMcFallback()
end

exports('ReloadSimeonShowroom', loadSimeonShowroom)
exports('ReloadOneilFarmhouse', loadOneilFarmhouse)
exports('ApplyMapFixes', applyMapFixes)

CreateThread(function()
    Wait(1000)
    applyMapFixes()
end)

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local nearOneil = #(p - ONEIL_CENTER) < 80.0
        local nearSimeon = #(p - SIMEON_CENTER) < 120.0
        if nearOneil then
            loadOneilFarmhouse()
            unlockOneilDoors()
            Wait(1500)
        elseif nearSimeon then
            loadSimeonShowroom()
            unlockSimeonDoors()
            Wait(1500)
        else
            Wait(4000)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'druglabs' or resourceName == 'fivempro_dealership' then
        Wait(500)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    applyMapFixes()
end)

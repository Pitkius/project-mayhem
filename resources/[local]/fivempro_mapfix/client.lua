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

local ONEIL_INTERIOR_PROBE = vec3(2453.229, 4965.452, 45.572)

--- O'Neil sodybos durys (vanilla prop_ld_farm_door01)
local ONEIL_DOORS = {
    { model = `prop_ld_farm_door01`, coords = vec3(2435.78, 4975.82, 46.81) },
    { model = `prop_ld_farm_door01`, coords = vec3(2441.50, 4981.85, 46.81) },
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
    if not interiorId or interiorId == 0 then return end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    RefreshInterior(interiorId)
end

local function unlockOneilDoors()
    for i, door in ipairs(ONEIL_DOORS) do
        local c = door.coords
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.5, door.model, false, false, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, false)
            SetEntityCanBeDamaged(obj, false)
        end

        local dh = joaat(('oneil_farm_%s'):format(i))
        local ok, reg = pcall(function()
            return IsDoorRegisteredWithSystem(dh)
        end)
        if not ok or not reg then
            AddDoorToSystem(dh, door.model, c.x, c.y, c.z, false, false, false)
        end
        DoorSystemSetDoorState(dh, 0, false, false)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 25.0, false, false) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
    end
end

local function loadSimionShowroom()
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')
    pinInteriorAt(vec3(-47.59, -1115.42, 26.43))
end

--- druglabs build4 keičia O'Neil išorę (id2_15) — vanilla farm IPL sukuria antrą interjerą ir užrakina duris.
local function loadOneilFarmhouse()
    removeIpls(BURNT_FARM_IPLS)

    if GetResourceState('druglabs') == 'started' then
        removeIpls(VANILLA_FARM_EXTERIOR_IPLS)
        requestIpls(VANILLA_FARM_INTERIOR_IPLS)
    else
        requestIpls(VANILLA_FARM_EXTERIOR_IPLS)
        requestIpls(VANILLA_FARM_INTERIOR_IPLS)
    end

    pinInteriorAt(ONEIL_INTERIOR_PROBE)
    unlockOneilDoors()
end

local function loadLostMcFallback()
    if GetResourceState('cfx-gabz-lost') ~= 'started' then return end
    pcall(function()
        exports['cfx-gabz-lost']:ReloadLostMc()
    end)
end

local function applyMapFixes()
    loadSimionShowroom()
    loadOneilFarmhouse()
    loadLostMcFallback()
end

CreateThread(function()
    Wait(1000)
    applyMapFixes()
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local nearOneil = #(p - vec3(2435.61, 4975.78, 46.57)) < 80.0
        if nearOneil then
            unlockOneilDoors()
            Wait(1500)
        else
            Wait(4000)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'druglabs' then
        Wait(500)
        applyMapFixes()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    applyMapFixes()
end)

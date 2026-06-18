local function loadSimionShowroom()
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')

    local interiorId = GetInteriorAtCoords(-47.59, -1115.42, 26.43)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

--- O'Neil sodyba (Grapeseed) — vanilla interjeras, ne sudegęs variantas
local function loadOneilFarmhouse()
    RemoveIpl('farm_burnt')
    RemoveIpl('farm_burnt_props')
    RemoveIpl('farm_burnt_lod')
    RemoveIpl('farm_burnt_props2')

    RequestIpl('farm')
    RequestIpl('farmint')
    RequestIpl('farm_lod')
    RequestIpl('farm_props')
    RequestIpl('des_farmhouse')
    RequestIpl('farmint_cap')

    local interiorId = GetInteriorAtCoords(2453.229, 4965.452, 45.572)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

local function loadLostMcFallback()
    if GetResourceState('cfx-gabz-lost') ~= 'started' then return end
    local ok, fn = pcall(function()
        return exports['cfx-gabz-lost']:ReloadLostMc()
    end)
    if not ok or not fn then return end
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

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(500)
    applyMapFixes()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    applyMapFixes()
end)

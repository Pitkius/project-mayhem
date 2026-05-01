local function loadSimionShowroom()
    -- Premium Deluxe Motorsport / Simeon showroom area
    RequestIpl('shr_int')
    RequestIpl('shr_int_lod')

    local interiorId = GetInteriorAtCoords(-47.59, -1115.42, 26.43)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

CreateThread(function()
    Wait(1000)
    loadSimionShowroom()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(500)
    loadSimionShowroom()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    loadSimionShowroom()
end)

--- Kai kurie REH auto turi įaustus EU numerius — priverstinai GTA San Andreas plokštelė.
local GTA_PLATE_MODELS = {
    [`karincorolla`] = true,
    [`karincorollapolis`] = true,
}

local fixed = {}

local function applyGtaPlate(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local model = GetEntityModel(vehicle)
    if not GTA_PLATE_MODELS[model] then
        return false
    end

    SetVehicleNumberPlateTextIndex(vehicle, 1)
    fixed[vehicle] = true
    return true
end

local function fixWithRetries(vehicle)
    if fixed[vehicle] then return end
    CreateThread(function()
        for _ = 1, 15 do
            if not DoesEntityExist(vehicle) then return end
            if applyGtaPlate(vehicle) then return end
            Wait(100)
        end
    end)
end

AddEventHandler('gameEventTriggered', function(name, data)
    if name ~= 'CEventNetworkEntityCreated' then return end
    local entity = data[1]
    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then return end
    fixWithRetries(entity)
end)

CreateThread(function()
    while true do
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then fixWithRetries(veh) end
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    fixed = {}
end)

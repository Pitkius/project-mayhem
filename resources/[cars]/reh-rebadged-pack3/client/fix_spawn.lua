--- REH pack3: kai kurie auto kėbulą turi mod dalyse — be to spawn metu trūksta tekstūrų.
local SPAWN_FIXES = {
    [`benefactors600b`] = { slot = 8 },
    [`declasseimpala`] = { slot = 10 },
}

local fixed = {}

local function needsSpawnFix(model)
    return SPAWN_FIXES[model] ~= nil
end

local function ensureControl(vehicle)
    if NetworkHasControlOfEntity(vehicle) then return true end
    local deadline = GetGameTimer() + 2500
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    end
    return NetworkHasControlOfEntity(vehicle)
end

local function applySpawnFix(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local model = GetEntityModel(vehicle)
    local cfg = SPAWN_FIXES[model]
    if not cfg then
        return false
    end

    if not IsEntityAVehicle(vehicle) then
        return false
    end

    if not ensureControl(vehicle) then
        return false
    end

    SetVehicleModKit(vehicle, 0)

    local slot = cfg.slot
    local modCount = GetNumVehicleMods(vehicle, slot)
    if modCount > 0 and GetVehicleMod(vehicle, slot) < 0 then
        SetVehicleMod(vehicle, slot, 0, false)
    end

    local applied = GetVehicleMod(vehicle, slot) >= 0
    if applied then
        fixed[vehicle] = true
    end
    return applied
end

local function fixWithRetries(vehicle)
    if fixed[vehicle] then return end
    CreateThread(function()
        for _ = 1, 20 do
            if not DoesEntityExist(vehicle) then return end
            if applySpawnFix(vehicle) then return end
            Wait(150)
        end
    end)
end

local function scanNearbyFixedVehicles()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')

    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) and not fixed[veh] then
            if needsSpawnFix(GetEntityModel(veh)) then
                if #(coords - GetEntityCoords(veh)) < 100.0 then
                    fixWithRetries(veh)
                end
            end
        end
    end
end

AddEventHandler('gameEventTriggered', function(name, data)
    if name ~= 'CEventNetworkEntityCreated' then return end
    local entity = data[1]
    if not entity or entity == 0 then return end
    if GetEntityType(entity) ~= 2 then return end
    fixWithRetries(entity)
end)

CreateThread(function()
    while true do
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            fixWithRetries(veh)
        end
        scanNearbyFixedVehicles()
        Wait(400)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    fixed = {}
end)

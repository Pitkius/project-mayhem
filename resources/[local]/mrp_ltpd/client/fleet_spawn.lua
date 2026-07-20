--- Tarnybinio PD transporto spawn kliente (addon modeliai reikalauja RequestModel).
local QBCore = exports['qb-core']:GetCoreObject()

local function loadModel(modelName, timeoutMs)
    modelName = tostring(modelName or ''):lower()
    if modelName == '' then return nil, 'Nenurodytas modelis.' end

    local hash = joaat(modelName)
    if hash == 0 then return nil, ('Neteisingas modelis: %s'):format(modelName) end

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil, ('Modelis „%s“ neįkeltas — paleisk `ensure mrp_pd_mrpd`.'):format(modelName)
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 12000)
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > deadline then
            return nil, ('Nepavyko užkrauti „%s“ — bandyk dar kartą.'):format(modelName)
        end
    end
    return hash
end

local function finalizeFleetVehicle(veh, plate)
    if not veh or veh == 0 then return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    --- Lightbar: įjunk tik jei preferred extras visi off (ne enable-all — exclusive extras bug)
    local preferred = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
    local anyOn, first = false, nil
    for i = 1, #preferred do
        local id = preferred[i]
        if DoesExtraExist(veh, id) then
            if not first then first = id end
            if IsVehicleExtraTurnedOn(veh, id) then anyOn = true; break end
        end
    end
    if first and not anyOn then
        SetVehicleExtra(veh, first, 0)
    end
    if plate and plate ~= '' then
        SetVehicleNumberPlateText(veh, plate)
        if GetResourceState('mrp_plates') == 'started' then
            exports['mrp_plates']:ApplyPlateStyle(veh)
        end
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end

RegisterNetEvent('mrp_ltpd:client:spawnFleetVehicle', function(modelName, spawn, plate)
    if type(spawn) ~= 'table' then return end

    local hash, err = loadModel(modelName)
    if not hash then
        return QBCore.Functions.Notify(err or 'Modelis neprieinamas.', 'error')
    end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not veh or veh == 0 then
        return QBCore.Functions.Notify('Nepavyko sukurti transporto.', 'error')
    end

    finalizeFleetVehicle(veh, plate)
    QBCore.Functions.Notify('Transportas paruoštas.', 'success')
end)

RegisterNetEvent('mrp_ltpd:client:spawnFleetHeli', function(modelName, spawn, plate)
    if type(spawn) ~= 'table' then return end

    local hash, err = loadModel(modelName, 15000)
    if not hash then
        return QBCore.Functions.Notify(err or 'Modelis neprieinamas.', 'error')
    end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not veh or veh == 0 then
        return QBCore.Functions.Notify('Nepavyko sukurti sraigtasparnio.', 'error')
    end

    finalizeFleetVehicle(veh, plate)
    QBCore.Functions.Notify('Sraigtasparnis paruoštas.', 'success')
end)

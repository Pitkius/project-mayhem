local QBCore = exports['qb-core']:GetCoreObject()
local GARAGE_SPRITE = 357
local GARAGE_COLOR = 3
local GARAGE_SCALE = 0.75

local uiOpen = false
local previewVehicle = nil
local previewCam = nil
local previewSpawnGen = 0
local activeGarage = nil
local garagePreviewMods = {}
local garagePreviewFuel = {}

local function getVehicleDisplayName(model)
    local shared = QBCore.Shared.Vehicles[model]
    if shared and shared.name then
        return string.format('%s %s', shared.brand or '', shared.name)
    end
    return model
end

local function getVehicleStats(model)
    local hash = joaat(model)
    local maxSpeedMps = GetVehicleModelEstimatedMaxSpeed(hash)
    local accel = GetVehicleModelAcceleration(hash)
    local braking = GetVehicleModelMaxBraking(hash)
    local traction = GetVehicleModelMaxTraction(hash)
    local maxKmh = (tonumber(maxSpeedMps) or 0.0) * 3.6
    local zeroToHundred = 27.777 / math.max(0.1, (tonumber(accel) or 0.1) * 7.5)
    return {
        maxKmh = maxKmh,
        zeroToHundred = zeroToHundred,
        braking = math.max(0.0, math.min(1.0, tonumber(braking) or 0.0)),
        traction = math.max(0.0, math.min(1.0, tonumber(traction) or 0.0)),
    }
end

local function getImageUrl(model)
    return ('https://docs.fivem.net/vehicles/%s.webp'):format(model)
end

local function forceDeleteVehicleEntity(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetEntityAsMissionEntity(veh, true, true)
    local tries = 0
    while not NetworkHasControlOfEntity(veh) and tries < 40 do
        NetworkRequestControlOfEntity(veh)
        Wait(0)
        tries = tries + 1
    end
    SetVehicleAsNoLongerNeeded(veh)
    DeleteVehicle(veh)
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
    local waitLeft = 20
    while DoesEntityExist(veh) and waitLeft > 0 do
        Wait(0)
        waitLeft = waitLeft - 1
    end
end

local function safeDeletePreviewVehicle()
    if previewVehicle and previewVehicle ~= 0 then
        forceDeleteVehicleEntity(previewVehicle)
    end
    previewVehicle = nil
end

local function clearVehiclesNearGarageSpawn(radius)
    if not activeGarage or not activeGarage.spawn then return end
    local spawn = activeGarage.spawn
    local center = vector3(spawn.x, spawn.y, spawn.z)
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh and veh ~= 0 and DoesEntityExist(veh) and veh ~= playerVeh then
            if #(GetEntityCoords(veh) - center) <= radius then
                forceDeleteVehicleEntity(veh)
            end
        end
    end
end

local function ensureGaragePreviewCam(spawn)
    if not spawn then return end
    if previewCam and DoesCamExist(previewCam) then
        SetCamActive(previewCam, true)
        return
    end
    local rad = math.rad(spawn.w + 0.0)
    local dist = 7.2
    local cx = spawn.x - math.sin(rad) * dist
    local cy = spawn.y - math.cos(rad) * dist
    local cz = spawn.z + 1.28
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, cx, cy, cz)
    PointCamAtCoord(previewCam, spawn.x, spawn.y, spawn.z + 0.42, true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyPreviewCam()
    if previewCam and DoesCamExist(previewCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(previewCam, false)
    end
    previewCam = nil
end

local function spawnGaragePreviewVehicle(model, plate)
    if not model or model == '' or not activeGarage or not activeGarage.spawn then return end
    previewSpawnGen = previewSpawnGen + 1
    local gen = previewSpawnGen
    local spawn = activeGarage.spawn

    CreateThread(function()
        safeDeletePreviewVehicle()
        clearVehiclesNearGarageSpawn(4.0)
        Wait(0)
        if gen ~= previewSpawnGen then return end

        local hash = joaat(model)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) do
            Wait(0)
            timeout = timeout + 1
            if gen ~= previewSpawnGen then return end
            if timeout > 8000 then return end
        end
        if gen ~= previewSpawnGen then return end

        local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, false, false)
        if gen ~= previewSpawnGen then
            if veh and veh ~= 0 then forceDeleteVehicleEntity(veh) end
            return
        end

        if not veh or veh == 0 then
            SetModelAsNoLongerNeeded(hash)
            return
        end

        previewVehicle = veh
        SetEntityAsMissionEntity(previewVehicle, true, true)
        SetVehicleOnGroundProperly(previewVehicle)
        SetVehicleDirtLevel(previewVehicle, 0.0)
        SetVehicleEngineOn(previewVehicle, false, true, true)
        SetVehicleUndriveable(previewVehicle, true)
        FreezeEntityPosition(previewVehicle, true)

        local modsStr = plate and garagePreviewMods[plate]
        if modsStr and modsStr ~= '' then
            local ok, mods = pcall(json.decode, modsStr)
            if ok and mods and QBCore.Functions.SetVehicleProperties then
                QBCore.Functions.SetVehicleProperties(previewVehicle, mods)
            end
        end

        local fuel = plate and garagePreviewFuel[plate]
        if fuel ~= nil and SetVehicleFuelLevel then
            SetVehicleFuelLevel(previewVehicle, math.max(0.0, math.min(100.0, fuel + 0.0)) + 0.0)
        end

        SetModelAsNoLongerNeeded(hash)
        ensureGaragePreviewCam(spawn)
        if previewCam and DoesCamExist(previewCam) then
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
        end
    end)
end

local function buildGarageRows(vehicles, garageId)
    local rows = {}
    for _, v in ipairs(vehicles or {}) do
        local state = tonumber(v.state) or 0
        local g = tostring(v.garage or '')
        local canTake = (state == 1) and (g == garageId)
        local statusLabel = 'Lauke'
        if state == 1 then
            statusLabel = canTake and 'Šiame garaže' or 'Kitame garaže'
        end
        local st = getVehicleStats(v.model)
        rows[#rows + 1] = {
            model = v.model,
            plate = v.plate,
            displayName = getVehicleDisplayName(v.model),
            fuel = math.floor(math.max(0, math.min(100, tonumber(v.fuel) or 0)) + 0.5),
            state = state,
            statusLabel = statusLabel,
            canTakeOut = canTake,
            image = getImageUrl(v.model),
            stats = {
                maxKmh = math.floor(st.maxKmh + 0.5),
                zeroToHundred = math.floor(st.zeroToHundred * 10 + 0.5) / 10,
                braking = math.floor(st.braking * 100 + 0.5),
                traction = math.floor(st.traction * 100 + 0.5),
            },
        }
    end
    table.sort(rows, function(a, b) return (a.displayName or '') < (b.displayName or '') end)
    return rows
end

local function closeGarageUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    safeDeletePreviewVehicle()
    destroyPreviewCam()
    activeGarage = nil
    garagePreviewMods = {}
    garagePreviewFuel = {}
end

local function openGarageUi(garage)
    QBCore.Functions.TriggerCallback('fivempro_garages:server:getPlayerVehicles', function(vehicles)
        garagePreviewMods = {}
        garagePreviewFuel = {}
        for _, v in ipairs(vehicles or {}) do
            garagePreviewMods[v.plate] = v.mods
            garagePreviewFuel[v.plate] = tonumber(v.fuel) or 0.0
        end

        local rows = buildGarageRows(vehicles, garage.id)
        activeGarage = garage
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            payload = {
                title = garage.label,
                vehicles = rows,
            },
        })
    end, garage.id)
end

local function isSpawnClear(spawn)
    local pool = GetGamePool('CVehicle')
    local spawnPos = vector3(spawn.x, spawn.y, spawn.z)
    for i = 1, #pool do
        local veh = pool[i]
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - spawnPos) < 3.0 then
            return false
        end
    end
    return true
end

local function doGarageVehicleSpawn(data)
    if not data or not data.plate or not data.spawn or not data.garageId then return end
    if not isSpawnClear(data.spawn) then
        return QBCore.Functions.Notify('Spawn vieta užimta', 'error')
    end

    QBCore.Functions.TriggerCallback('fivempro_garages:server:spawnVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Nepavyko ištraukti mašinos', 'error')
        end

        local modelHash = joaat(result.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(0) end

        local veh = CreateVehicle(modelHash, data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, true, false)
        if not veh or veh == 0 then
            return QBCore.Functions.Notify('Nepavyko spawninti mašinos', 'error')
        end

        SetVehicleNumberPlateText(veh, result.plate)
        SetEntityAsMissionEntity(veh, true, true)
        if result.mods and result.mods ~= '' then
            local ok, mods = pcall(json.decode, result.mods)
            if ok and mods and QBCore.Functions.SetVehicleProperties then
                QBCore.Functions.SetVehicleProperties(veh, mods)
            end
        end
        TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        QBCore.Functions.Notify('Mašina ištraukta', 'success')
    end, data.plate, data.garageId)
end

RegisterNetEvent('fivempro_garages:client:openGarage', function(data)
    if not data or not data.garageId then return end
    for _, garage in ipairs(Config.Garages) do
        if garage.id == data.garageId then
            return openGarageUi(garage)
        end
    end
end)

RegisterNetEvent('fivempro_garages:client:spawnVehicle', function(data)
    doGarageVehicleSpawn(data)
end)

RegisterNetEvent('fivempro_garages:client:parkVehicle', function(data)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Tu nesi mašinoje', 'error')
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return QBCore.Functions.Notify('Tu turi būti vairuotojas', 'error')
    end

    local plate = QBCore.Functions.GetPlate(veh)
    local props = QBCore.Functions.GetVehicleProperties(veh)
    QBCore.Functions.TriggerCallback('fivempro_garages:server:parkVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Nepavyko pastatyti mašinos', 'error')
        end

        DeleteVehicle(veh)
        QBCore.Functions.Notify('Mašina pastatyta į garažą', 'success')
    end, plate, props, data.garageId)
end)

RegisterNUICallback('close', function(_, cb)
    closeGarageUi()
    cb('ok')
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    local plate = data and data.plate
    local model = data and data.model
    if plate and model and model ~= '' then
        spawnGaragePreviewVehicle(model, plate)
    end
    cb('ok')
end)

RegisterNUICallback('rotatePreview', function(data, cb)
    local dir = tonumber(data and data.dir) or 0
    if previewVehicle and DoesEntityExist(previewVehicle) and dir ~= 0 then
        local h = GetEntityHeading(previewVehicle)
        SetEntityHeading(previewVehicle, h + (dir * 8.0))
        if previewCam and DoesCamExist(previewCam) and activeGarage and activeGarage.spawn then
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
        end
    end
    cb('ok')
end)

RegisterNUICallback('takeOut', function(data, cb)
    local plate = data and data.plate
    if not plate or plate == '' or not activeGarage then
        cb('ok')
        return
    end

    local gId = activeGarage.id
    local spawn = activeGarage.spawn
    closeGarageUi()
    doGarageVehicleSpawn({ garageId = gId, spawn = spawn, plate = plate })
    cb('ok')
end)

local function createGarageMapBlips()
    if Config.UseSingleGarageMapBlip then
        local ref = Config.Garages[1]
        if not ref then return end
        local cx, cy, cz = ref.coords.x, ref.coords.y, ref.coords.z
        if Config.GarageMapBlipCoords then
            cx = Config.GarageMapBlipCoords.x
            cy = Config.GarageMapBlipCoords.y
            cz = Config.GarageMapBlipCoords.z
        end
        local blip = AddBlipForCoord(cx, cy, cz)
        SetBlipSprite(blip, GARAGE_SPRITE)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, GARAGE_SCALE)
        SetBlipColour(blip, GARAGE_COLOR)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.GarageMapBlipLabel or 'Garažai')
        EndTextCommandSetBlipName(blip)
        return
    end

    for _, garage in ipairs(Config.Garages) do
        local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
        SetBlipSprite(blip, GARAGE_SPRITE)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, GARAGE_SCALE)
        SetBlipColour(blip, GARAGE_COLOR)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(garage.label)
        EndTextCommandSetBlipName(blip)
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    createGarageMapBlips()

    for _, garage in ipairs(Config.Garages) do
        exports['qb-target']:AddBoxZone(('fivempro_garage_%s'):format(garage.id), garage.coords, 2.4, 2.4, {
            name = ('fivempro_garage_%s'):format(garage.id),
            heading = garage.heading,
            debugPoly = false,
            minZ = garage.coords.z - 1.0,
            maxZ = garage.coords.z + 2.0,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_garages:client:openGarage',
                    icon = 'fas fa-warehouse',
                    label = 'Atidaryti garažą',
                    garageId = garage.id
                },
                {
                    type = 'client',
                    event = 'fivempro_garages:client:parkVehicle',
                    icon = 'fas fa-square-parking',
                    label = 'Pastatyti mašiną',
                    garageId = garage.id
                },
            },
            distance = Config.TargetDistance
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeGarageUi()
end)

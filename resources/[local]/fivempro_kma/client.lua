local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local previewVehicle = nil
local previewCam = nil
local previewSpawnGen = 0
local activeLocation = nil
local kmaPreviewMods = {}
local kmaPreviewFuel = {}

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
end

local function safeDeletePreviewVehicle()
    if previewVehicle and previewVehicle ~= 0 then
        forceDeleteVehicleEntity(previewVehicle)
    end
    previewVehicle = nil
end

local function ensureKmaPreviewCam(spawn)
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

local function spawnKmaPreviewVehicle(model, plate)
    if not model or model == '' or not activeLocation or not activeLocation.preview then return end
    local spawn = activeLocation.preview

    previewSpawnGen = previewSpawnGen + 1
    local gen = previewSpawnGen

    CreateThread(function()
        safeDeletePreviewVehicle()
        Wait(0)
        if gen ~= previewSpawnGen then return end

        SetFocusPosAndVel(spawn.x, spawn.y, spawn.z, 0.0, 0.0, 0.0)
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)

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
        SetVehicleDirtLevel(previewVehicle, 0.0)
        SetVehicleEngineOn(previewVehicle, false, true, true)
        SetVehicleUndriveable(previewVehicle, true)
        FreezeEntityPosition(previewVehicle, true)

        local modsStr = plate and kmaPreviewMods[plate]
        if modsStr and modsStr ~= '' then
            local ok, mods = pcall(json.decode, modsStr)
            if ok and mods and QBCore.Functions.SetVehicleProperties then
                QBCore.Functions.SetVehicleProperties(previewVehicle, mods)
            end
        end

        local fuel = plate and kmaPreviewFuel[plate]
        if fuel ~= nil and SetVehicleFuelLevel then
            SetVehicleFuelLevel(previewVehicle, math.max(0.0, math.min(100.0, fuel + 0.0)) + 0.0)
        end

        SetModelAsNoLongerNeeded(hash)
        ensureKmaPreviewCam(spawn)
        PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
    end)
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

local function spawnReleasedVehicle(result)
    if not result or not result.model or not activeLocation then return end
    local spawn = activeLocation.spawn or activeLocation.preview
    if not spawn then return end

    if not isSpawnClear(spawn) then
        return QBCore.Functions.Notify('KMA spawn vieta uzimta, patrauk transporta priemone', 'error')
    end

    local modelHash = joaat(result.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(0) end

    local veh = CreateVehicle(modelHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    if not veh or veh == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return QBCore.Functions.Notify('Nepavyko spawninti masinos', 'error')
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, result.plate or '')
    if result.mods and result.mods ~= '' then
        local ok, mods = pcall(json.decode, result.mods)
        if ok and mods and QBCore.Functions.SetVehicleProperties then
            QBCore.Functions.SetVehicleProperties(veh, mods)
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
    TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end

local function buildKmaRows(vehicles)
    local rows = {}
    for _, v in ipairs(vehicles or {}) do
        local st = getVehicleStats(v.model)
        rows[#rows + 1] = {
            model = v.model,
            plate = v.plate,
            displayName = getVehicleDisplayName(v.model),
            fuel = math.floor(math.max(0, math.min(100, tonumber(v.fuel) or 0)) + 0.5),
            statusLabel = 'Lauke / konfiskuota',
            canReclaim = true,
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

local function closeKmaUi()
    if not uiOpen then return end
    previewSpawnGen = previewSpawnGen + 1
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    safeDeletePreviewVehicle()
    destroyPreviewCam()
    ClearFocus()
    kmaPreviewMods = {}
    kmaPreviewFuel = {}
    activeLocation = nil
end

local function openKmaUi(location)
    if not location then return end
    activeLocation = location
    QBCore.Functions.TriggerCallback('fivempro_kma:server:getVehicles', function(vehicles)
        kmaPreviewMods = {}
        kmaPreviewFuel = {}
        for _, v in ipairs(vehicles or {}) do
            kmaPreviewMods[v.plate] = v.mods
            kmaPreviewFuel[v.plate] = tonumber(v.fuel) or 0.0
        end

        local rows = buildKmaRows(vehicles)
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            payload = {
                title = location.label or 'KMA',
                fee = Config.Kma.fee,
                locationId = location.id,
                vehicles = rows,
            },
        })
    end)
end

RegisterNetEvent('fivempro_kma:client:forceCloseUi', function()
    closeKmaUi()
end)

RegisterNetEvent('fivempro_kma:client:openUi', function(data)
    local wantedId = data and data.locationId
    local selected = nil
    for _, loc in ipairs((Config.Kma and Config.Kma.locations) or {}) do
        if loc.id == wantedId then
            selected = loc
            break
        end
    end
    if not selected then
        selected = ((Config.Kma and Config.Kma.locations) or {})[1]
    end
    openKmaUi(selected)
end)

RegisterNUICallback('close', function(_, cb)
    closeKmaUi()
    cb('ok')
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    local plate = data and data.plate
    local model = data and data.model
    if plate and model and model ~= '' then
        spawnKmaPreviewVehicle(model, plate)
    end
    cb('ok')
end)

RegisterNUICallback('rotatePreview', function(data, cb)
    local dir = tonumber(data and data.dir) or 0
    if previewVehicle and DoesEntityExist(previewVehicle) and dir ~= 0 then
        local h = GetEntityHeading(previewVehicle)
        SetEntityHeading(previewVehicle, h + (dir * 8.0))
    end
    cb('ok')
end)

RegisterNUICallback('reclaim', function(data, cb)
    local plate = data and data.plate
    if not plate or plate == '' or not activeLocation then
        cb('ok')
        return
    end

    QBCore.Functions.TriggerCallback('fivempro_kma:server:reclaim', function(result)
        if not result or not result.ok then
            QBCore.Functions.Notify((result and result.message) or 'Nepavyko', 'error')
            cb('ok')
            return
        end
        spawnReleasedVehicle(result)
        QBCore.Functions.Notify(result.message or 'Masina atsiimta is KMA', 'success')
        closeKmaUi()
        cb('ok')
    end, plate, activeLocation.id)
end)

-- P (199) / ESC (200): NUI fokusas suvalgo įprastą keydown — uždarymui reikia šio client sriegio.
-- Tai ne susije su blipais ar zona; blipus keičiant nenaikink šio ciklo.
CreateThread(function()
    while true do
        if uiOpen and (IsControlJustPressed(0, 199) or IsControlJustPressed(0, 200)) then
            closeKmaUi()
        end
        Wait(0)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    for _, loc in ipairs((Config.Kma and Config.Kma.locations) or {}) do
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, Config.Kma.blipSprite or 225)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Kma.blipScale or 0.9)
        SetBlipColour(blip, Config.Kma.blipColor or 1)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.label or Config.Kma.blipLabel or 'KMA')
        EndTextCommandSetBlipName(blip)

        local size = Config.Kma.targetSize or vec3(2.2, 2.2, 2.2)
        exports['qb-target']:AddBoxZone(('fivempro_kma_%s'):format(loc.id), loc.coords, size.x, size.y, {
            name = ('fivempro_kma_%s'):format(loc.id),
            heading = loc.heading or 0.0,
            debugPoly = false,
            minZ = loc.coords.z - 1.0,
            maxZ = loc.coords.z + 2.0,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_kma:client:openUi',
                    icon = 'fas fa-car-burst',
                    label = 'KMA - atgauti masina',
                    locationId = loc.id
                },
            },
            distance = Config.Kma.targetDistance or 2.5,
        })
    end
end)

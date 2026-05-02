local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local previewVehicle = nil
local previewCam = nil
local previewSpawnGen = 0
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

local function clearVehiclesNearKmaSpawn(radius)
    local spawn = Config.Kma.preview
    if not spawn then return end
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
    if not model or model == '' then return end
    local spawn = Config.Kma.preview
    if not spawn then return end

    previewSpawnGen = previewSpawnGen + 1
    local gen = previewSpawnGen

    CreateThread(function()
        safeDeletePreviewVehicle()
        clearVehiclesNearKmaSpawn(4.0)
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

        local cWait = 0
        while not HasCollisionLoadedAroundEntity(previewVehicle) and cWait < 120 do
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            Wait(0)
            cWait = cWait + 1
        end
        SetVehicleOnGroundProperly(previewVehicle)

        ensureKmaPreviewCam(spawn)
        if previewCam and DoesCamExist(previewCam) then
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
        end
    end)
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
end

RegisterNetEvent('fivempro_kma:client:forceCloseUi', function()
    closeKmaUi()
end)

local function openKmaUi()
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
                title = Config.Kma.label,
                fee = Config.Kma.fee,
                vehicles = rows,
            },
        })
    end)
end

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
        if previewCam and DoesCamExist(previewCam) and Config.Kma.preview then
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
        end
    end
    cb('ok')
end)

RegisterNUICallback('reclaim', function(data, cb)
    local plate = data and data.plate
    if not plate or plate == '' then
        cb('ok')
        return
    end

    QBCore.Functions.TriggerCallback('fivempro_kma:server:reclaim', function(result)
        if not result or not result.ok then
            QBCore.Functions.Notify((result and result.message) or 'Nepavyko', 'error')
            cb('ok')
            return
        end

        QBCore.Functions.Notify(result.message or 'Mašina grąžinta į garažą', 'success')
        closeKmaUi()
        cb('ok')
    end, plate)
end)

CreateThread(function()
    local cfg = Config.Kma
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.blipSprite or 225)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.blipScale or 0.9)
    SetBlipColour(blip, cfg.blipColor or 1)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.blipLabel or 'KMA')
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local cfg = Config.Kma
    local pos = cfg.coords
    local size = cfg.targetSize or vec3(2.2, 2.2, 2.2)

    exports['qb-target']:AddBoxZone('fivempro_kma_desk', pos, size.x, size.y, {
        name = 'fivempro_kma_desk',
        heading = cfg.heading or 0.0,
        debugPoly = false,
        minZ = pos.z - 1.0,
        maxZ = pos.z + 2.0,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_kma:client:openUi',
                icon = 'fas fa-car-burst',
                label = 'KMA — atgauti mašiną',
            },
        },
        distance = cfg.targetDistance or 2.5,
    })
end)

RegisterNetEvent('fivempro_kma:client:openUi', function()
    openKmaUi()
end)

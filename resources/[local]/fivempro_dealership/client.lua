local QBCore = exports['qb-core']:GetCoreObject()

local catalog = nil
local DEALERSHIP_BLIP_SPRITE = 326
local DEALERSHIP_BLIP_COLOR = 3
local DEALERSHIP_BLIP_SCALE = 0.85
local uiOpen = false
local previewVehicle = nil
local previewCam = nil
local currentColorIdx = (Config.PreviewColors and Config.PreviewColors[1] and Config.PreviewColors[1].idx) or 111
local selectedModel = nil

local function safeDeletePreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
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

local function ensurePreviewCam()
    if previewCam and DoesCamExist(previewCam) then return end
    local camCfg = Config.Dealership.camera
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, camCfg.x, camCfg.y, camCfg.z)
    SetCamRot(previewCam, -12.0, 0.0, camCfg.w, 2)
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

local function spawnPreviewVehicle(model)
    if not model or model == '' then return end
    safeDeletePreviewVehicle()

    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local spawn = Config.Dealership.preview
    previewVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, false, false)
    if not previewVehicle or previewVehicle == 0 then return end

    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    SetVehicleColours(previewVehicle, currentColorIdx, currentColorIdx)
    SetVehicleExtraColours(previewVehicle, 0, 0)
    SetVehicleEngineOn(previewVehicle, false, true, true)
    SetVehicleUndriveable(previewVehicle, true)
    FreezeEntityPosition(previewVehicle, true)
    SetModelAsNoLongerNeeded(hash)

    ensurePreviewCam()
    PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.2, true)
end

local function buildUiPayload()
    if not catalog or not catalog.vehicles then return nil end
    local categories = {}
    for key, label in pairs(catalog.categories or {}) do
        categories[#categories + 1] = { key = key, label = label }
    end
    table.sort(categories, function(a, b) return a.label < b.label end)

    local vehicles = {}
    for _, veh in ipairs(catalog.vehicles) do
        local st = getVehicleStats(veh.model)
        vehicles[#vehicles + 1] = {
            model = veh.model,
            name = veh.name,
            brand = veh.brand,
            category = veh.category,
            price = veh.price,
            image = getImageUrl(veh.model),
            stats = {
                maxKmh = math.floor(st.maxKmh + 0.5),
                zeroToHundred = math.floor(st.zeroToHundred * 10 + 0.5) / 10,
                braking = math.floor(st.braking * 100 + 0.5),
                traction = math.floor(st.traction * 100 + 0.5),
            }
        }
    end

    return {
        title = catalog.dealership.label,
        categories = categories,
        vehicles = vehicles,
        colors = Config.PreviewColors or {}
    }
end

local function closeDealershipUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    safeDeletePreviewVehicle()
    destroyPreviewCam()
end

RegisterNetEvent('fivempro_dealership:client:forceCloseUi', function()
    closeDealershipUi()
end)

local function openDealershipUi()
    if not catalog then
        return QBCore.Functions.Notify('Salono duomenys dar kraunami, pabandyk dar karta.', 'error')
    end
    local payload = buildUiPayload()
    if not payload or not payload.vehicles or #payload.vehicles == 0 then
        return QBCore.Functions.Notify('Nera salono automobiliu', 'error')
    end

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })

    selectedModel = payload.vehicles[1].model
    spawnPreviewVehicle(selectedModel)
end

local function buySelectedVehicle(model)
    if not model or model == '' then return end
    QBCore.Functions.TriggerCallback('fivempro_dealership:server:buyVehicle', function(result)
        if not result or not result.ok then
            return QBCore.Functions.Notify((result and result.message) or 'Pirkimas nepavyko', 'error')
        end

        closeDealershipUi()

        local spawn = result.spawn or {}
        local modelHash = joaat(result.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(0) end

        local veh = CreateVehicle(modelHash, spawn.x or 0.0, spawn.y or 0.0, spawn.z or 0.0, spawn.w or 0.0, true, false)
        if veh and veh ~= 0 then
            SetVehicleNumberPlateText(veh, result.plate)
            SetVehicleEngineOn(veh, true, true, false)
            SetEntityAsMissionEntity(veh, true, true)
            TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            QBCore.Functions.Notify(('Nupirkta! Numeriai: %s'):format(result.plate), 'success')
        else
            QBCore.Functions.Notify('Nupirkta, bet nepavyko spawninti auto. Ji irasyta i DB.', 'primary')
        end
    end, model)
end

RegisterNUICallback('close', function(_, cb)
    closeDealershipUi()
    cb('ok')
end)

RegisterNUICallback('selectVehicle', function(data, cb)
    local model = data and data.model
    if model and model ~= '' then
        selectedModel = model
        spawnPreviewVehicle(model)
    end
    cb('ok')
end)

RegisterNUICallback('setColor', function(data, cb)
    local idx = tonumber(data and data.colorIdx)
    if idx then
        currentColorIdx = idx
        if previewVehicle and DoesEntityExist(previewVehicle) then
            SetVehicleColours(previewVehicle, idx, idx)
        end
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

RegisterNUICallback('buyVehicle', function(data, cb)
    local model = (data and data.model) or selectedModel
    buySelectedVehicle(model)
    cb('ok')
end)

CreateThread(function()
    QBCore.Functions.TriggerCallback('fivempro_dealership:server:getCatalog', function(data)
        catalog = data
    end)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local pos = Config.Dealership.office
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, DEALERSHIP_BLIP_SPRITE)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, DEALERSHIP_BLIP_SCALE)
    SetBlipColour(blip, DEALERSHIP_BLIP_COLOR)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Dealership.label)
    EndTextCommandSetBlipName(blip)

    local size = Config.Dealership.targetSize
    exports['qb-target']:AddBoxZone('fivempro_dealership_office', pos, size.x, size.y, {
        name = 'fivempro_dealership_office',
        heading = Config.Dealership.officeHeading,
        debugPoly = false,
        minZ = pos.z - 0.8,
        maxZ = pos.z + 1.2,
    }, {
        options = {
            {
                type = 'client',
                action = function()
                    openDealershipUi()
                end,
                icon = 'fas fa-car',
                label = 'Atidaryti autosalono meniu'
            }
        },
        distance = Config.Dealership.targetDistance
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeDealershipUi()
end)


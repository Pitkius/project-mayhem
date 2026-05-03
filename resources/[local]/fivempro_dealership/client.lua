local QBCore = exports['qb-core']:GetCoreObject()

local catalog = nil
local DEALERSHIP_BLIP_SPRITE = 326
local DEALERSHIP_BLIP_COLOR = 3
local DEALERSHIP_BLIP_SCALE = 0.85
local uiOpen = false
local previewVehicle = nil
local previewCam = nil
local previewSpawnGen = 0
local currentColorIdx = (Config.PreviewColors and Config.PreviewColors[1] and Config.PreviewColors[1].idx) or 111
local selectedModel = nil
local fleetCatalog = nil
--- false arba 'police' / 'mechanic' / 'ems'
local uiFleetMode = false
local activeFleetStationId = 'ls_main'

local function previewApplyShowroomVisuals()
    pcall(function()
        NetworkOverrideClockTime(12, 0, 0)
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist('EXTRASUNNY')
        SetWeatherTypeNow('EXTRASUNNY')
        SetWeatherTypeNowPersist('EXTRASUNNY')
        SetRainLevel(0.0)
        --- Gatvių apšvietimas padeda kai žaidimo fonas vis dar naktinis
        SetArtificialLightsState(true)
    end)
    pcall(function()
        SetBlackout(false)
        ClearTimecycleModifier()
    end)
end

local function previewBeginShowroom()
    if GetResourceState('qb-weathersync') == 'started' then
        TriggerEvent('qb-weathersync:client:DisableSync')
    end
    previewApplyShowroomVisuals()
end

local function previewEndShowroom()
    if GetResourceState('qb-weathersync') == 'started' then
        TriggerEvent('qb-weathersync:client:EnableSync')
    end
    pcall(function()
        NetworkClearClockTimeOverride()
    end)
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

local function getFleetSubConfig()
    if uiFleetMode == 'police' then return Config.PoliceDealership end
    if uiFleetMode == 'mechanic' then return Config.MechanicDealership end
    if uiFleetMode == 'ems' then return Config.EmsDealership end
    return nil
end

local function getFleetStationPreviewCfg()
    local d = getFleetSubConfig()
    if not d or not d.stations then return nil end
    return d.stations[activeFleetStationId or 'ls_main']
end

local function getPreviewSpawnPos()
    if uiFleetMode then
        local sc = getFleetStationPreviewCfg()
        if sc and sc.preview then return sc.preview end
    end
    return Config.Dealership.preview
end

local function getPreviewCamPos()
    if uiFleetMode then
        local sc = getFleetStationPreviewCfg()
        if sc and sc.camera then return sc.camera end
    end
    return Config.Dealership.camera
end

--- Pašalina visus auto prie preview taško (kai lieka „užstrigę“ po nepavykusio Delete).
local function clearVehiclesNearPreviewSpawn(radius)
    local spawn = getPreviewSpawnPos()
    if not spawn then return end
    local center = vector3(spawn.x, spawn.y, spawn.z)
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            if veh ~= playerVeh then
                local c = GetEntityCoords(veh)
                if #(c - center) <= radius then
                    forceDeleteVehicleEntity(veh)
                end
            end
        end
    end
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
    local camCfg = getPreviewCamPos()
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
    previewSpawnGen = previewSpawnGen + 1
    local gen = previewSpawnGen

    CreateThread(function()
        safeDeletePreviewVehicle()
        clearVehiclesNearPreviewSpawn(4.0)
        Wait(0)
        if gen ~= previewSpawnGen then return end

        local spawn = getPreviewSpawnPos()
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
        SetVehicleColours(previewVehicle, currentColorIdx, currentColorIdx)
        SetVehicleExtraColours(previewVehicle, 0, 0)
        SetVehicleEngineOn(previewVehicle, false, true, true)
        SetVehicleUndriveable(previewVehicle, true)
        FreezeEntityPosition(previewVehicle, true)
        SetModelAsNoLongerNeeded(hash)

        local cWait = 0
        while not HasCollisionLoadedAroundEntity(previewVehicle) and cWait < 120 do
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            Wait(0)
            cWait = cWait + 1
        end
        SetVehicleOnGroundProperly(previewVehicle)
        SetVehicleLights(previewVehicle, 2)

        ensurePreviewCam()
        PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.2, true)
        previewApplyShowroomVisuals()
    end)
end

local function buildUiPayload()
    local srcCat = uiFleetMode and fleetCatalog or catalog
    if not srcCat or not srcCat.vehicles then return nil end
    local categories = {}
    for key, label in pairs(srcCat.categories or {}) do
        categories[#categories + 1] = { key = key, label = label }
    end
    table.sort(categories, function(a, b) return a.label < b.label end)

    local vehicles = {}
    for _, veh in ipairs(srcCat.vehicles) do
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
        title = srcCat.dealership.label,
        categories = categories,
        vehicles = vehicles,
        colors = Config.PreviewColors or {}
    }
end

local function closeDealershipUi()
    if not uiOpen then return end
    previewSpawnGen = previewSpawnGen + 1
    uiOpen = false
    uiFleetMode = false
    activeFleetStationId = 'ls_main'
    fleetCatalog = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    safeDeletePreviewVehicle()
    destroyPreviewCam()
    ClearFocus()
    previewEndShowroom()
end

RegisterNetEvent('fivempro_dealership:client:forceCloseUi', function()
    closeDealershipUi()
end)

CreateThread(function()
    while true do
        if uiOpen then
            local esc = false
            for cg = 0, 2 do
                if IsControlJustPressed(cg, 199) or IsDisabledControlJustPressed(cg, 199)
                    or IsControlJustPressed(cg, 200) or IsDisabledControlJustPressed(cg, 200) then
                    esc = true
                    break
                end
            end
            if esc then
                closeDealershipUi()
            end
        end
        Wait(0)
    end
end)

local function openDealershipUi()
    uiFleetMode = false
    if not catalog then
        return QBCore.Functions.Notify('Salono duomenys dar kraunami, pabandyk dar karta.', 'error')
    end
    local payload = buildUiPayload()
    if not payload or not payload.vehicles or #payload.vehicles == 0 then
        return QBCore.Functions.Notify('Nera salono automobiliu', 'error')
    end

    uiOpen = true
    previewBeginShowroom()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
    -- Preview spawną inicijuoja NUI (`selectVehicle`), kad nebūtų dvigubo spawn atidaryme.
end

local function openFleetDealershipUi(mode, stationId, catalogCbName)
    stationId = tostring(stationId or 'ls_main')
    QBCore.Functions.TriggerCallback(catalogCbName, function(data)
        safeDeletePreviewVehicle()
        destroyPreviewCam()
        fleetCatalog = data
        activeFleetStationId = stationId
        uiFleetMode = mode
        local payload = buildUiPayload()
        if not payload or not payload.vehicles or #payload.vehicles == 0 then
            uiFleetMode = false
            local msg = mode == 'police' and 'PD katalogas tuščias.' or (mode == 'mechanic' and 'Mechanikų katalogas tuščias.' or 'EMS katalogas tuščias.')
            return QBCore.Functions.Notify(msg, 'error')
        end
        uiOpen = true
        previewBeginShowroom()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', payload = payload })
    end)
end

local function openPoliceDealershipUi(stationId)
    openFleetDealershipUi('police', stationId, 'fivempro_dealership:server:getPoliceCatalog')
end

RegisterNetEvent('fivempro_dealership:client:openPoliceDealership', function(stationId)
    openPoliceDealershipUi(stationId)
end)

RegisterNetEvent('fivempro_dealership:client:openMechanicDealership', function(stationId)
    openFleetDealershipUi('mechanic', stationId or 'mech_ls', 'fivempro_dealership:server:getMechanicCatalog')
end)

RegisterNetEvent('fivempro_dealership:client:openEmsDealership', function(stationId)
    openFleetDealershipUi('ems', stationId or 'ems_ls', 'fivempro_dealership:server:getEmsCatalog')
end)

local function buySelectedVehicle(model)
    if not model or model == '' then return end
    if uiFleetMode == 'police' then
        QBCore.Functions.TriggerCallback('fivempro_dealership:server:buyPoliceVehicle', function(result)
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
                QBCore.Functions.Notify(('PD transportas įsigytas. Numeriai: %s'):format(result.plate), 'success')
            else
                QBCore.Functions.Notify('Įrašyta į garažą, bet spawn nepavyko.', 'primary')
            end
        end, model, activeFleetStationId)
        return
    end
    if uiFleetMode == 'mechanic' then
        QBCore.Functions.TriggerCallback('fivempro_dealership:server:buyMechanicVehicle', function(result)
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
                QBCore.Functions.Notify(('Tarnybinis transportas. Numeriai: %s'):format(result.plate), 'success')
            else
                QBCore.Functions.Notify('Įrašyta į garažą, bet spawn nepavyko.', 'primary')
            end
        end, model, activeFleetStationId)
        return
    end
    if uiFleetMode == 'ems' then
        QBCore.Functions.TriggerCallback('fivempro_dealership:server:buyEmsVehicle', function(result)
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
                QBCore.Functions.Notify(('EMS transportas. Numeriai: %s'):format(result.plate), 'success')
            else
                QBCore.Functions.Notify('Įrašyta į garažą, bet spawn nepavyko.', 'primary')
            end
        end, model, activeFleetStationId)
        return
    end
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
    while true do
        if uiOpen then
            previewApplyShowroomVisuals()
            Wait(120)
        else
            Wait(800)
        end
    end
end)

CreateThread(function()
    while true do
        if uiOpen and previewVehicle and previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
            local c = GetEntityCoords(previewVehicle)
            DrawSpotLight(c.x + 3.2, c.y + 2.8, c.z + 6.5, -0.2, -0.18, -1.0, 255, 250, 230, 48.0, 32.0, 0.0, 36.0, 1.12)
            DrawSpotLight(c.x - 2.6, c.y - 2.2, c.z + 5.8, 0.22, 0.2, -1.0, 230, 245, 255, 40.0, 26.0, 0.0, 28.0, 0.95)
            DrawLightWithRange(c.x, c.y, c.z + 1.05, 255, 250, 235, 18.0, 24.0)
            Wait(0)
        else
            Wait(400)
        end
    end
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


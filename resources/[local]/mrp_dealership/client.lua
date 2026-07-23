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
--- false arba 'police' / 'mechanic' / 'ems' / 'taxi'
local uiFleetMode = false
local activeFleetStationId = 'ls_main'
local PREVIEW_FOCUS_DIST = 80.0

local function mapfixEnsureSimeon()
    if GetResourceState('mrp_mapfix') ~= 'started' then return end
    pcall(function()
        exports['mrp_mapfix']:EnsureSimeonShowroom()
    end)
end

local function beginPreviewStreaming(spawn)
    if not spawn then return false end
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    local dist = #(GetEntityCoords(PlayerPedId()) - vector3(spawn.x, spawn.y, spawn.z))
    if dist > PREVIEW_FOCUS_DIST then
        SetFocusPosAndVel(spawn.x, spawn.y, spawn.z, 0.0, 0.0, 0.0)
        return true
    end
    return false
end

local function endPreviewStreaming(usedFocus)
    if usedFocus then
        ClearFocus()
    end
end

local function startSimeonKeepAlive()
    CreateThread(function()
        while uiOpen and not uiFleetMode do
            mapfixEnsureSimeon()
            local spawn = Config.Dealership and Config.Dealership.preview
            if spawn then
                RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            end
            Wait(3000)
        end
    end)
end

local function setShowroomWeatherPaused(paused)
    if GetResourceState('mrp_weather') ~= 'started' then return end
    pcall(function()
        exports['mrp_weather']:SetWeatherPaused(paused)
        if not paused then
            exports['mrp_weather']:RefreshNow()
        end
    end)
end

local function previewApplyShowroomVisuals()
    pcall(function()
        NetworkOverrideClockTime(12, 0, 0)
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist('EXTRASUNNY')
        SetWeatherTypeNow('EXTRASUNNY')
        SetWeatherTypeNowPersist('EXTRASUNNY')
        SetRainLevel(0.0)
        --- Priverstinis apšvietimas salone (oras sustabdytas — nebekovoja su mrp_weather)
        SetArtificialLightsState(true)
        SetArtificialLightsStateAffectsVehicles(false)
    end)
    pcall(function()
        SetBlackout(false)
        ClearTimecycleModifier()
    end)
end

local function getFleetSubConfig()
    if uiFleetMode == 'police' then return Config.PoliceDealership end
    if uiFleetMode == 'mechanic' then return Config.MechanicDealership end
    if uiFleetMode == 'ems' then return Config.EmsDealership end
    if uiFleetMode == 'taxi' then return Config.TaxiDealership end
    if uiFleetMode == 'ranger' then return Config.RangerDealership end
    if uiFleetMode == 'boat' then return Config.BoatDealership end
    if uiFleetMode == 'heli' then return Config.HeliDealership end
    return nil
end

local function getFleetStationPreviewCfg()
    local d = getFleetSubConfig()
    if not d or not d.stations then return nil end
    local stationId = activeFleetStationId
    if uiFleetMode == 'boat' or uiFleetMode == 'heli' then
        stationId = stationId or 'ls'
    else
        stationId = stationId or 'sandy'
    end
    return d.stations[stationId]
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

local function getShowroomLightCenter()
    local spawn = getPreviewSpawnPos()
    if not spawn then return nil end
    return vector3(spawn.x, spawn.y, spawn.z)
end

local function drawShowroomLights(center)
    if not center then return end
    DrawSpotLight(
        center.x + 3.2, center.y + 2.8, center.z + 6.5,
        -0.2, -0.18, -1.0,
        255, 250, 230, 48.0, 32.0, 0.0, 36.0, 1.12
    )
    DrawSpotLight(
        center.x - 2.6, center.y - 2.2, center.z + 5.8,
        0.22, 0.2, -1.0,
        230, 245, 255, 40.0, 26.0, 0.0, 28.0, 0.95
    )
    DrawLightWithRange(center.x, center.y, center.z + 1.05, 255, 250, 235, 18.0, 24.0)
end

local function previewBeginShowroom()
    mapfixEnsureSimeon()
    if GetResourceState('qb-weathersync') == 'started' then
        TriggerEvent('qb-weathersync:client:DisableSync')
    end
    setShowroomWeatherPaused(true)
    previewApplyShowroomVisuals()
end

local function previewEndShowroom()
    setShowroomWeatherPaused(false)
    if GetResourceState('qb-weathersync') == 'started' then
        TriggerEvent('qb-weathersync:client:EnableSync')
    end
    pcall(function()
        NetworkClearClockTimeOverride()
        SetArtificialLightsStateAffectsVehicles(true)
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

local function getConfiguredMaxKmh(model)
    if GetResourceState('mrp_vehicle_perf') ~= 'started' then return nil end
    local ok, kmh = pcall(function()
        return exports['mrp_vehicle_perf']:GetConfiguredMaxKmh(model)
    end)
    if ok and kmh then return tonumber(kmh) end
    return nil
end

local function getVehicleStats(model, category)
    local hash = joaat(model)
    if GetResourceState('mrp_vehicle_perf') == 'started' then
        local ok, profile = pcall(function()
            return exports['mrp_vehicle_perf']:GetVehiclePerfProfile(model, category)
        end)
        if ok and profile then
            return {
                maxKmh = profile.maxKmh,
                zeroToHundred = profile.zeroTo100,
                tier = profile.tier,
                tierLabel = profile.tierLabel,
                braking = profile.braking,
                traction = profile.traction,
            }
        end
    end

    local maxSpeedMps = GetVehicleModelEstimatedMaxSpeed(hash)
    local accel = GetVehicleModelAcceleration(hash)
    local braking = GetVehicleModelMaxBraking(hash)
    local traction = GetVehicleModelMaxTraction(hash)

    local configuredKmh = getConfiguredMaxKmh(model)
    local maxKmh = configuredKmh or ((tonumber(maxSpeedMps) or 0.0) * 3.6)
    local zeroToHundred = 27.777 / math.max(0.1, (tonumber(accel) or 0.1) * 7.5)

    return {
        maxKmh = maxKmh,
        zeroToHundred = zeroToHundred,
        braking = math.max(0.0, math.min(1.0, tonumber(braking) or 0.0)),
        traction = math.max(0.0, math.min(1.0, tonumber(traction) or 0.0)),
    }
end

local REH_MODELS = {}
if Config.RehModels then
    for _, model in ipairs(Config.RehModels) do
        REH_MODELS[tostring(model):lower()] = true
    end
elseif Config.RehPriceOverrides then
    for model in pairs(Config.RehPriceOverrides) do
        REH_MODELS[model] = true
    end
end

local function getImageUrl(model)
    if REH_MODELS[model] then
        return ('nui://%s/html/images/vehicles/%s.png'):format(GetCurrentResourceName(), model)
    end
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
        local usedFocus = beginPreviewStreaming(spawn)

        local hash = joaat(model)
        RequestModel(hash)
        local timeout = 0
        local maxWait = 8000
        if model == 'yosemite4' then
            maxWait = 15000
        elseif type(model) == 'string' and model:match('^mrpd%d+') then
            maxWait = 12000
        end
        while not HasModelLoaded(hash) do
            previewApplyShowroomVisuals()
            Wait(0)
            timeout = timeout + 1
            if gen ~= previewSpawnGen then
                endPreviewStreaming(usedFocus)
                return
            end
            if timeout > maxWait then
                endPreviewStreaming(usedFocus)
                if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
                    QBCore.Functions.Notify(('Auto "%s" neprieinamas (trūksta DLC / modelio).'):format(model), 'error')
                else
                    QBCore.Functions.Notify(('Nepavyko užkrauti "%s" peržiūrai.'):format(model), 'error')
                end
                return
            end
        end
        if gen ~= previewSpawnGen then
            endPreviewStreaming(usedFocus)
            return
        end

        local spawnZ = spawn.z + (model == 'yosemite4' and 0.35 or 0.0)
        local veh = CreateVehicle(hash, spawn.x, spawn.y, spawnZ, spawn.w, false, false)
        if gen ~= previewSpawnGen then
            if veh and veh ~= 0 then forceDeleteVehicleEntity(veh) end
            endPreviewStreaming(usedFocus)
            return
        end

        if not veh or veh == 0 then
            endPreviewStreaming(usedFocus)
            SetModelAsNoLongerNeeded(hash)
            return
        end

        previewVehicle = veh
        SetEntityAsMissionEntity(previewVehicle, true, true)
        SetVehicleModKit(previewVehicle, 0)
        if model == 'yosemite4' then
            SetVehicleOnGroundProperly(previewVehicle)
        end
        SetVehicleDirtLevel(previewVehicle, 0.0)
        SetVehicleColours(previewVehicle, currentColorIdx, currentColorIdx)
        SetVehicleExtraColours(previewVehicle, 0, 0)
        SetVehicleEngineOn(previewVehicle, false, true, true)
        SetVehicleUndriveable(previewVehicle, true)
        FreezeEntityPosition(previewVehicle, true)
        SetModelAsNoLongerNeeded(hash)

        local cWait = 0
        while not HasCollisionLoadedAroundEntity(previewVehicle) and cWait < 120 do
            previewApplyShowroomVisuals()
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            Wait(0)
            cWait = cWait + 1
        end
        if uiFleetMode ~= 'boat' then
            SetVehicleOnGroundProperly(previewVehicle)
        else
            SetEntityCoords(previewVehicle, spawn.x, spawn.y, spawn.z, false, false, false, false)
            SetEntityHeading(previewVehicle, spawn.w or 0.0)
        end
        SetVehicleLights(previewVehicle, 2)

        if uiFleetMode then
            local sc = getFleetStationPreviewCfg()
            local lateral = sc and tonumber(sc.previewLateralM) or 0.0
            if lateral ~= 0.0 then
                local h = math.rad((spawn.w or 0.0) + 0.0)
                local ox = -math.sin(h) * lateral
                local oy = math.cos(h) * lateral
                SetEntityCoords(previewVehicle, spawn.x + ox, spawn.y + oy, spawn.z, false, false, false, false)
                SetVehicleOnGroundProperly(previewVehicle)
            end
        end

        ensurePreviewCam()
        PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.2, true)
        previewApplyShowroomVisuals()
        endPreviewStreaming(usedFocus)
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
        local st = getVehicleStats(veh.model, veh.category)
        vehicles[#vehicles + 1] = {
            model = veh.model,
            name = veh.name,
            brand = veh.brand,
            category = veh.category,
            price = veh.price,
            tier = veh.tier or st.tier,
            tierLabel = st.tierLabel,
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
    mapfixEnsureSimeon()
end

RegisterNetEvent('mrp_dealership:client:forceCloseUi', function()
    closeDealershipUi()
end)

CreateThread(function()
    while true do
        local waitMs = 450
        if uiOpen then
            waitMs = 0
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
        Wait(waitMs)
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
    startSimeonKeepAlive()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
    -- Preview spawną inicijuoja NUI (`selectVehicle`), kad nebūtų dvigubo spawn atidaryme.
end

local function openFleetDealershipUi(mode, stationId, catalogCbName)
    stationId = tostring(stationId or ((mode == 'boat' or mode == 'heli') and 'ls' or 'sandy'))
    QBCore.Functions.TriggerCallback(catalogCbName, function(data)
        safeDeletePreviewVehicle()
        destroyPreviewCam()
        fleetCatalog = data
        activeFleetStationId = stationId
        uiFleetMode = mode
        local payload = buildUiPayload()
        if not payload or not payload.vehicles or #payload.vehicles == 0 then
            uiFleetMode = false
            local msg = 'Katalogas tuščias.'
            if mode == 'police' then msg = 'PD katalogas tuščias.'
            elseif mode == 'mechanic' then msg = 'Mechanikų katalogas tuščias.'
            elseif mode == 'taxi' then msg = 'Taksi katalogas tuščias.'
            elseif mode == 'ems' then msg = 'EMS katalogas tuščias.'
            elseif mode == 'boat' then msg = 'Laivų katalogas tuščias.'
            elseif mode == 'heli' then msg = 'Malūnsparnių katalogas tuščias.'
            end
            return QBCore.Functions.Notify(msg, 'error')
        end
        uiOpen = true
        previewBeginShowroom()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', payload = payload })
    end)
end

local function openPoliceDealershipUi(stationId)
    openFleetDealershipUi('police', stationId, 'mrp_dealership:server:getPoliceCatalog')
end

RegisterNetEvent('mrp_dealership:client:openPoliceDealership', function(stationId)
    openPoliceDealershipUi(stationId)
end)

RegisterNetEvent('mrp_dealership:client:openMechanicDealership', function(stationId)
    openFleetDealershipUi('mechanic', stationId or 'mech_ls', 'mrp_dealership:server:getMechanicCatalog')
end)

RegisterNetEvent('mrp_dealership:client:openEmsDealership', function(stationId)
    openFleetDealershipUi('ems', stationId or 'ems_ls', 'mrp_dealership:server:getEmsCatalog')
end)

RegisterNetEvent('mrp_dealership:client:openTaxiDealership', function(stationId)
    openFleetDealershipUi('taxi', stationId or 'taxi_ls', 'mrp_dealership:server:getTaxiCatalog')
end)

RegisterNetEvent('mrp_dealership:client:openRangerDealership', function(stationId)
    openFleetDealershipUi('ranger', stationId or 'ranger_main', 'mrp_dealership:server:getRangerCatalog')
end)

local function openBoatDealershipUi(stationId)
    openFleetDealershipUi('boat', stationId or 'ls', 'mrp_dealership:server:getBoatCatalog')
end

local function openHeliDealershipUi(stationId)
    openFleetDealershipUi('heli', stationId or 'ls', 'mrp_dealership:server:getHeliCatalog')
end

local function applyPurchasedVehicleColor(veh, colorIdx)
    local idx = tonumber(colorIdx)
    if veh and veh ~= 0 and idx then
        SetVehicleColours(veh, idx, idx)
        SetVehicleExtraColours(veh, 0, 0)
    end
end

local function spawnPurchasedVehicle(result, colorIdx, successMsg, spawnFailMsg)
    local spawn = result.spawn or {}
    local modelHash = joaat(result.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(0) end
    local veh = CreateVehicle(modelHash, spawn.x or 0.0, spawn.y or 0.0, spawn.z or 0.0, spawn.w or 0.0, true, false)
    SetModelAsNoLongerNeeded(modelHash)
    if veh and veh ~= 0 then
        SetVehicleNumberPlateText(veh, result.plate)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        if GetResourceState('mrp_plates') == 'started' then
            exports['mrp_plates']:ApplyPlateStyle(veh)
        end
        applyPurchasedVehicleColor(veh, colorIdx)
        --- Originalių PD packų extras paliekami modelio numatytoje būsenoje.
        local modelName = tostring(result.model or ''):lower()
        local originalPdModels = {
            mrpd1 = true, mrpd2 = true, mrpd3 = true, mrpd4 = true,
            mrpd5 = true, mrpd6 = true, mrpd7 = true, mrpd8 = true,
            mrpd9 = true, mrpd10 = true, mrpd11 = true, mrpd12 = true,
            mrpd13 = true, mrpd14 = true, mrpd15 = true, mrpd16 = true,
            mrpd17 = true, mrpd18 = true, mrpd19 = true, mrpd20 = true,
            mrpd21 = true,
        }
        if originalPdModels[modelName] == true
            or modelName == 'polmav'
            or modelName == 'buzzard2' then
            if GetResourceState('mrp_ltpd') == 'started' then
                pcall(function() exports['mrp_ltpd']:EnsureFleetLightbarExtras(veh) end)
                SetTimeout(150, function()
                    if DoesEntityExist(veh) then
                        pcall(function() exports['mrp_ltpd']:EnsureFleetLightbarExtras(veh) end)
                    end
                end)
            end
        end
        SetVehicleEngineOn(veh, true, true, false)
        TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
        local ped = PlayerPedId()
        TaskWarpPedIntoVehicle(ped, veh, -1)
        Wait(0)
        if GetVehiclePedIsIn(ped, false) ~= veh then
            SetPedIntoVehicle(ped, veh, -1)
        end
        QBCore.Functions.Notify(successMsg:format(result.plate), 'success')
        return true
    end
    QBCore.Functions.Notify(spawnFailMsg, 'primary')
    return false
end

local function onPurchaseResult(result, colorIdx, successMsg, spawnFailMsg)
    if not result or not result.ok then
        return QBCore.Functions.Notify((result and result.message) or 'Pirkimas nepavyko', 'error')
    end
    closeDealershipUi()
    spawnPurchasedVehicle(result, colorIdx, successMsg, spawnFailMsg)
end

local function buySelectedVehicle(model)
    if not model or model == '' then return end
    local colorIdx = currentColorIdx
    if uiFleetMode == 'police' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyPoliceVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'PD transportas įsigytas. Numeriai: %s', 'Įrašyta į garažą, bet spawn nepavyko.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'mechanic' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyMechanicVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'Tarnybinis transportas. Numeriai: %s', 'Įrašyta į garažą, bet spawn nepavyko.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'ems' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyEmsVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'EMS transportas. Numeriai: %s', 'Įrašyta į garažą, bet spawn nepavyko.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'taxi' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyTaxiVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'Taksi transportas. Numeriai: %s', 'Įrašyta į garažą, bet spawn nepavyko.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'ranger' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyRangerVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'Gamtos apsaugos transportas. Numeriai: %s', 'Įrašyta į garažą, bet spawn nepavyko.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'boat' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyBoatVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'Laivas nupirktas! Numeriai: %s', 'Nupirkta, bet nepavyko spawninti laivo. Įrašyta į garažą.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    if uiFleetMode == 'heli' then
        QBCore.Functions.TriggerCallback('mrp_dealership:server:buyHeliVehicle', function(result)
            onPurchaseResult(result, colorIdx, 'Malūnsparnis nupirktas! Numeriai: %s', 'Nupirkta, bet nepavyko spawninti. Įrašyta į garažą.')
        end, model, activeFleetStationId, colorIdx)
        return
    end
    QBCore.Functions.TriggerCallback('mrp_dealership:server:buyVehicle', function(result)
        onPurchaseResult(result, colorIdx, 'Nupirkta! Numeriai: %s', 'Nupirkta, bet nepavyko spawninti auto. Ji irasyta i DB.')
    end, model, colorIdx)
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
            drawShowroomLights(getShowroomLightCenter())
            Wait(0)
        else
            Wait(800)
        end
    end
end)

CreateThread(function()
    QBCore.Functions.TriggerCallback('mrp_dealership:server:getCatalog', function(data)
        catalog = data
    end)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    if GetResourceState('mrp_mapfix') == 'started' then
        mapfixEnsureSimeon()
    end

    local pos = Config.Dealership.office
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, DEALERSHIP_BLIP_SPRITE)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, DEALERSHIP_BLIP_SCALE)
    SetBlipColour(blip, DEALERSHIP_BLIP_COLOR)
    SetBlipAsShortRange(blip, true)
    exports['mrp_fonts']:SetBlipName(blip, Config.Dealership.label)

    local size = Config.Dealership.targetSize
    exports['qb-target']:AddBoxZone('mrp_dealership_office', pos, size.x, size.y, {
        name = 'mrp_dealership_office',
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

    local function registerSpecialDealership(cfg, mode, openFn, icon, label)
        if not cfg or not cfg.stations then return end
        local sizeSpec = cfg.targetSize or vec3(1.2, 1.2, 1.8)
        local dist = cfg.targetDistance or 2.2
        for stationId, st in pairs(cfg.stations) do
            if st.office then
                local office = st.office
                local heading = st.officeHeading or 0.0
                exports['qb-target']:AddBoxZone(('mrp_dealership_%s_%s'):format(mode, stationId), office, sizeSpec.x, sizeSpec.y, {
                    name = ('mrp_dealership_%s_%s'):format(mode, stationId),
                    heading = heading,
                    debugPoly = false,
                    minZ = office.z - 0.8,
                    maxZ = office.z + 1.2,
                }, {
                    options = {
                        {
                            type = 'client',
                            action = function()
                                openFn(stationId)
                            end,
                            icon = icon,
                            label = label,
                        },
                    },
                    distance = dist,
                })
            end
            if st.blip and st.office then
                local blipCfg = st.blip
                local blip = AddBlipForCoord(st.office.x, st.office.y, st.office.z)
                SetBlipSprite(blip, blipCfg.sprite or 410)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, blipCfg.scale or 0.88)
                SetBlipColour(blip, blipCfg.color or 3)
                SetBlipAsShortRange(blip, blipCfg.shortRange ~= false)
                SetBlipCategory(blip, 134)
                local blipLabel = blipCfg.label or cfg.label or 'Salonas'
                if GetResourceState('mrp_fonts') == 'started' then
                    exports['mrp_fonts']:SetBlipName(blip, blipLabel)
                else
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(blipLabel)
                    EndTextCommandSetBlipName(blip)
                end
            end
        end
    end

    registerSpecialDealership(Config.BoatDealership, 'boat', openBoatDealershipUi, 'fas fa-ship', 'Atidaryti laivų saloną')
    registerSpecialDealership(Config.HeliDealership, 'heli', openHeliDealershipUi, 'fas fa-helicopter', 'Atidaryti malūnsparnių saloną')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeDealershipUi()
end)


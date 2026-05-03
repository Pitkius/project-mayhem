local QBCore = exports['qb-core']:GetCoreObject()

local function isPoliceOfficerOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    local n = P.job.name
    return n == 'ltpd' or n == 'police'
end

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    return P.job.name == 'mechanic'
end

local function isEmsOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    return P.job.name == 'ambulance'
end

local function canUseGarageEntry(garage)
    if not garage then return true end
    if garage.policeOnly then return isPoliceOfficerOnDuty() end
    if garage.mechanicOnly then return isMechanicOnDuty() end
    if garage.emsOnly then return isEmsOnDuty() end
    return true
end

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

--- qb-weathersync nuolat perrašo laiką/orą – be DisableSync peržiūra lieka naktinė ir beveik juoda.
local function previewApplyShowroomVisuals()
    pcall(function()
        NetworkOverrideClockTime(12, 0, 0)
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist('EXTRASUNNY')
        SetWeatherTypeNow('EXTRASUNNY')
        SetWeatherTypeNowPersist('EXTRASUNNY')
        SetRainLevel(0.0)
    end)
    pcall(function()
        SetBlackout(false)
        ClearTimecycleModifier()
        SetTimecycleModifierStrength(0.0)
    end)
    pcall(function()
        ClearExtraTimecycleModifier()
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
    local cz = spawn.z + 2.05
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

        local cWait = 0
        while not HasCollisionLoadedAroundEntity(previewVehicle) and cWait < 120 do
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            Wait(0)
            cWait = cWait + 1
        end
        SetVehicleOnGroundProperly(previewVehicle)
        SetVehicleLights(previewVehicle, 2)

        local lateral = tonumber(activeGarage.previewLateralM) or 0.0
        if lateral ~= 0.0 and spawn then
            local r = math.rad(spawn.w + 0.0)
            local ox = math.cos(r + math.pi * 0.5) * lateral
            local oy = math.sin(r + math.pi * 0.5) * lateral
            SetEntityCoords(previewVehicle, spawn.x + ox, spawn.y + oy, spawn.z, false, false, false, false)
        end

        ensureGaragePreviewCam(spawn)
        if previewCam and DoesCamExist(previewCam) then
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.25, true)
        end
        previewApplyShowroomVisuals()
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
    previewSpawnGen = previewSpawnGen + 1
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    safeDeletePreviewVehicle()
    destroyPreviewCam()
    ClearFocus()
    previewEndShowroom()
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
        previewBeginShowroom()
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

RegisterNetEvent('fivempro_garages:client:forceCloseUi', function()
    closeGarageUi()
end)

RegisterNetEvent('fivempro_garages:client:openGarage', function(data)
    if not data or not data.garageId then return end
    for _, garage in ipairs(Config.Garages) do
        if garage.id == data.garageId then
            if not canUseGarageEntry(garage) then
                return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
            end
            return openGarageUi(garage)
        end
    end
end)

RegisterNetEvent('fivempro_garages:client:spawnVehicle', function(data)
    doGarageVehicleSpawn(data)
end)

RegisterNetEvent('fivempro_garages:client:parkVehicle', function(data)
    if data and data.garageId then
        for _, g in ipairs(Config.Garages or {}) do
            if g.id == data.garageId and not canUseGarageEntry(g) then
                return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
            end
        end
    end
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

-- ESC/P: su SetNuiFocus(true, true) žaidimo valdikliai neateina į NUI — reikia šio sriegio.
-- Tai ne blipų logika; keičiant blipus palik šitą gabalą, kitaip ESC/P nebeuždarys meniu.
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
                closeGarageUi()
            end
        end
        Wait(0)
    end
end)

-- Kol UI atidarytas, palaikom šviesų „salono“ režimą (atsarginis kelias jei kitas resursas perrašytų).
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

--- Papildomas projektinis šviestuvas į mašiną – kai žemėlapis vis tiek labai tamsus.
CreateThread(function()
    while true do
        if uiOpen and previewVehicle and previewVehicle ~= 0 and DoesEntityExist(previewVehicle) then
            local c = GetEntityCoords(previewVehicle)
            DrawSpotLight(c.x + 4.0, c.y + 3.2, c.z + 7.2, -0.2, -0.18, -1.0, 255, 252, 245, 52.0, 42.0, 0.0, 42.0, 1.65)
            DrawSpotLight(c.x - 3.2, c.y - 2.8, c.z + 6.5, 0.22, 0.2, -1.0, 245, 248, 255, 46.0, 38.0, 0.0, 36.0, 1.45)
            DrawSpotLight(c.x, c.y + 5.5, c.z + 8.0, 0.05, -0.95, -0.25, 255, 255, 255, 38.0, 48.0, 0.0, 32.0, 1.2)
            DrawLightWithRange(c.x, c.y, c.z + 1.15, 255, 250, 235, 28.0, 42.0)
            Wait(0)
        else
            Wait(400)
        end
    end
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
        local cat = Config.GarageMapBlipCategory
        if cat and cat > 0 then
            SetBlipCategory(blip, cat)
        end
        return
    end

    for _, garage in ipairs(Config.Garages) do
        if not garage.hideBlip then
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
            SetBlipSprite(blip, GARAGE_SPRITE)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, GARAGE_SCALE)
            SetBlipColour(blip, GARAGE_COLOR)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(garage.label)
            EndTextCommandSetBlipName(blip)
            local cat = Config.GarageMapBlipCategory
            if cat and cat > 0 then
                SetBlipCategory(blip, cat)
            end
        end
    end
end

local function drawFlatCylinderMarker(pos, scaleX, scaleY, scaleZ, r, g, b, a)
    DrawMarker(
        27,
        pos.x, pos.y, pos.z + 0.02,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scaleX, scaleY, scaleZ,
        r, g, b, a,
        false, false, 2, false, nil, nil, false
    )
end

local lastGarageInteractMs = 0

CreateThread(function()
    while true do
        if not Config.EnableGroundMarkers then
            Wait(1000)
        else
            local sleep = 400
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local drawD = Config.MarkerDrawDistance or 32.0
            local openR = Config.MarkerOpenRadius or 2.5
            local parkR = Config.MarkerParkRadius or 6.5
            local maxSpd = Config.MarkerParkMaxSpeedKmh or 12.0
            local ss = Config.MarkerSpawnScale or { x = 4.2, y = 4.2, z = 0.32 }
            local ds = Config.MarkerDeskScale or { x = 2.2, y = 2.2, z = 0.22 }

            for _, garage in ipairs(Config.Garages or {}) do
                -- PD / mechanikas / EMS: tik qb-target iš darbo resursų, be žemės [E].
                if not garage.policeOnly and not garage.mechanicOnly and not garage.emsOnly then
                    local spawn = garage.spawn
                    local desk = garage.coords
                    if spawn and desk then
                        local sp = vector3(spawn.x, spawn.y, spawn.z)
                        local dp = vector3(desk.x, desk.y, desk.z)
                        local dSpawn = #(pcoords - sp)
                        local dDesk = #(pcoords - dp)

                        if dSpawn < drawD or dDesk < drawD then
                            sleep = 0
                        end

                        if dSpawn < drawD then
                            drawFlatCylinderMarker(sp, ss.x, ss.y, ss.z, 48, 200, 160, 105)
                        end
                        if dDesk < drawD then
                            drawFlatCylinderMarker(dp, ds.x, ds.y, ds.z, 72, 160, 220, 95)
                        end

                        if not uiOpen and not IsNuiFocused() then
                            EnableControlAction(0, 38, true)

                            if IsPedInAnyVehicle(ped, false) and dSpawn < parkR then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                                    local kmh = GetEntitySpeed(veh) * 3.6
                                    if kmh <= maxSpd then
                                        QBCore.Functions.DrawText3D(sp.x, sp.y, sp.z + 0.55, '[E] Pastatyti mašiną į garažą')
                                        if IsControlJustPressed(0, 38) and (GetGameTimer() - lastGarageInteractMs) > 450 then
                                            lastGarageInteractMs = GetGameTimer()
                                            TriggerEvent('fivempro_garages:client:parkVehicle', { garageId = garage.id })
                                        end
                                    end
                                end
                            elseif not IsPedInAnyVehicle(ped, false) and dDesk < openR then
                                QBCore.Functions.DrawText3D(dp.x, dp.y, dp.z + 0.95, '[E] Atidaryti garažą')
                                if IsControlJustPressed(0, 38) and (GetGameTimer() - lastGarageInteractMs) > 450 then
                                    lastGarageInteractMs = GetGameTimer()
                                    TriggerEvent('fivempro_garages:client:openGarage', { garageId = garage.id })
                                end
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    createGarageMapBlips()

    for _, garage in ipairs(Config.Garages) do
        if not garage.policeOnly and not garage.mechanicOnly and not garage.emsOnly then
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
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeGarageUi()
end)

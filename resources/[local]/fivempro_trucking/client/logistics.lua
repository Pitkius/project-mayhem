local QBCore = exports['qb-core']:GetCoreObject()

local workTruck = 0
local workTrailer = 0
local carriedProp = 0
local loadingBusy = false

local function lc()
    return Config.LogisticsCenter or {}
end

local function flatDist(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function getVehicleRearPos(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local bone = GetEntityBoneIndexByName(veh, 'boot')
    if bone ~= -1 then
        return GetWorldPositionOfEntityBone(veh, bone)
    end
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, -2.9, 0.45)
end

local function clearCarriedProp()
    local ped = PlayerPedId()
    if carriedProp ~= 0 and DoesEntityExist(carriedProp) then
        DetachEntity(carriedProp, true, true)
        DeleteEntity(carriedProp)
    end
    carriedProp = 0
    ClearPedSecondaryTask(ped)
end

local function playTimedAnim(anim, label)
    if not anim or not anim.dict then return true end
    local ped = PlayerPedId()
    if not loadAnimDict(anim.dict) then return true end
    TaskPlayAnim(ped, anim.dict, anim.clip or 'idle', 8.0, -8.0, anim.duration or 1200, anim.flag or 1, 0, false, false, false)
    if label then
        QBCore.Functions.Notify(label, 'primary', anim.duration or 1200)
    end
    local endAt = GetGameTimer() + (anim.duration or 1200)
    while GetGameTimer() < endAt do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        Wait(0)
    end
    return true
end

local function startCarryAnim()
    local anim = (lc().anims or {}).carry
    if not anim then return end
    local ped = PlayerPedId()
    if not loadAnimDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip or 'idle', 8.0, -8.0, -1, anim.flag or 49, 0, false, false, false)
end

local function attachCarriedBox()
    clearCarriedProp()
    local cfg = lc()
    local hash = loadModel(cfg.boxProp or 'hei_prop_heist_box')
    if not hash then return end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    carriedProp = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetEntityCollision(carriedProp, false, false)
    AttachEntityToEntity(
        carriedProp,
        ped,
        GetPedBoneIndex(ped, 60309),
        0.025, 0.08, 0.255,
        -145.0, 290.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
    startCarryAnim()
end

function TruckingLogisticsCleanup()
    clearCarriedProp()
    loadingBusy = false
    if workTrailer ~= 0 and DoesEntityExist(workTrailer) then
        SetEntityAsMissionEntity(workTrailer, true, true)
        DeleteVehicle(workTrailer)
    end
    workTrailer = 0
    if workTruck ~= 0 and DoesEntityExist(workTruck) then
        SetEntityAsMissionEntity(workTruck, true, true)
        DeleteVehicle(workTruck)
    end
    workTruck = 0
end

function TruckingLogisticsSpawnTruck(opts)
    opts = opts or {}
    TruckingLogisticsCleanup()
    local cfg = lc()
    local spawn = cfg.truckSpawn
    if opts.tier == 'heavy' and cfg.heavySpawn then
        spawn = cfg.heavySpawn
    end
    if not spawn then return nil end
    local model = opts.model or cfg.truckModel or 'mule'
    local hash = loadModel(model)
    if not hash then
        QBCore.Functions.Notify('Nepavyko sukurti transporto.', 'error')
        return nil
    end
    local veh = CreateVehicle(hash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading or 0.0, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, false, true, false)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    local plate = ('LC%s'):format(math.random(100, 999))
    SetVehicleNumberPlateText(veh, plate)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
    SetModelAsNoLongerNeeded(hash)
    workTruck = veh

    local trailerModel = opts.trailer
    if trailerModel then
        local th = loadModel(trailerModel)
        if th then
            local off = GetOffsetFromEntityInWorldCoords(veh, 0.0, -9.5, 0.0)
            workTrailer = CreateVehicle(th, off.x, off.y, off.z, spawn.heading or 0.0, true, false)
            SetEntityAsMissionEntity(workTrailer, true, true)
            SetVehicleOnGroundProperly(workTrailer)
            AttachVehicleToTrailer(veh, workTrailer, 1.0)
            SetModelAsNoLongerNeeded(th)
        end
    end

    local label = opts.label or model
    QBCore.Functions.Notify(('Tavo %s paruoštas pakrovimui.'):format(label), 'success')
    return veh
end

function TruckingLogisticsGetTruck()
    if workTruck ~= 0 and DoesEntityExist(workTruck) then
        return workTruck
    end
    return 0
end

function TruckingLogisticsIsCarrying()
    return carriedProp ~= 0 and DoesEntityExist(carriedProp)
end

local function nearestBoxSpot(pos)
    local best, bestDist
    for _, spot in ipairs(lc().boxSpots or {}) do
        local c = spot.coords
        local d = #(pos - c)
        if not bestDist or d < bestDist then
            best, bestDist = spot, d
        end
    end
    return best, bestDist
end

local function tryPickupBox()
    if loadingBusy or not deliveryState or deliveryState.phase ~= 'loading' then return end
    if TruckingLogisticsIsCarrying() then
        return QBCore.Functions.Notify('Jau neši dežę — padėk į transportą.', 'error')
    end
    if (deliveryState.boxesLoaded or 0) >= (deliveryState.boxesRequired or 1) then
        return QBCore.Functions.Notify('Transportas pilnas — važiuok pristatyti.', 'primary')
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Išlipk iš transporto.', 'error')
    end
    local pos = GetEntityCoords(ped)
    local _, dist = nearestBoxSpot(pos)
    if not dist or dist > (lc().spotRadius or 1.85) then
        return QBCore.Functions.Notify('Eik prie dėžių sandėlyje.', 'error')
    end
    loadingBusy = true
    local pickupAnim = (lc().anims or {}).pickup
    playTimedAnim(pickupAnim, 'Imama dėžė…')
    attachCarriedBox()
    loadingBusy = false
    QBCore.Functions.Notify('Nešk dėžę prie transporto galinės.', 'primary')
end

local function tryLoadBoxIntoTruck()
    if loadingBusy or not deliveryState or deliveryState.phase ~= 'loading' then return end
    if not TruckingLogisticsIsCarrying() then
        return QBCore.Functions.Notify('Pirmiausia paimk dėžę iš sandėlio.', 'error')
    end
    local veh = TruckingLogisticsGetTruck()
    if veh == 0 then
        return QBCore.Functions.Notify('Darbinis transportas nerastas.', 'error')
    end
    local ped = PlayerPedId()
    local rear = getVehicleRearPos(veh)
    if not rear or #(GetEntityCoords(ped) - rear) > (lc().truckLoadRadius or 4.8) then
        return QBCore.Functions.Notify('Eik prie transporto galinės.', 'error')
    end
    loadingBusy = true
    SetVehicleDoorOpen(veh, 5, false, false)
    SetVehicleDoorOpen(veh, 2, false, false)
    SetVehicleDoorOpen(veh, 3, false, false)
    local placeAnim = (lc().anims or {}).place
    playTimedAnim(placeAnim, 'Dedama dėžė…')
    clearCarriedProp()
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:loadBox', function(res)
        loadingBusy = false
        SetVehicleDoorShut(veh, 5, false)
        SetVehicleDoorShut(veh, 2, false)
        SetVehicleDoorShut(veh, 3, false)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Nepavyko pakrauti.', 'error')
            attachCarriedBox()
            return
        end
        deliveryState.boxesLoaded = res.boxesLoaded or 0
        deliveryState.boxesRequired = res.boxesRequired or deliveryState.boxesRequired
        if res.complete then
            deliveryState.phase = 'delivery'
            deliveryState.loaded = true
            local c = deliveryState.contract
            if c and c.delivery then
                setMissionBlip(c.delivery, 'Pristatymas: ' .. (c.deliveryLabel or ''), true)
            end
            QBCore.Functions.Notify('Transportas pakrautas — važiuok į pristatymo vietą.', 'success')
        else
            QBCore.Functions.Notify(
                ('Pakrauta %s/%s — imk kitą dėžę.'):format(res.boxesLoaded, res.boxesRequired),
                'primary'
            )
        end
    end)
end

local function drawLoadHint(text)
    SetTextFont(4)
    SetTextScale(0.38, 0.38)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.90)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if deliveryState and deliveryState.phase == 'loading' then
            sleep = 0
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local cfg = lc()
            local loaded = deliveryState.boxesLoaded or 0
            local required = deliveryState.boxesRequired or 0
            drawLoadHint(('Pakrovimas: %s / %s'):format(loaded, required))

            if TruckingLogisticsIsCarrying() then
                local veh = TruckingLogisticsGetTruck()
                local rear = veh ~= 0 and getVehicleRearPos(veh) or nil
                if rear then
                    DrawMarker(1, rear.x, rear.y, rear.z - 0.4, 0, 0, 0, 0, 0, 0, 1.8, 1.8, 1.0, 124, 58, 237, 150, false, false, 2, false, nil, nil, false)
                    if #(pos - rear) < (cfg.truckLoadRadius or 4.8) then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Padėti dėžę į transportą')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, 38) and not loadingBusy then
                            tryLoadBoxIntoTruck()
                        end
                    end
                end
                if not IsEntityPlayingAnim(ped, (cfg.anims.carry or {}).dict or '', (cfg.anims.carry or {}).clip or '', 3) then
                    startCarryAnim()
                end
            else
                for _, spot in ipairs(cfg.boxSpots or {}) do
                    local c = spot.coords
                    if #(pos - c) < 25.0 then
                        DrawMarker(1, c.x, c.y, c.z - 0.95, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.8, 251, 146, 60, 120, false, false, 2, false, nil, nil, false)
                    end
                end
                local _, dist = nearestBoxSpot(pos)
                if dist and dist < (cfg.spotRadius or 1.85) then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Paimti dėžę')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not loadingBusy then
                        tryPickupBox()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if deliveryState and deliveryState.phase == 'loading' and TruckingLogisticsIsCarrying() then
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

local QBCore = exports['qb-core']:GetCoreObject()

local workTruck = 0
local workTrailer = 0
local carriedProp = 0
local loadedBoxProps = {}
local loadingBusy = false
local preloadedAnims = false
local missionFailPending = false

local TRUCK_BOX_OFFSETS = {
    { x = -0.42, y = -1.35, z = 0.42 },
    { x = 0.42, y = -1.35, z = 0.42 },
    { x = -0.42, y = -2.05, z = 0.42 },
    { x = 0.42, y = -2.05, z = 0.42 },
    { x = -0.42, y = -2.75, z = 0.42 },
    { x = 0.42, y = -2.75, z = 0.42 },
    { x = 0.0, y = -3.35, z = 0.42 },
    { x = 0.0, y = -1.95, z = 0.78 },
}

local function lc()
    return Config.LogisticsCenter or {}
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

local function preloadMissionAnims()
    if preloadedAnims then return end
    local anims = lc().anims or {}
    for _, anim in pairs(anims) do
        if anim.dict then
            loadAnimDict(anim.dict)
        end
    end
    preloadedAnims = true
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

local function clearLoadedBoxProps()
    for _, prop in ipairs(loadedBoxProps) do
        if prop ~= 0 and DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    loadedBoxProps = {}
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
    if not anim or not anim.dict then return false end
    local ped = PlayerPedId()
    if not loadAnimDict(anim.dict) then return false end
    TaskPlayAnim(
        ped,
        anim.dict,
        anim.clip or 'idle',
        8.0,
        -8.0,
        anim.duration or 1200,
        anim.flag or 0,
        0,
        false,
        false,
        false
    )
    if label then
        QBCore.Functions.Notify(label, 'primary', anim.duration or 1200)
    end
    local endAt = GetGameTimer() + (anim.duration or 1200)
    while GetGameTimer() < endAt do
        if not IsEntityPlayingAnim(ped, anim.dict, anim.clip or 'idle', 3) then
            TaskPlayAnim(
                ped,
                anim.dict,
                anim.clip or 'idle',
                8.0,
                -8.0,
                anim.duration or 1200,
                anim.flag or 0,
                0,
                false,
                false,
                false
            )
        end
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

local function createBoxProp()
    local hash = loadModel(lc().boxProp or 'hei_prop_heist_box')
    if not hash then return 0 end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetEntityCollision(prop, false, false)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function attachCarriedBox()
    clearCarriedProp()
    local prop = createBoxProp()
    if prop == 0 then return false end
    local ped = PlayerPedId()
    carriedProp = prop
    AttachEntityToEntity(
        carriedProp,
        ped,
        GetPedBoneIndex(ped, 60309),
        0.025, 0.08, 0.255,
        -145.0, 290.0, 0.0,
        true, true, false, true, 1, true
    )
    startCarryAnim()
    return true
end

local function attachBoxToTruckBed(veh, slotIndex)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    local offset = TRUCK_BOX_OFFSETS[slotIndex] or {
        x = 0.0,
        y = -1.5 - ((slotIndex - 1) * 0.35),
        z = 0.42,
    }
    local prop = createBoxProp()
    if prop == 0 then return false end
    AttachEntityToEntity(
        prop,
        veh,
        0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )
    loadedBoxProps[#loadedBoxProps + 1] = prop
    return true
end

local function attachCarriedBoxToTruck(veh, slotIndex)
    if carriedProp == 0 or not DoesEntityExist(carriedProp) then
        return attachBoxToTruckBed(veh, slotIndex)
    end
    local offset = TRUCK_BOX_OFFSETS[slotIndex] or {
        x = 0.0,
        y = -1.5 - ((slotIndex - 1) * 0.35),
        z = 0.42,
    }
    DetachEntity(carriedProp, true, true)
    AttachEntityToEntity(
        carriedProp,
        veh,
        0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )
    loadedBoxProps[#loadedBoxProps + 1] = carriedProp
    carriedProp = 0
    ClearPedSecondaryTask(PlayerPedId())
    return true
end

function TruckingLogisticsCleanup()
    clearCarriedProp()
    clearLoadedBoxProps()
    loadingBusy = false
    preloadedAnims = false
    missionFailPending = false
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
    preloadMissionAnims()
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

local function syncDeliveryPhase(res)
    if not res or not deliveryState then return end
    if res.delivery then
        deliveryState.boxesLoaded = res.delivery.boxesLoaded or deliveryState.boxesLoaded
        deliveryState.boxesRequired = res.delivery.boxesRequired or deliveryState.boxesRequired
        deliveryState.phase = res.delivery.phase or deliveryState.phase
        deliveryState.loaded = res.delivery.loaded == true
        if res.delivery.contract then
            deliveryState.contract = res.delivery.contract
        end
    else
        deliveryState.boxesLoaded = res.boxesLoaded or deliveryState.boxesLoaded
        deliveryState.boxesRequired = res.boxesRequired or deliveryState.boxesRequired
    end
    if res.complete or deliveryState.phase == 'delivery' then
        deliveryState.phase = 'delivery'
        deliveryState.loaded = true
        local c = deliveryState.contract
        if c and c.delivery then
            setMissionBlip(c.delivery, 'Pristatymas: ' .. (c.deliveryLabel or ''), true)
        end
        QBCore.Functions.Notify('Transportas pakrautas — važiuok į pristatymo vietą.', 'success')
    else
        QBCore.Functions.Notify(
            ('Pakrauta %s/%s — imk kitą dėžę.'):format(deliveryState.boxesLoaded, deliveryState.boxesRequired),
            'primary'
        )
    end
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
    if not playTimedAnim(pickupAnim, 'Imama dėžė…') then
        loadingBusy = false
        return QBCore.Functions.Notify('Animacija nepavyko — bandyk dar kartą.', 'error')
    end
    if not attachCarriedBox() then
        loadingBusy = false
        return QBCore.Functions.Notify('Nepavyko paimti dėžės.', 'error')
    end
    loadingBusy = false
    QBCore.Functions.Notify('Nešk dėžę prie transporto galinės.', 'primary')
end

local function tryLoadBoxIntoTruck()
    if loadingBusy or not deliveryState or deliveryState.phase ~= 'loading' then return end
    if (deliveryState.boxesLoaded or 0) >= (deliveryState.boxesRequired or 1) then
        return QBCore.Functions.Notify('Transportas pilnas — važiuok pristatyti.', 'primary')
    end
    local veh = TruckingLogisticsGetTruck()
    if veh == 0 then
        return QBCore.Functions.Notify('Darbinis transportas nerastas.', 'error')
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Išlipk iš transporto.', 'error')
    end
    local rear = getVehicleRearPos(veh)
    if not rear or #(GetEntityCoords(ped) - rear) > (lc().truckLoadRadius or 4.8) then
        return QBCore.Functions.Notify('Eik prie transporto galinės.', 'error')
    end

    loadingBusy = true
    SetVehicleDoorOpen(veh, 5, false, false)
    SetVehicleDoorOpen(veh, 2, false, false)
    SetVehicleDoorOpen(veh, 3, false, false)

    if not TruckingLogisticsIsCarrying() then
        local pickupAnim = (lc().anims or {}).pickup
        if not playTimedAnim(pickupAnim, 'Imama dėžė…') then
            loadingBusy = false
            SetVehicleDoorShut(veh, 5, false)
            SetVehicleDoorShut(veh, 2, false)
            SetVehicleDoorShut(veh, 3, false)
            return QBCore.Functions.Notify('Animacija nepavyko — bandyk dar kartą.', 'error')
        end
        if not attachCarriedBox() then
            loadingBusy = false
            SetVehicleDoorShut(veh, 5, false)
            SetVehicleDoorShut(veh, 2, false)
            SetVehicleDoorShut(veh, 3, false)
            return QBCore.Functions.Notify('Nepavyko paimti dėžės.', 'error')
        end
    end

    local placeAnim = (lc().anims or {}).place
    if not playTimedAnim(placeAnim, 'Dedama dėžė į bagažinę…') then
        loadingBusy = false
        SetVehicleDoorShut(veh, 5, false)
        SetVehicleDoorShut(veh, 2, false)
        SetVehicleDoorShut(veh, 3, false)
        return QBCore.Functions.Notify('Animacija nepavyko — bandyk dar kartą.', 'error')
    end

    local slotIndex = (deliveryState.boxesLoaded or 0) + 1
    attachCarriedBoxToTruck(veh, slotIndex)

    QBCore.Functions.TriggerCallback('mrp_trucking:server:loadBox', function(res)
        loadingBusy = false
        SetVehicleDoorShut(veh, 5, false)
        SetVehicleDoorShut(veh, 2, false)
        SetVehicleDoorShut(veh, 3, false)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Nepavyko pakrauti.', 'error')
            local last = loadedBoxProps[#loadedBoxProps]
            if last and DoesEntityExist(last) then
                DeleteEntity(last)
                loadedBoxProps[#loadedBoxProps] = nil
            end
            attachCarriedBox()
            return
        end
        syncDeliveryPhase(res)
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

            local veh = TruckingLogisticsGetTruck()
            local rear = veh ~= 0 and getVehicleRearPos(veh) or nil
            local nearRear = rear and #(pos - rear) < (cfg.truckLoadRadius or 4.8)

            if TruckingLogisticsIsCarrying() then
                if rear then
                    DrawMarker(1, rear.x, rear.y, rear.z - 0.4, 0, 0, 0, 0, 0, 0, 1.8, 1.8, 1.0, 124, 58, 237, 150, false, false, 2, false, nil, nil, false)
                    if nearRear then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Padėti dėžę į bagažinę')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, 38) and not loadingBusy then
                            tryLoadBoxIntoTruck()
                        end
                    end
                end
                local carryAnim = cfg.anims and cfg.anims.carry or {}
                if not IsEntityPlayingAnim(ped, carryAnim.dict or '', carryAnim.clip or '', 3) then
                    startCarryAnim()
                end
            else
                for _, spot in ipairs(cfg.boxSpots or {}) do
                    local c = spot.coords
                    if #(pos - c) < 25.0 then
                        DrawMarker(1, c.x, c.y, c.z - 0.95, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.8, 251, 146, 60, 120, false, false, 2, false, nil, nil, false)
                    end
                end
                if rear and loaded < required then
                    DrawMarker(1, rear.x, rear.y, rear.z - 0.4, 0, 0, 0, 0, 0, 0, 1.8, 1.8, 1.0, 124, 58, 237, 150, false, false, 2, false, nil, nil, false)
                end
                if nearRear and loaded < required then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Pakrauti dėžę į bagažinę')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) and not loadingBusy then
                        tryLoadBoxIntoTruck()
                    end
                else
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

local function missionVehicleHealthIssue(veh)
    if veh == 0 or not DoesEntityExist(veh) then
        return true, 'Darbinis transportas dingo — misija atšaukta.'
    end
    if IsEntityDead(veh) or not IsVehicleDriveable(veh, false) then
        return true, 'Darbinis transportas sunaikintas — misija atšaukta.'
    end
    local body = GetVehicleBodyHealth(veh) or 1000.0
    local engine = GetVehicleEngineHealth(veh) or 1000.0
    if body <= (Config.VehicleFailBodyHealth or 280.0) then
        return true, 'Transportas per daug pažeistas — misija atšaukta.'
    end
    if engine <= (Config.VehicleFailEngineHealth or 150.0) then
        return true, 'Variklis nebeveikia — misija atšaukta.'
    end
    return false
end

function TruckingLogisticsCheckMissionVehicle()
    local veh = TruckingLogisticsGetTruck()
    return missionVehicleHealthIssue(veh)
end

CreateThread(function()
    while true do
        Wait(1500)
        if not deliveryState or not deliveryState.contract or missionFailPending then goto continue end
        local failed, reason = TruckingLogisticsCheckMissionVehicle()
        if failed then
            missionFailPending = true
            QBCore.Functions.TriggerCallback('mrp_trucking:server:failDelivery', function(res)
                missionFailPending = false
                if res and res.ok then
                    QBCore.Functions.Notify(res.reason or reason, 'error', 7000)
                    if res.repLoss and res.repLoss > 0 then
                        QBCore.Functions.Notify(('Reputacija -%s'):format(res.repLoss), 'error', 6000)
                    end
                else
                    QBCore.Functions.Notify(reason, 'error', 7000)
                end
            end, reason)
        end
        ::continue::
    end
end)

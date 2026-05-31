--- Saugus barber flow: kėdė, animacija, kamera, be teleporto po mapu.
local QBCore = exports['qb-core']:GetCoreObject()

BarberSession = BarberSession or {}

local CHAIR_MODELS = {
    `v_ilev_hd_chair`,
    `v_ilev_hd_chair_02`,
    `prop_barber_chair_01`,
    `prop_barber_chair_02`,
    `prop_barber_chair_03`,
}

local SCENARIO_SIT = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

local function groundZ(x, y, seedZ)
    local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (seedZ or 50.0) + 1.0, false)
    if found then return gz end
    found, gz = GetGroundZFor_3dCoord(x, y, seedZ or 50.0, false)
    if found then return gz end
    return seedZ
end

local function findNearestChair(maxDist)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    maxDist = maxDist or 3.5
    local best, bestDist = nil, maxDist
    for _, obj in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(obj) then
            local model = GetEntityModel(obj)
            for i = 1, #CHAIR_MODELS do
                if model == CHAIR_MODELS[i] then
                    local oc = GetEntityCoords(obj)
                    local d = #(pcoords - oc)
                    if d < bestDist then
                        bestDist = d
                        best = obj
                    end
                    break
                end
            end
        end
    end
    return best
end

local function seatFromChairEntity(chairEnt, fallbackHeading)
    local c = GetEntityCoords(chairEnt)
    local h = GetEntityHeading(chairEnt)
    local z = groundZ(c.x, c.y, c.z)
    return vector4(c.x, c.y, z + 0.62, h + 180.0)
end

local function seatFromConfig(cfgChair)
    if not cfgChair then return nil end
    local z = groundZ(cfgChair.x, cfgChair.y, cfgChair.z)
    if math.abs(z - cfgChair.z) > 2.5 then
        z = cfgChair.z
    else
        z = z + 0.55
    end
    return vector4(cfgChair.x, cfgChair.y, z, cfgChair.w)
end

local function resolveSeat(cfg)
    local chairEnt = findNearestChair(4.0)
    if chairEnt then
        return seatFromChairEntity(chairEnt, cfg and cfg.chair and cfg.chair.w), chairEnt
    end
    if cfg and cfg.chair then
        return seatFromConfig(cfg.chair), nil
    end
    if cfg and cfg.coords then
        local c = cfg.coords
        local z = groundZ(c.x, c.y, c.z)
        return vector4(c.x, c.y, z + 0.55, c.w), nil
    end
    return nil, nil
end

local function waitSeated(ped, timeoutMs)
    timeoutMs = timeoutMs or 3500
    local t0 = GetGameTimer()
    while GetGameTimer() - t0 < timeoutMs do
        if IsPedUsingScenario(ped, SCENARIO_SIT) or IsPedActiveInScenario(ped) then
            return true
        end
        Wait(50)
    end
    return IsPedUsingScenario(ped, SCENARIO_SIT) or IsPedActiveInScenario(ped)
end

local function faceCamFromPed(ped)
    local p = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local rad = math.rad(h)
    local cx = p.x + math.cos(rad) * 0.85
    local cy = p.y + math.sin(rad) * 0.85
    return vector4(cx, cy, p.z + 0.68, h + 180.0)
end

function BarberSession.IsActive()
    return BarberSession.active == true
end

function BarberSession.Cleanup(restoreSaved)
    local ped = PlayerPedId()
    BarberSession.active = false

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    ClearPedTasks(ped)

    if restoreSaved and BarberSession.saved then
        local s = BarberSession.saved
        local z = groundZ(s.x, s.y, s.z)
        SetEntityCoordsNoOffset(ped, s.x, s.y, z + 0.02, false, false, false)
        SetEntityHeading(ped, s.w)
    elseif BarberSession.seat then
        local s = BarberSession.seat
        local z = groundZ(s.x, s.y, s.z)
        SetEntityCoordsNoOffset(ped, s.x, s.y, z + 0.02, false, false, false)
        SetEntityHeading(ped, s.w)
    end

    BarberSession.saved = nil
    BarberSession.seat = nil
    BarberSession.chairEnt = nil
end

local function startWatchdog()
    CreateThread(function()
        while BarberSession.active do
            local ped = PlayerPedId()
            if BarberSession.saved then
                local p = GetEntityCoords(ped)
                local s = BarberSession.saved
                if p.z < s.z - 4.0 or p.z < -50.0 then
                    BarberSession.Cleanup(true)
                    QBCore.Functions.Notify('Kirpykla: saugus atstatymas (Z klaida).', 'error')
                    break
                end
            end
            Wait(400)
        end
    end)
end

function BarberSession.Start(cfg, barberPed)
    if BarberSession.active then return end

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    BarberSession.saved = vector4(pcoords.x, pcoords.y, pcoords.z, GetEntityHeading(ped))
    BarberSession.active = true

    local seat, chairEnt = resolveSeat(cfg)
    if not seat then
        BarberSession.active = false
        return QBCore.Functions.Notify('Nepavyko rasti kirpyklos kėdės.', 'error')
    end
    BarberSession.seat = seat
    BarberSession.chairEnt = chairEnt

    ClearPedTasksImmediately(ped)
    SetEntityCollision(ped, true, true)

    RequestCollisionAtCoord(seat.x, seat.y, seat.z)
    local colWait = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colWait do
        Wait(10)
    end

    SetEntityCoordsNoOffset(ped, seat.x, seat.y, seat.z, false, false, false)
    SetEntityHeading(ped, seat.w)
    Wait(100)

    TaskStartScenarioAtPosition(ped, SCENARIO_SIT, seat.x, seat.y, seat.z, seat.w, 0, true, true)
    if not waitSeated(ped, 4000) then
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, seat.x, seat.y, seat.z, false, false, false)
        SetEntityHeading(ped, seat.w)
        FreezeEntityPosition(ped, true)
    else
        FreezeEntityPosition(ped, true)
    end

    if barberPed and DoesEntityExist(barberPed) then
        if loadAnimDict('misshair_shop@hair_dressers') then
            TaskPlayAnim(barberPed, 'misshair_shop@hair_dressers', 'keeper_hair_cut_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
    end

    startWatchdog()

    local camLoc = faceCamFromPed(ped)
    Wait(350)
    TriggerEvent('qb-clothing:client:openBarberOnly', camLoc)
end

AddEventHandler('qb-clothing:client:onMenuClose', function()
    if not BarberSession.active then return end
    Wait(100)
    BarberSession.Cleanup(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if BarberSession.active then BarberSession.Cleanup(true) end
end)

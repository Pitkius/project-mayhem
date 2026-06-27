local QBCore = exports['qb-core']:GetCoreObject()

local inLapDance = false
local lapStop = false
local lapStripper = nil
local playerSitted = false
local prevCamMode = nil

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 8000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

local function isFemalePed(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function femaleSuffix(ped)
    return isFemalePed(ped) and '_female' or ''
end

local function waitPedAtCoord(ped, coords, timeoutMs, dist)
    timeoutMs = timeoutMs or 12000
    dist = dist or 0.45
    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline and not lapStop do
        if not ped or not DoesEntityExist(ped) then return false end
        if #(GetEntityCoords(ped) - coords) <= dist then
            return true
        end
        Wait(100)
    end
    return false
end

local function stripperAnim(ped)
    if lapStop or not ped or not DoesEntityExist(ped) then return end
    if not loadDict('mini@strip_club@private_dance@part1') then return end
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@part1', 'priv_dance_p1', 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(22300)
    if lapStop then return end
    if not loadDict('mini@strip_club@private_dance@part2') then return end
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@part2', 'priv_dance_p2', 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(31200)
    if lapStop then return end
    if not loadDict('mini@strip_club@private_dance@exit') then return end
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@exit', 'priv_dance_exit', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(8000)
end

local function playerSitLoop(ped, seat)
    if not loadDict('mini@strip_club@lap_dance_2g@ld_2g_reach') then return end
    local anim = 'ld_2g_sit_idle'
    playerSitted = true
    prevCamMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4)

    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, seat.sit.x, seat.sit.y, seat.sit.z, false, false, false)
    SetEntityHeading(ped, seat.sit.w)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, 'mini@strip_club@lap_dance_2g@ld_2g_reach', anim, 8.0, -8.0, -1, 1, 0, false, false, false)
    SetGameplayCamRelativeHeading(seat.camHeading or -10.0)

    while inLapDance and not lapStop do
        if not IsEntityPlayingAnim(ped, 'mini@strip_club@lap_dance_2g@ld_2g_reach', anim, 3) then
            TaskPlayAnim(ped, 'mini@strip_club@lap_dance_2g@ld_2g_reach', anim, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        Wait(500)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    playerSitted = false

    if not lapStop and seat.exit then
        SetEntityCoordsNoOffset(ped, seat.exit.x, seat.exit.y, seat.exit.z, false, false, false)
        Wait(200)
        if prevCamMode then SetFollowPedCamViewMode(prevCamMode) end
    elseif prevCamMode then
        SetFollowPedCamViewMode(prevCamMode)
    end
end

local function runStripperSequence(seat, heading)
    local ped = lapStripper
    if not ped or not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, false)
    SetEntityHeading(ped, heading or 303.19)

    if loadDict('mini@strip_club@idles@stripper') then
        TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    TaskGoToCoordAnyMeans(ped, seat.stripperPath1.x, seat.stripperPath1.y, seat.stripperPath1.z, 1.0, 0, 0, 786603, 0.0)
    waitPedAtCoord(ped, seat.stripperPath1, seat.approachWait or 7000, 0.55)

    local waitUntil = GetGameTimer() + 25000
    while GetGameTimer() < waitUntil and not playerSitted and not lapStop do
        if loadDict('mini@strip_club@idles@stripper') and not IsEntityPlayingAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 3) then
            TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        Wait(250)
    end

    if lapStop then return end

    FreezeEntityPosition(ped, false)
    TaskGoToCoordAnyMeans(ped, seat.stripperPath2.x, seat.stripperPath2.y, seat.stripperPath2.z, 1.0, 0, 0, 786603, 0.0)
    waitPedAtCoord(ped, seat.stripperPath2, 5000, 0.6)
    TaskGoToCoordAnyMeans(ped, seat.stripperDance.x, seat.stripperDance.y, seat.stripperDance.z, 1.0, 0, 0, 786603, 0.0)
    waitPedAtCoord(ped, seat.stripperDance, 5000, 0.45)

    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, heading or 303.19)
    stripperAnim(ped)

    if not lapStop then
        FreezeEntityPosition(ped, false)
        TaskGoToCoordAnyMeans(ped, seat.stripperEnd.x, seat.stripperEnd.y, seat.stripperEnd.z, 1.0, 0, 0, 786603, 0.0)
        waitPedAtCoord(ped, seat.stripperEnd, 5000, 0.55)
        if loadDict('mini@strip_club@idles@stripper') then
            FreezeEntityPosition(ped, true)
            TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end
end

local function spawnLapStripper(stripperCfg, seat)
    local model = stripperCfg.model
    if type(model) == 'string' then model = joaat(model) end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 8000 do
        Wait(10)
        t = t + 10
    end
    if not HasModelLoaded(model) then return nil end

    local s = seat.stripperSpawn
    local ped = CreatePed(4, model, s.x, s.y, s.z, s.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, false)

    if stripperCfg.components then
        for _, c in ipairs(stripperCfg.components) do
            SetPedComponentVariation(ped, c[1], c[2], c[3] or 0, 0)
        end
    end
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function findSeat(seatId)
    local wanted = tonumber(seatId)
    if not wanted then return nil end
    for _, s in ipairs(Config.LapSeats or {}) do
        if tonumber(s.id) == wanted then
            return s
        end
    end
end

function IsLapDanceActive()
    return inLapDance
end

function StopLapDance()
    lapStop = true
    inLapDance = false
    local player = PlayerPedId()
    FreezeEntityPosition(player, false)
    ClearPedTasks(player)
    if prevCamMode then SetFollowPedCamViewMode(prevCamMode) end
    if lapStripper and DoesEntityExist(lapStripper) then
        DeleteEntity(lapStripper)
    end
    lapStripper = nil
    playerSitted = false
end

function StartLapDance(seatId, stripperIndex)
    if inLapDance then
        return QBCore.Functions.Notify('Jau vyksta šokis.', 'error')
    end

    local seat = findSeat(seatId)
    if not seat then
        return QBCore.Functions.Notify('VIP vieta nerasta.', 'error')
    end

    local stripperCfg = Config.Strippers[stripperIndex or 1] or Config.Strippers[1]
    if not stripperCfg then return end

    QBCore.Functions.TriggerCallback('mrp_stripclub:server:tryPay', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.msg or 'Mokėjimas nepavyko.', 'error')
        end

        lapStop = false
        inLapDance = true
        playerSitted = false
        local player = PlayerPedId()

        lapStripper = spawnLapStripper(stripperCfg, seat)
        if not lapStripper then
            inLapDance = false
            TriggerServerEvent('mrp_stripclub:server:releaseSeat', seatId)
            return QBCore.Functions.Notify('Nepavyko sukurti šokėjos.', 'error')
        end

        CreateThread(function()
            runStripperSequence(seat, seat.stripperSpawn.w)
        end)

        CreateThread(function()
            Wait(350)
            if inLapDance and not lapStop then
                playerSitLoop(player, seat)
            end
        end)

        CreateThread(function()
            while inLapDance do
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 32, true)
                DisableControlAction(0, 33, true)
                DisableControlAction(0, 34, true)
                DisableControlAction(0, 35, true)
                if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                    lapStop = true
                    break
                end
                Wait(0)
            end

            inLapDance = false
            FreezeEntityPosition(player, false)
            ClearPedTasks(player)
            if prevCamMode then SetFollowPedCamViewMode(prevCamMode) end
            if lapStripper and DoesEntityExist(lapStripper) then
                DeleteEntity(lapStripper)
            end
            lapStripper = nil
            playerSitted = false
            TriggerServerEvent('mrp_stripclub:server:releaseSeat', seatId)
            QBCore.Functions.Notify('Privatus šokis baigtas.', 'primary')
        end)
    end, 'lap', seatId)
end

function StartLeanThrow(heading)
    local player = PlayerPedId()
    local price = tonumber(Config.Prices.throwCash) or 40

    QBCore.Functions.TriggerCallback('mrp_stripclub:server:tryPay', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.msg or 'Nepakanka grynųjų.', 'error')
        end

        local p = GetEntityCoords(player)
        SetEntityCoordsNoOffset(player, p.x, p.y, p.z, false, false, false)
        FreezeEntityPosition(player, true)
        SetEntityHeading(player, heading)

        local suf = femaleSuffix(player)
        if not loadDict('mini@strip_club@leaning@enter') then
            FreezeEntityPosition(player, false)
            return
        end
        TaskPlayAnim(player, 'mini@strip_club@leaning@enter', 'enter' .. suf, 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(2750)

        prevCamMode = GetFollowPedCamViewMode()
        SetFollowPedCamViewMode(4)
        SetGameplayCamRelativeHeading(0.0)
        loadDict('mini@strip_club@leaning@base')
        TaskPlayAnim(player, 'mini@strip_club@leaning@base', 'base' .. suf, 8.0, -8.0, -1, 1, 0, false, false, false)

        QBCore.Functions.Notify(('Metei $%s į sceną. SPACE dar kartą · ESC atsistoti.'):format(price), 'success')

        CreateThread(function()
            local leaning = true
            while leaning do
                if IsControlJustPressed(0, 22) then
                    QBCore.Functions.TriggerCallback('mrp_stripclub:server:tryPay', function(r2)
                        if r2 and r2.ok then
                            loadDict('mini@strip_club@leaning@toss')
                            TaskPlayAnim(player, 'mini@strip_club@leaning@toss', 'toss' .. suf, 8.0, -8.0, -1, 2, 0, false, false, false)
                            Wait(1200)
                            TaskPlayAnim(player, 'mini@strip_club@leaning@base', 'base' .. suf, 8.0, -8.0, -1, 1, 0, false, false, false)
                        else
                            QBCore.Functions.Notify(r2 and r2.msg or 'Nepakanka grynųjų.', 'error')
                        end
                    end, 'throw', 0)
                    Wait(500)
                end
                if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                    leaning = false
                end
                Wait(0)
            end

            loadDict('mini@strip_club@leaning@exit')
            TaskPlayAnim(player, 'mini@strip_club@leaning@exit', 'exit' .. suf, 8.0, -8.0, -1, 0, 0, false, false, false)
            Wait(1800)
            FreezeEntityPosition(player, false)
            ClearPedTasks(player)
            if prevCamMode then SetFollowPedCamViewMode(prevCamMode) end
        end)
    end, 'throw', 0)
end

local QBCore = exports['qb-core']:GetCoreObject()

local inLapDance = false
local lapStop = false
local lapStripper = nil
local playerSitted = false
local prevCamMode = nil

local function loadDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    return dict
end

local function isFemalePed(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function femaleSuffix(ped)
    return isFemalePed(ped) and '_female' or ''
end

local function stripperAnim(ped)
    if lapStop or not ped or not DoesEntityExist(ped) then return end
    loadDict('mini@strip_club@private_dance@part1')
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@part1', 'priv_dance_p1', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(22300)
    if lapStop then return end
    loadDict('mini@strip_club@private_dance@part2')
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@part2', 'priv_dance_p2', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(31200)
    if lapStop then return end
    loadDict('mini@strip_club@private_dance@exit')
    TaskPlayAnim(ped, 'mini@strip_club@private_dance@exit', 'priv_dance_exit', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(8000)
end

local function playerSitLoop(ped, seat)
    local dict = loadDict('mini@strip_club@lap_dance_2g@ld_2g_reach')
    local anim = 'ld_2g_sit_idle'
    playerSitted = true
    prevCamMode = GetFollowPedCamViewMode(ped)
    SetFollowPedCamViewMode(4)
    SetEntityCoords(ped, seat.sit.x, seat.sit.y, seat.sit.z, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, seat.sit.w)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
    SetGameplayCamRelativeHeading(seat.camHeading or -10.0)

    while inLapDance do
        if GetEntityAnimCurrentTime(ped, dict, anim) >= 0.97 and GetEntityAnimCurrentTime(ped, dict, anim) < 1.0 then
            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
        end
        Wait(50)
    end

    FreezeEntityPosition(ped, false)
    playerSitted = false
    if not lapStop and seat.exit then
        SetEntityCoords(ped, seat.exit.x, seat.exit.y, seat.exit.z, false, false, false, false)
        Wait(200)
        if prevCamMode then SetFollowPedCamViewMode(prevCamMode) end
        TaskGoToCoordAnyMeans(ped, 117.48, -1294.82, 28.43, 1.0, 0, 0, 786603, 1.0)
        Wait(seat.exitWait or 5000)
    end
end

local function runStripperSequence(seat, stripperCfg, heading)
    local ped = lapStripper
    if not ped or not DoesEntityExist(ped) then return end

    SetEntityHeading(ped, heading or 303.19)
    FreezeEntityPosition(ped, true)
    loadDict('mini@strip_club@idles@stripper')
    TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 0, 0, false, false, false)

    TaskGoToCoordAnyMeans(ped, seat.stripperPath1.x, seat.stripperPath1.y, seat.stripperPath1.z, 1.0, 0, 0, 786603, 1.0)
    Wait(seat.approachWait or 5000)

    local repeatCount = -13
    local repeatMax = 0
    repeat
        Wait(200)
        repeatCount = repeatCount + 1
        repeatMax = repeatMax + 1
        if repeatCount == 17 then
            TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 0, 0, false, false, false)
            repeatCount = 0
        end
        if repeatMax >= 160 then break end
    until playerSitted or lapStop

    if lapStop then return end

    FreezeEntityPosition(ped, false)
    TaskGoToCoordAnyMeans(ped, seat.stripperPath2.x, seat.stripperPath2.y, seat.stripperPath2.z, 1.0, 0, 0, 786603, 1.0)
    Wait(1000)
    TaskGoToCoordAnyMeans(ped, seat.stripperDance.x, seat.stripperDance.y, seat.stripperDance.z, 1.0, 0, 0, 786603, 1.0)
    Wait(2100)

    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, heading or 303.19)
    stripperAnim(ped)

    if not lapStop then
        TaskGoToCoordAnyMeans(ped, seat.stripperEnd.x, seat.stripperEnd.y, seat.stripperEnd.z, 1.0, 0, 0, 786603, 1.0)
        Wait(2000)
        TaskPlayAnim(ped, 'mini@strip_club@idles@stripper', 'stripper_idle_02', 8.0, -8.0, -1, 0, 0, false, false, false)
    end
end

local function spawnLapStripper(stripperCfg, seat)
    local model = stripperCfg.model
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local s = seat.stripperSpawn
    local ped = CreatePed(4, model, s.x, s.y, s.z, s.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)

    if stripperCfg.components then
        for _, c in ipairs(stripperCfg.components) do
            SetPedComponentVariation(ped, c[1], c[2], c[3] or 0, 0)
        end
    end
    SetModelAsNoLongerNeeded(model)
    return ped
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
    if lapStripper and DoesEntityExist(lapStripper) then
        DeleteEntity(lapStripper)
    end
    lapStripper = nil
end

function StartLapDance(seatId, stripperIndex)
    if inLapDance then
        return QBCore.Functions.Notify('Jau vyksta šokis.', 'error')
    end

    local seat = nil
    for _, s in ipairs(Config.LapSeats or {}) do
        if s.id == seatId then seat = s break end
    end
    if not seat then return end

    local stripperCfg = Config.Strippers[stripperIndex or 1] or Config.Strippers[1]
    if not stripperCfg then return end

    QBCore.Functions.TriggerCallback('fivempro_stripclub:server:tryPay', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.msg or 'Mokėjimas nepavyko.', 'error')
        end

        lapStop = false
        inLapDance = true
        playerSitted = false
        local player = PlayerPedId()

        lapStripper = spawnLapStripper(stripperCfg, seat)
        SetEntityCoords(player, 116.88, -1295.04, 28.42, false, false, false, false)

        CreateThread(function()
            runStripperSequence(seat, stripperCfg, seat.stripperSpawn.w)
        end)

        CreateThread(function()
            Wait(800)
            while inLapDance and not playerSitted and not lapStop do
                local dist = #(GetEntityCoords(player) - seat.target)
                if dist < 1.2 then
                    playerSitLoop(player, seat)
                    break
                end
                Wait(100)
            end
        end)

        CreateThread(function()
            while inLapDance do
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 22, true)
                if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                    lapStop = true
                    break
                end
                Wait(0)
            end

            inLapDance = false
            FreezeEntityPosition(player, false)
            ClearPedTasks(player)
            if lapStripper and DoesEntityExist(lapStripper) then
                DeleteEntity(lapStripper)
            end
            lapStripper = nil
            TriggerServerEvent('fivempro_stripclub:server:releaseSeat', seatId)
            QBCore.Functions.Notify('Privatus šokis baigtas.', 'primary')
        end)
    end, 'lap', seatId)
end

function StartLeanThrow(heading)
    local player = PlayerPedId()
    local price = tonumber(Config.Prices.throwCash) or 40

    QBCore.Functions.TriggerCallback('fivempro_stripclub:server:tryPay', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.msg or 'Nepakanka grynųjų.', 'error')
        end

        local p = GetEntityCoords(player)
        SetEntityCoordsNoOffset(player, p.x, p.y, p.z, false, false, false)
        FreezeEntityPosition(player, true)
        SetEntityHeading(player, heading)

        local suf = femaleSuffix(player)
        loadDict('mini@strip_club@leaning@enter')
        TaskPlayAnim(player, 'mini@strip_club@leaning@enter', 'enter' .. suf, 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(2750)

        prevCamMode = GetFollowPedCamViewMode(player)
        SetFollowPedCamViewMode(4)
        SetGameplayCamRelativeHeading(0.0)
        loadDict('mini@strip_club@leaning@base')
        TaskPlayAnim(player, 'mini@strip_club@leaning@base', 'base' .. suf, 8.0, -8.0, -1, 1, 0, false, false, false)

        QBCore.Functions.Notify(('Metei $%s į sceną. SPACE dar kartą · ESC atsistoti.'):format(price), 'success')

        CreateThread(function()
            local leaning = true
            while leaning do
                if IsControlJustPressed(0, 22) then
                    QBCore.Functions.TriggerCallback('fivempro_stripclub:server:tryPay', function(r2)
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

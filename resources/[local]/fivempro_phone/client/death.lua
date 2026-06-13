local QBCore = exports['qb-core']:GetCoreObject()

local wasDown = false
local downSinceMs = nil
local holdGMs = 0.0
local deathFxActive = false
local lastNuiUpdateMs = 0

local function deathCfg()
    return Config.DeathScreen or {}
end

local function isDown()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return true end
    local P = QBCore.Functions.GetPlayerData()
    if P and P.metadata then
        if P.metadata.isdead or P.metadata.inlaststand then return true end
    end
    return false
end

local function sendDeathNui(show, payload)
    SendNUIMessage({
        action = 'deathScreen',
        show = show,
        title = payload and payload.title,
        timerSec = payload and payload.timerSec,
        canWake = payload and payload.canWake,
        holdSec = payload and payload.holdSec,
    })
end

local function startDeathFx()
    if deathFxActive then return end
    deathFxActive = true
    local cfg = deathCfg()
    local fx = cfg.postFx or 'DeathFailMPIn'
    pcall(function() AnimpostfxPlay(fx, 0, true) end)
    pcall(function() StartScreenEffect('DeathFailOut', 0, false) end)
    local tc = cfg.timecycle or 'damage'
    pcall(function()
        SetTimecycleModifier(tc)
        SetTimecycleModifierStrength(cfg.timecycleStrength or 0.72)
    end)
end

local function stopDeathFx()
    if not deathFxActive then return end
    deathFxActive = false
    sendDeathNui(false)
    local cfg = deathCfg()
    local fx = cfg.postFx or 'DeathFailMPIn'
    pcall(function() AnimpostfxStop(fx) end)
    pcall(function() AnimpostfxStop('DeathFailOut') end)
    pcall(function() StopScreenEffect('DeathFailOut') end)
    pcall(function()
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
    end)
end

local function updateDeathNui(elapsedMs, needSec, holdSec)
    local now = GetGameTimer()
    if now - lastNuiUpdateMs < 180 then return end
    lastNuiUpdateMs = now

    local canWake = elapsedMs >= needSec * 1000
    local timerSec = 0
    if not canWake then
        timerSec = math.max(0, math.ceil((needSec * 1000 - elapsedMs) / 1000))
    end

    sendDeathNui(true, {
        title = deathCfg().title or 'MIRĘS',
        timerSec = timerSec,
        canWake = canWake,
        holdSec = holdSec,
    })
end

AddEventHandler('fivempro_phone:local:AfterHospitalWake', function()
    wasDown = false
    downSinceMs = nil
    holdGMs = 0.0
    lastNuiUpdateMs = 0
    stopDeathFx()
end)

local function tryRequestMedic()
    if not isDown() then
        QBCore.Functions.Notify('Negalima – nesate sužeistas.', 'error')
        return
    end
    if IsPauseMenuActive() then return end
    if IsNuiFocused and IsNuiFocused() then return end
    local now = GetGameTimer()
    if now - (tryRequestMedic._last or 0) < 1500 then return end
    tryRequestMedic._last = now
    TriggerServerEvent('fivempro_phone:server:medicRequestFromDead')
end

CreateThread(function()
    while true do
        local down = isDown()
        if down then
            if not wasDown then
                wasDown = true
                downSinceMs = GetGameTimer()
                lastNuiUpdateMs = 0
                startDeathFx()
                TriggerServerEvent('fivempro_phone:server:reportDeath')
            end
        else
            if wasDown then
                wasDown = false
                downSinceMs = nil
                holdGMs = 0.0
                lastNuiUpdateMs = 0
                stopDeathFx()
                TriggerServerEvent('fivempro_phone:server:reportAlive')
            end
        end
        Wait(100)
    end
end)

CreateThread(function()
    local needSec = (Config.HospitalWake and Config.HospitalWake.waitAfterDeathSec) or 900
    local needHold = (Config.HospitalWake and Config.HospitalWake.holdGMs) or 2800.0
    while true do
        if wasDown and downSinceMs and not IsPauseMenuActive() and not (IsNuiFocused and IsNuiFocused()) then
            if IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 47) then
                tryRequestMedic()
            end
            local elapsed = GetGameTimer() - downSinceMs
            if elapsed >= needSec * 1000 then
                if IsControlPressed(0, 47) or IsDisabledControlPressed(0, 47) then
                    holdGMs = holdGMs + (GetFrameTime() * 1000.0)
                    if holdGMs >= needHold then
                        holdGMs = 0.0
                        TriggerServerEvent('fivempro_phone:server:hospitalWake')
                        Wait(900)
                    end
                else
                    holdGMs = 0.0
                end
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    local needSec = (Config.HospitalWake and Config.HospitalWake.waitAfterDeathSec) or 900
    local needHold = (Config.HospitalWake and Config.HospitalWake.holdGMs) or 2800.0
    local holdSec = math.max(1, math.floor(needHold / 1000 + 0.5))
    while true do
        if wasDown and downSinceMs and not IsPauseMenuActive() and not (IsNuiFocused and IsNuiFocused()) then
            if not deathFxActive then startDeathFx() end
            local elapsedMs = GetGameTimer() - downSinceMs
            updateDeathNui(elapsedMs, needSec, holdSec)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

RegisterCommand('fivempro_phone_medic', function()
    tryRequestMedic()
end, false)

RegisterKeyMapping(
    'fivempro_phone_medic',
    'Iškviesti medikus (kai miręs)',
    'keyboard',
    (Config.Emergency and Config.Emergency.medicRequestKey) or 'G'
)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopDeathFx()
end)

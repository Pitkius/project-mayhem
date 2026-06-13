local QBCore = exports['qb-core']:GetCoreObject()

local wasDown = false
local downSinceMs = nil
local holdGMs = 0.0
local deathFxActive = false

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

local function pulse()
    return (math.sin(GetGameTimer() / 380.0) + 1.0) * 0.5
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

local function drawOverlay()
    local cfg = deathCfg()
    local blood = cfg.blood or { r = 175, g = 18, b = 38 }
    local accent = cfg.accent or { r = 191, g = 95, b = 255 }
    local p = pulse()

    DrawRect(0.5, 0.5, 1.0, 1.0, 6, 0, 10, 200)

    local edgeA = math.floor(95 + p * 55)
    DrawRect(0.5, 0.0, 1.0, 0.22, blood.r, blood.g, blood.b, edgeA)
    DrawRect(0.5, 1.0, 1.0, 0.22, blood.r, blood.g, blood.b, edgeA)
    DrawRect(0.0, 0.5, 0.14, 1.0, blood.r, blood.g, blood.b, math.floor(75 + p * 45))
    DrawRect(1.0, 0.5, 0.14, 1.0, blood.r, blood.g, blood.b, math.floor(75 + p * 45))

    DrawRect(0.5, 0.40, 0.62, 0.28, accent.r, accent.g, accent.b, math.floor(10 + p * 14))
    DrawRect(0.5, 0.40, 0.58, 0.24, blood.r, blood.g, blood.b, math.floor(18 + p * 12))

    for i = 1, 6 do
        local x = 0.12 + (i * 0.14)
        local dripH = 0.08 + (math.sin((GetGameTimer() + i * 420) / 520.0) + 1.0) * 0.06
        DrawRect(x, 0.04 + dripH * 0.5, 0.018, dripH, blood.r, blood.g, blood.b, math.floor(40 + p * 35))
    end
end

local function drawCenterText(y, text, scale, r, g, b, a)
    if GetResourceState('fivempro_fonts') == 'started' then
        pcall(function()
            exports['fivempro_fonts']:UseNativeFont()
        end)
    end
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a or 255)
    SetTextOutline()
    SetTextCentre(true)
    SetTextDropShadow()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, y)
end

local function drawDeathScreen(elapsedMs, needSec, holdSec)
    local cfg = deathCfg()
    local blood = cfg.blood or { r = 175, g = 18, b = 38 }
    local accent = cfg.accent or { r = 191, g = 95, b = 255 }
    local p = pulse()

    drawOverlay()

    local titleScale = 1.05 + p * 0.08
    drawCenterText(0.36, cfg.title or 'MIRĘS', titleScale, blood.r, blood.g, blood.b, 255)
    drawCenterText(0.445, '─ ─ ─', 0.42, accent.r, accent.g, accent.b, math.floor(160 + p * 60))

    drawCenterText(
        0.50,
        'SPAUSK  G  —  iškviesti medikus',
        0.50,
        255, 245, 250, 255
    )
    drawCenterText(
        0.555,
        'EMS pamatys tavo vietą žemėlapyje',
        0.38,
        accent.r, accent.g, accent.b, math.floor(200 + p * 40)
    )

    if elapsedMs >= needSec * 1000 then
        drawCenterText(
            0.615,
            ('Laikyk  G  ~%ss — prisikelti artimiausioje ligoninėje'):format(holdSec),
            0.44,
            140, 255, 175, 255
        )
    else
        local leftSec = math.max(0, math.ceil((needSec * 1000 - elapsedMs) / 1000))
        local mm = math.floor(leftSec / 60)
        local ss = leftSec % 60
        drawCenterText(
            0.615,
            ('Liko %d:%.2d — tada laikyk G ligoninėje'):format(mm, ss),
            0.44,
            255, 210, 120, 255
        )
    end
end

AddEventHandler('fivempro_phone:local:AfterHospitalWake', function()
    wasDown = false
    downSinceMs = nil
    holdGMs = 0.0
    stopDeathFx()
end)

CreateThread(function()
    while true do
        local down = isDown()
        if down then
            if not wasDown then
                wasDown = true
                downSinceMs = GetGameTimer()
                startDeathFx()
                TriggerServerEvent('fivempro_phone:server:reportDeath')
            end
        else
            if wasDown then
                wasDown = false
                downSinceMs = nil
                holdGMs = 0.0
                stopDeathFx()
                TriggerServerEvent('fivempro_phone:server:reportAlive')
            end
        end
        Wait(250)
    end
end)

CreateThread(function()
    local needSec = (Config.HospitalWake and Config.HospitalWake.waitAfterDeathSec) or 900
    local needHold = (Config.HospitalWake and Config.HospitalWake.holdGMs) or 2800.0
    while true do
        if wasDown and downSinceMs and not IsPauseMenuActive() and not (IsNuiFocused and IsNuiFocused()) then
            local elapsed = GetGameTimer() - downSinceMs
            if elapsed >= needSec * 1000 then
                if IsControlPressed(0, 47) then
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
            drawDeathScreen(elapsedMs, needSec, holdSec)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

RegisterCommand('fivempro_phone_medic', function()
    if not wasDown then return end
    if IsPauseMenuActive() then return end
    if IsNuiFocused and IsNuiFocused() then return end
    TriggerServerEvent('fivempro_phone:server:medicRequestFromDead')
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

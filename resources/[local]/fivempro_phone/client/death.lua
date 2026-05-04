local QBCore = exports['qb-core']:GetCoreObject()

local wasDown = false
local downSinceMs = nil
local holdGMs = 0.0

local function isDown()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return true end
    local P = QBCore.Functions.GetPlayerData()
    if P and P.metadata then
        if P.metadata.isdead or P.metadata.inlaststand then return true end
    end
    return false
end

local function drawLine(y, text, r, g, b)
    SetTextFont(4)
    SetTextScale(0.36, 0.36)
    SetTextColour(r, g, b, 245)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, y)
end

AddEventHandler('fivempro_phone:local:AfterHospitalWake', function()
    wasDown = false
    downSinceMs = nil
    holdGMs = 0.0
end)

CreateThread(function()
    while true do
        local down = isDown()
        if down then
            if not wasDown then
                wasDown = true
                downSinceMs = GetGameTimer()
                TriggerServerEvent('fivempro_phone:server:reportDeath')
            end
        else
            if wasDown then
                wasDown = false
                downSinceMs = nil
                holdGMs = 0.0
                TriggerServerEvent('fivempro_phone:server:reportAlive')
            end
        end
        Wait(250)
    end
end)

--- Po laukti laikotarpio: laikyk G (INPUT_DETONATE = 47)
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

--- Ekrano instrukcijos: M visada; G – po laukimo
CreateThread(function()
    local needSec = (Config.HospitalWake and Config.HospitalWake.waitAfterDeathSec) or 900
    local needHold = (Config.HospitalWake and Config.HospitalWake.holdGMs) or 2800.0
    local holdSec = math.max(1, math.floor(needHold / 1000 + 0.5))
    while true do
        if wasDown and downSinceMs and not IsPauseMenuActive() and not (IsNuiFocused and IsNuiFocused()) then
            local elapsedMs = GetGameTimer() - downSinceMs
            drawLine(0.70, 'SPAUSK M – iškviesti medikus (EMS pamatys tavo vietą žemėlapyje)', 120, 220, 255)
            if elapsedMs >= needSec * 1000 then
                drawLine(
                    0.76,
                    ('Laikyk G ~%ss – prisikelti ARTIMIAUSIOJE ligoninėje'):format(holdSec),
                    180, 255,
                    180
                )
            else
                local leftSec = math.max(0, math.ceil((needSec * 1000 - elapsedMs) / 1000))
                local mm = math.floor(leftSec / 60)
                local ss = leftSec % 60
                drawLine(
                    0.76,
                    ('Liko %d:%.2d – tada laikyk G ir prisikelsi artimiausioje ligoninėje'):format(mm, ss),
                    255,
                    220,
                    160
                )
            end
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

RegisterKeyMapping('fivempro_phone_medic', 'Iškviesti medikus (kai miręs)', 'keyboard', 'M')

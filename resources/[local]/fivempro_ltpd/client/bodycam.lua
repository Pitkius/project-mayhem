local QBCore = exports['qb-core']:GetCoreObject()

local bodycamEquipped = false
local bodycamViewCam = nil
local bodycamViewTarget = nil
local bodycamOverlaySent = false

local function isPdOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    local n = P.job.name
    if n == Config.JobName then return P.job.onduty end
    return false
end

local function destroyBodycamView()
    if bodycamViewCam and DoesCamExist(bodycamViewCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(bodycamViewCam, false)
    end
    bodycamViewCam = nil
    bodycamViewTarget = nil
    bodycamOverlaySent = false
    ClearFocus()
    SendNUIMessage({ action = 'bodycamOverlay', active = false })
end

function StopLtpdBodycamView()
    destroyBodycamView()
    TriggerEvent('fivempro_ltpd:client:mdtCctvFocus', true)
end

local function playBodycamAnim(on)
    local ped = PlayerPedId()
    local dict = 'clothingtie'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Wait(10)
        t = t + 1
    end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, on and 'try_tie_positive_a' or 'try_tie_negative_a', 4.0, -4.0, 1200, 48, 0, false, false, false)
    end
end

local function bodycamBeep(on)
    PlaySoundFrontend(-1, on and 'CONFIRM_BEEP' or 'BACK', 'HUD_MINI_GAME_SOUNDSET', true)
end

RegisterNetEvent('fivempro_ltpd:client:bodycamUseItem', function()
    if not isPdOnDuty() then
        return QBCore.Functions.Notify('Kūno kamera – tik policijai tarnyboje.', 'error')
    end
  TriggerServerEvent('fivempro_ltpd:server:bodycamToggle')
end)

RegisterNetEvent('fivempro_ltpd:client:bodycamState', function(active, reason)
    bodycamEquipped = active == true
    if active then
        playBodycamAnim(true)
        bodycamBeep(true)
    else
        playBodycamAnim(false)
        if reason ~= 'toggle' then bodycamBeep(false) end
        destroyBodycamView()
    end
end)

RegisterNetEvent('fivempro_ltpd:client:surveillanceStopAll', function()
    destroyBodycamView()
end)

RegisterNUICallback('bodycamList', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:bodycamList', function(res)
        cb(res or { ok = false, feeds = {} })
    end)
end)

RegisterNUICallback('bodycamWatch', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:bodycamWatch', function(res)
        if not res or not res.ok then
            destroyBodycamView()
            cb(res or { ok = false })
            return
        end
        bodycamViewTarget = res.targetId
        destroyBodycamView()
        bodycamViewTarget = res.targetId
        SendNUIMessage({ action = 'bodycamOverlay', active = true, targetId = res.targetId })
        TriggerEvent('fivempro_ltpd:client:mdtCctvFocus', false)
        cb(res)
    end, data and data.targetId)
end)

RegisterNUICallback('bodycamStop', function(_, cb)
    StopLtpdBodycamView()
    cb({ ok = true })
end)

--- Panic → auto bodycam
RegisterNetEvent('fivempro_dispatch:client:panic', function()
    TriggerServerEvent('fivempro_ltpd:server:bodycamPanicAutoOn')
end)

CreateThread(function()
    while true do
        if bodycamViewTarget then
            local target = GetPlayerFromServerId(bodycamViewTarget)
            if target == -1 then
                StopLtpdBodycamView()
            else
                local tPed = GetPlayerPed(target)
                if not tPed or tPed == 0 or not DoesEntityExist(tPed) then
                    StopLtpdBodycamView()
                else
                    local bone = GetPedBoneIndex(tPed, 31086)
                    local pos = GetPedBoneCoords(tPed, bone, 0.12, 0.18, 0.02)
                    local fwd = GetEntityForwardVector(tPed)
                    local look = vector3(pos.x + fwd.x * 2.0, pos.y + fwd.y * 2.0, pos.z + 0.05)
                    if not bodycamViewCam or not DoesCamExist(bodycamViewCam) then
                        bodycamViewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                        SetCamActive(bodycamViewCam, true)
                        RenderScriptCams(true, false, 0, true, true)
                        if not bodycamOverlaySent then
                            bodycamOverlaySent = true
                            SendNUIMessage({ action = 'bodycamOverlay', active = true, targetId = bodycamViewTarget })
                        end
                    end
                    SetCamCoord(bodycamViewCam, pos.x, pos.y, pos.z)
                    PointCamAtCoord(bodycamViewCam, look.x, look.y, look.z)
                    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
                end
            end
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177) then
                StopLtpdBodycamView()
            end
            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        if bodycamEquipped then
            if IsEntityDead(PlayerPedId()) then
                TriggerServerEvent('fivempro_ltpd:server:bodycamForceOff', 'death')
                bodycamEquipped = false
            end
            Wait(500)
        else
            Wait(1200)
        end
    end
end)

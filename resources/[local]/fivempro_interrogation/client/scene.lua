InterrogationScene = InterrogationScene or {}

local spotlightOn = false
local spotlightData = nil
local scriptCam = nil
local recording = false
local pressureFx = 0
local blindfoldOn = false
local noisePlaying = false
local heartbeatThread = false

local function loadDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

function InterrogationScene.playAnim(ped, key)
    local cfg = Config.Anims and Config.Anims[key]
    if not cfg or not ped or ped == 0 then return end
    if not loadDict(cfg.dict) then return end
    local dur = (cfg.flag == 1) and -1 or 3200
    TaskPlayAnim(ped, cfg.dict, cfg.name, 8.0, -8.0, dur, cfg.flag or 48, 0, false, false, false)
end

function InterrogationScene.seatSuspect(ped, seat, animKey)
    if not ped or ped == 0 or not seat then return end
    SetEntityCoords(ped, seat.x, seat.y, seat.z, false, false, false, false)
    SetEntityHeading(ped, seat.w or 0.0)
    FreezeEntityPosition(ped, true)
    InterrogationScene.playAnim(ped, animKey or 'suspectSitCalm')
end

function InterrogationScene.unseatSuspect(ped)
    if not ped or ped == 0 then return end
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

function InterrogationScene.setSpotlight(on, data)
    spotlightOn = on == true
    spotlightData = data
end

function InterrogationScene.setRecording(on, camCfg)
    recording = on == true
    if recording and camCfg then
        if scriptCam and DoesCamExist(scriptCam) then
            DestroyCam(scriptCam, false)
        end
        scriptCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(scriptCam, camCfg.pos.x, camCfg.pos.y, camCfg.pos.z)
        PointCamAtCoord(scriptCam, camCfg.point.x, camCfg.point.y, camCfg.point.z)
        SetCamFov(scriptCam, camCfg.fov or 50.0)
        RenderScriptCams(true, true, 500, true, false)
    else
        if scriptCam and DoesCamExist(scriptCam) then
            RenderScriptCams(false, true, 400, true, false)
            DestroyCam(scriptCam, false)
            scriptCam = nil
        end
    end
end

function InterrogationScene.setBlindfold(on)
    blindfoldOn = on == true
end

function InterrogationScene.setPressureLevel(level)
    pressureFx = math.max(0, math.min(100, tonumber(level) or 0))
    SendNUIMessage({
        action = 'pressure',
        level = pressureFx,
        blindfold = blindfoldOn,
        recording = recording,
    })
    if pressureFx <= 0 and not blindfoldOn then
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
    elseif pressureFx >= 25 then
        SetTimecycleModifier('spectator_01')
        SetTimecycleModifierStrength(math.min(0.85, 0.2 + pressureFx / 120.0))
    end
    if pressureFx >= 55 then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', math.min(0.25, pressureFx / 400.0))
    end
    if pressureFx >= 30 and not heartbeatThread then
        heartbeatThread = true
        CreateThread(function()
            while pressureFx >= 30 do
                PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                Wait(math.max(450, 1100 - pressureFx * 6))
            end
            heartbeatThread = false
        end)
    end
end

function InterrogationScene.playNoiseBurst()
    noisePlaying = true
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(80)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    SetTimeout(1200, function()
        noisePlaying = false
    end)
end

function InterrogationScene.cleanup()
    spotlightOn = false
    spotlightData = nil
    InterrogationScene.setRecording(false)
    InterrogationScene.setBlindfold(false)
    InterrogationScene.setPressureLevel(0)
    SendNUIMessage({ action = 'hide' })
    SendNUIMessage({ action = 'policeControls', show = false })
    SendNUIMessage({ action = 'gangControls', show = false })
    local ped = PlayerPedId()
    InterrogationScene.unseatSuspect(ped)
end

CreateThread(function()
    while true do
        if spotlightOn and spotlightData then
            local o = spotlightData.origin
            local t = spotlightData.target
            if o and t then
                local dx, dy, dz = t.x - o.x, t.y - o.y, t.z - o.z
                local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                if len > 0.01 then
                    dx, dy, dz = dx / len, dy / len, dz / len
                    DrawSpotLight(o.x, o.y, o.z, dx, dy, dz, 255, 248, 220, 28.0, 2.2, 0.0, 42.0, 1.0)
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

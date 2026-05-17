local QBCore = exports['qb-core']:GetCoreObject()

local cctvCam = nil
local cctvActive = false
local cctvAudio = false
local cctvFocus = nil

local function destroyCctvCam()
    if cctvCam and DoesCamExist(cctvCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cctvCam, false)
    end
    cctvCam = nil
    cctvActive = false
    cctvAudio = false
    if cctvFocus then
        ClearFocus()
        cctvFocus = nil
    end
end

function StopLtpdCctvView()
    destroyCctvCam()
    SendNUIMessage({ action = 'cctvOverlay', active = false })
end

local function startCctvView(cam)
    destroyCctvCam()
    local c = cam.coords
    local l = cam.lookAt
    cctvCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cctvCam, c.x, c.y, c.z)
    PointCamAtCoord(cctvCam, l.x, l.y, l.z)
    SetCamFov(cctvCam, cam.fov or 55.0)
    SetCamActive(cctvCam, true)
    RenderScriptCams(true, false, 0, true, true)
    cctvActive = true
    cctvAudio = cam.audio == true
    if cctvAudio then
        SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
        cctvFocus = true
    end
    SendNUIMessage({ action = 'cctvOverlay', active = true, label = cam.label, audio = cctvAudio })
end

RegisterNetEvent('fivempro_ltpd:client:surveillanceStopAll', function()
    StopLtpdCctvView()
end)

RegisterNUICallback('cctvList', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:cctvList', function(res)
        cb(res or { ok = false, cameras = {} })
    end)
end)

RegisterNUICallback('cctvWatch', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:cctvWatch', function(res)
        if res and res.ok and res.cam then
            startCctvView(res.cam)
        else
            StopLtpdCctvView()
        end
        cb(res or { ok = false })
    end, data and data.camId)
end)

RegisterNUICallback('cctvStop', function(_, cb)
    StopLtpdCctvView()
    cb({ ok = true })
end)

RegisterNUICallback('cctvToggleAudio', function(data, cb)
    if not cctvActive or not cctvCam then
        cb({ ok = false })
        return
    end
    cctvAudio = data and data.enabled == true
    local c = GetCamCoord(cctvCam)
    if cctvAudio then
        SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
        cctvFocus = true
    else
        ClearFocus()
        cctvFocus = nil
    end
    cb({ ok = true, audio = cctvAudio })
end)

CreateThread(function()
    while true do
        if cctvActive and cctvCam and DoesCamExist(cctvCam) then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 200, true)
            if cctvAudio and cctvFocus then
                local c = GetCamCoord(cctvCam)
                SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

local QBCore = exports['qb-core']:GetCoreObject()

local cctvCam = nil
local cctvActive = false
local cctvAudio = false
local cctvFocus = nil
local cctvSession = 0
local cctvBase = nil ---@type { pos: vector3, look: vector3, fov: number, label: string, id: string }
local cctvYaw = 0.0
local cctvPitch = 0.0

local CFG = {
    yawMax = 60.0,
    pitchMax = 20.0,
    rotateSpeed = 1.35,
}

local function destroyCctvCam()
    cctvSession = cctvSession + 1
    if cctvCam and DoesCamExist(cctvCam) then
        RenderScriptCams(false, true, 200, true, true)
        DestroyCam(cctvCam, false)
    end
    cctvCam = nil
    cctvActive = false
    cctvAudio = false
    cctvBase = nil
    cctvYaw = 0.0
    cctvPitch = 0.0
    if cctvFocus then
        ClearFocus()
        cctvFocus = nil
    end
    ClearTimecycleModifier()
    SetNightvision(false)
    SetSeethrough(false)
end

function StopLtpdCctvView()
    destroyCctvCam()
    SendNUIMessage({
        action = 'cctvOverlay',
        active = false,
        label = '',
        camId = '',
        rec = false,
    })
end

local function applyCctvLook()
    if not cctvCam or not DoesCamExist(cctvCam) or not cctvBase then return end
    local pos = cctvBase.pos
    local look = cctvBase.look
    local dir = look - pos
    local dist = #(dir)
    if dist < 0.01 then return end
    dir = dir / dist
    local yawRad = math.rad(cctvYaw)
    local pitchRad = math.rad(cctvPitch)
    local cosP = math.cos(pitchRad)
    local rotDir = vector3(
        dir.x * math.cos(yawRad) - dir.y * math.sin(yawRad),
        dir.x * math.sin(yawRad) + dir.y * math.cos(yawRad),
        dir.z
    )
    rotDir = vector3(rotDir.x * cosP, rotDir.y * cosP, rotDir.z + math.sin(pitchRad))
    local mag = #(rotDir)
    if mag < 0.01 then return end
    rotDir = rotDir / mag
    local target = pos + rotDir * dist
    SetCamCoord(cctvCam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cctvCam, target.x, target.y, target.z)
end

local function startCctvView(cam)
    StopLtpdCctvView()
    local session = cctvSession + 1
    cctvSession = session

    local c = cam.coords
    local l = cam.lookAt
    cctvBase = {
        pos = vector3(c.x, c.y, c.z),
        look = vector3(l.x, l.y, l.z),
        fov = cam.fov or 52.0,
        label = cam.label or 'CCTV',
        id = cam.id or '—',
    }
    cctvYaw = 0.0
    cctvPitch = 0.0

    cctvCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cctvCam, cctvBase.pos.x, cctvBase.pos.y, cctvBase.pos.z)
    SetCamFov(cctvCam, cctvBase.fov)
    applyCctvLook()
    SetCamActive(cctvCam, true)
    RenderScriptCams(true, true, 250, true, true)
    cctvActive = true
    cctvAudio = cam.audio == true

    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(0.45)

    if cctvAudio then
        SetFocusPosAndVel(cctvBase.pos.x, cctvBase.pos.y, cctvBase.pos.z, 0.0, 0.0, 0.0)
        cctvFocus = true
    end

    SendNUIMessage({
        action = 'cctvOverlay',
        active = true,
        label = cctvBase.label,
        camId = cctvBase.id,
        audio = cctvAudio,
        rec = true,
    })
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
    if not cctvActive or not cctvCam or not cctvBase then
        cb({ ok = false })
        return
    end
    cctvAudio = data and data.enabled == true
    if cctvAudio then
        SetFocusPosAndVel(cctvBase.pos.x, cctvBase.pos.y, cctvBase.pos.z, 0.0, 0.0, 0.0)
        cctvFocus = true
    else
        ClearFocus()
        cctvFocus = nil
    end
    cb({ ok = true, audio = cctvAudio })
end)

CreateThread(function()
    while true do
        if cctvActive and cctvCam and DoesCamExist(cctvCam) and cctvBase then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 200, true)

            local lr = GetDisabledControlNormal(0, 1)
            local ud = GetDisabledControlNormal(0, 2)
            if math.abs(lr) > 0.02 or math.abs(ud) > 0.02 then
                cctvYaw = math.max(-CFG.yawMax, math.min(CFG.yawMax, cctvYaw - lr * CFG.rotateSpeed * 14.0))
                cctvPitch = math.max(-CFG.pitchMax, math.min(CFG.pitchMax, cctvPitch - ud * CFG.rotateSpeed * 10.0))
                applyCctvLook()
            end

            if cctvAudio and cctvFocus then
                SetFocusPosAndVel(cctvBase.pos.x, cctvBase.pos.y, cctvBase.pos.z, 0.0, 0.0, 0.0)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    StopLtpdCctvView()
end)

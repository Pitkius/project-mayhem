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
    TriggerEvent('fivempro_ltpd:client:mdtCctvFocus', true)
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

    local pos, look, yawMax, pitchMax = ResolveCctvCameraView(cam)
    if not pos or not look then
        local c = cam.coords
        local l = cam.lookAt
        if c and l then
            pos = vector3(c.x, c.y, c.z)
            look = vector3(l.x, l.y, l.z)
        end
    end
    if not pos or not look then return end

    CFG.yawMax = tonumber(yawMax) or 60.0
    CFG.pitchMax = tonumber(pitchMax) or 20.0

    cctvBase = {
        pos = pos,
        look = look,
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
    SetTimecycleModifierStrength(0.62)

    TriggerEvent('fivempro_ltpd:client:mdtCctvFocus', false)

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
    local done = false
    local function reply(res)
        if done then return end
        done = true
        cb(res or { ok = false, cameras = {}, sites = {} })
    end
    SetTimeout(12000, function()
        reply({ ok = false, msg = 'CCTV sąrašo timeout' })
    end)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:cctvList', function(res)
        reply(res)
    end)
end)

RegisterNUICallback('cctvWatch', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:cctvWatch', function(res)
        if res and res.ok then
            local camId = tostring((data and data.camId) or (res.cam and res.cam.id) or '')
            local fullCam = nil
            for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
                if c.id == camId then fullCam = c break end
            end
            startCctvView(fullCam or res.cam)
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

RegisterNUICallback('cctvSwitch', function(data, cb)
    local camId = data and data.camId
    if not camId then
        cb({ ok = false })
        return
    end
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:cctvWatch', function(res)
        if res and res.ok then
            local fullCam = nil
            for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
                if c.id == camId then fullCam = c break end
            end
            startCctvView(fullCam or res.cam)
        else
            StopLtpdCctvView()
        end
        cb(res or { ok = false })
    end, camId)
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

            if IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177) then
                StopLtpdCctvView()
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

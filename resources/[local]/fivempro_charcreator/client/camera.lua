CharCamera = CharCamera or {}

local cam = nil
local activePreset = 'default'

local function pedPos()
    local p = Config.PedCoords
    return vector3(p.x, p.y, p.z)
end

function CharCamera.enable()
    TriggerEvent('qb-weathersync:client:DisableSync')
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(0.65)
    CharCamera.setPreset('default', true)
end

function CharCamera.disable()
    SetTimecycleModifier('default')
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    TriggerEvent('qb-weathersync:client:EnableSync')
end

function CharCamera.setPreset(name, instant)
    local preset = Config.Cameras and Config.Cameras[name] or Config.Cameras.default
    if not preset then return end
    activePreset = name

    local base = pedPos()
    local heading = math.rad((Config.PedCoords.w or 0.0) + 180.0)
    local off = preset.offset
    local cx = base.x + off.x * math.cos(heading) - off.y * math.sin(heading)
    local cy = base.y + off.x * math.sin(heading) + off.y * math.cos(heading)
    local cz = base.z + off.z

    local pt = preset.point
    local tx = base.x + pt.x * math.cos(heading) - pt.y * math.sin(heading)
    local ty = base.y + pt.x * math.sin(heading) + pt.y * math.cos(heading)
    local tz = base.z + pt.z

    if not cam or not DoesCamExist(cam) then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    SetCamCoord(cam, cx, cy, cz)
    PointCamAtCoord(cam, tx, ty, tz)
    SetCamFov(cam, preset.fov or 42.0)
    if not instant then
        SetCamActiveWithInterp(cam, cam, 600, 1, 1)
    end
end

function CharCamera.forStep(stepId)
    local map = {
        personal = 'face',
        genetics = 'face',
        eyes = 'eyes',
        hair = 'hair',
        facedetails = 'face',
        body = 'body',
        voice = 'face',
        clothes = 'clothes',
        review = 'body',
    }
    CharCamera.setPreset(map[stepId] or 'default', false)
end

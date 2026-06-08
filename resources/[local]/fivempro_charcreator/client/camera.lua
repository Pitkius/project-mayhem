CharCamera = CharCamera or {}

local cam = nil
local activePreset = 'default'
local orbitAngle = 0.0
local rotateThreadActive = false
local shopAnchor = nil

local function pedPos()
    if shopAnchor then
        return vector3(shopAnchor.x, shopAnchor.y, shopAnchor.z)
    end
    local p = Config.PedCoords
    return vector3(p.x, p.y, p.z)
end

local function baseHeadingDeg()
    if shopAnchor then
        return (shopAnchor.w or 0.0) + 180.0 + orbitAngle
    end
    return (Config.PedCoords.w or 0.0) + 180.0 + orbitAngle
end

function CharCamera.setShopAnchor(coords)
    shopAnchor = coords
end

function CharCamera.clearShopAnchor()
    shopAnchor = nil
end

local function applyCamera(instant)
    local preset = Config.Cameras and Config.Cameras[activePreset] or Config.Cameras.default
    if not preset then return end

    local base = pedPos()
    local heading = math.rad(baseHeadingDeg())
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
end

function CharCamera.addOrbit(delta)
    if not delta or delta == 0 then return end
    orbitAngle = (orbitAngle + delta) % 360.0
    if orbitAngle < 0 then orbitAngle = orbitAngle + 360.0 end
    applyCamera(true)
end

function CharCamera.enable()
    orbitAngle = 0.0
    rotateThreadActive = true
    TriggerEvent('qb-weathersync:client:DisableSync')
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(0.65)
    applyCamera(true)

    CreateThread(function()
        local speed = Config.CameraRotateSpeed or 2.5
        while rotateThreadActive do
            Wait(0)
            local delta = 0.0
            if IsControlPressed(0, 174) or IsDisabledControlPressed(0, 174) then
                delta = -speed
            elseif IsControlPressed(0, 175) or IsDisabledControlPressed(0, 175) then
                delta = speed
            end
            if delta ~= 0.0 then
                CharCamera.addOrbit(delta)
            end
        end
    end)
end

function CharCamera.disable()
    rotateThreadActive = false
    CharCamera.clearShopAnchor()
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
    applyCamera(instant)
end

function CharCamera.forStep(stepId)
    local map = {
        personal = 'face',
        genetics = 'face',
        eyes = 'eyes',
        hair = 'hair',
        facedetails = 'face',
        body = 'body',
        clothes = 'clothes',
        review = 'body',
    }
    CharCamera.setPreset(map[stepId] or 'default', false)
end

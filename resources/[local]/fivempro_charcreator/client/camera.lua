CharCamera = CharCamera or {}

local cam = nil
local activePreset = 'default'
local orbitAngle = 0.0
local rotateThreadActive = false
local shopAnchor = nil
local targetPed = 0

function CharCamera.setTargetPed(ped)
    targetPed = ped or 0
end

function CharCamera.setShopAnchor(coords)
    shopAnchor = coords
end

function CharCamera.clearShopAnchor()
    shopAnchor = nil
end

local function pedBase()
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        return GetEntityCoords(targetPed)
    end
    if shopAnchor then
        return vector3(shopAnchor.x, shopAnchor.y, shopAnchor.z)
    end
    local p = Config.PedCoords
    return vector3(p.x, p.y, p.z)
end

local function pedHeadingDeg()
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        return GetEntityHeading(targetPed) + 180.0 + orbitAngle
    end
    if shopAnchor then
        return (shopAnchor.w or 0.0) + 180.0 + orbitAngle
    end
    return (Config.PedCoords.w or 0.0) + 180.0 + orbitAngle
end

local function applyCamera()
    local preset = Config.Cameras and Config.Cameras[activePreset] or Config.Cameras.default
    if not preset then return end

    local base = pedBase()
    local heading = math.rad(pedHeadingDeg())
    local dist = preset.distance or 2.5
    local camZ = preset.camHeight or 0.35
    local lookZ = preset.lookAt or 0.55

    local cx = base.x - dist * math.sin(heading)
    local cy = base.y + dist * math.cos(heading)
    local cz = base.z + camZ

    local tx = base.x
    local ty = base.y
    local tz = base.z + lookZ

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
    applyCamera()
end

local function refreshSceneLighting()
    NetworkOverrideClockTime(14, 30, 0)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist('CLEAR')
    SetWeatherTypeNow('CLEAR')
    SetRainLevel(0.0)
end

function CharCamera.enable()
    orbitAngle = 0.0
    rotateThreadActive = true
    TriggerEvent('qb-weathersync:client:DisableSync')
    ClearTimecycleModifier()
    SetTimecycleModifierStrength(0.0)
    refreshSceneLighting()

    local base = pedBase()
    SetFocusPosAndVel(base.x, base.y, base.z, 0.0, 0.0, 0.0)
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        SetFocusEntity(targetPed)
    end

    applyCamera()

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
    CharCamera.setTargetPed(0)
    ClearFocus()
    ClearTimecycleModifier()
    SetTimecycleModifierStrength(0.0)
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    TriggerEvent('qb-weathersync:client:EnableSync')
end

function CharCamera.setPreset(name)
    local preset = Config.Cameras and Config.Cameras[name] or Config.Cameras.default
    if not preset then return end
    activePreset = name
    applyCamera()
end

function CharCamera.forStep(stepId)
    local map = {
        personal = 'default',
        genetics = 'face',
        eyes = 'face',
        hair = 'hair',
        facedetails = 'face',
        body = 'body',
        clothes = 'body',
        review = 'body',
    }
    CharCamera.setPreset(map[stepId] or 'default')
end

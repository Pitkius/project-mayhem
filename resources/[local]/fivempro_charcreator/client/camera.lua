CharCamera = CharCamera or {}

local cam = nil
local activePreset = 'default'
local orbitAngle = 0.0
local rotateThreadActive = false
local controlLockThread = false
local shopAnchor = nil
local targetPed = 0

local BLOCKED_CONTROLS = {
    21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47, 58,
    140, 141, 142, 143, 257, 263, 264, 266, 267, 268, 269, 270, 271, 272,
}

local function clearCoverState(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetPedCanPeekInCover(ped, false)
    if IsPedInCover(ped, false) or IsPedGoingIntoCover(ped) then
        ClearPedTasks(ped)
    end
end

local function restoreCoverAbility()
    SetPlayerCanUseCover(PlayerId(), false)
    local ped = PlayerPedId()
    if ped ~= 0 and DoesEntityExist(ped) then
        SetPedCanPeekInCover(ped, false)
    end
end

local function startControlLock()
    if controlLockThread then return end
    controlLockThread = true
    SetPlayerCanUseCover(PlayerId(), false)
    CreateThread(function()
        while rotateThreadActive do
            Wait(0)
            local playerId = PlayerId()
            local ped = PlayerPedId()
            SetPlayerCanUseCover(playerId, false)
            for _, ctrl in ipairs(BLOCKED_CONTROLS) do
                DisableControlAction(0, ctrl, true)
                DisableControlAction(1, ctrl, true)
                DisableControlAction(2, ctrl, true)
            end
            DisablePlayerFiring(playerId, true)
            if ped ~= 0 then
                FreezeEntityPosition(ped, true)
                clearCoverState(ped)
            end
            if targetPed ~= 0 and DoesEntityExist(targetPed) and targetPed ~= ped then
                clearCoverState(targetPed)
            end
        end
        restoreCoverAbility()
        controlLockThread = false
    end)
end

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
    NetworkOverrideClockTime(12, 0, 0)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist('EXTRASUNNY')
    SetWeatherTypeNow('EXTRASUNNY')
    SetRainLevel(0.0)
    SetArtificialLightsState(true)
    ClearTimecycleModifier()
    SetTimecycleModifier('MP_corona_heist_blend')
    SetTimecycleModifierStrength(0.28)
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
    startControlLock()

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
            local base = pedBase()
            DrawLightWithRange(base.x, base.y, base.z + 1.35, 255, 248, 240, 2.8, 4.2)
            DrawLightWithRange(base.x + 0.6, base.y + 0.4, base.z + 0.9, 196, 148, 255, 1.6, 2.4)
        end
    end)
end

function CharCamera.disable()
    rotateThreadActive = false
    restoreCoverAbility()

    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end

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
        tattoos = 'body',
        review = 'body',
    }
    CharCamera.setPreset(map[stepId] or 'default')
end

function CharCamera.forTattooZone(zone)
    local map = {
        ZONE_HEAD = 'hair',
        ZONE_HAIR = 'hair',
        ZONE_TORSO = 'body',
        ZONE_LEFT_ARM = 'body',
        ZONE_RIGHT_ARM = 'body',
        ZONE_LEFT_LEG = 'body',
        ZONE_RIGHT_LEG = 'body',
    }
    CharCamera.setPreset(map[zone] or 'body')
end

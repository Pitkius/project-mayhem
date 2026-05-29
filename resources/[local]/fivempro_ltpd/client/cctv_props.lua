--- CCTV kameros: pozicija iš prop modelio / spawn pagal config.

local spawnedProps = {} ---@type table<string, number>
local propModels = {
    [`prop_cctv_cam_01a`] = true,
    [`prop_cctv_cam_01b`] = true,
    [`prop_cctv_cam_02a`] = true,
    [`prop_cctv_cam_03a`] = true,
    [`prop_cctv_cam_04a`] = true,
    [`prop_cctv_cam_05a`] = true,
    [`prop_cctv_cam_06a`] = true,
    [`prop_cctv_cam_07a`] = true,
}

local function headingForward(h)
    local rad = math.rad((tonumber(h) or 0.0) + 0.0)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function headingFromTo(from, to)
    local dx = (to.x or 0.0) - (from.x or 0.0)
    local dy = (to.y or 0.0) - (from.y or 0.0)
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return 0.0 end
    return (math.deg(math.atan2(dx, dy)) + 360.0) % 360.0
end

--- Kameros su coords/lookAt – susieti su prop (spawn arba pasaulio objektas).
local function ensureCamPropBinding(cam)
    if cam.propCoords and cam.propModel then return end
    if not cam.coords or not cam.lookAt then return end
    local c = cam.coords
    local l = cam.lookAt
    cam.propModel = cam.propModel or `prop_cctv_cam_01a`
    cam.propCoords = vector4(c.x, c.y, c.z, headingFromTo(c, l))
    cam.lookDistance = cam.lookDistance or 12.0
    cam.pitchOffset = cam.pitchOffset or -16.0
    cam.yawMax = cam.yawMax or 48.0
    cam.pitchMax = cam.pitchMax or 16.0
    if cam.spawnProp == nil then cam.spawnProp = true end
end

local function findWorldProp(model, coords, radius)
    local hash = type(model) == 'number' and model or joaat(model)
    if not propModels[hash] and not IsModelValid(hash) then return 0 end
    return GetClosestObjectOfType(coords.x, coords.y, coords.z, radius or 8.0, hash, false, false, false)
end

local function spawnPropForCam(cam)
    if cam.spawnProp ~= true or not cam.propModel or not cam.propCoords then return 0 end
    local c = cam.propCoords
    local hash = type(cam.propModel) == 'number' and cam.propModel or joaat(cam.propModel)
    if spawnedProps[cam.id] and DoesEntityExist(spawnedProps[cam.id]) then
        return spawnedProps[cam.id]
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return 0 end
        Wait(10)
    end
    local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    if obj == 0 then return 0 end
    SetEntityHeading(obj, c.w or c.heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    spawnedProps[cam.id] = obj
    SetModelAsNoLongerNeeded(hash)
    return obj
end

---@param cam table
---@return vector3 pos, vector3 look, number yawMax, number pitchMax
function ResolveCctvCameraView(cam)
    if type(cam) ~= 'table' then return nil, nil, 60.0, 20.0 end
    ensureCamPropBinding(cam)

    local yawMax = tonumber(cam.yawMax) or 60.0
    local pitchMax = tonumber(cam.pitchMax) or 20.0
    local lookDist = tonumber(cam.lookDistance) or 12.0
    local pitchOff = tonumber(cam.pitchOffset) or -14.0
    local zOff = tonumber(cam.zOffset) or 0.0

    local pos
    local look

    if cam.propCoords then
        local c = cam.propCoords
        local ent = findWorldProp(cam.propModel, vector3(c.x, c.y, c.z), cam.propSearchRadius or 10.0)
        if ent == 0 then
            ent = spawnPropForCam(cam)
        end
        if ent ~= 0 and DoesEntityExist(ent) then
            local ec = GetEntityCoords(ent)
            local eh = GetEntityHeading(ent)
            pos = vector3(ec.x, ec.y, ec.z + zOff)
            if cam.lookAt then
                look = vector3(cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
            else
                local fwd = headingForward(eh)
                local pitchRad = math.rad(pitchOff)
                look = pos + fwd * lookDist + vector3(0.0, 0.0, math.tan(pitchRad) * lookDist)
            end
        elseif cam.lookAt then
            pos = vector3(c.x, c.y, c.z + zOff)
            look = vector3(cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
        else
            pos = vector3(c.x, c.y, c.z + zOff)
            local fwd = headingForward(c.w or c.heading or 0.0)
            look = pos + fwd * lookDist + vector3(0.0, 0.0, math.tan(math.rad(pitchOff)) * lookDist)
        end
    elseif cam.coords and cam.lookAt then
        pos = vector3(cam.coords.x, cam.coords.y, cam.coords.z)
        look = vector3(cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
    else
        return nil, nil, yawMax, pitchMax
    end

    return pos, look, yawMax, pitchMax
end

exports('ResolveCctvCameraView', ResolveCctvCameraView)

CreateThread(function()
    Wait(2500)
    for _, cam in ipairs(Config.Surveillance.CctvCameras or {}) do
        ensureCamPropBinding(cam)
        if cam.spawnProp == true and cam.propCoords and cam.propModel then
            local ent = findWorldProp(cam.propModel, vector3(cam.propCoords.x, cam.propCoords.y, cam.propCoords.z), cam.propSearchRadius or 10.0)
            if ent == 0 then
                spawnPropForCam(cam)
            else
                spawnedProps[cam.id] = ent
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ent in pairs(spawnedProps) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    spawnedProps = {}
end)

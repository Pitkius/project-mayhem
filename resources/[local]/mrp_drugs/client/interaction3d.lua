--- Reusable local-only GTA workstation helpers.
Interaction3D = Interaction3D or {}

local ALLOWED_MODELS = {
    bkr_prop_weed_table_01a = true,
    bkr_prop_meth_table01a = true,
    bkr_prop_coke_scale_01 = true,
    prop_cs_script_bottle = true,
    prop_cooker_03 = true,
    prop_tool_bench02 = true,
}

function Interaction3D.Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Interaction3D.LoadModel(candidates, timeoutMs)
    for _, name in ipairs(candidates or {}) do
        if ALLOWED_MODELS[name] then
            local hash = joaat(name)
            if IsModelInCdimage(hash) and IsModelValid(hash) then
                RequestModel(hash)
                local deadline = GetGameTimer() + (timeoutMs or 5000)
                while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
                if HasModelLoaded(hash) then return hash, name end
            end
        end
    end
    return nil
end

function Interaction3D.NewRegistry()
    return { entities = {}, models = {}, cam = nil, selected = nil, ray = nil }
end

function Interaction3D.Track(registry, entity)
    if entity and entity ~= 0 then
        registry.entities[#registry.entities + 1] = entity
    end
    return entity
end

function Interaction3D.Spawn(registry, candidates, coords, heading, options)
    local hash = Interaction3D.LoadModel(candidates)
    if not hash then return nil, 'model_missing' end
    registry.models[hash] = true
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 then return nil, 'spawn_failed' end
    Interaction3D.Track(registry, entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityHeading(entity, heading or 0.0)
    if options and options.ground then PlaceObjectOnGroundProperly(entity) end
    FreezeEntityPosition(entity, not options or options.frozen ~= false)
    SetEntityCollision(entity, not options or options.collision ~= false, true)
    return entity
end

function Interaction3D.Forward(heading)
    local radians = math.rad(heading)
    return vector3(-math.sin(radians), math.cos(radians), 0.0)
end

function Interaction3D.Right(heading)
    local radians = math.rad(heading)
    return vector3(math.cos(radians), math.sin(radians), 0.0)
end

function Interaction3D.Offset(origin, heading, right, forward, up)
    local r, f = Interaction3D.Right(heading), Interaction3D.Forward(heading)
    return vector3(
        origin.x + r.x * right + f.x * forward,
        origin.y + r.y * right + f.y * forward,
        origin.z + (up or 0.0)
    )
end

function Interaction3D.CreateCamera(registry, position, lookAt, fov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not cam or cam == 0 then return nil end
    registry.cam = cam
    registry.lookAt = lookAt
    registry.camDistance = #(position - lookAt)
    local dx, dy, dz = position.x - lookAt.x, position.y - lookAt.y, position.z - lookAt.z
    registry.camYaw = math.deg(math.atan(-dx, dy))
    registry.camPitch = math.deg(math.asin(Interaction3D.Clamp(dz / math.max(0.01, registry.camDistance), -1.0, 1.0)))
    SetCamCoord(cam, position.x, position.y, position.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(cam, fov or 44.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)
    return cam
end

--- Orbit the scripted camera with mouse look while gameplay controls stay disabled.
function Interaction3D.UpdateOrbitCamera(registry, options)
    if not registry or not registry.cam or not DoesCamExist(registry.cam) or not registry.lookAt then
        return
    end
    options = options or {}
    local lookX = GetDisabledControlNormal(0, 1)
    local lookY = GetDisabledControlNormal(0, 2)
    registry.camYaw = (registry.camYaw or 0.0) - lookX * (options.yawSpeed or 3.2)
    registry.camPitch = Interaction3D.Clamp(
        (registry.camPitch or -18.0) - lookY * (options.pitchSpeed or 2.2),
        options.minPitch or -48.0,
        options.maxPitch or -6.0
    )
    local distance = options.distance or registry.camDistance or 2.8
    registry.camDistance = distance
    local yaw = math.rad(registry.camYaw)
    local pitch = math.rad(registry.camPitch)
    local horizontal = math.cos(pitch) * distance
    local target = registry.lookAt
    local camPos = vector3(
        target.x - math.sin(yaw) * horizontal,
        target.y + math.cos(yaw) * horizontal,
        target.z - math.sin(pitch) * distance
    )
    SetCamCoord(registry.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(registry.cam, target.x, target.y, target.z)
end

local function rotationDirection(rotation)
    local z, x = math.rad(rotation.z), math.rad(rotation.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

function Interaction3D.RaycastCamera(registry, distance, ignore)
    if not registry.cam or not DoesCamExist(registry.cam) then return nil end
    if registry.ray then
        local state, hit, endpoint, _, entity = GetShapeTestResult(registry.ray)
        if state == 2 then
            registry.ray = nil
            if hit == 1 then return entity, endpoint end
        end
    end
    local from = GetCamCoord(registry.cam)
    local direction = rotationDirection(GetCamRot(registry.cam, 2))
    local target = from + direction * (distance or 10.0)
    registry.ray = StartShapeTestRay(
        from.x, from.y, from.z, target.x, target.y, target.z,
        -1, ignore or PlayerPedId(), 0
    )
    return nil
end

--- Ar kamera žiūri į entity (veikia ir be collision — prop_cs_script_bottle dažnai be kolizijos).
function Interaction3D.IsLookingAt(registry, entity, minDot)
    if not registry or not registry.cam or not DoesCamExist(registry.cam) then return false end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local from = GetCamCoord(registry.cam)
    local dir = rotationDirection(GetCamRot(registry.cam, 2))
    local target = GetEntityCoords(entity)
    local to = target - from
    local len = #to
    if len < 0.05 then return true end
    to = to / len
    local dot = dir.x * to.x + dir.y * to.y + dir.z * to.z
    return dot >= (minDot or 0.72)
end

function Interaction3D.DrawTargetMarker(entity, r, g, b)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local c = GetEntityCoords(entity)
    local mn, mx = GetModelDimensions(GetEntityModel(entity))
    local top = c.z + (mx and mx.z or 0.25) + 0.12
    DrawMarker(2, c.x, c.y, top, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
        0.18, 0.18, 0.18, r or 34, g or 211, b or 238, 200,
        false, false, 2, true, nil, nil, false)
end

function Interaction3D.Select(registry, entity, color)
    if registry.selected and DoesEntityExist(registry.selected) then
        SetEntityDrawOutline(registry.selected, false)
    end
    registry.selected = entity
    if entity and DoesEntityExist(entity) then
        color = color or { 89, 220, 150, 220 }
        SetEntityDrawOutlineColor(color[1], color[2], color[3], color[4])
        SetEntityDrawOutline(entity, true)
    end
end

function Interaction3D.MoveSmooth(entity, target, durationMs, isValid, onDone)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetEntityCoords(entity)
    local startedAt = GetGameTimer()
    FreezeEntityPosition(entity, false)
    SetEntityCollision(entity, false, false)
    CreateThread(function()
        while DoesEntityExist(entity) and (not isValid or isValid()) do
            local t = Interaction3D.Clamp((GetGameTimer() - startedAt) / (durationMs or 500), 0.0, 1.0)
            local eased = t * t * (3.0 - 2.0 * t)
            local point = start + (target - start) * eased
            SetEntityCoordsNoOffset(entity, point.x, point.y, point.z, false, false, false)
            if t >= 1.0 then
                FreezeEntityPosition(entity, true)
                if onDone then onDone() end
                return
            end
            Wait(0)
        end
        if DoesEntityExist(entity) then
            FreezeEntityPosition(entity, true)
        end
    end)
    return true
end

function Interaction3D.NearestSnap(coords, snaps, accept)
    local best, distance
    for _, snap in ipairs(snaps or {}) do
        if not snap.disabled and (not accept or accept(snap)) then
            local d = #(coords - snap.coords)
            if not distance or d < distance then best, distance = snap, d end
        end
    end
    return best, distance
end

function Interaction3D.DrawSnaps(snaps)
    for _, snap in ipairs(snaps or {}) do
        if not snap.disabled then
            local c, color = snap.coords, snap.color or { 89, 220, 150 }
            DrawMarker(28, c.x, c.y, c.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                (snap.radius or 0.25) * 1.7, (snap.radius or 0.25) * 1.7, 0.04,
                color[1], color[2], color[3], 145, false, false, 2, false, nil, nil, false)
        end
    end
end

function Interaction3D.Cleanup(registry)
    if not registry then return end
    Interaction3D.Select(registry, nil)
    for _, entity in ipairs(registry.entities or {}) do
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
    if registry.cam and DoesCamExist(registry.cam) then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(registry.cam, false)
    end
    for hash in pairs(registry.models or {}) do SetModelAsNoLongerNeeded(hash) end
    registry.entities, registry.models, registry.cam = {}, {}, nil
end

--- Ieško jau pasaulyje esančio prop (įranga) — NEkuria naujo, NEtrinti cleanup metu.
function Interaction3D.FindNearby(candidates, origin, radius)
    radius = tonumber(radius) or 4.0
    if not origin then return nil end
    for _, name in ipairs(candidates or {}) do
        local hash = type(name) == 'number' and name or joaat(name)
        local entity = GetClosestObjectOfType(origin.x, origin.y, origin.z, radius, hash, false, false, false)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            return entity, hash, name
        end
    end
    return nil
end

--- workspace.entity arba artimiausias modelis; neįtraukiamas į registry.entities.
function Interaction3D.ResolveExisting(workspace, candidates, origin, radius)
    local entity = workspace and tonumber(workspace.entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local model = GetEntityModel(entity)
        local ok = false
        for _, name in ipairs(candidates or {}) do
            if joaat(name) == model then
                ok = true
                break
            end
        end
        if ok or not candidates or #candidates == 0 then
            return entity, model
        end
    end
    return Interaction3D.FindNearby(candidates, origin, radius)
end

--- Aukštis virš objekto paviršiaus (stalas / katilas).
function Interaction3D.SurfaceTop(entity, fallbackZ)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return (fallbackZ or 0.0) + 0.85
    end
    local coords = GetEntityCoords(entity)
    local _, maxDim = GetModelDimensions(GetEntityModel(entity))
    return coords.z + math.max(0.55, maxDim and maxDim.z or 0.7) + 0.03
end

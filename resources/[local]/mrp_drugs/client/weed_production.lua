--- Žolės process/pack 3D darbo stotis.
--- NUI naudojamas tik informacijai; visi veiksmai ir objektai yra GTA pasaulyje.
WeedProduction = WeedProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local MODELS = {
    table = { 'bkr_prop_weed_table_01a', 'prop_tool_bench02' },
    leaf = { 'bkr_prop_weed_bud_02b', 'bkr_prop_weed_leaf_01a', 'prop_meth_bag_01' },
    rack = { 'bkr_prop_weed_drying_01a', 'bkr_prop_weed_table_01a' },
    scale = { 'bkr_prop_coke_scale_01', 'prop_tool_bench02' },
    emptyBag = { 'bkr_prop_weed_bag_01a', 'prop_meth_bag_01' },
    packedBag = { 'bkr_prop_weed_smallbag_01a', 'prop_meth_bag_01' },
}

local function hud(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function loadFirstModel(candidates)
    for _, model in ipairs(candidates or {}) do
        local hash = joaat(model)
        if IsModelInCdimage(hash) and IsModelValid(hash) then
            RequestModel(hash)
            local deadline = GetGameTimer() + 5000
            while not HasModelLoaded(hash) and GetGameTimer() < deadline do
                Wait(10)
            end
            if HasModelLoaded(hash) then
                return hash, model
            end
        end
    end
    return nil
end

local function directionFromHeading(heading)
    local radians = math.rad(heading)
    return vector3(-math.sin(radians), math.cos(radians), 0.0)
end

local function rightFromHeading(heading)
    local radians = math.rad(heading)
    return vector3(math.cos(radians), math.sin(radians), 0.0)
end

local function offsetPoint(origin, heading, x, y, z)
    local right = rightFromHeading(heading)
    local forward = directionFromHeading(heading)
    return vector3(
        origin.x + right.x * x + forward.x * y,
        origin.y + right.y * x + forward.y * y,
        origin.z + (z or 0.0)
    )
end

local function rotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function createLocalObject(hash, coords, heading)
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 then return nil end
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityHeading(entity, heading or 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, true)
    return entity
end

local function registerEntity(session, entity)
    if entity and entity ~= 0 then
        session.entities[#session.entities + 1] = entity
    end
    return entity
end

local function clearSelection(session)
    if session.selected and session.selected.entity and DoesEntityExist(session.selected.entity) then
        SetEntityDrawOutline(session.selected.entity, false)
    end
    session.selected = nil
end

local function setPackHighlight(entity, enabled)
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityDrawOutline(entity, enabled == true)
    if enabled then
        SetEntityDrawOutlineColor(72, 255, 120, 255)
        pcall(SetEntityDrawOutlineShader, 1)
    end
end

local function clearPackHighlights(session)
    if session.bag and session.bag.entity then
        setPackHighlight(session.bag.entity, false)
    end
    if session.currentBud then
        setPackHighlight(session.currentBud, false)
    end
end

local function updatePackHighlights(session)
    clearPackHighlights(session)
    if session.packBusy or session.stage == 'moving' or session.stage == 'stage_pending' then
        return
    end
    if session.stage == 'bag_select' and session.bag and session.bag.entity then
        setPackHighlight(session.bag.entity, true)
        return
    end
    if session.stage == 'packing' and session.currentBud and DoesEntityExist(session.currentBud) then
        setPackHighlight(session.currentBud, true)
    end
end

local function cleanupSession(session)
    if not session then return end
    clearPackHighlights(session)
    clearSelection(session)
    for _, entry in ipairs(session.items or {}) do
        if entry.entity and DoesEntityExist(entry.entity) then
            SetEntityDrawOutline(entry.entity, false)
        end
    end
    for _, entity in ipairs(session.entities or {}) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    if session.packBudHash then SetModelAsNoLongerNeeded(session.packBudHash) end
    if session.emptyBagHash then SetModelAsNoLongerNeeded(session.emptyBagHash) end
    if session.packedBagHash then SetModelAsNoLongerNeeded(session.packedBagHash) end
    if session.cam and DoesCamExist(session.cam) then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(session.cam, false)
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    hud('weedPackClose')
    hud('weed3dClose')
end

local function finishSession(success, extra)
    local session = active
    if not session or session.finished then return end
    session.finished = true
    active = nil
    cleanupSession(session)
    if session.onDone then
        session.onDone(success == true, extra or {
            score = math.floor(session.score or 0),
            mistakes = session.mistakes or 0,
        })
    end
end

local function reportServerStage(session, stage, onAccepted)
    if not session or not session.craftToken then
        if onAccepted then onAccepted() end
        return
    end
    session.stageRequestId = (session.stageRequestId or 0) + 1
    local requestId = session.stageRequestId
    QBCore.Functions.TriggerCallback('mrp_drugs:server:weedProductionStage', function(response)
        if active ~= session or session.finished then return end
        if session.stageRequestId ~= requestId then return end
        session.stageRequestId = requestId + 1
        if not response or not response.ok then
            finishSession(false, {
                score = math.floor(session.score or 0),
                mistakes = (session.mistakes or 0) + 1,
                reason = (response and response.reason) or 'stage_rejected',
            })
            return
        end
        if onAccepted then onAccepted(response) end
    end, session.craftToken, stage)
    CreateThread(function()
        Wait(30000)
        if active ~= session or session.finished or session.stageRequestId ~= requestId then return end
        session.stageRequestId = requestId + 1
        finishSession(false, {
            score = math.floor(session.score or 0),
            mistakes = (session.mistakes or 0) + 1,
            reason = 'stage_timeout',
        })
    end)
end

local function finishAfterServerStage(session, stage, success, extra)
    session.stage = 'stage_pending'
    reportServerStage(session, stage, function()
        if active == session then finishSession(success, extra) end
    end)
end

local function createCamera(session)
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not session.cam or session.cam == 0 then return false end
    if session.mode == 'pack' then
        local height = session.tableTop - session.tableOrigin.z
        local cameraPos = offsetPoint(session.tableOrigin, session.heading, 0.0, -2.15, height + 1.45)
        SetCamCoord(session.cam, cameraPos.x, cameraPos.y, cameraPos.z)
        PointCamAtCoord(session.cam, session.lookAt.x, session.lookAt.y, session.lookAt.z)
        SetCamFov(session.cam, 42.0)
    else
        session.camYaw = session.heading + 180.0
        session.camPitch = -22.0
        session.camDistance = 3.5
        SetCamFov(session.cam, 45.0)
    end
    SetCamActive(session.cam, true)
    RenderScriptCams(true, true, 350, true, true)
    return true
end

local function updateCamera(session)
    if session.mode == 'pack' then return end
    local lookX = GetDisabledControlNormal(0, 1)
    local lookY = GetDisabledControlNormal(0, 2)
    session.camYaw = session.camYaw - lookX * 3.2
    session.camPitch = clamp(session.camPitch - lookY * 2.2, -48.0, -8.0)

    local yaw = math.rad(session.camYaw)
    local pitch = math.rad(session.camPitch)
    local horizontal = math.cos(pitch) * session.camDistance
    local target = session.lookAt
    local camPos = vector3(
        target.x - math.sin(yaw) * horizontal,
        target.y + math.cos(yaw) * horizontal,
        target.z - math.sin(pitch) * session.camDistance
    )
    SetCamCoord(session.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(session.cam, target.x, target.y, target.z)
end

local function findItemByEntity(session, entity)
    for _, entry in ipairs(session.items or {}) do
        if entry.entity == entity and not entry.placed and entry.movable ~= false then
            return entry
        end
    end
end

local function updateSelection(session)
    if session.held then
        clearSelection(session)
        session.selectionRay = nil
        return
    end
    if session.selectionRay then
        local state, hit, _, _, entity = GetShapeTestResult(session.selectionRay)
        if state == 2 then
            session.selectionRay = nil
            local nextSelection = hit == 1 and findItemByEntity(session, entity) or nil
            if nextSelection ~= session.selected then
                clearSelection(session)
                session.selected = nextSelection
                if nextSelection and DoesEntityExist(nextSelection.entity) then
                    SetEntityDrawOutline(nextSelection.entity, true)
                    SetEntityDrawOutlineColor(104, 211, 145, 180)
                end
            end
        end
    end
    if not session.selectionRay then
        local from = GetCamCoord(session.cam)
        local direction = rotationToDirection(GetCamRot(session.cam, 2))
        local to = from + direction * 8.0
        session.selectionRay = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 16, PlayerPedId(), 0)
    end
end

local function dragPoint(session)
    local from = GetCamCoord(session.cam)
    local direction = rotationToDirection(GetCamRot(session.cam, 2))
    local planeZ = session.tableTop + 0.13
    if direction.z < -0.01 then
        local distance = (planeZ - from.z) / direction.z
        if distance > 0.5 and distance < 10.0 then
            return from + direction * distance
        end
    end
    return from + direction * 3.0
end

local function updateHeld(session)
    local held = session.held
    if not held or not DoesEntityExist(held.entity) then
        session.held = nil
        return
    end
    local target = dragPoint(session)
    local current = GetEntityCoords(held.entity)
    local smooth = current + (target - current) * 0.24
    SetEntityCoordsNoOffset(held.entity, smooth.x, smooth.y, smooth.z, false, false, false)
    if IsDisabledControlPressed(0, 241) then held.rotation = (held.rotation or 0.0) + 2.0 end
    if IsDisabledControlPressed(0, 242) then held.rotation = (held.rotation or 0.0) - 2.0 end
    SetEntityRotation(held.entity, 0.0, 0.0, (session.heading + (held.rotation or 0.0)) % 360.0, 2, true)
end

local function nearestSnap(session, entry)
    local coords = GetEntityCoords(entry.entity)
    local best, bestDistance
    for _, snap in ipairs(session.snaps or {}) do
        if not snap.disabled and (not snap.accept or snap.accept(entry)) then
            local distance = #(coords - snap.coords)
            if not bestDistance or distance < bestDistance then
                best = snap
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

local function placeHeld(session)
    local entry = session.held
    if not entry then return end
    local snap, distance = nearestSnap(session, entry)
    if not snap or distance > (snap.radius or 0.30) then
        hud('weed3dUpdate', { hint = 'Priartink objektą prie pažymėto snap taško.' })
        return
    end
    session.held = nil
    entry.placed = true
    SetEntityCoordsNoOffset(entry.entity, snap.coords.x, snap.coords.y, snap.coords.z, false, false, false)
    SetEntityRotation(entry.entity, 0.0, 0.0, snap.heading or session.heading, 2, true)
    SetEntityCollision(entry.entity, true, true)
    FreezeEntityPosition(entry.entity, true)
    if snap.onPlace then snap.onPlace(entry, snap, distance) end
end

local function pickSelected(session)
    local entry = session.selected
    if not entry then return end
    clearSelection(session)
    session.held = entry
    entry.rotation = entry.rotation or 0.0
    FreezeEntityPosition(entry.entity, false)
    SetEntityCollision(entry.entity, false, false)
end

local function drawSnapPoints(session)
    for _, snap in ipairs(session.snaps or {}) do
        if not snap.disabled then
            local color = snap.color or { 90, 210, 140 }
            DrawMarker(
                28,
                snap.coords.x, snap.coords.y, snap.coords.z + 0.025,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                (snap.radius or 0.30) * 1.65, (snap.radius or 0.30) * 1.65, 0.05,
                color[1], color[2], color[3], 145,
                false, false, 2, false, nil, nil, false
            )
        end
    end
end

local function controls(session)
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 32, true)
    DisableControlAction(0, 33, true)
    DisableControlAction(0, 34, true)
    DisableControlAction(0, 35, true)
    DisableControlAction(0, 38, true)
    DisableControlAction(0, 73, true)
    DisableControlAction(0, 200, true)
    DisableControlAction(0, 241, true)
    DisableControlAction(0, 242, true)

    if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 73) then
        finishSession(false, { score = math.floor(session.score or 0), mistakes = (session.mistakes or 0) + 1, reason = 'cancelled' })
        return false
    end
    return true
end

local function allPlaced(session, kind)
    for _, entry in ipairs(session.items) do
        if entry.kind == kind and not entry.placed then return false end
    end
    return true
end

local function startDrying(session)
    session.stage = 'stage_pending'
    reportServerStage(session, 'sorted', function()
        session.stage = 'drying'
        session.stageStartedAt = GetGameTimer()
        session.temperature = 62.0
        session.airflow = 52.0
        session.dryingGoodMs = 0
        session.snaps = {}
        session.held = nil
        clearSelection(session)
        for i, entry in ipairs(session.items) do
            local pos = offsetPoint(session.tableOrigin, session.heading, -0.55 + ((i - 1) % 3) * 0.55, 0.20 + math.floor((i - 1) / 3) * 0.32, session.tableTop - session.tableOrigin.z + 0.08)
            SetEntityCoordsNoOffset(entry.entity, pos.x, pos.y, pos.z, false, false, false)
            FreezeEntityPosition(entry.entity, true)
        end
        hud('weed3dUpdate', {
            title = 'Žolė · džiovinimas',
            stage = '2/2',
            hint = 'A/D – temperatūra · W/S – oro srautas. Išlaikyk abu žalioje zonoje.',
            temperature = session.temperature,
            airflow = session.airflow,
        })
    end)
end

local function setupProcess(session)
    session.stage = 'sorting'
    session.score = 0
    session.mistakes = 0
    local leafHash = loadFirstModel(MODELS.leaf)
    if not leafHash then return false, 'Nerastas žolės objekto modelis.' end

    local qualities = { true, false, true, true, false }
    for i = 1, 5 do
        local pos = offsetPoint(session.tableOrigin, session.heading, -0.72 + (i - 1) * 0.36, -0.28, session.tableTop - session.tableOrigin.z + 0.10)
        local entity = registerEntity(session, createLocalObject(leafHash, pos, session.heading + (i * 17.0)))
        if not entity then return false, 'Nepavyko sukurti žolės objektų.' end
        session.items[#session.items + 1] = {
            entity = entity,
            kind = 'leaf',
            good = qualities[i],
            label = qualities[i] and 'Švarus žiedas' or 'Pažeistas žiedas',
        }
    end
    SetModelAsNoLongerNeeded(leafHash)

    local goodSnap = {
        id = 'good',
        coords = offsetPoint(session.tableOrigin, session.heading, -0.58, 0.42, session.tableTop - session.tableOrigin.z + 0.08),
        heading = session.heading,
        radius = 0.32,
        color = { 70, 210, 115 },
    }
    local rejectSnap = {
        id = 'reject',
        coords = offsetPoint(session.tableOrigin, session.heading, 0.58, 0.42, session.tableTop - session.tableOrigin.z + 0.08),
        heading = session.heading,
        radius = 0.32,
        color = { 225, 80, 80 },
    }
    local function onSorted(entry, snap, distance)
        local correct = (entry.good and snap.id == 'good') or (not entry.good and snap.id == 'reject')
        session.score = session.score + (correct and 12 or 3) + math.floor(math.max(0, 4 - distance * 10))
        if not correct then session.mistakes = session.mistakes + 1 end
        hud('weed3dUpdate', {
            title = 'Žolė · rūšiavimas',
            stage = '1/2',
            hint = correct and 'Teisingai surūšiuota.' or 'Netinkama krūva – kokybė sumažėjo.',
            score = math.floor(session.score),
            mistakes = session.mistakes,
        })
        if allPlaced(session, 'leaf') then
            CreateThread(function()
                Wait(450)
                if active == session then startDrying(session) end
            end)
        end
    end
    goodSnap.onPlace = onSorted
    rejectSnap.onPlace = onSorted
    session.snaps = { goodSnap, rejectSnap }
    return true
end

local function startPackingAnimation(session)
    local dict = 'anim@amb@business@weed@weed_sorting_seated@'
    local clip = 'sorter_right_sort_v3_weeddry01c'
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(PlayerPedId(), dict, clip, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    session.animDict = dict
end

local function movePackObject(session, entity, target, durationMs, onDone)
    if not entity or not DoesEntityExist(entity) then
        if onDone then onDone() end
        return
    end
    local start = GetEntityCoords(entity)
    local startedAt = GetGameTimer()
    CreateThread(function()
        while active == session and DoesEntityExist(entity) do
            local progress = clamp((GetGameTimer() - startedAt) / durationMs, 0.0, 1.0)
            local eased = 1.0 - ((1.0 - progress) * (1.0 - progress))
            local point = start + (target - start) * eased
            SetEntityCoordsNoOffset(entity, point.x, point.y, point.z, false, false, false)
            if progress >= 1.0 then break end
            Wait(0)
        end
        if active == session and onDone then onDone() end
    end)
end

local function facePackBagToCamera(session, entity)
    if not entity or not DoesEntityExist(entity) or not session.cam or not DoesCamExist(session.cam) then return end
    local coords = GetEntityCoords(entity)
    local camera = GetCamCoord(session.cam)
    local heading = GetHeadingFromVector_2d(camera.x - coords.x, camera.y - coords.y)
    -- The empty/filled weed bag models are flat by default. Pitching them
    -- 90 degrees keeps them upright while the heading faces the fixed camera.
    SetEntityRotation(entity, 90.0, 0.0, heading, 2, true)
end

-- Forward declaration: pack setup/spawn run before screen helpers are defined.
local cachePackScreenAnchors
local updatePackTargets

local function showPackedBagPreview(session, onDone)
    if active ~= session then return end
    session.stage = 'packed_preview'
    session.packBusy = true
    clearPackHighlights(session)

    if session.bag and session.bag.entity and DoesEntityExist(session.bag.entity) then
        SetEntityVisible(session.bag.entity, false, false)
        SetEntityCollision(session.bag.entity, false, false)
    end
    if session.packedBagEntity and DoesEntityExist(session.packedBagEntity) then
        SetEntityCoordsNoOffset(
            session.packedBagEntity,
            session.packedBagCenter.x, session.packedBagCenter.y, session.packedBagCenter.z,
            false, false, false
        )
        facePackBagToCamera(session, session.packedBagEntity)
        SetEntityVisible(session.packedBagEntity, true, false)
    end

    CreateThread(function()
        Wait(1000)
        if active ~= session or session.finished then return end

        if session.packedBagEntity and DoesEntityExist(session.packedBagEntity) then
            SetEntityVisible(session.packedBagEntity, false, false)
        end
        if session.bag and session.bag.entity and DoesEntityExist(session.bag.entity) then
            SetEntityVisible(session.bag.entity, true, false)
            SetEntityCollision(session.bag.entity, true, true)
        end
        session.packBusy = false
        if onDone then onDone() end
    end)
end

local function spawnPackBud(session)
    if active ~= session or session.packedCount >= session.packTarget then return end
    local entity = registerEntity(session, createLocalObject(session.packBudHash, session.budSide, session.heading))
    if not entity then
        return finishSession(false, {
            score = math.floor(session.score),
            mistakes = session.mistakes + 1,
            reason = 'bud_spawn_failed',
        })
    end
    session.currentBud = entity
    session.stage = 'packing'
    session.packBusy = false
    cachePackScreenAnchors(session)
    updatePackHighlights(session)
    session.lastTargetHudAt = 0
    if updatePackTargets then updatePackTargets(session) end
    hud('weed3dUpdate', {
        title = 'Žolė · pakavimas',
        stage = '2/2',
        hint = 'Paspausk kairį pelės mygtuką ant žolės gabaliuko.',
        packed = session.packedCount,
        targetCount = session.packTarget,
        score = math.floor(session.score),
    })
end

local function handlePackClick(session, target)
    if active ~= session or session.mode ~= 'pack' or session.packBusy then return false end
    if target == 'bag' and session.stage == 'bag_select' then
        session.packBusy = true
        session.stage = 'moving'
        clearPackHighlights(session)
        movePackObject(session, session.bag.entity, session.bagCenter, 450, function()
            facePackBagToCamera(session, session.bag.entity)
            session.stage = 'stage_pending'
            reportServerStage(session, 'bag_ready', function()
                session.packBusy = false
                spawnPackBud(session)
            end)
        end)
        return true
    end
    if target == 'bud' and session.stage == 'packing' and session.currentBud then
        session.packBusy = true
        session.stage = 'moving'
        clearPackHighlights(session)
        local bud = session.currentBud
        session.currentBud = nil
        movePackObject(session, bud, session.bagCenter + vector3(0.0, 0.0, 0.08), 500, function()
            if DoesEntityExist(bud) then DeleteEntity(bud) end
            session.packedCount = session.packedCount + 1
            session.score = clamp(session.packedCount * 20, 0, 100)
            hud('weed3dUpdate', {
                title = 'Žolė · pakavimas',
                stage = '2/2',
                hint = session.packedCount >= session.packTarget
                    and 'Supakuoti visi 5 žolės gabaliukai.'
                    or 'Gabaliukas supakuotas. Pakuok kitą.',
                packed = session.packedCount,
                targetCount = session.packTarget,
                score = math.floor(session.score),
            })
            showPackedBagPreview(session, function()
                if session.packedCount >= session.packTarget then
                    finishAfterServerStage(session, 'packed_five', true, {
                        score = math.floor(session.score),
                        mistakes = session.mistakes,
                        packed = session.packedCount,
                    })
                else
                    spawnPackBud(session)
                end
            end)
        end)
        return true
    end
    return false
end

local function setupPack(session)
    session.stage = 'bag_select'
    session.score = 0
    session.mistakes = 0
    session.packedCount = 0
    session.packTarget = 5
    session.packBusy = false
    local leafHash = loadFirstModel(MODELS.leaf)
    local emptyBagHash = loadFirstModel(MODELS.emptyBag)
    local packedBagHash = loadFirstModel(MODELS.packedBag)
    if not leafHash or not emptyBagHash or not packedBagHash then
        return false, 'Nerasti pakavimui reikalingi objektų modeliai.'
    end
    local surfaceHeight = session.tableTop - session.tableOrigin.z
    local emptyMin, emptyMax = GetModelDimensions(emptyBagHash)
    local packedMin, packedMax = GetModelDimensions(packedBagHash)
    local emptyHeight = clamp(math.abs(emptyMax.y - emptyMin.y), 0.12, 0.36)
    local packedHeight = clamp(math.abs(packedMax.y - packedMin.y), 0.12, 0.36)
    session.bagSide = offsetPoint(session.tableOrigin, session.heading, -0.58, -0.22, surfaceHeight + emptyHeight * 0.5 + 0.01)
    session.bagCenter = offsetPoint(session.tableOrigin, session.heading, 0.0, 0.0, surfaceHeight + emptyHeight * 0.5 + 0.01)
    session.packedBagCenter = offsetPoint(session.tableOrigin, session.heading, 0.0, 0.0, surfaceHeight + packedHeight * 0.5 + 0.01)
    session.budSide = offsetPoint(session.tableOrigin, session.heading, 0.58, -0.22, surfaceHeight + 0.08)
    session.packBudHash = leafHash
    session.emptyBagHash = emptyBagHash
    session.packedBagHash = packedBagHash

    local bagPos = session.bagSide
    local bagEntity = registerEntity(session, createLocalObject(emptyBagHash, bagPos, session.heading))
    if not bagEntity then return false, 'Nepavyko sukurti pakavimo maišelio.' end
    facePackBagToCamera(session, bagEntity)
    local packedBagEntity = registerEntity(session, createLocalObject(packedBagHash, session.packedBagCenter, session.heading))
    if not packedBagEntity then return false, 'Nepavyko sukurti supakuoto maišelio peržiūros.' end
    facePackBagToCamera(session, packedBagEntity)
    SetEntityVisible(packedBagEntity, false, false)
    SetEntityCollision(packedBagEntity, false, false)
    session.packedBagEntity = packedBagEntity
    session.bag = {
        entity = bagEntity,
        kind = 'bag',
        label = 'Tuščias maišelis',
    }
    session.items[#session.items + 1] = session.bag
    startPackingAnimation(session)
    cachePackScreenAnchors(session)
    updatePackHighlights(session)
    return true
end

local function updateDrying(session)
    local dt = GetFrameTime()
    if IsDisabledControlPressed(0, 34) then session.temperature = session.temperature - 8.0 * dt end
    if IsDisabledControlPressed(0, 35) then session.temperature = session.temperature + 8.0 * dt end
    if IsDisabledControlPressed(0, 32) then session.airflow = session.airflow + 10.0 * dt end
    if IsDisabledControlPressed(0, 33) then session.airflow = session.airflow - 10.0 * dt end
    session.temperature = clamp(session.temperature + math.sin(GetGameTimer() / 730.0) * 0.035, 35.0, 90.0)
    session.airflow = clamp(session.airflow + math.cos(GetGameTimer() / 860.0) * 0.045, 10.0, 90.0)

    local inRange = session.temperature >= 58.0 and session.temperature <= 68.0
        and session.airflow >= 45.0 and session.airflow <= 65.0
    if inRange then session.dryingGoodMs = session.dryingGoodMs + math.floor(dt * 1000) end

    if GetGameTimer() - (session.lastHudAt or 0) >= 100 then
        session.lastHudAt = GetGameTimer()
        hud('weed3dUpdate', {
            title = 'Žolė · džiovinimas',
            stage = '2/2',
            hint = inRange and 'Parametrai stabilūs.' or 'Grąžink abu parametrus į žalią zoną.',
            temperature = session.temperature,
            airflow = session.airflow,
            remaining = math.max(0, 10000 - (GetGameTimer() - session.stageStartedAt)),
        })
    end

    if GetGameTimer() - session.stageStartedAt >= 10000 then
        local dryingScore = math.floor(clamp((session.dryingGoodMs / 10000) * 40.0, 0.0, 40.0))
        session.score = clamp(session.score + dryingScore, 0, 100)
        finishAfterServerStage(session, 'dried', true, { score = math.floor(session.score), mistakes = session.mistakes })
    end
end

local function updateSealing(session)
    local elapsed = GetGameTimer() - session.stageStartedAt
    local gauge = (math.sin(elapsed / 310.0) + 1.0) * 0.5
    if GetGameTimer() - (session.lastHudAt or 0) >= 100 then
        session.lastHudAt = GetGameTimer()
        hud('weed3dUpdate', {
            title = 'Žolė · sandarinimas',
            stage = '3/3',
            hint = 'Spausk E žalioje zonoje (65–85%).',
            seal = gauge,
            score = math.floor(session.score),
        })
    end
    if elapsed >= 500 and IsDisabledControlJustPressed(0, 38) then
        local accurate = gauge >= 0.65 and gauge <= 0.85
        if accurate then
            session.score = clamp(session.score + 20, 0, 100)
        else
            session.score = clamp(session.score + 5, 0, 100)
            session.mistakes = session.mistakes + 1
        end
        finishAfterServerStage(session, 'sealed', true, { score = math.floor(session.score), mistakes = session.mistakes })
    elseif elapsed > 20000 then
        session.mistakes = session.mistakes + 1
        finishSession(false, { score = math.floor(session.score), mistakes = session.mistakes, reason = 'seal_timeout' })
    end
end

local function screenCoordVisible(value)
    return value == true or value == 1
end

local function projectToScreenWithCamera(session, coords)
    if not coords or not session or not session.cam or not DoesCamExist(session.cam) then
        return false, nil, nil
    end

    local camPos = GetCamCoord(session.cam)
    local camRot = GetCamRot(session.cam, 2)
    local forward = rotationToDirection(camRot)
    local right = vector3(forward.y, -forward.x, 0.0)
    local rightLen = math.sqrt(right.x * right.x + right.y * right.y)
    if rightLen < 0.0001 then return false, nil, nil end
    right = vector3(right.x / rightLen, right.y / rightLen, 0.0)
    local up = vector3(
        forward.y * right.z - forward.z * right.y,
        forward.z * right.x - forward.x * right.z,
        forward.x * right.y - forward.y * right.x
    )

    local delta = vector3(coords.x - camPos.x, coords.y - camPos.y, coords.z - camPos.z)
    local depth = delta.x * forward.x + delta.y * forward.y + delta.z * forward.z
    if depth < 0.05 then return false, nil, nil end

    local planeX = delta.x * right.x + delta.y * right.y + delta.z * right.z
    local planeY = delta.x * up.x + delta.y * up.y + delta.z * up.z
    local fov = GetCamFov(session.cam)
    local aspect = GetAspectRatio(false)
    local tanHalf = math.tan(math.rad(fov * 0.5))
    local ndcX = planeX / (depth * tanHalf * aspect)
    local ndcY = -planeY / (depth * tanHalf)
    local screenX = 0.5 + ndcX * 0.5
    local screenY = 0.5 + ndcY * 0.5

    if screenX < -0.05 or screenX > 1.05 or screenY < -0.05 or screenY > 1.05 then
        return false, screenX, screenY
    end
    return true, screenX, screenY
end

local function projectToScreen(session, coords)
    if not coords then return false, nil, nil end
    for _, offset in ipairs({ 0.14, 0.08, 0.0, 0.22 }) do
        local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + offset)
        if screenCoordVisible(visible) and x and y then
            return true, x, y
        end
    end
    if session then
        return projectToScreenWithCamera(session, coords)
    end
    return false, nil, nil
end

local function packAnchorCoords(session, anchorKey)
    if anchorKey == 'bag' then
        if session.bag and session.bag.entity and DoesEntityExist(session.bag.entity) then
            return GetEntityCoords(session.bag.entity)
        end
        return session.bagSide
    end
    if session.currentBud and DoesEntityExist(session.currentBud) then
        return GetEntityCoords(session.currentBud)
    end
    return session.budSide
end

cachePackScreenAnchors = function(session)
    session.packAnchors = session.packAnchors or {}
    for _, anchorKey in ipairs({ 'bag', 'bud' }) do
        local coords = packAnchorCoords(session, anchorKey)
        if coords then
            local projected, x, y = projectToScreen(session, coords)
            session.packAnchors[anchorKey] = {
                x = projected and x or (anchorKey == 'bag' and 0.40 or 0.68),
                y = projected and y or 0.52,
            }
        end
    end
end

local function screenTargetForPack(session, coords, anchorKey, active)
    local projected, x, y = projectToScreen(session, coords)
    if projected and active == true then
        session.packAnchors = session.packAnchors or {}
        session.packAnchors[anchorKey] = { x = x, y = y }
    elseif session.packAnchors and session.packAnchors[anchorKey] then
        local anchor = session.packAnchors[anchorKey]
        x = anchor.x
        y = anchor.y
    end
    if not x or not y then
        if anchorKey == 'bag' then
            x, y = 0.40, 0.56
        else
            x, y = 0.68, 0.52
        end
    end
    return {
        visible = active == true,
        active = active == true,
        projected = projected == true,
        x = x,
        y = y,
    }
end

local PACK_CLICK_RADIUS = 0.22

local function getPackCursorNorm()
    if IsNuiFocused() then
        local resX, resY = GetActiveScreenResolution()
        local cx, cy = GetNuiCursorPosition()
        if resX and resX > 0 and cx and cy then
            return cx / resX, cy / resY
        end
    end

    local normX = GetDisabledControlNormal(0, 239)
    local normY = GetDisabledControlNormal(0, 240)
    if normX and normY and normX >= 0.0 and normX <= 1.0 and normY >= 0.0 and normY <= 1.0 then
        return normX, normY
    end
    return nil, nil
end

local function getPackScreenPoint(session, anchorKey)
    local coords = packAnchorCoords(session, anchorKey)
    local projected, x, y = projectToScreen(session, coords)
    if projected and x and y then
        session.packAnchors = session.packAnchors or {}
        session.packAnchors[anchorKey] = { x = x, y = y }
        return x, y
    end
    if session.packAnchors and session.packAnchors[anchorKey] then
        return session.packAnchors[anchorKey].x, session.packAnchors[anchorKey].y
    end
    if anchorKey == 'bag' then return 0.40, 0.56 end
    return 0.68, 0.52
end

local function entityFromCursorRay(session, normX, normY)
    if not session.cam or not DoesCamExist(session.cam) then return nil end
    local camPos = GetCamCoord(session.cam)
    local worldCoord, normalDir = GetWorldCoordFromScreenCoord(normX, normY)
    if not worldCoord or not normalDir then return nil end
    local target = worldCoord + normalDir * 12.0
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, target.x, target.y, target.z, -1, PlayerPedId(), 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit ~= 1 or not entity or entity == 0 then return nil end
    return entity
end

local function getPackTargetFromCursor(session, normX, normY)
    local bestTarget = nil
    local bestDist = PACK_CLICK_RADIUS

    if session.stage == 'bag_select' and session.bag and session.bag.entity then
        local x, y = getPackScreenPoint(session, 'bag')
        local dist = math.sqrt((normX - x) * (normX - x) + (normY - y) * (normY - y))
        if dist <= bestDist then
            bestTarget = 'bag'
            bestDist = dist
        end
    end

    if session.stage == 'packing' and session.currentBud and DoesEntityExist(session.currentBud) then
        local x, y = getPackScreenPoint(session, 'bud')
        local dist = math.sqrt((normX - x) * (normX - x) + (normY - y) * (normY - y))
        if dist <= bestDist then
            bestTarget = 'bud'
            bestDist = dist
        end
    end

    if bestTarget then return bestTarget end

    local entity = entityFromCursorRay(session, normX, normY)
    if not entity then return nil end
    if session.stage == 'bag_select' and session.bag and entity == session.bag.entity then
        return 'bag'
    end
    if session.stage == 'packing' and session.currentBud and entity == session.currentBud then
        return 'bud'
    end
    return nil
end

local function tryPackCursorClick(session)
    if session.mode ~= 'pack' or session.packBusy then return end
    if not (IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24)) then return end

    -- Each pack step only has one valid action. Any left-click should trigger it
    -- instead of relying on brittle screen hitboxes or CEF overlays.
    if session.stage == 'bag_select' and session.bag and session.bag.entity then
        handlePackClick(session, 'bag')
        return
    end
    if session.stage == 'packing' and session.currentBud and DoesEntityExist(session.currentBud) then
        handlePackClick(session, 'bud')
        return
    end

    local normX, normY = getPackCursorNorm()
    if not normX then return end
    local target = getPackTargetFromCursor(session, normX, normY)
    if target then handlePackClick(session, target) end
end

updatePackTargets = function(session)
    if GetGameTimer() - (session.lastTargetHudAt or 0) < 50 then return end
    session.lastTargetHudAt = GetGameTimer()
    updatePackHighlights(session)
    local bagActive = session.stage == 'bag_select' and not session.packBusy
    local budActive = session.stage == 'packing' and not session.packBusy
        and session.currentBud and DoesEntityExist(session.currentBud)
    local bagCoords = packAnchorCoords(session, 'bag')
    local budCoords = packAnchorCoords(session, 'bud')
    hud('weedPackTargets', {
        bag = screenTargetForPack(session, bagCoords, 'bag', bagActive),
        bud = screenTargetForPack(session, budCoords, 'bud', budActive),
        packed = session.packedCount,
        targetCount = session.packTarget,
    })
end

local function runSession(session)
    CreateThread(function()
        while active == session and not session.finished do
            Wait(0)
            if not controls(session) then return end
            updateCamera(session)
            if session.mode == 'pack' then
                updatePackTargets(session)
                tryPackCursorClick(session)
            end
            drawSnapPoints(session)

            if session.mode ~= 'pack'
                and (session.stage == 'sorting' or session.stage == 'weighing' or session.stage == 'bagging') then
                updateSelection(session)
                updateHeld(session)
                if IsDisabledControlJustPressed(0, 38) then
                    if session.held then placeHeld(session) else pickSelected(session) end
                end
                local focus = session.held or session.selected
                if GetGameTimer() - (session.lastInteractionHudAt or 0) >= 100 then
                    session.lastInteractionHudAt = GetGameTimer()
                    hud('weed3dUpdate', {
                        title = session.mode == 'process' and 'Žolė · rūšiavimas' or 'Žolė · pakavimas',
                        stage = session.mode == 'process' and '1/2' or (session.stage == 'weighing' and '1/3' or '2/3'),
                        hint = focus and (('%s · E – %s · ratukas – sukti'):format(
                            focus.label or 'Objektas',
                            session.held and 'padėti' or 'paimti'
                        )) or 'Nukreipk kamerą į objektą.',
                        score = math.floor(session.score),
                        mistakes = session.mistakes,
                        weight = session.mode == 'pack' and session.totalWeight or nil,
                        target = session.mode == 'pack' and '4.90–5.10 g' or nil,
                    })
                end
            elseif session.stage == 'drying' then
                updateDrying(session)
            elseif session.stage == 'sealing' then
                updateSealing(session)
            end
        end
    end)
end

RegisterNUICallback('weedPackClick', function(data, cb)
    local session = active
    local target = tostring(data and data.target or '')
    if session and session.mode == 'pack' and not session.packBusy then
        if session.stage == 'bag_select' then
            target = 'bag'
        elseif session.stage == 'packing' and session.currentBud
            and DoesEntityExist(session.currentBud) then
            target = 'bud'
        end
    end
    local accepted = session and handlePackClick(session, target)
    cb(accepted and 'ok' or 'ignored')
end)

RegisterNUICallback('weedPackCancel', function(_, cb)
    local session = active
    if session and session.mode == 'pack' then
        finishSession(false, {
            score = math.floor(session.score or 0),
            mistakes = (session.mistakes or 0) + 1,
            reason = 'cancelled',
        })
    end
    cb('ok')
end)

function WeedProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { score = 0, mistakes = 1, reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { score = 0, mistakes = 1, reason = 'missing_craft_token' }) end
        return false
    end
    local mode = payload.mode == 'weed_pack' and 'pack' or 'process'
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local origin = pedCoords + directionFromHeading(heading) * 1.35
    local workspace = payload.workspace
    if mode == 'pack' and workspace and workspace.x and workspace.y and workspace.z then
        origin = vector3(workspace.x + 0.0, workspace.y + 0.0, workspace.z + 0.0)
        heading = tonumber(workspace.w) or heading
    end

    local session = {
        id = payload.sessionId,
        craftToken = payload.craftToken,
        mode = mode,
        onDone = onDone,
        heading = heading,
        tableOrigin = origin,
        entities = {},
        items = {},
        snaps = {},
        score = 0,
        mistakes = 0,
        finished = false,
    }
    active = session

    if mode == 'pack' then
        local existingTable, existingTableHash
        local findDeadline = GetGameTimer() + 8000
        repeat
            RequestCollisionAtCoord(origin.x, origin.y, origin.z)
            local hash = joaat(MODELS.table[1])
            local entity = GetClosestObjectOfType(origin.x, origin.y, origin.z, 5.0, hash, false, false, false)
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                existingTable = entity
                existingTableHash = hash
            end
            if not existingTable then Wait(100) end
        until existingTable or GetGameTimer() >= findDeadline
        if not existingTable then
            finishSession(false, {
                score = 0,
                mistakes = 1,
                reason = 'existing_table_not_found',
            })
            QBCore.Functions.Notify('Nerastas esamas pakavimo stalas.', 'error')
            return false
        end
        session.tableOrigin = GetEntityCoords(existingTable)
        session.heading = GetEntityHeading(existingTable)
        local _, maxDim = GetModelDimensions(existingTableHash)
        session.tableTop = session.tableOrigin.z + math.max(0.65, maxDim.z) + 0.03
    else
        local tableHash = loadFirstModel(MODELS.table)
        if not tableHash then
            finishSession(false, { score = 0, mistakes = 1, reason = 'table_model_missing' })
            return false
        end
        local tableEntity = registerEntity(session, createLocalObject(tableHash, origin, heading))
        if not tableEntity then
            finishSession(false, { score = 0, mistakes = 1, reason = 'table_spawn_failed' })
            return false
        end
        PlaceObjectOnGroundProperly(tableEntity)
        FreezeEntityPosition(tableEntity, true)
        session.tableOrigin = GetEntityCoords(tableEntity)
        local _, maxDim = GetModelDimensions(tableHash)
        session.tableTop = session.tableOrigin.z + math.max(0.65, maxDim.z) + 0.03
        SetModelAsNoLongerNeeded(tableHash)
    end
    session.lookAt = vector3(session.tableOrigin.x, session.tableOrigin.y, session.tableTop + 0.08)

    if not createCamera(session) then
        finishSession(false, { score = 0, mistakes = 1, reason = 'camera_failed' })
        return false
    end

    if mode == 'pack' then
        TaskTurnPedToFaceCoord(ped, session.tableOrigin.x, session.tableOrigin.y, session.tableTop, 600)
        Wait(600)
    end
    FreezeEntityPosition(ped, true)
    SetNuiFocus(false, false)
    local ok, reason = mode == 'process' and setupProcess(session) or setupPack(session)
    if not ok then
        finishSession(false, { score = 0, mistakes = 1, reason = reason })
        return false
    end

    hud('weed3dOpen', {
        title = mode == 'process' and 'Žolė · rūšiavimas' or 'Žolė · pakavimas',
        stage = mode == 'process' and '1/2' or '1/2',
        hint = mode == 'process'
            and 'Pelė – kamera · E – paimti/padėti · ratukas – sukti · ESC – atšaukti'
            or 'Spausk kairį pelės mygtuką ant maišelio, tada ant žolės gabaliukų.',
        packed = mode == 'pack' and 0 or nil,
        targetCount = mode == 'pack' and 5 or nil,
    })
    if mode == 'pack' then
        -- Keep the HUD visible but let GTA receive mouse clicks directly.
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        hud('weedPackClose')
        CreateThread(function()
            Wait(250)
            if active == session then cachePackScreenAnchors(session) end
        end)
    end
    runSession(session)
    return true
end

function WeedProduction.Close(reason)
    if not active then return end
    finishSession(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function WeedProduction.IsActive()
    return active ~= nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if active then
        local session = active
        if session.craftToken then
            TriggerServerEvent('mrp_drugs:server:cancelCraft', session.craftToken, 'resource_stop')
        end
        active = nil
        cleanupSession(session)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    WeedProduction.Close('player_unload')
end)

AddEventHandler('baseevents:onPlayerDied', function()
    WeedProduction.Close('player_died')
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    WeedProduction.Close('player_killed')
end)

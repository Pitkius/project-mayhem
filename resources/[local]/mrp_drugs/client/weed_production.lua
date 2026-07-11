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
    bag = { 'prop_meth_bag_01', 'prop_cs_package_01' },
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

local function cleanupSession(session)
    if not session then return end
    clearSelection(session)
    for _, entry in ipairs(session.items or {}) do
        if entry.entity and DoesEntityExist(entry.entity) then
            SetEntityDrawOutline(entry.entity, false)
        end
    end
    for _, entity in ipairs(session.entities or {}) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    if session.cam and DoesCamExist(session.cam) then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(session.cam, false)
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    SetNuiFocus(false, false)
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
    QBCore.Functions.TriggerCallback('mrp_drugs:server:weedProductionStage', function(response)
        if active ~= session or session.finished then return end
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
end

local function finishAfterServerStage(session, stage, success, extra)
    session.stage = 'stage_pending'
    reportServerStage(session, stage, function()
        if active == session then finishSession(success, extra) end
    end)
end

local function createCamera(session)
    session.camYaw = session.heading + 180.0
    session.camPitch = -22.0
    session.camDistance = 3.5
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not session.cam or session.cam == 0 then return false end
    SetCamActive(session.cam, true)
    SetCamFov(session.cam, 45.0)
    RenderScriptCams(true, true, 350, true, true)
    return true
end

local function updateCamera(session)
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

    if session.stage == 'stage_pending' then return true end
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

local function setupPack(session)
    session.stage = 'weighing'
    session.score = 0
    session.mistakes = 0

    local leafHash = loadFirstModel(MODELS.leaf)
    local scaleHash = loadFirstModel(MODELS.scale)
    local bagHash = loadFirstModel(MODELS.bag)
    if not leafHash or not scaleHash or not bagHash then
        return false, 'Nerasti pakavimui reikalingi objektų modeliai.'
    end

    local scalePos = offsetPoint(session.tableOrigin, session.heading, -0.52, 0.32, session.tableTop - session.tableOrigin.z + 0.04)
    registerEntity(session, createLocalObject(scaleHash, scalePos, session.heading))

    local bagPos = offsetPoint(session.tableOrigin, session.heading, 0.62, 0.32, session.tableTop - session.tableOrigin.z + 0.08)
    local bagEntity = registerEntity(session, createLocalObject(bagHash, bagPos, session.heading))
    session.bag = {
        entity = bagEntity,
        kind = 'bag',
        label = 'Pripildytas maišelis',
        movable = false,
    }
    session.items[#session.items + 1] = session.bag

    for i = 1, 5 do
        local pos = offsetPoint(session.tableOrigin, session.heading, -0.70 + (i - 1) * 0.35, -0.30, session.tableTop - session.tableOrigin.z + 0.10)
        local entity = registerEntity(session, createLocalObject(leafHash, pos, session.heading + i * 11.0))
        if not entity then return false, 'Nepavyko sukurti džiovintų žiedų.' end
        session.items[#session.items + 1] = {
            entity = entity,
            kind = 'bud',
            label = ('Džiovintas žiedas %d'):format(i),
            weight = ({ 1.04, 0.93, 1.08, 0.97, 0.98 })[i],
        }
    end
    SetModelAsNoLongerNeeded(leafHash)
    SetModelAsNoLongerNeeded(scaleHash)
    SetModelAsNoLongerNeeded(bagHash)

    local scaleSnap = {
        id = 'scale',
        coords = scalePos + vector3(0.0, 0.0, 0.16),
        heading = session.heading,
        radius = 0.28,
        color = { 70, 170, 235 },
        accept = function(entry) return entry.kind == 'bud' end,
    }
    scaleSnap.onPlace = function(entry, _, distance)
        session.totalWeight = (session.totalWeight or 0) + entry.weight
        session.score = session.score + math.floor(math.max(8, 16 - distance * 20))
        SetEntityVisible(entry.entity, false, false)
        SetEntityCollision(entry.entity, false, false)
        hud('weed3dUpdate', {
            title = 'Žolė · svėrimas',
            stage = '1/3',
            hint = 'Dėk likusius žiedus ant svarstyklių.',
            weight = session.totalWeight,
            target = '4.90–5.10 g',
            score = math.floor(session.score),
        })
        if allPlaced(session, 'bud') then
            session.stage = 'stage_pending'
            reportServerStage(session, 'weighed', function()
                session.stage = 'bagging'
                session.bag.movable = true
                session.bag.placed = false
                session.snaps = {
                    {
                        id = 'sealer',
                        coords = offsetPoint(session.tableOrigin, session.heading, 0.48, -0.05, session.tableTop - session.tableOrigin.z + 0.09),
                        heading = session.heading,
                        radius = 0.30,
                        color = { 180, 100, 235 },
                        accept = function(item) return item.kind == 'bag' end,
                        onPlace = function()
                            session.stage = 'stage_pending'
                            reportServerStage(session, 'bagged', function()
                                session.stage = 'sealing'
                                session.stageStartedAt = GetGameTimer()
                                session.snaps = {}
                                local weightAccuracy = math.max(0, 20 - math.abs((session.totalWeight or 0) - 5.0) * 80)
                                session.score = session.score + weightAccuracy
                                hud('weed3dUpdate', {
                                    title = 'Žolė · sandarinimas',
                                    stage = '3/3',
                                    hint = 'Spausk E, kai slėgio indikatorius bus žalioje zonoje.',
                                    seal = 0,
                                    score = math.floor(session.score),
                                })
                            end)
                        end,
                    },
                }
                hud('weed3dUpdate', {
                    title = 'Žolė · pakavimas',
                    stage = '2/3',
                    hint = 'Paimk maišelį ir įstatyk į violetinį sandarinimo tašką.',
                    weight = session.totalWeight,
                })
            end)
        end
    end
    session.snaps = { scaleSnap }
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

local function runSession(session)
    CreateThread(function()
        while active == session and not session.finished do
            Wait(0)
            if not controls(session) then return end
            updateCamera(session)
            drawSnapPoints(session)

            if session.stage == 'sorting' or session.stage == 'weighing' or session.stage == 'bagging' then
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

    local tableHash = loadFirstModel(MODELS.table)
    if not tableHash then
        if onDone then onDone(false, { score = 0, mistakes = 1, reason = 'table_model_missing' }) end
        return false
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

    local tableEntity = registerEntity(session, createLocalObject(tableHash, origin, heading))
    if not tableEntity then
        finishSession(false, { score = 0, mistakes = 1, reason = 'table_spawn_failed' })
        return false
    end
    PlaceObjectOnGroundProperly(tableEntity)
    FreezeEntityPosition(tableEntity, true)
    SetModelAsNoLongerNeeded(tableHash)
    session.tableOrigin = GetEntityCoords(tableEntity)
    local _, maxDim = GetModelDimensions(tableHash)
    session.tableTop = session.tableOrigin.z + math.max(0.65, maxDim.z) + 0.03
    session.lookAt = vector3(session.tableOrigin.x, session.tableOrigin.y, session.tableTop + 0.08)

    if not createCamera(session) then
        finishSession(false, { score = 0, mistakes = 1, reason = 'camera_failed' })
        return false
    end

    FreezeEntityPosition(ped, true)
    SetNuiFocus(false, false)
    local ok, reason = mode == 'process' and setupProcess(session) or setupPack(session)
    if not ok then
        finishSession(false, { score = 0, mistakes = 1, reason = reason })
        return false
    end

    hud('weed3dOpen', {
        title = mode == 'process' and 'Žolė · rūšiavimas' or 'Žolė · svėrimas',
        stage = mode == 'process' and '1/2' or '1/3',
        hint = 'Pelė – kamera · E – paimti/padėti · ratukas – sukti · ESC – atšaukti',
    })
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

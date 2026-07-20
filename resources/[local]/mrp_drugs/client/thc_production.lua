--- L1 THC production: GTA world 3D interaction (trim → distill → cart pack).
ThcProduction = ThcProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active

local PROCESS_STEPS = { 'prepare', 'trim', 'heat', 'collect', 'stabilize' }
local PACK_STEPS = { 'cartridge', 'fill', 'coil', 'seal', 'finalize' }
local LABELS = {
    prepare = 'Paruošk distiliatorių',
    trim = 'Apkirpk trim medžiagą',
    heat = 'Įkaitink distiliatorių',
    collect = 'Surink THC distiliatą',
    stabilize = 'Stabilizuok temperatūrą',
    cartridge = 'Pasirink tuščią kasetę',
    fill = 'Užpildyk kasetę',
    coil = 'Įkaitink ritę',
    seal = 'Užsandarink antgalį',
    finalize = 'Patikrink ir užbaik',
}
local TRIM_NEED = 4
local COIL_SEQ = { 2, 1, 3 }

local function clamp(value, low, high)
    return Interaction3D.Clamp(value, low, high)
end

local function hud(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function stageIndex(session)
    for index, name in ipairs(session.steps) do
        if name == session.stage then return index end
    end
    return 1
end

local function updateHud(session, hint, extra)
    local data = extra or {}
    data.title = session.mode == 'pack' and 'THC · kasetės pildymas' or 'THC · distiliacija'
    data.stage = ('%d/%d'):format(stageIndex(session), #session.steps)
    data.stageName = LABELS[session.stage] or session.stage
    data.hint = hint or ''
    data.score = math.floor(session.score or 0)
    data.mistakes = session.mistakes or 0
    data.kicker = '3D THC WORKSTATION'
    hud('vape3dUpdate', data)
end

local function cleanup(session)
    if not session or session.cleaned then return end
    session.cleaned = true
    Interaction3D.Cleanup(session.world)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    hud('vape3dClose')
end

local function finish(session, success, reason)
    if active ~= session or session.finished then return end
    session.finished = true
    active = nil
    cleanup(session)
    local result = {
        success = success == true,
        score = math.floor(clamp(session.score or 0, 0, 100)),
        mistakes = session.mistakes or 0,
        reason = reason or (success and 'completed' or 'failed'),
        sessionId = session.id,
    }
    local callback = session.onDone
    session.onDone = nil
    if callback then callback(success == true, result) end
end

local function reportStage(session, stageName, accepted)
    if active ~= session or session.finished or session.pending then return end
    session.pending = true
    session.requestId = (session.requestId or 0) + 1
    local requestId = session.requestId
    updateHud(session, 'Tikrinamas etapas…')
    QBCore.Functions.TriggerCallback('mrp_drugs:server:thcProductionStage', function(response)
        if active ~= session or session.finished or session.requestId ~= requestId then return end
        session.pending = false
        if not response or not response.ok then
            session.mistakes = session.mistakes + 1
            finish(session, false, (response and response.reason) or 'stage_rejected')
            return
        end
        if accepted then accepted(response) end
    end, session.craftToken, stageName)
    CreateThread(function()
        Wait(30000)
        if active ~= session or session.finished or not session.pending or session.requestId ~= requestId then return end
        session.pending = false
        session.mistakes = session.mistakes + 1
        finish(session, false, 'stage_timeout')
    end)
end

local function nextStage(session, completed, callback)
    reportStage(session, completed, function(response)
        if active ~= session then return end
        session.step = session.step + 1
        session.stage = session.steps[session.step]
        if callback then callback(response) end
    end)
end

local function spawnScene(session)
    local world = session.world
    local origin, heading = session.origin, session.heading
    local workspace = session.workspace

    --- Fiksuota įranga (thc_still / bagging_table) — NEspawninti antrojo stalo.
    local anchorModels = session.mode == 'pack'
        and { 'bkr_prop_weed_table_01a', 'prop_tool_bench02', 'bkr_prop_meth_table01a' }
        or { 'bkr_prop_weed_table_01a', 'prop_cooker_03', 'bkr_prop_meth_table01a', 'prop_tool_bench02' }

    local existing = Interaction3D.ResolveExisting(workspace, anchorModels, origin, 5.0)
    if existing and DoesEntityExist(existing) then
        session.anchor = existing
        session.origin = GetEntityCoords(existing)
        session.heading = GetEntityHeading(existing)
        heading = session.heading
        origin = session.origin
        session.table = existing
    else
        local table = Interaction3D.Spawn(world,
            { 'bkr_prop_weed_table_01a', 'prop_tool_bench02', 'bkr_prop_weed_table_01a' },
            origin, heading, { ground = true })
        if not table then return false, 'table_spawn_failed' end
        session.table = table
        session.origin = GetEntityCoords(table)
        session.heading = GetEntityHeading(table)
        heading = session.heading
        origin = session.origin
    end

    session.top = Interaction3D.SurfaceTop(session.table or session.anchor, origin.z)
    session.lookAt = vector3(origin.x, origin.y, session.top + 0.05)

    local back = Interaction3D.Offset(origin, heading, 0.0, -2.30, 1.55)
    if not Interaction3D.CreateCamera(world, back, session.lookAt, 43.0) then
        return false, 'camera_failed'
    end
    world.lookAt = session.lookAt
    world.camDistance = 2.85

    local vialPos = Interaction3D.Offset(origin, heading, 0.52, -0.15, session.top - origin.z + 0.12)
    session.vial = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, vialPos, heading, { collision = false })
    if not session.vial then return false, 'vial_spawn_failed' end

    local scalePos = Interaction3D.Offset(origin, heading, -0.48, 0.05, session.top - origin.z + 0.03)
    session.scale = Interaction3D.Spawn(world, { 'bkr_prop_coke_scale_01' }, scalePos, heading, { collision = false })

    if session.mode == 'process' then
        local stillPos = Interaction3D.Offset(origin, heading, 0.0, 0.22, session.top - origin.z + 0.04)
        session.still = Interaction3D.Spawn(world, { 'prop_cooker_03' }, stillPos, heading, { collision = false })
        if not session.still then return false, 'still_spawn_failed' end

        local trimPos = Interaction3D.Offset(origin, heading, -0.35, -0.20, session.top - origin.z + 0.05)
        session.trim = Interaction3D.Spawn(world, { 'bkr_prop_weed_bud_02b', 'bkr_prop_weed_leaf_01a', 'prop_meth_bag_01' },
            trimPos, heading, { collision = false })
        if not session.trim then return false, 'trim_spawn_failed' end

        local scissorsPos = Interaction3D.Offset(origin, heading, 0.38, 0.28, session.top - origin.z + 0.06)
        session.scissors = Interaction3D.Spawn(world, { 'prop_cs_scissors' }, scissorsPos, heading + 90.0, { collision = false })
        if not session.scissors then return false, 'scissors_spawn_failed' end

        session.collectPoint = Interaction3D.Offset(origin, heading, 0.0, 0.05, session.top - origin.z + 0.30)
    else
        local corkPos = Interaction3D.Offset(origin, heading, 0.45, 0.25, session.top - origin.z + 0.12)
        session.cap = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, corkPos, heading + 180.0, { collision = false })
        if not session.cap then return false, 'cap_spawn_failed' end

        session.coilPads = {}
        local padOffsets = {
            { -0.28, 0.18 },
            { 0.0, 0.28 },
            { 0.28, 0.18 },
        }
        for i, off in ipairs(padOffsets) do
            local pos = Interaction3D.Offset(origin, heading, off[1], off[2], session.top - origin.z + 0.04)
            local pad = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, pos, heading + (i * 40.0), { collision = false })
            if not pad then return false, 'coil_pad_spawn_failed' end
            session.coilPads[i] = pad
        end
    end
    return true
end

local function selectEntity(session, target, hint, onSelected)
    local entity = Interaction3D.RaycastCamera(session.world, 8.0, PlayerPedId())
    Interaction3D.Select(session.world, entity == target and target or nil)
    updateHud(session, entity == target and ('E · %s'):format(hint) or 'Nukreipk kamerą į pažymėtą objektą.')
    if entity == target and IsDisabledControlJustPressed(0, 38) then
        Interaction3D.Select(session.world, nil)
        onSelected()
    end
end

local function updateProcess(session)
    if session.stage == 'trim' then
        if not session.trimReady then
            selectEntity(session, session.scissors, 'paimti žirkles', function()
                session.trimReady = true
                session.cuts = 0
                session.score = session.score + 8
                updateHud(session, ('E · kirpti trim (%d/%d)'):format(0, TRIM_NEED))
            end)
        else
            selectEntity(session, session.trim, ('kirpti (%d/%d)'):format(session.cuts or 0, TRIM_NEED), function()
                session.cuts = (session.cuts or 0) + 1
                session.score = session.score + 4
                if session.cuts >= TRIM_NEED then
                    nextStage(session, 'trim', function()
                        session.hold = 0
                        updateHud(session, 'Laikyk E ir kaitink distiliatorių.')
                    end)
                else
                    updateHud(session, ('E · kirpti trim (%d/%d)'):format(session.cuts, TRIM_NEED))
                end
            end)
        end
    elseif session.stage == 'heat' then
        local dt = GetFrameTime()
        if IsDisabledControlPressed(0, 38) then
            session.hold = clamp((session.hold or 0) + dt / 2.0, 0.0, 1.0)
        else
            session.hold = clamp((session.hold or 0) - dt * 0.28, 0.0, 1.0)
        end
        Interaction3D.Select(session.world, session.still)
        updateHud(session, 'Laikyk E ir kaitink distiliatorių.', { progress = session.hold })
        if session.hold >= 1.0 then
            session.score = session.score + 15
            nextStage(session, 'heat', function()
                updateHud(session, 'Nukreipk kamerą į indą ir spausk E.')
            end)
        end
    elseif session.stage == 'collect' then
        if not session.collecting then
            selectEntity(session, session.vial, 'paimti indą', function()
                session.collecting = true
                session.score = session.score + 10
                updateHud(session, 'E · perkelti indą prie distiliatoriaus.')
            end)
        else
            Interaction3D.DrawSnaps({ { coords = session.collectPoint, radius = 0.25 } })
            Interaction3D.Select(session.world, session.vial)
            updateHud(session, 'E · sklandžiai perkelti prie snap taško.')
            if IsDisabledControlJustPressed(0, 38) then
                Interaction3D.Select(session.world, nil)
                session.pending = true
                Interaction3D.MoveSmooth(session.vial, session.collectPoint, 650, function()
                    return active == session
                end, function()
                    session.pending = false
                    session.score = session.score + 15
                    nextStage(session, 'collect', function()
                        session.hold = 0.55
                        session.holdGood = 0
                        session.gaugeStarted = GetGameTimer()
                        updateHud(session, 'Laikyk temperatūrą A/D pagal rodyklę.')
                    end)
                end)
            end
        end
    elseif session.stage == 'stabilize' then
        local dt = GetFrameTime()
        local target = 0.5 + 0.22 * math.sin((GetGameTimer() - session.gaugeStarted) / 900.0)
        if IsDisabledControlPressed(0, 34) then
            session.hold = clamp((session.hold or 0.5) - dt * 0.35, 0.0, 1.0)
        elseif IsDisabledControlPressed(0, 35) then
            session.hold = clamp((session.hold or 0.5) + dt * 0.35, 0.0, 1.0)
        else
            session.hold = clamp((session.hold or 0.5) + (target - (session.hold or 0.5)) * dt * 0.15, 0.0, 1.0)
        end
        local error = math.abs((session.hold or 0.5) - target)
        session.holdGood = (session.holdGood or 0) + (error <= 0.12 and dt or -dt * 0.35)
        session.holdGood = clamp(session.holdGood, 0.0, 2.4)
        if error > 0.28 then
            session.score = math.max(0, session.score - dt * 4)
        end
        updateHud(session, 'A/D · laikyk temperatūrą žalioje zonoje.', {
            progress = session.holdGood / 2.4,
            gauge = session.hold,
        })
        if session.holdGood >= 2.4 then
            session.score = session.score + 25
            reportStage(session, 'stabilize', function()
                finish(session, true, 'completed')
            end)
        end
    end
end

local function updatePack(session)
    if session.stage == 'cartridge' then
        selectEntity(session, session.vial, 'pasirinkti kasetę', function()
            session.score = session.score + 12
            nextStage(session, 'cartridge', function()
                session.hold = 0
                session.gaugeStarted = GetGameTimer()
                updateHud(session, 'Laikyk E žalioje slėgio zonoje.')
            end)
        end)
    elseif session.stage == 'fill' then
        local dt = GetFrameTime()
        local gauge = (math.sin((GetGameTimer() - session.gaugeStarted) / 280.0) + 1.0) * 0.5
        local inZone = gauge >= 0.42 and gauge <= 0.72
        if IsDisabledControlPressed(0, 38) then
            if inZone then
                session.hold = clamp((session.hold or 0) + dt / 2.2, 0.0, 1.0)
            else
                session.hold = clamp((session.hold or 0) - dt * 0.35, 0.0, 1.0)
                session.score = math.max(0, session.score - dt * 6)
            end
        end
        Interaction3D.Select(session.world, session.vial)
        updateHud(session, inZone and 'Laikyk E · slėgis geras.' or 'Palauk žalios zonos, tada laikyk E.', {
            progress = session.hold or 0,
            gauge = gauge,
        })
        if (session.hold or 0) >= 1.0 then
            session.score = session.score + 20
            nextStage(session, 'fill', function()
                session.coilStep = 1
                updateHud(session, ('E · įkaitink ritę (%d/%d)'):format(1, #COIL_SEQ))
            end)
        end
    elseif session.stage == 'coil' then
        local step = session.coilStep or 1
        local padIndex = COIL_SEQ[step]
        local target = session.coilPads and session.coilPads[padIndex]
        if not target then
            finish(session, false, 'coil_pad_missing')
            return
        end
        selectEntity(session, target, ('įkaitinti ritę %d/%d'):format(step, #COIL_SEQ), function()
            session.score = session.score + 8
            if step >= #COIL_SEQ then
                nextStage(session, 'coil', function()
                    session.gaugeStarted = GetGameTimer()
                    updateHud(session, 'Spausk E žalioje sandarinimo zonoje.')
                end)
            else
                session.coilStep = step + 1
                updateHud(session, ('E · įkaitink ritę (%d/%d)'):format(session.coilStep, #COIL_SEQ))
            end
        end)
    elseif session.stage == 'seal' then
        local gauge = (math.sin((GetGameTimer() - session.gaugeStarted) / 300.0) + 1.0) * 0.5
        updateHud(session, 'E · sandarinti ties 68–84%.', { gauge = gauge })
        if IsDisabledControlJustPressed(0, 38) then
            if gauge >= 0.68 and gauge <= 0.84 then
                session.score = session.score + 22
            else
                session.score = session.score + 6
                session.mistakes = session.mistakes + 1
            end
            nextStage(session, 'seal', function()
                updateHud(session, 'E · galutinė kokybės patikra.')
            end)
        end
    elseif session.stage == 'finalize' then
        Interaction3D.Select(session.world, session.vial)
        updateHud(session, 'E · patvirtinti paruoštą kasetę.')
        if IsDisabledControlJustPressed(0, 38) then
            Interaction3D.Select(session.world, nil)
            session.score = session.score + 15
            reportStage(session, 'finalize', function()
                finish(session, true, 'completed')
            end)
        end
    end
end

local function run(session)
    CreateThread(function()
        while active == session and not session.finished do
            Interaction3D.UpdateOrbitCamera(session.world, {
                distance = 2.85,
                minPitch = -42.0,
                maxPitch = -8.0,
            })
            if not session.pending then
                if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 73) then
                    session.mistakes = session.mistakes + 1
                    finish(session, false, 'cancelled')
                    return
                end
                if session.mode == 'pack' then updatePack(session) else updateProcess(session) end
            elseif IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 73) then
                session.mistakes = session.mistakes + 1
                finish(session, false, 'cancelled')
                return
            end
            Wait(0)
        end
    end)
end

function ThcProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { score = 0, mistakes = 1, reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { score = 0, mistakes = 1, reason = 'missing_craft_token' }) end
        return false
    end

    local mode = 'process'
    if payload.mode == 'thc_pack' or tostring(payload.productId or ''):find('_pack$') then
        mode = 'pack'
    end
    local ped = PlayerPedId()
    local heading = tonumber(payload.workspace and payload.workspace.w) or GetEntityHeading(ped)
    local coords = GetEntityCoords(ped)
    local origin = coords + Interaction3D.Forward(heading) * 1.35
    if payload.workspace and payload.workspace.x and payload.workspace.y and payload.workspace.z then
        origin = vector3(payload.workspace.x, payload.workspace.y, payload.workspace.z)
    end

    local session = {
        id = tostring(payload.sessionId or ''),
        craftToken = payload.craftToken,
        productId = payload.productId,
        mode = mode,
        steps = mode == 'pack' and PACK_STEPS or PROCESS_STEPS,
        step = 1,
        stage = mode == 'pack' and 'cartridge' or 'prepare',
        origin = origin,
        heading = heading,
        workspace = payload.workspace,
        world = Interaction3D.NewRegistry(),
        score = 0,
        mistakes = 0,
        onDone = onDone,
    }
    active = session
    local ok, reason = spawnScene(session)
    if not ok then
        finish(session, false, reason)
        return false
    end

    TaskTurnPedToFaceCoord(ped, session.origin.x, session.origin.y, session.top, 500)
    Wait(500)
    FreezeEntityPosition(ped, true)
    hud('vape3dOpen', {
        title = mode == 'pack' and 'THC · kasetės pildymas' or 'THC · distiliacija',
        stage = ('1/%d'):format(#session.steps),
        stageName = LABELS[session.stage],
        hint = 'Pelė · kamera · E · veiksmas · ESC · atšaukti',
        kicker = '3D THC WORKSTATION',
    })

    if mode == 'process' then
        reportStage(session, 'prepare', function()
            session.score = session.score + 10
            session.step, session.stage = 2, 'trim'
            updateHud(session, 'Nukreipk kamerą į žirkles ir spausk E.')
        end)
    else
        updateHud(session, 'Nukreipk kamerą į kasetę ir spausk E.')
    end
    run(session)
    return true
end

function ThcProduction.Close(reason)
    local session = active
    if not session then return false end
    session.finished = true
    session.onDone = nil
    active = nil
    cleanup(session)
    return true
end

function ThcProduction.IsActive()
    return active ~= nil
end

exports('StartThcProduction', function(payload, onDone)
    return ThcProduction.Start(payload, onDone)
end)

exports('CloseThcProduction', function(reason)
    return ThcProduction.Close(reason)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and active then
        ThcProduction.Close('resource_stop')
    end
end)

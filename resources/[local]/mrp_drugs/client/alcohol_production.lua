--- L1 alcohol production: GTA world interaction with shared 3D HUD.
AlcoholProduction = AlcoholProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active

local PROCESS_STEPS = { 'prepare', 'heat', 'hold', 'distill', 'collect', 'cool' }
local PACK_STEPS = { 'bottle', 'pour', 'cork', 'seal', 'finalize' }
local LABELS = {
    prepare = 'Paruošk distiliatorių',
    heat = 'Įkaitink katilą',
    hold = 'Laikyk temperatūrą',
    distill = 'Distiliuok samagoną',
    collect = 'Surink distiliatą',
    cool = 'Atvėsink ir užbaik',
    bottle = 'Pasirink stiklainį',
    pour = 'Supilk samagoną',
    cork = 'Užkimšk stiklainį',
    seal = 'Užsandarink',
    finalize = 'Patikrink ir užbaik',
}

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
    data.title = session.mode == 'pack' and 'Samagonas · pakavimas' or 'Samagonas · distiliacija'
    data.stage = ('%d/%d'):format(stageIndex(session), #session.steps)
    data.stageName = LABELS[session.stage] or session.stage
    data.hint = hint or ''
    data.score = math.floor(session.score or 0)
    data.mistakes = session.mistakes or 0
    data.kicker = '3D ALCOHOL WORKSTATION'
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
    QBCore.Functions.TriggerCallback('mrp_drugs:server:alcoholProductionStage', function(response)
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
    local table = Interaction3D.Spawn(world,
        session.mode == 'pack' and { 'prop_tool_bench02', 'bkr_prop_weed_table_01a' }
            or { 'bkr_prop_meth_table01a', 'prop_tool_bench02', 'bkr_prop_weed_table_01a' },
        origin, heading, { ground = true })
    if not table then return false, 'table_spawn_failed' end
    session.origin = GetEntityCoords(table)
    local _, tableMax = GetModelDimensions(GetEntityModel(table))
    session.top = session.origin.z + math.max(0.70, tableMax.z) + 0.03
    session.lookAt = vector3(session.origin.x, session.origin.y, session.top + 0.05)

    local back = Interaction3D.Offset(session.origin, heading, 0.0, -2.30, 1.55)
    if not Interaction3D.CreateCamera(world, back, session.lookAt, 43.0) then
        return false, 'camera_failed'
    end
    world.lookAt = session.lookAt
    world.camDistance = 2.85

    local bottlePos = Interaction3D.Offset(session.origin, heading, 0.52, -0.15, session.top - session.origin.z + 0.12)
    session.bottle = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, bottlePos, heading, {})
    if not session.bottle then return false, 'bottle_spawn_failed' end

    if session.mode == 'process' then
        local cookerPos = Interaction3D.Offset(session.origin, heading, 0.0, 0.22, session.top - session.origin.z + 0.04)
        session.cooker = Interaction3D.Spawn(world, { 'prop_cooker_03' }, cookerPos, heading, {})
        if not session.cooker then return false, 'cooker_spawn_failed' end
        session.collectPoint = Interaction3D.Offset(session.origin, heading, 0.0, 0.05, session.top - session.origin.z + 0.30)
        local scalePos = Interaction3D.Offset(session.origin, heading, -0.48, 0.05, session.top - session.origin.z + 0.03)
        session.scale = Interaction3D.Spawn(world, { 'bkr_prop_coke_scale_01' }, scalePos, heading, {})
    else
        local corkPos = Interaction3D.Offset(session.origin, heading, 0.45, 0.25, session.top - session.origin.z + 0.12)
        session.cork = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, corkPos, heading + 180.0, {})
        if not session.cork then return false, 'cork_spawn_failed' end
        local scalePos = Interaction3D.Offset(session.origin, heading, -0.45, 0.05, session.top - session.origin.z + 0.03)
        session.scale = Interaction3D.Spawn(world, { 'bkr_prop_coke_scale_01' }, scalePos, heading, {})
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
    if session.stage == 'heat' then
        local dt = GetFrameTime()
        if IsDisabledControlPressed(0, 38) then
            session.hold = clamp((session.hold or 0) + dt / 2.0, 0.0, 1.0)
        else
            session.hold = clamp((session.hold or 0) - dt * 0.28, 0.0, 1.0)
        end
        Interaction3D.Select(session.world, session.cooker)
        updateHud(session, 'Laikyk E ir kaitink katilą.', { progress = session.hold })
        if session.hold >= 1.0 then
            session.score = session.score + 15
            nextStage(session, 'heat', function()
                session.hold = 0.55
                session.gaugeStarted = GetGameTimer()
                updateHud(session, 'Laikyk temperatūrą A/D pagal rodyklę.')
            end)
        end
    elseif session.stage == 'hold' then
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
            session.score = session.score + 20
            nextStage(session, 'hold', function()
                session.mixCount, session.lastMix = 0, nil
                updateHud(session, 'Distiliuok ritmiškai: A ↔ D.')
            end)
        end
    elseif session.stage == 'distill' then
        local pressed
        if IsDisabledControlJustPressed(0, 34) then pressed = 'left' end
        if IsDisabledControlJustPressed(0, 35) then pressed = 'right' end
        if pressed then
            if session.lastMix and session.lastMix == pressed then
                session.mistakes = session.mistakes + 1
                session.score = math.max(0, session.score - 3)
            else
                session.mixCount = (session.mixCount or 0) + 1
                session.score = session.score + 3
                session.lastMix = pressed
            end
        end
        updateHud(session, 'Distiliacija: A ↔ D.', { progress = (session.mixCount or 0) / 8 })
        if (session.mixCount or 0) >= 8 then
            nextStage(session, 'distill', function()
                updateHud(session, 'Nukreipk kamerą į buteliuką ir spausk E.')
            end)
        end
    elseif session.stage == 'collect' then
        if not session.collecting then
            selectEntity(session, session.bottle, 'paimti indą', function()
                session.collecting = true
                session.score = session.score + 10
                updateHud(session, 'E · perkelti indą prie distiliatoriaus.')
            end)
        else
            Interaction3D.DrawSnaps({ { coords = session.collectPoint, radius = 0.25 } })
            Interaction3D.Select(session.world, session.bottle)
            updateHud(session, 'E · sklandžiai perkelti prie snap taško.')
            if IsDisabledControlJustPressed(0, 38) then
                Interaction3D.Select(session.world, nil)
                session.pending = true
                Interaction3D.MoveSmooth(session.bottle, session.collectPoint, 650, function()
                    return active == session
                end, function()
                    session.pending = false
                    session.score = session.score + 15
                    nextStage(session, 'collect', function()
                        session.gaugeStarted = GetGameTimer()
                        updateHud(session, 'Spausk E, kai aušinimas žalioje zonoje.')
                    end)
                end)
            end
        end
    elseif session.stage == 'cool' then
        local gauge = (math.sin((GetGameTimer() - session.gaugeStarted) / 340.0) + 1.0) * 0.5
        updateHud(session, 'E · atvėsinti ties 60–76%.', { gauge = gauge })
        if IsDisabledControlJustPressed(0, 38) then
            if gauge >= 0.60 and gauge <= 0.76 then
                session.score = session.score + 30
            else
                session.score = session.score + 8
                session.mistakes = session.mistakes + 1
            end
            reportStage(session, 'cool', function()
                finish(session, true, 'completed')
            end)
        end
    end
end

local function updatePack(session)
    if session.stage == 'bottle' then
        selectEntity(session, session.bottle, 'pasirinkti stiklainį', function()
            session.score = session.score + 15
            nextStage(session, 'bottle', function()
                session.hold = 0
                updateHud(session, 'Laikyk E ir pilk samagoną.')
            end)
        end)
    elseif session.stage == 'pour' then
        local dt = GetFrameTime()
        if IsDisabledControlPressed(0, 38) then
            session.hold = clamp((session.hold or 0) + dt / 2.5, 0.0, 1.15)
        end
        updateHud(session, 'Atleisk E ties 95–100%.', { progress = math.min(session.hold, 1.0) })
        if session.hold >= 0.95 and not IsDisabledControlPressed(0, 38) then
            if session.hold <= 1.02 then
                session.score = session.score + 25
            else
                session.score = session.score + 8
                session.mistakes = session.mistakes + 1
            end
            nextStage(session, 'pour', function()
                updateHud(session, 'Nukreipk kamerą į kamštį ir spausk E.')
            end)
        elseif session.hold >= 1.15 then
            session.score = session.score + 4
            session.mistakes = session.mistakes + 1
            nextStage(session, 'pour')
        end
    elseif session.stage == 'cork' then
        selectEntity(session, session.cork, 'užkimšti stiklainį', function()
            session.score = session.score + 20
            nextStage(session, 'cork', function()
                session.gaugeStarted = GetGameTimer()
                updateHud(session, 'Spausk E žalioje sandarinimo zonoje.')
            end)
        end)
    elseif session.stage == 'seal' then
        local gauge = (math.sin((GetGameTimer() - session.gaugeStarted) / 300.0) + 1.0) * 0.5
        updateHud(session, 'E · sandarinti ties 68–84%.', { gauge = gauge })
        if IsDisabledControlJustPressed(0, 38) then
            if gauge >= 0.68 and gauge <= 0.84 then
                session.score = session.score + 25
            else
                session.score = session.score + 6
                session.mistakes = session.mistakes + 1
            end
            nextStage(session, 'seal', function()
                updateHud(session, 'E · galutinė kokybės patikra.')
            end)
        end
    elseif session.stage == 'finalize' then
        Interaction3D.Select(session.world, session.bottle)
        updateHud(session, 'E · patvirtinti paruoštą stiklainį.')
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

function AlcoholProduction.Start(payload, onDone)
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
    if payload.mode == 'alcohol_pack' or tostring(payload.productId or ''):find('_pack$') then
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
        stage = mode == 'pack' and 'bottle' or 'prepare',
        origin = origin,
        heading = heading,
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
        title = mode == 'pack' and 'Samagonas · pakavimas' or 'Samagonas · distiliacija',
        stage = ('1/%d'):format(#session.steps),
        stageName = LABELS[session.stage],
        hint = 'ESC · atšaukti',
        kicker = '3D ALCOHOL WORKSTATION',
    })

    if mode == 'process' then
        reportStage(session, 'prepare', function()
            session.score = session.score + 10
            session.step, session.stage = 2, 'heat'
            session.hold = 0
            updateHud(session, 'Laikyk E ir kaitink katilą.')
        end)
    else
        updateHud(session, 'Nukreipk kamerą į stiklainį ir spausk E.')
    end
    run(session)
    return true
end

function AlcoholProduction.Close(reason)
    local session = active
    if not session then return false end
    session.finished = true
    session.onDone = nil
    active = nil
    cleanup(session)
    return true
end

function AlcoholProduction.IsActive()
    return active ~= nil
end

exports('StartAlcoholProduction', function(payload, onDone)
    return AlcoholProduction.Start(payload, onDone)
end)

exports('CloseAlcoholProduction', function(reason)
    return AlcoholProduction.Close(reason)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and active then
        AlcoholProduction.Close('resource_stop')
    end
end)

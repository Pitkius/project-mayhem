--- L1 alcohol production: aiškūs veiksmai + vizualus feedback (ugnis, judantys propai).
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

local function stopFire(session)
    if session.fireFx then
        StopParticleFxLooped(session.fireFx, false)
        session.fireFx = nil
    end
    if session.steamFx then
        StopParticleFxLooped(session.steamFx, false)
        session.steamFx = nil
    end
end

local function ensurePtfx()
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local t = GetGameTimer() + 3000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(10) end
    end
    return HasNamedPtfxAssetLoaded('core')
end

local function updateFire(session, intensity)
    intensity = clamp(intensity or 0.0, 0.0, 1.5)
    local cooker = session.cooker
    if not cooker or not DoesEntityExist(cooker) then return end
    if intensity < 0.05 then
        stopFire(session)
        return
    end
    if not ensurePtfx() then return end
    if not session.fireFx then
        UseParticleFxAssetNextCall('core')
        session.fireFx = StartParticleFxLoopedOnEntity(
            'ent_amb_torch_fire', cooker,
            0.0, 0.0, 0.22,
            0.0, 0.0, 0.0,
            0.35, false, false, false
        )
    end
    if session.fireFx then
        SetParticleFxLoopedScale(session.fireFx, 0.25 + intensity * 0.9)
        SetParticleFxLoopedAlpha(session.fireFx, clamp(0.4 + intensity * 0.6, 0.0, 1.0))
    end
    if intensity > 0.55 and not session.steamFx then
        UseParticleFxAssetNextCall('core')
        session.steamFx = StartParticleFxLoopedOnEntity(
            'ent_amb_steam', cooker,
            0.0, 0.05, 0.55,
            0.0, 0.0, 0.0,
            0.8, false, false, false
        )
    elseif intensity <= 0.45 and session.steamFx then
        StopParticleFxLooped(session.steamFx, false)
        session.steamFx = nil
    end
end

local function cleanup(session)
    if not session or session.cleaned then return end
    session.cleaned = true
    stopFire(session)
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
    local workspace = session.workspace

    local anchorModels = session.mode == 'pack'
        and { 'bkr_prop_weed_table_01a', 'prop_tool_bench02', 'bkr_prop_meth_table01a' }
        or { 'prop_cooker_03', 'bkr_prop_meth_table01a', 'prop_tool_bench02', 'bkr_prop_weed_table_01a' }

    local existing = Interaction3D.ResolveExisting(workspace, anchorModels, origin, 5.0)
    if existing and DoesEntityExist(existing) then
        session.anchor = existing
        session.origin = GetEntityCoords(existing)
        session.heading = GetEntityHeading(existing)
        heading = session.heading
        origin = session.origin
        if session.mode == 'process' then
            session.cooker = existing
            session.table = nil
        else
            session.table = existing
        end
    else
        local table = Interaction3D.Spawn(world,
            session.mode == 'pack' and { 'prop_tool_bench02', 'bkr_prop_weed_table_01a' }
                or { 'bkr_prop_meth_table01a', 'prop_tool_bench02', 'bkr_prop_weed_table_01a' },
            origin, heading, { ground = true })
        if not table then return false, 'table_spawn_failed' end
        session.table = table
        session.origin = GetEntityCoords(table)
        session.heading = GetEntityHeading(table)
        heading = session.heading
        origin = session.origin
    end

    session.top = Interaction3D.SurfaceTop(session.cooker or session.table or session.anchor, origin.z)
    session.lookAt = vector3(origin.x, origin.y, session.top + 0.05)

    local back = Interaction3D.Offset(origin, heading, 0.0, -2.30, 1.55)
    if not Interaction3D.CreateCamera(world, back, session.lookAt, 43.0) then
        return false, 'camera_failed'
    end
    world.lookAt = session.lookAt
    world.camDistance = 2.85

    local bottlePos = Interaction3D.Offset(origin, heading, 0.52, -0.15, session.top - origin.z + 0.12)
    --- collision=true kad marker/outline būtų matomi; judėjimas vistiek be fizikos
    session.bottle = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, bottlePos, heading, { collision = true })
    if not session.bottle then return false, 'bottle_spawn_failed' end
    SetEntityCollision(session.bottle, false, false)
    session.bottleBaseHeading = heading
    session.bottleHome = bottlePos

    if session.mode == 'process' then
        if not session.cooker then
            local cookerPos = Interaction3D.Offset(origin, heading, 0.0, 0.22, session.top - origin.z + 0.04)
            session.cooker = Interaction3D.Spawn(world, { 'prop_cooker_03' }, cookerPos, heading, { collision = false })
            if not session.cooker then return false, 'cooker_spawn_failed' end
        end
        session.collectPoint = Interaction3D.Offset(origin, heading, 0.0, 0.05, session.top - origin.z + 0.35)
        local scalePos = Interaction3D.Offset(origin, heading, -0.48, 0.05, session.top - origin.z + 0.03)
        session.scale = Interaction3D.Spawn(world, { 'bkr_prop_coke_scale_01' }, scalePos, heading, { collision = false })
    else
        local corkPos = Interaction3D.Offset(origin, heading, 0.45, 0.25, session.top - origin.z + 0.12)
        session.cork = Interaction3D.Spawn(world, { 'prop_cs_script_bottle' }, corkPos, heading + 180.0, { collision = true })
        if not session.cork then return false, 'cork_spawn_failed' end
        SetEntityCollision(session.cork, false, false)
        session.corkHome = corkPos
        local scalePos = Interaction3D.Offset(origin, heading, -0.45, 0.05, session.top - origin.z + 0.03)
        session.scale = Interaction3D.Spawn(world, { 'bkr_prop_coke_scale_01' }, scalePos, heading, { collision = false })
    end
    return true
end

--- Pažymėtas objektas + E (be fragile raycast — propai dažnai be collision).
local function promptTarget(session, target, hintReady, onSelected)
    if not target or not DoesEntityExist(target) then return end
    Interaction3D.Select(session.world, target)
    Interaction3D.DrawTargetMarker(target, 34, 211, 238)
    local looking = Interaction3D.IsLookingAt(session.world, target, 0.55)
    --- Net jei nežiūri tiksliai — po 1.2s leidžiam E (kad neužstrigtų)
    session._targetSince = session._targetSince or GetGameTimer()
    local allow = looking or (GetGameTimer() - session._targetSince) > 1200
    if allow then
        updateHud(session, ('[E] %s'):format(hintReady))
        if IsDisabledControlJustPressed(0, 38) then
            session._targetSince = nil
            Interaction3D.Select(session.world, nil)
            onSelected()
        end
    else
        updateHud(session, 'Pelė · nukreipk kamerą į žalią objektą su rodykle ↑')
    end
end

local function setBottleTilt(session, amount)
    local bottle = session.bottle
    if not bottle or not DoesEntityExist(bottle) then return end
    local h = session.bottleBaseHeading or GetEntityHeading(bottle)
    SetEntityRotation(bottle, -55.0 * clamp(amount, 0.0, 1.0), 0.0, h, 2, true)
end

local function updateProcess(session)
    if session.stage == 'heat' then
        local dt = GetFrameTime()
        if IsDisabledControlPressed(0, 38) then
            session.hold = clamp((session.hold or 0) + dt / 1.8, 0.0, 1.0)
        else
            session.hold = clamp((session.hold or 0) - dt * 0.22, 0.0, 1.0)
        end
        Interaction3D.Select(session.world, session.cooker)
        Interaction3D.DrawTargetMarker(session.cooker, 255, 120, 40)
        updateFire(session, session.hold)
        updateHud(session, 'Laikyk [E] — ugnis auga, kol užpildysi juostą.', { progress = session.hold or 0 })
        if (session.hold or 0) >= 1.0 then
            session.score = session.score + 15
            nextStage(session, 'heat', function()
                session.hold = 0.55
                session.gaugeStarted = GetGameTimer()
                session.holdGood = 0
                updateHud(session, 'A / D · laikyk temperatūrą žalioje zonoje.')
            end)
        end
    elseif session.stage == 'hold' then
        local dt = GetFrameTime()
        local target = 0.5 + 0.22 * math.sin((GetGameTimer() - (session.gaugeStarted or GetGameTimer())) / 900.0)
        if IsDisabledControlPressed(0, 34) then
            session.hold = clamp((session.hold or 0.5) - dt * 0.4, 0.0, 1.0)
        elseif IsDisabledControlPressed(0, 35) then
            session.hold = clamp((session.hold or 0.5) + dt * 0.4, 0.0, 1.0)
        end
        local error = math.abs((session.hold or 0.5) - target)
        session.holdGood = clamp((session.holdGood or 0) + (error <= 0.14 and dt or -dt * 0.4), 0.0, 2.0)
        updateFire(session, 0.55 + (session.hold or 0.5) * 0.5)
        Interaction3D.Select(session.world, session.cooker)
        updateHud(session, 'A = mažiau · D = daugiau · laikyk juostą žalioje.', {
            progress = session.holdGood / 2.0,
            gauge = session.hold,
        })
        if session.holdGood >= 2.0 then
            session.score = session.score + 20
            nextStage(session, 'hold', function()
                session.mixCount, session.lastMix = 0, nil
                updateHud(session, 'Pakaitomis spausk A ir D (8 kartus).')
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
                --- Trumpas „burbuliavimas“ — butelis suvirpa
                if session.bottle and DoesEntityExist(session.bottle) then
                    local c = GetEntityCoords(session.bottle)
                    SetEntityCoordsNoOffset(session.bottle, c.x, c.y, c.z + 0.02, false, false, false)
                end
            end
        end
        updateFire(session, 0.85 + ((session.mixCount or 0) / 8) * 0.4)
        Interaction3D.Select(session.world, session.cooker)
        updateHud(session, ('Distiliacija: A ↔ D  ·  %d/8'):format(session.mixCount or 0), {
            progress = (session.mixCount or 0) / 8,
        })
        if (session.mixCount or 0) >= 8 then
            nextStage(session, 'distill', function()
                session._targetSince = GetGameTimer()
                session.collecting = false
                updateHud(session, 'Pasirink buteliuką — [E].')
            end)
        end
    elseif session.stage == 'collect' then
        updateFire(session, 0.7)
        if not session.collecting then
            promptTarget(session, session.bottle, 'paimti indą', function()
                session.collecting = true
                session.score = session.score + 10
                updateHud(session, '[E] perkelti indą prie distiliatoriaus (žalias taškas).')
            end)
        else
            Interaction3D.DrawSnaps({ { coords = session.collectPoint, radius = 0.28 } })
            Interaction3D.Select(session.world, session.bottle)
            Interaction3D.DrawTargetMarker(session.bottle, 34, 211, 238)
            updateHud(session, '[E] perkelti buteliuką į žalią tašką')
            if IsDisabledControlJustPressed(0, 38) then
                Interaction3D.Select(session.world, nil)
                session.pending = true
                Interaction3D.MoveSmooth(session.bottle, session.collectPoint, 700, function()
                    return active == session
                end, function()
                    session.pending = false
                    session.score = session.score + 15
                    nextStage(session, 'collect', function()
                        session.gaugeStarted = GetGameTimer()
                        updateHud(session, '[E] kai rodyklė žalioje zonoje (60–76%).')
                    end)
                end)
            end
        end
    elseif session.stage == 'cool' then
        local gauge = (math.sin((GetGameTimer() - (session.gaugeStarted or GetGameTimer())) / 340.0) + 1.0) * 0.5
        updateFire(session, 0.25 + (1.0 - gauge) * 0.3)
        updateHud(session, '[E] atvėsinti kai juosta žalioje zonoje (60–76%).', { gauge = gauge })
        if IsDisabledControlJustPressed(0, 38) then
            if gauge >= 0.60 and gauge <= 0.76 then
                session.score = session.score + 30
            else
                session.score = session.score + 8
                session.mistakes = session.mistakes + 1
            end
            stopFire(session)
            reportStage(session, 'cool', function()
                finish(session, true, 'completed')
            end)
        end
    end
end

local function updatePack(session)
    if session.stage == 'bottle' then
        promptTarget(session, session.bottle, 'pasirinkti stiklainį', function()
            session.score = session.score + 15
            nextStage(session, 'bottle', function()
                session.hold = 0
                updateHud(session, 'Laikyk [E] — butelis pasvirs, juosta augs. Atleisk ties 95–100%.')
            end)
        end)
    elseif session.stage == 'pour' then
        local dt = GetFrameTime()
        Interaction3D.Select(session.world, session.bottle)
        Interaction3D.DrawTargetMarker(session.bottle, 34, 211, 238)
        if IsDisabledControlPressed(0, 38) then
            session.hold = clamp((session.hold or 0) + dt / 2.2, 0.0, 1.15)
        end
        setBottleTilt(session, math.min(session.hold or 0, 1.0))
        updateHud(session, 'Laikyk [E] pildymui · atleisk ties 95–100%.', {
            progress = math.min(session.hold or 0, 1.0),
        })
        if (session.hold or 0) >= 0.95 and not IsDisabledControlPressed(0, 38) then
            if session.hold <= 1.02 then
                session.score = session.score + 25
            else
                session.score = session.score + 8
                session.mistakes = session.mistakes + 1
            end
            setBottleTilt(session, 0)
            session._targetSince = GetGameTimer()
            nextStage(session, 'pour', function()
                updateHud(session, 'Pasirink kamštį (antras butelis) — [E].')
            end)
        elseif (session.hold or 0) >= 1.15 then
            session.score = session.score + 4
            session.mistakes = session.mistakes + 1
            setBottleTilt(session, 0)
            session._targetSince = GetGameTimer()
            nextStage(session, 'pour')
        end
    elseif session.stage == 'cork' then
        promptTarget(session, session.cork, 'užkimšti stiklainį', function()
            session.score = session.score + 20
            session.pending = true
            local target = GetEntityCoords(session.bottle)
            target = vector3(target.x, target.y, target.z + 0.12)
            Interaction3D.MoveSmooth(session.cork, target, 550, function()
                return active == session
            end, function()
                session.pending = false
                nextStage(session, 'cork', function()
                    session.gaugeStarted = GetGameTimer()
                    updateHud(session, '[E] sandarinti kai juosta žalioje (68–84%).')
                end)
            end)
        end)
    elseif session.stage == 'seal' then
        local gauge = (math.sin((GetGameTimer() - (session.gaugeStarted or GetGameTimer())) / 300.0) + 1.0) * 0.5
        Interaction3D.Select(session.world, session.bottle)
        updateHud(session, '[E] sandarinti žalioje zonoje (68–84%).', { gauge = gauge })
        if IsDisabledControlJustPressed(0, 38) then
            if gauge >= 0.68 and gauge <= 0.84 then
                session.score = session.score + 25
            else
                session.score = session.score + 6
                session.mistakes = session.mistakes + 1
            end
            nextStage(session, 'seal', function()
                updateHud(session, '[E] patvirtinti paruoštą stiklainį.')
            end)
        end
    elseif session.stage == 'finalize' then
        Interaction3D.Select(session.world, session.bottle)
        Interaction3D.DrawTargetMarker(session.bottle, 74, 222, 128)
        updateHud(session, '[E] baigti pakavimą')
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
        title = mode == 'pack' and 'Samagonas · pakavimas' or 'Samagonas · distiliacija',
        stage = ('1/%d'):format(#session.steps),
        stageName = LABELS[session.stage],
        hint = 'Pelė = kamera · E = veiksmas · A/D = temperatūra · ESC = atšaukti',
        kicker = '3D ALCOHOL WORKSTATION',
    })

    if mode == 'process' then
        reportStage(session, 'prepare', function()
            session.score = session.score + 10
            session.step, session.stage = 2, 'heat'
            session.hold = 0
            updateHud(session, 'Laikyk [E] ant katilo — ugnis turi augti.')
        end)
    else
        session._targetSince = GetGameTimer()
        updateHud(session, 'Žalias objektas = stiklainis. Spausk [E].')
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

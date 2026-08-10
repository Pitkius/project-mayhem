--- Metamfetamino 3D gamyba — stovima grandinė (pilimas → kaitinimas → kristalai → rinkimas / smulkinimas → svėrimas → maišeliai).
--- NE kopija žolės kameros/stalo pakavimo — unikalūs propai, animacijos ir įvestis.

MethProduction = MethProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local PROPS = {
    flask = { 'bkr_prop_meth_sacid', 'prop_cs_script_bottle_01' },
    bottle = { 'prop_cs_script_bottle', 'prop_ld_flow_bottle' },
    tray = { 'bkr_prop_meth_tray_01b', 'bkr_prop_meth_tray_02a', 'prop_cs_tray_01' },
    crystal = { 'bkr_prop_meth_smallbag_01a', 'prop_meth_bag_01' },
    hammer = { 'prop_tool_hammer', 'prop_tool_mallet' },
    bag = { 'prop_meth_bag_01', 'bkr_prop_meth_bag_01a' },
    scale = { 'bkr_prop_coke_scale_01', 'prop_scales_ped_01' },
}

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadModel(candidates)
    for _, name in ipairs(candidates or {}) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) and IsModelValid(hash) then
            RequestModel(hash)
            local deadline = GetGameTimer() + 4000
            while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
            if HasModelLoaded(hash) then return hash end
        end
    end
    return nil
end

local function loadDict(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function playAnim(dict, clip, flag)
    local ped = PlayerPedId()
    if loadDict(dict) then
        TaskPlayAnim(ped, dict, clip, 4.0, -4.0, -1, flag or 49, 0, false, false, false)
    end
end

local function stopAnim()
    ClearPedTasks(PlayerPedId())
end

local function spawnObj(hash, coords, heading)
    local ent = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if not ent or ent == 0 then return nil end
    SetEntityHeading(ent, heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    return ent
end

local function attachProp(hash, bone, ox, oy, oz, rx, ry, rz)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local ent = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    if not ent or ent == 0 then return nil end
    AttachEntityToEntity(ent, ped, GetPedBoneIndex(ped, bone or 57005),
        ox or 0.12, oy or 0.02, oz or -0.02,
        rx or -90.0, ry or 0.0, rz or 0.0,
        true, true, false, true, 1, true)
    return ent
end

local function cleanup(session)
    if not session then return end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    for _, ent in ipairs(session.entities or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    stopAnim()
    FreezeEntityPosition(PlayerPedId(), false)
    SetNuiFocus(false, false)
end

local function finish(success, extra)
    local session = active
    if not session or session.finished then return end
    session.finished = true
    active = nil
    cleanup(session)
    if session.onDone then
        session.onDone(success == true, extra or {
            score = math.floor(session.score or 0),
            mistakes = session.mistakes or 0,
        })
    end
end

local function reportStage(session, stageName, onOk)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:worldProductionStage', function(res)
        if active ~= session or session.finished then return end
        if not res or not res.ok then
            finish(false, {
                score = math.floor(session.score or 0),
                mistakes = (session.mistakes or 0) + 1,
                reason = (res and res.reason) or 'stage_rejected',
            })
            notify((res and res.reason) or 'Etapas atmestas.', 'error')
            return
        end
        if onOk then onOk(res) end
    end, session.craftToken, stageName)
end

local function waitKey(control, ms)
    local deadline = GetGameTimer() + (ms or 15000)
    while GetGameTimer() < deadline do
        if IsControlJustPressed(0, control) then return true end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then return false end -- ESC
        Wait(0)
    end
    return false
end

local function drawHelp(lines)
    local y = 0.78
    for _, line in ipairs(lines or {}) do
        SetTextFont(4)
        SetTextScale(0.38, 0.38)
        SetTextColour(220, 235, 255, 230)
        SetTextCentre(true)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(0.5, y)
        y = y + 0.028
    end
end

local function setHelp(session, lines)
    session.helpLines = lines or {}
end

local function helpLoop(session)
    if session.helpStarted then return end
    session.helpStarted = true
    CreateThread(function()
        while active == session and not session.finished do
            drawHelp(session.helpLines)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Wait(0)
        end
    end)
end

local function originFromWorkspace(workspace)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    if workspace and workspace.x then
        return vector3(workspace.x + 0.0, workspace.y + 0.0, workspace.z + 0.0), tonumber(workspace.w) or heading
    end
    local rad = math.rad(heading)
    return coords + vector3(-math.sin(rad) * 1.2, math.cos(rad) * 1.2, 0.0), heading
end

--- Temperatūros laikymo skillas (ne NUI) — žalia zona juda.
local function runHeatSkill(session, durationMs)
    local needle = 0.35
    local vel = 0.55
    local greenCenter = 0.5
    local greenHalf = 0.12
    local hold = 0.0
    local need = 2.4
    local start = GetGameTimer()
    local deadline = start + (durationMs or 12000)
    playAnim('amb@world_human_stand_fire@male@idle_a', 'idle_a', 49)

    while active == session and not session.finished and GetGameTimer() < deadline do
        local dt = GetFrameTime()
        needle = needle + vel * dt
        if needle > 1.0 then needle = 1.0; vel = -math.abs(vel) end
        if needle < 0.0 then needle = 0.0; vel = math.abs(vel) end
        if IsControlPressed(0, 38) then -- E
            if math.abs(needle - greenCenter) <= greenHalf then
                hold = hold + dt
                vel = vel * 0.992
            else
                hold = math.max(0.0, hold - dt * 0.55)
                session.mistakes = (session.mistakes or 0) + 0
            end
        else
            hold = math.max(0.0, hold - dt * 0.35)
        end
        if math.random() < 0.01 then
            greenCenter = 0.28 + math.random() * 0.44
        end

        DrawRect(0.5, 0.86, 0.28, 0.028, 20, 20, 28, 180)
        DrawRect(0.5 - 0.14 + greenCenter * 0.28, 0.86, greenHalf * 2 * 0.28, 0.028, 40, 160, 70, 160)
        DrawRect(0.5 - 0.14 + needle * 0.28, 0.86, 0.008, 0.036, 255, 220, 80, 240)
        drawHelp({
            ('~b~Kaitinimas~s~ · laikyk ~INPUT_CONTEXT~ žalioje zonoje  (%.0f%%)'):format((hold / need) * 100),
            'ESC — atšaukti',
        })
        if hold >= need then
            stopAnim()
            return true
        end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
            stopAnim()
            return false
        end
        Wait(0)
    end
    stopAnim()
    return hold >= need * 0.85
end

local function stagePour(session)
    local bottleHash = loadModel(PROPS.bottle)
    local flaskHash = loadModel(PROPS.flask)
    if not bottleHash or not flaskHash then return false, 'prop_missing' end

    local flask = spawnObj(flaskHash, session.origin + vector3(0.15, 0.35, 0.05), session.heading)
    if flask then session.entities[#session.entities + 1] = flask end
    session.handProp = attachProp(bottleHash, 57005, 0.11, 0.03, -0.02, -80.0, 0.0, 20.0)
    SetModelAsNoLongerNeeded(bottleHash)
    SetModelAsNoLongerNeeded(flaskHash)

    local pours = 0
    helpLoop(session)
    setHelp(session, {
        '~y~Metas · pilimas~s~  0/4',
        'E — įpilti cheminį mišinį į kolbą · ESC — atšaukti',
    })

    playAnim('amb@prop_human_parking_meter@female@idle_a', 'idle_a_female', 49)
    while pours < 4 and active == session and not session.finished do
        if waitKey(38, 20000) then
            pours = pours + 1
            session.score = (session.score or 0) + 8
            setHelp(session, {
                ('~y~Metas · pilimas~s~  %d/4'):format(pours),
                'E — įpilti cheminį mišinį į kolbą · ESC — atšaukti',
            })
            playAnim('amb@prop_human_parking_meter@female@idle_a', 'idle_a_female', 49)
            Wait(700)
        else
            return false, 'cancelled'
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    local ok = false
    reportStage(session, 'poured', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageHeat(session)
    notify('Stebėk temperatūrą — laikyk E žalioje zonoje.', 'primary')
    local okSkill = runHeatSkill(session, 14000)
    if not okSkill then return false, 'heat_fail' end
    session.score = (session.score or 0) + 22
    local ok = false
    reportStage(session, 'heated', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageCrystalize(session)
    local trayHash = loadModel(PROPS.tray)
    local crystalHash = loadModel(PROPS.crystal)
    if not trayHash then return false, 'prop_missing' end
    local tray = spawnObj(trayHash, session.origin + vector3(-0.25, 0.4, 0.02), session.heading + 15.0)
    if tray then session.entities[#session.entities + 1] = tray end
    session.crystalTray = tray

    playAnim('anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 49)
    helpLoop(session)
    setHelp(session, { '~p~Kristalizacija~s~ · lauk, kol susiformuos kristalai', 'Nejudėk nuo stalo' })

    RequestNamedPtfxAsset('core')
    local crystals = {}
    local start = GetGameTimer()
    while GetGameTimer() - start < 7000 and active == session and not session.finished do
        local progress = (GetGameTimer() - start) / 7000
        if crystalHash and #crystals < math.floor(progress * 5) then
            local ox = (#crystals - 2) * 0.07
            local c = spawnObj(crystalHash, session.origin + vector3(-0.25 + ox, 0.38, 0.08), session.heading)
            if c then
                session.entities[#session.entities + 1] = c
                crystals[#crystals + 1] = c
            end
        end
        if HasNamedPtfxAssetLoaded('core') then
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('ent_amb_smoke_foundry',
                session.origin.x, session.origin.y, session.origin.z + 0.4,
                0.0, 0.0, 0.0, 0.25, false, false, false)
        end
        Wait(400)
    end
    session.crystals = crystals
    stopAnim()
    if crystalHash then SetModelAsNoLongerNeeded(crystalHash) end
    if trayHash then SetModelAsNoLongerNeeded(trayHash) end
    session.score = (session.score or 0) + 20
    local ok = false
    reportStage(session, 'crystallized', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageCollect(session)
    playAnim('anim@amb@business@weed@weed_sorting_seated@', 'sorter_right_sort_v3_weeddry01c', 49)
    helpLoop(session)
    setHelp(session, { '~g~Rinkimas~s~ · E — nuskinti kristalus nuo padėklo', 'ESC — atšaukti' })
    local picks = 0
    while picks < 3 and active == session and not session.finished do
        if waitKey(38, 18000) then
            picks = picks + 1
            session.score = (session.score or 0) + 10
            if session.crystals and session.crystals[picks] and DoesEntityExist(session.crystals[picks]) then
                DeleteEntity(session.crystals[picks])
            end
            Wait(550)
        else
            return false, 'cancelled'
        end
    end
    stopAnim()
    local ok = false
    reportStage(session, 'collected', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageSmash(session)
    local hammerHash = loadModel(PROPS.hammer)
    local trayHash = loadModel(PROPS.tray)
    if trayHash then
        local tray = spawnObj(trayHash, session.origin + vector3(0.0, 0.35, 0.02), session.heading)
        if tray then session.entities[#session.entities + 1] = tray end
        SetModelAsNoLongerNeeded(trayHash)
    end
    if hammerHash then
        session.handProp = attachProp(hammerHash, 57005, 0.08, 0.02, 0.0, -80.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(hammerHash)
    end
    helpLoop(session)
    setHelp(session, { '~r~Smulkinimas~s~ · E — daužyti kristalus (3×)', 'ESC — atšaukti' })
    local hits = 0
    while hits < 3 and active == session and not session.finished do
        if waitKey(38, 16000) then
            hits = hits + 1
            playAnim('melee@large_wpn@streamed_core', 'ground_attack_on_spot', 0)
            Wait(900)
            session.score = (session.score or 0) + 12
        else
            return false, 'cancelled'
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    local ok = false
    reportStage(session, 'smashed', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageWeigh(session)
    local scaleHash = loadModel(PROPS.scale)
    if scaleHash then
        local scale = spawnObj(scaleHash, session.origin + vector3(0.35, 0.25, 0.0), session.heading - 20.0)
        if scale then session.entities[#session.entities + 1] = scale end
        SetModelAsNoLongerNeeded(scaleHash)
    end
    helpLoop(session)
    setHelp(session, { '~b~Svėrimas~s~ · E — padėti miltelius ant svarstyklių' })
    if not waitKey(38, 20000) then return false, 'cancelled' end
    playAnim('anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 49)
    local endAt = GetGameTimer() + 3200
    while GetGameTimer() < endAt and active == session do
        drawHelp({ '~b~Sveriama…~s~' })
        Wait(0)
    end
    stopAnim()
    session.score = (session.score or 0) + 18
    local ok = false
    reportStage(session, 'weighed', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function stageBag(session)
    local bagHash = loadModel(PROPS.bag)
    if bagHash then
        session.handProp = attachProp(bagHash, 57005, 0.12, 0.0, -0.04, -70.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(bagHash)
    end
    helpLoop(session)
    setHelp(session, { '~g~Pakavimas~s~ · E — užpildyti maišelį (2×)', 'ESC — atšaukti' })
    local bags = 0
    while bags < 2 and active == session and not session.finished do
        if waitKey(38, 18000) then
            bags = bags + 1
            playAnim('mp_common', 'givetake1_a', 49)
            Wait(900)
            session.score = (session.score or 0) + 14
        else
            return false, 'cancelled'
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    local ok = false
    reportStage(session, 'bagged', function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok, ok and nil or 'stage_fail'
end

local function runProcess(session)
    local ok, err = stagePour(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    ok, err = stageHeat(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    ok, err = stageCrystalize(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    ok, err = stageCollect(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local function runPack(session)
    local ok, err = stageSmash(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    ok, err = stageWeigh(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    ok, err = stageBag(session)
    if not ok then return finish(false, { reason = err, score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

function MethProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { reason = 'missing_craft_token' }) end
        return false
    end
    local mode = (payload.mode == 'meth_crush_pack' or payload.productId == 'meth_pack') and 'pack' or 'process'
    local origin, heading = originFromWorkspace(payload.workspace)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, origin.x, origin.y, origin.z, 500)
    Wait(500)

    local session = {
        craftToken = payload.craftToken,
        mode = mode,
        onDone = onDone,
        origin = origin,
        heading = heading,
        entities = {},
        score = 0,
        mistakes = 0,
        finished = false,
    }
    active = session
    FreezeEntityPosition(ped, true)
    SetNuiFocus(false, false)
    notify(mode == 'pack' and 'Metas · smulkinimas ir pakavimas' or 'Metas · kristalizacija', 'primary')

    CreateThread(function()
        if mode == 'pack' then runPack(session) else runProcess(session) end
    end)
    return true
end

function MethProduction.Close(reason)
    if not active then return end
    finish(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function MethProduction.IsActive()
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
        cleanup(session)
    end
end)

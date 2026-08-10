--- Grybų 3D process + pack (be schedule CSS/NUI).
--- Process: clean → sort → dry → tray | Pack: fill → seal → label

MushroomProduction = MushroomProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local PROPS = {
    brush = { 'prop_cs_scissors', 'prop_cs_credit_card', 'prop_tool_screwdvr01' },
    tray = { 'prop_cs_tray', 'bkr_prop_meth_tray_01b', 'prop_bar_beans' },
    jar = { 'prop_cs_script_bottle', 'prop_bottle_brandy', 'v_res_mbbin' },
    bag = { 'prop_paper_bag_small', 'prop_meth_bag_01' },
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
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function playAnim(dict, clip, flag)
    if loadDict(dict) then
        TaskPlayAnim(PlayerPedId(), dict, clip, 4.0, -4.0, -1, flag or 49, 0, false, false, false)
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
    local c = GetEntityCoords(ped)
    local ent = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    if not ent or ent == 0 then return nil end
    AttachEntityToEntity(ent, ped, GetPedBoneIndex(ped, bone or 57005),
        ox or 0.1, oy or 0.0, oz or 0.0, rx or 0.0, ry or 0.0, rz or 0.0,
        true, true, false, true, 1, true)
    return ent
end

local function cleanup(session)
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    for _, ent in ipairs(session.entities or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    session.entities = {}
    stopAnim()
    FreezeEntityPosition(PlayerPedId(), false)
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
        if onOk then onOk() end
    end, session.craftToken, stageName)
end

local function waitReport(session, stageName)
    local ok = false
    reportStage(session, stageName, function() ok = true end)
    local t = GetGameTimer() + 5000
    while not ok and active == session and GetGameTimer() < t do Wait(50) end
    return ok
end

local function waitKey(control, ms)
    local deadline = GetGameTimer() + (ms or 15000)
    while GetGameTimer() < deadline do
        if IsControlJustPressed(0, control) then return true end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then return false end
        Wait(0)
    end
    return false
end

local function drawHelp(lines)
    local y = 0.76
    for _, line in ipairs(lines or {}) do
        SetTextFont(4)
        SetTextScale(0.38, 0.38)
        SetTextColour(230, 210, 255, 230)
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
    return coords + vector3(-math.sin(rad) * 1.1, math.cos(rad) * 1.1, 0.0), heading
end

local function pressCount(session, times, helpFmt, animDict, animClip, waitMs, scoreEach)
    helpLoop(session)
    local n = 0
    while n < times and active == session do
        setHelp(session, { (helpFmt):format(n, times) })
        if waitKey(38, 16000) then
            n = n + 1
            playAnim(animDict or 'mp_common', animClip or 'givetake1_a', 49)
            Wait(waitMs or 700)
            session.score = (session.score or 0) + (scoreEach or 10)
        else
            return false
        end
    end
    stopAnim()
    return true
end

local function stageClean(session)
    local brushHash = loadModel(PROPS.brush)
    if brushHash then
        session.handProp = attachProp(brushHash, 57005, 0.1, 0.02, -0.02, -80.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(brushHash)
    end
    local ok = pressCount(session, 5, '~o~Valymas~s~ · E — šepetėliu valyti (%d/%d)',
        'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 500, 8)
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not ok then return false end
    return waitReport(session, 'cleaned')
end

local function stageSort(session)
    local trayHash = loadModel(PROPS.tray)
    if trayHash then
        local e = spawnObj(trayHash, session.origin + vector3(0.0, 0.35, 0.0), session.heading)
        if e then session.entities[#session.entities + 1] = e end
        SetModelAsNoLongerNeeded(trayHash)
    end
    if not pressCount(session, 4, '~y~Rūšiavimas~s~ · E — atrinkti gerus (%d/%d)',
        'mp_common', 'givetake1_a', 600, 9) then
        return false
    end
    return waitReport(session, 'sorted')
end

local function stageDry(session)
    helpLoop(session)
    setHelp(session, { '~p~Džiovinimas~s~ · laikyk E 3 s prie padėklo' })
    local held = 0.0
    local need = 3.0
    local deadline = GetGameTimer() + 16000
    playAnim('amb@world_human_gardener_plant@male@base', 'base', 49)
    while active == session and GetGameTimer() < deadline do
        if IsControlPressed(0, 38) then
            held = held + GetFrameTime()
        else
            held = math.max(0.0, held - GetFrameTime() * 0.4)
        end
        DrawRect(0.5, 0.87, 0.22, 0.022, 25, 15, 30, 180)
        DrawRect(0.5 - 0.11 + (held / need) * 0.11, 0.87, math.min(0.22, (held / need) * 0.22), 0.022, 160, 100, 220, 220)
        setHelp(session, {
            ('~p~Džiovinimas~s~ · %.0f%%'):format(math.min(100, (held / need) * 100)),
            'ESC — atšaukti',
        })
        if held >= need then
            stopAnim()
            session.score = (session.score or 0) + 16
            return waitReport(session, 'dried')
        end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
            stopAnim()
            return false
        end
        Wait(0)
    end
    stopAnim()
    if held >= need * 0.8 then
        session.score = (session.score or 0) + 12
        return waitReport(session, 'dried')
    end
    return false
end

local function stageTray(session)
    if not pressCount(session, 2, '~g~Padėklas~s~ · E — sudėti džiovintus (%d/%d)',
        'mp_common', 'givetake1_a', 750, 12) then
        return false
    end
    return waitReport(session, 'trayed')
end

local function stageFill(session)
    local jarHash = loadModel(PROPS.jar)
    if jarHash then
        session.handProp = attachProp(jarHash, 57005, 0.12, 0.0, -0.04, -80.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(jarHash)
    end
    local ok = pressCount(session, 4, '~o~Pildymas~s~ · E — pildyti stiklainį (%d/%d)',
        'mp_common', 'givetake1_a', 650, 10)
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not ok then return false end
    return waitReport(session, 'filled')
end

local function stageSeal(session)
    if not pressCount(session, 3, '~y~Sandarinimas~s~ · E — užsukti dangtelį (%d/%d)',
        'mp_common', 'givetake1_a', 700, 11) then
        return false
    end
    return waitReport(session, 'sealed')
end

local function stageLabel(session)
    if not pressCount(session, 2, '~p~Etiketė~s~ · E — užklijuoti (%d/%d)',
        'mp_common', 'givetake1_a', 650, 12) then
        return false
    end
    return waitReport(session, 'labeled')
end

local function runProcess(session)
    if not stageClean(session) then return finish(false, { reason = 'clean', score = session.score, mistakes = 1 }) end
    if not stageSort(session) then return finish(false, { reason = 'sort', score = session.score, mistakes = 1 }) end
    if not stageDry(session) then return finish(false, { reason = 'dry', score = session.score, mistakes = 1 }) end
    if not stageTray(session) then return finish(false, { reason = 'tray', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local function runPack(session)
    if not stageFill(session) then return finish(false, { reason = 'fill', score = session.score, mistakes = 1 }) end
    if not stageSeal(session) then return finish(false, { reason = 'seal', score = session.score, mistakes = 1 }) end
    if not stageLabel(session) then return finish(false, { reason = 'label', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

function MushroomProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { reason = 'missing_craft_token' }) end
        return false
    end

    local mode = 'process'
    local pid = tostring(payload.productId or '')
    local pmode = tostring(payload.mode or '')
    if pid == 'mushroom_pack' or pmode == 'mushroom_jar' or payload.action == 'pack' then
        mode = 'pack'
    end

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
    notify(mode == 'pack' and 'Grybai · stiklainių pakavimas' or 'Grybai · valymas ir džiovinimas', 'primary')
    CreateThread(function()
        if mode == 'pack' then runPack(session) else runProcess(session) end
    end)
    return true
end

function MushroomProduction.Close(reason)
    if not active then return end
    finish(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function MushroomProduction.IsActive()
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

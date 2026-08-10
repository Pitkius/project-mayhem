--- Kokaino 3D gamyba — statinė / trypimas / nusausinimas / grandymas → presas / vyniojimas / antspaudas.
--- Skiriasi nuo meto (kaitinimas/kristalai) ir žolės (kamera/stalas).

CocaineProduction = CocaineProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local PROPS = {
    barrel = { 'prop_barrel_02a', 'prop_barrel_01a', 'prop_wooden_barrel' },
    leaves = { 'bkr_prop_weed_leaf_01a', 'prop_cs_leaf' },
    stick = { 'prop_cs_mopbucket_01', 'prop_tool_broom' },
    tray = { 'bkr_prop_coke_bakingsoda_o', 'bkr_prop_coke_metalbowl_01', 'prop_cs_tray_01' },
    paste = { 'bkr_prop_coke_powder_01', 'bkr_prop_coke_doll' },
    mold = { 'bkr_prop_coke_block_01a', 'bkr_prop_coke_press_01aa' },
    brick = { 'bkr_prop_coke_block_01a', 'prop_coke_block_half_a' },
    tape = { 'prop_cs_roll_mat', 'prop_cs_cardbox_01' },
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
    local ent = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    if not ent or ent == 0 then return nil end
    AttachEntityToEntity(ent, ped, GetPedBoneIndex(ped, bone or 57005),
        ox or 0.1, oy or 0.0, oz or 0.0, rx or 0.0, ry or 0.0, rz or 0.0,
        true, true, false, true, 1, true)
    return ent
end

local function cleanup(session)
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    for _, ent in ipairs(session.entities or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
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
        SetTextColour(255, 250, 240, 230)
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
    return coords + vector3(-math.sin(rad) * 1.15, math.cos(rad) * 1.15, 0.0), heading
end

--- Ritminis trypimas — spausk E kai indikatorius centre (ne meto temperatūra).
local function runStompRhythm(session)
    local beat = 0.0
    local hits = 0
    local need = 5
    local window = 0.14
    playAnim('special_ped@mountain_dancer@monologue_1@monologue_1a', 'mtn_dnc_if_you_want_to', 1)
    -- fallback jei anim nėra
    if not HasAnimDictLoaded('special_ped@mountain_dancer@monologue_1@monologue_1a') then
        playAnim('amb@world_human_jog_standing@male@idle_a', 'idle_a', 1)
    end

    local deadline = GetGameTimer() + 16000
    while active == session and hits < need and GetGameTimer() < deadline do
        local t = GetGameTimer() / 1000.0
        beat = (math.sin(t * 4.2) + 1.0) * 0.5
        DrawRect(0.5, 0.88, 0.22, 0.02, 30, 20, 15, 180)
        DrawRect(0.5, 0.88, 0.03, 0.028, 80, 200, 90, 200)
        DrawRect(0.5 - 0.11 + beat * 0.22, 0.88, 0.012, 0.032, 255, 230, 120, 255)
        setHelp(session, {
            ('~o~Trypimas~s~ · spausk E ritmu  (%d/%d)'):format(hits, need),
            'ESC — atšaukti',
        })
        if IsControlJustPressed(0, 38) then
            if math.abs(beat - 0.5) <= window then
                hits = hits + 1
                session.score = (session.score or 0) + 10
            else
                session.mistakes = (session.mistakes or 0) + 1
                session.score = math.max(0, (session.score or 0) - 4)
            end
        end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
            stopAnim()
            return false
        end
        Wait(0)
    end
    stopAnim()
    return hits >= need
end

local function stageSoak(session)
    local barrelHash = loadModel(PROPS.barrel)
    local leafHash = loadModel(PROPS.leaves)
    if barrelHash then
        local barrel = spawnObj(barrelHash, session.origin + vector3(0.0, 0.55, -0.35), session.heading)
        if barrel then session.entities[#session.entities + 1] = barrel end
        session.barrel = barrel
        SetModelAsNoLongerNeeded(barrelHash)
    end
    if leafHash then
        session.handProp = attachProp(leafHash, 57005, 0.1, 0.02, -0.02, 0.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(leafHash)
    end
    helpLoop(session)
    setHelp(session, { '~g~Mirkymas~s~ · E — mesti lapus į statinaitę (4×)' })
    local n = 0
    while n < 4 and active == session do
        if waitKey(38, 18000) then
            n = n + 1
            playAnim('amb@world_human_gardener_plant@male@base', 'base', 49)
            Wait(800)
            session.score = (session.score or 0) + 8
            setHelp(session, { ('~g~Mirkymas~s~ · E — mesti lapus (%d/4)'):format(n) })
        else
            return false
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    return waitReport(session, 'soaked')
end

local function stageStomp(session)
    helpLoop(session)
    notify('Trypk statinaitėje — pataikyk į ritmą.', 'primary')
    if not runStompRhythm(session) then return false end
    return waitReport(session, 'stomped')
end

local function stageDrain(session)
    local trayHash = loadModel(PROPS.tray)
    if trayHash then
        for i = 1, 3 do
            local tray = spawnObj(trayHash, session.origin + vector3(-0.4 + (i - 1) * 0.28, 0.2, 0.0), session.heading)
            if tray then session.entities[#session.entities + 1] = tray end
        end
        SetModelAsNoLongerNeeded(trayHash)
    end
    helpLoop(session)
    setHelp(session, { '~b~Nusausinimas~s~ · E — pilti skystį ant padėklų (3×)' })
    playAnim('amb@world_human_bum_wash@male@high@base', 'base', 49)
    local n = 0
    while n < 3 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            session.score = (session.score or 0) + 10
            setHelp(session, { ('~b~Nusausinimas~s~ · padėklai %d/3'):format(n) })
            Wait(700)
        else
            return false
        end
    end
    stopAnim()
    return waitReport(session, 'drained')
end

local function stageScrape(session)
    helpLoop(session)
    setHelp(session, { '~y~Grandymas~s~ · E — nugrandyti pastą (3×)' })
    playAnim('amb@world_human_maid_clean@', 'base', 49)
    local n = 0
    while n < 3 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            session.score = (session.score or 0) + 12
            Wait(650)
        else
            return false
        end
    end
    stopAnim()
    return waitReport(session, 'scraped')
end

local function stagePress(session)
    local moldHash = loadModel(PROPS.mold)
    if moldHash then
        local mold = spawnObj(moldHash, session.origin + vector3(0.1, 0.4, 0.0), session.heading)
        if mold then session.entities[#session.entities + 1] = mold end
        SetModelAsNoLongerNeeded(moldHash)
    end
    helpLoop(session)
    setHelp(session, { '~o~Presavimas~s~ · laikyk E 3 sek. spausti formą' })
    local held = 0.0
    local need = 3.0
    while held < need and active == session do
        if IsControlPressed(0, 38) then
            held = held + GetFrameTime()
            playAnim('anim@amb@business@coc@coc_unpack_cut@', 'fullcut_cycle_cokepacker', 49)
        else
            held = math.max(0.0, held - GetFrameTime() * 0.4)
            stopAnim()
        end
        setHelp(session, { ('~o~Presavimas~s~ · %.0f%%'):format((held / need) * 100) })
        if IsControlJustPressed(0, 322) then return false end
        Wait(0)
    end
    stopAnim()
    session.score = (session.score or 0) + 22
    local brickHash = loadModel(PROPS.brick)
    if brickHash then
        local brick = spawnObj(brickHash, session.origin + vector3(0.1, 0.4, 0.12), session.heading)
        if brick then
            session.entities[#session.entities + 1] = brick
            session.brick = brick
        end
        SetModelAsNoLongerNeeded(brickHash)
    end
    return waitReport(session, 'pressed')
end

local function stageWrap(session)
    helpLoop(session)
    setHelp(session, { '~w~Vyniojimas~s~ · E — apvynioti bloką (3×)' })
    local n = 0
    while n < 3 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('mp_common', 'givetake1_a', 49)
            Wait(800)
            session.score = (session.score or 0) + 12
        else
            return false
        end
    end
    stopAnim()
    return waitReport(session, 'wrapped')
end

local function stageStamp(session)
    helpLoop(session)
    setHelp(session, { '~p~Antspaudas~s~ · E — uždėti kartelio ženklą' })
    if not waitKey(38, 20000) then return false end
    playAnim('anim@amb@business@coc@coc_packing_hi@', 'full_cycle_v1_pressoperator', 49)
    Wait(2200)
    stopAnim()
    session.score = (session.score or 0) + 18
    return waitReport(session, 'stamped')
end

local function runProcess(session)
    if not stageSoak(session) then return finish(false, { reason = 'soak', score = session.score, mistakes = 1 }) end
    if not stageStomp(session) then return finish(false, { reason = 'stomp', score = session.score, mistakes = 1 }) end
    if not stageDrain(session) then return finish(false, { reason = 'drain', score = session.score, mistakes = 1 }) end
    if not stageScrape(session) then return finish(false, { reason = 'scrape', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = session.mistakes or 0 })
end

local function runPack(session)
    if not stagePress(session) then return finish(false, { reason = 'press', score = session.score, mistakes = 1 }) end
    if not stageWrap(session) then return finish(false, { reason = 'wrap', score = session.score, mistakes = 1 }) end
    if not stageStamp(session) then return finish(false, { reason = 'stamp', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = session.mistakes or 0 })
end

function CocaineProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { reason = 'missing_craft_token' }) end
        return false
    end
    local mode = (payload.mode == 'cocaine_brick' or payload.productId == 'cocaine_pack') and 'pack' or 'process'
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
    notify(mode == 'pack' and 'Kokainas · bloko formavimas' or 'Kokainas · cheminis apdorojimas', 'primary')
    CreateThread(function()
        if mode == 'pack' then runPack(session) else runProcess(session) end
    end)
    return true
end

function CocaineProduction.Close(reason)
    if not active then return end
    finish(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function CocaineProduction.IsActive()
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

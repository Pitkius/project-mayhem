--- Heroino 3D gamyba — grūdimas / virimas / filtravimas / aušinimas → dozavimas / folijos lankstymas / sandarinimas.
--- Skiriasi nuo meto (kristalai) ir kokaino (statinė/trypimas).

HeroinProduction = HeroinProduction or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local PROPS = {
    mortar = { 'prop_bar_beans', 'prop_cs_bowl_01', 'v_res_pestle' },
    pestle = { 'prop_tool_mallet', 'prop_cs_wrench' },
    pot = { 'prop_kitch_pot_fry', 'prop_pot_05', 'prop_cooker_03' },
    cloth = { 'prop_cs_magazine', 'prop_paper_ball' },
    bowl = { 'prop_cs_bowl_01', 'bkr_prop_coke_metalbowl_01' },
    paste = { 'bkr_prop_meth_smallbag_01a', 'prop_meth_bag_01' },
    foil = { 'prop_cs_roll_mat', 'prop_paper_bag_small' },
    bag = { 'prop_meth_bag_01', 'bkr_prop_meth_bag_01a' },
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

--- Virimo „burbuliavimo“ stebėjimas — paleisk/stabdyk dujas (Q/E), laikyk lygį.
local function runCookControl(session)
    local heat = 0.35
    local target = 0.62
    local stable = 0.0
    local need = 3.2
    local deadline = GetGameTimer() + 15000
    playAnim('amb@world_human_stand_fire@male@idle_a', 'idle_a', 49)

    RequestNamedPtfxAsset('core')
    while active == session and GetGameTimer() < deadline do
        if IsControlPressed(0, 38) then -- E padidinti
            heat = math.min(1.0, heat + GetFrameTime() * 0.28)
        end
        if IsControlPressed(0, 44) then -- Q sumažinti
            heat = math.max(0.0, heat - GetFrameTime() * 0.28)
        end
        heat = heat + (math.random() - 0.5) * 0.01
        heat = math.max(0.0, math.min(1.0, heat))

        if math.abs(heat - target) < 0.1 then
            stable = stable + GetFrameTime()
        else
            stable = math.max(0.0, stable - GetFrameTime() * 0.5)
        end

        DrawRect(0.5, 0.87, 0.26, 0.024, 25, 15, 30, 180)
        DrawRect(0.5 - 0.13 + target * 0.26, 0.87, 0.04, 0.024, 90, 50, 160, 150)
        DrawRect(0.5 - 0.13 + heat * 0.26, 0.87, 0.01, 0.032, 255, 180, 80, 240)
        setHelp(session, {
            ('~p~Virimas~s~ · E ↑  Q ↓  stabilumas %.0f%%'):format((stable / need) * 100),
            'ESC — atšaukti',
        })

        if HasNamedPtfxAssetLoaded('core') then
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedAtCoord('ent_amb_smoke_factory_white',
                session.origin.x, session.origin.y, session.origin.z + 0.55,
                0.0, 0.0, 0.0, 0.2 + heat * 0.35, false, false, false)
        end

        if stable >= need then
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
    return stable >= need * 0.8
end

local function stageGrind(session)
    local mortarHash = loadModel(PROPS.mortar)
    local pestleHash = loadModel(PROPS.pestle)
    if mortarHash then
        local m = spawnObj(mortarHash, session.origin + vector3(0.0, 0.4, 0.0), session.heading)
        if m then session.entities[#session.entities + 1] = m end
        SetModelAsNoLongerNeeded(mortarHash)
    end
    if pestleHash then
        session.handProp = attachProp(pestleHash, 57005, 0.08, 0.02, 0.0, -70.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(pestleHash)
    end
    helpLoop(session)
    setHelp(session, { '~y~Grūdimas~s~ · E — grūsti aguonas piestoje (5×)' })
    local n = 0
    while n < 5 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 49)
            Wait(550)
            session.score = (session.score or 0) + 7
            setHelp(session, { ('~y~Grūdimas~s~ · %d/5'):format(n) })
        else
            return false
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    return waitReport(session, 'ground')
end

local function stageCook(session)
    local potHash = loadModel(PROPS.pot)
    if potHash then
        local pot = spawnObj(potHash, session.origin + vector3(0.15, 0.45, 0.0), session.heading)
        if pot then session.entities[#session.entities + 1] = pot end
        SetModelAsNoLongerNeeded(potHash)
    end
    helpLoop(session)
    notify('Kontroliuok ugnį — E didina, Q mažina.', 'primary')
    if not runCookControl(session) then return false end
    session.score = (session.score or 0) + 24
    return waitReport(session, 'cooked')
end

local function stageFilter(session)
    local clothHash = loadModel(PROPS.cloth)
    local bowlHash = loadModel(PROPS.bowl)
    if bowlHash then
        local bowl = spawnObj(bowlHash, session.origin + vector3(-0.25, 0.35, 0.0), session.heading)
        if bowl then session.entities[#session.entities + 1] = bowl end
        SetModelAsNoLongerNeeded(bowlHash)
    end
    if clothHash then
        session.handProp = attachProp(clothHash, 57005, 0.12, 0.0, -0.02, 0.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(clothHash)
    end
    helpLoop(session)
    setHelp(session, { '~b~Filtravimas~s~ · E — perkošti per audinį (3×)' })
    local n = 0
    while n < 3 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('amb@world_human_bum_wash@male@high@base', 'base', 49)
            Wait(900)
            session.score = (session.score or 0) + 11
        else
            return false
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    return waitReport(session, 'filtered')
end

local function stageCool(session)
    helpLoop(session)
    setHelp(session, { '~c~Aušinimas~s~ · palauk, kol pasta sustings' })
    local start = GetGameTimer()
    while GetGameTimer() - start < 4500 and active == session do
        local p = (GetGameTimer() - start) / 4500
        setHelp(session, { ('~c~Aušinimas~s~ · %.0f%%'):format(p * 100) })
        if IsControlJustPressed(0, 322) then return false end
        Wait(0)
    end
    session.score = (session.score or 0) + 15
    local pasteHash = loadModel(PROPS.paste)
    if pasteHash then
        local paste = spawnObj(pasteHash, session.origin + vector3(-0.25, 0.35, 0.08), session.heading)
        if paste then session.entities[#session.entities + 1] = paste end
        SetModelAsNoLongerNeeded(pasteHash)
    end
    return waitReport(session, 'cooled')
end

local function stagePortion(session)
    local foilHash = loadModel(PROPS.foil)
    if foilHash then
        for i = 1, 4 do
            local foil = spawnObj(foilHash, session.origin + vector3(-0.35 + (i - 1) * 0.18, 0.3, 0.02), session.heading)
            if foil then session.entities[#session.entities + 1] = foil end
        end
        SetModelAsNoLongerNeeded(foilHash)
    end
    helpLoop(session)
    setHelp(session, { '~g~Dozavimas~s~ · E — užtepti pastą ant folijos (4×)' })
    local n = 0
    while n < 4 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v5_coccutter', 49)
            Wait(700)
            session.score = (session.score or 0) + 9
            setHelp(session, { ('~g~Dozavimas~s~ · %d/4'):format(n) })
        else
            return false
        end
    end
    stopAnim()
    return waitReport(session, 'portioned')
end

local function stageFold(session)
    helpLoop(session)
    setHelp(session, { '~w~Lankstymas~s~ · E — sulankstyti folijos paketėlį (4×)' })
    local n = 0
    while n < 4 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('mp_common', 'givetake1_a', 49)
            Wait(750)
            session.score = (session.score or 0) + 10
        else
            return false
        end
    end
    stopAnim()
    return waitReport(session, 'folded')
end

local function stageSeal(session)
    local bagHash = loadModel(PROPS.bag)
    if bagHash then
        session.handProp = attachProp(bagHash, 57005, 0.12, 0.0, -0.04, -70.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(bagHash)
    end
    helpLoop(session)
    setHelp(session, { '~p~Sandarinimas~s~ · E — sudėti paketėlius į maišelį (2×)' })
    local n = 0
    while n < 2 and active == session do
        if waitKey(38, 16000) then
            n = n + 1
            playAnim('mp_common', 'givetake1_a', 49)
            Wait(850)
            session.score = (session.score or 0) + 14
        else
            return false
        end
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    stopAnim()
    return waitReport(session, 'sealed')
end

local function runProcess(session)
    if not stageGrind(session) then return finish(false, { reason = 'grind', score = session.score, mistakes = 1 }) end
    if not stageCook(session) then return finish(false, { reason = 'cook', score = session.score, mistakes = 1 }) end
    if not stageFilter(session) then return finish(false, { reason = 'filter', score = session.score, mistakes = 1 }) end
    if not stageCool(session) then return finish(false, { reason = 'cool', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = session.mistakes or 0 })
end

local function runPack(session)
    if not stagePortion(session) then return finish(false, { reason = 'portion', score = session.score, mistakes = 1 }) end
    if not stageFold(session) then return finish(false, { reason = 'fold', score = session.score, mistakes = 1 }) end
    if not stageSeal(session) then return finish(false, { reason = 'seal', score = session.score, mistakes = 1 }) end
    finish(true, { score = math.min(100, session.score or 70), mistakes = session.mistakes or 0 })
end

function HeroinProduction.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { reason = 'missing_craft_token' }) end
        return false
    end
    local mode = (payload.mode == 'heroin_fold' or payload.productId == 'heroin_pack') and 'pack' or 'process'
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
    notify(mode == 'pack' and 'Heroinas · folijos pakavimas' or 'Heroinas · redukcija', 'primary')
    CreateThread(function()
        if mode == 'pack' then runPack(session) else runProcess(session) end
    end)
    return true
end

function HeroinProduction.Close(reason)
    if not active then return end
    finish(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function HeroinProduction.IsActive()
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

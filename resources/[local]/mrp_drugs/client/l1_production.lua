--- L1 3D gamyba (THC / alkoholis / vape) — process + pack be schedule CSS/NUI.
--- Etapų vardai sutampa su serverio WORLD_STAGE_SEQUENCES.

L1Production = L1Production or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local PROPS = {
    still = { 'prop_still', 'prop_copper_pan', 'prop_kitch_pot_lrg' },
    pot = { 'prop_kitch_pot_fry', 'prop_pot_05', 'prop_cooker_03' },
    flask = { 'prop_cs_script_bottle_01', 'prop_cs_pills', 'prop_ld_flow_bottle' },
    bowl = { 'prop_cs_bowl_01', 'bkr_prop_coke_metalbowl_01' },
    jar = { 'prop_cs_script_bottle', 'prop_bottle_brandy', 'prop_drink_redwine' },
    cork = { 'prop_wine_bot', 'prop_bottle_cognac' },
    cartridge = { 'prop_cs_pills', 'prop_cs_script_bottle_01' },
    dropper = { 'prop_cs_credit_card', 'prop_cs_scissors' },
    bag = { 'prop_meth_bag_01', 'prop_paper_bag_small' },
    mixer = { 'prop_cs_bowl_01b', 'prop_bar_beans' },
}

local DRUG_LABEL = {
    thc = 'THC',
    alcohol = 'Samagonas',
    vape = 'Vape skystis',
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

local function runHeatBar(session, label)
    local heat = 0.3
    local target = 0.58
    local stable = 0.0
    local need = 2.8
    local deadline = GetGameTimer() + 14000
    playAnim('amb@world_human_stand_fire@male@idle_a', 'idle_a', 49)
    helpLoop(session)
    while active == session and GetGameTimer() < deadline do
        if IsControlPressed(0, 38) then heat = math.min(1.0, heat + GetFrameTime() * 0.3) end
        if IsControlPressed(0, 44) then heat = math.max(0.0, heat - GetFrameTime() * 0.3) end
        heat = math.max(0.0, math.min(1.0, heat + (math.random() - 0.5) * 0.012))
        if math.abs(heat - target) < 0.11 then
            stable = stable + GetFrameTime()
        else
            stable = math.max(0.0, stable - GetFrameTime() * 0.45)
        end
        DrawRect(0.5, 0.87, 0.26, 0.024, 25, 15, 30, 180)
        DrawRect(0.5 - 0.13 + target * 0.26, 0.87, 0.04, 0.024, 90, 50, 160, 150)
        DrawRect(0.5 - 0.13 + heat * 0.26, 0.87, 0.01, 0.032, 255, 180, 80, 240)
        setHelp(session, {
            ('%s · E ↑  Q ↓  %.0f%%'):format(label or '~p~Šildymas~s~', (stable / need) * 100),
            'ESC — atšaukti',
        })
        if stable >= need then
            stopAnim()
            session.score = (session.score or 0) + 18
            return true
        end
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
            stopAnim()
            return false
        end
        Wait(0)
    end
    stopAnim()
    return stable >= need * 0.75
end

-- ——— THC process: load → heat → scrape → collect ———

local function thcProcess(session)
    local potHash = loadModel(PROPS.pot)
    if potHash then
        local e = spawnObj(potHash, session.origin + vector3(0.0, 0.35, 0.0), session.heading)
        if e then session.entities[#session.entities + 1] = e end
        SetModelAsNoLongerNeeded(potHash)
    end
    if not pressCount(session, 4, '~g~Krovimas~s~ · E — dėti žaliavą (%d/%d)', 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 550, 8) then
        return finish(false, { reason = 'load', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'loaded') then return end

    if not runHeatBar(session, '~g~Distiliacija~s~') then
        return finish(false, { reason = 'heated', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'heated') then return end

    local flaskHash = loadModel(PROPS.flask)
    if flaskHash then
        session.handProp = attachProp(flaskHash, 57005, 0.1, 0.02, -0.02, -80.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(flaskHash)
    end
    if not pressCount(session, 5, '~y~Nugramdymas~s~ · E — rinkti distiliatą (%d/%d)', 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 500, 9) then
        return finish(false, { reason = 'scraped', score = session.score, mistakes = 1 })
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not waitReport(session, 'scraped') then return end

    if not pressCount(session, 2, '~p~Surinkimas~s~ · E — surinkti produktą (%d/%d)', 'mp_common', 'givetake1_a', 800, 12) then
        return finish(false, { reason = 'collected', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'collected') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local function thcPack(session)
    if not pressCount(session, 3, '~g~Dozavimas~s~ · E — dozuoti (%d/%d)', 'mp_common', 'givetake1_a', 650, 10) then
        return finish(false, { reason = 'portioned', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'portioned') then return end

    local cartHash = loadModel(PROPS.cartridge)
    if cartHash then
        session.handProp = attachProp(cartHash, 57005, 0.1, 0.0, -0.03, -70.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(cartHash)
    end
    if not pressCount(session, 4, '~y~Kasetė~s~ · E — pildyti kasetę (%d/%d)', 'mp_common', 'givetake1_a', 700, 11) then
        return finish(false, { reason = 'filled', score = session.score, mistakes = 1 })
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not waitReport(session, 'filled') then return end

    if not pressCount(session, 2, '~p~Sandarinimas~s~ · E — užsandarinti (%d/%d)', 'mp_common', 'givetake1_a', 750, 14) then
        return finish(false, { reason = 'sealed', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'sealed') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

-- ——— Alcohol process: charge → distill ———

local function alcoholProcess(session)
    local stillHash = loadModel(PROPS.still)
    if stillHash then
        local e = spawnObj(stillHash, session.origin + vector3(0.0, 0.4, -0.05), session.heading)
        if e then session.entities[#session.entities + 1] = e end
        SetModelAsNoLongerNeeded(stillHash)
    end
    if not pressCount(session, 4, '~o~Krovimas~s~ · E — krauti į still (%d/%d)', 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 600, 9) then
        return finish(false, { reason = 'charged', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'charged') then return end

    if not runHeatBar(session, '~o~Distiliacija~s~') then
        return finish(false, { reason = 'distilled', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'distilled') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local function alcoholPack(session)
    if not pressCount(session, 3, '~o~Pilstymas~s~ · E — pilti į stiklainį (%d/%d)', 'mp_common', 'givetake1_a', 700, 10) then
        return finish(false, { reason = 'poured', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'poured') then return end

    local jarHash = loadModel(PROPS.jar)
    if jarHash then
        session.handProp = attachProp(jarHash, 57005, 0.12, 0.0, -0.04, -80.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(jarHash)
    end
    if not pressCount(session, 3, '~y~Kamštis~s~ · E — užkorkuoti (%d/%d)', 'mp_common', 'givetake1_a', 750, 12) then
        return finish(false, { reason = 'corked', score = session.score, mistakes = 1 })
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not waitReport(session, 'corked') then return end

    if not pressCount(session, 2, '~p~Etiketė~s~ · E — užklijuoti (%d/%d)', 'mp_common', 'givetake1_a', 650, 12) then
        return finish(false, { reason = 'labeled', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'labeled') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

-- ——— Vape process: measure → blend ———

local function vapeProcess(session)
    local mixHash = loadModel(PROPS.mixer)
    if mixHash then
        local e = spawnObj(mixHash, session.origin + vector3(0.0, 0.35, 0.0), session.heading)
        if e then session.entities[#session.entities + 1] = e end
        SetModelAsNoLongerNeeded(mixHash)
    end
    if not pressCount(session, 3, '~b~Matavimas~s~ · E — dozuoti bazę (%d/%d)', 'mp_common', 'givetake1_a', 650, 10) then
        return finish(false, { reason = 'measured', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'measured') then return end

    if not pressCount(session, 5, '~b~Maišymas~s~ · E — maišyti skystį (%d/%d)', 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter', 500, 9) then
        return finish(false, { reason = 'blended', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'blended') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local function vapePack(session)
    local dropHash = loadModel(PROPS.dropper)
    if dropHash then
        session.handProp = attachProp(dropHash, 57005, 0.1, 0.02, -0.02, -70.0, 0.0, 0.0)
        SetModelAsNoLongerNeeded(dropHash)
    end
    if not pressCount(session, 4, '~b~Lašinimas~s~ · E — lašinti (%d/%d)', 'mp_common', 'givetake1_a', 550, 10) then
        return finish(false, { reason = 'dropped', score = session.score, mistakes = 1 })
    end
    if session.handProp and DoesEntityExist(session.handProp) then DeleteEntity(session.handProp) end
    session.handProp = nil
    if not waitReport(session, 'dropped') then return end

    if not pressCount(session, 2, '~y~Uždarymas~s~ · E — užsukti dangtelį (%d/%d)', 'mp_common', 'givetake1_a', 700, 12) then
        return finish(false, { reason = 'capped', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'capped') then return end

    if not pressCount(session, 2, '~p~Pakavimas~s~ · E — sudėti į maišelį (%d/%d)', 'mp_common', 'givetake1_a', 700, 12) then
        return finish(false, { reason = 'bagged', score = session.score, mistakes = 1 })
    end
    if not waitReport(session, 'bagged') then return end
    finish(true, { score = math.min(100, session.score or 70), mistakes = 0 })
end

local RUNNERS = {
    thc = { process = thcProcess, pack = thcPack },
    alcohol = { process = alcoholProcess, pack = alcoholPack },
    vape = { process = vapeProcess, pack = vapePack },
}

function L1Production.Start(payload, onDone)
    if active then
        if onDone then onDone(false, { reason = 'busy' }) end
        return false
    end
    payload = payload or {}
    if not payload.craftToken then
        if onDone then onDone(false, { reason = 'missing_craft_token' }) end
        return false
    end

    local drug = tostring(payload.drug or ''):lower()
    if not RUNNERS[drug] then
        if onDone then onDone(false, { reason = 'unsupported_drug' }) end
        return false
    end

    local mode = 'process'
    local pid = tostring(payload.productId or '')
    local pmode = tostring(payload.mode or '')
    if pid:find('_pack') or pmode:find('cartridge') or pmode:find('jar') or pmode:find('dropper')
        or pmode == 'thc_cartridge' or pmode == 'moonshine_jar' or pmode == 'vape_dropper' then
        mode = 'pack'
    end
    if payload.action == 'pack' then mode = 'pack' end

    local origin, heading = originFromWorkspace(payload.workspace)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, origin.x, origin.y, origin.z, 500)
    Wait(500)

    local session = {
        craftToken = payload.craftToken,
        drug = drug,
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
    local label = DRUG_LABEL[drug] or drug
    notify(('%s · %s'):format(label, mode == 'pack' and 'pakavimas' or 'gamyba'), 'primary')
    CreateThread(function()
        local runner = RUNNERS[drug][mode]
        if runner then runner(session) else finish(false, { reason = 'no_runner' }) end
    end)
    return true
end

function L1Production.Close(reason)
    if not active then return end
    finish(false, {
        score = math.floor(active.score or 0),
        mistakes = (active.mistakes or 0) + 1,
        reason = reason or 'forced_close',
    })
end

function L1Production.IsActive()
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

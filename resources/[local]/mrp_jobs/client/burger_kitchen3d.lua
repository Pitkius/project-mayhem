--[[
  Burger Shot 3D virtuvė — propai, animacijos, etapinis gaminimas in-game.
  Export: StartBurgerKitchen3D(productId, opts) → promise { success, score, quality }
]]

BurgerKitchen3D = BurgerKitchen3D or {}

local QBCore = exports['qb-core']:GetCoreObject()
local active = nil

local function cfg()
    return Config.BurgerKitchen or {}
end

local function productDef(id)
    return (cfg().products or {})[id]
end

local function loadModel(candidates)
    for _, name in ipairs(candidates or {}) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) and IsModelValid(hash) then
            RequestModel(hash)
            local t = GetGameTimer() + 4000
            while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
            if HasModelLoaded(hash) then return hash, name end
        end
    end
    return nil
end

local function loadAnim(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function playAnim(key, duration)
    local a = (cfg().anims or {})[key]
    if not a or not loadAnim(a.dict) then return end
    TaskPlayAnim(PlayerPedId(), a.dict, a.clip, 2.0, 2.0, duration or 1800, 49, 0.0, false, false, false)
end

local function forward(h)
    local r = math.rad(h)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

local function right(h)
    local r = math.rad(h)
    return vector3(math.cos(r), math.sin(r), 0.0)
end

local function offset(origin, heading, rx, fz, uz)
    local R, F = right(heading), forward(heading)
    return vector3(
        origin.x + R.x * rx + F.x * fz,
        origin.y + R.y * rx + F.y * fz,
        origin.z + (uz or 0.0)
    )
end

local function spawnProp(session, key, pos, heading)
    local hash = loadModel((cfg().props or {})[key])
    if not hash then return nil end
    local ent = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    if not ent or ent == 0 then return nil end
    SetEntityAsMissionEntity(ent, true, true)
    SetEntityHeading(ent, heading or session.heading)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    session.ents[#session.ents + 1] = ent
    session.models[hash] = true
    return ent
end

local function deleteEnt(session, ent)
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    if not session then return end
    for i = #session.ents, 1, -1 do
        if session.ents[i] == ent then table.remove(session.ents, i) end
    end
end

local function cleanup(session)
    if not session then return end
    if session.steam then
        StopParticleFxLooped(session.steam, false)
        session.steam = nil
    end
    for _, ent in ipairs(session.ents or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    for hash in pairs(session.models or {}) do
        SetModelAsNoLongerNeeded(hash)
    end
    ClearPedTasks(PlayerPedId())
    if session.cam and DoesCamExist(session.cam) then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(session.cam, false)
    end
    session.ents = {}
end

local function hint(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function drawStage(session, title, sub)
    SetTextFont(4)
    SetTextScale(0.45, 0.45)
    SetTextColour(255, 220, 120, 230)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(title or '')
    EndTextCommandDisplayText(0.5, 0.08)
    if sub then
        SetTextFont(4)
        SetTextScale(0.32, 0.32)
        SetTextColour(230, 230, 230, 210)
        SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(sub)
        EndTextCommandDisplayText(0.5, 0.12)
    end
    SetTextFont(4)
    SetTextScale(0.28, 0.28)
    SetTextColour(180, 255, 180, 200)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('Kokybė: %d  |  Klaidos: %d'):format(math.floor(session.score or 0), session.mistakes or 0))
    EndTextCommandDisplayText(0.5, 0.155)
end

local function markerAt(pos, r, g, b)
    DrawMarker(20, pos.x, pos.y, pos.z + 0.15, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
        0.18, 0.18, 0.18, r or 255, g or 200, b or 40, 200, true, true, 2, false, nil, nil, false)
end

local function waitE(session, pos, label, timeout)
    local deadline = GetGameTimer() + (timeout or 20000)
    while GetGameTimer() < deadline and active == session do
        Wait(0)
        DisableAllControlActions(0)
        EnableControlAction(0, 38, true) --- E
        EnableControlAction(0, 177, true)
        EnableControlAction(0, 200, true)
        drawStage(session, session.title, label)
        if pos then markerAt(pos) end
        hint('~INPUT_CONTEXT~ — ' .. (label or 'Tęsti') .. '  |  BACKSPACE — atšaukti')
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
            return false
        end
        if IsControlJustPressed(0, 38) then
            return true
        end
    end
    return false
end

local function holdE(session, pos, label, holdMs)
    local held = 0
    local start = GetGameTimer()
    while GetGameTimer() - start < 25000 and active == session do
        Wait(0)
        DisableAllControlActions(0)
        EnableControlAction(0, 38, true)
        EnableControlAction(0, 177, true)
        drawStage(session, session.title, label)
        if pos then markerAt(pos, 80, 180, 255) end
        local pct = math.floor((held / holdMs) * 100)
        hint(('Laikyk ~INPUT_CONTEXT~ — %s (%d%%)'):format(label or '', pct))
        if IsControlJustPressed(0, 177) then return false end
        if IsControlPressed(0, 38) then
            held = held + GetFrameTime() * 1000
            if held >= holdMs then return true end
        else
            held = math.max(0, held - GetFrameTime() * 1500)
        end
    end
    return false
end

local function timingWindow(session, pos, label, readyAt, burnAt)
    local start = GetGameTimer()
    local flipped = false
    while GetGameTimer() - start < (burnAt + 2000) and active == session do
        Wait(0)
        DisableAllControlActions(0)
        EnableControlAction(0, 38, true)
        EnableControlAction(0, 177, true)
        local now = GetGameTimer() - start
        local state = 'kepa…'
        local col = { 255, 200, 40 }
        if now >= burnAt then
            state = 'DEGĄ!'
            col = { 255, 60, 40 }
        elseif now >= readyAt then
            state = 'PARUOŠTA — apversk!'
            col = { 80, 255, 120 }
        end
        drawStage(session, session.title, ('%s — %s'):format(label, state))
        if pos then markerAt(pos, col[1], col[2], col[3]) end
        hint('~INPUT_CONTEXT~ kai PARUOŠTA  |  BACKSPACE — atšaukti')
        if IsControlJustPressed(0, 177) then return false, 0 end
        if IsControlJustPressed(0, 38) then
            if now < readyAt then
                session.mistakes = (session.mistakes or 0) + 1
                session.score = math.max(0, (session.score or 0) - 15)
                QBCore.Functions.Notify('Per anksti!', 'error')
            elseif now >= burnAt then
                session.mistakes = (session.mistakes or 0) + 1
                session.score = math.max(0, (session.score or 0) - 25)
                return true, 40
            else
                local mid = (readyAt + burnAt) * 0.5
                local dist = math.abs(now - mid) / math.max(1, burnAt - readyAt)
                local pts = math.floor(100 - dist * 80)
                session.score = (session.score or 0) + pts
                flipped = true
                playAnim('flip', 1200)
                return true, pts
            end
        end
    end
    session.mistakes = (session.mistakes or 0) + 1
    return flipped, 20
end

local function ensureSteam(session, at)
    if session.steam then return end
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local t = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(10) end
    end
    if not HasNamedPtfxAssetLoaded('core') then return end
    UseParticleFxAssetNextCall('core')
    session.steam = StartParticleFxLoopedAtCoord('ent_amb_smoke_foundry', at.x, at.y, at.z + 0.2, 0.0, 0.0, 0.0, 0.5, false, false, false, false)
end

local function setupCam(session, look)
    local camPos = offset(look, session.heading, 0.15, -1.35, 1.05)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z + 0.2)
    SetCamFov(cam, 42.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 280, true, true)
    session.cam = cam
end

local function useMloFurniture()
    return cfg().useMloFurniture ~= false
end

local function applyStation(session, stationType)
    for _, stn in ipairs(session.stations or {}) do
        if stn.type == stationType and stn.coords then
            local c = stn.coords
            session.origin = vector3(c.x, c.y, c.z)
            if c.w then session.heading = c.w end
            return true
        end
    end
    return false
end

local function runBurgerLine(session, def)
    applyStation(session, 'grill')
    local origin, h = session.origin, session.heading
    local mlo = useMloFurniture()
    local grillPos = mlo and origin or offset(origin, h, -0.55, 0.35, 0.0)
    local boardPos = mlo and offset(origin, h, 0.55, 0.15, 0.05) or offset(origin, h, 0.45, 0.25, 0.0)
    if not mlo then
        session.grill = spawnProp(session, 'grill', grillPos, h)
    end
    session.board = spawnProp(session, 'board', boardPos, h)
    setupCam(session, offset(origin, h, 0.0, 0.25, mlo and 0.2 or 0.35))

    --- 1) Padėti žalią mėsą
    local rawKey = def.patty == 'chicken' and 'chicken' or 'patty_raw'
    local grillTop = offset(grillPos, h, 0.0, 0.0, mlo and 0.18 or 0.55)
    if not waitE(session, grillTop, 'Padėk mėsą ant grilio') then return false end
    playAnim('grab', 900)
    local patty = spawnProp(session, rawKey, grillTop, h)
    session.score = (session.score or 0) + 10
    ensureSteam(session, grillTop)

    --- 2) Timing flip (×patties)
    local timing = cfg().timing or {}
    local ready = math.random((timing.grillReadyMs and timing.grillReadyMs.min) or 4500, (timing.grillReadyMs and timing.grillReadyMs.max) or 7000)
    local burn = timing.grillBurnMs or 11000
    for i = 1, (def.patties or 1) do
        local ok = timingWindow(session, grillTop, ('Kepa %d/%d'):format(i, def.patties or 1), ready, burn)
        if not ok then return false end
        Wait(400)
    end

    deleteEnt(session, patty)
    patty = spawnProp(session, 'patty_cooked', grillTop, h)
    if session.steam then StopParticleFxLooped(session.steam, false); session.steam = nil end

    --- 3) Surinkimas
    local stackZ = 0.08
    local stack = offset(boardPos, h, 0.0, 0.0, 0.12)
    if not waitE(session, stack, 'Padėk apatinę bandelę') then return false end
    playAnim('assemble', 800)
    spawnProp(session, 'bun_bot', stack, h)
    stackZ = stackZ + 0.04
    session.score = (session.score or 0) + 8

    if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ), 'Uždėk kepsnį') then return false end
    deleteEnt(session, patty)
    spawnProp(session, 'patty_cooked', offset(boardPos, h, 0.0, 0.0, stackZ), h)
    stackZ = stackZ + 0.05
    session.score = (session.score or 0) + 10

    if def.cheese then
        if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ), 'Uždėk sūrį') then return false end
        playAnim('assemble', 700)
        spawnProp(session, 'cheese', offset(boardPos, h, 0.0, 0.0, stackZ), h)
        stackZ = stackZ + 0.03
        session.score = (session.score or 0) + 6
    end

    if def.bacon then
        if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ), 'Uždėk šoninę') then return false end
        spawnProp(session, 'bacon', offset(boardPos, h, 0.0, 0.0, stackZ), h)
        stackZ = stackZ + 0.03
        session.score = (session.score or 0) + 6
    end

    --- Padažai
    for _, sauce in ipairs(def.sauces or {}) do
        local bottle = spawnProp(session, 'sauce', offset(boardPos, h, 0.35, -0.1, 0.2), h)
        local ok = holdE(session, offset(boardPos, h, 0.0, 0.0, stackZ + 0.05),
            ('Pilk padažą (%s)'):format(sauce), timing.sauceHoldMs or 1600)
        deleteEnt(session, bottle)
        if not ok then return false end
        playAnim('pour', 900)
        session.score = (session.score or 0) + 8
    end

    --- Salotos / toppingai
    local tops = def.toppings or {}
    if def.heavySalad then
        tops = { 'lettuce', 'lettuce', 'tomato', 'onion' }
    end
    for _, top in ipairs(tops) do
        local key = (top == 'tomato' and 'tomato') or (top == 'onion' and 'lettuce') or 'lettuce'
        if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ), ('Uždėk: %s'):format(top)) then return false end
        playAnim('assemble', 650)
        spawnProp(session, key, offset(boardPos, h, 0.0, 0.0, stackZ), h)
        stackZ = stackZ + 0.03
        session.score = (session.score or 0) + 5
    end

    if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ), 'Uždėk viršutinę bandelę') then return false end
    spawnProp(session, 'bun_top', offset(boardPos, h, 0.0, 0.0, stackZ), h)
    session.score = (session.score or 0) + 10

    if not waitE(session, offset(boardPos, h, 0.0, 0.0, stackZ + 0.08), 'Įpakuok burgerį') then return false end
    playAnim('grab', 1000)
    spawnProp(session, 'finished_burger', offset(boardPos, h, 0.2, 0.0, 0.15), h)
    session.score = (session.score or 0) + 12
    return true
end

local function runFriesLine(session)
    applyStation(session, 'fryer')
    local origin, h = session.origin, session.heading
    local mlo = useMloFurniture()
    local fryPos = mlo and origin or offset(origin, h, 0.0, 0.3, 0.0)
    if not mlo then
        session.fryer = spawnProp(session, 'fryer', fryPos, h)
    end
    setupCam(session, offset(origin, h, 0.0, 0.25, mlo and 0.25 or 0.4))
    local basket = offset(fryPos, h, 0.0, 0.0, mlo and 0.2 or 0.55)
    if not waitE(session, basket, 'Įmesk šaldytas bulvytes') then return false end
    playAnim('fry', 1000)
    local fries = spawnProp(session, 'fries_raw', basket, h)
    ensureSteam(session, basket)
    local timing = cfg().timing or {}
    local ready = math.random((timing.fryReadyMs and timing.fryReadyMs.min) or 5000, (timing.fryReadyMs and timing.fryReadyMs.max) or 8000)
    local burn = timing.fryBurnMs or 12000
    local ok = timingWindow(session, basket, 'Kepamos bulvytės', ready, burn)
    if not ok then return false end
    deleteEnt(session, fries)
    spawnProp(session, 'fries_done', basket, h)
    if session.steam then StopParticleFxLooped(session.steam, false); session.steam = nil end
    if not waitE(session, basket, 'Išimk ir pasūdyk') then return false end
    playAnim('grab', 900)
    session.score = (session.score or 0) + 20
    return true
end

local function runDrinkLine(session, def)
    applyStation(session, 'drinks')
    local origin, h = session.origin, session.heading
    local mlo = useMloFurniture()
    local fPos = mlo and origin or offset(origin, h, 0.0, 0.25, 0.0)
    if not mlo then
        session.fountain = spawnProp(session, 'fountain', fPos, h)
    end
    setupCam(session, offset(origin, h, 0.0, 0.2, mlo and 0.3 or 0.45))
    local cupPos = offset(fPos, h, 0.0, 0.12, mlo and 0.25 or 0.5)
    if not waitE(session, cupPos, 'Padėk tuščią puodelį') then return false end
    local cup = spawnProp(session, 'cup_empty', cupPos, h)
    playAnim('pour', 500)
    local ok = holdE(session, cupPos, ('Pilk %s'):format(def.flavor or 'gėrimą'), (cfg().timing and cfg().timing.pourHoldMs) or 2200)
    if not ok then return false end
    deleteEnt(session, cup)
    spawnProp(session, 'cup_full', cupPos, h)
    session.score = (session.score or 0) + 25
    if not waitE(session, cupPos, 'Uždėk dangtelį ir paduok') then return false end
    playAnim('grab', 800)
    session.score = (session.score or 0) + 10
    return true
end

local function runMealLine(session)
    --- Mini meniu: greitas burgeris + fries + drink etapų santrauka
    session.title = 'Burgerio meniu'
    if not runBurgerLine(session, productDef('burger_basic') or {
        patty = 'beef', sauces = { 'ketchup' }, toppings = { 'lettuce' }, patties = 1,
    }) then return false end
    cleanup(session)
    session.ents, session.models = {}, {}
    Wait(300)
    session.title = 'Meniu · bulvytės'
    if not runFriesLine(session) then return false end
    cleanup(session)
    session.ents, session.models = {}, {}
    Wait(300)
    session.title = 'Meniu · gėrimas'
    if not runDrinkLine(session, { flavor = 'cola' }) then return false end
    applyStation(session, 'assembly')
    local boxPos = offset(session.origin, session.heading, 0.0, 0.15, 0.15)
    spawnProp(session, 'meal_box', boxPos, session.heading)
    session.score = (session.score or 0) + 15
    return true
end

local function qualityFromScore(score, mistakes)
    score = (score or 0) - (mistakes or 0) * 8
    if score >= 95 then return 'perfect' end
    if score >= 70 then return 'good' end
    if score >= 40 then return 'normal' end
    return 'poor'
end

--- opts: { origin = vector4, title = string }
function BurgerKitchen3D.Start(productId, opts)
    opts = opts or {}
    if active then return { success = false, reason = 'busy' } end
    local def = productDef(productId)
    if not def then return { success = false, reason = 'unknown' } end

    local origin = opts.origin
    local heading = 0.0
    if origin and origin.w then
        heading = origin.w
        origin = vector3(origin.x, origin.y, origin.z)
    elseif origin then
        origin = vector3(origin.x, origin.y, origin.z)
    else
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        heading = GetEntityHeading(ped)
        origin = c + forward(heading) * 1.2
    end

    local session = {
        productId = productId,
        def = def,
        origin = origin,
        heading = heading,
        stations = opts.stations,
        ents = {},
        models = {},
        score = 0,
        mistakes = 0,
        title = def.label or productId,
    }
    active = session

    local ok = false
    local line = def.line or 'burger'
    if line == 'burger' then
        ok = runBurgerLine(session, def)
    elseif line == 'fries' then
        ok = runFriesLine(session)
    elseif line == 'drink' then
        ok = runDrinkLine(session, def)
    elseif line == 'meal' then
        ok = runMealLine(session)
    end

    local score = session.score or 0
    local mistakes = session.mistakes or 0
    local quality = qualityFromScore(score, mistakes)
    cleanup(session)
    active = nil

    if not ok then
        return { success = false, score = score, quality = 'poor', mistakes = mistakes }
    end
    return { success = true, score = score, quality = quality, mistakes = mistakes }
end

exports('StartBurgerKitchen3D', function(productId, opts)
    return BurgerKitchen3D.Start(productId, opts)
end)

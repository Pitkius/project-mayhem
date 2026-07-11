--[[
  mrp_jobs — Burger Joint VALYTOJAS (klientas).
  Dinaminės užduočių zonos (qb-target), valymo minigame, progreso HUD.
]]

local activeZones = {}      -- sukurtų qb-target zonų vardai
local cleanerState = nil    -- paskutinė serverio būsena (cleaner dalis)

local CLEAN_ANIM = {
    default = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base' },
    scrub   = { dict = 'amb@world_human_maid_clean@male@base', clip = 'base' },
}

local ZONE_LABELS = { dining = 'Salė', kitchen = 'Virtuvė', toilets = 'Tualetai', other = 'Kitos zonos' }
local TYPE_LABELS = {
    table = 'Nuvalyti stalą', trash = 'Surinkti šiukšles', floor = 'Išplauti grindis',
    drink_spill = 'Išvalyti išpiltą gėrimą', seats = 'Nuvalyti sėdynes',
    grease = 'Nuvalyti riebalus', counter = 'Nuvalyti stalviršį', grill = 'Nuvalyti grilį', food = 'Pašalinti maisto likučius',
    sink = 'Nuvalyti kriauklę', toilet = 'Nuvalyti tualetą', refill = 'Papildyti muilą/popierių',
    window = 'Nuvalyti langą', door = 'Nuvalyti durų zoną', storage = 'Sutvarkyti sandėlį',
    staff = 'Sutvarkyti darbuotojų zoną', outside = 'Surinkti lauko šiukšles', drivethrough = 'Nuvalyti drive-through',
}

local function clearZones()
    for _, name in ipairs(activeZones) do
        exports['qb-target']:RemoveZone(name)
    end
    activeZones = {}
end

local function doTask(task)
    local anim = task.minigame == 'clean_scrub' and CLEAN_ANIM.scrub or CLEAN_ANIM.default
    local prof = Config.GetMinigame(task.minigame, {
        label = TYPE_LABELS[task.ttype] or 'Valyti',
        anim = anim,
    })
    local ok = Minigame.run(prof)
    if not ok then Notify('Nutraukta.', 'error'); return end
    QBCore.Functions.TriggerCallback('mrp_jobs:server:cleaner:complete', function(res)
        if res and res.ok then
            if res.routeComplete then
                Notify('Abi burgerinės išvalytos! Gautas pilno maršruto bonusas.', 'success', 8000)
            elseif res.jointComplete then
                Notify('Burgerinė pilnai išvalyta! Toliau — kita burgerinė.', 'success', 6000)
            else
                Notify('Užduotis atlikta.', 'primary')
            end
        else
            local msg = { too_far = 'Per toli.', already = 'Jau atlikta.', rate = 'Per greitai.' }
            Notify(msg[res and res.reason] or 'Nepavyko.', 'error')
        end
    end, task.id)
end

local function rebuildZones()
    clearZones()
    if not cleanerState or not cleanerState.tasks then return end
    for _, t in ipairs(cleanerState.tasks) do
        if not t.done then
            local name = 'mrp_jobs_clean_' .. t.id
            local captured = t
            exports['qb-target']:AddCircleZone(name, vector3(t.coords.x, t.coords.y, t.coords.z), 1.2, {
                name = name, useZ = true, debugPoly = false,
            }, {
                options = {
                    { icon = 'fas fa-broom', label = TYPE_LABELS[t.ttype] or 'Valyti',
                      canInteract = function() return JobClient.isOnJob('burger') end,
                      action = function() doTask(captured) end },
                },
                distance = 1.6,
            })
            activeZones[#activeZones + 1] = name
        end
    end
end

-- ── Būsenos atnaujinimas ──────────────────────────────────────────
AddEventHandler('mrp_jobs:client:stateChanged', function(state)
    if state and state.jobType == 'burger' and state.role == 'cleaner' and state.cleaner then
        cleanerState = state.cleaner
        rebuildZones()
    else
        cleanerState = nil
        clearZones()
    end
end)

RegisterNetEvent('mrp_jobs:client:jobEnded', function()
    cleanerState = nil
    clearZones()
end)

-- ── Progreso HUD ──────────────────────────────────────────────────
local function drawTxt(x, y, text, scale, center)
    SetTextFont(4); SetTextScale(scale, scale); SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    if center then SetTextCentre(true) end
    SetTextEntry('STRING'); AddTextComponentString(text)
    DrawText(x, y)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if cleanerState then
            sleep = 0
            local p = cleanerState.progress or {}
            local y = 0.34
            drawTxt(0.015, y, ('~y~%s~s~  %d/%d'):format(cleanerState.jointLabel or 'Burgerinė', cleanerState.done or 0, cleanerState.total or 0), 0.42)
            y = y + 0.035
            for _, z in ipairs({ 'dining', 'kitchen', 'toilets', 'other' }) do
                local zp = p[z]
                if zp then
                    drawTxt(0.015, y, ('%s: %d/%d'):format(ZONE_LABELS[z], zp.d or 0, zp.t or 0), 0.34)
                    y = y + 0.028
                end
            end
            drawTxt(0.015, y + 0.005, ('Burgerinė %d/%d'):format(cleanerState.routeIndex or 1, cleanerState.routeTotal or 2), 0.32)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearZones()
end)

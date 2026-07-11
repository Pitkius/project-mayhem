--[[
  mrp_jobs — Burger Joint VALYTOJAS (serveris, autoritetingas).
  Atsitiktinai generuoja valymo užduotis abiem burgerinėms. Didžioji atlygio dalis
  mokama tik už PILNAI išvalytas burgerines + viso maršruto bonusą (≈ 15 000 $).
  2 val. cooldown pradedamas TIK užbaigus abi. Nutraukus viduryje — be cooldown.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Cleaner = Cleaner or {}

local RC = Config.Rewards.cleaner
local joints = Config.Locations.burger.joints

-- Zonų tipų šablonai (užtikrina, kad kiekvienas ciklas turi bent po užduotį).
local ZONE_TYPES = {
    dining  = { 'table', 'trash', 'floor', 'drink_spill', 'seats' },
    kitchen = { 'grease', 'counter', 'floor', 'trash', 'grill', 'food' },
    toilets = { 'sink', 'toilet', 'floor', 'trash', 'refill' },
    other   = { 'window', 'door', 'storage', 'staff', 'outside', 'drivethrough' },
}
local SCRUB = { grease = true, toilet = true, grill = true, sink = true }

local function pickMinigame(zone, ttype)
    return SCRUB[ttype] and 'clean_scrub' or 'clean_generic'
end

-- Sugeneruoja vienos burgerinės užduotis (coords — placeholder aplink centrą).
local function generateJointTasks(session, jointId)
    local joint = joints[jointId]
    local center = joint.registerNpc.coords
    local tasks = {}
    for zone, cfg in pairs(RC.taskCounts) do
        local n = Utils.randInt(cfg.min, cfg.max)
        for _ = 1, n do
            local types = ZONE_TYPES[zone]
            local ttype = types[math.random(1, #types)]
            local ang = math.random() * math.pi * 2
            local rad = 1.5 + math.random() * 5.0
            local id = JobManager.nextTaskId(session)
            tasks[id] = {
                id = id, zone = zone, ttype = ttype,
                coords = vector3(center.x + math.cos(ang) * rad, center.y + math.sin(ang) * rad, center.z),
                minigame = pickMinigame(zone, ttype),
                state = Constants.TaskState.PENDING,
            }
        end
    end
    return tasks
end

local function jointProgress(cd)
    local per = { dining = { d = 0, t = 0 }, kitchen = { d = 0, t = 0 }, toilets = { d = 0, t = 0 }, other = { d = 0, t = 0 } }
    local doneAll, totalAll = 0, 0
    for _, t in pairs(cd.tasks) do
        local z = per[t.zone]; if z then z.t = z.t + 1 end
        totalAll = totalAll + 1
        if t.state == Constants.TaskState.DONE then
            if z then z.d = z.d + 1 end
            doneAll = doneAll + 1
        end
    end
    return per, doneAll, totalAll
end

-- ── Handlerio kabliukai (kviečia server/burger.lua 'burger' handleris) ──
function Cleaner.onStart(session)
    -- Maršrutas: pradedam nuo registruotos burgerinės, tada likusios (surūšiuota).
    local order = {}
    for id in pairs(joints) do order[#order + 1] = id end
    table.sort(order)
    -- perkeliam starto burgerinę į priekį
    local route = { session.locationId }
    for _, id in ipairs(order) do
        if id ~= session.locationId then route[#route + 1] = id end
    end

    session.data.cleaner = {
        route = route,
        index = 1,
        tasks = {},
        jointsDone = 0,
    }
    session.data.cleaner.tasks = generateJointTasks(session, route[1])
end

function Cleaner.onStop(session, reason)
    -- Nutraukus viduryje — cooldown NETAIKOMAS (jis dedamas tik užbaigus maršrutą).
    session.data.cleaner = nil
end

function Cleaner.buildClientState(session)
    local cd = session.data.cleaner
    if not cd then return { cleaner = false } end
    local per, doneAll, totalAll = jointProgress(cd)
    local taskList = {}
    for _, t in pairs(cd.tasks) do
        taskList[#taskList + 1] = { id = t.id, zone = t.zone, ttype = t.ttype, coords = t.coords, minigame = t.minigame, done = t.state == Constants.TaskState.DONE }
    end
    local jointId = cd.route[cd.index]
    return { cleaner = {
        jointId = jointId,
        jointLabel = joints[jointId] and joints[jointId].label or jointId,
        routeIndex = cd.index,
        routeTotal = #cd.route,
        tasks = taskList,
        progress = per,
        done = doneAll,
        total = totalAll,
    } }
end

-- ── Užduoties užbaigimas ──────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:cleaner:complete', function(src, cb, taskId)
    if not Security.rateLimit(src, 'cleaner_task', 700) then return cb({ ok = false, reason = 'rate' }) end
    local s = JobManager.getBySource(src)
    if not s or s.jobType ~= 'burger' or s.role ~= 'cleaner' then return cb({ ok = false, reason = 'no_job' }) end
    local cd = s.data.cleaner
    if not cd then return cb({ ok = false, reason = 'no_state' }) end

    local t = cd.tasks[tonumber(taskId)]
    if not t then return cb({ ok = false, reason = 'no_task' }) end
    if t.state == Constants.TaskState.DONE then return cb({ ok = false, reason = 'already' }) end
    if not Security.isNear(src, t.coords, 3.0) then return cb({ ok = false, reason = 'too_far' }) end

    t.state = Constants.TaskState.DONE

    -- Mažas tarpinis atlygis.
    if (RC.perTask or 0) > 0 then
        Rewards.pay(src, RC.perTask, RC.account or 'bank', 'cleaner-task')
    end

    -- Ar visa burgerinė išvalyta?
    local _, doneAll, totalAll = jointProgress(cd)
    if doneAll >= totalAll then
        -- Burgerinės pilno išvalymo premija.
        Rewards.pay(src, RC.perJointComplete, RC.account or 'bank', 'cleaner-joint-complete')
        cd.jointsDone = cd.jointsDone + 1

        if cd.index < #cd.route then
            -- Kita burgerinė.
            cd.index = cd.index + 1
            cd.tasks = generateJointTasks(s, cd.route[cd.index])
            JobManager.pushState(s)
            return cb({ ok = true, jointComplete = true, routeComplete = false })
        else
            -- Visas maršrutas baigtas → bonusas + cooldown + darbo pabaiga.
            Rewards.pay(src, RC.fullRouteBonus, RC.account or 'bank', 'cleaner-route-bonus')
            Cooldowns.set(src, Config.Jobs.burger.cooldownKey, RC.cooldownSeconds or (2 * 60 * 60))
            cb({ ok = true, jointComplete = true, routeComplete = true })
            SetTimeout(1000, function() JobManager.stop(src, 'complete') end)
            return
        end
    end

    JobManager.pushState(s)
    cb({ ok = true, jointComplete = false, routeComplete = false })
end)

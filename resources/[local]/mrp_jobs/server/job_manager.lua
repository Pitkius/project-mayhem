--[[
  mrp_jobs — serverio darbų valdiklis (autoritetingas branduolys).

  Laiko kiekvieno aktyvaus žaidėjo darbo būseną (ActiveJob) atmintyje ir
  suteikia bendrą API, kurį naudoja konkretūs darbų moduliai (oil/burger/fruit).

  Darbo moduliai registruoja savo handlerį per JobManager.registerHandler(key, handler).
  Handler laukai (visi neprivalomi):
    canStart(Player, role, locationId) -> ok, err   -- papildoma validacija prieš startą
    onStart(session, Player)                          -- inicializuoja užduotis / būseną
    onStop(session, Player, reason)                   -- valymas nutraukiant/baigiant
    buildClientState(session) -> table                -- ką siųsti klientui (be jautrių duomenų)
]]

local QBCore = exports['qb-core']:GetCoreObject()

JobManager = JobManager or {}

-- sessions[citizenid] = ActiveJob
local sessions = {}
-- srcToCid[src] = citizenid (greitai peržiūrai)
local srcToCid = {}
-- handlers[key] = handler table
local handlers = {}

-- ── Handlerių registracija ────────────────────────────────────────
function JobManager.registerHandler(key, handler)
    handlers[key] = handler or {}
    if Config.Debug then print(('[mrp_jobs] Užregistruotas handleris: %s'):format(key)) end
end

function JobManager.getHandler(key)
    return handlers[key]
end

-- ── Sesijų prieiga ────────────────────────────────────────────────
function JobManager.get(citizenid)
    return sessions[citizenid]
end

function JobManager.getBySource(src)
    local cid = srcToCid[src]
    return cid and sessions[cid] or nil
end

function JobManager.isOnJob(src, jobType)
    local s = JobManager.getBySource(src)
    if not s then return false end
    if jobType then return s.jobType == jobType end
    return true
end

-- Grąžina aktyvių sesijų sąrašą, atitinkančių darbą/poziciją/vietą (bet kuris nil = ignoruojamas).
function JobManager.findWorkers(jobType, role, locationId)
    local out = {}
    for _, s in pairs(sessions) do
        if (not jobType or s.jobType == jobType)
        and (not role or s.role == role)
        and (not locationId or s.locationId == locationId) then
            out[#out + 1] = s
        end
    end
    return out
end

-- Ar konkrečioje vietoje yra bent vienas darbuotojas su nurodyta pozicija.
function JobManager.hasWorker(jobType, role, locationId)
    return #JobManager.findWorkers(jobType, role, locationId) > 0
end

-- ── Užduočių pagalbininkai ────────────────────────────────────────
function JobManager.nextTaskId(session)
    session.taskSeq = (session.taskSeq or 0) + 1
    return session.taskSeq
end

-- Prideda serverio sugeneruotą užduotį. task: { type, zone, category, meta, minigame }
function JobManager.addTask(session, task)
    task.id = JobManager.nextTaskId(session)
    task.state = Constants.TaskState.PENDING
    session.tasks[task.id] = task
    return task
end

function JobManager.getTask(session, taskId)
    return session.tasks[tonumber(taskId)]
end

-- Pažymi užduotį atlikta (su patikra, kad dar neatlikta). Grąžina true jei pavyko.
function JobManager.completeTask(session, taskId)
    local t = JobManager.getTask(session, taskId)
    if not t then return false, 'no_task' end
    if t.state == Constants.TaskState.DONE then return false, 'already_done' end
    t.state = Constants.TaskState.DONE
    t.completedAt = os.time()
    session.completedCount = (session.completedCount or 0) + 1
    return true
end

function JobManager.countTasks(session)
    local total, done = 0, 0
    for _, t in pairs(session.tasks) do
        total = total + 1
        if t.state == Constants.TaskState.DONE then done = done + 1 end
    end
    return done, total
end

-- ── Startas / stabdymas ───────────────────────────────────────────
-- Grąžina session, err.
function JobManager.start(src, jobType, role, locationId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, 'no_player' end
    local cid = Player.PlayerData.citizenid

    local jobDef = Config.GetJob(jobType)
    if not jobDef or not jobDef.enabled then return nil, 'job_disabled' end

    -- Jau dirba?
    if sessions[cid] then return nil, 'already_working' end

    -- Pozicijos validacija
    if not Config.IsValidRole(jobType, role) then return nil, 'invalid_role' end

    -- Handlerio papildoma validacija
    local handler = handlers[jobDef.handler]
    if handler and handler.canStart then
        local ok, err = handler.canStart(Player, role, locationId)
        if not ok then return nil, err or 'cannot_start' end
    end

    local session = {
        citizenid   = cid,
        source      = src,
        jobType     = jobType,
        role        = role,
        locationId  = locationId,
        stage       = Constants.JobState.ACTIVE,
        tasks       = {},
        taskSeq     = 0,
        completedCount = 0,
        data        = {},            -- darbo-specifinė "scratch" būsena
        startedAt   = os.time(),
        rewardPending = false,
        paidTotal   = 0,
    }
    sessions[cid] = session
    srcToCid[src] = cid

    if handler and handler.onStart then
        handler.onStart(session, Player)
    end

    if Persistence then Persistence.log(cid, jobType, role, Constants.LogCat.START, 0) end
    JobManager.pushState(session)
    return session
end

-- Nutraukia/baigia darbą. reason: 'quit' | 'complete' | 'dropped' | 'admin'
function JobManager.stop(ref, reason)
    local cid = ref
    if type(ref) == 'number' then cid = srcToCid[ref] end
    local session = cid and sessions[cid]
    if not session then return false end

    local Player = QBCore.Functions.GetPlayer(session.source)
    local jobDef = Config.GetJob(session.jobType)
    local handler = jobDef and handlers[jobDef.handler]
    if handler and handler.onStop then
        pcall(handler.onStop, session, Player, reason or 'quit')
    end

    if Persistence then Persistence.log(session.citizenid, session.jobType, session.role, Constants.LogCat.STOP, 0, { reason = reason }) end

    srcToCid[session.source] = nil
    sessions[cid] = nil

    -- Praneša klientui, kad darbas baigtas.
    if session.source then
        TriggerClientEvent('mrp_jobs:client:jobEnded', session.source, reason or 'quit')
    end
    return true
end

-- ── Būsenos siuntimas klientui (be jautrių duomenų) ───────────────
function JobManager.pushState(session)
    if not session or not session.source then return end
    local jobDef = Config.GetJob(session.jobType)
    local handler = jobDef and handlers[jobDef.handler]

    local payload = {
        jobType = session.jobType,
        role = session.role,
        locationId = session.locationId,
        stage = session.stage,
        startedAt = session.startedAt,
    }
    -- Handleris pateikia savo dalį (užduotys, progresas ir pan.).
    if handler and handler.buildClientState then
        local ok, extra = pcall(handler.buildClientState, session)
        if ok and type(extra) == 'table' then
            for k, v in pairs(extra) do payload[k] = v end
        end
    end
    TriggerClientEvent('mrp_jobs:client:jobState', session.source, payload)
end

-- ── Žaidėjo išėjimo / iškrovimo tvarkymas ─────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    local cid = srcToCid[src]
    if cid then JobManager.stop(cid, 'dropped') end
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    local cid = srcToCid[src]
    if cid then JobManager.stop(cid, 'dropped') end
end)

--[[
  mrp_jobs — serverio bootstrap + bendri callback'ai/eventai/exports.
  Konkretūs darbai (oil/burger/fruit) prisijungia per JobManager.registerHandler
  ir registruoja savo callback'us atskiruose failuose.
]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Darbo pasirinkimo meniu duomenys (bendras) ────────────────────
-- Grąžina galimų darbų sąrašą + cooldown būseną žaidėjui.
QBCore.Functions.CreateCallback('mrp_jobs:server:getMenu', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local list = {}
    for jobType, def in pairs(Config.Jobs) do
        if def.enabled then
            local cdLeft = 0
            if def.cooldownKey then
                cdLeft = Cooldowns.remaining(src, def.cooldownKey)
            end
            list[#list + 1] = {
                jobType = jobType,
                label = def.label,
                needsRole = def.needsRole == true,
                roles = def.roles,
                cooldown = cdLeft,
            }
        end
    end

    local current = JobManager.getBySource(src)
    cb({
        jobs = list,
        active = current and { jobType = current.jobType, role = current.role } or nil,
    })
end)

-- ── Darbo pradžia (bendra validacija; handleris tikrina papildomai) ──
QBCore.Functions.CreateCallback('mrp_jobs:server:startJob', function(src, cb, jobType, role, locationId)
    if not Security.rateLimit(src, 'startJob', 1500) then return cb({ ok = false, reason = 'rate' }) end
    if not Security.isAlive(src) then return cb({ ok = false, reason = 'dead' }) end

    local def = Config.GetJob(jobType)
    if not def or not def.enabled then return cb({ ok = false, reason = 'job_disabled' }) end

    -- Cooldown patikra (jei darbas jį naudoja pradžioje). Valytojo cooldownas
    -- tikrinamas handleryje, nes taikomas tik cleaner pozicijai.
    local session, err = JobManager.start(src, jobType, role, locationId)
    if not session then
        return cb({ ok = false, reason = err })
    end
    cb({ ok = true })
end)

-- ── Darbo nutraukimas žaidėjo iniciatyva ──────────────────────────
RegisterNetEvent('mrp_jobs:server:stopJob', function()
    local src = source
    if not Security.rateLimit(src, 'stopJob', 1000) then return end
    JobManager.stop(src, 'quit')
end)

-- ── Exports kitiems resursams ─────────────────────────────────────
exports('IsOnJob', function(src, jobType)
    return JobManager.isOnJob(src, jobType)
end)

exports('GetActiveJob', function(src)
    local s = JobManager.getBySource(src)
    if not s then return nil end
    return { jobType = s.jobType, role = s.role, locationId = s.locationId, stage = s.stage }
end)

if Config.Debug then
    print('[mrp_jobs] Serveris paruoštas.')
end

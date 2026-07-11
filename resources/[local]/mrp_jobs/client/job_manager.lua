--[[
  mrp_jobs — kliento darbo būsenos laikiklis + bendras darbo pasirinkimo meniu.
  Aktyvaus darbo būseną (užduotys, progresas) siunčia serveris — klientas jos
  necache'ina kaip "tiesos šaltinio", tik atvaizduoja.
]]

JobClient = JobClient or {}

-- Paskutinė serverio atsiųsta būsena (tik atvaizdavimui).
local state = nil

function JobClient.get() return state end
function JobClient.isOnJob(jobType)
    if not state then return false end
    if jobType then return state.jobType == jobType end
    return true
end

-- Serveris atnaujina būseną.
RegisterNetEvent('mrp_jobs:client:jobState', function(payload)
    state = payload
    TriggerEvent('mrp_jobs:client:stateChanged', payload)
end)

RegisterNetEvent('mrp_jobs:client:jobEnded', function(reason)
    state = nil
    TriggerEvent('mrp_jobs:client:stateChanged', nil)
    Notify('Darbas baigtas.', 'primary')
end)

-- ── Darbo pasirinkimo meniu (qb-menu) ─────────────────────────────
local function startJob(jobType, role, locationId)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:startJob', function(res)
        if res and res.ok then
            Notify('Darbas pradėtas.', 'success')
        else
            local reasons = {
                already_working = 'Jau dirbi kitą darbą.',
                invalid_role = 'Netinkama pozicija.',
                job_disabled = 'Darbas šiuo metu neprieinamas.',
                cooldown = 'Dar aktyvus atvėsimo laikas.',
                dead = 'Negali dirbti šioje būsenoje.',
                rate = 'Per greitai — palauk.',
            }
            Notify(reasons[res and res.reason] or 'Nepavyko pradėti darbo.', 'error')
        end
    end, jobType, role, locationId)
end
-- Eksportuojam, kad darbų moduliai (oil/burger/fruit) galėtų kviesti tiesiogiai.
JobClient.startJob = startJob

local function openRoleMenu(job, locationId)
    local menu = {
        { header = job.label, txt = 'Pasirink poziciją', isMenuHeader = true },
    }
    for _, r in ipairs(job.roles or {}) do
        menu[#menu + 1] = {
            header = r.label,
            txt = '',
            params = { event = 'mrp_jobs:client:pickRole', args = { jobType = job.jobType, role = r.id, locationId = locationId } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('mrp_jobs:client:pickRole', function(args)
    startJob(args.jobType, args.role, args.locationId)
end)

function JobClient.openMenu(locationId)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:getMenu', function(data)
        if not data then return end
        if data.active then
            local menu = {
                { header = 'Aktyvus darbas', txt = data.active.jobType .. (data.active.role and (' · ' .. data.active.role) or ''), isMenuHeader = true },
                { header = 'Baigti darbą', txt = 'Nutraukti dabartinį darbą', params = { event = 'mrp_jobs:client:endJob' } },
            }
            exports['qb-menu']:openMenu(menu)
            return
        end

        local menu = { { header = 'Darbai', txt = 'Pasirink darbą', isMenuHeader = true } }
        for _, job in ipairs(data.jobs) do
            local txt = ''
            if job.cooldown and job.cooldown > 0 then
                txt = ('Atvėsimas: %d min'):format(math.ceil(job.cooldown / 60))
            end
            if job.needsRole then
                menu[#menu + 1] = {
                    header = job.label, txt = txt,
                    params = { event = 'mrp_jobs:client:openRole', args = { job = job, locationId = locationId } },
                }
            else
                menu[#menu + 1] = {
                    header = job.label, txt = txt,
                    params = { event = 'mrp_jobs:client:pickRole', args = { jobType = job.jobType, role = nil, locationId = locationId } },
                }
            end
        end
        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterNetEvent('mrp_jobs:client:openRole', function(args)
    openRoleMenu(args.job, args.locationId)
end)

RegisterNetEvent('mrp_jobs:client:endJob', function()
    TriggerServerEvent('mrp_jobs:server:stopJob')
end)

-- Komanda atidaryti meniu (papildomai prie NPC/target, kurie ateis vėlesniuose etapuose).
RegisterCommand(Config.OpenCommand or 'darbas', function()
    JobClient.openMenu(nil)
end, false)

-- Valymas resurso stabdymo metu (darbų moduliai valo savo entity patys).
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    state = nil
end)

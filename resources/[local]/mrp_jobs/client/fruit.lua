--[[
  mrp_jobs — VAISIŲ rinkėjas (klientas).
  NPC registracija, rinkimo zonos (medis/žemė animacijos), pakavimas, pristatymas.
]]

local FL = Config.Locations.fruit
local npcPed = nil
local zonesReady = false

local function onFruit() return JobClient.isOnJob('fruit') end

-- Blip
CreateThread(function()
    if FL.blip then
        local b = AddBlipForCoord(FL.npc.coords.x, FL.npc.coords.y, FL.npc.coords.z)
        SetBlipSprite(b, FL.blip.sprite); SetBlipColour(b, FL.blip.color)
        SetBlipScale(b, FL.blip.scale); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(FL.blip.name); EndTextCommandSetBlipName(b)
    end
end)

local function spawnNpc()
    if npcPed and DoesEntityExist(npcPed) then return end
    local m = LoadModel(FL.npc.model)
    if not m then return end
    local c = FL.npc.coords
    npcPed = CreatePed(0, m, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(npcPed, true); SetBlockingOfNonTemporaryEvents(npcPed, true); FreezeEntityPosition(npcPed, true)
    if FL.npc.scenario then TaskStartScenarioInPlace(npcPed, FL.npc.scenario, 0, true) end
    SetModelAsNoLongerNeeded(m)

    exports['qb-target']:AddTargetEntity(npcPed, {
        options = {
            { icon = 'fas fa-apple-whole', label = 'Pradėti vaisių darbą', canInteract = function() return not onFruit() end,
              action = function() JobClient.startJob('fruit', nil, 'orchard') end },
            { icon = 'fas fa-flag-checkered', label = 'Baigti darbą', canInteract = function() return onFruit() end,
              action = function() TriggerServerEvent('mrp_jobs:server:stopJob') end },
        },
        distance = Config.Target.npcDistance or 2.5,
    })
end

-- ── Rinkimo veiksmas ──────────────────────────────────────────────
local function pickAt(fruitId, index)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:fruit:startPick', function(res)
        if not res or not res.ok then
            local msg = { not_ready = ('Dar neatsinaujino (%ds).'):format(res and res.wait or 0), too_far = 'Per toli.', rate = 'Per greitai.', no_job = 'Nėra darbo.' }
            Notify(msg[res and res.reason] or 'Nepavyko.', 'error'); return
        end
        local prof = Config.GetMinigame(res.minigame, {
            label = 'Renki vaisius',
            anim = res.anim,
        })
        local ok = Minigame.run(prof)
        QBCore.Functions.TriggerCallback('mrp_jobs:server:fruit:finishPick', function(done)
            if done and done.ok then
                Notify(('Surinkai %d vnt.'):format(done.amount), 'success')
            else
                Notify('Nepavyko surinkti.', 'error')
            end
        end, res.token, ok == true)
    end, fruitId, index)
end

-- ── Zonos: rinkimo taškai + pristatymas/pakavimas ─────────────────
local function setupZones()
    if zonesReady then return end
    zonesReady = true

    for fruitId, fr in pairs(Config.Fruits) do
        for i, loc in ipairs(fr.locations) do
            local capturedId, capturedIndex = fruitId, i
            local name = ('mrp_jobs_fruit_%s_%d'):format(fruitId, i)
            exports['qb-target']:AddCircleZone(name, vector3(loc.x, loc.y, loc.z), fr.zoneRadius or 1.5, {
                name = name, useZ = true, debugPoly = false,
            }, {
                options = {
                    { icon = 'fas fa-seedling', label = ('Rinkti: %s'):format(fr.label), canInteract = function() return onFruit() end,
                      action = function() pickAt(capturedId, capturedIndex) end },
                },
                distance = (fr.zoneRadius or 1.5) + 0.6,
            })
        end
    end

    -- Pristatymas + pakavimas
    local d = FL.delivery
    local opts = {
        { icon = 'fas fa-truck-ramp-box', label = 'Parduoti dėžes', canInteract = function() return onFruit() end,
          action = function() deliverCrates() end },
    }
    for fruitId, fr in pairs(Config.Fruits) do
        local capturedId = fruitId
        opts[#opts + 1] = {
            icon = 'fas fa-box-open', label = ('Pakuoti: %s'):format(fr.label), canInteract = function() return onFruit() end,
            action = function() packFruit(capturedId) end,
        }
    end
    exports['qb-target']:AddCircleZone('mrp_jobs_fruit_delivery', vector3(d.coords.x, d.coords.y, d.coords.z), d.radius or 5.0, {
        name = 'mrp_jobs_fruit_delivery', useZ = true, debugPoly = false,
    }, { options = opts, distance = (d.radius or 5.0) })
end

function packFruit(fruitId)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:fruit:pack', function(res)
        if res and res.ok then Notify('Supakuota į dėžę.', 'success')
        else
            local msg = { not_enough = ('Reikia %d vnt.'):format(res and res.need or 0), inv_full = 'Inventorius pilnas.', too_far = 'Per toli.' }
            Notify(msg[res and res.reason] or 'Nepavyko pakuoti.', 'error')
        end
    end, fruitId)
end

function deliverCrates()
    QBCore.Functions.TriggerCallback('mrp_jobs:server:fruit:deliver', function(res)
        if res and res.ok then Notify(('Pristatyta %d dėžių! +$%d'):format(res.crates, res.pay), 'success')
        else
            local msg = { no_crates = 'Neturi dėžių.', too_far = 'Per toli.' }
            Notify(msg[res and res.reason] or 'Nepavyko pristatyti.', 'error')
        end
    end)
end

CreateThread(function()
    Wait(1700)
    spawnNpc()
    setupZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if npcPed and DoesEntityExist(npcPed) then DeleteEntity(npcPed) end
end)

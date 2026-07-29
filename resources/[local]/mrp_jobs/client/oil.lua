--[[
  mrp_jobs — NAFTOS darbas (klientas).
  NPC registracija + transporto išdavimas, pumpų minigame, statinės nešimas,
  pakrovimas į transportą, pristatymas į elektrinę.
]]

local OIL = Config.Locations.oil

local npcPed = nil
local jobVehicle = nil
local loadedProps = {}
local zonesReady = false

local function isOnOil() return JobClient.isOnJob('oil') end

-- ── Blip ──────────────────────────────────────────────────────────
CreateThread(function()
    if OIL.blip then
        local b = AddBlipForCoord(OIL.npc.coords.x, OIL.npc.coords.y, OIL.npc.coords.z)
        SetBlipSprite(b, OIL.blip.sprite); SetBlipColour(b, OIL.blip.color)
        SetBlipScale(b, OIL.blip.scale); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(OIL.blip.name); EndTextCommandSetBlipName(b)
    end
    if OIL.blipDelivery and OIL.delivery then
        local c = OIL.delivery.coords
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, OIL.blipDelivery.sprite or 436)
        SetBlipColour(b, OIL.blipDelivery.color or 1)
        SetBlipScale(b, OIL.blipDelivery.scale or 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(OIL.blipDelivery.name or 'Naftos pristatymas')
        EndTextCommandSetBlipName(b)
    end
    if OIL.blipRubber and OIL.rubberProcess then
        local c = OIL.rubberProcess.coords
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, OIL.blipRubber.sprite or 478)
        SetBlipColour(b, OIL.blipRubber.color or 21)
        SetBlipScale(b, OIL.blipRubber.scale or 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(OIL.blipRubber.name or 'Sintetinės gumos gamyba')
        EndTextCommandSetBlipName(b)
    end
end)

-- ── Registracijos NPC ─────────────────────────────────────────────
local function spawnNpc()
    if npcPed and DoesEntityExist(npcPed) then return end
    local m = LoadModel(OIL.npc.model)
    if not m then return end
    local c = OIL.npc.coords
    npcPed = CreatePed(0, m, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    if OIL.npc.scenario then TaskStartScenarioInPlace(npcPed, OIL.npc.scenario, 0, true) end
    SetModelAsNoLongerNeeded(m)

    exports['qb-target']:AddTargetEntity(npcPed, {
        options = {
            { icon = 'fas fa-oil-well', label = 'Pradėti naftos darbą', canInteract = function() return not isOnOil() end,
              action = function() JobClient.startJob('oil', nil, 'oilfield') end },
            { icon = 'fas fa-truck', label = 'Gauti darbo transportą', canInteract = function() return isOnOil() end,
              action = function() spawnJobVehicle() end },
            { icon = 'fas fa-flag-checkered', label = 'Baigti darbą', canInteract = function() return isOnOil() end,
              action = function() TriggerServerEvent('mrp_jobs:server:stopJob') end },
        },
        distance = Config.Target.npcDistance or 2.5,
    })
end

-- ── Darbo transportas ─────────────────────────────────────────────
function spawnJobVehicle()
    if jobVehicle and DoesEntityExist(jobVehicle) then
        Notify('Transportas jau išduotas.', 'error'); return
    end
    local vs = OIL.vehicleSpawn
    local hash = LoadModel(vs.model)
    if not hash then return end
    jobVehicle = CreateVehicle(hash, vs.coords.x, vs.coords.y, vs.coords.z, vs.coords.w, true, false)
    SetVehicleNumberPlateText(jobVehicle, 'OIL' .. math.random(100, 999))
    SetEntityAsMissionEntity(jobVehicle, true, true)
    SetModelAsNoLongerNeeded(hash)
    Notify('Transportas paruoštas. Pakrauk statines ir vežk į elektrinę.', 'success')

    exports['qb-target']:AddTargetEntity(jobVehicle, {
        options = {
            { icon = 'fas fa-box', label = 'Įkelti statinę', canInteract = function() return isOnOil() and Props.isCarrying() end,
              action = function() loadBarrel() end },
        },
        distance = 3.0,
    })
end

-- ── Zonos: pumpai + pristatymas ───────────────────────────────────
local function setupZones()
    if zonesReady then return end
    zonesReady = true

    for _, pump in ipairs(OIL.pumps) do
        local captured = pump
        exports['qb-target']:AddCircleZone('mrp_jobs_oil_' .. pump.id, vector3(pump.coords.x, pump.coords.y, pump.coords.z), 1.6, {
            name = 'mrp_jobs_oil_' .. pump.id, useZ = true, debugPoly = false,
        }, {
            options = {
                { icon = 'fas fa-gears', label = 'Išgauti naftą', canInteract = function() return isOnOil() and not Props.isCarrying() end,
                  action = function() extractAt(captured) end },
            },
            distance = 2.5,
        })
    end

    local d = OIL.delivery
    exports['qb-target']:AddCircleZone('mrp_jobs_oil_delivery', vector3(d.coords.x, d.coords.y, d.coords.z), d.radius or 6.0, {
        name = 'mrp_jobs_oil_delivery', useZ = true, debugPoly = false,
    }, {
        options = {
            { icon = 'fas fa-industry', label = 'Iškrauti į elektrinę', canInteract = function() return isOnOil() end,
              action = function() deliver() end },
        },
        distance = d.radius or 6.0,
    })

    local rp = OIL.rubberProcess
    if rp and rp.coords then
        exports['qb-target']:AddCircleZone('mrp_jobs_oil_rubber', vector3(rp.coords.x, rp.coords.y, rp.coords.z), rp.radius or 2.4, {
            name = 'mrp_jobs_oil_rubber', useZ = true, debugPoly = false,
        }, {
            options = {
                {
                    icon = 'fas fa-industry',
                    label = rp.label or 'Gaminti sintetinę gumą',
                    action = function() processRubber() end,
                },
            },
            distance = 2.5,
        })
    end
end

function processRubber()
    QBCore.Functions.Progressbar('mrp_jobs_oil_rubber', 'Gaminama sintetinė guma…', 3500, false, true, {
        disableMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function()
        QBCore.Functions.TriggerCallback('mrp_jobs:server:oil:processRubber', function(res)
            if res and res.ok then
                Notify(('Pagaminta guma: %sx'):format(res.produced), 'success')
            else
                local msg = {
                    no_residue = 'Trūksta naftos likučių.',
                    too_far = 'Per toli nuo gamybos taško.',
                    inv_full = 'Inventorius pilnas.',
                    rate = 'Palauk akimirką.',
                }
                Notify(msg[res and res.reason] or 'Nepavyko pagaminti gumos.', 'error')
            end
        end)
    end, function() end)
end

-- ── Veiksmai ──────────────────────────────────────────────────────
function extractAt(pump)
    if Props.isCarrying() then Notify('Jau neši statinę — nunešk ją.', 'error'); return end
    QBCore.Functions.TriggerCallback('mrp_jobs:server:oil:startExtract', function(res)
        if not res or not res.ok then
            local msg = { rate = 'Per greitai.', carrying = 'Jau neši statinę.', full_load = 'Krovinys pilnas — pristatyk.', too_far = 'Per toli nuo siurblio.', no_job = 'Neturi aktyvaus darbo.' }
            Notify(msg[res and res.reason] or 'Nepavyko.', 'error'); return
        end
        local ok = Minigame.run(Config.GetMinigame('oil_pump'))
        QBCore.Functions.TriggerCallback('mrp_jobs:server:oil:finishExtract', function(done)
            if done and done.ok then
                Props.pickUp(done.barrelProp or OIL.barrelProp)
                Notify('Išgavai statinę. Nunešk prie transporto.', 'success')
            else
                Notify('Nepavyko išgauti naftos.', 'error')
            end
        end, res.token, ok == true)
    end, pump.id)
end

function loadBarrel()
    if not Props.isCarrying() then Notify('Neturi statinės.', 'error'); return end
    if not (jobVehicle and DoesEntityExist(jobVehicle)) then Notify('Nėra darbo transporto.', 'error'); return end
    QBCore.Functions.TriggerCallback('mrp_jobs:server:oil:loadBarrel', function(res)
        if res and res.ok then
            local offsets = OIL.vehicleSpawn.loadOffsets or {}
            local off = offsets[res.slot] or vector3(0.0, 0.0, 1.1)
            local obj = Props.loadIntoVehicle(jobVehicle, off)
            if obj then loadedProps[#loadedProps + 1] = obj end
            Notify(('Pakrauta: %d/%d'):format(res.loaded, res.maxLoad), 'primary')
        else
            local msg = { no_barrel = 'Neturi statinės.', full_load = 'Krovinys pilnas.', no_job = 'Nėra darbo.' }
            Notify(msg[res and res.reason] or 'Nepavyko pakrauti.', 'error')
        end
    end)
end

function deliver()
    local health = 1000
    if jobVehicle and DoesEntityExist(jobVehicle) then
        health = math.floor(GetVehicleEngineHealth(jobVehicle))
    end
    QBCore.Functions.TriggerCallback('mrp_jobs:server:oil:deliver', function(res)
        if res and res.ok then
            for _, o in ipairs(loadedProps) do
                if o and DoesEntityExist(o) then DeleteEntity(o) end
            end
            loadedProps = {}
            Notify(('Pristatyta %d statinių! +$%d'):format(res.barrels, res.pay), 'success')
            if (res.residue or 0) > 0 then
                Notify(('Gavai naftos likučių: %sx — gamink gumą šalia elektrinės.'):format(res.residue), 'primary', 7000)
            end
        else
            local msg = { empty = 'Nėra ką pristatyti.', too_far = 'Privažiuok prie elektrinės.', no_job = 'Nėra darbo.' }
            Notify(msg[res and res.reason] or 'Nepavyko pristatyti.', 'error')
        end
    end, health)
end

-- ── Valymas baigus darbą ──────────────────────────────────────────
local function cleanupJob()
    Props.removeCarried()
    for _, o in ipairs(loadedProps) do
        if o and DoesEntityExist(o) then DeleteEntity(o) end
    end
    loadedProps = {}
    if jobVehicle and DoesEntityExist(jobVehicle) then
        DeleteEntity(jobVehicle)
    end
    jobVehicle = nil
end

AddEventHandler('mrp_jobs:client:stateChanged', function(state)
    if not state or state.jobType ~= 'oil' then
        -- Jei buvo naftos darbas ir baigėsi — valom.
        if jobVehicle or Props.isCarrying() then cleanupJob() end
    end
end)

RegisterNetEvent('mrp_jobs:client:jobEnded', function()
    cleanupJob()
end)

CreateThread(function()
    Wait(1500)
    spawnNpc()
    setupZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupJob()
    if npcPed and DoesEntityExist(npcPed) then DeleteEntity(npcPed) end
end)

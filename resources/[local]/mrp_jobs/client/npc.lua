--[[
  mrp_jobs — Burger Joint klientų NPC (valdo dirbančio KASININKO klientas).
  Būsenų mašina: SPAWN → eilė → užsakymas → laukimas → išėjimas → despawn.
  Tik vienas klientas (kasininkas) generuoja NPC — todėl nėra network spam.
]]

local BN = Config.BurgerNpc
local activeJoint = nil
local npcs = {}                 -- eilė (masyvas): { ped, state, orderId, spawnedAt, orderedAt, line }
local lastSpawnAt = 0
local nextSpawnGap = 15000

local function jointCfg() return activeJoint and Config.Locations.burger.joints[activeJoint] or nil end

local function queueSlotCoords(index)
    local j = jointCfg(); if not j then return nil end
    local q = j.queue
    local a = q.anchor
    local step = q.step or vector3(0.0, 1.0, 0.0)
    return vector3(a.x + step.x * (index - 1), a.y + step.y * (index - 1), a.z + step.z * (index - 1))
end

local function despawnNpc(entry)
    if entry.ped and DoesEntityExist(entry.ped) then
        SetPedKeepTask(entry.ped, false)
        DeleteEntity(entry.ped)
    end
end

local function cleanupAll()
    for _, e in ipairs(npcs) do despawnNpc(e) end
    npcs = {}
end

local function spawnCustomer()
    local j = jointCfg(); if not j then return end
    local model = BN.models[math.random(1, #BN.models)]
    local hash = LoadModel(model)
    if not hash then return end
    local sp = j.queue.spawn
    local ped = CreatePed(0, hash, sp.x, sp.y, sp.z - 1.0, sp.w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    npcs[#npcs + 1] = { ped = ped, state = 'toqueue', orderId = nil, spawnedAt = GetGameTimer(), line = nil }
end

-- NPC atvyko prie kasos → prašom serverio užsakymo.
local function requestOrder(entry)
    entry.state = 'ordering'
    local net = NetworkGetNetworkIdFromEntity(entry.ped)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:npcArrived', function(res)
        if res and res.ok then
            entry.orderId = res.orderId
            entry.line = res.line
            entry.orderedAt = GetGameTimer()
            entry.state = 'waiting'
            -- Voice-over: bandom NUI audio (jei failas yra); tekstas rodomas visada (fallback).
            SendNUIMessage({ action = 'burgerVoice', data = { orderId = res.menuId } })
        else
            -- Nepavyko (eilė pilna / ne kasininkas) — NPC išeina.
            entry.state = 'leaving'
        end
    end, activeJoint, net)
end

-- Serveris pranešė, kad užsakymas priduotas — NPC išeina.
RegisterNetEvent('mrp_jobs:client:burger:orderServed', function(orderId)
    for _, e in ipairs(npcs) do
        if e.orderId == orderId then e.state = 'leaving' end
    end
end)

-- ── Valdymo ciklas ────────────────────────────────────────────────
CreateThread(function()
    while true do
        if activeJoint then
            local j = jointCfg()
            local now = GetGameTimer()

            -- Naujo NPC generavimas.
            if j and #npcs < (BN.queue.maxActive or 5) and (now - lastSpawnAt) > nextSpawnGap then
                spawnCustomer()
                lastSpawnAt = now
                nextSpawnGap = math.random(BN.queue.spawnIntervalMs.min or 12000, BN.queue.spawnIntervalMs.max or 26000)
            end

            -- Kiekvieno NPC atnaujinimas.
            for i = #npcs, 1, -1 do
                local e = npcs[i]
                if not e.ped or not DoesEntityExist(e.ped) then
                    table.remove(npcs, i)
                else
                    local slot = queueSlotCoords(i)
                    if e.state == 'toqueue' or e.state == 'inqueue' then
                        if slot then
                            local pc = GetEntityCoords(e.ped)
                            local d = #(pc - slot)
                            if d > 1.2 then
                                TaskGoStraightToCoord(e.ped, slot.x, slot.y, slot.z, BN.queue.walkSpeed or 1.0, 8000, j.queue.anchor.w or 0.0, 0.5)
                                e.state = 'toqueue'
                            else
                                e.state = 'inqueue'
                                if i == 1 and not e.orderId then
                                    requestOrder(e)
                                end
                            end
                        end
                    elseif e.state == 'waiting' then
                        -- Kantrybė
                        if e.orderedAt and (now - e.orderedAt) > (BN.queue.patienceSec or 90) * 1000 then
                            TriggerServerEvent('mrp_jobs:server:burger:npcLeft', e.orderId)
                            e.state = 'leaving'
                        end
                    elseif e.state == 'leaving' then
                        local ex = j.queue.exit
                        TaskGoStraightToCoord(e.ped, ex.x, ex.y, ex.z, 1.2, 12000, 0.0, 1.0)
                        local pc = GetEntityCoords(e.ped)
                        if #(pc - vector3(ex.x, ex.y, ex.z)) < 2.0 or (now - (e.spawnedAt or now)) > 120000 then
                            despawnNpc(e)
                            table.remove(npcs, i)
                        end
                    end
                end
            end

            Wait(1000)
        else
            Wait(1500)
        end
    end
end)

-- 3D tekstas virš laukiančių NPC (fallback, veikia visada). Aktyvus tik kai reikia.
CreateThread(function()
    while true do
        local sleep = 800
        if activeJoint and #npcs > 0 then
            local myc = GetEntityCoords(PlayerPedId())
            for _, e in ipairs(npcs) do
                if e.state == 'waiting' and e.line and e.ped and DoesEntityExist(e.ped) then
                    local pc = GetEntityCoords(e.ped)
                    if #(pc - myc) < 8.0 then
                        sleep = 0
                        SetDrawOrigin(pc.x, pc.y, pc.z + 1.05, 0)
                        SetTextScale(0.34, 0.34)
                        SetTextFont(4); SetTextColour(255, 255, 255, 215); SetTextCentre(true)
                        SetTextEntry('STRING'); AddTextComponentString(e.line)
                        DrawText(0.0, 0.0)
                        ClearDrawOrigin()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── Būsenos keitimas: įjungiam/išjungiam NPC valdymą ──────────────
AddEventHandler('mrp_jobs:client:stateChanged', function(state)
    if state and state.jobType == 'burger' and state.role == 'cashier' then
        activeJoint = state.locationId
    else
        if activeJoint then cleanupAll() end
        activeJoint = nil
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupAll()
end)

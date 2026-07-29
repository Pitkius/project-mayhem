--[[
  mrp_jobs — Burger Joint klientų NPC (valdo dirbančio KASININKO klientas).
  Būsenų mašina: SPAWN (lauke) → waypoints → eilė → užsakymas prie terminalo → laukimas → exit → despawn.
  Tik vienas klientas (kasininkas) generuoja NPC — todėl nėra network spam.
]]

local BN = Config.BurgerNpc
local activeJoint = nil
local npcs = {}                 -- eilė: { ped, state, orderId, spawnedAt, orderedAt, line, wpIndex, ordered }
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

local function walkTo(ped, x, y, z, heading, speed, timeoutMs)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    speed = speed or (BN.queue.walkSpeed or 1.0)
    timeoutMs = timeoutMs or 20000
    ClearPedTasks(ped)
    TaskFollowNavMeshToCoord(ped, x + 0.0, y + 0.0, z + 0.0, speed, timeoutMs, 0.8, false, heading or 0.0)
end

local function announceCustomerLine(line, reinforce)
    if not line or line == '' then return end
    local voice = BN.voice or {}
    if voice.chatFallback == false and not reinforce then return end

    local msg = ('Klientas: %s'):format(line)
    TriggerEvent('chat:addMessage', {
        color = { 255, 180, 80 },
        multiline = false,
        args = { 'Burger Shot', msg },
    })
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, reinforce and 'error' or 'primary', reinforce and 6500 or 5500)
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
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
    SetPedKeepTask(ped, true)
    npcs[#npcs + 1] = {
        ped = ped,
        state = 'towaypoint',
        wpIndex = 1,
        orderId = nil,
        ordered = false,
        spawnedAt = GetGameTimer(),
        line = nil,
    }
end

-- NPC atvyko prie kasos → prašom serverio užsakymo (tik slot 1).
local function requestOrder(entry)
    if entry.ordered or entry.state == 'ordering' or entry.state == 'waiting' then return end
    entry.state = 'ordering'
    entry.ordered = true

    ClearPedTasks(entry.ped)
    TaskStartScenarioInPlace(entry.ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    local net = NetworkGetNetworkIdFromEntity(entry.ped)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:npcArrived', function(res)
        if res and res.ok then
            entry.orderId = res.orderId
            entry.line = res.line
            entry.orderedAt = GetGameTimer()
            entry.state = 'waiting'

            -- Tekstas visada (chat + notify + feed + 3D).
            announceCustomerLine(res.line, false)

            -- Optional VO: tik jei netoli NPC.
            local voice = BN.voice or {}
            if voice.enabled ~= false then
                local maxDist = tonumber(voice.maxDistance) or 12.0
                local myc = GetEntityCoords(PlayerPedId())
                local pc = GetEntityCoords(entry.ped)
                if #(myc - pc) <= maxDist then
                    SendNUIMessage({
                        action = 'burgerVoice',
                        data = {
                            orderId = res.menuId,
                            line = res.line,
                            maxDistance = maxDist,
                        },
                    })
                end
            end
        else
            entry.state = 'leaving'
            entry.ordered = false
        end
    end, activeJoint, net)
end

RegisterNetEvent('mrp_jobs:client:burger:orderServed', function(orderId)
    for _, e in ipairs(npcs) do
        if e.orderId == orderId then e.state = 'leaving' end
    end
end)

RegisterNetEvent('mrp_jobs:client:burger:voiceFailed', function(line)
    if line and line ~= '' then
        announceCustomerLine(line, true)
    end
end)

RegisterNUICallback('burger:voiceFailed', function(data, cb)
    cb('ok')
    local line = data and data.line
    if line and line ~= '' then
        announceCustomerLine(line, true)
    end
end)

-- ── Valdymo ciklas ────────────────────────────────────────────────
CreateThread(function()
    while true do
        if activeJoint then
            local j = jointCfg()
            local now = GetGameTimer()

            if j and #npcs < (BN.queue.maxActive or 5) and (now - lastSpawnAt) > nextSpawnGap then
                spawnCustomer()
                lastSpawnAt = now
                nextSpawnGap = math.random(BN.queue.spawnIntervalMs.min or 12000, BN.queue.spawnIntervalMs.max or 26000)
            end

            for i = #npcs, 1, -1 do
                local e = npcs[i]
                if not e.ped or not DoesEntityExist(e.ped) then
                    table.remove(npcs, i)
                else
                    local slot = queueSlotCoords(i)
                    local speed = BN.queue.walkSpeed or 1.0
                    local heading = (j.queue.anchor and j.queue.anchor.w) or 0.0

                    if e.state == 'towaypoint' then
                        local wps = j.queue.waypoints
                        if type(wps) ~= 'table' or #wps == 0 then
                            e.state = 'toqueue'
                        else
                            local idx = e.wpIndex or 1
                            if idx > #wps then
                                e.state = 'toqueue'
                            else
                                local wp = wps[idx]
                                local target = vector3(wp.x + 0.0, wp.y + 0.0, wp.z + 0.0)
                                local pc = GetEntityCoords(e.ped)
                                if #(pc - target) > 1.4 then
                                    walkTo(e.ped, target.x, target.y, target.z, heading, speed, 25000)
                                else
                                    e.wpIndex = idx + 1
                                    if e.wpIndex > #wps then
                                        e.state = 'toqueue'
                                    end
                                end
                            end
                        end
                    elseif e.state == 'toqueue' or e.state == 'inqueue' then
                        if slot then
                            local pc = GetEntityCoords(e.ped)
                            local d = #(pc - slot)
                            if d > 1.2 then
                                walkTo(e.ped, slot.x, slot.y, slot.z, heading, speed, 20000)
                                e.state = 'toqueue'
                            else
                                e.state = 'inqueue'
                                if i == 1 and not e.orderId and not e.ordered then
                                    requestOrder(e)
                                end
                            end
                        end
                    elseif e.state == 'waiting' then
                        if e.orderedAt and (now - e.orderedAt) > (BN.queue.patienceSec or 90) * 1000 then
                            TriggerServerEvent('mrp_jobs:server:burger:npcLeft', e.orderId)
                            e.state = 'leaving'
                        end
                    elseif e.state == 'leaving' then
                        local ex = j.queue.exit
                        walkTo(e.ped, ex.x, ex.y, ex.z, ex.w or 0.0, 1.2, 25000)
                        local pc = GetEntityCoords(e.ped)
                        if #(pc - vector3(ex.x, ex.y, ex.z)) < 2.0 or (now - (e.spawnedAt or now)) > 120000 then
                            despawnNpc(e)
                            table.remove(npcs, i)
                        end
                    end
                end
            end

            Wait(900)
        else
            Wait(1500)
        end
    end
end)

-- 3D tekstas virš laukiančių NPC (fallback, veikia visada).
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

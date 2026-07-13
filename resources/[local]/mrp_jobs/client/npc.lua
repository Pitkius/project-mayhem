--[[
  mrp_jobs — Burger Joint klientų NPC (valdo dirbančio KASININKO klientas).
  Maršrutas: spawn prie įėjimo → waypoints palei sieną → užsakymo vieta.
]]

local BN = Config.BurgerNpc
local activeJoint = nil
local npcs = {}
local lastSpawnAt = 0
local nextSpawnGap = 15000

local ARRIVE_DIST = 0.85
local STUCK_MS = 2800
local TASK_REISSUE_MS = 1800

local function jointCfg() return activeJoint and Config.Locations.burger.joints[activeJoint] or nil end

local function queueSlotCoords(index)
    local j = jointCfg(); if not j then return nil, nil end
    local q = j.queue
    if index == 1 then
        local r = q.register or q.anchor
        return vector3(r.x, r.y, r.z), r.w or 0.0
    end
    local a = q.anchor
    local step = q.step or vector3(0.0, 1.0, 0.0)
    local off = index - 2
    return vector3(a.x + step.x * off, a.y + step.y * off, a.z + step.z * off), a.w or 0.0
end

local function buildRoute(j, slotIndex)
    local route = {}
    if j.queue.waypoints then
        for _, wp in ipairs(j.queue.waypoints) do
            route[#route + 1] = wp
        end
    end
    local slot = queueSlotCoords(slotIndex)
    if slot then route[#route + 1] = slot end
    return route
end

local function holdPedAt(ped, heading)
    ClearPedTasks(ped)
    TaskStandStill(ped, -1)
    if heading then SetEntityHeading(ped, heading) end
end

local function faceRegister(ped, j)
    local reg = j.queue.register or j.queue.anchor
    if reg then
        TaskTurnPedToFaceCoord(ped, reg.x, reg.y, reg.z, 800)
    end
end

local function walkPedTo(ped, coords, speed, heading)
    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, speed or 1.0, 12000, heading or 0.0, 0.15)
end

local function snapPedTo(ped, coords, heading)
    ClearPedTasks(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
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
    RequestCollisionAtCoord(sp.x, sp.y, sp.z)
    local ped = CreatePed(0, hash, sp.x, sp.y, sp.z, sp.w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    PlaceEntityOnGroundProperly(ped)
    SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false)
    SetEntityHeading(ped, sp.w or 0.0)

    npcs[#npcs + 1] = {
        ped = ped,
        state = 'toqueue',
        orderId = nil,
        spawnedAt = GetGameTimer(),
        orderedAt = nil,
        line = nil,
        slotIndex = #npcs + 1,
        routeIdx = 1,
        lastPos = GetEntityCoords(ped),
        lastMoveAt = GetGameTimer(),
        taskIssuedAt = 0,
        stuckCount = 0,
    }
end

local function requestOrder(entry, j)
    entry.state = 'ordering'
    local net = NetworkGetNetworkIdFromEntity(entry.ped)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:npcArrived', function(res)
        if res and res.ok then
            entry.orderId = res.orderId
            entry.line = res.line
            entry.orderedAt = GetGameTimer()
            entry.state = 'waiting'
            holdPedAt(entry.ped, (j.queue.register or j.queue.anchor).w)
            faceRegister(entry.ped, j)
            SendNUIMessage({ action = 'burgerVoice', data = { orderId = res.menuId } })
        else
            entry.state = 'leaving'
            entry.routeIdx = 1
        end
    end, activeJoint, net)
end

RegisterNetEvent('mrp_jobs:client:burger:orderServed', function(orderId)
    for _, e in ipairs(npcs) do
        if e.orderId == orderId then
            e.state = 'leaving'
            e.routeIdx = 1
        end
    end
end)

local function moveNpcAlongRoute(e, slotIndex, j)
    local route = buildRoute(j, slotIndex)
    local slotPos, heading = queueSlotCoords(slotIndex)
    if #route == 0 then return end

    local now = GetGameTimer()
    local pc = GetEntityCoords(e.ped)
    local speed = BN.queue.walkSpeed or 1.0

    -- Persikėlimas eilėje (pvz. 2 → 1) — trumpas kelias iki naujos pozicijos.
    if e.slotIndex ~= slotIndex then
        e.slotIndex = slotIndex
        local wpCount = j.queue.waypoints and #j.queue.waypoints or 0
        if slotPos and #(pc - slotPos) < 1.6 then
            e.routeIdx = #route
        else
            e.routeIdx = math.max(1, wpCount)
        end
        e.taskIssuedAt = 0
        e.stuckCount = 0
    end

    if not e.routeIdx or e.routeIdx < 1 then e.routeIdx = 1 end

    if e.routeIdx > #route then
        holdPedAt(e.ped, heading)
        faceRegister(e.ped, j)
        e.state = 'inqueue'
        if slotIndex == 1 and not e.orderId then
            requestOrder(e, j)
        end
        return
    end

    local target = route[e.routeIdx]
    local dist = #(pc - target)

    if e.lastPos and #(pc - e.lastPos) > 0.18 then
        e.lastPos = pc
        e.lastMoveAt = now
        e.stuckCount = 0
    elseif not e.lastPos then
        e.lastPos = pc
        e.lastMoveAt = now
    end

    if dist <= ARRIVE_DIST then
        e.routeIdx = e.routeIdx + 1
        e.taskIssuedAt = 0
        e.lastMoveAt = now
        return
    end

    if (now - e.lastMoveAt) >= STUCK_MS then
        e.stuckCount = (e.stuckCount or 0) + 1
        e.lastMoveAt = now
        if e.stuckCount >= 2 then
            snapPedTo(e.ped, target, heading)
            e.routeIdx = e.routeIdx + 1
            e.stuckCount = 0
            e.taskIssuedAt = 0
            return
        end
        ClearPedTasks(e.ped)
        e.taskIssuedAt = 0
    end

    if (now - (e.taskIssuedAt or 0)) >= TASK_REISSUE_MS then
        walkPedTo(e.ped, target, speed, heading)
        e.taskIssuedAt = now
    end
end

local function moveNpcToExit(e, j)
    local ex = j.queue.exit
    local target = vector3(ex.x, ex.y, ex.z)
    local now = GetGameTimer()
    local pc = GetEntityCoords(e.ped)
    local dist = #(pc - target)

    if dist <= 1.5 then return true end

    if e.lastPos and #(pc - e.lastPos) < 0.15 and (now - (e.lastMoveAt or now)) >= STUCK_MS then
        snapPedTo(e.ped, target, ex.w)
        return true
    end

    if (now - (e.taskIssuedAt or 0)) >= TASK_REISSUE_MS then
        walkPedTo(e.ped, target, 1.15, ex.w)
        e.taskIssuedAt = now
    end
    return false
end

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
                    if e.state == 'toqueue' or e.state == 'inqueue' then
                        moveNpcAlongRoute(e, i, j)
                    elseif e.state == 'waiting' then
                        holdPedAt(e.ped, (j.queue.register or j.queue.anchor).w)
                        if e.orderedAt and (now - e.orderedAt) > (BN.queue.patienceSec or 90) * 1000 then
                            TriggerServerEvent('mrp_jobs:server:burger:npcLeft', e.orderId)
                            e.state = 'leaving'
                            e.routeIdx = 1
                        end
                    elseif e.state == 'leaving' then
                        if moveNpcToExit(e, j) or (now - (e.spawnedAt or now)) > 90000 then
                            despawnNpc(e)
                            table.remove(npcs, i)
                        end
                    end
                end
            end

            Wait(350)
        else
            Wait(1500)
        end
    end
end)

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

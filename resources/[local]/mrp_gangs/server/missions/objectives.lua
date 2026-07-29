GangObjectives = GangObjectives or {}

local actionPhaseTypes = {
    interact = true,
    breach = true,
    search = true,
    collect = true,
    sabotage = true,
    rescue = true,
    capture = true,
}

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function phaseElapsed(run)
    return os.time() - (tonumber(run.phaseStartedAt) or os.time())
end

local function requiredElapsed(phase)
    local durationSeconds = math.ceil((tonumber(phase.durationMs) or 0) / 1000)
    return math.max(tonumber(phase.minSeconds) or 0, durationSeconds)
end

local function near(source, target, maxDistance)
    local current = playerCoords(source)
    if not current or not target then return false end
    return #(current - vector3(target.x, target.y, target.z)) <= (maxDistance or 5.0)
end

local function near2D(source, target, maxDistance)
    local current = playerCoords(source)
    if not current or not target then return false end
    return GangUtils.Distance2D(current, target) <= (maxDistance or 5.0)
end

local function offsetXYZW(offset)
    if not offset then return 0.0, 0.0, 0.0, nil end
    -- vector3/vector4 support .x/.y/.z/.w but not numeric [1]/[4] indexing.
    if type(offset) ~= 'table' then
        return tonumber(offset.x) or 0.0,
            tonumber(offset.y) or 0.0,
            tonumber(offset.z) or 0.0,
            tonumber(offset.w)
    end
    return tonumber(offset.x or offset[1]) or 0.0,
        tonumber(offset.y or offset[2]) or 0.0,
        tonumber(offset.z or offset[3]) or 0.0,
        tonumber(offset.w or offset[4])
end

local function applyOffset(origin, offset)
    if not origin or not offset then return origin end
    local ox, oy, oz, ow = offsetXYZW(offset)
    local bx, by, bz, bw = offsetXYZW(origin)
    return {
        x = bx + ox,
        y = by + oy,
        z = bz + oz,
        w = ow or bw or 0.0,
    }
end

local function compoundData(run)
    return run.compoundKey and Config.MissionCompounds[run.compoundKey] or nil
end

function GangObjectives.Begin(run, phase, source)
    if not actionPhaseTypes[phase.type] then return false, 'objective_does_not_require_begin' end
    local target = GangObjectives.GetTarget(run, phase)
    if not near(source, target, 5.0) then return false, 'not_at_objective' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then return false, 'player_incapacitated' end

    local player = GangCore.GetPlayer(source)
    if not player then return false, 'player_missing' end
    local metadata = player.PlayerData.metadata or {}
    if metadata.isdead or metadata.inlaststand then return false, 'player_incapacitated' end
    local missionRole = 'support'
    for _, participant in ipairs(run.participants or {}) do
        if participant.citizenid == player.PlayerData.citizenid then
            missionRole = participant.roleKey or missionRole
            break
        end
    end
    local durationMs = tonumber(phase.durationMs) or 5000
    if phase.type == 'breach' and missionRole == 'breacher' then
        durationMs = math.floor(durationMs * 0.80)
    elseif phase.type == 'search' and missionRole == 'scout' then
        durationMs = math.floor(durationMs * 0.85)
    end
    run.actions = run.actions or {}
    local token = GangUtils.RandomToken(('action-%s-%s'):format(run.dbId, run.phaseIndex))
    run.actions[player.PlayerData.citizenid] = {
        token = token,
        phaseIndex = run.phaseIndex,
        startedAt = os.time(),
        durationMs = durationMs,
    }
    return true, {
        actionToken = token,
        durationMs = durationMs,
    }
end

local function makeCheckpoints(run, count)
    local origin = run.site
    local points = {}
    local radius = 380.0
    count = math.max(3, tonumber(count) or 5)
    for index = 1, count do
        local angle = ((index - 1) / count) * (math.pi * 2.0)
        points[#points + 1] = {
            x = origin.x + math.cos(angle) * radius,
            y = origin.y + math.sin(angle) * radius,
            z = origin.z,
            w = 0.0,
        }
    end
    return points
end

function GangObjectives.GetTarget(run, phase)
    local compound = compoundData(run)
    if phase.type == 'approach' or phase.location == 'site' or phase.type == 'vehicle' then
        return run.site
    end
    if phase.type == 'enter' then
        if compound and compound.entryOffset then
            return applyOffset(run.site, compound.entryOffset)
        end
        return run.site
    end
    if phase.type == 'extract' then return run.extraction end

    local interior = run.interiorKey and Config.MissionInteriors[run.interiorKey]
    if phase.type == 'exit' then
        if run.inInterior and interior then
            return GangUtils.CoordsToTable(interior.exit)
        end
        if compound and compound.exitOffset then
            return applyOffset(run.site, compound.exitOffset)
        end
        return run.site
    end
    if phase.objectiveIndex then
        if run.inInterior and interior then
            local coords = interior.objective[tonumber(phase.objectiveIndex)]
            return GangUtils.CoordsToTable(coords)
        end
        if compound and compound.objective then
            local offset = compound.objective[tonumber(phase.objectiveIndex)]
            return applyOffset(run.site, offset)
        end
    end
    if phase.type == 'eliminate' or phase.type == 'defend' then
        if run.inInterior and interior then
            return GangUtils.CoordsToTable(interior.entry)
        end
        return run.site
    end
    if phase.type == 'checkpoint_run' then
        run.checkpoints = run.checkpoints or makeCheckpoints(run, phase.checkpointCount)
        run.checkpointIndex = run.checkpointIndex or 1
        return run.checkpoints[run.checkpointIndex]
    end
    return run.site
end

function GangObjectives.BuildClientPhase(run, phase)
    local compound = compoundData(run)
    return {
        runToken = run.token,
        missionKey = run.missionKey,
        state = run.state,
        phaseIndex = run.phaseIndex,
        phaseCount = #run.phases,
        phase = GangUtils.Copy(phase),
        target = GangObjectives.GetTarget(run, phase),
        checkpointIndex = run.checkpointIndex,
        checkpointCount = run.checkpoints and #run.checkpoints or nil,
        interiorKey = run.interiorKey,
        compoundKey = run.compoundKey,
        inCompound = run.inCompound == true,
        entryPrompt = compound and compound.entryPrompt or 'Eik į vidų',
        bucketId = run.bucketId,
    }
end

function GangObjectives.Validate(run, phase, source, payload)
    payload = payload or {}
    local actorPed = GetPlayerPed(source)
    if not actorPed or actorPed == 0 or GetEntityHealth(actorPed) <= 0 then
        return false, 'player_incapacitated'
    end
    local actor = GangCore.GetPlayer(source)
    local metadata = actor and actor.PlayerData and actor.PlayerData.metadata or {}
    if metadata.isdead or metadata.inlaststand then return false, 'player_incapacitated' end
    local elapsed = phaseElapsed(run)
    local minimum = actionPhaseTypes[phase.type]
        and (tonumber(phase.minSeconds) or 0)
        or requiredElapsed(phase)

    if elapsed < math.max(0, minimum - 1) then
        return false, 'objective_too_fast'
    end

    if phase.type == 'approach' then
        return near(source, run.site, 12.0), 'not_at_approach'
    end

    if phase.type == 'enter' then
        local target = GangObjectives.GetTarget(run, phase)
        return near(source, target, 8.0), 'not_at_entry'
    end

    if actionPhaseTypes[phase.type] then
        local target = GangObjectives.GetTarget(run, phase)
        if not near(source, target, 5.0) then return false, 'not_at_objective' end
        local player = GangCore.GetPlayer(source)
        local action = player and run.actions and run.actions[player.PlayerData.citizenid]
        if not action
            or action.phaseIndex ~= run.phaseIndex
            or action.token ~= tostring(payload.actionToken or '') then
            return false, 'objective_action_not_started'
        end
        local requiredSeconds = math.ceil((tonumber(action.durationMs) or 5000) / 1000)
        if os.time() - action.startedAt < math.max(1, requiredSeconds - 1) then
            return false, 'objective_action_too_fast'
        end
        run.actions[player.PlayerData.citizenid] = nil
        return true
    end

    if phase.type == 'vehicle' then
        if not run.missionVehicleEntity or not DoesEntityExist(run.missionVehicleEntity) then
            return false, 'mission_vehicle_missing'
        end
        local ped = GetPlayerPed(source)
        if not ped or ped == 0 then return false, 'player_missing' end
        if GetVehiclePedIsIn(ped, false) ~= run.missionVehicleEntity
            or GetPedInVehicleSeat(run.missionVehicleEntity, -1) ~= ped then
            return false, 'mission_vehicle_driver_required'
        end
        return true
    end

    if phase.type == 'eliminate' then
        return GangEncounters.IsCleared(run), 'enemies_remaining'
    end

    if phase.type == 'defend' then
        local duration = tonumber(phase.durationSec) or 60
        if elapsed < duration then return false, 'defence_timer_active' end
        return GangEncounters.IsCleared(run), 'enemies_remaining'
    end

    if phase.type == 'exit' then
        local target = GangObjectives.GetTarget(run, phase)
        return near(source, target, 8.0), 'not_at_exit'
    end

    if phase.type == 'extract' then
        if run.cargoCarrierCitizenId then
            local carrierSource = GangCore.GetSourceByCitizenId(run.cargoCarrierCitizenId)
            local carrierPed = carrierSource and GetPlayerPed(carrierSource) or 0
            if not carrierPed or carrierPed == 0
                or GangUtils.Distance2D(GetEntityCoords(carrierPed), run.extraction) > 15.0 then
                return false, 'mission_cargo_not_at_extraction'
            end
        end
        if run.missionTargetFreed then
            if not run.missionTargetEntity or not DoesEntityExist(run.missionTargetEntity)
                or IsEntityDead(run.missionTargetEntity) then
                return false, 'mission_target_lost'
            end
            local targetCoords = GetEntityCoords(run.missionTargetEntity)
            if GangUtils.Distance2D(targetCoords, run.extraction) > 25.0 then
                return false, 'mission_target_not_at_extraction'
            end
        end
        return near(source, run.extraction, 12.0), 'not_at_extraction'
    end

    if phase.type == 'checkpoint_run' then
        local expected = tonumber(run.checkpointIndex) or 1
        if tonumber(payload.checkpointIndex) ~= expected then return false, 'invalid_checkpoint_order' end
        local target = GangObjectives.GetTarget(run, phase)
        if not near2D(source, target, 18.0) then return false, 'not_at_checkpoint' end
        local ped = GetPlayerPed(source)
        local vehicle = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        if vehicle == 0 then
            return false, 'vehicle_required'
        end
        if run.missionVehicleEntity and vehicle ~= run.missionVehicleEntity then
            return false, 'mission_vehicle_required'
        end
        local previous = expected == 1 and run.site or run.checkpoints[expected - 1]
        local minimumTravelSeconds = math.max(3, math.floor(GangUtils.Distance2D(previous, target) / 120.0))
        local previousAt = run.lastCheckpointAt or run.phaseStartedAt
        if os.time() - previousAt < minimumTravelSeconds then return false, 'checkpoint_too_fast' end
        run.lastCheckpointAt = os.time()
        if expected < #run.checkpoints then
            run.checkpointIndex = expected + 1
            return true, 'checkpoint_advanced', false
        end
        return true, nil, true
    end

    return false, 'unknown_objective'
end

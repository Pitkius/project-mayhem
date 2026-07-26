local QBCore = GangCore.QBCore

GangMissions = GangMissions or {}
GangMissions.Runs = {}
GangMissions.RunByCitizen = {}
GangMissions.RunBySource = {}
GangMissions.RunByGang = {}
GangMissions.ReadyMembers = {}
GangMissions.Contests = {}
--- source -> contest token (rivals who discovered a site by proximity)
GangMissions.ContestWatchers = {}
GangMissions.NextBucketOffset = 0

local function missionAllowed(mission, gangType)
    if not mission.enabled then return false end
    if mission.gangTypes and mission.gangTypes[tostring(gangType)] ~= true then return false end
    return true
end

local function difficultyAllowed(mission, difficulty)
    return Config.Difficulties[difficulty] ~= nil and GangUtils.Contains(mission.allowedDifficulties, difficulty)
end

local function allocateBucket()
    for _ = 1, 100 do
        GangMissions.NextBucketOffset = (GangMissions.NextBucketOffset % 900) + 1
        local candidate = (Config.MissionBucketBase or 31000) + GangMissions.NextBucketOffset
        local used = false
        for _, run in pairs(GangMissions.Runs) do
            if run.bucketId == candidate then used = true break end
        end
        if not used then return candidate end
    end
    return nil
end

local function pickSite(poolKey)
    local pool = Config.MissionWorldSites[poolKey]
    if not pool or #pool == 0 then return nil end
    return GangUtils.CoordsToTable(pool[math.random(1, #pool)])
end

local function pickExtraction(poolKey, site)
    local pool = Config.MissionWorldSites[poolKey]
    if not pool or #pool == 0 then return nil end
    local candidates = {}
    for _, coords in ipairs(pool) do
        local value = GangUtils.CoordsToTable(coords)
        if GangUtils.Distance2D(value, site) >= 100.0 then candidates[#candidates + 1] = value end
    end
    if #candidates == 0 then
        return { x = site.x + 250.0, y = site.y + 250.0, z = site.z, w = site.w }
    end
    return candidates[math.random(1, #candidates)]
end

local function activeRunCount()
    local count = 0
    for _ in pairs(GangMissions.Runs) do count = count + 1 end
    return count
end

local function getParticipant(run, citizenid)
    for _, participant in ipairs(run.participants or {}) do
        if participant.citizenid == citizenid then return participant end
    end
    return nil
end

local function getParticipantBySource(run, source)
    for _, participant in ipairs(run.participants or {}) do
        if participant.source == tonumber(source) then return participant end
    end
    local player = GangCore.GetPlayer(source)
    return player and getParticipant(run, player.PlayerData.citizenid) or nil
end

local function participantSources(run)
    local result = {}
    for _, participant in ipairs(run.participants or {}) do
        local source = GangCore.GetSourceByCitizenId(participant.citizenid)
        if source then result[#result + 1] = source end
    end
    return result
end

local function partyNear(run, target, radius, requiredRatio)
    local online = 0
    local nearby = 0
    for _, source in ipairs(participantSources(run)) do
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            online = online + 1
            local coords = GetEntityCoords(ped)
            if #(coords - vector3(target.x, target.y, target.z)) <= radius then nearby = nearby + 1 end
        end
    end
    if online == 0 then return false end
    return (nearby / online) >= requiredRatio
end

local function clientSummary(run)
    local mission = Config.Missions[run.missionKey]
    return {
        token = run.token,
        missionKey = run.missionKey,
        missionLabel = mission and mission.label or run.missionKey,
        difficulty = run.difficulty,
        partySize = #run.participants,
        leaderCitizenId = run.leaderCitizenId,
        state = run.state,
    }
end

local function broadcast(run, eventName, ...)
    for _, source in ipairs(participantSources(run)) do
        TriggerClientEvent(eventName, source, ...)
    end
end

local function setPartyBucket(run, bucket)
    for _, source in ipairs(participantSources(run)) do
        SetPlayerRoutingBucket(source, bucket)
    end
end

local function persistPhase(run)
    MySQL.update.await([[
        UPDATE mrp_gang_mission_runs
        SET state = ?, phase_index = ?
        WHERE id = ? AND settled_at IS NULL
    ]], { run.state, run.phaseIndex, run.dbId })
end

local function clearContestWatchers(token)
    token = tostring(token or '')
    for source, watched in pairs(GangMissions.ContestWatchers) do
        if token == '' or tostring(watched) == token then
            TriggerClientEvent('mrp_gangs:client:clearContestedObjective', source, watched)
            GangMissions.ContestWatchers[source] = nil
        end
    end
end

local function clearContest(token)
    token = tostring(token or '')
    if token == '' or not GangMissions.Contests[token] then return end
    GangMissions.Contests[token] = nil
    clearContestWatchers(token)
end

local function isContestable(run, phase)
    local cfg = Config.MissionContest
    if not cfg or cfg.enabled ~= true or not phase then return false end
    if phase.contested ~= true then return false end
    if run.inInterior then return false end
    if phase.objectiveIndex and run.interiorKey then return false end
    local allowed = cfg.contestablePhaseTypes or {}
    return allowed[phase.type] == true
end

local function contestClientPayload(contest)
    return {
        token = contest.token,
        gangId = contest.gangId,
        missionLabel = contest.missionLabel,
        label = contest.label,
        target = contest.target,
        cargo = contest.cargo == true,
        phaseIndex = contest.phaseIndex,
        radius = (Config.MissionContest and Config.MissionContest.radius) or 55.0,
    }
end

local function publishContest(run, phase)
    clearContest(run.token)
    local target = GangObjectives.GetTarget(run, phase)
    if not target then return end
    local mission = Config.Missions[run.missionKey] or {}
    GangMissions.Contests[run.token] = {
        token = run.token,
        gangId = run.gangId,
        missionKey = run.missionKey,
        missionLabel = mission.label or run.missionKey,
        phaseIndex = run.phaseIndex,
        phaseType = phase.type,
        cargo = phase.cargo == true,
        label = phase.label or 'Contested loot',
        target = target,
        publishedAt = os.time(),
    }
    run.contestActive = true
    --- No global notify/blip — rivals discover via proximity sync only.
end

local function syncContestDiscoveries()
    local cfg = Config.MissionContest
    if not cfg or cfg.enabled ~= true then
        clearContestWatchers('')
        return
    end

    local discoveryRadius = tonumber(cfg.discoveryRadius) or 70.0
    local wanted = {}

    for _, contest in pairs(GangMissions.Contests) do
        local target = contest.target
        if target then
            local targetCoords = vector3(target.x + 0.0, target.y + 0.0, target.z + 0.0)
            for _, playerId in ipairs(GetPlayers()) do
                local source = tonumber(playerId)
                if source and not wanted[source] then
                    local ped = GetPlayerPed(source)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        if #(coords - targetCoords) <= discoveryRadius then
                            local gang = GangCore.GetPlayerGang(source)
                            if gang and tonumber(gang.gang_id) ~= tonumber(contest.gangId) then
                                if not GangMissions.GetBySource(source) then
                                    wanted[source] = contest
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for source, token in pairs(GangMissions.ContestWatchers) do
        local contest = wanted[source]
        if not contest or tostring(contest.token) ~= tostring(token) then
            TriggerClientEvent('mrp_gangs:client:clearContestedObjective', source, token)
            GangMissions.ContestWatchers[source] = nil
        end
    end

    for source, contest in pairs(wanted) do
        if GangMissions.ContestWatchers[source] ~= contest.token then
            GangMissions.ContestWatchers[source] = contest.token
            TriggerClientEvent('mrp_gangs:client:contestedObjective', source, contestClientPayload(contest))
        end
    end
end

local function clearRun(run)
    clearContest(run.token)
    GangEncounters.Cleanup(run)
    if run.missionTargetEntity and DoesEntityExist(run.missionTargetEntity) then
        DeleteEntity(run.missionTargetEntity)
    end
    if run.missionVehicleEntity and DoesEntityExist(run.missionVehicleEntity) then
        DeleteEntity(run.missionVehicleEntity)
    end
    setPartyBucket(run, 0)
    for _, participant in ipairs(run.participants or {}) do
        GangMissions.RunByCitizen[participant.citizenid] = nil
        local source = GangCore.GetSourceByCitizenId(participant.citizenid) or participant.source
        if source then GangMissions.RunBySource[source] = nil end
    end
    MySQL.update.await('DELETE FROM mrp_gang_mission_locks WHERE gang_id = ? AND run_token = ?', {
        run.gangId,
        run.token,
    })
    GangMissions.RunByGang[run.gangId] = nil
    GangMissions.Runs[run.token] = nil
end

local function spawnMissionTarget(run, phase)
    if run.missionTargetEntity and DoesEntityExist(run.missionTargetEntity) then return true end
    local target = GangObjectives.GetTarget(run, phase)
    if not target then return false end
    local model = phase.type == 'capture' and joaat('g_m_m_mexboss_01') or joaat('a_m_y_business_02')
    local ped = CreatePed(4, model, target.x, target.y, target.z, target.w or 0.0, true, true)
    if not ped or ped == 0 then return false end
    SetEntityRoutingBucket(ped, run.inInterior and run.bucketId or 0)
    SetEntityOrphanMode(ped, 2)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    Entity(ped).state:set('mrpGangMissionRun', run.token, true)
    Entity(ped).state:set('mrpGangMissionTarget', phase.type, true)
    run.missionTargetEntity = ped
    run.missionTargetNetworkId = NetworkGetNetworkIdFromEntity(ped)
    run.missionTargetMode = phase.type
    broadcast(
        run,
        'mrp_gangs:client:configureMissionTarget',
        run.token,
        run.missionTargetNetworkId,
        phase.type,
        false
    )
    return true
end

local function failRun(run, reason, state)
    if not run or run.settled then return end
    run.state = state or 'failed'
    MySQL.update.await([[
        UPDATE mrp_gang_mission_runs
        SET state = ?, failure_reason = ?, finished_at = CURRENT_TIMESTAMP
        WHERE id = ? AND settled_at IS NULL
    ]], { run.state, tostring(reason or 'unknown'):sub(1, 128), run.dbId })
    GangCore.Audit({
        gangId = run.gangId,
        runId = run.dbId,
        action = 'mission_' .. run.state,
        targetType = 'mission',
        targetId = run.missionKey,
        metadata = { reason = reason },
    })
    broadcast(run, 'mrp_gangs:client:missionFinished', {
        success = false,
        reason = reason,
        summary = clientSummary(run),
    })
    clearRun(run)
end

local function eligibleParticipants(run)
    local elapsed = math.max(1, os.time() - run.startedAt)
    local result = {}
    for _, participant in ipairs(run.participants) do
        local activeSeconds = tonumber(participant.activeSeconds) or 0
        if activeSeconds <= 0 and GangCore.GetSourceByCitizenId(participant.citizenid) then
            activeSeconds = elapsed
        end
        local participation = math.min(1.0, activeSeconds / elapsed)
        if participation >= (Config.Reward.minimumParticipation or 0.60)
            and (participant.objectiveActions or 0) > 0 then
            result[#result + 1] = participant
        end
    end
    if #result == 0 and run.participants[1] then
        result[1] = run.participants[1]
    end
    return result
end

local function completeRun(run)
    if run.settled then return end
    local mission = Config.Missions[run.missionKey]
    local participants = eligibleParticipants(run)
    local performance = 1.0
    local ok, settlement = GangEconomy.SettleMission(run, mission, participants, performance)
    if not ok then return failRun(run, settlement or 'settlement_failed') end

    run.state = 'completed'
    MySQL.update.await([[
        UPDATE mrp_gang_mission_runs
        SET state = 'completed',
            performance_score = ?,
            finished_at = CURRENT_TIMESTAMP,
            settled_at = CURRENT_TIMESTAMP
        WHERE id = ? AND settled_at IS NULL
    ]], { performance, run.dbId })

    GangCore.Audit({
        gangId = run.gangId,
        runId = run.dbId,
        action = 'mission_completed',
        targetType = 'mission',
        targetId = run.missionKey,
        metadata = settlement,
    })
    broadcast(run, 'mrp_gangs:client:missionFinished', {
        success = true,
        settlement = settlement,
        summary = clientSummary(run),
    })
    clearRun(run)
end

local function startCurrentPhase(run)
    local phase = run.phases[run.phaseIndex]
    if not phase then return completeRun(run) end
    run.phaseStartedAt = os.time()
    run.checkpoints = nil
    run.checkpointIndex = nil
    run.lastCheckpointAt = nil
    run.actions = {}

    if phase.type == 'vehicle' and not run.missionVehicleEntity then
        if not run.vehicleModel then return failRun(run, 'mission_vehicle_model_missing') end
        local vehicle = CreateVehicle(
            joaat(run.vehicleModel),
            run.site.x,
            run.site.y,
            run.site.z,
            run.site.w or 0.0,
            true,
            true
        )
        if not vehicle or vehicle == 0 then return failRun(run, 'mission_vehicle_spawn_failed') end
        SetEntityRoutingBucket(vehicle, 0)
        SetEntityOrphanMode(vehicle, 2)
        SetVehicleNumberPlateText(vehicle, ('GANG%04d'):format(run.dbId % 10000))
        Entity(vehicle).state:set('mrpGangMissionRun', run.token, true)
        run.missionVehicleEntity = vehicle
        run.missionVehicleNetworkId = NetworkGetNetworkIdFromEntity(vehicle)
        broadcast(run, 'mrp_gangs:client:configureMissionVehicle', run.token, run.missionVehicleNetworkId)
    elseif (phase.type == 'rescue' or phase.type == 'capture') and not spawnMissionTarget(run, phase) then
        return failRun(run, 'mission_target_spawn_failed')
    elseif phase.type == 'eliminate' or phase.type == 'defend' then
        local ok, reason = GangEncounters.Start(run, phase)
        if not ok then return failRun(run, reason) end
        if not run.dispatchRolled then
            run.dispatchRolled = true
            local chance = tonumber(Config.Difficulties[run.difficulty].dispatchChance) or 0
            if math.random(1, 100) <= chance and GetResourceState('mrp_dispatch') == 'started' then
                pcall(function()
                    exports['mrp_dispatch']:CreateCall({
                        callType = 'gang_operation',
                        callTypeLabel = 'Galima ginkluota gaujos operacija',
                        x = run.site.x,
                        y = run.site.y,
                        z = run.site.z,
                        priority = run.difficulty == 'extreme' and 3 or 2,
                    })
                end)
            end
        end
    end

    persistPhase(run)
    if isContestable(run, phase) then
        publishContest(run, phase)
    else
        clearContest(run.token)
        run.contestActive = false
    end
    broadcast(run, 'mrp_gangs:client:missionPhase', GangObjectives.BuildClientPhase(run, phase))
end

local function advancePhase(run, source, payload)
    local phase = run.phases[run.phaseIndex]
    if not phase then return false, 'phase_missing' end
    if phase.type == 'enter' and not partyNear(run, run.site, 20.0, 1.0) then
        return false, 'party_not_at_entry'
    end
    if phase.type == 'extract' and not partyNear(run, run.extraction, 30.0, 0.60) then
        return false, 'party_not_at_extraction'
    end
    local ok, reason, phaseComplete = GangObjectives.Validate(run, phase, source, payload)
    if not ok then return false, reason end

    local participant = getParticipantBySource(run, source)
    if participant then
        participant.objectiveActions = (participant.objectiveActions or 0) + 1
        MySQL.update.await([[
            UPDATE mrp_gang_mission_participants
            SET objective_actions = objective_actions + 1
            WHERE run_id = ? AND citizenid = ?
        ]], { run.dbId, participant.citizenid })
    end
    if phase.cargo and participant then
        run.cargoCarrierCitizenId = participant.citizenid
        TriggerClientEvent('mrp_gangs:client:setMissionCargo', source, run.token, true)
    end

    if phase.type == 'checkpoint_run' and phaseComplete == false then
        broadcast(run, 'mrp_gangs:client:missionPhase', GangObjectives.BuildClientPhase(run, phase))
        return true, 'checkpoint_advanced'
    end

    if run.contestActive then
        clearContest(run.token)
        run.contestActive = false
    end

    if phase.type == 'eliminate' or phase.type == 'defend' then
        GangEncounters.Cleanup(run)
    elseif phase.type == 'rescue' or phase.type == 'capture' then
        run.missionTargetFreed = true
        if run.missionTargetEntity and DoesEntityExist(run.missionTargetEntity) then
            SetEntityInvincible(run.missionTargetEntity, false)
            FreezeEntityPosition(run.missionTargetEntity, false)
        end
        broadcast(
            run,
            'mrp_gangs:client:configureMissionTarget',
            run.token,
            run.missionTargetNetworkId,
            phase.type,
            true,
            source
        )
    elseif phase.type == 'enter' then
        local interior = Config.MissionInteriors[run.interiorKey]
        if not interior then return false, 'interior_missing' end
        run.inInterior = true
        setPartyBucket(run, run.bucketId)
        broadcast(
            run,
            'mrp_gangs:client:enterMissionInterior',
            run.token,
            GangUtils.CoordsToTable(interior.entry),
            run.site
        )
    elseif phase.type == 'exit' then
        run.inInterior = false
        GangEncounters.Cleanup(run)
        setPartyBucket(run, 0)
        if run.missionTargetEntity and DoesEntityExist(run.missionTargetEntity) then
            SetEntityRoutingBucket(run.missionTargetEntity, 0)
            SetEntityCoords(
                run.missionTargetEntity,
                run.site.x + 2.0,
                run.site.y + 2.0,
                run.site.z,
                false,
                false,
                false,
                false
            )
        end
        broadcast(run, 'mrp_gangs:client:leaveMissionInterior', run.token, run.site)
        if run.missionTargetNetworkId then
            broadcast(
                run,
                'mrp_gangs:client:configureMissionTarget',
                run.token,
                run.missionTargetNetworkId,
                run.missionTargetMode,
                true,
                source
            )
        end
    end

    run.phaseIndex = run.phaseIndex + 1
    startCurrentPhase(run)
    return true
end

local function readyParty(source, gang)
    local nearby = GangCore.GetNearbyGangParty(source, gang.gang_id)
    local ready = GangMissions.ReadyMembers[tonumber(gang.gang_id)] or {}
    local party = {}
    for _, member in ipairs(nearby) do
        local readiness = ready[member.citizenid]
        if member.source == source or (readiness and readiness.expiresAt >= os.time()) then
            member.missionRole = member.source == source and 'leader' or readiness.roleKey
            party[#party + 1] = member
        end
    end
    return party
end

function GangMissions.Start(source, missionKey, difficulty)
    source = tonumber(source)
    if not GangSystem.Ready then return false, 'system_not_ready' end
    if not GangCore.RateLimit(source, 'mission_start', Config.MissionStartRateLimitSec or 5) then
        return false, 'rate_limited'
    end
    if activeRunCount() >= (Config.MaxConcurrentMissionRuns or 8) then return false, 'server_mission_limit' end

    local gang = GangCore.GetPlayerGang(source)
    if not gang then return false, 'not_in_gang' end
    if GangRBAC and not GangRBAC.HasPermission(source, 'missions.start') then return false, 'permission_denied' end
    if GangMissions.RunByGang[tonumber(gang.gang_id)] then return false, 'gang_already_active' end

    local mission = Config.Missions[tostring(missionKey or '')]
    difficulty = tostring(difficulty or 'easy'):lower()
    if not mission or not missionAllowed(mission, gang.gang_type) then return false, 'mission_not_allowed' end
    if not difficultyAllowed(mission, difficulty) then return false, 'difficulty_not_allowed' end
    local lastStartedAt = MySQL.scalar.await([[
        SELECT UNIX_TIMESTAMP(started_at)
        FROM mrp_gang_mission_runs
        WHERE gang_id = ? AND mission_key = ?
        ORDER BY id DESC
        LIMIT 1
    ]], { gang.gang_id, mission.id })
    if lastStartedAt and os.time() - tonumber(lastStartedAt) < (tonumber(mission.cooldownSec) or 1800) then
        return false, 'mission_cooldown'
    end

    local player = GangCore.GetPlayer(source)
    local setupCost = tonumber(Config.Difficulties[difficulty].setupCost) or 0
    if setupCost > 0 and (tonumber(player.PlayerData.money.cash) or 0) < setupCost then
        return false, 'not_enough_setup_cash'
    end

    local party = readyParty(source, gang)
    if #party == 0 then return false, 'party_empty' end
    for _, participant in ipairs(party) do
        if GangMissions.RunByCitizen[participant.citizenid] then return false, 'party_member_busy' end
    end

    local site = pickSite(mission.sitePool)
    local extraction = site and pickExtraction(mission.sitePool, site)
    local bucketId = allocateBucket()
    if not site or not extraction or not bucketId then return false, 'mission_location_unavailable' end
    local token = GangUtils.RandomToken(('mission-%s'):format(gang.gang_id))
    local lockId = MySQL.update.await([[
        INSERT IGNORE INTO mrp_gang_mission_locks (gang_id, run_token)
        VALUES (?, ?)
    ]], { gang.gang_id, token })
    if not lockId or tonumber(lockId) == 0 then return false, 'gang_already_active' end

    if setupCost > 0 and not player.Functions.RemoveMoney('cash', setupCost, 'gang-mission-setup') then
        MySQL.update.await('DELETE FROM mrp_gang_mission_locks WHERE gang_id = ? AND run_token = ?', {
            gang.gang_id,
            token,
        })
        return false, 'setup_payment_failed'
    end

    local seed = math.random(100000, 2147483646)
    local dbId = MySQL.insert.await([[
        INSERT INTO mrp_gang_mission_runs
            (run_token, gang_id, mission_key, difficulty, state, phase_index, seed, bucket_id,
             leader_citizenid, site_json, interior_key)
        VALUES (?, ?, ?, ?, 'active', 1, ?, ?, ?, ?, ?)
    ]], {
        token,
        gang.gang_id,
        mission.id,
        difficulty,
        seed,
        bucketId,
        gang.citizenid,
        json.encode({ site = site, extraction = extraction }),
        mission.interior,
    })

    if not dbId then
        if setupCost > 0 then player.Functions.AddMoney('cash', setupCost, 'gang-mission-setup-refund') end
        MySQL.update.await('DELETE FROM mrp_gang_mission_locks WHERE gang_id = ? AND run_token = ?', {
            gang.gang_id,
            token,
        })
        return false, 'mission_persist_failed'
    end

    local run = {
        token = token,
        dbId = dbId,
        gangId = tonumber(gang.gang_id),
        gangType = gang.gang_type,
        missionKey = mission.id,
        difficulty = difficulty,
        state = 'active',
        seed = seed,
        bucketId = bucketId,
        leaderCitizenId = gang.citizenid,
        site = site,
        extraction = extraction,
        interiorKey = mission.interior,
        vehicleModel = mission.vehicleModel,
        phases = GangUtils.Copy(mission.phases),
        phaseIndex = 1,
        phaseStartedAt = os.time(),
        startedAt = os.time(),
        participants = {},
        inInterior = false,
        settled = false,
    }

    for _, member in ipairs(party) do
        local participant = {
            source = member.source,
            citizenid = member.citizenid,
            displayName = member.displayName,
            roleKey = member.missionRole or 'support',
            activeSeconds = 0,
            objectiveActions = 0,
            lastSeenAt = os.time(),
        }
        run.participants[#run.participants + 1] = participant
    end

    local participantsSaved = pcall(function()
        for _, participant in ipairs(run.participants) do
            local affected = MySQL.update.await([[
            INSERT INTO mrp_gang_mission_participants
                (run_id, citizenid, display_name, role_key)
            VALUES (?, ?, ?, ?)
            ]], { dbId, participant.citizenid, participant.displayName, participant.roleKey })
            if (tonumber(affected) or 0) <= 0 then error('participant_insert_failed') end
        end
    end)
    if not participantsSaved then
        MySQL.update.await('DELETE FROM mrp_gang_mission_runs WHERE id = ?', { dbId })
        MySQL.update.await('DELETE FROM mrp_gang_mission_locks WHERE gang_id = ? AND run_token = ?', {
            gang.gang_id,
            token,
        })
        if setupCost > 0 then player.Functions.AddMoney('cash', setupCost, 'gang-mission-setup-refund') end
        return false, 'party_persist_failed'
    end

    for _, participant in ipairs(run.participants) do
        GangMissions.RunByCitizen[participant.citizenid] = token
        GangMissions.RunBySource[participant.source] = token
    end

    GangMissions.Runs[token] = run
    GangMissions.RunByGang[run.gangId] = token
    GangCore.Audit({
        gangId = run.gangId,
        runId = run.dbId,
        actorCitizenId = gang.citizenid,
        actorSource = source,
        action = 'mission_started',
        targetType = 'mission',
        targetId = mission.id,
        metadata = { difficulty = difficulty, partySize = #party, setupCost = setupCost },
    })

    broadcast(run, 'mrp_gangs:client:missionStarted', clientSummary(run))
    startCurrentPhase(run)
    return true, clientSummary(run)
end

function GangMissions.GetBySource(source)
    local directToken = GangMissions.RunBySource[tonumber(source)]
    if directToken and GangMissions.Runs[directToken] then return GangMissions.Runs[directToken] end
    local player = GangCore.GetPlayer(source)
    if not player then return nil end
    local token = GangMissions.RunByCitizen[player.PlayerData.citizenid]
    return token and GangMissions.Runs[token] or nil
end

function GangMissions.Cancel(source, reason)
    local run = GangMissions.GetBySource(source)
    if not run then return false, 'mission_not_active' end
    local player = GangCore.GetPlayer(source)
    if not player then return false, 'player_missing' end
    if player.PlayerData.citizenid ~= run.leaderCitizenId
        and not GangCore.IsAdmin(source)
        and not (GangRBAC and GangRBAC.HasPermission(source, 'missions.cancel')) then
        return false, 'leader_only'
    end
    failRun(run, reason or 'cancelled_by_leader', 'cancelled')
    return true
end

local function boardFor(source)
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return { gang = nil, missions = {}, difficulties = Config.Difficulties } end
    local missions = {}
    for key, mission in pairs(Config.Missions) do
        if missionAllowed(mission, gang.gang_type) then
            missions[#missions + 1] = {
                id = key,
                label = mission.label,
                description = mission.description,
                category = mission.category,
                baseReward = mission.baseReward,
                baseReputation = mission.baseReputation,
                difficulties = mission.allowedDifficulties,
                hasInterior = mission.interior ~= nil,
            }
        end
    end
    table.sort(missions, function(left, right)
        if left.category == right.category then return left.label < right.label end
        return left.category < right.category
    end)
    return {
        gang = {
            id = gang.gang_id,
            label = gang.label,
            gangType = gang.gang_type,
            reputation = gang.reputation,
            treasury = gang.treasury,
        },
        missions = missions,
        difficulties = Config.Difficulties,
        active = GangMissions.GetBySource(source) and clientSummary(GangMissions.GetBySource(source)) or nil,
    }
end

GangMissions.GetBoard = boardFor

QBCore.Functions.CreateCallback('mrp_gangs:server:getMissionBoard', function(source, callback)
    if not GangCore.RateLimit(source, 'mission_board', 1) then
        return callback({ gang = nil, missions = {}, difficulties = Config.Difficulties, error = 'rate_limited' })
    end
    callback(boardFor(source))
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:startMission', function(source, callback, missionKey, difficulty)
    local ok, result = GangMissions.Start(source, missionKey, difficulty)
    callback({ ok = ok, result = result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:beginObjective', function(source, callback, token, phaseIndex)
    if not GangCore.RateLimit(source, 'mission_objective_begin', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    local run = GangMissions.GetBySource(source)
    if not run or run.token ~= tostring(token or '') then return callback({ ok = false, reason = 'mission_not_active' }) end
    if tonumber(phaseIndex) ~= run.phaseIndex then return callback({ ok = false, reason = 'stale_phase' }) end
    local ok, result = GangObjectives.Begin(run, run.phases[run.phaseIndex], source)
    callback({ ok = ok, result = result, reason = ok and nil or result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:completeObjective', function(source, callback, token, phaseIndex, payload)
    if not GangCore.RateLimit(source, 'mission_objective_complete', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    local run = GangMissions.GetBySource(source)
    if not run or run.token ~= tostring(token or '') then return callback({ ok = false, reason = 'mission_not_active' }) end
    if tonumber(phaseIndex) ~= run.phaseIndex then return callback({ ok = false, reason = 'stale_phase' }) end
    local ok, reason = advancePhase(run, source, payload)
    callback({ ok = ok, reason = reason })
end)

local function contestNear(source, contest)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not contest or not contest.target then return false end
    local radius = (Config.MissionContest and Config.MissionContest.radius) or 55.0
    return #(GetEntityCoords(ped) - vector3(contest.target.x, contest.target.y, contest.target.z)) <= radius
end

local function payContestSteal(source, run, thiefGang)
    local mission = Config.Missions[run.missionKey] or {}
    local difficulty = Config.Difficulties[run.difficulty] or {}
    local multiplier = (Config.MissionContest and Config.MissionContest.stealCashMultiplier) or 0.65
    local cash = GangUtils.Round((tonumber(mission.baseReward) or 0) * (difficulty.rewardMultiplier or 1.0) * multiplier)
    if cash > 0 then
        GangAdapters.Money.Add(source, 'cash', cash, 'gang-contest-steal')
    end
    local reputation = tonumber(Config.MissionContest and Config.MissionContest.stealReputation) or 10
    if reputation ~= 0 then
        GangCore.AddReputation(
            thiefGang.gang_id,
            reputation,
            'mission_contest_steal',
            'mission_run',
            run.dbId,
            thiefGang.citizenid
        )
    end
    GangCore.Audit({
        gangId = thiefGang.gang_id,
        runId = run.dbId,
        actorCitizenId = thiefGang.citizenid,
        actorSource = source,
        action = 'mission_contest_steal',
        targetType = 'mission',
        targetId = run.missionKey,
        metadata = {
            victimGangId = run.gangId,
            cash = cash,
            reputation = reputation,
        },
    })
    return cash, reputation
end

QBCore.Functions.CreateCallback('mrp_gangs:server:beginContestLoot', function(source, callback, token)
    if not GangCore.RateLimit(source, 'mission_contest_begin', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    token = tostring(token or '')
    local contest = GangMissions.Contests[token]
    local run = contest and GangMissions.Runs[token]
    if not contest or not run then return callback({ ok = false, reason = 'contest_not_active' }) end
    if tonumber(contest.phaseIndex) ~= tonumber(run.phaseIndex) then
        return callback({ ok = false, reason = 'stale_phase' })
    end
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return callback({ ok = false, reason = 'not_in_gang' }) end
    if tonumber(gang.gang_id) == tonumber(run.gangId) then
        return callback({ ok = false, reason = 'own_mission_use_board' })
    end
    if GangMissions.GetBySource(source) then
        return callback({ ok = false, reason = 'already_in_mission' })
    end
    if not contestNear(source, contest) then
        return callback({ ok = false, reason = 'not_at_objective' })
    end
    local phase = run.phases[run.phaseIndex]
    local ok, result = GangObjectives.Begin(run, phase, source)
    if not ok then return callback({ ok = false, reason = result }) end
    local bonus = tonumber(Config.MissionContest and Config.MissionContest.rivalDurationBonusMs) or 0
    if bonus > 0 and type(result) == 'table' then
        result.durationMs = (tonumber(result.durationMs) or 5000) + bonus
        local player = GangCore.GetPlayer(source)
        if player and run.actions and run.actions[player.PlayerData.citizenid] then
            run.actions[player.PlayerData.citizenid].durationMs = result.durationMs
        end
    end
    callback({ ok = true, result = result })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:completeContestLoot', function(source, callback, token, payload)
    if not GangCore.RateLimit(source, 'mission_contest_complete', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    token = tostring(token or '')
    local contest = GangMissions.Contests[token]
    local run = contest and GangMissions.Runs[token]
    if not contest or not run then return callback({ ok = false, reason = 'contest_not_active' }) end
    if tonumber(contest.phaseIndex) ~= tonumber(run.phaseIndex) then
        return callback({ ok = false, reason = 'stale_phase' })
    end
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return callback({ ok = false, reason = 'not_in_gang' }) end
    if tonumber(gang.gang_id) == tonumber(run.gangId) then
        return callback({ ok = false, reason = 'own_mission_use_board' })
    end
    if GangMissions.GetBySource(source) then
        return callback({ ok = false, reason = 'already_in_mission' })
    end
    if not contestNear(source, contest) then
        return callback({ ok = false, reason = 'not_at_objective' })
    end
    local phase = run.phases[run.phaseIndex]
    local ok, reason = GangObjectives.Validate(run, phase, source, payload or {})
    if not ok then return callback({ ok = false, reason = reason }) end

    local cash = payContestSteal(source, run, gang)
    GangCore.Notify(source, ('Pavogei operacijos krovinį (+$%s).'):format(cash), 'success')
    failRun(run, 'cargo_contested_stolen')
    callback({ ok = true, cash = cash })
end)

QBCore.Functions.CreateCallback('mrp_gangs:server:toggleMissionReady', function(source, callback, roleKey)
    if not GangCore.RateLimit(source, 'mission_ready', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    local gang = GangCore.GetPlayerGang(source)
    if not gang then return callback({ ok = false, reason = 'not_in_gang' }) end
    local gangId = tonumber(gang.gang_id)
    GangMissions.ReadyMembers[gangId] = GangMissions.ReadyMembers[gangId] or {}
    local current = GangMissions.ReadyMembers[gangId][gang.citizenid]
    if current and current.expiresAt >= os.time() then
        GangMissions.ReadyMembers[gangId][gang.citizenid] = nil
        return callback({ ok = true, ready = false })
    end
    roleKey = tostring(roleKey or 'support'):lower()
    if not Config.MissionRoles[roleKey] or roleKey == 'leader' then roleKey = 'support' end
    GangMissions.ReadyMembers[gangId][gang.citizenid] = {
        expiresAt = os.time() + Config.MissionReservationSec,
        roleKey = roleKey,
    }
    callback({ ok = true, ready = true, expiresIn = Config.MissionReservationSec, roleKey = roleKey })
end)

RegisterNetEvent('mrp_gangs:server:requestMissionResume', function()
    local source = source
    local run = GangMissions.GetBySource(source)
    if not run then return end
    local participant = getParticipantBySource(run, source)
    if participant then
        participant.source = source
        participant.disconnectedAt = nil
        participant.lastSeenAt = os.time()
    end
    GangMissions.RunBySource[source] = run.token
    if run.inInterior then
        SetPlayerRoutingBucket(source, run.bucketId)
        local interior = Config.MissionInteriors[run.interiorKey]
        TriggerClientEvent(
            'mrp_gangs:client:enterMissionInterior',
            source,
            run.token,
            GangUtils.CoordsToTable(interior.entry),
            run.site
        )
    end
    TriggerClientEvent('mrp_gangs:client:missionStarted', source, clientSummary(run))
    if run.missionVehicleNetworkId then
        TriggerClientEvent('mrp_gangs:client:configureMissionVehicle', source, run.token, run.missionVehicleNetworkId)
    end
    if run.missionTargetNetworkId then
        TriggerClientEvent(
            'mrp_gangs:client:configureMissionTarget',
            source,
            run.token,
            run.missionTargetNetworkId,
            run.missionTargetMode,
            run.missionTargetFreed == true,
            source
        )
    end
    if participant and run.cargoCarrierCitizenId == participant.citizenid then
        TriggerClientEvent('mrp_gangs:client:setMissionCargo', source, run.token, true)
    end
    TriggerClientEvent('mrp_gangs:client:missionPhase', source, GangObjectives.BuildClientPhase(run, run.phases[run.phaseIndex]))
end)

RegisterNetEvent('mrp_gangs:server:cancelMission', function()
    GangMissions.Cancel(source, 'cancelled_by_leader')
end)

exports('GetActiveMission', function(source)
    local run = GangMissions.GetBySource(source)
    return run and clientSummary(run) or nil
end)
exports('StartGangMission', GangMissions.Start)
exports('CancelGangMission', GangMissions.Cancel)

AddEventHandler('playerDropped', function()
    local source = source
    GangMissions.ContestWatchers[source] = nil
    local token = GangMissions.RunBySource[source]
    local run = token and GangMissions.Runs[token] or GangMissions.GetBySource(source)
    if not run then return end
    local participant = getParticipantBySource(run, source)
    if participant then
        participant.disconnectedAt = os.time()
        MySQL.update.await([[
            UPDATE mrp_gang_mission_participants
            SET left_at = CURRENT_TIMESTAMP, active_seconds = ?
            WHERE run_id = ? AND citizenid = ?
        ]], { participant.activeSeconds or 0, run.dbId, participant.citizenid })
    end
    GangMissions.RunBySource[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, run in pairs(GangMissions.Runs) do
        GangEncounters.Cleanup(run)
        if run.missionVehicleEntity and DoesEntityExist(run.missionVehicleEntity) then
            DeleteEntity(run.missionVehicleEntity)
        end
        if run.missionTargetEntity and DoesEntityExist(run.missionTargetEntity) then
            DeleteEntity(run.missionTargetEntity)
        end
        setPartyBucket(run, 0)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, run in pairs(GangMissions.Runs) do
            local vehicleFailed = run.missionVehicleEntity
                and (not DoesEntityExist(run.missionVehicleEntity) or GetEntityHealth(run.missionVehicleEntity) <= 0)
            local targetFailed = run.missionTargetFreed and run.missionTargetEntity
                and (not DoesEntityExist(run.missionTargetEntity) or IsEntityDead(run.missionTargetEntity))
            if vehicleFailed or targetFailed then
                failRun(run, vehicleFailed and 'mission_vehicle_destroyed' or 'mission_target_lost')
            else
            local onlineCount = 0
            local nextLeader = nil
            for _, participant in ipairs(run.participants) do
                local source = GangCore.GetSourceByCitizenId(participant.citizenid)
                if source then
                    onlineCount = onlineCount + 1
                    nextLeader = nextLeader or participant
                    participant.activeSeconds = (participant.activeSeconds or 0) + 30
                    participant.lastSeenAt = now
                    participant.disconnectedAt = nil
                elseif participant.disconnectedAt
                    and now - participant.disconnectedAt > (Config.ReconnectGraceSec or 180) then
                    participant.eligible = false
                end
            end
            if run.cargoCarrierCitizenId then
                local carrierSource = GangCore.GetSourceByCitizenId(run.cargoCarrierCitizenId)
                if not carrierSource and nextLeader then
                    run.cargoCarrierCitizenId = nextLeader.citizenid
                    local nextSource = GangCore.GetSourceByCitizenId(nextLeader.citizenid)
                    if nextSource then
                        TriggerClientEvent('mrp_gangs:client:setMissionCargo', nextSource, run.token, true)
                        GangCore.Notify(nextSource, 'Perėmei operacijos krovinį.', 'primary')
                    end
                end
            end
            local leader = getParticipant(run, run.leaderCitizenId)
            if leader and leader.disconnectedAt
                and now - leader.disconnectedAt > (Config.ReconnectGraceSec or 180)
                and nextLeader and nextLeader.citizenid ~= run.leaderCitizenId then
                run.leaderCitizenId = nextLeader.citizenid
                MySQL.update.await('UPDATE mrp_gang_mission_runs SET leader_citizenid = ? WHERE id = ?', {
                    run.leaderCitizenId,
                    run.dbId,
                })
                broadcast(run, 'mrp_gangs:client:missionLeaderChanged', run.leaderCitizenId, nextLeader.displayName)
            end
            if onlineCount == 0 then
                local latestDisconnect = 0
                for _, participant in ipairs(run.participants) do
                    latestDisconnect = math.max(latestDisconnect, participant.disconnectedAt or now)
                end
                if now - latestDisconnect > (Config.ReconnectGraceSec or 180) then
                    failRun(run, 'party_disconnected')
                end
            end
            end
        end
    end
end)

--- Rival gangs discover contested outdoor loot by walking near the site (no city-wide alert/blip).
CreateThread(function()
    while true do
        local hasContests = next(GangMissions.Contests) ~= nil
        local hasWatchers = next(GangMissions.ContestWatchers) ~= nil
        if hasContests or hasWatchers then
            syncContestDiscoveries()
            Wait(1500)
        else
            Wait(4000)
        end
    end
end)

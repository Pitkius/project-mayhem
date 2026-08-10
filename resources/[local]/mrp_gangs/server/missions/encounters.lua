GangEncounters = GangEncounters or {}

local archetypePools = {
    easy = { 'thug', 'cutter', 'brawler', 'thug' },
    medium = { 'patrol', 'guard', 'guard', 'rusher', 'suppressor' },
    hard = { 'guard', 'rusher', 'suppressor', 'marksman', 'armored' },
    extreme = { 'rusher', 'suppressor', 'marksman', 'armored', 'commander' },
}

local function partyThreatMultiplier(partySize)
    return math.min(
        Config.Encounter.threatMultiplierMax or 2.10,
        1.0 + ((math.max(1, partySize) - 1) * (Config.Encounter.partyThreatGrowth or 0.42))
    )
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

local function offsetSpawn(origin, offset)
    if not origin or not offset then return nil end
    local ox, oy, oz, ow = offsetXYZW(offset)
    return {
        x = (tonumber(origin.x) or 0.0) + ox,
        y = (tonumber(origin.y) or 0.0) + oy,
        z = (tonumber(origin.z) or 0.0) + oz,
        w = ow or 0.0,
    }
end

local function isEntityDeadSafe(entity)
    return GangUtils.IsEntityDeadSafe(entity)
end

local function outdoorSpawn(site, index, total)
    local radius = 12.0 + ((index % 3) * 3.0)
    local angle = ((index - 1) / math.max(1, total)) * math.pi * 2.0
    return {
        x = site.x + math.cos(angle) * radius,
        y = site.y + math.sin(angle) * radius,
        z = site.z + 0.5,
        w = math.deg(angle + math.pi),
    }
end

local function pickGangPool(run)
    local pools = Config.Encounter.gangModelPools or {}
    local keys = {}
    for key in pairs(pools) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    if #keys == 0 then
        return Config.Encounter.defaultModels or { 'g_m_y_mexgoon_01' }, 'default'
    end
    local idx = (((tonumber(run.seed) or 1) + ((run.encounter and run.encounter.wave) or 1) * 17) % #keys) + 1
    local key = keys[idx]
    return pools[key], key
end

local function selectArchetypes(run, phase, budgetScale)
    local difficulty = Config.Difficulties[run.difficulty] or {}
    local budget = math.floor(
        (difficulty.threatBudget or 100)
        * partyThreatMultiplier(#run.participants)
        * (tonumber(budgetScale) or 1.0)
    )
    local cap = difficulty.maxActiveNpc or 6
    if run.interiorKey and run.inInterior then
        local interior = Config.MissionInteriors[run.interiorKey]
        cap = math.min(cap, interior and interior.maxNpc or Config.Encounter.interiorActiveNpcCap or 12)
    elseif run.compoundKey then
        local compound = Config.MissionCompounds[run.compoundKey]
        cap = math.min(cap, compound and compound.maxNpc or Config.Encounter.exteriorActiveNpcCap or 16)
    else
        cap = math.min(cap, Config.Encounter.exteriorActiveNpcCap or 16)
    end

    if run.difficulty == 'easy' or difficulty.meleeOnly then
        cap = math.min(cap, 2)
    end

    if phase.encounter == 'search' then budget = math.floor(budget * 0.80) end
    if phase.encounter == 'defence' then budget = math.floor(budget * 1.15) end

    local pool = archetypePools[run.difficulty] or archetypePools.easy
    local selected = {}

    if run.difficulty == 'easy' or difficulty.meleeOnly then
        local count = math.random(difficulty.minNpc or 1, math.max(difficulty.minNpc or 1, math.min(2, cap)))
        for _ = 1, count do
            selected[#selected + 1] = pool[math.random(1, #pool)]
        end
        return selected
    end

    local attempts = 0
    while budget >= 12 and #selected < cap and attempts < 100 do
        attempts = attempts + 1
        local archetype = pool[math.random(1, #pool)]
        local definition = Config.Encounter.archetypes[archetype]
        if definition and definition.cost <= budget then
            selected[#selected + 1] = archetype
            budget = budget - definition.cost
        end
    end
    local minCount = math.min(difficulty.minNpc or 3, cap)
    while #selected < minCount do
        selected[#selected + 1] = pool[1] or 'patrol'
    end
    return selected
end

local function participantSources(run)
    local sources = {}
    for _, participant in ipairs(run.participants) do
        local source = GangCore.GetSourceByCitizenId(participant.citizenid)
        if source then sources[#sources + 1] = source end
    end
    return sources
end

local function scheduleEntityDelete(entity, delaySec)
    if not entity or entity == 0 then return end
    CreateThread(function()
        Wait(math.max(5, tonumber(delaySec) or 45) * 1000)
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end)
end

local function notifyEncounter(run, networkIds, wave, maxWaves, staging)
    for _, source in ipairs(participantSources(run)) do
        TriggerClientEvent(
            'mrp_gangs:client:configureEncounter',
            source,
            run.token,
            networkIds,
            wave,
            maxWaves,
            staging == true
        )
    end
end

local function pickSpawnCoords(run, index, total, preferDoors)
    local interior = run.inInterior and run.interiorKey and Config.MissionInteriors[run.interiorKey]
    local compound = (not run.inInterior) and run.compoundKey and Config.MissionCompounds[run.compoundKey]
    local stagingCfg = Config.Encounter.staging or {}
    local useDoors = preferDoors and stagingCfg.useDoorSpawnsFirst ~= false

    if useDoors and interior and interior.doorSpawns and #interior.doorSpawns > 0 then
        return GangUtils.CoordsToTable(interior.doorSpawns[((index - 1) % #interior.doorSpawns) + 1])
    end
    if useDoors and compound and compound.doorSpawns and #compound.doorSpawns > 0 then
        return offsetSpawn(run.site, compound.doorSpawns[((index - 1) % #compound.doorSpawns) + 1])
    end
    if interior and interior.enemySpawns and #interior.enemySpawns > 0 then
        return GangUtils.CoordsToTable(interior.enemySpawns[((index - 1) % #interior.enemySpawns) + 1])
    end
    if compound and compound.enemySpawns and #compound.enemySpawns > 0 then
        return offsetSpawn(run.site, compound.enemySpawns[((index - 1) % #compound.enemySpawns) + 1])
    end
    return outdoorSpawn(run.site, index, total)
end

local function spawnWave(run, opts)
    opts = opts or {}
    local encounter = run.encounter
    local staging = opts.staging == true
    local preferDoors = opts.preferDoors == true or (staging and (Config.Encounter.staging or {}).useDoorSpawnsFirst ~= false)
    local replaceAlive = opts.replaceAlive ~= false

    if replaceAlive then
        for _, entity in ipairs(encounter.entities or {}) do
            if DoesEntityExist(entity) then
                scheduleEntityDelete(entity, (Config.CorpseLoot and Config.CorpseLoot.cleanupSec) or Config.Encounter.corpseCleanupSec or 45)
            end
        end
        encounter.entities = {}
        encounter.networkIds = {}
    end

    encounter.looted = encounter.looted or {}
    local waveScale = encounter.wave == 1 and 1.0 or 0.65
    local archetypes = selectArchetypes(run, encounter.phase or { type = 'eliminate' }, waveScale)
    local models, gangKey = pickGangPool(run)
    encounter.gangKey = gangKey
    local encounterBucket = run.inInterior and run.bucketId or 0

    for index, archetype in ipairs(archetypes) do
        local spawn = pickSpawnCoords(run, index, #archetypes, preferDoors)
        local model = joaat(models[((index - 1) % #models) + 1])
        local ped = CreatePed(4, model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, true)
        if ped and ped ~= 0 then
            SetEntityRoutingBucket(ped, encounterBucket)
            GangUtils.SetEntityOrphanMode(ped, 2)
            local definition = Config.Encounter.archetypes[archetype] or {}
            local weapon = definition.weapon or 'WEAPON_BAT'
            if (run.difficulty == 'easy' or (Config.Difficulties[run.difficulty] or {}).meleeOnly) and not definition.melee then
                weapon = 'WEAPON_BAT'
            end
            SetPedArmour(ped, tonumber(definition.armor) or 0)
            Entity(ped).state:set('mrpGangMissionRun', run.token, true)
            Entity(ped).state:set('mrpGangArchetype', archetype, true)
            Entity(ped).state:set('mrpGangEncounterWave', encounter.wave, true)
            Entity(ped).state:set('mrpGangWeapon', weapon, true)
            Entity(ped).state:set('mrpGangFaction', gangKey, true)
            Entity(ped).state:set('mrpGangStaging', staging and 'idle' or 'armed', true)
            local netId = GangUtils.GetNetworkIdSafe(ped, 2500)
            if not netId then
                DeleteEntity(ped)
            else
                encounter.entities[#encounter.entities + 1] = ped
                local entry = {
                    networkId = netId,
                    archetype = archetype,
                    weapon = weapon,
                    accuracy = definition.accuracy or 20,
                    melee = definition.melee == true or run.difficulty == 'easy',
                    gangKey = gangKey,
                    staging = staging,
                }
                encounter.networkIds[#encounter.networkIds + 1] = entry
                run.corpseRegistry = run.corpseRegistry or {}
                run.corpseRegistry[netId] = {
                    archetype = archetype,
                    weapon = weapon,
                    looted = false,
                }
            end
        end
    end

    if #encounter.entities == 0 then
        encounter.spawnFailed = true
        return false, 'encounter_spawn_failed'
    end

    encounter.staged = staging
    notifyEncounter(run, encounter.networkIds, encounter.wave, encounter.maxWaves, staging)
    return true
end

local function computeMaxWaves(run, phase)
    if phase.type == 'defend' then
        return run.difficulty == 'extreme' and 3
            or (run.difficulty == 'hard' or run.difficulty == 'medium') and 2
            or 1
    elseif phase.type == 'eliminate' and run.difficulty == 'extreme' then
        return 2
    end
    return 1
end

local function activateStagedEncounter(run)
    local encounter = run.encounter
    if not encounter then return false end
    encounter.staged = false
    encounter.armedAt = os.time()
    for _, ped in ipairs(encounter.entities or {}) do
        if DoesEntityExist(ped) and not isEntityDeadSafe(ped) then
            Entity(ped).state:set('mrpGangStaging', 'armed', true)
        end
    end
    for _, entry in ipairs(encounter.networkIds or {}) do
        entry.staging = false
    end
    for _, source in ipairs(participantSources(run)) do
        TriggerClientEvent(
            'mrp_gangs:client:activateEncounterAggro',
            source,
            run.token,
            encounter.networkIds,
            encounter.wave,
            encounter.maxWaves
        )
    end
    return true
end

--- Pre-spawn wave 1 near doors on enter (idle, no combat yet).
function GangEncounters.PreStage(run)
    if not run then return false end
    if run.encounter and #(run.encounter.entities or {}) > 0 then return true end
    run.encounter = {
        startedAt = os.time(),
        entities = {},
        networkIds = {},
        looted = {},
        spawnFailed = false,
        phase = { type = 'eliminate', encounter = 'assault' },
        wave = 1,
        maxWaves = 1,
        clearedAt = nil,
        staged = true,
    }
    return spawnWave(run, { staging = true, preferDoors = true, replaceAlive = true })
end

function GangEncounters.Start(run, phase)
    local maxWaves = computeMaxWaves(run, phase)
    if run.encounter and run.encounter.staged and #(run.encounter.entities or {}) > 0 then
        run.encounter.phase = GangUtils.Copy(phase)
        run.encounter.maxWaves = maxWaves
        run.encounter.wave = 1
        run.encounter.clearedAt = nil
        run.encounter.spawnFailed = false
        run.encounter.pendingReinforceAt = nil
        return activateStagedEncounter(run)
    end

    GangEncounters.Cleanup(run)
    run.encounter = {
        startedAt = os.time(),
        entities = {},
        networkIds = {},
        looted = {},
        spawnFailed = false,
        phase = GangUtils.Copy(phase),
        wave = 1,
        maxWaves = maxWaves,
        clearedAt = nil,
        staged = true,
    }
    local ok, reason = spawnWave(run, { staging = true, preferDoors = true, replaceAlive = true })
    if not ok then return false, reason end
    --- Brief idle even when combat starts without a prior enter pre-stage.
    CreateThread(function()
        local token = run.token
        Wait(math.max(2, tonumber((Config.Encounter.staging or {}).idleSec) or 10) * 1000)
        if not run.encounter or run.token ~= token then return end
        if run.encounter.staged then
            activateStagedEncounter(run)
        end
    end)
    return true
end

function GangEncounters.IsCleared(run)
    if not run.encounter or run.encounter.spawnFailed then return false end
    if run.encounter.staged then return false end

    for _, entity in ipairs(run.encounter.entities or {}) do
        if DoesEntityExist(entity) and not isEntityDeadSafe(entity) then return false end
    end

    if run.encounter.wave < run.encounter.maxWaves then
        local delay = tonumber(Config.Encounter.reinforcementDelaySec) or 12
        if not run.encounter.pendingReinforceAt then
            run.encounter.pendingReinforceAt = os.time() + delay
            return false
        end
        if os.time() < run.encounter.pendingReinforceAt then
            return false
        end
        run.encounter.wave = run.encounter.wave + 1
        run.encounter.clearedAt = nil
        run.encounter.pendingReinforceAt = nil
        --- Reinforcements use deeper enemySpawns (not doors in player's face).
        local ok = spawnWave(run, { staging = false, preferDoors = false, replaceAlive = true })
        if not ok then return false end
        return false
    end

    if not run.encounter.clearedAt then
        run.encounter.clearedAt = os.time()
    end
    local grace = tonumber(Config.CorpseLoot and Config.CorpseLoot.clearGraceSec) or 18
    if (os.time() - run.encounter.clearedAt) < grace then
        return false
    end
    return true
end

function GangEncounters.Cleanup(run)
    if not run or not run.encounter then return end
    local delay = (Config.CorpseLoot and Config.CorpseLoot.cleanupSec)
        or Config.Encounter.corpseCleanupSec
        or 45
    for _, entity in ipairs(run.encounter.entities or {}) do
        if DoesEntityExist(entity) then
            scheduleEntityDelete(entity, delay)
        end
    end
    run.encounter = nil
end

function GangEncounters.TryLootCorpse(source, run, networkId)
    if not run then return false, 'mission_not_active' end
    networkId = tonumber(networkId)
    if not networkId then return false, 'invalid_corpse' end

    run.corpseRegistry = run.corpseRegistry or {}
    local meta = run.corpseRegistry[networkId]
    if not meta then return false, 'invalid_corpse' end
    if meta.looted or (run.encounter and run.encounter.looted and run.encounter.looted[networkId]) then
        return false, 'corpse_already_looted'
    end

    local entity = NetworkGetEntityFromNetworkId(networkId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 'corpse_gone'
    end
    if not isEntityDeadSafe(entity) then return false, 'npc_still_alive' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'player_missing' end
    local playerCoords = GetEntityCoords(ped)
    local corpseCoords = GetEntityCoords(entity)
    local maxDist = tonumber(Config.CorpseLoot and Config.CorpseLoot.maxDistance) or 2.4
    if #(playerCoords - corpseCoords) > (maxDist + 1.25) then
        return false, 'corpse_too_far'
    end

    meta.looted = true
    if run.encounter then
        run.encounter.looted = run.encounter.looted or {}
        run.encounter.looted[networkId] = true
    end
    Entity(entity).state:set('mrpGangLooted', true, true)

    local weapon = meta.weapon
        or (Entity(entity).state and Entity(entity).state.mrpGangWeapon)
        or 'WEAPON_BAT'
    local drops = GangEconomy.RollCorpseLoot(run.difficulty, weapon, meta.archetype)
    local ok, granted = GangEconomy.GrantCorpseLoot(source, run, drops)
    if not ok then
        meta.looted = false
        if run.encounter and run.encounter.looted then
            run.encounter.looted[networkId] = nil
        end
        return false, granted or 'loot_failed'
    end

    local player = GangCore.GetPlayer(source)
    GangCore.Audit({
        gangId = run.gangId,
        runId = run.dbId,
        actorCitizenId = player and player.PlayerData.citizenid,
        actorSource = source,
        action = 'corpse_loot',
        targetType = 'mission_run',
        targetId = run.token,
        metadata = {
            networkId = networkId,
            archetype = meta.archetype,
            weapon = weapon,
            granted = granted,
        },
    })

    return true, granted
end

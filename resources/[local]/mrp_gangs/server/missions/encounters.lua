GangEncounters = GangEncounters or {}

local archetypePools = {
    easy = { 'lookout', 'patrol', 'patrol', 'guard' },
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

local function outdoorSpawn(site, index, total)
    local radius = 24.0 + ((index % 3) * 5.0)
    local angle = ((index - 1) / math.max(1, total)) * math.pi * 2.0
    return {
        x = site.x + math.cos(angle) * radius,
        y = site.y + math.sin(angle) * radius,
        z = site.z + 0.5,
        w = math.deg(angle + math.pi),
    }
end

local function selectArchetypes(run, phase, budgetScale)
    local difficulty = Config.Difficulties[run.difficulty]
    local budget = math.floor(
        (difficulty.threatBudget or 100)
        * partyThreatMultiplier(#run.participants)
        * (tonumber(budgetScale) or 1.0)
    )
    local cap = difficulty.maxActiveNpc or 6
    if run.interiorKey then
        local interior = Config.MissionInteriors[run.interiorKey]
        cap = math.min(cap, interior and interior.maxNpc or Config.Encounter.interiorActiveNpcCap or 12)
    else
        cap = math.min(cap, Config.Encounter.exteriorActiveNpcCap or 16)
    end
    if phase.encounter == 'search' then budget = math.floor(budget * 0.80) end
    if phase.encounter == 'defence' then budget = math.floor(budget * 1.15) end

    local pool = archetypePools[run.difficulty] or archetypePools.easy
    local selected = {}
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
    while #selected < math.min(3, cap) do selected[#selected + 1] = 'patrol' end
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

local function spawnWave(run)
    local encounter = run.encounter
    for _, entity in ipairs(encounter.entities or {}) do
        if DoesEntityExist(entity) then
            scheduleEntityDelete(entity, (Config.CorpseLoot and Config.CorpseLoot.cleanupSec) or Config.Encounter.corpseCleanupSec or 45)
        end
    end
    encounter.entities = {}
    encounter.networkIds = {}
    encounter.looted = encounter.looted or {}
    local waveScale = encounter.wave == 1 and 1.0 or 0.65
    local archetypes = selectArchetypes(run, encounter.phase, waveScale)
    local interior = run.interiorKey and Config.MissionInteriors[run.interiorKey]
    local models = Config.Encounter.defaultModels
    local encounterBucket = run.inInterior and run.bucketId or 0

    for index, archetype in ipairs(archetypes) do
        local spawn
        if interior and interior.enemySpawns and #interior.enemySpawns > 0 then
            spawn = GangUtils.CoordsToTable(interior.enemySpawns[((index - 1) % #interior.enemySpawns) + 1])
        else
            spawn = outdoorSpawn(run.site, index, #archetypes)
        end
        local model = joaat(models[((index - 1) % #models) + 1])
        local ped = CreatePed(4, model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, true)
        if ped and ped ~= 0 then
            SetEntityRoutingBucket(ped, encounterBucket)
            GangUtils.SetEntityOrphanMode(ped, 2)
            local definition = Config.Encounter.archetypes[archetype]
            local weapon = definition.weapon or 'WEAPON_PISTOL'
            SetPedArmour(ped, tonumber(definition.armor) or 0)
            Entity(ped).state:set('mrpGangMissionRun', run.token, true)
            Entity(ped).state:set('mrpGangArchetype', archetype, true)
            Entity(ped).state:set('mrpGangEncounterWave', encounter.wave, true)
            Entity(ped).state:set('mrpGangWeapon', weapon, true)
            encounter.entities[#encounter.entities + 1] = ped
            local netId = NetworkGetNetworkIdFromEntity(ped)
            local entry = {
                networkId = netId,
                archetype = archetype,
                weapon = weapon,
                accuracy = definition.accuracy,
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

    if #encounter.entities == 0 then
        encounter.spawnFailed = true
        return false, 'encounter_spawn_failed'
    end

    for _, source in ipairs(participantSources(run)) do
        TriggerClientEvent(
            'mrp_gangs:client:configureEncounter',
            source,
            run.token,
            encounter.networkIds,
            encounter.wave,
            encounter.maxWaves
        )
    end
    return true
end

function GangEncounters.Start(run, phase)
    GangEncounters.Cleanup(run)
    local maxWaves = 1
    if phase.type == 'defend' then
        maxWaves = run.difficulty == 'extreme' and 3
            or (run.difficulty == 'hard' or run.difficulty == 'medium') and 2
            or 1
    elseif phase.type == 'eliminate' and run.difficulty == 'extreme' then
        maxWaves = 2
    end
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
    }
    return spawnWave(run)
end

function GangEncounters.IsCleared(run)
    if not run.encounter or run.encounter.spawnFailed then return false end
    for _, entity in ipairs(run.encounter.entities or {}) do
        if DoesEntityExist(entity) and not IsEntityDead(entity) then return false end
    end
    if run.encounter.wave < run.encounter.maxWaves then
        run.encounter.wave = run.encounter.wave + 1
        run.encounter.clearedAt = nil
        local ok = spawnWave(run)
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
    if not IsEntityDead(entity) then return false, 'npc_still_alive' end

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
        or 'WEAPON_PISTOL'
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

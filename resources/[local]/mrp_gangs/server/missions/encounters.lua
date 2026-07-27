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

local function spawnWave(run)
    local encounter = run.encounter
    for _, entity in ipairs(encounter.entities or {}) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    encounter.entities = {}
    encounter.networkIds = {}
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
            SetPedArmour(ped, tonumber(definition.armor) or 0)
            Entity(ped).state:set('mrpGangMissionRun', run.token, true)
            Entity(ped).state:set('mrpGangArchetype', archetype, true)
            Entity(ped).state:set('mrpGangEncounterWave', encounter.wave, true)
            encounter.entities[#encounter.entities + 1] = ped
            encounter.networkIds[#encounter.networkIds + 1] = {
                networkId = NetworkGetNetworkIdFromEntity(ped),
                archetype = archetype,
                weapon = definition.weapon,
                accuracy = definition.accuracy,
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
        spawnFailed = false,
        phase = GangUtils.Copy(phase),
        wave = 1,
        maxWaves = maxWaves,
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
        local ok = spawnWave(run)
        if not ok then return false end
        return false
    end
    return true
end

function GangEncounters.Cleanup(run)
    if not run or not run.encounter then return end
    for _, entity in ipairs(run.encounter.entities or {}) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    run.encounter = nil
end

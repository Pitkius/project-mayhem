local QBCore = GangClient.QBCore

local activeMission = nil
local activePhase = nil
local objectiveBlip = nil
local objectiveBusy = false
local nextAutomaticCheck = 0
local enemyRelationshipGroup = nil
local missionReturnCoords = nil
local missionCargoProp = nil
local contestedObjective = nil
local contestedBusy = false
local corpseBusy = false
local corpseTargetRegistered = false
local OBJECTIVE_ZONE = 'mrp_gangs_mission_objective'
local CONTEST_ZONE = 'mrp_gangs_contest_loot'
local CORPSE_TARGET_LABEL = 'Apiplėšti NPC'
local actionPhaseTypes = {
    interact = true,
    breach = true,
    search = true,
    collect = true,
    sabotage = true,
    rescue = true,
    capture = true,
}

-- Approach auto-confirms on marker; enter/exit/extract use E at checkpoint (no qb-target arrival).
local autoCompletePhaseTypes = {
    approach = true,
}

local promptPhaseTypes = {
    enter = true,
    exit = true,
    extract = true,
    vehicle = true,
    checkpoint_run = true,
}

local showEnterPrompt = false
local prepProgressActive = false

local function nuiMission(payload)
    SendNUIMessage(payload)
end

local function hidePrepProgress()
    if not prepProgressActive then return end
    prepProgressActive = false
    nuiMission({ action = 'missionProgressHide' })
end

local function showPrepProgress(label, durationMs)
    prepProgressActive = true
    nuiMission({
        action = 'missionProgressShow',
        label = label or 'Ruošiama...',
        durationMs = tonumber(durationMs) or 5000,
    })
end

local function drawHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function hasTarget()
    return GetResourceState('qb-target') == 'started'
end

local function removeTargetZone(name)
    if not hasTarget() then return end
    pcall(function()
        exports['qb-target']:RemoveZone(name)
    end)
end

local function clearObjectiveTarget()
    removeTargetZone(OBJECTIVE_ZONE)
end

local function clearContestTarget()
    removeTargetZone(CONTEST_ZONE)
end

local function clearMissionTargets()
    clearObjectiveTarget()
    clearContestTarget()
end

local function removeObjectiveBlip()
    if objectiveBlip and DoesBlipExist(objectiveBlip) then RemoveBlip(objectiveBlip) end
    objectiveBlip = nil
end

local function clearMissionCargo()
    if missionCargoProp and DoesEntityExist(missionCargoProp) then DeleteEntity(missionCargoProp) end
    missionCargoProp = nil
end

local function clearContestedObjective()
    contestedObjective = nil
    contestedBusy = false
    clearContestTarget()
end

local function lootCorpseEntity(entity)
    if corpseBusy or objectiveBusy or not activeMission then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) or not IsEntityDead(entity) then return end
    local state = Entity(entity).state
    if not state or state.mrpGangMissionRun ~= activeMission.token or state.mrpGangLooted then return end
    local networkId = NetworkGetNetworkIdFromEntity(entity)
    if not networkId or networkId == 0 then return end

    corpseBusy = true
    local duration = tonumber(Config.CorpseLoot and Config.CorpseLoot.searchDurationMs) or 3500
    QBCore.Functions.Progressbar(
        ('gang_corpse_%s_%s'):format(activeMission.token, networkId),
        'Apieškai NPC...',
        duration,
        false,
        true,
        {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        { animDict = 'amb@medic@standing@kneel@base', anim = 'base', flags = 1 },
        {},
        {},
        function()
            QBCore.Functions.TriggerCallback('mrp_gangs:server:lootCorpse', function(response)
                corpseBusy = false
                if not response or not response.ok then
                    return GangClient.Notify(GangClient.Reason(response and response.reason), 'error')
                end
                local granted = response.result or {}
                if #granted == 0 then
                    GangClient.Notify('Nieko vertingo neradai.', 'primary')
                else
                    local bits = {}
                    for _, row in ipairs(granted) do
                        if row.worth then
                            bits[#bits + 1] = ('$%s nešvarių'):format(row.worth)
                        elseif row.quality then
                            bits[#bits + 1] = ('%s (būklė %d%%)'):format(row.item, math.floor(row.quality))
                        else
                            bits[#bits + 1] = ('%sx %s'):format(row.amount or 1, row.item)
                        end
                    end
                    GangClient.Notify('Radiniai: ' .. table.concat(bits, ', '), 'success')
                end
            end, activeMission.token, networkId)
        end,
        function()
            corpseBusy = false
            GangClient.Notify('Kratosimas nutrauktas.', 'error')
        end
    )
end

local function registerCorpseTarget()
    if corpseTargetRegistered or not hasTarget() then return end
    exports['qb-target']:AddGlobalPed({
        options = {
            {
                num = 1,
                type = 'client',
                icon = 'fas fa-search',
                label = CORPSE_TARGET_LABEL,
                canInteract = function(entity)
                    if not activeMission or corpseBusy or objectiveBusy then return false end
                    if not entity or entity == 0 or not DoesEntityExist(entity) or IsPedAPlayer(entity) then return false end
                    if not IsEntityDead(entity) then return false end
                    local state = Entity(entity).state
                    return state
                        and state.mrpGangMissionRun == activeMission.token
                        and not state.mrpGangLooted
                end,
                action = function(entity)
                    lootCorpseEntity(entity)
                end,
            },
        },
        distance = (Config.CorpseLoot and Config.CorpseLoot.maxDistance) or 2.4,
    })
    corpseTargetRegistered = true
end

local function unregisterCorpseTarget()
    if not corpseTargetRegistered or not hasTarget() then return end
    pcall(function()
        exports['qb-target']:RemoveGlobalPed(CORPSE_TARGET_LABEL)
    end)
    corpseTargetRegistered = false
end

local function setObjectiveBlip(target, label)
    removeObjectiveBlip()
    if not target then return end
    objectiveBlip = AddBlipForCoord(target.x + 0.0, target.y + 0.0, target.z + 0.0)
    SetBlipSprite(objectiveBlip, 1)
    SetBlipColour(objectiveBlip, 1)
    SetBlipScale(objectiveBlip, 0.85)
    SetBlipRoute(objectiveBlip, true)
    SetBlipRouteColour(objectiveBlip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Gang operacija')
    EndTextCommandSetBlipName(objectiveBlip)
end

local refreshObjectiveTarget
local refreshContestTarget

local function completeObjective(payload)
    if not activeMission or not activePhase or objectiveBusy then return end
    objectiveBusy = true
    QBCore.Functions.TriggerCallback('mrp_gangs:server:completeObjective', function(response)
        objectiveBusy = false
        if not response or not response.ok then
            local reason = response and response.reason
            if reason ~= 'enemies_remaining' and reason ~= 'defence_timer_active' and reason ~= 'objective_too_fast' then
                GangClient.Notify(GangClient.Reason(reason), 'error')
            end
        end
    end, activeMission.token, activePhase.phaseIndex, payload or {})
end

local function interactWithObjective()
    local phase = activePhase and activePhase.phase
    if not phase or objectiveBusy then return end
    if not actionPhaseTypes[phase.type] then
        local payload = {}
        if phase.type == 'checkpoint_run' then payload.checkpointIndex = activePhase.checkpointIndex end
        return completeObjective(payload)
    end

    objectiveBusy = true
    QBCore.Functions.TriggerCallback('mrp_gangs:server:beginObjective', function(response)
        if not response or not response.ok then
            objectiveBusy = false
            hidePrepProgress()
            return GangClient.Notify(GangClient.Reason(response and response.reason), 'error')
        end
        local action = response.result
        local duration = tonumber(action.durationMs) or tonumber(phase.durationMs) or 5000
        showPrepProgress(phase.label or 'Vykdoma operacija...', duration)

        local ped = PlayerPedId()
        local animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
        local animName = 'machinic_loop_mechandplayer'
        RequestAnimDict(animDict)
        local animTimeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < animTimeout do Wait(10) end
        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(ped, animDict, animName, 2.0, 2.0, duration, 49, 0.0, false, false, false)
        end

        local endsAt = GetGameTimer() + duration
        CreateThread(function()
            while objectiveBusy and GetGameTimer() < endsAt do
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 37, true)
                if IsControlJustReleased(0, 200) or IsControlJustReleased(0, 194) then
                    ClearPedTasks(ped)
                    hidePrepProgress()
                    objectiveBusy = false
                    GangClient.Notify('Veiksmas nutrauktas.', 'error')
                    return
                end
                Wait(0)
            end
            if not objectiveBusy then return end
            ClearPedTasks(ped)
            hidePrepProgress()
            objectiveBusy = false
            completeObjective({ actionToken = action.actionToken })
        end)
    end, activeMission.token, activePhase.phaseIndex)
end

local function safeTeleport(coords)
    if not coords then return end
    local ped = PlayerPedId()
    DoScreenFadeOut(350)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(50) end
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(350)
end

RegisterNetEvent('mrp_gangs:client:missionStarted', function(summary)
    activeMission = summary
    if contestedObjective and contestedObjective.token == summary.token then
        clearContestedObjective()
    end
    GangClient.Notify(('%s · %s · %s nariai'):format(
        summary.missionLabel,
        Config.Difficulties[summary.difficulty].label,
        summary.partySize
    ), 'success', 8000)
end)

RegisterNetEvent('mrp_gangs:client:missionPhase', function(data)
    if not activeMission or data.runToken ~= activeMission.token then return end
    hidePrepProgress()
    activePhase = data
    activePhase.receivedAt = GetGameTimer()
    objectiveBusy = false
    showEnterPrompt = false
    nextAutomaticCheck = GetGameTimer() + 1500
    setObjectiveBlip(data.target, data.phase.label)
    refreshObjectiveTarget()
    GangClient.Notify(('[%s/%s] %s'):format(data.phaseIndex, data.phaseCount, data.phase.label), 'primary', 7000)
end)

RegisterNetEvent('mrp_gangs:client:enterMissionInterior', function(token, coords, returnCoords)
    if not activeMission or token ~= activeMission.token then return end
    missionReturnCoords = returnCoords or missionReturnCoords
    safeTeleport(coords)
end)

RegisterNetEvent('mrp_gangs:client:leaveMissionInterior', function(token, coords)
    if not activeMission or token ~= activeMission.token then return end
    safeTeleport(coords)
    missionReturnCoords = nil
end)

RegisterNetEvent('mrp_gangs:client:enterMissionCompound', function(token, _compoundKey)
    if not activeMission or token ~= activeMission.token then return end
    GangClient.Notify('Zona aktyvi — dirbk objektų zonoje.', 'primary', 5000)
end)

RegisterNetEvent('mrp_gangs:client:leaveMissionCompound', function(token)
    if not activeMission or token ~= activeMission.token then return end
end)

RegisterNetEvent('mrp_gangs:client:missionLeaderChanged', function(citizenid, displayName)
    if not activeMission then return end
    activeMission.leaderCitizenId = citizenid
    GangClient.Notify(('Operacijos vadovas perduotas: %s'):format(displayName or citizenid), 'primary', 7000)
end)

RegisterNetEvent('mrp_gangs:client:setMissionCargo', function(token, enabled)
    if not activeMission or token ~= activeMission.token then return end
    clearMissionCargo()
    if not enabled then return end
    CreateThread(function()
        local model = joaat('prop_cs_cardbox_01')
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(25) end
        if not HasModelLoaded(model) then return end
        local ped = PlayerPedId()
        missionCargoProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(
            missionCargoProp,
            ped,
            GetPedBoneIndex(ped, 57005),
            0.28,
            0.02,
            -0.03,
            -90.0,
            0.0,
            80.0,
            true,
            true,
            false,
            true,
            1,
            true
        )
        SetModelAsNoLongerNeeded(model)
    end)
end)

RegisterNetEvent('mrp_gangs:client:configureMissionVehicle', function(token, networkId)
    if not activeMission or token ~= activeMission.token then return end
    CreateThread(function()
        local timeout = GetGameTimer() + 8000
        while not NetworkDoesEntityExistWithNetworkId(networkId) and GetGameTimer() < timeout do Wait(50) end
        if not NetworkDoesEntityExistWithNetworkId(networkId) then return end
        local vehicle = NetToVeh(networkId)
        if vehicle == 0 or not DoesEntityExist(vehicle) then return end
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleOnGroundProperly(vehicle)
        local plate = GetVehicleNumberPlateText(vehicle)
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
        end
    end)
end)

RegisterNetEvent('mrp_gangs:client:configureMissionTarget', function(token, networkId, mode, released, leaderSource)
    if not activeMission or token ~= activeMission.token then return end
    CreateThread(function()
        local timeout = GetGameTimer() + 8000
        while not NetworkDoesEntityExistWithNetworkId(networkId) and GetGameTimer() < timeout do Wait(50) end
        if not NetworkDoesEntityExistWithNetworkId(networkId) then return end
        local ped = NetToPed(networkId)
        if ped == 0 or not DoesEntityExist(ped) then return end
        NetworkRequestControlOfEntity(ped)
        local controlTimeout = GetGameTimer() + 1200
        while not NetworkHasControlOfEntity(ped) and GetGameTimer() < controlTimeout do
            NetworkRequestControlOfEntity(ped)
            Wait(25)
        end
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDropsWeaponsWhenDead(ped, false)
        SetPedFleeAttributes(ped, 0, false)
        if not released then
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            if mode == 'capture' then TaskHandsUp(ped, -1, PlayerPedId(), -1, true) end
            return
        end
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        local playerIndex = leaderSource and GetPlayerFromServerId(tonumber(leaderSource)) or -1
        local followPed = playerIndex and playerIndex >= 0 and GetPlayerPed(playerIndex) or PlayerPedId()
        TaskFollowToOffsetOfEntity(ped, followPed, 0.0, -1.5, 0.0, 2.0, -1, 2.5, true)
    end)
end)

RegisterNetEvent('mrp_gangs:client:contestedObjective', function(payload)
    payload = payload or {}
    if activeMission and activeMission.token == payload.token then
        return clearContestedObjective()
    end
    --- Silent discovery only — no notify / no map blip.
    contestedObjective = payload
    refreshContestTarget()
end)

RegisterNetEvent('mrp_gangs:client:clearContestedObjective', function(token)
    if contestedObjective and tostring(token or '') == tostring(contestedObjective.token or '') then
        clearContestedObjective()
    elseif not token then
        clearContestedObjective()
    end
end)

local function stealContestedLoot()
    if not contestedObjective or contestedBusy or activeMission then return end
    contestedBusy = true
    QBCore.Functions.TriggerCallback('mrp_gangs:server:beginContestLoot', function(beginResponse)
        if not beginResponse or not beginResponse.ok then
            contestedBusy = false
            return GangClient.Notify(GangClient.Reason(beginResponse and beginResponse.reason), 'error')
        end
        local duration = tonumber(beginResponse.result and beginResponse.result.durationMs) or 7000
        local actionToken = beginResponse.result and beginResponse.result.actionToken
        QBCore.Functions.Progressbar(
            'mrp_gangs_contest_loot',
            contestedObjective.label or 'Vagiama...',
            duration,
            false,
            true,
            { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
            {},
            {},
            {},
            function()
                QBCore.Functions.TriggerCallback('mrp_gangs:server:completeContestLoot', function(completeResponse)
                    contestedBusy = false
                    if completeResponse and completeResponse.ok then
                        clearContestedObjective()
                        GangClient.Notify('Konteineris / krovinys perimtas.', 'success')
                    else
                        GangClient.Notify(GangClient.Reason(completeResponse and completeResponse.reason), 'error')
                    end
                end, contestedObjective.token, { actionToken = actionToken })
            end,
            function()
                contestedBusy = false
                GangClient.Notify('Counter loot nutrauktas.', 'error')
            end
        )
    end, contestedObjective.token)
end

refreshObjectiveTarget = function()
    clearObjectiveTarget()
    if not hasTarget() or not activeMission or not activePhase or not activePhase.target then return end
    local phase = activePhase.phase
    if not phase then return end
    -- Arrival / enter / exit / extract / vehicle: marker checkpoints only (no qb-target confirm).
    if autoCompletePhaseTypes[phase.type]
        or promptPhaseTypes[phase.type]
        or phase.type == 'eliminate'
        or phase.type == 'defend' then
        return
    end
    if not actionPhaseTypes[phase.type] then return end

    local target = activePhase.target
    exports['qb-target']:AddCircleZone(
        OBJECTIVE_ZONE,
        vector3(target.x + 0.0, target.y + 0.0, target.z + 0.0),
        1.85,
        { name = OBJECTIVE_ZONE, useZ = true, debugPoly = false },
        {
            options = {
                {
                    num = 1,
                    type = 'client',
                    icon = 'fas fa-hand',
                    label = phase.label or 'Vykdyti',
                    canInteract = function()
                        return activeMission ~= nil and activePhase ~= nil and not objectiveBusy and not corpseBusy
                    end,
                    action = function()
                        interactWithObjective()
                    end,
                },
            },
            distance = 2.4,
        }
    )
end

refreshContestTarget = function()
    clearContestTarget()
    if not hasTarget() or not contestedObjective or not contestedObjective.target or activeMission then return end
    local target = contestedObjective.target
    exports['qb-target']:AddCircleZone(
        CONTEST_ZONE,
        vector3(target.x + 0.0, target.y + 0.0, target.z + 0.0),
        1.9,
        { name = CONTEST_ZONE, useZ = true, debugPoly = false },
        {
            options = {
                {
                    num = 1,
                    type = 'client',
                    icon = 'fas fa-box-open',
                    label = contestedObjective.label or 'Counter loot',
                    canInteract = function()
                        return contestedObjective ~= nil and not contestedBusy and not activeMission
                    end,
                    action = function()
                        stealContestedLoot()
                    end,
                },
            },
            distance = 2.5,
        }
    )
end

RegisterNetEvent('mrp_gangs:client:missionFinished', function(result)
    if activeMission and result.summary and result.summary.token ~= activeMission.token then return end
    hidePrepProgress()
    removeObjectiveBlip()
    clearMissionTargets()
    activePhase = nil
    activeMission = nil
    missionReturnCoords = nil
    showEnterPrompt = false
    clearMissionCargo()
    objectiveBusy = false
    corpseBusy = false
    if contestedObjective and result.summary and contestedObjective.token == result.summary.token then
        clearContestedObjective()
    end
    if result.success then
        local settlement = result.settlement or {}
        GangClient.Notify(('Operacija baigta · crew $%s · gaujai $%s · rep +%s'):format(
            settlement.crewCashEach or 0,
            settlement.treasury or 0,
            settlement.reputation or 0
        ), 'success', 10000)
    else
        GangClient.Notify(('Operacija nepavyko: %s'):format(GangClient.Reason(result.reason)), 'error', 9000)
    end
end)

RegisterNetEvent('mrp_gangs:client:configureEncounter', function(token, networkEntities, wave, maxWaves)
    if not activeMission or token ~= activeMission.token then return end
    if tonumber(maxWaves) and tonumber(maxWaves) > 1 then
        GangClient.Notify(('Priešų banga %s/%s'):format(wave or 1, maxWaves), 'primary', 5000)
    end
    if not enemyRelationshipGroup then
        AddRelationshipGroup('MRP_MISSION_ENEMY')
        enemyRelationshipGroup = joaat('MRP_MISSION_ENEMY')
    end
    local playerGroup = GetPedRelationshipGroupHash(PlayerPedId())
    SetRelationshipBetweenGroups(5, enemyRelationshipGroup, playerGroup)
    SetRelationshipBetweenGroups(5, playerGroup, enemyRelationshipGroup)

    CreateThread(function()
        for _, data in ipairs(networkEntities or {}) do
            local timeout = GetGameTimer() + 8000
            while not NetworkDoesEntityExistWithNetworkId(data.networkId) and GetGameTimer() < timeout do Wait(50) end
            if NetworkDoesEntityExistWithNetworkId(data.networkId) then
                local ped = NetToPed(data.networkId)
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    NetworkRequestControlOfEntity(ped)
                    local controlTimeout = GetGameTimer() + 1000
                    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < controlTimeout do
                        NetworkRequestControlOfEntity(ped)
                        Wait(25)
                    end
                    SetEntityAsMissionEntity(ped, true, false)
                    SetPedRelationshipGroupHash(ped, enemyRelationshipGroup)
                    SetPedAsEnemy(ped, true)
                    SetPedDropsWeaponsWhenDead(ped, false)
                    SetPedCanEvasiveDive(ped, true)
                    SetPedCombatAttributes(ped, 5, true)
                    SetPedCombatAttributes(ped, 46, true)
                    SetPedCombatAbility(ped, activeMission.difficulty == 'easy' and 1 or 2)
                    SetPedCombatMovement(ped, activeMission.difficulty == 'extreme' and 3 or 2)
                    SetPedSeeingRange(ped, 80.0)
                    SetPedHearingRange(ped, 60.0)
                    SetPedAccuracy(ped, tonumber(data.accuracy) or 25)
                    local weaponName = data.weapon or 'WEAPON_BAT'
                    local ammo = data.melee and 1 or 180
                    GiveWeaponToPed(ped, joaat(weaponName), ammo, false, true)
                    if data.melee or activeMission.difficulty == 'easy' then
                        SetPedCombatAttributes(ped, 46, true)
                        SetPedCombatRange(ped, 0)
                    end
                    TaskCombatHatedTargetsAroundPed(ped, 100.0, 0)
                end
            end
        end
    end)
end)

CreateThread(function()
    for _, interior in pairs(Config.MissionInteriors or {}) do
        if interior.ipl then RequestIpl(interior.ipl) end
    end

    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    registerCorpseTarget()

    while true do
        local drawingMission = activeMission and activePhase and activePhase.target
        local drawingContest = contestedObjective and contestedObjective.target and not activeMission
        if not drawingMission and not drawingContest then
            Wait(750)
        else
            if drawingContest then
                local target = contestedObjective.target
                local distance = #(GetEntityCoords(PlayerPedId()) - vector3(target.x, target.y, target.z))
                if distance < 35.0 then
                    DrawMarker(2, target.x, target.y, target.z + 0.45, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.45, 0.45, 0.45, 255, 50, 50, 200, false, true, 2, false, nil, nil, false)
                end
            end

            if drawingMission then
                local target = activePhase.target
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - vector3(target.x + 0.0, target.y + 0.0, target.z + 0.0))
                local phase = activePhase.phase
                local phaseType = phase.type
                local markerZ = target.z
                if phaseType == 'checkpoint_run' then
                    local dx = playerCoords.x - target.x
                    local dy = playerCoords.y - target.y
                    distance = math.sqrt(dx * dx + dy * dy)
                    markerZ = playerCoords.z
                end

                local showMarker = phaseType ~= 'eliminate' and phaseType ~= 'defend'
                if showMarker and distance < 80.0 then
                    -- Ground cylinder checkpoint for approach / enter
                    if autoCompletePhaseTypes[phaseType] or phaseType == 'enter' then
                        DrawMarker(
                            1,
                            target.x, target.y, markerZ - 0.95,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            2.2, 2.2, 0.55,
                            220, 70, 70, 140,
                            false, false, 2, false, nil, nil, false
                        )
                        DrawMarker(
                            2,
                            target.x, target.y, markerZ + 0.55,
                            0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                            0.35, 0.35, 0.35,
                            220, 70, 70, 200,
                            false, true, 2, false, nil, nil, false
                        )
                    else
                        DrawMarker(2, target.x, target.y, markerZ + 0.35, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                            0.35, 0.35, 0.35, 220, 60, 60, 180, false, true, 2, false, nil, nil, false)
                    end
                end

                if not objectiveBusy and not corpseBusy and GetGameTimer() >= nextAutomaticCheck then
                    if autoCompletePhaseTypes[phaseType] and distance <= 10.0 then
                        nextAutomaticCheck = GetGameTimer() + 2500
                        completeObjective({})
                    elseif (phaseType == 'eliminate' or phaseType == 'defend') then
                        nextAutomaticCheck = GetGameTimer() + 4000
                        completeObjective({})
                    elseif promptPhaseTypes[phaseType] then
                        local radius = phaseType == 'checkpoint_run' and 16.0
                            or (phaseType == 'extract' and 10.0)
                            or 3.2
                        if distance <= radius then
                            local prompt = phaseType == 'enter'
                                and (activePhase.entryPrompt or 'Eik į vidų')
                                or (phase.label or 'Tęsti')
                            drawHelpText(('~INPUT_CONTEXT~ %s'):format(prompt))
                            if IsControlJustReleased(0, 38) then
                                nextAutomaticCheck = GetGameTimer() + 2000
                                interactWithObjective()
                            end
                        end
                    elseif actionPhaseTypes[phaseType] and distance <= 2.6 then
                        drawHelpText(('~INPUT_CONTEXT~ %s'):format(phase.label or 'Vykdyti'))
                        if IsControlJustReleased(0, 38) then
                            nextAutomaticCheck = GetGameTimer() + 1500
                            interactWithObjective()
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hidePrepProgress()
    removeObjectiveBlip()
    clearMissionCargo()
    clearMissionTargets()
    unregisterCorpseTarget()
    clearContestedObjective()
    if missionReturnCoords then
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(
            ped,
            missionReturnCoords.x,
            missionReturnCoords.y,
            missionReturnCoords.z,
            false,
            false,
            false
        )
        SetEntityHeading(ped, missionReturnCoords.w or 0.0)
    end
end)

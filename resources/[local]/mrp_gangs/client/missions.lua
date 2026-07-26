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
local actionPhaseTypes = {
    interact = true,
    breach = true,
    search = true,
    collect = true,
    sabotage = true,
    rescue = true,
    capture = true,
}

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

local function drawText3D(coords, text)
    local visible, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not visible then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

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
            return GangClient.Notify(GangClient.Reason(response and response.reason), 'error')
        end
        local action = response.result
        QBCore.Functions.Progressbar(
            ('gang_mission_%s_%s'):format(activeMission.token, activePhase.phaseIndex),
            phase.label or 'Vykdoma operacija...',
            tonumber(action.durationMs) or tonumber(phase.durationMs) or 5000,
            false,
            true,
            {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            { animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flags = 49 },
            {},
            {},
            function()
                objectiveBusy = false
                completeObjective({ actionToken = action.actionToken })
            end,
            function()
                objectiveBusy = false
                GangClient.Notify('Veiksmas nutrauktas.', 'error')
            end
        )
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
    activePhase = data
    activePhase.receivedAt = GetGameTimer()
    objectiveBusy = false
    nextAutomaticCheck = GetGameTimer() + 3000
    setObjectiveBlip(data.target, data.phase.label)
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

RegisterNetEvent('mrp_gangs:client:missionFinished', function(result)
    if activeMission and result.summary and result.summary.token ~= activeMission.token then return end
    removeObjectiveBlip()
    activePhase = nil
    activeMission = nil
    missionReturnCoords = nil
    clearMissionCargo()
    objectiveBusy = false
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
                    GiveWeaponToPed(ped, joaat(data.weapon or 'WEAPON_PISTOL'), 180, false, true)
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

    while true do
        local drawingMission = activeMission and activePhase and activePhase.target
        local drawingContest = contestedObjective and contestedObjective.target and not activeMission
        if not drawingMission and not drawingContest then
            Wait(750)
        else
            local playerCoords = GetEntityCoords(PlayerPedId())
            if drawingContest then
                local target = contestedObjective.target
                local targetCoords = vector3(target.x, target.y, target.z)
                local distance = #(playerCoords - targetCoords)
                if distance < 35.0 then
                    DrawMarker(2, target.x, target.y, target.z + 0.45, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.45, 0.45, 0.45, 255, 50, 50, 200, false, true, 2, false, nil, nil, false)
                end
                if distance < 3.0 then
                    drawText3D(vector3(target.x, target.y, target.z + 0.75),
                        '[E] Counter loot · ' .. (contestedObjective.label or 'Konteineris'))
                    if IsControlJustReleased(0, 38) then stealContestedLoot() end
                end
            end

            if drawingMission then
                local target = activePhase.target
                local targetCoords = vector3(target.x, target.y, target.z)
                local distance = #(playerCoords - targetCoords)
                local phaseType = activePhase.phase.type
                local markerZ = target.z
                if phaseType == 'checkpoint_run' then
                    local dx = playerCoords.x - target.x
                    local dy = playerCoords.y - target.y
                    distance = math.sqrt(dx * dx + dy * dy)
                    markerZ = playerCoords.z
                end

                if distance < 80.0 and phaseType ~= 'eliminate' and phaseType ~= 'defend' then
                    DrawMarker(2, target.x, target.y, markerZ + 0.35, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.35, 0.35, 0.35, 220, 60, 60, 180, false, true, 2, false, nil, nil, false)
                end
                if distance < 3.0 and phaseType ~= 'eliminate' and phaseType ~= 'defend' then
                    drawText3D(vector3(target.x, target.y, markerZ + 0.65), '[E] ' .. (activePhase.phase.label or 'Vykdyti'))
                    if IsControlJustReleased(0, 38) then interactWithObjective() end
                end

                if (phaseType == 'eliminate' or phaseType == 'defend')
                    and GetGameTimer() >= nextAutomaticCheck and not objectiveBusy then
                    nextAutomaticCheck = GetGameTimer() + 4000
                    completeObjective({})
                end
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeObjectiveBlip()
    clearMissionCargo()
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

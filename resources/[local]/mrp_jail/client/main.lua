local QBCore = exports['qb-core']:GetCoreObject()

local jailed = false
local jailState = nil
local canteenPed = nil
local workBusy = false
local activeWorkSpots = {}
local workSpotCooldowns = {}

local function workSpotKey(spot)
    return ('%.1f,%.1f,%.1f'):format(spot.x, spot.y, spot.z)
end

local function pickRandomWorkSpots(count)
    local pool = Config.WorkSpots or {}
    if #pool == 0 then return {} end
    local now = GetGameTimer()
    local candidates = {}
    for _, spot in ipairs(pool) do
        local key = workSpotKey(spot)
        local untilMs = workSpotCooldowns[key]
        if not untilMs or now >= untilMs then
            candidates[#candidates + 1] = spot
        end
    end
    if #candidates == 0 then
        for _, spot in ipairs(pool) do
            candidates[#candidates + 1] = spot
        end
    end
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    local out = {}
    local n = math.min(count, #candidates)
    for i = 1, n do
        out[i] = candidates[i]
    end
    return out
end

local function refreshActiveWorkSpots(force)
    local maxActive = Config.WorkSpotMaxActive or 5
    local minActive = Config.WorkSpotMinActive or 1
    if force or #activeWorkSpots == 0 then
        activeWorkSpots = pickRandomWorkSpots(maxActive)
        return
    end
    local now = GetGameTimer()
    local kept = {}
    for _, spot in ipairs(activeWorkSpots) do
        local key = workSpotKey(spot)
        local untilMs = workSpotCooldowns[key]
        if not untilMs or now >= untilMs then
            kept[#kept + 1] = spot
        end
    end
    activeWorkSpots = kept
    while #activeWorkSpots < minActive do
        local added = false
        for _, spot in ipairs(pickRandomWorkSpots(1)) do
            local dup = false
            for _, existing in ipairs(activeWorkSpots) do
                if #(existing - spot) < 0.5 then
                    dup = true
                    break
                end
            end
            if not dup then
                activeWorkSpots[#activeWorkSpots + 1] = spot
                added = true
                break
            end
        end
        if not added then break end
    end
    while #activeWorkSpots < maxActive do
        local candidates = pickRandomWorkSpots(1)
        if #candidates == 0 then break end
        local spot = candidates[1]
        local dup = false
        for _, existing in ipairs(activeWorkSpots) do
            if #(existing - spot) < 0.5 then
                dup = true
                break
            end
        end
        if dup then break end
        activeWorkSpots[#activeWorkSpots + 1] = spot
    end
end

local function markWorkSpotUsed(spot)
    workSpotCooldowns[workSpotKey(spot)] = GetGameTimer() + (Config.WorkSpotCooldownMs or 90000)
    for i, s in ipairs(activeWorkSpots) do
        if #(s - spot) < 0.5 then
            table.remove(activeWorkSpots, i)
            break
        end
    end
    refreshActiveWorkSpots(false)
end

local function groundZAt(x, y, zHint)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, (zHint or 0.0) + 8.0, false)
    if found then
        return groundZ + 0.02
    end
    return zHint or 0.0
end

local function placePedOnSpot(ped, spot)
    local z = groundZAt(spot.x, spot.y, spot.z)
    SetEntityCoords(ped, spot.x, spot.y, z, false, false, false, false)
    PlaceEntityOnGroundProperly(ped)
end

--- Block melee/attack inputs (not AIM — keeps native GTA targeting dot). Control indices, not key labels.
local MELEE_BLOCK_CONTROLS = {
    24, 47, 58,
    140, 141, 142, 143, 257, 263, 264,
}

local function disableJailCombatControls()
    local playerId = PlayerId()
    DisablePlayerFiring(playerId, true)
    for group = 0, 2 do
        for _, ctrl in ipairs(MELEE_BLOCK_CONTROLS) do
            DisableControlAction(group, ctrl, true)
        end
    end
end

local function suppressPedMelee(ped, restoreAnimDict, restoreAnimName)
    if not ped or ped == 0 then return end
    if IsPedInMeleeCombat(ped) or IsPedPerformingMeleeAction(ped) then
        ClearPedTasksImmediately(ped)
        if restoreAnimDict and restoreAnimName and HasAnimDictLoaded(restoreAnimDict) then
            TaskPlayAnim(ped, restoreAnimDict, restoreAnimName, 2.0, 2.0, -1, 1, 0.0, false, false, false)
        end
    end
end

local function isNearActiveWorkSpot(coords)
    local radius = Config.WorkCombatDisableDistance or ((Config.WorkInteractDistance or 2.2) + 1.0)
    for _, spot in ipairs(activeWorkSpots) do
        local spotZ = groundZAt(spot.x, spot.y, spot.z)
        if #(coords - vector3(spot.x, spot.y, spotZ)) <= radius then
            return true
        end
    end
    return false
end

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function setHud(state)
    if not state then
        nui('hide')
        return
    end
    nui('show', {
        remainingSeconds = state.remainingSeconds or 0,
        reason = state.reason or Config.Defaults.noReason,
        requireWork = state.requireWork == true,
        byType = state.byType or 'police',
    })
end

local function updateHud(state)
    if not state then return end
    nui('update', {
        remainingSeconds = state.remainingSeconds or 0,
        reason = state.reason,
        requireWork = state.requireWork == true,
        byType = state.byType,
    })
end

local function deleteCanteenPed()
    if canteenPed and DoesEntityExist(canteenPed) then
        DeleteEntity(canteenPed)
    end
    canteenPed = nil
end

local function ensureCanteenPed()
    if canteenPed and DoesEntityExist(canteenPed) then return end
    local cfg = Config.Canteen
    if not cfg then return end
    local model = joaat(cfg.pedModel or 's_m_m_dockwork_01')
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(model) then return end

    local c = cfg.coords
    canteenPed = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w or 0.0, false, false)
    SetEntityAsMissionEntity(canteenPed, true, true)
    SetBlockingOfNonTemporaryEvents(canteenPed, true)
    FreezeEntityPosition(canteenPed, true)
    SetEntityInvincible(canteenPed, true)
    SetModelAsNoLongerNeeded(model)

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(canteenPed, {
            options = {
                {
                    icon = 'fas fa-utensils',
                    label = 'Kalėjimo valgykla',
                    action = function()
                        TriggerServerEvent('mrp_jail:server:openCanteen')
                    end,
                },
            },
            distance = cfg.interactDistance or 2.5,
        })
    end
end

local function isPoliceOnDutyClient()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    return P.job.name == Config.PoliceJob and P.job.onduty == true
end

local function serverIdFromEntity(entity)
    if not entity or entity == 0 then return nil end
    local idx = NetworkGetPlayerIndexFromPed(entity)
    if idx == nil or idx < 0 then return nil end
    return GetPlayerServerId(idx)
end

local function startJail(state)
    jailed = true
    jailState = state
    workSpotCooldowns = {}
    refreshActiveWorkSpots(true)
    setHud(state)
    ensureCanteenPed()
end

local function clearJail()
    jailed = false
    jailState = nil
    workBusy = false
    activeWorkSpots = {}
    workSpotCooldowns = {}
    setHud(nil)
    nui('workHide')
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    deleteCanteenPed()
end

RegisterNetEvent('mrp_jail:client:setJail', function(state)
    if type(state) ~= 'table' then return end
    startJail(state)
end)

RegisterNetEvent('mrp_jail:client:clearJail', function()
    clearJail()
end)

RegisterNetEvent('mrp_jail:client:teleport', function(coords)
    if type(coords) ~= 'vector4' and type(coords) ~= 'table' then return end
    local ped = PlayerPedId()
    local x, y, z, w = coords.x, coords.y, coords.z, coords.w or 0.0
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, w)
    Wait(200)
    DoScreenFadeIn(400)
end)

local function tryWorkAtSpot(spot)
    if workBusy or not jailed then return end
    workBusy = true

    local ped = PlayerPedId()
    local duration = Config.WorkDurationMs or 60000
    local label = (jailState and jailState.requireWork) and 'Valymo darbas' or 'Viešieji darbai'
    local animDict = 'amb@world_human_janitor@male@idle_a'
    local animName = 'idle_a'

    --- Snap + freeze in place for the whole task (ground level, no floating)
    placePedOnSpot(ped, spot)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)

    RequestAnimDict(animDict)
    local loadUntil = GetGameTimer() + 3000
    while not HasAnimDictLoaded(animDict) and GetGameTimer() < loadUntil do
        Wait(10)
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_JANITOR', 0, true)
    end

    nui('workShow', { durationMs = duration, label = label })

    local endAt = GetGameTimer() + duration
    while GetGameTimer() < endAt do
        if not jailed then
            break
        end
        ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)   -- look
        EnableControlAction(0, 2, true)
        EnableControlAction(0, 249, true) -- push to talk
        disableJailCombatControls()
        suppressPedMelee(ped, animDict, animName)

        if HasAnimDictLoaded(animDict) and not IsEntityPlayingAnim(ped, animDict, animName, 3) then
            TaskPlayAnim(ped, animDict, animName, 2.0, 2.0, -1, 1, 0.0, false, false, false)
        end
        Wait(0)
    end

    nui('workHide')
    ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if jailed then
        TriggerServerEvent('mrp_jail:server:completeWork', spot.x, spot.y, spot.z)
        markWorkSpotUsed(spot)
    end
    workBusy = false
end

--- Anti-escape + work markers
CreateThread(function()
    while true do
        local sleep = 1000
        if jailed then
            sleep = 0
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local center = Config.Carrier.center
            local maxDist = Config.Carrier.maxDistance or 95.0

            if #(coords - center) > maxDist then
                TriggerServerEvent('mrp_jail:server:escapeAttempt')
                Wait(Config.EscapeCheckMs or 2500)
            end

            refreshActiveWorkSpots(false)

            local atWorkZone = workBusy or isNearActiveWorkSpot(coords)
            if atWorkZone then
                disableJailCombatControls()
                suppressPedMelee(ped)
            end

            for _, spot in ipairs(activeWorkSpots) do
                local spotZ = groundZAt(spot.x, spot.y, spot.z)
                local spotPos = vector3(spot.x, spot.y, spotZ)
                local dist = #(coords - spotPos)
                if dist < 25.0 then
                    local m = Config.WorkMarker
                    DrawMarker(
                        m.type or 2,
                        spot.x, spot.y, spotZ + 0.05,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        m.scale.x, m.scale.y, m.scale.z,
                        m.color.r, m.color.g, m.color.b, m.color.a,
                        false, false, 2, false, nil, nil, false
                    )
                    if dist <= (Config.WorkInteractDistance or 2.2) then
                        QBCore.Functions.DrawText3D(
                            spot.x, spot.y, spotZ + 0.35,
                            (jailState and jailState.requireWork)
                                and '[E] Valymo darbas (−1)'
                                or '[E] Viešieji darbai (−1 min)'
                        )
                        if IsControlJustReleased(0, 38) and not workBusy then
                            tryWorkAtSpot(spot)
                        end
                    end
                end
            end

            --- Fallback canteen interact without target
            if Config.Canteen and (not canteenPed or not DoesEntityExist(canteenPed)) then
                ensureCanteenPed()
            end
            if Config.Canteen and GetResourceState('qb-target') ~= 'started' then
                local c = Config.Canteen.coords
                local cpos = vector3(c.x, c.y, c.z)
                if #(coords - cpos) <= (Config.Canteen.interactDistance or 2.5) then
                    QBCore.Functions.DrawText3D(c.x, c.y, c.z + 1.0, '[E] Valgykla')
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('mrp_jail:server:openCanteen')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

--- Keep HUD in sync if NUI missed an event
CreateThread(function()
    while true do
        Wait(15000)
        if jailed and jailState then
            TriggerServerEvent('mrp_jail:server:requestSync')
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('mrp_jail:server:requestSync')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    clearJail()
end)

local function openPoliceJailInput(targetId)
    if GetResourceState('qb-input') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-input resurso.', 'error')
    end
    local input = exports['qb-input']:ShowInput({
        header = 'Įkalinti žaidėją #' .. tostring(targetId),
        submitText = 'Įkalinti',
        inputs = {
            { text = 'Minutės', name = 'minutes', type = 'number', isRequired = true },
            { text = 'Priežastis', name = 'reason', type = 'text', isRequired = false },
        },
    })
    if not input then return end
    local minutes = tonumber(input.minutes)
    if not minutes or minutes < 1 then
        return QBCore.Functions.Notify(Config.Notify.invalidMinutes, 'error')
    end
    TriggerServerEvent('mrp_jail:server:policeJail', targetId, minutes, input.reason or '')
end

CreateThread(function()
    if GetResourceState('qb-target') ~= 'started' then return end
    Wait(1000)
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-gavel',
                label = 'Įkalinti',
                canInteract = function(entity)
                    if not isPoliceOnDutyClient() then return false end
                    local sid = serverIdFromEntity(entity)
                    if not sid or sid == GetPlayerServerId(PlayerId()) then return false end
                    return true
                end,
                action = function(entity)
                    local sid = serverIdFromEntity(entity)
                    if sid then openPoliceJailInput(sid) end
                end,
            },
            {
                icon = 'fas fa-unlock',
                label = 'Paleisti iš kalėjimo',
                canInteract = function(entity)
                    if not isPoliceOnDutyClient() then return false end
                    local sid = serverIdFromEntity(entity)
                    if not sid then return false end
                    --- optimistic: always show for PD; server validates
                    return true
                end,
                action = function(entity)
                    local sid = serverIdFromEntity(entity)
                    if sid then
                        TriggerServerEvent('mrp_jail:server:policeUnjail', sid)
                    end
                end,
            },
        },
        distance = 2.5,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearJail()
end)

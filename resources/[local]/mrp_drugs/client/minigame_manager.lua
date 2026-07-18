--- Single owner for every mrp_drugs client minigame session.
MinigameManager = MinigameManager or {}

local active
local sequence = 0

local function emitReset(reason, session)
    TriggerEvent('mrp_drugs:client:productionReset', reason, session and session.id)
end

local function setFocus(session, enabled)
    if enabled then
        SetNuiFocus(session.focus == true, session.cursor == true)
        SetNuiFocusKeepInput(session.keepInput == true)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

function MinigameManager.GetActive()
    return active
end

function MinigameManager.IsActive(sessionId)
    if not active then return false end
    return sessionId == nil or active.id == tostring(sessionId)
end

function MinigameManager.Begin(options, onDone)
    options = options or {}
    if active then
        MinigameManager.Close('replaced', { success = false })
    end

    sequence = sequence + 1
    local session = {
        id = tostring(options.sessionId or ('%d-%d'):format(GetGameTimer(), sequence)),
        productId = options.productId,
        craftToken = options.craftToken,
        focus = options.focus == true,
        cursor = options.cursor == true,
        keepInput = options.keepInput == true,
        disableControls = options.disableControls == true,
        closeNui = options.closeNui ~= false,
        onDone = onDone,
        backend = nil,
        finished = false,
    }
    active = session
    setFocus(session, true)

    local timeoutMs = math.max(1000, tonumber(options.timeoutMs) or 180000)
    CreateThread(function()
        Wait(timeoutMs)
        if active == session and not session.finished then
            MinigameManager.Close('timeout', {
                success = false,
                score = 0,
                mistakes = 1,
            })
        end
    end)

    if session.disableControls then
        CreateThread(function()
            while active == session and not session.finished do
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 32, true)
                DisableControlAction(0, 33, true)
                DisableControlAction(0, 34, true)
                DisableControlAction(0, 35, true)
                DisableControlAction(0, 38, true)
                DisableControlAction(0, 73, true)
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 241, true)
                DisableControlAction(0, 242, true)
                Wait(0)
            end
        end)
    end
    return session.id, session
end

function MinigameManager.AttachBackend(sessionId, backend)
    if not active or active.id ~= tostring(sessionId) then return false end
    active.backend = backend
    return true
end

function MinigameManager.Close(reason, result, sessionId, fromBackend)
    local session = active
    if not session or session.finished then return false end
    if sessionId ~= nil and session.id ~= tostring(sessionId) then return false end

    session.finished = true
    active = nil
    result = type(result) == 'table' and result or {}
    reason = tostring(reason or result.reason or 'closed')
    if result.reason == nil then result.reason = reason end
    if result.success == nil then result.success = reason == 'completed' end

    if not fromBackend and session.backend and session.backend.Close then
        pcall(session.backend.Close, reason)
    end
    setFocus(session, false)
    if session.closeNui then SendNUIMessage({ action = 'close' }) end
    if ScheduleAnimStop then ScheduleAnimStop() end
    emitReset(reason, session)

    local callback = session.onDone
    session.onDone = nil
    if callback then
        callback(result.success == true, result)
    end
    return true
end

function CloseActiveMinigame(reason, result, sessionId)
    return MinigameManager.Close(reason, result, sessionId)
end

exports('CloseActiveMinigame', CloseActiveMinigame)
exports('IsMinigameActive', function()
    return MinigameManager.IsActive()
end)

local function serverAbort(reason, token)
    local session = active
    if not session then return end
    if reason ~= nil and tostring(reason) == tostring(session.craftToken) then
        reason, token = token, reason
    end
    if token ~= nil and tostring(token) ~= tostring(session.craftToken) then return end
    MinigameManager.Close(reason or 'server_abort', { success = false })
end

RegisterNetEvent('mrp_drugs:client:abortProduction', serverAbort)
RegisterNetEvent('mrp_drugs:client:vapeProductionAbort', serverAbort)
RegisterNetEvent('mrp_drugs:client:abortVapeProduction', serverAbort)

local function closeForPlayer(reason)
    if active then MinigameManager.Close(reason, { success = false }) end
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closeForPlayer('player_unload')
end)

AddEventHandler('baseevents:onPlayerDied', function()
    closeForPlayer('player_died')
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    closeForPlayer('player_killed')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not active then return end
    local session = active
    active = nil
    session.finished = true
    if session.craftToken then
        TriggerServerEvent('mrp_drugs:server:cancelCraft', session.craftToken, 'resource_stop')
    end
    if session.backend and session.backend.Close then
        pcall(session.backend.Close, 'resource_stop')
    end
    setFocus(session, false)
    emitReset('resource_stop', session)
end)

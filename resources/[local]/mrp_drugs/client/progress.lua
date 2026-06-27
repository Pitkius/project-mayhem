local QBCore = exports['qb-core']:GetCoreObject()

DrugProgress = {}

local progressToken = 0

local DEFAULT_DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

local function applyDisables(disableControls)
    disableControls = disableControls or DEFAULT_DISABLE
    if disableControls.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 21, true)
    end
    if disableControls.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
    end
    if disableControls.disableCombat then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
    end
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function hideProgress()
    SendNUIMessage({ action = 'craftProgressHide' })
end

function DrugProgress.run(name, label, durationMs, useWhileDead, canCancel, disableControls, animation, onFinish, onCancel)
    durationMs = tonumber(durationMs) or 5000
    label = label or 'Vykdoma…'
    canCancel = canCancel ~= false
    disableControls = disableControls or DEFAULT_DISABLE

    if GetResourceState('progressbar') == 'started' then
        return QBCore.Functions.Progressbar(name, label, durationMs, useWhileDead, canCancel, disableControls, animation, {}, {}, onFinish, onCancel)
    end

    progressToken = progressToken + 1
    local token = progressToken
    local ped = PlayerPedId()
    local animDict = animation and (animation.animDict or animation.dict)
    local animClip = animation and (animation.anim or animation.clip or 'base')
    local animFlags = animation and (animation.flags or 49) or 49

    if animDict and loadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animClip, 4.0, 4.0, -1, animFlags, 0, false, false, false)
    end

    local phaseStart = GetGameTimer()
    local endAt = phaseStart + durationMs

    SendNUIMessage({
        action = 'craftProgress',
        data = {
            label = label,
            phaseIndex = 1,
            phaseCount = 1,
            durationMs = durationMs,
            totalMs = durationMs,
            elapsedMs = 0,
        },
    })

    CreateThread(function()
        local lastNuiUpdate = 0
        while GetGameTimer() < endAt do
            if token ~= progressToken then return end

            applyDisables(disableControls)

            if animDict and animClip then
                if not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
                    TaskPlayAnim(ped, animDict, animClip, 4.0, 4.0, -1, animFlags, 0, false, false, false)
                end
            end

            if canCancel and (IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200)) then
                hideProgress()
                ClearPedTasks(ped)
                if onCancel then onCancel() end
                return
            end

            local now = GetGameTimer()
            if now - lastNuiUpdate >= 100 then
                lastNuiUpdate = now
                local phaseElapsed = now - phaseStart
                SendNUIMessage({
                    action = 'craftProgressUpdate',
                    data = {
                        totalRemainingMs = math.max(0, durationMs - phaseElapsed),
                        overallPct = math.min(100, math.floor((phaseElapsed / durationMs) * 100)),
                    },
                })
            end

            Wait(0)
        end

        if token ~= progressToken then return end
        hideProgress()
        ClearPedTasks(ped)
        if onFinish then onFinish() end
    end)
end

function DrugProgress.cancel()
    progressToken = progressToken + 1
    hideProgress()
    ClearPedTasks(PlayerPedId())
end

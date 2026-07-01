local QBCore = exports['qb-core']:GetCoreObject()

local DEFAULT_DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

local function applyDisableControls(disableControls)
    if type(disableControls) ~= 'table' then return end
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

function RestraintProgress(name, label, durationMs, canCancel, anim)
    durationMs = tonumber(durationMs) or 4000
    canCancel = canCancel ~= false
    local animDict, animClip, animFlags = nil, nil, 49
    if type(anim) == 'table' then
        animDict = anim.dict
        animClip = anim.clip
        animFlags = anim.flag or 49
    end

    if GetResourceState('progressbar') == 'started' then
        local done = false
        local cancelled = false
        QBCore.Functions.Progressbar(name, label or 'Vykdoma…', durationMs, false, canCancel, DEFAULT_DISABLE, {
            animDict = animDict,
            anim = animClip,
            flags = animFlags,
        }, {}, {}, function()
            done = true
        end, function()
            cancelled = true
        end)
        local deadline = GetGameTimer() + durationMs + 800
        while GetGameTimer() < deadline do
            if cancelled then return false end
            if done then return true end
            Wait(50)
        end
        return done
    end

    local endAt = GetGameTimer() + durationMs
    local ped = PlayerPedId()
    if animDict and animClip then
        RequestAnimDict(animDict)
        local deadline = GetGameTimer() + 3000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < deadline do
            Wait(10)
        end
        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(ped, animDict, animClip, 2.0, 2.0, -1, animFlags, 0.0, false, false, false)
        end
    end
    while GetGameTimer() < endAt do
        applyDisableControls(DEFAULT_DISABLE)
        if canCancel and (IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200)) then
            ClearPedTasks(ped)
            return false
        end
        Wait(0)
    end
    ClearPedTasks(ped)
    return true
end

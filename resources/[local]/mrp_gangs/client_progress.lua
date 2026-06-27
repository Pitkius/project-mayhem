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

--- Grąžina true jei baigta, false jei atšaukta.
function GangRunProgressSync(name, label, durationMs, disableControls, canCancel, anim)
    durationMs = tonumber(durationMs) or 5000
    disableControls = disableControls or DEFAULT_DISABLE
    canCancel = canCancel ~= false
    local animDict, animClip, animFlags = nil, nil, nil
    if type(anim) == 'table' then
        animDict = anim.dict
        animClip = anim.clip
        animFlags = anim.flag
    end

    if GetResourceState('progressbar') == 'started' then
        local done = false
        local cancelled = false
        QBCore.Functions.Progressbar(name, label or 'Vykdoma…', durationMs, false, canCancel, disableControls, {
            animDict = animDict,
            anim = animClip,
            flags = animFlags or 1,
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
            TaskPlayAnim(ped, animDict, animClip, 2.0, 2.0, -1, animFlags or 1, 0.0, false, false, false)
        end
    end
    while GetGameTimer() < endAt do
        applyDisableControls(disableControls)
        if canCancel and (IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200)) then
            ClearPedTasks(ped)
            return false
        end
        Wait(0)
    end
    ClearPedTasks(ped)
    return true
end

function GangRunProgressAsync(name, label, durationMs, disableControls, canCancel, onFinish, onCancel)
    CreateThread(function()
        local ok = GangRunProgressSync(name, label, durationMs, disableControls, canCancel)
        if ok then
            if onFinish then onFinish() end
        else
            if onCancel then onCancel() end
        end
    end)
end

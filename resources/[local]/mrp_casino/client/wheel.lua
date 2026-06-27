local QBCore = exports['qb-core']:GetCoreObject()

local spinning = false

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasAnimDictLoaded(dict)
end

local function playSpinAnim(ped)
    local lib = 'anim_casino_a@amb@casino@games@lucky7wheel@female'
    if IsPedMale(ped) then
        lib = 'anim_casino_a@amb@casino@games@lucky7wheel@male'
    end
    if not loadAnimDict(lib) then return end

    local move = (Config.Wheel and Config.Wheel.movePos) or vector3(1109.55, 228.75, -49.64)
    TaskGoStraightToCoord(ped, move.x, move.y, move.z, 1.0, 8000, (Config.Wheel and Config.Wheel.moveHeading) or 0.0, 0.0)

    local moved = false
    local deadline = GetGameTimer() + 5000
    while not moved and GetGameTimer() < deadline do
        local c = GetEntityCoords(ped)
        if #(c - move) < 0.35 then moved = true end
        Wait(0)
    end

    TaskPlayAnim(ped, lib, 'enter_right_to_baseidle', 8.0, -8.0, -1, 0, 0, false, false, false)
    while IsEntityPlayingAnim(ped, lib, 'enter_right_to_baseidle', 3) do
        DisableAllControlActions(0)
        Wait(0)
    end

    TaskPlayAnim(ped, lib, 'enter_to_armraisedidle', 8.0, -8.0, -1, 0, 0, false, false, false)
    while IsEntityPlayingAnim(ped, lib, 'enter_to_armraisedidle', 3) do
        DisableAllControlActions(0)
        Wait(0)
    end

    TaskPlayAnim(ped, lib, 'armraisedidle_to_spinningidle_high', 8.0, -8.0, -1, 0, 0, false, false, false)
end

local function animateWheel(slot)
    local wheel = Casino.getWheelEntity and Casino.getWheelEntity()
    if not wheel or not DoesEntityExist(wheel) then return end

    slot = math.max(1, math.min(20, tonumber(slot) or 1))
    local winAngle = (slot - 1) * 18.0
    local rollAngle = winAngle + (360.0 * 8)
    local midLength = rollAngle / 2.0
    local speedIntCnt = 1.0

    SetEntityRotation(wheel, 0.0, 0.0, 0.0, 2, true)

    while rollAngle > 0.0 do
        local retval = GetEntityRotation(wheel, 2)
        if rollAngle > midLength then
            speedIntCnt = speedIntCnt + 1.0
        else
            speedIntCnt = speedIntCnt - 1.0
            if speedIntCnt < 0.0 then speedIntCnt = 0.0 end
        end
        local rollspeed = speedIntCnt / 10.0
        local newY = retval.y - rollspeed
        rollAngle = rollAngle - rollspeed
        SetEntityRotation(wheel, 0.0, newY, (Config.Wheel and Config.Wheel.heading) or 0.0, 2, true)
        Wait(0)
    end
end

local function notifyResult(res)
    if res.type == 'none' then
        QBCore.Functions.Notify('Ratas: ' .. (res.label or 'Nieko'), 'error')
    elseif res.type == 'vehicle' and res.carPlate then
        QBCore.Functions.Notify(
            ('JACKPOT! Laimėjote %s — numeriai %s (garaže).'):format(res.carLabel or res.carModel or 'automobilį', res.carPlate),
            'success', 10000
        )
    elseif res.type == 'chips' then
        QBCore.Functions.Notify(('Ratas: %s!'):format(res.label or 'Prizas'), 'success')
    else
        QBCore.Functions.Notify(('Ratas: %s!'):format(res.label or 'Prizas'), 'success')
    end
end

RegisterNetEvent('mrp_casino:client:openWheel', function()
    if spinning then return end
    if not Casino.canUseCasino() then return end

    QBCore.Functions.TriggerCallback('mrp_casino:server:spinWheel', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Ratas neprieinamas.', 'error')
            return
        end

        spinning = true
        local ped = PlayerPedId()
        CreateThread(function() playSpinAnim(ped) end)
        CreateThread(function() animateWheel(res.slot) end)

        Wait(9000)
        ClearPedTasks(ped)
        spinning = false
        notifyResult(res)
    end)
end)

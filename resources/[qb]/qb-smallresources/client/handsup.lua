local handsUp = false

local function isPlayingHandsup(ped)
    return IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
end

local function setHandsDown(clearTasks)
    handsUp = false
    exports['qb-smallresources']:removeDisableControls(Config.HandsUp.controls)
    if clearTasks ~= false then
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            ClearPedSecondaryTask(ped)
        end
    end
end

exports('resetHandsupState', function()
    setHandsDown(false)
end)

RegisterCommand(Config.HandsUp.command, function()
    local ped = PlayerPedId()
    local isCuffed = false
    if GetResourceState('qb-policejob') == 'started' then
        local ok, val = pcall(function()
            return exports['qb-policejob']:IsHandcuffed()
        end)
        if ok and val then
            isCuffed = true
        end
    end
    if isCuffed then return end
    if LocalPlayer.state.ltpdCuffed then return end
    if IsPedInAnyVehicle(ped, false) then return end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return end
    local okBusy, isCarryBusy = pcall(function()
        if GetResourceState('mrp_carry') ~= 'started' then return false end
        return exports['mrp_carry']:IsCarryBusy()
    end)
    if okBusy and isCarryBusy then return end

    if GetResourceState('mrp_emotes') == 'started' then
        local okPlaying, isEmotePlaying = pcall(function()
            return exports['mrp_emotes']:IsEmotePlaying()
        end)
        if okPlaying and isEmotePlaying then
            pcall(function()
                exports['mrp_emotes']:CancelEmote(true)
            end)
            return
        end
    end

    -- Animacija nutrūko, bet rankų būsena liko — atstatom be pakartotinio pakėlimo
    if handsUp and not isPlayingHandsup(ped) then
        setHandsDown(true)
        return
    end

    if not HasAnimDictLoaded('missminuteman_1ig_2') then
        RequestAnimDict('missminuteman_1ig_2')
        while not HasAnimDictLoaded('missminuteman_1ig_2') do
            Wait(10)
        end
    end

    handsUp = not handsUp
    if handsUp then
        ClearPedSecondaryTask(ped)
        TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, 8.0, -1, 50, 0, false, false, false)
        exports['qb-smallresources']:addDisableControls(Config.HandsUp.controls)
    else
        setHandsDown(true)
    end
end, false)

RegisterKeyMapping(Config.HandsUp.command, 'Hands Up', 'keyboard', Config.HandsUp.keybind)
exports('getHandsup', function() return handsUp end)

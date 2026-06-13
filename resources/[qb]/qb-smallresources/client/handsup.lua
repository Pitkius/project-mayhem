local handsUp = false

local function isPlayingHandsup(ped)
    return IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
end

local function setHandsDown(clearTasks)
    if not handsUp then return end
    handsUp = false
    if clearTasks ~= false then
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            ClearPedSecondaryTask(ped)
        end
    end
    exports['qb-smallresources']:removeDisableControls(Config.HandsUp.controls)
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
        if GetResourceState('fivempro_carry') ~= 'started' then return false end
        return exports['fivempro_carry']:IsCarryBusy()
    end)
    if okBusy and isCarryBusy then return end

    -- Atšaukti tik aktyvią emote animaciją (ne rankų pakėlimą)
    if not handsUp or not isPlayingHandsup(ped) then
        if GetResourceState('fivempro_emotes') == 'started' then
            pcall(function()
                exports['fivempro_emotes']:CancelEmote(true)
            end)
        end
    end

    -- Animacijos kartais palieka handsUp=true be animacijos
    if handsUp and not isPlayingHandsup(ped) then
        setHandsDown(false)
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

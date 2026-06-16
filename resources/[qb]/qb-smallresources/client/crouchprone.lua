local isCrouching = false
local walkSet = 'default'

local function loadAnimSet(anim)
    if not HasAnimSetLoaded(anim) then
        RequestAnimSet(anim)
        while not HasAnimSetLoaded(anim) do
            Wait(10)
        end
    end
end

local function resetAnimSet()
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 1.0)
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)

    if walkSet ~= 'default' then
        loadAnimSet(walkSet)
        SetPedMovementClipset(ped, walkSet, 1.0)
        RemoveAnimSet(walkSet)
    end
end

local function setCrouch(state)
    local ped = PlayerPedId()
    if state then
        if IsPedSittingInAnyVehicle(ped) or IsPedFalling(ped) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
            return
        end
        ClearPedTasks(ped)
        loadAnimSet('move_ped_crouched')
        SetPedMovementClipset(ped, 'move_ped_crouched', 1.0)
        SetPedStrafeClipset(ped, 'move_ped_crouched_strafing')
        SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
        isCrouching = true
    else
        resetAnimSet()
        SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
        isCrouching = false
    end
end

RegisterNetEvent('crouchprone:client:SetWalkSet', function(clipset)
    walkSet = clipset
end)

local function toggleCrouch()
    if IsPauseMenuActive() then return end
    setCrouch(not isCrouching)
end

RegisterCommand('togglecrouch', toggleCrouch, false)
RegisterKeyMapping('togglecrouch', 'Atsitūpti', 'keyboard', 'LCONTROL')

-- Blokuoja GTA sneak (tylus ėjimas su Ctrl), palieka tik atsitūpimą
CreateThread(function()
    while true do
        local ped = PlayerPedId()

        DisableControlAction(0, 36, true) -- INPUT_DUCK (Ctrl)
        DisableControlAction(1, 36, true)
        DisableControlAction(2, 36, true)

        if GetPedStealthMovement(ped) then
            SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
        end

        if isCrouching and (IsPedSittingInAnyVehicle(ped) or IsPedDeadOrDying(ped, true)) then
            setCrouch(false)
        end

        Wait(0)
    end
end)

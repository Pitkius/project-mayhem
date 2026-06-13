local blocked = false

local function rotationToDirection(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local cosX = math.abs(math.cos(radX))
    return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

local function castRay(from, to, ped)
    local handle = StartShapeTestRay(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        511, ped, 4
    )

    local result, hit, endCoords = 1, 0, vector3(0.0, 0.0, 0.0)
    local deadline = GetGameTimer() + 25

    while result == 1 and GetGameTimer() < deadline do
        result, hit, endCoords = GetShapeTestResult(handle)
        if result ~= 1 then break end
        Wait(0)
    end

    if result == 2 and hit == 1 then
        return true, endCoords
    end

    return false, to
end

local function getWeaponOrigin(ped)
    local bone = GetPedBoneIndex(ped, 28422) -- PH_R_Hand
    if bone ~= -1 then
        return GetWorldPositionOfEntityBone(ped, bone)
    end

    return GetPedBoneCoords(ped, 57005, 0.05, 0.0, 0.0)
end

local function isAiming(ped)
    if IsPlayerFreeAiming(PlayerId()) then
        return true
    end

    if IsControlPressed(0, 25) then
        return true
    end

    if IsPedShooting(ped) then
        return true
    end

    return false
end

local function isGhostPeeking(ped)
    if not Config.Enabled then
        return false
    end

    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
        return false
    end

    if not IsPedArmed(ped, 4) then
        return false
    end

    local weapon = GetSelectedPedWeapon(ped)
    if Config.IgnoredWeapons[weapon] then
        return false
    end

    if not isAiming(ped) then
        return false
    end

    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local destination = camCoord + (direction * Config.MaxRayDistance)
    local weaponCoord = getWeaponOrigin(ped)

    local camHit, camEnd = castRay(camCoord, destination, ped)
    local weaponHit, weaponEnd = castRay(weaponCoord, destination, ped)

    local camDist = camHit and #(camCoord - camEnd) or Config.MaxRayDistance
    local weaponDist = weaponHit and #(weaponCoord - weaponEnd) or Config.MaxRayDistance

    if weaponHit and camDist > (weaponDist + Config.DistanceThreshold) then
        return true
    end

    if weaponHit and not camHit then
        return true
    end

    return false
end

local function setIndicator(active)
    SendNUIMessage({
        action = 'ghostpeek',
        active = active == true,
    })
end

local function blockFiring()
    local playerId = PlayerId()
    DisablePlayerFiring(playerId, true)
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 47, true)  -- weapon
    DisableControlAction(0, 58, true)  -- weapon
    DisableControlAction(0, 140, true) -- melee light
    DisableControlAction(0, 141, true) -- melee heavy
    DisableControlAction(0, 142, true) -- melee alternate
    DisableControlAction(0, 257, true) -- attack 2
    DisableControlAction(0, 263, true)
    DisableControlAction(0, 264, true)
end

CreateThread(function()
    while true do
        local sleep = 250
        local ped = PlayerPedId()

        if Config.Enabled and DoesEntityExist(ped) and IsPedArmed(ped, 4) and isAiming(ped) then
            sleep = 0
            local peeking = isGhostPeeking(ped)

            if peeking then
                blockFiring()
            end

            if peeking ~= blocked then
                blocked = peeking
                setIndicator(blocked)
            end
        elseif blocked then
            blocked = false
            setIndicator(false)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if blocked then
            blockFiring()
            Wait(0)
        else
            Wait(100)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    blocked = false
    setIndicator(false)
end)

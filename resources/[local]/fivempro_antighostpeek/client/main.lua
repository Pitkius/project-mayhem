local blocked = false

local function rotationToDirection(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local cosX = math.abs(math.cos(radX))
    return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

local function normalizeVec(vec)
    local len = #(vec)
    if len < 0.001 then
        return vector3(0.0, 0.0, 0.0), 0.0
    end
    return vec / len, len
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
        result, hit, endCoords, _, _ = GetShapeTestResult(handle)
        if result ~= 1 then
            break
        end
        Wait(0)
    end

    if result == 2 and hit == 1 then
        return true, endCoords
    end

    return false, to
end

local function isPathBlocked(from, to, ped)
    local dist = #(from - to)
    if dist < 0.05 then
        return false
    end

    local hit, endCoords = castRay(from, to, ped)
    if not hit then
        return false
    end

    local hitDist = #(from - endCoords)
    return hitDist < dist - Config.DistanceThreshold
end

local function getShootOrigins(ped, direction)
    local origins = {}
    local dir = select(1, normalizeVec(direction))

    local weaponEnt = GetCurrentPedWeaponEntityIndex(ped)
    if weaponEnt and weaponEnt ~= 0 and DoesEntityExist(weaponEnt) then
        origins[#origins + 1] = GetOffsetFromEntityInWorldCoords(weaponEnt, 0.0, 0.58, 0.03)
        origins[#origins + 1] = GetOffsetFromEntityInWorldCoords(weaponEnt, 0.0, 0.42, 0.08)
        origins[#origins + 1] = GetOffsetFromEntityInWorldCoords(weaponEnt, 0.0, 0.26, 0.02)
    end

    local hand = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    origins[#origins + 1] = hand + dir * 0.58
    origins[#origins + 1] = hand + dir * 0.42 + vector3(0.0, 0.0, 0.16)
    origins[#origins + 1] = hand + dir * 0.28

    local rhBone = GetPedBoneIndex(ped, 28422) -- PH_R_Hand
    if rhBone ~= -1 then
        origins[#origins + 1] = GetWorldPositionOfEntityBone(ped, rhBone) + dir * 0.45
    end

    local head = GetPedBoneCoords(ped, 31086, 0.08, 0.04, 0.0) -- SKEL_Head
    origins[#origins + 1] = head + dir * 0.18

    return origins
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

--- Ghost peek tik jei kamera mato taikinį (crosshair), bet nė vienas šūvio taškas negali pasiekti to taško.
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
    local farDest = camCoord + (direction * Config.MaxRayDistance)

    local camHit, camEnd = castRay(camCoord, farDest, ped)
    local aimTarget = camHit and camEnd or farDest
    local aimDist = #(camCoord - aimTarget)

    if aimDist < (Config.MinAimDistance or 2.0) then
        return false
    end

    local origins = getShootOrigins(ped, direction)
    for i = 1, #origins do
        if not isPathBlocked(origins[i], aimTarget, ped) then
            return false
        end
    end

    return true
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

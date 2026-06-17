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

local function getDistanceThreshold(dist)
    local base = Config.DistanceThreshold or 0.35
    local scale = Config.DistanceThresholdScale or 0.011
    local maxThreshold = Config.MaxDistanceThreshold or 1.85
    return math.min(maxThreshold, base + dist * scale)
end

local function isAttachedToPed(entityHit, ped)
    if not entityHit or entityHit == 0 or not ped or ped == 0 then
        return false
    end
    local current = entityHit
    for _ = 1, 5 do
        if current == ped then
            return true
        end
        local parent = GetEntityAttachedTo(current)
        if not parent or parent == 0 then
            break
        end
        current = parent
    end
    return false
end

local function isDeadPedEntity(entityHit)
    return entityHit
        and entityHit ~= 0
        and DoesEntityExist(entityHit)
        and IsEntityAPed(entityHit)
        and IsPedDeadOrDying(entityHit, true)
end

local function isIgnoredHitEntity(entityHit, ped, weaponEnt)
    if not entityHit or entityHit == 0 or not DoesEntityExist(entityHit) then
        return true
    end

    if entityHit == ped or isAttachedToPed(entityHit, ped) then
        return true
    end

    if weaponEnt and weaponEnt ~= 0 and (entityHit == weaponEnt or isAttachedToPed(entityHit, weaponEnt)) then
        return true
    end

    if Config.IgnoreDeadPedHits ~= false and isDeadPedEntity(entityHit) then
        return true
    end

    if IsEntityAPed(entityHit) and IsPedAPlayer(entityHit) and entityHit == ped then
        return true
    end

    return false
end

local function isPenetrableMaterial(materialHash)
    return materialHash and materialHash ~= 0 and Config.PenetrableMaterials[materialHash] == true
end

local function waitShapeTestResult(handle, useMaterial)
    local deadline = GetGameTimer() + 30
    while GetGameTimer() < deadline do
        local result, hit, endCoords, surfaceNormal, materialHash, entityHit

        if useMaterial then
            result, hit, endCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResultIncludingMaterial(handle)
        else
            result, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
            materialHash = 0
        end

        if result ~= 1 then
            return result == 2 and hit == 1, endCoords, materialHash or 0, entityHit or 0
        end

        Wait(0)
    end

    return false, vector3(0.0, 0.0, 0.0), 0, 0
end

local function castProbe(from, to, ped, traceFlags, traceOptions)
    local handle = StartShapeTestLosProbe(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        traceFlags or Config.TraceFlags or 255,
        ped,
        traceOptions or Config.TraceOptions or 7
    )

    return waitShapeTestResult(handle, true)
end

--- Spindulys ta pačia kryptimi; praleidžia krūmus, žolę, tinklelius ir pan.
local function traceAlongDirection(origin, direction, maxDistance, ped, weaponEnt)
    local dir = select(1, normalizeVec(direction))
    if #(dir) < 0.001 or maxDistance <= 0.05 then
        return maxDistance, false, 0, 0, origin
    end

    local traveled = 0.0
    local cursor = origin
    local maxPasses = Config.RayMaxPasses or 5
    local step = Config.PenetrateStep or 0.1

    for _ = 1, maxPasses do
        local remaining = maxDistance - traveled
        if remaining <= 0.05 then
            break
        end

        local dest = cursor + dir * remaining
        local hit, endCoords, materialHash, entityHit = castProbe(cursor, dest, ped)

        if not hit or not endCoords then
            return maxDistance, false, 0, 0, dest
        end

        if isIgnoredHitEntity(entityHit, ped, weaponEnt) then
            local selfSkip = Config.SelfBodyAdvance or 0.5
            local segLen = #(cursor - endCoords)
            local advance = math.max(step, segLen + step)
            if entityHit == ped or isAttachedToPed(entityHit, ped) then
                advance = math.max(advance, selfSkip)
            end
            traveled = traveled + advance
            cursor = cursor + dir * advance
            if traveled >= maxDistance - 0.05 then
                return maxDistance, false, 0, 0, cursor
            end
        elseif isPenetrableMaterial(materialHash) then
            local seg = #(cursor - endCoords)
            traveled = traveled + seg + step
            cursor = endCoords + dir * step
            if traveled >= maxDistance - 0.05 then
                return maxDistance, false, 0, 0, cursor
            end
        else
            traveled = traveled + #(cursor - endCoords)
            return traveled, true, materialHash, entityHit, endCoords
        end
    end

    return maxDistance, false, 0, 0, origin + dir * maxDistance
end

local function getShootOrigins(ped, direction)
    local origins = {}
    local dir = select(1, normalizeVec(direction))

    local weaponEnt = GetCurrentPedWeaponEntityIndex(ped)
    if weaponEnt and weaponEnt ~= 0 and DoesEntityExist(weaponEnt) then
        local offsets = Config.WeaponMuzzleOffsets or { 0.82, 0.62, 0.42 }
        for _, yOff in ipairs(offsets) do
            origins[#origins + 1] = GetOffsetFromEntityInWorldCoords(weaponEnt, 0.0, yOff, 0.03)
        end
        if Config.WeaponOnlyOrigins ~= false then
            return origins, weaponEnt
        end
    end

    local hand = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    origins[#origins + 1] = hand + dir * 0.58
    origins[#origins + 1] = hand + dir * 0.42 + vector3(0.0, 0.0, 0.08)

    local rhBone = GetPedBoneIndex(ped, 28422)
    if rhBone ~= -1 then
        origins[#origins + 1] = GetWorldPositionOfEntityBone(ped, rhBone) + dir * 0.48
    end

    return origins, weaponEnt
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

local function isClearWeaponPath(origin, direction, camDistance, ped, weaponEnt, threshold)
    local weaponDist, weaponHit, _, weaponEntity = traceAlongDirection(
        origin,
        direction,
        camDistance + 0.35,
        ped,
        weaponEnt
    )

    if not weaponHit then
        return true
    end

    if Config.IgnoreDeadPedHits ~= false and isDeadPedEntity(weaponEntity) then
        return true
    end

    return weaponDist >= camDistance - threshold
end

--- Ghost peek: kamera mato toliau nei realus šūvis (už kietos kliūties), ne krūmo/tinklelio.
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

    local camCoord = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(2)
    local direction = rotationToDirection(camRot)

    local camDistance, camHit, camMaterial, camEntity = traceAlongDirection(
        camCoord,
        direction,
        Config.MaxRayDistance,
        ped,
        nil
    )

    if not camHit then
        return false
    end

    if camDistance < (Config.MinAimDistance or 2.0) then
        return false
    end

    if camEntity and camEntity ~= 0 and DoesEntityExist(camEntity) and IsEntityAPed(camEntity) then
        if Config.IgnoreDeadPedHits ~= false and IsPedDeadOrDying(camEntity, true) then
            return false
        end
        -- Kamera mato gyvą pedą — tikriname ar ginklas gali pasiekti tą patį atstumą.
    elseif isPenetrableMaterial(camMaterial) then
        return false
    end

    local threshold = getDistanceThreshold(camDistance)
    local origins, weaponEnt = getShootOrigins(ped, direction)
    local clearPaths = 0

    for i = 1, #origins do
        if isClearWeaponPath(origins[i], direction, camDistance, ped, weaponEnt, threshold) then
            clearPaths = clearPaths + 1
        end
    end

    local minClear = Config.MinClearPaths or 1
    if weaponEnt and weaponEnt ~= 0 then
        minClear = Config.MinClearPathsWithWeapon or minClear
    end
    return clearPaths < minClear
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
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 47, true)
    DisableControlAction(0, 58, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
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

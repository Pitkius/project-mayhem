local QBCore = exports['qb-core']:GetCoreObject()

local lastNotifyAt = 0
local FIRE_CONTROLS = { 24, 47, 58, 140, 141, 142, 257, 263, 264 }

-- ── Vektoriai / raycast ─────────────────────────────────────────────────────

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

local function isPenetrableMaterial(materialHash)
    return materialHash and materialHash ~= 0 and Config.PenetrableMaterials[materialHash] == true
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
    return false
end

local function waitShapeTestResult(handle)
    local deadline = GetGameTimer() + 30
    while GetGameTimer() < deadline do
        local result, hit, endCoords, surfaceNormal, materialHash, entityHit =
            GetShapeTestResultIncludingMaterial(handle)
        if result ~= 1 then
            return result == 2 and hit == 1, endCoords, materialHash or 0, entityHit or 0
        end
        Wait(0)
    end
    return false, vector3(0.0, 0.0, 0.0), 0, 0
end

local function castProbe(from, to, ped, ignoreEnt)
    local handle = StartShapeTestRay(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        Config.TraceFlags or 255,
        ignoreEnt or ped,
        Config.TraceOptions or 7
    )
    return waitShapeTestResult(handle)
end

local function castLosProbe(from, to, ped)
    local handle = StartShapeTestLosProbe(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        Config.TraceFlags or 255,
        ped,
        Config.TraceOptions or 7
    )
    return waitShapeTestResult(handle)
end

local function traceAlongDirection(origin, direction, maxDistance, ped, weaponEnt)
    local dir = select(1, normalizeVec(direction))
    if #(dir) < 0.001 or maxDistance <= 0.05 then
        return maxDistance, false, 0, 0, origin
    end

    local traveled = 0.0
    local cursor = origin
    local maxPasses = Config.RayMaxPasses or 8
    local step = Config.PenetrateStep or 0.1

    for _ = 1, maxPasses do
        local remaining = maxDistance - traveled
        if remaining <= 0.05 then
            break
        end

        local dest = cursor + dir * remaining
        local hit, endCoords, materialHash, entityHit = castLosProbe(cursor, dest, ped)

        if not hit or not endCoords then
            return maxDistance, false, 0, 0, dest
        end

        if isIgnoredHitEntity(entityHit, ped, weaponEnt) then
            local segLen = #(cursor - endCoords)
            local advance = math.max(step, segLen + step)
            if entityHit == ped or isAttachedToPed(entityHit, ped) then
                advance = math.max(advance, Config.SelfBodyAdvance or 0.45)
            end
            traveled = traveled + advance
            cursor = cursor + dir * advance
        elseif isPenetrableMaterial(materialHash) then
            local seg = #(cursor - endCoords)
            traveled = traveled + seg + step
            cursor = endCoords + dir * step
        else
            traveled = traveled + #(cursor - endCoords)
            return traveled, true, materialHash, entityHit, endCoords
        end

        if traveled >= maxDistance - 0.05 then
            return maxDistance, false, 0, 0, cursor
        end
    end

    return maxDistance, false, 0, 0, origin + dir * maxDistance
end

-- ── Ginklas / taikinys ──────────────────────────────────────────────────────

local function isValidPlayerTarget(entity, shooterPed)
    if not entity or entity == 0 or entity == shooterPed then
        return false
    end
    if not DoesEntityExist(entity) or not IsEntityAPed(entity) then
        return false
    end
    if not IsPedAPlayer(entity) then
        return false
    end
    if IsPedDeadOrDying(entity, true) then
        return false
    end
    return true
end

local function getShootOrigins(ped, direction)
    local origins = {}
    local dir = select(1, normalizeVec(direction))
    local weaponEnt = GetCurrentPedWeaponEntityIndex(ped)

    if weaponEnt and weaponEnt ~= 0 and DoesEntityExist(weaponEnt) then
        for _, yOff in ipairs(Config.WeaponMuzzleOffsets or { 0.82, 0.62 }) do
            origins[#origins + 1] = GetOffsetFromEntityInWorldCoords(weaponEnt, 0.0, yOff, 0.03)
        end
        if Config.WeaponOnlyOrigins ~= false then
            return origins, weaponEnt
        end
    end

    local hand = GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0)
    origins[#origins + 1] = hand + dir * 0.55
    return origins, weaponEnt
end

local function getPedBonePos(ped, boneId)
    return GetPedBoneCoords(ped, boneId, 0.0, 0.0, 0.0)
end

local function getTargetAimPoint(targetPed)
    for _, boneId in ipairs(Config.TargetAimBones or { 24818, 31086 }) do
        local pos = getPedBonePos(targetPed, boneId)
        if pos and #(pos) > 0.01 then
            return pos
        end
    end
    return GetEntityCoords(targetPed)
end

local function angleBetweenDegrees(a, b)
    local dot = a.x * b.x + a.y * b.y + a.z * b.z
    dot = math.max(-1.0, math.min(1.0, dot))
    return math.deg(math.acos(dot))
end

local function findAimedPlayerTarget(shooterPed)
    local playerId = PlayerId()
    local maxDist = Config.MaxTargetDistance or 120.0

    local _, freeAimEntity = GetEntityPlayerIsFreeAimingAt(playerId)
    if isValidPlayerTarget(freeAimEntity, shooterPed) then
        return freeAimEntity
    end

    local camCoord = GetFinalRenderedCamCoord()
    local camDir = rotationToDirection(GetFinalRenderedCamRot(2))
    local rayDist, rayHit, _, rayEntity = traceAlongDirection(
        camCoord,
        camDir,
        maxDist,
        shooterPed,
        nil
    )

    if rayHit and isValidPlayerTarget(rayEntity, shooterPed) then
        return rayEntity
    end

    if rayHit and rayEntity and rayEntity ~= 0 and DoesEntityExist(rayEntity) then
        local attachedTo = GetEntityAttachedTo(rayEntity)
        if isValidPlayerTarget(attachedTo, shooterPed) then
            return attachedTo
        end
    end

    local bestPed, bestAngle = nil, Config.AimConeDegrees or 9.0
    local shooterCoords = GetEntityCoords(shooterPed)

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= playerId then
            local tp = GetPlayerPed(pid)
            if isValidPlayerTarget(tp, shooterPed) then
                local tCoords = getTargetAimPoint(tp)
                local dist = #(shooterCoords - tCoords)
                if dist <= maxDist then
                    local toTarget = select(1, normalizeVec(tCoords - camCoord))
                    local ang = angleBetweenDegrees(camDir, toTarget)
                    if ang < bestAngle then
                        local losDist, losHit, _, losEnt = traceAlongDirection(camCoord, toTarget, dist, shooterPed, nil)
                        local hitsTarget = not losHit or losEnt == tp or isAttachedToPed(losEnt, tp)
                        if hitsTarget or losDist >= dist - 1.2 then
                            bestAngle = ang
                            bestPed = tp
                        end
                    end
                end
            end
        end
    end

    return bestPed
end

-- ── Sąžiningumo tikrinimas ──────────────────────────────────────────────────

local function hasClearLos(from, to, ped, weaponEnt, targetEnt)
    local dist = #(from - to)
    if dist < 0.05 then
        return true
    end
    local dir = (to - from) / dist
    local traveled, hit, _, hitEnt = traceAlongDirection(from, dir, dist + 0.35, ped, weaponEnt)

    if not hit then
        return true
    end

    if targetEnt and (hitEnt == targetEnt or isAttachedToPed(hitEnt, targetEnt)) then
        return true
    end

    local slack = Config.MuzzleHitSlack or 0.45
    return traveled >= dist - slack
end

local function countBonesVisibleTo(fromPed, toPed, boneList)
    local eye = getPedBonePos(fromPed, 31086) + vector3(0.0, 0.0, 0.08)
    local visible = 0

    for _, boneId in ipairs(boneList or {}) do
        local bonePos = getPedBonePos(toPed, boneId)
        if hasClearLos(eye, bonePos, fromPed, nil, toPed) then
            visible = visible + 1
        end
    end

    return visible
end

local function isMuzzleBehindCover(muzzle, direction, ped, weaponEnt)
    local dir = select(1, normalizeVec(direction))
    local embed = Config.MuzzleWallEmbedDistance or 0.14
    local behind = muzzle - dir * 0.22
    local dist, hit = traceAlongDirection(behind, dir, embed + 0.08, ped, weaponEnt)
    return hit and dist < embed
end

--- Blokuoti tik nesąžiningą kampą prieš žaidėją (ne taikymąsi į sieną).
local function shouldBlockGhostPeekShot(shooterPed, targetPed)
    if not targetPed or not isValidPlayerTarget(targetPed, shooterPed) then
        return false
    end

    local camDir = rotationToDirection(GetFinalRenderedCamRot(2))
    local targetPoint = getTargetAimPoint(targetPed)
    local origins, weaponEnt = getShootOrigins(shooterPed, camDir)

    -- 1) Ar bent vienas vamzdis gali pasiekti taikinį be kietos kliūties?
    for i = 1, #origins do
        if hasClearLos(origins[i], targetPoint, shooterPed, weaponEnt, targetPed) then
            return false
        end
    end

    -- 2) Ar priešininkas mato šaulio modelį?
    local shooterBonesSeen = countBonesVisibleTo(
        targetPed,
        shooterPed,
        Config.ShooterVisibilityBones
    )
    if shooterBonesSeen >= (Config.MinShooterBonesVisibleToTarget or 1) then
        return false
    end

    -- 3) Ar šūvis prasideda už kampo / sienos viduje?
    local muzzle = origins[1]
    if muzzle and isMuzzleBehindCover(muzzle, camDir, shooterPed, weaponEnt) then
        return true
    end

    -- 4) Kamera mato taikinį, bet vamzdis ir priešininkas — ne: klasikinis ghost peek.
    local camCoord = GetFinalRenderedCamCoord()
    if hasClearLos(camCoord, targetPoint, shooterPed, nil, targetPed) then
        return true
    end

    return false
end

-- ── Įvestis / pranešimai ────────────────────────────────────────────────────

local function isIgnoredWeapon(ped)
    local weapon = GetSelectedPedWeapon(ped)
    return Config.IgnoredWeapons[weapon] == true
end

local function isTryingToFire()
    for i = 1, #FIRE_CONTROLS do
        if IsControlPressed(0, FIRE_CONTROLS[i]) or IsDisabledControlPressed(0, FIRE_CONTROLS[i]) then
            return true
        end
    end
    return IsPedShooting(PlayerPedId())
end

local function blockFiringThisFrame()
    local playerId = PlayerId()
    DisablePlayerFiring(playerId, true)
    for i = 1, #FIRE_CONTROLS do
        DisableControlAction(0, FIRE_CONTROLS[i], true)
    end
end

local function notifyBlocked()
    local now = GetGameTimer()
    local cooldown = Config.NotifyCooldownMs or 2800
    if now - lastNotifyAt < cooldown then
        return
    end
    lastNotifyAt = now
    QBCore.Functions.Notify(Config.BlockMessage or 'Ghost Peek apsauga', 'error', 2200)
end

local function canEvaluate(ped)
    if not Config.Enabled then
        return false
    end
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
        return false
    end
    if not IsPedArmed(ped, 4) then
        return false
    end
    if isIgnoredWeapon(ped) then
        return false
    end
    return true
end

-- ── Pagrindinis ciklas: tik šūvio bandymas, ne taikymasis ───────────────────

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if canEvaluate(ped) and isTryingToFire() then
            local target = findAimedPlayerTarget(ped)
            if target and shouldBlockGhostPeekShot(ped, target) then
                blockFiringThisFrame()
                notifyBlocked()
            end
            Wait(0)
        else
            Wait(50)
        end
    end
end)

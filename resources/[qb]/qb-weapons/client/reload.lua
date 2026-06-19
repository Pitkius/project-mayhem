--- Stipresnis užtaisymas: native reload + atsarginės animacijos, kulkos kraunamos po vizualo.
WeaponReload = WeaponReload or {}

local activeReloadAnim = nil
local reloadMovementState = { sprint = false, moving = false }

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function allowReloadMovement()
    return Config.ReloadAllowMovement ~= false
end

local function isMovementControlPressed()
    for _, ctrl in ipairs({ 21, 32, 33, 34, 35 }) do
        if IsControlPressed(0, ctrl) or IsDisabledControlPressed(0, ctrl) then
            return true
        end
    end
    return false
end

local function isPedMoving(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedRunning(ped) or IsPedSprinting(ped) then return true end
    if GetEntitySpeed(ped) > 1.0 then return true end
    return isMovementControlPressed()
end

local function captureMovementState(ped)
    reloadMovementState.sprint = IsPedSprinting(ped)
        or IsControlPressed(0, 21)
        or IsDisabledControlPressed(0, 21)
    reloadMovementState.moving = isPedMoving(ped)
end

local function restoreMovementAfterReload(ped)
    if not allowReloadMovement() or not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsPedInAnyVehicle(ped, false) then return end

    ClearPedSecondaryTask(ped)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)

    local wantsSprint = reloadMovementState.sprint
        or IsControlPressed(0, 21)
        or IsDisabledControlPressed(0, 21)
    local wantsMove = reloadMovementState.moving or isMovementControlPressed()

    if not wantsMove and not wantsSprint then return end

    SetPedMoveRateOverride(ped, 1.0)
    if wantsSprint then
        SetPedMaxMoveBlendRatio(ped, 3.0)
        SetPedMinMoveBlendRatio(ped, 2.0)
    elseif wantsMove then
        SetPedMaxMoveBlendRatio(ped, 2.0)
        SetPedMinMoveBlendRatio(ped, 1.0)
    end
end

local function reloadAnimFlags()
    if allowReloadMovement() then
        return 48 -- viršutinė kūno dalis + žaidėjo valdymas, be loop
    end
    return 49
end

local function enableReloadMovementControls()
    if not allowReloadMovement() then return end
    EnableControlAction(0, 21, true) -- sprint
    EnableControlAction(0, 22, true) -- jump
    EnableControlAction(0, 30, true) -- move LR
    EnableControlAction(0, 31, true) -- move UD
    EnableControlAction(0, 32, true) -- W
    EnableControlAction(0, 33, true) -- S
    EnableControlAction(0, 34, true) -- A
    EnableControlAction(0, 35, true) -- D
end

local function loadAnimDict(dict)
    if not dict or dict == '' or HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function resolveInventoryWeaponName(weaponHash, weaponData)
    if weaponData and weaponData.name then
        return string.lower(tostring(weaponData.name))
    end
    if WeaponHash and WeaponHash.inventoryNameFromNative then
        return WeaponHash.inventoryNameFromNative(weaponHash)
    end
    return nil
end

local function isSwappedWeaponModel(invName)
    if not invName then return false end
    local map = Config.WeaponNativeHash
    return type(map) == 'table' and map[invName] ~= nil
end

local function pinClipDuringVisual(ped, weaponHash, clipNow)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    clipNow = math.max(0, tonumber(clipNow) or 0)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetPedAmmo(ped, weaponHash, clipNow)
    SetAmmoInClip(ped, weaponHash, clipNow)
end

local function suppressNativeReloadDuringVisual(ped, weaponHash, clipNow)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    pinClipDuringVisual(ped, weaponHash, clipNow)
    if IsPedReloading(ped) then
        SetCurrentPedWeapon(ped, weaponHash, true)
        pinClipDuringVisual(ped, weaponHash, clipNow)
    end
end

local function isReloadMoving()
    return allowReloadMovement()
        and (reloadMovementState.moving or reloadMovementState.sprint)
end

local function reloadAnimCandidates(weaponHash, weaponData)
    local moving = isReloadMoving()
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if invName == 'weapon_fgc9' then
        if moving then
            return {
                { 'weapons@rifle@lo@carbine_str', 'reload' },
                { 'weapons@submg@', 'reload' },
            }
        end
        return {
            { 'weapons@rifle@lo@carbine_str', 'reload_aim' },
            { 'weapons@rifle@lo@carbine_str', 'reload' },
            { 'weapons@submg@', 'reload_aim' },
            { 'weapons@submg@', 'reload' },
        }
    end

    local group = GetWeapontypeGroup(weaponHash)
    if group == `GROUP_SMG` or group == `GROUP_MG` then
        if moving then
            return {
                { 'weapons@submg@', 'reload' },
                { 'weapons@rifle@lo@carbine_str', 'reload' },
            }
        end
        return {
            { 'weapons@submg@', 'reload_aim' },
            { 'weapons@submg@', 'reload' },
            { 'weapons@rifle@lo@carbine_str', 'reload_aim' },
        }
    end
    if group == `GROUP_RIFLE` or group == `GROUP_SNIPER` then
        if moving then
            return {
                { 'weapons@rifle@lo@carbine_str', 'reload' },
                { 'weapons@submg@', 'reload' },
            }
        end
        return {
            { 'weapons@rifle@lo@carbine_str', 'reload_aim' },
            { 'weapons@rifle@lo@carbine_str', 'reload' },
            { 'weapons@submg@', 'reload_aim' },
        }
    end
    if group == `GROUP_SHOTGUN` then
        if moving then
            return {
                { 'weapons@shotgun@', 'reload' },
            }
        end
        return {
            { 'weapons@shotgun@', 'reload_aim' },
            { 'weapons@shotgun@', 'reload' },
        }
    end
  -- Pistoletai: judant tik `reload`, ne `reload_aim` (kitaip dubluojasi su native).
    if moving then
        return {
            { 'weapons@pistol@', 'reload' },
            { 'weapons@pistol@combat@', 'reload' },
        }
    end
    return {
        { 'weapons@pistol@', 'reload_aim' },
        { 'weapons@pistol@', 'reload' },
        { 'weapons@pistol@combat@', 'reload_aim' },
        { 'weapons@pistol@combat@', 'reload' },
    }
end

local function stopReloadAnimation(ped, restoreMovement)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if activeReloadAnim then
        if allowReloadMovement() then
            ClearPedSecondaryTask(ped)
        else
            StopAnimTask(ped, activeReloadAnim.dict, activeReloadAnim.anim, 1.0)
        end
        activeReloadAnim = nil
    end
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    if restoreMovement ~= false then
        restoreMovementAfterReload(ped)
    end
end

local function snapshotClipState(ped, weaponHash)
    local hasClip, clipNow = GetAmmoInClip(ped, weaponHash)
    clipNow = hasClip and (tonumber(clipNow) or 0) or 0
    local totalBefore = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    return clipNow, totalBefore
end

local function restoreClipState(ped, weaponHash, clipNow, totalBefore)
    SetPedAmmo(ped, weaponHash, totalBefore)
    SetAmmoInClip(ped, weaponHash, clipNow)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

local function primeReloadReserve(ped, weaponHash, clipNow, totalBefore, bulletsToLoad)
    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    if bulletsToLoad <= 0 then return totalBefore end
    local reserve = math.max(0, totalBefore - clipNow)
    if reserve >= bulletsToLoad then return totalBefore end
    local boosted = totalBefore + (bulletsToLoad - reserve)
    SetPedAmmo(ped, weaponHash, boosted)
    SetAmmoInClip(ped, weaponHash, clipNow)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    return boosted
end

local function playMobileReloadAnimation(ped, weaponHash, durationMs, weaponData, clipNow)
    local animFlags = reloadAnimFlags()
    for _, pair in ipairs(reloadAnimCandidates(weaponHash, weaponData)) do
        local dict, anim = pair[1], pair[2]
        if loadAnimDict(dict) then
            activeReloadAnim = { dict = dict, anim = anim }
            SetCurrentPedWeapon(ped, weaponHash, true)
            pinClipDuringVisual(ped, weaponHash, clipNow)
            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, durationMs, animFlags, 0.0, false, false, false)

            local deadline = GetGameTimer() + durationMs
            local replayAt = GetGameTimer() + 180
            while GetGameTimer() < deadline do
                if not DoesEntityExist(ped) then break end
                suppressNativeReloadDuringVisual(ped, weaponHash, clipNow)
                enableReloadMovementControls()
                if not isReloadMoving()
                    and GetGameTimer() >= replayAt
                    and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, durationMs, animFlags, 0.0, false, false, false)
                    replayAt = GetGameTimer() + 220
                end
                Wait(0)
            end
            activeReloadAnim = nil
            return true
        end
    end
    return false
end

local function tryNativeReloadAnimation(ped, weaponHash, clipNow, totalBefore, bulletsToLoad, durationMs)
    primeReloadReserve(ped, weaponHash, clipNow, totalBefore, bulletsToLoad)
    SetCurrentPedWeapon(ped, weaponHash, true)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    MakePedReload(ped)
    if not IsPedReloading(ped) then
        TaskReloadWeapon(ped, true)
    end

    local startDeadline = GetGameTimer() + 700
    while GetGameTimer() < startDeadline do
        if not DoesEntityExist(ped) then return false end
        enableReloadMovementControls()
        if IsPedReloading(ped) then
            local endDeadline = GetGameTimer() + durationMs
            while GetGameTimer() < endDeadline do
                if not DoesEntityExist(ped) then break end
                enableReloadMovementControls()
                if not IsPedReloading(ped) then
                    return true
                end
                Wait(0)
            end
            return true
        end
        if not IsPedReloading(ped) then
            TaskReloadWeapon(ped, true)
        end
        Wait(0)
    end
    return false
end

--- Animacija be kulkų keitimo — kulkos kraunamos tik po šios funkcijos.
function WeaponReload.playVisual(ped, weaponHash, bulletsToLoad, weaponData)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(400)
        return
    end

    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    local durationMs = getReloadWaitMs()
    captureMovementState(ped)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)

    local clipNow, totalBefore = snapshotClipState(ped, weaponHash)
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    pinClipDuringVisual(ped, weaponHash, clipNow)

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1400, durationMs))
        stopReloadAnimation(ped)
        restoreClipState(ped, weaponHash, clipNow, totalBefore)
        return
    end

    local usedNative = false
    local canUseNative = Config.ReloadUseNativeFirst ~= false
        and not isSwappedWeaponModel(invName)
        and not isReloadMoving()
    if canUseNative then
        usedNative = tryNativeReloadAnimation(ped, weaponHash, clipNow, totalBefore, bulletsToLoad, durationMs)
    end

    if not usedNative then
        local played = playMobileReloadAnimation(ped, weaponHash, durationMs, weaponData, clipNow)
        if not played then
            local waitMs = math.min(1200, durationMs)
            local deadline = GetGameTimer() + waitMs
            while GetGameTimer() < deadline do
                suppressNativeReloadDuringVisual(ped, weaponHash, clipNow)
                enableReloadMovementControls()
                Wait(0)
            end
        end
    end

    stopReloadAnimation(ped)
    restoreClipState(ped, weaponHash, clipNow, totalBefore)
    WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    restoreMovementAfterReload(ped)
end

function WeaponReload.cancel(ped)
    stopReloadAnimation(ped or PlayerPedId(), false)
end

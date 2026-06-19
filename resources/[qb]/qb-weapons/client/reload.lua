--- Stiprus užtaisymo modulis: viršutinės kūno animacija + priverstinis judėjimas (bėgimas leidžiamas).
WeaponReload = WeaponReload or {}

local activeReloadAnim = nil
local reloadMovementState = { sprint = false, moving = false }
local reloadSessionToken = 0
local reloadSessionActive = false

local MOTION_WALK = `MotionState_Walk`
local MOTION_RUN = `MotionState_Run`
local MOTION_SPRINT = `MotionState_Sprint`

local MOBILE_ANIM_FLAG = 49   -- LOOP + UPPERBODY + SECONDARY
local STATIC_ANIM_FLAG = 49

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function allowReloadMovement()
    return Config.ReloadAllowMovement ~= false
end

local function isMovementControlPressed()
    for _, ctrl in ipairs({ 21, 30, 31, 32, 33, 34, 35 }) do
        if IsControlPressed(0, ctrl) or IsDisabledControlPressed(0, ctrl) then
            return true
        end
    end
    return false
end

local function isPedActuallyMoving(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedRunning(ped) or IsPedSprinting(ped) then return true end
    return GetEntitySpeed(ped) > 1.05
end

local function captureMovementState(ped)
    reloadMovementState.sprint = IsPedSprinting(ped)
        or IsControlPressed(0, 21)
        or IsDisabledControlPressed(0, 21)
    reloadMovementState.moving = isPedActuallyMoving(ped)
end

local function reloadAnimFlags()
    if allowReloadMovement() then
        return MOBILE_ANIM_FLAG
    end
    return STATIC_ANIM_FLAG
end

local function enableReloadMovementControls()
    if not allowReloadMovement() then return end
    EnableControlAction(0, 21, true)
    EnableControlAction(0, 22, true)
    EnableControlAction(0, 30, true)
    EnableControlAction(0, 31, true)
    EnableControlAction(0, 32, true)
    EnableControlAction(0, 33, true)
    EnableControlAction(0, 34, true)
    EnableControlAction(0, 35, true)
end

local function loadAnimDict(dict)
    if not dict or dict == '' or HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
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
        ClearPedSecondaryTask(ped)
    end
end

local function canTryNativeReload(invName)
    if Config.ReloadUseNativeFirst == false then return false end
    if isSwappedWeaponModel(invName) then return false end
    if allowReloadMovement() then return false end
    return true
end

local function reloadAnimCandidates(weaponHash, weaponData)
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if invName == 'weapon_fgc9' then
        return {
            { 'weapons@rifle@lo@carbine_str', 'reload' },
            { 'weapons@submg@', 'reload' },
        }
    end

    local group = GetWeapontypeGroup(weaponHash)
    if group == `GROUP_SMG` or group == `GROUP_MG` then
        return {
            { 'weapons@submg@', 'reload' },
            { 'weapons@rifle@lo@carbine_str', 'reload' },
        }
    end
    if group == `GROUP_RIFLE` or group == `GROUP_SNIPER` then
        return {
            { 'weapons@rifle@lo@carbine_str', 'reload' },
            { 'weapons@submg@', 'reload' },
        }
    end
    if group == `GROUP_SHOTGUN` then
        return {
            { 'weapons@shotgun@', 'reload' },
        }
    end
    return {
        { 'weapons@pistol@', 'reload' },
        { 'weapons@pistol@combat@', 'reload' },
    }
end

local function preparePedForMobileReload(ped, weaponHash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanPlayAmbientBaseAnims(ped, true)
    SetPedUsingActionMode(ped, false, -1, 0)
    SetCurrentPedWeapon(ped, weaponHash, true)
end

local function forceReloadLocomotion(ped)
    if not allowReloadMovement() or not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsPedInAnyVehicle(ped, false) then return end

    local wantsSprint = reloadMovementState.sprint
        or IsControlPressed(0, 21)
        or IsDisabledControlPressed(0, 21)
    local wantsMove = reloadMovementState.moving
        or isMovementControlPressed()
        or isPedActuallyMoving(ped)

    if not wantsMove and not wantsSprint then return end

    SetPedUsingActionMode(ped, false, -1, 0)
    SetPedMoveRateOverride(ped, 1.0)

    if wantsSprint then
        SetPlayerSprint(PlayerId(), true)
        SetPedMaxMoveBlendRatio(ped, 3.0)
        ForcePedMotionState(ped, MOTION_SPRINT, false, 0, false)
    elseif wantsMove then
        SetPedMaxMoveBlendRatio(ped, 2.0)
        ForcePedMotionState(ped, MOTION_RUN, false, 0, false)
    end
end

local function restoreMovementAfterReload(ped)
    if not allowReloadMovement() or not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if IsPedInAnyVehicle(ped, false) then return end

    ClearPedSecondaryTask(ped)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetPedMoveRateOverride(ped, 1.0)
    SetPedMaxMoveBlendRatio(ped, 1.0)
    forceReloadLocomotion(ped)
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

local function maintainReloadAnimation(ped, dict, anim, animFlags, durationMs)
    if not dict or not anim then return end
    if not IsEntityPlayingAnim(ped, dict, anim, 3) then
        TaskPlayAnim(ped, dict, anim, 8.0, -3.0, durationMs or -1, animFlags, 0.0, false, false, false)
    end
end

local function tickReloadSession(ped, weaponHash, clipNow, dict, anim, animFlags, durationMs)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    enableReloadMovementControls()
    suppressNativeReloadDuringVisual(ped, weaponHash, clipNow)
    pinClipDuringVisual(ped, weaponHash, clipNow)

    if allowReloadMovement() then
        preparePedForMobileReload(ped, weaponHash)
        forceReloadLocomotion(ped)
        maintainReloadAnimation(ped, dict, anim, animFlags, -1)
    elseif dict and anim then
        maintainReloadAnimation(ped, dict, anim, animFlags, durationMs)
    end

    return true
end

function WeaponReload.isActive()
    return reloadSessionActive
end

function WeaponReload.tickControls()
    if not reloadSessionActive or not activeReloadAnim then return end
    local ped = PlayerPedId()
    tickReloadSession(
        ped,
        activeReloadAnim.weaponHash,
        activeReloadAnim.clipNow,
        activeReloadAnim.dict,
        activeReloadAnim.anim,
        activeReloadAnim.flags,
        activeReloadAnim.durationMs
    )
end

local function playMobileReloadAnimation(ped, weaponHash, durationMs, weaponData, clipNow)
    local animFlags = reloadAnimFlags()
    preparePedForMobileReload(ped, weaponHash)
    pinClipDuringVisual(ped, weaponHash, clipNow)

    for _, pair in ipairs(reloadAnimCandidates(weaponHash, weaponData)) do
        local dict, anim = pair[1], pair[2]
        if loadAnimDict(dict) then
            activeReloadAnim = {
                dict = dict,
                anim = anim,
                weaponHash = weaponHash,
                clipNow = clipNow,
                flags = animFlags,
                durationMs = durationMs,
            }
            TaskPlayAnim(ped, dict, anim, 8.0, -3.0, -1, animFlags, 0.0, false, false, false)

            local deadline = GetGameTimer() + durationMs
            while GetGameTimer() < deadline do
                if not DoesEntityExist(ped) then break end
                if not tickReloadSession(ped, weaponHash, clipNow, dict, anim, animFlags, durationMs) then
                    break
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

    reloadSessionToken = reloadSessionToken + 1
    local myToken = reloadSessionToken
    reloadSessionActive = true

    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    local durationMs = getReloadWaitMs()
    captureMovementState(ped)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)

    local clipNow, totalBefore = snapshotClipState(ped, weaponHash)
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1400, durationMs))
        stopReloadAnimation(ped)
        restoreClipState(ped, weaponHash, clipNow, totalBefore)
        reloadSessionActive = false
        return
    end

    local usedNative = false
    if canTryNativeReload(invName) then
        usedNative = tryNativeReloadAnimation(ped, weaponHash, clipNow, totalBefore, bulletsToLoad, durationMs)
    end

    if not usedNative then
        local played = playMobileReloadAnimation(ped, weaponHash, durationMs, weaponData, clipNow)
        if not played then
            local waitMs = math.min(1200, durationMs)
            local deadline = GetGameTimer() + waitMs
            while GetGameTimer() < deadline and myToken == reloadSessionToken do
                suppressNativeReloadDuringVisual(ped, weaponHash, clipNow)
                enableReloadMovementControls()
                forceReloadLocomotion(ped)
                Wait(0)
            end
        end
    end

    stopReloadAnimation(ped)
    restoreClipState(ped, weaponHash, clipNow, totalBefore)
    WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    restoreMovementAfterReload(ped)
    reloadSessionActive = false
end

function WeaponReload.cancel(ped)
    reloadSessionToken = reloadSessionToken + 1
    reloadSessionActive = false
    stopReloadAnimation(ped or PlayerPedId(), false)
end

CreateThread(function()
    while true do
        if reloadSessionActive then
            WeaponReload.tickControls()
            Wait(0)
        else
            Wait(200)
        end
    end
end)

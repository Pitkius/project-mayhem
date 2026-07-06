--- Perkrovos animacija. Kulkos kraunamos PO animacijos — main.lua.
WeaponReload = WeaponReload or {}

local QBCore = exports['qb-core']:GetCoreObject()

local activeReloadAnim = nil
local reloadPedStateActive = false

local function animRow(dict, clips, fallbacks)
    return {
        dict = dict,
        clips = clips or { 'w_reload_aim', 'reload_aim' },
        fallbacks = fallbacks or {},
    }
end

local CLIPS = {
    rifle = { 'w_reload_aim', 'reload_aim', 'reload_aim_xl', 'reload_low_left_xl' },
    pistol = { 'w_reload_aim', 'reload_aim', 'reload_aim_l' },
    smg = { 'w_reload_aim', 'reload_aim', 'reload_aim_xl' },
    shotgun = { 'w_reload_aim', 'reload_aim', 'reload_aim_l' },
    sniper = { 'w_reload_aim', 'reload_aim' },
}

local RELOAD_BY_INVENTORY = {
    weapon_fgc9 = animRow('weapons@pistol@combat_pistol_str', CLIPS.pistol, { 'weapons@pistol@pistol_str' }),
    weapon_combatpistol = animRow('weapons@pistol@combat_pistol_str', CLIPS.pistol, { 'weapons@pistol@pistol_str' }),
    weapon_pistol = animRow('weapons@pistol@pistol_str', CLIPS.pistol),
    weapon_pistol_mk2 = animRow('weapons@pistol@pistol_str', CLIPS.pistol),
    weapon_appistol = animRow('weapons@pistol@ap_pistol_str', CLIPS.pistol, { 'weapons@pistol@pistol_str' }),
    weapon_pistol50 = animRow('weapons@pistol@pistol_50_str', CLIPS.pistol, { 'weapons@pistol@pistol_str' }),
    weapon_microsmg = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_smg = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_smg_mk2 = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_assaultsmg = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_combatpdw = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_minismg = animRow('anim@weapons@pistol@minismg_str', CLIPS.smg, { 'weapons@rifle@lo@smg_str' }),
    weapon_machinepistol = animRow('anim@weapons@pistol@machine_str', CLIPS.smg, { 'weapons@rifle@lo@smg_str' }),
    weapon_carbinerifle = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    weapon_carbinerifle_mk2 = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    weapon_assaultrifle = animRow('weapons@rifle@hi@assault_rifle_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_assaultrifle_mk2 = animRow('weapons@rifle@hi@assault_rifle_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_advancedrifle = animRow('weapons@rifle@hi@assault_rifle_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_specialcarbine = animRow('anim@weapons@rifle@lo@spcarbine_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_specialcarbine_mk2 = animRow('anim@weapons@rifle@lo@spcarbine_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_bullpuprifle = animRow('weapons@rifle@hi@assault_rifle_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_compactrifle = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    weapon_militaryrifle = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    weapon_heavyrifle = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    weapon_tacticalrifle = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    weapon_pumpshotgun = animRow('weapons@rifle@lo@pump_str', CLIPS.shotgun),
    weapon_pumpshotgun_mk2 = animRow('weapons@rifle@lo@pump_str', CLIPS.shotgun),
    weapon_sawnoffshotgun = animRow('weapons@rifle@lo@sawnoff_str', CLIPS.shotgun),
    weapon_assaultshotgun = animRow('weapons@rifle@lo@shotgun_assault_str', CLIPS.shotgun),
    weapon_bullpupshotgun = animRow('weapons@rifle@lo@shotgun_bullpup_str', CLIPS.shotgun, { 'weapons@rifle@lo@shotgun_assault_str' }),
    weapon_heavyshotgun = animRow('weapons@rifle@lo@shotgun_assault_str', CLIPS.shotgun),
    weapon_sniperrifle = animRow('weapons@rifle@hi@sniper_rifle_str', CLIPS.sniper, { 'weapons@rifle@lo@sniper_heavy_str' }),
    weapon_heavysniper = animRow('weapons@rifle@lo@sniper_heavy_str', CLIPS.sniper),
    weapon_marksmanrifle = animRow('weapons@rifle@hi@sniper_rifle_str', CLIPS.sniper),
    weapon_mg = animRow('weapons@rifle@lo@smg_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_combatmg = animRow('weapons@rifle@lo@smg_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    weapon_gusenberg = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
}

local RELOAD_BY_GROUP = {
    [`GROUP_PISTOL`] = animRow('weapons@pistol@pistol_str', CLIPS.pistol),
    [`GROUP_SMG`] = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    [`GROUP_RIFLE`] = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    [`GROUP_MG`] = animRow('weapons@rifle@lo@smg_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    [`GROUP_SHOTGUN`] = animRow('weapons@rifle@lo@pump_str', CLIPS.shotgun),
    [`GROUP_SNIPER`] = animRow('weapons@rifle@hi@sniper_rifle_str', CLIPS.sniper),
}

local RELOAD_BY_AMMO = {
    AMMO_SHOTGUN = animRow('weapons@rifle@lo@pump_str', CLIPS.shotgun),
    AMMO_SMG = animRow('weapons@rifle@lo@smg_str', CLIPS.smg),
    AMMO_MG = animRow('weapons@rifle@lo@smg_str', CLIPS.rifle, { 'weapons@rifle@lo@carbine_str' }),
    AMMO_RIFLE = animRow('weapons@rifle@lo@carbine_str', CLIPS.rifle),
    AMMO_SNIPER = animRow('weapons@rifle@hi@sniper_rifle_str', CLIPS.sniper),
    AMMO_PISTOL = animRow('weapons@pistol@pistol_str', CLIPS.pistol),
}

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function allowReloadMovement()
    return Config.ReloadAllowMovement ~= false
end

--- 48 = viršutinė kūno dalis + leisti judėti (be loop). 16 = stovint be judėjimo.
local function reloadAnimFlags()
    if allowReloadMovement() then
        return 48
    end
    return 16
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end
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

local function weaponAmmoType(weaponHash, weaponData)
    if weaponData and weaponData.ammotype then
        return tostring(weaponData.ammotype):upper()
    end
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if invName and QBCore.Shared.Items[invName] and QBCore.Shared.Items[invName].ammotype then
        return tostring(QBCore.Shared.Items[invName].ammotype):upper()
    end
    local shared = QBCore.Shared.Weapons[weaponHash]
    if shared and shared.ammotype then
        return tostring(shared.ammotype):upper()
    end
    return ''
end

local function getReloadAnim(weaponHash, weaponData)
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if invName and RELOAD_BY_INVENTORY[invName] then
        return RELOAD_BY_INVENTORY[invName]
    end

    local group = GetWeapontypeGroup(weaponHash)
    local byGroup = RELOAD_BY_GROUP[group]
    if byGroup then
        return byGroup
    end

    local ammoType = weaponAmmoType(weaponHash, weaponData)
    local byAmmo = RELOAD_BY_AMMO[ammoType]
    if byAmmo then
        return byAmmo
    end

    return animRow('weapons@pistol@pistol_str', CLIPS.pistol)
end

local function orderByPriority(clips, priority)
    local ordered = {}
    local used = {}

    for _, pref in ipairs(priority) do
        for _, clip in ipairs(clips) do
            if clip == pref and not used[clip] then
                ordered[#ordered + 1] = clip
                used[clip] = true
            end
        end
    end

    for _, clip in ipairs(clips) do
        if not used[clip] then
            ordered[#ordered + 1] = clip
        end
    end

    return ordered
end

local function dictsToTry(animRowData)
    local list = { animRowData.dict }
    for _, fb in ipairs(animRowData.fallbacks or {}) do
        list[#list + 1] = fb
    end
    return list
end

local function pedIsMoving(ped)
    if not ped or ped == 0 then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    if GetEntitySpeed(ped) > 0.85 then return true end
    for _, ctrl in ipairs({ 21, 32, 33, 34, 35 }) do
        if IsControlPressed(0, ctrl) or IsDisabledControlPressed(0, ctrl) then
            return true
        end
    end
    return false
end

local function preparePedForReloadAnim(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetCurrentPedWeapon(ped, weaponHash, true)
end

local function pinClipOnce(ped, weaponHash, clipNow)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    clipNow = math.max(0, tonumber(clipNow) or 0)
    SetPedAmmo(ped, weaponHash, clipNow)
    SetAmmoInClip(ped, weaponHash, clipNow)
end

local function beginReloadPedState(ped, weaponHash, clipNow, pinClip)
    if not ped or ped == 0 then return end
    reloadPedStateActive = true
    SetPedCanSwitchWeapon(ped, false)
    preparePedForReloadAnim(ped, weaponHash)
    if pinClip then
        pinClipOnce(ped, weaponHash, clipNow)
    end
end

local function restoreClipState(ped, weaponHash, clipNow)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    clipNow = math.max(0, tonumber(clipNow) or 0)
    SetPedAmmo(ped, weaponHash, clipNow)
    SetAmmoInClip(ped, weaponHash, clipNow)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

local function stagePedAmmoForNativeReload(ped, weaponHash, clipNow, bulletsToLoad, weaponData)
    clipNow = math.max(0, tonumber(clipNow) or 0)
    local load = math.max(1, tonumber(bulletsToLoad) or 1)
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local targetTotal = math.min(maxClip, clipNow + load)
    if targetTotal <= clipNow then
        targetTotal = math.min(maxClip, clipNow + 1)
    end
    SetPedAmmo(ped, weaponHash, targetTotal)
    SetAmmoInClip(ped, weaponHash, clipNow)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

local function playReloadSound(ped, weaponHash, weaponData)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    local soundId = GetSoundId()
    if not soundId or soundId == -1 then return end

    local audioRef = 'WEP_PISTOL'
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if invName and invName ~= '' then
        audioRef = invName:upper()
    else
        local shared = QBCore.Shared.Weapons[weaponHash]
        if shared and shared.name then
            audioRef = tostring(shared.name):upper()
        end
    end

    PlaySoundFromEntity(soundId, 'Reload', ped, audioRef, false, 0)
    CreateThread(function()
        Wait(1400)
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end)
end

local function endReloadPedState(ped)
    if not reloadPedStateActive then return end
    reloadPedStateActive = false
    ped = ped or PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetPedCanSwitchWeapon(ped, true)
    end
end

local function orderClipsForPed(ped, clips)
    if not ped or ped == 0 then return clips end
    local aiming = IsPlayerFreeAiming(PlayerId())
        or IsControlPressed(0, 25)
        or IsDisabledControlPressed(0, 25)
    local moving = pedIsMoving(ped)

    if aiming or moving then
        return orderByPriority(clips, {
            'reload_aim',
            'w_reload_aim',
            'reload_aim_xl',
            'w_reload_aim_xl',
            'reload_aim_l',
            'reload_low_left_xl',
        })
    end

    return orderByPriority(clips, {
        'w_reload_aim',
        'reload_aim',
        'reload_aim_l',
        'reload_aim_xl',
        'w_reload_aim_xl',
        'reload_low_left_xl',
    })
end

local function playClipFromList(ped, dict, clips, flags)
    clips = orderClipsForPed(ped, clips)
    local mobile = allowReloadMovement()

    for _, clip in ipairs(clips) do
        if mobile then
            TaskPlayAnim(ped, dict, clip, 8.0, -4.0, -1, flags, 0.0, false, false, false)
        else
            local pos = GetEntityCoords(ped, true)
            local rot = GetEntityHeading(ped)
            TaskPlayAnimAdvanced(
                ped, dict, clip,
                pos.x, pos.y, pos.z,
                0.0, 0.0, rot,
                8.0, 3.0, -1,
                flags, 0.0, false, false
            )
        end

        local deadline = GetGameTimer() + 900
        while GetGameTimer() < deadline do
            if IsEntityPlayingAnim(ped, dict, clip, 3) then
                return clip, true
            end
            Wait(0)
        end
    end

    return clips[1], false
end

local function tryPlayReloadAnim(ped, animRowData, flags)
    for _, dict in ipairs(dictsToTry(animRowData)) do
        if loadAnimDict(dict) then
            local clip, started = playClipFromList(ped, dict, animRowData.clips, flags)
            if started then
                return dict, clip, true
            end
        end
    end
    return animRowData.dict, animRowData.clips[1], false
end

local function stopReloadAnimation(ped)
    ped = ped or PlayerPedId()
    if activeReloadAnim and activeReloadAnim.dict and activeReloadAnim.clip then
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            StopAnimTask(ped, activeReloadAnim.dict, activeReloadAnim.clip, 1.0)
        end
        if HasAnimDictLoaded(activeReloadAnim.dict) then
            RemoveAnimDict(activeReloadAnim.dict)
        end
    end
    activeReloadAnim = nil
end

local function enableReloadMovementControls(ped)
    if not allowReloadMovement() then return end
    for _, ctrl in ipairs({ 21, 30, 31, 32, 33, 34, 35 }) do
        EnableControlAction(0, ctrl, true)
    end
    SetPedCanPlayAmbientAnims(ped, true)
end

local function playUpperBodyReload(ped, weaponHash, weaponData, durationMs, clipNow)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 then return false end

    playReloadSound(ped, weaponHash, weaponData)

    local animRowData = getReloadAnim(weaponHash, weaponData)
    local flags = reloadAnimFlags()
    local dict, clip, started = tryPlayReloadAnim(ped, animRowData, flags)

    if not started then
        Wait(math.min(900, durationMs))
        return false
    end

    activeReloadAnim = { dict = dict, clip = clip }
    local retriesLeft = 1
    local deadline = GetGameTimer() + durationMs

    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        ped = PlayerPedId()
        enableReloadMovementControls(ped)

        if not IsEntityPlayingAnim(ped, dict, clip, 3) and retriesLeft > 0 then
            retriesLeft = retriesLeft - 1
            SetCurrentPedWeapon(ped, weaponHash, true)
            local retryClip, retryStarted = playClipFromList(ped, dict, animRowData.clips, flags)
            if retryStarted then
                clip = retryClip
                activeReloadAnim.clip = clip
            end
        end
        Wait(0)
    end

    stopReloadAnimation(ped)
    return true
end

local function playNativeReload(ped, weaponHash, durationMs, clipNow, bulletsToLoad, weaponData)
    ped = ped or PlayerPedId()
    preparePedForReloadAnim(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)

    stagePedAmmoForNativeReload(ped, weaponHash, clipNow, bulletsToLoad, weaponData)

    MakePedReload(ped)
    if not IsPedReloading(ped) then
        TaskReloadWeapon(ped, false)
    end

    local deadline = GetGameTimer() + durationMs
    local startedAt = GetGameTimer()
    local sawReload = false

    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        ped = PlayerPedId()
        SetCurrentPedWeapon(ped, weaponHash, true)
        if IsPedReloading(ped) then
            sawReload = true
            Wait(0)
        elseif sawReload or GetGameTimer() - startedAt > 1200 then
            break
        else
            TaskReloadWeapon(ped, false)
            Wait(0)
        end
    end

    restoreClipState(ped, weaponHash, clipNow)
    return sawReload or (GetGameTimer() - startedAt) > 350
end

--- Vizualinė animacija prieš inventoriaus užtaisymą.
function WeaponReload.playVisual(ped, weaponHash, bulletsToLoad, weaponData)
    ped = PlayerPedId()
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(250)
        return
    end

    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    local durationMs = getReloadWaitMs()
    local startedAt = GetGameTimer()
    local clipNow = select(1, WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData))

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1100, durationMs))
        return
    end

    local moving = allowReloadMovement() and pedIsMoving(ped)
    local usedNative = false

    beginReloadPedState(ped, weaponHash, clipNow, false)

    if not moving and Config.ReloadUseNativeFirst ~= false and bulletsToLoad > 0 then
        usedNative = playNativeReload(ped, weaponHash, durationMs, clipNow, bulletsToLoad, weaponData)
    end

    if not usedNative then
        pinClipOnce(ped, weaponHash, clipNow)
        playUpperBodyReload(ped, weaponHash, weaponData, durationMs, clipNow)
    end

    endReloadPedState(ped)

    local elapsed = GetGameTimer() - startedAt
    if elapsed < durationMs then
        Wait(durationMs - elapsed)
    end
end

function WeaponReload.cancel(ped)
    stopReloadAnimation(ped or PlayerPedId())
    endReloadPedState(ped or PlayerPedId())
end

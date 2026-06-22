--- Perkrovos animacija. Kulkos kraunamos PO animacijos — main.lua.
WeaponReload = WeaponReload or {}

local QBCore = exports['qb-core']:GetCoreObject()

local activeReloadAnim = nil

local RELOAD_BY_GROUP = {
    [`GROUP_PISTOL`] = { dict = 'weapons@pistol@', clips = { 'reload_aim', 'reload' } },
    [`GROUP_SMG`] = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    [`GROUP_RIFLE`] = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    [`GROUP_MG`] = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    [`GROUP_SHOTGUN`] = { dict = 'weapons@shotgun@', clips = { 'reload_aim', 'reload' } },
    [`GROUP_SNIPER`] = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
}

local RELOAD_BY_AMMO = {
    AMMO_SHOTGUN = { dict = 'weapons@shotgun@', clips = { 'reload_aim', 'reload' } },
    AMMO_SMG = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    AMMO_MG = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    AMMO_RIFLE = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    AMMO_SNIPER = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    AMMO_PISTOL = { dict = 'weapons@pistol@', clips = { 'reload_aim', 'reload' } },
}

local RELOAD_BY_INVENTORY = {
    weapon_fgc9 = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    weapon_machinepistol = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    weapon_minismg = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    weapon_microsmg = { dict = 'weapons@smg@', clips = { 'reload_aim', 'reload' } },
    weapon_combatpistol = { dict = 'weapons@pistol@', clips = { 'reload_aim', 'reload' } },
    weapon_pistol = { dict = 'weapons@pistol@', clips = { 'reload_aim', 'reload' } },
    weapon_carbinerifle = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    weapon_assaultrifle = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    weapon_pumpshotgun = { dict = 'weapons@shotgun@', clips = { 'reload_aim', 'reload' } },
}

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function allowReloadMovement()
    return Config.ReloadAllowMovement ~= false
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
        local row = RELOAD_BY_INVENTORY[invName]
        return row.dict, row.clips
    end

    local group = GetWeapontypeGroup(weaponHash)
    local byGroup = RELOAD_BY_GROUP[group]
    if byGroup then
        return byGroup.dict, byGroup.clips
    end

    local ammoType = weaponAmmoType(weaponHash, weaponData)
    local byAmmo = RELOAD_BY_AMMO[ammoType]
    if byAmmo then
        return byAmmo.dict, byAmmo.clips
    end

    return 'weapons@pistol@', { 'reload_aim', 'reload' }
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

local function pinClipDuringVisual(ped, weaponHash, clipNow)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    clipNow = math.max(0, tonumber(clipNow) or 0)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedAmmo(ped, weaponHash, clipNow)
    SetAmmoInClip(ped, weaponHash, clipNow)
end

local function playClipFromList(ped, dict, clips, durationMs, flags)
    for _, clip in ipairs(clips) do
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durationMs, flags, 0.0, false, false, false)
        Wait(120)
        if IsEntityPlayingAnim(ped, dict, clip, 3) then
            return clip
        end
    end
    return clips[1]
end

local function stopReloadAnimation(ped)
    ped = ped or PlayerPedId()
    if activeReloadAnim and activeReloadAnim.dict and activeReloadAnim.clip then
        StopAnimTask(ped, activeReloadAnim.dict, activeReloadAnim.clip, 1.0)
        if HasAnimDictLoaded(activeReloadAnim.dict) then
            RemoveAnimDict(activeReloadAnim.dict)
        end
    end
    activeReloadAnim = nil
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedSecondaryTask(ped)
    end
end

local function playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
    local dict, clips = getReloadAnim(weaponHash, weaponData)
    if not loadAnimDict(dict) then
        Wait(math.min(900, durationMs))
        return false
    end

    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)

    local flags = allowReloadMovement() and 49 or 0
    local clip = playClipFromList(ped, dict, clips, durationMs, flags)
    activeReloadAnim = { dict = dict, clip = clip }

    local deadline = GetGameTimer() + durationMs
    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        if allowReloadMovement() then
            for _, ctrl in ipairs({ 21, 30, 31, 32, 33, 34, 35 }) do
                EnableControlAction(0, ctrl, true)
            end
        end
        if not IsEntityPlayingAnim(ped, dict, clip, 3) and (GetGameTimer() + 450) < deadline then
            clip = playClipFromList(ped, dict, clips, durationMs, flags)
            activeReloadAnim.clip = clip
        end
        Wait(0)
    end

    stopReloadAnimation(ped)
    return true
end

local function playNativeReload(ped, weaponHash, durationMs, clipNow)
    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    clipNow = math.max(0, tonumber(clipNow) or 0)
    -- GTA native reload reikalauja rezervo — kitaip animacija neprasideda.
    SetPedAmmo(ped, weaponHash, math.max(clipNow, 1) + 30)
    SetAmmoInClip(ped, weaponHash, clipNow)

    MakePedReload(ped)
    if not IsPedReloading(ped) then
        TaskReloadWeapon(ped, true)
    end

    local deadline = GetGameTimer() + durationMs
    local startedAt = GetGameTimer()
    local sawReload = false

    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        if IsPedReloading(ped) then
            sawReload = true
            Wait(0)
        elseif sawReload or GetGameTimer() - startedAt > 650 then
            break
        else
            TaskReloadWeapon(ped, true)
            Wait(0)
        end
    end

    pinClipDuringVisual(ped, weaponHash, clipNow)
    return sawReload
end

--- Vizualinė animacija prieš inventoriaus užtaisymą.
function WeaponReload.playVisual(ped, weaponHash, _bulletsToLoad, weaponData)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(250)
        return
    end

    local durationMs = getReloadWaitMs()
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1100, durationMs))
        return
    end

    local clipNow = select(1, WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData))
    pinClipDuringVisual(ped, weaponHash, clipNow)

    local moving = pedIsMoving(ped)
    local usedNative = false

    if not moving and Config.ReloadUseNativeFirst ~= false then
        usedNative = playNativeReload(ped, weaponHash, durationMs, clipNow)
    end

    if not usedNative or moving then
        playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
    else
        local remain = durationMs - 400
        if remain > 0 then
            Wait(remain)
        end
    end

    pinClipDuringVisual(ped, weaponHash, clipNow)
end

function WeaponReload.cancel(ped)
    stopReloadAnimation(ped or PlayerPedId())
end

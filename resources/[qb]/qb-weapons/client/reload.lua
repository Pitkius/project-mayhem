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
    weapon_pistol_mk2 = { dict = 'weapons@pistol@', clips = { 'reload_aim', 'reload' } },
    weapon_carbinerifle = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    weapon_assaultrifle = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    weapon_specialcarbine = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
    weapon_specialcarbine_mk2 = { dict = 'weapons@rifle@lo@', clips = { 'reload_aim', 'reload' } },
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

--- 48 = viršutinė kūno dalis + leisti judėti (kaip weapdraw.lua).
local function reloadAnimFlags()
    if allowReloadMovement() then
        return 48
    end
    return 2
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

local function preparePedForReloadAnim(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return end
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetCurrentPedWeapon(ped, weaponHash, true)
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

local function orderClipsForPed(ped, clips)
    if not ped or ped == 0 then return clips end
    local aiming = IsPlayerFreeAiming(PlayerId())
        or IsControlPressed(0, 25)
        or IsDisabledControlPressed(0, 25)
        or pedIsMoving(ped)
    if not aiming then
        return clips
    end
    local ordered = {}
    for _, clip in ipairs(clips) do
        if clip == 'reload_aim' then
            ordered[#ordered + 1] = clip
        end
    end
    for _, clip in ipairs(clips) do
        if clip ~= 'reload_aim' then
            ordered[#ordered + 1] = clip
        end
    end
    return ordered
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

        local started = GetGameTimer() + 1200
        while GetGameTimer() < started do
            if IsEntityPlayingAnim(ped, dict, clip, 3) then
                return clip
            end
            Wait(0)
        end
    end

    return clips[1]
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

    local dict, clips = getReloadAnim(weaponHash, weaponData)
    if not loadAnimDict(dict) then
        Wait(math.min(900, durationMs))
        return false
    end

    preparePedForReloadAnim(ped, weaponHash)
    pinClipDuringVisual(ped, weaponHash, clipNow)

    local flags = reloadAnimFlags()
    local clip = playClipFromList(ped, dict, clips, flags)
    activeReloadAnim = { dict = dict, clip = clip }

    local startedAt = GetGameTimer()
    local deadline = startedAt + durationMs
    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        ped = PlayerPedId()
        enableReloadMovementControls(ped)
        pinClipDuringVisual(ped, weaponHash, clipNow)

        if not IsEntityPlayingAnim(ped, dict, clip, 3) and (GetGameTimer() + 700) < deadline then
            preparePedForReloadAnim(ped, weaponHash)
            clip = playClipFromList(ped, dict, clips, flags)
            activeReloadAnim.clip = clip
        end
        Wait(0)
    end

    stopReloadAnimation(ped)
    return true
end

local function playNativeReload(ped, weaponHash, durationMs, clipNow)
    ped = ped or PlayerPedId()
    preparePedForReloadAnim(ped, weaponHash)
    pinClipDuringVisual(ped, weaponHash, clipNow)

    MakePedReload(ped)
    if not IsPedReloading(ped) then
        TaskReloadWeapon(ped, true)
    end

    local deadline = GetGameTimer() + durationMs
    local startedAt = GetGameTimer()
    local sawReload = false

    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        ped = PlayerPedId()
        pinClipDuringVisual(ped, weaponHash, clipNow)
        if IsPedReloading(ped) then
            sawReload = true
            Wait(0)
        elseif sawReload or GetGameTimer() - startedAt > 900 then
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
    ped = PlayerPedId()
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(250)
        return
    end

    local durationMs = getReloadWaitMs()
    local startedAt = GetGameTimer()
    preparePedForReloadAnim(ped, weaponHash)

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1100, durationMs))
        return
    end

    local clipNow = select(1, WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData))
    local moving = allowReloadMovement() and pedIsMoving(ped)
    local usedNative = false

    -- Judant arba su įjungtu movement — tik custom animacija (native užpildo apkabą be animacijos).
    if Config.ReloadUseNativeFirst ~= false and not moving and not allowReloadMovement() then
        usedNative = playNativeReload(ped, weaponHash, durationMs, clipNow)
    end

    if not usedNative then
        playUpperBodyReload(ped, weaponHash, weaponData, durationMs, clipNow)
    end

    local elapsed = GetGameTimer() - startedAt
    if elapsed < durationMs then
        Wait(durationMs - elapsed)
    end
end

function WeaponReload.cancel(ped)
    stopReloadAnimation(ped or PlayerPedId())
end

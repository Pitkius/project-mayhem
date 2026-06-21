--- Perkrovos animacija. Kulkos kraunamos PO animacijos — main.lua.
WeaponReload = WeaponReload or {}

local QBCore = exports['qb-core']:GetCoreObject()

local RELOAD_BY_GROUP = {
    [`GROUP_PISTOL`] = { dict = 'weapons@pistol_1h@', clips = { 'reload_aim_l', 'reload_aim', 'reload' } },
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
    AMMO_PISTOL = { dict = 'weapons@pistol_1h@', clips = { 'reload_aim_l', 'reload_aim', 'reload' } },
}

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function weaponAmmoType(weaponHash, weaponData)
    if weaponData and weaponData.ammotype then
        return tostring(weaponData.ammotype):upper()
    end
    local shared = QBCore and QBCore.Shared and QBCore.Shared.Weapons and QBCore.Shared.Weapons[weaponHash]
    if shared and shared.ammotype then
        return tostring(shared.ammotype):upper()
    end
    return ''
end

local function getReloadAnim(weaponHash, weaponData)
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

    return 'weapons@pistol_1h@', { 'reload_aim_l', 'reload_aim', 'reload' }
end

local function pedIsMoving(ped)
    if not ped or ped == 0 then return false end
    return GetEntitySpeed(ped) > 0.85
end

local function playClipFromList(ped, dict, clips, durationMs, flags)
    for _, clip in ipairs(clips) do
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durationMs, flags, 0.0, false, false, false)
        Wait(80)
        if IsEntityPlayingAnim(ped, dict, clip, 3) then
            return clip
        end
    end
    return clips[1]
end

local function playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
    local dict, clips = getReloadAnim(weaponHash, weaponData)
    if not loadAnimDict(dict) then
        Wait(math.min(900, durationMs))
        return
    end

    SetCurrentPedWeapon(ped, weaponHash, true)
    local flags = 49
    local clip = playClipFromList(ped, dict, clips, durationMs, flags)

    local deadline = GetGameTimer() + durationMs
    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        if not IsEntityPlayingAnim(ped, dict, clip, 3) and (GetGameTimer() + 400) < deadline then
            clip = playClipFromList(ped, dict, clips, durationMs, flags)
        end
        Wait(0)
    end

    StopAnimTask(ped, dict, clip, 1.0)
    RemoveAnimDict(dict)
end

local function playNativeReload(ped, weaponHash, durationMs)
    SetCurrentPedWeapon(ped, weaponHash, true)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    local _, clipNow = GetAmmoInClip(ped, weaponHash)
    local savedClip = math.max(0, tonumber(clipNow) or 0)

    -- Jei apkaba jau pilna (fallback), trumpam ištuštinam kad GTA paleistų reload anim.
    if savedClip > 0 then
        SetPedAmmo(ped, weaponHash, 0)
        SetAmmoInClip(ped, weaponHash, 0)
    end

    MakePedReload(ped)
    if not IsPedReloading(ped) then
        TaskReloadWeapon(ped, true)
    end

    local deadline = GetGameTimer() + durationMs
    local startedAt = GetGameTimer()

    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        if IsPedReloading(ped) then
            Wait(0)
        elseif GetGameTimer() - startedAt > 500 then
            break
        else
            TaskReloadWeapon(ped, true)
            Wait(0)
        end
    end

    if savedClip > 0 then
        SetPedAmmo(ped, weaponHash, savedClip)
        SetAmmoInClip(ped, weaponHash, savedClip)
        WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    end
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

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1100, durationMs))
        return
    end

    if pedIsMoving(ped) then
        playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
        return
    end

    if Config.ReloadUseNativeFirst ~= false then
        playNativeReload(ped, weaponHash, durationMs)
        return
    end

    playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
end

function WeaponReload.cancel(ped)
    ped = ped or PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedSecondaryTask(ped)
    end
end

--- Perkrovos animacija (vizualinė). Kulkos kraunamos prieš animaciją — main.lua.
WeaponReload = WeaponReload or {}

local QBCore = exports['qb-core']:GetCoreObject()

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
    local shared = QBCore and QBCore.Shared and QBCore.Shared.Weapons and QBCore.Shared.Weapons[weaponHash]
    if shared and shared.ammotype then
        return tostring(shared.ammotype):upper()
    end
    return ''
end

local function getReloadAnim(weaponHash, weaponData)
    local ammoType = weaponAmmoType(weaponHash, weaponData)
    if ammoType == 'AMMO_SHOTGUN' then
        return 'weapons@shotgun@', 'reload_aim'
    end
    if ammoType == 'AMMO_SMG' or ammoType == 'AMMO_MG' then
        return 'weapons@smg@', 'reload_aim'
    end
    if ammoType == 'AMMO_RIFLE' or ammoType == 'AMMO_SNIPER' then
        return 'weapons@rifle@', 'reload_aim'
    end
    return 'weapons@pistol@', 'reload_aim'
end

local function pedIsMoving(ped)
    if not ped or ped == 0 then return false end
    return GetEntitySpeed(ped) > 0.85
end

local function playUpperBodyReload(ped, weaponHash, weaponData, durationMs)
    local dict, primaryClip = getReloadAnim(weaponHash, weaponData)
    if not loadAnimDict(dict) then
        Wait(math.min(900, durationMs))
        return
    end

    SetCurrentPedWeapon(ped, weaponHash, true)
    local flags = 49 -- upper body, allow movement
    local clip = primaryClip
    if not IsEntityPlayingAnim(ped, dict, clip, 3) then
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durationMs, flags, 0.0, false, false, false)
    end
    if not IsEntityPlayingAnim(ped, dict, clip, 3) and clip == 'reload_aim' then
        clip = 'reload'
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durationMs, flags, 0.0, false, false, false)
    end

    local deadline = GetGameTimer() + durationMs
    while DoesEntityExist(ped) and GetGameTimer() < deadline do
        if not IsEntityPlayingAnim(ped, dict, clip, 3) and (GetGameTimer() + 400) < deadline then
            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durationMs, flags, 0.0, false, false, false)
        end
        Wait(0)
    end

    StopAnimTask(ped, dict, clip, 1.0)
    RemoveAnimDict(dict)
end

local function playNativeReload(ped, weaponHash, durationMs)
    SetCurrentPedWeapon(ped, weaponHash, true)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

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
end

--- Vizualinė animacija po sėkmingo inventoriaus užtaisymo (be kulkų keitimo).
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

    local allowMove = Config.ReloadAllowMovement == true
    if allowMove or pedIsMoving(ped) then
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
        ClearPedTasks(ped)
    end
end

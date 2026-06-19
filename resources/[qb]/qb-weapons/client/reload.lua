--- Paprastas GTA native reload; inventoriaus kulkos kraunamos po animacijos.
WeaponReload = WeaponReload or {}

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

local function snapshotClipState(ped, weaponHash)
    local hasClip, clipNow = GetAmmoInClip(ped, weaponHash)
    clipNow = hasClip and (tonumber(clipNow) or 0) or 0
    local totalBefore = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    return clipNow, totalBefore
end

local function primeReloadReserve(ped, weaponHash, clipNow, totalBefore, bulletsToLoad)
    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    if bulletsToLoad <= 0 then return end
    local reserve = math.max(0, totalBefore - clipNow)
    if reserve >= bulletsToLoad then return end
    local boosted = totalBefore + (bulletsToLoad - reserve)
    SetPedAmmo(ped, weaponHash, boosted)
    SetAmmoInClip(ped, weaponHash, clipNow)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
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

local function isSwappedWeaponModel(weaponHash, weaponData)
    local invName = resolveInventoryWeaponName(weaponHash, weaponData)
    if not invName then return false end
    local map = Config.WeaponNativeHash
    return type(map) == 'table' and map[invName] ~= nil
end

local function playNativeReload(ped, weaponHash, bulletsToLoad, durationMs)
    local clipNow, totalBefore = snapshotClipState(ped, weaponHash)
    primeReloadReserve(ped, weaponHash, clipNow, totalBefore, bulletsToLoad)

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
        elseif GetGameTimer() - startedAt > 350 then
            break
        else
            TaskReloadWeapon(ped, true)
            Wait(0)
        end
    end
end

function WeaponReload.playVisual(ped, weaponHash, bulletsToLoad, weaponData)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(400)
        return
    end

    local durationMs = getReloadWaitMs()
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)

    if IsPedInAnyVehicle(ped, false) then
        Wait(math.min(1400, durationMs))
        return
    end

    if isSwappedWeaponModel(weaponHash, weaponData) then
        Wait(math.min(1800, durationMs))
        return
    end

    playNativeReload(ped, weaponHash, bulletsToLoad, durationMs)
end

function WeaponReload.cancel(ped)
    ped = ped or PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedTasks(ped)
    end
end

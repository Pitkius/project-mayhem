--- Apkaba, inventoriaus sinchronizacija — papildomos kulkos tik inventoriuje, ne ant ped.
WeaponAmmo = WeaponAmmo or {}

local function componentHash(comp)
    if type(comp) == 'number' then return comp end
    if comp then return joaat(tostring(comp)) end
end

local function weaponHasAttachment(ped, weaponHash, weaponData, attachmentTable)
    local weaponName = weaponData and weaponData.name
    if not weaponName or type(attachmentTable) ~= 'table' then return false end
    local nativeName = WeaponHash and WeaponHash.nativeName and WeaponHash.nativeName(weaponName)
    local comp = attachmentTable[weaponName] or (nativeName and attachmentTable[nativeName])
    if not comp then return false end
    local compHash = componentHash(comp)
    if ped and weaponHash and compHash and HasPedGotWeaponComponent(ped, weaponHash, compHash) then
        return true
    end
    local info = weaponData.info or weaponData
    if type(info) == 'table' and type(info.attachments) == 'table' then
        for _, attachment in pairs(info.attachments) do
            local attached = attachment and (attachment.component or attachment)
            if attached == comp or attached == compHash then return true end
            if type(attached) == 'string' and compHash and joaat(attached) == compHash then return true end
        end
    end
    return false
end

local function resolveAttachmentClipCapacity(weaponName, ped, weaponHash, weaponData)
    if not weaponName then return 0 end
    local cap = 0
    if weaponHasAttachment(ped, weaponHash, weaponData, WeaponAttachments.drum_attachment) then
        cap = math.max(cap, tonumber(Config.DrumClipCapacity and Config.DrumClipCapacity[weaponName]) or 0)
    end
    if weaponHasAttachment(ped, weaponHash, weaponData, WeaponAttachments.clip_attachment) then
        cap = math.max(cap, tonumber(Config.ExtendedClipCapacity and Config.ExtendedClipCapacity[weaponName]) or 0)
    end
    return cap
end

local function defaultClipForWeapon(weaponHash, weaponData)
    local weaponName = weaponData and weaponData.name
    local byWeapon = Config.StandardClipCapacity or {}
    if weaponName and byWeapon[weaponName] then
        return tonumber(byWeapon[weaponName]) or 0
    end
    local ammoType = tostring(weaponData and weaponData.ammotype or ''):upper()
    return tonumber(Config.DefaultClipCapacityByAmmoType and Config.DefaultClipCapacityByAmmoType[ammoType]) or 30
end

function WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return end
    SetPedInfiniteAmmoClip(ped, false)
    SetPedInfiniteAmmo(ped, false, weaponHash)
end

function WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local nativeMax = 0
    for _, p2 in ipairs({ true, false }) do
        local hasMaxClip, maxClipAmmo = GetMaxAmmoInClip(ped, weaponHash, p2)
        if hasMaxClip and maxClipAmmo then
            nativeMax = math.max(nativeMax, tonumber(maxClipAmmo) or 0)
        end
    end

    local weaponName = weaponData and weaponData.name
    local attachmentCap = resolveAttachmentClipCapacity(weaponName, ped, weaponHash, weaponData)
    if attachmentCap > 0 then
        return math.max(nativeMax, attachmentCap)
    end

    local standardClip = defaultClipForWeapon(weaponHash, weaponData)
    if nativeMax > 0 then
        return math.min(nativeMax, standardClip)
    end
    return standardClip
end

function WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData)
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local hasClip, currentClipAmmo = GetAmmoInClip(ped, weaponHash)
    local curInClip = hasClip and (tonumber(currentClipAmmo) or 0) or 0
    curInClip = math.min(math.max(0, curInClip), maxClip)
    local totalAmmo = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    local clipMissing = math.max(0, maxClip - curInClip)
    return curInClip, maxClip, clipMissing, totalAmmo
end

--- Ped laiko tik apkaboje — likusios kulkos inventoriuje (item).
function WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0, 0
    end

    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local _, clipNow = GetAmmoInClip(ped, weaponHash)
    local clip = math.min(maxClip, math.max(0, tonumber(clipNow) or 0))
    local total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)

    if total > maxClip then
        clip = math.min(clip, maxClip)
    elseif total > 0 and clip > total then
        clip = math.min(clip, total, maxClip)
    elseif clip <= 0 and total > 0 then
        clip = math.min(total, maxClip)
    end

    clip = math.min(clip, maxClip)
    SetPedAmmo(ped, weaponHash, clip)
    SetAmmoInClip(ped, weaponHash, clip)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    return clip, maxClip
end

function WeaponAmmo.applyWeaponAmmoState(ped, weaponHash, ammo, weaponData)
    ammo = math.max(0, tonumber(ammo) or 0)
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local clip = math.min(ammo, maxClip)
    SetPedAmmo(ped, weaponHash, clip)
    SetAmmoInClip(ped, weaponHash, clip)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    return clip
end

--- GTA reload užduočiai laikinai duoda tik tiek reserve, kiek patvirtino serveris.
--- Apkaba nekeičiama; SetPedAmmo kviečiamas prieš SetAmmoInClip, nes native gali
--- automatiškai perkelti dalį total ammo į apkabą.
function WeaponAmmo.stageNativeReserve(ped, weaponHash, weaponData, bullets)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0
    end

    local clip, maxClip, missing = WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData)
    local staged = math.min(
        math.max(0, math.floor(tonumber(bullets) or 0)),
        math.max(0, missing)
    )
    if staged <= 0 then return 0 end

    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetPedAmmo(ped, weaponHash, clip + staged)
    SetAmmoInClip(ped, weaponHash, clip)
    return staged
end

--- Užbaigus native animaciją pašalina laikiną GTA reserve ir palieka tik apkabą.
--- Grąžina realiai į apkabą patekusių kulkų delta bei galutinę apkabą.
function WeaponAmmo.finishNativeReload(ped, weaponHash, clipBefore, maxClip)
    clipBefore = math.max(0, math.floor(tonumber(clipBefore) or 0))
    maxClip = math.max(clipBefore, math.floor(tonumber(maxClip) or clipBefore))
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0, clipBefore
    end

    local hasClip, nativeClip = GetAmmoInClip(ped, weaponHash)
    local clip = hasClip and math.floor(tonumber(nativeClip) or clipBefore) or clipBefore
    clip = math.min(maxClip, math.max(0, clip))
    local loaded = math.max(0, clip - clipBefore)

    SetPedAmmo(ped, weaponHash, clip)
    SetAmmoInClip(ped, weaponHash, clip)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    return loaded, clip
end

function WeaponAmmo.getSyncedAmmoAmount(ped, weaponHash, weaponData)
    local clip = WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    return clip
end

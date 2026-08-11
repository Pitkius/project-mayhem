--- Apkaba, inventoriaus sinchronizacija — papildomos kulkos tik inventoriuje, ne ant ped.
WeaponAmmo = WeaponAmmo or {}

local function componentHash(comp)
    if type(comp) == 'number' then return comp end
    if type(comp) == 'string' then
        local asNum = tonumber(comp)
        if asNum then return asNum end
        return joaat(comp)
    end
end

local function componentsMatch(a, b)
    if a == nil or b == nil then return false end
    if a == b then return true end
    local na, nb = tonumber(a), tonumber(b)
    if na and nb and na == nb then return true end
    local ha, hb = componentHash(a), componentHash(b)
    return ha ~= nil and hb ~= nil and ha == hb
end

local function lookupAttachmentComponent(attachmentTable, weaponName)
    if type(attachmentTable) ~= 'table' or not weaponName then return nil end
    local nativeName = WeaponHash and WeaponHash.nativeName and WeaponHash.nativeName(weaponName)
    return attachmentTable[weaponName] or (nativeName and attachmentTable[nativeName]) or nil
end

local function weaponHasClipItem(ped, weaponHash, weaponData, itemKey, attachmentTable)
    local weaponName = weaponData and weaponData.name
    if not weaponName or type(attachmentTable) ~= 'table' then return false end
    local comp = lookupAttachmentComponent(attachmentTable, weaponName)
    if not comp then return false end
    local compHash = componentHash(comp)
    if ped and weaponHash and compHash and HasPedGotWeaponComponent(ped, weaponHash, compHash) then
        return true
    end
    local info = weaponData.info or weaponData
    if type(info) ~= 'table' or type(info.attachments) ~= 'table' then return false end
    for _, attachment in pairs(info.attachments) do
        local attached = attachment and (attachment.component or attachment)
        if componentsMatch(attached, comp) or componentsMatch(attached, compHash) then
            return true
        end
        if type(attachment) == 'table' and tostring(attachment.item or '') == tostring(itemKey) then
            return true
        end
    end
    return false
end

local function capacityFromTable(capacityTable, weaponName)
    if type(capacityTable) ~= 'table' or not weaponName then return 0 end
    local byName = tonumber(capacityTable[weaponName]) or 0
    local nativeName = WeaponHash and WeaponHash.nativeName and WeaponHash.nativeName(weaponName)
    local byNative = nativeName and tonumber(capacityTable[nativeName]) or 0
    return math.max(byName, byNative)
end

--- Ped komponentas ARBA ginklo metadata attachments (kad reload metu flicker'is nenuimtų talpos).
local function liveAttachmentCapacity(ped, weaponHash, weaponData, itemKeys, capacityTable)
    if type(itemKeys) ~= 'table' or type(capacityTable) ~= 'table' then return 0 end
    local weaponName = weaponData and weaponData.name
    if not weaponName then return 0 end

    local cap = 0
    for _, itemKey in ipairs(itemKeys) do
        local attachmentTable = WeaponAttachments and WeaponAttachments[itemKey]
        if weaponHasClipItem(ped, weaponHash, weaponData, itemKey, attachmentTable) then
            cap = math.max(cap, capacityFromTable(capacityTable, weaponName))
        end
    end
    return cap
end

local function resolveAttachmentClipCapacity(weaponName, ped, weaponHash, weaponData)
    if not weaponName then return 0 end
    local drumCap = liveAttachmentCapacity(
        ped,
        weaponHash,
        weaponData,
        Config.DrumClipAttachmentItems,
        Config.DrumClipCapacity
    )
    local extCap = liveAttachmentCapacity(
        ped,
        weaponHash,
        weaponData,
        Config.ExtendedClipAttachmentItems,
        Config.ExtendedClipCapacity
    )
    return math.max(drumCap, extCap)
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

function WeaponAmmo.getNativeMaxClip(ped, weaponHash)
    local nativeMax = 0
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 then return 0 end
    for _, p2 in ipairs({ true, false }) do
        local hasMaxClip, maxClipAmmo = GetMaxAmmoInClip(ped, weaponHash, p2)
        if hasMaxClip and maxClipAmmo then
            nativeMax = math.max(nativeMax, tonumber(maxClipAmmo) or 0)
        end
    end
    return nativeMax
end

--- Užtikrina, kad CLIP_02/03 iš metadata būtų ant ped prieš talpos/native reload.
function WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData)
    if not ped or ped == 0 or not weaponHash or not weaponData then return end
    local groups = {
        Config.DrumClipAttachmentItems,
        Config.ExtendedClipAttachmentItems,
    }
    local applied = false
    for i = 1, #groups do
        local itemKeys = groups[i]
        if type(itemKeys) == 'table' then
            for _, itemKey in ipairs(itemKeys) do
                local attachmentTable = WeaponAttachments and WeaponAttachments[itemKey]
                local weaponName = weaponData.name
                local comp = lookupAttachmentComponent(attachmentTable, weaponName)
                local compHash = componentHash(comp)
                if compHash then
                    local already = HasPedGotWeaponComponent(ped, weaponHash, compHash)
                    local shouldApply = false
                    if not already then
                        local info = weaponData.info or weaponData
                        if type(info) == 'table' and type(info.attachments) == 'table' then
                            for _, attachment in pairs(info.attachments) do
                                local attached = attachment and (attachment.component or attachment)
                                if componentsMatch(attached, comp) or componentsMatch(attached, compHash) then
                                    shouldApply = true
                                    break
                                end
                                if type(attachment) == 'table' and tostring(attachment.item or '') == tostring(itemKey) then
                                    shouldApply = true
                                    break
                                end
                            end
                        end
                    end
                    if shouldApply then
                        GiveWeaponComponentToPed(ped, weaponHash, compHash)
                        applied = true
                    end
                end
            end
        end
    end
    if applied then
        Wait(0)
    end
end

function WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return end
    SetPedInfiniteAmmoClip(ped, false)
    SetPedInfiniteAmmo(ped, false, weaponHash)
end

function WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    if ped and weaponHash and weaponData then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData)
    end

    local nativeMax = WeaponAmmo.getNativeMaxClip(ped, weaponHash)
    local standardClip = defaultClipForWeapon(weaponHash, weaponData)
    local attachmentCap = resolveAttachmentClipCapacity(
        weaponData and weaponData.name,
        ped,
        weaponHash,
        weaponData
    )

    -- CLIP_02/03: native arba config (jei native vis dar grąžina standartą).
    if attachmentCap > 0 then
        return math.max(nativeMax, attachmentCap, 1)
    end

    -- Be priedo — serverio standartinis limitas (nepripučiame).
    if nativeMax > 0 then
        return math.min(nativeMax, standardClip)
    end
    return math.max(1, standardClip)
end

local function readClipAmmoClamped(ped, weaponHash, maxClip)
    local hasClip, currentClipAmmo = GetAmmoInClip(ped, weaponHash)
    local curInClip = hasClip and (tonumber(currentClipAmmo) or 0) or 0
    local totalAmmo = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    maxClip = math.max(1, math.floor(tonumber(maxClip) or 1))

    -- GetAmmoInClip kartais grąžina visą reserve — limituojam pagal resolved maxClip
    -- (NE pagal stale nativeMax, nes tai „−100 / +30“ bug'as su extended/drum).
    if curInClip > maxClip and totalAmmo >= curInClip then
        curInClip = maxClip
    end

    curInClip = math.min(math.max(0, curInClip), maxClip)
    return curInClip, WeaponAmmo.getNativeMaxClip(ped, weaponHash), totalAmmo
end

function WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData)
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local curInClip, _, totalAmmo = readClipAmmoClamped(ped, weaponHash, maxClip)
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
    local clip = select(1, readClipAmmoClamped(ped, weaponHash, maxClip))
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

--- Užbaigus native animaciją: užpildo intended, inventoriui nuskaito tik verified.
--- Extended/drum: krauti pagal resolved maxClip (po CLIP_02/03), ne pagal stale native 30.
--- @return number loadedDelta, number finalClip
function WeaponAmmo.finishNativeReload(ped, weaponHash, clipBefore, maxClip, staged, weaponData)
    clipBefore = math.max(0, math.floor(tonumber(clipBefore) or 0))
    maxClip = math.max(clipBefore, math.floor(tonumber(maxClip) or clipBefore))
    staged = math.max(0, math.floor(tonumber(staged) or 0))

    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0, clipBefore
    end

    if weaponData then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData)
        maxClip = math.max(maxClip, WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData))
    end

    local intended = math.min(maxClip, clipBefore + staged)

    SetPedAmmo(ped, weaponHash, intended)
    SetAmmoInClip(ped, weaponHash, intended)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    local hasClip, rawAfter = GetAmmoInClip(ped, weaponHash)
    local after = hasClip and math.floor(tonumber(rawAfter) or 0) or 0
    local total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)

    if after > maxClip and total >= after then
        after = maxClip
    end

    if after < intended then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData)
        SetPedAmmo(ped, weaponHash, intended)
        SetAmmoInClip(ped, weaponHash, intended)
        hasClip, rawAfter = GetAmmoInClip(ped, weaponHash)
        after = hasClip and math.floor(tonumber(rawAfter) or 0) or after
        total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
        if after > maxClip and total >= after then
            after = maxClip
        end
    end

    local verified = intended
    if after > 0 then
        if after >= intended then
            verified = intended
        else
            verified = math.max(clipBefore, math.min(intended, after))
        end
    end

    verified = math.min(intended, math.max(clipBefore, verified))
    SetPedAmmo(ped, weaponHash, verified)
    SetAmmoInClip(ped, weaponHash, verified)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    return math.max(0, verified - clipBefore), verified
end

function WeaponAmmo.getSyncedAmmoAmount(ped, weaponHash, weaponData)
    local clip = WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    return clip
end
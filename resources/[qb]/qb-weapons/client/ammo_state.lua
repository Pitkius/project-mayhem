--- Apkaba, inventoriaus sinchronizacija — papildomos kulkos tik inventoriuje, ne ant ped.
WeaponAmmo = WeaponAmmo or {}

--- Kai CLIP_02 ant ped, bet SetAmmoInClip nepriima virš native max — blokuojam spam.
local overNativeFillFailed = {}

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

local function normalizeWeaponName(weaponName)
    if not weaponName then return nil end
    return tostring(weaponName):lower()
end

local function lookupAttachmentComponent(attachmentTable, weaponName)
    if type(attachmentTable) ~= 'table' or not weaponName then return nil end
    local key = normalizeWeaponName(weaponName)
    local nativeName = WeaponHash and WeaponHash.nativeName and WeaponHash.nativeName(key)
    return attachmentTable[key]
        or (nativeName and attachmentTable[nativeName])
        or attachmentTable[weaponName]
        or nil
end

local function metadataHasClipItem(weaponData, itemKey, comp, compHash)
    local info = weaponData and (weaponData.info or weaponData)
    if type(info) ~= 'table' or type(info.attachments) ~= 'table' then return false end
    for _, attachment in pairs(info.attachments) do
        if type(attachment) == 'table' and tostring(attachment.item or '') == tostring(itemKey) then
            return true
        end
        local attached = attachment and (attachment.component or attachment)
        if comp and (componentsMatch(attached, comp) or componentsMatch(attached, compHash)) then
            return true
        end
    end
    return false
end

local function resolveClipComponentHash(weaponData, itemKey, attachmentTable)
    local comp = lookupAttachmentComponent(attachmentTable, weaponData and weaponData.name)
    local compHash = componentHash(comp)
    if compHash then return compHash end
    local info = weaponData and (weaponData.info or weaponData)
    if type(info) ~= 'table' or type(info.attachments) ~= 'table' then return nil end
    for _, attachment in pairs(info.attachments) do
        if type(attachment) == 'table' and tostring(attachment.item or '') == tostring(itemKey) then
            return componentHash(attachment.component)
        end
    end
    return nil
end

local function weaponHasClipItem(ped, weaponHash, weaponData, itemKey, attachmentTable)
    local weaponName = weaponData and weaponData.name
    if not weaponName then return false end

    if metadataHasClipItem(weaponData, itemKey, nil, nil) then
        return true
    end

    if type(attachmentTable) ~= 'table' then return false end
    local compHash = resolveClipComponentHash(weaponData, itemKey, attachmentTable)
    if ped and weaponHash and compHash and HasPedGotWeaponComponent(ped, weaponHash, compHash) then
        return true
    end
    local comp = lookupAttachmentComponent(attachmentTable, weaponName)
    if comp and metadataHasClipItem(weaponData, itemKey, comp, compHash) then
        return true
    end
    return false
end

--- true jei bent vienas CLIP_02/03 komponentas realiai ant ped.
local function pedHasClipComponent(ped, weaponHash, weaponData)
    if not ped or not weaponHash or not weaponData then return false end
    local groups = {
        Config.DrumClipAttachmentItems,
        Config.ExtendedClipAttachmentItems,
    }
    for i = 1, #groups do
        local itemKeys = groups[i]
        if type(itemKeys) == 'table' then
            for _, itemKey in ipairs(itemKeys) do
                local attachmentTable = WeaponAttachments and WeaponAttachments[itemKey]
                local compHash = resolveClipComponentHash(weaponData, itemKey, attachmentTable)
                if compHash and HasPedGotWeaponComponent(ped, weaponHash, compHash) then
                    return true
                end
            end
        end
    end
    return false
end

local function capacityFromTable(capacityTable, weaponName)
    if type(capacityTable) ~= 'table' or not weaponName then return 0 end
    local key = normalizeWeaponName(weaponName)
    local byName = tonumber(capacityTable[key]) or tonumber(capacityTable[weaponName]) or 0
    local nativeName = WeaponHash and WeaponHash.nativeName and WeaponHash.nativeName(key)
    local byNative = nativeName and tonumber(capacityTable[nativeName]) or 0
    return math.max(byName, byNative)
end

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
    local weaponName = normalizeWeaponName(weaponData and weaponData.name)
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
        local a, b = GetMaxAmmoInClip(ped, weaponHash, p2)
        if type(a) == 'boolean' and b ~= nil then
            if a then
                nativeMax = math.max(nativeMax, tonumber(b) or 0)
            end
        else
            local asNum = tonumber(a)
            if asNum and asNum > 0 then
                nativeMax = math.max(nativeMax, asNum)
            end
        end
    end
    return nativeMax
end

local function readClipAmount(ped, weaponHash)
    local a, b = GetAmmoInClip(ped, weaponHash)
    if type(a) == 'boolean' then
        return a and math.max(0, math.floor(tonumber(b) or 0)) or 0
    end
    return math.max(0, math.floor(tonumber(a) or 0))
end

--- Užtikrina, kad CLIP_02/03 iš metadata būtų ant ped prieš talpos/native reload.
--- force=true: Give net jei HasPedGot sako true (holster race); nenaudoti kas-frame sync'e.
function WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData, force)
    if not ped or ped == 0 or not weaponHash or not weaponData then return false end
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
                local comp = lookupAttachmentComponent(attachmentTable, weaponData.name)
                local compHash = resolveClipComponentHash(weaponData, itemKey, attachmentTable)
                if compHash then
                    local wantsClip = metadataHasClipItem(weaponData, itemKey, comp, compHash)
                    if wantsClip then
                        local already = HasPedGotWeaponComponent(ped, weaponHash, compHash)
                        if not already or force then
                            GiveWeaponComponentToPed(ped, weaponHash, compHash)
                            applied = true
                        end
                    end
                end
            end
        end
    end
    if applied then
        Wait(0)
    end
    return applied
end

function WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return end
    SetPedInfiniteAmmoClip(ped, false)
    SetPedInfiniteAmmo(ped, false, weaponHash)
end

--- Talpa: GetMaxAmmoInClip po CLIP_02/03. Config extended TIK kai komponentas ant ped
--- (metadata be komponento → fake 60 ir infinite reload).
function WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local standardClip = math.max(1, defaultClipForWeapon(weaponHash, weaponData))

    if ped and weaponHash and weaponData then
        -- Be force — sync thread kviečia dažnai; trūkstamą CLIP_02 vis tiek uždeda.
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData, false)
    end

    local nativeMax = WeaponAmmo.getNativeMaxClip(ped, weaponHash)
    local attachmentCap = resolveAttachmentClipCapacity(
        weaponData and weaponData.name,
        ped,
        weaponHash,
        weaponData
    )
    local componentOnPed = pedHasClipComponent(ped, weaponHash, weaponData)

    -- Native jau rodo extended/drum — niekada nemažinam iki standard.
    if nativeMax > standardClip then
        overNativeFillFailed[weaponHash] = nil
        if componentOnPed and attachmentCap > nativeMax then
            return attachmentCap
        end
        return nativeMax
    end

    -- CLIP_02/03 ant ped, bet GetMaxAmmoInClip kartais lieka 30 — config fallback OK,
    -- nebent anksčiau SetAmmoInClip atsisakė priimti virš native (spam apsauga).
    if componentOnPed and attachmentCap > 0 then
        if overNativeFillFailed[weaponHash] and nativeMax > 0 and nativeMax <= standardClip then
            return math.min(nativeMax, standardClip)
        end
        return math.max(nativeMax, attachmentCap, 1)
    end

    overNativeFillFailed[weaponHash] = nil

    -- Metadata yra, bet komponento ant ped nėra — soft ensure jau bandė.
    -- Force give daromas reload/equip metu, ne sync thread'e.

    if nativeMax > 0 then
        return math.min(nativeMax, standardClip)
    end
    return standardClip
end

local function readClipAmmoClamped(ped, weaponHash, maxClip)
    local curInClip = readClipAmount(ped, weaponHash)
    local totalAmmo = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    maxClip = math.max(1, math.floor(tonumber(maxClip) or 1))

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
    if ped and weaponHash and weaponData then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData, true)
    end
    local maxClip = WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData)
    local clip = math.min(ammo, maxClip)
    SetPedAmmo(ped, weaponHash, clip)
    SetAmmoInClip(ped, weaponHash, clip)
    local after = select(1, readClipAmmoClamped(ped, weaponHash, maxClip))
    if after < clip then
        clip = after
        SetPedAmmo(ped, weaponHash, clip)
        SetAmmoInClip(ped, weaponHash, clip)
    end
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
    return clip
end

function WeaponAmmo.stageNativeReserve(ped, weaponHash, weaponData, bullets)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0
    end

    local clip, _, missing = WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData)
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

function WeaponAmmo.abortNativeReload(ped, weaponHash, clipBefore, weaponData)
    clipBefore = math.max(0, math.floor(tonumber(clipBefore) or 0))
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0, clipBefore
    end
    WeaponAmmo.applyWeaponAmmoState(ped, weaponHash, clipBefore, weaponData)
    return 0, clipBefore
end

--- @return number loadedDelta, number finalClip
function WeaponAmmo.finishNativeReload(ped, weaponHash, clipBefore, maxClip, staged, weaponData)
    clipBefore = math.max(0, math.floor(tonumber(clipBefore) or 0))
    maxClip = math.max(clipBefore, math.floor(tonumber(maxClip) or clipBefore))
    staged = math.max(0, math.floor(tonumber(staged) or 0))

    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return 0, clipBefore
    end

    if weaponData then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData, true)
        maxClip = math.max(maxClip, WeaponAmmo.resolveMaxClip(ped, weaponHash, weaponData))
    end

    local intended = math.min(maxClip, clipBefore + staged)
    if intended <= clipBefore then
        WeaponAmmo.applyWeaponAmmoState(ped, weaponHash, clipBefore, weaponData)
        return 0, clipBefore
    end

    SetPedAmmo(ped, weaponHash, intended)
    SetAmmoInClip(ped, weaponHash, intended)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    local after = readClipAmount(ped, weaponHash)
    local total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    if after > maxClip and total >= after then
        after = maxClip
    end
    after = math.min(math.max(0, after), maxClip)

    if after < intended then
        WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData, true)
        Wait(0)
        SetPedAmmo(ped, weaponHash, intended)
        SetAmmoInClip(ped, weaponHash, intended)
        after = readClipAmount(ped, weaponHash)
        total = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
        if after > maxClip and total >= after then
            after = maxClip
        end
        after = math.min(math.max(0, after), maxClip)
    end

    local verified = clipBefore
    if after > 0 then
        verified = math.max(clipBefore, math.min(intended, after))
    end

    local nativeMax = WeaponAmmo.getNativeMaxClip(ped, weaponHash)
    if verified > clipBefore and nativeMax > 0 and verified > nativeMax then
        overNativeFillFailed[weaponHash] = nil
    elseif verified <= clipBefore and intended > clipBefore and nativeMax > 0 and clipBefore >= nativeMax then
        -- GTA nepriėmė extended fill — sekantis resolveMaxClip naudos native, kad nebūtų R spam.
        overNativeFillFailed[weaponHash] = true
    end

    SetPedAmmo(ped, weaponHash, verified)
    SetAmmoInClip(ped, weaponHash, verified)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)

    return math.max(0, verified - clipBefore), verified
end

function WeaponAmmo.clearOverNativeFillFail(weaponHash)
    if weaponHash then
        overNativeFillFailed[weaponHash] = nil
    end
end

function WeaponAmmo.getSyncedAmmoAmount(ped, weaponHash, weaponData)
    local clip = WeaponAmmo.normalizePedAmmo(ped, weaponHash, weaponData)
    return clip
end

local QBCore = exports['qb-core']:GetCoreObject()
local ReloadSessions = {}
local ReloadSequence = 0

AddEventHandler('playerDropped', function()
    ReloadSessions[source] = nil
end)

-- Functions

local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

-- Callback

QBCore.Functions.CreateCallback('qb-weapons:server:GetConfig', function(_, cb)
    cb(Config.WeaponRepairPoints)
end)

QBCore.Functions.CreateCallback('weapon:server:GetWeaponAmmo', function(source, cb, WeaponData)
    local Player = QBCore.Functions.GetPlayer(source)
    local retval = 0
    if WeaponData then
        if Player then
            local ItemData = Player.Functions.GetItemBySlot(WeaponData.slot)
            if ItemData then
                retval = ItemData.info.ammo and ItemData.info.ammo or 0
            end
        end
    end
    cb(retval, WeaponData.name)
end)

QBCore.Functions.CreateCallback('qb-weapons:server:RepairWeapon', function(source, cb, RepairPoint, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, '_')[2]):lower()

    if not Player then
        cb(false)
        return
    end

    if not Player.PlayerData.items[data.slot] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_weapon_in_hand'), 'error')
        TriggerClientEvent('qb-weapons:client:SetCurrentWeapon', src, {}, false)
        cb(false)
        return
    end

    if not Player.PlayerData.items[data.slot].info.quality or Player.PlayerData.items[data.slot].info.quality == 100 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_damage_on_weapon'), 'error')
        cb(false)
        return
    end

    if not Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
        cb(false)
        return
    end

    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
        CitizenId = Player.PlayerData.citizenid,
        WeaponData = Player.PlayerData.items[data.slot],
        Ready = false,
    }

    if not exports['qb-inventory']:RemoveItem(src, data.name, 1, data.slot, 'qb-weapons:server:RepairWeapon') then
        Player.Functions.AddMoney('cash', Config.WeaponRepairCosts[WeaponClass], 'qb-weapons:server:RepairWeapon')
        return
    end

    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[data.name], 'remove')
    TriggerClientEvent('qb-inventory:client:CheckWeapon', src, data.name)
    TriggerClientEvent('qb-weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

    SetTimeout(Timeout, function()
        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
        TriggerClientEvent('qb-weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
        exports['qb-phone']:sendNewMailToOffline(Player.PlayerData.citizenid, {
            sender = Lang:t('mail.sender'),
            subject = Lang:t('mail.subject'),
            message = Lang:t('mail.message', { value = WeaponData.label })
        })

        SetTimeout(7 * 60000, function()
            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                TriggerClientEvent('qb-weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
            end
        end)
    end)

    cb(true)
end)

QBCore.Functions.CreateCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    local throwable = false
    for _, v in pairs(Config.Throwables) do
        if QBCore.Shared.Weapons[weapon].name == 'weapon_' .. v then
            if not exports['qb-inventory']:RemoveItem(source, 'weapon_' .. v, 1, false, 'prison:server:checkThrowable') then return cb(false) end
            throwable = true
            break
        end
    end
    cb(throwable)
end)

-- Events

local function capStoredWeaponAmmo(weaponName, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    weaponName = tostring(weaponName or ''):lower()
    if weaponName == 'weapon_petrolcan' or weaponName == 'weapon_fireextinguisher' then
        return math.min(amount, 4000)
    end
    return math.min(amount, 120)
end

local function normalizedAmmoType(value)
    return tostring(value or ''):upper()
end

local function weaponAmmoType(item)
    if not item or not item.name then return '' end
    local shared = QBCore.Shared.Items[item.name]
    if shared and shared.ammotype then
        return normalizedAmmoType(shared.ammotype)
    end
    local weapon = QBCore.Shared.Weapons[joaat(item.name)]
    return normalizedAmmoType(weapon and weapon.ammotype)
end

local function weaponNativeName(weaponName)
    weaponName = tostring(weaponName or ''):lower()
    if WeaponHash and WeaponHash.nativeName then
        return tostring(WeaponHash.nativeName(weaponName) or weaponName):lower()
    end
    local mapped = Config.WeaponNativeHash and Config.WeaponNativeHash[weaponName]
    return tostring(mapped or weaponName):lower()
end

local function lookupWeaponComponent(attachmentTable, weaponName)
    if type(attachmentTable) ~= 'table' then return nil end
    weaponName = tostring(weaponName or ''):lower()
    return attachmentTable[weaponName]
        or attachmentTable[weaponNativeName(weaponName)]
end

--- Server negali kviesti client native `HasPedGotWeaponComponent`.
--- CLIP_02/03 talpa skaičiuojama iš ginklo metadata attachments.
local function normalizeComponentHash(value)
    if value == nil then return nil end
    if type(value) == 'number' then return math.floor(value) end
    local asNum = tonumber(value)
    if asNum then return math.floor(asNum) end
    return joaat(tostring(value))
end

local function weaponHasInstalledComponent(item, component)
    if not item or not component then return false end
    local compHash = normalizeComponentHash(component)
    local attachments = item.info and item.info.attachments
    if type(attachments) ~= 'table' then return false end
    for _, entry in pairs(attachments) do
        local attached = entry and (entry.component or entry)
        local attachedHash = normalizeComponentHash(attached)
        if attached == component or attached == compHash then
            return true
        end
        if attachedHash and compHash and attachedHash == compHash then
            return true
        end
        if type(entry) == 'table' and entry.item then
            local map = WeaponAttachments and WeaponAttachments[tostring(entry.item)]
            local mapped = map and lookupWeaponComponent(map, item.name)
            if mapped and normalizeComponentHash(mapped) == compHash then
                return true
            end
        end
    end
    return false
end

--- Talpa pagal standard + įdiegtus CLIP_02/03 attachmentus (metadata).
local function serverMaxClip(_src, item)
    local name = tostring(item and item.name or ''):lower()
    local ammoType = weaponAmmoType(item)
    local maxClip = tonumber(Config.StandardClipCapacity and Config.StandardClipCapacity[name])
        or tonumber(Config.DefaultClipCapacityByAmmoType and Config.DefaultClipCapacityByAmmoType[ammoType])
        or 30

    local function bumpFromItems(itemKeys, capacityTable)
        if type(itemKeys) ~= 'table' or type(capacityTable) ~= 'table' then return end
        for _, itemKey in ipairs(itemKeys) do
            local attachmentTable = WeaponAttachments and WeaponAttachments[itemKey]
            local component = lookupWeaponComponent(attachmentTable, name)
            if component and weaponHasInstalledComponent(item, component) then
                maxClip = math.max(
                    maxClip,
                    tonumber(capacityTable[name]) or 0,
                    tonumber(capacityTable[weaponNativeName(name)]) or 0
                )
            end
        end
    end

    bumpFromItems(Config.DrumClipAttachmentItems, Config.DrumClipCapacity)
    bumpFromItems(Config.ExtendedClipAttachmentItems, Config.ExtendedClipCapacity)

    return math.min(120, math.max(1, math.floor(maxClip)))
end

local function ammoItemMatchesType(itemName, ammoType)
    local cfg = Config.AmmoTypes[tostring(itemName or ''):lower()]
    return cfg and normalizedAmmoType(cfg.ammoType) == normalizedAmmoType(ammoType)
end

local function countAmmoForType(Player, ammoType)
    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and ammoItemMatchesType(item.name, ammoType) then
            total = total + math.max(0, math.floor(tonumber(item.amount) or 0))
        end
    end
    return total
end

local function nextReloadToken(src)
    ReloadSequence = ReloadSequence + 1
    return ('%d:%d:%d:%d'):format(src, os.time(), ReloadSequence, math.random(100000, 999999))
end

RegisterNetEvent('qb-weapons:server:UpdateWeaponAmmo', function(CurrentWeaponData, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local weaponName = tostring(CurrentWeaponData and CurrentWeaponData.name or ''):lower()
    if weaponName == '' then return end
    amount = capStoredWeaponAmmo(weaponName, amount)
    if CurrentWeaponData then
        local slot = tonumber(CurrentWeaponData.slot)
        local updated = false
        local specialAmmo = weaponName == 'weapon_petrolcan' or weaponName == 'weapon_fireextinguisher'
        if slot and Player.PlayerData.items[slot]
            and tostring(Player.PlayerData.items[slot].name or ''):lower() == weaponName then
            Player.PlayerData.items[slot].info = Player.PlayerData.items[slot].info or {}
            local stored = capStoredWeaponAmmo(weaponName, Player.PlayerData.items[slot].info.ammo or 0)
            Player.PlayerData.items[slot].info.ammo = specialAmmo and amount or math.min(stored, amount)
            updated = true
        end
        if not updated then
            for k, item in pairs(Player.PlayerData.items) do
                if item and tostring(item.name or ''):lower() == weaponName then
                    local isWeapon = item.type == 'weapon'
                    if not isWeapon and item.name:find('^weapon_', 1, false) then
                        isWeapon = true
                    end
                    if isWeapon then
                        Player.PlayerData.items[k].info = Player.PlayerData.items[k].info or {}
                        local stored = capStoredWeaponAmmo(weaponName, Player.PlayerData.items[k].info.ammo or 0)
                        Player.PlayerData.items[k].info.ammo = specialAmmo and amount or math.min(stored, amount)
                        updated = true
                        break
                    end
                end
            end
        end
        if updated then
            Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        end
    end
end)

RegisterNetEvent('qb-weapons:server:TakeBackWeapon', function(k)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    exports['qb-inventory']:AddItem(src, itemdata.name, 1, false, itemdata.info, 'qb-weapons:server:TakeBackWeapon')
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemdata.name], 'add')
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('qb-weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent('qb-weapons:server:SetWeaponQuality', function(data, hp)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local WeaponSlot = Player.PlayerData.items[data.slot]
    WeaponSlot.info.quality = hp
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent('qb-weapons:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponSlot = Player.PlayerData.items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]
    if WeaponSlot then
        if not IsWeaponBlocked(WeaponData.name) then
            if WeaponSlot.info.quality then
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = QBCore.Shared.Round(WeaponSlot.info.quality - DecreaseAmount, 2)
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('qb-weapons:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), 'error')
                        break
                    end
                end
            else
                WeaponSlot.info.quality = 100
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = QBCore.Shared.Round(WeaponSlot.info.quality - DecreaseAmount, 2)
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('qb-weapons:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), 'error')
                        break
                    end
                end
            end
        end
    end
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

local function removeAmmoForReload(src, Player, session, amount)
    local candidates = {}
    local seenSlots = {}
    local preferredSlot = tonumber(session.preferredSlot)
    local preferredItem = tostring(session.preferredItem or ''):lower()

    local function addCandidate(item)
        if not item or not ammoItemMatchesType(item.name, session.ammoType) then return end
        local slot = tonumber(item.slot)
        local available = math.max(0, math.floor(tonumber(item.amount) or 0))
        if not slot or available <= 0 or seenSlots[slot] then return end
        seenSlots[slot] = true
        candidates[#candidates + 1] = {
            name = tostring(item.name):lower(),
            slot = slot,
            amount = available,
        }
    end

    if preferredSlot then
        for _, item in pairs(Player.PlayerData.items or {}) do
            if tonumber(item and item.slot) == preferredSlot
                and (preferredItem == '' or tostring(item.name):lower() == preferredItem) then
                addCandidate(item)
                break
            end
        end
    end
    for _, item in pairs(Player.PlayerData.items or {}) do
        addCandidate(item)
    end

    local remaining = math.max(0, math.floor(tonumber(amount) or 0))
    local removed = 0
    local firstItemName = nil
    for _, candidate in ipairs(candidates) do
        if remaining <= 0 then break end
        local take = math.min(candidate.amount, remaining)
        if take > 0 and exports['qb-inventory']:RemoveItem(
            src,
            candidate.name,
            take,
            candidate.slot,
            'qb-weapons:native-reload'
        ) then
            firstItemName = firstItemName or candidate.name
            removed = removed + take
            remaining = remaining - take
        end
    end
    return removed, firstItemName
end

QBCore.Functions.CreateCallback('qb-weapons:server:beginReload', function(source, cb, request)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    request = type(request) == 'table' and request or {}
    if not Player then return cb({ ok = false }) end

    local previous = ReloadSessions[src]
    if previous and previous.expiresAt > os.time() then
        return cb({ ok = false, message = '' })
    end
    ReloadSessions[src] = nil

    local weaponSlot = tonumber(request.weaponSlot)
    local weaponName = tostring(request.weaponName or ''):lower()
    local weaponItem = weaponSlot and exports['qb-inventory']:GetItemBySlot(src, weaponSlot) or nil
    local isWeaponItem = weaponItem and (
        weaponItem.type == 'weapon'
        or tostring(weaponItem.name or ''):lower():find('^weapon_') ~= nil
    )
    if not weaponItem or tostring(weaponItem.name or ''):lower() ~= weaponName
        or not isWeaponItem then
        return cb({ ok = false, message = Lang:t('error.no_weapon_in_hand') })
    end

    local ammoType = weaponAmmoType(weaponItem)
    if ammoType == '' or ammoType ~= normalizedAmmoType(request.ammoType) then
        return cb({ ok = false, message = Lang:t('error.wrong_ammo') })
    end

    local preferredItem = tostring(request.preferredItem or ''):lower()
    if preferredItem ~= '' and not ammoItemMatchesType(preferredItem, ammoType) then
        return cb({ ok = false, message = Lang:t('error.wrong_ammo') })
    end

    local maxClip = serverMaxClip(src, weaponItem)
    -- Talpa tik iš ginklo metadata (CLIP_02/03). Commit nuskaito tik verified `loaded`.
    local storedClip = capStoredWeaponAmmo(weaponName, weaponItem.info and weaponItem.info.ammo or 0)
    local reportedClip = math.max(0, math.floor(tonumber(request.clipBefore) or 0))
    local clipBefore = math.min(storedClip, reportedClip, maxClip)
    local missing = math.max(0, maxClip - clipBefore)
    if missing <= 0 then
        return cb({ ok = false, message = Lang:t('error.max_ammo') or 'Apkaba pilna.' })
    end

    local available = countAmmoForType(Player, ammoType)
    local grant = math.min(missing, available)
    if grant <= 0 then
        return cb({ ok = false, message = 'No ammo in inventory.' })
    end

    local token = nextReloadToken(src)
    ReloadSessions[src] = {
        token = token,
        weaponName = weaponName,
        weaponSlot = weaponSlot,
        weaponSerial = tostring(weaponItem.info and weaponItem.info.serie or ''),
        ammoType = ammoType,
        clipBefore = clipBefore,
        maxClip = maxClip,
        grant = grant,
        preferredItem = preferredItem,
        preferredSlot = tonumber(request.preferredSlot),
        issuedAt = GetGameTimer(),
        expiresAt = os.time() + 12,
    }

    cb({
        ok = true,
        token = token,
        clipBefore = clipBefore,
        maxClip = maxClip,
        grant = grant,
    })
end)

QBCore.Functions.CreateCallback('qb-weapons:server:commitReload', function(source, cb, request)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    request = type(request) == 'table' and request or {}
    local session = ReloadSessions[src]
    if not Player or not session or tostring(request.token or '') ~= session.token then
        return cb({ ok = false, message = 'Reload sesija nebegalioja.' })
    end

    -- Tokenas vienkartinis: pašalinamas prieš bet kokį inventory veiksmą.
    ReloadSessions[src] = nil
    if session.expiresAt <= os.time() then
        return cb({ ok = false, clip = session.clipBefore, message = 'Reload sesija baigėsi.' })
    end

    local weaponItem = exports['qb-inventory']:GetItemBySlot(src, session.weaponSlot)
    if not weaponItem or tostring(weaponItem.name or ''):lower() ~= session.weaponName then
        return cb({ ok = false, clip = session.clipBefore, message = Lang:t('error.no_weapon_in_hand') })
    end
    local currentSerial = tostring(weaponItem.info and weaponItem.info.serie or '')
    if session.weaponSerial ~= '' and currentSerial ~= session.weaponSerial then
        return cb({ ok = false, message = Lang:t('error.no_weapon_in_hand') })
    end

    local requestedLoaded = math.min(
        session.grant,
        math.max(0, math.floor(tonumber(request.loaded) or 0))
    )
    local currentStored = capStoredWeaponAmmo(
        session.weaponName,
        weaponItem.info and weaponItem.info.ammo or 0
    )
    if requestedLoaded > 0 and (GetGameTimer() - (tonumber(session.issuedAt) or 0)) < 350 then
        return cb({
            ok = false,
            clip = currentStored,
            message = 'Reload patvirtintas per anksti.',
        })
    end
    local cancelClip = request.cancelClip ~= nil
        and math.max(0, math.floor(tonumber(request.cancelClip) or 0))
        or session.clipBefore
    local baseClip = math.min(session.clipBefore, currentStored, cancelClip, session.maxClip)
    local available = countAmmoForType(Player, session.ammoType)
    local toRemove = math.min(requestedLoaded, available)
    local removed, itemName = removeAmmoForReload(src, Player, session, toRemove)
    local finalClip = math.min(session.maxClip, baseClip + removed)

    Player = QBCore.Functions.GetPlayer(src)
    weaponItem = Player and exports['qb-inventory']:GetItemBySlot(src, session.weaponSlot) or nil
    if not Player or not weaponItem or tostring(weaponItem.name or ''):lower() ~= session.weaponName then
        return cb({ ok = false, clip = baseClip, message = Lang:t('error.no_weapon_in_hand') })
    end
    currentSerial = tostring(weaponItem.info and weaponItem.info.serie or '')
    if session.weaponSerial ~= '' and currentSerial ~= session.weaponSerial then
        return cb({ ok = false, clip = baseClip, message = Lang:t('error.no_weapon_in_hand') })
    end

    weaponItem.info = weaponItem.info or {}
    weaponItem.info.ammo = finalClip
    Player.PlayerData.items[session.weaponSlot] = weaponItem
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)

    cb({
        ok = true,
        clip = finalClip,
        removed = removed,
        itemName = itemName,
    })
end)

-- Commands

QBCore.Commands.Add('repairweapon', 'Repair Weapon (God Only)', { { name = 'hp', help = Lang:t('info.hp_of_weapon') } }, true, function(source, args)
    TriggerClientEvent('qb-weapons:client:SetWeaponQuality', source, tonumber(args[1]))
end, 'god')

-- Items

-- AMMO
for ammoItem, properties in pairs(Config.AmmoTypes) do
    QBCore.Functions.CreateUseableItem(ammoItem, function(source, item)
        TriggerClientEvent('qb-weapons:client:UseAmmo', source, properties.ammoType, item)
    end)
end

-- TINTS

local function GetWeaponSlotByName(items, weaponName)
    weaponName = tostring(weaponName or ''):lower()
    for index, item in pairs(items) do
        if item and tostring(item.name or ''):lower() == weaponName then
            return item, index
        end
    end

    -- Addon ginklai naudoja native hash (pvz. fgc9 → combatpistol).
    for invName, nativeName in pairs(Config.WeaponNativeHash or {}) do
        if tostring(nativeName):lower() == weaponName then
            local key = tostring(invName):lower()
            for index, item in pairs(items) do
                if item and tostring(item.name or ''):lower() == key then
                    return item, index
                end
            end
        end
    end

    if WeaponHash and WeaponHash.inventoryNameFromNative then
        local invName = WeaponHash.inventoryNameFromNative(joaat(weaponName))
        if invName then
            for index, item in pairs(items) do
                if item and tostring(item.name or ''):lower() == tostring(invName):lower() then
                    return item, index
                end
            end
        end
    end

    return nil, nil
end

local function IsMK2Weapon(weaponHash)
    local weaponName = QBCore.Shared.Weapons[weaponHash]['name']
    return string.find(weaponName, 'mk2') ~= nil
end

local function EquipWeaponTint(source, tintIndex, item, isMK2)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local ped = GetPlayerPed(source)
    local selectedWeaponHash = GetSelectedPedWeapon(ped)

    if selectedWeaponHash == `WEAPON_UNARMED` then
        TriggerClientEvent('QBCore:Notify', source, 'You have no weapon selected.', 'error')
        return
    end

    local weaponName = QBCore.Shared.Weapons[selectedWeaponHash].name
    if not weaponName then return end

    if isMK2 and not IsMK2Weapon(selectedWeaponHash) then
        TriggerClientEvent('QBCore:Notify', source, 'This tint is only for MK2 weapons', 'error')
        return
    end

    local weaponSlot, weaponSlotIndex = GetWeaponSlotByName(Player.PlayerData.items, weaponName)
    if not weaponSlot then return end

    if weaponSlot.info.tint == tintIndex then
        TriggerClientEvent('QBCore:Notify', source, 'This tint is already applied to your weapon.', 'error')
        return
    end

    weaponSlot.info.tint = tintIndex
    Player.PlayerData.items[weaponSlotIndex] = weaponSlot
    Player.Functions.SetInventory(Player.PlayerData.items, true)
    exports['qb-inventory']:RemoveItem(source, item, 1, false, 'qb-weapon:EquipWeaponTint')
    TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove')
    TriggerClientEvent('qb-weapons:client:EquipTint', source, selectedWeaponHash, tintIndex)
end

for i = 0, 7 do
    QBCore.Functions.CreateUseableItem('weapontint_' .. i, function(source, item)
        EquipWeaponTint(source, i, item.name, false)
    end)
end

for i = 0, 32 do
    QBCore.Functions.CreateUseableItem('weapontint_mk2_' .. i, function(source, item)
        EquipWeaponTint(source, i, item.name, true)
    end)
end

-- Attachments

local function HasAttachment(component, attachments)
    for k, v in pairs(attachments) do
        if v.component == component then
            return true, k
        end
    end
    return false, nil
end

local function DoesWeaponTakeWeaponComponent(item, weaponName)
    weaponName = tostring(weaponName or ''):lower()
    local map = WeaponAttachments and WeaponAttachments[item]
    if not map then return false end
    local component = lookupWeaponComponent(map, weaponName)
    return component or false
end

local function EquipWeaponAttachment(src, item)
    local shouldRemove = false
    local ped = GetPlayerPed(src)
    local selectedWeaponHash = GetSelectedPedWeapon(ped)
    if selectedWeaponHash == `WEAPON_UNARMED` then return end
    local sharedWeapon = QBCore.Shared.Weapons[selectedWeaponHash]
    local weaponName = sharedWeapon and sharedWeapon.name
    if not weaponName then return end
    local attachmentComponent = DoesWeaponTakeWeaponComponent(item, weaponName)
    if not attachmentComponent then
        TriggerClientEvent('QBCore:Notify', src, 'This attachment is not valid for the selected weapon.', 'error')
        return
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local weaponSlot, weaponSlotIndex = GetWeaponSlotByName(Player.PlayerData.items, weaponName)
    if not weaponSlot then return end
    weaponSlot.info.attachments = weaponSlot.info.attachments or {}
    local hasAttach, attachIndex = HasAttachment(attachmentComponent, weaponSlot.info.attachments)
    if hasAttach then
        pcall(RemoveWeaponComponentFromPed, ped, selectedWeaponHash, attachmentComponent)
        table.remove(weaponSlot.info.attachments, attachIndex)
        TriggerClientEvent('qb-weapons:client:SetWeaponComponent', src, selectedWeaponHash, attachmentComponent, false)
    else
        -- Tik komponentas — jokio ammo „užkrovimo“ iš inventoriaus.
        weaponSlot.info.attachments[#weaponSlot.info.attachments + 1] = {
            component = attachmentComponent,
            item = item,
        }
        pcall(GiveWeaponComponentToPed, ped, selectedWeaponHash, attachmentComponent)
        TriggerClientEvent('qb-weapons:client:SetWeaponComponent', src, selectedWeaponHash, attachmentComponent, true)
        shouldRemove = true
    end
    Player.PlayerData.items[weaponSlotIndex] = weaponSlot
    Player.Functions.SetInventory(Player.PlayerData.items, true)
    if shouldRemove then
        exports['qb-inventory']:RemoveItem(src, item, 1, false, 'qb-weapons:EquipWeaponAttachment')
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove')
    end
end

for attachmentItem in pairs(WeaponAttachments) do
    QBCore.Functions.CreateUseableItem(attachmentItem, function(source, item)
        EquipWeaponAttachment(source, item.name)
    end)
end

QBCore.Functions.CreateCallback('qb-weapons:server:RemoveAttachment', function(source, cb, AttachmentData, WeaponData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local allAttachments = WeaponAttachments
    local AttachmentComponent = allAttachments[AttachmentData.attachment]
        and lookupWeaponComponent(allAttachments[AttachmentData.attachment], WeaponData.name)
    if not AttachmentComponent then
        cb(false)
        return
    end
    if Inventory[WeaponData.slot] then
        if Inventory[WeaponData.slot].info.attachments and next(Inventory[WeaponData.slot].info.attachments) then
            local HasAttach, key = HasAttachment(AttachmentComponent, Inventory[WeaponData.slot].info.attachments)
            if HasAttach then
                table.remove(Inventory[WeaponData.slot].info.attachments, key)
                Player.Functions.SetInventory(Player.PlayerData.items, true)
                exports['qb-inventory']:AddItem(src, AttachmentData.attachment, 1, false, false, 'qb-weapons:server:RemoveAttachment')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[AttachmentData.attachment], 'add')
                TriggerClientEvent('QBCore:Notify', src, Lang:t('info.removed_attachment', { value = QBCore.Shared.Items[AttachmentData.attachment].label }), 'error')
                local ped = GetPlayerPed(src)
                local weaponHash = joaat(weaponNativeName(WeaponData.name))
                pcall(RemoveWeaponComponentFromPed, ped, weaponHash, AttachmentComponent)
                TriggerClientEvent('qb-weapons:client:SetWeaponComponent', src, weaponHash, AttachmentComponent, false)
                cb(Inventory[WeaponData.slot].info.attachments)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

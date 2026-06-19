-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local CurrentWeaponData, CanShoot, MultiplierAmount, currentWeapon = {}, true, 0, nil
local lastSyncedWeapon = nil
local lastSyncedAmmo = nil
local lastAmmoSyncAt = 0
local reloadGuardUntil = 0
local isReloading = false

local AmmoItemByType = {
    AMMO_PISTOL = { 'pistol_ammo', 'pistolammo' },
    AMMO_SMG = { 'smg_ammo', 'smgammo' },
    AMMO_RIFLE = { 'rifle_ammo', 'rifleammo' },
    AMMO_SHOTGUN = { 'shotgun_ammo' },
    AMMO_MUSKET = { 'hunting_ammo' },
    AMMO_MG = { 'mg_ammo' },
    AMMO_SNIPER = { 'snp_ammo' },
}

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2400
end

--- QB dažnai atnaujina inventorių — visada skaitom šviežią kopiją (ne modulio PlayerData).
local function getTotalAmmoItems(itemName)
    if not itemName then return 0 end
    local pd = QBCore.Functions.GetPlayerData()
    local items = pd and pd.items or nil
    if not items then return 0 end
    local total = 0
    for _, item in pairs(items) do
        if item and item.name == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function getTotalAmmoForType(normalizedAmmoType, preferredItemName)
    local list = AmmoItemByType[tostring(normalizedAmmoType or ''):upper()]
    if type(list) ~= 'table' then
        local one = preferredItemName and getTotalAmmoItems(preferredItemName) or 0
        return one, preferredItemName
    end
    local total = 0
    local pickName = nil
    if preferredItemName and getTotalAmmoItems(preferredItemName) > 0 then
        pickName = preferredItemName
    end
    for _, itemName in ipairs(list) do
        total = total + getTotalAmmoItems(itemName)
        if not pickName and getTotalAmmoItems(itemName) > 0 then
            pickName = itemName
        end
    end
    return total, pickName or list[1]
end

local function pickAmmoItemForType(ammoType)
    local list = AmmoItemByType[tostring(ammoType or ''):upper()]
    if type(list) ~= 'table' then return nil end
    for _, itemName in ipairs(list) do
        if getTotalAmmoItems(itemName) > 0 then
            return itemName
        end
    end
    return list[1]
end

local function nativeWeaponHash(weaponName)
    if WeaponHash and WeaponHash.resolve then
        return WeaponHash.resolve(weaponName)
    end
    return joaat(weaponName)
end

--- Seni DB itemai dažnai neturi `type` — kitaip holster sync ištrina visus ginklus ir nebeatstato.
local function isInventoryWeaponItem(item)
    if not item or not item.name then return false end
    if item.type == 'weapon' then return true end
    local name = tostring(item.name):lower()
    if name:find('^weapon_', 1, false) then return true end
    local shared = QBCore.Shared.Items[name]
    return shared and shared.type == 'weapon'
end

local function resolveCurrentWeaponDataForPed(pedWeaponHash, selectedWeaponData)
    if CurrentWeaponData and CurrentWeaponData.name and nativeWeaponHash(CurrentWeaponData.name) == pedWeaponHash then
        return CurrentWeaponData
    end
    local invName = WeaponHash and WeaponHash.inventoryNameFromNative(pedWeaponHash)
    if invName then
        local row = resolveCurrentWeaponDataByName(invName)
        if row then return row end
    end
    if selectedWeaponData and selectedWeaponData.name then
        return resolveCurrentWeaponDataByName(selectedWeaponData.name) or CurrentWeaponData
    end
    return CurrentWeaponData
end

local function inventoryWeaponNameForPed(pedWeaponHash, selectedWeaponData)
    local row = resolveCurrentWeaponDataForPed(pedWeaponHash, selectedWeaponData)
    return (row and row.name) or (selectedWeaponData and selectedWeaponData.name)
end

local function isReloadBusy()
    return isReloading or GetGameTimer() < reloadGuardUntil
end

local function isWeaponDrawBusy()
    return _G.QBWeaponDrawBusy == true
end

local function cancelActiveReload()
    if not isReloading and GetGameTimer() >= reloadGuardUntil then return end
    if WeaponReload and WeaponReload.cancel then
        WeaponReload.cancel(PlayerPedId())
    end
    isReloading = false
    reloadGuardUntil = 0
end

local function applyWeaponAttachmentsAndTint(ped, weaponHash, weaponInfo)
    weaponInfo = weaponInfo or {}
    if weaponInfo.attachments then
        for _, attachment in pairs(weaponInfo.attachments) do
            local comp = attachment.component
            if type(comp) == 'number' then
                GiveWeaponComponentToPed(ped, weaponHash, comp)
            elseif comp then
                GiveWeaponComponentToPed(ped, weaponHash, joaat(tostring(comp)))
            end
        end
    end
    if weaponInfo.tint then
        SetPedWeaponTintIndex(ped, weaponHash, weaponInfo.tint)
    end
end

--- Užtikrina, kad pasirinktas inventoriaus ginklas būtų rankoje (ne tik ant nugaros / paslėptas).
local function equipWeaponInHand(weaponData)
    if not weaponData or not weaponData.name then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local name = tostring(weaponData.name)
    local weaponHash = nativeWeaponHash(name)
    if not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return end

    local ammo = tonumber(weaponData.info and weaponData.info.ammo) or 0
    if name == 'weapon_petrolcan' or name == 'weapon_fireextinguisher' then
        ammo = 4000
    end

    if not HasPedGotWeapon(ped, weaponHash, false) then
        GiveWeaponToPed(ped, weaponHash, math.max(ammo, 0), false, false)
    end
    WeaponAmmo.applyWeaponAmmoState(ped, weaponHash, ammo, weaponData)
    applyWeaponAttachmentsAndTint(ped, weaponHash, weaponData.info)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetCurrentPedWeapon(ped, weaponHash, true)
    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

local function queueDrawWeapon(weaponName)
    CreateThread(function()
        TriggerEvent('qb-weapons:client:DrawWeapon', weaponName)
    end)
end

-- Handlers

--- QB dažnai atnaujina inventorių per `UpdatePlayerDataField` — visada skaitom iš core, ne iš pasenusios `PlayerData` kopijos.
local function getItemsFromCore()
    local pd = QBCore.Functions.GetPlayerData()
    return pd and pd.items or nil
end

local function attemptQuickReload(ped)
    if isReloadBusy() then return false end

    ped = ped or PlayerPedId()
    if not ped or ped == 0 or not IsPedArmed(ped, 7) then return false end

    local weapon = GetSelectedPedWeapon(ped)
    local selectedWeaponData = QBCore.Shared.Weapons[weapon]
    if not selectedWeaponData or selectedWeaponData.name == 'weapon_unarmed' then return false end

    local weaponRow = resolveCurrentWeaponDataForPed(weapon, selectedWeaponData)
    local _, _, clipMissing = WeaponAmmo.getClipAmmoState(ped, weapon, weaponRow or selectedWeaponData)
    if clipMissing <= 0 then
        QBCore.Functions.Notify(Lang:t('error.max_ammo') or 'Apkaba pilna.', 'error')
        return false
    end

    local ammoType = tostring(selectedWeaponData.ammotype or ''):upper()
    local ammoNames = AmmoItemByType[ammoType]
    if type(ammoNames) ~= 'table' then return false end

    local items = getItemsFromCore()
    if not items then return false end

    for _, ammoItemName in ipairs(ammoNames) do
        for _, item in pairs(items) do
            if item and item.name == ammoItemName and (tonumber(item.amount) or 0) > 0 then
                TriggerServerEvent('qb-weapons:server:requestQuickReload', ammoItemName, ammoType, tonumber(item.slot))
                return true
            end
        end
    end

    QBCore.Functions.Notify('No ammo in inventory.', 'error')
    return false
end

local holsterApplyPending = false
local lastHolsterVisualSig = nil

local function isThrowableInventoryWeaponName(name)
    if not name then return true end
    local n = tostring(name):lower()
    if n == 'weapon_unarmed' then return true end
    local throwEventBlock = {
        weapon_stickybomb = true,
        weapon_pipebomb = true,
        weapon_smokegrenade = true,
        weapon_flare = true,
        weapon_proxmine = true,
        weapon_ball = true,
        weapon_molotov = true,
        weapon_grenade = true,
        weapon_bzgas = true,
        weapon_snowball = true,
    }
    if throwEventBlock[n] then return true end
    for _, t in ipairs(Config.Throwables or {}) do
        local key = tostring(t):lower()
        if n == ('weapon_' .. key) or n == key then return true end
    end
    return false
end

local function isExternallyBackCarriedWeapon(name)
    if GetResourceState('fivempro_basics') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports['fivempro_basics']:IsLongBackWeapon(name)
    end)
    return ok and res == true
end

local function buildHolsterVisualSignature(items)
    if not items then return '' end
    local parts = {}
    for _, item in pairs(items) do
        if item and isInventoryWeaponItem(item) and (tonumber(item.amount) or 0) > 0 then
            local name = tostring(item.name or '')
            if not isThrowableInventoryWeaponName(name) and not isExternallyBackCarriedWeapon(name) then
                local attachments = ''
                if item.info and item.info.attachments then
                    local ac = {}
                    for _, a in pairs(item.info.attachments) do
                        ac[#ac + 1] = tostring(a.component or a)
                    end
                    table.sort(ac)
                    attachments = table.concat(ac, ',')
                end
                local tint = item.info and item.info.tint or ''
                parts[#parts + 1] = name .. '#' .. attachments .. '#' .. tostring(tint)
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, '|') .. '@' .. tostring(currentWeapon or '')
end

--- Visi inventoriaus ginklai ant pedo (paslėpti), išskyrus dabar pasirinktą — kad matytųsi ant nugaros/kojų.
function applyHolsteredWeaponsFromInventory(force)
    if not LocalPlayer.state.isLoggedIn then return end
    if not force and (isReloadBusy() or isWeaponDrawBusy()) then return end
    if currentWeapon and isThrowableInventoryWeaponName(currentWeapon) then return end
    local items = getItemsFromCore()
    local sig = buildHolsterVisualSignature(items)
    if not force and sig == lastHolsterVisualSig then return end
    lastHolsterVisualSig = sig

    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)

    if not items then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        return
    end

    local shownHash = nil
    if currentWeapon then
        shownHash = nativeWeaponHash(currentWeapon)
    end

    for _, item in pairs(items) do
        if not item or not isInventoryWeaponItem(item) or (tonumber(item.amount) or 0) <= 0 then goto continue end
        local name = tostring(item.name or '')
        if isThrowableInventoryWeaponName(name) then goto continue end

        local h = nativeWeaponHash(name)
        local ammo = tonumber(item.info and item.info.ammo) or 0
        if name == 'weapon_petrolcan' or name == 'weapon_fireextinguisher' then
            ammo = 4000
        end

        local hidden = not shownHash or h ~= shownHash

        if hidden and isExternallyBackCarriedWeapon(name) then
            goto continue
        end

        GiveWeaponToPed(ped, h, ammo, hidden, false)
        WeaponAmmo.applyWeaponAmmoState(ped, h, ammo, item)

        applyWeaponAttachmentsAndTint(ped, h, item.info)

        ::continue::
    end

    if shownHash and shownHash ~= 0 and shownHash ~= `WEAPON_UNARMED` then
        if not HasPedGotWeapon(ped, shownHash, false) and currentWeapon then
            local activeItem = resolveCurrentWeaponDataByName(currentWeapon)
            if activeItem then
                local ammo = tonumber(activeItem.info and activeItem.info.ammo) or 0
                GiveWeaponToPed(ped, shownHash, math.max(ammo, 0), false, false)
                WeaponAmmo.applyWeaponAmmoState(ped, shownHash, ammo, activeItem)
                applyWeaponAttachmentsAndTint(ped, shownHash, activeItem.info)
            end
        end
        SetPedCurrentWeaponVisible(ped, true, false, false, false)
        SetCurrentPedWeapon(ped, shownHash, true)
        WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, shownHash)
    else
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
end

local function scheduleHolsteredWeaponVisuals()
    if holsterApplyPending then return end
    holsterApplyPending = true
    SetTimeout(200, function()
        holsterApplyPending = false
        applyHolsteredWeaponsFromInventory()
        if GetResourceState('fivempro_basics') == 'started' then
            TriggerEvent('fivempro_basics:client:refreshSlungWeapons')
        end
    end)
end

local function resolveCurrentWeaponDataByName(weaponName)
    local items = getItemsFromCore()
    if not items then return nil end
    for _, item in pairs(items) do
        if item and isInventoryWeaponItem(item) and item.name == weaponName then
            return item
        end
    end
    return nil
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('qb-weapons:server:GetConfig', function(RepairPoints)
        for k, data in pairs(RepairPoints) do
            Config.WeaponRepairPoints[k].IsRepairing = data.IsRepairing
            Config.WeaponRepairPoints[k].RepairingData = data.RepairingData
        end
    end)
    SetTimeout(2600, function()
        scheduleHolsteredWeaponVisuals()
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    lastHolsterVisualSig = nil
    for k in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = false
        Config.WeaponRepairPoints[k].RepairingData = {}
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val or QBCore.Functions.GetPlayerData() or {}
end)

RegisterNetEvent('QBCore:Player:UpdatePlayerDataField', function(field, _)
    PlayerData = QBCore.Functions.GetPlayerData() or {}
    if field == 'items' then
        if isReloadBusy() or isWeaponDrawBusy() then return end
        if not (currentWeapon and isThrowableInventoryWeaponName(currentWeapon)) then
            scheduleHolsteredWeaponVisuals()
        end
    end
end)

AddEventHandler('qb-weapons:client:HolsterVisualsAfterDraw', function()
    if isReloadBusy() then return end
    if currentWeapon and isThrowableInventoryWeaponName(currentWeapon) then return end
    scheduleHolsteredWeaponVisuals()
end)

exports('IsWeaponDrawBusy', function()
    return isWeaponDrawBusy()
end)

-- Functions

local function DrawText3Ds(x, y, z, text)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:DrawText3D(x, y, z, text)
        return
    end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Events

RegisterNetEvent('qb-weapons:client:SyncRepairShops', function(NewData, key)
    Config.WeaponRepairPoints[key].IsRepairing = NewData.IsRepairing
    Config.WeaponRepairPoints[key].RepairingData = NewData.RepairingData
end)

RegisterNetEvent('qb-weapons:client:EquipTint', function(weapon, tint)
    local player = PlayerPedId()
    SetPedWeaponTintIndex(player, weapon, tint)
end)

RegisterNetEvent('qb-weapons:client:SetCurrentWeapon', function(data, bool)
    if data ~= false then
        CurrentWeaponData = data
    else
        CurrentWeaponData = {}
    end
    -- Tik aiškus `false` blokuoja šaudymą (sugęstas ginklas). `nil` = gali šaudyti.
    -- Tai ne liečia šovinių naudojimo / R perkrovimo / priedų – tik LMB šūvių logiką.
    CanShoot = bool ~= false
end)

RegisterNetEvent('qb-weapons:client:SetWeaponQuality', function(amount)
    if CurrentWeaponData and next(CurrentWeaponData) then
        TriggerServerEvent('qb-weapons:server:SetWeaponQuality', CurrentWeaponData, amount)
    end
end)

RegisterNetEvent('qb-weapons:client:AddAmmo', function(ammoType, amount, itemData)
    if isReloadBusy() then return end

    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local selectedWeaponData = QBCore.Shared.Weapons[weapon]
    if not selectedWeaponData then
        QBCore.Functions.Notify(Lang:t('error.no_weapon'), 'error')
        return
    end

    if selectedWeaponData.name == 'weapon_unarmed' then
        QBCore.Functions.Notify(Lang:t('error.no_weapon_in_hand'), 'error')
        return
    end

    local normalizedAmmoType = tostring(ammoType or ''):upper()
    local weaponAmmoNorm = tostring(selectedWeaponData.ammotype or ''):upper()
    if weaponAmmoNorm == '' and selectedWeaponData.name and selectedWeaponData.name:find('assaultrifle', 1, true) then
        weaponAmmoNorm = 'AMMO_RIFLE'
    end
    if weaponAmmoNorm ~= normalizedAmmoType then
        QBCore.Functions.Notify(Lang:t('error.wrong_ammo'), 'error')
        return
    end

    CurrentWeaponData = resolveCurrentWeaponDataForPed(weapon, selectedWeaponData)

    local curInClip, maxC, clipMissing = WeaponAmmo.getClipAmmoState(ped, weapon, CurrentWeaponData or selectedWeaponData)

    if clipMissing <= 0 then
        QBCore.Functions.Notify(Lang:t('error.max_ammo') or 'Apkaba pilna.', 'error')
        return
    end

    local preferredAmmoItem = itemData and itemData.name
    local ammoItemName = preferredAmmoItem
    local availableBullets, resolvedAmmoItem = getTotalAmmoForType(normalizedAmmoType, preferredAmmoItem)
    if resolvedAmmoItem then
        ammoItemName = resolvedAmmoItem
    end
    if not ammoItemName then
        ammoItemName = pickAmmoItemForType(normalizedAmmoType)
    end
    if itemData and itemData.quickReload then
        availableBullets = math.max(availableBullets, tonumber(amount) or 0)
    end
    if preferredAmmoItem and getTotalAmmoItems(preferredAmmoItem) > 0 then
        availableBullets = math.max(availableBullets, getTotalAmmoItems(preferredAmmoItem))
        ammoItemName = preferredAmmoItem
    end
    if availableBullets <= 0 then
        QBCore.Functions.Notify('No ammo in inventory.', 'error')
        return
    end

    local bulletsToLoad = math.min(clipMissing, availableBullets)
    if maxC > 0 then
        bulletsToLoad = math.min(bulletsToLoad, maxC - curInClip)
    end
    if bulletsToLoad <= 0 then
        return
    end

    local cachedInventoryBullets = availableBullets
    local plannedBullets = bulletsToLoad

    local function applyInventoryReload()
        ped = PlayerPedId()
        weapon = GetSelectedPedWeapon(ped)
        local current = QBCore.Shared.Weapons[weapon]

        if not current or tostring(current.ammotype or ''):upper() ~= normalizedAmmoType then
            return false, Lang:t('error.wrong_ammo')
        end

        local weaponPayload = CurrentWeaponData
        if not weaponPayload or not weaponPayload.name then
            weaponPayload = resolveCurrentWeaponDataByName(current.name) or selectedWeaponData
        end

        local bulletsAvailable = math.max(getTotalAmmoItems(ammoItemName), cachedInventoryBullets)
        if preferredAmmoItem then
            bulletsAvailable = math.max(bulletsAvailable, getTotalAmmoItems(preferredAmmoItem))
        end
        if itemData and itemData.quickReload then
            bulletsAvailable = math.max(bulletsAvailable, tonumber(amount) or 0)
        end
        if bulletsAvailable <= 0 then
            return false, 'No ammo in inventory.'
        end

        local bulletsNow = math.min(plannedBullets, bulletsAvailable)
        if bulletsNow <= 0 then
            return false, nil
        end

        local reallyLoaded = WeaponAmmo.loadBulletsIntoClip(ped, weapon, weaponPayload or current, bulletsNow)
        if reallyLoaded <= 0 then
            return false, 'Nepavyko užpildyti apkabos.'
        end

        local refreshedAmmo = WeaponAmmo.getSyncedAmmoAmount(ped, weapon, weaponPayload or current)
        local unitsToRemove = math.min(reallyLoaded, bulletsNow, bulletsAvailable)
        local payload = CurrentWeaponData
        if not payload or not payload.name then
            payload = resolveCurrentWeaponDataByName(current.name)
        end
        if payload and payload.name then
            payload.info = payload.info or {}
            payload.info.ammo = refreshedAmmo
            CurrentWeaponData = payload
            TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', payload, refreshedAmmo)
        end
        local ammoInvSlot = itemData and tonumber(itemData.slot)
        TriggerServerEvent('qb-weapons:server:removeWeaponAmmoItem', ammoItemName, unitsToRemove, ammoInvSlot)
        if ammoItemName and QBCore.Shared.Items[ammoItemName] then
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[ammoItemName], 'use', unitsToRemove)
        end
        QBCore.Functions.Notify(Lang:t('success.reloaded'), 'success')

        lastSyncedAmmo = refreshedAmmo
        lastSyncedWeapon = inventoryWeaponNameForPed(weapon, current)
        lastAmmoSyncAt = GetGameTimer()
        return true
    end

    isReloading = true

    local reloadPed = ped
    local reloadWeapon = weapon
    local reloadPayload = CurrentWeaponData or selectedWeaponData

    CreateThread(function()
        local threadOk, threadErr = pcall(function()
            WeaponReload.playVisual(reloadPed, reloadWeapon, plannedBullets, reloadPayload)
        end)
        if not threadOk then
            print(('[qb-weapons] reload visual error: %s'):format(tostring(threadErr)))
            WeaponReload.cancel(PlayerPedId())
        end

        local ok, errMsg = applyInventoryReload()
        if not ok then
            if errMsg then
                QBCore.Functions.Notify(errMsg, 'error')
            end
        else
            local p = PlayerPedId()
            local w = GetSelectedPedWeapon(p)
            if p and p ~= 0 and w and w ~= 0 and CurrentWeaponData and CurrentWeaponData.name then
                WeaponAmmo.normalizePedAmmo(p, w, CurrentWeaponData)
            end
        end

        isReloading = false
        reloadGuardUntil = GetGameTimer() + 120
    end)
end)

RegisterNetEvent('qb-weapons:client:UseWeapon', function(weaponData, shootbool)
    local info = weaponData and weaponData.info
    if not info or info.quality == nil then
        shootbool = true
    elseif shootbool == nil then
        shootbool = tonumber(info.quality) > 0
    end
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    local weaponHash = nativeWeaponHash(weaponData.name)
    if currentWeapon == weaponName then
        cancelActiveReload()
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
        applyHolsteredWeaponsFromInventory(true)
        queueDrawWeapon(nil)
    elseif weaponName == 'weapon_stickybomb' or weaponName == 'weapon_pipebomb' or weaponName == 'weapon_smokegrenade' or weaponName == 'weapon_flare' or weaponName == 'weapon_proxmine' or weaponName == 'weapon_ball' or weaponName == 'weapon_molotov' or weaponName == 'weapon_grenade' or weaponName == 'weapon_bzgas' then
        cancelActiveReload()
        GiveWeaponToPed(ped, weaponHash, 1, false, false)
        SetPedAmmo(ped, weaponHash, 1)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
        queueDrawWeapon(weaponName)
    elseif weaponName == 'weapon_snowball' then
        cancelActiveReload()
        GiveWeaponToPed(ped, weaponHash, 10, false, false)
        SetPedAmmo(ped, weaponHash, 10)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerServerEvent('qb-inventory:server:snowball', 'remove')
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
        queueDrawWeapon(weaponName)
    else
        cancelActiveReload()
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
        applyHolsteredWeaponsFromInventory(true)
        weaponHash = nativeWeaponHash(weaponData.name)
        local syncedAmmo = GetAmmoInPedWeapon(ped, weaponHash)
        TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', weaponData, syncedAmmo)
        -- Paslėpti aktyvų ginklą ir laikyti UNARMED, kad pullout loop'as paleistų animaciją.
        if weaponHash and weaponHash ~= 0 and weaponHash ~= `WEAPON_UNARMED` and HasPedGotWeapon(ped, weaponHash, false) then
            SetPedCurrentWeaponVisible(ped, false, false, false, false)
        end
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        queueDrawWeapon(weaponName)
    end
end)

RegisterNetEvent('qb-weapons:client:CheckWeapon', function(weaponName)
    local wname = weaponName and tostring(weaponName):lower()
    if not wname or currentWeapon ~= wname then return end
    TriggerEvent('qb-weapons:ResetHolster')
    TriggerEvent('qb-weapons:client:SetCurrentWeapon', nil, CanShoot)
    currentWeapon = nil
    applyHolsteredWeaponsFromInventory(true)
end)

-- Threads

CreateThread(function()
    SetWeaponsNoAutoswap(true)
end)

--- Kai kurie resursai vėl įjungia begalinę apkabą – blokuoja tikrą kulkų mažėjimą.
CreateThread(function()
    while true do
        Wait(150)
        local ped = PlayerPedId()
        if IsPedArmed(ped, 7) then
            local w = GetSelectedPedWeapon(ped)
            if w and w ~= 0 and w ~= `WEAPON_UNARMED` then
                WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, w)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if isReloading then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            Wait(0)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if not LocalPlayer.state.isLoggedIn then goto continue end

        local ped = PlayerPedId()
        if not IsPedArmed(ped, 7) then goto continue end

        -- Blokuojam GTA native R perkrovą — naudojam tik savo logiką.
        DisableControlAction(0, 45, true)

        if not isReloadBusy()
            and (IsDisabledControlJustPressed(0, 45) or IsControlJustPressed(0, 45)) then
            attemptQuickReload(ped)
        end

        ::continue::
    end
end)

CreateThread(function()
    while true do
        if not isReloadBusy() then
            local ped = PlayerPedId()
            if IsPedArmed(ped, 7) then
                local weapon = GetSelectedPedWeapon(ped)
                local selectedWeaponData = QBCore.Shared.Weapons[weapon]
                if selectedWeaponData then
                    CurrentWeaponData = resolveCurrentWeaponDataForPed(weapon, selectedWeaponData)
                    WeaponAmmo.normalizePedAmmo(ped, weapon, CurrentWeaponData or selectedWeaponData)
                    local ammo = WeaponAmmo.getSyncedAmmoAmount(ped, weapon, CurrentWeaponData or selectedWeaponData)
                    if CurrentWeaponData and CurrentWeaponData.name then
                        -- Tik kai ped kulkų sk. pasikeičia (šūvis / perkrova) ar keičiasi ginklas — atnaujinam ginklo item info.ammo serveryje.
                        local now = GetGameTimer()
                        local syncName = inventoryWeaponNameForPed(weapon, selectedWeaponData)
                        local weaponSwitched = lastSyncedWeapon ~= syncName
                        local ammoDelta = lastSyncedAmmo ~= ammo
                        local rareResync = (now - lastAmmoSyncAt) >= 120000
                        if weaponSwitched or ammoDelta or rareResync then
                            TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', CurrentWeaponData, tonumber(ammo))
                            lastSyncedWeapon = syncName
                            lastSyncedAmmo = ammo
                            lastAmmoSyncAt = now
                        end
                    end
                    if MultiplierAmount > 0 and CurrentWeaponData and CurrentWeaponData.name then
                        TriggerServerEvent('qb-weapons:server:UpdateWeaponQuality', CurrentWeaponData, MultiplierAmount)
                        MultiplierAmount = 0
                    end
                end
            else
                lastSyncedWeapon = nil
                lastSyncedAmmo = nil
                lastAmmoSyncAt = 0
            end
        end
        Wait(isReloadBusy() and 150 or 100)
    end
end)

local lastDurabilityCheckAt = 0

CreateThread(function()
    while true do
        local waitMs = 400
        if LocalPlayer.state.isLoggedIn and CurrentWeaponData and next(CurrentWeaponData) then
            local ped = PlayerPedId()
            if IsPedArmed(ped, 7) then
                waitMs = 50
                if IsPedShooting(ped) then
                    local weapon = GetSelectedPedWeapon(ped)
                    WeaponAmmo.clearPedWeaponInfiniteAmmo(ped, weapon)
                    if CanShoot then
                        if weapon and weapon ~= 0 and QBCore.Shared.Weapons[weapon] then
                            local now = GetGameTimer()
                            if now - lastDurabilityCheckAt > 180 then
                                lastDurabilityCheckAt = now
                                QBCore.Functions.TriggerCallback('prison:server:checkThrowable', function(result)
                                    if result or GetAmmoInPedWeapon(ped, weapon) <= 0 then return end
                                    MultiplierAmount += 1
                                end, weapon)
                            end
                        end
                    elseif weapon ~= `WEAPON_UNARMED` then
                        TriggerEvent('qb-weapons:client:CheckWeapon', QBCore.Shared.Weapons[weapon]['name'])
                        QBCore.Functions.Notify(Lang:t('error.weapon_broken'), 'error')
                        MultiplierAmount = 0
                    end
                end
            end
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 1500
        if LocalPlayer.state.isLoggedIn then
            local inRange = false
            local nearInteract = false
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local myCitizenId = (QBCore.Functions.GetPlayerData() or {}).citizenid
            for k, data in pairs(Config.WeaponRepairPoints) do
                local distance = #(pos - data.coords)
                if distance < 10 then
                    inRange = true
                    if distance < 1 then
                        nearInteract = true
                        if data.IsRepairing then
                            if data.RepairingData.CitizenId ~= myCitizenId then
                                DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repairshop_not_usable'))
                            else
                                if not data.RepairingData.Ready then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.weapon_will_repair'))
                                else
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                end
                            end
                        else
                            if CurrentWeaponData and next(CurrentWeaponData) then
                                if not data.RepairingData.Ready then
                                    local WeaponData = QBCore.Shared.Weapons[GetHashKey(CurrentWeaponData.name)]
                                    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, '_')[2]):lower()
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repair_weapon_price', { value = Config.WeaponRepairCosts[WeaponClass] }))
                                    if IsControlJustPressed(0, 38) then
                                        QBCore.Functions.TriggerCallback('qb-weapons:server:RepairWeapon', function(HasMoney)
                                            if HasMoney then
                                                CurrentWeaponData = {}
                                            end
                                        end, k, CurrentWeaponData)
                                    end
                                else
                                    if data.RepairingData.CitizenId ~= myCitizenId then
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repairshop_not_usable'))
                                    else
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                        if IsControlJustPressed(0, 38) then
                                            TriggerServerEvent('qb-weapons:server:TakeBackWeapon', k, data)
                                        end
                                    end
                                end
                            else
                                if data.RepairingData.CitizenId == nil then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('error.no_weapon_in_hand'))
                                elseif data.RepairingData.CitizenId == myCitizenId then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                    if IsControlJustPressed(0, 38) then
                                        TriggerServerEvent('qb-weapons:server:TakeBackWeapon', k, data)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if nearInteract then
                waitMs = 5
            elseif inRange then
                waitMs = 250
            end
        end
        Wait(waitMs)
    end
end)

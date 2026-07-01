local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(Player)
    return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

local function isExpiryValid(expiryStr)
    if not expiryStr or expiryStr == '' then return true end
    local y, m, d = tostring(expiryStr):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return true end
    local exp = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 23,
        min = 59,
        sec = 59,
    })
    return os.time() <= exp
end

local function itemMatchesCitizen(info, citizenid)
    if not info or not info.citizenid or info.citizenid == '' then return true end
    return info.citizenid == citizenid
end

local function playerHasLicenseItem(Player, citizenid)
    if not Player then return false end
    citizenid = citizenid or getCitizenId(Player)
    local items = Player.Functions.GetItemsByName(Config.LicenseItem)
    for _, it in pairs(items or {}) do
        if itemMatchesCitizen(it.info, citizenid) then return true end
    end
    return false
end

local function metadataWeaponActive(meta)
    meta = meta or {}
    local licences = meta.licences or {}
    if licences.weapon ~= true then return false end
    return isExpiryValid(meta.weapon_license_expiry)
end

local function hasWeaponLicense(Player)
    if not Player then return false end
    local cid = getCitizenId(Player)
    if metadataWeaponActive(Player.PlayerData.metadata) then return true end
    if playerHasLicenseItem(Player, cid) then return true end
    return false
end

local function licenseDates()
    local issued = os.date('%Y-%m-%d')
    local expiry = os.date('%Y-%m-%d', os.time() + (Config.LicenseValidityDays * 24 * 60 * 60))
    return issued, expiry
end

local function buildLicenseInfo(Player)
    local charinfo = Player.PlayerData.charinfo or {}
    return {
        citizenid = getCitizenId(Player),
        firstname = charinfo.firstname or '',
        lastname = charinfo.lastname or '',
        birthdate = charinfo.birthdate or '',
        type = Config.LicenseLabel,
    }
end

local function setLicenceMetadata(Player, active, issued, expiry)
    local meta = Player.PlayerData.metadata or {}
    local licences = meta.licences or {}
    licences.weapon = active == true
    Player.Functions.SetMetaData('licences', licences)
    if active then
        Player.Functions.SetMetaData('weapon_license_issued', issued)
        Player.Functions.SetMetaData('weapon_license_expiry', expiry)
    else
        Player.Functions.SetMetaData('weapon_license_issued', nil)
        Player.Functions.SetMetaData('weapon_license_expiry', nil)
    end
end

local function removeLicenseItems(Player, citizenid)
    citizenid = citizenid or getCitizenId(Player)
    local items = Player.Functions.GetItemsByName(Config.LicenseItem)
    for _, it in pairs(items or {}) do
        if itemMatchesCitizen(it.info, citizenid) then
            Player.Functions.RemoveItem(Config.LicenseItem, it.amount or 1, it.slot)
        end
    end
end

local function parseInventory(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return {} end
    return data
end

local function inventoryHasLicenseItem(inv, citizenid)
    if type(inv) ~= 'table' then return false end
    for _, item in pairs(inv) do
        if type(item) == 'table' and item.name == Config.LicenseItem then
            if itemMatchesCitizen(item.info, citizenid) then return true end
        end
    end
    return false
end

local function removeLicenseItemsFromInventory(inv, citizenid)
    if type(inv) ~= 'table' then return inv, false end
    local changed = false
    local out = {}
    for _, item in pairs(inv) do
        if type(item) == 'table' and item.name == Config.LicenseItem and itemMatchesCitizen(item.info, citizenid) then
            changed = true
        else
            out[#out + 1] = item
        end
    end
    return out, changed
end

local function addLicenseItemToInventory(inv, info)
    inv = type(inv) == 'table' and inv or {}
    local maxSlot = 0
    for _, item in pairs(inv) do
        if type(item) == 'table' then
            local s = tonumber(item.slot) or 0
            if s > maxSlot then maxSlot = s end
        end
    end
    inv[#inv + 1] = {
        name = Config.LicenseItem,
        amount = 1,
        info = info,
        slot = maxSlot + 1,
    }
    return inv
end

local function decodeMetadata(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function applyMetadataWeapon(meta, active, issued, expiry)
    meta = meta or {}
    meta.licences = meta.licences or {}
    meta.licences.weapon = active == true
    if active then
        meta.weapon_license_issued = issued
        meta.weapon_license_expiry = expiry
    else
        meta.weapon_license_issued = nil
        meta.weapon_license_expiry = nil
    end
    return meta
end

local function issueWeaponLicenseForCitizen(citizenid, issuerSrc)
    if not citizenid or citizenid == '' then
        return false, 'Neteisingas citizenid.'
    end

    local online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if online then
        if hasWeaponLicense(online) then
            return false, 'Asmuo jau turi ginklo licenciją.'
        end
        local issued, expiry = licenseDates()
        setLicenceMetadata(online, true, issued, expiry)
        local info = buildLicenseInfo(online)
        if not online.Functions.AddItem(Config.LicenseItem, 1, false, info) then
            setLicenceMetadata(online, false)
            return false, 'Nepavyko įdėti licencijos į inventorių (pilnas?).'
        end
        TriggerClientEvent('inventory:client:ItemBox', online.PlayerData.source, QBCore.Shared.Items[Config.LicenseItem], 'add')
        TriggerClientEvent('QBCore:Notify', online.PlayerData.source, 'Ginklo licencija išduota.', 'success')
        return true, 'Ginklo licencija išduota.'
    end

    local row = MySQL.single.await(
        'SELECT citizenid, charinfo, metadata, inventory FROM players WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    if not row then return false, 'Asmuo nerastas.' end

    local meta = decodeMetadata(row.metadata)
    if metadataWeaponActive(meta) or inventoryHasLicenseItem(parseInventory(row.inventory), citizenid) then
        return false, 'Asmuo jau turi ginklo licenciją.'
    end

    local charinfo = {}
    if row.charinfo and row.charinfo ~= '' then
        local ok, data = pcall(json.decode, row.charinfo)
        if ok and type(data) == 'table' then charinfo = data end
    end
    local issued, expiry = licenseDates()
    meta = applyMetadataWeapon(meta, true, issued, expiry)
    local info = {
        citizenid = citizenid,
        firstname = charinfo.firstname or '',
        lastname = charinfo.lastname or '',
        birthdate = charinfo.birthdate or '',
        type = Config.LicenseLabel,
    }
    local inv = addLicenseItemToInventory(parseInventory(row.inventory), info)
    MySQL.update.await(
        'UPDATE players SET metadata = ?, inventory = ? WHERE citizenid = ?',
        { json.encode(meta), json.encode(inv), citizenid }
    )
    return true, 'Ginklo licencija išduota (offline).'
end

local function revokeWeaponLicenseForCitizen(citizenid)
    if not citizenid or citizenid == '' then
        return false, 'Neteisingas citizenid.'
    end

    local online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if online then
        if not hasWeaponLicense(online) then
            return false, 'Asmuo neturi ginklo licencijos.'
        end
        setLicenceMetadata(online, false)
        removeLicenseItems(online, citizenid)
        TriggerClientEvent('QBCore:Notify', online.PlayerData.source, 'Ginklo licencija atšaukta.', 'error')
        return true, 'Ginklo licencija atšaukta.'
    end

    local row = MySQL.single.await(
        'SELECT citizenid, metadata, inventory FROM players WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    if not row then return false, 'Asmuo nerastas.' end

    local meta = decodeMetadata(row.metadata)
    local inv = parseInventory(row.inventory)
    local had = metadataWeaponActive(meta) or inventoryHasLicenseItem(inv, citizenid)
    if not had then return false, 'Asmuo neturi ginklo licencijos.' end

    meta = applyMetadataWeapon(meta, false)
    inv, _ = removeLicenseItemsFromInventory(inv, citizenid)
    MySQL.update.await(
        'UPDATE players SET metadata = ?, inventory = ? WHERE citizenid = ?',
        { json.encode(meta), json.encode(inv), citizenid }
    )
    return true, 'Ginklo licencija atšaukta (offline).'
end

local function registerGunShop()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    local cfg = Config.Shop
    if not cfg or not cfg.name or not cfg.items then return end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label,
        slots = #cfg.items,
        items = cfg.items,
    })
end

CreateThread(function()
    Wait(1000)
    registerGunShop()
end)

local function nearGunShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    for _, loc in ipairs(Config.Locations or {}) do
        local c = loc.coords
        if c and #(p - vector3(c.x, c.y, c.z)) <= (Config.ShopOpenDistance or 5.0) then
            return true
        end
    end
    return false
end

RegisterNetEvent('mrp_gunshop:server:openShop', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not nearGunShop(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo ginklų parduotuvės.', 'error')
    end
    if not hasWeaponLicense(Player) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia ginklo licencijos. Kreipkitės į policiją.', 'error')
    end
    registerGunShop()
    exports['qb-inventory']:OpenShop(src, Config.Shop.name)
end)

QBCore.Functions.CreateCallback('mrp_gunshop:server:hasLicense', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(hasWeaponLicense(Player))
end)

exports('HasWeaponLicense', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return hasWeaponLicense(Player)
end)

exports('IssueWeaponLicense', function(citizenid, issuerSrc)
    return issueWeaponLicenseForCitizen(citizenid, issuerSrc)
end)

exports('RevokeWeaponLicense', function(citizenid)
    return revokeWeaponLicenseForCitizen(citizenid)
end)

exports('MetadataWeaponActive', metadataWeaponActive)

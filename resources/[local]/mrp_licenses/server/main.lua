local QBCore = exports['qb-core']:GetCoreObject()

local function formatDate(ts)
    if ts == nil or ts == '' then return nil end
    if type(ts) == 'number' then
        if ts > 1e12 then ts = math.floor(ts / 1000) end
        return os.date('%Y-%m-%d', ts)
    end
    if type(ts) == 'string' then return ts end
    return nil
end

local function today()
    return os.date('%Y-%m-%d')
end

local function addYears(years)
    return os.date('%Y-%m-%d', os.time() + (years * 365 * 24 * 60 * 60))
end

local function genderLabel(g)
    if g == 0 or g == '0' or g == 'male' or g == 'Male' or g == 'Vyras' then return 'Vyras' end
    if g == 1 or g == '1' or g == 'female' or g == 'Female' or g == 'Moteris' then return 'Moteris' end
    return tostring(g or '—')
end

local function initials(first, last)
    local a = (tostring(first or ''):sub(1, 1)):upper()
    local b = (tostring(last or ''):sub(1, 1)):upper()
    if a == '' and b == '' then return '?' end
    return a .. b
end

local function hasDrivingCategory(licences, cat)
    if licences[cat.key] == true then return true end
    if cat.altKeys then
        for _, k in ipairs(cat.altKeys) do
            if licences[k] == true then return true end
        end
    end
    return false
end

local function itemMatchesPlayer(Player, info)
    if not Player or not info then return false end
    local cid = Player.PlayerData.citizenid
    if not info.citizenid or info.citizenid == '' then return true end
    return info.citizenid == cid
end

local function getNearbyPlayerIds(src, radius)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { src } end
    local coords = GetEntityCoords(ped)
    local list = { src }
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local id = tonumber(pid)
        if id and id ~= src then
            local tped = GetPlayerPed(id)
            if tped and tped ~= 0 then
                if #(coords - GetEntityCoords(tped)) <= radius then
                    list[#list + 1] = id
                end
            end
        end
    end
    return list
end

local function broadcastCard(src, payload)
    local targets = getNearbyPlayerIds(src, Config.ShowRadius or 3.0)
    for _, target in ipairs(targets) do
        TriggerClientEvent('mrp_licenses:client:show', target, payload)
    end
end

local function buildIdCard(Player)
    local char = Player.PlayerData.charinfo or {}
    local meta = Player.PlayerData.metadata or {}
    return {
        type = 'id_card',
        title = 'Asmens tapatybės kortelė',
        firstname = char.firstname or '',
        lastname = char.lastname or '',
        birthdate = char.birthdate or '—',
        gender = genderLabel(char.gender),
        nationality = char.nationality or Config.DefaultNationality,
        citizenid = Player.PlayerData.citizenid or '—',
        issued = formatDate(meta.id_issued or meta.idcard_issued) or today(),
        photoInitials = initials(char.firstname, char.lastname),
        holderName = ('%s %s'):format(char.firstname or '', char.lastname or ''),
    }
end

local function buildDrivingCard(Player)
    local char = Player.PlayerData.charinfo or {}
    local licences = Player.PlayerData.metadata.licences or {}
    local categories = {}
    for _, cat in ipairs(Config.DrivingCategories or {}) do
        categories[#categories + 1] = {
            letter = cat.letter,
            label = cat.label,
            active = hasDrivingCategory(licences, cat),
        }
    end
    local any = false
    for _, c in ipairs(categories) do
        if c.active then any = true break end
    end
    local meta = Player.PlayerData.metadata or {}
    return {
        type = 'driving_license',
        title = 'Vairuotojo pažymėjimas',
        firstname = char.firstname or '',
        lastname = char.lastname or '',
        citizenid = Player.PlayerData.citizenid or '—',
        categories = categories,
        validUntil = formatDate(meta.driver_license_expiry) or addYears(Config.LicenseValidityYears),
        issued = formatDate(meta.driver_license_issued) or today(),
        status = any and 'Galiojanti' or 'Negaliojanti',
        photoInitials = initials(char.firstname, char.lastname),
        holderName = ('%s %s'):format(char.firstname or '', char.lastname or ''),
    }
end

local function buildOutdoorsCard(Player, licenseKey)
    local char = Player.PlayerData.charinfo or {}
    local cfg = licenseKey == Config.Items.fishing and Config.Outdoors.fishing or Config.Outdoors.hunting
    local meta = Player.PlayerData.metadata or {}
    local expiryKey = licenseKey == Config.Items.fishing and 'fishing_license_expiry' or 'hunting_license_expiry'
    local issuedKey = licenseKey == Config.Items.fishing and 'fishing_license_issued' or 'hunting_license_issued'
    return {
        type = licenseKey,
        title = cfg.licenseType,
        firstname = char.firstname or '',
        lastname = char.lastname or '',
        citizenid = Player.PlayerData.citizenid or '—',
        licenseType = cfg.licenseType,
        allowed = cfg.allowed,
        validUntil = formatDate(meta[expiryKey]) or addYears(Config.LicenseValidityYears),
        issued = formatDate(meta[issuedKey]) or today(),
        status = 'Galiojanti',
        photoInitials = initials(char.firstname, char.lastname),
        holderName = ('%s %s'):format(char.firstname or '', char.lastname or ''),
    }
end

local function buildWeaponCard(Player)
    local char = Player.PlayerData.charinfo or {}
    local meta = Player.PlayerData.metadata or {}
    local cfg = Config.Weapon or {}
    local licences = meta.licences or {}
    local active = licences.weapon == true
    return {
        type = Config.Items.weapon,
        title = cfg.licenseType or 'Ginklo licencija',
        firstname = char.firstname or '',
        lastname = char.lastname or '',
        citizenid = Player.PlayerData.citizenid or '—',
        licenseType = cfg.licenseType or 'Ginklo licencija',
        allowed = cfg.allowed or 'Legalus ginklo įsigijimas',
        validUntil = formatDate(meta.weapon_license_expiry) or addYears(Config.LicenseValidityYears),
        issued = formatDate(meta.weapon_license_issued) or today(),
        status = active and 'Galiojanti' or 'Negaliojanti',
        photoInitials = initials(char.firstname, char.lastname),
        holderName = ('%s %s'):format(char.firstname or '', char.lastname or ''),
    }
end

local function resolveItemType(itemName)
    if itemName == Config.Items.id then return 'id_card' end
    if itemName == Config.Items.fishing then return Config.Items.fishing end
    if itemName == Config.Items.hunting then return Config.Items.hunting end
    if itemName == Config.Items.weapon then return Config.Items.weapon end
    for _, name in ipairs(Config.Items.driving) do
        if itemName == name then return 'driving_license' end
    end
    return nil
end

local function playerHasItem(Player, itemName)
    local items = Player.Functions.GetItemsByName(itemName)
    if not items then return false end
    for _, it in pairs(items) do
        if itemMatchesPlayer(Player, it.info) then return true, it end
    end
    return false, nil
end

local function buildCardForPlayer(src, cardType, itemInfo)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, 'Žaidėjas nerastas.' end

    if cardType == 'id_card' then
        local ok = playerHasItem(Player, Config.Items.id)
        if not ok then return nil, 'Neturite ID kortelės.' end
        if itemInfo and not itemMatchesPlayer(Player, itemInfo) then
            return nil, 'ID kortelė nepriklauso jums.'
        end
        return buildIdCard(Player)
    end

    if cardType == 'driving_license' then
        local hasItem = false
        for _, name in ipairs(Config.Items.driving) do
            local ok = playerHasItem(Player, name)
            if ok then hasItem = true break end
        end
        if not hasItem then return nil, 'Neturite vairuotojo pažymėjimo.' end
        if itemInfo and itemInfo.citizenid and not itemMatchesPlayer(Player, itemInfo) then
            return nil, 'Pažymėjimas nepriklauso jums.'
        end
        return buildDrivingCard(Player)
    end

    if cardType == Config.Items.fishing or cardType == Config.Items.hunting then
        local ok = playerHasItem(Player, cardType)
        if not ok then return nil, 'Neturite licencijos.' end
        if itemInfo and not itemMatchesPlayer(Player, itemInfo) then
            return nil, 'Licencija nepriklauso jums.'
        end
        return buildOutdoorsCard(Player, cardType)
    end

    if cardType == Config.Items.weapon then
        local ok = playerHasItem(Player, Config.Items.weapon)
        if not ok then return nil, 'Neturite ginklo licencijos.' end
        if itemInfo and not itemMatchesPlayer(Player, itemInfo) then
            return nil, 'Licencija nepriklauso jums.'
        end
        return buildWeaponCard(Player)
    end

    return nil, 'Nežinomas dokumentas.'
end

local function showCard(src, cardType, itemInfo)
    local data, err = buildCardForPlayer(src, cardType, itemInfo)
    if not data then
        TriggerClientEvent('QBCore:Notify', src, err or 'Klaida.', 'error')
        return false
    end
    data.serverName = Config.ServerName
    data.serverSubtitle = Config.ServerSubtitle
    data.viewerMode = 'viewer'
    broadcastCard(src, data)
    return true
end

exports('ShowCard', showCard)

RegisterNetEvent('mrp_licenses:server:showFromItem', function(itemName, itemInfo)
    local src = source
    local cardType = resolveItemType(itemName)
    if not cardType then return end
    showCard(src, cardType, itemInfo)
end)

local function registerUseable(itemName)
    QBCore.Functions.CreateUseableItem(itemName, function(source, item)
        local cardType = resolveItemType(itemName)
        if not cardType then return end
        showCard(source, cardType, item and item.info)
    end)
end

CreateThread(function()
    registerUseable(Config.Items.id)
    registerUseable(Config.Items.fishing)
    registerUseable(Config.Items.hunting)
    registerUseable(Config.Items.weapon)
    for _, name in ipairs(Config.Items.driving) do
        registerUseable(name)
    end
end)

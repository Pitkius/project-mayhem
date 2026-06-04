local QBCore = exports['qb-core']:GetCoreObject()
local hasDonePreloading = {}

local function giveStarterItems(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    for _, v in pairs(QBCore.Shared.StarterItems) do
        local info = {}
        if v.item == 'id_card' then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == 'driver_license' then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = 'Class C Driver License'
        end
        exports['qb-inventory']:AddItem(src, v.item, v.amount, false, info, 'fivempro_charcreator:starter')
    end
end

local function loadHouseData(src)
    if GetResourceState('qb-houses') ~= 'started' then return end
    local ok, result = pcall(function()
        return MySQL.query.await('SELECT * FROM houselocations', {})
    end)
    if not ok or not result then return end
    local HouseGarages, Houses = {}, {}
    for _, v in pairs(result) do
        local garage = v.garage and json.decode(v.garage) or {}
        Houses[v.name] = {
            coords = json.decode(v.coords),
            owned = tonumber(v.owned) == 1,
            price = v.price,
            locked = true,
            adress = v.label,
            tier = v.tier,
            garage = garage,
            decorations = {},
        }
        HouseGarages[v.name] = { label = v.label, takeVehicle = garage }
    end
    TriggerClientEvent('qb-garages:client:houseGarageConfig', src, HouseGarages)
    TriggerClientEvent('qb-houses:client:setHouseConfig', src, Houses)
end

local function finishLoad(src)
    repeat Wait(10) until hasDonePreloading[src]
    if GetResourceState('fivempro_spawnfix') == 'started' then
        exports['fivempro_spawnfix']:SyncQBCoreAdmin(src)
    else
        QBCore.Commands.Refresh(src)
    end
    loadHouseData(src)
    TriggerClientEvent('fivempro_spawnfix:client:spawn', src)
end

local function getMaxChars(license)
    local n = Config.DefaultNumberOfCharacters or 5
    if Config.PlayersNumberOfCharacters then
        for _, v in pairs(Config.PlayersNumberOfCharacters) do
            if v.license == license then
                n = v.numberOfChars
                break
            end
        end
    end
    return n
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    Wait(500)
    hasDonePreloading[Player.PlayerData.source] = true
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    hasDonePreloading[src] = false
end)

RegisterNetEvent('fivempro_charcreator:server:sessionStart', function()
    local src = source
    if QBCore.Players[src] then return end
    TriggerClientEvent('fivempro_charcreator:client:open', src)
end)

QBCore.Functions.CreateCallback('fivempro_charcreator:server:getSession', function(src, cb)
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then return cb({ ok = false }) end

    local rows = MySQL.query.await(
        'SELECT citizenid, charinfo, money, job, position, last_updated FROM players WHERE license = ? ORDER BY last_updated DESC',
        { license }
    ) or {}

    local characters = {}
    for _, row in ipairs(rows) do
        local ch = json.decode(row.charinfo or '{}') or {}
        local money = json.decode(row.money or '{}') or {}
        local job = json.decode(row.job or '{}') or {}
        local skin = MySQL.single.await(
            'SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1',
            { row.citizenid }
        )
        characters[#characters + 1] = {
            citizenid = row.citizenid,
            firstname = ch.firstname or '',
            lastname = ch.lastname or '',
            birthdate = ch.birthdate or '',
            gender = ch.gender or 0,
            nationality = ch.nationality or '',
            job = job.label or job.name or 'Bedarbis',
            cash = (money.cash or 0) + 0,
            bank = (money.bank or 0) + 0,
            lastPlayed = row.last_updated,
            model = skin and skin.model,
            skin = skin and skin.skin,
        }
    end

    cb({
        ok = true,
        maxChars = getMaxChars(license),
        enableDelete = Config.EnableDeleteButton ~= false,
        characters = characters,
        options = {
            nationalities = Config.Nationalities,
            originCities = Config.OriginCities,
            bloodTypes = Config.BloodTypes,
            eyeColors = Config.EyeColors,
            voicePresets = Config.VoicePresets,
        },
    })
end)

RegisterNetEvent('fivempro_charcreator:server:selectCharacter', function(citizenid)
    local src = source
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return end
    if QBCore.Player.Login(src, citizenid) then
        finishLoad(src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Nepavyko užkrauti personažo.', 'error')
    end
end)

RegisterNetEvent('fivempro_charcreator:server:createCharacter', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local license = QBCore.Functions.GetIdentifier(src, 'license')
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license }) or 0
    if count >= getMaxChars(license) then
        return TriggerClientEvent('QBCore:Notify', src, 'Pasiektas personažų limitas.', 'error')
    end

    local personal = payload.personal or {}
    local firstname = tostring(personal.firstname or 'Zaidejas'):gsub('[^%a%s%-]', ''):sub(1, 20)
    local lastname = tostring(personal.lastname or 'Naujas'):gsub('[^%a%s%-]', ''):sub(1, 20)
    if firstname == '' then firstname = 'Zaidejas' end
    if lastname == '' then lastname = 'Naujas' end

    local gender = personal.gender == 1 and 1 or 0
    local cid = (count or 0) + 1

    local newData = {
        cid = cid,
        charinfo = {
            firstname = firstname,
            lastname = lastname,
            birthdate = tostring(personal.birthdate or '01-01-1995'):sub(1, 10),
            gender = gender,
            nationality = tostring(personal.nationality or 'Lietuvos'):sub(1, 32),
            origin_city = tostring(personal.originCity or 'Vilnius'):sub(1, 48),
            blood_type = tostring(personal.bloodType or 'A+'):sub(1, 8),
        },
    }

    if not QBCore.Player.Login(src, false, newData) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko sukurti personažo.', 'error')
    end

    repeat Wait(10) until hasDonePreloading[src]

    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local meta = Player.PlayerData.metadata or {}
        meta.charcreator = {
            voice = tostring(payload.voice or 'male_young'):sub(1, 32),
            body = payload.body or {},
        }
        Player.Functions.SetMetaData('charcreator', meta.charcreator)
    end

    giveStarterItems(src)
    QBCore.Commands.Refresh(src)
    loadHouseData(src)

    TriggerClientEvent('fivempro_charcreator:client:finishCreate', src, {
        model = payload.model,
        skin = payload.skin,
        spawn = Config.DefaultSpawn,
    })
    SetTimeout(1800, function()
        finishLoad(src)
    end)
end)

RegisterNetEvent('fivempro_charcreator:server:deleteCharacter', function(citizenid)
    local src = source
    if not Config.EnableDeleteButton then return end
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return end
    QBCore.Player.DeleteCharacter(src, citizenid)
    TriggerClientEvent('QBCore:Notify', src, 'Personažas ištrintas.', 'success')
    TriggerClientEvent('fivempro_charcreator:client:refreshList', src)
end)

RegisterNetEvent('fivempro_charcreator:server:savePreset', function(name, skin)
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license or type(skin) ~= 'table' then return end
    name = tostring(name or 'Preset'):sub(1, 40)
    MySQL.insert.await(
        'INSERT INTO fivempro_char_presets (license, name, skin) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE skin = VALUES(skin)',
        { license, name, json.encode(skin) }
    )
    TriggerClientEvent('QBCore:Notify', src, 'Išsaugota: ' .. name, 'success')
end)

QBCore.Functions.CreateCallback('fivempro_charcreator:server:getPresets', function(src, cb)
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then return cb({}) end
    local rows = MySQL.query.await(
        'SELECT name, skin FROM fivempro_char_presets WHERE license = ? ORDER BY id DESC LIMIT 12',
        { license }
    ) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { name = r.name, skin = r.skin }
    end
    cb(out)
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_char_presets` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `license` varchar(64) NOT NULL,
        `name` varchar(40) NOT NULL,
        `skin` longtext NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `license_name` (`license`, `name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end)

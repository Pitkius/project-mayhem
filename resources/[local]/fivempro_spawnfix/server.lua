local QBCore = exports['qb-core']:GetCoreObject()
local hasDonePreloading = {}

local function giveStarterItems(source)
    local Player = QBCore.Functions.GetPlayer(source)
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
        exports['qb-inventory']:AddItem(source, v.item, v.amount, false, info, 'fivempro_spawnfix:GiveStarterItems')
    end
end

local function loadHouseData(src)
    if GetResourceState('qb-houses') ~= 'started' then return end
    local HouseGarages = {}
    local Houses = {}
    local ok, result = pcall(function()
        return MySQL.query.await('SELECT * FROM houselocations', {})
    end)
    if not ok or not result then return end
    for _, v in pairs(result) do
        local owned = tonumber(v.owned) == 1
        local garage = v.garage ~= nil and json.decode(v.garage) or {}
        Houses[v.name] = {
            coords = json.decode(v.coords),
            owned = owned,
            price = v.price,
            locked = true,
            adress = v.label,
            tier = v.tier,
            garage = garage,
            decorations = {},
        }
        HouseGarages[v.name] = {
            label = v.label,
            takeVehicle = garage,
        }
    end
    TriggerClientEvent('qb-garages:client:houseGarageConfig', src, HouseGarages)
    TriggerClientEvent('qb-houses:client:setHouseConfig', src, Houses)
end

local function syncVitalsFromPed(Player)
    if not Player or not Player.PlayerData.source then return end
    local src = Player.PlayerData.source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    Player.PlayerData.position = vector4(coords.x, coords.y, coords.z, heading)
    Player.Functions.SetMetaData('armor', GetPedArmour(ped))
    Player.Functions.SetMetaData('health', GetEntityHealth(ped))
end

local function fetchCharacterRow(license)
    return MySQL.single.await(
        'SELECT * FROM players WHERE license = ? ORDER BY last_updated DESC LIMIT 1',
        { license }
    )
end

local function createFirstCharacter(src)
    local newData = {
        cid = 1,
        charinfo = {
            firstname = Config.DefaultFirstName,
            lastname = Config.DefaultLastName,
            birthdate = '01-01-1990',
            gender = Config.DefaultGender,
            nationality = Config.DefaultNationality,
        },
    }
    if not QBCore.Player.Login(src, false, newData) then
        return false
    end
    giveStarterItems(src)
    return true
end

local function loginExisting(src, row)
    return QBCore.Player.Login(src, row.citizenid)
end

local function finishPlayerLoad(src)
    repeat
        Wait(10)
    until hasDonePreloading[src]
    QBCore.Commands.Refresh(src)
    loadHouseData(src)
    TriggerClientEvent('fivempro_spawnfix:client:spawn', src)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    Wait(1000)
    hasDonePreloading[Player.PlayerData.source] = true
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    hasDonePreloading[src] = false
end)

AddEventHandler('QBCore:Server:PlayerDropped', function(Player)
    syncVitalsFromPed(Player)
    if Player.PlayerData.metadata and Player.PlayerData.metadata.inside then
        Player.PlayerData.metadata.inside.house = nil
        Player.PlayerData.metadata.inside.apartment = {
            apartmentType = nil,
            apartmentId = nil,
        }
        Player.Functions.SetMetaData('inside', Player.PlayerData.metadata.inside)
    end
end)

RegisterNetEvent('fivempro_spawnfix:server:requestLogin', function()
    local src = source
    if QBCore.Players[src] then return end

    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then
        DropPlayer(src, 'Nepavyko nustatyti Rockstar licencijos.')
        return
    end

    local row = fetchCharacterRow(license)
    local okLogin

    if row then
        okLogin = loginExisting(src, row)
        if okLogin and row.position then
            local Player = QBCore.Functions.GetPlayer(src)
            local savedPos = json.decode(row.position)
            if Player and savedPos then
                Player.PlayerData.position = savedPos
                MySQL.update.await('UPDATE players SET position = ? WHERE citizenid = ?', { row.position, row.citizenid })
            end
        end
    elseif Config.AutoCreateCharacter then
        okLogin = createFirstCharacter(src)
    else
        DropPlayer(src, 'Nerastas personažas. Susisiekite su administracija.')
        return
    end

    if not okLogin then
        DropPlayer(src, 'Nepavyko užkrauti personažo.')
        return
    end

    finishPlayerLoad(src)
end)

RegisterNetEvent('fivempro_spawnfix:server:syncVitals', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    syncVitalsFromPed(Player)
end)

QBCore.Commands.Add('logout', 'Atsijungti nuo personažo (admin)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        syncVitalsFromPed(Player)
        Player.Functions.Save()
    end
    QBCore.Player.Logout(src)
    TriggerClientEvent('fivempro_spawnfix:client:beginLogin', src)
end, 'admin')

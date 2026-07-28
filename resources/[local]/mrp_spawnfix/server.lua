local QBCore = exports['qb-core']:GetCoreObject()
local hasDonePreloading = {}
local keepCachedPosition = {}

local function stopLegacyCharResources()
    for _, res in ipairs({ 'qb-multicharacter', 'qb-spawn' }) do
        if GetResourceState(res) == 'started' then
            StopResource(res)
            print(('^3[mrp_spawnfix]^0 Sustabdytas %s — naudokite mrp_charcreator'):format(res))
        end
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(1500, stopLegacyCharResources)
end)

CreateThread(function()
    Wait(3000)
    stopLegacyCharResources()
end)

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
        exports['qb-inventory']:AddItem(source, v.item, v.amount, false, info, 'mrp_spawnfix:GiveStarterItems')
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

local function shouldSkipPositionSave(src, ped, metadata)
    if not ped or ped == 0 then return true end

    if src then
        local ply = Player(src)
        if ply and ply.state and ply.state.spawnfixSkipSave then
            return true
        end
    end

    local health = GetEntityHealth(ped)
    if not health or health <= 100 then return true end

    if metadata and (metadata.isdead or metadata.inlaststand) then
        return true
    end

    local vel = GetEntityVelocity(ped)
    if vel then
        if math.abs(vel.z or 0.0) > 6.0 then return true end
        local speed = math.sqrt((vel.x * vel.x) + (vel.y * vel.y) + (vel.z * vel.z))
        if speed > 4.0 then return true end
    end

    return false
end

local function normalizeSavedPosition(pos)
    if type(pos) ~= 'table' then return nil end
    local x = pos.x or pos[1]
    local y = pos.y or pos[2]
    local z = pos.z or pos[3]
    if not x or not y or not z then return nil end
    local w = pos.w or pos.a or pos.h or 0.0
    return vector4(x + 0.0, y + 0.0, z + 0.0, w + 0.0)
end

local function syncVitalsFromPed(Player)
    if not Player or not Player.PlayerData.source then return end
    local src = Player.PlayerData.source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local metadata = Player.PlayerData.metadata or {}
    if not shouldSkipPositionSave(src, ped, metadata) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        Player.PlayerData.position = vector4(coords.x, coords.y, coords.z, heading)
    end

    Player.Functions.SetMetaData('armor', GetPedArmour(ped))
    Player.Functions.SetMetaData('health', GetEntityHealth(ped))

    local savedHealth = tonumber(Player.PlayerData.metadata.health) or 0
    if savedHealth > 100 and (metadata.isdead or metadata.inlaststand) then
        Player.Functions.SetMetaData('isdead', false)
        Player.Functions.SetMetaData('inlaststand', false)
    end
end

local function sanitizeLoginState(Player)
    if not Player then return end
    local m = Player.PlayerData.metadata or {}
    local savedHealth = tonumber(m.health) or 200
    if savedHealth > 100 then
        Player.Functions.SetMetaData('isdead', false)
        Player.Functions.SetMetaData('inlaststand', false)
    end
    local pos = normalizeSavedPosition(Player.PlayerData.position)
    if pos then
        Player.PlayerData.position = pos
    end
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

--- txAdmin (group.admin) arba cfg (identifier → qbcore.god) — QBCore komandoms reikia player.ID → qbcore.*
local function syncQBCoreAdmin(src)
    if not src or src < 1 then return end
    local hasAceAdmin = IsPlayerAceAllowed(src, 'group.admin')
        or IsPlayerAceAllowed(src, 'qbcore.god')
        or IsPlayerAceAllowed(src, 'qbcore.admin')
    if hasAceAdmin and not QBCore.Functions.HasPermission(src, 'god') then
        QBCore.Functions.AddPermission(src, 'god')
    end
    if hasAceAdmin and not IsPlayerAceAllowed(src, 'group.admin') then
        ExecuteCommand(('add_principal player.%s group.admin'):format(src))
    end
    QBCore.Commands.Refresh(src)
end

local function grantPlayerAdmin(src, level)
    level = tostring(level or 'god'):lower()
    if level ~= 'god' and level ~= 'admin' and level ~= 'mod' then
        level = 'god'
    end
    if level == 'god' then
        ExecuteCommand(('add_principal player.%s qbcore.god'):format(src))
        ExecuteCommand(('add_principal player.%s group.admin'):format(src))
    else
        ExecuteCommand(('add_principal player.%s qbcore.%s'):format(src, level))
    end
    QBCore.Functions.AddPermission(src, level)
    QBCore.Commands.Refresh(src)
end

local function finishPlayerLoad(src)
    repeat
        Wait(10)
    until hasDonePreloading[src]
    syncQBCoreAdmin(src)
    loadHouseData(src)
    TriggerClientEvent('mrp_spawnfix:client:spawn', src)
end

exports('SyncQBCoreAdmin', syncQBCoreAdmin)
exports('SanitizeLoginState', sanitizeLoginState)

--- QBCore.Player.Save kviečiamas iškart po PlayerDropped — naudoti paskutinę saugią poziciją, ne ore esančią.
exports('KeepCachedPositionOnSave', function(src)
    if keepCachedPosition[src] then
        keepCachedPosition[src] = nil
        return true
    end
    return false
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    Wait(1000)
    hasDonePreloading[src] = true
    SetTimeout(2500, function()
        if QBCore.Players[src] then
            syncQBCoreAdmin(src)
        end
    end)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    hasDonePreloading[src] = false
    keepCachedPosition[src] = nil
    local ply = Player(src)
    if ply and ply.state then
        ply.state:set('spawnfixSkipSave', false, true)
    end
end)

AddEventHandler('QBCore:Server:PlayerDropped', function(Player)
    local src = Player.PlayerData.source
    local ped = GetPlayerPed(src)
    local metadata = Player.PlayerData.metadata or {}
    if shouldSkipPositionSave(src, ped, metadata) then
        keepCachedPosition[src] = true
    end

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

RegisterNetEvent('mrp_spawnfix:server:requestLogin', function()
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
        if okLogin then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                if row.position then
                    local savedPos = json.decode(row.position)
                    if savedPos then
                        Player.PlayerData.position = savedPos
                    end
                end
                sanitizeLoginState(Player)
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

RegisterNetEvent('mrp_spawnfix:server:syncVitals', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    syncVitalsFromPed(Player)
end)

QBCore.Commands.Add('fixadmin', 'Sinchronizuoti admin teises -> QBCore (F8)', {}, false, function(source)
    syncQBCoreAdmin(source)
    local hasGod = QBCore.Functions.HasPermission(source, 'god')
    local hasAdmin = QBCore.Functions.HasPermission(source, 'admin')
    local lic = QBCore.Functions.GetIdentifier(source, 'license') or 'n/a'
    local msg = hasGod and 'God teisės aktyvios.' or (hasAdmin and 'Admin teisės aktyvios.' or ('Admin teisių nėra — patikrink txAdmin arba cfg license: %s'):format(lic))
    TriggerClientEvent('QBCore:Notify', source, msg, (hasGod or hasAdmin) and 'success' or 'error')
end)

QBCore.Commands.Add('grantadmin', 'Duoti žaidėjui god/admin (online ID)', {
    { name = 'id', help = 'Server ID (skaičius šalia vardo)' },
    { name = 'lygis', help = 'god / admin / mod (default: god)' },
}, true, function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        return TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /grantadmin [server_id] [god]', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(targetId)
    if not Player then
        return TriggerClientEvent('QBCore:Notify', source, 'Žaidėjas neprisijungęs.', 'error')
    end
    local level = args[2] or 'god'
    grantPlayerAdmin(Player.PlayerData.source, level)
    TriggerClientEvent('QBCore:Notify', source, ('Duotos %s teisės ID %s'):format(level, targetId), 'success')
    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, ('Gautos %s teisės. Jei komandos neveikia — /fixadmin'):format(level), 'success')
end, 'god')

QBCore.Commands.Add('logout', 'Atsijungti nuo personažo (admin)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        syncVitalsFromPed(Player)
        Player.Functions.Save()
    end
    QBCore.Player.Logout(src)
    TriggerClientEvent('mrp_spawnfix:client:beginLogin', src)
end, 'admin')

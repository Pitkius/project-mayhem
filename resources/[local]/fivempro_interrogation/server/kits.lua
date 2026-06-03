local QBCore = exports['qb-core']:GetCoreObject()

Kits = Kits or { byId = {} }

local function ensureKitTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_interrogation_kits` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `x` double NOT NULL,
        `y` double NOT NULL,
        `z` double NOT NULL,
        `heading` float NOT NULL DEFAULT 0,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function rowToKit(r)
    return {
        id = tonumber(r.id),
        citizenid = r.citizenid,
        x = r.x + 0.0,
        y = r.y + 0.0,
        z = r.z + 0.0,
        heading = r.heading + 0.0,
    }
end

function Kits.loadAll()
    ensureKitTable()
    Kits.byId = {}
    local rows = MySQL.query.await('SELECT id, citizenid, x, y, z, heading FROM fivempro_interrogation_kits') or {}
    for _, r in ipairs(rows) do
        local k = rowToKit(r)
        Kits.byId[k.id] = k
    end
end

function Kits.list()
    local out = {}
    for _, k in pairs(Kits.byId) do
        out[#out + 1] = k
    end
    return out
end

function Kits.get(id)
    return Kits.byId[tonumber(id)]
end

function Kits.syncAll(target)
    TriggerClientEvent('fivempro_interrogation:client:syncKits', target or -1, Kits.list())
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local function canPickup(src, kit)
    if not kit then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if isAdmin(src) then return true end
    return P.PlayerData.citizenid == kit.citizenid
end

RegisterNetEvent('fivempro_interrogation:server:placeKit', function(x, y, z, heading)
    local src = source
    local cfg = Config.GangKit or {}
    local item = cfg.item or 'gang_interrog_kit'
    if not canLeadCriminal(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės naudoti gaujų įrangos.', 'error')
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if not P.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi įrangos.', 'error')
    end
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not x or not y or not z then return end

    if not P.Functions.RemoveItem(item, 1) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti itemo.', 'error')
    end

    local id = MySQL.insert.await(
        'INSERT INTO fivempro_interrogation_kits (citizenid, x, y, z, heading) VALUES (?, ?, ?, ?, ?)',
        { P.PlayerData.citizenid, x, y, z, heading or 0.0 }
    )
    local kit = {
        id = id,
        citizenid = P.PlayerData.citizenid,
        x = x, y = y, z = z,
        heading = heading or 0.0,
    }
    Kits.byId[id] = kit
    Kits.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Įranga padėta. Galima surinkti vėliau.', 'success')
    if adminLog then
        adminLog(src, 'kit_place', ('Kit #%s'):format(id), kit)
    end
end)

RegisterNetEvent('fivempro_interrogation:server:pickupKit', function(kitId)
    local src = source
    kitId = tonumber(kitId)
    local kit = Kits.get(kitId)
    if not kit then
        return TriggerClientEvent('QBCore:Notify', src, 'Įranga nerasta.', 'error')
    end
    if not canPickup(src, kit) then
        return TriggerClientEvent('QBCore:Notify', src, 'Gali surinkti tik savo įrangą arba admin.', 'error')
    end
    if sessionOnKit and sessionOnKit(kitId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vyksta sesija – negalima surinkti.', 'error')
    end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        if #(c - vector3(kit.x, kit.y, kit.z)) > ((Config.GangKit and Config.GangKit.pickupDist) or 2.8) + 1.2 then
            return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
        end
    end

    MySQL.query.await('DELETE FROM fivempro_interrogation_kits WHERE id = ?', { kitId })
    Kits.byId[kitId] = nil
    local P = QBCore.Functions.GetPlayer(src)
    if P then
        P.Functions.AddItem((Config.GangKit and Config.GangKit.item) or 'gang_interrog_kit', 1)
    end
    Kits.syncAll()
    TriggerClientEvent('QBCore:Notify', src, 'Įranga surinkta.', 'success')
    if adminLog then
        adminLog(src, 'kit_pickup', ('Kit #%s'):format(kitId), {})
    end
end)

CreateThread(function()
    Wait(500)
    Kits.loadAll()
    Kits.syncAll()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Kits.loadAll()
    Kits.syncAll()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then Kits.syncAll(src) end
end)

CreateThread(function()
    Wait(800)
    local cfg = Config.GangKit or {}
    local item = cfg.item or 'gang_interrog_kit'
    QBCore.Functions.CreateUseableItem(item, function(source)
        TriggerClientEvent('fivempro_interrogation:client:startPlaceKit', source)
    end)
end)

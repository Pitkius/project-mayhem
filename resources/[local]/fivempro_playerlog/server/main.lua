local QBCore = exports['qb-core']:GetCoreObject()

--- @type table<number, number> serverId -> unix time
local setInventoryLogAt = {}

local function safeTruncate(str, maxLen)
    if not str or type(str) ~= 'string' then return '' end
    maxLen = tonumber(maxLen) or 60000
    if #str <= maxLen then return str end
    return str:sub(1, maxLen) .. '…[truncated]'
end

local function extractServerIdFromMessage(msg)
    if type(msg) ~= 'string' then return nil end
    local sid = msg:match('|%s*id:%s*(%d+)') or msg:match('|%s*ID:%s*(%d+)') or msg:match('id:%s*(%d+)')
    return tonumber(sid)
end

local function extractCitizenidFromMessage(msg)
    if type(msg) ~= 'string' then return nil end
    return msg:match('citizenid:%s*([%w]+)')
end

--- FiveM `GetPlayerName` – rodomas vardas (dažnai kaip Steam profilio vardas serveryje).
local function playerRowFromSource(src)
    if not src or src == 0 then
        return {}
    end
    local displayName = GetPlayerName(src)
    if not displayName or displayName == '' then
        return {}
    end
    local steam = GetPlayerIdentifierByType(src, 'steam')
    local license = GetPlayerIdentifierByType(src, 'license')
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local citizenid, fn, ln = nil, nil, nil
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData then
        citizenid = Player.PlayerData.citizenid
        local ch = Player.PlayerData.charinfo
        if type(ch) == 'table' then
            fn = ch.firstname or ch.firstName
            ln = ch.lastname or ch.lastName
        end
    end
    return {
        display_name = displayName,
        steam_hex = steam,
        license = license,
        discord = discord,
        citizenid = citizenid,
        char_firstname = fn,
        char_lastname = ln,
        server_id = src,
    }
end

--- Įterpia vieną eilutę į `fivempro_player_logs`.
---@param row table display_name, steam_hex, license, discord, citizenid, char_firstname, char_lastname, server_id, category, action, color, message, meta (table|string), invoking_resource
function InsertPlayerActivityLog(row)
    if not row or not row.category or not row.action then return end
    local metaJson = nil
    if row.meta then
        if type(row.meta) == 'table' then
            metaJson = json.encode(row.meta)
        elseif type(row.meta) == 'string' then
            metaJson = row.meta
        end
    end
    local maxLen = Config.MaxMessageLength or 60000
    MySQL.insert(
        [[INSERT INTO fivempro_player_logs (
            display_name, steam_hex, license, discord, citizenid, char_firstname, char_lastname, server_id,
            category, action, color, message, meta, invoking_resource
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            row.display_name,
            row.steam_hex,
            row.license,
            row.discord,
            row.citizenid,
            row.char_firstname,
            row.char_lastname,
            row.server_id,
            row.category,
            row.action,
            row.color,
            safeTruncate(row.message or '', maxLen),
            metaJson,
            row.invoking_resource,
        }
    )
end

exports('InsertPlayerActivityLog', InsertPlayerActivityLog)

local function logFromSource(src, category, action, message, meta, color)
    if not src or src == 0 then return end
    local base = playerRowFromSource(src)
    base.category = category
    base.action = action
    base.message = message or ''
    base.meta = meta
    base.color = color
    base.invoking_resource = GetInvokingResource()
    if (not base.display_name or base.display_name == '') and type(message) == 'string' then
        base.display_name = message:match('%*%*([^%*]+)%*%*')
    end
    InsertPlayerActivityLog(base)
end

exports('LogPlayer', logFromSource)

local function ensureTable()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `fivempro_player_logs` (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        `display_name` varchar(128) DEFAULT NULL,
        `steam_hex` varchar(72) DEFAULT NULL,
        `license` varchar(72) DEFAULT NULL,
        `discord` varchar(72) DEFAULT NULL,
        `citizenid` varchar(50) DEFAULT NULL,
        `char_firstname` varchar(64) DEFAULT NULL,
        `char_lastname` varchar(64) DEFAULT NULL,
        `server_id` int(11) DEFAULT NULL,
        `category` varchar(64) NOT NULL,
        `action` varchar(128) NOT NULL,
        `color` varchar(32) DEFAULT NULL,
        `message` mediumtext,
        `meta` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
        `invoking_resource` varchar(64) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_created` (`created_at`),
        KEY `idx_citizenid` (`citizenid`),
        KEY `idx_steam` (`steam_hex`),
        KEY `idx_license` (`license`),
        KEY `idx_category_action` (`category`, `action`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;]])
end

MySQL.ready(function()
    ensureTable()
end)

if Config.HookQbLog then
    AddEventHandler('qb-log:server:CreateLog', function(name, title, color, message, tagEveryone, imageUrl)
        local msg = message or ''
        local cd = Config.SetInventoryLogCooldownSeconds or 0
        if cd > 0 and name == 'playerinventory' then
            local t = title or ''
            if t == 'SetInventory' or t == 'Inventory Set' then
                local sidEarly = extractServerIdFromMessage(msg)
                if sidEarly then
                    local now = os.time()
                    local last = setInventoryLogAt[sidEarly]
                    if last and (now - last) < cd then
                        return
                    end
                    setInventoryLogAt[sidEarly] = now
                end
            end
        end

        local sid = extractServerIdFromMessage(msg)
        local row = {}
        if sid and GetPlayerName(sid) and GetPlayerName(sid) ~= '' then
            row = playerRowFromSource(sid)
        end
        if not row.citizenid then
            row.citizenid = extractCitizenidFromMessage(msg)
        end
        if (not row.display_name or row.display_name == '') and msg ~= '' then
            row.display_name = msg:match('%*%*([^%*]+)%*%*')
        end
        row.server_id = sid or row.server_id

        row.category = name or 'qb-log'
        row.action = title or 'entry'
        row.color = color
        row.message = msg
        row.meta = {
            tagEveryone = tagEveryone and true or nil,
            imageUrl = (imageUrl and imageUrl ~= '') and imageUrl or nil,
        }
        row.invoking_resource = GetInvokingResource()
        InsertPlayerActivityLog(row)
    end)
end

if Config.HookPlayerConnecting then
    AddEventHandler('playerConnecting', function(playerName, _setKickReason, _deferrals)
        local src = source
        if not src or src == 0 then return end
        local ids = {}
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            ids[#ids + 1] = id
        end
        InsertPlayerActivityLog({
            display_name = playerName,
            steam_hex = GetPlayerIdentifierByType(src, 'steam'),
            license = GetPlayerIdentifierByType(src, 'license'),
            discord = GetPlayerIdentifierByType(src, 'discord'),
            citizenid = nil,
            char_firstname = nil,
            char_lastname = nil,
            server_id = src,
            category = 'joinleave',
            action = 'playerConnecting',
            color = 'white',
            message = ('Prisijungimas: %s'):format(playerName or '?'),
            meta = { identifiers = ids },
            invoking_resource = GetInvokingResource(),
        })
    end)
end

if Config.HookPlayerLoaded then
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        if not Player or not Player.PlayerData then return end
        local src = Player.PlayerData.source
        local pd = Player.PlayerData
        local ch = pd.charinfo or {}
        InsertPlayerActivityLog({
            display_name = GetPlayerName(src),
            steam_hex = GetPlayerIdentifierByType(src, 'steam'),
            license = pd.license,
            discord = GetPlayerIdentifierByType(src, 'discord'),
            citizenid = pd.citizenid,
            char_firstname = ch.firstname or ch.firstName,
            char_lastname = ch.lastname or ch.lastName,
            server_id = src,
            category = 'joinleave',
            action = 'characterLoaded',
            color = 'lightgreen',
            message = ('Personažas įkeltas: %s %s (%s)'):format(
                tostring(ch.firstname or ch.firstName or ''),
                tostring(ch.lastname or ch.lastName or ''),
                tostring(pd.citizenid or '')
            ),
            meta = { job = pd.job, gang = pd.gang },
            invoking_resource = GetInvokingResource(),
        })
    end)
end

if Config.HookPlayerDropped then
    AddEventHandler('QBCore:Server:PlayerDropped', function(Player)
        if not Player or not Player.PlayerData then return end
        local pd = Player.PlayerData
        local src = pd.source
        local ch = pd.charinfo or {}
        InsertPlayerActivityLog({
            display_name = GetPlayerName(src),
            steam_hex = GetPlayerIdentifierByType(src, 'steam'),
            license = pd.license,
            discord = GetPlayerIdentifierByType(src, 'discord'),
            citizenid = pd.citizenid,
            char_firstname = ch.firstname or ch.firstName,
            char_lastname = ch.lastname or ch.lastName,
            server_id = src,
            category = 'joinleave',
            action = 'characterUnload',
            color = 'red',
            message = ('Personažas išsijungė / išsaugota: %s'):format(tostring(pd.citizenid or '')),
            meta = nil,
            invoking_resource = GetInvokingResource(),
        })
    end)
end

if Config.HookJobUpdate then
    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
        if not src or not job then return end
        logFromSource(src, 'job', 'jobUpdate', json.encode(job), { job = job }, 'blue')
    end)
end

if Config.HookGangUpdate then
    AddEventHandler('QBCore:Server:OnGangUpdate', function(src, gang)
        if not src or not gang then return end
        logFromSource(src, 'gang', 'gangUpdate', json.encode(gang), { gang = gang }, 'blue')
    end)
end

if Config.HookVehicleBaseEvents then
    RegisterNetEvent('baseevents:enteredVehicle', function(veh, seat, modelName)
        local src = source
        logFromSource(src, 'vehicle', 'enteredVehicle', ('model=%s seat=%s'):format(tostring(modelName), tostring(seat)), { veh = veh, seat = seat, modelName = modelName }, 'default')
    end)
    RegisterNetEvent('baseevents:leftVehicle', function(veh, seat, modelName)
        local src = source
        logFromSource(src, 'vehicle', 'leftVehicle', ('model=%s seat=%s'):format(tostring(modelName), tostring(seat)), { veh = veh, seat = seat, modelName = modelName }, 'default')
    end)
end

--[[
  mrp_jobs — cooldownų valdymas (serveris, autoritetingas).
  In-memory cache + neprivaloma DB persistencija (Config.PersistCooldowns).
  Rišama prie citizenid arba license (Config.AccountWideCooldowns).
]]

local QBCore = exports['qb-core']:GetCoreObject()

Cooldowns = Cooldowns or {}

-- cache[ownerId][cdKey] = expiresAtUnix
local cache = {}

-- Grąžina "owner" raktą pagal config (citizenid arba license).
local function ownerKey(Player)
    if not Player then return nil end
    if Config.AccountWideCooldowns then
        local lic = Player.PlayerData.license or Player.PlayerData.license2
        return lic or Player.PlayerData.citizenid
    end
    return Player.PlayerData.citizenid
end

-- Užkrauna žaidėjo cooldownus iš DB į cache.
local function loadOwner(ownerId)
    if not ownerId then return end
    cache[ownerId] = cache[ownerId] or {}
    if not Config.PersistCooldowns then return end
    local rows = MySQL.query.await('SELECT cd_key, expires_at FROM fivempro_job_cooldowns WHERE owner_id = ?', { ownerId })
    if rows then
        local now = os.time()
        for _, r in ipairs(rows) do
            if tonumber(r.expires_at) > now then
                cache[ownerId][r.cd_key] = tonumber(r.expires_at)
            else
                MySQL.query('DELETE FROM fivempro_job_cooldowns WHERE owner_id = ? AND cd_key = ?', { ownerId, r.cd_key })
            end
        end
    end
end

-- Likęs cooldown laikas sekundėmis (0 = neaktyvus). Priima src arba citizenid/ownerId.
function Cooldowns.remaining(ownerRef, cdKey)
    local ownerId = ownerRef
    if type(ownerRef) == 'number' then
        local P = QBCore.Functions.GetPlayer(ownerRef)
        ownerId = ownerKey(P)
    end
    if not ownerId or not cdKey then return 0 end
    local exp = cache[ownerId] and cache[ownerId][cdKey]
    if not exp then return 0 end
    local left = exp - os.time()
    return left > 0 and left or 0
end

-- Nustato cooldown (sekundėmis nuo dabar). ownerRef: src arba ownerId.
function Cooldowns.set(ownerRef, cdKey, seconds)
    local ownerId = ownerRef
    if type(ownerRef) == 'number' then
        local P = QBCore.Functions.GetPlayer(ownerRef)
        ownerId = ownerKey(P)
    end
    if not ownerId or not cdKey or (seconds or 0) <= 0 then return end
    local expires = os.time() + math.floor(seconds)
    cache[ownerId] = cache[ownerId] or {}
    cache[ownerId][cdKey] = expires
    if Config.PersistCooldowns then
        MySQL.query('INSERT INTO fivempro_job_cooldowns (owner_id, cd_key, expires_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)', {
            ownerId, cdKey, expires,
        })
    end
end

-- Panaikina cooldown (pvz. nutraukus darbą viduryje — cooldown netaikomas).
function Cooldowns.clear(ownerRef, cdKey)
    local ownerId = ownerRef
    if type(ownerRef) == 'number' then
        local P = QBCore.Functions.GetPlayer(ownerRef)
        ownerId = ownerKey(P)
    end
    if not ownerId or not cdKey then return end
    if cache[ownerId] then cache[ownerId][cdKey] = nil end
    if Config.PersistCooldowns then
        MySQL.query('DELETE FROM fivempro_job_cooldowns WHERE owner_id = ? AND cd_key = ?', { ownerId, cdKey })
    end
end

-- Užkraunam cooldownus žaidėjui prisijungus.
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local ownerId = ownerKey(Player)
    if ownerId then loadOwner(ownerId) end
end)

exports('GetCooldown', function(src, cdKey)
    return Cooldowns.remaining(src, cdKey)
end)

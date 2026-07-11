--[[
  mrp_jobs — serverio saugumo pagalbininkai.
  Rate limit, atstumo/vietos patikros, žaidėjo gavimas. Visa jautri logika
  turi eiti per šias funkcijas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Security = Security or {}

-- [src][action] = paskutinio veiksmo GetGameTimer() ms
local lastAction = {}

-- Grąžina QBCore žaidėją arba nil.
function Security.getPlayer(src)
    if not src or src <= 0 then return nil end
    return QBCore.Functions.GetPlayer(src)
end

-- Rate limit: true = LEIDŽIAMA, false = per dažnai.
function Security.rateLimit(src, action, minIntervalMs)
    minIntervalMs = minIntervalMs or (Config.RateLimit and Config.RateLimit.default) or 600
    local now = GetGameTimer()
    lastAction[src] = lastAction[src] or {}
    local last = lastAction[src][action] or 0
    if now - last < minIntervalMs then
        return false
    end
    lastAction[src][action] = now
    return true
end

-- Serverinis atstumo patikrinimas (klientas negali meluoti dėl vietos).
-- coords: vector3/vector4. Grąžina true jei žaidėjas pakankamai arti.
function Security.isNear(src, coords, maxDist)
    maxDist = maxDist or (Config.MaxInteractDistance or 4.5)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pc = GetEntityCoords(ped)
    local tx, ty, tz = coords.x, coords.y, coords.z
    if not tx then return false end
    local dx, dy, dz = pc.x - tx, pc.y - ty, pc.z - tz
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    return dist <= maxDist, dist
end

-- Ar žaidėjas gyvas (kad negalėtų vykdyti darbo miręs).
function Security.isAlive(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return not IsEntityDead(ped) and not IsPedFatallyInjured(ped)
end

-- Valymas atsijungus.
AddEventHandler('playerDropped', function()
    local src = source
    lastAction[src] = nil
end)

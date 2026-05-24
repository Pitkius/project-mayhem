local QBCore = exports['qb-core']:GetCoreObject()

local Busy = {}
local PlayerCd = {}
local LocationCd = {}

local function locKey(tierId, locId)
    return tierId .. ':' .. locId
end

local function findLocation(tierId, locId)
    local list = Config.Robberies and Config.Robberies.Locations and Config.Robberies.Locations[tierId]
    if not list then return nil end
    for _, loc in ipairs(list) do
        if loc.id == locId then return loc end
    end
    return nil
end

local function onCooldown(src, tierId, locId)
    local now = os.time()
    local pCd = (Config.Robberies.PlayerCooldown or {})[tierId] or 900
    local lCd = (Config.Robberies.LocationCooldown or {})[tierId] or 1800
    if PlayerCd[src] and PlayerCd[src][tierId] and now < PlayerCd[src][tierId] then
        return true, 'Palauk prieš kitą apiplėšimą.'
    end
    local key = locKey(tierId, locId)
    if LocationCd[key] and now < LocationCd[key] then
        return true, 'Ši vieta neseniai apiplėšta.'
    end
    return false
end

local function setCooldown(src, tierId, locId)
    local now = os.time()
    PlayerCd[src] = PlayerCd[src] or {}
    PlayerCd[src][tierId] = now + ((Config.Robberies.PlayerCooldown or {})[tierId] or 900)
    LocationCd[locKey(tierId, locId)] = now + ((Config.Robberies.LocationCooldown or {})[tierId] or 1800)
end

local function giveLoot(src, tierId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local loot = (Config.Robberies.Loot or {})[tierId]
    if not loot then return end

    if loot.cash then
        local amount = math.random(loot.cash.min or 100, loot.cash.max or 500)
        Player.Functions.AddMoney('cash', amount, 'robbery-' .. tierId)
    end
    if loot.markedbills then
        local count = math.random(loot.markedbills.min or 0, loot.markedbills.max or 1)
        local worth = loot.markedbills.worth or 400
        for _ = 1, count do
            Player.Functions.AddItem('markedbills', 1, false, { worth = worth })
        end
    end
    if loot.casinochips then
        local chips = math.random(loot.casinochips.min or 5, loot.casinochips.max or 20)
        Player.Functions.AddItem('casinochips', chips)
    end
    if loot.goldbar and math.random() < (loot.goldbar.chance or 0.2) then
        local n = math.random(loot.goldbar.min or 1, loot.goldbar.max or 1)
        for _ = 1, n do
            Player.Functions.AddItem('goldbar', 1)
        end
    end
end

local function consumeNeed(Player, tierId, phase)
    local needs = (Config.Robberies.ItemNeeds or {})[tierId] or {}
    if phase == 'card' and needs.card then
        if not Player.Functions.GetItemByName(needs.card) then return false, 'Reikia prieigos kortelės.' end
        Player.Functions.RemoveItem(needs.card, 1)
        return true
    end
    if phase == 'thermite' and needs.thermite then
        if not Player.Functions.GetItemByName(needs.thermite) then return false, 'Reikia termito.' end
        Player.Functions.RemoveItem(needs.thermite, 1)
        return true
    end
    if phase == 'drill' and needs.drill then
        if not Player.Functions.GetItemByName(needs.drill) then return false, 'Reikia gręžtuvo (drill).' end
        Player.Functions.RemoveItem(needs.drill, 1)
        return true
    end
    return true
end

local function dispatchAlert(src, tierId, loc)
    if GetResourceState('fivempro_dispatch') ~= 'started' then return end
    local ped = GetPlayerPed(src)
    local c = loc and loc.coords or GetEntityCoords(ped)
    local labels = {
        store = '24/7 kasos apiplėšimas',
        bank_fleeca = 'Fleeca banko apiplėšimas',
        bank_main = 'Pacific banko apiplėšimas',
        casino = 'Kazino sistemos įsilaužimas',
        vault = 'Federal vault apiplėšimas',
    }
    exports['fivempro_dispatch']:CreateDispatchCall('police', 'robbery', c, labels[tierId] or 'Apiplėšimas', src)
end

QBCore.Functions.CreateCallback('fivempro_hacking:server:robberyCanStart', function(src, cb, tierId, locId)
    local loc = findLocation(tierId, locId)
    if not loc then return cb({ ok = false, msg = 'Vieta nerasta.' }) end
    local cd, cdMsg = onCooldown(src, tierId, locId)
    if cd then return cb({ ok = false, msg = cdMsg }) end
    local ok, msg = exports['fivempro_hacking']:CanAccessRobbery(src, tierId)
    if not ok then return cb({ ok = false, msg = msg }) end
    local key = locKey(tierId, locId)
    if Busy[key] and Busy[key] ~= src then
        return cb({ ok = false, msg = 'Kažkas jau apiplėšinėja šią vietą.' })
    end
    cb({ ok = true, flow = (Config.Robberies.Flow or {})[tierId] or {} })
end)

RegisterNetEvent('fivempro_hacking:server:robberyClaim', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    Busy[key] = src
end)

RegisterNetEvent('fivempro_hacking:server:robberyRelease', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    if Busy[key] == src then Busy[key] = nil end
end)

RegisterNetEvent('fivempro_hacking:server:robberyPhaseDone', function(tierId, locId, phase)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = locKey(tierId, locId)
    if Busy[key] ~= src then return end

    local flow = (Config.Robberies.Flow or {})[tierId] or {}
    local okItem, itemMsg = consumeNeed(Player, tierId, phase)
    if not okItem then
        TriggerClientEvent('QBCore:Notify', src, itemMsg, 'error')
        TriggerClientEvent('fivempro_hacking:client:robberyAbort', src)
        return
    end

    if phase == 'loot' then
        giveLoot(src, tierId)
        setCooldown(src, tierId, locId)
        Busy[key] = nil
        local loc = findLocation(tierId, locId)
        dispatchAlert(src, tierId, loc)
        TriggerClientEvent('QBCore:Notify', src, 'Apiplėšimas sėkmingas.', 'success')
        TriggerClientEvent('fivempro_hacking:client:robberyFinished', src)
        if GetResourceState('fivempro_gangs') == 'started' then
            pcall(function()
                local c = loc and loc.coords or GetEntityCoords(GetPlayerPed(src))
                exports['fivempro_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
            end)
        end
        return
    end

    TriggerClientEvent('fivempro_hacking:client:robberyNextPhase', src, tierId, locId, phase)
end)

RegisterNetEvent('fivempro_hacking:server:robberyFailed', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    if Busy[key] == src then Busy[key] = nil end
    local loc = findLocation(tierId, locId)
    dispatchAlert(src, tierId, loc)
    if GetResourceState('fivempro_gangs') == 'started' then
        pcall(function()
            local c = loc and loc.coords or GetEntityCoords(GetPlayerPed(src))
            exports['fivempro_gangs']:OnHackFailed(src, tierId, { x = c.x, y = c.y, z = c.z })
        end)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(Busy) do
        if v == src then Busy[k] = nil end
    end
end)

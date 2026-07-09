local QBCore = exports['qb-core']:GetCoreObject()

local Busy = {}
local PlayerCd = {}
local LocationCd = {}
local CasinoLootStep = {}

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

local function scaleAmount(minV, maxV, step, total)
    local base = math.random(minV or 0, maxV or 0)
    if total <= 1 then return base end
    local slice = math.max(1, math.floor(base / total))
    if step == total then
        return math.max(slice, base - slice * (total - 1))
    end
    return slice
end

local function giveLootSlice(src, tierId, step, total, finalSlice)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local loot = (Config.Robberies.Loot or {})[tierId]
    if not loot then return end

    if loot.cash then
        local amount = scaleAmount(loot.cash.min, loot.cash.max, step, total)
        Player.Functions.AddMoney('cash', amount, 'robbery-' .. tierId)
    end
    if loot.markedbills then
        local count = scaleAmount(loot.markedbills.min, loot.markedbills.max, step, total)
        local worth = loot.markedbills.worth or 400
        if count > 0 then
            Player.Functions.AddItem('markedbills', count, false, { worth = worth })
        end
    end
    if loot.casinochips then
        local chips = scaleAmount(loot.casinochips.min, loot.casinochips.max, step, total)
        if chips > 0 then
            Player.Functions.AddItem('casinochips', chips)
        end
    end
    if finalSlice and loot.goldbar and math.random() < (loot.goldbar.chance or 0.2) then
        local n = math.random(loot.goldbar.min or 1, loot.goldbar.max or 1)
        for _ = 1, n do
            Player.Functions.AddItem('goldbar', 1)
        end
    end
end

local function giveLoot(src, tierId)
    giveLootSlice(src, tierId, 1, 1, true)
end

local function clearCasinoLoot(src)
    CasinoLootStep[src] = nil
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
    if GetResourceState('mrp_dispatch') ~= 'started' then return end
    local ped = GetPlayerPed(src)
    local c = loc and loc.coords or GetEntityCoords(ped)
    local labels = {
        store = '24/7 kasos apiplėšimas',
        bank_fleeca = 'Fleeca banko apiplėšimas',
        bank_main = 'Pacific banko apiplėšimas',
        casino = 'Diamond Casino Heist',
        vault = 'Federal vault apiplėšimas',
    }
    exports['mrp_dispatch']:CreateDispatchCall('police', 'robbery', c, labels[tierId] or 'Apiplėšimas', src)
end

QBCore.Functions.CreateCallback('mrp_hacking:server:robberyCanStart', function(src, cb, tierId, locId)
    local loc = findLocation(tierId, locId)
    if not loc then return cb({ ok = false, msg = 'Vieta nerasta.' }) end
    local cd, cdMsg = onCooldown(src, tierId, locId)
    if cd then return cb({ ok = false, msg = cdMsg }) end
    local ok, msg = exports['mrp_hacking']:CanAccessRobbery(src, tierId)
    if not ok then return cb({ ok = false, msg = msg }) end
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and not exports['mrp_hacking']:IsRobberyLocDiscovered(src, tierId, locId) then
        return cb({ ok = false, msg = 'Pirmiau nuskanuok šią vietą planšete (būk parduotuvėje su atidaryta planšete).' })
    end
    local key = locKey(tierId, locId)
    if Busy[key] and Busy[key] ~= src then
        return cb({ ok = false, msg = 'Kažkas jau apiplėšinėja šią vietą.' })
    end
    cb({ ok = true, flow = (Config.Robberies.Flow or {})[tierId] or {} })
end)

local function hasRobberyItems(Player, tierId)
    local needs = (Config.Robberies.ItemNeeds or {})[tierId] or {}
    for _, itemName in pairs(needs) do
        if type(itemName) == 'string' and itemName ~= '' then
            if not Player.Functions.GetItemByName(itemName) then
                return false
            end
        end
    end
    return true
end

QBCore.Functions.CreateCallback('mrp_hacking:server:robberyCanInteract', function(src, cb, tierId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local ok = exports['mrp_hacking']:CanAccessRobbery(src, tierId)
    if not ok then return cb(false) end
    cb(hasRobberyItems(Player, tierId))
end)

RegisterNetEvent('mrp_hacking:server:robberyClaim', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    Busy[key] = src
end)

RegisterNetEvent('mrp_hacking:server:robberyRelease', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    if Busy[key] == src then Busy[key] = nil end
    clearCasinoLoot(src)
end)

RegisterNetEvent('mrp_hacking:server:robberyPhaseDone', function(tierId, locId, phase)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = locKey(tierId, locId)
    if Busy[key] ~= src then return end

    local flow = (Config.Robberies.Flow or {})[tierId] or {}
    local okItem, itemMsg = consumeNeed(Player, tierId, phase)
    if not okItem then
        TriggerClientEvent('QBCore:Notify', src, itemMsg, 'error')
        TriggerClientEvent('mrp_hacking:client:robberyAbort', src)
        return
    end

    if tierId == 'casino' and phase == 'thermite' then
        local loc = findLocation(tierId, locId)
        dispatchAlert(src, tierId, loc)
    end

    if phase == 'loot' then
        local loc = findLocation(tierId, locId)
        local casinoSteps = (Config.Robberies.CasinoHeist and Config.Robberies.CasinoHeist.lootSteps) or 1

        if tierId == 'casino' and casinoSteps > 1 then
            local step = (CasinoLootStep[src] or 0) + 1
            CasinoLootStep[src] = step
            giveLootSlice(src, tierId, step, casinoSteps, step >= casinoSteps)
            TriggerClientEvent('QBCore:Notify', src,
                ('Vežimėlis %d/%d — grobis paimtas.'):format(step, casinoSteps), 'success')

            if step < casinoSteps then
                TriggerClientEvent('mrp_hacking:client:robberyNextPhase', src, tierId, locId, phase)
                return
            end

            clearCasinoLoot(src)
            setCooldown(src, tierId, locId)
            Busy[key] = nil
            dispatchAlert(src, tierId, loc)
            TriggerClientEvent('QBCore:Notify', src, 'Diamond Casino Heist baigtas sėkmingai.', 'success')
            TriggerClientEvent('mrp_hacking:client:robberyFinished', src)
            if GetResourceState('mrp_gangs') == 'started' then
                pcall(function()
                    local c = loc and loc.coords or GetEntityCoords(GetPlayerPed(src))
                    exports['mrp_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
                end)
            end
            return
        end

        giveLoot(src, tierId)
        clearCasinoLoot(src)
        setCooldown(src, tierId, locId)
        Busy[key] = nil
        dispatchAlert(src, tierId, loc)
        TriggerClientEvent('QBCore:Notify', src, 'Apiplėšimas sėkmingas.', 'success')
        TriggerClientEvent('mrp_hacking:client:robberyFinished', src)
        if GetResourceState('mrp_gangs') == 'started' then
            pcall(function()
                local c = loc and loc.coords or GetEntityCoords(GetPlayerPed(src))
                exports['mrp_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
            end)
        end
        return
    end

    TriggerClientEvent('mrp_hacking:client:robberyNextPhase', src, tierId, locId, phase)
end)

RegisterNetEvent('mrp_hacking:server:robberyFailed', function(tierId, locId)
    local src = source
    local key = locKey(tierId, locId)
    if Busy[key] == src then Busy[key] = nil end
    clearCasinoLoot(src)
    local loc = findLocation(tierId, locId)
    dispatchAlert(src, tierId, loc)
    if GetResourceState('mrp_gangs') == 'started' then
        pcall(function()
            local c = loc and loc.coords or GetEntityCoords(GetPlayerPed(src))
            exports['mrp_gangs']:OnHackFailed(src, tierId, { x = c.x, y = c.y, z = c.z })
        end)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(Busy) do
        if v == src then Busy[k] = nil end
    end
    clearCasinoLoot(src)
end)

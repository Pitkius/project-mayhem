local QBCore = exports['qb-core']:GetCoreObject()

local Opened = {} --- [src] = { [boxKey] = true }
local VaultOpen = {} --- [src] = { [locId] = true }

local function boxKey(locId, index)
    return ('%s:%d'):format(tostring(locId), tonumber(index) or 0)
end

RegisterNetEvent('mrp_hacking:server:markVaultOpen', function(locId)
    local src = source
    VaultOpen[src] = VaultOpen[src] or {}
    VaultOpen[src][tostring(locId)] = true
end)

exports('MarkVaultOpenFor', function(src, locId)
    src = tonumber(src)
    if not src or not locId then return end
    VaultOpen[src] = VaultOpen[src] or {}
    VaultOpen[src][tostring(locId)] = true
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:depositCanDrill', function(src, cb, locId, index)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    if not (VaultOpen[src] and VaultOpen[src][tostring(locId)]) then
        return cb({ ok = false, msg = 'Pirmiau atrakink seifą (L2/L3 hack).' })
    end
    local key = boxKey(locId, index)
    Opened[src] = Opened[src] or {}
    if Opened[src][key] then
        return cb({ ok = false, msg = 'Ši dėžutė jau atidaryta.' })
    end
    local item = Config.SmallDrillItem or 'small_drill'
    if not Player.Functions.GetItemByName(item) then
        return cb({ ok = false, msg = 'Reikia mažo grąžto (small_drill).' })
    end
    cb({ ok = true })
end)

RegisterNetEvent('mrp_hacking:server:depositDrilled', function(locId, index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not (VaultOpen[src] and VaultOpen[src][tostring(locId)]) then return end
    local key = boxKey(locId, index)
    Opened[src] = Opened[src] or {}
    if Opened[src][key] then return end

    local item = Config.SmallDrillItem or 'small_drill'
    if not Player.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia mažo grąžto.', 'error')
    end
    Player.Functions.RemoveItem(item, 1)
    Opened[src][key] = true

    local loot = (Config.Robberies.Loot or {}).deposit_box or {}
    if loot.cash then
        local amount = math.random(loot.cash.min or 500, loot.cash.max or 1500)
        Player.Functions.AddMoney('cash', amount, 'deposit-box')
        TriggerClientEvent('QBCore:Notify', src, ('Deposit dėžutė: $%s'):format(amount), 'success')
    end
    if loot.markedbills then
        local count = math.random(loot.markedbills.min or 0, loot.markedbills.max or 1)
        local worth = loot.markedbills.worth or 400
        local dirty = count * worth
        if dirty > 0 then
            Player.Functions.AddItem('markedbills', dirty, false, {})
        end
    end
    if loot.goldbar and math.random() < (loot.goldbar.chance or 0.05) then
        Player.Functions.AddItem('goldbar', 1)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Opened[src] = nil
    VaultOpen[src] = nil
end)

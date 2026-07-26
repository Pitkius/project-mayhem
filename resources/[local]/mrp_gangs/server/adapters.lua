local QBCore = GangCore.QBCore

GangAdapters = GangAdapters or {}

GangAdapters.Player = {}
GangAdapters.Inventory = {}
GangAdapters.Money = {}
GangAdapters.Dispatch = {}
GangAdapters.Drugs = {}

function GangAdapters.Player.Get(source)
    return QBCore.Functions.GetPlayer(tonumber(source))
end

function GangAdapters.Player.GetByCitizenId(citizenid)
    return QBCore.Functions.GetPlayerByCitizenId(tostring(citizenid or ''))
end

function GangAdapters.Inventory.Has(source, itemName, amount)
    local player = GangAdapters.Player.Get(source)
    if not player then return false end
    local item = player.Functions.GetItemByName(tostring(itemName or ''))
    return item ~= nil and (tonumber(item.amount) or 0) >= math.max(1, tonumber(amount) or 1)
end

function GangAdapters.Inventory.Remove(source, itemName, amount, reason)
    local player = GangAdapters.Player.Get(source)
    if not player or not GangAdapters.Inventory.Has(source, itemName, amount) then return false end
    return player.Functions.RemoveItem(
        tostring(itemName),
        math.max(1, tonumber(amount) or 1),
        false,
        reason or 'gang-system'
    ) == true
end

function GangAdapters.Inventory.Add(source, itemName, amount, info, reason)
    local player = GangAdapters.Player.Get(source)
    if not player or not QBCore.Shared.Items[tostring(itemName or '')] then return false end
    return player.Functions.AddItem(
        tostring(itemName),
        math.max(1, tonumber(amount) or 1),
        false,
        info,
        reason or 'gang-system'
    ) == true
end

function GangAdapters.Money.Remove(source, account, amount, reason)
    local player = GangAdapters.Player.Get(source)
    amount = math.max(0, GangUtils.Round(amount))
    if not player or amount <= 0 then return false end
    local balance = tonumber(player.PlayerData.money[tostring(account)]) or 0
    if balance < amount then return false end
    return player.Functions.RemoveMoney(tostring(account), amount, reason or 'gang-system') == true
end

function GangAdapters.Money.Add(source, account, amount, reason)
    local player = GangAdapters.Player.Get(source)
    amount = math.max(0, GangUtils.Round(amount))
    if not player or amount <= 0 then return false end
    player.Functions.AddMoney(tostring(account), amount, reason or 'gang-system')
    return true
end

function GangAdapters.Dispatch.Create(call)
    if GetResourceState('mrp_dispatch') ~= 'started' then return false end
    local ok = pcall(function()
        exports['mrp_dispatch']:CreateCall(call)
    end)
    return ok
end

function GangAdapters.Drugs.CanSell(source, itemName, coords)
    if not GangTerritories or not GangTerritories.CanSellDrug then
        return false, 'territory_system_unavailable'
    end
    return GangTerritories.CanSellDrug(source, itemName, coords)
end

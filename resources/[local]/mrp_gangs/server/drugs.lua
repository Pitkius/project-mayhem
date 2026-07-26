local QBCore = GangCore.QBCore

QBCore.Functions.CreateCallback('mrp_gangs:server:canSellDrug', function(source, callback, itemName)
    if not GangCore.RateLimit(source, 'drug_territory_check', 1) then
        return callback({ ok = false, reason = 'rate_limited' })
    end
    local ok, result = GangTerritories.CanSellDrug(source, tostring(itemName or ''), nil)
    callback({ ok = ok, result = ok and result or nil, reason = ok and nil or result })
end)

exports('ValidateDrugSale', function(source, itemName)
    return GangTerritories.CanSellDrug(tonumber(source), tostring(itemName or ''), nil)
end)

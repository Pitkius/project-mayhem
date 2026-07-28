

RegisterNetEvent('tackle:server:TacklePlayer', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = Player.PlayerData.job
    if not job or job.name ~= 'police' or not job.onduty then return end

    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then return end

    local srcPed = GetPlayerPed(src)
    local tgtPed = GetPlayerPed(targetId)
    if srcPed == 0 or tgtPed == 0 then return end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed))
    if dist > 3.0 then return end

    TriggerClientEvent('tackle:client:GetTackled', targetId)
end)

QBCore.Commands.Add('id', 'Check Your ID #', {}, false, function(source)
    TriggerClientEvent('QBCore:Notify', source, 'ID: ' .. source)
end)

QBCore.Functions.CreateUseableItem('harness', function(source, item)
    TriggerClientEvent('seatbelt:client:UseHarness', source, item)
end)

RegisterNetEvent('equip:harness', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Player.PlayerData.items[item.slot].info.uses then
        Player.PlayerData.items[item.slot].info.uses = Config.HarnessUses - 1
        Player.Functions.SetInventory(Player.PlayerData.items)
    elseif Player.PlayerData.items[item.slot].info.uses == 1 then
        exports['qb-inventory']:RemoveItem(src, 'harness', 1, false, 'equip:harness')
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['harness'], 'remove')
    else
        Player.PlayerData.items[item.slot].info.uses -= 1
        Player.Functions.SetInventory(Player.PlayerData.items)
    end
end)

RegisterNetEvent('seatbelt:DoHarnessDamage', function(hp, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if hp == 0 then
        exports['qb-inventory']:RemoveItem(src, 'harness', 1, data.slot, 'seatbelt:DoHarnessDamage')
    else
        Player.PlayerData.items[data.slot].info.uses -= 1
        Player.Functions.SetInventory(Player.PlayerData.items)
    end
end)

RegisterNetEvent('qb-carwash:server:washCar', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    if Player.Functions.RemoveMoney('cash', Config.CarWash.defaultPrice, 'car-washed') then
        TriggerClientEvent('qb-carwash:client:washCar', src)
    elseif Player.Functions.RemoveMoney('bank', Config.CarWash.defaultPrice, 'car-washed') then
        TriggerClientEvent('qb-carwash:client:washCar', src)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.dont_have_enough_money'), 'error')
    end
end)

QBCore.Functions.CreateCallback('smallresources:server:GetCurrentPlayers', function(_, cb)
    cb(#GetPlayers())
end)

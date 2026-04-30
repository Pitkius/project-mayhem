local QBCore = exports['qb-core']:GetCoreObject()

print("^2[fivempro_basics]^7 Resource paleistas sekmingai.")

AddEventHandler('playerJoining', function(playerName)
    local src = source
    print(("[fivempro_basics] Prisijunge zaidejas: %s (ID: %s)"):format(playerName, src))
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 200, 120 },
        multiline = true,
        args = { "SERVER", ("Sveikas atvykes, %s!"):format(playerName) }
    })
end)

QBCore.Commands.Add('register', 'Atidaryti veikejo kurimo langa (admin)', {}, false, function(source)
    TriggerClientEvent('fivempro_basics:client:openRegister', source)
end, 'admin')

local function setNeedsFull(player)
    player.Functions.SetMetaData('hunger', 100)
    player.Functions.SetMetaData('thirst', 100)
    TriggerClientEvent('hud:client:UpdateNeeds', player.PlayerData.source, 100, 100)
end

local function resolveTarget(source, argValue)
    if argValue then
        local targetId = tonumber(argValue)
        if not targetId then return nil end
        return QBCore.Functions.GetPlayer(targetId)
    end

    return QBCore.Functions.GetPlayer(source)
end

QBCore.Commands.Add('revive', 'Admin revive su max maistu/vandeniu', {
    { name = 'id', help = 'Server ID (optional)' }
}, false, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Zaidejas nerastas', 'error')
        return
    end

    target.Functions.SetMetaData('isdead', false)
    target.Functions.SetMetaData('inlaststand', false)
    setNeedsFull(target)
    TriggerClientEvent('fivempro_basics:client:adminRevive', target.PlayerData.source)
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, 'Admin revive + needs atnaujinti', 'success')
end, 'admin')

QBCore.Commands.Add('heal', 'Admin heal su max maistu/vandeniu', {
    { name = 'id', help = 'Server ID (optional)' }
}, false, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Zaidejas nerastas', 'error')
        return
    end

    setNeedsFull(target)
    TriggerClientEvent('fivempro_basics:client:adminHeal', target.PlayerData.source)
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, 'Admin heal + needs atnaujinti', 'success')
end, 'admin')

QBCore.Commands.Add('coords', 'Parodyti zaidejo koordinates (admin)', {
    { name = 'id', help = 'Server ID (optional)' }
}, false, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Zaidejas nerastas', 'error')
        return
    end

    TriggerClientEvent('fivempro_basics:client:showCoords', source, target.PlayerData.source)
end, 'admin')

QBCore.Functions.CreateUseableItem('sandwich', function(source, item)
    if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'fivempro_basics:sandwich') then return end
    TriggerClientEvent('fivempro_basics:client:useSandwich', source, item.name)
end)

QBCore.Functions.CreateUseableItem('water_bottle', function(source, item)
    if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'fivempro_basics:water_bottle') then return end
    TriggerClientEvent('fivempro_basics:client:useWaterBottle', source, item.name)
end)


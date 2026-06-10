local QBCore = exports['qb-core']:GetCoreObject()

print("^2[fivempro_basics]^7 Resource paleistas sekmingai.")

local function playerDisplayName(src, Player)
    if Player and Player.PlayerData and Player.PlayerData.charinfo then
        local c = Player.PlayerData.charinfo
        local full = ('%s %s'):format(c.firstname or '', c.lastname or '')
        full = full:gsub('^%s+', ''):gsub('%s+$', '')
        if full ~= '' then return full end
    end
    return GetPlayerName(src) or ('Žaidėjas %s'):format(src)
end

AddEventHandler('playerJoining', function()
    local src = source
    print(('[fivempro_basics] Prisijungia žaidėjas (ID: %s)'):format(src))
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    local src = Player.PlayerData.source
    local name = playerDisplayName(src, Player)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 200, 120 },
        multiline = true,
        args = { 'SERVER', ('Sveikas atvykęs, %s!'):format(name) },
    })
end)

QBCore.Commands.Add('register', 'Personažo kūrimas / redagavimas (admin)', {}, false, function(source)
    if GetResourceState('fivempro_charcreator') ~= 'started' then
        TriggerClientEvent('QBCore:Notify', source, 'fivempro_charcreator nėra paleistas.', 'error')
        return
    end
    TriggerClientEvent('fivempro_charcreator:client:openWizard', source, true)
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

local function isFemale(player)
    local ch = player and player.PlayerData and player.PlayerData.charinfo
    return ch and ch.gender == 1
end

local function healNotifyText(player)
    if isFemale(player) then
        return 'Jūs buvote sėkmingai pagydyta.'
    end
    return 'Jūs buvote sėkmingai pagydytas.'
end

local function reviveNotifyText(player)
    if isFemale(player) then
        return 'Jūs buvote sėkmingai atgaivinta.'
    end
    return 'Jūs buvote sėkmingai atgaivintas.'
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
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, reviveNotifyText(target), 'success')
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
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, healNotifyText(target), 'success')
end, 'admin')

QBCore.Commands.Add('coords', 'Ijungti/isjungti savo koordinates ekrano virsuje (admin)', {}, false, function(source)
    TriggerClientEvent('fivempro_basics:client:toggleCoords', source)
end, 'admin')

QBCore.Commands.Add('addmoney', 'Admin: prideti pinigu sau (cash/bank)', {
    { name = 'type', help = 'cash arba bank' },
    { name = 'amount', help = 'suma' }
}, true, function(source, args)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local moneyType = tostring(args[1] or ''):lower()
    local amount = tonumber(args[2]) or 0
    if (moneyType ~= 'cash' and moneyType ~= 'bank') or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /addmoney cash 1000 arba /addmoney bank 1000', 'error')
        return
    end

    player.Functions.AddMoney(moneyType, amount, 'fivempro-basics-admin-addmoney')
    TriggerClientEvent('QBCore:Notify', source, ('Prideta $%s i %s'):format(amount, moneyType), 'success')
end, 'admin')


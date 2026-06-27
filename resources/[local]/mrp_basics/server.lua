local QBCore = exports['qb-core']:GetCoreObject()

print("^2[mrp_basics]^7 Resource paleistas sekmingai.")

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
    print(('[mrp_basics] Prisijungia žaidėjas (ID: %s)'):format(src))
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
    if GetResourceState('mrp_charcreator') ~= 'started' then
        TriggerClientEvent('QBCore:Notify', source, 'mrp_charcreator nėra paleistas.', 'error')
        return
    end
    TriggerClientEvent('mrp_charcreator:client:openWizard', source, true)
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
    TriggerClientEvent('mrp_basics:client:adminRevive', target.PlayerData.source)
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, reviveNotifyText(target), 'success')
    if GetResourceState('server_logs') == 'started' then
        pcall(function()
            exports['server_logs']:LogAdminAction(source, 'revive', ('Atgaivintas **%s**'):format(GetPlayerName(target.PlayerData.source) or target.PlayerData.source), {
                { name = 'Žaidėjas', value = ('%s [%s]'):format(GetPlayerName(target.PlayerData.source) or '?', target.PlayerData.source), inline = true },
            })
        end)
    end
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
    TriggerClientEvent('mrp_basics:client:adminHeal', target.PlayerData.source)
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, healNotifyText(target), 'success')
    if GetResourceState('server_logs') == 'started' then
        pcall(function()
            exports['server_logs']:LogAdminAction(source, 'heal', ('Pagydytas **%s**'):format(GetPlayerName(target.PlayerData.source) or target.PlayerData.source), {
                { name = 'Žaidėjas', value = ('%s [%s]'):format(GetPlayerName(target.PlayerData.source) or '?', target.PlayerData.source), inline = true },
            })
        end)
    end
end, 'admin')

local function logAdminTeleport(adminSrc, command, targetId, coords)
    if GetResourceState('server_logs') ~= 'started' then return end
    pcall(function()
        local targetName = GetPlayerName(targetId) or ('ID %s'):format(targetId)
        local coordText = coords and ('%.1f, %.1f, %.1f'):format(coords.x, coords.y, coords.z) or '?'
        exports['server_logs']:LogAdminAction(adminSrc, command, ('**%s** [%s]'):format(targetName, targetId), {
            { name = 'Žaidėjas', value = ('%s [%s]'):format(targetName, targetId), inline = true },
            { name = 'Koordinatės', value = coordText, inline = false },
        })
    end)
end

QBCore.Commands.Add('goto', 'Admin: nueiti pas žaidėją', {
    { name = 'id', help = 'Server ID' },
}, true, function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /goto [id]', 'error')
        return
    end

    if targetId == source then
        TriggerClientEvent('QBCore:Notify', source, 'Negalite nueiti pas save.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Žaidėjas nerastas.', 'error')
        return
    end

    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('QBCore:Command:TeleportToPlayer', source, coords)
    TriggerClientEvent('QBCore:Notify', source, ('Nueita pas %s [%s]'):format(GetPlayerName(targetId) or '?', targetId), 'success')
    logAdminTeleport(source, 'goto', targetId, coords)
end, 'admin')

QBCore.Commands.Add('bring', 'Admin: atvesti žaidėją pas save', {
    { name = 'id', help = 'Server ID' },
}, true, function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /bring [id]', 'error')
        return
    end

    if targetId == source then
        TriggerClientEvent('QBCore:Notify', source, 'Negalite atvesti savęs.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Žaidėjas nerastas.', 'error')
        return
    end

    local adminPed = GetPlayerPed(source)
    if not adminPed or adminPed == 0 then return end

    local coords = GetEntityCoords(adminPed)
    local heading = GetEntityHeading(adminPed)
    TriggerClientEvent('QBCore:Command:TeleportToCoords', targetId, coords.x, coords.y, coords.z, heading)
    TriggerClientEvent('QBCore:Notify', source, ('Atvestas %s [%s]'):format(GetPlayerName(targetId) or '?', targetId), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Administratorius jus perkėlė.', 'primary')
    logAdminTeleport(source, 'bring', targetId, coords)
end, 'admin')

QBCore.Commands.Add('coords', 'Ijungti/isjungti savo koordinates ekrano virsuje (admin)', {}, false, function(source)
    TriggerClientEvent('mrp_basics:client:toggleCoords', source)
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

QBCore.Commands.Add('s', 'Sukti — matoma chate ir virš galvos', {
    { name = 'žinutė', help = 'Tekstas kurį nori sukti' },
}, false, function(source, args)
    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /s tekstas', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local name = playerDisplayName(source, Player)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pCoords = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    if msg == '' then
        TriggerClientEvent('QBCore:Notify', source, 'Tuščia žinutė.', 'error')
        return
    end

    local range = 35.0
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed and targetPed ~= 0 then
            local tCoords = GetEntityCoords(targetPed)
            if targetPed == ped or #(pCoords - tCoords) <= range then
                TriggerClientEvent('mrp_basics:client:showShout', playerId, source, name, msg)
            end
        end
    end
end, 'user')

local function broadcastHeadText(source, eventName, args, range)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pCoords = GetEntityCoords(ped)
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed and targetPed ~= 0 then
            local tCoords = GetEntityCoords(targetPed)
            if targetPed == ped or #(pCoords - tCoords) <= range then
                TriggerClientEvent(eventName, playerId, table.unpack(args))
            end
        end
    end
end

local function sendTadText(source, args)
    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Naudojimas: /tad tekstas', 'error')
        return
    end

    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    if msg == '' then
        TriggerClientEvent('QBCore:Notify', source, 'Tuščias tekstas.', 'error')
        return
    end

    broadcastHeadText(source, 'mrp_basics:client:showTad', { source, msg }, 20.0)
end

QBCore.Commands.Add('tad', 'Aplinkos aprašymas virš galvos (kaip /do)', {
    { name = 'tekstas', help = 'Kas vyksta aplinkoje' },
}, false, function(source, args)
    sendTadText(source, args)
end, 'user')

QBCore.Commands.Add('do', 'Alias /tad — aplinkos aprašymas virš galvos', {
    { name = 'tekstas', help = 'Kas vyksta aplinkoje' },
}, false, function(source, args)
    sendTadText(source, args)
end, 'user')

local staffTags = {}

local function getStaffTagInfo(src)
    if QBCore.Functions.HasPermission(src, 'god') then
        return 'Savininkas', { 220, 50, 50 }
    elseif QBCore.Functions.HasPermission(src, 'admin') then
        return 'Adminas', { 255, 140, 0 }
    elseif QBCore.Functions.HasPermission(src, 'mod') then
        return 'Moderatorius', { 70, 160, 255 }
    end
end

local function syncStaffTags(target)
    TriggerClientEvent('mrp_basics:client:syncStaffTags', target or -1, staffTags)
end

QBCore.Commands.Add('tag', 'Staff žymė virš galvos (įjungti/išjungti)', {}, false, function(source)
    local label, color = getStaffTagInfo(source)
    if not label then
        TriggerClientEvent('QBCore:Notify', source, 'Neturi staff teisių.', 'error')
        return
    end

    if staffTags[source] then
        staffTags[source] = nil
        TriggerClientEvent('QBCore:Notify', source, 'Staff žymė išjungta.', 'primary')
    else
        staffTags[source] = { label = label, color = color }
        TriggerClientEvent('QBCore:Notify', source, ('Staff žymė įjungta: %s'):format(label), 'success')
    end
    syncStaffTags()
end, 'mod')

AddEventHandler('playerDropped', function()
    local src = source
    if staffTags[src] then
        staffTags[src] = nil
        syncStaffTags()
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    syncStaffTags(Player.PlayerData.source)
end)

local LOCKPICK_SUCCESS_CHANCE = { lockpick = 68, advancedlockpick = 88 }
local LOCKPICK_BREAK_CHANCE = { lockpick = 45, advancedlockpick = 20 }

RegisterNetEvent('mrp_basics:server:vehicleLockpick', function(netId, plate, vehicleLabel, advanced)
    local src = source
    netId = tonumber(netId) or 0
    if netId <= 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemName = advanced and 'advancedlockpick' or 'lockpick'
    if not Player.Functions.GetItemByName(itemName) then
        TriggerClientEvent('QBCore:Notify', src, 'Neturi visrakčio.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)

    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        TriggerClientEvent('QBCore:Notify', src, 'Transportas nerastas.', 'error')
        return
    end

    if #(coords - GetEntityCoords(ent)) > 6.0 then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo transporto.', 'error')
        return
    end

    plate = tostring(plate or GetVehicleNumberPlateText(ent) or '???'):upper():gsub('%s+', '')
    vehicleLabel = tostring(vehicleLabel or 'Transportas')

    local chance = LOCKPICK_SUCCESS_CHANCE[itemName] or 60
    local success = math.random(1, 100) <= chance

    if success then
        TriggerClientEvent('mrp_basics:client:vehicleLockpickResult', src, {
            success = true,
            netId = netId,
            msg = 'Spyna sėkmingai atrakinta.',
        })
        return
    end

    if math.random(1, 100) <= (LOCKPICK_BREAK_CHANCE[itemName] or 40) then
        Player.Functions.RemoveItem(itemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove', 1)
    end

    local alertText = ('Signalizacija: %s, numeriai %s'):format(vehicleLabel, plate)
    if GetResourceState('mrp_dispatch') == 'started' then
        exports['mrp_dispatch']:CreateDispatchCall('police', 'vehicle_alarm', coords, alertText, src)
    end

    TriggerClientEvent('mrp_basics:client:vehicleLockpickResult', src, {
        success = false,
        netId = netId,
        msg = 'Nepavyko atrakinti — signalizacija!',
    })
end)


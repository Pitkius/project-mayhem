local QBCore = exports['qb-core']:GetCoreObject()

print("^2[mrp_basics]^7 Resource paleistas sekmingai.")

local function isValidPlayerSource(src)
    return type(src) == 'number' and src > 0
end

local function playerSource(player)
    if not player or not player.PlayerData then return nil end
    local src = tonumber(player.PlayerData.source)
    if not isValidPlayerSource(src) then return nil end
    return src
end

local function notifyPlayer(src, msg, ntype)
    if not isValidPlayerSource(src) then
        print(('[mrp_basics] %s'):format(msg))
        return
    end
    TriggerClientEvent('QBCore:Notify', src, msg, ntype or 'primary')
end

local function triggerClient(src, event, ...)
    if not isValidPlayerSource(src) then return false end
    TriggerClientEvent(event, src, ...)
    return true
end

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
    local src = playerSource(Player)
    if not src then return end
    local name = playerDisplayName(src, Player)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 0, 200, 120 },
        multiline = true,
        args = { 'SERVER', ('Sveikas atvykęs, %s!'):format(name) },
    })
end)

QBCore.Commands.Add('register', 'Personažo kūrimas / redagavimas (admin)', {}, false, function(source)
    if not isValidPlayerSource(source) then return end
    if GetResourceState('mrp_charcreator') ~= 'started' then
        notifyPlayer(source, 'mrp_charcreator nėra paleistas.', 'error')
        return
    end
    triggerClient(source, 'mrp_charcreator:client:openWizard', true)
end, 'admin')

local function setNeedsFull(player)
    local src = playerSource(player)
    if not src then return end
    player.Functions.SetMetaData('hunger', 100)
    player.Functions.SetMetaData('thirst', 100)
    TriggerClientEvent('hud:client:UpdateNeeds', src, 100, 100)
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
        notifyPlayer(source, 'Zaidejas nerastas', 'error')
        return
    end

    local targetSrc = playerSource(target)
    if not targetSrc then return end

    target.Functions.SetMetaData('isdead', false)
    target.Functions.SetMetaData('inlaststand', false)
    setNeedsFull(target)
    triggerClient(targetSrc, 'mrp_basics:client:adminRevive')
    notifyPlayer(targetSrc, reviveNotifyText(target), 'success')
    if GetResourceState('server_logs') == 'started' then
        pcall(function()
            exports['server_logs']:LogAdminAction(source, 'revive', ('Atgaivintas **%s**'):format(GetPlayerName(targetSrc) or targetSrc), {
                { name = 'Žaidėjas', value = ('%s [%s]'):format(GetPlayerName(targetSrc) or '?', targetSrc), inline = true },
            })
        end)
    end
end, 'admin')

QBCore.Commands.Add('heal', 'Admin heal su max maistu/vandeniu', {
    { name = 'id', help = 'Server ID (optional)' }
}, false, function(source, args)
    local target = resolveTarget(source, args[1])
    if not target then
        notifyPlayer(source, 'Zaidejas nerastas', 'error')
        return
    end

    local targetSrc = playerSource(target)
    if not targetSrc then return end

    setNeedsFull(target)
    triggerClient(targetSrc, 'mrp_basics:client:adminHeal')
    notifyPlayer(targetSrc, healNotifyText(target), 'success')
    if GetResourceState('server_logs') == 'started' then
        pcall(function()
            exports['server_logs']:LogAdminAction(source, 'heal', ('Pagydytas **%s**'):format(GetPlayerName(targetSrc) or targetSrc), {
                { name = 'Žaidėjas', value = ('%s [%s]'):format(GetPlayerName(targetSrc) or '?', targetSrc), inline = true },
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
        notifyPlayer(source, 'Naudojimas: /goto [id]', 'error')
        return
    end

    if isValidPlayerSource(source) and targetId == source then
        notifyPlayer(source, 'Negalite nueiti pas save.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        notifyPlayer(source, 'Žaidėjas nerastas.', 'error')
        return
    end

    local coords = GetEntityCoords(targetPed)
    if not triggerClient(source, 'QBCore:Command:TeleportToPlayer', coords) then return end
    notifyPlayer(source, ('Nueita pas %s [%s]'):format(GetPlayerName(targetId) or '?', targetId), 'success')
    logAdminTeleport(source, 'goto', targetId, coords)
end, 'admin')

QBCore.Commands.Add('bring', 'Admin: atvesti žaidėją pas save', {
    { name = 'id', help = 'Server ID' },
}, true, function(source, args)
    local targetId = tonumber(args[1])
    if not targetId then
        notifyPlayer(source, 'Naudojimas: /bring [id]', 'error')
        return
    end

    if isValidPlayerSource(source) and targetId == source then
        notifyPlayer(source, 'Negalite atvesti savęs.', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        notifyPlayer(source, 'Žaidėjas nerastas.', 'error')
        return
    end

    if not isValidPlayerSource(source) then
        notifyPlayer(source, 'Bring reikia vykdyti žaidime, ne konsolėje.', 'error')
        return
    end

    local adminPed = GetPlayerPed(source)
    if not adminPed or adminPed == 0 then return end

    local coords = GetEntityCoords(adminPed)
    local heading = GetEntityHeading(adminPed)
    triggerClient(targetId, 'QBCore:Command:TeleportToCoords', coords.x, coords.y, coords.z, heading)
    notifyPlayer(source, ('Atvestas %s [%s]'):format(GetPlayerName(targetId) or '?', targetId), 'success')
    notifyPlayer(targetId, 'Administratorius jus perkėlė.', 'primary')
    logAdminTeleport(source, 'bring', targetId, coords)
end, 'admin')

QBCore.Commands.Add('coords', 'Ijungti/isjungti savo koordinates ekrano virsuje (admin)', {}, false, function(source)
    triggerClient(source, 'mrp_basics:client:toggleCoords')
end, 'admin')

QBCore.Commands.Add('addmoney', 'Admin: prideti pinigu sau (cash/bank)', {
    { name = 'type', help = 'cash arba bank' },
    { name = 'amount', help = 'suma' }
}, true, function(source, args)
    if not isValidPlayerSource(source) then return end
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local moneyType = tostring(args[1] or ''):lower()
    local amount = tonumber(args[2]) or 0
    if (moneyType ~= 'cash' and moneyType ~= 'bank') or amount <= 0 then
        notifyPlayer(source, 'Naudojimas: /addmoney cash 1000 arba /addmoney bank 1000', 'error')
        return
    end

    player.Functions.AddMoney(moneyType, amount, 'fivempro-basics-admin-addmoney')
    notifyPlayer(source, ('Prideta $%s i %s'):format(amount, moneyType), 'success')
end, 'admin')

QBCore.Commands.Add('s', 'Sukti — matoma chate ir virš galvos', {
    { name = 'žinutė', help = 'Tekstas kurį nori sukti' },
}, false, function(source, args)
    if not isValidPlayerSource(source) then return end
    if #args < 1 then
        notifyPlayer(source, 'Naudojimas: /s tekstas', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local name = playerDisplayName(source, Player)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pCoords = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    if msg == '' then
        notifyPlayer(source, 'Tuščia žinutė.', 'error')
        return
    end

    local range = 35.0
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed and targetPed ~= 0 then
            local tCoords = GetEntityCoords(targetPed)
            if targetPed == ped or #(pCoords - tCoords) <= range then
                triggerClient(playerId, 'mrp_basics:client:showShout', source, name, msg)
            end
        end
    end
end, 'user')

local function broadcastHeadText(source, eventName, args, range)
    if not isValidPlayerSource(source) then return end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local pCoords = GetEntityCoords(ped)
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed and targetPed ~= 0 then
            local tCoords = GetEntityCoords(targetPed)
            if targetPed == ped or #(pCoords - tCoords) <= range then
                triggerClient(playerId, eventName, table.unpack(args))
            end
        end
    end
end

local function sendTadText(source, args)
    if not isValidPlayerSource(source) then return end
    if #args < 1 then
        notifyPlayer(source, 'Naudojimas: /tad tekstas', 'error')
        return
    end

    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    if msg == '' then
        notifyPlayer(source, 'Tuščias tekstas.', 'error')
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
    if isValidPlayerSource(target) then
        triggerClient(target, 'mrp_basics:client:syncStaffTags', staffTags)
        return
    end
    TriggerClientEvent('mrp_basics:client:syncStaffTags', -1, staffTags)
end

QBCore.Commands.Add('tag', 'Staff žymė virš galvos (įjungti/išjungti)', {}, false, function(source)
    if not isValidPlayerSource(source) then return end
    local label, color = getStaffTagInfo(source)
    if not label then
        notifyPlayer(source, 'Neturi staff teisių.', 'error')
        return
    end

    if staffTags[source] then
        staffTags[source] = nil
        notifyPlayer(source, 'Staff žymė išjungta.', 'primary')
    else
        staffTags[source] = { label = label, color = color }
        notifyPlayer(source, ('Staff žymė įjungta: %s'):format(label), 'success')
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
    local src = playerSource(Player)
    if not src then return end
    syncStaffTags(src)
end)

local LOCKPICK_SUCCESS_CHANCE = { lockpick = 68, advancedlockpick = 88 }
local LOCKPICK_BREAK_CHANCE = { lockpick = 45, advancedlockpick = 20 }
local LOCKPICK_REACH = 6.5
local LOCKPICK_ALARM_MS = 45000
local LOCKPICK_FAIL_COOLDOWN = {}

local function resolveVehicleNetId(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return 0, 0 end
    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then
        return netId, 0
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        return netId, 0
    end
    return netId, ent
end

local function playerNearEntity(src, ent, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= (maxDist or LOCKPICK_REACH)
end

local function broadcastVehicleUnlock(netId)
    TriggerClientEvent('mrp_hud:client:syncVehicleLock', -1, netId, false)
    TriggerClientEvent('mrp_basics:client:markNpcVehicleUnlocked', -1, netId)
end

local function handleLockpickFailure(src, Player, netId, plate, vehicleLabel, itemName)
    plate = tostring(plate or '???'):upper():gsub('%s+', '')
    vehicleLabel = tostring(vehicleLabel or 'Transportas')
    itemName = tostring(itemName or 'lockpick')

    if Player and math.random(1, 100) <= (LOCKPICK_BREAK_CHANCE[itemName] or 40) then
        if Player.Functions.RemoveItem(itemName, 1) then
            triggerClient(src, 'inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove', 1)
        end
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local alertText = ('Signalizacija: %s, numeriai %s'):format(vehicleLabel, plate)
    if GetResourceState('mrp_dispatch') == 'started' then
        exports['mrp_dispatch']:CreateDispatchCall('police', 'vehicle_alarm', coords, alertText, src)
    end

    TriggerClientEvent('mrp_basics:client:vehicleAlarm', -1, netId, LOCKPICK_ALARM_MS)
end

RegisterNetEvent('mrp_basics:server:syncVehicleUnlock', function(netId)
    local src = source
    local resolvedNetId, ent = resolveVehicleNetId(netId)
    if resolvedNetId <= 0 then return end
    if ent ~= 0 and not playerNearEntity(src, ent, LOCKPICK_REACH) then return end
    broadcastVehicleUnlock(resolvedNetId)
end)

--- Minigame / progress fail — signalizacija + PD
RegisterNetEvent('mrp_basics:server:vehicleLockpickFail', function(netId, plate, vehicleLabel, advanced)
    local src = source
    if not isValidPlayerSource(src) then return end

    local now = os.time()
    if (LOCKPICK_FAIL_COOLDOWN[src] or 0) > now then return end
    LOCKPICK_FAIL_COOLDOWN[src] = now + 8

    local resolvedNetId, ent = resolveVehicleNetId(netId)
    if resolvedNetId <= 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemName = advanced and 'advancedlockpick' or 'lockpick'
    if not Player.Functions.GetItemByName(itemName) then return end

    if ent ~= 0 and not playerNearEntity(src, ent, LOCKPICK_REACH) then return end

    handleLockpickFailure(src, Player, resolvedNetId, plate, vehicleLabel, itemName)
end)

AddEventHandler('playerDropped', function()
    LOCKPICK_FAIL_COOLDOWN[source] = nil
end)

RegisterNetEvent('mrp_basics:server:vehicleLockpick', function(netId, plate, vehicleLabel, advanced)
    local src = source
    if not isValidPlayerSource(src) then return end
    local resolvedNetId, ent = resolveVehicleNetId(netId)
    if resolvedNetId <= 0 then
        notifyPlayer(src, 'Transportas nerastas.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemName = advanced and 'advancedlockpick' or 'lockpick'
    if not Player.Functions.GetItemByName(itemName) then
        notifyPlayer(src, 'Neturi visrakčio.', 'error')
        return
    end

    if ent ~= 0 and not playerNearEntity(src, ent, LOCKPICK_REACH) then
        notifyPlayer(src, 'Per toli nuo transporto.', 'error')
        return
    end

    plate = tostring(plate or (ent ~= 0 and GetVehicleNumberPlateText(ent) or '') or '???'):upper():gsub('%s+', '')
    vehicleLabel = tostring(vehicleLabel or 'Transportas')

    local chance = LOCKPICK_SUCCESS_CHANCE[itemName] or 60
    local success = math.random(1, 100) <= chance

    if success then
        broadcastVehicleUnlock(resolvedNetId)
        triggerClient(src, 'mrp_basics:client:vehicleLockpickResult', {
            success = true,
            netId = resolvedNetId,
            msg = 'Spyna sėkmingai atrakinta.',
        })
        return
    end

    handleLockpickFailure(src, Player, resolvedNetId, plate, vehicleLabel, itemName)
    triggerClient(src, 'mrp_basics:client:vehicleLockpickResult', {
        success = false,
        netId = resolvedNetId,
        msg = 'Nepavyko atrakinti — signalizacija!',
    })
end)

exports('IsBulkyCarryItem', function(itemName)
    return WeaponCarry.isBulkyItem(itemName)
end)

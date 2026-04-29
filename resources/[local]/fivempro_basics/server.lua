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


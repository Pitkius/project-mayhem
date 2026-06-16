local function enableDevForSource(src)
    if not src or src <= 0 then return end
    if IsPlayerAceAllowed(src, 'command.resmon') or IsPlayerAceAllowed(src, 'group.admin') then
        TriggerClientEvent('fivempro_devtools:client:enableDev', src)
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    enableDevForSource(src)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        enableDevForSource(tonumber(playerId))
    end
end)

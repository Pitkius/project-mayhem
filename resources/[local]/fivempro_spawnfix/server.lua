local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('fivempro:spawnfix:server:normalizeState', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local metadata = player.PlayerData.metadata or {}
    if metadata.isdead == nil then
        player.Functions.SetMetaData('isdead', false)
    end
    if metadata.inlaststand == nil then
        player.Functions.SetMetaData('inlaststand', false)
    end
    if metadata.armor == nil then
        player.Functions.SetMetaData('armor', 0)
    end
end)

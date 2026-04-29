local QBCore = exports['qb-core']:GetCoreObject()
local housesTableExists = nil

local function hasPlayerHousesTable()
    if housesTableExists ~= nil then
        return housesTableExists
    end

    local ok, result = pcall(function()
        return MySQL.query.await(
            "SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'player_houses' LIMIT 1"
        )
    end)

    housesTableExists = ok and result and result[1] ~= nil or false
    return housesTableExists
end

QBCore.Functions.CreateCallback('qb-spawn:server:getOwnedHouses', function(_, cb, cid)
    if cid ~= nil then
        if not hasPlayerHousesTable() then
            cb({})
            return
        end

        local ok, houses = pcall(function()
            return MySQL.query.await('SELECT * FROM player_houses WHERE citizenid = ?', { cid })
        end)
        if ok and houses and houses[1] ~= nil then
            cb(houses)
            return
        end
        cb({})
        return
    else
        cb({})
    end
end)

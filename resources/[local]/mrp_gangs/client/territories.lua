local QBCore = GangClient.QBCore

GangTerritoryClient = GangTerritoryClient or {}
GangTerritoryClient.Snapshot = {}
GangTerritoryClient.CurrentId = nil

function GangTerritoryClient.Refresh(callback)
    QBCore.Functions.TriggerCallback('mrp_gangs:server:getTerritories', function(rows)
        GangTerritoryClient.Snapshot = type(rows) == 'table' and rows or {}
        if callback then callback(GangTerritoryClient.Snapshot) end
        SendNUIMessage({ action = 'territoriesUpdated', territories = GangTerritoryClient.Snapshot })
    end)
end

function GangTerritoryClient.GetCurrent()
    if not GangTerritoryClient.CurrentId then return nil end
    for _, territory in ipairs(GangTerritoryClient.Snapshot) do
        if territory.id == GangTerritoryClient.CurrentId then return territory end
    end
    return nil
end

RegisterNetEvent('mrp_gangs:client:territoriesUpdated', function()
    GangTerritoryClient.Refresh()
end)

--- Runtime / admin-edited territory polygons from server.
RegisterNetEvent('mrp_gangs:client:syncTerritoryDefs', function(defs, removedIds)
    Config.Territories = Config.Territories or {}
    Config.TerritoryPolygons = Config.TerritoryPolygons or {}
    for _, territoryId in ipairs(type(removedIds) == 'table' and removedIds or {}) do
        Config.Territories[territoryId] = nil
        Config.TerritoryPolygons[territoryId] = nil
    end
    if type(defs) ~= 'table' then return end
    for territoryId, definition in pairs(defs) do
        if type(definition) == 'table' then
            definition.vertices = definition.vertices or {}
            Config.TerritoryPolygons[territoryId] = definition.vertices
            Config.Territories[territoryId] = definition
        end
    end
    GangTerritoryClient.Refresh()
end)

CreateThread(function()
    Wait(2500)
    GangTerritoryClient.Refresh()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local territoryId = GangUtils.FindTerritoryAt(coords.x, coords.y)
        if territoryId ~= GangTerritoryClient.CurrentId then
            GangTerritoryClient.CurrentId = territoryId
            TriggerEvent('mrp_gangs:client:territoryChanged', territoryId, GangTerritoryClient.GetCurrent())
        end
        Wait(1000)
    end
end)

exports('GetCurrentTerritory', GangTerritoryClient.GetCurrent)
exports('GetTerritorySnapshot', function()
    return GangTerritoryClient.Snapshot
end)

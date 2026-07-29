local QBCore = GangClient.QBCore
local tabletOpen = false
local adminOnlySession = false

local function setOpen(open)
    tabletOpen = open == true
    SetNuiFocus(tabletOpen, tabletOpen)
    SetNuiFocusKeepInput(false)
    if not tabletOpen then
        adminOnlySession = false
        SendNUIMessage({ action = 'close' })
    end
end

local function loadBootstrap(options)
    options = options or {}
    QBCore.Functions.TriggerCallback('mrp_gangs:server:getTabletBootstrap', function(payload)
        if not payload then
            return GangClient.Notify('Nepavyko užkrauti gaujų tabletės.', 'error')
        end
        SendNUIMessage({
            action = 'open',
            payload = payload,
            startPage = options.startPage or (adminOnlySession and 'admin' or nil),
            adminOnly = adminOnlySession,
        })
    end)
end

local function openTablet(options)
    if tabletOpen then return end
    QBCore.Functions.TriggerCallback('mrp_gangs:server:canOpenTablet', function(allowed)
        if not allowed then return GangClient.Notify(('Reikia %s.'):format(Config.TabletItem), 'error') end
        adminOnlySession = false
        setOpen(true)
        loadBootstrap(options)
    end)
end

local function openGangAdmin()
    if tabletOpen then
        setOpen(false)
    end
    QBCore.Functions.TriggerCallback('mrp_gangs:server:canOpenGangAdmin', function(allowed)
        if not allowed then
            return GangClient.Notify('Nėra teisių.', 'error')
        end
        adminOnlySession = true
        setOpen(true)
        loadBootstrap({ startPage = 'admin', adminOnly = true })
    end)
end

local function callbackAction(nuiName, serverName, argsBuilder, refresh)
    RegisterNUICallback(nuiName, function(data, callback)
        local args = argsBuilder and argsBuilder(data or {}) or {}
        QBCore.Functions.TriggerCallback(serverName, function(response)
            callback(response or { ok = false, reason = 'empty_response' })
            if refresh and response and response.ok then
                loadBootstrap({ startPage = adminOnlySession and 'admin' or nil })
            end
        end, table.unpack(args))
    end)
end

RegisterNetEvent('mrp_gangs:client:openTablet', function()
    openTablet()
end)

RegisterNetEvent('mrp_gangs:client:openGangAdmin', openGangAdmin)

RegisterCommand('gangtablet', function()
    openTablet()
end, false)

--- Legacy alias restored from pre–Gang System 2.0 (`/gangadmin`).
RegisterCommand('gangadmin', openGangAdmin, false)

RegisterNUICallback('close', function(_, callback)
    setOpen(false)
    callback({ ok = true })
end)

RegisterNUICallback('refresh', function(_, callback)
    loadBootstrap()
    callback({ ok = true })
end)

callbackAction('startMission', 'mrp_gangs:server:startMission', function(data)
    return { data.missionKey, data.difficulty }
end, true)
callbackAction('toggleMissionReady', 'mrp_gangs:server:toggleMissionReady', function(data)
    return { data.roleKey }
end, false)
callbackAction('createGang', 'mrp_gangs:server:createGang', function(data)
    return { data }
end, true)
callbackAction('acceptInvite', 'mrp_gangs:server:acceptInvite', function(data)
    return { data.inviteId }
end, true)

RegisterNUICallback('setWaypoint', function(data, callback)
    local x = tonumber(data and data.x)
    local y = tonumber(data and data.y)
    if not x or not y then
        return callback({ ok = false, reason = 'invalid_coords' })
    end
    SetNewWaypoint(x + 0.0, y + 0.0)
    GangClient.Notify('GPS nustatytas į teritoriją.', 'success')
    callback({ ok = true })
end)
callbackAction('inviteMember', 'mrp_gangs:server:inviteMember', function(data)
    return { data.targetSource, data.roleKey }
end, true)
callbackAction('kickMember', 'mrp_gangs:server:kickMember', function(data)
    return { data.citizenid }
end, true)
callbackAction('setMemberRole', 'mrp_gangs:server:setMemberRole', function(data)
    return { data.citizenid, data.roleKey }
end, true)
callbackAction('setResponsibility', 'mrp_gangs:server:setResponsibility', function(data)
    return { data.citizenid, data.key, data.enabled == true }
end, true)
callbackAction('treasury', 'mrp_gangs:server:treasury', function(data)
    return { data.operation, data.amount }
end, true)
callbackAction('updateGangInfo', 'mrp_gangs:server:updateGangInfo', function(data)
    return { data }
end, true)
callbackAction('saveRole', 'mrp_gangs:server:saveRole', function(data)
    return { data }
end, true)
callbackAction('deleteRole', 'mrp_gangs:server:deleteRole', function(data)
    return { data.roleKey }
end, true)
callbackAction('proposeTreaty', 'mrp_gangs:server:proposeTreaty', function(data)
    return { data }
end, true)
callbackAction('resolveTreaty', 'mrp_gangs:server:resolveTreaty', function(data)
    return { data.treatyId, data.accept == true }
end, true)
callbackAction('breakTreaty', 'mrp_gangs:server:breakTreaty', function(data)
    return { data.treatyId }
end, true)
callbackAction('declareWar', 'mrp_gangs:server:declareWar', function(data)
    return { data.defenderGangId, data.territoryId }
end, true)
callbackAction('manageWarRoster', 'mrp_gangs:server:manageWarRoster', function(data)
    return { data.warId, data.citizenid, data.enabled == true }
end, true)
callbackAction('getWarDetails', 'mrp_gangs:server:getWarDetails', function(data)
    return { data.warId }
end, false)
callbackAction('adminSetTerritoryOwner', 'mrp_gangs:server:adminSetTerritoryOwner', function(data)
    return { data.territoryId, data.gangId }
end, true)
callbackAction('adminSetMissionState', 'mrp_gangs:server:adminSetMissionState', function(data)
    return { data.missionKey, data.enabled == true }
end, true)
callbackAction('adminUpdateTerritoryBonus', 'mrp_gangs:server:adminUpdateTerritoryBonus', function(data)
    return { data.territoryId, data.bonuses }
end, true)
callbackAction('adminCancelWar', 'mrp_gangs:server:adminCancelWar', function(data)
    return { data.warId }
end, true)
callbackAction('adminSetGangStatus', 'mrp_gangs:server:adminSetGangStatus', function(data)
    return { data.gangId, data.status }
end, true)
callbackAction('adminDeleteGang', 'mrp_gangs:server:adminDeleteGang', function(data)
    return { data.gangId, data.confirm }
end, true)
callbackAction('adminResetTerritory', 'mrp_gangs:server:adminResetTerritory', function(data)
    return { data.territoryId }
end, true)
callbackAction('adminUpsertTerritory', 'mrp_gangs:server:adminUpsertTerritory', function(data)
    return { data }
end, true)
callbackAction('adminDeleteTerritory', 'mrp_gangs:server:adminDeleteTerritory', function(data)
    return { data.territoryId }
end, true)

RegisterNUICallback('adminGetPlayerCoords', function(_, callback)
    local coords = GetEntityCoords(PlayerPedId())
    callback({ ok = true, x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 })
end)

RegisterNetEvent('mrp_gangs:client:warsUpdated', function()
    if tabletOpen then loadBootstrap() end
end)

RegisterNetEvent('mrp_gangs:client:territoriesUpdated', function()
    if tabletOpen then loadBootstrap() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and tabletOpen then
        SetNuiFocus(false, false)
    end
end)

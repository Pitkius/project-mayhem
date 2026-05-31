local QBCore = exports['qb-core']:GetCoreObject()

local function registerJobShops()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    for _, cfg in ipairs({ Config.PoliceSupplyShop, Config.EmsSupplyShop, Config.RangerSupplyShop }) do
        if cfg and cfg.name and cfg.items then
            exports['qb-inventory']:CreateShop({
                name = cfg.name,
                label = cfg.label,
                slots = #cfg.items,
                items = cfg.items,
            })
        end
    end
end

CreateThread(function()
    Wait(800)
    registerJobShops()
end)

local function nearNpc(src, coords, maxDist)
    maxDist = tonumber(maxDist) or Config.JobNpcReach or 3.5
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = coords
    return #(p - vector3(c.x, c.y, c.z)) <= maxDist + 2.0
end

local function findNpcEntry(job, stationId, role)
    for _, e in ipairs(Config.JobStationNpcs or {}) do
        if e.job == job and e.stationId == stationId and e.role == role then
            return e
        end
    end
    return nil
end

local function playerJobOk(src, jobName)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == jobName and j.onduty
end

RegisterNetEvent('fivempro_npcshops:server:openJobSupply', function(jobName, stationId)
    local src = source
    jobName = tostring(jobName or '')
    stationId = tostring(stationId or '')
    if not playerJobOk(src, jobName) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik tarnyboje.', 'error')
    end
    local entry = findNpcEntry(jobName, stationId, 'supply')
    if not entry or not nearNpc(src, entry.coords) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo taško.', 'error')
    end
    local shop
    if jobName == 'police' then
        shop = Config.PoliceSupplyShop
    elseif jobName == 'ambulance' then
        shop = Config.EmsSupplyShop
    elseif jobName == 'ranger' then
        shop = Config.RangerSupplyShop
    end
    if not shop then return end
    registerJobShops()
    exports['qb-inventory']:OpenShop(src, shop.name)
end)

RegisterNetEvent('fivempro_npcshops:server:validateJobNpc', function(jobName, stationId, role)
    local src = source
    jobName = tostring(jobName or '')
    stationId = tostring(stationId or '')
    role = tostring(role or '')
    local entry = findNpcEntry(jobName, stationId, role)
    if not entry then
        return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'NPC nerastas.')
    end
    if role ~= 'duty' and role ~= 'boss' and role ~= 'locker' and not playerJobOk(src, jobName) then
        local msg = 'Tik tarnyboje.'
        if jobName == 'ranger' then
            msg = 'Pirmiausia pradėkite tarnybą (Tarnyba NPC arba rūbinė).'
        end
        return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, msg)
    end
    if role == 'boss' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= jobName then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik gamtosaugininkams.')
        end
        if not P.PlayerData.job.isboss and (tonumber(P.PlayerData.job.grade.level) or 0) < 3 then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik vadovui.')
        end
        if not P.PlayerData.job.onduty then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik tarnyboje.')
        end
    end
    if jobName == 'ambulance' and role == 'duty' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'ambulance' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik EMS darbuotojams.')
        end
    end
    if jobName == 'police' and role == 'duty' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'police' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik policijos darbuotojams.')
        end
    end
    if jobName == 'ranger' and role == 'duty' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'ranger' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik gamtosaugininkams.')
        end
    end
    if role == 'locker' and jobName == 'ranger' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'ranger' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik gamtosaugininkams.')
        end
    end
    if role == 'locker' and jobName == 'ambulance' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'ambulance' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik EMS darbuotojams.')
        end
    end
    if role == 'locker' and jobName == 'police' then
        local P = QBCore.Functions.GetPlayer(src)
        if not P or P.PlayerData.job.name ~= 'police' then
            return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Tik policijos darbuotojams.')
        end
    end
    if not nearNpc(src, entry.coords) then
        return TriggerClientEvent('fivempro_npcshops:client:jobNpcDenied', src, 'Per toli nuo taško.')
    end
    TriggerClientEvent('fivempro_npcshops:client:jobNpcApproved', src, jobName, stationId, role)
end)

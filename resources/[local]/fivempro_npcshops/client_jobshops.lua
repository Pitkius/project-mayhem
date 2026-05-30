local QBCore = exports['qb-core']:GetCoreObject()

local function openGarageMenu(jobName, stationId)
    if jobName == 'police' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'PD transportas', isMenuHeader = true },
            {
                header = 'Garažas',
                params = { event = 'fivempro_ltpd:client:openPdGarage', args = { stationId = stationId } },
            },
            {
                header = 'Transporto pirkimas',
                params = { event = 'fivempro_ltpd:client:goPoliceDealership', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    elseif jobName == 'ambulance' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'EMS transportas', isMenuHeader = true },
            {
                header = 'Garažas',
                params = { event = 'fivempro_ambulance:client:openGarageFleet', args = { stationId = stationId } },
            },
            {
                header = 'Transporto pirkimas',
                params = { event = 'fivempro_ambulance:client:openDealershipFleet', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end
end

local function openStashMenu(jobName, stationId)
    if jobName == 'police' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'PD sandėliai', isMenuHeader = true },
            {
                header = 'Bendras sandėlis',
                params = { event = 'fivempro_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 1 } },
            },
            {
                header = 'Sandėlis (nuo 3 rango)',
                params = { event = 'fivempro_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 2 } },
            },
            {
                header = 'Sandėlis (nuo 8 rango)',
                params = { event = 'fivempro_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 3 } },
            },
            {
                header = 'Ginklinė (stash)',
                params = { event = 'fivempro_ltpd:client:tryOpenArmory', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    elseif jobName == 'ambulance' then
        TriggerEvent('fivempro_ambulance:client:openStash', { stationId = stationId })
    end
end

RegisterNetEvent('fivempro_npcshops:client:jobNpcDenied', function(msg)
    QBCore.Functions.Notify(msg or 'Negalima.', 'error')
end)

RegisterNetEvent('fivempro_npcshops:client:jobNpcApproved', function(jobName, stationId, role)
    if role == 'supply' then
        TriggerServerEvent('fivempro_npcshops:server:openJobSupply', jobName, stationId)
    elseif role == 'garage' then
        openGarageMenu(jobName, stationId)
    elseif role == 'locker' then
        if jobName == 'police' then
            TriggerEvent('fivempro_ltpd:client:openDutyLockerMenu')
        else
            TriggerEvent('fivempro_ambulance:client:openLocker', { stationId = stationId })
        end
    elseif role == 'stash' then
        openStashMenu(jobName, stationId)
    elseif role == 'duty' then
        if jobName == 'ambulance' then
            TriggerEvent('fivempro_ambulance:client:toggleDuty')
        end
    end
end)

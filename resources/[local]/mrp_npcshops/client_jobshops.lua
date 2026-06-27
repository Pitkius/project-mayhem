local QBCore = exports['qb-core']:GetCoreObject()

local function openGarageMenu(jobName, stationId)
    if jobName == 'police' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'PD transportas', isMenuHeader = true },
            {
                header = 'Garažas',
                params = { event = 'mrp_ltpd:client:openPdGarage', args = { stationId = stationId } },
            },
            {
                header = 'Transporto pirkimas',
                params = { event = 'mrp_ltpd:client:goPoliceDealership', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    elseif jobName == 'ambulance' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'EMS transportas', isMenuHeader = true },
            {
                header = 'Garažas',
                params = { event = 'mrp_ambulance:client:openGarageFleet', args = { stationId = stationId } },
            },
            {
                header = 'Transporto pirkimas',
                params = { event = 'mrp_ambulance:client:openDealershipFleet', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    elseif jobName == 'ranger' then
        if GetResourceState('qb-menu') ~= 'started' then return end
        local menu = {
            { header = 'Gamtos apsaugos transportas', isMenuHeader = true },
            {
                header = 'Garažas',
                params = { event = 'mrp_ranger:client:openGarage', args = { stationId = stationId } },
            },
            {
                header = 'Transporto pirkimas',
                params = { event = 'mrp_ranger:client:openDealershipFleet', args = { stationId = stationId } },
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
                params = { event = 'mrp_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 1 } },
            },
            {
                header = 'Sandėlis (nuo 3 rango)',
                params = { event = 'mrp_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 2 } },
            },
            {
                header = 'Sandėlis (vadovų)',
                params = { event = 'mrp_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 3 } },
            },
            {
                header = 'Sandėlis (bosas / pavaduotojas)',
                params = { event = 'mrp_ltpd:client:tryOpenStash', args = { stationId = stationId, stashIndex = 4 } },
            },
            {
                header = 'ARO sandėlis (ginklinė)',
                params = { event = 'mrp_ltpd:client:tryOpenArmory', args = { stationId = stationId } },
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    elseif jobName == 'ambulance' then
        TriggerEvent('mrp_ambulance:client:openStash', { stationId = stationId })
    elseif jobName == 'ranger' then
        TriggerEvent('mrp_ranger:client:openPersonalStash')
    end
end

RegisterNetEvent('mrp_npcshops:client:jobNpcDenied', function(msg)
    QBCore.Functions.Notify(msg or 'Negalima.', 'error')
end)

RegisterNetEvent('mrp_npcshops:client:jobNpcApproved', function(jobName, stationId, role)
    if role == 'supply' then
        TriggerServerEvent('mrp_npcshops:server:openJobSupply', jobName, stationId)
    elseif role == 'garage' then
        openGarageMenu(jobName, stationId)
    elseif role == 'locker' then
        if jobName == 'police' then
            TriggerEvent('mrp_ltpd:client:openDutyLockerMenu')
        elseif jobName == 'ranger' then
            TriggerEvent('mrp_ranger:client:openLocker')
        else
            TriggerEvent('mrp_ambulance:client:openLocker', { stationId = stationId })
        end
    elseif role == 'stash' then
        openStashMenu(jobName, stationId)
    elseif role == 'boss' then
        if jobName == 'ranger' then
            TriggerEvent('mrp_ranger:client:bossOpenMenu')
        elseif jobName == 'police' then
            TriggerEvent('mrp_ltpd:client:bossOpenMenu')
        end
    elseif role == 'duty' then
        if jobName == 'police' then
            TriggerEvent('mrp_ltpd:client:toggleDuty')
        elseif jobName == 'ambulance' then
            TriggerEvent('mrp_ambulance:client:toggleDuty')
        elseif jobName == 'ranger' then
            TriggerEvent('mrp_ranger:client:toggleDuty')
        end
    end
end)

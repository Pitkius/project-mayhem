local QBCore = exports['qb-core']:GetCoreObject()

local spawnedJobPeds = {}
local pendingJobTargets = {}

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

local function setupPed(ped)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
end

local function spawnJobPed(model, coords)
    local hash = loadModel(model)
    if not hash then return nil end
    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w)
    SetModelAsNoLongerNeeded(hash)
    setupPed(ped)
    spawnedJobPeds[#spawnedJobPeds + 1] = ped
    return ped
end

local function queueTarget(ped, data)
    if not ped or not DoesEntityExist(ped) then return end
    pendingJobTargets[#pendingJobTargets + 1] = { ped = ped, data = data }
end

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

local function requestNpcAction(entry)
    TriggerServerEvent('fivempro_npcshops:server:validateJobNpc', entry.job, entry.stationId, entry.role)
end

CreateThread(function()
    while true do
        if GetResourceState('qb-target') == 'started' then
            for i = #pendingJobTargets, 1, -1 do
                local entry = pendingJobTargets[i]
                if entry and DoesEntityExist(entry.ped) then
                    exports['qb-target']:AddTargetEntity(entry.ped, entry.data)
                end
                table.remove(pendingJobTargets, i)
            end
        end
        Wait(500)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(350) end
    Wait(1200)

    for idx, entry in ipairs(Config.JobStationNpcs or {}) do
        local ped = spawnJobPed(entry.model or 's_m_m_doctor_01', entry.coords)
        if ped then
            local icon = 'fas fa-user'
            if entry.role == 'supply' then icon = 'fas fa-box-open'
            elseif entry.role == 'garage' then icon = 'fas fa-car'
            elseif entry.role == 'locker' then icon = 'fas fa-shirt'
            elseif entry.role == 'stash' then icon = 'fas fa-warehouse'
            elseif entry.role == 'duty' then icon = 'fas fa-id-badge'
            end

            local captured = entry
            queueTarget(ped, {
                options = {
                    {
                        icon = icon,
                        label = entry.label or 'Tarnyba',
                        action = function()
                            requestNpcAction(captured)
                        end,
                    },
                },
                distance = Config.JobNpcReach or 3.5,
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #spawnedJobPeds do
        if DoesEntityExist(spawnedJobPeds[i]) then
            DeletePed(spawnedJobPeds[i])
        end
    end
end)

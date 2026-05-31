local QBCore = exports['qb-core']:GetCoreObject()

local function canOpenBoss()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then
        return false
    end
    if P.job.isboss then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 3)
end

local function openBossMenu()
    if not canOpenBoss() then
        return QBCore.Functions.Notify('Neturi teisės naudoti vadovybės meniu.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'Gamtos apsaugos vadovybė', isMenuHeader = true },
        {
            header = 'Įdarbinti',
            txt = 'Serverio ID + pradinis rangas (0–3)',
            params = { event = 'fivempro_ranger:client:bossHireInput' },
        },
        {
            header = 'Atleisti',
            txt = 'Serverio ID',
            params = { event = 'fivempro_ranger:client:bossFireInput' },
        },
        {
            header = 'Keisti rangą',
            txt = 'Serverio ID + naujas rangas 0–3',
            params = { event = 'fivempro_ranger:client:bossGradeInput' },
        },
        {
            header = 'Tarnyba: įjungti / išjungti',
            txt = 'Tavo duty',
            params = { event = 'fivempro_ranger:client:bossToggleDuty' },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_ranger:client:bossOpenMenu', function()
    openBossMenu()
end)

RegisterNetEvent('fivempro_ranger:client:bossHireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Įdarbinti į gamtos apsaugą',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Pradinis rangas (0–3)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ranger:server:bossHire', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_ranger:client:bossFireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Atleisti',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ranger:server:bossFire', tonumber(r.pid))
end)

RegisterNetEvent('fivempro_ranger:client:bossGradeInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Keisti rangą',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Naujas rangas (0–3)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ranger:server:bossSetGrade', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_ranger:client:bossToggleDuty', function()
    TriggerEvent('fivempro_ranger:client:toggleDuty')
end)

RegisterNetEvent('fivempro_ranger:client:openDealershipFleet', function(data)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then
        return QBCore.Functions.Notify('Tik gamtosaugininkams tarnyboje.', 'error')
    end
    local stationId = type(data) == 'table' and data.stationId or Config.Station.id
    TriggerEvent('fivempro_dealership:client:openRangerDealership', stationId)
end)

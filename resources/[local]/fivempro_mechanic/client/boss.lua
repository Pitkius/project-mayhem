local QBCore = exports['qb-core']:GetCoreObject()

local function canOpenBoss()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then
        return false
    end
    if P.job.isboss then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 4)
end

RegisterNetEvent('fivempro_mechanic:client:bossOpenMenu', function()
    if not canOpenBoss() then
        return QBCore.Functions.Notify('Neturi teisės naudoti vadovybės meniu.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'Mechanikų vadovybė', isMenuHeader = true },
        {
            header = 'Įdarbinti',
            txt = 'Serverio ID + rangas',
            params = { event = 'fivempro_mechanic:client:bossHireInput' },
        },
        {
            header = 'Atleisti',
            txt = 'Serverio ID',
            params = { event = 'fivempro_mechanic:client:bossFireInput' },
        },
        {
            header = 'Keisti rangą',
            txt = 'Serverio ID + naujas rangas',
            params = { event = 'fivempro_mechanic:client:bossGradeInput' },
        },
        {
            header = 'Tarnyba',
            txt = 'Įjungti / išjungti savo duty',
            params = { event = 'fivempro_mechanic:client:bossToggleDuty' },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_mechanic:client:bossHireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Įdarbinti mechaniką',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Rangas (0–5)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_mechanic:server:bossHire', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_mechanic:client:bossFireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Atleisti mechaniką',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_mechanic:server:bossFire', tonumber(r.pid))
end)

RegisterNetEvent('fivempro_mechanic:client:bossGradeInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Keisti rangą',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Naujas rangas (0–5)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_mechanic:server:bossSetGrade', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_mechanic:client:bossToggleDuty', function()
    local j = QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().job
    if not j or j.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

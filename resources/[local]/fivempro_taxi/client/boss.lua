local QBCore = exports['qb-core']:GetCoreObject()

local function canOpenBoss()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then
        return false
    end
    if P.job.isboss then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 2)
end

RegisterNetEvent('fivempro_taxi:client:bossOpenMenu', function()
    if not canOpenBoss() then
        return QBCore.Functions.Notify('Neturi teisės naudoti vadovybės meniu.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'Taksi vadovybė', isMenuHeader = true },
        {
            header = 'Įdarbinti',
            txt = 'Serverio ID + rangas',
            params = { event = 'fivempro_taxi:client:bossHireInput' },
        },
        {
            header = 'Atleisti',
            txt = 'Serverio ID',
            params = { event = 'fivempro_taxi:client:bossFireInput' },
        },
        {
            header = 'Keisti rangą',
            txt = 'Serverio ID + naujas rangas',
            params = { event = 'fivempro_taxi:client:bossGradeInput' },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_taxi:client:bossHireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Įdarbinti taksi darbuotoją',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Rangas (0-2)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_taxi:server:bossHire', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_taxi:client:bossFireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Atleisti taksi darbuotoją',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_taxi:server:bossFire', tonumber(r.pid))
end)

RegisterNetEvent('fivempro_taxi:client:bossGradeInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Keisti rangą',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Naujas rangas (0-2)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_taxi:server:bossSetGrade', tonumber(r.pid), tonumber(r.grade))
end)

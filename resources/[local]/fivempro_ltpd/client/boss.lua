local QBCore = exports['qb-core']:GetCoreObject()

local function isPdJobName(name)
    if not name then return false end
    if name == Config.JobName then return true end
    if Config.AcceptLegacyPoliceJob and name == 'police' then return true end
    return false
end

local function canOpenBoss()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not isPdJobName(P.job.name) or not P.job.onduty then
        return false
    end
    if P.job.isboss then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 7)
end

local function openBossMenu()
    if not canOpenBoss() then
        return QBCore.Functions.Notify('Neturi teisės naudoti vadovybės meniu.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'LTPD vadovybė', isMenuHeader = true },
        {
            header = 'Įdarbinti į PD',
            txt = 'Serverio ID + pradinis rangas',
            params = {
                event = 'fivempro_ltpd:client:bossHireInput',
            },
        },
        {
            header = 'Atleisti iš PD',
            txt = 'Serverio ID',
            params = {
                event = 'fivempro_ltpd:client:bossFireInput',
            },
        },
        {
            header = 'Keisti pareigūno rangą',
            txt = 'Serverio ID + naujas rangas 0–10',
            params = {
                event = 'fivempro_ltpd:client:bossGradeInput',
            },
        },
        {
            header = 'Tarnyba: įjungti / išjungti',
            txt = 'Tavo duty (kaip F5 meniu)',
            params = {
                event = 'fivempro_ltpd:client:bossToggleDuty',
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_ltpd:client:bossOpenMenu', function()
    openBossMenu()
end)

RegisterNetEvent('fivempro_ltpd:client:bossHireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Įdarbinti',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Pradinis rangas (0–10)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ltpd:server:bossHire', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_ltpd:client:bossFireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Atleisti iš PD',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ltpd:server:bossFire', tonumber(r.pid))
end)

RegisterNetEvent('fivempro_ltpd:client:bossGradeInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Keisti rangą',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Naujas rangas (0–10)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('fivempro_ltpd:server:bossSetGrade', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('fivempro_ltpd:client:bossToggleDuty', function()
    local j = QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().job
    if not j or not isPdJobName(j.name) then
        return
    end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

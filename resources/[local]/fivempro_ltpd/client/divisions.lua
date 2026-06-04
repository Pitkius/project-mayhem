--- PD padaliniai – kliento būsena ir pasirinkimo meniu
local QBCore = exports['qb-core']:GetCoreObject()

local pdGrade = 0
local pdDivision = 'patrol'
local pdEffective = 'lpm'

local function refreshFromPlayer()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return end
    pdGrade = tonumber(P.job.grade and P.job.grade.level) or 0
end

local function applySync(data)
    if not data then return end
    pdGrade = tonumber(data.grade) or pdGrade
    pdDivision = PdDivisions.normalize(data.division or pdDivision)
    pdEffective = PdDivisions.effectiveDivision(pdGrade, pdDivision)
end

function SyncPdDivisionState()
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:getPdDivisionState', function(data)
        applySync(data)
    end)
end

exports('GetPdGrade', function()
    return pdGrade
end)

exports('GetPdDivision', function()
    return pdDivision
end)

exports('GetPdEffectiveDivision', function()
    return pdEffective
end)

exports('CanAccessPdPoint', function(entry)
    return PdDivisions.canAccessPoint(pdGrade, pdDivision, entry)
end)

RegisterNetEvent('fivempro_ltpd:client:syncDivision', function(data)
    applySync(data)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshFromPlayer()
    SyncPdDivisionState()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if job and job.name == (Config.JobName or 'police') then
        pdGrade = tonumber(job.grade and job.grade.level) or pdGrade
        SyncPdDivisionState()
    end
end)

local function isPdOnDutyClient()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == (Config.JobName or 'police') and P.job.onduty
end

local function openChooseDivisionMenu()
    if not isPdOnDutyClient() then
        return QBCore.Functions.Notify('Tik tarnyboje.', 'error')
    end
    local chooseMin = tonumber((Config.DivisionRules or {}).chooseMinGrade) or 4
    if pdGrade < chooseMin then
        return QBCore.Functions.Notify(
            ('LPM padalinys iki %d rango. Nuo %d rango galėsi rinktis tarnybą.'):format(
                tonumber((Config.DivisionRules or {}).lpmMaxGrade) or 3,
                chooseMin
            ),
            'error'
        )
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local options = PdDivisions.listChoosable(pdGrade)
    if #options == 0 then
        return QBCore.Functions.Notify('Nėra prieinamų padalinių.', 'error')
    end
    local menu = {
        {
            header = 'PD padalinys',
            txt = ('Dabartinis: %s'):format(
                (Config.Divisions[pdEffective] and Config.Divisions[pdEffective].label) or pdEffective
            ),
            isMenuHeader = true,
        },
    }
    for _, opt in ipairs(options) do
        local sel = opt.id == pdDivision
        menu[#menu + 1] = {
            header = opt.label .. (sel and ' ✓' or ''),
            txt = sel and 'Dabartinis padalinys' or 'Pasirinkti',
            params = {
                isServer = true,
                event = 'fivempro_ltpd:server:chooseDivision',
                args = { division = opt.id },
            },
        }
    end
    menu[#menu + 1] = {
        header = '← Uždaryti',
        params = { event = 'qb-menu:closeMenu' },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_ltpd:client:openChooseDivisionMenu', function()
    openChooseDivisionMenu()
end)

RegisterCommand('pddept', function()
    openChooseDivisionMenu()
end, false)

CreateThread(function()
    Wait(1500)
    refreshFromPlayer()
    SyncPdDivisionState()
end)

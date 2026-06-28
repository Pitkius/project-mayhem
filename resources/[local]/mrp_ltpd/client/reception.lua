--- PD registratūra — civiliai: pareiškimas, anketa į policijos gretas
local QBCore = exports['qb-core']:GetCoreObject()

local function receptionCfg()
    return Config.Reception or {}
end

local function isPoliceEmployee()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == (Config.JobName or 'police')
end

local function openStatementForm()
    if GetResourceState('qb-input') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-input resurso.', 'error')
    end
    local input = exports['qb-input']:ShowInput({
        header = 'Pareiškimas policijai',
        submitText = 'Pateikti',
        inputs = {
            { text = 'Incidento tipas (pvz. vagystė, smurtas)', name = 'subject', type = 'text', isRequired = true },
            { text = 'Vieta (jei žinoma)', name = 'location', type = 'text', isRequired = false },
            { text = 'Pareiškimo turinys', name = 'body', type = 'text', isRequired = true },
        },
    })
    if not input or not input.subject or not input.body then return end
    TriggerServerEvent('mrp_ltpd:server:submitCivilianStatement', {
        subject = input.subject,
        location = input.location or '',
        body = input.body,
    })
end

local function openRecruitmentForm()
    if isPoliceEmployee() then
        return QBCore.Functions.Notify('Jau esi policijos darbuotojas. Pamainą valdyk prie pamainos NPC.', 'error')
    end
    if GetResourceState('qb-input') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-input resurso.', 'error')
    end
    local input = exports['qb-input']:ShowInput({
        header = 'Anketa į policijos gretas',
        submitText = 'Pateikti anketa',
        inputs = {
            { text = 'Kodėl norite tarnauti policijoje?', name = 'motivation', type = 'text', isRequired = true },
            { text = 'Išsilavinimas / darbo patirtis', name = 'experience', type = 'text', isRequired = false },
            { text = 'Papildoma informacija', name = 'extra', type = 'text', isRequired = false },
        },
    })
    if not input or not input.motivation then return end
    TriggerServerEvent('mrp_ltpd:server:submitRecruitmentApplication', {
        motivation = input.motivation,
        experience = input.experience or '',
        extra = input.extra or '',
    })
end

local function openCivilianReceptionMenu()
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'Los Santos policijos registratūra', isMenuHeader = true },
        {
            header = 'Pateikti pareiškimą',
            txt = 'Pranešti apie įvykį ar palikti oficialų pareiškimą.',
            params = { event = 'mrp_ltpd:client:receptionStatement' },
        },
        {
            header = 'Anketa į policijos gretas',
            txt = 'Pildyti priėmimo anketą (įdarbinimą tvirtina vadovybė).',
            params = { event = 'mrp_ltpd:client:receptionApplication' },
        },
        { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('mrp_ltpd:client:openCivilianReception', function()
    openCivilianReceptionMenu()
end)

RegisterNetEvent('mrp_ltpd:client:receptionStatement', function()
    openStatementForm()
end)

RegisterNetEvent('mrp_ltpd:client:receptionApplication', function()
    openRecruitmentForm()
end)

RegisterNetEvent('mrp_ltpd:client:receptionSubmitResult', function(ok, msg)
    QBCore.Functions.Notify(msg or (ok and 'Pateikta.' or 'Nepavyko.'), ok and 'success' or 'error', 6500)
end)

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

local receptionBlips = {}

local function setupReceptionBlip(stationId, coords, blipCfg)
    if not blipCfg or not coords then return end
    local bl = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(bl, blipCfg.sprite or 280)
    SetBlipDisplay(bl, 4)
    SetBlipScale(bl, blipCfg.scale or 0.72)
    SetBlipColour(bl, blipCfg.color or 3)
    SetBlipAsShortRange(bl, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipCfg.label or 'PD registratūra')
    EndTextCommandSetBlipName(bl)
    receptionBlips[stationId] = bl
end

local function setupReceptionTargets()
    if GetResourceState('qb-target') ~= 'started' then return false end

    for _, st in ipairs(Config.Stations or {}) do
        local rec = st.reception
        if not rec or not rec.coords then goto continue end

        local c = rec.coords
        local zoneName = ('ltpd_reception_%s'):format(st.id or 'main')
        exports['qb-target']:AddBoxZone(zoneName, c, rec.length or 1.6, rec.width or 1.4, {
            name = zoneName,
            heading = rec.heading or 0.0,
            minZ = c.z - 1.0,
            maxZ = c.z + 1.2,
            debugPoly = false,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_ltpd:client:openCivilianReception',
                    icon = 'fas fa-clipboard',
                    label = rec.label or 'PD registratūra',
                },
            },
            distance = 2.2,
        })

        setupReceptionBlip(st.id or 'main', c, rec.blip)

        ::continue::
    end
    return true
end

CreateThread(function()
    local waited = 0
    while not setupReceptionTargets() and waited < 60 do
        Wait(1000)
        waited = waited + 1
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, bl in pairs(receptionBlips) do
        if bl and DoesBlipExist(bl) then
            RemoveBlip(bl)
        end
    end
    receptionBlips = {}
end)

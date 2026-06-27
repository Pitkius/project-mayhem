local QBCore = exports['qb-core']:GetCoreObject()

local function isRangerOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function hasGrade(minGrade)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    return (tonumber(P.job.grade.level) or 0) >= (minGrade or 0)
end

RegisterNetEvent('mrp_ranger:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('mrp_ranger:client:openGarage', function(data)
    if not isRangerOnDuty() then
        return QBCore.Functions.Notify('Tik gamtosaugininkams tarnyboje.', 'error')
    end
    local gid = (data and data.stationId == Config.Station.id) and Config.Station.garageId or Config.Station.garageId
    TriggerEvent('mrp_garages:client:openGarage', { garageId = gid })
end)

RegisterNetEvent('mrp_ranger:client:openLocker', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then
        return QBCore.Functions.Notify('Ne gamtosaugininkas.', 'error')
    end
    if not P.job.onduty then
        return QBCore.Functions.Notify('Rūbinė – tik tarnyboje. Pamainą pradėk prie tarnybos NPC.', 'error')
    end
    local menu = {
        { header = 'Gamtos apsaugos rūbinė', isMenuHeader = true },
        {
            header = 'Uniforma',
            params = { event = 'mrp_ranger:client:wearUniform' },
        },
        {
            header = 'Baigti tarnybą',
            txt = 'Civilio apranga (duty lieka — pamainą baigti prie tarnybos NPC)',
            params = { event = 'mrp_ranger:client:applyCivilianOutfit' },
        },
    }
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('mrp_ranger:client:applyCivilianOutfit', function()
    if not isRangerOnDuty() then return end
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    if GetResourceState('qb-clothing') == 'started' then
        exports['qb-clothing']:reloadSkin(health)
    else
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        TriggerServerEvent('qb-clothing:loadPlayerSkin')
    end
    SetPedArmour(ped, 0)
    QBCore.Functions.Notify('Civilio apranga uždėta. Duty lieka aktyvus.', 'success')
end)

RegisterNetEvent('mrp_ranger:client:wearUniform', function()
    if not isRangerOnDuty() then
        return QBCore.Functions.Notify('Pirmiausia pradėkite tarnybą.', 'error')
    end
    local P = QBCore.Functions.GetPlayerData()
    local gender = P.charinfo and P.charinfo.gender == 1 and 'female' or 'male'
    local outfit = Config.DutyOutfits[gender]
    if not outfit then return end
    TriggerEvent('qb-clothing:client:loadOutfit', { outfitData = outfit })
    QBCore.Functions.Notify('Uniforma apsirengta.', 'success')
end)

RegisterNetEvent('mrp_ranger:client:openPersonalStash', function()
    if not isRangerOnDuty() then
        return QBCore.Functions.Notify('Tik tarnyboje.', 'error')
    end
    TriggerServerEvent('mrp_ranger:server:openStash')
end)

RegisterNetEvent('mrp_ranger:client:cuffedState', function(state)
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end)

local function openFineMenu(targetId)
    if not isRangerOnDuty() or not hasGrade(Config.Permissions.fine or 0) then
        return QBCore.Functions.Notify('Neturite teisių.', 'error')
    end
    local menu = { { header = 'Gamtos bauda', isMenuHeader = true } }
    for _, p in ipairs(Config.FinePresets or {}) do
        menu[#menu + 1] = {
            header = p.label .. ' — $' .. p.defaultAmount,
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_ranger:server:issueFine', targetId, p.code, p.label, p.defaultAmount, '')
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Kita suma…',
        params = {
            isAction = true,
            event = function()
                local input = exports['qb-input']:ShowInput({
                    header = 'Bauda',
                    submitText = 'Išrašyti',
                    inputs = {
                        { text = 'Priežastis', name = 'reason', type = 'text' },
                        { text = 'Suma €', name = 'amount', type = 'number' },
                    },
                })
                if not input then return end
                TriggerServerEvent('mrp_ranger:server:issueFine', targetId, 'CUSTOM', input.reason or 'Pažeidimas', tonumber(input.amount) or 0, input.reason or '')
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

CreateThread(function()
    Wait(2000)
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-handcuffs',
                label = 'Antrankiai',
                canInteract = function()
                    return isRangerOnDuty() and hasGrade(Config.Permissions.cuff or 0)
                end,
                action = function(entity)
                    local idx = NetworkGetPlayerIndexFromPed(entity)
                    if idx == -1 then return end
                    TriggerServerEvent('mrp_ranger:server:cuffPlayer', GetPlayerServerId(idx))
                end,
            },
            {
                icon = 'fas fa-file-invoice-dollar',
                label = 'Bauda',
                canInteract = function()
                    return isRangerOnDuty() and hasGrade(Config.Permissions.fine or 0)
                end,
                action = function(entity)
                    local idx = NetworkGetPlayerIndexFromPed(entity)
                    if idx == -1 then return end
                    openFineMenu(GetPlayerServerId(idx))
                end,
            },
        },
        distance = 2.0,
    })
end)

RegisterCommand('rangerfine', function()
    if not isRangerOnDuty() then return end
    local input = exports['qb-input']:ShowInput({
        header = 'Bauda (server ID)',
        submitText = 'Tęsti',
        inputs = { { text = 'Žaidėjo ID', name = 'id', type = 'number' } },
    })
    if not input or not input.id then return end
    openFineMenu(tonumber(input.id))
end, false)

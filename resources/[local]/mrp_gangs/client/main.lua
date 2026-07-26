local QBCore = exports['qb-core']:GetCoreObject()

GangClient = GangClient or {}
GangClient.QBCore = QBCore

local reasonLabels = {
    system_not_ready = 'Misijų sistema dar nepasiruošusi.',
    rate_limited = 'Bandai per greitai.',
    server_mission_limit = 'Šiuo metu vyksta per daug operacijų.',
    not_in_gang = 'Nepriklausai gaujai.',
    gang_already_active = 'Tavo gauja jau vykdo operaciją.',
    mission_not_allowed = 'Šis kontraktas tavo gaujai nepasiekiamas.',
    difficulty_not_allowed = 'Šis sunkumas kontraktui nepasiekiamas.',
    mission_cooldown = 'Šis kontraktas dar turi cooldown.',
    not_enough_setup_cash = 'Nepakanka grynųjų pasiruošimo kainai.',
    setup_payment_failed = 'Nepavyko apmokėti pasiruošimo.',
    party_member_busy = 'Vienas iš pasiruošusių narių jau vykdo kitą operaciją.',
    mission_location_unavailable = 'Nepavyko parinkti operacijos vietos.',
    mission_persist_failed = 'Nepavyko išsaugoti operacijos.',
    party_persist_failed = 'Nepavyko išsaugoti operacijos komandos.',
    leader_only = 'Atšaukti gali tik operacijos vadovas.',
    party_not_at_entry = 'Visi prisijungę operacijos nariai turi būti prie įėjimo.',
    party_not_at_extraction = 'Bent 60% prisijungusios komandos turi pasiekti extraction.',
    not_at_checkpoint = 'Neatvykai į pažymėtą checkpoint.',
    not_at_objective = 'Esi per toli nuo operacijos objekto.',
    vehicle_required = 'Šį etapą reikia vykdyti transporto priemonėje.',
    mission_vehicle_driver_required = 'Turi vairuoti pažymėtą operacijos transportą.',
    mission_vehicle_required = 'Checkpoint turi būti kertamas operacijos transportu.',
    mission_vehicle_destroyed = 'Operacijos transportas sunaikintas.',
    mission_target_lost = 'Operacijos taikinys žuvo arba dingo.',
    mission_target_not_at_extraction = 'Taikinys dar nepasiekė extraction vietos.',
    mission_cargo_not_at_extraction = 'Operacijos krovinys dar nepasiekė extraction vietos.',
    cargo_contested_stolen = 'Priešiška gauja perėmė outdoor krovinį / konteinerį.',
    contest_not_active = 'Šis contested loot jau nebegalioja.',
    own_mission_use_board = 'Tai tavo gaujos operacija — naudok normalų mission trackerį.',
    already_in_mission = 'Jau vykdai kitą operaciją.',
    checkpoint_too_fast = 'Checkpoint pasiektas neįmanomai greitai.',
    objective_action_not_started = 'Veiksmas nebuvo tinkamai pradėtas.',
    objective_action_too_fast = 'Veiksmas baigtas per greitai.',
    player_incapacitated = 'Negali vykdyti tikslo būdamas sužeistas.',
    permission_denied = 'Neturi teisės atlikti šio veiksmo.',
}

function GangClient.Notify(message, messageType, duration)
    QBCore.Functions.Notify(tostring(message), messageType or 'primary', duration or 6000)
end

function GangClient.Reason(reason)
    return reasonLabels[tostring(reason)] or tostring(reason or 'Nežinoma klaida.')
end

local function openDifficultyMenu(mission)
    local menu = {
        {
            header = mission.label,
            txt = mission.description,
            isMenuHeader = true,
        },
    }
    for _, difficultyKey in ipairs(mission.difficulties or {}) do
        local difficulty = Config.Difficulties[difficultyKey]
        menu[#menu + 1] = {
            header = ('%s · $%s setup'):format(difficulty.label, difficulty.setupCost or 0),
            txt = ('Rekomenduojama %s–%s · reward ×%.2f'):format(
                difficulty.recommendedMin,
                difficulty.recommendedMax,
                difficulty.rewardMultiplier
            ),
            params = {
                event = 'mrp_gangs:client:startMissionFromMenu',
                args = { missionKey = mission.id, difficulty = difficultyKey },
            },
        }
    end
    menu[#menu + 1] = {
        header = '← Atgal',
        params = { event = 'mrp_gangs:client:openMissionBoard' },
    }
    exports['qb-menu']:openMenu(menu)
end

local function renderBoard(board)
    if not board.gang then return GangClient.Notify('Nepriklausai Gang System 2.0 gaujai.', 'error') end
    if GetResourceState('qb-menu') ~= 'started' then
        return GangClient.Notify('Mission Board reikalauja qb-menu arba būsimos tabletės.', 'error')
    end

    local menu = {
        {
            header = ('%s · Mission Board'):format(board.gang.label),
            txt = ('%s kontraktų · reputacija %s'):format(#board.missions, board.gang.reputation or 0),
            isMenuHeader = true,
        },
        {
            header = 'Party pasiruošimas',
            txt = 'Pažymėk save pasiruošusiu 5 minutėms. Leader visada įtraukiamas.',
            params = { event = 'mrp_gangs:client:toggleMissionReady' },
        },
    }
    if board.active then
        menu[#menu + 1] = {
            header = ('Aktyvi: %s'):format(board.active.missionLabel),
            txt = 'Uždaryti meniu ir tęsti aktyvią operaciją.',
            isMenuHeader = true,
        }
    end
    for _, mission in ipairs(board.missions) do
        menu[#menu + 1] = {
            header = ('%s · %s'):format(mission.category:upper(), mission.label),
            txt = ('%s · base $%s · rep %s%s'):format(
                mission.description,
                mission.baseReward,
                mission.baseReputation,
                mission.hasInterior and ' · interjeras' or ''
            ),
            params = {
                event = 'mrp_gangs:client:chooseMissionDifficulty',
                args = mission,
            },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('mrp_gangs:client:openMissionBoard', function()
    QBCore.Functions.TriggerCallback('mrp_gangs:server:getMissionBoard', renderBoard)
end)

RegisterNetEvent('mrp_gangs:client:chooseMissionDifficulty', function(mission)
    openDifficultyMenu(mission)
end)

RegisterNetEvent('mrp_gangs:client:startMissionFromMenu', function(data)
    QBCore.Functions.TriggerCallback('mrp_gangs:server:startMission', function(response)
        if not response or not response.ok then
            return GangClient.Notify(GangClient.Reason(response and response.result), 'error')
        end
        GangClient.Notify(('Operacija „%s“ pradėta.'):format(response.result.missionLabel), 'success')
        if GetResourceState('qb-menu') == 'started' then exports['qb-menu']:closeMenu() end
    end, data.missionKey, data.difficulty)
end)

RegisterNetEvent('mrp_gangs:client:toggleMissionReady', function(roleKey)
    QBCore.Functions.TriggerCallback('mrp_gangs:server:toggleMissionReady', function(response)
        if not response or not response.ok then
            return GangClient.Notify(GangClient.Reason(response and response.reason), 'error')
        end
        if response.ready then
            local role = Config.MissionRoles[response.roleKey]
            GangClient.Notify(('Esi pasiruošęs kaip %s. Leader gali pradėti operaciją per 5 minutes.'):format(
                role and role.label or response.roleKey
            ), 'success')
        else
            GangClient.Notify('Pasiruošimas atšauktas.', 'primary')
        end
    end, roleKey)
end)

RegisterCommand('gangmissions', function()
    TriggerEvent('mrp_gangs:client:openMissionBoard')
end, false)

RegisterCommand('gangready', function(_, args)
    TriggerEvent('mrp_gangs:client:toggleMissionReady', args and args[1] or 'support')
end, false)

RegisterCommand('cancelgangmission', function()
    TriggerServerEvent('mrp_gangs:server:cancelMission')
end, false)

CreateThread(function()
    Wait(3000)
    TriggerServerEvent('mrp_gangs:server:requestMissionResume')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('mrp_gangs:server:requestMissionResume')
end)

exports('OpenMissionBoard', function()
    TriggerEvent('mrp_gangs:client:openMissionBoard')
end)

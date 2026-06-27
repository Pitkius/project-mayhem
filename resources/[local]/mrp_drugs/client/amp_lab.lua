local QBCore = exports['qb-core']:GetCoreObject()

local synthesizing = false
local flareToken = 0

local function ampCfg()
    return Config.AmpMobileLab or {}
end

local function isAmpVehicle(entity)
    if not entity or entity == 0 then return false end
    local hash = GetEntityModel(entity)
    local models = ampCfg().vehicleModels or { journey = true, journey2 = true }
    for name in pairs(models) do
        if joaat(name) == hash then return true end
    end
    return false
end

local function findNearbyJourney()
    local cfg = ampCfg()
    local lab = cfg.lab and cfg.lab.coords
    if not lab then return nil end
    local maxD = cfg.vehicleMaxDistance or 9.0
    local best, bestD = nil, maxD + 1.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and isAmpVehicle(veh) then
            local d = #(GetEntityCoords(veh) - lab)
            if d <= maxD and d < bestD then
                best = veh
                bestD = d
            end
        end
    end
    return best
end

local function pickQuestions(count)
    local pool = ampCfg().questions or {}
    local picked = {}
    local used = {}
    count = math.min(count, #pool)
    local tries = 0
    while #picked < count and tries < 100 do
        tries = tries + 1
        local idx = math.random(1, #pool)
        if not used[idx] then
            used[idx] = true
            picked[#picked + 1] = pool[idx]
        end
    end
    return picked
end

local function exhaustFlareLoop(veh, token)
    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do Wait(10) end
    while flareToken == token and veh and DoesEntityExist(veh) do
        local bones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' }
        for _, boneName in ipairs(bones) do
            local bone = GetEntityBoneIndexByName(veh, boneName)
            if bone ~= -1 then
                local pos = GetWorldPositionOfEntityBone(veh, bone)
                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord('exp_grd_flare', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.45, false, false, false)
                UseParticleFxAssetNextCall('core')
                StartParticleFxNonLoopedAtCoord('ent_amb_smoke_foundry', pos.x, pos.y, pos.z + 0.1, 0.0, 0.0, 0.0, 0.35, false, false, false)
            end
        end
        Wait(650)
    end
end

local function runAmpQuizFixed(questionCount, durationMs)
    local questions = pickQuestions(questionCount)
    local wrong = 0
    local interval = math.floor((durationMs or 72000) / math.max(1, #questions))

    for i, q in ipairs(questions) do
        quizWaiter = { correct = q.answer, answered = false, result = false }
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'ampQuizShow',
            data = {
                index = i,
                total = #questions,
                question = q.q,
                options = q.options,
            },
        })

        local deadline = GetGameTimer() + interval
        while not quizWaiter.answered and GetGameTimer() < deadline do
            Wait(50)
        end

        if not quizWaiter.answered then
            wrong = wrong + 1
        elseif quizWaiter.result == false then
            wrong = wrong + 1
        end

        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'ampQuizHide' })
        quizWaiter = nil
        Wait(500)
    end

    return wrong
end

local quizWaiter = nil

RegisterNUICallback('ampQuizAnswer', function(data, cb)
    if quizWaiter then
        local choice = tonumber(data and data.choice)
        quizWaiter.result = (choice == quizWaiter.correct)
        quizWaiter.answered = true
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'ampQuizHide' })
    end
    cb('ok')
end)

local function startAmpSynthesis()
    if synthesizing then return end
    local cfg = ampCfg()
    if not cfg.enabled then
        return QBCore.Functions.Notify('Laboratorija išjungta.', 'error')
    end

    local veh = findNearbyJourney()
    if not veh then
        return QBCore.Functions.Notify('Reikia Zirconium Journey šalia laboratorijos.', 'error')
    end

    local vehNetId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:startAmpSynthesis', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Nepavyko pradėti.', 'error')
        end

        synthesizing = true
        local token = res.token
        local duration = res.durationMs or 72000
        local qCount = res.questionCount or 3

        SetVehicleEngineOn(veh, true, true, false)
        flareToken = flareToken + 1
        CreateThread(function()
            exhaustFlareLoop(veh, flareToken)
        end)

        QBCore.Functions.Notify('Sintezė pradėta — stebėk klausimus!', 'primary')

        local wrong = 0
        local quizDone = false
        CreateThread(function()
            wrong = runAmpQuizFixed(qCount, duration)
            quizDone = true
        end)

        DrugProgress.run('mrp_amp_synth', 'Amfetamino sintezė…', duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableCombat = true,
        }, nil, function()
            flareToken = flareToken + 1
            synthesizing = false
            while not quizDone do Wait(50) end
            TriggerServerEvent('mrp_drugs:server:finishAmpSynthesis', token, wrong, vehNetId)
        end, function()
            flareToken = flareToken + 1
            synthesizing = false
            TriggerServerEvent('mrp_drugs:server:cancelAmpSynthesis', token)
            QBCore.Functions.Notify('Sintezė atšaukta.', 'error')
        end)
    end, vehNetId)
end

RegisterNetEvent('mrp_drugs:client:ampLabExplode', function(vehNetId)
    vehNetId = tonumber(vehNetId)
    local veh = vehNetId and NetworkGetEntityFromNetworkId(vehNetId) or 0
    if veh == 0 or not DoesEntityExist(veh) then
        veh = findNearbyJourney()
    end
    if veh and DoesEntityExist(veh) then
        local c = GetEntityCoords(veh)
        AddExplosion(c.x, c.y, c.z, 2, 1.0, true, false, 1.0)
        SetEntityHealth(veh, 0)
        SetVehicleEngineHealth(veh, -4000.0)
        SetVehicleBodyHealth(veh, 0.0)
    end
end)

local function setupAmpLab()
    local cfg = ampCfg()
    if not cfg.enabled then return end
    local lab = cfg.lab
    if not lab or not lab.coords then return end

    exports['qb-target']:AddCircleZone('mrp_amp_lab', lab.coords, 2.2, {
        name = 'mrp_amp_lab',
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-flask',
                label = 'Pradėti amfetamino sintezę (Journey)',
                canInteract = function()
                    return not synthesizing and findNearbyJourney() ~= nil
                end,
                action = startAmpSynthesis,
            },
        },
        distance = 2.5,
    })
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(600)
    setupAmpLab()
end)

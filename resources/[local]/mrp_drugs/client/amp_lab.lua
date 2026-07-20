local QBCore = exports['qb-core']:GetCoreObject()

local synthesizing = false
local flareToken = 0
local quizWaiter = nil

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

    if type(NetworkGetEntityIsNetworked) == 'function' and not NetworkGetEntityIsNetworked(veh) then
        pcall(NetworkRegisterEntityAsNetworked, veh)
        local deadline = GetGameTimer() + 500
        while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < deadline do
            Wait(0)
        end
    end
    local vehNetId = 0
    if type(NetworkGetEntityIsNetworked) ~= 'function' or NetworkGetEntityIsNetworked(veh) then
        local ok, nid = pcall(NetworkGetNetworkIdFromEntity, veh)
        if ok then vehNetId = tonumber(nid) or 0 end
    end
    if vehNetId <= 0 then
        return QBCore.Functions.Notify('Mašina nėra sinchronizuota (išimk iš garažo / respawn).', 'error')
    end

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

local function ensureVehNetId(veh)
    if not veh or veh == 0 then return 0 end
    if type(NetworkGetEntityIsNetworked) == 'function' and not NetworkGetEntityIsNetworked(veh) then
        pcall(NetworkRegisterEntityAsNetworked, veh)
        local deadline = GetGameTimer() + 500
        while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < deadline do
            Wait(0)
        end
    end
    local ok, nid = pcall(NetworkGetNetworkIdFromEntity, veh)
    return (ok and tonumber(nid)) or 0
end

local function findClosestJourney(maxDist)
    maxDist = maxDist or (ampCfg().installDistance or 4.0)
    local p = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, maxDist + 0.01
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and isAmpVehicle(veh) then
            local d = #(GetEntityCoords(veh) - p)
            if d < bestD then
                best, bestD = veh, d
            end
        end
    end
    return best
end

local installing = false

local function installAmpPart(itemName)
    if installing or synthesizing then return end
    local veh = findClosestJourney()
    if not veh then
        return QBCore.Functions.Notify('Atsistok prie Zirconium Journey ir naudok modulį.', 'error')
    end
    local vehNetId = ensureVehNetId(veh)
    if vehNetId <= 0 then
        return QBCore.Functions.Notify('Mašina nėra sinchronizuota.', 'error')
    end

    installing = true
    local ms = tonumber(ampCfg().installMs) or 8500
    local label = (QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label) or itemName
    QBCore.Functions.Progressbar('amp_install_part', ('Montuojama: %s…'):format(label), ms, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_ped',
        flags = 49,
    }, {}, {}, function()
        QBCore.Functions.TriggerCallback('mrp_drugs:server:installAmpPart', function(res)
            installing = false
            if not res or not res.ok then
                return QBCore.Functions.Notify((res and res.reason) or 'Nepavyko sumontuoti.', 'error')
            end
            if res.complete then
                QBCore.Functions.Notify(('Laboratorija paruošta (%d/%d) — važiuok į Grapeseed zoną sintezei.'):format(res.done, res.total), 'success', 9000)
            else
                QBCore.Functions.Notify(('Sumontuota: %s (%d/%d)'):format(res.label or label, res.done or 0, res.total or 3), 'primary', 6000)
            end
        end, vehNetId, itemName)
    end, function()
        installing = false
        QBCore.Functions.Notify('Montavimas atšauktas.', 'error')
    end)
end

RegisterNetEvent('mrp_drugs:client:tryInstallAmpPart', function(itemName)
    installAmpPart(itemName)
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
            {
                icon = 'fas fa-clipboard-list',
                label = 'Patikrinti Journey lab statusą',
                canInteract = function()
                    return findNearbyJourney() ~= nil
                end,
                action = function()
                    local veh = findNearbyJourney()
                    local nid = ensureVehNetId(veh)
                    QBCore.Functions.TriggerCallback('mrp_drugs:server:getAmpLabStatus', function(res)
                        if not res or not res.ok then
                            return QBCore.Functions.Notify('Nepavyko patikrinti.', 'error')
                        end
                        if res.complete then
                            QBCore.Functions.Notify('Journey lab pilnai sumontuotas — galima sintezė.', 'success')
                        else
                            QBCore.Functions.Notify(('Trūksta modulių: %s'):format(table.concat(res.missing or {}, ', ')), 'error', 8000)
                        end
                    end, nid)
                end,
            },
        },
        distance = 2.5,
    })

    --- Target ant Journey modelių — montavimas / statusas bet kur
    local models = {}
    for name in pairs(cfg.vehicleModels or { journey = true }) do
        models[#models + 1] = name
    end
    if #models > 0 then
        exports['qb-target']:AddTargetModel(models, {
            options = {
                {
                    icon = 'fas fa-wrench',
                    label = 'Montuoti lab modulį (iš inventoriaus)',
                    canInteract = function(entity)
                        if installing or synthesizing then return false end
                        if not isAmpVehicle(entity) then return false end
                        for _, row in ipairs(cfg.requiredParts or {}) do
                            if QBCore.Functions.HasItem(row.item, 1) then return true end
                        end
                        return false
                    end,
                    action = function(entity)
                        for _, row in ipairs(cfg.requiredParts or {}) do
                            if QBCore.Functions.HasItem(row.item, 1) then
                                --- Prioritetas: dar nesumontuotas
                                local st = Entity(entity).state.mrpAmpLab
                                if type(st) ~= 'table' or st[row.id] ~= true then
                                    return installAmpPart(row.item)
                                end
                            end
                        end
                        for _, row in ipairs(cfg.requiredParts or {}) do
                            if QBCore.Functions.HasItem(row.item, 1) then
                                return installAmpPart(row.item)
                            end
                        end
                    end,
                },
            },
            distance = 2.8,
        })
    end

    local scrap = Config.AmpScrapYard
    if scrap and scrap.enabled and scrap.coords then
        exports['qb-target']:AddCircleZone('mrp_amp_scrap', scrap.coords, scrap.radius or 1.4, {
            name = 'mrp_amp_scrap',
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = 'fas fa-dumpster',
                    label = scrap.label or 'Ravėti atliekų dėžę',
                    action = function()
                        QBCore.Functions.Progressbar('amp_scrap', 'Ieškoma chemikalų…', 4500, false, true, {
                            disableMovement = true,
                            disableCombat = true,
                        }, {
                            animDict = 'amb@prop_human_bum_bin@base',
                            anim = 'base',
                            flags = 49,
                        }, {}, {}, function()
                            QBCore.Functions.TriggerCallback('mrp_drugs:server:ampScrapLoot', function(res)
                                if not res or not res.ok then
                                    return QBCore.Functions.Notify((res and res.reason) or 'Tuščia.', 'error')
                                end
                                if res.empty then
                                    return QBCore.Functions.Notify('Nieko naudingo nerasta.', 'primary')
                                end
                                QBCore.Functions.Notify('Radau naudingų chemikalų.', 'success')
                            end)
                        end, function()
                            QBCore.Functions.Notify('Atšaukta.', 'error')
                        end)
                    end,
                },
            },
            distance = 1.8,
        })
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(600)
    setupAmpLab()
end)

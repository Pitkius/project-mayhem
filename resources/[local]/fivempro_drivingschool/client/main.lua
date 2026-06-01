local QBCore = exports['qb-core']:GetCoreObject()

local schoolPed = nil
local theoryState = nil
local practicalState = nil

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(hash)
end

local function createBlip()
    local cfg = Config.Blip
    local c = Config.Location.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite or 498)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale or 0.85)
    SetBlipColour(blip, cfg.colour or 3)
    SetBlipAsShortRange(blip, true)
    exports['fivempro_fonts']:SetBlipName(blip, cfg.label or 'Vairavimo mokykla')
end

local function spawnSchoolPed()
    if schoolPed and DoesEntityExist(schoolPed) then return end
    local c = Config.Location.coords
    if not loadModel(Config.PedModel) then return end
    schoolPed = CreatePed(0, joaat(Config.PedModel), c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(schoolPed, true)
    SetBlockingOfNonTemporaryEvents(schoolPed, true)
    FreezeEntityPosition(schoolPed, true)
    if Config.PedScenario then
        TaskStartScenarioInPlace(schoolPed, Config.PedScenario, 0, true)
    end
    SetModelAsNoLongerNeeded(joaat(Config.PedModel))

    exports['qb-target']:AddTargetEntity(schoolPed, {
        options = {
            {
                icon = 'fas fa-id-card',
                label = 'Vairavimo mokykla',
                action = function()
                    TriggerEvent('fivempro_drivingschool:client:openMenu')
                end,
            },
        },
        distance = Config.TargetDistance or 2.5,
    })
end

local function cleanupPractical()
    if not practicalState then return end
    if practicalState.blip and DoesBlipExist(practicalState.blip) then
        RemoveBlip(practicalState.blip)
    end
    if practicalState.vehicle and DoesEntityExist(practicalState.vehicle) then
        SetEntityAsMissionEntity(practicalState.vehicle, true, true)
        DeleteVehicle(practicalState.vehicle)
    end
    practicalState = nil
end

local function failPractical(reason)
    if not practicalState then return end
    notify(reason or 'Praktinis egzaminas neišlaikytas.', 'error')
    TriggerServerEvent('fivempro_drivingschool:server:practicalResult', practicalState.category, false)
    cleanupPractical()
end

local function passPractical()
    if not practicalState then return end
    notify('Praktinis egzaminas išlaikytas!', 'success')
    TriggerServerEvent('fivempro_drivingschool:server:practicalResult', practicalState.category, true)
    cleanupPractical()
end

local function addPracticalError(reason)
    if not practicalState then return end
    practicalState.errors = practicalState.errors + 1
    notify(('%s (%s/%s klaidų)'):format(reason, practicalState.errors, Config.PracticalMaxErrors), 'error')
    if practicalState.errors > Config.PracticalMaxErrors then
        failPractical('Per daug klaidų — egzaminas nutrauktas.')
    end
end

local function updateCheckpointBlip()
    if not practicalState then return end
    if practicalState.blip and DoesBlipExist(practicalState.blip) then
        RemoveBlip(practicalState.blip)
    end
    local idx = practicalState.checkpoint
    local cp = Config.RouteCheckpoints[idx]
    if not cp then return end
    local blip = AddBlipForCoord(cp.x, cp.y, cp.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    exports['fivempro_fonts']:SetBlipName(blip, ('Egzaminas — taškas %s/%s'):format(idx, #Config.RouteCheckpoints))
    practicalState.blip = blip
end

local function drawCheckpointMarker()
    if not practicalState then return end
    local idx = practicalState.checkpoint
    local cp = Config.RouteCheckpoints[idx]
    if not cp then return end
    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        4.0, 4.0, 1.5, 50, 200, 50, 120, false, false, 2, false, nil, nil, false)
end

local function getSpeedLimit()
    if not practicalState then return 50 end
    local cat = Config.Categories[practicalState.category]
    local limits = cat and cat.routeSpeedLimits
    local idx = practicalState.checkpoint or 1
    if limits and limits[idx] then return limits[idx] end
    return cat and cat.speedLimitKmh or 50
end

local function startPracticalLoop()
    CreateThread(function()
        while practicalState do
            local ped = PlayerPedId()
            if not IsPedInVehicle(ped, practicalState.vehicle, false) then
                failPractical('Išlipote iš transporto — egzaminas nutrauktas.')
                break
            end
            if GetPedInVehicleSeat(practicalState.vehicle, -1) ~= ped then
                failPractical('Turite vairuoti patys.')
                break
            end
            if IsEntityDead(ped) or IsEntityDead(practicalState.vehicle) then
                failPractical('Egzaminas nutrauktas dėl avarijos.')
                break
            end

            drawCheckpointMarker()

            local limit = getSpeedLimit()
            SetTextFont(4)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 215)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString(('Egzaminas | Taškas %s/%s | Limitas %d km/h | Klaidos %s/%s'):format(
                practicalState.checkpoint, #Config.RouteCheckpoints, limit,
                practicalState.errors, Config.PracticalMaxErrors))
            DrawText(0.015, 0.88)

            local cp = Config.RouteCheckpoints[practicalState.checkpoint]
            if cp then
                local pos = GetEntityCoords(ped)
                if #(pos - cp) <= (Config.PracticalCheckpointRadius or 6.0) then
                    if practicalState.checkpoint >= #Config.RouteCheckpoints then
                        passPractical()
                        break
                    end
                    practicalState.checkpoint = practicalState.checkpoint + 1
                    notify(('Taškas pasiektas (%s/%s)'):format(
                        practicalState.checkpoint - 1, #Config.RouteCheckpoints), 'success')
                    updateCheckpointBlip()
                end
            end

            Wait(0)
        end
    end)

    CreateThread(function()
        while practicalState do
            local veh = practicalState.vehicle
            if veh and DoesEntityExist(veh) then
                local speedKmh = GetEntitySpeed(veh) * 3.6
                local limit = getSpeedLimit()
                local grace = Config.SpeedGraceKmh or 5
                if speedKmh > (limit + grace) then
                    practicalState.speedOverTime = (practicalState.speedOverTime or 0) + 0.25
                    if practicalState.speedOverTime >= (Config.SpeedViolationSeconds or 3.0) then
                        practicalState.speedOverTime = 0
                        addPracticalError(('Viršytas greitis (%d km/h, limitas %d)'):format(
                            math.floor(speedKmh + 0.5), limit))
                    end
                else
                    practicalState.speedOverTime = 0
                end

                local body = GetVehicleBodyHealth(veh)
                local engine = GetVehicleEngineHealth(veh)
                local prevBody = practicalState.lastBody or body
                local prevEngine = practicalState.lastEngine or engine
                if (prevBody - body) > 15.0 or (prevEngine - engine) > 25.0 then
                    addPracticalError('Susidūrimas arba kliudymas.')
                end
                practicalState.lastBody = body
                practicalState.lastEngine = engine
            end
            Wait(250)
        end
    end)
end

RegisterNetEvent('fivempro_drivingschool:client:startPractical', function(category)
    if practicalState then
        notify('Jau vyksta praktinis egzaminas.', 'error')
        return
    end

    local cat = Config.Categories[category]
    if not cat then return end

    local sp = Config.Location.vehicleSpawn
    if not loadModel(cat.vehicleModel) then
        notify('Egzamino transportas neprieinamas.', 'error')
        return
    end

    local veh = CreateVehicle(joaat(cat.vehicleModel), sp.x, sp.y, sp.z, sp.w, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'EGZAMIN')
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleEngineOn(veh, true, true, false)

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, veh, -1)

    practicalState = {
        category = category,
        vehicle = veh,
        checkpoint = 1,
        errors = 0,
        lastBody = GetVehicleBodyHealth(veh),
        lastEngine = GetVehicleEngineHealth(veh),
        speedOverTime = 0,
    }

    updateCheckpointBlip()
    notify(('Praktinis %s egzaminas prasidėjo. Laikykitės greičio limitų!'):format(cat.label), 'primary')
    startPracticalLoop()
end)

RegisterNetEvent('fivempro_drivingschool:client:openMenu', function()
    QBCore.Functions.TriggerCallback('fivempro_drivingschool:server:getLicenceStatus', function(status)
        status = status or {}
        local menu = {
            { header = 'Vairavimo mokykla', isMenuHeader = true },
            { header = 'Pasirinkite kategoriją', isMenuHeader = true },
        }

        for _, key in ipairs({ 'a', 'b', 'c' }) do
            local cat = Config.Categories[key]
            if cat then
                local owned = status[cat.licenceKey] == true
                if cat.licenceKeys then
                    for _, lk in ipairs(cat.licenceKeys) do
                        if status[lk] == true then owned = true break end
                    end
                end
                menu[#menu + 1] = {
                    header = ('%s %s'):format(cat.icon or '', cat.label),
                    txt = owned and 'Jau turite licenciją' or ('Egzaminas: $%s | Teorija 80%% + praktika'):format(cat.examPrice),
                    disabled = owned,
                    params = {
                        event = 'fivempro_drivingschool:client:confirmExam',
                        args = { category = key },
                    },
                }
            end
        end

        exports['qb-menu']:openMenu(menu)
    end)
end)

RegisterNetEvent('fivempro_drivingschool:client:showLicense', function(info)
    QBCore.Functions.TriggerCallback('fivempro_drivingschool:server:getLicenseCard', function(card)
        if not card then
            return notify('Nepavyko nuskaityti pažymėjimo.', 'error')
        end

        local lines = {}
        lines[#lines + 1] = {
            header = ('%s %s'):format(card.firstname or '', card.lastname or ''),
            isMenuHeader = true,
        }
        if card.birthdate and card.birthdate ~= '' then
            lines[#lines + 1] = { header = 'Gimimo data', txt = card.birthdate, isMenuHeader = true }
        end
        if card.citizenid then
            lines[#lines + 1] = { header = 'ID', txt = card.citizenid, isMenuHeader = true }
        end

        lines[#lines + 1] = { header = '— Turimos kategorijos —', isMenuHeader = true }

        if card.categories and #card.categories > 0 then
            for _, cat in ipairs(card.categories) do
                lines[#lines + 1] = {
                    header = ('%s %s'):format(cat.icon or '', cat.label or cat.id or ''),
                    txt = cat.licenceLabel or '',
                    isMenuHeader = true,
                }
            end
        else
            lines[#lines + 1] = {
                header = 'Nėra galiojančių kategorijų',
                txt = 'Laikyk egzaminus vairavimo mokykloje.',
                isMenuHeader = true,
            }
        end

        lines[#lines + 1] = { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } }

        if GetResourceState('qb-menu') == 'started' then
            exports['qb-menu']:openMenu(lines)
        else
            local summary = {}
            for _, cat in ipairs(card.categories or {}) do
                summary[#summary + 1] = cat.label or cat.id
            end
            notify(('%s %s | %s'):format(
                card.firstname or '',
                card.lastname or '',
                #summary > 0 and table.concat(summary, ', ') or 'be kategorijų'
            ), 'primary', 8000)
        end
    end)
end)

RegisterNetEvent('fivempro_drivingschool:client:confirmExam', function(data)
    local category = type(data) == 'table' and data.category or nil
    local cat = category and Config.Categories[category]
    if not cat then return end

    exports['qb-menu']:openMenu({
        { header = cat.label, isMenuHeader = true },
        {
            header = 'Pradėti egzaminą',
            txt = ('$%s — 20 klausimų (80%%) + praktinis važiavimas'):format(cat.examPrice),
            params = {
                event = 'fivempro_drivingschool:client:beginTheory',
                args = { category = category },
            },
        },
        {
            header = 'Atgal',
            params = { event = 'fivempro_drivingschool:client:openMenu' },
        },
    })
end)

RegisterNetEvent('fivempro_drivingschool:client:beginTheory', function(data)
    local category = type(data) == 'table' and data.category or nil
    if not category then return end
    if theoryState or practicalState then
        notify('Jau vyksta egzaminas.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('fivempro_drivingschool:server:startTheory', function(ok, payload, msg)
        if not ok then
            notify(msg or 'Negalima pradėti.', 'error')
            return
        end
        theoryState = {
            category = category,
            sessionId = payload.sessionId,
            questions = payload.questions,
            index = 1,
            total = payload.total,
        }
        TriggerEvent('fivempro_drivingschool:client:showTheoryQuestion')
    end, category)
end)

RegisterNetEvent('fivempro_drivingschool:client:showTheoryQuestion', function()
    if not theoryState then return end
    local q = theoryState.questions[theoryState.index]
    if not q then return end

    local menu = {
        {
            header = ('Teorija %s/%s'):format(theoryState.index, theoryState.total),
            isMenuHeader = true,
        },
        { header = q.q, isMenuHeader = true },
    }

    for ai, ans in ipairs(q.answers) do
        menu[#menu + 1] = {
            header = ans,
            params = {
                event = 'fivempro_drivingschool:client:theoryPick',
                args = { chosen = ai },
            },
        }
    end

    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_drivingschool:client:theoryPick', function(data)
    if not theoryState then return end
    local chosen = type(data) == 'table' and data.chosen or nil
    if not chosen then return end

    QBCore.Functions.TriggerCallback('fivempro_drivingschool:server:submitTheoryAnswer', function(result)
        if not result or not theoryState then return end

        if result.done then
            local cat = theoryState.category
            theoryState = nil
            if result.passed then
                notify(('Teorija išlaikyta (%s/%s teisingų)! Pradedamas praktinis egzaminas.'):format(
                    result.score, result.total), 'success')
                TriggerEvent('fivempro_drivingschool:client:startPractical', cat)
            else
                notify(('Teorija neišlaikyta (%s/%s). Reikia bent %s%%.'):format(
                    result.score, result.total, Config.TheoryPassPercent), 'error')
            end
            return
        end

        theoryState.index = result.index or (theoryState.index + 1)
        TriggerEvent('fivempro_drivingschool:client:showTheoryQuestion')
    end, theoryState.sessionId, chosen)
end)

CreateThread(function()
    Wait(1500)
    createBlip()
    spawnSchoolPed()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupPractical()
    if schoolPed and DoesEntityExist(schoolPed) then
        DeleteEntity(schoolPed)
    end
end)

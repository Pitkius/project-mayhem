local QBCore = exports['qb-core']:GetCoreObject()

local polePeds = {}
local targetsAdded = false
local sitting = false

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    return true
end

local function loadDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function applyStripperLook(ped, cfg)
    if cfg.components then
        for _, c in ipairs(cfg.components) do
            SetPedComponentVariation(ped, c[1], c[2], c[3] or 0, 0)
        end
    end
end

local function playPoleDance(ped, poleIndex)
    local anims = Config.PoleAnims or {}
    if #anims == 0 then return end
    local a = anims[((poleIndex - 1) % #anims) + 1]
    if not a or not loadDict(a.dict) then return end

    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(150)
    FreezeEntityPosition(ped, true)

    CreateThread(function()
        while DoesEntityExist(ped) do
            Wait(1000)
            if not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then
                if loadDict(a.dict) then
                    TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
                end
            end
        end
    end)
end

local function clearPolePeds()
    for _, ped in ipairs(polePeds) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    polePeds = {}
end

local function spawnPoleDancers()
    if #polePeds > 0 then return end
    local poles = Config.Poles or {}
    for i, pole in ipairs(poles) do
        local cfg = Config.Strippers[((i - 1) % #(Config.Strippers or {})) + 1] or Config.Strippers[1]
        if not cfg then break end
        if not loadModel(cfg.model) then goto continue end
        local c = pole.coords
        local ped = CreatePed(4, cfg.model, c.x, c.y, c.z, pole.heading or 0.0, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityInvincible(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedCanPlayAmbientAnims(ped, false)
        SetPedCanPlayAmbientBaseAnims(ped, false)
        applyStripperLook(ped, cfg)
        playPoleDance(ped, i)
        polePeds[#polePeds + 1] = ped
        SetModelAsNoLongerNeeded(cfg.model)

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_stripclub:client:menuLapFromPole',
                    icon = 'fas fa-heart',
                    label = ('Privatus šokis su %s'):format(cfg.name or 'šokėja'),
                    stripperIndex = ((i - 1) % #(Config.Strippers or {})) + 1,
                },
            },
            distance = 2.0,
        })
        ::continue::
    end
end

local function sitOnChair(coords4)
    if sitting or (IsLapDanceActive and IsLapDanceActive()) then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    sitting = true
    local scenario = Config.WatchScenario or 'PROP_HUMAN_SEAT_STRIP_WATCH'

    ClearPedTasksImmediately(ped)
    RequestCollisionAtCoord(coords4.x, coords4.y, coords4.z)
    SetEntityCoordsNoOffset(ped, coords4.x, coords4.y, coords4.z - 0.48, false, false, false)
    SetEntityHeading(ped, coords4.w)
    FreezeEntityPosition(ped, true)

    TaskStartScenarioAtPosition(ped, scenario, coords4.x, coords4.y, coords4.z - 0.48, coords4.w, -1, true, true)

    QBCore.Functions.Notify('Atsistok su ESC.', 'primary')

    CreateThread(function()
        local started = GetGameTimer() + 2500
        while sitting and GetGameTimer() < started do
            if IsPedUsingScenario(ped, scenario) or IsPedActiveInScenario(ped) then
                break
            end
            Wait(50)
        end

        while sitting do
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                sitting = false
                break
            end
            if not IsPedUsingScenario(ped, scenario) and not IsPedActiveInScenario(ped) then
                TaskStartScenarioAtPosition(ped, scenario, coords4.x, coords4.y, coords4.z - 0.48, coords4.w, -1, true, true)
            end
            Wait(200)
        end

        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end)
end

local function addTargets()
    if targetsAdded then return end
    if GetResourceState('qb-target') ~= 'started' then return end
    targetsAdded = true

    for _, seat in ipairs(Config.LapSeats or {}) do
        local zoneName = ('vu_lap_%s'):format(seat.id)
        exports['qb-target']:AddCircleZone(zoneName, seat.target, 0.85, {
            name = zoneName,
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_stripclub:client:menuLapSeat',
                    icon = 'fas fa-chair',
                    label = ('Privatus šokis — %s ($%s)'):format(seat.label or 'VIP', Config.Prices.lapDance or 120),
                    seatId = seat.id,
                },
            },
            distance = 2.0,
        })
    end

    for i, chair in ipairs(Config.WatchChairs or {}) do
        local zoneName = ('vu_chair_%s'):format(i)
        exports['qb-target']:AddCircleZone(zoneName, vector3(chair.x, chair.y, chair.z), 0.55, {
            name = zoneName,
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_stripclub:client:sitChair',
                    icon = 'fas fa-couch',
                    label = 'Atsisėsti ir žiūrėti',
                    chairIndex = i,
                },
            },
            distance = 1.8,
        })
    end

    for i, lean in ipairs(Config.LeanSpots or {}) do
        local zoneName = ('vu_lean_%s'):format(i)
        exports['qb-target']:AddCircleZone(zoneName, lean.coords, 0.9, {
            name = zoneName,
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_stripclub:client:leanBar',
                    icon = 'fas fa-dollar-sign',
                    label = ('Pritilti prie baro ($%s)'):format(Config.Prices.throwCash or 40),
                    leanHeading = lean.heading,
                },
            },
            distance = 2.0,
        })
    end
end

local function removeTargets()
    if not targetsAdded then return end
    for _, seat in ipairs(Config.LapSeats or {}) do
        exports['qb-target']:RemoveZone(('vu_lap_%s'):format(seat.id))
    end
    for i = 1, #(Config.WatchChairs or {}) do
        exports['qb-target']:RemoveZone(('vu_chair_%s'):format(i))
    end
    for i = 1, #(Config.LeanSpots or {}) do
        exports['qb-target']:RemoveZone(('vu_lean_%s'):format(i))
    end
    targetsAdded = false
end

CreateThread(function()
    local blip = Config.Blip
    if blip and blip.enabled then
        local b = AddBlipForCoord(blip.coords.x, blip.coords.y, blip.coords.z)
        SetBlipSprite(b, blip.sprite or 121)
        SetBlipColour(b, blip.color or 48)
        SetBlipScale(b, blip.scale or 0.75)
        SetBlipAsShortRange(b, true)
        if GetResourceState('fivempro_fonts') == 'started' then
            exports['fivempro_fonts']:SetBlipName(b, blip.label or 'Strip Club')
        else
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(blip.label or 'Strip Club')
            EndTextCommandSetBlipName(b)
        end
    end

    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local center = Config.Club and Config.Club.center or vector3(115.0, -1293.0, 28.27)
    local radius = (Config.Club and Config.Club.spawnRadius) or 45.0

    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - center)
        if dist < radius then
            spawnPoleDancers()
            addTargets()
            Wait(1500)
        else
            clearPolePeds()
            removeTargets()
            Wait(2000)
        end
    end
end)

RegisterNetEvent('fivempro_stripclub:client:menuLapSeat', function(data)
    local seatId = data and data.seatId
    if not seatId then return end

    local menu = {
        { header = 'Privatus šokis', isMenuHeader = true },
    }
    for i, s in ipairs(Config.Strippers or {}) do
        menu[#menu + 1] = {
            header = s.name or ('Šokėja ' .. i),
            txt = ('$%s · VIP sofa'):format(Config.Prices.lapDance or 120),
            params = {
                event = 'fivempro_stripclub:client:startLap',
                args = { seatId = seatId, stripperIndex = i },
            },
        }
    end
    menu[#menu + 1] = { header = 'Atšaukti', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_stripclub:client:menuLapFromPole', function(data)
    local stripperIndex = data and data.stripperIndex or 1
    local menu = {
        { header = 'Pasirink VIP vietą', isMenuHeader = true },
    }
    for _, seat in ipairs(Config.LapSeats or {}) do
        menu[#menu + 1] = {
            header = seat.label or ('Sofa ' .. seat.id),
            txt = ('$%s'):format(Config.Prices.lapDance or 120),
            params = {
                event = 'fivempro_stripclub:client:startLap',
                args = { seatId = seat.id, stripperIndex = stripperIndex },
            },
        }
    end
    menu[#menu + 1] = { header = 'Atšaukti', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_stripclub:client:startLap', function(args)
    if not args or args.seatId == nil then return end
    StartLapDance(tonumber(args.seatId), tonumber(args.stripperIndex) or 1)
end)

RegisterNetEvent('fivempro_stripclub:client:sitChair', function(data)
    local idx = data and tonumber(data.chairIndex)
    local chair = idx and Config.WatchChairs[idx]
    if chair then sitOnChair(chair) end
end)

RegisterNetEvent('fivempro_stripclub:client:leanBar', function(data)
    local heading = data and data.leanHeading
    if heading then StartLeanThrow(heading + 0.0) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearPolePeds()
    removeTargets()
    if StopLapDance then StopLapDance() end
end)

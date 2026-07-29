local QBCore = exports['qb-core']:GetCoreObject()

local polePeds = {}
local poleMeta = {} -- ped -> { index, name, tipBusy }
local targetsAdded = false
local sitting = false
local tipCooldownUntil = 0

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    return true
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasAnimDictLoaded(dict)
end

local function applyStripperLook(ped, cfg)
    if cfg.components then
        for _, c in ipairs(cfg.components) do
            SetPedComponentVariation(ped, c[1], c[2], c[3] or 0, 0)
        end
    end
end

--- Spawn cash note / pile briefly (vanilla tip feel)
local function spawnCashPropAt(coords, modelName, lifetimeMs)
    CreateThread(function()
        local model = joaat(modelName or Config.CashProp or 'prop_anim_cash_note')
        if not loadModel(model) then return end
        local obj = CreateObject(model, coords.x, coords.y, coords.z + 0.05, false, false, false)
        SetEntityAsMissionEntity(obj, true, true)
        PlaceObjectOnGroundProperly(obj)
        SetEntityCollision(obj, false, false)
        FreezeEntityPosition(obj, true)
        SetModelAsNoLongerNeeded(model)
        Wait(lifetimeMs or 2500)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end)
end

local function throwCashToward(fromPed, toCoords)
    CreateThread(function()
        local model = joaat(Config.CashProp or 'prop_anim_cash_note')
        if not loadModel(model) then return end
        local bone = GetPedBoneIndex(fromPed, 28422) -- right hand
        local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(obj, fromPed, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        Wait(400)
        DetachEntity(obj, true, true)
        local start = GetEntityCoords(fromPed)
        local dir = toCoords - start
        local len = #dir
        if len < 0.01 then len = 1.0 end
        dir = dir / len
        SetEntityVelocity(obj, dir.x * 4.5, dir.y * 4.5, 1.8)
        SetEntityCollision(obj, true, true)
        Wait(1800)
        if DoesEntityExist(obj) then
            local c = GetEntityCoords(obj)
            DeleteEntity(obj)
            spawnCashPropAt(c, Config.CashPileProp or 'prop_cash_pile_01', 3500)
        end
        SetModelAsNoLongerNeeded(model)
    end)
end

local function playPoleDance(ped, poleIndex)
    local anims = Config.PoleAnims or {}
    if #anims == 0 then return end

    CreateThread(function()
        local rotateMs = tonumber(Config.PoleAnimRotateMs) or 45000
        local idx = ((poleIndex - 1) % #anims) + 1
        while DoesEntityExist(ped) do
            local a = anims[idx]
            if a and loadDict(a.dict) then
                FreezeEntityPosition(ped, false)
                ClearPedTasksImmediately(ped)
                TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
                Wait(150)
                FreezeEntityPosition(ped, true)

                local untilMs = GetGameTimer() + rotateMs
                while DoesEntityExist(ped) and GetGameTimer() < untilMs do
                    if not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then
                        if loadDict(a.dict) then
                            TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
                        end
                    end
                    Wait(1000)
                end
            else
                Wait(2000)
            end
            idx = (idx % #anims) + 1
        end
    end)
end

local function clearPolePeds()
    for _, ped in ipairs(polePeds) do
        if ped and DoesEntityExist(ped) then
            if GetResourceState('qb-target') == 'started' then
                pcall(function()
                    exports['qb-target']:RemoveTargetEntity(ped)
                end)
            end
            DeleteEntity(ped)
        end
    end
    polePeds = {}
    poleMeta = {}
end

local function tipDancer(ped)
    if not ped or not DoesEntityExist(ped) then return end
    if GetGameTimer() < tipCooldownUntil then
        return QBCore.Functions.Notify('Palauk truputį prieš kitą tipą.', 'error')
    end
    local meta = poleMeta[ped]
    if meta and meta.tipBusy then return end
    if meta then meta.tipBusy = true end

    QBCore.Functions.TriggerCallback('mrp_stripclub:server:tryPay', function(res)
        if meta then meta.tipBusy = false end
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.msg or 'Nepakanka grynųjų.', 'error')
        end

        tipCooldownUntil = GetGameTimer() + 2500
        local player = PlayerPedId()
        local to = GetEntityCoords(ped)
        throwCashToward(player, to)

        if loadDict('mp_common') then
            TaskPlayAnim(player, 'mp_common', 'givetake1_a', 8.0, -8.0, 1200, 48, 0, false, false, false)
        end

        local name = (meta and meta.name) or 'Šokėja'
        QBCore.Functions.Notify(('%s dėkoja už $%s tipą.'):format(name, res.price or Config.Prices.tipDancer or 25), 'success')
    end, 'tip', 0)
end

local function spawnPoleDancers()
    if #polePeds > 0 then return end
    local poles = Config.Poles or {}
    for i, pole in ipairs(poles) do
        local cfg = Config.Strippers[((i - 1) % #(Config.Strippers or {})) + 1] or Config.Strippers[1]
        if not cfg then break end
        if not loadModel(cfg.model) then goto continue end
        local c = pole.coords
        -- Networked so other players see the same stage energy; still local-owned
        local ped = CreatePed(4, cfg.model, c.x, c.y, c.z, pole.heading or 0.0, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityInvincible(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedCanBeTargetted(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedCanPlayAmbientAnims(ped, false)
        SetPedCanPlayAmbientBaseAnims(ped, false)
        SetEntityCollision(ped, true, true)
        applyStripperLook(ped, cfg)
        playPoleDance(ped, i)
        polePeds[#polePeds + 1] = ped
        poleMeta[ped] = {
            index = i,
            stripperIndex = ((i - 1) % #(Config.Strippers or {})) + 1,
            name = cfg.name or 'Šokėja',
            tipBusy = false,
        }
        SetModelAsNoLongerNeeded(cfg.model)

        local tipPrice = Config.Prices.tipDancer or 25
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_stripclub:client:tipDancer',
                    icon = 'fas fa-dollar-sign',
                    label = ('Duoti tipą %s ($%s)'):format(cfg.name or 'šokėjai', tipPrice),
                    pedNet = PedToNet(ped),
                    canInteract = function(entity)
                        return entity == ped and DoesEntityExist(ped)
                    end,
                },
                {
                    type = 'client',
                    event = 'mrp_stripclub:client:menuLapFromPole',
                    icon = 'fas fa-heart',
                    label = ('Privatus šokis su %s'):format(cfg.name or 'šokėja'),
                    stripperIndex = ((i - 1) % #(Config.Strippers or {})) + 1,
                },
            },
            distance = 2.5,
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
    local zOff = tonumber(Config.WatchSitZOffset) or -0.52
    local sx, sy, sz = coords4.x, coords4.y, coords4.z + zOff

    ClearPedTasksImmediately(ped)
    RequestCollisionAtCoord(coords4.x, coords4.y, coords4.z)
    Wait(50)
    SetEntityCoordsNoOffset(ped, sx, sy, sz, false, false, false)
    SetEntityHeading(ped, coords4.w)
    FreezeEntityPosition(ped, true)

    -- playEnterAnim = true for proper sit-down like vanilla VU
    TaskStartScenarioAtPosition(ped, scenario, sx, sy, sz, coords4.w, 0, true, true)

    QBCore.Functions.Notify('Atsistok su ESC / Backspace.', 'primary')

    CreateThread(function()
        local started = GetGameTimer() + 3500
        while sitting and GetGameTimer() < started do
            if IsPedUsingScenario(ped, scenario) or IsPedActiveInScenario(ped) then
                break
            end
            Wait(50)
        end

        while sitting do
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 22, true)
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) or IsControlJustPressed(0, 73) then
                sitting = false
                break
            end
            if not IsPedUsingScenario(ped, scenario) and not IsPedActiveInScenario(ped) then
                TaskStartScenarioAtPosition(ped, scenario, sx, sy, sz, coords4.w, 0, true, true)
            end
            Wait(0)
        end

        FreezeEntityPosition(ped, false)
        ClearPedTasksImmediately(ped)
        -- Stand slightly in front of chair
        local rad = math.rad(coords4.w)
        SetEntityCoordsNoOffset(ped, coords4.x - math.sin(rad) * 0.55, coords4.y + math.cos(rad) * 0.55, coords4.z, false, false, false)
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
                    event = 'mrp_stripclub:client:menuLapSeat',
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
                    event = 'mrp_stripclub:client:sitChair',
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
                    event = 'mrp_stripclub:client:leanBar',
                    icon = 'fas fa-dollar-sign',
                    label = ('Pritilti prie baro ($%s)'):format(Config.Prices.throwCash or 40),
                    leanHeading = lean.heading,
                    leanCoords = lean.coords,
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
        if GetResourceState('mrp_fonts') == 'started' then
            exports['mrp_fonts']:SetBlipName(b, blip.label or 'Strip Club')
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

RegisterNetEvent('mrp_stripclub:client:tipDancer', function(data)
    local ped = data and data.entity
    if (not ped or ped == 0) and data and data.pedNet then
        ped = NetToPed(data.pedNet)
    end
    -- qb-target often passes entity in data.entity
    if not ped or ped == 0 then
        -- find nearest pole ped
        local pcoords = GetEntityCoords(PlayerPedId())
        local best, bestD = nil, 3.0
        for _, p in ipairs(polePeds) do
            if DoesEntityExist(p) then
                local d = #(GetEntityCoords(p) - pcoords)
                if d < bestD then best, bestD = p, d end
            end
        end
        ped = best
    end
    tipDancer(ped)
end)

RegisterNetEvent('mrp_stripclub:client:menuLapSeat', function(data)
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
                event = 'mrp_stripclub:client:startLap',
                args = { seatId = seatId, stripperIndex = i },
            },
        }
    end
    menu[#menu + 1] = { header = 'Atšaukti', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('mrp_stripclub:client:menuLapFromPole', function(data)
    local stripperIndex = data and data.stripperIndex or 1
    local menu = {
        { header = 'Pasirink VIP vietą', isMenuHeader = true },
    }
    for _, seat in ipairs(Config.LapSeats or {}) do
        menu[#menu + 1] = {
            header = seat.label or ('Sofa ' .. seat.id),
            txt = ('$%s'):format(Config.Prices.lapDance or 120),
            params = {
                event = 'mrp_stripclub:client:startLap',
                args = { seatId = seat.id, stripperIndex = stripperIndex },
            },
        }
    end
    menu[#menu + 1] = { header = 'Atšaukti', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('mrp_stripclub:client:startLap', function(args)
    if not args or args.seatId == nil then return end
    StartLapDance(tonumber(args.seatId), tonumber(args.stripperIndex) or 1)
end)

RegisterNetEvent('mrp_stripclub:client:sitChair', function(data)
    local idx = data and tonumber(data.chairIndex)
    local chair = idx and Config.WatchChairs[idx]
    if chair then sitOnChair(chair) end
end)

RegisterNetEvent('mrp_stripclub:client:leanBar', function(data)
    local heading = data and data.leanHeading
    local coords = data and data.leanCoords
    if heading then StartLeanThrow(heading + 0.0, coords) end
end)

--- Shared cash throw for lapdance lean
function StripClubThrowCashProp(fromPed, toCoords)
    throwCashToward(fromPed, toCoords)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearPolePeds()
    removeTargets()
    if StopLapDance then StopLapDance() end
end)

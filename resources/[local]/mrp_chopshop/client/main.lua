local QBCore = exports['qb-core']:GetCoreObject()

local buyerPeds = {}
local scrapNpcPeds = {}
local scrapBusy = false
local activeScrapVeh = nil
local scrapProgress = nil -- { startedAt, durationMs, label }

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function drawText3D(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function drawScrapProgressBar(coords, ratio, label, remainSec)
    ratio = math.max(0.0, math.min(1.0, ratio or 0.0))
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 1.15)
    if not onScreen then return end

    local w, h = 0.14, 0.016
    local x, y = sx, sy
    DrawRect(x, y, w, h, 20, 20, 20, 180)
    DrawRect(x - w / 2 + (w * ratio) / 2, y, w * ratio, h - 0.004, 220, 80, 60, 220)

    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('%s · %ds'):format(label or 'Ardoma', remainSec or 0))
    EndTextCommandDisplayText(x, y - 0.028)
end

local function getVehicleInZone(location)
    local ped = PlayerPedId()
    local radius = tonumber(location.zoneRadius) or 18.0

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and #(GetEntityCoords(veh) - location.coords) <= radius then
            return veh
        end
    end

    local closest, closestDist = nil, radius + 1.0
    local pool = GetGamePool('CVehicle')
    for i = 1, #pool do
        local veh = pool[i]
        if DoesEntityExist(veh) and not IsPedAPlayer(GetPedInVehicleSeat(veh, -1)) then
            local dist = #(GetEntityCoords(veh) - location.coords)
            if dist <= radius and dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
    end
    return closest
end

local function resolveVehicleModel(veh)
    if not veh or veh == 0 then return 'sultan' end
    local model = GetEntityModel(veh)
    for name, data in pairs(QBCore.Shared.Vehicles or {}) do
        if data.hash == model or joaat(name) == model then
            return name
        end
    end
    return 'sultan'
end

local function estimateNpcValue(veh)
    local model = resolveVehicleModel(veh)
    local shared = QBCore.Shared.Vehicles[model]
    if shared and shared.price then
        return math.max(15000, math.floor(tonumber(shared.price) or 25000))
    end
    return 25000
end

local function isNpcVehicle(veh)
    if GetResourceState('mrp_basics') == 'started' then
        local ok, isNpc = pcall(function()
            return exports['mrp_basics']:IsNaturalNpcVehicle(veh)
        end)
        if ok and isNpc then return true end
    end
    return not NetworkGetEntityIsNetworked(veh)
end

local function deleteVehicleEntity(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetEntityAsMissionEntity(veh, true, true)
    local tries = 0
    while not NetworkHasControlOfEntity(veh) and tries < 40 do
        NetworkRequestControlOfEntity(veh)
        Wait(0)
        tries = tries + 1
    end
    SetVehicleAsNoLongerNeeded(veh)
    DeleteVehicle(veh)
    if DoesEntityExist(veh) then DeleteEntity(veh) end
end

--- Užrakina mašiną ardymo metu — niekas neįlipa / nevažiuoja.
local function lockVehicleForScrap(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local tries = 0
    while not NetworkHasControlOfEntity(veh) and tries < 40 do
        NetworkRequestControlOfEntity(veh)
        Wait(0)
        tries = tries + 1
    end

    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)) or 4
    for seat = -1, maxSeats - 2 do
        local occupant = GetPedInVehicleSeat(veh, seat)
        if occupant and occupant ~= 0 then
            TaskLeaveVehicle(occupant, veh, 16)
        end
    end
    Wait(600)

    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleUndriveable(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDoorsLockedForAllPlayers(veh, true)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleHandbrake(veh, true)
end

local function unlockVehicleAfterCancel(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    FreezeEntityPosition(veh, false)
    SetEntityInvincible(veh, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    SetVehicleHandbrake(veh, false)
end

local function runScrapProgress(ms, label, veh)
    ms = math.max(1000, tonumber(ms) or 45000)
    label = label or 'Ardoma transporto priemonė…'
    scrapProgress = {
        startedAt = GetGameTimer(),
        durationMs = ms,
        label = label,
        veh = veh,
    }

    CreateThread(function()
        while scrapProgress do
            local prog = scrapProgress
            local vehRef = prog.veh
            if vehRef and DoesEntityExist(vehRef) then
                -- Blokuoti bandymus įlipti / vairuoti
                SetVehicleDoorsLocked(vehRef, 2)
                SetVehicleDoorsLockedForAllPlayers(vehRef, true)
                SetVehicleUndriveable(vehRef, true)
                FreezeEntityPosition(vehRef, true)
                local ped = PlayerPedId()
                if IsPedInVehicle(ped, vehRef, false) then
                    TaskLeaveVehicle(ped, vehRef, 16)
                end
                local elapsed = GetGameTimer() - prog.startedAt
                local ratio = math.min(1.0, elapsed / prog.durationMs)
                local remain = math.max(0, math.ceil((prog.durationMs - elapsed) / 1000))
                drawScrapProgressBar(GetEntityCoords(vehRef), ratio, prog.label, remain)
            end
            Wait(0)
        end
    end)

    if GetResourceState('progressbar') == 'started' then
        local finished, cancelled = false, false
        QBCore.Functions.Progressbar('mrp_chopshop_scrap', label, ms, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableCombat = true,
        }, {
            animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            anim = 'machinic_loop_mechandplayer',
            flags = 16,
        }, {}, {}, function()
            finished = true
        end, function()
            cancelled = true
        end)
        local deadline = GetGameTimer() + ms + 1500
        while GetGameTimer() < deadline do
            if cancelled then
                scrapProgress = nil
                return false
            end
            if finished then
                scrapProgress = nil
                return true
            end
            Wait(50)
        end
        scrapProgress = nil
        return finished
    end

    notify(label, 'primary')
    local started = GetGameTimer()
    while GetGameTimer() - started < ms do
        Wait(100)
    end
    scrapProgress = nil
    return true
end

local function startScrapAtLocation(location)
    if scrapBusy then return end

    local veh = getVehicleInZone(location)
    if not veh or veh == 0 then
        return notify('Pastatyk transportą ardymo zonoje', 'error')
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    if plate == '' then plate = ('NPC%04d'):format(math.random(1000, 9999)) end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    scrapBusy = true
    activeScrapVeh = veh

    QBCore.Functions.TriggerCallback('mrp_chopshop:server:canScrap', function(res)
        if not res or not res.ok then
            scrapBusy = false
            activeScrapVeh = nil
            return notify((res and res.message) or 'Negalima ardyti', 'error')
        end

        if not DoesEntityExist(veh) then
            scrapBusy = false
            activeScrapVeh = nil
            return notify('Transportas dingęs', 'error')
        end

        lockVehicleForScrap(veh)
        TriggerServerEvent('mrp_chopshop:server:lockVehicle', netId, plate)

        local model = res.model or resolveVehicleModel(veh)
        local vehicleValue = res.vehicleValue or estimateNpcValue(veh)
        if not res.isOwned and isNpcVehicle(veh) then
            vehicleValue = estimateNpcValue(veh)
        end

        TriggerServerEvent('mrp_chopshop:server:beginScrap', {
            locationId = location.id,
            plate = plate,
            scrapMs = res.scrapMs,
            netId = netId,
        })

        local ok = runScrapProgress(
            res.scrapMs,
            ('Ardoma (%s)…'):format(res.tierLabel or 'Paprasta'),
            veh
        )
        if not ok then
            TriggerServerEvent('mrp_chopshop:server:cancelScrap', netId, plate)
            unlockVehicleAfterCancel(veh)
            scrapBusy = false
            activeScrapVeh = nil
            return notify('Ardymas nutrauktas', 'error')
        end

        TriggerServerEvent('mrp_chopshop:server:completeScrap', {
            locationId = location.id,
            plate = plate,
            netId = netId,
            model = model,
            vehicleValue = vehicleValue,
        })
        scrapBusy = false
        activeScrapVeh = nil
    end, plate, location.id, netId)
end

RegisterNetEvent('mrp_chopshop:client:deleteVehicle', function(netId, plate)
    local veh = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then
        local pool = GetGamePool('CVehicle')
        plate = normalizePlate(plate)
        for i = 1, #pool do
            local v = pool[i]
            if DoesEntityExist(v) and normalizePlate(GetVehicleNumberPlateText(v)) == plate then
                veh = v
                break
            end
        end
    end
    deleteVehicleEntity(veh)
end)

--- Kiti klientai: mašina ardoma — užrakinti / neišvažiuoti
RegisterNetEvent('mrp_chopshop:client:applyScrapLock', function(netId, plate, locked)
    local veh = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if (veh == 0 or not DoesEntityExist(veh)) and plate then
        plate = normalizePlate(plate)
        for _, v in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(v) and normalizePlate(GetVehicleNumberPlateText(v)) == plate then
                veh = v
                break
            end
        end
    end
    if veh == 0 or not DoesEntityExist(veh) then return end
    if locked then
        local ped = PlayerPedId()
        if IsPedInVehicle(ped, veh, false) then
            TaskLeaveVehicle(ped, veh, 16)
        end
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleUndriveable(veh, true)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleDoorsLockedForAllPlayers(veh, true)
        FreezeEntityPosition(veh, true)
    else
        unlockVehicleAfterCancel(veh)
    end
end)

local function openBuyerMenu(locationId)
    QBCore.Functions.TriggerCallback('mrp_chopshop:server:getSellInventory', function(res)
        if not res or not res.ok then
            return notify((res and res.message) or 'Klaida', 'error')
        end
        if not res.items or #res.items == 0 then
            return notify('Neturi dalių pardavimui', 'error')
        end

        local menu = {
            { header = 'Laužo supirkėjas', isMenuHeader = true },
        }
        for _, row in ipairs(res.items) do
            menu[#menu + 1] = {
                header = ('%s x%d'):format(row.label, row.count),
                txt = ('$%d / vnt.'):format(row.unitPrice),
                params = {
                    isAction = true,
                    event = function()
                        TriggerServerEvent('mrp_chopshop:server:sellPart', row.item, locationId)
                    end,
                },
            }
        end
        menu[#menu + 1] = {
            header = ('Parduoti viską ($%d)'):format(res.grandTotal or 0),
            txt = 'Nešvarūs pinigai',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_chopshop:server:sellAllParts', locationId)
                end,
            },
        }
        menu[#menu + 1] = { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } }
        exports['qb-menu']:openMenu(menu)
    end)
end

local function spawnPedAt(coords, modelName, scenario)
    local model = joaat(modelName or 's_m_y_construct_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function spawnBuyerPed(location)
    local b = location.buyer
    if not b then return end

    local ped = spawnPedAt(b.coords, b.model, b.scenario)
    buyerPeds[location.id] = ped

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = 'fas fa-recycle',
                label = b.label or 'Parduoti dalis',
                action = function()
                    openBuyerMenu(location.id)
                end,
            },
        },
        distance = Config.ChopShop.targetDistance or 3.0,
    })
end

local function spawnScrapNpc(location)
    local n = location.scrapNpc
    if not n then return end

    local ped = spawnPedAt(n.coords, n.model, n.scenario)
    scrapNpcPeds[location.id] = ped

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = 'fas fa-car-crash',
                label = n.label or 'Atiduoti mašiną detalėms',
                action = function()
                    startScrapAtLocation(location)
                end,
            },
        },
        distance = Config.ChopShop.targetDistance or 3.0,
    })
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end

    local cfg = Config.ChopShop or {}
    for _, loc in ipairs(cfg.locations or {}) do
        local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
        SetBlipSprite(blip, cfg.blipSprite or 643)
        SetBlipColour(blip, cfg.blipColor or 1)
        SetBlipScale(blip, cfg.blipScale or 0.85)
        SetBlipAsShortRange(blip, true)
        if GetResourceState('mrp_fonts') == 'started' then
            exports['mrp_fonts']:SetBlipName(blip, loc.label or 'Ardymo aikštelė')
        else
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(loc.label or 'Ardymo aikštelė')
            EndTextCommandSetBlipName(blip)
        end

        -- Zona lieka kaip atsarginė (be NPC), pagrindinis kelias — scrapNpc
        exports['qb-target']:AddBoxZone(('mrp_chopshop_%s'):format(loc.id), loc.coords, 4.0, 4.0, {
            name = ('mrp_chopshop_%s'):format(loc.id),
            heading = loc.heading or 0.0,
            debugPoly = false,
            minZ = loc.coords.z - 2.0,
            maxZ = loc.coords.z + 3.0,
        }, {
            options = {
                {
                    icon = 'fas fa-car-crash',
                    label = 'Ardyti transportą',
                    action = function()
                        startScrapAtLocation(loc)
                    end,
                },
            },
            distance = cfg.targetDistance or 3.0,
        })

        spawnScrapNpc(loc)
        spawnBuyerPed(loc)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    scrapProgress = nil
    for _, ped in pairs(buyerPeds) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, ped in pairs(scrapNpcPeds) do
        if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)

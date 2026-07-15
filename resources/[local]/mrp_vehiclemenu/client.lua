local QBCore = exports['qb-core']:GetCoreObject()

local lockStateByPlate = {}
local engineStartBusy = false
local lastEngineHealth = {}
--- Pikas greitis (KM/H) tarp smūgių — smūgio kadrui greitis dažnai jau kritęs.
local peakSpeedKmhByNet = {}
local lastBodyHealthByNet = {}
local engineStartBlockedUntil = {}
local STALL_AFTER_IMPACT_SPEED = 120.0
--- Po avarijos: +1,5 s už kiekvienus 100 km/h (100 → 1,5 s, 200 → 3 s).
local CRASH_RESTART_MS_PER_100KMH = 1500
--- REH/addon handling.meta dažnai turi labai žemą fEngineDamageMult — normalizuojame vairuotojui įlipus.
local MIN_ENGINE_DAMAGE_MULT = 1.0
local MIN_COLLISION_DAMAGE_MULT = 0.7
--- Jei kėbulas smarkiai pažeidžiamas, o variklis beveik ne — perkeliame dalį smūgio.
local BODY_TO_ENGINE_TRANSFER_RATIO = 0.85
local BODY_LOSS_TRANSFER_MIN = 5.0
local ENGINE_LOSS_VS_BODY_FRACTION = 0.35

local damageMultNormalizedByNet = {}

local function crashRestartDelayMs(speedKmh)
    speedKmh = math.max(0.0, tonumber(speedKmh) or 0.0)
    return math.floor((speedKmh / 100.0) * CRASH_RESTART_MS_PER_100KMH)
end

local function isEngineStartBlocked(netId)
    local untilTs = engineStartBlockedUntil[netId]
    if not untilTs then return false end
    if GetGameTimer() >= untilTs then
        engineStartBlockedUntil[netId] = nil
        return false
    end
    return true
end

local function remainingBlockMs(netId)
    local untilTs = engineStartBlockedUntil[netId]
    if not untilTs then return 0 end
    local rem = untilTs - GetGameTimer()
    if rem <= 0 then
        engineStartBlockedUntil[netId] = nil
        return 0
    end
    return rem
end

local function plateOf(veh)
    return (QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
end

local function isNaturalNpcVehicle(veh)
    if GetResourceState('mrp_basics') ~= 'started' then return false end
    local ok, isNpc = pcall(function()
        return exports['mrp_basics']:IsNaturalNpcVehicle(veh)
    end)
    return ok and isNpc == true
end

local function isRehVehicle(veh)
    if GetResourceState('mrp_vehicle_perf') ~= 'started' then return false end
    local hash = GetEntityModel(veh)
    local spawnName = nil
    local vehicles = QBCore.Shared and QBCore.Shared.Vehicles or {}
    for name, row in pairs(vehicles) do
        local model = (row.model or name):lower()
        if joaat(model) == hash or joaat(name:lower()) == hash then
            spawnName = model
            break
        end
    end
    if not spawnName then
        local display = GetDisplayNameFromVehicleModel(hash)
        if display and display ~= 'CARNOTFOUND' then
            spawnName = display:lower()
        end
    end
    if not spawnName then return false end
    local ok, yes = pcall(function()
        return exports['mrp_vehicle_perf']:IsRehModel(spawnName)
    end)
    return ok and yes == true
end

local function normalizeVehicleDamageHandling(veh, netId)
    if damageMultNormalizedByNet[netId] then return end
    damageMultNormalizedByNet[netId] = true
    if isNaturalNpcVehicle(veh) then return end

    local engMult = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fEngineDamageMult')
    local colMult = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fCollisionDamageMult')
    local changed = false

    if engMult < MIN_ENGINE_DAMAGE_MULT then
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fEngineDamageMult', MIN_ENGINE_DAMAGE_MULT)
        changed = true
    end
    if colMult < MIN_COLLISION_DAMAGE_MULT then
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fCollisionDamageMult', MIN_COLLISION_DAMAGE_MULT)
        changed = true
    end
    if changed or isRehVehicle(veh) then
        SetVehicleEngineCanDegrade(veh, true)
    end
end

local function isLocked(veh)
    local p = plateOf(veh)
    if p ~= '' and lockStateByPlate[p] ~= nil then
        return lockStateByPlate[p]
    end
    local st = GetVehicleDoorLockStatus(veh)
    return st == 2 or st == 4
end

local function setLocked(veh, locked)
    local p = plateOf(veh)
    if p ~= '' then lockStateByPlate[p] = locked and true or false end
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(veh, locked and true or false)
    SetVehicleAlarm(veh, false)
    SetVehicleAlarmTimeLeft(veh, 0)
end

local function toggleLock(veh)
    if GetResourceState('mrp_basics') == 'started' then
        local ok, isNpc = pcall(function()
            return exports['mrp_basics']:IsNaturalNpcVehicle(veh)
        end)
        if ok and isNpc then
            return QBCore.Functions.Notify('NPC transportas visada užrakintas.', 'error')
        end
    end
    if GetResourceState('mrp_hud') == 'started' then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        local nextLocked = not isLocked(veh)
        setLocked(veh, nextLocked)
        TriggerServerEvent('mrp_hud:server:setVehicleLock', netId, nextLocked)
        QBCore.Functions.Notify(nextLocked and 'Transportas užrakintas.' or 'Transportas atrakintas.', 'primary')
        return
    end
    local nextLocked = not isLocked(veh)
    setLocked(veh, nextLocked)
    QBCore.Functions.Notify(nextLocked and 'Transportas užrakintas.' or 'Transportas atrakintas.', 'primary')
end

RegisterNetEvent('mrp_hud:client:syncVehicleLock', function(netId, locked)
    netId = tonumber(netId)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        setLocked(veh, locked == true)
    end
end)

local function nearestVehicle(maxDist)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local bestVeh, bestD = 0, maxDist + 0.01
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local d = #(GetEntityCoords(veh) - pos)
            if d < bestD then
                bestD = d
                bestVeh = veh
            end
        end
    end
    if bestVeh == 0 then return 0 end
    return bestVeh
end

local function toggleDoor(veh, doorIdx, label)
    local ratio = GetVehicleDoorAngleRatio(veh, doorIdx)
    if ratio > 0.05 then
        SetVehicleDoorShut(veh, doorIdx, false)
        QBCore.Functions.Notify(label .. ' uždaryta.', 'primary')
    else
        SetVehicleDoorOpen(veh, doorIdx, false, false)
        QBCore.Functions.Notify(label .. ' atidaryta.', 'primary')
    end
end

local function tryToggleEngine(veh)
    if engineStartBusy then return end
    local on = GetIsVehicleEngineRunning(veh)
    if on then
        SetVehicleEngineOn(veh, false, true, true)
        QBCore.Functions.Notify('Variklis išjungtas.', 'primary')
        return
    end

    local netId = VehToNet(veh)
    local blockMs = remainingBlockMs(netId)
    if blockMs > 0 then
        QBCore.Functions.Notify('Variklis užgeso.', 'error')
        return
    end

    local hp = GetVehicleEngineHealth(veh)
    local delay = 350
    if hp < 700.0 then
        delay = delay + math.floor((700.0 - hp) * 2.2)
    end
    delay = math.min(delay, 3500)
    local failChance = 0.0
    if hp < 800.0 then
        failChance = math.min(0.85, (800.0 - hp) / 1000.0)
    end

    engineStartBusy = true
    QBCore.Functions.Notify('Bandoma užvesti...', 'primary')
    SetTimeout(delay, function()
        engineStartBusy = false
        if math.random() < failChance then
            SetVehicleEngineOn(veh, false, true, true)
            QBCore.Functions.Notify('Variklis neužsivedė. Pabandyk dar kartą.', 'error')
            return
        end
        SetVehicleEngineOn(veh, true, false, true)
        QBCore.Functions.Notify('Variklis užvestas.', 'success')
    end)
end

local function openVehicleMenu(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if GetResourceState('mrp_hud') == 'started' then
        local ok, opened = pcall(function()
            return exports['mrp_hud']:OpenVehicleQuickMenu(veh)
        end)
        if ok and opened then return end
    end
    local doors = 4
    if type(GetNumberOfVehicleDoors) == 'function' then
        local ok, n = pcall(GetNumberOfVehicleDoors, veh)
        if ok and tonumber(n) then
            doors = tonumber(n)
        end
    end
    local plate = QBCore.Functions.GetPlate(veh) or 'N/A'
    local model = string.upper(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or 'AUTO')
    local menu = {
        { header = ('%s [%s]'):format(model, plate), txt = ('Durų skaičius: %s'):format(doors), isMenuHeader = true },
        { header = 'Užrakinti / atrakinti', params = { isAction = true, event = function() toggleLock(veh) end } },
        { header = 'Variklis ON/OFF', params = { isAction = true, event = function() tryToggleEngine(veh) end } },
        { header = 'Kapotas', params = { isAction = true, event = function() toggleDoor(veh, 4, 'Kapotas') end } },
        { header = 'Bagažinė', params = { isAction = true, event = function() toggleDoor(veh, 5, 'Bagažinė') end } },
    }
    local maxDoor = math.max(1, math.min(4, doors))
    for i = 0, maxDoor - 1 do
        local doorLabel = ('Durys #%s'):format(i + 1)
        menu[#menu + 1] = {
            header = doorLabel,
            params = { isAction = true, event = function() toggleDoor(veh, i, doorLabel) end }
        }
    end
    menu[#menu + 1] = { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } }
    TriggerEvent('qb-menu:client:openMenu', menu)
end

RegisterCommand('mrp_vehiclemenu', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            return QBCore.Functions.Notify('Turi būti vairuotojo vietoje.', 'error')
        end
        if GetResourceState('mrp_hud') == 'started' then
            local ok = pcall(function()
                exports['mrp_hud']:ToggleVehicleControlPanel()
            end)
            if ok then return end
        end
        openVehicleMenu(veh)
        return
    end

    local veh = nearestVehicle(8.0)
    if veh == 0 then
        return QBCore.Functions.Notify('Netoliese nėra transporto.', 'error')
    end
    toggleLock(veh)
end, false)

RegisterKeyMapping('mrp_vehiclemenu', 'Transporto meniu / lock', 'keyboard', 'M')

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                local netId = VehToNet(veh)
                normalizeVehicleDamageHandling(veh, netId)

                local spdNow = GetEntitySpeed(veh) * 3.6
                local peak = peakSpeedKmhByNet[netId] or 0.0
                if spdNow >= STALL_AFTER_IMPACT_SPEED then
                    peakSpeedKmhByNet[netId] = math.max(peak, spdNow)
                elseif spdNow < 45.0 then
                    -- Mažinant „seną“ freeway piką, kad parkuojantis smūgis nebeskaitytų kaip 120+
                    peakSpeedKmhByNet[netId] = math.min(peak, math.max(spdNow, peak * 0.97))
                else
                    peakSpeedKmhByNet[netId] = peak
                end

                local hp = GetVehicleEngineHealth(veh)
                local prev = lastEngineHealth[netId] or hp

                local bodyNow = GetVehicleBodyHealth(veh)
                local prevBody = lastBodyHealthByNet[netId] or bodyNow

                local bodyLoss = prevBody - bodyNow
                local engineLoss = prev - hp
                if bodyLoss > BODY_LOSS_TRANSFER_MIN and engineLoss < (bodyLoss * ENGINE_LOSS_VS_BODY_FRACTION) then
                    local engineDrop = bodyLoss * BODY_TO_ENGINE_TRANSFER_RATIO
                    hp = math.max(80.0, hp - engineDrop)
                    SetVehicleEngineHealth(veh, hp)
                end

                local engineHit = (prev - hp) > 35.0
                local bodyHit = bodyLoss > 18.0

                --- Smūgis + ≥120 KM/H („pikas“ per važiavimą): variklis užgesta — be auto-užvedimo, su cooldown pagal greitį
                local crashPeak = peakSpeedKmhByNet[netId] or 0.0
                if (engineHit or bodyHit) and crashPeak >= STALL_AFTER_IMPACT_SPEED then
                    SetVehicleEngineOn(veh, false, true, true)
                    local delayMs = crashRestartDelayMs(crashPeak)
                    engineStartBlockedUntil[netId] = GetGameTimer() + delayMs
                    QBCore.Functions.Notify('Variklis užgeso.', 'error')
                    peakSpeedKmhByNet[netId] = spdNow
                end

                if isEngineStartBlocked(netId) and GetIsVehicleEngineRunning(veh) then
                    SetVehicleEngineOn(veh, false, true, true)
                end

                lastBodyHealthByNet[netId] = bodyNow

                -- Greitesnė degradacija esant blogai būklei
                if hp < 750.0 then
                    local extra = 0.08 + ((750.0 - hp) / 750.0) * 0.30
                    SetVehicleEngineHealth(veh, math.max(80.0, hp - extra))
                end

                lastEngineHealth[netId] = GetVehicleEngineHealth(veh)
                Wait(120)
            else
                Wait(300)
            end
        else
            Wait(500)
        end
    end
end)

exports('IsEngineStartBlocked', function(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return isEngineStartBlocked(VehToNet(veh))
end)

exports('GetEngineStartBlockSecondsLeft', function(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0.0 end
    return remainingBlockMs(VehToNet(veh)) / 1000.0
end)

RegisterNetEvent('mrp_vehiclemenu:client:grantKeysNearest', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or not DoesEntityExist(veh) then
        veh = nearestVehicle(6.0)
    end
    if veh == 0 or not DoesEntityExist(veh) then
        return QBCore.Functions.Notify('Nėra transporto šalia.', 'error')
    end
    local plate = plateOf(veh)
    if plate == '' then
        return QBCore.Functions.Notify('Nepavyko nuskaityti numerių.', 'error')
    end
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    QBCore.Functions.Notify(('Gavote raktus: %s'):format(plate), 'success')
end)


local QBCore = exports['qb-core']:GetCoreObject()

local VALID_MODES = { off = true, lights = true, sound = true, full = true }
local VALID_TONES = { wail = true, yelp = true, priority = true }

local function normalizeMode(mode)
    mode = type(mode) == 'string' and mode:lower() or 'off'
    if not VALID_MODES[mode] then return 'off' end
    return mode
end

local function pedVehicleSeatIsDriver(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil, nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil, nil end
    return ped, veh
end

local function vehicleNearPlayer(src, veh, dist)
    dist = dist or Config.ValidateDistance or 28.0
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    local vcoords = GetEntityCoords(veh)
    return #(pcoords - vcoords) <= dist
end

local function safeVehicleNetId(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    return NetworkGetNetworkIdFromEntity(veh)
end

local function isFleetModel(hash, jobType)
    local list = Config.FleetVehicles[jobType] or {}
    for _, m in ipairs(list) do
        if joaat(m) == hash then return true end
    end
    return false
end

local function isEmsOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == Config.Jobs.ambulance.jobName and j.onduty
end

local function isPdOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == Config.Jobs.police.jobName and j.onduty
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

RegisterNetEvent('mrp_siren:server:setTone', function(netId, tone)
    local src = source
    netId = tonumber(netId)
    tone = type(tone) == 'string' and tone:lower() or 'wail'
    if not VALID_TONES[tone] then tone = 'wail' end
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not vehicleNearPlayer(src, veh) then return end
    local _, driverVeh = pedVehicleSeatIsDriver(src)
    if driverVeh ~= veh then return end
    if not isPdOnDuty(src) and not isEmsOnDuty(src) then return end
    Entity(veh).state:set('fpSirenTone', tone, true)
    TriggerClientEvent('mrp_siren:client:syncUi', src)
end)

RegisterNetEvent('mrp_siren:server:setMuted', function(netId, muted)
    local src = source
    netId = tonumber(netId)
    muted = muted == true
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not vehicleNearPlayer(src, veh) then return end
    local _, driverVeh = pedVehicleSeatIsDriver(src)
    if driverVeh ~= veh then return end
    if not isPdOnDuty(src) and not isEmsOnDuty(src) then return end
    Entity(veh).state:set('fpSirenMuted', muted, true)
    TriggerClientEvent('mrp_siren:client:syncUi', src)
end)

RegisterNetEvent('mrp_siren:server:setEmsEmergencyMode', function(mode)
    local src = source
    if not isEmsOnDuty(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje.', 'error')
    end
    mode = normalizeMode(mode)
    local _, veh = pedVehicleSeatIsDriver(src)
    if not veh then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti vairuotoju transporte.', 'error')
    end
    if safeVehicleNetId(veh) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Mašina turi būti tinkamai sinchronizuota.', 'error')
    end
    if not vehicleNearPlayer(src, veh) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo transporto.', 'error')
    end
    local hash = GetEntityModel(veh)
    if mode ~= 'off' and not isFleetModel(hash, 'ambulance') then
        if Entity(veh).state.ltEmsKit ~= true then
            return TriggerClientEvent('QBCore:Notify', src, 'Ant civilinės TP reikia EMS avarinės įrangos (itemas iš inventoriaus).', 'error')
        end
    end
    Entity(veh).state:set('ltEmsSirenMode', mode, true)
    if mode == 'off' then
        Entity(veh).state:set('fpSirenMuted', false, true)
    end
    TriggerClientEvent('QBCore:Notify', src, ('EMS režimas: %s'):format(mode), 'primary')
    TriggerClientEvent('mrp_siren:client:syncUi', src)
end)

RegisterNetEvent('mrp_siren:server:setEmsEmergencyKit', function(equip)
    local src = source
    if not isEmsOnDuty(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje.', 'error')
    end
    local _, veh = pedVehicleSeatIsDriver(src)
    if not veh then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti vairuotoju transporte.', 'error')
    end
    if not vehicleNearPlayer(src, veh) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo transporto.', 'error')
    end
    if safeVehicleNetId(veh) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Mašina turi būti tinkamai sinchronizuota.', 'error')
    end
    equip = equip == true
    local hash = GetEntityModel(veh)
    if isFleetModel(hash, 'ambulance') then
        return TriggerClientEvent('QBCore:Notify', src, 'Ši mašina jau turi tarnybinę įrangą.', 'error')
    end
    local ek = Config.EmergencyKit or {}
    local kitItem = ek.emsKitItem or 'ems_emergency_kit'
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if equip then
        if not isAdmin(src) then
            if not Player.Functions.GetItemByName(kitItem) then
                return TriggerClientEvent('QBCore:Notify', src, 'Neturi EMS avarinės įrangos inventoriuje.', 'error')
            end
            if not Player.Functions.RemoveItem(kitItem, 1) then
                return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti įrangos.', 'error')
            end
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[kitItem], 'remove', 1)
        end
    elseif ek.returnKitItemOnRemove ~= false and not isAdmin(src) then
        if not Player.Functions.AddItem(kitItem, 1) then
            return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas – negalima grąžinti įrangos.', 'error')
        end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[kitItem], 'add', 1)
    end
    Entity(veh).state:set('ltEmsKit', equip, true)
    if not equip then
        Entity(veh).state:set('ltEmsSirenMode', 'off', true)
    end
    TriggerClientEvent('QBCore:Notify', src, equip and 'EMS įranga įdėta.' or 'EMS įranga nuimta.', equip and 'success' or 'primary')
end)

RegisterNetEvent('mrp_siren:server:clearEmsEmergencyOnExit', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    if not isEmsOnDuty(src) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not vehicleNearPlayer(src, veh, (Config.ValidateDistance or 28.0) + 10.0) then return end
    Entity(veh).state:set('ltEmsSirenMode', 'off', true)
end)

CreateThread(function()
    Wait(900)
    local ek = Config.EmergencyKit or {}
    local kitItem = ek.emsKitItem or 'ems_emergency_kit'
    QBCore.Functions.CreateUseableItem(kitItem, function(source)
        TriggerClientEvent('mrp_siren:client:openEmsEmergencyKitMenu', source)
    end)
end)

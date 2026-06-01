local QBCore = exports['qb-core']:GetCoreObject()

local missionBlip = nil
local missionData = nil

local function clearMission()
    if missionBlip and DoesBlipExist(missionBlip) then
        RemoveBlip(missionBlip)
    end
    missionBlip = nil
    missionData = nil
end

local function setMissionBlip(coords, label)
    if missionBlip and DoesBlipExist(missionBlip) then RemoveBlip(missionBlip) end
    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 1)
    SetBlipColour(missionBlip, 27)
    SetBlipRoute(missionBlip, true)
    exports['fivempro_fonts']:SetBlipName(missionBlip, label or 'Misija')
end

local function getCurrentTurfId()
    local p = GetEntityCoords(PlayerPedId())
    local id = Config.FindTurfAt(p.x, p.y)
    return id
end

local function runProgress(ms, label)
    return GangRunProgressSync('gang_mission', label, ms)
end

local function finishStep(token, step)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:finishMissionStep', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Misija nepavyko.', 'error')
            TriggerServerEvent('fivempro_gangs:server:cancelMission')
            clearMission()
            return
        end
        if res.done then
            QBCore.Functions.Notify('Misija įvykdyta.', 'success')
            clearMission()
            return
        end
        if missionData and res.nextStep == 2 then
            missionData.step = 2
            setMissionBlip(missionData.drop, 'Pristatymas į turf')
            QBCore.Functions.Notify('Nuvežk krovinį į turf centrą ir /gangmissiondrop', 'primary')
        end
    end, token, step)
end

local function startMissionAt(turfId, missionType)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:startMission', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Negalima pradėti.', 'error')
        end
        if missionType == 'hacking' then
            missionData = { token = res.token, step = 1, hacking = true }
            return QBCore.Functions.Notify('Atlik sėkmingą hack — turf progresas bus priskirtas.', 'primary')
        end
        missionData = {
            token = res.token,
            step = 1,
            pickup = vector3(res.pickup.x, res.pickup.y, res.pickup.z),
            drop = vector3(res.drop.x, res.drop.y, res.drop.z),
            durationMs = res.durationMs or 7000,
            requireVehicle = res.requireVehicle == true,
        }
        setMissionBlip(missionData.pickup, res.label)
        QBCore.Functions.Notify(('Misija: %s — [E] paėmimo taške'):format(res.label), 'success')
    end, turfId, missionType)
end

RegisterNetEvent('fivempro_gangs:client:startMission', function(turfId, missionType)
    startMissionAt(turfId, missionType)
end)

RegisterCommand('gangmission', function(_, args)
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Stovėk turf zonoje.', 'error')
    end
    startMissionAt(turfId, tostring(args[1] or 'smuggle'))
end, false)

RegisterCommand('gangmissiondrop', function()
    if not missionData or missionData.step ~= 2 or missionData.hacking then
        return QBCore.Functions.Notify('Nėra aktyvios pristatymo fazės.', 'error')
    end
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - missionData.drop) > 85.0 then
        return QBCore.Functions.Notify('Per toli nuo turf centro.', 'error')
    end
    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Reikia transporto.', 'error')
    end
    if not runProgress(missionData.durationMs or 7000, 'Pristatoma…') then
        TriggerServerEvent('fivempro_gangs:server:cancelMission')
        clearMission()
        return
    end
    finishStep(missionData.token, 2)
end, false)

CreateThread(function()
    while true do
        local sleep = 1000
        if missionData and missionData.step == 1 and missionData.pickup and not missionData.hacking then
            local ped = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - missionData.pickup)
            if dist < 18.0 then
                sleep = 0
                if dist < 3.5 and IsControlJustReleased(0, 38) then
                    if missionData.requireVehicle and not IsPedInAnyVehicle(ped, false) then
                        QBCore.Functions.Notify('Reikia transporto.', 'error')
                    elseif runProgress(missionData.durationMs or 7000, 'Renkamas krovinys…') then
                        finishStep(missionData.token, 1)
                    else
                        TriggerServerEvent('fivempro_gangs:server:cancelMission')
                        clearMission()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

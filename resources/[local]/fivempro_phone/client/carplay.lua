local QBCore = exports['qb-core']:GetCoreObject()

local currentVehNet = 0
local inVehicle = false

local function sendUi(action, payload)
    SendNUIMessage({ action = action, payload = payload or {} })
end

local function getVehicleNetId()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or not DoesEntityExist(veh) then return 0 end
    return VehToNet(veh)
end

local function refreshCarPlayState()
    local netId = getVehicleNetId()
    inVehicle = netId ~= 0
    currentVehNet = netId
    if not inVehicle then
        sendUi('carplayState', { inVehicle = false })
        TriggerServerEvent('fivempro_phone:server:carplayLeave')
        return
    end
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getCarPlayState', function(res)
        sendUi('carplayState', {
            inVehicle = true,
            netId = netId,
            session = res and res.session or nil,
        })
    end, { netId = netId })
end

CreateThread(function()
    while true do
        Wait(1200)
        local netId = getVehicleNetId()
        if netId ~= currentVehNet then
            if currentVehNet ~= 0 and netId == 0 then
                sendUi('carplayAudio', { command = 'stop' })
                TriggerServerEvent('fivempro_phone:server:carplayLeave')
            end
            currentVehNet = netId
            inVehicle = netId ~= 0
            if inVehicle then
                refreshCarPlayState()
            else
                sendUi('carplayState', { inVehicle = false })
            end
        end
    end
end)

RegisterNUICallback('carplayGetState', function(_, cb)
    local netId = getVehicleNetId()
    if netId == 0 then
        return cb({ ok = false, message = 'Turite būti transporto priemonėje.' })
    end
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getCarPlayState', function(res)
        cb(res or { ok = false })
    end, { netId = netId })
end)

RegisterNUICallback('carplayControl', function(data, cb)
    local netId = getVehicleNetId()
    if netId == 0 then
        return cb({ ok = false, message = 'Turite būti transporto priemonėje.' })
    end
    QBCore.Functions.TriggerCallback('fivempro_phone:server:carplayControl', function(res)
        cb(res or { ok = false })
    end, {
        netId = netId,
        action = data and data.action,
        url = data and data.url,
        title = data and data.title,
        volume = data and data.volume,
    })
end)

RegisterNetEvent('fivempro_phone:client:carplaySync', function(payload)
    if not payload then return end
    local myNet = getVehicleNetId()
    if myNet == 0 or tonumber(payload.netId) ~= myNet then return end
    sendUi('carplayState', {
        inVehicle = true,
        netId = myNet,
        session = payload.session,
    })
    if payload.audio then
        sendUi('carplayAudio', payload.audio)
    end
end)

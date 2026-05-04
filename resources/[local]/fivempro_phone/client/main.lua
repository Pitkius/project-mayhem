local QBCore = exports['qb-core']:GetCoreObject()

local phoneOpen = false

local function sendUi(action, payload)
    SendNUIMessage({
        action = action,
        payload = payload or {},
    })
end

local function closePhone()
    if not phoneOpen then return end
    phoneOpen = false
    SetNuiFocus(false, false)
    sendUi('close')
end

local function fetchPhoneData(cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getInitialData', function(data)
        if cb then cb(data or {}) end
    end)
end

local function showPhone(opts)
    opts = opts or {}
    if IsPauseMenuActive() then return end
    if phoneOpen then
        if opts.refreshIfOpen then
            fetchPhoneData(function(data)
                sendUi('hydrate', data)
            end)
        end
        return
    end
    phoneOpen = true
    SetNuiFocus(true, true)
    sendUi('open')
    fetchPhoneData(function(data)
        sendUi('hydrate', data)
    end)
end

local function togglePhone()
    if phoneOpen then
        closePhone()
        return
    end
    showPhone({})
end

RegisterCommand(Config.KeybindCommand or 'fivempro_phone_toggle', function()
    local itemName = Config.PhoneItem or 'phone'
    if Config.RequirePhoneItemForKeybind and not QBCore.Functions.HasItem(itemName, 1) then
        QBCore.Functions.Notify('Jums reikia telefono inventoriuje.', 'error')
        return
    end
    togglePhone()
end, false)

RegisterKeyMapping(
    Config.KeybindCommand or 'fivempro_phone_toggle',
    'Atidaryti telefoną',
    'keyboard',
    Config.KeybindDefault or 'F1'
)

RegisterNetEvent('fivempro_phone:client:refreshData', function()
    if not phoneOpen then return end
    fetchPhoneData(function(data)
        sendUi('hydrate', data)
    end)
end)

RegisterNetEvent('fivempro_phone:client:newMessageNotify', function(fromNumber)
    fromNumber = tostring(fromNumber or 'Nežinomas')
    if not phoneOpen then
        QBCore.Functions.Notify(('Nauja žinutė iš %s'):format(fromNumber), 'primary')
    end
    sendUi('newMessageNotify', { fromNumber = fromNumber })
end)

RegisterNetEvent('fivempro_phone:client:incomingCall', function(call)
    if not phoneOpen then
        QBCore.Functions.Notify(('Gaunamas skambutis: %s'):format(call and call.fromNumber or 'Nežinomas'), 'primary')
    end
    sendUi('incomingCall', call or {})
end)

RegisterNetEvent('fivempro_phone:client:callState', function(call)
    sendUi('callState', call or {})
end)

RegisterNetEvent('fivempro_phone:client:closePhone', function()
    closePhone()
end)

RegisterNetEvent('fivempro_phone:client:openPhoneFromItem', function()
    local itemName = Config.PhoneItem or 'phone'
    if not QBCore.Functions.HasItem(itemName, 1) then
        QBCore.Functions.Notify('Neturite telefono.', 'error')
        return
    end
    showPhone({ refreshIfOpen = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    fetchPhoneData(function(data)
        cb(data or {})
    end)
end)

RegisterNUICallback('saveContact', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:saveContact', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('sendMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:sendMessage', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('getConversation', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getConversation', function(res)
        cb(res or { ok = false, messages = {} })
    end, data or {})
end)

RegisterNUICallback('createAd', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:createAd', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('createPost', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:createPost', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('likePost', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:likePost', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('startCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:startCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('respondCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:respondCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('endCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:endCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('emergencyCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:emergencyCall', data and data.service or '')
    cb({ ok = true })
end)

RegisterNetEvent('fivempro_phone:client:serviceDispatch', function(data)
    if not data or not data.x then return end
    local service = tostring(data.service or '')
    local blip = AddBlipForCoord(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    SetBlipSprite(blip, tonumber(data.sprite) or 161)
    SetBlipScale(blip, tonumber(data.scale) or 1.0)
    if service == 'police' then
        SetBlipColour(blip, 38)
    elseif service == 'ems' then
        SetBlipColour(blip, 1)
    elseif service == 'taxi' then
        SetBlipColour(blip, 5)
    else
        SetBlipColour(blip, 5)
    end
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.title or 'Skubus iškvietimas')
    EndTextCommandSetBlipName(blip)
    QBCore.Functions.Notify(data.title or 'Skubus iškvietimas', 'primary', 7500)
    local dur = tonumber(data.duration) or 120000
    SetTimeout(dur, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

RegisterNetEvent('fivempro_phone:client:hospitalWake', function(data)
    local c = data
    if not c or c.x == nil then
        local h = Config.HospitalWake
        local locs = h and h.locations
        if type(locs) == 'table' and locs[1] then
            c = { x = locs[1].x, y = locs[1].y, z = locs[1].z, w = locs[1].w }
        elseif h and h.coords then
            c = { x = h.coords.x, y = h.coords.y, z = h.coords.z, w = h.coords.w }
        else
            return
        end
    end
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(c.x, c.y, c.z + 0.35, c.w, true, false)
    ped = PlayerPedId()
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    TriggerEvent('fivempro_phone:local:AfterHospitalWake')
end)

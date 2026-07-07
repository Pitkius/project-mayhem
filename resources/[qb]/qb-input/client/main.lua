local properties = nil
local inputBusy = false

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    Wait(1000)
    SendNUIMessage({
        action = 'SET_STYLE',
        data = Config.Style
    })
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SendNUIMessage({
        action = 'SET_STYLE',
        data = Config.Style
    })
end)

RegisterNUICallback('buttonSubmit', function(data, cb)
    cb('ok')
    if not properties then
        SetNuiFocus(false, false)
        return
    end
    SetNuiFocus(false, false)
    local pending = properties
    properties = nil
    inputBusy = false
    pending:resolve(data.data)
end)

RegisterNUICallback('closeMenu', function(_, cb)
    cb('ok')
    if not properties then
        SetNuiFocus(false, false)
        return
    end
    SetNuiFocus(false, false)
    local pending = properties
    properties = nil
    inputBusy = false
    pending:resolve(nil)
end)

local function ShowInput(data)
    Wait(150)
    if not data then return end
    if properties or inputBusy then return end

    inputBusy = true
    properties = promise.new()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OPEN_MENU',
        data = data
    })

    local result = Citizen.Await(properties)
    inputBusy = false
    return result
end

exports('ForceClose', function()
    if properties then
        local pending = properties
        properties = nil
        inputBusy = false
        pending:resolve(nil)
    else
        inputBusy = false
    end
    SetNuiFocus(false, false)
end)

exports('ShowInput', ShowInput)

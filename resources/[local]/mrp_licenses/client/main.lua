local QBCore = exports['qb-core']:GetCoreObject()
local cardOpen = false

local function closeCard()
    if not cardOpen then return end
    cardOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('mrp_licenses:client:show', function(payload)
    if not payload or not payload.type then return end
    cardOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        card = payload,
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeCard()
    cb('ok')
end)

CreateThread(function()
    while true do
        if cardOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 106, true)
            if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 177) then
                closeCard()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('IsCardOpen', function()
    return cardOpen
end)

exports('CloseCard', closeCard)

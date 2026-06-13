local QBCore = exports['qb-core']:GetCoreObject()

local terminalOpen = false

local function bankCb(name, data, cb)
    QBCore.Functions.TriggerCallback(name, function(res)
        cb(res or { ok = false, message = 'Klaida.' })
    end, data or {})
end

local function openTerminal()
    if terminalOpen then return end
    terminalOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

local function closeTerminal()
    if not terminalOpen then return end
    terminalOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('atmClose', function(_, cb)
    closeTerminal()
    cb({ ok = true })
end)

RegisterNUICallback('copyText', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('bankGetState', function(_, cb)
    bankCb('fivempro_phone:server:bankGetState', {}, cb)
end)

RegisterNUICallback('bankLookupRecipient', function(data, cb)
    bankCb('fivempro_phone:server:bankLookupRecipient', data, cb)
end)

RegisterNUICallback('bankTransfer', function(data, cb)
    bankCb('fivempro_phone:server:bankTransfer', data, cb)
end)

RegisterNUICallback('bankDeposit', function(data, cb)
    bankCb('fivempro_phone:server:bankDeposit', data, cb)
end)

RegisterNUICallback('bankWithdraw', function(data, cb)
    bankCb('fivempro_phone:server:bankWithdraw', data, cb)
end)

RegisterNUICallback('bankGetHistory', function(data, cb)
    bankCb('fivempro_phone:server:bankGetHistory', data, cb)
end)

RegisterNetEvent('fivempro:bank:client:open', function()
    openTerminal()
end)

RegisterCommand('bank', function()
    openTerminal()
end, false)

CreateThread(function()
    for _, coords in ipairs(Config.BankLocations) do
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 108)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.85)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        exports['fivempro_fonts']:SetBlipName(blip, 'Bankas')
    end
end)

CreateThread(function()
    for i, coords in ipairs(Config.BankLocations) do
        exports['qb-target']:AddCircleZone(('fivempro_bank_%s'):format(i), coords, 1.2, {
            name = ('fivempro_bank_%s'):format(i),
            debugPoly = false,
            useZ = true
        }, {
            options = {
                {
                    type = 'client',
                    icon = 'fas fa-building-columns',
                    label = 'Atidaryti BANKNET terminalą',
                    action = function()
                        openTerminal()
                    end
                }
            },
            distance = 2.0
        })
    end
end)

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.ATMModels, {
        options = {
            {
                type = 'client',
                icon = 'fas fa-money-bill-wave',
                label = 'Naudoti bankomatą',
                action = function()
                    openTerminal()
                end
            }
        },
        distance = 2.0
    })
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if terminalOpen then
            sleep = 0
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 106, true)
        else
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for _, coords in ipairs(Config.BankLocations) do
                local dist = #(pos - coords)
                if dist < 2.0 then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Spausk ~INPUT_CONTEXT~ atidaryti BANKNET')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustPressed(0, 38) then
                        openTerminal()
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

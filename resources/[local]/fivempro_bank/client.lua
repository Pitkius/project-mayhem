local QBCore = exports['qb-core']:GetCoreObject()

local function openBankMenu()
    QBCore.Functions.TriggerCallback('fivempro:bank:server:getSnapshot', function(snapshot)
        if not snapshot then return end

        local menu = {
            {
                header = 'Fivempro Bankas',
                isMenuHeader = true
            },
            {
                header = ('Cash: $%s'):format(snapshot.cash),
                txt = ('Bank: $%s'):format(snapshot.bank),
                isMenuHeader = true
            },
            {
                header = 'Inesti pinigus',
                txt = 'Perkelti cash i banka',
                params = { event = 'fivempro:bank:client:deposit' }
            },
            {
                header = 'Issiimti pinigus',
                txt = 'Perkelti is banko i cash',
                params = { event = 'fivempro:bank:client:withdraw' }
            },
            {
                header = 'Pervesti zaidejui',
                txt = 'Pervedimas pagal server ID',
                params = { event = 'fivempro:bank:client:transfer' }
            },
            {
                header = 'Operaciju istorija',
                txt = 'Paskutiniai irasai',
                params = { event = 'fivempro:bank:client:history' }
            },
            {
                header = 'Uzdaryti',
                params = { event = 'qb-menu:client:closeMenu' }
            }
        }
        exports['qb-menu']:openMenu(menu)
    end)
end

local function openAtmMenu()
    QBCore.Functions.TriggerCallback('fivempro:bank:server:getSnapshot', function(snapshot)
        if not snapshot then return end

        local menu = {
            {
                header = 'Bankomatas',
                isMenuHeader = true
            },
            {
                header = ('Cash: $%s'):format(snapshot.cash),
                txt = ('Bank: $%s'):format(snapshot.bank),
                isMenuHeader = true
            },
            {
                header = 'Inesti pinigus',
                txt = 'Perkelti cash i banka',
                params = { event = 'fivempro:bank:client:deposit' }
            },
            {
                header = 'Issiimti pinigus',
                txt = 'Perkelti is banko i cash',
                params = { event = 'fivempro:bank:client:withdraw' }
            },
            {
                header = 'Uzdaryti',
                params = { event = 'qb-menu:client:closeMenu' }
            }
        }

        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterNetEvent('fivempro:bank:client:deposit', function()
    local result = exports['qb-input']:ShowInput({
        header = 'Inesti i banka',
        submitText = 'Patvirtinti',
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'amount',
                text = 'Suma'
            }
        }
    })
    if not result or not result.amount then return end
    TriggerServerEvent('fivempro:bank:server:deposit', tonumber(result.amount))
end)

RegisterNetEvent('fivempro:bank:client:withdraw', function()
    local result = exports['qb-input']:ShowInput({
        header = 'Issiimti is banko',
        submitText = 'Patvirtinti',
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'amount',
                text = 'Suma'
            }
        }
    })
    if not result or not result.amount then return end
    TriggerServerEvent('fivempro:bank:server:withdraw', tonumber(result.amount))
end)

RegisterNetEvent('fivempro:bank:client:transfer', function()
    local result = exports['qb-input']:ShowInput({
        header = 'Pervedimas zaidejui',
        submitText = 'Patvirtinti',
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'target',
                text = 'Gavejo ID'
            },
            {
                type = 'number',
                isRequired = true,
                name = 'amount',
                text = 'Suma'
            }
        }
    })
    if not result or not result.target or not result.amount then return end
    TriggerServerEvent('fivempro:bank:server:transfer', tonumber(result.target), tonumber(result.amount))
end)

RegisterNetEvent('fivempro:bank:client:history', function()
    QBCore.Functions.TriggerCallback('fivempro:bank:server:getHistory', function(rows)
        local menu = {
            {
                header = 'Banko istorija',
                isMenuHeader = true
            }
        }

        if not rows or #rows == 0 then
            menu[#menu + 1] = {
                header = 'Irasu nerasta',
                isMenuHeader = true
            }
        else
            for _, row in ipairs(rows) do
                menu[#menu + 1] = {
                    header = ('%s $%s'):format(row.tx_type, row.amount),
                    txt = ('Balansas po operacijos: $%s'):format(row.balance_after),
                    isMenuHeader = true
                }
            end
        end

        menu[#menu + 1] = {
            header = 'Atgal',
            params = { event = 'fivempro:bank:client:open' }
        }
        exports['qb-menu']:openMenu(menu)
    end)
end)

RegisterNetEvent('fivempro:bank:client:open', function()
    openBankMenu()
end)

RegisterCommand('bank', function()
    openBankMenu()
end, false)

CreateThread(function()
    for _, coords in ipairs(Config.BankLocations) do
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 108) -- Dollar sign icon.
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.85)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Bankas')
        EndTextCommandSetBlipName(blip)
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
                    event = 'fivempro:bank:client:open',
                    icon = 'fas fa-building-columns',
                    label = 'Atidaryti banka',
                    action = function()
                        openBankMenu()
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
                label = 'Naudoti bankomata',
                action = function()
                    openAtmMenu()
                end
            }
        },
        distance = 2.0
    })
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for _, coords in ipairs(Config.BankLocations) do
            local dist = #(pos - coords)
            if dist < 2.0 then
                sleep = 0
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Spausk ~INPUT_CONTEXT~ atidaryti banka')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustPressed(0, 38) then
                    openBankMenu()
                end
            end
        end
        Wait(sleep)
    end
end)

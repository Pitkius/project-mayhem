local QBCore = exports['qb-core']:GetCoreObject()

local TX_LABELS = {
    DEPOSIT = 'Įnešimas',
    WITHDRAW = 'Išėmimas',
    TRANSFER_OUT = 'Pervedimas (iš)',
    TRANSFER_IN = 'Gavimas',
}

local function txLabel(txType)
    return TX_LABELS[txType] or txType
end

local function openBankMenu()
    QBCore.Functions.TriggerCallback('fivempro:bank:server:getSnapshot', function(snapshot)
        if not snapshot then return end

        local menu = {
            {
                header = 'Fivempro Bankas',
                isMenuHeader = true
            },
            {
                header = ('Grynieji: $%s'):format(snapshot.cash),
                txt = ('Bankas: $%s'):format(snapshot.bank),
                isMenuHeader = true
            },
            {
                header = 'Įnešti pinigus',
                txt = 'Perkelti grynuosius į banką',
                params = { event = 'fivempro:bank:client:deposit' }
            },
            {
                header = 'Išsiimti pinigus',
                txt = 'Perkelti iš banko į grynuosius',
                params = { event = 'fivempro:bank:client:withdraw' }
            },
            {
                header = 'Pervesti žaidėjui',
                txt = 'Pervedimas pagal serverio ID',
                params = { event = 'fivempro:bank:client:transfer' }
            },
            {
                header = 'Operacijų istorija',
                txt = 'Paskutiniai įrašai',
                params = { event = 'fivempro:bank:client:history' }
            },
            {
                header = 'Uždaryti',
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
                header = ('Grynieji: $%s'):format(snapshot.cash),
                txt = ('Bankas: $%s'):format(snapshot.bank),
                isMenuHeader = true
            },
            {
                header = 'Įnešti pinigus',
                txt = 'Perkelti grynuosius į banką',
                params = { event = 'fivempro:bank:client:deposit' }
            },
            {
                header = 'Išsiimti pinigus',
                txt = 'Perkelti iš banko į grynuosius',
                params = { event = 'fivempro:bank:client:withdraw' }
            },
            {
                header = 'Uždaryti',
                params = { event = 'qb-menu:client:closeMenu' }
            }
        }

        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterNetEvent('fivempro:bank:client:deposit', function()
    local result = exports['qb-input']:ShowInput({
        header = 'Įnešti į banką',
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
        header = 'Išsiimti iš banko',
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
        header = 'Pervedimas žaidėjui',
        submitText = 'Patvirtinti',
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'target',
                text = 'Gavėjo ID'
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
                header = 'Įrašų nerasta',
                isMenuHeader = true
            }
        else
            for _, row in ipairs(rows) do
                menu[#menu + 1] = {
                    header = ('%s $%s'):format(txLabel(row.tx_type), row.amount),
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

local QBCore = exports['qb-core']:GetCoreObject()

local cashierPed = nil

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10) t = t + 1 end
    return HasModelLoaded(hash), hash
end

local function openCashierMenu(status)
    if not status then return end

    local used = (status.maxDailyWin or 50000) - (status.remaining or 0)
    local menu = {
        { header = 'Kazino kasa', isMenuHeader = true },
        { header = ('Turite: %s žetonų'):format(status.chips or 0), txt = ('Grynieji: $%s'):format(status.cash or 0), isMenuHeader = true },
        {
            header = ('Dienos limitas: %s / %s žetonų'):format(used, status.maxDailyWin or 50000),
            txt = status.banned and 'Limitas pasiektas — rytoj galėsite vėl keisti.' or 'Limitas skaičiuojamas tik lošimų laimėjimams.',
            isMenuHeader = true,
        },
        {
            header = 'Pirkti žetonus',
            txt = 'Grynieji → žetonai (1:1)',
            params = {
                isAction = true,
                event = function()
                    if GetResourceState('qb-input') ~= 'started' then return notify('qb-input neįkeltas.', 'error') end
                    local r = exports['qb-input']:ShowInput({
                        header = 'Pirkti žetonus',
                        submitText = 'Pirkti',
                        inputs = { { text = 'Suma ($)', name = 'amount', type = 'number', isRequired = true } },
                    })
                    if not r or not r.amount then return end
                    QBCore.Functions.TriggerCallback('fivempro_casino:server:exchangeChips', function(res)
                        notify(res and res.msg or 'Klaida.', res and res.ok and 'success' or 'error')
                    end, 'buy', tonumber(r.amount))
                end,
            },
        },
        {
            header = 'Keisti žetonus į grynuosius',
            txt = 'Žetonai → grynieji (1:1)',
            params = {
                isAction = true,
                event = function()
                    if GetResourceState('qb-input') ~= 'started' then return notify('qb-input neįkeltas.', 'error') end
                    local r = exports['qb-input']:ShowInput({
                        header = 'Keisti žetonus',
                        submitText = 'Keisti',
                        inputs = { { text = 'Žetonų kiekis', name = 'amount', type = 'number', isRequired = true } },
                    })
                    if not r or not r.amount then return end
                    QBCore.Functions.TriggerCallback('fivempro_casino:server:exchangeChips', function(res)
                        notify(res and res.msg or 'Klaida.', res and res.ok and 'success' or 'error')
                    end, 'sell', tonumber(r.amount))
                end,
            },
        },
    }
    exports['qb-menu']:openMenu(menu)
end

local function openCashier()
    if not Casino.isInside() then
        return notify('Turite būti kazino.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_casino:server:getCashierStatus', function(status)
        if not status then return notify('Klaida.', 'error') end
        openCashierMenu(status)
    end)
end

CreateThread(function()
    Wait(2000)
    local cfg = Config.Cashier
    if not cfg or not cfg.coords then return end
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end

    local c = cfg.coords
    exports['qb-target']:AddBoxZone('casino_cashier', vector3(c.x, c.y, c.z), 1.4, 1.4, {
        name = 'casino_cashier',
        heading = c.w,
        minZ = c.z - 1.0,
        maxZ = c.z + 1.2,
        debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-coins',
                label = 'Kazino kasa',
                action = openCashier,
            },
        },
        distance = cfg.targetDistance or 2.5,
    })
end)

CreateThread(function()
    local cfg = Config.Cashier
    if not cfg or not cfg.coords then return end
    local model = cfg.pedModel or 'u_f_m_casinoshop_01'
    local c = cfg.coords

    while true do
        local sleep = 2000
        if Casino.isInside and Casino.isInside() then
            sleep = 800
            if not cashierPed or not DoesEntityExist(cashierPed) then
                local ok, hash = loadModel(model)
                if ok then
                    cashierPed = CreatePed(0, hash, c.x, c.y, c.z - 1.0, c.w, false, false)
                    SetEntityInvincible(cashierPed, true)
                    SetBlockingOfNonTemporaryEvents(cashierPed, true)
                    FreezeEntityPosition(cashierPed, true)
                    if cfg.pedScenario then
                        TaskStartScenarioInPlace(cashierPed, cfg.pedScenario, 0, true)
                    end
                    SetModelAsNoLongerNeeded(hash)
                end
            end
        elseif cashierPed and DoesEntityExist(cashierPed) then
            DeleteEntity(cashierPed)
            cashierPed = nil
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if cashierPed and DoesEntityExist(cashierPed) then DeleteEntity(cashierPed) end
    pcall(function() exports['qb-target']:RemoveZone('casino_cashier') end)
end)

--- Artimos zonos + [E] — nepriklauso nuo qb-target (veikia MLO interjere)

local QBCore = exports['qb-core']:GetCoreObject()

Casino = Casino or {}

local prompts = {}

local function addPrompt(id, coords, dist, label, icon, action, extraCheck)
    prompts[#prompts + 1] = {
        id = id,
        coords = coords,
        dist = dist or 2.2,
        label = label,
        icon = icon or 'fa-solid fa-circle',
        action = action,
        extraCheck = extraCheck,
    }
end

local function registerPrompts()
    prompts = {}

    local wheel = Config.Wheel
    if wheel then
        local pos = wheel.movePos or wheel.coords
        if pos then
            addPrompt('wheel', pos, 2.4, 'Laimės ratas (24h)', 'fa-solid fa-dharmachakra', function()
                TriggerEvent('mrp_casino:client:openWheel')
            end)
        end
    end

    for _, tbl in ipairs(Config.BlackjackTables or {}) do
        addPrompt(tbl.id, tbl.coords, 2.2, 'Blackjack', 'fa-solid fa-playing-card', function()
            TriggerEvent('mrp_casino:client:openBlackjack', tbl.id)
        end)
    end

    for _, tbl in ipairs(Config.RouletteTables or {}) do
        addPrompt(tbl.id, tbl.coords, 2.2, 'Ruletė', 'fa-solid fa-circle-notch', function()
            TriggerEvent('mrp_casino:client:openRoulette', tbl.id)
        end)
    end

    for _, machine in ipairs(Config.SlotMachines or {}) do
        addPrompt(machine.id, machine.coords, 2.0, 'Lošimo automatas', 'fa-solid fa-coins', function()
            TriggerEvent('mrp_casino:client:openSlots', machine.id)
        end)
    end

    local cashier = Config.Cashier
    if cashier and cashier.coords then
        addPrompt('cashier', vector3(cashier.coords.x, cashier.coords.y, cashier.coords.z), cashier.targetDistance or 2.5, 'Kazino kasa', 'fa-solid fa-coins', function()
            TriggerEvent('mrp_casino:client:openCashier')
        end)
    end
end

RegisterNetEvent('mrp_casino:client:openCashier', function()
    if not Casino.isInside() then
        return QBCore.Functions.Notify('Turite būti kazino.', 'error')
    end
    QBCore.Functions.TriggerCallback('mrp_casino:server:getCashierStatus', function(status)
        if not status then return QBCore.Functions.Notify('Klaida.', 'error') end
        TriggerEvent('mrp_casino:client:showCashierMenu', status)
    end)
end)

CreateThread(function()
    Wait(2500)
    registerPrompts()
end)

CreateThread(function()
    while true do
        local sleep = 800
        if Casino.isInside and Casino.isInside() and not (Casino.isBanned and Casino.isBanned()) then
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local nearest = nil
            local nearestDist = 999.0

            for _, pr in ipairs(prompts) do
                if not pr.extraCheck or pr.extraCheck() then
                    local d = #(p - pr.coords)
                    if d <= (pr.dist + 0.35) and d < nearestDist then
                        nearest = pr
                        nearestDist = d
                    end
                end
            end

            if nearest and nearestDist <= nearest.dist then
                sleep = 0
                local label = ('[%s] %s'):format(Config.InteractKeyLabel or 'E', nearest.label)
                if Casino.drawText3D then
                    Casino.drawText3D(vector3(nearest.coords.x, nearest.coords.y, nearest.coords.z + 0.95), label, 0.42)
                end
                if IsControlJustReleased(0, 38) then
                    nearest.action()
                    Wait(400)
                end
            end
        end
        Wait(sleep)
    end
end)

local QBCore = exports['qb-core']:GetCoreObject()

local Busy = {}
local TellerCd = {}
--- [src] = { [key] = true } — maišas jau išmokėtas, laukiama PD alert
local PaidPendingAlert = {}

local function giveLootKey(src, lootKey)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local loot = (Config.Robberies.Loot or {})[lootKey]
    if not loot then return end
    if loot.cash then
        local amount = math.random(loot.cash.min or 0, loot.cash.max or 0)
        Player.Functions.AddMoney('cash', amount, 'teller-robbery')
        TriggerClientEvent('QBCore:Notify', src, ('Gavai $%s iš maišo.'):format(amount), 'success')
    end
    if loot.markedbills then
        local count = math.random(loot.markedbills.min or 0, loot.markedbills.max or 0)
        local worth = loot.markedbills.worth or 400
        local dirty = count * worth
        if dirty > 0 then
            Player.Functions.AddItem('markedbills', dirty, false, {})
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add', dirty)
        end
    end
end

local function policeAlert(src, text)
    local c = GetEntityCoords(GetPlayerPed(src))
    MRP_DispatchAlert('police', 'robbery', c, text, src)
end

local function sessionKey(kind, locId)
    return ('teller:%s:%s'):format(kind, tostring(locId or 'x'))
end

QBCore.Functions.CreateCallback('mrp_hacking:server:tellerStart', function(src, cb, kind, locId)
    kind = kind == 'store' and 'store' or 'bank_fleeca'
    local ok, msg = exports['mrp_hacking']:CanAccessRobbery(src, kind, 'soft')
    if not ok then return cb({ ok = false, msg = msg }) end
    local key = sessionKey(kind, locId)
    local now = os.time()
    TellerCd[src] = TellerCd[src] or {}
    if TellerCd[src][key] and now < TellerCd[src][key] then
        return cb({ ok = false, msg = 'Palauk prieš kitą apiplėšimą.' })
    end
    if Busy[key] and Busy[key] ~= src then
        return cb({ ok = false, msg = 'Kažkas jau apiplėšinėja.' })
    end
    Busy[key] = src
    cb({ ok = true, key = key })
end)

--- gotBag + alertNow=false: išmoka / atrakinimas, PD vėliau
--- alertNow=true: PD (ir išmoka jei dar nebuvo)
RegisterNetEvent('mrp_hacking:server:tellerComplete', function(kind, locId, gotBag, alertNow)
    local src = source
    kind = kind == 'store' and 'store' or 'bank_fleeca'
    local key = sessionKey(kind, locId)

    local pending = PaidPendingAlert[src] and PaidPendingAlert[src][key]
    local isBusy = Busy[key] == src

    if not isBusy and not pending then return end

    local lootKey = kind == 'store'
        and ((Config.Robberies.Teller and Config.Robberies.Teller.storeLootKey) or 'store')
        or ((Config.Robberies.Teller and Config.Robberies.Teller.lootKey) or 'bank_fleeca_soft')

    if gotBag and isBusy and not pending then
        giveLootKey(src, lootKey)
        TellerCd[src] = TellerCd[src] or {}
        TellerCd[src][key] = os.time() + ((Config.Robberies.PlayerCooldown or {})[kind] or 600)
        if kind == 'bank_fleeca' then
            TriggerClientEvent('mrp_hacking:client:tellerUnlockBooth', src, locId)
        elseif kind == 'store' and locId then
            exports['mrp_hacking']:UnlockStoreFor(src, locId, false, { cashTaken = true })
            TriggerClientEvent('QBCore:Notify', src,
                'Kasa ištuštinta. Seifą gale gali gręžti bet kada (PD kai pradedi).',
                'primary', 9000)
        end
        Busy[key] = nil
        if alertNow == false then
            PaidPendingAlert[src] = PaidPendingAlert[src] or {}
            PaidPendingAlert[src][key] = true
            return
        end
    end

    if alertNow ~= false then
        if PaidPendingAlert[src] then PaidPendingAlert[src][key] = nil end
        if Busy[key] == src then Busy[key] = nil end
        local text = kind == 'store' and '24/7 kasininko apiplėšimas' or 'Fleeca kasininko apiplėšimas'
        policeAlert(src, text)
    end
end)

RegisterNetEvent('mrp_hacking:server:tellerAbort', function(kind, locId)
    local src = source
    kind = kind == 'store' and 'store' or 'bank_fleeca'
    local key = sessionKey(kind, locId)
    if Busy[key] == src then Busy[key] = nil end
    if PaidPendingAlert[src] then PaidPendingAlert[src][key] = nil end
    policeAlert(src, kind == 'store' and '24/7 apiplėšimas — PD kvietimas' or 'Fleeca apiplėšimas — PD kvietimas')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(Busy) do
        if v == src then Busy[k] = nil end
    end
    PaidPendingAlert[src] = nil
end)

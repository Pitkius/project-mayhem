local QBCore = exports['qb-core']:GetCoreObject()

--- [src] = { [locId] = { until = os.time, silent = bool, cash = bool, perlas = bool, safe = bool } }
local Unlock = {}

local function findStore(locId)
    local list = Config.Robberies and Config.Robberies.Locations and Config.Robberies.Locations.store
    if not list then return nil end
    for _, loc in ipairs(list) do
        if loc.id == locId then return loc end
    end
    return nil
end

local function giveLootKey(src, lootKey, notifyText)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local loot = (Config.Robberies.Loot or {})[lootKey]
    if not loot then return end
    if loot.cash then
        local amount = math.random(loot.cash.min or 0, loot.cash.max or 0)
        if amount > 0 then
            Player.Functions.AddMoney('cash', amount, 'store-' .. lootKey)
            TriggerClientEvent('QBCore:Notify', src, (notifyText or 'Gavai $%s.'):format(amount), 'success')
        end
    end
    if loot.markedbills then
        local count = math.random(loot.markedbills.min or 0, loot.markedbills.max or 0)
        local worth = loot.markedbills.worth or 350
        local dirty = count * worth
        if dirty > 0 then
            Player.Functions.AddItem('markedbills', dirty, false, {})
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add', dirty)
        end
    end
end

local function getEntry(src, locId)
    local e = Unlock[src] and Unlock[src][tostring(locId)]
    if not e then return nil end
    if e.untilTs and os.time() > e.untilTs then
        Unlock[src][tostring(locId)] = nil
        return nil
    end
    return e
end

local function maybeClearSilent(src)
    local map = Unlock[src]
    if not map then
        exports['mrp_hacking']:ClearSilentHack(src)
        return
    end
    for _, e in pairs(map) do
        if e.silent and e.untilTs and os.time() <= e.untilTs then
            local cashDone = e.cashTaken == true
            local perlasDone = e.perlasTaken == true or not e.hasPerlas
            local safeDone = e.safeTaken == true
            if not (cashDone and perlasDone and safeDone) then
                return
            end
        end
    end
    exports['mrp_hacking']:ClearSilentHack(src)
end

local function policeAlert(src, text, coords)
    if GetResourceState('mrp_dispatch') ~= 'started' then return end
    local c = coords or GetEntityCoords(GetPlayerPed(src))
    exports['mrp_dispatch']:CreateDispatchCall('police', 'robbery', c, text, src)
end

--- silent=true po L1 hack; silent=false po soft (PD jau gali būti iškviesta)
exports('UnlockStoreFor', function(src, locId, silent, opts)
    src = tonumber(src)
    locId = tostring(locId or '')
    if not src or locId == '' then return end
    local loc = findStore(locId)
    if not loc then return end
    local mins = (Config.Robberies.StoreSide and Config.Robberies.StoreSide.unlockMinutes) or 12
    Unlock[src] = Unlock[src] or {}
    local prev = Unlock[src][locId] or {}
    local cashTaken = prev.cashTaken or false
    if opts and opts.cashTaken ~= nil then
        cashTaken = opts.cashTaken == true
    end
    Unlock[src][locId] = {
        untilTs = os.time() + (mins * 60),
        silent = silent == true or prev.silent == true,
        hasPerlas = loc.perlas ~= nil,
        cashTaken = cashTaken,
        perlasTaken = prev.perlasTaken or false,
        safeTaken = prev.safeTaken or false,
    }
    if silent then
        exports['mrp_hacking']:SetSilentHack(src, true)
    end
end)

exports('IsStoreUnlocked', function(src, locId)
    return getEntry(tonumber(src), locId) ~= nil
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:storeSideCan', function(src, cb, locId, kind)
    local loc = findStore(locId)
    if not loc then return cb({ ok = false, msg = 'Vieta nerasta.' }) end
    local e = getEntry(src, locId)
    if not e then
        return cb({ ok = false, msg = 'Pirmiau apiplėšk kasininką arba padaryk L1 hack.' })
    end
    kind = tostring(kind or '')
    if kind == 'cash' then
        if e.cashTaken then return cb({ ok = false, msg = 'Kasa jau ištuštinta.' }) end
        if not loc.cashRegister then return cb({ ok = false, msg = 'Nėra kasos.' }) end
        return cb({ ok = true, silent = e.silent })
    end
    if kind == 'perlas' then
        if not loc.perlas then return cb({ ok = false, msg = 'Čia nėra Perlas terminalo.' }) end
        if e.perlasTaken then return cb({ ok = false, msg = 'Perlas jau išlaužtas.' }) end
        return cb({ ok = true, silent = e.silent })
    end
    if kind == 'safe' then
        if not loc.safe then return cb({ ok = false, msg = 'Nėra seifo.' }) end
        if e.safeTaken then return cb({ ok = false, msg = 'Seifas jau atidarytas.' }) end
        local item = (Config.Robberies.StoreSide and Config.Robberies.StoreSide.safeItem) or (Config.DrillItem or 'drill')
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or not Player.Functions.GetItemByName(item) then
            return cb({ ok = false, msg = 'Reikia grąžto (drill).' })
        end
        return cb({ ok = true, silent = e.silent, needAlert = not e.silent })
    end
    cb({ ok = false, msg = 'Nežinomas veiksmas.' })
end)

RegisterNetEvent('mrp_hacking:server:storeSideLoot', function(locId, kind)
    local src = source
    local loc = findStore(locId)
    if not loc then return end
    local e = getEntry(src, locId)
    if not e then return end
    kind = tostring(kind or '')
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if kind == 'cash' then
        if e.cashTaken or not loc.cashRegister then return end
        e.cashTaken = true
        giveLootKey(src, 'store', 'Kasa: $%s')
        if not e.silent then
            policeAlert(src, '24/7 kasos apiplėšimas', loc.coords)
        end
        maybeClearSilent(src)
        return
    end

    if kind == 'perlas' then
        if e.perlasTaken or not loc.perlas then return end
        e.perlasTaken = true
        giveLootKey(src, 'store_perlas', 'Perlas: $%s')
        maybeClearSilent(src)
        return
    end

    if kind == 'safe' then
        if e.safeTaken or not loc.safe then return end
        local item = (Config.Robberies.StoreSide and Config.Robberies.StoreSide.safeItem) or (Config.DrillItem or 'drill')
        if not Player.Functions.GetItemByName(item) then
            return TriggerClientEvent('QBCore:Notify', src, 'Reikia grąžto.', 'error')
        end
        Player.Functions.RemoveItem(item, 1)
        e.safeTaken = true
        giveLootKey(src, 'store_safe', 'Seifas: $%s')
        --- PD jau kviesta pradėjus (storeSideAlert), jei ne silent
        maybeClearSilent(src)
        return
    end
end)

--- Soft be hack: seifo / Perlas pradžia kelia PD
RegisterNetEvent('mrp_hacking:server:storeSideAlert', function(locId, kind)
    local src = source
    local loc = findStore(locId)
    if not loc then return end
    local e = getEntry(src, locId)
    if not e or e.silent then return end
    kind = tostring(kind or '')
    if kind == 'safe' then
        if e.safeAlerted then return end
        e.safeAlerted = true
        local text = (Config.Robberies.StoreSide and Config.Robberies.StoreSide.alertSafeNoHack)
            or '24/7 — kas nors gręžia seifą'
        policeAlert(src, text, loc.safe and loc.safe.coords or loc.coords)
    elseif kind == 'perlas' then
        if e.perlasAlerted then return end
        e.perlasAlerted = true
        local text = (Config.Robberies.StoreSide and Config.Robberies.StoreSide.alertPerlasNoHack)
            or '24/7 — Perlas terminalo apiplėšimas'
        policeAlert(src, text, loc.perlas and loc.perlas.coords or loc.coords)
    end
end)

--- Soft / stealth serveriai kviečia šį eventą kai atrakinama
RegisterNetEvent('mrp_hacking:server:unlockStore', function(locId, silent, cashTaken)
    local src = source
    exports['mrp_hacking']:UnlockStoreFor(src, locId, silent == true, { cashTaken = cashTaken == true })
end)

AddEventHandler('playerDropped', function()
    Unlock[source] = nil
end)

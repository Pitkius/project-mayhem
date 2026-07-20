local QBCore = exports['qb-core']:GetCoreObject()

local AtmBusy = {} --- [key] = src
local PlayerCd = {}
local LocationCd = {}
local AtmSilent = {} --- [src] = true

local function atmKey(coords)
    return ('%.1f_%.1f_%.1f'):format(coords.x, coords.y, coords.z)
end

local function onCooldown(src, coords)
    local now = os.time()
    if PlayerCd[src] and now < PlayerCd[src] then
        return true, 'Palauk prieš kitą bankomatą.'
    end
    local key = atmKey(coords)
    if LocationCd[key] and now < LocationCd[key] then
        return true, 'Šis bankomatas neseniai apiplėštas.'
    end
    return false
end

local function setCooldown(src, coords)
    PlayerCd[src] = os.time() + (Config.Atm.PlayerCooldownSec or 900)
    LocationCd[atmKey(coords)] = os.time() + (Config.Atm.LocationCooldownSec or 1800)
end

--- soft = be planšetės; stealth = su L1 hack
QBCore.Functions.CreateCallback('mrp_hacking:server:atmCanStart', function(src, cb, coords, mode)
    local c = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or nil
    if not c then return cb({ ok = false }) end
    local cd, cdMsg = onCooldown(src, c)
    if cd then return cb({ ok = false, msg = cdMsg }) end
    mode = mode == 'stealth' and 'stealth' or 'soft'
    local ok, msg = exports['mrp_hacking']:CanAccessRobbery(src, 'atm', mode)
    if not ok then return cb({ ok = false, msg = msg }) end
    local key = atmKey(c)
    if AtmBusy[key] and AtmBusy[key] ~= src then
        return cb({ ok = false, msg = 'Kažkas jau dirba prie šio ATM.' })
    end
    cb({ ok = true, mode = mode })
end)

RegisterNetEvent('mrp_hacking:server:atmClaim', function(coords, silent)
    local src = source
    local c = vector3(coords.x, coords.y, coords.z)
    AtmBusy[atmKey(c)] = src
    AtmSilent[src] = silent == true
    if silent then
        exports['mrp_hacking']:SetSilentHack(src, true)
    else
        exports['mrp_hacking']:ClearSilentHack(src)
    end
end)

RegisterNetEvent('mrp_hacking:server:atmRelease', function(coords)
    local src = source
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] == src then AtmBusy[key] = nil end
    AtmSilent[src] = nil
end)

RegisterNetEvent('mrp_hacking:server:atmDrillDone', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    if not Player.Functions.GetItemByName(Config.DrillItem or 'drill') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia gręžtuvo (drill).', 'error')
    end
    Player.Functions.RemoveItem(Config.DrillItem or 'drill', 1)
    TriggerClientEvent('mrp_hacking:client:atmDrillOk', src, coords)
end)

RegisterNetEvent('mrp_hacking:server:atmChainDone', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    if not Player.Functions.GetItemByName(Config.ChainItem or 'tow_chain') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia grandinės (tow_chain).', 'error')
    end
    Player.Functions.RemoveItem(Config.ChainItem, 1)
    TriggerClientEvent('mrp_hacking:client:atmChainOk', src, coords)
end)

RegisterNetEvent('mrp_hacking:server:atmPulled', function(coords, dropIndex)
    local src = source
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    TriggerClientEvent('mrp_hacking:client:atmGoCrack', src, dropIndex)
end)

RegisterNetEvent('mrp_hacking:server:atmCrackResult', function(success, wrongStep, dropIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cfg = Config.Atm
    local cash = math.random(cfg.CashMin or 500, cfg.CashMax or 2000)
    local bills = math.random(cfg.MarkedBillMin or 1, cfg.MarkedBillMax or 2)
    local worth = cfg.MarkedBillWorth or 400
    local silent = AtmSilent[src] == true or exports['mrp_hacking']:IsSilentHack(src)

    if not success then
        if wrongStep and math.random() < (cfg.DyePackChance or 0.2) then
            cash = math.floor(cash * (1.0 - (cfg.DyeDamagePct or 0.5)))
            bills = math.max(0, bills - 1)
            TriggerClientEvent('QBCore:Notify', src, 'Dye pack sudegino dalį pinigų!', 'error')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Nepavyko – ATM pažeistas.', 'error')
            local c = GetEntityCoords(GetPlayerPed(src))
            MRP_DispatchAlert('police', 'atm', c, 'Nepavykęs bankomato apiplėšimas', src)
            return
        end
    end

    Player.Functions.AddMoney('cash', cash, 'atm-robbery')
    if bills > 0 then
        local dirty = bills * worth
        Player.Functions.AddItem('markedbills', dirty, false, {})
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add', dirty)
    end
    if math.random() < 0.12 then
        Player.Functions.AddItem('rolex', 1)
    end

    setCooldown(src, GetEntityCoords(GetPlayerPed(src)))
    for k, v in pairs(AtmBusy) do
        if v == src then AtmBusy[k] = nil end
    end
    AtmSilent[src] = nil
    exports['mrp_hacking']:ClearSilentHack(src)

    TriggerClientEvent('QBCore:Notify', src, ('Gavai $%s + marked bills.'):format(cash), 'success')
    TriggerClientEvent('mrp_hacking:client:atmFinished', src)

    if success and GetResourceState('mrp_gangs') == 'started' then
        pcall(function()
            local c = GetEntityCoords(GetPlayerPed(src))
            exports['mrp_gangs']:OnHackSuccess(src, 'atm', { x = c.x, y = c.y, z = c.z })
        end)
    end

    --- Soft (be stealth) — PD gauna; stealth hack — ne
    if not silent then
        local c = GetEntityCoords(GetPlayerPed(src))
        MRP_DispatchAlert('police', 'atm', c, 'Pranešta apie išlaužtą bankomatą', src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(AtmBusy) do
        if v == src then AtmBusy[k] = nil end
    end
    AtmSilent[src] = nil
end)

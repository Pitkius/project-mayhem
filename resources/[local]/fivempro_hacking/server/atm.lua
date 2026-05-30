local QBCore = exports['qb-core']:GetCoreObject()

local AtmBusy = {}
local PlayerCd = {}
local LocationCd = {}

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

QBCore.Functions.CreateCallback('fivempro_hacking:server:atmCanStart', function(src, cb, coords)
    local c = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or nil
    if not c then return cb({ ok = false }) end
    local cd, cdMsg = onCooldown(src, c)
    if cd then return cb({ ok = false, msg = cdMsg }) end
    local ok, msg = exports['fivempro_hacking']:CanAccessRobbery(src, 'atm')
    if not ok then return cb({ ok = false, msg = msg }) end
    local key = atmKey(c)
    if AtmBusy[key] and AtmBusy[key] ~= src then
        return cb({ ok = false, msg = 'Kažkas jau dirba prie šio ATM.' })
    end
    cb({ ok = true })
end)

RegisterNetEvent('fivempro_hacking:server:atmClaim', function(coords)
    local src = source
    local c = vector3(coords.x, coords.y, coords.z)
    AtmBusy[atmKey(c)] = src
end)

RegisterNetEvent('fivempro_hacking:server:atmRelease', function(coords)
    local src = source
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] == src then AtmBusy[key] = nil end
end)

RegisterNetEvent('fivempro_hacking:server:atmPhase', function(coords, phase)
    local src = source
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    TriggerClientEvent('fivempro_hacking:client:atmPhaseAck', src, phase)
end)

RegisterNetEvent('fivempro_hacking:server:atmDrillDone', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    if not Player.Functions.GetItemByName(Config.DrillItem or 'drill') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia gręžtuvo (drill).', 'error')
    end
    Player.Functions.RemoveItem(Config.DrillItem or 'drill', 1)
    TriggerClientEvent('fivempro_hacking:client:atmDrillOk', src, coords)
end)

RegisterNetEvent('fivempro_hacking:server:atmChainDone', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    if not Player.Functions.GetItemByName(Config.ChainItem or 'tow_chain') then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia grandinės (tow_chain).', 'error')
    end
    Player.Functions.RemoveItem(Config.ChainItem, 1)
    TriggerClientEvent('fivempro_hacking:client:atmChainOk', src, coords)
end)

RegisterNetEvent('fivempro_hacking:server:atmPulled', function(coords, dropIndex)
    local src = source
    local key = atmKey(vector3(coords.x, coords.y, coords.z))
    if AtmBusy[key] ~= src then return end
    TriggerClientEvent('fivempro_hacking:client:atmGoCrack', src, dropIndex)
end)

RegisterNetEvent('fivempro_hacking:server:atmCrackResult', function(success, wrongStep, dropIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cfg = Config.Atm
    local cash = math.random(cfg.CashMin or 500, cfg.CashMax or 2000)
    local bills = math.random(cfg.MarkedBillMin or 1, cfg.MarkedBillMax or 2)
    local worth = cfg.MarkedBillWorth or 400

    if not success then
        if wrongStep and math.random() < (cfg.DyePackChance or 0.2) then
            cash = math.floor(cash * (1.0 - (cfg.DyeDamagePct or 0.5)))
            bills = math.max(0, bills - 1)
            TriggerClientEvent('QBCore:Notify', src, 'Dye pack sudegino dalį pinigų!', 'error')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Nepavyko – ATM pažeistas.', 'error')
            return
        end
    end

    Player.Functions.AddMoney('cash', cash, 'atm-robbery')
    if bills > 0 then
        Player.Functions.AddItem('markedbills', bills, false, { worth = worth })
    end
    if math.random() < 0.12 then
        Player.Functions.AddItem('rolex', 1)
    end

    setCooldown(src, GetEntityCoords(GetPlayerPed(src)))
    for k, v in pairs(AtmBusy) do
        if v == src then AtmBusy[k] = nil end
    end

    TriggerClientEvent('QBCore:Notify', src, ('Gavai $%s + marked bills.'):format(cash), 'success')
    TriggerClientEvent('fivempro_hacking:client:atmFinished', src)

    if success and GetResourceState('fivempro_gangs') == 'started' then
        pcall(function()
            local c = GetEntityCoords(GetPlayerPed(src))
            exports['fivempro_gangs']:OnHackSuccess(src, 'atm', { x = c.x, y = c.y, z = c.z })
        end)
    elseif not success and GetResourceState('fivempro_gangs') == 'started' then
        pcall(function()
            local c = GetEntityCoords(GetPlayerPed(src))
            exports['fivempro_gangs']:OnHackFailed(src, 'atm', { x = c.x, y = c.y, z = c.z })
        end)
    end

    if GetResourceState('fivempro_dispatch') == 'started' then
        local c = GetEntityCoords(GetPlayerPed(src))
        exports['fivempro_dispatch']:CreateDispatchCall('police', 'atm', c, 'Pranešta apie išlaužtą bankomatą', src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for k, v in pairs(AtmBusy) do
        if v == src then AtmBusy[k] = nil end
    end
end)

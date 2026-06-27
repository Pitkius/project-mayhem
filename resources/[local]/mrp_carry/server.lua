local QBCore = exports['qb-core']:GetCoreObject()

---@type table<number, { peer: number, variant: number }>
local PairMeta = {}

local function clearPair(a, b)
    PairMeta[a] = nil
    PairMeta[b] = nil
    local pa = Player(a).state
    local pb = Player(b).state
    if pa then pa:set('fivemproCarryPeer', nil, true) end
    if pb then pb:set('fivemproCarryPeer', nil, true) end
end

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function getPedOrNil(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return ped
end

local function pedDistance(a, b)
    local p1, p2 = getPedOrNil(a), getPedOrNil(b)
    if not p1 or not p2 then return nil end
    return #(GetEntityCoords(p1) - GetEntityCoords(p2))
end

local function isBlockedPlayer(src)
    local p = QBCore.Functions.GetPlayer(src)
    if not p then return true, 'Žaidėjas nerastas.' end
    local m = p.PlayerData.metadata or {}
    if m.isdead or m.inlaststand then
        return true, 'Šiuo metu negalima.'
    end
    if m.ishandcuffed then
        return true, 'Su antrankiais negalima.'
    end
    local ped = getPedOrNil(src)
    if not ped then return true, 'Veikėjas dar neparuoštas.' end
    if IsPedInAnyVehicle(ped, false) then
        return true, 'Transporte negalima.'
    end
    local st = Player(src).state
    if st and st.ltpdCuffed then
        return true, 'Su LTPD antrankiais negalima.'
    end
    return false
end

local function beginCarry(carrier, target, variant)
    PairMeta[carrier] = { peer = target, variant = variant }
    PairMeta[target] = { peer = carrier, variant = variant }

    Player(carrier).state:set('fivemproCarryPeer', target, true)
    Player(target).state:set('fivemproCarryPeer', carrier, true)

    TriggerClientEvent('mrp_carry:client:start', carrier, {
        role = 'carrier',
        peer = target,
        variant = variant,
    })
    TriggerClientEvent('mrp_carry:client:start', target, {
        role = 'carried',
        peer = carrier,
        variant = variant,
    })
end

RegisterNetEvent('mrp_carry:server:request', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local target = tonumber(payload.target)
    local variant = tonumber(payload.variant)
    if not target or not variant or not Config.Variants[variant] then
        notify(src, 'Prašymas netinkamas.', 'error')
        return
    end

    if target == src then
        notify(src, 'Savęs nešti negali.', 'error')
        return
    end

    if PairMeta[src] or PairMeta[target] then
        notify(src, 'Vienas iš jūsų jau neša ar būna nešamas.', 'error')
        return
    end

    local blocker, msg = isBlockedPlayer(src)
    if blocker then
        notify(src, msg, 'error')
        return
    end
    blocker, msg = isBlockedPlayer(target)
    if blocker then
        notify(src, 'Tikslas šiuo metu negali sutikti.', 'error')
        return
    end

    if not QBCore.Functions.GetPlayer(target) then
        notify(src, 'Žaidėjas neprisijungęs.', 'error')
        return
    end

    local dist = pedDistance(src, target)
    if not dist or dist > Config.MaxDistance + 0.25 then
        notify(src, 'Per toli nuo žaidėjo.', 'error')
        return
    end

    beginCarry(src, target, variant)
    notify(src, 'Nešimas pradėtas.', 'success')
end)

RegisterNetEvent('mrp_carry:server:breakPair', function()
    local src = source
    local meta = PairMeta[src]
    if not meta then return end
    local peer = meta.peer
    clearPair(src, peer)
    TriggerClientEvent('mrp_carry:client:stop', src)
    TriggerClientEvent('mrp_carry:client:stop', peer)
end)

RegisterNetEvent('mrp_carry:server:stop', function()
    local src = source
    local meta = PairMeta[src]
    if not meta then
        notify(src, 'Tu neši nieko ir tavęs niekas neneša.', 'error')
        return
    end

    local peer = meta.peer
    clearPair(src, peer)
    TriggerClientEvent('mrp_carry:client:stop', src)
    TriggerClientEvent('mrp_carry:client:stop', peer)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local meta = PairMeta[src]
    if meta then
        local peer = meta.peer
        clearPair(src, peer)
        TriggerClientEvent('mrp_carry:client:stop', peer)
    end
end)

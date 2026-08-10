--[[
  Premium shop purchases paid with credits (1 EUR = 1 CR via Tebex).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local VIP_PRICES = {
    SILVER = { price = 500, days = 30 },
    GOLD = { price = 1200, days = 30 },
    DIAMOND = { price = 2500, days = 30 },
}

local CRATE_PRICES = {
    deze_legali = 350,
    deze_exp = 400,
    deze_nelegali = 550,
}

local function spend(src, amount, reason)
    if GetResourceState('mrp_credits') ~= 'started' then
        return false, 'credits_resource'
    end
    return exports['mrp_credits']:RemoveCredits(src, amount, reason)
end

local function pushBalance(src)
    if GetResourceState('mrp_credits') ~= 'started' then return end
    local bal = exports['mrp_credits']:GetCredits(src)
    TriggerClientEvent('mrp_dashboard:client:setCredits', src, bal)
end

RegisterNetEvent('mrp_dashboard:server:purchaseCrate', function(crateId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    crateId = tostring(crateId or '')
    local price = CRATE_PRICES[crateId]
    if not price then
        TriggerClientEvent('QBCore:Notify', src, 'Šios dėžės pirkti negalima.', 'error')
        return
    end
    local ok, err = spend(src, price, 'buy-crate-' .. crateId)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, err == 'insufficient' and 'Nepakanka kreditų.' or 'Pirkimas nepavyko.', 'error')
        return
    end
    if not Player.Functions.AddItem(crateId, 1) then
        exports['mrp_credits']:AddCredits(src, price, 'refund-crate')
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas — kreditai grąžinti.', 'error')
        return
    end
    local item = QBCore.Shared.Items[crateId]
    if item then
        TriggerClientEvent('inventory:client:ItemBox', src, item, 'add')
    end
    pushBalance(src)
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta už %s CR. Atidaryk inventoriuje.'):format(price), 'success')
end)

RegisterNetEvent('mrp_dashboard:server:purchaseImport', function(vehicleId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- Price comes from client validation stub — real vehicle grant later
    local price = tonumber(vehicleId and 0) -- placeholder; client sends id, lookup below
    TriggerClientEvent('QBCore:Notify', src, 'Importų pristatymas ruošiamas — kaina bus nuskaičiuota iš CR.', 'primary')
end)

RegisterNetEvent('mrp_dashboard:server:buyVip', function(planId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    planId = tostring(planId or ''):upper()
    local plan = VIP_PRICES[planId]
    if not plan then
        TriggerClientEvent('QBCore:Notify', src, 'Nežinomas VIP planas.', 'error')
        return
    end
    local ok, err = spend(src, plan.price, 'buy-vip-' .. planId)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, err == 'insufficient' and 'Nepakanka kreditų.' or 'Pirkimas nepavyko.', 'error')
        return
    end
    local meta = Player.PlayerData.metadata or {}
    local vipUntil = tonumber(meta.vip_until) or 0
    local now = os.time()
    if vipUntil < now then vipUntil = now end
    vipUntil = vipUntil + (plan.days * 86400)
    Player.Functions.SetMetaData('vip', planId)
    Player.Functions.SetMetaData('vip_until', vipUntil)
    pushBalance(src)
    TriggerClientEvent('mrp_dashboard:client:setVip', src, planId, math.ceil((vipUntil - now) / 86400))
    TriggerClientEvent('QBCore:Notify', src, ('VIP %s aktyvuotas %s d. (−%s CR)'):format(planId, plan.days, plan.price), 'success')
end)

RegisterNetEvent('mrp_dashboard:server:openTebex', function()
    local src = source
    local url = 'https://mayhem.tebex.io/'
    if GetResourceState('mrp_credits') == 'started' then
        url = exports['mrp_credits']:GetStoreUrl() or url
    end
    TriggerClientEvent('QBCore:Notify', src, 'Atidaryk Tebex parduotuvę naršyklėje (nuoroda chate / Discord).', 'primary')
    TriggerClientEvent('chat:addMessage', src, {
        color = { 167, 139, 250 },
        args = { 'Mayhem', ('Kreditai: 1€ = 1 CR · %s'):format(url) },
    })
end)

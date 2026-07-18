--[[
  mrp_jobs — VAPE supirkimas (serveris).
  Gamybos sesijas, ingredientus ir atlygius autoritetingai valdo mrp_drugs.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local FL = Config.Locations.fruit
local RV = Config.Rewards.vape

-- ── Vape pardavimas ───────────────────────────────────────────────
local function priceFor(itemName)
    if itemName == Config.VapeSimple.sellItem then return RV.simpleBase end
    for _, f in pairs(Config.VapeFlavors) do
        if f.finalItem == itemName then
            return math.floor(RV.simpleBase * (f.valueMultiplier or 1.0))
        end
    end
    return nil
end

QBCore.Functions.CreateCallback('mrp_jobs:server:vape:sell', function(src, cb, itemName)
    if not Security.rateLimit(src, 'vape_sell', 1000) then return cb({ ok = false, reason = 'rate' }) end
    if not Security.isNear(src, FL.vapeBuyer.coords, FL.vapeBuyer.radius or 4.0) then return cb({ ok = false, reason = 'too_far' }) end
    local unit = priceFor(itemName)
    if not unit then return cb({ ok = false, reason = 'bad_item' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    local it = Player.Functions.GetItemByName(itemName)
    if not it or it.amount <= 0 then return cb({ ok = false, reason = 'none' }) end
    local n = it.amount
    if not Player.Functions.RemoveItem(itemName, n, nil, 'vape-sell') then return cb({ ok = false, reason = 'remove_fail' }) end
    local total = unit * n
    Rewards.pay(src, total, RV.account or 'cash', 'vape-sell', { item = itemName, count = n })
    cb({ ok = true, pay = total, count = n })
end)

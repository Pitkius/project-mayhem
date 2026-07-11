--[[
  mrp_jobs — VAPE gamyba (serveris). Du keliai:
    1) Paprastas vape (be vaisių) — trumpas, pigus.
    2) Vaisinis vape — vaisius → koncentratas → vape skystis (ilgesnis, brangesnis).
  Rišasi su esamais mrp_drugs itemais (vape_liquid_base, empty_bottle, vape_liquid).
  Nesusietas su darbo sesija — tai gamybos stotelė; sauganti logika = ingredientų
  patikra + minigame tokenas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local FL = Config.Locations.fruit
local RV = Config.Rewards.vape
local pending = {} -- [src] = { token, inputs, output, outputAmount, at }

local function hasAll(Player, inputs)
    for _, ing in ipairs(inputs) do
        local it = Player.Functions.GetItemByName(ing.item)
        if not it or it.amount < ing.count then return false, ing end
    end
    return true
end

local function removeAll(Player, inputs)
    for _, ing in ipairs(inputs) do
        if not Player.Functions.RemoveItem(ing.item, ing.count, nil, 'vape-craft') then return false end
    end
    return true
end

-- Sukuria recepto aprašą pagal tipą.
local function buildRecipe(kind, arg)
    if kind == 'simple' then
        return { inputs = Config.VapeSimple.recipe, output = Config.VapeSimple.output, amount = Config.VapeSimple.outputAmount or 1, station = FL.processing.mix.coords, minigame = Config.VapeSimple.minigame }
    elseif kind == 'concentrate' then
        local c = Config.Concentrates[arg]
        if not c then return nil end
        return { inputs = { { item = c.fruitItem, count = c.fruitAmount } }, output = c.output, amount = 1, station = FL.processing.wash.coords, minigame = c.steps and c.steps[1] or 'concentrate_wash', steps = c.steps }
    elseif kind == 'flavored' then
        local f = Config.VapeFlavors[arg]
        if not f then return nil end
        return { inputs = { { item = f.concentrateItem, count = 1 }, { item = f.baseItem, count = 1 }, { item = f.bottleItem, count = 1 } }, output = f.finalItem, amount = 1, station = FL.processing.mix.coords, minigame = f.minigame or 'concentrate_press' }
    end
    return nil
end

-- ── Gamybos pradžia ───────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:vape:start', function(src, cb, kind, arg)
    if not Security.rateLimit(src, 'vape_craft', 900) then return cb({ ok = false, reason = 'rate' }) end
    local recipe = buildRecipe(kind, arg)
    if not recipe then return cb({ ok = false, reason = 'bad_recipe' }) end
    if not Security.isNear(src, recipe.station, 3.0) then return cb({ ok = false, reason = 'too_far' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    local ok, missing = hasAll(Player, recipe.inputs)
    if not ok then return cb({ ok = false, reason = 'missing', item = missing and missing.item }) end

    local token = ('%d-%d'):format(src, GetGameTimer())
    pending[src] = { token = token, inputs = recipe.inputs, output = recipe.output, amount = recipe.amount, at = GetGameTimer() }
    cb({ ok = true, token = token, minigame = recipe.minigame, steps = recipe.steps })
end)

-- ── Gamybos pabaiga ───────────────────────────────────────────────
QBCore.Functions.CreateCallback('mrp_jobs:server:vape:finish', function(src, cb, token, success)
    local p = pending[src]
    pending[src] = nil
    if not p or p.token ~= token then return cb({ ok = false, reason = 'bad_token' }) end
    if GetGameTimer() - p.at > 90000 then return cb({ ok = false, reason = 'expired' }) end
    if success ~= true then return cb({ ok = false, reason = 'failed' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'no_player' }) end
    -- Pakartotinė patikra + pašalinimas (atomiškumui).
    local ok = hasAll(Player, p.inputs)
    if not ok then return cb({ ok = false, reason = 'missing' }) end
    if not removeAll(Player, p.inputs) then return cb({ ok = false, reason = 'remove_fail' }) end
    if not Player.Functions.AddItem(p.output, p.amount, false, nil, 'vape-craft') then
        return cb({ ok = false, reason = 'inv_full' })
    end
    cb({ ok = true, output = p.output, amount = p.amount })
end)

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

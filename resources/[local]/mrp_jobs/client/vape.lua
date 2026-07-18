--[[
  mrp_jobs — VAPE gamyba (klientas). Stotelės: plovimas/smulkinimas (koncentratas),
  maišymas (paprastas + vaisinis vape), supirkimas (pardavimas).
]]

local FL = Config.Locations.fruit
local ready = false
local crafting = false
local activeCraftId = 0

local PRODUCT_IDS = {
    simple = {
        default = 'vape_simple',
    },
    concentrate = {
        apple = 'vape_apple_concentrate',
        strawberry = 'vape_strawberry_concentrate',
    },
    flavored = {
        apple = 'vape_apple_pack',
        strawberry = 'vape_strawberry_pack',
    },
}

local function productIdFor(kind, arg)
    local products = PRODUCT_IDS[kind]
    if not products then return nil end
    return products[arg or 'default']
end

local function craftError(res, fallback)
    if res and type(res.reason) == 'string' and res.reason ~= '' then
        return res.reason
    end
    return fallback or 'Nepavyko.'
end

-- Bendras gamybos vykdymas (mrp_drugs start → 3D gamyba → finish).
local function runCraft(kind, arg, label)
    if crafting then
        return Notify('Gamyba jau vyksta.', 'error')
    end

    local productId = productIdFor(kind, arg)
    if not productId then
        return Notify('Nėra tokio vape recepto.', 'error')
    end

    crafting = true
    activeCraftId = activeCraftId + 1
    local craftId = activeCraftId
    local startResolved = false
    local startAbandoned = false

    QBCore.Functions.TriggerCallback('mrp_drugs:server:startNamedVapeCraft', function(res)
        startResolved = true
        if startAbandoned or craftId ~= activeCraftId then
            if res and res.ok and type(res.token) == 'string' and res.token ~= '' then
                QBCore.Functions.TriggerCallback('mrp_drugs:server:finishCraft', function() end, res.token, false, {
                    reason = 'start_callback_timeout',
                })
            end
            return
        end
        if not res or not res.ok then
            crafting = false
            return Notify(craftError(res, 'Nepavyko pradėti gamybos.'), 'error')
        end

        if type(res.token) ~= 'string' or res.token == '' then
            crafting = false
            return Notify('Serveris negrąžino gamybos rakto.', 'error')
        end

        local completed = false
        local function finish(success, extra)
            if completed or craftId ~= activeCraftId then return end
            completed = true
            crafting = false
            QBCore.Functions.TriggerCallback('mrp_drugs:server:finishCraft', function(done)
                if craftId ~= activeCraftId then return end
                if done and done.ok then
                    local madeLabel = done.label or label or 'Vape gaminys'
                    Notify(('Pagaminta: %s x%d'):format(madeLabel, tonumber(done.amount) or 1), 'success')
                else
                    Notify(craftError(done, 'Gamyba nepavyko.'), 'error')
                end
            end, res.token, success == true, type(extra) == 'table' and extra or {})
        end

        local started = false
        local ok, result = pcall(function()
            return exports['mrp_drugs']:RunVapeProduction(productId, res, finish)
        end)
        started = ok and result == true

        if not started then
            local profile = res.profile or res.minigameProfile or res.scheduleProfile
            local prod = res.product or res.prod or {
                label = res.label or label,
                outputAmount = res.outputAmount or res.amount or 1,
                level = res.level or 1,
            }
            ok, result = pcall(function()
                return exports['mrp_drugs']:RunScheduleMinigame(
                    productId,
                    profile,
                    prod,
                    finish,
                    res.token,
                    res.workspace
                )
            end)
            started = ok and (result == true or result == nil)
        end

        if not started then
            Notify('Vape gamybos modulis nepasiekiamas.', 'error')
            finish(false, { reason = 'production_export_unavailable' })
            return
        end

        -- Apsauga nuo eksporto, kuris negrąžina rezultato.
        SetTimeout(math.max(tonumber(res.timeoutMs) or 180000, 30000), function()
            if not completed and craftId == activeCraftId then
                Notify('Gamybos laikas baigėsi.', 'error')
                finish(false, { reason = 'client_timeout' })
            end
        end)
    end, productId)

    SetTimeout(15000, function()
        if craftId == activeCraftId and not startResolved then
            startAbandoned = true
            crafting = false
            Notify('Gamybos serveris neatsakė.', 'error')
        end
    end)
end

-- Meniu: koncentrato gamyba
local function openConcentrateMenu()
    local menu = { { header = 'Koncentrato gamyba', txt = 'Perdirbk vaisius', isMenuHeader = true } }
    for fruitId, c in pairs(Config.Concentrates) do
        local fr = Config.Fruits[fruitId]
        menu[#menu + 1] = {
            header = ('%s koncentratas'):format(fr and fr.label or fruitId),
            txt = ('Reikia %d %s'):format(c.fruitAmount, fr and fr.label or c.fruitItem),
            params = { event = 'mrp_jobs:client:vape:make', args = { kind = 'concentrate', arg = fruitId, label = 'Gaminamas koncentratas' } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

-- Meniu: vape skysčio gamyba (paprastas + vaisinis)
local function openMixMenu()
    local menu = { { header = 'Vape skysčio gamyba', txt = 'Pasirink receptą', isMenuHeader = true } }
    menu[#menu + 1] = {
        header = 'Paprastas vape skystis', txt = 'Be vaisių · pigesnis',
        params = { event = 'mrp_jobs:client:vape:make', args = { kind = 'simple', label = 'Gaminamas vape skystis' } },
    }
    for fruitId, f in pairs(Config.VapeFlavors) do
        local fr = Config.Fruits[fruitId]
        menu[#menu + 1] = {
            header = ('%s vape skystis'):format(fr and fr.label or fruitId),
            txt = 'Vaisinis · brangesnis',
            params = { event = 'mrp_jobs:client:vape:make', args = { kind = 'flavored', arg = fruitId, label = 'Gaminamas vaisinis vape' } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

-- Meniu: pardavimas
local function openSellMenu()
    local menu = { { header = 'Vape supirkimas', txt = 'Parduok skystį', isMenuHeader = true } }
    local items = { Config.VapeSimple.sellItem }
    for _, f in pairs(Config.VapeFlavors) do items[#items + 1] = f.finalItem end
    for _, item in ipairs(items) do
        local label = (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item
        menu[#menu + 1] = {
            header = label, txt = 'Parduoti visus turimus',
            params = { event = 'mrp_jobs:client:vape:sell', args = { item = item } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('mrp_jobs:client:vape:make', function(args)
    if type(args) ~= 'table' then return end
    runCraft(args.kind, args.arg, args.label)
end)

RegisterNetEvent('mrp_jobs:client:vape:sell', function(args)
    if type(args) ~= 'table' or type(args.item) ~= 'string' then return end
    QBCore.Functions.TriggerCallback('mrp_jobs:server:vape:sell', function(res)
        if res and res.ok then Notify(('Pardavei %d vnt. +$%d'):format(res.count, res.pay), 'success')
        else
            local msg = { none = 'Neturi šio skysčio.', too_far = 'Per toli.', bad_item = 'Neperkama.' }
            Notify(msg[res and res.reason] or 'Nepavyko parduoti.', 'error')
        end
    end, args.item)
end)

CreateThread(function()
    if ready then return end
    ready = true
    Wait(1800)
    local P = FL.processing
    exports['qb-target']:AddCircleZone('mrp_jobs_vape_wash', vector3(P.wash.coords.x, P.wash.coords.y, P.wash.coords.z), 1.4, { name = 'mrp_jobs_vape_wash', useZ = true }, {
        options = { { icon = 'fas fa-blender', label = P.wash.label or 'Koncentrato gamyba', action = function() openConcentrateMenu() end } },
        distance = 2.0,
    })
    exports['qb-target']:AddCircleZone('mrp_jobs_vape_mix', vector3(P.mix.coords.x, P.mix.coords.y, P.mix.coords.z), 1.4, { name = 'mrp_jobs_vape_mix', useZ = true }, {
        options = { { icon = 'fas fa-flask', label = P.mix.label or 'Vape skysčio gamyba', action = function() openMixMenu() end } },
        distance = 2.0,
    })
    local vb = FL.vapeBuyer
    exports['qb-target']:AddCircleZone('mrp_jobs_vape_buyer', vector3(vb.coords.x, vb.coords.y, vb.coords.z), vb.radius or 4.0, { name = 'mrp_jobs_vape_buyer', useZ = true }, {
        options = { { icon = 'fas fa-dollar-sign', label = vb.label or 'Parduoti vape', action = function() openSellMenu() end } },
        distance = vb.radius or 4.0,
    })
end)

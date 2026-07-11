--[[
  mrp_jobs — VAPE gamyba (klientas). Stotelės: plovimas/smulkinimas (koncentratas),
  maišymas (paprastas + vaisinis vape), supirkimas (pardavimas).
]]

local FL = Config.Locations.fruit
local ready = false

-- Bendras gamybos vykdymas (start → minigame(-ai) → finish).
local function runCraft(kind, arg, label)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:vape:start', function(res)
        if not res or not res.ok then
            local msg = { missing = ('Trūksta: %s'):format(res and res.item or '?'), too_far = 'Per toli nuo stotelės.', rate = 'Per greitai.', bad_recipe = 'Nėra recepto.' }
            Notify(msg[res and res.reason] or 'Nepavyko pradėti.', 'error'); return
        end
        local success = true
        -- Koncentratui — keli etapai; kitiems — vienas.
        local steps = res.steps or { res.minigame }
        for _, mgKey in ipairs(steps) do
            local ok = Minigame.run(Config.GetMinigame(mgKey, { label = label }))
            if not ok then success = false break end
        end
        QBCore.Functions.TriggerCallback('mrp_jobs:server:vape:finish', function(done)
            if done and done.ok then Notify('Pagaminta!', 'success')
            else
                local msg = { missing = 'Trūksta sudedamųjų.', inv_full = 'Inventorius pilnas.', failed = 'Nepavyko.' }
                Notify(msg[done and done.reason] or 'Nepavyko.', 'error')
            end
        end, res.token, success)
    end, kind, arg)
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
    runCraft(args.kind, args.arg, args.label)
end)

RegisterNetEvent('mrp_jobs:client:vape:sell', function(args)
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

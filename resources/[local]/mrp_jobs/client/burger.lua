--[[
  mrp_jobs — Burger Joint klientas: registracija, kasos/virtuvės NUI,
  self-service pirkimas, kepimo minigame, maisto valgymas.
]]

local joints = Config.Locations.burger.joints
local registerPeds = {}
local uiOpen = false
local lastOrders = {}     -- kasos lenta (cache)
local lastKitchen = {}    -- virtuvės lenta (cache)

local function onBurger(role, jointId)
    local st = JobClient.get()
    if not st or st.jobType ~= 'burger' then return false end
    if role and st.role ~= role then return false end
    if jointId and st.locationId ~= jointId then return false end
    return true
end

-- ── Vaidmens pasirinkimo meniu (per burgerinę) ────────────────────
local function openRoleMenu(jointId)
    local menu = { { header = joints[jointId].label, txt = 'Pasirink poziciją', isMenuHeader = true } }
    for _, r in ipairs(Config.Jobs.burger.roles) do
        menu[#menu + 1] = {
            header = r.label, txt = '',
            params = { event = 'mrp_jobs:client:pickRole', args = { jobType = 'burger', role = r.id, locationId = jointId } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

-- ── Self-service maisto pirkimas ──────────────────────────────────
local function openSelfService(jointId)
    local SS = Config.Rewards.burgerNpcSelfService
    if not SS.enabled then Notify('Šiuo metu neaptarnaujama.', 'error'); return end
    local menu = { { header = 'Užsisakyti maisto', txt = 'Savitarna (nėra darbuotojų)', isMenuHeader = true } }
    for item, price in pairs(SS.prices) do
        local label = (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item
        menu[#menu + 1] = {
            header = ('%s — $%d'):format(label, price), txt = '',
            params = { event = 'mrp_jobs:client:burger:buy', args = { jointId = jointId, item = item } },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('mrp_jobs:client:burger:buy', function(args)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:buyFood', function(res)
        if res and res.ok then
            Notify('Nusipirkai maisto.', 'success')
        else
            local msg = { staffed = 'Kreipkis į kasininką.', no_money = 'Nepakanka pinigų.', inv_full = 'Inventorius pilnas.', too_far = 'Per toli nuo kasos.', disabled = 'Neaptarnaujama.' }
            Notify(msg[res and res.reason] or 'Nepavyko.', 'error')
        end
    end, args.jointId, args.item)
end)

-- ── Registracijos / kasos NPC kiekvienoje burgerinėje ─────────────
local function spawnRegisterNpc(jointId, joint)
    local rn = joint.registerNpc
    local m = LoadModel(rn.model)
    if not m then return end
    local c = rn.coords
    local ped = CreatePed(0, m, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(ped, true); SetBlockingOfNonTemporaryEvents(ped, true); FreezeEntityPosition(ped, true)
    if rn.scenario then TaskStartScenarioInPlace(ped, rn.scenario, 0, true) end
    SetModelAsNoLongerNeeded(m)
    registerPeds[#registerPeds + 1] = ped

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            { icon = 'fas fa-briefcase', label = 'Dirbti čia', canInteract = function() return not JobClient.isOnJob('burger') end,
              action = function() openRoleMenu(jointId) end },
            { icon = 'fas fa-burger', label = 'Užsisakyti maisto (savitarna)',
              canInteract = function() return not JobClient.isOnJob('burger') end,
              action = function() openSelfService(jointId) end },
            { icon = 'fas fa-flag-checkered', label = 'Baigti darbą', canInteract = function() return JobClient.isOnJob('burger') end,
              action = function() TriggerServerEvent('mrp_jobs:server:stopJob') end },
        },
        distance = Config.Target.npcDistance or 2.5,
    })
end

-- ── Kasos / virtuvės zonos ────────────────────────────────────────
local function setupJointZones(jointId, joint)
    for _, reg in ipairs(joint.registers or {}) do
        local zc = reg.coords
        exports['qb-target']:AddBoxZone('mrp_jobs_reg_' .. jointId .. '_' .. reg.id, vector3(zc.x, zc.y, zc.z), 1.4, 1.0, {
            name = 'mrp_jobs_reg_' .. jointId .. '_' .. reg.id, heading = zc.w or 0.0, minZ = zc.z - 1.2, maxZ = zc.z + 1.2, debugPoly = false,
        }, {
            options = {
                { icon = 'fas fa-cash-register', label = 'Kasa', canInteract = function() return onBurger('cashier', jointId) end,
                  action = function() openBoard('cashier', jointId) end },
            },
            distance = Config.Target.zoneDistance or 2.2,
        })
    end
    for _, k in ipairs(joint.kitchen or {}) do
        local zc = k.coords
        exports['qb-target']:AddBoxZone('mrp_jobs_kit_' .. jointId .. '_' .. k.id, vector3(zc.x, zc.y, zc.z), 1.4, 1.0, {
            name = 'mrp_jobs_kit_' .. jointId .. '_' .. k.id, heading = zc.w or 0.0, minZ = zc.z - 1.2, maxZ = zc.z + 1.2, debugPoly = false,
        }, {
            options = {
                { icon = 'fas fa-fire-burner', label = 'Virtuvė', canInteract = function()
                    return onBurger('cook', jointId) or (onBurger('cashier', jointId) and Config.Jobs.burger.solo)
                  end,
                  action = function() openBoard('kitchen', jointId) end },
            },
            distance = Config.Target.zoneDistance or 2.2,
        })
    end
end

-- ── NUI atidarymas / duomenų atnaujinimas ─────────────────────────
local function buildItemLabels()
    local labels = {}
    for item in pairs(Config.Rewards.burger.perItem) do
        labels[item] = (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item
    end
    return labels
end

function openBoard(view, jointId)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:getBoard', function(data)
        if not data then Notify('Nepavyko atidaryti.', 'error'); return end
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'itemLabels', data = buildItemLabels() })
        SendNUIMessage({ action = 'burgerOpen', data = { view = view, role = data.role, jointId = jointId, orders = data.orders or {} } })
    end)
end

RegisterNetEvent('mrp_jobs:client:burger:orders', function(list)
    lastOrders = list or {}
    if uiOpen then SendNUIMessage({ action = 'burgerOrders', data = lastOrders }) end
end)

RegisterNetEvent('mrp_jobs:client:burger:kitchen', function(list)
    lastKitchen = list or {}
    if uiOpen then SendNUIMessage({ action = 'burgerKitchen', data = lastKitchen }) end
end)

-- ── NUI callback'ai ───────────────────────────────────────────────
RegisterNUICallback('burger:close', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('burger:confirm', function(data, cb)
    if data and data.orderId then
        TriggerServerEvent('mrp_jobs:server:burger:confirmOrder', data.orderId)
    end
    cb('ok')
end)

RegisterNUICallback('burger:serve', function(data, cb)
    if data and data.orderId then
        QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:serve', function(res)
            if res and res.ok then Notify(('Užsakymas priduotas! +$%d'):format(res.total), 'success')
            else
                local msg = { not_ready = 'Užsakymas dar neparuoštas.', items_missing = 'Trūksta pagamintų produktų.', already_paid = 'Jau apmokėta.' }
                Notify(msg[res and res.reason] or 'Nepavyko priduoti.', 'error')
            end
        end, data.orderId)
    end
    cb('ok')
end)

-- Kepėjas gamina produktą užsakymui.
RegisterNUICallback('burger:produce', function(data, cb)
    cb('ok')
    if not data or not data.orderId or not data.item then return end
    produceItem(data.orderId, data.item)
end)

function produceItem(orderId, itemName)
    QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:startProduce', function(res)
        if not res or not res.ok then
            local msg = { enough = 'Jau pagaminta pakankamai.', not_cooking = 'Užsakymas dar nepatvirtintas.', rate = 'Per greitai.', bad_role = 'Netinkama pozicija.' }
            Notify(msg[res and res.reason] or 'Nepavyko pradėti gaminti.', 'error')
            return
        end

        --- Uždaryti NUI kol vyksta 3D gamyba
        if uiOpen then
            uiOpen = false
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'burgerClose' })
        end

        local success, quality, score = false, 'normal', 0
        local kitchenCfg = Config.BurgerKitchen
        if kitchenCfg and kitchenCfg.enabled ~= false and BurgerKitchen3D and BurgerKitchen3D.Start then
            local st = JobClient.get()
            local joint = st and joints[st.locationId]
            local def = kitchenCfg.products and kitchenCfg.products[itemName]
            local hint = def and def.stationHint or 'grill'
            local origin = nil
            if joint and joint.kitchen then
                for _, stn in ipairs(joint.kitchen) do
                    if stn.type == hint or (not origin and stn.type == 'grill') then
                        origin = stn.coords
                        if stn.type == hint then break end
                    end
                end
                if not origin and joint.kitchen[1] then origin = joint.kitchen[1].coords end
            end
            local result = BurgerKitchen3D.Start(itemName, {
                origin = origin,
                stations = joint and joint.kitchen or nil,
            })
            success = result and result.success == true
            quality = (result and result.quality) or 'poor'
            score = (result and result.score) or 0
        else
            --- Fallback: seni minigame
            local ok1, x1 = Minigame.run(Config.GetMinigame('burger_grill'))
            local ok2 = ok1 and Minigame.run(Config.GetMinigame('burger_order'))
            success = ok1 and ok2
            score = (x1 and x1.score) or 0
            quality = Utils.scoreToQuality(success and score or 0, { normal = 0.4, good = 0.7, perfect = 0.95 })
        end

        QBCore.Functions.TriggerCallback('mrp_jobs:server:burger:finishProduce', function(done)
            if done and done.ok then
                Notify(done.ready and 'Užsakymas paruoštas!' or ('Pagaminta (%s).'):format(quality), 'success')
            else
                Notify('Gaminimas nepavyko.', 'error')
            end
        end, res.token, success, quality)
    end, orderId, itemName)
end

-- ── Maisto valgymas ───────────────────────────────────────────────
RegisterNetEvent('mrp_jobs:client:eatFood', function(item)
    local ped = PlayerPedId()
    local dict = 'mp_player_inteat@burger'
    if LoadAnimDict(dict) then
        TaskPlayAnim(ped, dict, 'mp_player_int_eat_burger', 3.0, 3.0, 2500, 49, 0, false, false, false)
    end
    Notify('Skanaus!', 'primary')
end)

-- ── Blip'ai ───────────────────────────────────────────────────────
CreateThread(function()
    for _, joint in pairs(joints) do
        if joint.blip then
            local c = joint.registerNpc.coords
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, joint.blip.sprite); SetBlipColour(b, joint.blip.color)
            SetBlipScale(b, joint.blip.scale); SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(joint.blip.name); EndTextCommandSetBlipName(b)
        end
    end
end)

CreateThread(function()
    Wait(1600)
    for jointId, joint in pairs(joints) do
        spawnRegisterNpc(jointId, joint)
        setupJointZones(jointId, joint)
    end
end)

AddEventHandler('mrp_jobs:client:jobEnded', function()
    if uiOpen then uiOpen = false; SetNuiFocus(false, false); SendNUIMessage({ action = 'burgerClose' }) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(registerPeds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    if uiOpen then SetNuiFocus(false, false) end
end)

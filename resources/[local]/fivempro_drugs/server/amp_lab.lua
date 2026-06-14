local QBCore = exports['qb-core']:GetCoreObject()

local activeAmp = {}

local function ampCfg()
    return Config.AmpMobileLab or {}
end

local function playerNearAmpLab(src)
    local cfg = ampCfg().lab
    if not cfg or not cfg.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - cfg.coords) <= (cfg.radius or 14.0) + 2.0
end

local function hasRecipeItems(Player, recipe)
    for _, row in ipairs(recipe or {}) do
        local it = Player.Functions.GetItemByName(row.item)
        local have = it and (tonumber(it.amount) or 0) or 0
        if have < (tonumber(row.count) or 1) then
            return false, row.item
        end
    end
    return true
end

local function removeRecipeItems(Player, recipe)
    for _, row in ipairs(recipe or {}) do
        if not Player.Functions.RemoveItem(row.item, row.count) then
            return false
        end
    end
    return true
end

local function refundRecipeItems(Player, recipe)
    for _, row in ipairs(recipe or {}) do
        Player.Functions.AddItem(row.item, row.count)
    end
end

QBCore.Functions.CreateCallback('fivempro_drugs:server:startAmpSynthesis', function(src, cb, vehNetId)
    local cfg = ampCfg()
    if not cfg.enabled then
        return cb({ ok = false, reason = 'Laboratorija išjungta.' })
    end
    if not playerNearAmpLab(src) then
        return cb({ ok = false, reason = 'Per toli nuo laboratorijos.' })
    end
    if activeAmp[src] then
        return cb({ ok = false, reason = 'Jau vyksta sintezė.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local recipe = cfg.recipe or (Config.Recipes and Config.Recipes.amp_process) or {}
    local okItems, missing = hasRecipeItems(Player, recipe)
    if not okItems then
        local label = missing and QBCore.Shared.Items[missing] and QBCore.Shared.Items[missing].label or missing
        return cb({ ok = false, reason = ('Trūksta: %s'):format(label or '?') })
    end

    if not removeRecipeItems(Player, recipe) then
        return cb({ ok = false, reason = 'Nepavyko paimti ingredientų.' })
    end

    local token = ('amp-%s-%s'):format(src, GetGameTimer())
    activeAmp[src] = {
        token = token,
        vehNetId = tonumber(vehNetId),
        recipe = recipe,
        startedAt = os.time(),
    }

    cb({
        ok = true,
        token = token,
        durationMs = cfg.processDurationMs or 72000,
        questionCount = cfg.questionCount or 3,
    })
end)

RegisterNetEvent('fivempro_drugs:server:finishAmpSynthesis', function(token, wrongCount, vehNetId)
    local src = source
    local state = activeAmp[src]
    if not state or state.token ~= token then return end
    activeAmp[src] = nil

    if not playerNearAmpLab(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo laboratorijos.', 'error')
    end

    local cfg = ampCfg()
    local wrong = math.max(0, math.min(3, tonumber(wrongCount) or 3))
    local yields = cfg.yieldByWrong or { [0] = 2, [1] = 1, [2] = 1, [3] = 0 }
    local amount = tonumber(yields[wrong]) or 0

    if wrong >= 3 then
        TriggerClientEvent('fivempro_drugs:client:ampLabExplode', src, tonumber(vehNetId) or state.vehNetId)
        TriggerClientEvent('QBCore:Notify', src, 'Mišinys detonavo — Journey sunaikintas!', 'error')
        if math.random(1, 100) <= (cfg.policeChance or 18) then
            TriggerEvent('fivempro_drugs:server:ampPoliceAlert', src)
        end
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if amount <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Sintezė nepavyko.', 'error')
    end

    local item = cfg.outputItem or 'amp_paste'
    if not Player.Functions.AddItem(item, amount) then
        refundRecipeItems(Player, state.recipe)
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    local itemData = QBCore.Shared.Items[item]
    TriggerClientEvent('inventory:client:ItemBox', src, itemData, 'add', amount)

    if wrong == 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Sintezė sėkminga — gavai %sx %s'):format(amount, itemData and itemData.label or item), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, ('Sintezė nestabili (%s klaid.) — gavai %sx %s'):format(wrong, amount, itemData and itemData.label or item), 'primary')
    end

    if math.random(1, 100) <= (cfg.policeChance or 18) then
        TriggerEvent('fivempro_drugs:server:ampPoliceAlert', src)
    end
end)

RegisterNetEvent('fivempro_drugs:server:cancelAmpSynthesis', function(token)
    local src = source
    local state = activeAmp[src]
    if not state or state.token ~= token then return end
    activeAmp[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and state.recipe then
        refundRecipeItems(Player, state.recipe)
        TriggerClientEvent('QBCore:Notify', src, 'Sintezė atšaukta — ingredientai grąžinti.', 'primary')
    end
end)

AddEventHandler('playerDropped', function()
    activeAmp[source] = nil
end)

RegisterNetEvent('fivempro_drugs:server:ampPoliceAlert', function(src)
    src = tonumber(src) or source
    if GetResourceState('fivempro_dispatch') ~= 'started' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    pcall(function()
        exports['fivempro_dispatch']:CreateDispatchCall('police', 'drugs', { x = c.x, y = c.y, z = c.z }, 'Signalinis ir dūmai — amfetamino laboratorija', src)
    end)
end)

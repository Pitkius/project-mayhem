local QBCore = exports['qb-core']:GetCoreObject()

local activeAmp = {}
local scrapCd = {} --- [src] = gameTimer ms

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

local function getVehFromNet(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return 0 end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
    return 0
end

local function readLabParts(veh)
    if not veh or veh == 0 then return {} end
    local st = Entity(veh).state.mrpAmpLab
    if type(st) ~= 'table' then return {} end
    return st
end

local function vehicleHasAllParts(veh)
    local parts = readLabParts(veh)
    local req = ampCfg().requiredParts or {}
    for _, row in ipairs(req) do
        if parts[row.id] ~= true then
            return false, row.label or row.id
        end
    end
    return true
end

local function findPartDefByItem(itemName)
    for _, row in ipairs(ampCfg().requiredParts or {}) do
        if row.item == itemName then return row end
    end
    return nil
end

QBCore.Functions.CreateCallback('mrp_drugs:server:startAmpSynthesis', function(src, cb, vehNetId)
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

    local veh = getVehFromNet(vehNetId)
    if veh == 0 then
        return cb({ ok = false, reason = 'Journey nerastas.' })
    end

    local okParts, missingPart = vehicleHasAllParts(veh)
    if not okParts then
        return cb({
            ok = false,
            reason = ('Journey nepilnai sumontuotas — trūksta: %s'):format(missingPart or '?'),
        })
    end

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

RegisterNetEvent('mrp_drugs:server:finishAmpSynthesis', function(token, wrongCount, vehNetId)
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
        local veh = getVehFromNet(tonumber(vehNetId) or state.vehNetId)
        if veh ~= 0 then
            Entity(veh).state:set('mrpAmpLab', {}, true)
        end
        TriggerClientEvent('mrp_drugs:client:ampLabExplode', src, tonumber(vehNetId) or state.vehNetId)
        TriggerClientEvent('QBCore:Notify', src, 'Mišinys detonavo — Journey sunaikintas, įranga prarasta!', 'error')
        if math.random(1, 100) <= (cfg.policeChance or 18) then
            TriggerEvent('mrp_drugs:server:ampPoliceAlert', src)
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
        TriggerEvent('mrp_drugs:server:ampPoliceAlert', src)
    end
end)

RegisterNetEvent('mrp_drugs:server:cancelAmpSynthesis', function(token)
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

--- Montuoti modulį į Journey
QBCore.Functions.CreateCallback('mrp_drugs:server:installAmpPart', function(src, cb, vehNetId, itemName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    local partDef = findPartDefByItem(itemName)
    if not partDef then
        return cb({ ok = false, reason = 'Nežinomas modulis.' })
    end

    local it = Player.Functions.GetItemByName(itemName)
    if not it or (tonumber(it.amount) or 0) < 1 then
        return cb({ ok = false, reason = 'Neturi modulio.' })
    end

    local veh = getVehFromNet(vehNetId)
    if veh == 0 then
        return cb({ ok = false, reason = 'Journey nerastas.' })
    end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > ((ampCfg().installDistance or 4.0) + 2.0) then
        return cb({ ok = false, reason = 'Per toli nuo Journey.' })
    end

    local parts = readLabParts(veh)
    if parts[partDef.id] == true then
        return cb({ ok = false, reason = ('%s jau sumontuotas.'):format(partDef.label) })
    end

    if not Player.Functions.RemoveItem(itemName, 1) then
        return cb({ ok = false, reason = 'Nepavyko paimti modulio.' })
    end

    parts[partDef.id] = true
    Entity(veh).state:set('mrpAmpLab', parts, true)

    local done, total = 0, #(ampCfg().requiredParts or {})
    for _, row in ipairs(ampCfg().requiredParts or {}) do
        if parts[row.id] then done = done + 1 end
    end

    cb({
        ok = true,
        partId = partDef.id,
        label = partDef.label,
        done = done,
        total = total,
        complete = done >= total,
    })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:getAmpLabStatus', function(src, cb, vehNetId)
    local veh = getVehFromNet(vehNetId)
    if veh == 0 then return cb({ ok = false, parts = {} }) end
    local parts = readLabParts(veh)
    local missing = {}
    for _, row in ipairs(ampCfg().requiredParts or {}) do
        if parts[row.id] ~= true then
            missing[#missing + 1] = row.label
        end
    end
    cb({ ok = true, parts = parts, missing = missing, complete = #missing == 0 })
end)

--- Laužyno loot
QBCore.Functions.CreateCallback('mrp_drugs:server:ampScrapLoot', function(src, cb)
    local scrap = Config.AmpScrapYard
    if not scrap or not scrap.enabled then
        return cb({ ok = false, reason = 'Išjungta.' })
    end
    local now = GetGameTimer()
    local cd = scrap.cooldownMs or 180000
    if scrapCd[src] and (now - scrapCd[src]) < cd then
        local left = math.ceil((cd - (now - scrapCd[src])) / 1000)
        return cb({ ok = false, reason = ('Palauk %ss.'):format(left) })
    end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - scrap.coords) > (scrap.radius or 1.4) + 2.5 then
        return cb({ ok = false, reason = 'Per toli.' })
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    scrapCd[src] = now
    local got = {}
    for _, row in ipairs(scrap.loot or {}) do
        if math.random() <= (row.chance or 0.5) then
            local n = math.random(row.min or 1, row.max or 1)
            if n > 0 and Player.Functions.AddItem(row.item, n) then
                got[#got + 1] = { item = row.item, amount = n }
                local data = QBCore.Shared.Items[row.item]
                if data then
                    TriggerClientEvent('inventory:client:ItemBox', src, data, 'add', n)
                end
            end
        end
    end

    if #got == 0 then
        return cb({ ok = true, empty = true })
    end
    cb({ ok = true, loot = got })
end)

local function registerAmpPartUseable(itemName)
    QBCore.Functions.CreateUseableItem(itemName, function(source)
        TriggerClientEvent('mrp_drugs:client:tryInstallAmpPart', source, itemName)
    end)
end

CreateThread(function()
    for _, row in ipairs(ampCfg().requiredParts or {}) do
        if row.item then registerAmpPartUseable(row.item) end
    end
end)

AddEventHandler('playerDropped', function()
    activeAmp[source] = nil
    scrapCd[source] = nil
end)

RegisterNetEvent('mrp_drugs:server:ampPoliceAlert', function(src)
    src = src or source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    if GetResourceState('mrp_dispatch') == 'started' then
        pcall(function()
            exports['mrp_dispatch']:CreateCall('police', 'drugs', c, 'Įtartina cheminė veikla — mobilioji laboratorija', src)
        end)
    end
end)

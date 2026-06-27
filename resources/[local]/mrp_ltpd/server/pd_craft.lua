local QBCore = exports['qb-core']:GetCoreObject()

local function cfg()
    return Config.PdWeaponCraft or {}
end

local function ensureCraftColumns()
    local row = MySQL.single.await(
        "SELECT COUNT(*) AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ltpd_profiles' AND COLUMN_NAME = 'craft_level'"
    )
    if row and tonumber(row.c) and tonumber(row.c) > 0 then return end
    MySQL.query.await('ALTER TABLE ltpd_profiles ADD COLUMN craft_level tinyint NOT NULL DEFAULT 1')
    MySQL.query.await('ALTER TABLE ltpd_profiles ADD COLUMN crafts_at_level int NOT NULL DEFAULT 0')
end

local function getDivisionForCitizenid(citizenid)
    local row = MySQL.single.await('SELECT division FROM ltpd_profiles WHERE citizenid = ?', { citizenid })
    return PdDivisions.normalize(row and row.division or 'patrol')
end

local function getCraftProfile(citizenid)
    ensureCraftColumns()
    local row = MySQL.single.await(
        'SELECT craft_level, crafts_at_level FROM ltpd_profiles WHERE citizenid = ?',
        { citizenid }
    )
    local maxLv = tonumber((cfg().maxLevel)) or 3
    local level = tonumber(row and row.craft_level) or tonumber(cfg().defaultLevel) or 1
    level = math.max(1, math.min(maxLv, level))
    return {
        craft_level = level,
        crafts_at_level = math.max(0, tonumber(row and row.crafts_at_level) or 0),
    }
end

local function saveCraftProfile(citizenid, profile)
    MySQL.update.await(
        'UPDATE ltpd_profiles SET craft_level = ?, crafts_at_level = ? WHERE citizenid = ?',
        { profile.craft_level, profile.crafts_at_level, citizenid }
    )
end

local function ensureProfileRow(citizenid)
    MySQL.query.await('INSERT IGNORE INTO ltpd_profiles (citizenid, division) VALUES (?, ?)', {
        citizenid, 'patrol',
    })
end

local function getStation(stationKey)
    for _, st in ipairs(cfg().stations or {}) do
        if st.id == stationKey or st.stationId == stationKey then
            return st
        end
    end
end

local function officerNearCraftStation(src, stationKey)
    local st = getStation(stationKey)
    if not st or not st.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - st.coords) <= (cfg().interactDistance or 2.2) + 1.0
end

local function isPdOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == (Config.JobName or 'police') and j.onduty == true
end

local function hasCraftPerm(src, st)
    if not isPdOnDuty(src) then return false end
    local need = Config.Permissions and Config.Permissions.pd_craft
    if need == nil then need = 0 end
    local grade = tonumber(QBCore.Functions.GetPlayer(src).PlayerData.job.grade.level) or 0
    if grade < need then return false end
    if st and st.minGrade and grade < st.minGrade then return false end
    if st and st.divisions and #st.divisions > 0 then
        local P = QBCore.Functions.GetPlayer(src)
        local div = P and getDivisionForCitizenid(P.PlayerData.citizenid) or 'patrol'
        local ok = false
        for _, d in ipairs(st.divisions) do
            if d == div then ok = true break end
        end
        if not ok then return false end
    end
    return true
end

local function getRecipe(id)
    return (cfg().recipes or {})[tostring(id or '')]
end

local function materialLabel(item)
    local shared = QBCore.Shared.Items[item]
    return shared and shared.label or item
end

local function recipeIngredients(recipe)
    if Config.PdRecipeIngredients then
        return Config.PdRecipeIngredients(recipe)
    end
    if recipe and recipe.ingredients then return recipe.ingredients end
    local out = {}
    for item, cnt in pairs(recipe and recipe.materials or {}) do
        out[#out + 1] = { item = item, count = cnt }
    end
    return out
end

local function buildIngredientStatus(Player, recipe)
    local rows = {}
    for _, row in ipairs(recipeIngredients(recipe)) do
        local it = Player.Functions.GetItemByName(row.item)
        local have = it and it.amount or 0
        rows[#rows + 1] = {
            item = row.item,
            label = materialLabel(row.item),
            need = row.count,
            have = have,
            missing = math.max(0, row.count - have),
        }
    end
    return rows
end

local function hasAllIngredients(Player, recipe)
    for _, row in ipairs(recipeIngredients(recipe)) do
        local it = Player.Functions.GetItemByName(row.item)
        if not it or (it.amount or 0) < row.count then
            return false
        end
    end
    return true
end

local function removeIngredients(Player, recipe)
    for _, row in ipairs(recipeIngredients(recipe)) do
        if not Player.Functions.RemoveItem(row.item, row.count) then
            return false
        end
        local shared = QBCore.Shared.Items[row.item]
        if shared then
            TriggerClientEvent('qb-inventory:client:ItemBox', Player.PlayerData.source, shared, 'remove', row.count)
        end
    end
    return true
end

local function refundIngredients(Player, recipe)
    for _, row in ipairs(recipeIngredients(recipe)) do
        Player.Functions.AddItem(row.item, row.count)
        local shared = QBCore.Shared.Items[row.item]
        if shared then
            TriggerClientEvent('qb-inventory:client:ItemBox', Player.PlayerData.source, shared, 'add', row.count)
        end
    end
end

local function buildProductRows(Player, craftLevel)
    local labels = cfg().levelLabels or {}
    local rows = {}
    for id, recipe in pairs(cfg().recipes or {}) do
        local needLv = tonumber(recipe.craftLevel) or 1
        if craftLevel >= needLv then
            local out = recipe.output
            local outLabel = QBCore.Shared.Items[out] and QBCore.Shared.Items[out].label or out
            local timeSec = math.ceil((tonumber(recipe.timeMs) or 10000) / 1000)
            rows[#rows + 1] = {
                id = id,
                label = recipe.label or id,
                outputLabel = outLabel,
                outputCount = recipe.count or 1,
                craftLevel = needLv,
                levelLabel = labels[needLv] or ('Lygis ' .. needLv),
                locked = false,
                timeLabel = timeSec >= 60 and ('~%d min'):format(math.ceil(timeSec / 60)) or ('%d sek.'):format(timeSec),
                ingredients = buildIngredientStatus(Player, recipe),
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.craftLevel ~= b.craftLevel then return a.craftLevel < b.craftLevel end
        return a.label < b.label
    end)
    return rows
end

local function tryLevelUp(profile)
    local per = cfg().craftsPerLevel or {}
    local maxLv = tonumber(cfg().maxLevel) or 3
    while profile.craft_level < maxLv do
        local need = tonumber(per[profile.craft_level]) or 999
        if profile.crafts_at_level < need then break end
        profile.crafts_at_level = profile.crafts_at_level - need
        profile.craft_level = profile.craft_level + 1
    end
end

local function craftUiPayload(src, stationKey)
    local st = getStation(stationKey)
    if not hasCraftPerm(src, st) or not officerNearCraftStation(src, stationKey) then
        return { ok = false, reason = 'Neturi teisės arba per toli nuo ginklinės.' }
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return { ok = false, reason = 'Žaidėjas nerastas.' } end
    ensureProfileRow(P.PlayerData.citizenid)
    local profile = getCraftProfile(P.PlayerData.citizenid)
    local per = cfg().craftsPerLevel or {}
    return {
        ok = true,
        stationLabel = (st and st.label) or 'Ginklų gamykla',
        craftLevel = profile.craft_level,
        craftsAtLevel = profile.crafts_at_level,
        craftsNeeded = tonumber(per[profile.craft_level]),
        maxLevel = tonumber(cfg().maxLevel) or 3,
        products = buildProductRows(P, profile.craft_level),
    }
end

QBCore.Functions.CreateCallback('mrp_ltpd:server:getPdCraftUi', function(src, cb, stationKey)
    cb(craftUiPayload(src, stationKey))
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getPdCraftMenu', function(src, cb, stationKey)
    local data = craftUiPayload(src, stationKey)
    if not data.ok then return cb(nil) end
    cb({
        craftLevel = data.craftLevel,
        craftsAtLevel = data.craftsAtLevel,
        craftsNeeded = data.craftsNeeded,
        maxLevel = data.maxLevel,
        materialItem = cfg().materialItem,
        recipes = data.products,
    })
end)

RegisterNetEvent('mrp_ltpd:server:pdWeaponCraft', function(stationKey, recipeId)
    local src = source
    stationKey = tostring(stationKey or '')
    recipeId = tostring(recipeId or '')
    local st = getStation(stationKey)
    local recipe = getRecipe(recipeId)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not recipe or not st then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkamas receptas.', 'error')
    end
    if not hasCraftPerm(src, st) or not officerNearCraftStation(src, stationKey) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės arba per toli.', 'error')
    end

    ensureProfileRow(P.PlayerData.citizenid)
    local profile = getCraftProfile(P.PlayerData.citizenid)
    local needLv = tonumber(recipe.craftLevel) or 1
    if profile.craft_level < needLv then
        return TriggerClientEvent('QBCore:Notify', src, ('Reikia gamybos %d lygio.'):format(needLv), 'error')
    end

    if not hasAllIngredients(P, recipe) then
        return TriggerClientEvent('QBCore:Notify', src, 'Trūksta ingredientų.', 'error')
    end

    if not removeIngredients(P, recipe) then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti medžiagų.', 'error')
    end

    local out = recipe.output
    local count = tonumber(recipe.count) or 1
    if not P.Functions.AddItem(out, count) then
        refundIngredients(P, recipe)
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    local outShared = QBCore.Shared.Items[out]
    if outShared then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, outShared, 'add', count)
    end

    profile.crafts_at_level = profile.crafts_at_level + 1
    local oldLv = profile.craft_level
    tryLevelUp(profile)
    saveCraftProfile(P.PlayerData.citizenid, profile)

    local outLabel = outShared and outShared.label or out
    TriggerClientEvent('QBCore:Notify', src, ('Pagaminta: %s x%s'):format(outLabel, count), 'success')
    if profile.craft_level > oldLv then
        TriggerClientEvent('QBCore:Notify', src, ('Ginklų gamybos lygis pakeltas iki %d!'):format(profile.craft_level), 'success', 6000)
    end
end)

CreateThread(function()
    Wait(1200)
    ensureCraftColumns()
end)

--- PD fleet prieiga pagal rangą / ARO / boso nustatymus
local QBCore = exports['qb-core']:GetCoreObject()

local FleetAccess = {} --- [model] = { minGrade, arasOrGrade, shopEnabled, label }
local FleetDivisionLock = false

local DEFAULTS = {
    mrpd1  = { minGrade = 6, arasOrGrade = true,  shopEnabled = true,  label = 'MRPD 1' },
    mrpd2  = { minGrade = 6, arasOrGrade = true,  shopEnabled = true,  label = 'MRPD 2' },
    mrpd3  = { minGrade = 6, arasOrGrade = true,  shopEnabled = true,  label = 'MRPD 3' },
    mrpd4  = { minGrade = 6, arasOrGrade = true,  shopEnabled = true,  label = 'MRPD 4' },
    mrpd5  = { minGrade = 3, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 5' },
    mrpd6  = { minGrade = 7, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 6' },
    mrpd7  = { minGrade = 6, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 7' },
    mrpd8  = { minGrade = 4, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 8' },
    mrpd9  = { minGrade = 4, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 9' },
    mrpd10 = { minGrade = 0, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 10' },
    mrpd11 = { minGrade = 0, arasOrGrade = false, shopEnabled = false, label = 'MRPD 11 (importas)' },
    mrpd12 = { minGrade = 5, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 12' },
    mrpd13 = { minGrade = 8, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 13 — Audi RS6' },
    mrpd14 = { minGrade = 5, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 14 — Kia Stinger' },
    mrpd15 = { minGrade = 2, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 15 — Hyundai' },
    mrpd16 = { minGrade = 4, arasOrGrade = false, shopEnabled = true,  label = 'MRPD 16 — Alfa Romeo' },
}

local function normalizeModel(model)
    return string.lower(tostring(model or ''))
end

local function isArasDivision(div)
    div = string.lower(tostring(div or ''))
    return div == 'aras'
end

local function seedFromDefaults()
    for model, def in pairs(DEFAULTS) do
        MySQL.insert.await([[
            INSERT INTO mrp_faction_fleet_access
                (job_name, model, min_grade, aras_or_grade, shop_enabled, label)
            VALUES ('police', ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE label = IF(label IS NULL OR label = '', VALUES(label), label)
        ]], {
            model,
            tonumber(def.minGrade) or 0,
            def.arasOrGrade and 1 or 0,
            def.shopEnabled == false and 0 or 1,
            def.label or model,
        })
    end
end

local function loadFleetAccess()
    FleetAccess = {}
    for model, def in pairs(DEFAULTS) do
        FleetAccess[model] = {
            minGrade = tonumber(def.minGrade) or 0,
            arasOrGrade = def.arasOrGrade == true,
            shopEnabled = def.shopEnabled ~= false,
            label = def.label or model,
        }
    end
    local rows = MySQL.query.await(
        'SELECT model, min_grade, aras_or_grade, shop_enabled, label FROM mrp_faction_fleet_access WHERE job_name = ?',
        { 'police' }
    ) or {}
    for _, row in ipairs(rows) do
        local model = normalizeModel(row.model)
        if model ~= '' then
            FleetAccess[model] = {
                minGrade = tonumber(row.min_grade) or 0,
                arasOrGrade = tonumber(row.aras_or_grade) == 1,
                shopEnabled = tonumber(row.shop_enabled) ~= 0,
                label = row.label or (DEFAULTS[model] and DEFAULTS[model].label) or model,
            }
        end
    end
    local lockRow = MySQL.single.await(
        'SELECT division_lock FROM mrp_faction_fleet_settings WHERE job_name = ? LIMIT 1',
        { 'police' }
    )
    FleetDivisionLock = lockRow and tonumber(lockRow.division_lock) == 1 or false
end

local function ensureTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_fleet_access` (
            `job_name` varchar(64) NOT NULL,
            `model` varchar(32) NOT NULL,
            `min_grade` int NOT NULL DEFAULT 0,
            `aras_or_grade` tinyint(1) NOT NULL DEFAULT 0,
            `shop_enabled` tinyint(1) NOT NULL DEFAULT 1,
            `label` varchar(128) DEFAULT NULL,
            PRIMARY KEY (`job_name`, `model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_fleet_settings` (
            `job_name` varchar(64) NOT NULL,
            `division_lock` tinyint(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`job_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.insert.await([[
        INSERT INTO mrp_faction_fleet_settings (job_name, division_lock)
        VALUES ('police', 0)
        ON DUPLICATE KEY UPDATE job_name = job_name
    ]])
    seedFromDefaults()
    loadFleetAccess()
    --- mrpd11 visada import-only
    if FleetAccess.mrpd11 then
        FleetAccess.mrpd11.shopEnabled = false
        MySQL.update.await(
            'UPDATE mrp_faction_fleet_access SET shop_enabled = 0 WHERE job_name = ? AND model = ?',
            { 'police', 'mrpd11' }
        )
    end
end

CreateThread(function()
    Wait(500)
    ensureTables()
end)

local function getPlayerDivision(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 'mp', 0 end
    local grade = Player.PlayerData.job and Player.PlayerData.job.grade
        and tonumber(Player.PlayerData.job.grade.level) or 0
    local stored = 'mp'
    if GetResourceState('mrp_ltpd') == 'started' then
        local ok, div = pcall(function()
            return exports['mrp_ltpd']:GetDivisionForCitizenid(Player.PlayerData.citizenid)
        end)
        if ok and div then stored = tostring(div) end
    else
        local row = MySQL.single.await(
            'SELECT division FROM ltpd_profiles WHERE citizenid = ? LIMIT 1',
            { Player.PlayerData.citizenid }
        )
        if row and row.division then stored = tostring(row.division) end
    end
    --- Efektyvus padalinys (0–3 = LPM)
    if grade <= 3 then
        return 'lpm', grade
    end
    stored = string.lower(stored)
    if stored == 'lpm' then stored = 'mp' end
    if stored == 'aro' or stored == 'sor' then stored = 'aras' end
    return stored, grade
end

local function getRule(model)
    model = normalizeModel(model)
    return FleetAccess[model] or DEFAULTS[model]
end

--- @return boolean, string|nil reason
local function canAccessFleetModel(src, model, opts)
    opts = opts or {}
    local forShop = opts.forShop ~= false --- shop katalogas / pirkimas
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.job then
        return false, 'Žaidėjas nerastas.'
    end
    local job = Player.PlayerData.job
    if job.name ~= 'police' or not job.onduty then
        return false, 'Tik policijai tarnyboje.'
    end
    model = normalizeModel(model)
    local rule = getRule(model)
    if not rule then
        --- Nežinomas modelis — leisti jei garaže (importas)
        if forShop then return false, 'Modelis neprieinamas.' end
        return true
    end
    if forShop and rule.shopEnabled == false then
        return false, 'Šis modelis tik importui (ne parduotuvėje).'
    end

    local division, grade = getPlayerDivision(src)
    grade = tonumber(job.grade and job.grade.level) or grade or 0

    --- Divizijos unlock: bet kuris divizijos narys (įskaitant LPM) — visos shopEnabled mašinos
    if FleetDivisionLock then
        return true
    end

    local minG = tonumber(rule.minGrade) or 0
    if rule.arasOrGrade then
        if isArasDivision(division) or grade >= minG then
            return true
        end
        return false, ('Reikia ARO divizijos arba rango ≥ %d.'):format(minG)
    end
    if grade < minG then
        return false, ('Reikia rango ≥ %d.'):format(minG)
    end
    return true
end

local function buildFleetListForBoss()
    local list = {}
    for model, rule in pairs(FleetAccess) do
        list[#list + 1] = {
            model = model,
            label = rule.label or model,
            minGrade = tonumber(rule.minGrade) or 0,
            arasOrGrade = rule.arasOrGrade == true,
            shopEnabled = rule.shopEnabled ~= false,
        }
    end
    table.sort(list, function(a, b)
        local na = tonumber(tostring(a.model):match('%d+')) or 0
        local nb = tonumber(tostring(b.model):match('%d+')) or 0
        return na < nb
    end)
    return list
end

--- Eksportai dealership / garages
exports('CanAccessPoliceFleet', function(src, model, opts)
    local ok = canAccessFleetModel(src, model, opts)
    return ok
end)

exports('CanAccessPoliceFleetDetailed', function(src, model, opts)
    return canAccessFleetModel(src, model, opts)
end)

exports('IsPoliceFleetShopEnabled', function(model)
    local rule = getRule(model)
    if not rule then return false end
    return rule.shopEnabled ~= false
end)

exports('GetPoliceFleetAccessList', function()
    return buildFleetListForBoss()
end)

exports('IsPoliceFleetDivisionLock', function()
    return FleetDivisionLock == true
end)

--- Boss dashboard papildymas (kviečia main)
function BossMenuGetFleetPayload()
    return {
        fleetEnabled = true,
        fleetDivisionLock = FleetDivisionLock,
        fleetVehicles = buildFleetListForBoss(),
    }
end

RegisterNetEvent('mrp_bossmenu:server:setFleetDivisionLock', function(jobName, enabled)
    local src = source
    if jobName ~= 'police' then return end
    if not exports['mrp_bossmenu']:CanOpenBossMenu(src, 'police') then return end
    FleetDivisionLock = enabled == true
    MySQL.update.await(
        'UPDATE mrp_faction_fleet_settings SET division_lock = ? WHERE job_name = ?',
        { FleetDivisionLock and 1 or 0, 'police' }
    )
    TriggerClientEvent('QBCore:Notify', src,
        FleetDivisionLock
            and 'Parkas: divizijos režimas — visos mašinos prieinamos divizijų nariams (be rango limito).'
            or 'Parkas: rango režimas — mašinos pagal nustatytus rangus.',
        'success')
end)

RegisterNetEvent('mrp_bossmenu:server:saveFleetVehicle', function(jobName, data)
    local src = source
    if jobName ~= 'police' or type(data) ~= 'table' then return end
    if not exports['mrp_bossmenu']:CanOpenBossMenu(src, 'police') then return end
    local model = normalizeModel(data.model)
    if model == '' or not FleetAccess[model] then
        return TriggerClientEvent('QBCore:Notify', src, 'Nežinomas modelis.', 'error')
    end
    local minGrade = math.max(0, math.min(15, tonumber(data.minGrade) or 0))
    local arasOrGrade = data.arasOrGrade == true
    local shopEnabled = data.shopEnabled ~= false
    --- mrpd11 visada import-only
    if model == 'mrpd11' then
        shopEnabled = false
    end
    FleetAccess[model].minGrade = minGrade
    FleetAccess[model].arasOrGrade = arasOrGrade
    FleetAccess[model].shopEnabled = shopEnabled
    MySQL.update.await([[
        UPDATE mrp_faction_fleet_access
        SET min_grade = ?, aras_or_grade = ?, shop_enabled = ?
        WHERE job_name = 'police' AND model = ?
    ]], { minGrade, arasOrGrade and 1 or 0, shopEnabled and 1 or 0, model })
    TriggerClientEvent('QBCore:Notify', src, ('Parkas atnaujintas: %s'):format(FleetAccess[model].label or model), 'success')
end)

local QBCore = exports['qb-core']:GetCoreObject()

local Funds = {}
local Settings = {}
local GradeOverrides = {}
local Divisions = {}

local function jobCfg(jobName)
    return Config.Jobs[jobName]
end

local function isManagedJob(jobName)
    return jobCfg(jobName) ~= nil
end

local function getPlayerJob(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData.job then return nil end
    return P.PlayerData.job
end

local function getGradeLevel(src)
    local j = getPlayerJob(src)
    if not j then return 0 end
    return tonumber(j.grade and j.grade.level or 0) or 0
end

local function gradeMeta(jobName, level)
    level = tostring(level)
    local base = QBShared.Jobs[jobName] and QBShared.Jobs[jobName].grades[level]
    local ov = GradeOverrides[jobName] and GradeOverrides[jobName][level]
    if not base and not ov then return nil end
    local merged = {
        name = (ov and ov.name) or (base and base.name) or ('Rangas ' .. level),
        payment = (ov and ov.payment ~= nil) and ov.payment or (base and base.payment) or 0,
        isboss = (ov and ov.isboss ~= nil) and ov.isboss or (base and base.isboss == true) or false,
        isdeputy = (ov and ov.isdeputy == true) or false,
        permissions = (ov and ov.permissions) or {},
    }
    return merged
end

local function applyGradesToShared(jobName)
    if not QBShared.Jobs[jobName] then return end
    local ovs = GradeOverrides[jobName] or {}
    for level, ov in pairs(ovs) do
        QBShared.Jobs[jobName].grades[level] = QBShared.Jobs[jobName].grades[level] or {}
        local g = QBShared.Jobs[jobName].grades[level]
        if ov.name then g.name = ov.name end
        if ov.payment ~= nil then g.payment = ov.payment end
        if ov.isboss ~= nil then g.isboss = ov.isboss end
    end
end

local function refreshOnlineJobPlayers(jobName)
    for _, P in pairs(QBCore.Players) do
        if P and P.PlayerData.job and P.PlayerData.job.name == jobName then
            local lvl = tostring(P.PlayerData.job.grade.level)
            local meta = gradeMeta(jobName, lvl)
            if meta then
                P.PlayerData.job.grade.name = meta.name
                P.PlayerData.job.grade.payment = meta.payment
                P.PlayerData.job.isboss = meta.isboss or false
                P.Functions.UpdatePlayerData()
            end
        end
    end
end

local function loadFunds()
    Funds = {}
    local rows = MySQL.query.await('SELECT job_name, balance FROM mrp_faction_funds') or {}
    for _, r in ipairs(rows) do
        Funds[r.job_name] = tonumber(r.balance) or 0
    end
    for jobName in pairs(Config.Jobs) do
        if Funds[jobName] == nil then
            MySQL.insert.await('INSERT INTO mrp_faction_funds (job_name, balance) VALUES (?, ?)', { jobName, 0 })
            Funds[jobName] = 0
        end
    end
end

local function loadSettings()
    Settings = {}
    local rows = MySQL.query.await('SELECT job_name, salary_enabled, salary_multiplier FROM mrp_faction_settings') or {}
    for _, r in ipairs(rows) do
        Settings[r.job_name] = {
            salary_enabled = r.salary_enabled == 1 or r.salary_enabled == true,
            salary_multiplier = tonumber(r.salary_multiplier) or 1.0,
        }
    end
    for jobName in pairs(Config.Jobs) do
        if not Settings[jobName] then
            MySQL.insert.await(
                'INSERT INTO mrp_faction_settings (job_name, salary_enabled, salary_multiplier) VALUES (?, ?, ?)',
                { jobName, 1, 1.0 }
            )
            Settings[jobName] = { salary_enabled = true, salary_multiplier = 1.0 }
        end
    end
end

local function loadGradeOverrides()
    GradeOverrides = {}
    local rows = MySQL.query.await(
        'SELECT job_name, grade_level, name, payment, isboss, isdeputy, permissions FROM mrp_faction_grades'
    ) or {}
    for _, r in ipairs(rows) do
        GradeOverrides[r.job_name] = GradeOverrides[r.job_name] or {}
        local perms = {}
        if r.permissions and r.permissions ~= '' then
            local ok, decoded = pcall(json.decode, r.permissions)
            if ok and type(decoded) == 'table' then perms = decoded end
        end
        GradeOverrides[r.job_name][tostring(r.grade_level)] = {
            name = r.name,
            payment = r.payment,
            isboss = r.isboss == 1 or r.isboss == true,
            isdeputy = r.isdeputy == 1 or r.isdeputy == true,
            permissions = perms,
        }
    end
    for jobName in pairs(Config.Jobs) do
        applyGradesToShared(jobName)
    end
end

local function seedPoliceDivisions()
    for _, div in ipairs(Config.DefaultPoliceDivisions or {}) do
        MySQL.insert.await([[
            INSERT INTO mrp_faction_divisions (job_name, division_id, label, abbr, description, min_grade, choosable, sort_order, builtin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
            ON DUPLICATE KEY UPDATE label = VALUES(label), abbr = VALUES(abbr), description = VALUES(description),
                min_grade = VALUES(min_grade), choosable = VALUES(choosable), sort_order = VALUES(sort_order)
        ]], {
            'police', div.id, div.label, div.abbr, div.description,
            div.min_grade or 4, div.choosable and 1 or 0, div.sort_order or 0,
        })
    end
end

local function loadDivisions()
    Divisions = {}
    local rows = MySQL.query.await(
        'SELECT job_name, division_id, label, abbr, description, min_grade, choosable, sort_order, builtin FROM mrp_faction_divisions ORDER BY sort_order ASC'
    ) or {}
    for _, r in ipairs(rows) do
        Divisions[r.job_name] = Divisions[r.job_name] or {}
        Divisions[r.job_name][r.division_id] = {
            id = r.division_id,
            label = r.label,
            abbr = r.abbr,
            description = r.description,
            minGrade = tonumber(r.min_grade) or 4,
            choosable = r.choosable == 1 or r.choosable == true,
            sortOrder = tonumber(r.sort_order) or 0,
            builtin = r.builtin == 1 or r.builtin == true,
        }
    end
end

local function migrateDivisionIds()
    for oldId, newId in pairs(Config.DivisionAliases or {}) do
        MySQL.update.await('UPDATE ltpd_profiles SET division = ? WHERE division = ?', { newId, oldId })
    end
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_funds` (
            `job_name` varchar(64) NOT NULL,
            `balance` int NOT NULL DEFAULT 0,
            PRIMARY KEY (`job_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_settings` (
            `job_name` varchar(64) NOT NULL,
            `salary_enabled` tinyint(1) NOT NULL DEFAULT 1,
            `salary_multiplier` decimal(6,2) NOT NULL DEFAULT 1.00,
            PRIMARY KEY (`job_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_grades` (
            `job_name` varchar(64) NOT NULL,
            `grade_level` int NOT NULL,
            `name` varchar(128) DEFAULT NULL,
            `payment` int DEFAULT NULL,
            `isboss` tinyint(1) NOT NULL DEFAULT 0,
            `isdeputy` tinyint(1) NOT NULL DEFAULT 0,
            `permissions` longtext DEFAULT NULL,
            PRIMARY KEY (`job_name`, `grade_level`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mrp_faction_divisions` (
            `job_name` varchar(64) NOT NULL,
            `division_id` varchar(32) NOT NULL,
            `label` varchar(128) NOT NULL,
            `abbr` varchar(16) NOT NULL,
            `description` varchar(255) DEFAULT NULL,
            `min_grade` int NOT NULL DEFAULT 4,
            `choosable` tinyint(1) NOT NULL DEFAULT 1,
            `sort_order` int NOT NULL DEFAULT 0,
            `builtin` tinyint(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`job_name`, `division_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    seedPoliceDivisions()
    migrateDivisionIds()
    loadFunds()
    loadSettings()
    loadGradeOverrides()
    loadDivisions()
    if not GradeOverrides.police or not GradeOverrides.police['9'] then
        MySQL.insert.await([[
            INSERT INTO mrp_faction_grades (job_name, grade_level, name, payment, isboss, isdeputy, permissions)
            VALUES ('police', 9, NULL, NULL, 0, 1, NULL)
            ON DUPLICATE KEY UPDATE isdeputy = 1
        ]])
        GradeOverrides.police = GradeOverrides.police or {}
        GradeOverrides.police['9'] = GradeOverrides.police['9'] or { isdeputy = true }
    end
end)

local function isBossOrDeputy(src, jobName)
    local j = getPlayerJob(src)
    if not j or j.name ~= jobName or not j.onduty then return false end
    if j.isboss then return true end
    local meta = gradeMeta(jobName, j.grade.level)
    if meta and meta.isdeputy then return true end
    local cfg = jobCfg(jobName)
    if cfg and cfg.defaultDeputyGrade and getGradeLevel(src) == cfg.defaultDeputyGrade then
        return true
    end
    return false
end

local function canOpenBossMenu(src, jobName)
    local j = getPlayerJob(src)
    if not j or j.name ~= jobName or not j.onduty then return false end
    if j.isboss then return true end
    local meta = gradeMeta(jobName, j.grade.level)
    if meta and meta.isdeputy then return true end
    local perms = meta and meta.permissions or {}
    if perms.boss_menu ~= nil then
        return getGradeLevel(src) >= tonumber(perms.boss_menu) or false
    end
    local cfg = jobCfg(jobName)
    if j.isboss then return true end
    if cfg and cfg.bossMenuMinGrade then
        return getGradeLevel(src) >= cfg.bossMenuMinGrade
    end
    return false
end

local function canManageFunds(src, jobName)
    return isBossOrDeputy(src, jobName)
end

local function bossOutranks(src, jobName, targetGrade)
    local j = getPlayerJob(src)
    if not j or j.name ~= jobName then return false end
    if j.isboss then return true end
    local meta = gradeMeta(jobName, j.grade.level)
    if meta and meta.isdeputy then
        return getGradeLevel(src) > (tonumber(targetGrade) or 0)
    end
    return getGradeLevel(src) > (tonumber(targetGrade) or 0)
end

local function maxGradeForJob(jobName)
    local cfg = jobCfg(jobName)
    local max = cfg and cfg.maxGrade or 10
    if QBShared.Jobs[jobName] and QBShared.Jobs[jobName].grades then
        for k in pairs(QBShared.Jobs[jobName].grades) do
            local n = tonumber(k)
            if n and n > max then max = n end
        end
    end
    if GradeOverrides[jobName] then
        for k in pairs(GradeOverrides[jobName]) do
            local n = tonumber(k)
            if n and n > max then max = n end
        end
    end
    return max
end

local function buildGradesList(jobName)
    local out = {}
    local max = maxGradeForJob(jobName)
    for i = 0, max do
        local meta = gradeMeta(jobName, i)
        if meta then
            out[#out + 1] = {
                level = i,
                name = meta.name,
                payment = meta.payment,
                isboss = meta.isboss,
                isdeputy = meta.isdeputy,
                permissions = meta.permissions,
            }
        end
    end
    return out
end

local function buildDivisionsList(jobName)
    local out = {}
    local map = Divisions[jobName] or {}
    for _, div in pairs(map) do
        out[#out + 1] = div
    end
    table.sort(out, function(a, b) return (a.sortOrder or 0) < (b.sortOrder or 0) end)
    return out
end

local function onlineMembers(jobName)
    local out = {}
    for src, P in pairs(QBCore.Players) do
        if P and P.PlayerData.job and P.PlayerData.job.name == jobName then
            local pd = P.PlayerData
            out[#out + 1] = {
                id = src,
                name = ('%s %s'):format(pd.charinfo.firstname or '', pd.charinfo.lastname or ''),
                grade = pd.job.grade.level,
                gradeName = pd.job.grade.name,
                onduty = pd.job.onduty,
                citizenid = pd.citizenid,
            }
        end
    end
    table.sort(out, function(a, b) return a.grade > b.grade end)
    return out
end

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

QBCore.Functions.CreateCallback('mrp_bossmenu:server:getDashboard', function(src, cb, jobName)
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then
        return cb(nil)
    end
    local cfg = jobCfg(jobName)
    local st = Settings[jobName] or { salary_enabled = true, salary_multiplier = 1.0 }
    cb({
        jobName = jobName,
        jobLabel = cfg.label,
        balance = Funds[jobName] or 0,
        salaryEnabled = st.salary_enabled,
        salaryMultiplier = st.salary_multiplier,
        canManageFunds = canManageFunds(src, jobName),
        canManageRanks = canManageFunds(src, jobName),
        divisionsEnabled = cfg.divisionsEnabled == true,
        members = onlineMembers(jobName),
        grades = buildGradesList(jobName),
        divisions = buildDivisionsList(jobName),
        permissionKeys = cfg.permissionKeys or {},
        playerGrade = getGradeLevel(src),
        isBoss = isBossOrDeputy(src, jobName),
    })
end)

RegisterNetEvent('mrp_bossmenu:server:fundDeposit', function(jobName, amount)
    local src = source
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if not P.Functions.RemoveMoney('bank', amount, 'faction-fund-deposit') then
        return notify(src, 'Nepakanka lėšų banke.', 'error')
    end
    Funds[jobName] = (Funds[jobName] or 0) + amount
    MySQL.update.await('UPDATE mrp_faction_funds SET balance = ? WHERE job_name = ?', { Funds[jobName], jobName })
    notify(src, ('Į fondą įdėta $%s'):format(amount), 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:fundWithdraw', function(jobName, amount)
    local src = source
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    if (Funds[jobName] or 0) < amount then
        return notify(src, 'Frakcijos fonde nepakanka lėšų.', 'error')
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    Funds[jobName] = Funds[jobName] - amount
    MySQL.update.await('UPDATE mrp_faction_funds SET balance = ? WHERE job_name = ?', { Funds[jobName], jobName })
    P.Functions.AddMoney('bank', amount, 'faction-fund-withdraw')
    notify(src, ('Iš fondo išimta $%s'):format(amount), 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:setSalarySettings', function(jobName, enabled, multiplier)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    enabled = enabled == true
    multiplier = tonumber(multiplier) or 1.0
    if multiplier < 0 then multiplier = 0 end
    if multiplier > 3 then multiplier = 3 end
    Settings[jobName] = { salary_enabled = enabled, salary_multiplier = multiplier }
    MySQL.update.await(
        'UPDATE mrp_faction_settings SET salary_enabled = ?, salary_multiplier = ? WHERE job_name = ?',
        { enabled and 1 or 0, multiplier, jobName }
    )
    notify(src, enabled and 'Algos iš fondo įjungtos.' or 'Algos iš fondo išjungtos.', 'success')
end)

local function persistGrade(jobName, data, src)
    local level = tonumber(data.level)
    if level == nil or level < 0 or level > maxGradeForJob(jobName) then return false end
    local perms = type(data.permissions) == 'table' and data.permissions or {}
    MySQL.insert.await([[
        INSERT INTO mrp_faction_grades (job_name, grade_level, name, payment, isboss, isdeputy, permissions)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), payment = VALUES(payment),
            isboss = VALUES(isboss), isdeputy = VALUES(isdeputy), permissions = VALUES(permissions)
    ]], {
        jobName, level, data.name or ('Rangas ' .. level), tonumber(data.payment) or 0,
        data.isboss and 1 or 0, data.isdeputy and 1 or 0, json.encode(perms),
    })
    GradeOverrides[jobName] = GradeOverrides[jobName] or {}
    GradeOverrides[jobName][tostring(level)] = {
        name = data.name,
        payment = tonumber(data.payment) or 0,
        isboss = data.isboss == true,
        isdeputy = data.isdeputy == true,
        permissions = perms,
    }
    if not QBShared.Jobs[jobName].grades[tostring(level)] then
        QBShared.Jobs[jobName].grades[tostring(level)] = { name = data.name, payment = tonumber(data.payment) or 0 }
    end
    applyGradesToShared(jobName)
    refreshOnlineJobPlayers(jobName)
    if src then notify(src, 'Rangas išsaugotas.', 'success') end
    return true
end

RegisterNetEvent('mrp_bossmenu:server:saveGrade', function(jobName, data)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    if type(data) ~= 'table' then return end
    local level = tonumber(data.level)
    if not bossOutranks(src, jobName, level) and not (getPlayerJob(src) and getPlayerJob(src).isboss) then
        return notify(src, 'Negali redaguoti aukštesnio ar lygaus rango.', 'error')
    end
    persistGrade(jobName, data, src)
end)

RegisterNetEvent('mrp_bossmenu:server:addGrade', function(jobName)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    local cfg = jobCfg(jobName)
    local maxAllowed = cfg and cfg.maxGrade or 10
    local currentMax = 0
    for i = 0, maxAllowed do
        if gradeMeta(jobName, i) then currentMax = i end
    end
    if currentMax >= maxAllowed then
        return notify(src, ('Daugiausia %s rangų.'):format(maxAllowed + 1), 'error')
    end
    local newLevel = currentMax + 1
    local prev = gradeMeta(jobName, currentMax)
    persistGrade(jobName, {
        level = newLevel,
        name = 'Naujas rangas ' .. newLevel,
        payment = (prev and prev.payment or 50) + 15,
        isboss = false,
        isdeputy = false,
        permissions = {},
    }, src)
end)

RegisterNetEvent('mrp_bossmenu:server:saveDivision', function(jobName, data)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    local cfg = jobCfg(jobName)
    if not cfg or not cfg.divisionsEnabled then return end
    if type(data) ~= 'table' then return end
    local id = tostring(data.id or ''):lower():gsub('%s+', '_'):sub(1, 32)
    if id == '' then return notify(src, 'Divizijos ID privalomas.', 'error') end
    MySQL.insert.await([[
        INSERT INTO mrp_faction_divisions (job_name, division_id, label, abbr, description, min_grade, choosable, sort_order, builtin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE label = VALUES(label), abbr = VALUES(abbr), description = VALUES(description),
            min_grade = VALUES(min_grade), choosable = VALUES(choosable), sort_order = VALUES(sort_order)
    ]], {
        jobName, id, data.label or id, data.abbr or id:upper(), data.description or '',
        tonumber(data.minGrade) or 4, data.choosable ~= false and 1 or 0, tonumber(data.sortOrder) or 80,
    })
    loadDivisions()
    TriggerEvent('mrp_bossmenu:divisionsUpdated', jobName)
    notify(src, 'Divizija išsaugota.', 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:hire', function(jobName, targetId, grade, divisionId)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or not grade then return end
    if not bossOutranks(src, jobName, grade) then
        return notify(src, 'Negali skirti aukštesnio ar lygaus rango.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return notify(src, 'Žaidėjas neprisijungęs.', 'error') end
    T.Functions.SetJob(jobName, grade)
    T.Functions.SetJobDuty(true)
    if jobName == 'police' and divisionId then
        TriggerEvent('mrp_bossmenu:internal:setPdDivision', targetId, divisionId)
    end
    notify(src, ('Įdarbinta (ID %s), rangas %s'):format(targetId, grade), 'success')
    notify(targetId, ('Priimta į %s. Rangas: %s'):format(jobCfg(jobName).label, grade), 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:fire', function(jobName, targetId)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= jobName then
        return notify(src, 'Žaidėjas ne šioje frakcijoje.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, jobName, tg) then
        return notify(src, 'Negali atleisti aukštesnio ar lygaus rango.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    notify(src, ('Atleistas ID %s'):format(targetId), 'success')
    notify(targetId, 'Atleistas iš frakcijos.', 'error')
end)

RegisterNetEvent('mrp_bossmenu:server:setGrade', function(jobName, targetId, grade)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= jobName then
        return notify(src, 'Žaidėjas ne šioje frakcijoje.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, jobName, tg) or not bossOutranks(src, jobName, grade) then
        return notify(src, 'Negali keisti į aukštesnį ar lygų rangą.', 'error')
    end
    T.Functions.SetJob(jobName, grade)
    if jobName == 'police' then
        TriggerEvent('mrp_bossmenu:internal:setPdDivisionByGrade', targetId, grade)
    end
    notify(src, ('Rangas pakeistas (ID %s → %s)'):format(targetId, grade), 'success')
    notify(targetId, ('Naujas rangas: %s'):format(grade), 'primary')
end)

RegisterNetEvent('mrp_bossmenu:server:setMemberDivision', function(jobName, targetId, divisionId)
    local src = source
    if jobName ~= 'police' or not canOpenBossMenu(src, jobName) then return end
    targetId = tonumber(targetId)
    if not targetId then return end
    TriggerEvent('mrp_bossmenu:internal:setPdDivision', targetId, divisionId)
    notify(src, 'Divizija pakeista.', 'success')
end)

--- Paycheck iš frakcijos fondo (kviečiama iš qb-core)
exports('ProcessPaycheck', function(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return false end
    local jobName = Player.PlayerData.job.name
    if not isManagedJob(jobName) then return false end
    local st = Settings[jobName]
    if not st or not st.salary_enabled then return false end
    local lvl = tostring(Player.PlayerData.job.grade.level)
    local meta = gradeMeta(jobName, lvl)
    local payment = math.floor((meta and meta.payment or 0) * (st.salary_multiplier or 1.0))
    if payment <= 0 then return true end
    if not (QBShared.Jobs[jobName].offDutyPay or Player.PlayerData.job.onduty) then return true end
    if (Funds[jobName] or 0) < payment then
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'Frakcijos fonde nepakanka algoms.', 'error')
        return true
    end
    Funds[jobName] = Funds[jobName] - payment
    MySQL.update.await('UPDATE mrp_faction_funds SET balance = ? WHERE job_name = ?', { Funds[jobName], jobName })
    Player.Functions.AddMoney('bank', payment, 'faction-paycheck')
    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, ('Algos iš fondo: $%s'):format(payment), 'success')
    return true
end)

exports('GetFundBalance', function(jobName)
    return Funds[jobName] or 0
end)

exports('GetGradePermissionMin', function(jobName, gradeLevel, permKey)
    local meta = gradeMeta(jobName, gradeLevel)
    if meta and meta.permissions and meta.permissions[permKey] ~= nil then
        return tonumber(meta.permissions[permKey])
    end
    return nil
end)

exports('GetDivisionsMap', function(jobName)
    return Divisions[jobName] or {}
end)

exports('NormalizeDivisionId', function(divisionId)
    local d = tostring(divisionId or 'mp'):lower()
    return (Config.DivisionAliases and Config.DivisionAliases[d]) or d
end)

exports('CanOpenBossMenu', function(src, jobName)
    return canOpenBossMenu(src, jobName)
end)

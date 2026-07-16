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
    local jobs = QBCore.Shared and QBCore.Shared.Jobs
    local base = jobs and jobs[jobName] and jobs[jobName].grades[level]
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
    local jobs = QBCore.Shared and QBCore.Shared.Jobs
    if not jobs or not jobs[jobName] then return end
    local ovs = GradeOverrides[jobName] or {}
    for level, ov in pairs(ovs) do
        jobs[jobName].grades[level] = jobs[jobName].grades[level] or {}
        local g = jobs[jobName].grades[level]
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
                P.PlayerData.job.isdeputy = meta.isdeputy or false
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
    --- INSERT IGNORE — neperrašo custom pavadinimų po bosų redagavimo
    for _, div in ipairs(Config.DefaultPoliceDivisions or {}) do
        MySQL.insert.await([[
            INSERT IGNORE INTO mrp_faction_divisions
                (job_name, division_id, label, abbr, description, min_grade, choosable, sort_order, builtin)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
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
    for jobName in pairs(Config.Jobs or {}) do
        applyGradesToShared(jobName)
        refreshOnlineJobPlayers(jobName)
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return end
    local jobName = Player.PlayerData.job.name
    if not isManagedJob(jobName) then return end
    local meta = gradeMeta(jobName, Player.PlayerData.job.grade and Player.PlayerData.job.grade.level)
    if not meta then return end
    Player.PlayerData.job.grade.name = meta.name
    Player.PlayerData.job.grade.payment = meta.payment
    Player.PlayerData.job.isboss = meta.isboss or false
    Player.PlayerData.job.isdeputy = meta.isdeputy or false
    Player.Functions.UpdatePlayerData()
end)

local function hasLeadershipGrade(src, jobName)
    local j = getPlayerJob(src)
    if not j or j.name ~= jobName then return false end
    if j.isboss == true or j.isdeputy == true then return true end
    local meta = gradeMeta(jobName, j.grade and j.grade.level)
    if meta and (meta.isboss or meta.isdeputy) then return true end
    local cfg = jobCfg(jobName)
    if cfg and cfg.defaultDeputyGrade and getGradeLevel(src) == cfg.defaultDeputyGrade then
        return true
    end
    return false
end

local function isBossOrDeputy(src, jobName)
    local j = getPlayerJob(src)
    if not j or j.name ~= jobName or not j.onduty then return false end
    return hasLeadershipGrade(src, jobName)
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
    local jobs = QBCore.Shared and QBCore.Shared.Jobs
    if jobs and jobs[jobName] and jobs[jobName].grades then
        for k in pairs(jobs[jobName].grades) do
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

local function parseJsonField(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function charFullName(charinfo)
    charinfo = type(charinfo) == 'table' and charinfo or parseJsonField(charinfo)
    local first = charinfo.firstname or charinfo.firstName or ''
    local last = charinfo.lastname or charinfo.lastName or ''
    local full = (('%s %s'):format(first, last)):gsub('^%s+', ''):gsub('%s+$', '')
    return full ~= '' and full or 'Nežinomas'
end

local function divisionLabel(jobName, divisionId)
    if not divisionId or divisionId == '' then return nil end
    local map = Divisions[jobName] or {}
    local div = map[divisionId]
    if not div then return tostring(divisionId) end
    if div.abbr and div.abbr ~= '' then
        return ('[%s] %s'):format(div.abbr, div.label or divisionId)
    end
    return div.label or divisionId
end

local function loadDivisionByCitizenids(citizenids)
    local out = {}
    if not citizenids or #citizenids == 0 then return out end
    local placeholders = {}
    for i = 1, #citizenids do
        placeholders[i] = '?'
    end
    local ok, rows = pcall(function()
        return MySQL.query.await(
            ('SELECT citizenid, division FROM ltpd_profiles WHERE citizenid IN (%s)'):format(table.concat(placeholders, ',')),
            citizenids
        )
    end)
    if not ok or not rows then return out end
    for _, r in ipairs(rows) do
        out[r.citizenid] = r.division
    end
    return out
end

--- Visi įdarbinti (online + offline) iš `players` lentelės
local function jobMembers(jobName)
    local onlineByCid = {}
    for src, P in pairs(QBCore.Players) do
        if P and P.PlayerData and P.PlayerData.job and P.PlayerData.job.name == jobName then
            local pd = P.PlayerData
            onlineByCid[pd.citizenid] = {
                id = tonumber(src) or src,
                name = charFullName(pd.charinfo),
                grade = tonumber(pd.job.grade and pd.job.grade.level) or 0,
                gradeName = (pd.job.grade and pd.job.grade.name) or ('Rangas ' .. tostring(pd.job.grade and pd.job.grade.level or 0)),
                onduty = pd.job.onduty == true,
                online = true,
                citizenid = pd.citizenid,
            }
        end
    end

    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, job
        FROM players
        WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?
    ]], { jobName }) or {}

    --- Fallback, jei JSON_EXTRACT nepavyksta (senesnės DB)
    if #rows == 0 then
        rows = MySQL.query.await(
            'SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?',
            { '%"name":"' .. jobName .. '"%' }
        ) or {}
    end

    local citizenids = {}
    local out = {}
    local seen = {}

    for _, row in ipairs(rows) do
        local cid = row.citizenid
        if cid and not seen[cid] then
            seen[cid] = true
            citizenids[#citizenids + 1] = cid
            local online = onlineByCid[cid]
            if online then
                out[#out + 1] = online
            else
                local job = parseJsonField(row.job)
                local grade = job.grade or {}
                local level = tonumber(grade.level) or 0
                local meta = gradeMeta(jobName, level)
                out[#out + 1] = {
                    id = nil,
                    name = charFullName(row.charinfo),
                    grade = level,
                    gradeName = (meta and meta.name) or grade.name or ('Rangas ' .. level),
                    onduty = false,
                    online = false,
                    citizenid = cid,
                }
            end
        end
    end

    --- Online, bet dar nesave'inti DB (retas race) — vis tiek parodyti
    for cid, member in pairs(onlineByCid) do
        if not seen[cid] then
            seen[cid] = true
            citizenids[#citizenids + 1] = cid
            out[#out + 1] = member
        end
    end

    if jobName == 'police' then
        local divMap = loadDivisionByCitizenids(citizenids)
        local aliases = Config.DivisionAliases or {}
        for _, m in ipairs(out) do
            local divId = tostring(divMap[m.citizenid] or 'mp'):lower()
            divId = aliases[divId] or divId
            m.divisionId = divId
            m.divisionLabel = divisionLabel(jobName, divId)
        end
    end

    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.name or '') < (b.name or '')
    end)
    return out
end

local function resolveJobPlayer(jobName, targetId, citizenid)
    targetId = tonumber(targetId)
    citizenid = citizenid and tostring(citizenid) or nil
    if targetId and targetId > 0 then
        local P = QBCore.Functions.GetPlayer(targetId)
        if P and P.PlayerData.job and P.PlayerData.job.name == jobName then
            return P, false
        end
    end
    if citizenid and citizenid ~= '' then
        local Online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Online and Online.PlayerData.job and Online.PlayerData.job.name == jobName then
            return Online, false
        end
        local Offline = QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
        if Offline and Offline.PlayerData.job and Offline.PlayerData.job.name == jobName then
            return Offline, true
        end
    end
    return nil, false
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
    local members = jobMembers(jobName)
    local onlineCount = 0
    for _, m in ipairs(members) do
        if m.online then onlineCount = onlineCount + 1 end
    end
    cb({
        jobName = jobName,
        jobLabel = cfg.label,
        balance = Funds[jobName] or 0,
        salaryEnabled = st.salary_enabled,
        canManageFunds = canManageFunds(src, jobName),
        canManageRanks = canManageFunds(src, jobName) or canOpenBossMenu(src, jobName),
        divisionsEnabled = cfg.divisionsEnabled == true,
        members = members,
        memberCount = #members,
        onlineCount = onlineCount,
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

RegisterNetEvent('mrp_bossmenu:server:setSalarySettings', function(jobName, enabled)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    enabled = enabled == true
    Settings[jobName] = { salary_enabled = enabled, salary_multiplier = 1.0 }
    MySQL.update.await(
        'UPDATE mrp_faction_settings SET salary_enabled = ?, salary_multiplier = ? WHERE job_name = ?',
        { enabled and 1 or 0, 1.0, jobName }
    )
    notify(src, enabled and 'Algos automatiškai mokamos iš fondo.' or 'Algų mokėjimas iš fondo išjungtas.', 'success')
end)

local function countPlayersAtGrade(jobName, level)
    local n = 0
    for _, P in pairs(QBCore.Players) do
        if P and P.PlayerData.job and P.PlayerData.job.name == jobName then
            if tonumber(P.PlayerData.job.grade.level) == level then
                n = n + 1
            end
        end
    end
    return n
end

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
    local sharedJob = QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]
    GradeOverrides[jobName] = GradeOverrides[jobName] or {}
    GradeOverrides[jobName][tostring(level)] = {
        name = data.name,
        payment = tonumber(data.payment) or 0,
        isboss = data.isboss == true,
        isdeputy = data.isdeputy == true,
        permissions = perms,
    }
    if sharedJob then
        sharedJob.grades = sharedJob.grades or {}
        if not sharedJob.grades[tostring(level)] then
            sharedJob.grades[tostring(level)] = { name = data.name, payment = tonumber(data.payment) or 0 }
        end
    end
    applyGradesToShared(jobName)
    refreshOnlineJobPlayers(jobName)
    if src then notify(src, 'Rangas išsaugotas.', 'success') end
    return true
end

local function moveGradeLevel(jobName, oldLevel, newLevel, data, src)
    oldLevel = tonumber(oldLevel)
    newLevel = tonumber(newLevel)
    if oldLevel == nil or newLevel == nil or oldLevel == newLevel then
        return persistGrade(jobName, data, src)
    end
    if newLevel < 0 or newLevel > maxGradeForJob(jobName) then
        if src then notify(src, 'Netinkamas rango lygis.', 'error') end
        return false
    end
    if oldLevel < 1 then
        if src then notify(src, 'Pradinio (0) rango lygio keisti negalima.', 'error') end
        return false
    end
    MySQL.update.await('DELETE FROM mrp_faction_grades WHERE job_name = ? AND grade_level = ?', { jobName, oldLevel })
    if GradeOverrides[jobName] then
        GradeOverrides[jobName][tostring(oldLevel)] = nil
    end
    data.level = newLevel
    persistGrade(jobName, data, nil)
    for _, P in pairs(QBCore.Players) do
        if P and P.PlayerData.job and P.PlayerData.job.name == jobName then
            if tonumber(P.PlayerData.job.grade.level) == oldLevel then
                P.Functions.SetJob(jobName, newLevel)
            end
        end
    end
    if src then notify(src, ('Rango lygis pakeistas: %s → %s'):format(oldLevel, newLevel), 'success') end
    return true
end

local function deleteGrade(jobName, level, src)
    level = tonumber(level)
    if level == nil or level < 1 then
        if src then notify(src, 'Pradinio (0) rango ištrinti negalima.', 'error') end
        return false
    end
    if countPlayersAtGrade(jobName, level) > 0 then
        if src then notify(src, 'Pirmiau perkelk arba atleisk darbuotojus su šiuo rangu.', 'error') end
        return false
    end
    MySQL.update.await('DELETE FROM mrp_faction_grades WHERE job_name = ? AND grade_level = ?', { jobName, level })
    if GradeOverrides[jobName] then
        GradeOverrides[jobName][tostring(level)] = nil
    end
    local sharedJob = QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]
    if sharedJob and sharedJob.grades then
        sharedJob.grades[tostring(level)] = nil
    end
    applyGradesToShared(jobName)
    if src then notify(src, ('Rangas [%s] ištrintas.'):format(level), 'success') end
    return true
end

RegisterNetEvent('mrp_bossmenu:server:saveGrade', function(jobName, data)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    if type(data) ~= 'table' then return end
    local level = tonumber(data.level)
    local newLevel = tonumber(data.newLevel)
    if level == nil then return end
    if not bossOutranks(src, jobName, level) and not (getPlayerJob(src) and getPlayerJob(src).isboss) then
        return notify(src, 'Negali redaguoti aukštesnio ar lygaus rango.', 'error')
    end
    if newLevel and newLevel ~= level then
        if not bossOutranks(src, jobName, newLevel) and not (getPlayerJob(src) and getPlayerJob(src).isboss) then
            return notify(src, 'Negali perkelti į aukštesnį ar lygų rango lygį.', 'error')
        end
        moveGradeLevel(jobName, level, newLevel, data, src)
        return
    end
    persistGrade(jobName, data, src)
end)

RegisterNetEvent('mrp_bossmenu:server:deleteGrade', function(jobName, level)
    local src = source
    if not isManagedJob(jobName) or not canManageFunds(src, jobName) then return end
    level = tonumber(level)
    if level == nil then return end
    if not bossOutranks(src, jobName, level) and not (getPlayerJob(src) and getPlayerJob(src).isboss) then
        return notify(src, 'Negali ištrinti aukštesnio ar lygaus rango.', 'error')
    end
    deleteGrade(jobName, level, src)
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
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    local cfg = jobCfg(jobName)
    if not cfg or not cfg.divisionsEnabled then return end
    if type(data) ~= 'table' then return end
    local id = tostring(data.id or ''):lower():gsub('[^%w_%-]', ''):gsub('%s+', '_'):sub(1, 32)
    if id == '' then return notify(src, 'Divizijos ID privalomas.', 'error') end
    local label = tostring(data.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' then label = id end
    local abbr = tostring(data.abbr or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if abbr == '' then abbr = id:upper():sub(1, 8) end
    local existing = Divisions[jobName] and Divisions[jobName][id]
    local sortOrder = tonumber(data.sortOrder)
    if not sortOrder then
        sortOrder = existing and existing.sortOrder or 80
    end
    MySQL.insert.await([[
        INSERT INTO mrp_faction_divisions (job_name, division_id, label, abbr, description, min_grade, choosable, sort_order, builtin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), abbr = VALUES(abbr), description = VALUES(description),
            min_grade = VALUES(min_grade), choosable = VALUES(choosable), sort_order = VALUES(sort_order)
    ]], {
        jobName, id, label, abbr:sub(1, 8), tostring(data.description or ''),
        tonumber(data.minGrade) or 4, data.choosable ~= false and 1 or 0, sortOrder,
        (existing and existing.builtin) and 1 or 0,
    })
    loadDivisions()
    TriggerEvent('mrp_bossmenu:divisionsUpdated', jobName)
    notify(src, existing and 'Divizija atnaujinta.' or 'Divizija sukurta.', 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:deleteDivision', function(jobName, divisionId)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    local cfg = jobCfg(jobName)
    if not cfg or not cfg.divisionsEnabled then return end
    divisionId = tostring(divisionId or ''):lower()
    if divisionId == '' then return end
    local existing = Divisions[jobName] and Divisions[jobName][divisionId]
    if not existing then
        return notify(src, 'Divizija nerasta.', 'error')
    end
    if existing.builtin then
        return notify(src, 'Standartinės divizijos ištrinti negalima — gali tik pervadinti.', 'error')
    end
    MySQL.update.await('DELETE FROM mrp_faction_divisions WHERE job_name = ? AND division_id = ?', { jobName, divisionId })
    if jobName == 'police' then
        MySQL.update.await('UPDATE ltpd_profiles SET division = ? WHERE division = ?', { 'mp', divisionId })
    end
    loadDivisions()
    TriggerEvent('mrp_bossmenu:divisionsUpdated', jobName)
    notify(src, 'Divizija ištrinta. Pareigūnai perkelti į MP.', 'success')
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
    if not T then return notify(src, 'Žaidėjas neprisijungęs (įdarbinimui reikia serverio ID).', 'error') end
    T.Functions.SetJob(jobName, grade)
    T.Functions.SetJobDuty(true)
    if jobName == 'police' and divisionId then
        TriggerEvent('mrp_bossmenu:internal:setPdDivision', targetId, divisionId)
    end
    notify(src, ('Įdarbinta (ID %s), rangas %s'):format(targetId, grade), 'success')
    notify(targetId, ('Priimta į %s. Rangas: %s'):format(jobCfg(jobName).label, grade), 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:fire', function(jobName, targetId, citizenid)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    local T, offline = resolveJobPlayer(jobName, targetId, citizenid)
    if not T then
        return notify(src, 'Žaidėjas ne šioje frakcijoje.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, jobName, tg) then
        return notify(src, 'Negali atleisti aukštesnio ar lygaus rango.', 'error')
    end
    local cid = T.PlayerData.citizenid
    local onlineSrc = not offline and T.PlayerData.source or nil
    T.Functions.SetJob('unemployed', 0)
    if offline then
        T.Functions.Save()
    end
    if jobName == 'police' and cid then
        MySQL.update.await('UPDATE ltpd_profiles SET division = ? WHERE citizenid = ?', { 'mp', cid })
    end
    notify(src, ('Atleistas: %s'):format(cid or tostring(targetId)), 'success')
    if onlineSrc then
        notify(onlineSrc, 'Atleistas iš frakcijos.', 'error')
    end
end)

RegisterNetEvent('mrp_bossmenu:server:setGrade', function(jobName, targetId, grade, citizenid)
    local src = source
    if not isManagedJob(jobName) or not canOpenBossMenu(src, jobName) then return end
    grade = tonumber(grade)
    if grade == nil then return end
    local T, offline = resolveJobPlayer(jobName, targetId, citizenid)
    if not T then
        return notify(src, 'Žaidėjas ne šioje frakcijoje.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, jobName, tg) or not bossOutranks(src, jobName, grade) then
        return notify(src, 'Negali keisti į aukštesnį ar lygų rangą.', 'error')
    end
    T.Functions.SetJob(jobName, grade)
    if offline then
        T.Functions.Save()
    else
        if jobName == 'police' then
            TriggerEvent('mrp_bossmenu:internal:setPdDivisionByGrade', T.PlayerData.source, grade)
        end
        notify(T.PlayerData.source, ('Naujas rangas: %s'):format(grade), 'primary')
    end
    if jobName == 'police' and offline then
        TriggerEvent('mrp_bossmenu:internal:setPdDivisionByCitizenId', T.PlayerData.citizenid, nil, grade)
    end
    notify(src, ('Rangas pakeistas → %s'):format(grade), 'success')
end)

RegisterNetEvent('mrp_bossmenu:server:setMemberDivision', function(jobName, targetId, divisionId, citizenid)
    local src = source
    if jobName ~= 'police' or not canOpenBossMenu(src, jobName) then return end
    local T, offline = resolveJobPlayer(jobName, targetId, citizenid)
    if not T then
        return notify(src, 'Žaidėjas ne šioje frakcijoje.', 'error')
    end
    if offline then
        TriggerEvent('mrp_bossmenu:internal:setPdDivisionByCitizenId', T.PlayerData.citizenid, divisionId, nil)
    else
        TriggerEvent('mrp_bossmenu:internal:setPdDivision', T.PlayerData.source, divisionId)
    end
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
    local payment = math.floor(meta and meta.payment or 0)
    if payment <= 0 then return true end
    local sharedJob = QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]
    if not (sharedJob and (sharedJob.offDutyPay or Player.PlayerData.job.onduty)) then return true end
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

exports('IsBossOrDeputy', function(src, jobName)
    return isBossOrDeputy(src, jobName)
end)

--- Vadas / pavaduotojas pagal rangą (be onduty reikalavimo) – pd_markers / sync
exports('HasLeadershipGrade', function(src, jobName)
    return hasLeadershipGrade(src, jobName)
end)

--- Divizijos rangai (vizualūs) – be teisių / prieigos
local QBCore = exports['qb-core']:GetCoreObject()

local RankCache = {} ---@type table<number, { id: number, division_id: string, label: string, sort_order: number, builtin: boolean }>
local RanksByDivision = {} ---@type table<string, table[]>

local function ensureDivisionRankSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ltpd_division_ranks` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `division_id` varchar(32) NOT NULL,
            `label` varchar(128) NOT NULL,
            `sort_order` int NOT NULL DEFAULT 0,
            `builtin` tinyint(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `division_id` (`division_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local col = MySQL.single.await(
        "SELECT COUNT(*) AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ltpd_profiles' AND COLUMN_NAME = 'division_rank_id'"
    )
    if not col or tonumber(col.c) == 0 then
        MySQL.query.await('ALTER TABLE `ltpd_profiles` ADD COLUMN `division_rank_id` int(11) DEFAULT NULL')
        MySQL.query.await('ALTER TABLE `ltpd_profiles` ADD KEY `division_rank_id` (`division_rank_id`)')
    end
end

local function loadRankCache()
    RankCache = {}
    RanksByDivision = {}
    local rows = MySQL.query.await(
        'SELECT id, division_id, label, sort_order, builtin FROM ltpd_division_ranks ORDER BY sort_order ASC, id ASC'
    ) or {}
    for _, r in ipairs(rows) do
        local entry = {
            id = tonumber(r.id),
            division_id = PdDivisions.normalize(r.division_id),
            label = r.label,
            sort_order = tonumber(r.sort_order) or 0,
            builtin = r.builtin == 1 or r.builtin == true,
        }
        RankCache[entry.id] = entry
        local key = tostring(r.division_id):lower()
        RanksByDivision[key] = RanksByDivision[key] or {}
        RanksByDivision[key][#RanksByDivision[key] + 1] = entry
        local norm = PdDivisions.normalize(key)
        if norm ~= key then
            RanksByDivision[norm] = RanksByDivision[norm] or {}
            -- avoid dup if both keys already seeded
            local seen = false
            for _, e in ipairs(RanksByDivision[norm]) do
                if e.id == entry.id then seen = true break end
            end
            if not seen then
                RanksByDivision[norm][#RanksByDivision[norm] + 1] = entry
            end
        end
    end
end

local function seedDivisionRanks()
    MySQL.update.await(
        "UPDATE ltpd_division_ranks SET division_id = 'aras' WHERE division_id IN ('sor', 'aro', 'ARAS', 'ARO')"
    )
    for divId, labels in pairs(Config.DefaultDivisionRanks or {}) do
        if type(labels) == 'table' then
            local count = MySQL.scalar.await(
                'SELECT COUNT(*) FROM ltpd_division_ranks WHERE division_id = ?',
                { divId }
            )
            if tonumber(count) == 0 then
                for i, label in ipairs(labels) do
                    if type(label) == 'string' and label ~= '' then
                        MySQL.insert.await(
                            'INSERT INTO ltpd_division_ranks (division_id, label, sort_order, builtin) VALUES (?, ?, ?, 1)',
                            { divId, label, i * 10 }
                        )
                    end
                end
            end
        end
    end
end

local function listRanksForDivision(divisionId)
    divisionId = tostring(divisionId or ''):lower()
    local norm = PdDivisions.normalize(divisionId)
    local list = RanksByDivision[divisionId] or RanksByDivision[norm] or {}
    local out = {}
    for _, e in ipairs(list) do
        out[#out + 1] = {
            id = e.id,
            divisionId = e.division_id,
            label = e.label,
            sortOrder = e.sort_order,
            builtin = e.builtin,
        }
    end
    table.sort(out, function(a, b)
        if a.sortOrder == b.sortOrder then return a.id < b.id end
        return a.sortOrder < b.sortOrder
    end)
    return out
end

local function allRanksGrouped()
    local out = {}
    local seenDiv = {}
    for divId in pairs(Config.Divisions or {}) do
        seenDiv[divId] = true
        out[divId] = listRanksForDivision(divId)
    end
    for divId in pairs(RanksByDivision) do
        local norm = PdDivisions.normalize(divId)
        if not seenDiv[norm] and not out[divId] then
            out[divId] = listRanksForDivision(divId)
        end
    end
    return out
end

local function getRankById(rankId)
    rankId = tonumber(rankId)
    if not rankId then return nil end
    return RankCache[rankId]
end

local function getAssignedRank(citizenid)
    if not citizenid then return nil end
    local row = MySQL.single.await(
        'SELECT division_rank_id FROM ltpd_profiles WHERE citizenid = ?',
        { citizenid }
    )
    local rid = row and tonumber(row.division_rank_id)
    if not rid then return nil end
    local rank = getRankById(rid)
    if not rank then return nil end
    return {
        id = rank.id,
        label = rank.label,
        divisionId = rank.division_id,
    }
end

local function clearAssignedRank(citizenid)
    if not citizenid then return end
    MySQL.update.await(
        'UPDATE ltpd_profiles SET division_rank_id = NULL WHERE citizenid = ?',
        { citizenid }
    )
end

local function rankBelongsToDivision(rankId, divisionId)
    for _, r in ipairs(listRanksForDivision(divisionId)) do
        if r.id == rankId then return true end
    end
    return false
end

local function setAssignedRank(citizenid, rankId, expectedDivision)
    if not citizenid then return false, 'Nėra profilio.' end
    rankId = tonumber(rankId)
    if not rankId or rankId < 1 then
        clearAssignedRank(citizenid)
        return true
    end
    local rank = getRankById(rankId)
    if not rank then return false, 'Divizijos rangas nerastas.' end
    if expectedDivision and not rankBelongsToDivision(rankId, expectedDivision) then
        return false, 'Rangas nepriklauso šiai divizijai.'
    end
    MySQL.query.await(
        'INSERT INTO ltpd_profiles (citizenid, division, division_rank_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE division_rank_id = VALUES(division_rank_id)',
        {
            citizenid,
            expectedDivision and PdDivisions.normalize(expectedDivision) or 'mp',
            rankId,
        }
    )
    return true
end

local function createRank(divisionId, label)
    divisionId = PdDivisions.normalize(divisionId)
    if not divisionId or divisionId == '' then return nil, 'Divizija privaloma.' end
    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' or #label > 128 then return nil, 'Neteisingas pavadinimas.' end
    local maxOrder = MySQL.scalar.await(
        'SELECT COALESCE(MAX(sort_order), 0) FROM ltpd_division_ranks WHERE division_id = ?',
        { divisionId }
    )
    local id = MySQL.insert.await(
        'INSERT INTO ltpd_division_ranks (division_id, label, sort_order, builtin) VALUES (?, ?, ?, 0)',
        { divisionId, label, (tonumber(maxOrder) or 0) + 10 }
    )
    loadRankCache()
    return id
end

local function deleteRank(rankId)
    rankId = tonumber(rankId)
    if not rankId then return false, 'Neteisingas ID.' end
    local rank = getRankById(rankId)
    if not rank then return false, 'Rangas nerastas.' end
    if rank.builtin then
        return false, 'Numatytojo rango ištrinti negalima.'
    end
    MySQL.update.await('UPDATE ltpd_profiles SET division_rank_id = NULL WHERE division_rank_id = ?', { rankId })
    MySQL.query.await('DELETE FROM ltpd_division_ranks WHERE id = ? AND builtin = 0', { rankId })
    loadRankCache()
    return true
end

local function renameRank(rankId, label)
    rankId = tonumber(rankId)
    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if not rankId or label == '' or #label > 128 then return false, 'Neteisingi duomenys.' end
    if not getRankById(rankId) then return false, 'Rangas nerastas.' end
    MySQL.update.await('UPDATE ltpd_division_ranks SET label = ? WHERE id = ?', { label, rankId })
    loadRankCache()
    return true
end

MySQL.ready(function()
    ensureDivisionRankSchema()
    seedDivisionRanks()
    loadRankCache()
end)

--- Išvalyti rangą, jei jis nepriklauso naujai divizijai
function LtpdClearDivisionRankIfMismatch(citizenid, newDivision)
    local assigned = getAssignedRank(citizenid)
    if not assigned then return end
    local want = PdDivisions.normalize(newDivision)
    local ranks = listRanksForDivision(want)
    for _, r in ipairs(ranks) do
        if r.id == assigned.id then return end
    end
    clearAssignedRank(citizenid)
end

function LtpdGetDivisionRankPayload(citizenid)
    return getAssignedRank(citizenid)
end

function LtpdGetDivisionRankLabel(citizenid)
    local r = getAssignedRank(citizenid)
    return r and r.label or nil
end

exports('GetDivisionRanks', listRanksForDivision)
exports('GetAllDivisionRanks', allRanksGrouped)
exports('GetDivisionRankForCitizenid', getAssignedRank)
exports('GetDivisionRankLabelForCitizenid', LtpdGetDivisionRankLabel)
exports('CreateDivisionRank', createRank)
exports('DeleteDivisionRank', deleteRank)
exports('RenameDivisionRank', renameRank)
exports('SetDivisionRankForCitizenid', setAssignedRank)
exports('ClearDivisionRankForCitizenid', clearAssignedRank)

local function canBossManageRanks(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData.job or P.PlayerData.job.name ~= (Config.JobName or 'police') then
        return false
    end
    if not P.PlayerData.job.onduty then return false end
    if P.PlayerData.job.isboss then return true end
    local grade = tonumber(P.PlayerData.job.grade and P.PlayerData.job.grade.level) or 0
    if grade >= (tonumber(Config.Permissions and Config.Permissions.boss_menu) or 7) then
        return true
    end
    if GetResourceState('mrp_bossmenu') == 'started' then
        return exports['mrp_bossmenu']:CanOpenBossMenu(src, 'police') == true
    end
    return false
end

RegisterNetEvent('mrp_ltpd:server:createDivisionRank', function(divisionId, label)
    local src = source
    if not canBossManageRanks(src) then return end
    local id, err = createRank(divisionId, label)
    if not id then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Nepavyko sukurti.', 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Divizijos rangas sukurtas.', 'success')
    TriggerEvent('mrp_ltpd:divisionRanksUpdated')
end)

RegisterNetEvent('mrp_ltpd:server:deleteDivisionRank', function(rankId)
    local src = source
    if not canBossManageRanks(src) then return end
    local ok, err = deleteRank(rankId)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Nepavyko ištrinti.', 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Divizijos rangas ištrintas.', 'success')
    TriggerEvent('mrp_ltpd:divisionRanksUpdated')
end)

RegisterNetEvent('mrp_ltpd:server:renameDivisionRank', function(rankId, label)
    local src = source
    if not canBossManageRanks(src) then return end
    local ok, err = renameRank(rankId, label)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Nepavyko pervadinti.', 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Divizijos rangas atnaujintas.', 'success')
    TriggerEvent('mrp_ltpd:divisionRanksUpdated')
end)

RegisterNetEvent('mrp_ltpd:server:setMemberDivisionRank', function(targetId, rankId)
    local src = source
    if not canBossManageRanks(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= (Config.JobName or 'police') then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas ne PD.', 'error')
    end
    local divRow = MySQL.single.await(
        'SELECT division FROM ltpd_profiles WHERE citizenid = ?',
        { T.PlayerData.citizenid }
    )
    local div = PdDivisions.normalize(divRow and divRow.division or 'mp')
    local ok, err = setAssignedRank(T.PlayerData.citizenid, rankId, div)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Nepavyko priskirti.', 'error')
    end
    TriggerClientEvent('mrp_ltpd:client:syncDivision', targetId, {
        division = div,
        storedDivision = div,
        grade = tonumber(T.PlayerData.job.grade and T.PlayerData.job.grade.level) or 0,
        effective = PdDivisions.effectiveDivision(
            tonumber(T.PlayerData.job.grade and T.PlayerData.job.grade.level) or 0,
            div
        ),
        divisionRank = getAssignedRank(T.PlayerData.citizenid),
    })
    local label = LtpdGetDivisionRankLabel(T.PlayerData.citizenid) or '—'
    TriggerClientEvent('QBCore:Notify', src, ('Divizijos rangas: %s'):format(label), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Naujas divizijos rangas: %s'):format(label), 'primary')
end)

--- Boss menu kviečia per event (kad nereikėtų tiesioginio dependency)
AddEventHandler('mrp_bossmenu:internal:setPdDivisionRank', function(targetId, rankId)
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= (Config.JobName or 'police') then return end
    local divRow = MySQL.single.await(
        'SELECT division FROM ltpd_profiles WHERE citizenid = ?',
        { T.PlayerData.citizenid }
    )
    local div = PdDivisions.normalize(divRow and divRow.division or 'mp')
    setAssignedRank(T.PlayerData.citizenid, rankId, div)
    TriggerClientEvent('mrp_ltpd:client:syncDivision', targetId, {
        division = div,
        storedDivision = div,
        grade = tonumber(T.PlayerData.job.grade and T.PlayerData.job.grade.level) or 0,
        effective = PdDivisions.effectiveDivision(
            tonumber(T.PlayerData.job.grade and T.PlayerData.job.grade.level) or 0,
            div
        ),
        divisionRank = getAssignedRank(T.PlayerData.citizenid),
    })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getDivisionRanksDashboard', function(src, cb)
    if not canBossManageRanks(src) then return cb(nil) end
    cb({
        ranksByDivision = allRanksGrouped(),
    })
end)

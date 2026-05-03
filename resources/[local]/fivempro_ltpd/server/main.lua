local QBCore = exports['qb-core']:GetCoreObject()

local function ensureTables()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_profiles` (
        `citizenid` varchar(50) NOT NULL,
        `division` varchar(32) NOT NULL DEFAULT 'patrol',
        `badge` varchar(16) DEFAULT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`),
        KEY `division` (`division`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_fines` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `amount` int(11) NOT NULL,
        `reason_code` varchar(64) DEFAULT NULL,
        `reason_label` varchar(255) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `officer` (`officer_citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_wanted` (
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL DEFAULT 0,
        `reason` varchar(512) DEFAULT NULL,
        `updated_by` varchar(50) DEFAULT NULL,
        `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_wanted_history` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL,
        `officer_citizenid` varchar(50) DEFAULT NULL,
        `note` varchar(512) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_arrests` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `notes` text,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

MySQL.ready(function()
    ensureTables()
end)

local function getGrade(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return -1 end
    return tonumber(Player.PlayerData.job.grade.level) or 0
end

local function jobIsPd(j)
    if not j or not j.name then return false end
    if j.name == Config.JobName then return true end
    if Config.AcceptLegacyPoliceJob and j.name == 'police' then return true end
    return false
end

local function isLtpdOnDuty(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local j = Player.PlayerData.job
    return jobIsPd(j) and j.onduty == true
end

local function hasPerm(src, key)
    if not isLtpdOnDuty(src) then return false end
    local need = Config.Permissions[key]
    if need == nil then return false end
    return getGrade(src) >= need
end

--- @param targetSrc number|nil
local function validTarget(officerSrc, targetSrc, maxDist)
    if not targetSrc or targetSrc < 1 then return false end
    local oPed = GetPlayerPed(officerSrc)
    local tPed = GetPlayerPed(targetSrc)
    if not oPed or not tPed or oPed == 0 or tPed == 0 then return false end
    local oc = GetEntityCoords(oPed)
    local tc = GetEntityCoords(tPed)
    return #(oc - tc) <= (maxDist or 3.5)
end

local function getDivisionForCitizenid(citizenid)
    local row = MySQL.single.await('SELECT division FROM ltpd_profiles WHERE citizenid = ?', { citizenid })
    if row and row.division then return row.division end
    return 'patrol'
end

-- Išplėstinė MDT informacija (transportas, baudų istorija, pinigai)
local function mdtFullAccess(src)
    if not hasPerm(src, 'mdt_search_full') then return false end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local g = getGrade(src)
    local div = getDivisionForCitizenid(Player.PlayerData.citizenid)
    if div == 'aras' and g < 5 then
        return false
    end
    local divCfg = Config.Divisions[div]
    if divCfg and g < (divCfg.minGrade or 0) then
        return false
    end
    return true
end

RegisterNetEvent('fivempro_ltpd:server:setDivision', function(targetCitizenid, newDiv)
    local src = source
    if not hasPerm(src, 'division_admin') then return end
    if not Config.Divisions[newDiv] then return end
    MySQL.query.await(
        'INSERT INTO ltpd_profiles (citizenid, division) VALUES (?, ?) ON DUPLICATE KEY UPDATE division = VALUES(division)',
        { targetCitizenid, newDiv }
    )
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:canOpenMdt', function(src, cb)
    cb(hasPerm(src, 'mdt_open'))
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:mdtContext', function(src, cb)
    if not hasPerm(src, 'mdt_open') then return cb(nil) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    MySQL.query.await('INSERT IGNORE INTO ltpd_profiles (citizenid, division) VALUES (?, ?)', {
        P.PlayerData.citizenid,
        'patrol',
    })
    cb({
        presets = Config.FinePresets,
        division = getDivisionForCitizenid(P.PlayerData.citizenid),
        grade = getGrade(src),
        permissions = {
            fullSearch = mdtFullAccess(src),
            fine = hasPerm(src, 'mdt_fine'),
            wanted = hasPerm(src, 'mdt_wanted'),
            arrest = hasPerm(src, 'mdt_arrest_record'),
        },
    })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:searchPerson', function(src, cb, query)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false }) end
    query = tostring(query or ''):gsub('%%', ''):sub(1, 64)
    if #query < 2 then return cb({ ok = true, rows = {} }) end

    local like = '%' .. query:lower() .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, money, metadata
        FROM players
        WHERE LOWER(charinfo) LIKE ?
        OR LOWER(citizenid) LIKE ?
        LIMIT 25
    ]], { like, like }) or {}

    local full = mdtFullAccess(src)
    for _, r in ipairs(rows) do
        local charinfo = json.decode(r.charinfo or '{}') or {}
        r.name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        r.citizenid = r.citizenid
        local onlineP = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
        r.player_id = onlineP and onlineP.PlayerData.source or nil
        local money = json.decode(r.money or '{}') or {}
        if full then
            r.cash = tonumber(money.cash) or 0
            r.bank = tonumber(money.bank) or 0
        else
            r.cash = nil
            r.bank = nil
        end
        local wanted = MySQL.single.await('SELECT level, reason FROM ltpd_wanted WHERE citizenid = ?', { r.citizenid })
        r.wanted_level = wanted and tonumber(wanted.level) or 0
        r.wanted_reason = wanted and wanted.reason or ''
        if full then
            local veh = MySQL.query.await(
                'SELECT plate, vehicle, state FROM player_vehicles WHERE citizenid = ? LIMIT 15',
                { r.citizenid }
            ) or {}
            r.vehicles = veh
            local fines = MySQL.query.await(
                'SELECT amount, reason_label, created_at FROM ltpd_fines WHERE citizenid = ? ORDER BY id DESC LIMIT 10',
                { r.citizenid }
            ) or {}
            r.fines = fines
        else
            r.vehicles = nil
            r.fines = nil
        end
        r.charinfo = nil
        r.money = nil
        r.metadata = nil
    end

    cb({ ok = true, rows = rows, full = full })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:searchVehicle', function(src, cb, plate)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false }) end
    plate = tostring(plate or ''):upper():gsub('%s+', ''):sub(1, 16)
    if #plate < 2 then return cb({ ok = true, row = nil }) end

    local row = MySQL.single.await([[
        SELECT pv.plate, pv.vehicle, pv.citizenid, pv.state,
               p.charinfo
        FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid
        WHERE pv.plate = ?
        LIMIT 1
    ]], { plate })

    if not row then return cb({ ok = true, row = nil }) end

    local charinfo = json.decode(row.charinfo or '{}') or {}
    row.owner_name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    row.charinfo = nil
    row.status = tonumber(row.state) == 0 and 'lauke' or 'garaže / saugoma'
    cb({ ok = true, row = row })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:issueFine', function(src, cb, data)
    if not hasPerm(src, 'mdt_fine') then return cb({ ok = false, message = 'Nėra teisės' }) end
    local tid = data and data.citizenid
    local amount = tonumber(data and data.amount) or 0
    local code = tostring(data and data.reason_code or ''):sub(1, 64)
    local label = tostring(data and data.reason_label or ''):sub(1, 255)
    if not tid or amount < 1 or amount > Config.MaxFineAmount then return cb({ ok = false }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false }) end

    local Target = QBCore.Functions.GetPlayerByCitizenId(tid)
    if Target then
        if not Target.Functions.RemoveMoney('bank', amount, 'ltpd-fine') then
            if not Target.Functions.RemoveMoney('cash', amount, 'ltpd-fine') then
                return cb({ ok = false, message = 'Žaidėjas neturi pinigų (bankas/grynieji)' })
            end
        end
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('Bauda %s €: %s'):format(amount, label), 'error')
    end

    MySQL.insert(
        'INSERT INTO ltpd_fines (citizenid, officer_citizenid, amount, reason_code, reason_label) VALUES (?, ?, ?, ?, ?)',
        { tid, Officer.PlayerData.citizenid, amount, code, label }
    )

    TriggerClientEvent('QBCore:Notify', src, 'Bauda išrašyta', 'success')
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:setWanted', function(src, cb, data)
    if not hasPerm(src, 'mdt_wanted') then return cb({ ok = false }) end
    local tid = data and data.citizenid
    local level = math.floor(tonumber(data and data.level) or 0)
    local reason = tostring(data and data.reason or ''):sub(1, 500)
    if not tid or level < 0 or level > 5 then return cb({ ok = false }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false }) end

    MySQL.query.await(
        [[INSERT INTO ltpd_wanted (citizenid, level, reason, updated_by)
          VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE level = VALUES(level), reason = VALUES(reason), updated_by = VALUES(updated_by)]],
        { tid, level, reason, Officer.PlayerData.citizenid }
    )

    MySQL.insert(
        'INSERT INTO ltpd_wanted_history (citizenid, level, officer_citizenid, note) VALUES (?, ?, ?, ?)',
        { tid, level, Officer.PlayerData.citizenid, reason }
    )

    local T = QBCore.Functions.GetPlayerByCitizenId(tid)
    if T then
        TriggerClientEvent('QBCore:Notify', T.PlayerData.source, ('Paieškomumas: %s'):format(level), 'primary')
    end

    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:addArrestNote', function(src, cb, citizenid, notes)
    if not hasPerm(src, 'mdt_arrest_record') then return cb({ ok = false }) end
    notes = tostring(notes or ''):sub(1, 2000)
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer or not citizenid then return cb({ ok = false }) end
    MySQL.insert(
        'INSERT INTO ltpd_arrests (citizenid, officer_citizenid, notes) VALUES (?, ?, ?)',
        { citizenid, Officer.PlayerData.citizenid, notes }
    )
    cb({ ok = true })
end)

RegisterNetEvent('fivempro_ltpd:server:cuffPlayer', function(targetId)
    local src = source
    if not hasPerm(src, 'cuff') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.5) then return end

    local tPlayer = QBCore.Functions.GetPlayer(targetId)
    if not tPlayer then return end

    local cuffed = Player(targetId).state.ltpdCuffed
    Player(targetId).state:set('ltpdCuffed', not cuffed, true)
    TriggerClientEvent('fivempro_ltpd:client:cuffedState', targetId, not cuffed)
    TriggerClientEvent('QBCore:Notify', src, cuffed and 'Antrankiai nuimti' or 'Uždėti antrankiai', 'primary')
end)

RegisterNetEvent('fivempro_ltpd:server:trySearchInventory', function(targetId)
    local src = source
    if not hasPerm(src, 'search_inventory') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.0) then return end
    if GetResourceState('qb-inventory') ~= 'started' then return end
    exports['qb-inventory']:OpenInventoryById(src, targetId)
end)

local function getStationById(id)
    id = tostring(id or '')
    for _, st in ipairs(Config.Stations or {}) do
        if st.id == id then return st end
    end
    return nil
end

local function officerNearCoords(src, coordsVec3, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - coordsVec3) <= maxDist
end

local function fleetModelAllowed(modelName)
    modelName = tostring(modelName or ''):lower()
    for _, v in ipairs(Config.FleetVehicles or {}) do
        if v.model and tostring(v.model):lower() == modelName then return true end
    end
    return false
end

RegisterNetEvent('fivempro_ltpd:server:openPoliceStash', function(stationId, stashIndex)
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if Player(src).state.inv_busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Uždaryk inventorių ir bandyk dar kartą.', 'error')
    end
    if not hasPerm(src, 'armory') then
        return TriggerClientEvent('QBCore:Notify', src, 'Prieinama tik policijai tarnyboje.', 'error')
    end
    stationId = tostring(stationId or '')
    stashIndex = tonumber(stashIndex)
    if not stashIndex or stashIndex < 1 then return end
    local st = getStationById(stationId)
    if not st or not st.stashes then return end
    local entry = st.stashes[stashIndex]
    if not entry or not entry.coords or not entry.stashId then return end
    if getGrade(src) < (tonumber(entry.minGrade) or 0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per žemas rangas šiam sandėliui.', 'error')
    end
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, entry.coords, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, entry.stashId, {
        maxweight = entry.maxweight or 2000000,
        slots = entry.slots or 60,
        label = entry.label or 'PD sandėlis',
    })
end)

RegisterNetEvent('fivempro_ltpd:server:openArmory', function(stationId)
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if Player(src).state.inv_busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Uždaryk inventorių ir bandyk dar kartą.', 'error')
    end
    if not hasPerm(src, 'armory') then
        return TriggerClientEvent('QBCore:Notify', src, 'Prieinama tik policijai tarnyboje.', 'error')
    end
    stationId = tostring(stationId or '')
    local st = getStationById(stationId)
    if not st or not st.armory or not st.armory.coords or not st.armory.stashId then return end
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, st.armory.coords, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo ginklinės (rūbinės). Priartėk arba patikrink koordinates.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.armory.stashId, {
        maxweight = st.armory.maxweight or 4000000,
        slots = st.armory.slots or 80,
        label = st.armory.label or 'Policijos ginklinė',
    })
end)

RegisterNetEvent('fivempro_ltpd:server:spawnFleet', function(stationId, modelName)
    local src = source
    if not hasPerm(src, 'garage') then return end
    stationId = tostring(stationId or '')
    modelName = tostring(modelName or ''):lower()
    if not fleetModelAllowed(modelName) then return end
    local st = getStationById(stationId)
    if not st or not st.garage or not st.garage.spawn then return end
    local sp = st.garage.spawn
    local checkVec = vector3(sp.x, sp.y, sp.z)
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, checkVec, maxD + 6.0) then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo PD transporto vietos.', 'error')
        return
    end
    local hash = joaat(modelName)
    local veh = QBCore.Functions.SpawnVehicle(src, hash, sp, true)
    if not veh or veh == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Nepavyko sukurti transporto.', 'error')
        return
    end
    local plateRaw = ('PD%s'):format(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plateRaw)
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
    if plate == nil or plate == '' then plate = plateRaw end
    SetVehicleEngineOn(veh, true, true, false)
    TriggerClientEvent('fivempro_ltpd:client:fleetVehicleReady', src, plate)
    TriggerClientEvent('QBCore:Notify', src, 'Transportas paruoštas.', 'success')
end)

local function fleetHeliModelAllowed(modelName)
    modelName = tostring(modelName or ''):lower()
    for _, v in ipairs(Config.FleetHelicopters or {}) do
        if v.model and tostring(v.model):lower() == modelName then return true end
    end
    return false
end

RegisterNetEvent('fivempro_ltpd:server:spawnFleetHeli', function(stationId, modelName)
    local src = source
    if not hasPerm(src, 'garage') then return end
    stationId = tostring(stationId or '')
    modelName = tostring(modelName or ''):lower()
    if not fleetHeliModelAllowed(modelName) then return end
    local st = getStationById(stationId)
    if not st or not st.heliGarage or not st.heliGarage.spawn then
        return TriggerClientEvent('QBCore:Notify', src, 'Helipadas nekonfigūruotas.', 'error')
    end
    local sp = st.heliGarage.spawn
    local checkVec = vector3(sp.x, sp.y, sp.z)
    local maxD = (tonumber(Config.ArmoryGarageDistance) or 22.0) + 10.0
    if not officerNearCoords(src, checkVec, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo helipado.', 'error')
    end
    local hash = joaat(modelName)
    local veh = QBCore.Functions.SpawnVehicle(src, hash, sp, true)
    if not veh or veh == 0 then
        veh = QBCore.Functions.CreateVehicle(src, hash, 'heli', sp, true)
    end
    if not veh or veh == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko sukurti sraigtasparnio.', 'error')
    end
    local plateRaw = ('PD%s'):format(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plateRaw)
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
    if plate == nil or plate == '' then plate = plateRaw end
    SetVehicleEngineOn(veh, true, true, false)
    TriggerClientEvent('fivempro_ltpd:client:fleetVehicleReady', src, plate)
    TriggerClientEvent('QBCore:Notify', src, 'Sraigtasparnis paruoštas.', 'success')
end)

local function canBossAction(src)
    if not isLtpdOnDuty(src) then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if P.PlayerData.job.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 8)
end

local function nearAnyManagement(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local r = tonumber(Config.ManagementRadius) or 12.0
    for _, st in ipairs(Config.Stations or {}) do
        if st.management and st.management.coords then
            if #(c - st.management.coords) <= r then
                return true
            end
        end
    end
    return false
end

--- Vadovas gali keisti tik žemesnio rango pareigūnus (isboss – viską).
local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    local bg = getGrade(bossSrc)
    return bg > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('fivempro_ltpd:server:bossHire', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 10 then return end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti aukštesnio ar lygaus rango už save.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    T.Functions.SetJobDuty(true)
    TriggerClientEvent('QBCore:Notify', src, ('Įdarbinta (ID %s), rangas %s'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Priimta į policiją. Rangas: %s'):format(grade), 'success')
end)

RegisterNetEvent('fivempro_ltpd:server:bossFire', function(targetId)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if not jobIsPd(T.PlayerData.job) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis žaidėjas ne PD.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti aukštesnio ar lygaus rango.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, ('Atleistas žaidėjas ID %s'):format(targetId), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš policijos.', 'error')
end)

RegisterNetEvent('fivempro_ltpd:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 10 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if not jobIsPd(T.PlayerData.job) then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas ne PD.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti aukštesnio ar lygaus rango.', 'error')
    end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti šio rango (per aukštas).', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, ('Rangas pakeistas (ID %s → %s)'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Tavo naujas rangas: %s'):format(grade), 'primary')
end)

exports('IsLtpdOnDuty', function(src)
    return isLtpdOnDuty(src)
end)

exports('HasLtpdPermission', function(src, key)
    return hasPerm(src, key)
end)

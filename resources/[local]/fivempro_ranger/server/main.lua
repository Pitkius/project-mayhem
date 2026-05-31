local QBCore = exports['qb-core']:GetCoreObject()

local function isRanger(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    return P.PlayerData.job.name == Config.JobName and P.PlayerData.job.onduty
end

local function hasGrade(src, minGrade)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    return (tonumber(P.PlayerData.job.grade.level) or 0) >= (minGrade or 0)
end

local function validTarget(src, targetId, maxDist)
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return false end
    local pedA = GetPlayerPed(src)
    local pedB = GetPlayerPed(targetId)
    if not pedA or not pedB or pedA == 0 or pedB == 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= (maxDist or 3.5)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `fivempro_ranger_fines` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `officer_cid` VARCHAR(50) NOT NULL,
            `code` VARCHAR(32) NOT NULL,
            `label` VARCHAR(128) NOT NULL,
            `amount` INT NOT NULL DEFAULT 0,
            `notes` TEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

RegisterNetEvent('fivempro_ranger:server:cuffPlayer', function(targetId)
    local src = source
    if not isRanger(src) or not hasGrade(src, Config.Permissions.cuff or 0) then return end
    if not validTarget(src, targetId, 3.5) then return end
    if not QBCore.Functions.GetPlayer(targetId) then return end
    local cuffed = Player(targetId).state.ltpdCuffed
    Player(targetId).state:set('ltpdCuffed', not cuffed, true)
    TriggerClientEvent('fivempro_ranger:client:cuffedState', targetId, not cuffed)
    TriggerClientEvent('QBCore:Notify', src, cuffed and 'Antrankiai nuimti' or 'Uždėti antrankiai', 'primary')
end)

RegisterNetEvent('fivempro_ranger:server:issueFine', function(targetId, code, label, amount, notes)
    local src = source
    if not isRanger(src) or not hasGrade(src, Config.Permissions.fine or 0) then return end
    if not validTarget(src, targetId, 5.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local Target = QBCore.Functions.GetPlayer(targetId)
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Target or not Officer then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > (Config.MaxFineAmount or 25000) then
        return TriggerClientEvent('QBCore:Notify', src, 'Netinkama suma.', 'error')
    end
    local bank = Target.PlayerData.money.bank or 0
    if bank >= amount then
        Target.Functions.RemoveMoney('bank', amount, 'ranger-fine')
    else
        local rest = amount - bank
        if bank > 0 then Target.Functions.RemoveMoney('bank', bank, 'ranger-fine') end
        Target.Functions.RemoveMoney('cash', rest, 'ranger-fine')
    end
    MySQL.insert.await(
        'INSERT INTO fivempro_ranger_fines (citizenid, officer_cid, code, label, amount, notes) VALUES (?, ?, ?, ?, ?, ?)',
        { Target.PlayerData.citizenid, Officer.PlayerData.citizenid, tostring(code or ''), tostring(label or ''), amount, tostring(notes or '') }
    )
    TriggerClientEvent('QBCore:Notify', src, ('Bauda $%s išrašyta.'):format(amount), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Gamtos bauda: $%s — %s'):format(amount, label), 'error')
end)

RegisterNetEvent('fivempro_ranger:server:openStash', function()
    local src = source
    if not isRanger(src) then return end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    local stashId = ('ranger_%s'):format(P.PlayerData.citizenid)
    local data = { label = 'Gamtosaugininko daiktadėžė', slots = 30, maxweight = 120000 }
    exports['qb-inventory']:CreateInventory(stashId, data)
    exports['qb-inventory']:OpenInventory(src, stashId, data)
end)

local function ensureRangerStash(citizenid)
    if GetResourceState('qb-inventory') ~= 'started' then return end
    local stashId = ('ranger_%s'):format(citizenid)
    exports['qb-inventory']:CreateInventory(stashId, {
        label = 'Gamtosaugininko daiktadėžė',
        slots = 30,
        maxweight = 120000,
    })
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then
        ensureRangerStash(Player.PlayerData.citizenid)
    end
end)

local function getGrade(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return 0 end
    return tonumber(P.PlayerData.job.grade.level) or 0
end

local function canBossAction(src)
    if not isRanger(src) then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if P.PlayerData.job.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 3)
end

local function nearBossPoint(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local boss = Config.Station.bossCoords or Config.Station.coords
    return #(c - boss) <= (Config.Station.managementRadius or 4.0)
end

local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    return getGrade(bossSrc) > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('fivempro_ranger:server:bossHire', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearBossPoint(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 3 then return end
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
    TriggerClientEvent('QBCore:Notify', targetId, ('Priimta į gamtos apsaugą. Rangas: %s'):format(grade), 'success')
end)

RegisterNetEvent('fivempro_ranger:server:bossFire', function(targetId)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearBossPoint(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if T.PlayerData.job.name ~= Config.JobName then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis žaidėjas ne gamtosaugininkas.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti aukštesnio ar lygaus rango.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, ('Atleistas žaidėjas ID %s'):format(targetId), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš gamtos apsaugos.', 'error')
end)

RegisterNetEvent('fivempro_ranger:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearBossPoint(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 3 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if T.PlayerData.job.name ~= Config.JobName then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis žaidėjas ne gamtosaugininkas.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti aukštesnio ar lygaus rango.', 'error')
    end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti aukštesnio ar lygaus rango už save.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, ('Rangas pakeistas (ID %s → %s)'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Naujas rangas: %s'):format(grade), 'primary')
end)

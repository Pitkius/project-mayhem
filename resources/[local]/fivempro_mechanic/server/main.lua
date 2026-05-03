local QBCore = exports['qb-core']:GetCoreObject()

local function nearCoords(src, coords, maxDist)
    maxDist = tonumber(maxDist) or 18.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local d = #(p - vector3(coords.x, coords.y, coords.z))
    return d <= maxDist
end

RegisterNetEvent('fivempro_mechanic:server:openStash', function()
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    local st = Config.Stash
    if not nearCoords(src, st.coords, 22.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.stashId, {
        maxweight = st.maxweight,
        slots = st.slots,
        label = st.label,
    })
end)

local function getGrade(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return -1 end
    return tonumber(P.PlayerData.job.grade.level) or 0
end

local function canBoss(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then return false end
    if j.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 4)
end

local function nearManagement(src)
    return nearCoords(src, Config.Management.coords, 18.0)
end

local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    local bg = getGrade(bossSrc)
    return bg > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('fivempro_mechanic:server:bossHire', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > 5 then return end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti tokio rango.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    T.Functions.SetJobDuty(true)
    TriggerClientEvent('QBCore:Notify', src, 'Įdarbinta.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Priimta į mechanikus.', 'success')
end)

RegisterNetEvent('fivempro_mechanic:server:bossFire', function(targetId)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return end
    if T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, 'Atleista.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš mechanikų.', 'error')
end)

RegisterNetEvent('fivempro_mechanic:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBoss(src) or not nearManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or grade == nil or grade < 0 or grade > 5 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or T.PlayerData.job.name ~= Config.JobName then return end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) or not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, 'Rangas pakeistas.', 'success')
end)

local function nearRepairBay(src, bayIdx)
    bayIdx = tonumber(bayIdx)
    if not bayIdx or not Config.RepairBays or not Config.RepairBays[bayIdx] then
        return false
    end
    local bay = Config.RepairBays[bayIdx]
    local radius = math.max(tonumber(bay.length) or 6.0, tonumber(bay.width) or 6.0) * 0.55 + 14.0
    return nearCoords(src, bay.coords, radius)
end

RegisterNetEvent('fivempro_mechanic:server:saveBayVehicleTune', function(bayIdx, props)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    if not nearRepairBay(src, bayIdx) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo remonto zonos.', 'error')
    end
    if type(props) ~= 'table' then return end
    local plate = props.plate and tostring(props.plate):upper():gsub('%s+', '')
    if not plate or plate == '' then
        return TriggerClientEvent('QBCore:Notify', src, 'Nėra numerių.', 'error')
    end
    local row = MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not row then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis transportas neregistruotas sistemoje.', 'error')
    end
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {
        json.encode(props),
        plate,
    })
    TriggerClientEvent('QBCore:Notify', src, 'Modifikacijos išsaugotos duomenų bazėje.', 'success')
end)

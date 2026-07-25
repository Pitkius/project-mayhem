local QBCore = exports['qb-core']:GetCoreObject()

local function nearCoords(src, coords, maxDist)
    maxDist = tonumber(maxDist) or 18.0
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local d = #(p - vector3(coords.x, coords.y, coords.z))
    return d <= maxDist
end

local function validPlayerTarget(src, targetId, maxDist)
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return false end
    local sp = GetPlayerPed(src)
    local tp = GetPlayerPed(targetId)
    if not sp or sp == 0 or not tp or tp == 0 then return false end
    return #(GetEntityCoords(sp) - GetEntityCoords(tp)) <= (maxDist or 2.8)
end

local function isEmsOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local j = P.PlayerData.job
    return j and j.name == Config.JobName and j.onduty == true
end

local function emsHasGrade(src, minGrade)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    return (tonumber(P.PlayerData.job.grade.level) or 0) >= (minGrade or 0)
end

local function targetIsDown(targetId)
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return false end
    local m = T.PlayerData.metadata or {}
    if m.isdead == true or m.inlaststand == true then return true end
    local ped = GetPlayerPed(targetId)
    if not ped or ped == 0 then return false end
    local hp = GetEntityHealth(ped)
    return hp <= 100
end

local function clearDeathMeta(Player)
    if not Player then return end
    Player.Functions.SetMetaData('isdead', false)
    Player.Functions.SetMetaData('inlaststand', false)
end

local function removeOneItem(Player, itemName)
    if not Player or not itemName then return false end
    local item = Player.Functions.GetItemByName(itemName)
    if not item then return false end
    return Player.Functions.RemoveItem(itemName, 1)
end

RegisterNetEvent('mrp_ambulance:server:revivePlayer', function(targetId)
    local src = source
    if not isEmsOnDuty(src) or not emsHasGrade(src, Config.Permissions.revive or 0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje.', 'error')
    end
    local maxDist = (Config.Medical and Config.Medical.maxDistance) or 2.8
    if not validPlayerTarget(src, targetId, maxDist + 0.5) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return end
    if not targetIsDown(targetId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Asmuo nėra negyvas.', 'error')
    end
    clearDeathMeta(T)
    local health = (Config.Medical and Config.Medical.revive and Config.Medical.revive.health) or 200
    TriggerClientEvent('mrp_ambulance:client:applyRevive', targetId, health)
    TriggerClientEvent('QBCore:Notify', src, 'Asmuo atgaivintas.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Jus atgaivino medikas.', 'success')
end)

RegisterNetEvent('mrp_ambulance:server:healPlayer', function(targetId)
    local src = source
    if not isEmsOnDuty(src) or not emsHasGrade(src, Config.Permissions.heal or 0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje.', 'error')
    end
    local maxDist = (Config.Medical and Config.Medical.maxDistance) or 2.8
    if not validPlayerTarget(src, targetId, maxDist + 0.5) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then return end
    if targetIsDown(targetId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Pirmiausia atgaivinkite.', 'error')
    end
    local health = (Config.Medical and Config.Medical.heal and Config.Medical.heal.health) or 200
    TriggerClientEvent('mrp_ambulance:client:applyHeal', targetId, health, 0)
    TriggerClientEvent('QBCore:Notify', src, 'Asmuo pagydytas.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Jus pagydė medikas.', 'success')
end)

RegisterNetEvent('mrp_ambulance:server:useMedicalItem', function(itemName, targetId)
    local src = source
    itemName = tostring(itemName or '')
    local cfg = Config.Medical and Config.Medical.items and Config.Medical.items[itemName]
    if not cfg then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Player.Functions.GetItemByName(itemName) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite daikto.', 'error')
    end

    targetId = tonumber(targetId)
    local applyTo = src
    if targetId and targetId ~= src then
        if not cfg.canUseOnOthers then
            return TriggerClientEvent('QBCore:Notify', src, 'Negalima naudoti ant kito.', 'error')
        end
        if cfg.emsOnlyOnOthers and not isEmsOnDuty(src) then
            return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje ant kitų.', 'error')
        end
        if not validPlayerTarget(src, targetId, 3.0) then
            return TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
        end
        applyTo = targetId
    end

    local down = targetIsDown(applyTo)
    if down then
        if not cfg.canRevive then
            return TriggerClientEvent('QBCore:Notify', src, 'Šis daiktas neatgaivina.', 'error')
        end
        if not isEmsOnDuty(src) then
            return TriggerClientEvent('QBCore:Notify', src, 'Atgaivinti gali tik EMS.', 'error')
        end
        if not removeOneItem(Player, itemName) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
        local T = QBCore.Functions.GetPlayer(applyTo)
        clearDeathMeta(T)
        local health = (Config.Medical and Config.Medical.revive and Config.Medical.revive.health) or 200
        TriggerClientEvent('mrp_ambulance:client:applyRevive', applyTo, health)
        TriggerClientEvent('QBCore:Notify', src, 'Atgaivinta.', 'success')
        if applyTo ~= src then
            TriggerClientEvent('QBCore:Notify', applyTo, 'Jus atgaivino.', 'success')
        end
        return
    end

    if not removeOneItem(Player, itemName) then return end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    TriggerClientEvent('mrp_ambulance:client:applyHealAmount', applyTo, cfg.healAmount or 20, cfg.armour or 0)
    TriggerClientEvent('QBCore:Notify', src, 'Panaudota.', 'success')
    if applyTo ~= src then
        TriggerClientEvent('QBCore:Notify', applyTo, 'Jums suteikta medicininė pagalba.', 'success')
    end
end)

CreateThread(function()
    local items = Config.Medical and Config.Medical.items or {}
    for itemName in pairs(items) do
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            TriggerClientEvent('mrp_ambulance:client:useMedicalItem', source, itemName)
        end)
    end
end)

RegisterNetEvent('mrp_ambulance:server:openStash', function(stationId)
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    if j.name ~= Config.JobName or not j.onduty then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik EMS tarnyboje.', 'error')
    end
    stationId = tostring(stationId or '')
    local st = nil
    for _, row in ipairs(Config.Stations or {}) do
        if row.id == stationId then st = row break end
    end
    st = st or Config.Stations[1]
    if not st or not st.stash then return end
    if not nearCoords(src, st.stash.coords, 22.0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.stash.stashId, {
        maxweight = st.stash.maxweight,
        slots = st.stash.slots,
        label = st.stash.label,
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
    for _, st in ipairs(Config.Stations or {}) do
        if st.management and st.management.coords and nearCoords(src, st.management.coords, 18.0) then
            return true
        end
    end
    return false
end

local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    local bg = getGrade(bossSrc)
    return bg > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('mrp_ambulance:server:bossHire', function(targetId, grade)
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
    TriggerClientEvent('QBCore:Notify', targetId, 'Priimta į EMS.', 'success')
end)

RegisterNetEvent('mrp_ambulance:server:bossFire', function(targetId)
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
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš EMS.', 'error')
end)

RegisterNetEvent('mrp_ambulance:server:bossSetGrade', function(targetId, grade)
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

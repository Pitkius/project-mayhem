local QBCore = exports['qb-core']:GetCoreObject()

local function validTarget(src, targetId, maxDist)
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return false end
    local sp = GetPlayerPed(src)
    local tp = GetPlayerPed(targetId)
    if not sp or sp == 0 or not tp or tp == 0 then return false end
    return #(GetEntityCoords(sp) - GetEntityCoords(tp)) <= (maxDist or Config.MaxDistance or 2.5)
end

local function targetMetadataDown(Player)
    if not Player then return false end
    local m = Player.PlayerData.metadata or {}
    return m.isdead == true or m.inlaststand == true
end

local function targetAllowsInteraction(targetId)
    local st = Player(targetId).state
    if st.ltpdCuffed then return true, 'restrained' end
    if st.handsUp then return true, 'hands' end
    local tPlayer = QBCore.Functions.GetPlayer(targetId)
    if targetMetadataDown(tPlayer) then return true, 'down' end
    return false, 'hands'
end

local function setRestrained(targetId, state, rType)
    local tPlayer = QBCore.Functions.GetPlayer(targetId)
    if not tPlayer then return end
    Player(targetId).state:set('ltpdCuffed', state, true)
    Player(targetId).state:set('mrpRestraintType', state and rType or nil, true)
    tPlayer.Functions.SetMetaData('ishandcuffed', state)
    TriggerClientEvent('mrp_restraints:client:restrainedState', targetId, state, rType)
end

local function hasItem(Player, itemName)
    if not Player or not itemName then return false end
    return Player.Functions.GetItemByName(itemName) ~= nil
end

local function removeItem(Player, itemName, amount)
    amount = amount or 1
    return Player.Functions.RemoveItem(itemName, amount)
end

local function addItem(Player, itemName, amount)
    amount = amount or 1
    return Player.Functions.AddItem(itemName, amount)
end

local function isPdOnDuty(Player)
    local j = Player and Player.PlayerData.job
    return j and j.name == Config.PoliceJob and j.onduty == true
end

local function isRangerOnDuty(Player)
    local j = Player and Player.PlayerData.job
    return j and j.name == Config.RangerJob and j.onduty == true
end

QBCore.Functions.CreateCallback('mrp_restraints:server:canSearch', function(src, cb, targetId)
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId) then
        return cb(false, 'Per toli arba netinkamas taikinys.')
    end
    local ok = targetAllowsInteraction(targetId)
    if not ok then
        return cb(false, 'Galima apieškoti tik pakėlus rankas arba negyvą asmenį.')
    end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_restraints:server:canRestrain', function(src, cb, targetId, rType, removing)
    targetId = tonumber(targetId)
    rType = tostring(rType or '')
    local cfg = Config.Restraints[rType]
    if not cfg then return cb(false, 'Nežinomas surakymo tipas.') end
    if not validTarget(src, targetId) then
        return cb(false, 'Per toli arba netinkamas taikinys.')
    end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    local tgtPlayer = QBCore.Functions.GetPlayer(targetId)
    if not srcPlayer or not tgtPlayer then return cb(false, 'Žaidėjas neprisijungęs.') end

    local restrained = Player(targetId).state.ltpdCuffed == true
    local currentType = Player(targetId).state.mrpRestraintType

    if removing then
        if not restrained then return cb(false, 'Asmuo nėra surakintas.') end
        if currentType and currentType ~= rType then
            return cb(false, 'Netinkamas nuėmimo būdas.')
        end
        if cfg.removeRequiresItem and not hasItem(srcPlayer, cfg.removeRequiresItem) then
            return cb(false, ('Reikia: %s'):format(QBCore.Shared.Items[cfg.removeRequiresItem].label or cfg.removeRequiresItem))
        end
        if cfg.returnOnRemove and not hasItem(srcPlayer, cfg.item) then
            -- leidžiama nuimti antrankius net jei neturi laisvų — grąžinami po nuėmimo
        end
        return cb(true)
    end

    if restrained then return cb(false, 'Asmuo jau surakintas.') end
    local ok, reason = targetAllowsInteraction(targetId)
    if not ok and reason ~= 'restrained' then
        return cb(false, 'Galima surakinti tik pakėlus rankas arba negyvą asmenį.')
    end
    if not hasItem(srcPlayer, cfg.item) then
        return cb(false, ('Neturite: %s'):format(QBCore.Shared.Items[cfg.item].label or cfg.item))
    end
    cb(true)
end)

local function doSearchPlayer(src, targetId)
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId) then return end
    local ok = targetAllowsInteraction(targetId)
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima apieškoti.', 'error')
    end
    if GetResourceState('qb-inventory') ~= 'started' then return end
    TriggerClientEvent('mrp_restraints:client:startSearchAnim', src)
    exports['qb-inventory']:OpenInventoryById(src, targetId)
end

local function doToggleRestraint(src, targetId, rType)
    targetId = tonumber(targetId)
    rType = tostring(rType or '')
    local cfg = Config.Restraints[rType]
    if not cfg or not validTarget(src, targetId) then return end

    local srcPlayer = QBCore.Functions.GetPlayer(src)
    local tgtPlayer = QBCore.Functions.GetPlayer(targetId)
    if not srcPlayer or not tgtPlayer then return end

    local restrained = Player(targetId).state.ltpdCuffed == true
    local currentType = Player(targetId).state.mrpRestraintType

    if restrained then
        if currentType and currentType ~= rType then
            return TriggerClientEvent('QBCore:Notify', src, 'Netinkamas nuėmimo būdas.', 'error')
        end
        if cfg.removeRequiresItem and not hasItem(srcPlayer, cfg.removeRequiresItem) then
            return TriggerClientEvent('QBCore:Notify', src, ('Reikia: %s'):format(QBCore.Shared.Items[cfg.removeRequiresItem].label or cfg.removeRequiresItem), 'error')
        end
        setRestrained(targetId, false, nil)
        if cfg.returnOnRemove then
            if addItem(srcPlayer, cfg.item, 1) then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.item], 'add')
            end
        end
        TriggerClientEvent('QBCore:Notify', src, 'Surakymas nuimtas.', 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Surakymas nuimtas.', 'primary')
        return
    end

    local ok, reason = targetAllowsInteraction(targetId)
    if not ok and reason ~= 'restrained' then
        return TriggerClientEvent('QBCore:Notify', src, 'Galima surakinti tik pakėlus rankas arba negyvą asmenį.', 'error')
    end
    if not hasItem(srcPlayer, cfg.item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite reikiamo daikto.', 'error')
    end
    if cfg.consumeOnApply or cfg.returnOnRemove then
        if not removeItem(srcPlayer, cfg.item, 1) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.item], 'remove')
    end
    setRestrained(targetId, true, rType)
    TriggerClientEvent('QBCore:Notify', src, cfg.label .. ' uždėta.', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Esate surakintas.', 'error')
end

RegisterNetEvent('mrp_restraints:server:searchPlayer', function(targetId)
    doSearchPlayer(source, targetId)
end)

RegisterNetEvent('mrp_restraints:server:searchAnimStopped', function()
    TriggerClientEvent('mrp_restraints:client:stopSearchAnim', source)
end)

RegisterNetEvent('mrp_restraints:server:toggleRestraint', function(targetId, rType)
    doToggleRestraint(source, targetId, rType)
end)

AddEventHandler('mrp_restraints:internal:toggleRestraint', function(src, targetId, rType)
    doToggleRestraint(src, targetId, rType)
end)

AddEventHandler('mrp_restraints:internal:searchPlayer', function(src, targetId)
    doSearchPlayer(src, targetId)
end)

exports('IsRestrained', function(targetId)
    targetId = tonumber(targetId)
    if not targetId then return false end
    return Player(targetId).state.ltpdCuffed == true
end)

exports('GetRestraintType', function(targetId)
    targetId = tonumber(targetId)
    if not targetId then return nil end
    return Player(targetId).state.mrpRestraintType
end)

exports('SetRestrained', setRestrained)

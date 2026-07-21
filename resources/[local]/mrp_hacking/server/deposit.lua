local QBCore = exports['qb-core']:GetCoreObject()

--- Shared vault / boxes — loot iškart po gręžimo (be pinigų kalno)
local VaultOpenUntil = {} --- [locId] = unix
local Drilled = {} --- [boxKey] = true

local function boxKey(locId, index)
    return ('%s:%d'):format(tostring(locId), tonumber(index) or 0)
end

local function depositCfg()
    return Config.Robberies.Deposit or {}
end

local function getBoxDef(locId, index)
    local list = (Config.Robberies.DepositBoxes or {})[tostring(locId)]
    if not list then return nil end
    return list[tonumber(index)]
end

local function isVaultOpen(locId)
    locId = tostring(locId or '')
    local untilTs = VaultOpenUntil[locId]
    return untilTs and os.time() < untilTs
end

local function buildDrilledMap(locId)
    locId = tostring(locId or '')
    local drilled = {}
    for key, v in pairs(Drilled) do
        if v and key:sub(1, #locId + 1) == (locId .. ':') then
            drilled[key] = true
        end
    end
    return drilled
end

local function openVault(locId)
    locId = tostring(locId or '')
    if locId == '' then return end
    local mins = tonumber(depositCfg().vaultOpenMinutes) or 25
    VaultOpenUntil[locId] = os.time() + (mins * 60)
    TriggerClientEvent('mrp_hacking:client:depositVaultState', -1, locId, true, buildDrilledMap(locId))
end

RegisterNetEvent('mrp_hacking:server:markVaultOpen', function(locId)
    openVault(locId)
end)

exports('MarkVaultOpenFor', function(src, locId)
    openVault(locId)
    if src then
        TriggerClientEvent('QBCore:Notify', src,
            'Seifas atidarytas — žali markeriai = gręžiamos deposit dėžutės (GTA Online gręžimas).',
            'success', 10000)
    end
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:depositGetState', function(_, cb, locId)
    locId = tostring(locId or '')
    cb({ open = isVaultOpen(locId), drilled = buildDrilledMap(locId) })
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:depositCanDrill', function(src, cb, locId, index)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    locId = tostring(locId or '')
    if not isVaultOpen(locId) then
        return cb({ ok = false, msg = 'Pirmiau išgręžk ir atidaryk seifo duris.' })
    end
    local key = boxKey(locId, index)
    if Drilled[key] then
        return cb({ ok = false, msg = 'Ši dėžutė jau išgręžta.' })
    end
    local item = Config.SmallDrillItem or 'small_drill'
    if not Player.Functions.GetItemByName(item) then
        return cb({ ok = false, msg = 'Reikia mažo grąžto (small_drill).' })
    end
    if not getBoxDef(locId, index) then
        return cb({ ok = false, msg = 'Dėžutė nerasta.' })
    end
    cb({ ok = true })
end)

RegisterNetEvent('mrp_hacking:server:depositDrilled', function(locId, index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    locId = tostring(locId or '')
    index = tonumber(index)
    if not isVaultOpen(locId) then return end

    local box = getBoxDef(locId, index)
    if not box then return end

    local key = boxKey(locId, index)
    if Drilled[key] then return end

    local item = Config.SmallDrillItem or 'small_drill'
    if not Player.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia mažo grąžto.', 'error')
    end
    Player.Functions.RemoveItem(item, 1)
    Drilled[key] = true

    exports['mrp_hacking']:GiveRobberyLoot(src, 'deposit_box', {
        reason = 'deposit-box',
        prefix = 'Deposit dėžutė: ',
    })

    TriggerClientEvent('mrp_hacking:client:depositBoxDrilled', -1, locId, index, key)
    TriggerClientEvent('QBCore:Notify', src, 'Dėžutė išgręžta — grobis paimtas.', 'success', 6000)
end)

RegisterNetEvent('mrp_hacking:server:depositClaimPile', function() end)
RegisterNetEvent('mrp_hacking:server:depositStartClaim', function(locId, index)
    local src = source
    TriggerClientEvent('mrp_hacking:client:depositClaimDenied', src,
        boxKey(tostring(locId or ''), tonumber(index)),
        'Pinigų kalno nėra — grobis jau paimtas gręžiant.')
end)
RegisterNetEvent('mrp_hacking:server:depositCancelClaim', function() end)

local QBCore = exports['qb-core']:GetCoreObject()

--- Shared vault / boxes (ne per-player) — pinigų kalną surenka tik 1 žmogus
local VaultOpenUntil = {} --- [locId] = unix
local Drilled = {} --- [boxKey] = true
local Piles = {} --- [boxKey] = { locId, index, coords, heading, claiming }

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

local function buildStatePayload(locId)
    locId = tostring(locId or '')
    local drilled, piles = {}, {}
    for key, v in pairs(Drilled) do
        if v and key:sub(1, #locId + 1) == (locId .. ':') then
            drilled[key] = true
        end
    end
    for key, pile in pairs(Piles) do
        if pile and pile.locId == locId and not pile.claimed then
            piles[key] = {
                locId = pile.locId,
                index = pile.index,
                coords = pile.coords,
                heading = pile.heading,
            }
        end
    end
    return drilled, piles
end

local function openVault(locId)
    locId = tostring(locId or '')
    if locId == '' then return end
    local mins = tonumber(depositCfg().vaultOpenMinutes) or 25
    VaultOpenUntil[locId] = os.time() + (mins * 60)
    local drilledMap, pilesMap = buildStatePayload(locId)
    TriggerClientEvent('mrp_hacking:client:depositVaultState', -1, locId, true, drilledMap, pilesMap)
end

RegisterNetEvent('mrp_hacking:server:markVaultOpen', function(locId)
    openVault(locId)
end)

exports('MarkVaultOpenFor', function(src, locId)
    openVault(locId)
    if src then
        TriggerClientEvent('QBCore:Notify', src,
            'Seifas atrakintas — žali markeriai = gręžiamos deposit dėžutės. Po gręžimo surink pinigų kalną.',
            'success', 10000)
    end
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:depositGetState', function(src, cb, locId)
    locId = tostring(locId or '')
    local open = isVaultOpen(locId)
    local drilled, piles = buildStatePayload(locId)
    cb({ open = open, drilled = drilled, piles = piles })
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:depositCanDrill', function(src, cb, locId, index)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    locId = tostring(locId or '')
    if not isVaultOpen(locId) then
        return cb({ ok = false, msg = 'Pirmiau atrakink seifą (L2/L3 hack).' })
    end
    local key = boxKey(locId, index)
    if Drilled[key] then
        return cb({ ok = false, msg = 'Ši dėžutė jau išgręžta.' })
    end
    if Piles[key] and not Piles[key].claimed then
        return cb({ ok = false, msg = 'Dėžutė atidaryta — surink pinigų kalną.' })
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
    if Drilled[key] or (Piles[key] and not Piles[key].claimed) then return end

    local item = Config.SmallDrillItem or 'small_drill'
    if not Player.Functions.GetItemByName(item) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia mažo grąžto.', 'error')
    end
    Player.Functions.RemoveItem(item, 1)
    Drilled[key] = true

    local cfg = depositCfg()
    local off = cfg.pileOffset or vector3(0.0, 0.35, 0.0)
    local heading = box.heading or 0.0
    local rad = math.rad(heading)
    local fx = -math.sin(rad)
    local fy = math.cos(rad)
    local forward = off.y or 0.35
    local coords = vector3(
        box.coords.x + fx * forward,
        box.coords.y + fy * forward,
        box.coords.z + (off.z or 0.0)
    )

    Piles[key] = {
        locId = locId,
        index = index,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
        claimed = false,
        claiming = nil,
    }

    TriggerClientEvent('mrp_hacking:client:depositBoxDrilled', -1, locId, index, key, Piles[key])
    TriggerClientEvent('QBCore:Notify', src, 'Dėžutė atidaryta — surink pinigų kalną (tik vienas gali paimti).', 'primary', 8000)
end)

RegisterNetEvent('mrp_hacking:server:depositClaimPile', function(locId, index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    locId = tostring(locId or '')
    index = tonumber(index)
    local key = boxKey(locId, index)
    local pile = Piles[key]
    if not pile or pile.claimed then
        return TriggerClientEvent('QBCore:Notify', src, 'Pinigų kalnas jau paimtas.', 'error')
    end
    if pile.claiming and pile.claiming ~= src then
        return TriggerClientEvent('QBCore:Notify', src, 'Kažkas jau renka šį kalną.', 'error')
    end

    --- Distance check
    local ped = GetPlayerPed(src)
    local pc = GetEntityCoords(ped)
    local c = pile.coords
    if #(pc - vector3(c.x, c.y, c.z)) > 3.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo pinigų.', 'error')
    end

    pile.claiming = src
    pile.claimed = true
    Piles[key] = pile

    exports['mrp_hacking']:GiveRobberyLoot(src, 'deposit_box', {
        reason = 'deposit-box',
        prefix = 'Deposit dėžutė: ',
    })

    TriggerClientEvent('mrp_hacking:client:depositPileClaimed', -1, locId, index, key)
end)

--- Pradėti claim (lock kol progressbar)
RegisterNetEvent('mrp_hacking:server:depositStartClaim', function(locId, index)
    local src = source
    locId = tostring(locId or '')
    index = tonumber(index)
    local key = boxKey(locId, index)
    local pile = Piles[key]
    if not pile or pile.claimed then
        return TriggerClientEvent('mrp_hacking:client:depositClaimDenied', src, key, 'Pinigų kalnas jau paimtas.')
    end
    if pile.claiming and pile.claiming ~= src then
        return TriggerClientEvent('mrp_hacking:client:depositClaimDenied', src, key, 'Kažkas jau renka šį kalną.')
    end
    pile.claiming = src
    TriggerClientEvent('mrp_hacking:client:depositClaimAllowed', src, key)
end)

RegisterNetEvent('mrp_hacking:server:depositCancelClaim', function(locId, index)
    local src = source
    local key = boxKey(tostring(locId), tonumber(index))
    local pile = Piles[key]
    if pile and pile.claiming == src and not pile.claimed then
        pile.claiming = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, pile in pairs(Piles) do
        if pile and pile.claiming == src and not pile.claimed then
            pile.claiming = nil
        end
    end
end)

--[[
  Crate open + reward delivery with CSGO-style NUI spin.
]]

local QBCore = exports['qb-core']:GetCoreObject()

--- pending[src] = { crateId, drop, token, expires }
local pending = {}

local function invImageUrl(imageName)
    if not imageName or imageName == '' then return nil end
    return ('nui://qb-inventory/html/images/%s'):format(imageName)
end

local function resolveLabel(entry)
    if entry.label then return entry.label end
    if entry.kind == 'xp' then
        return ('%s XP'):format(entry.amount or 0)
    end
    local shared = entry.item and QBCore.Shared.Items[entry.item]
    return (shared and shared.label) or entry.item or 'Item'
end

local function resolveIconUrl(entry)
    if entry.kind == 'xp' then
        return invImageUrl('deze_exp.png')
    end
    local shared = entry.item and QBCore.Shared.Items[entry.item]
    if shared and shared.image then
        return invImageUrl(shared.image)
    end
    return nil
end

local function serializeEntry(entry)
    return {
        kind = entry.kind or 'item',
        item = entry.item,
        amount = entry.amount or 1,
        rarity = entry.rarity or 'common',
        label = resolveLabel(entry),
        icon = entry.icon or '🎁',
        iconUrl = resolveIconUrl(entry),
    }
end

local function grantDrop(src, Player, drop)
    if not drop then return false, 'empty' end
    if drop.kind == 'xp' then
        local amount = tonumber(drop.amount) or 0
        local meta = Player.PlayerData.metadata or {}
        local cur = tonumber(meta.dashboard_xp) or 0
        Player.Functions.SetMetaData('dashboard_xp', cur + amount)
        -- Hook for RP Pass later
        TriggerEvent('mrp_dashboard:server:grantXp', src, amount)
        return true, ('+%s XP'):format(amount)
    end

    local itemName = drop.item
    if not itemName or not QBCore.Shared.Items[itemName] then
        return false, 'unknown_item'
    end
    local amount = tonumber(drop.amount) or 1
    if itemName == 'cash' then
        Player.Functions.AddMoney('cash', amount, 'crate-open')
        return true, ('$%s'):format(amount)
    end
    local ok = Player.Functions.AddItem(itemName, amount)
    if not ok then return false, 'inventory_full' end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
    return true, resolveLabel(drop)
end

local function startCrateOpen(src, crateId, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local def = MrpCrates.Get(crateId)
    if not def then return end

    if pending[src] then
        TriggerClientEvent('QBCore:Notify', src, 'Jau atidarai dėžę.', 'error')
        return
    end

    if not Player.Functions.RemoveItem(crateId, 1, slot) then
        return
    end
    local sharedCrate = QBCore.Shared.Items[crateId]
    if sharedCrate then
        TriggerClientEvent('inventory:client:ItemBox', src, sharedCrate, 'remove')
    end

    local drop = MrpCrates.Pick(crateId)
    if not drop then
        TriggerClientEvent('QBCore:Notify', src, 'Dėžė tuščia.', 'error')
        return
    end

    local winnerIndex = 40
    local reelRaw = select(1, MrpCrates.BuildReel(crateId, drop, 48, winnerIndex))
    local reel = {}
    for i, e in ipairs(reelRaw) do
        reel[i] = serializeEntry(e)
    end

    local token = ('%s-%s-%s'):format(src, crateId, os.time())
    pending[src] = {
        crateId = crateId,
        drop = drop,
        token = token,
        expires = os.time() + 45,
    }

    TriggerClientEvent('mrp_dashboard:client:openCrateSpin', src, {
        token = token,
        crateId = crateId,
        crateLabel = def.label,
        crateIcon = def.icon,
        crateIconUrl = invImageUrl(def.image),
        accent = def.accent,
        reel = reel,
        winnerIndex = winnerIndex - 1, -- JS 0-based
        winner = serializeEntry(drop),
    })
end

RegisterNetEvent('mrp_dashboard:server:crateSpinDone', function(token)
    local src = source
    local p = pending[src]
    if not p or p.token ~= token then return end
    if os.time() > (p.expires or 0) then
        pending[src] = nil
        return
    end
    pending[src] = nil

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, msg = grantDrop(src, Player, p.drop)
    if ok then
        TriggerClientEvent('QBCore:Notify', src, ('Dėžė: gavai %s'):format(msg), 'success')
    else
        -- Refund crate if grant failed
        Player.Functions.AddItem(p.crateId, 1)
        TriggerClientEvent('QBCore:Notify', src, 'Nepavyko išduoti loot — dėžė grąžinta.', 'error')
    end
end)

-- Safety: if NUI dies, grant after timeout
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, p in pairs(pending) do
            if now > (p.expires or 0) then
                pending[src] = nil
                local Player = QBCore.Functions.GetPlayer(src)
                if Player then
                    grantDrop(src, Player, p.drop)
                end
            end
        end
    end
end)

for crateId in pairs(MrpCrates.Defs) do
    QBCore.Functions.CreateUseableItem(crateId, function(source, item)
        startCrateOpen(source, crateId, item and item.slot)
    end)
end

print(('^2[mrp_dashboard]^7 crates ready (%s types)'):format((function()
    local n = 0
    for _ in pairs(MrpCrates.Defs) do n = n + 1 end
    return n
end)()))

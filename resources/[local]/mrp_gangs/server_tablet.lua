--[[
  mrp_gangs — Gaujos planšetė pririšta prie gaujos (metadata gang_id).
  Svetimos gaujos planšetė = tik peržiūra (nariai, hierarchija, turfai).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local TabletSessions = {} --- [src] = { gangId = number, readOnly = bool }

function GangOrg.setTabletSession(src, gangId, readOnly)
    src = tonumber(src)
    gangId = tonumber(gangId)
    if not src then return end
    if not gangId then
        TabletSessions[src] = nil
        return
    end
    TabletSessions[src] = { gangId = gangId, readOnly = readOnly == true }
end

function GangOrg.clearTabletSession(src)
    src = tonumber(src)
    if src then TabletSessions[src] = nil end
end

function GangOrg.getTabletSession(src)
    return TabletSessions[tonumber(src)]
end

--- true = negalima keisti / valdyti (spy / svetima planšetė)
function GangOrg.isOrgWriteBlocked(src)
    local s = TabletSessions[tonumber(src)]
    return s ~= nil and s.readOnly == true
end

function GangOrg.writeBlockedMsg()
    return 'Tik peržiūra — ši planšetė priklauso kitai gaujai.'
end

AddEventHandler('playerDropped', function()
    GangOrg.clearTabletSession(source)
end)

RegisterNetEvent('mrp_gangs:server:clearTabletSession', function()
    GangOrg.clearTabletSession(source)
end)

local function gangDisplayName(gang)
    if not gang then return 'Gauja' end
    local label = tostring(gang.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if label ~= '' then return label end
    return tostring(gang.name or 'Gauja')
end

local function buildTabletInfo(gang)
    local name = gangDisplayName(gang)
    return {
        gang_id = tonumber(gang.id),
        gang_name = tostring(gang.name or name),
        gang_label = name,
        description = ('Užregistruota: %s'):format(name),
        display = false,
    }
end

--- Atnaujina inventoriaus slotų label į „{Gauja} planšetė“.
local function relabelTabletSlots(Player, gangId, displayName)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return end
    local changed = false
    local want = tonumber(gangId)
    local newLabel = ('%s planšetė'):format(displayName)
    for _, it in pairs(Player.PlayerData.items) do
        if it and it.name == Config.TabletItem and it.info and tonumber(it.info.gang_id) == want then
            if it.label ~= newLabel then
                it.label = newLabel
                changed = true
            end
        end
    end
    if changed then
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    end
end

--- Duoda planšetę, užregistruotą konkrečiai gaujai.
function GangOrg.giveRegisteredTablet(src, gangId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Žaidėjas nerastas.' end
    gangId = tonumber(gangId)
    if not gangId then return false, 'Nėra gaujos.' end
    local gang = MySQL.single.await('SELECT id, name, label FROM fivempro_gangs WHERE id = ? LIMIT 1', { gangId })
    if not gang then return false, 'Gauja nerasta.' end

    local info = buildTabletInfo(gang)
    local tabletRowId = MySQL.insert.await(
        'INSERT INTO fivempro_gang_tablets (gang_id, registered_by) VALUES (?, ?)',
        { gangId, Player.PlayerData.citizenid }
    )
    if tabletRowId then
        info.tablet_id = tonumber(tabletRowId)
    end
    local ok = Player.Functions.AddItem(Config.TabletItem, 1, false, info)
    if not ok then
        if tabletRowId then
            MySQL.update.await('DELETE FROM fivempro_gang_tablets WHERE id = ?', { tabletRowId })
        end
        return false, 'Inventorius pilnas.'
    end

    relabelTabletSlots(Player, gangId, gangDisplayName(gang))
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.TabletItem], 'add', 1)
    return true, gangDisplayName(gang)
end

--- Jei sena planšetė be gang_id — pririša prie žaidėjo gaujos (jei yra).
function GangOrg.ensureTabletBound(src, item)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(item) ~= 'table' then return item end
    local info = item.info
    if type(info) ~= 'table' then info = {} end
    if tonumber(info.gang_id) then
        --- Senesnės planšetės be DB įrašo — užregistruoti vieną kartą
        if not tonumber(info.tablet_id) then
            local tabletRowId = MySQL.insert.await(
                'INSERT INTO fivempro_gang_tablets (gang_id, registered_by) VALUES (?, ?)',
                { tonumber(info.gang_id), Player.PlayerData.citizenid }
            )
            if tabletRowId then
                info.tablet_id = tonumber(tabletRowId)
                item.info = info
                local slot = tonumber(item.slot)
                if slot and Player.PlayerData.items and Player.PlayerData.items[slot] then
                    Player.PlayerData.items[slot].info = info
                    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
                end
            end
        end
        relabelTabletSlots(Player, info.gang_id, info.gang_label or info.gang_name or 'Gauja')
        return item
    end

    local row = MySQL.single.await([[
        SELECT g.id, g.name, g.label
        FROM fivempro_gang_members gm
        JOIN fivempro_gangs g ON g.id = gm.gang_id
        WHERE gm.citizenid = ?
        LIMIT 1
    ]], { Player.PlayerData.citizenid })
    if not row then return item end

    info = buildTabletInfo(row)
    local tabletRowId = MySQL.insert.await(
        'INSERT INTO fivempro_gang_tablets (gang_id, registered_by) VALUES (?, ?)',
        { tonumber(row.id), Player.PlayerData.citizenid }
    )
    if tabletRowId then info.tablet_id = tonumber(tabletRowId) end
    item.info = info
    local slot = tonumber(item.slot)
    if slot and Player.PlayerData.items and Player.PlayerData.items[slot] then
        Player.PlayerData.items[slot].info = info
        Player.PlayerData.items[slot].label = ('%s planšetė'):format(gangDisplayName(row))
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    else
        relabelTabletSlots(Player, row.id, gangDisplayName(row))
    end
    return item
end

exports('GiveRegisteredTablet', function(src, gangId)
    return GangOrg.giveRegisteredTablet(src, gangId)
end)

exports('IsGangTabletWriteBlocked', function(src)
    return GangOrg.isOrgWriteBlocked(src)
end)

local QBCore = exports['qb-core']:GetCoreObject()

local function osLevel(osId)
    local o = Config.OperatingSystems[osId]
    return o and o.level or 0
end

local function tabletCfg(itemName)
    return Config.Tablets[itemName]
end

local function getTabletItem(Player)
    for name in pairs(Config.Tablets) do
        local it = Player.Functions.GetItemByName(name)
        if it then return it, name end
    end
    return nil, nil
end

local function metaInfo(item)
    if not item then return {} end
    local info = item.info or item.metadata or {}
    if type(info) ~= 'table' then info = {} end
    if not info.exploits or type(info.exploits) ~= 'table' then info.exploits = {} end
    return info
end

local function saveTabletMeta(src, item, info)
    if not item or not item.slot then return end
    if GetResourceState('qb-inventory') == 'started' then
        exports['qb-inventory']:SetItemData(src, item.name, 'info', info, item.slot)
    end
end

local function hasExploit(info, exploitId)
    for _, e in ipairs(info.exploits or {}) do
        if e == exploitId then return true end
    end
    return false
end

local function canAccessRobbery(src, tierId)
    local tier = Config.RobberyTiers[tierId]
    if not tier then return false, 'Nežinomas robbery tipas.' end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Žaidėjas nerastas.' end
    local item, tName = getTabletItem(Player)
    if not item then return false, 'Reikia hacking tablet.' end
    local tCfg = tabletCfg(tName)
    if not tCfg then return false, 'Netinkamas tablet.' end
    local info = metaInfo(item)
    if not info.installed_os then return false, 'Įdiek OS per flashdrive (tablet meniu).' end
    if osLevel(info.installed_os) < osLevel(tier.minOs) then
        return false, ('Reikia OS: %s'):format(Config.OperatingSystems[tier.minOs].label)
    end
  local minTab = tier.minTablet
    local tabOrder = { basic_tablet = 1, advanced_tablet = 2, military_tablet = 3 }
    if (tabOrder[tName] or 0) < (tabOrder[minTab] or 99) then
        return false, ('Reikia tablet: %s'):format(Config.Tablets[minTab].label)
    end
    local osDef = Config.OperatingSystems[info.installed_os]
    local allowed = false
    for _, r in ipairs(osDef.robberies or {}) do
        if r == tierId then allowed = true break end
    end
    if not allowed then return false, 'OS nepalaiko šio robbery lygio.' end
    return true, nil, {
        tablet = tName,
        os = info.installed_os,
        exploits = info.exploits,
        hackSpeed = (tCfg.hackSpeed or 1) * (osDef.hackSpeed or 1),
    }
end

local function buildHackProfile(tierId, ctx)
    local tier = Config.RobberyTiers[tierId]
    local base = Config.HackProfiles[tier.hackProfile] or { steps = 5, timeMs = 12000, grid = 4 }
    local profile = {
        steps = base.steps,
        timeMs = base.timeMs,
        grid = base.grid,
        profileId = tier.hackProfile,
    }
    if ctx and ctx.exploits then
        for _, exId in ipairs(ctx.exploits) do
            local ex = Config.Exploits[exId]
            if ex and ex.hackBonus then
                profile.timeMs = profile.timeMs + (ex.hackBonus.timeMs or 0)
                profile.steps = math.max(3, profile.steps + (ex.hackBonus.steps or 0))
            end
        end
    end
    if ctx and ctx.hackSpeed then
        profile.timeMs = math.floor(profile.timeMs * (1.0 / math.max(0.5, ctx.hackSpeed)))
    end
    return profile
end

local function policeAlert(coords, callType, text, delaySec)
    CreateThread(function()
        if delaySec and delaySec > 0 then Wait(delaySec * 1000) end
        if GetResourceState('fivempro_dispatch') == 'started' then
            exports['fivempro_dispatch']:CreateDispatchCall('police', callType or 'robbery', coords, text or 'Apiplėšimas', nil)
        end
    end)
end

local function applyCctvTamper(src, coords, ctx)
    if not ctx or not ctx.exploits then return end
    if not hasExploit(ctx, 'cam_spoof') then return end
    if GetResourceState('fivempro_ltpd') ~= 'started' then return end
    local ex = Config.Exploits.cam_spoof
    exports['fivempro_ltpd']:TamperCctvRadius(coords, ex.cctvRadius or 30, ex.cctvSeconds or 120)
end

QBCore.Functions.CreateCallback('fivempro_hacking:server:getTabletData', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end
    local item, tName = getTabletItem(Player)
    if not item then return cb({ ok = false, msg = 'Neturi tablet.' }) end
    local info = metaInfo(item)
    local tCfg = tabletCfg(tName)
    cb({
        ok = true,
        tablet = tName,
        tabletLabel = tCfg.label,
        installed_os = info.installed_os,
        exploits = info.exploits,
        storage = tCfg.storage,
        exploitSlots = tCfg.exploitSlots,
        osCatalog = Config.OperatingSystems,
        exploitCatalog = Config.Exploits,
        robberyTiers = Config.RobberyTiers,
        robberyFlows = Config.Robberies and Config.Robberies.Flow or {},
        robberyLocCounts = (function()
            local out = {}
            if Config.Robberies and Config.Robberies.Locations then
                for tierId, list in pairs(Config.Robberies.Locations) do
                    out[tierId] = #list
                end
            end
            return out
        end)(),
    })
end)

QBCore.Functions.CreateCallback('fivempro_hacking:server:installFromDrive', function(src, cb, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local item, tName = getTabletItem(Player)
    if not item then return cb({ ok = false, msg = 'Reikia tablet.' }) end
    local drive = Player.Functions.GetItemBySlot(tonumber(slot))
    if not drive or not Config.Flashdrives[drive.name] then
        return cb({ ok = false, msg = 'Flashdrive nerastas.' })
    end
    local dInfo = metaInfo(drive)
    if not dInfo.payload_type or not dInfo.payload_id then
        return cb({ ok = false, msg = 'Flashdrive tuščias arba neparuoštas.' })
    end
    local tCfg = tabletCfg(tName)
    local tabInfo = metaInfo(item)
    local used = (tabInfo.installed_os and 1 or 0) + #(tabInfo.exploits or {})
    if used >= (tCfg.storage or 4) then
        return cb({ ok = false, msg = 'Tablet storage pilnas.' })
    end
    if dInfo.payload_type == 'os' then
        if not Config.OperatingSystems[dInfo.payload_id] then
            return cb({ ok = false, msg = 'Nežinoma OS.' })
        end
        tabInfo.installed_os = dInfo.payload_id
    elseif dInfo.payload_type == 'exploit' then
        if not Config.Exploits[dInfo.payload_id] then
            return cb({ ok = false, msg = 'Nežinomas exploit.' })
        end
        if #tabInfo.exploits >= (tCfg.exploitSlots or 1) then
            return cb({ ok = false, msg = 'Exploit slotai pilni.' })
        end
        if hasExploit(tabInfo, dInfo.payload_id) then
            return cb({ ok = false, msg = 'Exploit jau įdiegtas.' })
        end
        tabInfo.exploits[#tabInfo.exploits + 1] = dInfo.payload_id
    else
        return cb({ ok = false, msg = 'Netinkamas payload.' })
    end
    saveTabletMeta(src, item, tabInfo)
    Player.Functions.RemoveItem(drive.name, 1, drive.slot)
    cb({ ok = true, installed_os = tabInfo.installed_os, exploits = tabInfo.exploits })
end)

QBCore.Functions.CreateCallback('fivempro_hacking:server:prepareHack', function(src, cb, tierId)
    local ok, reason, ctx = canAccessRobbery(src, tierId)
    if not ok then return cb({ ok = false, msg = reason }) end
    local profile = buildHackProfile(tierId, ctx)
    cb({ ok = true, profile = profile, ctx = ctx })
end)

RegisterNetEvent('fivempro_hacking:server:hackFinished', function(tierId, success, coords)
    local src = source
    local ok, reason, ctx = canAccessRobbery(src, tierId)
    if not ok then return end
    local c = type(coords) == 'table' and vector3(coords.x or 0, coords.y or 0, coords.z or 0) or GetEntityCoords(GetPlayerPed(src))
    local alertText = {
        atm = 'Bankomato / ATM įtartina veikla',
        store = '24/7 kasos įsilaužimas',
        bank_fleeca = 'Fleeca banko signalizacija',
        bank_main = 'Pacific banko signalizacija',
        casino = 'Kazino serverio įsilaužimas',
        vault = 'Federal vault signalizacija',
    }
    if success then
        local delay = 0
        if ctx and hasExploit(ctx, 'signal_jammer') then
            delay = (Config.Exploits.signal_jammer.delayDispatchSec or 60)
        end
        applyCctvTamper(src, c, ctx)
        if tierId == 'atm' then
            if GetResourceState('fivempro_gangs') == 'started' then
                pcall(function()
                    exports['fivempro_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
                end)
            end
            TriggerClientEvent('fivempro_hacking:client:hackSuccess', src, tierId, c, ctx)
        end
    else
        policeAlert(c, tierId == 'atm' and 'atm' or 'robbery', alertText[tierId] or 'Apiplėšimas', 0)
        if GetResourceState('fivempro_ltpd') == 'started' then
            exports['fivempro_ltpd']:TamperCctvRadius(c, 25.0, 30)
        end
        if tierId == 'atm' then
            if GetResourceState('fivempro_gangs') == 'started' then
                pcall(function()
                    exports['fivempro_gangs']:OnHackFailed(src, tierId, { x = c.x, y = c.y, z = c.z })
                end)
            end
            TriggerClientEvent('fivempro_hacking:client:hackFailed', src, tierId)
        end
    end
end)

for name in pairs(Config.Tablets) do
    QBCore.Functions.CreateUseableItem(name, function(source)
        TriggerClientEvent('fivempro_hacking:client:openTablet', source)
    end)
end

for name in pairs(Config.Flashdrives) do
    QBCore.Functions.CreateUseableItem(name, function(source)
        TriggerClientEvent('fivempro_hacking:client:openTablet', source, { flashTab = true })
    end)
end

RegisterNetEvent('fivempro_hacking:server:buyBlackMarket', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local entry = Config.BlackMarket.items[tonumber(index)]
    if not entry then return end
    local price = tonumber(entry.price) or 0
    if Player.PlayerData.money.cash < price then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepakanka grynais.', 'error')
    end
    local info = nil
    if entry.payload then
        info = {
            payload_type = entry.payload.payload_type,
            payload_id = entry.payload.payload_id,
        }
    end
    if not Player.Functions.RemoveMoney('cash', price, 'blackmarket-hack') then return end
    Player.Functions.AddItem(entry.item, 1, false, info)
    TriggerClientEvent('QBCore:Notify', src, 'Nupirkta.', 'success')
end)

exports('CanAccessRobbery', function(src, tierId)
    return canAccessRobbery(src, tierId)
end)

exports('PoliceAlert', policeAlert)

exports('BuildHackProfile', function(src, tierId)
    local ok, _, ctx = canAccessRobbery(src, tierId)
    if not ok then return nil end
    return buildHackProfile(tierId, ctx)
end)

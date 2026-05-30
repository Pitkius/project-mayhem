local QBCore = exports['qb-core']:GetCoreObject()

local function osLevel(osId)
    local o = Config.OperatingSystems[osId]
    return o and o.level or 0
end

local function tabletCfg(itemName)
    return Config.Tablets[itemName]
end

local function getTabletItem(Player, tierId)
    local tabOrder = { basic_tablet = 1, advanced_tablet = 2, military_tablet = 3 }
    local minRank = 0
    if tierId and Config.RobberyTiers[tierId] then
        minRank = tabOrder[Config.RobberyTiers[tierId].minTablet] or 0
    end
    local candidates = {}
    for name in pairs(Config.Tablets) do
        local it = Player.Functions.GetItemByName(name)
        if it then
            local rank = tabOrder[name] or 0
            if rank >= minRank then
                candidates[#candidates + 1] = {
                    item = it,
                    name = name,
                    rank = rank,
                    hasOs = metaInfo(it).installed_os and true or false,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.hasOs ~= b.hasOs then return a.hasOs end
        return a.rank > b.rank
    end)
    if candidates[1] then
        return candidates[1].item, candidates[1].name
    end
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

local function payloadLabel(payloadType, payloadId)
    if not payloadType or not payloadId then return nil end
    if payloadType == 'os' then
        local o = Config.OperatingSystems[payloadId]
        return o and o.label or payloadId
    end
    if payloadType == 'exploit' then
        local e = Config.Exploits[payloadId]
        return e and e.label or payloadId
    end
    return payloadId
end

local function buildFlashInfo(payload)
    if not payload or not payload.payload_type or not payload.payload_id then return nil end
    local label = payloadLabel(payload.payload_type, payload.payload_id)
    return {
        payload_type = payload.payload_type,
        payload_id = payload.payload_id,
        payload_label = label,
    }
end

local function listFlashDrives(Player)
    local drives = {}
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and Config.Flashdrives[item.name] then
            local info = metaInfo(item)
            local ready = info.payload_type and info.payload_id
            drives[#drives + 1] = {
                slot = item.slot,
                name = item.name,
                itemLabel = Config.Flashdrives[item.name].label or item.label,
                payload_type = info.payload_type,
                payload_id = info.payload_id,
                payloadLabel = info.payload_label or payloadLabel(info.payload_type, info.payload_id),
                ready = ready and true or false,
            }
        end
    end
    table.sort(drives, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)
    return drives
end

local function canAccessRobbery(src, tierId)
    local tier = Config.RobberyTiers[tierId]
    if not tier then return false, 'Nežinomas robbery tipas.' end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Žaidėjas nerastas.' end
    local item, tName = getTabletItem(Player, tierId)
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
        return false, ('Reikia %s (turi %s). Įdiek CipherOS į tinkamą tablet.'):format(
            Config.Tablets[minTab].label,
            Config.Tablets[tName].label
        )
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

local function buildHackProfile(tierId, ctx, locId)
    local tier = Config.RobberyTiers[tierId]
    local profileKey = tier.hackProfile
    if locId and Config.Robberies and Config.Robberies.Locations and Config.Robberies.Locations[tierId] then
        for _, loc in ipairs(Config.Robberies.Locations[tierId]) do
            if loc.id == locId and loc.hackProfile then
                profileKey = loc.hackProfile
                break
            end
        end
    end
    local base = Config.HackProfiles[profileKey] or { steps = 5, timeMs = 12000, grid = 4 }
    local profile = {
        mode = base.mode or 'sequence',
        steps = base.steps,
        timeMs = base.timeMs,
        grid = base.grid,
        flashMs = base.flashMs or 380,
        profileId = profileKey,
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
    local item, tName = getTabletItem(Player, tierId)
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
        flashDrives = listFlashDrives(Player),
    })
end)

QBCore.Functions.CreateCallback('fivempro_hacking:server:installFromDrive', function(src, cb, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end
    local item, tName = getTabletItem(Player, tierId)
    if not item then return cb({ ok = false, msg = 'Reikia tablet.' }) end
    local drive = Player.Functions.GetItemBySlot(tonumber(slot))
    if not drive or not Config.Flashdrives[drive.name] then
        return cb({ ok = false, msg = 'Flashdrive nerastas.' })
    end
    local dInfo = metaInfo(drive)
    if not dInfo.payload_type or not dInfo.payload_id then
        return cb({
            ok = false,
            msg = 'Flashdrive tuščias — nusipirk su OS/exploit (meniu „Flashdrive OS / exploit“, ne tuščią iš shop).',
        })
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
    cb({
        ok = true,
        installed_os = tabInfo.installed_os,
        exploits = tabInfo.exploits,
        flashDrives = listFlashDrives(Player),
    })
end)

QBCore.Functions.CreateCallback('fivempro_hacking:server:prepareHack', function(src, cb, tierId, locId)
    local ok, reason, ctx = canAccessRobbery(src, tierId)
    if not ok then return cb({ ok = false, msg = reason }) end
    local profile = buildHackProfile(tierId, ctx, locId)
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
            policeAlert(c, 'atm', alertText.atm, delay)
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
    QBCore.Functions.CreateUseableItem(name, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if not getTabletItem(Player) then
            return TriggerClientEvent('QBCore:Notify', source, 'Reikia hacking planšetės inventoriuje.', 'error')
        end
        TriggerClientEvent('fivempro_hacking:client:openTablet', source, {
            flashTab = true,
            driveSlot = item and item.slot,
        })
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
    local info = buildFlashInfo(entry.payload)
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

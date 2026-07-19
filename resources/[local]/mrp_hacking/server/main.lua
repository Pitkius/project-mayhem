local QBCore = exports['qb-core']:GetCoreObject()

local function osLevel(osId)
    local o = Config.OperatingSystems[osId]
    return o and o.level or 0
end

local function tabletCfg(itemName)
    return Config.Tablets[itemName]
end

local function metaInfo(item)
    if not item then return {} end
    local info = item.info or item.metadata or {}
    if type(info) ~= 'table' then info = {} end
    if not info.exploits or type(info.exploits) ~= 'table' then info.exploits = {} end
    return info
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
        if GetResourceState('mrp_dispatch') == 'started' then
            exports['mrp_dispatch']:CreateDispatchCall('police', callType or 'robbery', coords, text or 'Apiplėšimas', nil)
        end
    end)
end

local function applyCctvTamper(src, coords, ctx)
    if not ctx or not ctx.exploits then return end
    if not hasExploit(ctx, 'cam_spoof') then return end
    if GetResourceState('mrp_ltpd') ~= 'started' then return end
    local ex = Config.Exploits.cam_spoof
    exports['mrp_ltpd']:TamperCctvRadius(coords, ex.cctvRadius or 30, ex.cctvSeconds or 120)
end

local function locDiscoveryKey(tierId, locId)
    return ('%s:%s'):format(tostring(tierId), tostring(locId))
end

local function discoveryRequired(tierId)
    return Config.RobberyDiscoveryTiers and Config.RobberyDiscoveryTiers[tierId] == true
end

local function getDiscoveredLocs(Player)
    local meta = Player.PlayerData.metadata or {}
    local raw = meta.hack_discovered_locs
    if type(raw) ~= 'table' then return {} end
    return raw
end

local function isRobberyLocDiscovered(Player, tierId, locId)
    if not discoveryRequired(tierId) then return true end
    local key = locDiscoveryKey(tierId, locId)
    local discovered = getDiscoveredLocs(Player)
    return discovered[key] == true
end

local function setRobberyLocDiscovered(Player, tierId, locId)
    local key = locDiscoveryKey(tierId, locId)
    local discovered = getDiscoveredLocs(Player)
    if discovered[key] then return false end
    discovered[key] = true
    Player.Functions.SetMetaData('hack_discovered_locs', discovered)
    return true
end

local function playerNearRobberyLoc(src, loc)
    if not loc or not loc.coords then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pcoords = GetEntityCoords(ped)
    local radius = tonumber(loc.discoverRadius) or tonumber(Config.RobberyDiscoverRadius) or 20.0
    return #(pcoords - loc.coords) <= radius
end

local function findNearbyRobberyLoc(src, tierId)
    local list = Config.Robberies and Config.Robberies.Locations and Config.Robberies.Locations[tierId]
    if not list then return nil end
    for _, loc in ipairs(list) do
        if playerNearRobberyLoc(src, loc) then
            return loc
        end
    end
end

local function buildRobberyMapSites(discovered)
    local sites = {}
    local tiers = Config.RobberyTiers or {}
    local locations = Config.Robberies and Config.Robberies.Locations or {}

    for tierId, list in pairs(locations) do
        if tierId ~= 'atm' then
            local tierCfg = tiers[tierId] or {}
            local level = tonumber(tierCfg.level) or 1
            for _, loc in ipairs(list) do
                if discoveryRequired(tierId) and not (discovered and discovered[locDiscoveryKey(tierId, loc.id)]) then
                    goto continue_site
                end
                local c = loc.coords
                if c then
                    sites[#sites + 1] = {
                        id = loc.id,
                        tierId = tierId,
                        label = loc.label or loc.id,
                        level = level,
                        x = c.x,
                        y = c.y,
                        z = c.z,
                    }
                end
                ::continue_site::
            end
        end
    end

    table.sort(sites, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return tostring(a.label) < tostring(b.label)
    end)

    return sites
end

QBCore.Functions.CreateCallback('mrp_hacking:server:getTabletData', function(src, cb)
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
        networkTargets = Config.NetworkTargets or {},
        targetMeta = Config.TabletTargetMeta or {},
        tabletFiles = Config.TabletFiles or {},
        tabletContracts = Config.TabletContracts or {},
        marketItems = Config.BlackMarket and Config.BlackMarket.items or {},
        marketCurrency = (Config.BlackMarket and Config.BlackMarket.currency) or 'cash',
        marketCurrencyLabel = (Config.BlackMarket and Config.BlackMarket.label) or 'Lesteris',
        playerMoney = {
            cash = Player.PlayerData.money.cash or 0,
            bank = Player.PlayerData.money.bank or 0,
            crypto = Player.PlayerData.money.crypto or 0,
        },
        cryptoExchange = Config.CryptoExchange or {},
        robberyMapSites = buildRobberyMapSites(getDiscoveredLocs(Player)),
        discoveredRobberyLocs = getDiscoveredLocs(Player),
        atmMapNote = 'Galima apiplėšti bet kurį bankomatą mieste (LVL 1).',
    })
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:getDiscoveredRobberyLocs', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({}) end
    cb(getDiscoveredLocs(Player))
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:discoverNearbyRobbery', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false }) end

    for tierId, required in pairs(Config.RobberyDiscoveryTiers or {}) do
        if required then
            local loc = findNearbyRobberyLoc(src, tierId)
            if loc and not isRobberyLocDiscovered(Player, tierId, loc.id) then
                setRobberyLocDiscovered(Player, tierId, loc.id)
                local discovered = getDiscoveredLocs(Player)
                TriggerClientEvent('mrp_hacking:client:discoveredLocsUpdated', src, discovered, tierId, loc.id, loc.label)
                return cb({
                    ok = true,
                    new = true,
                    tierId = tierId,
                    locId = loc.id,
                    label = loc.label or loc.id,
                    discovered = discovered,
                    robberyMapSites = buildRobberyMapSites(discovered),
                })
            end
        end
    end

    cb({ ok = true, new = false, discovered = getDiscoveredLocs(Player) })
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:installFromDrive', function(src, cb, slot)
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

QBCore.Functions.CreateCallback('mrp_hacking:server:prepareHack', function(src, cb, tierId, locId)
    local ok, reason, ctx = canAccessRobbery(src, tierId)
    if not ok then return cb({ ok = false, msg = reason }) end
    local profile = buildHackProfile(tierId, ctx, locId)
    cb({ ok = true, profile = profile, ctx = ctx })
end)

RegisterNetEvent('mrp_hacking:server:hackFinished', function(tierId, success, coords)
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
            if GetResourceState('mrp_gangs') == 'started' then
                pcall(function()
                    exports['mrp_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
                end)
            end
            TriggerClientEvent('mrp_hacking:client:hackSuccess', src, tierId, c, ctx)
        end
    else
        policeAlert(c, tierId == 'atm' and 'atm' or 'robbery', alertText[tierId] or 'Apiplėšimas', 0)
        if GetResourceState('mrp_ltpd') == 'started' then
            exports['mrp_ltpd']:TamperCctvRadius(c, 25.0, 30)
        end
        if tierId == 'atm' then
            if GetResourceState('mrp_gangs') == 'started' then
                pcall(function()
                    exports['mrp_gangs']:OnHackFailed(src, tierId, { x = c.x, y = c.y, z = c.z })
                end)
            end
            TriggerClientEvent('mrp_hacking:client:hackFailed', src, tierId)
        end
    end
end)

for name in pairs(Config.Tablets) do
    QBCore.Functions.CreateUseableItem(name, function(source)
        TriggerClientEvent('mrp_hacking:client:openTablet', source)
    end)
end

for name in pairs(Config.Flashdrives) do
    QBCore.Functions.CreateUseableItem(name, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if not getTabletItem(Player) then
            return TriggerClientEvent('QBCore:Notify', source, 'Reikia hacking planšetės inventoriuje.', 'error')
        end
        TriggerClientEvent('mrp_hacking:client:openTablet', source, {
            flashTab = true,
            driveSlot = item and item.slot,
        })
    end)
end

RegisterNetEvent('mrp_hacking:server:buyBlackMarket', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local entry = Config.BlackMarket.items[tonumber(index)]
    if not entry then return end
    local price = tonumber(entry.price) or 0
    local currency = (Config.BlackMarket and Config.BlackMarket.currency) or 'cash'
    local balance = Player.PlayerData.money[currency] or 0
    if balance < price then
        local hint = currency == 'crypto'
            and 'Nepakanka crypto.'
            or 'Nepakanka grynųjų.'
        return TriggerClientEvent('QBCore:Notify', src, hint, 'error')
    end
    local info = buildFlashInfo(entry.payload)
    if not Player.Functions.RemoveMoney(currency, price, 'lester-hack-shop') then return end
    Player.Functions.AddItem(entry.item, 1, false, info)
    local paid = currency == 'crypto' and (('%s crypto'):format(price)) or (('$%s'):format(price))
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta už %s.'):format(paid), 'success')
end)

RegisterNetEvent('mrp_hacking:server:exchangeBankToCrypto', function(amount)
    local src = source
    local cfg = Config.CryptoExchange or {}
    if cfg.enabled == false then
        return TriggerClientEvent('QBCore:Notify', src, 'Crypto keitykla šiuo metu neprieinama.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)
    local minAmount = tonumber(cfg.minAmount) or 500
    local maxAmount = tonumber(cfg.maxAmount) or 500000

    if amount < minAmount then
        return TriggerClientEvent('QBCore:Notify', src, ('Minimali suma: $%s'):format(minAmount), 'error')
    end
    if amount > maxAmount then
        return TriggerClientEvent('QBCore:Notify', src, ('Maksimali suma: $%s'):format(maxAmount), 'error')
    end

    local bank = Player.PlayerData.money.bank or 0
    if bank < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepakanka švarių pinigų banke.', 'error')
    end

    local fee = math.floor(amount * (tonumber(cfg.feePercent) or 5) / 100)
    local rate = tonumber(cfg.bankToCryptoRate) or 1.0
    local receive = math.floor((amount - fee) * rate)
    if receive <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Suma per maža po mokesčio.', 'error')
    end

    if not Player.Functions.RemoveMoney('bank', amount, 'bank-to-crypto') then return end
    Player.Functions.AddMoney('crypto', receive, 'bank-to-crypto')

    local label = cfg.currencyLabel or 'Crypto'
    TriggerClientEvent('QBCore:Notify', src,
        ('$%s → %s %s (mokestis $%s)'):format(amount, receive, label, fee), 'success')
end)

exports('IsRobberyLocDiscovered', function(src, tierId, locId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return isRobberyLocDiscovered(Player, tierId, locId)
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

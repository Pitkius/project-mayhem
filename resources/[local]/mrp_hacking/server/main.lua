local QBCore = exports['qb-core']:GetCoreObject()

local SilentHack = {} --- [src] = true — sėkmingas stealth hack (be PD iki soft pabaigos)

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

local function playerBestTablet(Player)
    local bestLvl, bestItem, bestName = 0, nil, nil
    for name in pairs(Config.Tablets or {}) do
        local it = Player.Functions.GetItemByName(name)
        if it then
            local lvl = Config.GetTabletLevel and Config.GetTabletLevel(name) or 0
            if lvl > bestLvl then
                bestLvl, bestItem, bestName = lvl, it, name
            end
        end
    end
    return bestLvl, bestItem, bestName
end

local function getTabletItem(Player, _tierId)
    local _, item, name = playerBestTablet(Player)
    return item, name
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

--- mode: 'soft' (be planšetės) | 'stealth'/'full' (reikia planšetės lygio)
local function canAccessRobbery(src, tierId, mode)
    mode = mode or 'full'
    local tier = Config.RobberyTiers[tierId]
    if not tier then return false, 'Nežinomas robbery tipas.' end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Žaidėjas nerastas.' end

    local need = 0
    if mode == 'soft' then
        need = tonumber(tier.minTabletLevel) or 0
    elseif mode == 'stealth' then
        need = tonumber(tier.stealthTabletLevel) or tonumber(tier.minTabletLevel) or 1
    else
        need = tonumber(tier.minTabletLevel) or 0
        --- full vault Fleeca / L3 — reikia stealth lygio
        if tierId == 'bank_fleeca' or tierId == 'bank_main' or tierId == 'casino' then
            need = tonumber(tier.stealthTabletLevel) or need
        end
    end

    if need <= 0 then
        return true, nil, { tabletLevel = 0, silent = false, hackSpeed = 1.0, exploits = {} }
    end

    local lvl, item, tName = playerBestTablet(Player)
    if lvl < need then
        return false, ('Reikia L%d įsilaužimo planšetės.'):format(need)
    end
    local tCfg = tabletCfg(tName) or {}
    local info = metaInfo(item)
    return true, nil, {
        tablet = tName,
        tabletLevel = lvl,
        silent = mode ~= 'soft',
        exploits = info.exploits or {},
        hackSpeed = tCfg.hackSpeed or 1.0,
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
    local base = Config.HackProfiles[profileKey] or { mode = 'sequence', steps = 5, timeMs = 12000, grid = 4 }
    local profile = {
        mode = base.mode or 'sequence',
        steps = base.steps or 5,
        timeMs = base.timeMs or 12000,
        grid = base.grid or 4,
        flashMs = base.flashMs or 380,
        difficulty = base.difficulty or 3.0,
        profileId = profileKey,
        traceSpeed = base.traceSpeed,
        traceWidth = base.traceWidth,
    }
    if ctx and ctx.exploits then
        for _, exId in ipairs(ctx.exploits) do
            local ex = Config.Exploits[exId]
            if ex and ex.hackBonus then
                profile.timeMs = (profile.timeMs or 12000) + (ex.hackBonus.timeMs or 0)
                profile.steps = math.max(3, (profile.steps or 5) + (ex.hackBonus.steps or 0))
                if ex.hackBonus.difficulty then
                    profile.difficulty = math.max(2.0, (profile.difficulty or 3.0) + ex.hackBonus.difficulty)
                end
            end
        end
    end
    if ctx and ctx.hackSpeed then
        local speed = math.max(0.5, tonumber(ctx.hackSpeed) or 1.0)
        profile.timeMs = math.floor((profile.timeMs or 12000) * (1.0 / speed))
        --- Greitesnė planšetė = lengvesnis native datacrack
        if profile.mode == 'native_datacrack' or profile.mode == 'gtao_datacrack' or profile.mode == 'datacrack' then
            profile.difficulty = math.max(2.0, (profile.difficulty or 3.0) / speed)
        end
    end
    return profile
end

local function policeAlert(coords, callType, text, delaySec)
    CreateThread(function()
        if delaySec and delaySec > 0 then Wait(delaySec * 1000) end
        MRP_DispatchAlert('police', callType or 'robbery', coords, text or 'Apiplėšimas', nil)
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
        tabletLabel = tCfg and tCfg.label or tName,
        tabletLevel = (tCfg and tCfg.level) or (Config.GetTabletLevel and Config.GetTabletLevel(tName)) or 1,
        installed_os = nil,
        exploits = info.exploits or {},
        storage = 0,
        exploitSlots = 0,
        osCatalog = {},
        exploitCatalog = {},
        robberyTiers = Config.RobberyTiers,
        robberyFlows = Config.Robberies and Config.Robberies.Flow or {},
        robberyLocCounts = (function()
            local out = {}
            if Config.Robberies and Config.Robberies.Locations then
                for tid, list in pairs(Config.Robberies.Locations) do
                    out[tid] = #list
                end
            end
            return out
        end)(),
        flashDrives = listFlashDrives(Player),
        networkTargets = Config.NetworkTargets or {},
        targetMeta = Config.TabletTargetMeta or {},
        tabletFiles = Config.TabletFiles or {},
        tabletContracts = Config.TabletContracts or {},
        marketItems = (function()
            local out = {}
            for _, e in ipairs((Config.BlackMarket and Config.BlackMarket.items) or {}) do
                local it = QBCore.Shared.Items[e.item]
                out[#out + 1] = {
                    item = e.item,
                    label = (it and it.label) or e.item,
                    price = e.price,
                    desc = e.desc,
                }
            end
            return out
        end)(),
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
        atmMapNote = 'L1: bankomatai / parduotuvės. Soft be planšetės (PD alert); hack = stealth.',
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

QBCore.Functions.CreateCallback('mrp_hacking:server:installFromDrive', function(src, cb)
    cb({ ok = false, msg = 'OS sistema išjungta — planšetės lygis (L1/L2/L3) pakanka apiplėšimams.' })
end)

QBCore.Functions.CreateCallback('mrp_hacking:server:prepareHack', function(src, cb, tierId, locId)
    --- Hack visada reikalauja stealth lygio planšetės
    local ok, reason, ctx = canAccessRobbery(src, tierId, 'stealth')
    if not ok then return cb({ ok = false, msg = reason }) end
    local profile = buildHackProfile(tierId, ctx, locId)
    cb({ ok = true, profile = profile, ctx = ctx })
end)

RegisterNetEvent('mrp_hacking:server:hackFinished', function(tierId, success, coords)
    local src = source
    local ok, _, ctx = canAccessRobbery(src, tierId, 'stealth')
    if not ok then return end
    local c = type(coords) == 'table' and vector3(coords.x or 0, coords.y or 0, coords.z or 0) or GetEntityCoords(GetPlayerPed(src))
    local failText = {
        atm = 'Kažkas bando įsilaužti į bankomatą',
        store = 'Kažkas bando įsilaužti į parduotuvės kasą',
        bank_fleeca = 'Kažkas bando įsilaužti į Fleeca banką',
        bank_main = 'Kažkas bando įsilaužti į Pacific banką',
        casino = 'Kažkas bando įsilaužti į kazino tinklą',
    }
    if success then
        --- Sėkmingas hack = stealth (PD NEGAUNA pranešimo)
        SilentHack[src] = true
        applyCctvTamper(src, c, ctx)
        if GetResourceState('mrp_gangs') == 'started' then
            pcall(function()
                exports['mrp_gangs']:OnHackSuccess(src, tierId, { x = c.x, y = c.y, z = c.z })
            end)
        end
        TriggerClientEvent('mrp_hacking:client:hackSuccess', src, tierId, c, ctx)
    else
        SilentHack[src] = nil
        policeAlert(c, tierId == 'atm' and 'atm' or 'robbery', failText[tierId] or 'Bandymas įsilaužti', 0)
        if GetResourceState('mrp_gangs') == 'started' then
            pcall(function()
                exports['mrp_gangs']:OnHackFailed(src, tierId, { x = c.x, y = c.y, z = c.z })
            end)
        end
        TriggerClientEvent('mrp_hacking:client:hackFailed', src, tierId)
    end
end)

exports('IsSilentHack', function(src)
    return SilentHack[tonumber(src)] == true
end)

exports('ClearSilentHack', function(src)
    SilentHack[tonumber(src)] = nil
end)

exports('SetSilentHack', function(src, value)
    SilentHack[tonumber(src)] = value and true or nil
end)

AddEventHandler('playerDropped', function()
    SilentHack[source] = nil
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
    if not QBCore.Shared.Items[entry.item] then
        return TriggerClientEvent('QBCore:Notify', src, 'Itemas neegzistuoja.', 'error')
    end
    local price = tonumber(entry.price) or 0
    local currency = (Config.BlackMarket and Config.BlackMarket.currency) or 'cash'
    local balance = Player.PlayerData.money[currency] or 0
    if balance < price then
        local hint = currency == 'crypto'
            and 'Nepakanka crypto.'
            or 'Nepakanka grynųjų.'
        return TriggerClientEvent('QBCore:Notify', src, hint, 'error')
    end
    if not Player.Functions.RemoveMoney(currency, price, 'lester-hack-shop') then return end
    Player.Functions.AddItem(entry.item, 1, false, nil)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[entry.item], 'add', 1)
    local paid = currency == 'crypto' and (('%s crypto'):format(price)) or (('$%s'):format(price))
    TriggerClientEvent('QBCore:Notify', src, ('Nupirkta: %s už %s.'):format(
        QBCore.Shared.Items[entry.item].label or entry.item, paid), 'success')
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

exports('CanAccessRobbery', function(src, tierId, mode)
    return canAccessRobbery(src, tierId, mode)
end)

exports('PoliceAlert', policeAlert)

--- Robbery loot: dirty (markedbills 1=$1) = inventoriaus suma; cash = HUD piniginė.
--- Notify visada rodo tą pačią sumą, kurią gauni.
function GiveRobberyLoot(src, lootKey, opts)
    opts = opts or {}
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0, 0 end
    local loot = (Config.Robberies.Loot or {})[lootKey]
    if not loot then return 0, 0 end

    local cashGiven, dirtyGiven = 0, 0

    if loot.dirty then
        dirtyGiven = math.random(loot.dirty.min or 0, loot.dirty.max or 0)
    elseif loot.markedbills then
        local count = math.random(loot.markedbills.min or 0, loot.markedbills.max or 0)
        local worth = loot.markedbills.worth or 350
        dirtyGiven = math.max(0, count * worth)
    end

    if loot.cash then
        cashGiven = math.random(loot.cash.min or 0, loot.cash.max or 0)
    end

    if cashGiven > 0 then
        Player.Functions.AddMoney('cash', cashGiven, opts.reason or 'robbery-loot')
    end
    if dirtyGiven > 0 then
        Player.Functions.AddItem('markedbills', dirtyGiven, false, {})
        if QBCore.Shared.Items['markedbills'] then
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add', dirtyGiven)
        end
    end

    if loot.goldbar and math.random() < (loot.goldbar.chance or 0) then
        local n = math.random(loot.goldbar.min or 1, loot.goldbar.max or 1)
        if n > 0 then Player.Functions.AddItem('goldbar', n) end
    end
    if loot.casinochips then
        local n = math.random(loot.casinochips.min or 0, loot.casinochips.max or 0)
        if n > 0 then Player.Functions.AddItem('casinochips', n) end
    end

    local parts = {}
    if cashGiven > 0 then parts[#parts + 1] = ('$%s švarių'):format(cashGiven) end
    if dirtyGiven > 0 then parts[#parts + 1] = ('$%s nešvarių'):format(dirtyGiven) end
    if #parts > 0 then
        local total = cashGiven + dirtyGiven
        local msg
        if opts.notifyText then
            msg = opts.notifyText:format(total)
            if cashGiven > 0 and dirtyGiven > 0 then
                msg = msg .. (' (švarių $%s + nešvarių $%s)'):format(cashGiven, dirtyGiven)
            end
        else
            msg = (opts.prefix or 'Gavai ') .. table.concat(parts, ' + ')
        end
        TriggerClientEvent('QBCore:Notify', src, msg, 'success')
    end
    return cashGiven, dirtyGiven
end

exports('GiveRobberyLoot', GiveRobberyLoot)

exports('BuildHackProfile', function(src, tierId)
    local ok, _, ctx = canAccessRobbery(src, tierId, 'stealth')
    if not ok then return nil end
    return buildHackProfile(tierId, ctx)
end)

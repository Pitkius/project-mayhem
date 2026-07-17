--[[
  Server: veikėjo narkotikų duomenys — Dark Net prieiga, įvadinės misijos būsena,
  L1/L2/L3 pardavimų progresas ir lygių atrakinimas.

  Eksportuoja globalų `DrugPlayer` (naudoja darknet.lua, intro_mission.lua, main.lua).
  DB lentelė: fivempro_drugs_player (viena eilutė vienam citizenid).

  Intro būsenos (intro_state):
    0 = nepradėta
    1 = gauta SMS, reikia susitikti su kontaktu
    2 = susitikta, reikia paimti siuntą
    3 = siunta paimta, reikia pristatyti
    4 = misija baigta (istoriškai; darknet_unlocked = 1 yra tiesos šaltinis)
]]

local QBCore = exports['qb-core']:GetCoreObject()

DrugPlayer = DrugPlayer or {}

local cache = {} -- [citizenid] = row

-- ── Lygių žemėlapis: itemName → lygis ──────────────────────────────
local itemLevelMap = {}
local function buildItemLevelMap()
    itemLevelMap = {}
    local cfg = Config.DrugProgression or {}
    for level, items in pairs(cfg.levelProducts or {}) do
        for _, item in ipairs(items) do
            itemLevelMap[tostring(item):lower()] = tonumber(level)
        end
    end
end

function DrugPlayer.itemLevel(itemName)
    return itemLevelMap[tostring(itemName or ''):lower()]
end

-- ── DB ─────────────────────────────────────────────────────────────
function DrugPlayer.ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_drugs_player` (
        `citizenid` varchar(60) NOT NULL,
        `darknet_unlocked` tinyint(1) NOT NULL DEFAULT 0,
        `intro_state` int(11) NOT NULL DEFAULT 0,
        `level_unlocked` int(11) NOT NULL DEFAULT 1,
        `l1_sold` int(11) NOT NULL DEFAULT 0,
        `l2_sold` int(11) NOT NULL DEFAULT 0,
        `l3_sold` int(11) NOT NULL DEFAULT 0,
        `weapon_prints` int(11) NOT NULL DEFAULT 0,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    -- Senesnės DB be stulpelio
    pcall(function()
        MySQL.query.await('ALTER TABLE `fivempro_drugs_player` ADD COLUMN `weapon_prints` int(11) NOT NULL DEFAULT 0')
    end)
end

local function defaultRow(citizenid)
    return {
        citizenid = citizenid,
        darknet_unlocked = 0,
        intro_state = 0,
        level_unlocked = 1,
        l1_sold = 0,
        l2_sold = 0,
        l3_sold = 0,
        weapon_prints = 0,
    }
end

function DrugPlayer.load(citizenid)
    if not citizenid or citizenid == '' then return nil end
    local row = MySQL.single.await('SELECT * FROM fivempro_drugs_player WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then
        row = defaultRow(citizenid)
        MySQL.insert.await(
            'INSERT IGNORE INTO fivempro_drugs_player (citizenid) VALUES (?)',
            { citizenid }
        )
    end
    row.darknet_unlocked = tonumber(row.darknet_unlocked) or 0
    row.intro_state = tonumber(row.intro_state) or 0
    row.level_unlocked = math.max(1, tonumber(row.level_unlocked) or 1)
    row.l1_sold = tonumber(row.l1_sold) or 0
    row.l2_sold = tonumber(row.l2_sold) or 0
    row.l3_sold = tonumber(row.l3_sold) or 0
    row.weapon_prints = tonumber(row.weapon_prints) or 0
    cache[citizenid] = row
    return row
end

local function citizenOf(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, nil end
    return Player.PlayerData.citizenid, Player
end

function DrugPlayer.getByCitizen(citizenid)
    if not citizenid then return nil end
    return cache[citizenid] or DrugPlayer.load(citizenid)
end

function DrugPlayer.get(src)
    local citizenid = citizenOf(src)
    if not citizenid then return nil end
    return DrugPlayer.getByCitizen(citizenid)
end

local function persist(citizenid)
    local row = cache[citizenid]
    if not row then return end
    MySQL.update.await([[
        UPDATE fivempro_drugs_player
        SET darknet_unlocked = ?, intro_state = ?, level_unlocked = ?, l1_sold = ?, l2_sold = ?, l3_sold = ?, weapon_prints = ?
        WHERE citizenid = ?
    ]], {
        row.darknet_unlocked, row.intro_state, row.level_unlocked,
        row.l1_sold, row.l2_sold, row.l3_sold, row.weapon_prints or 0, citizenid,
    })
end
DrugPlayer.persist = persist

-- ── SMS pagalbininkas ──────────────────────────────────────────────
function DrugPlayer.sendSms(citizenid, body)
    if not citizenid or not body then return end
    if GetResourceState('mrp_phone') ~= 'started' then return end
    local fromNumber = (Config.DarkNet and Config.DarkNet.sms and Config.DarkNet.sms.fromNumber) or '000000'
    pcall(function()
        exports['mrp_phone']:SendSystemSMS(citizenid, fromNumber, body)
    end)
end

-- ── Nešvarūs pinigai (1 markedbills = $1; legacy info.worth palaikomas) ──
local function slotDirtyValue(it)
    local count = math.floor(tonumber(it.amount) or 0)
    if count <= 0 then return 0, false end
    local worth = tonumber(it.info and it.info.worth)
    if worth and worth > 0 then
        return worth * count, true -- senas formatas: x1 banknotas su worth
    end
    return count, false -- naujas: kiekis = doleriai
end

local function collectMarkedBills(Player)
    local slots = Player.Functions.GetItemsByName('markedbills') or {}
    local list, total = {}, 0
    local hasLegacy = false
    for _, it in ipairs(slots) do
        local value, legacy = slotDirtyValue(it)
        if value > 0 then
            list[#list + 1] = { slot = it.slot, count = math.floor(tonumber(it.amount) or 0), value = value, legacy = legacy }
            total = total + value
            if legacy then hasLegacy = true end
        end
    end
    return list, total, hasLegacy
end

--- Surenka visus markedbills į vieną stacką be info.worth (1 = $1).
local function normalizeDirtyMoney(Player)
    local list, total, hasLegacy = collectMarkedBills(Player)
    if total <= 0 then return 0 end
    if not hasLegacy and #list <= 1 then return total end

    for _, b in ipairs(list) do
        Player.Functions.RemoveItem('markedbills', b.count, b.slot)
    end
    if total > 0 then
        Player.Functions.AddItem('markedbills', total, false, {})
    end
    return total
end

function DrugPlayer.getDirtyTotal(Player)
    local _, total = collectMarkedBills(Player)
    return total
end

function DrugPlayer.normalizeDirty(Player)
    return normalizeDirtyMoney(Player)
end

--- Prideda nešvarių pinigų kaip inventorius kiekį (x suma).
function DrugPlayer.addDirty(src, Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    normalizeDirtyMoney(Player)
    local ok = Player.Functions.AddItem('markedbills', amount, false, {})
    if not ok and GetResourceState('qb-inventory') == 'started' then
        ok = exports['qb-inventory']:AddItem(src, 'markedbills', amount, nil, {}, reason or 'dirty-money')
    end
    return ok == true
end

--- Ar žaidėjas turi bent `amount` nešvarių pinigų.
function DrugPlayer.canAffordDirty(Player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local _, total = collectMarkedBills(Player)
    return total >= amount
end

--- Nurašo `amount` nešvarių pinigų (markedbills). Grąža lieka kaip x kiekis.
--- @return boolean ok
function DrugPlayer.chargeDirty(src, Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    reason = reason or 'mrp_drugs:charge'

    local total = normalizeDirtyMoney(Player)
    if total < amount then return false end

    if not Player.Functions.RemoveItem('markedbills', amount) then
        return false
    end
    return true
end

-- ── Gaujos patikra ─────────────────────────────────────────────────
function DrugPlayer.isInGang(src)
    if GetResourceState('mrp_gangs') ~= 'started' then return false end
    local ok, inGang = pcall(function()
        return exports['mrp_gangs']:IsInGang(src)
    end)
    return ok and inGang == true
end

-- ── Dark Net prieiga ───────────────────────────────────────────────
--- Ar žaidėjas gali PIRKTI/naudoti Dark Net (asmeninis atrakinimas ARBA gaujos narys).
function DrugPlayer.hasDarknetAccess(src)
    local row = DrugPlayer.get(src)
    if row and row.darknet_unlocked == 1 then return true end
    if DrugPlayer.isInGang(src) then return true end
    return false
end

function DrugPlayer.unlockDarknet(src, sendSms)
    local citizenid, Player = citizenOf(src)
    if not citizenid then return false end
    local row = DrugPlayer.getByCitizen(citizenid)
    if not row then return false end
    if row.darknet_unlocked == 1 then return true end
    row.darknet_unlocked = 1
    row.intro_state = 4
    persist(citizenid)
    if sendSms ~= false then
        local finalSms = (Config.IntroMission and Config.IntroMission.finalSms)
        if finalSms then DrugPlayer.sendSms(citizenid, finalSms) end
    end
    DrugPlayer.syncClient(src)
    return true
end

-- ── Įvadinės misijos būsena ────────────────────────────────────────
function DrugPlayer.getIntroState(src)
    local row = DrugPlayer.get(src)
    return row and row.intro_state or 0
end

function DrugPlayer.setIntroState(src, state)
    local citizenid = citizenOf(src)
    if not citizenid then return end
    local row = DrugPlayer.getByCitizen(citizenid)
    if not row then return end
    row.intro_state = tonumber(state) or 0
    persist(citizenid)
    DrugPlayer.syncClient(src)
end

-- ── Lygio atrakinimas ──────────────────────────────────────────────
function DrugPlayer.levelUnlocked(src, level)
    level = tonumber(level) or 1
    if level <= 1 then return true end
    local row = DrugPlayer.get(src)
    if not row then return false end
    return (row.level_unlocked or 1) >= level
end

--- 3D spausdinimo XP (ginklų craft atrakinimui)
function DrugPlayer.getWeaponPrints(src)
    local row = DrugPlayer.get(src)
    return row and (tonumber(row.weapon_prints) or 0) or 0
end

--- Grąžina 0 (tik spausdintuvas), 1 (L1 ginklai), 2 (išplėstas L1 rinkinys)
function DrugPlayer.getWeaponCraftTier(src)
    local cfg = Config.WeaponPrintProgression or {}
    if cfg.enabled == false then return 2 end
    local prints = DrugPlayer.getWeaponPrints(src)
    local l2 = tonumber(cfg.unlockL2At) or 15
    local l1 = tonumber(cfg.unlockL1At) or 10
    if prints >= l2 then return 2 end
    if prints >= l1 then return 1 end
    return 0
end

function DrugPlayer.weaponProductUnlocked(src, productLevel)
    productLevel = tonumber(productLevel) or 1
    local tier = DrugPlayer.getWeaponCraftTier(src)
    return tier >= productLevel
end

--- +1 po sėkmingo 3D print. Grąžina { prints, unlockedTier, justUnlocked }
function DrugPlayer.addWeaponPrint(src, amount)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local citizenid = citizenOf(src)
    if not citizenid then return nil end
    local row = DrugPlayer.getByCitizen(citizenid)
    if not row then return nil end

    local cfg = Config.WeaponPrintProgression or {}
    local before = DrugPlayer.getWeaponCraftTier(src)
    row.weapon_prints = (tonumber(row.weapon_prints) or 0) + amount
    persist(citizenid)
    local after = DrugPlayer.getWeaponCraftTier(src)
    local justUnlocked = after > before and after or nil

    if justUnlocked == 1 then
        TriggerClientEvent('QBCore:Notify', src,
            ('Atrakinta L1 ginklų gamykla! (%d/%d spausdinimų)'):format(
                row.weapon_prints, tonumber(cfg.unlockL1At) or 10
            ), 'success')
    elseif justUnlocked == 2 then
        TriggerClientEvent('QBCore:Notify', src,
            ('Atrakintas išplėstas L1 rinkinys (Tec-9 / shotgun / .50)! (%d/%d)'):format(
                row.weapon_prints, tonumber(cfg.unlockL2At) or 15
            ), 'success')
    end

    return {
        prints = row.weapon_prints,
        unlockedTier = after,
        justUnlocked = justUnlocked,
    }
end

--- Test QA: atrakina L1–L3 gamybos lygius (naudojama nemokamos parduotuvės NPC).
function DrugPlayer.unlockAllLevels(src, maxLevel)
    if not (Config.DrugProgression and Config.DrugProgression.enabled) then return true, false end
    local citizenid = citizenOf(src)
    if not citizenid then return false, false end
    local row = DrugPlayer.getByCitizen(citizenid)
    if not row then return false, false end
    maxLevel = math.max(1, math.min(3, tonumber(maxLevel) or 3))
    local previous = row.level_unlocked or 1
    if previous >= maxLevel then return true, false end
    row.level_unlocked = maxLevel
    persist(citizenid)
    DrugPlayer.syncClient(src)
    return true, true
end

-- ── Pardavimo progresas ────────────────────────────────────────────
--- Iškviečiama serverio pusėje po SĖKMINGO pardavimo (parduota `amount` vnt. `itemName`).
--- Prideda realų kiekį prie atitinkamo lygio, tikrina atrakinimus, siunčia SMS,
--- ir aktyvuoja įvadinę misiją (jei sąlygos tenkinamos).
function DrugPlayer.addSale(src, itemName, amount)
    if not (Config.DrugProgression and Config.DrugProgression.enabled) then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    local level = DrugPlayer.itemLevel(itemName)
    if not level then return end -- ne progresuojamas galutinis produktas

    local citizenid = citizenOf(src)
    if not citizenid then return end
    local row = DrugPlayer.getByCitizen(citizenid)
    if not row then return end

    local key = ('l%d_sold'):format(level)
    row[key] = (row[key] or 0) + amount

    -- Lygių atrakinimas (progresas iš žemesnio lygio atrakina kitą).
    local req = Config.DrugProgression.unlockRequirements or {}
    for nextLevel = 2, 3 do
        if (row.level_unlocked or 1) < nextLevel then
            local need = tonumber(req[nextLevel])
            local sourceLevel = nextLevel - 1
            local have = row[('l%d_sold'):format(sourceLevel)] or 0
            if need and have >= need then
                row.level_unlocked = nextLevel
                local sms = Config.DrugProgression.unlockSms and Config.DrugProgression.unlockSms[nextLevel]
                if sms then DrugPlayer.sendSms(citizenid, sms) end
            end
        end
    end

    persist(citizenid)

    -- Įvadinės misijos aktyvavimas (civilis, be prieigos, dar nepradėjęs).
    DrugPlayer.maybeActivateIntro(src, row)

    DrugPlayer.syncClient(src)
end

function DrugPlayer.totalSold(row)
    if not row then return 0 end
    return (row.l1_sold or 0) + (row.l2_sold or 0) + (row.l3_sold or 0)
end

--- Aktyvuoja civilio įvadinę misiją, jei tenkinamos sąlygos.
function DrugPlayer.maybeActivateIntro(src, row)
    local intro = Config.IntroMission
    if not (intro and intro.enabled) then return end
    if not row then row = DrugPlayer.get(src) end
    if not row then return end
    if row.darknet_unlocked == 1 then return end
    if row.intro_state ~= 0 then return end
    if DrugPlayer.isInGang(src) then return end -- gaujos nariui misija nereikalinga

    local act = intro.activation or {}
    if act.mode == 'drug_activity' then
        local need = tonumber(act.afterSales) or 1
        if DrugPlayer.totalSold(row) < need then return end
    end

    row.intro_state = 1
    DrugPlayer.persist(row.citizenid)
    DrugPlayer.sendSms(row.citizenid, intro.introSms)
    if intro.locationSms then
        SetTimeout(4000, function() DrugPlayer.sendSms(row.citizenid, intro.locationSms) end)
    end
    DrugPlayer.syncClient(src)
end

-- ── Kliento sinchronizacija ────────────────────────────────────────
function DrugPlayer.buildClientState(src)
    local row = DrugPlayer.get(src)
    local inGang = DrugPlayer.isInGang(src)
    return {
        darknetAccess = (row and row.darknet_unlocked == 1) or inGang,
        darknetUnlocked = row and row.darknet_unlocked == 1 or false,
        inGang = inGang,
        introState = row and row.intro_state or 0,
        levelUnlocked = row and row.level_unlocked or 1,
        l1 = row and row.l1_sold or 0,
        l2 = row and row.l2_sold or 0,
        l3 = row and row.l3_sold or 0,
    }
end

function DrugPlayer.syncClient(src)
    if not src then return end
    TriggerClientEvent('mrp_drugs:client:playerStateSync', src, DrugPlayer.buildClientState(src))
end

-- ── Įkrovimas / eventai ────────────────────────────────────────────
CreateThread(function()
    buildItemLevelMap()
    DrugPlayer.ensureTable()
    Wait(500)
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local citizenid = citizenOf(src)
        if citizenid then
            DrugPlayer.load(citizenid)
            DrugPlayer.syncClient(src)
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local citizenid = citizenOf(src)
    if citizenid then
        DrugPlayer.load(citizenid)
        SetTimeout(2500, function()
            if QBCore.Functions.GetPlayer(src) then
                DrugPlayer.syncClient(src)
            end
        end)
    end
end)

AddEventHandler('QBCore:Server:PlayerUnloaded', function(src)
    local citizenid = citizenOf(src)
    if citizenid then
        persist(citizenid)
        cache[citizenid] = nil
    end
end)

--- Kliento užklausa būsenai (pvz. atsidarant UI).
QBCore.Functions.CreateCallback('mrp_drugs:server:getPlayerState', function(src, cb)
    cb(DrugPlayer.buildClientState(src))
end)

return DrugPlayer

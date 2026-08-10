--[[
  Mayhem loot crates — shared definitions (legal / XP / illegal / daily / weekly).
]]

MrpCrates = MrpCrates or {}

---@class MrpCrateLootEntry
---@field item string|nil QBCore item name (nil if kind=xp)
---@field kind string|nil 'item' | 'xp'
---@field amount number
---@field weight number
---@field rarity string
---@field label string|nil override label
---@field icon string|nil emoji fallback

MrpCrates.Defs = {
    deze_legali = {
        id = 'deze_legali',
        label = 'Legalių daiktų dėžė',
        description = 'Naudingi legalūs daiktai iš rinkos.',
        image = 'deze_legali.png',
        accent = '#38bdf8',
        icon = '🧰',
        loot = {
            { item = 'water_bottle', amount = 8, weight = 40, rarity = 'common', icon = '💧' },
            { item = 'coffee', amount = 5, weight = 35, rarity = 'common', icon = '☕' },
            { item = 'bandage', amount = 6, weight = 30, rarity = 'common', icon = '🩹' },
            { item = 'painkillers', amount = 4, weight = 28, rarity = 'common', icon = '💊' },
            { item = 'cleaningkit', amount = 2, weight = 24, rarity = 'uncommon', icon = '🧽' },
            { item = 'repairkit', amount = 1, weight = 20, rarity = 'uncommon', icon = '🔧' },
            { item = 'tirerepairkit', amount = 1, weight = 18, rarity = 'uncommon', icon = '🛞' },
            { item = 'firstaid', amount = 2, weight = 16, rarity = 'rare', icon = '⛑️' },
            { item = 'jerry_can', amount = 1, weight = 12, rarity = 'rare', icon = '⛽' },
            { item = 'advancedrepairkit', amount = 1, weight = 8, rarity = 'epic', icon = '🛠️' },
            { item = 'armor_light', amount = 1, weight = 6, rarity = 'epic', icon = '🦺' },
            { item = 'phone', amount = 1, weight = 3, rarity = 'legendary', icon = '📱' },
        },
    },
    deze_exp = {
        id = 'deze_exp',
        label = 'EXP dėžė',
        description = 'RP Pass XP paketai.',
        image = 'deze_exp.png',
        accent = '#a78bfa',
        icon = '✨',
        loot = {
            { kind = 'xp', amount = 100, weight = 40, rarity = 'common', label = '100 XP', icon = '✨' },
            { kind = 'xp', amount = 200, weight = 30, rarity = 'common', label = '200 XP', icon = '✨' },
            { kind = 'xp', amount = 350, weight = 22, rarity = 'uncommon', label = '350 XP', icon = '⭐' },
            { kind = 'xp', amount = 500, weight = 16, rarity = 'rare', label = '500 XP', icon = '🌟' },
            { kind = 'xp', amount = 750, weight = 10, rarity = 'epic', label = '750 XP', icon = '💫' },
            { kind = 'xp', amount = 1200, weight = 4, rarity = 'legendary', label = '1200 XP', icon = '👑' },
            { item = 'cash', amount = 500, weight = 12, rarity = 'uncommon', icon = '💵' },
            { item = 'cash', amount = 1500, weight = 5, rarity = 'epic', icon = '💵' },
        },
    },
    deze_nelegali = {
        id = 'deze_nelegali',
        label = 'Nelegalių daiktų dėžė',
        description = 'Kontrabanda ir gatvės įrankiai (be ginklų).',
        image = 'deze_nelegali.png',
        accent = '#f87171',
        icon = '☠️',
        loot = {
            { item = 'lockpick', amount = 3, weight = 35, rarity = 'common', icon = '🔓' },
            { item = 'advancedlockpick', amount = 1, weight = 18, rarity = 'uncommon', icon = '🔐' },
            { item = 'joint', amount = 4, weight = 28, rarity = 'common', icon = '🚬' },
            { item = 'weed_bag', amount = 1, weight = 16, rarity = 'uncommon', icon = '🌿' },
            { item = 'cokebaggy', amount = 1, weight = 12, rarity = 'rare', icon = '❄️' },
            { item = 'oxy', amount = 2, weight = 14, rarity = 'uncommon', icon = '💊' },
            { item = 'markedbills', amount = 1, weight = 10, rarity = 'rare', icon = '💸' },
            { item = 'electronickit', amount = 1, weight = 8, rarity = 'rare', icon = '🔌' },
            { item = 'trojan_usb', amount = 1, weight = 5, rarity = 'epic', icon = '💾' },
            { item = 'rolex', amount = 1, weight = 3, rarity = 'legendary', icon = '⌚' },
        },
    },
    dienos_deze = {
        id = 'dienos_deze',
        label = 'Dienos dėžė',
        description = 'Kasdienė Mayhem loot dėžė.',
        image = 'dienos_deze.png',
        accent = '#fbbf24',
        icon = '📦',
        loot = {
            { item = 'water_bottle', amount = 5, weight = 36, rarity = 'common', icon = '💧' },
            { item = 'coffee', amount = 3, weight = 30, rarity = 'common', icon = '☕' },
            { item = 'bandage', amount = 4, weight = 28, rarity = 'common', icon = '🩹' },
            { item = 'repairkit', amount = 1, weight = 18, rarity = 'uncommon', icon = '🔧' },
            { item = 'cleaningkit', amount = 2, weight = 20, rarity = 'uncommon', icon = '🧽' },
            { item = 'firstaid', amount = 1, weight = 14, rarity = 'rare', icon = '⛑️' },
            { item = 'jerry_can', amount = 1, weight = 10, rarity = 'rare', icon = '⛽' },
            { kind = 'xp', amount = 150, weight = 16, rarity = 'uncommon', label = '150 XP', icon = '✨' },
            { item = 'armor_light', amount = 1, weight = 6, rarity = 'epic', icon = '🦺' },
            { item = 'cash', amount = 1000, weight = 4, rarity = 'legendary', icon = '💵' },
        },
    },
    savaites_deze = {
        id = 'savaites_deze',
        label = 'Savaitės dėžė',
        description = 'Savaitinė mega dėžė — geresni dropai.',
        image = 'savaites_deze.png',
        accent = '#67e8f9',
        icon = '🏆',
        loot = {
            { item = 'repairkit', amount = 3, weight = 28, rarity = 'common', icon = '🔧' },
            { item = 'advancedrepairkit', amount = 1, weight = 16, rarity = 'uncommon', icon = '🛠️' },
            { item = 'ifaks', amount = 3, weight = 20, rarity = 'uncommon', icon = '🩺' },
            { item = 'armor_standard', amount = 1, weight = 12, rarity = 'rare', icon = '🛡️' },
            { kind = 'xp', amount = 500, weight = 18, rarity = 'rare', label = '500 XP', icon = '🌟' },
            { kind = 'xp', amount = 1000, weight = 8, rarity = 'epic', label = '1000 XP', icon = '💫' },
            { item = 'parachute', amount = 1, weight = 8, rarity = 'epic', icon = '🪂' },
            { item = 'diving_gear', amount = 1, weight = 5, rarity = 'legendary', icon = '🤿' },
            { item = 'cash', amount = 3500, weight = 6, rarity = 'legendary', icon = '💵' },
            { item = 'phone', amount = 1, weight = 4, rarity = 'legendary', icon = '📱' },
        },
    },
}

function MrpCrates.Get(id)
    return MrpCrates.Defs[id]
end

function MrpCrates.Pick(crateId)
    local def = MrpCrates.Defs[crateId]
    if not def or not def.loot then return nil end
    local total = 0
    for _, e in ipairs(def.loot) do
        total = total + (e.weight or 1)
    end
    local roll = math.random(1, math.max(total, 1))
    local acc = 0
    for _, e in ipairs(def.loot) do
        acc = acc + (e.weight or 1)
        if roll <= acc then
            return e
        end
    end
    return def.loot[1]
end

--- Build CSGO-style reel with winner forced at winnerIndex
function MrpCrates.BuildReel(crateId, winner, length, winnerIndex)
    length = length or 48
    winnerIndex = winnerIndex or 40
    local def = MrpCrates.Defs[crateId]
    local pool = def and def.loot or { winner }
    local reel = {}
    for i = 1, length do
        if i == winnerIndex then
            reel[i] = winner
        else
            reel[i] = pool[math.random(1, #pool)]
        end
    end
    return reel, winnerIndex
end

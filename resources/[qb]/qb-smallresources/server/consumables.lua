
----------- / alcohol

for k, _ in pairs(Config.Consumables.alcohol) do
    QBCore.Functions.CreateUseableItem(k, function(source, item)
        TriggerClientEvent('consumables:client:DrinkAlcohol', source, item.name, item.slot)
    end)
end

----------- / Eat

for k, _ in pairs(Config.Consumables.eat) do
    QBCore.Functions.CreateUseableItem(k, function(source, item)
        TriggerClientEvent('consumables:client:Eat', source, item.name, item.slot)
    end)
end

----------- / Drink
for k, _ in pairs(Config.Consumables.drink) do
    QBCore.Functions.CreateUseableItem(k, function(source, item)
        TriggerClientEvent('consumables:client:Drink', source, item.name, item.slot)
    end)
end

----------- / Custom
for k, _ in pairs(Config.Consumables.custom) do
    QBCore.Functions.CreateUseableItem(k, function(source, item)
        if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'qb-smallresources:consumables:custom') then return end
        TriggerClientEvent('consumables:client:Custom', source, item.name)
    end)
end

local function createItem(name, type)
    QBCore.Functions.CreateUseableItem(name, function(source, item)
        if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'qb-smallresources:consumables:createItem') then return end
        TriggerClientEvent('consumables:client:' .. type, source, item.name)
    end)
end
----------- / Drug

QBCore.Functions.CreateUseableItem('joint', function(source, item)
    if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'qb-smallresources:joint') then return end
    TriggerClientEvent('consumables:client:UseJoint', source)
end)

QBCore.Functions.CreateUseableItem('cokebaggy', function(source)
    TriggerClientEvent('consumables:client:Cokebaggy', source)
end)

QBCore.Functions.CreateUseableItem('crack_baggy', function(source)
    TriggerClientEvent('consumables:client:Crackbaggy', source)
end)

QBCore.Functions.CreateUseableItem('xtcbaggy', function(source)
    TriggerClientEvent('consumables:client:EcstasyBaggy', source)
end)

QBCore.Functions.CreateUseableItem('oxy', function(source)
    TriggerClientEvent('consumables:client:oxy', source)
end)

QBCore.Functions.CreateUseableItem('meth', function(source)
    TriggerClientEvent('consumables:client:meth', source)
end)

----------- / Tools

local function registerArmorVests()
    if not Config.ArmorVests then return end
    for itemName, _ in pairs(Config.ArmorVests) do
        QBCore.Functions.CreateUseableItem(itemName, function(source)
            TriggerClientEvent('consumables:client:UseArmorVest', source, itemName)
        end)
    end
end

registerArmorVests()

QBCore.Commands.Add('resetarmor', 'Resets Vest (Police Only)', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.name == 'police' then
        TriggerClientEvent('consumables:client:ResetArmor', source)
    else
        TriggerClientEvent('QBCore:Notify', source, 'For Police Officer Only', 'error')
    end
end)

QBCore.Functions.CreateUseableItem('binoculars', function(source)
    TriggerClientEvent('binoculars:Toggle', source)
end)

QBCore.Functions.CreateUseableItem('parachute', function(source, item)
    if not exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'qb-smallresources:parachute') then return end
    TriggerClientEvent('consumables:client:UseParachute', source)
end)

QBCore.Commands.Add('resetparachute', 'Resets Parachute', {}, false, function(source)
    TriggerClientEvent('consumables:client:ResetParachute', source)
end)

----------- / Firework

for _, v in pairs(Config.Fireworks.items) do
    QBCore.Functions.CreateUseableItem(v, function(source, item)
        local src = source
        TriggerClientEvent('fireworks:client:UseFirework', src, item.name, 'proj_indep_firework')
    end)
end

----------- / Lockpicking

QBCore.Functions.CreateUseableItem('lockpick', function(source)
    TriggerClientEvent('lockpicks:UseLockpick', source, false)
end)

QBCore.Functions.CreateUseableItem('advancedlockpick', function(source)
    TriggerClientEvent('lockpicks:UseLockpick', source, true)
end)

-- Events for adding and removing specific items to fix some exploits

RegisterNetEvent('consumables:server:AddParachute', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:AddItem(source, 'parachute', 1, false, false, 'consumables:server:AddParachute')
end)

RegisterNetEvent('consumables:server:resetArmor', function(itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local returnItem = itemName
    if not returnItem or not Config.ArmorVests or not Config.ArmorVests[returnItem] then
        returnItem = 'heavyarmor'
    end
    exports['qb-inventory']:AddItem(source, returnItem, 1, false, false, 'consumables:server:resetArmor')
    Player.Functions.SetMetaData('armor', 0)
end)

RegisterNetEvent('consumables:server:useArmorVest', function(itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local vestCfg = Config.ArmorVests and Config.ArmorVests[itemName]
    if not vestCfg then return end
    if vestCfg.job and Player.PlayerData.job.name ~= vestCfg.job then
        TriggerClientEvent('QBCore:Notify', src, 'Ši liemenė skirta tik tarnautojams.', 'error')
        return
    end
    if not exports['qb-inventory']:RemoveItem(src, itemName, 1, false, ('consumables:server:useArmorVest:%s'):format(itemName)) then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    Player.Functions.SetMetaData('armor', vestCfg.armor)
    SetPedArmour(GetPlayerPed(src), vestCfg.armor)
end)

RegisterNetEvent('consumables:server:useMeth', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'meth', 1, false, 'consumables:server:useMeth')
end)

RegisterNetEvent('consumables:server:useOxy', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'oxy', 1, false, 'consumables:server:useOxy')
end)

RegisterNetEvent('consumables:server:useXTCBaggy', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'xtcbaggy', 1, false, 'consumables:server:useXTCBaggy')
end)

RegisterNetEvent('consumables:server:useCrackBaggy', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'crack_baggy', 1, false, 'consumables:server:useCrackBaggy')
end)

RegisterNetEvent('consumables:server:useCokeBaggy', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'cokebaggy', 1, false, 'consumables:server:useCokeBaggy')
end)

RegisterNetEvent('consumables:server:drinkAlcohol', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local foundItem = nil

    for k in pairs(Config.Consumables.alcohol) do
        if k == item then
            foundItem = k
            break
        end
    end

    if not foundItem then return end
    exports['qb-inventory']:RemoveItem(source, foundItem, 1, false, 'consumables:server:drinkAlcohol')
end)

RegisterNetEvent('consumables:server:UseFirework', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local foundItem = nil

    for i = 1, #Config.Fireworks.items do
        if Config.Fireworks.items[i] == item then
            foundItem = Config.Fireworks.items[i]
            break
        end
    end

    if not foundItem then return end
    exports['qb-inventory']:RemoveItem(source, foundItem, 1, false, 'consumables:server:UseFirework')
end)

local function clampNeed(value)
    return math.max(0, math.min(100, tonumber(value) or 0))
end

local function applyNeeds(src, Player, hungerDelta, thirstDelta)
    local hunger = clampNeed((tonumber(Player.PlayerData.metadata.hunger) or 0) + (hungerDelta or 0))
    local thirst = clampNeed((tonumber(Player.PlayerData.metadata.thirst) or 0) + (thirstDelta or 0))
    Player.Functions.SetMetaData('hunger', hunger)
    Player.Functions.SetMetaData('thirst', thirst)
    TriggerClientEvent('hud:client:UpdateNeeds', src, hunger, thirst)
end

RegisterNetEvent('consumables:server:finishEat', function(itemName, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    itemName = type(itemName) == 'string' and itemName:lower() or ''
    local hungerAdd = Config.Consumables.eat[itemName]
    if not hungerAdd then return end
    if not exports['qb-inventory']:RemoveItem(src, itemName, 1, slot, 'qb-smallresources:consumables:eat') then return end
    local thirstAdd = (Config.Consumables.dualFoodBoost or {})[itemName] or 0
    applyNeeds(src, Player, hungerAdd, thirstAdd)
end)

RegisterNetEvent('consumables:server:finishDrink', function(itemName, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    itemName = type(itemName) == 'string' and itemName:lower() or ''
    local thirstAdd = Config.Consumables.drink[itemName]
    if not thirstAdd then return end
    if not exports['qb-inventory']:RemoveItem(src, itemName, 1, slot, 'qb-smallresources:consumables:drink') then return end
    local hungerAdd = (Config.Consumables.dualDrinkBoost or {})[itemName] or 0
    applyNeeds(src, Player, hungerAdd, thirstAdd)
end)

RegisterNetEvent('consumables:server:finishDrinkAlcohol', function(itemName, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    itemName = type(itemName) == 'string' and itemName:lower() or ''
    local thirstAdd = Config.Consumables.alcohol[itemName]
    if not thirstAdd then return end
    if not exports['qb-inventory']:RemoveItem(src, itemName, 1, slot, 'qb-smallresources:consumables:drinkAlcohol') then return end
    applyNeeds(src, Player, 0, thirstAdd)
end)

RegisterNetEvent('consumables:server:addThirst', function(amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    amount = math.max(0, math.min(100, tonumber(amount) or 0))
    Player.Functions.SetMetaData('thirst', amount)
    local hunger = math.max(0, math.min(100, tonumber(Player.PlayerData.metadata.hunger) or 0))
    TriggerClientEvent('hud:client:UpdateNeeds', source, hunger, amount)
end)

RegisterNetEvent('consumables:server:addHunger', function(amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    amount = math.max(0, math.min(100, tonumber(amount) or 0))
    Player.Functions.SetMetaData('hunger', amount)
    local thirst = math.max(0, math.min(100, tonumber(Player.PlayerData.metadata.thirst) or 0))
    TriggerClientEvent('hud:client:UpdateNeeds', source, amount, thirst)
end)

QBCore.Functions.CreateCallback('consumables:itemdata', function(_, cb, itemName)
    cb(Config.Consumables.custom[itemName])
end)

---Checks if item already exists in the table. If not, it creates it.
---@param drinkName string name of item
---@param replenish number amount it replenishes
---@return boolean, string
local function addDrink(drinkName, replenish)
    if Config.Consumables.drink[drinkName] ~= nil then
        return false, 'already added'
    else
        Config.Consumables.drink[drinkName] = replenish
        createItem(drinkName, 'Drink')
        return true, 'success'
    end
end

exports('AddDrink', addDrink)

---Checks if item already exists in the table. If not, it creates it.
---@param foodName string name of item
---@param replenish number amount it replenishes
---@return boolean, string
local function addFood(foodName, replenish)
    if Config.Consumables.eat[foodName] ~= nil then
        return false, 'already added'
    else
        Config.Consumables.eat[foodName] = replenish
        createItem(foodName, 'Eat')
        return true, 'success'
    end
end

exports('AddFood', addFood)

---Checks if item already exists in the table. If not, it creates it.
---@param alcoholName string name of item
---@param replenish number amount it replenishes
---@return boolean, string
local function addAlcohol(alcoholName, replenish)
    if Config.Consumables.alcohol[alcoholName] ~= nil then
        return false, 'already added'
    else
        Config.Consumables.alcohol[alcoholName] = replenish
        createItem(alcoholName, 'DrinkAlcohol')
        return true, 'success'
    end
end

exports('AddAlcohol', addAlcohol)

---Checks if item already exists in the table. If not, it creates it.
---@param itemName string name of item
---@param data number amount it replenishes
---@return boolean, string
local function addCustom(itemName, data)
    if Config.Consumables.custom[itemName] ~= nil then
        return false, 'already added'
    else
        Config.Consumables.custom[itemName] = data
        createItem(itemName, 'Custom')
        return true, 'success'
    end
end

exports('AddCustom', addCustom)

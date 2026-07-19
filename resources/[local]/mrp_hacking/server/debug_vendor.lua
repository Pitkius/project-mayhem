local QBCore = exports['qb-core']:GetCoreObject()

local function nearDebugVendor(src)
    local v = Config.DebugHeistVendor or {}
    if v.enabled ~= true or not v.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = v.coords
    return #(p - vector3(c.x, c.y, c.z)) <= 22.0
end

local function tryGiveItem(src, itemName, amount, info)
    amount = math.max(1, tonumber(amount) or 1)
    itemName = tostring(itemName or '')
    if itemName == '' or not QBCore.Shared.Items[itemName] then
        return false, 'Itemas neegzistuoja (qb-core/shared/items.lua).'
    end

    local canAdd, reason = exports['qb-inventory']:CanAddItem(src, itemName, amount)
    if not canAdd then
        if reason == 'weight' then
            return false, 'Per sunku inventoriui — išmesk daiktų arba palik vietos svoriui.'
        end
        if reason == 'slots' then
            return false, 'Inventorius pilnas — reikia laisvo sloto (nėra job apribojimo).'
        end
        return false, 'Negali laikyti daikto — patikrink inventoriaus slotus ir svorį.'
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Žaidėjas nerastas.' end
    local ok = Player.Functions.AddItem(itemName, amount, false, info)
    if not ok then
        return false, 'Nepavyko pridėti į inventorių.'
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', amount)
    return true
end

local function buildDebugHeistShopItems()
    local out = {}
    for _, row in ipairs(Config.DebugHeistShopItems or {}) do
        if row and row.item and QBCore.Shared.Items[row.item] then
            out[#out + 1] = {
                name = row.item,
                amount = 99999,
                price = math.max(1, tonumber(row.price) or 1),
            }
        end
    end
    return out
end

local function registerDebugHeistShop()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    local shop = Config.DebugHeistShop or {}
    exports['qb-inventory']:CreateShop({
        name = shop.name or 'mrp_hack_debug_heist',
        label = shop.label or 'TEST: Heist įrankiai ($1)',
        slots = math.max(1, #buildDebugHeistShopItems()),
        items = buildDebugHeistShopItems(),
    })
end

CreateThread(function()
    Wait(700)
    registerDebugHeistShop()
end)

RegisterNetEvent('mrp_hacking:server:debugOpenHeistShop', function()
    local src = source
    local cfg = Config.DebugHeistVendor or {}
    if cfg.enabled ~= true then return end
    if not nearDebugVendor(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo test pardavėjo.', 'error')
    end
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia qb-inventory.', 'error')
    end
    registerDebugHeistShop()
    local shop = Config.DebugHeistShop or {}
    exports['qb-inventory']:OpenShop(src, shop.name or 'mrp_hack_debug_heist')
end)

RegisterNetEvent('mrp_hacking:server:debugBuyHeistItem', function(itemName)
    local src = source
    local cfg = Config.DebugHeistVendor or {}
    if cfg.enabled ~= true then return end
    if not nearDebugVendor(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo test pardavėjo.', 'error')
    end

    itemName = tostring(itemName or '')
    local entry = nil
    for _, row in ipairs(Config.DebugHeistShopItems or {}) do
        if row and row.item == itemName then
            entry = row
            break
        end
    end
    if not entry then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local price = math.max(1, tonumber(entry.price) or 1)
    if (Player.PlayerData.money.cash or 0) < price then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepakanka grynais.', 'error')
    end
    if not Player.Functions.RemoveMoney('cash', price, 'debug-heist-item') then return end

    local ok, msg = tryGiveItem(src, itemName, 1, nil)
    if not ok then
        Player.Functions.AddMoney('cash', price, 'debug-heist-refund')
        return TriggerClientEvent('QBCore:Notify', src, msg or 'Nepavyko.', 'error')
    end
    TriggerClientEvent('QBCore:Notify', src, 'Nupirkta (test).', 'success')
end)

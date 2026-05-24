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

local function buildDebugHeistShopItems()
    local out = {}
    for i, row in ipairs(Config.DebugHeistShopItems or {}) do
        if row and row.item and QBCore.Shared.Items[row.item] then
            out[#out + 1] = {
                name = row.item,
                amount = 99999,
                price = math.max(1, tonumber(row.price) or 1),
                slot = i,
            }
        end
    end
    return out
end

local function registerDebugHeistShop()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    local shop = Config.DebugHeistShop or {}
    exports['qb-inventory']:CreateShop({
        name = shop.name or 'fivempro_hack_debug_heist',
        label = shop.label or 'TEST: Heist įrankiai ($1)',
        slots = math.max(1, #(Config.DebugHeistShopItems or {})),
        items = buildDebugHeistShopItems(),
    })
end

CreateThread(function()
    Wait(700)
    registerDebugHeistShop()
end)

RegisterNetEvent('fivempro_hacking:server:debugOpenHeistShop', function()
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
    exports['qb-inventory']:OpenShop(src, shop.name or 'fivempro_hack_debug_heist')
end)

RegisterNetEvent('fivempro_hacking:server:debugBuyFlashOffer', function(index)
    local src = source
    local cfg = Config.DebugHeistVendor or {}
    if cfg.enabled ~= true then return end
    if not nearDebugVendor(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo test pardavėjo.', 'error')
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local entry = Config.DebugHeistFlashOffers and Config.DebugHeistFlashOffers[tonumber(index)]
    if not entry or not entry.item then return end
    if not QBCore.Shared.Items[entry.item] then
        return TriggerClientEvent('QBCore:Notify', src, 'Itemas neegzistuoja.', 'error')
    end
    local price = math.max(1, tonumber(entry.price) or 1)
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
    if not Player.Functions.RemoveMoney('cash', price, 'debug-heist-flash') then return end
    Player.Functions.AddItem(entry.item, 1, false, info)
    TriggerClientEvent('QBCore:Notify', src, 'Nupirkta (test).', 'success')
end)

local QBCore = exports['qb-core']:GetCoreObject()

local function registerShop(cfg)
    if not cfg or not cfg.name or not cfg.items then return end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label,
        slots = #cfg.items,
        items = cfg.items
    })
end

CreateThread(function()
    registerShop(Config.FoodShop)
    registerShop(Config.PharmacyShop)
end)

RegisterNetEvent('fivempro_npcshops:server:openFoodShop', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    registerShop(Config.FoodShop)
    exports['qb-inventory']:OpenShop(src, Config.FoodShop.name)
end)

RegisterNetEvent('fivempro_npcshops:server:openPharmacyShop', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    registerShop(Config.PharmacyShop)
    exports['qb-inventory']:OpenShop(src, Config.PharmacyShop.name)
end)

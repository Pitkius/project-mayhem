local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    exports['qb-inventory']:CreateShop({
        name = Config.FoodShop.name,
        label = Config.FoodShop.label,
        slots = #Config.FoodShop.items,
        items = Config.FoodShop.items
    })
end)

RegisterNetEvent('fivempro_npcshops:server:openFoodShop', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    -- Re-register on every open so stock effectively stays infinite.
    exports['qb-inventory']:CreateShop({
        name = Config.FoodShop.name,
        label = Config.FoodShop.label,
        slots = #Config.FoodShop.items,
        items = Config.FoodShop.items
    })
    exports['qb-inventory']:OpenShop(src, Config.FoodShop.name)
end)

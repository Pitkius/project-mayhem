local QBCore = exports['qb-core']:GetCoreObject()

local function getCitizenId(Player)
    return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

local function hasLicense(Player, licenseItem)
    if not Player then return false end
    local cid = getCitizenId(Player)
    local items = Player.Functions.GetItemsByName(licenseItem)
    for _, it in pairs(items or {}) do
        local info = it.info or {}
        if info.citizenid == cid then return true end
    end
    return false
end

local function issueLicense(src, licenseItem, label)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
  local cid = getCitizenId(Player)
    if hasLicense(Player, licenseItem) then
        TriggerClientEvent('QBCore:Notify', src, 'Jau turite šią licenciją.', 'error')
        return
    end
    local charinfo = Player.PlayerData.charinfo or {}
    local info = {
        citizenid = cid,
        firstname = charinfo.firstname or '',
        lastname = charinfo.lastname or '',
        birthdate = charinfo.birthdate or '',
        type = label,
    }
    if not Player.Functions.AddItem(licenseItem, 1, false, info) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[licenseItem], 'add')
    TriggerClientEvent('QBCore:Notify', src, label .. ' išduota.', 'success')
end

QBCore.Functions.CreateCallback('fivempro_outdoors:server:hasLicense', function(source, cb, licenseItem)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(hasLicense(Player, licenseItem))
end)

QBCore.Functions.CreateCallback('fivempro_outdoors:server:canTakeLicenseTest', function(source, cb, testType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false, 'Klaida') return end
    local licenseItem = testType == 'fishing' and 'fishing_license' or 'hunting_license'
    if hasLicense(Player, licenseItem) then
        cb(false, 'Jau turite licenciją.')
        return
    end
    if Player.PlayerData.money.cash < Config.LicenseTestPrice then
        cb(false, ('Reikia $%s testui.'):format(Config.LicenseTestPrice))
        return
    end
    cb(true)
end)

local function registerNatureShops()
    if GetResourceState('qb-inventory') ~= 'started' then return end
    for _, cfg in ipairs({ Config.FishingShop, Config.HuntingShop }) do
        if cfg and cfg.name and cfg.items then
            exports['qb-inventory']:CreateShop({
                name = cfg.name,
                label = cfg.label,
                slots = #cfg.items,
                items = cfg.items,
            })
        end
    end
end

CreateThread(function()
    Wait(1000)
    registerNatureShops()
end)

local function nearNatureShop(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = Config.NatureShopLocation.coords
    return #(p - vector3(c.x, c.y, c.z)) <= 5.0
end

local function openLicensedShop(src, shopCfg)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not nearNatureShop(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo parduotuvės.', 'error')
    end
    if not hasLicense(Player, shopCfg.license) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia licencijos — testą rasite Gamtos apsaugos stotyje.', 'error')
    end
    registerNatureShops()
    exports['qb-inventory']:OpenShop(src, shopCfg.name)
end

RegisterNetEvent('fivempro_outdoors:server:openFishingShop', function()
    openLicensedShop(source, Config.FishingShop)
end)

RegisterNetEvent('fivempro_outdoors:server:openHuntingShop', function()
    openLicensedShop(source, Config.HuntingShop)
end)

RegisterNetEvent('fivempro_outdoors:server:submitLicenseTest', function(testType, score, total)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(score) ~= 'number' or type(total) ~= 'number' then return end
    if score < Config.LicensePassScore then
        TriggerClientEvent('QBCore:Notify', src, 'Testas neišlaikytas. Bandykite dar kartą.', 'error')
        return
    end
    if not Player.Functions.RemoveMoney('cash', Config.LicenseTestPrice, 'outdoors-license-test') then
        TriggerClientEvent('QBCore:Notify', src, 'Nepakanka pinigų.', 'error')
        return
    end
    if testType == 'fishing' then
        issueLicense(src, 'fishing_license', 'Žvejybos licencija')
    elseif testType == 'hunting' then
        issueLicense(src, 'hunting_license', 'Medžioklės licencija')
    end
end)

RegisterNetEvent('fivempro_outdoors:server:sellItem', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return end
    local priceEach = Config.SellPrices[itemName]
    if not priceEach then return end
    local have = Player.Functions.GetItemByName(itemName)
    if not have or have.amount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Neturite pakankamai.', 'error')
        return
    end
  if not Player.Functions.RemoveItem(itemName, amount) then return end
    local payout = priceEach * amount
    Player.Functions.AddMoney('cash', payout, 'outdoors-sell')
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    TriggerClientEvent('QBCore:Notify', src, ('Parduota už $%s.'):format(payout), 'success')
end)

RegisterNetEvent('fivempro_outdoors:server:fishReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not hasLicense(Player, 'fishing_license') then return end
    if not Player.Functions.GetItemByName('fishingrod') then
        TriggerClientEvent('QBCore:Notify', src, 'Reikia meškerės.', 'error')
        return
    end
    local roll = math.random(1, 100)
    local acc = 0
    local item = 'fish_raw'
    for _, row in ipairs(Config.FishingLoot) do
        acc = acc + row.weight
        if roll <= acc then item = row.item break end
    end
    if Player.Functions.AddItem(item, 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
        TriggerClientEvent('QBCore:Notify', src, 'Pagavote žuvį!', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end
end)

RegisterNetEvent('fivempro_outdoors:server:gutAnimal', function(meatItem, extraItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not hasLicense(Player, 'hunting_license') then return end
    if not Player.Functions.GetItemByName('hunting_knife') then
        TriggerClientEvent('QBCore:Notify', src, 'Reikia medžioklinio peilio.', 'error')
        return
    end
    local meatAmt = math.random(1, 3)
    local extraAmt = extraItem and math.random(1, 2) or 0
    if not Player.Functions.AddItem(meatItem, meatAmt) then
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[meatItem], 'add')
    if extraItem and extraAmt > 0 then
        if Player.Functions.AddItem(extraItem, extraAmt) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[extraItem], 'add')
        end
    end
    TriggerClientEvent('QBCore:Notify', src, 'Gavai mėsą ir odą.', 'success')
end)

RegisterNetEvent('fivempro_outdoors:server:butcherItem', function(rawItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local clean = Config.ButcherMap[rawItem]
    if not clean then return end
    if not Player.Functions.RemoveItem(rawItem, 1) then
        TriggerClientEvent('QBCore:Notify', src, 'Neturite žaliavos.', 'error')
        return
    end
    if not Player.Functions.AddItem(clean, 1) then
        Player.Functions.AddItem(rawItem, 1)
        TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
        return
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[rawItem], 'remove')
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[clean], 'add')
    TriggerClientEvent('QBCore:Notify', src, 'Apdorota.', 'success')
end)

--- Neletalus musketas žaidėjams
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not data or not data.weaponType then return end
    if data.weaponType ~= joaat('weapon_musket') then return end
    local victimNet = data.hitGlobalId or data.hitGlobalIds and data.hitGlobalIds[1]
    if not victimNet then return end
    local victim = NetworkGetEntityFromNetworkId(victimNet)
    if not victim or victim == 0 then return end
    if not IsPedAPlayer(victim) then return end
    CancelEvent()
    local victimSrc = NetworkGetEntityOwner(victim)
    if victimSrc and victimSrc > 0 then
        TriggerClientEvent('fivempro_outdoors:client:musketRagdoll', victimSrc)
    end
end)

--- Licencijų naudojimas (rodyti ID)
QBCore.Functions.CreateUseableItem('fishing_license', function(source, item)
    TriggerClientEvent('fivempro_outdoors:client:showLicense', source, item.info, 'Žvejybos licencija')
end)

QBCore.Functions.CreateUseableItem('hunting_license', function(source, item)
    TriggerClientEvent('fivempro_outdoors:client:showLicense', source, item.info, 'Medžioklės licencija')
end)

QBCore.Functions.CreateUseableItem('hunting_knife', function(source)
    TriggerClientEvent('QBCore:Notify', source, 'Naudokite prie negyvo gyvūno (target).', 'primary')
end)

QBCore.Functions.CreateUseableItem('fishingrod', function(source)
    TriggerClientEvent('fivempro_outdoors:client:tryFish', source)
end)

exports('HasOutdoorsLicense', function(src, licenseItem)
    local Player = QBCore.Functions.GetPlayer(src)
    return hasLicense(Player, licenseItem)
end)

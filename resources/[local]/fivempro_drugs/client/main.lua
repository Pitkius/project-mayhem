local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local currentStationId = nil
local testPed = 0
local supplyShopPed = 0
local supplyShopBlip = nil
local mapBlips = {}

local function nui(msg, data)
    SendNUIMessage({ action = msg, data = data or {} })
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    currentStationId = nil
    SetNuiFocus(false, false)
    nui('close')
end

local function openStationUi(stationId)
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:getStationUi', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Nepavyko atidaryti.', 'error')
        end
        currentStationId = stationId
        uiOpen = true
        SetNuiFocus(true, true)
        nui('open', res)
    end, stationId)
end

local function runProgress(label, durationMs, onDone)
    QBCore.Functions.Progressbar('fivempro_drugs_craft', label or 'Gaminama…', durationMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function()
        if onDone then onDone(true) end
    end, function()
        if onDone then onDone(false) end
    end)
end

local pendingMinigame = nil

local function runSkillMinigame(onDone)
    pendingMinigame = onDone
    nui('minigameSkill', { durationMs = 4200 })
    SetNuiFocus(true, true)
end

local function runAdvancedMinigame(onDone)
    pendingMinigame = onDone
    nui('minigameAdvanced', { rounds = 3 })
    SetNuiFocus(true, true)
end

local function startCraftFlow(productId)
    if not currentStationId then return end
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:startCraft', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Gamyba negalima.', 'error')
        end

        local function afterMinigame(success)
            QBCore.Functions.TriggerCallback('fivempro_drugs:server:finishCraft', function(done)
                if not done or not done.ok then
                    QBCore.Functions.Notify((done and done.reason) or 'Gamyba nepavyko.', 'error')
                    if currentStationId then openStationUi(currentStationId) end
                    return
                end
                QBCore.Functions.Notify(('Pagaminta: %s x%d'):format(done.label or done.item, done.amount or 1), 'success')
                if currentStationId then openStationUi(currentStationId) end
            end, res.token, success)
        end

        local mg = res.minigame or 'progress'
        if mg == 'progress' then
            runProgress(res.label, res.craftTimeMs or 25000, afterMinigame)
        elseif mg == 'skill' then
            runProgress(res.label, math.floor((res.craftTimeMs or 30000) * 0.55), function()
                runSkillMinigame(afterMinigame)
            end)
        else
            runProgress(res.label, math.floor((res.craftTimeMs or 40000) * 0.45), function()
                runAdvancedMinigame(afterMinigame)
            end)
        end
    end, currentStationId, productId)
end

local function findSellTargetPed()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local handle, foundPed = FindFirstPed()
    local ok = true
    local target = 0
    repeat
        if foundPed and foundPed ~= ped and not IsPedAPlayer(foundPed) and not IsEntityDead(foundPed) then
            local tp = GetEntityCoords(foundPed)
            if #(p - tp) <= (Config.Sell and Config.Sell.maxDistanceToPed or 3.0) then
                target = foundPed
                break
            end
        end
        ok, foundPed = FindNextPed(handle)
    until not ok
    EndFindPed(handle)
    return target
end

local function trySellToNpc(itemName)
    local target = findSellTargetPed()
    if target == 0 then
        return QBCore.Functions.Notify('Netoliese nėra NPC.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:tryNpcSell', function(res)
        if not res or not res.ok then
            if res and res.panic then
                return QBCore.Functions.Notify(res.reason or 'NPC panikuoja!', 'error')
            end
            if res and res.refused then
                return QBCore.Functions.Notify('NPC atsisakė pirkti.', 'error')
            end
            return QBCore.Functions.Notify((res and res.reason) or 'Pardavimas nepavyko.', 'error')
        end
        QBCore.Functions.Notify(('Parduota už $%s'):format(res.price or 0), 'success')
        if res.alertPolice then
            QBCore.Functions.Notify('Kažkas gali būti iškvietęs policiją…', 'error', 5500)
        end
    end, itemName, NetworkGetNetworkIdFromEntity(target))
end

RegisterNetEvent('fivempro_drugs:client:policeAlert', function(msg)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('fivempro_dispatch:server:createServiceCall', 'police', 'drugs', msg or 'Įtartina veikla', {
        x = c.x, y = c.y, z = c.z,
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('craft', function(data, cb)
    if data and data.productId then
        startCraftFlow(data.productId)
    end
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    if currentStationId then openStationUi(currentStationId) end
    cb('ok')
end)

local function finishMinigame(success)
    SetNuiFocus(uiOpen, uiOpen)
    local cb = pendingMinigame
    pendingMinigame = nil
    if cb then cb(success == true) end
end

RegisterNUICallback('skillResult', function(data, cb)
    finishMinigame(data and data.success)
    cb('ok')
end)

RegisterNUICallback('advancedResult', function(data, cb)
    finishMinigame(data and data.success)
    cb('ok')
end)

RegisterCommand('drugsell', function()
    local sellables = {}
    for _, prod in pairs(Config.Products or {}) do
        sellables[#sellables + 1] = prod.output
    end
    for _, outItem in ipairs(sellables) do
        if QBCore.Functions.HasItem(outItem, 1) then
            return trySellToNpc(outItem)
        end
    end
    QBCore.Functions.Notify('Neturi parduodamų produktų.', 'error')
end, false)

local function setBlipLabel(blip, label)
    local text = tostring(label or 'Gamyba')
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, text)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)
end

local function resolveStationBlipCfg(st)
    if not st or st.blip == false then return nil end
    if not Config.ShowStationBlips and st.blip ~= true and type(st.blip) ~= 'table' then return nil end
    local def = Config.StationBlip or {}
    local custom = type(st.blip) == 'table' and st.blip or {}
    return {
        coords = custom.coords or st.coords,
        sprite = custom.sprite or def.sprite or 496,
        color = custom.color or def.color or 27,
        scale = custom.scale or def.scale or 0.72,
        shortRange = custom.shortRange ~= false and (def.shortRange ~= false),
        label = custom.label or st.label or def.label or 'Narkotikų gamyba',
    }
end

local function createMapBlip(cfg)
    if not cfg or not cfg.coords then return end
    local c = cfg.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite or 496)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale or 0.72)
    SetBlipColour(blip, cfg.color or 27)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    setBlipLabel(blip, cfg.label)
    mapBlips[#mapBlips + 1] = blip
end

local function setupStationBlips()
    for _, bl in ipairs(mapBlips) do
        if bl and DoesBlipExist(bl) then RemoveBlip(bl) end
    end
    mapBlips = {}
    if not Config.ShowStationBlips then return end
    local hub = Config.DevHub
    local def = Config.StationBlip or {}
    if hub and hub.blipCoords then
        createMapBlip({
            coords = hub.blipCoords,
            sprite = def.sprite,
            color = def.color,
            scale = def.scale,
            shortRange = def.shortRange,
            label = def.label or 'Test: narkotikai ir ginklai',
        })
    end
end

local function setupStations()
    if GetResourceState('qb-target') ~= 'started' then return end
    for _, st in ipairs(Config.Stations or {}) do
        local isWeapon = st.mode == 'weapon'
        exports['qb-target']:AddCircleZone(('fivempro_drugs_%s'):format(st.id), st.coords, st.radius or 2.0, {
            name = ('fivempro_drugs_%s'):format(st.id),
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = isWeapon and 'fas fa-gun' or 'fas fa-flask',
                    label = isWeapon and ('Ginklų gamyba: %s'):format(st.label) or ('Gamybos stotis: %s'):format(st.label),
                    action = function()
                        openStationUi(st.id)
                    end,
                },
            },
            distance = Config.InteractDistance or 2.0,
        })
    end
end

local function openMaterialShop()
    TriggerServerEvent('fivempro_drugs:server:openMaterialShop')
end

local function openTestMenu()
    if not Config.EnableDrugTestNPC then return end
    local rows = {
        { header = 'Narkotikų gamyba', isMenuHeader = true },
        { header = 'Pirkti reikmenis (parduotuvė)', txt = 'Ingredientai ir ginklų dalys', params = { isAction = true, event = openMaterialShop } },
        { header = 'L1 sandėliukas', params = { isAction = true, event = function() openStationUi('stash_grove') end } },
        { header = 'L2 trap house', params = { isAction = true, event = function() openStationUi('trap_chamberlain') end } },
        { header = 'L3 kartelis', params = { isAction = true, event = function() openStationUi('cartel_lab') end } },
        { header = 'Ginklų dirbtuvė L1', params = { isAction = true, event = function() openStationUi('weapon_bench_l1') end } },
        { header = 'Ginklų dirbtuvė L2', params = { isAction = true, event = function() openStationUi('weapon_bench_l2') end } },
        { header = 'Ginklų dirbtuvė L3', params = { isAction = true, event = function() openStationUi('weapon_bench_l3') end } },
        { header = 'Pardavimas (/drugsell)', txt = 'Stovėk prie NPC su produktu inventoriuje', isMenuHeader = true },
        { header = 'Uždaryti', params = { isAction = true, event = function() exports['qb-menu']:closeMenu() end } },
    }
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

RegisterNetEvent('fivempro_drugs:client:testKit', function(data)
    TriggerServerEvent('fivempro_drugs:server:testGiveKit', data and data.kit or 'level1')
end)

local function spawnHubPed(cfg, onTarget)
    if not cfg then return 0 end
    local model = joaat(cfg.model or 's_m_y_dealer_01')
    RequestModel(model)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return 0 end
    local c = cfg.coords
    local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    if cfg.scenario then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    end
    if onTarget then onTarget(ped) end
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function setNpcBlip(blip, label)
    local text = tostring(label or 'Nelegalūs reikmenys')
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, text)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)
end

local function createSupplyShopBlip()
    local cfg = Config.SupplyShopNPC
    if not cfg or not cfg.blip or cfg.blip.enabled == false then return end
    local bc = cfg.blip.coords or (cfg.coords and vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z))
    if not bc then return end
    supplyShopBlip = AddBlipForCoord(bc.x, bc.y, bc.z)
    SetBlipSprite(supplyShopBlip, cfg.blip.sprite or 52)
    SetBlipColour(supplyShopBlip, cfg.blip.color or 27)
    SetBlipScale(supplyShopBlip, cfg.blip.scale or 0.8)
    SetBlipAsShortRange(supplyShopBlip, true)
    setNpcBlip(supplyShopBlip, cfg.blip.label or cfg.label)
end

local function spawnSupplyShopNpc()
    if not Config.EnableDrugTestNPC or not Config.SupplyShopNPC then return end
    supplyShopPed = spawnHubPed(Config.SupplyShopNPC, function(ped)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-store',
                    label = Config.SupplyShopNPC.label or 'Nelegalūs reikmenys',
                    action = openMaterialShop,
                },
            },
            distance = (Config.InteractDistance or 2.5) + 1.0,
        })
    end)
    createSupplyShopBlip()
end

local function spawnTestNpc()
    if not Config.EnableDrugTestNPC or not Config.TestNPC then return end
    testPed = spawnHubPed(Config.TestNPC, function(ped)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-vial',
                    label = Config.TestNPC.label or 'Narkotikų gamyba',
                    action = openTestMenu,
                },
                {
                    icon = 'fas fa-shopping-bag',
                    label = 'Pirkti reikmenis',
                    action = openMaterialShop,
                },
            },
            distance = (Config.InteractDistance or 2.5) + 1.0,
        })
    end)
end

--- Violetiniai žymekliai ant žemės — matosi eilė (tik test režime)
CreateThread(function()
    if not Config.EnableDrugTestNPC then return end
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local hub = Config.DevHub and (Config.DevHub.center or Config.DevHub.blipCoords)
        if hub and #(pos - hub) < 55.0 then
            sleep = 0
            for _, st in ipairs(Config.Stations or {}) do
                if st.coords then
                    DrawMarker(27, st.coords.x, st.coords.y, st.coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        1.15, 1.15, 0.25, 120, 80, 220, 140, false, false, 2, false, nil, nil, false)
                end
            end
            for _, key in ipairs({ 'TestNPC', 'SupplyShopNPC' }) do
                local npc = Config[key]
                if npc and npc.coords then
                    DrawMarker(2, npc.coords.x, npc.coords.y, npc.coords.z + 1.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.35, 0.35, 0.35, 251, 191, 36, 180, false, false, 2, false, nil, nil, false)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(500)
    setupStationBlips()
    setupStations()
    spawnTestNpc()
    spawnSupplyShopNpc()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeUi()
    for _, bl in ipairs(mapBlips) do
        if bl and DoesBlipExist(bl) then RemoveBlip(bl) end
    end
    mapBlips = {}
    if testPed ~= 0 and DoesEntityExist(testPed) then
        DeleteEntity(testPed)
    end
    if supplyShopPed ~= 0 and DoesEntityExist(supplyShopPed) then
        DeleteEntity(supplyShopPed)
    end
    if supplyShopBlip and DoesBlipExist(supplyShopBlip) then
        RemoveBlip(supplyShopBlip)
        supplyShopBlip = nil
    end
end)

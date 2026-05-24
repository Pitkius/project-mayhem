local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPeds = {}
local minigamePromise = nil

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(model)
end

local function spawnStationPed(key, coords, scenario)
    if spawnedPeds[key] and DoesEntityExist(spawnedPeds[key]) then return end
    local m = Config.RangerStation.pedModel
    if not loadModel(m) then return end
    local ped = CreatePed(0, m, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    spawnedPeds[key] = ped
    SetModelAsNoLongerNeeded(m)
end

local function inZoneList(list, pos)
    for _, z in ipairs(list) do
        if #(pos - z.coords) <= z.radius then return true, z end
    end
    return false, nil
end

--- Minigame NUI + animacijos
local function playMinigameAnim(mode)
    local ped = PlayerPedId()
    if mode == 'butcher' then
        local dict = 'anim@amb@business@coc@coc_unpack_cut_left@'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 100 do Wait(10) t = t + 1 end
        TaskPlayAnim(ped, dict, 'coke_cut_coccutter', 3.0, 3.0, -1, 49, 0, false, false, false)
    end
end

function OpenMinigame(mode, data)
    if minigamePromise then return false end
    playMinigameAnim(mode)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', mode = mode, data = data or {} })
    local p = promise.new()
    minigamePromise = p
    local result = Citizen.Await(p)
    minigamePromise = nil
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())
    return result == true
end

RegisterNUICallback('minigameResult', function(body, cb)
    cb('ok')
    if minigamePromise then
        minigamePromise:resolve(body.success == true)
    end
end)

RegisterNUICallback('minigameCancel', function(_, cb)
    cb('ok')
    if minigamePromise then
        minigamePromise:resolve(false)
    end
end)

--- Licencijos rodymas
RegisterNetEvent('fivempro_outdoors:client:showLicense', function(info, title)
    info = info or {}
    notify(('%s | %s %s | ID: %s'):format(
        title,
        info.firstname or '',
        info.lastname or '',
        info.citizenid or '—'
    ), 'primary')
end)

--- Testas
local testState = nil

RegisterNetEvent('fivempro_outdoors:client:startLicenseTest', function(data)
    local testType = data.testType
    QBCore.Functions.TriggerCallback('fivempro_outdoors:server:canTakeLicenseTest', function(ok, msg)
        if not ok then notify(msg or 'Negalima.', 'error') return end
        local questions = testType == 'fishing' and Config.FishingTestQuestions or Config.HuntingTestQuestions
        testState = { testType = testType, questions = questions, index = 1, score = 0 }
        TriggerEvent('fivempro_outdoors:client:showLicenseQuestion')
    end, testType)
end)

RegisterNetEvent('fivempro_outdoors:client:showLicenseQuestion', function()
    if not testState then return end
    local q = testState.questions[testState.index]
    if not q then return end
    local menu = {
        { header = ('Klausimas %s/%s'):format(testState.index, #testState.questions), isMenuHeader = true },
        { header = q.q, isMenuHeader = true },
    }
    for ai, ans in ipairs(q.answers) do
        menu[#menu + 1] = {
            header = ans,
            params = {
                isAction = true,
                event = 'fivempro_outdoors:client:licensePick',
                args = { chosen = ai },
            },
        }
    end
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_outdoors:client:licensePick', function(data)
    if not testState then return end
    local q = testState.questions[testState.index]
    if data.chosen == q.correct then testState.score = testState.score + 1 end
    testState.index = testState.index + 1
    if testState.index > #testState.questions then
        TriggerServerEvent('fivempro_outdoors:server:submitLicenseTest', testState.testType, testState.score, #testState.questions)
        testState = nil
        return
    end
    TriggerEvent('fivempro_outdoors:client:showLicenseQuestion')
end)

--- Žvejyba
local fishBusy = false
RegisterNetEvent('fivempro_outdoors:client:tryFish', function()
    if fishBusy then return end
    local pos = GetEntityCoords(PlayerPedId())
    local inZone = inZoneList(Config.FishingZones, pos)
    if not inZone then
        notify('Ne žvejybos zonoje.', 'error')
        return
    end
    QBCore.Functions.TriggerCallback('fivempro_outdoors:server:hasLicense', function(has)
        if not has then notify('Reikia žvejybos licencijos.', 'error') return end
        fishBusy = true
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_FISHING', 0, true)
        local ok = OpenMinigame('fishing', { label = 'Spausk SPACE kai žymeklis žalioje zonoje' })
        ClearPedTasks(ped)
        if ok then
            TriggerServerEvent('fivempro_outdoors:server:fishReward')
        else
            notify('Žuvies nepavyko pagauti.', 'error')
        end
        SetTimeout(Config.FishCooldown * 1000, function() fishBusy = false end)
    end, 'fishing_license')
end)

--- Skerdimas (butcher stotis ranger)
local function openButcherMenu()
    local menu = {
        { header = 'Skerdykla — apdoroti', isMenuHeader = true },
    }
    for raw, clean in pairs(Config.ButcherMap) do
        local rawItem = QBCore.Shared.Items[raw]
        if rawItem then
            menu[#menu + 1] = {
                header = rawItem.label,
                txt = '→ ' .. (QBCore.Shared.Items[clean] and QBCore.Shared.Items[clean].label or clean),
                params = {
                    isAction = true,
                    event = 'fivempro_outdoors:client:butcherStart',
                    args = { item = raw },
                },
            }
        end
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('fivempro_outdoors:client:butcherStart', function(data)
    local ok = OpenMinigame('butcher', { label = 'Spausk rodykles pagal instrukcijas' })
    if ok then
        TriggerServerEvent('fivempro_outdoors:server:butcherItem', data.item)
    else
        notify('Apdorojimas nepavyko.', 'error')
    end
end)

--- Pardavimas
local function openSellMenu()
    local menu = { { header = 'Supirkimas — gamtininkai', isMenuHeader = true } }
    for item, price in pairs(Config.SellPrices) do
        local it = QBCore.Shared.Items[item]
        if it then
            menu[#menu + 1] = {
                header = it.label .. ' — $' .. price,
                txt = 'Parduoti 1 vnt.',
                params = {
                    isAction = true,
                    event = 'fivempro_outdoors:client:sellOne',
                    args = { item = item },
                },
            }
        end
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('fivempro_outdoors:client:sellOne', function(data)
    TriggerServerEvent('fivempro_outdoors:server:sellItem', data.item, 1)
end)

--- Gamtos parduotuvė
local function openNatureShop(category)
    QBCore.Functions.TriggerCallback('fivempro_outdoors:server:hasLicense', function(has)
        if not has then
            notify('Pirmiausia gaukite licenciją ir išlaikykite testą.', 'error')
            return
        end
        local shop = Config.NatureShop[category]
        if not shop then return end
        local menu = {
            { header = category == 'fishing' and 'Žvejybos reikmenys' or 'Medžioklės reikmenys', isMenuHeader = true },
        }
        for i, entry in ipairs(shop.items) do
            local it = QBCore.Shared.Items[entry.item]
            local label = entry.label or (it and it.label) or entry.item
            menu[#menu + 1] = {
                header = label .. ' — $' .. entry.price,
                txt = 'Kiekis: ' .. (entry.amount or 1),
                params = {
                    isAction = true,
                    event = 'fivempro_outdoors:client:buyNature',
                    args = { category = category, index = i },
                },
            }
        end
        exports['qb-menu']:openMenu(menu)
    end, Config.NatureShop[category].license)
end

RegisterNetEvent('fivempro_outdoors:client:buyNature', function(data)
    TriggerServerEvent('fivempro_outdoors:server:buyNatureItem', data.category, data.index)
end)

--- Target / NPC setup
CreateThread(function()
    local st = Config.RangerStation
    local b = Config.Blips.ranger
    local blip = AddBlipForCoord(st.coords.x, st.coords.y, st.coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.colour)
    SetBlipScale(blip, b.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(b.label)
    EndTextCommandSetBlipName(blip)

    for _, z in ipairs(Config.FishingZones) do
        local fb = Config.Blips.fishing
        local bl = AddBlipForCoord(z.coords.x, z.coords.y, z.coords.z)
        SetBlipSprite(bl, fb.sprite)
        SetBlipColour(bl, fb.colour)
        SetBlipScale(bl, fb.scale)
        SetBlipAsShortRange(bl, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(z.label or fb.label)
        EndTextCommandSetBlipName(bl)
    end

    for _, z in ipairs(Config.HuntingZones) do
        local hb = Config.Blips.hunting
        local bl = AddBlipForCoord(z.coords.x, z.coords.y, z.coords.z)
        SetBlipSprite(bl, hb.sprite)
        SetBlipColour(bl, hb.colour)
        SetBlipScale(bl, hb.scale)
        SetBlipAsShortRange(bl, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(z.label or hb.label)
        EndTextCommandSetBlipName(bl)
    end

    while true do
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        if #(pcoords - vector3(st.coords.x, st.coords.y, st.coords.z)) < 80.0 then
            spawnStationPed('license', st.licenseNpc, 'WORLD_HUMAN_CLIPBOARD')
            spawnStationPed('shop', st.shopNpc, 'WORLD_HUMAN_STAND_IMPATIENT')
            spawnStationPed('buyer', st.buyerNpc, 'WORLD_HUMAN_STAND_IMPATIENT')
        end
        Wait(2000)
    end
end)

CreateThread(function()
    Wait(1500)
    local st = Config.RangerStation

    exports['qb-target']:AddBoxZone('outdoors_license', vector3(st.licenseNpc.x, st.licenseNpc.y, st.licenseNpc.z), 1.2, 1.2, {
        name = 'outdoors_license', heading = st.licenseNpc.w, minZ = st.licenseNpc.z - 1, maxZ = st.licenseNpc.z + 1.5, debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-id-card',
                label = 'Žvejybos licencijos testas ($' .. Config.LicenseTestPrice .. ')',
                action = function() TriggerEvent('fivempro_outdoors:client:startLicenseTest', { testType = 'fishing' }) end,
            },
            {
                icon = 'fas fa-id-card',
                label = 'Medžioklės licencijos testas ($' .. Config.LicenseTestPrice .. ')',
                action = function() TriggerEvent('fivempro_outdoors:client:startLicenseTest', { testType = 'hunting' }) end,
            },
        },
        distance = 2.0,
    })

    exports['qb-target']:AddBoxZone('outdoors_shop_fish', vector3(st.shopNpc.x - 0.5, st.shopNpc.y, st.shopNpc.z), 1.5, 1.0, {
        name = 'outdoors_shop_fish', heading = st.shopNpc.w, minZ = st.shopNpc.z - 1, maxZ = st.shopNpc.z + 1.5, debugPoly = false,
    }, {
        options = {
            { icon = 'fas fa-fish', label = 'Žvejybos reikmenys', action = function() openNatureShop('fishing') end },
            { icon = 'fas fa-crosshairs', label = 'Medžioklės reikmenys', action = function() openNatureShop('hunting') end },
        },
        distance = 2.0,
    })

    exports['qb-target']:AddBoxZone('outdoors_buyer', vector3(st.buyerNpc.x, st.buyerNpc.y, st.buyerNpc.z), 1.2, 1.2, {
        name = 'outdoors_buyer', heading = st.buyerNpc.w, minZ = st.buyerNpc.z - 1, maxZ = st.buyerNpc.z + 1.5, debugPoly = false,
    }, {
        options = {
            { icon = 'fas fa-dollar-sign', label = 'Parduoti laimikį', action = openSellMenu },
        },
        distance = 2.0,
    })

    exports['qb-target']:AddBoxZone('outdoors_butcher', vector3(st.butcherCoords.x, st.butcherCoords.y, st.butcherCoords.z), 1.5, 1.0, {
        name = 'outdoors_butcher', heading = st.butcherCoords.w, minZ = st.butcherCoords.z - 1, maxZ = st.butcherCoords.z + 1.5, debugPoly = false,
    }, {
        options = {
            { icon = 'fas fa-cut', label = 'Apdoroti mėsą / žuvį', action = openButcherMenu },
        },
        distance = 2.0,
    })
end)

--- Musket ragdoll
RegisterNetEvent('fivempro_outdoors:client:musketRagdoll', function()
    local ped = PlayerPedId()
    SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
end)

exports('OpenMinigame', OpenMinigame)
exports('InFishingZone', function()
    return inZoneList(Config.FishingZones, GetEntityCoords(PlayerPedId()))
end)

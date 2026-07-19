local QBCore = exports['qb-core']:GetCoreObject()
local tabletOpen = false
local hackCb = nil
local tabletProp = nil

local TABLET_ANIM_DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a'
local TABLET_ANIM_CLIP = 'idle_a'
local TABLET_ANIM_FALLBACK_DICT = 'amb@world_human_seat_wall_tablet@female@base'
local TABLET_ANIM_FALLBACK_CLIP = 'base'
local TABLET_PROP = `prop_cs_tablet`

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function attachTabletProp(ped)
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil

    RequestModel(TABLET_PROP)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(TABLET_PROP) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(TABLET_PROP) then return end

    local c = GetEntityCoords(ped)
    tabletProp = CreateObject(TABLET_PROP, c.x, c.y, c.z + 0.2, true, true, false)
    SetEntityCollision(tabletProp, false, false)
    AttachEntityToEntity(
        tabletProp,
        ped,
        GetPedBoneIndex(ped, 60309),
        0.03, 0.002, -0.02,
        10.0, 160.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(TABLET_PROP)
end

local function getTabletAnim()
    if loadAnimDict(TABLET_ANIM_DICT) then
        return TABLET_ANIM_DICT, TABLET_ANIM_CLIP
    end
    if loadAnimDict(TABLET_ANIM_FALLBACK_DICT) then
        return TABLET_ANIM_FALLBACK_DICT, TABLET_ANIM_FALLBACK_CLIP
    end
    return nil, nil
end

local function playTabletHoldAnim(ped, dict, clip)
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
end

local function stopTabletAnim()
    local ped = PlayerPedId()
    for _, pair in ipairs({
        { TABLET_ANIM_DICT, TABLET_ANIM_CLIP },
        { TABLET_ANIM_FALLBACK_DICT, TABLET_ANIM_FALLBACK_CLIP },
    }) do
        if pair[1] and IsEntityPlayingAnim(ped, pair[1], pair[2], 3) then
            StopAnimTask(ped, pair[1], pair[2], 1.0)
        end
    end
    ClearPedSecondaryTask(ped)
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil
end

local function playTabletAnim()
    local ped = PlayerPedId()
    local dict, clip = getTabletAnim()
    if not dict then return end
    playTabletHoldAnim(ped, dict, clip)
    attachTabletProp(ped)
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTabletAnim()
end

local function closeHack()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hackClose' })
end

RegisterNetEvent('mrp_hacking:client:openTablet', function(opts)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:getTabletData', function(data)
        if not data or not data.ok then
            return QBCore.Functions.Notify((data and data.msg) or 'Neturi hacking tablet.', 'error')
        end
        tabletOpen = true
        playTabletAnim()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openTablet', data = data, flashTab = opts and opts.flashTab, driveSlot = opts and opts.driveSlot })
        QBCore.Functions.TriggerCallback('mrp_hacking:server:discoverNearbyRobbery', function(res)
            if res and res.new and tabletOpen and res.robberyMapSites then
                SendNUIMessage({
                    action = 'tabletMapRefresh',
                    robberyMapSites = res.robberyMapSites,
                    discoveredRobberyLocs = res.discovered,
                })
            end
        end)
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('networkAction', function(data, cb)
    local tierId = data and data.tierId
    local action = data and data.action
    if action == 'breach' then
        closeTablet()
        local label = (Config.RobberyTiers[tierId] and Config.RobberyTiers[tierId].label) or tierId or 'taikinio'
        QBCore.Functions.Notify(('Artėk prie „%s“ ir naudok target zoną (Pradėti įsilaužimą).'):format(label), 'primary', 8000)
    elseif action == 'backdoor' then
        QBCore.Functions.Notify('Backdoor modulis dar neaktyvuotas šiame taikinyje.', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('marketBuy', function(data, cb)
    local idx = tonumber(data and data.index)
    if idx then
        TriggerServerEvent('mrp_hacking:server:buyBlackMarket', idx)
    end
    cb('ok')
end)

RegisterNUICallback('installDrive', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:installFromDrive', function(res)
        cb(res or { ok = false })
        if res and res.ok then
            SendNUIMessage({ action = 'tabletRefresh', data = res })
            QBCore.Functions.Notify('Įdiegta iš flashdrive.', 'success')
        elseif res and res.msg then
            QBCore.Functions.Notify(res.msg, 'error')
        end
    end, data and data.slot)
end)

function StartHackMinigame(tierId, coords, onDone, locId)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:prepareHack', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.msg) or 'Negali pradėti hack.', 'error')
            if onDone then onDone(false) end
            return
        end
        hackCb = onDone
        exports['mrp_hacking']:PlayRobberyAnim((Config.RobberyAnims or {}).hack)
        PlaySoundFrontend(-1, 'Background', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'hackOpen', profile = res.profile, tierId = tierId })
    end, tierId, locId)
end

RegisterNUICallback('hackResult', function(data, cb)
    local success = data and data.success == true
    local tierId = data and data.tierId
    local coords = GetEntityCoords(PlayerPedId())
    exports['mrp_hacking']:StopRobberyAnim()
    TriggerServerEvent('mrp_hacking:server:hackFinished', tierId, success, { x = coords.x, y = coords.y, z = coords.z })
    closeHack()
    if hackCb then
        local fn = hackCb
        hackCb = nil
        fn(success)
    end
    cb('ok')
end)

RegisterNUICallback('hackCancel', function(_, cb)
    closeHack()
    exports['mrp_hacking']:StopRobberyAnim()
    if hackCb then
        local fn = hackCb
        hackCb = nil
        fn(false)
    end
    cb('ok')
end)

exports('StartHack', StartHackMinigame)

CreateThread(function()
    while true do
        if tabletOpen then
            local ped = PlayerPedId()
            local dict, clip = getTabletAnim()
            if dict and not IsEntityPlayingAnim(ped, dict, clip, 3) then
                playTabletHoldAnim(ped, dict, clip)
            end
            if not tabletProp or not DoesEntityExist(tabletProp) then
                attachTabletProp(ped)
            end
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            if IsControlJustPressed(0, 322) then
                closeTablet()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local lesterPed = nil
local lesterBlip = nil

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopTabletAnim()
    if lesterPed and DoesEntityExist(lesterPed) then
        DeleteEntity(lesterPed)
        lesterPed = nil
    end
    if lesterBlip and DoesBlipExist(lesterBlip) then
        RemoveBlip(lesterBlip)
        lesterBlip = nil
    end
    pcall(function()
        exports['qb-target']:RemoveZone('mrp_hacking_lester_shop')
    end)
end)

local function openLesterShopFromConfig()
    local bm = Config.BlackMarket
    if not bm then return end
    local shopLabel = bm.label or 'Lesteris'
    local currency = bm.currency or 'cash'
    local rows = { { header = shopLabel .. ' — heist reikmenys', isMenuHeader = true } }
    for i, e in ipairs(bm.items or {}) do
        local idx = i
        local label = QBCore.Shared.Items[e.item] and QBCore.Shared.Items[e.item].label or e.item
        local priceTxt = currency == 'crypto' and (('%s₿'):format(e.price)) or (('$%s'):format(e.price))
        local txt = e.desc or ''
        rows[#rows + 1] = {
            header = ('%s — %s'):format(label, priceTxt),
            txt = txt ~= '' and txt or nil,
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_hacking:server:buyBlackMarket', idx)
                end,
            },
        }
    end
    if GetResourceState('qb-menu') == 'started' then
        exports['qb-menu']:openMenu(rows)
    else
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(500)
    end
    --- Palaukti, kol žaidėjas įsikraus (collision / ground Z)
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(1500)

    local bm = Config.BlackMarket
    if not bm or bm.enabled == false or not bm.coords then return end

    local hash = joaat(bm.pedModel or 'ig_lestercrest')
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then
        print('[mrp_hacking] WARN: Lester ped model failed to load, fallback dealer')
        hash = joaat('s_m_y_dealer_01')
        RequestModel(hash)
        deadline = GetGameTimer() + 8000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    end

    local x, y, z = bm.coords.x + 0.0, bm.coords.y + 0.0, bm.coords.z + 0.0
    if HasModelLoaded(hash) then
        RequestCollisionAtCoord(x, y, z)
        local colDeadline = GetGameTimer() + 4000
        while GetGameTimer() < colDeadline do
            RequestCollisionAtCoord(x, y, z)
            local ok, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
            if ok and gz and gz > 0.0 then
                z = gz
                break
            end
            Wait(50)
        end

        lesterPed = CreatePed(0, hash, x, y, z, bm.heading or 0.0, false, true)
        if lesterPed and lesterPed ~= 0 and DoesEntityExist(lesterPed) then
            SetEntityAsMissionEntity(lesterPed, true, true)
            SetEntityInvincible(lesterPed, true)
            SetBlockingOfNonTemporaryEvents(lesterPed, true)
            SetPedCanRagdoll(lesterPed, false)
            FreezeEntityPosition(lesterPed, true)
            SetPedDiesWhenInjured(lesterPed, false)
            SetEntityCoordsNoOffset(lesterPed, x, y, z, false, false, false)
            if bm.scenario then
                TaskStartScenarioInPlace(lesterPed, bm.scenario, 0, true)
            end
        else
            print('[mrp_hacking] ERROR: CreatePed failed for Lester')
            lesterPed = nil
        end
        SetModelAsNoLongerNeeded(hash)
    else
        print('[mrp_hacking] ERROR: could not load Lester/dealer ped — zone-only shop')
    end

    local shopLabel = bm.label or 'Lesteris'
    local options = {
        {
            icon = 'fas fa-toolbox',
            label = shopLabel .. ' — heist reikmenys',
            action = openLesterShopFromConfig,
        },
    }

    local cryptoCfg = Config.CryptoExchange or {}
    if cryptoCfg.enabled == true then
        options[#options + 1] = {
            icon = 'fas fa-bitcoin-sign',
            label = 'Keisti banką į crypto',
            action = function()
                if GetResourceState('qb-input') ~= 'started' then
                    return QBCore.Functions.Notify('qb-input neaktyvus.', 'error')
                end
                local input = exports['qb-input']:ShowInput({
                    header = 'Bankas → Crypto',
                    submitText = 'Keisti',
                    inputs = {
                        {
                            type = 'number',
                            name = 'amount',
                            text = ('Suma banke ($%s–$%s)'):format(cryptoCfg.minAmount or 500, cryptoCfg.maxAmount or 500000),
                            isRequired = true,
                        },
                    },
                })
                if not input or not input.amount then return end
                TriggerServerEvent('mrp_hacking:server:exchangeBankToCrypto', tonumber(input.amount))
            end,
        }
    end

    if lesterPed and DoesEntityExist(lesterPed) then
        exports['qb-target']:AddTargetEntity(lesterPed, {
            options = options,
            distance = 2.5,
        })
    end

    --- Atsarginė zona (jei ped nerodomas)
    exports['qb-target']:AddCircleZone('mrp_hacking_lester_shop', vector3(x, y, z), 2.2, {
        name = 'mrp_hacking_lester_shop',
        useZ = true,
        debugPoly = false,
    }, {
        options = options,
        distance = 2.5,
    })

    local blipCfg = bm.blip
    if blipCfg and blipCfg.enabled ~= false then
        lesterBlip = AddBlipForCoord(x, y, z)
        SetBlipSprite(lesterBlip, blipCfg.sprite or 521)
        SetBlipDisplay(lesterBlip, 4)
        SetBlipScale(lesterBlip, blipCfg.scale or 0.75)
        SetBlipColour(lesterBlip, blipCfg.colour or 1)
        SetBlipAsShortRange(lesterBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(blipCfg.label or 'Apiplėšimo reikmenys')
        EndTextCommandSetBlipName(lesterBlip)
    end
end)

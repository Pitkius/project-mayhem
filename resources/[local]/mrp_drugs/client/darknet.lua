--[[
  Client: Dark Net — UI fokusas, NUI callback'ai, dead drop, PIN, telefono pardavėjas.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local playerState = { darknetAccess = false, introState = 0, levelUnlocked = 1 }

local dropData = nil       -- aktyvaus dead drop info
local dropEntity = nil
local dropBlip = nil
local dropRadiusBlip = nil
local vendorPed = nil

local function nui(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function notify(msg, typ, dur)
    QBCore.Functions.Notify(msg, typ or 'primary', dur)
end

-- ── Būsenos sinchronizacija ────────────────────────────────────────
RegisterNetEvent('mrp_drugs:client:playerStateSync', function(state)
    if type(state) == 'table' then
        playerState = state
    end
end)

exports('GetDrugPlayerState', function() return playerState end)

-- ── UI atidarymas / uždarymas ──────────────────────────────────────
RegisterNetEvent('mrp_drugs:client:openDarknet', function(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    nui('darknet:open', payload)
end)

RegisterNetEvent('mrp_drugs:client:darknetOrderSync', function(order)
    nui('darknet:orderSync', { order = order })
end)

RegisterNUICallback('darknetClose', function(_, cb)
    uiOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('darknetPlaceOrder', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetPlaceOrder', function(res)
        if not res or not res.ok then
            notify((res and res.reason) or 'Užsakymas nepavyko.', 'error')
        else
            notify(res.night and 'Siunta paruošta — patikrink zoną.' or 'Užsakymas priimtas. Lauk nakties.', 'success')
        end
        nui('darknet:orderSync', { order = res and res.order or nil })
    end, data and data.cart or {})
    cb('ok')
end)

RegisterNUICallback('darknetCancelOrder', function(_, cb)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetCancelOrder', function(res)
        if res and res.ok then
            notify('Užsakymas atšauktas.', 'primary')
        else
            notify((res and res.reason) or 'Nepavyko atšaukti.', 'error')
        end
        nui('darknet:orderSync', { order = nil })
    end)
    cb('ok')
end)

RegisterNUICallback('darknetPinSubmit', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetCollect', function(res)
        if res and res.ok then
            notify('Siunta atsiimta.', 'success')
        else
            notify((res and res.reason) or 'Nepavyko atsiimti.', 'error')
        end
        SetNuiFocus(false, false)
        uiOpen = false
    end, data and data.orderId, data and data.pin)
    cb('ok')
end)

RegisterNUICallback('darknetPinCancel', function(_, cb)
    if not uiOpen then
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

-- ── Dead drop ──────────────────────────────────────────────────────
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do Wait(10); t = t + 10 end
    return HasModelLoaded(hash)
end

local function clearDrop()
    if dropEntity and DoesEntityExist(dropEntity) then
        exports['qb-target']:RemoveTargetEntity(dropEntity)
        DeleteEntity(dropEntity)
    end
    dropEntity = nil
    if dropBlip then RemoveBlip(dropBlip); dropBlip = nil end
    if dropRadiusBlip then RemoveBlip(dropRadiusBlip); dropRadiusBlip = nil end
    dropData = nil
end

local function openPinPrompt()
    if not dropData then return end
    SetNuiFocus(true, true)
    nui('darknet:pin', { orderId = dropData.id })
end

local function spawnDrop(data)
    clearDrop()
    if not data or not data.drop then return end
    dropData = data
    local d = data.drop
    local radius = tonumber(data.radius) or (Config.DarkNet.searchRadius or 70.0)

    -- Paieškos zona žemėlapyje (apytikslė, ne tikslus taškas).
    dropRadiusBlip = AddBlipForRadius(d.x, d.y, d.z, radius)
    SetBlipHighDetail(dropRadiusBlip, true)
    SetBlipColour(dropRadiusBlip, 1)
    SetBlipAlpha(dropRadiusBlip, 90)

    dropBlip = AddBlipForCoord(d.x, d.y, d.z)
    SetBlipSprite(dropBlip, 501)
    SetBlipColour(dropBlip, 1)
    SetBlipScale(dropBlip, 0.7)
    SetBlipAsShortRange(dropBlip, true)
    -- Slepiam tikslų tašką: blipas tik zonos centre, mažas.
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Dark Net siunta')
    EndTextCommandSetBlipName(dropBlip)

    CreateThread(function()
        local model = data.prop or 'prop_cs_package_01'
        if not loadModel(model) then return end
        local z = d.z
        local found, gz = GetGroundZFor_3dCoord(d.x, d.y, d.z + 2.0, false)
        if found then z = gz end
        dropEntity = CreateObject(joaat(model), d.x, d.y, z, false, false, false)
        PlaceObjectOnGroundProperly(dropEntity)
        FreezeEntityPosition(dropEntity, true)
        SetModelAsNoLongerNeeded(joaat(model))

        if GetResourceState('qb-target') == 'started' then
            exports['qb-target']:AddTargetEntity(dropEntity, {
                options = {
                    {
                        icon = 'fas fa-box',
                        label = 'Atsiimti siuntą (PIN)',
                        action = function() openPinPrompt() end,
                    },
                },
                distance = (Config.DarkNet.interactDist or 2.0) + 0.5,
            })
        end
    end)
end

RegisterNetEvent('mrp_drugs:client:darknetDropActive', function(data)
    spawnDrop(data)
    notify('Siunta palikta. Patikrink pažymėtą zoną žemėlapyje.', 'primary', 8000)
end)

RegisterNetEvent('mrp_drugs:client:darknetDropClear', function(_orderId)
    clearDrop()
end)

-- ── Telefono pardavėjas (juodosios rinkos kontaktas) ───────────────
local function spawnVendor()
    local v = Config.DarkNet and Config.DarkNet.phoneVendor
    if not v or v.enabled == false or not v.coords then return end
    if vendorPed and DoesEntityExist(vendorPed) then return end
    if not loadModel(v.model) then return end
    local c = v.coords
    vendorPed = CreatePed(4, joaat(v.model), c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
    SetEntityInvincible(vendorPed, true)
    FreezeEntityPosition(vendorPed, true)
    SetBlockingOfNonTemporaryEvents(vendorPed, true)
    if v.scenario then TaskStartScenarioInPlace(vendorPed, v.scenario, 0, true) end
    SetModelAsNoLongerNeeded(joaat(v.model))

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(vendorPed, {
            options = {
                {
                    icon = 'fas fa-mobile-screen',
                    label = 'Nusipirkti Dark Net telefoną',
                    canInteract = function() return playerState and playerState.darknetAccess == true end,
                    action = function()
                        QBCore.Functions.TriggerCallback('mrp_drugs:server:darknetBuyPhone', function(res)
                            if res and res.ok then
                                notify('Įrenginys nupirktas.', 'success')
                            else
                                notify((res and res.reason) or 'Pirkimas nepavyko.', 'error')
                            end
                        end)
                    end,
                },
            },
            distance = 2.5,
        })
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end
    Wait(800)
    spawnVendor()
    TriggerServerEvent('mrp_drugs:server:darknetRequestSync')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(4000, function()
        TriggerServerEvent('mrp_drugs:server:darknetRequestSync')
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearDrop()
    if vendorPed and DoesEntityExist(vendorPed) then DeleteEntity(vendorPed) end
end)
